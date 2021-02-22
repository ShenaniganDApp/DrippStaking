pragma solidity ^0.8.0;

import "./interface/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./access/Ownable.sol";

contract DrippStaking is Ownable {
    using SafeERC20 for IERC20;

    struct Dripp {
        address primaryToken;
        address lpToken;
        uint256 activeTime;
        uint256 supply;
    }

    struct Account {
        mapping(address => uint256) ghstStakingTokensAllowances;
        mapping(address => uint256) tokensStaked;
        mapping(address => uint256) liquidityTokensStaked;
        mapping(address => uint256) rewards;
        uint256 lastRewardUpdate;
    }

    mapping(address => uint256) totalTokenStaked;
    mapping(address => uint256) totalRewards;
    mapping(address => Account) accounts;
    mapping(address => Dripp) dripps;
    address[] allDripps;

    /*
     * @notice stake ERC20 tokens in the contract
     */
    function stake(address token, uint256 amount) external {
        require(amount > 0, "Stake Token: Token amount must be greater than 0");
        updateRewards();
        IERC20 stakeToken = IERC20(token);
        accounts[msg.sender].tokensStaked[token] += amount;
        stakeToken.transferFrom(msg.sender, address(this), amount);
    }

    /*
     * @notice stake ERC20 liquidity tokens in the contract
     */
    function stakeLP(address token, uint256 amount) external {
        require(amount > 0, "Stake Token: Token amount must be greater than 0");
        updateRewards();
        IERC20 stakeToken = IERC20(token);
        accounts[msg.sender].liquidityTokensStaked[token] += amount;
        stakeToken.transferFrom(msg.sender, address(this), amount);
    }

    /*
     * @notice withdraw ERC20 tokens from the contract
     */
    function withdrawTokenStake(address token, uint256 _amount) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].tokensStaked[token];
        require(bal >= _amount, "Can't withdraw more token than staked");
        IERC20 stakeToken = IERC20(token);
        accounts[msg.sender].tokensStaked[token] = uint96(bal - _amount);
        totalTokenStaked[token] -= _amount;
        stakeToken.transfer(msg.sender, _amount);
    }

    /*
     * @notice withdraw ERC20 liquidity tokens from the contract
     */
    function withdrawLiquidityStake(address token, uint256 _amount) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].liquidityTokensStaked[token];
        require(
            bal >= _amount,
            "Can't withdraw more liquidity token than in account"
        );
        accounts[msg.sender].liquidityTokensStaked[token] = bal - _amount;
        totalTokenStaked[token] -= _amount;
        IERC20 stakeToken = IERC20(token);
        stakeToken.transfer(msg.sender, _amount);
    }

    /*
     * @notice withdraw all ERC20 tokens from the contract
     */
    function withdrawTokenStake(address token) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].tokensStaked[token];
        require(bal != 0, "Cannot withdraw zero token stake balance");
        accounts[msg.sender].tokensStaked[token] = uint96(0);
        totalTokenStaked[token] -= bal;
        IERC20 stakeToken = IERC20(token);
        stakeToken.transfer(msg.sender, bal);
    }

    /*
     * @notice withdraw all ERC20 liquidity tokens from the contract
     */
    function withdrawLiquidityStake(address token) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].liquidityTokensStaked[token];
        require(bal != 0, "Cannot withdraw zero liquidity stake balance");
        accounts[msg.sender].liquidityTokensStaked[token] = 0;
        totalTokenStaked[token] -= bal;
        IERC20 stakeToken = IERC20(token);
        stakeToken.transfer(msg.sender, bal);
    }

    /*
     * @notice add a dripp token to start dripping out of the contract
     */
    function startDripp(
        address token,
        address primaryToken,
        address lpToken,
        uint256 activeTime,
        uint256 supply
    ) external {
        require(
            activeTime > 0,
            "Start Dripp: Dripp must be active for some amount of time"
        );
        require(supply > 0, "Start Dripp: Supply must be greater than 0");
        dripps[token] = Dripp(primaryToken, lpToken, activeTime, supply);
        allDripps.push(token);
    }

    /*
     * @notice Calulate rewards per block
     */
    function reward(address _account, address token) public returns (uint256) {
        Account storage account = accounts[_account];
        // address(this) cannot underflow or overflow
        require(
            totalRewards[token] < dripps[token].supply,
            "Maximum amount of rewards have been given out"
        );
        uint256 timePeriod = block.timestamp - account.lastRewardUpdate;
        IERC20 drippToken = IERC20(token);
        require(
            drippToken.balanceOf(address(this)) > 0,
            "address(this) contracts has no more of address(this) Dripp"
        );
        uint256 cap = dripps[token].supply;
        address primaryToken = dripps[token].primaryToken;
        address liquidityToken = dripps[token].lpToken;
        uint256 reward_ = account.rewards[token];
        uint256 rewardedTokens = 0;
        rewardedTokens +=
            (((account.tokensStaked[primaryToken] /
                totalTokenStaked[primaryToken]) * cap) * timePeriod) /
            dripps[token].activeTime;
        rewardedTokens +=
            (((account.liquidityTokensStaked[liquidityToken] /
                totalTokenStaked[liquidityToken]) * cap) * timePeriod) /
            dripps[token].activeTime;
        if ((totalRewards[token] + rewardedTokens) > cap) {
            rewardedTokens = cap - totalRewards[token];
        }
        totalRewards[token] += rewardedTokens;
        account.rewards[token] = reward_ + rewardedTokens;

        return account.rewards[token];
    }

    function updateRewards() internal {
        Account storage account = accounts[msg.sender];
        for (uint256 i = 0; i < allDripps.length; i++) {
            account.rewards[allDripps[i]] = reward(msg.sender, allDripps[i]);
        }
        account.lastRewardUpdate = uint40(block.timestamp);
    }

    /*
     * @notice Claim dripp tokens
     */
    function claim(address token) external {
        updateRewards();
        Account storage account = accounts[msg.sender];
        IERC20 drippToken = IERC20(token);
        require(
            drippToken.balanceOf(address(this)) > account.rewards[token],
            "Claim: Contract has no tokens left"
        );
        account.rewards[token] = 0;
        drippToken.transfer(msg.sender, account.rewards[token]);
    }

    function accountTokenStaked(address token, address _account)
        external
        view
        returns (uint256)
    {
        return accounts[_account].tokensStaked[token];
    }

    function accountLPStaked(address token, address _account)
        external
        view
        returns (uint256)
    {
        return accounts[_account].liquidityTokensStaked[token];
    }

    function accountRewards(address token, address _account)
        external
        view
        returns (uint256)
    {
        return accounts[_account].rewards[token];
    }

    function totalStaked(address token) external view returns (uint256) {
        return totalTokenStaked[token];
    }

    /*
     *@notice get rewards for each dripp token
     */
    function totalRewarded(address token) external view returns (uint256) {
        return totalRewards[token];
    }
}

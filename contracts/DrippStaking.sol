pragma solidity ^0.8.0;

import "./interface/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./access/Ownable.sol";

contract DrippStaking is Ownable {
    using SafeERC20 for IERC20;

    struct Dripp {
        address primaryToken;
        address lpToken;
        uint256 rate;
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

    constructor(
        address[] memory token,
        address[] memory primaryToken,
        address[] memory lpToken,
        uint256[] memory activeTime,
        uint256[] memory supply
    ) {
        for (uint256 i = 0; i < token.length; i++) {
            startDripp(
                token[i],
                primaryToken[i],
                lpToken[i],
                activeTime[i],
                supply[i]
            );
        }
    }

    /*
     * @notice stake ERC20 tokens in the contract
     */
    function stake(address token, uint256 amount) external {
        require(amount > 0, "Stake Token: Token amount must be greater than 0");
        updateRewards();
        IERC20 stakeToken = IERC20(token);
        accounts[msg.sender].tokensStaked[token] += amount;
        totalTokenStaked[token] += amount;
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /*
     * @notice stake ERC20 liquidity tokens in the contract
     */
    function stakeLP(address token, uint256 amount) external {
        require(amount > 0, "Stake Token: Token amount must be greater than 0");
        updateRewards();
        IERC20 stakeToken = IERC20(token);
        accounts[msg.sender].liquidityTokensStaked[token] += amount;
        totalTokenStaked[token] += amount;
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
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
        stakeToken.safeTransfer(msg.sender, _amount);
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
        stakeToken.safeTransfer(msg.sender, _amount);
    }

    /*
     * @notice withdraw all ERC20 tokens from the contract
     */
    function withdrawAllTokenStake(address token) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].tokensStaked[token];
        require(bal != 0, "Cannot withdraw zero token stake balance");
        accounts[msg.sender].tokensStaked[token] = uint96(0);
        totalTokenStaked[token] -= bal;
        IERC20 stakeToken = IERC20(token);
        stakeToken.safeTransfer(msg.sender, bal);
    }

    /*
     * @notice withdraw all ERC20 liquidity tokens from the contract
     */
    function withdrawAllLiquidityStake(address token) external {
        updateRewards();
        uint256 bal = accounts[msg.sender].liquidityTokensStaked[token];
        require(bal != 0, "Cannot withdraw zero liquidity stake balance");
        accounts[msg.sender].liquidityTokensStaked[token] = 0;
        totalTokenStaked[token] -= bal;
        IERC20 stakeToken = IERC20(token);
        stakeToken.safeTransfer(msg.sender, bal);
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
    ) public onlyOwner {
        require(
            activeTime > 0,
            "Start Dripp: Dripp must be active for some amount of time"
        );
        require(supply > 0, "Start Dripp: Supply must be greater than 0");
        uint256 rate = setDrippRate(activeTime, supply);
        dripps[token] = Dripp(primaryToken, lpToken, rate, supply);
        allDripps.push(token);
    }

    function setDrippRate(uint256 time, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        return supply / time;
    }

    /*
     * @notice Calulate rewards per block
     */
    function reward(address _account, address token)
        public
        view
        returns (uint256 reward_, uint256 rewardedTokens_)
    {
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
        address primaryToken = dripps[token].primaryToken;
        address liquidityToken = dripps[token].lpToken;
        reward_ = account.rewards[token];
        rewardedTokens_ = 0;
        if (totalTokenStaked[primaryToken] > 0) {
            rewardedTokens_ +=
                ((account.tokensStaked[primaryToken] /
                    totalTokenStaked[primaryToken]) *
                    dripps[token].rate *
                    timePeriod) /
                2;
        }
        if (totalTokenStaked[liquidityToken] > 0) {
            rewardedTokens_ +=
                ((account.liquidityTokensStaked[liquidityToken] /
                    totalTokenStaked[liquidityToken]) *
                    dripps[token].rate *
                    timePeriod) /
                2;
            if (
                (totalRewards[token] + rewardedTokens_) > dripps[token].supply
            ) {
                rewardedTokens_ = dripps[token].supply - totalRewards[token];
            }
            reward_ = reward_ + rewardedTokens_;
        }
    }

    function updateRewards() internal {
        Account storage account = accounts[msg.sender];
        for (uint256 i = 0; i < allDripps.length; i++) {
            (uint256 reward_, uint256 rewardedTokens_) =
                reward(msg.sender, allDripps[i]);
            totalRewards[allDripps[i]] += rewardedTokens_;
            account.rewards[allDripps[i]] = reward_;
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
        drippToken.safeTransfer(msg.sender, account.rewards[token]);
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

    function drippRate(address token) external view returns (uint256) {
        return dripps[token].rate;
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

    function countDripps() external view returns (uint256) {
        return allDripps.length;
    }
}

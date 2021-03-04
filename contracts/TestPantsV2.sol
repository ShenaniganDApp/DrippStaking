// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20PresetMinterPauser.sol";

contract TestpantsV2Token is ERC20PresetMinterPauser {
    constructor(uint256 initialSupply, address migrator)
        public
        ERC20PresetMinterPauser("Shenanigan Testpants V2", "TESTPANTS")
    {
        _mint(msg.sender, initialSupply);
        grantRole(MINTER_ROLE, migrator);
    }
}

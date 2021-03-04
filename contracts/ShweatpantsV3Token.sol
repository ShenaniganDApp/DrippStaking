// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20PresetMinterPauser.sol";

contract ShweatpantsV3Token is ERC20PresetMinterPauser {
    constructor(uint256 initialSupply, address migrator)
        public
        ERC20PresetMinterPauser("Shenanigan Shweatpants V3", "SHWEATPANTS")
    {
        _mint(msg.sender, initialSupply);
        grantRole(MINTER_ROLE, migrator);
    }
}

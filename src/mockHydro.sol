// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {ERC20} from "oz/contracts/token/ERC20/ERC20.sol";

contract MockHydro is ERC20 {
    constructor() ERC20("MHYDRO", "MHD") {
        _mint(msg.sender, 1000e18);
    }
}

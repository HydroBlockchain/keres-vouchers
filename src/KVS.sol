// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {ERC20} from "../lib/openzeppelin-contracts.git/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts.git/contracts/access/Ownable.sol";

contract KVS is ERC20, Ownable {
    error OnlyStakerContract();

    constructor() ERC20("Keres Vouchers", "KVS") {
        _mint(msg.sender, 201497100e18);
    }

    address ExchangeContract;

    function burn(uint256 _amount, address _target) external {
        if (msg.sender != ExchangeContract) revert OnlyStakerContract();
        _burn(_target, _amount);
    }

    function setStaker(address _exchangeContract) public onlyOwner {
        ExchangeContract = _exchangeContract;
    }
}

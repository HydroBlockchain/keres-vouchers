// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import "../src/mockHydro.sol";
import "../src/KVS.sol";
import "../lib/forge-std/src/Vm.sol";
import {IERC20} from "oz/contracts/token/ERC20/ERC20.sol";

contract StakingTest is Test {
    MockHydro hydro;
    KVS kvs;
    KVSStaking stake;

    function setUp() public {
        //deploy tokens
        hydro = new MockHydro();
        kvs = new KVS();

        //deploy staker
        stake = new KVSStaking(address(hydro), address(kvs));
        IERC20(kvs).transfer(address(stake), 1000e18);
        stake.toggleStake(true);
    }

    function testStake() public {
        IERC20(address(hydro)).approve(address(stake), 100000000000e18);
        stake.stake(1000e18);
        //13days
        vm.warp(1200000);
        uint256 total = stake.checkCurrentRewards(address(this));
        stake.checkCurrentRate();
        stake.exit();
        stake.checkCurrentRewards(address(this));
        stake.viewUser(address(this));

        vm.warp(block.timestamp + 7 days);
        stake.claimHydro();
        //
        stake.viewUser(address(this));
        stake.stake(1000e18);
        stake.checkCurrentRewards(address(this));
        vm.warp(block.timestamp + 1000);
        // //vm.warp(1200000);
        stake.checkCurrentRewards(address(this));
        // stake.viewUser(address(this));
        // emit log_uint(block.timestamp);
        stake.withdrawFunds(100e18);
        // stake.claimHydro();
        vm.warp(block.timestamp + 7 days);
        stake.claimHydro();
        // stake.checkCurrentRewards(address(this));
        // stake.viewUser(address(this));
        // stake.totalHydroStaked();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SimpleStaking} from "../contracts/SimpleStaking.sol";
import {ISimpleStaking} from "../contracts/interfaces/ISimpleStaking.sol";
import {BEP20Token} from "../contracts/Mocks/BEP20Token.sol";
import {Test, console} from "forge-std/Test.sol";

interface CheatCodes {
    // Gets address for a given private key, (privateKey) => (address)
    function addr(uint256) external returns (address);
}

contract TestSimpleStaking is Test {
    SimpleStaking public stake_contract;
    BEP20Token public token_contract;

    address nativeTokenAddress = address(0);
    address newOwner = vm.addr(1);
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    address[] public banAddresses;

    function setUp() public {
        stake_contract = new SimpleStaking();
        token_contract = new BEP20Token();

        deal(user1, 10e18);
        deal(user2, 10e18);

        token_contract.mint(3_000_000_000_000);
        token_contract.owner();
        token_contract.transfer(user1, 2_000_000_000_000);
        token_contract.transfer(user2, 1_000_000_000_000); // 1m tokens with 6 decimals

        stake_contract.whitelistToken(address(token_contract));
        stake_contract.whitelistToken(nativeTokenAddress);
    }

    // ======================================
    //              Whitelisting
    // ======================================

    // [Fail] Non-owner cannot whitelist
    function testFailWhiteListTokenUnauthorized() public {
        vm.prank(user1);
        stake_contract.whitelistToken(address(token_contract));
        assertFalse(stake_contract.whitelistedTokens(address(token_contract)));
    }

    // [Fail] Non-owner cannot remove whitelisted
    function testFailRemoveWhiteListTokenUnauthorized() public {
        stake_contract.whitelistToken(address(token_contract));
        vm.prank(user1);
        stake_contract.removeWhitelistedToken(address(token_contract));
        assertTrue(stake_contract.whitelistedTokens(address(token_contract)));
    }

    // [OK] Owner can whitelist
    function testWhitelistToken() public {
        stake_contract.whitelistToken(address(token_contract));
        assertTrue(stake_contract.whitelistedTokens(address(token_contract)));
    }

    // [OK] Owner can remove whitelisted
    function testRemoveWhitelistToken() public {
        stake_contract.removeWhitelistedToken(address(token_contract));
        assertFalse(stake_contract.whitelistedTokens(address(token_contract)));
    }

    // ======================================
    //              Staking
    // ======================================

    // [Fail] Stake non-whitelisted token
    function testFailStakeNonWhitelisted() public {
        stake_contract.removeWhitelistedToken(address(token_contract));
        vm.prank(user1);
        stake_contract.stake(address(token_contract), 500);
    }

    // [Fail] Stake amount > user balance
    function testFailStakeInsufficientBalance() public {
        uint256 userBalance = token_contract.balanceOf(user1);
        uint256 oneTooMany = userBalance + 1;
        vm.prank(user1);
        stake_contract.stake(address(token_contract), oneTooMany);
    }

    // [OK] Stake and check user balance
    function testStake() public {
        uint256 userBalance = token_contract.balanceOf(user1);
        uint256 stakeAmount = 500 * 10 ** 6;

        vm.startPrank(user1);
        token_contract.approve(address(stake_contract), stakeAmount);
        stake_contract.stake(address(token_contract), stakeAmount);
        vm.stopPrank();

        assertEq(token_contract.balanceOf(user1), userBalance - stakeAmount);
        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount);
        assertEq(stake_contract.totalStaked(address(token_contract)), stakeAmount);
    }

    // [OK] Stake increase
    function testStakeIncrease() public {
        uint256 userBalance = token_contract.balanceOf(user1);
        uint256 stakeAmount1 = 500 * 10 ** 6;

        vm.startPrank(user1);
        token_contract.approve(address(stake_contract), userBalance);
        stake_contract.stake(address(token_contract), stakeAmount1);

        assertEq(token_contract.balanceOf(user1), userBalance - stakeAmount1);
        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount1);
        assertEq(stake_contract.totalStaked(address(token_contract)), stakeAmount1);

        uint256 stakeAmount2 = 2000 * 10 ** 6;
        stake_contract.stake(address(token_contract), stakeAmount2);

        assertEq(token_contract.balanceOf(user1), userBalance - (stakeAmount1 + stakeAmount2));
        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount1 + stakeAmount2);
        assertEq(stake_contract.totalStaked(address(token_contract)), stakeAmount1 + stakeAmount2);
    }

    // [OK] Emit stake event
    function testEmitStakeEvent() public {
        vm.startPrank(user1);
        uint256 stakeAmount = 500 * 10 ** 6;

        token_contract.approve(address(stake_contract), stakeAmount);

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.Stake(user1, address(token_contract), stakeAmount, block.timestamp);
        stake_contract.stake(address(token_contract), stakeAmount);
    }

    // ======================================
    //              Unstaking
    // ======================================

    // [Fail] Unstake amount > user staked balance
    function testFailUnstakeInsufficientStakeBalance() public {
        vm.startPrank(user1);
        uint256 stakeAmount = 500 * 10 ** 6;

        token_contract.approve(address(stake_contract), stakeAmount);
        stake_contract.stake(address(token_contract), stakeAmount);

        stake_contract.unstake(address(stake_contract), stakeAmount + 1);
        vm.stopPrank();
    }

    // [Ok] Unstake
    function testUnstake() public {
        vm.startPrank(user1);

        uint256 stakeAmount = 500 * 10 ** 6;
        uint256 unstakeAmount = 200 * 10 ** 6;

        token_contract.approve(address(stake_contract), stakeAmount);
        stake_contract.stake(address(token_contract), stakeAmount);

        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount);
        assertEq(stake_contract.totalStaked(address(token_contract)), stakeAmount);

        stake_contract.unstake(address(token_contract), unstakeAmount);

        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount - unstakeAmount);
        assertEq(stake_contract.totalStaked(address(token_contract)), stakeAmount - unstakeAmount);
    }

    // [OK] Emit unstake event
    function testEmitUnstakeEvent() public {
        vm.startPrank(user1);

        uint256 stakeAmount = 500 * 10 ** 6;
        uint256 unstakeAmount = 200 * 10 ** 6;

        token_contract.approve(address(stake_contract), stakeAmount);
        stake_contract.stake(address(token_contract), stakeAmount);

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.Unstake(user1, address(token_contract), unstakeAmount, block.timestamp);
        stake_contract.unstake(address(token_contract), unstakeAmount);
    }

    // ======================================
    //             Native Staking
    // ======================================

    // [Fail] Native token not whitelisted
    function testFailNativeNotWhitelisted() public {
        stake_contract.removeWhitelistedToken(nativeTokenAddress);

        vm.prank(user1);
        stake_contract.stakeNative();
    }

    // [OK] Native stake
    function testNativeStake() public {
        uint256 stakeAmount = 500 * 10 ** 6;

        vm.startPrank(user1);

        stake_contract.stakeNative{value: stakeAmount}();

        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount);
    }

    // [OK] Increase native staked amount
    function testNativeStakeIncrease() public {
        uint256 stakeAmount1 = 500 * 10 ** 6;
        uint256 stakeAmount2 = 200 * 10 ** 6;

        vm.startPrank(user1);

        // Stake 1
        stake_contract.stakeNative{value: stakeAmount1}();
        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount1);

        // Stake 2
        stake_contract.stakeNative{value: stakeAmount2}();
        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount1 + stakeAmount2);
    }

    // [OK] Emit staked event
    function testEmitNativeStakeEvent() public {
        uint256 stakeAmount = 500 * 10 ** 6;

        vm.startPrank(user1);

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.Stake(user1, nativeTokenAddress, stakeAmount, block.timestamp);
        stake_contract.stakeNative{value: stakeAmount}();
    }

    // ======================================
    //            Native Unstaking
    // ======================================

    // [OK] Unstake
    function testNativeUnstake() public {
        uint256 stakeAmount = 500 * 10 ** 6;
        uint256 unstakeAmount = 200 * 10 ** 6;

        vm.startPrank(user1);

        // Stake
        stake_contract.stakeNative{value: stakeAmount}();
        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount);

        // Unstake
        stake_contract.unstakeNative(unstakeAmount);
        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount - unstakeAmount);
    }

    // [Fail] Unstake amount > staked balance
    function testFailInsufficientNativeStakedBalance() public {
        uint256 stakeAmount = 500 * 10 ** 6;
        uint256 unstakeAmount = 1000 * 10 ** 6;

        vm.startPrank(user1);

        // Stake
        stake_contract.stakeNative{value: stakeAmount}();
        assertEq(stake_contract.stakes(user1, nativeTokenAddress), stakeAmount);

        // Unstake
        stake_contract.unstakeNative(unstakeAmount);
    }

    // [OK] Emit unstaked event
    function testEmitNativeUnstakeEvent() public {
        uint256 stakeAmount = 500 * 10 ** 6;
        uint256 unstakeAmount = 200 * 10 ** 6;

        vm.startPrank(user1);
        stake_contract.stakeNative{value: stakeAmount}();

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.Unstake(user1, nativeTokenAddress, unstakeAmount, block.timestamp);
        stake_contract.unstakeNative(unstakeAmount);
    }

    // ======================================
    //              Ban User
    // ======================================

    // [Fail] Unauthorised user cannot ban
    function testFailUnauthorisedBanUser() public {
        vm.startPrank(user1);

        banAddresses.push(user1);
        stake_contract.setBannedAddress(banAddresses, true);
    }

    // [OK] Ban user and emit event
    function testBanUser() public {
        banAddresses.push(user1);

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.SetBannedAddress(address(this), banAddresses, true);
        stake_contract.setBannedAddress(banAddresses, true);
        assertTrue(stake_contract.bannedAddresses(user1));
    }

    // [OK] Ban multiple users and emit event
    function testBanMultipleUsers() public {
        banAddresses.push(user1);
        banAddresses.push(user2);

        vm.expectEmit(true, true, true, true);
        emit ISimpleStaking.SetBannedAddress(address(this), banAddresses, true);
        stake_contract.setBannedAddress(banAddresses, true);
        assertTrue(stake_contract.bannedAddresses(user1));
        assertTrue(stake_contract.bannedAddresses(user2));
    }

    // [Fail] Banner user tries to stake
    function testFailBannedUserStakes() public {
        uint256 stakeAmount = 500 * 10 ** 6;

        banAddresses.push(user1);
        stake_contract.setBannedAddress(banAddresses, true);

        vm.startPrank(user1);

        token_contract.approve(address(stake_contract), stakeAmount);

        stake_contract.stake(address(token_contract), stakeAmount);
        assertEq(stake_contract.stakes(user1, address(token_contract)), 0);
    }

    // [OK] Unbanned user allowed to stake
    function testUnbannedUserStakes() public {
        uint256 stakeAmount = 500 * 10 ** 6;

        banAddresses.push(user1);
        stake_contract.setBannedAddress(banAddresses, true);
        assertTrue(stake_contract.bannedAddresses(user1));
        stake_contract.setBannedAddress(banAddresses, false);
        assertFalse(stake_contract.bannedAddresses(user1));

        vm.startPrank(user1);

        token_contract.approve(address(stake_contract), stakeAmount);
        stake_contract.stake(address(token_contract), stakeAmount);
        assertEq(stake_contract.stakes(user1, address(token_contract)), stakeAmount);
    }
}

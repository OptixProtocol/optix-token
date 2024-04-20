// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakingRewards} from "src/StakingRewards.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";


contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;

    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);

        // Deploy mock tokens
        stakingToken = new MockERC20("Staking Token", "STK", 18);
        rewardsToken = new MockERC20("Rewards Token", "RWD", 18);

        // Allocate some tokens for testing
        stakingToken.mint(owner, 1e24); // 1 million tokens
        stakingToken.mint(user1, 1e24);
        rewardsToken.mint(address(this), 1e24);

        // Deploy the StakingRewards contract
        stakingRewards = new StakingRewards(address(stakingToken), address(rewardsToken));

        // Approve StakingRewards contract to spend on behalf of owner and user1
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        vm.prank(user1); stakingToken.approve(address(stakingRewards), type(uint256).max);
    }

    function test_StakeTokens() public {
        uint256 amountToStake = 1e23; // 100k tokens
        stakingRewards.stake(amountToStake);

        // Verify the state after staking
        assertEq(stakingToken.balanceOf(address(stakingRewards)), amountToStake, "StakingRewards contract did not receive the tokens");
        assertEq(stakingRewards.balances(owner), amountToStake, "Owner's staked balance is incorrect");
        assertEq(stakingRewards.totalSupply(), amountToStake, "Total supply is incorrect");
    }

    function testFuzz_StakeTokens(uint256 amountToStake) public {
        // Skip overflows and 0 staking
        vm.assume(amountToStake > 0 && amountToStake <= 1e24);

        stakingRewards.stake(amountToStake);

        // Verify the state after staking
        assertEq(stakingToken.balanceOf(address(stakingRewards)), amountToStake, "StakingRewards contract did not receive the tokens");
        assertEq(stakingRewards.balances(owner), amountToStake, "Owner's staked balance is incorrect");
        assertEq(stakingRewards.totalSupply(), amountToStake, "Total supply is incorrect");
    }

    function test_WithdrawTokens() public {
        uint256 amountToStake = 1e23; // 100k tokens
        stakingRewards.stake(amountToStake);
        stakingRewards.withdraw(amountToStake);

        // Verify the state after withdrawing
        assertEq(stakingToken.balanceOf(address(this)), 1e24, "Owner did not receive the tokens back");
        assertEq(stakingRewards.balances(owner), 0, "Owner's staked balance should be zero");
        assertEq(stakingRewards.totalSupply(), 0, "Total supply should be zero");
    }

    function test_UpdateRewardRate() public {
        // Setup: Initial reward rate
        uint256 initialRate = stakingRewards.rewardRate();
        uint256 newRate = initialRate + 1e18; // Increase by 1 token per second

        // Act: Update reward rate
        stakingRewards.setRewardRate(newRate);

        // Assert: Reward rate is updated
        assertEq(stakingRewards.rewardRate(), newRate, "Reward rate not updated correctly");

        // Assert: Only owner can update

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user1); stakingRewards.setRewardRate(initialRate);
    }


    function testFuzz_WithdrawTokens(uint256 amountToStake, uint256 amountToWithdraw) public {
        vm.assume(amountToStake > 0 && amountToStake <= 1e24 && amountToWithdraw <= amountToStake);
        stakingRewards.stake(amountToStake);

        stakingRewards.withdraw(amountToWithdraw);

    }


    function testFuzz_ClaimRewards(uint256 amountToStake, uint256 timeToWait) public {
        vm.assume(amountToStake > 0 && amountToStake <= 1e24 && timeToWait < 365 days);
        stakingRewards.stake(amountToStake);
        vm.warp(block.timestamp + timeToWait);
    }   

}

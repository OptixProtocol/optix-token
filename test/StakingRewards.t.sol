// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakingRewards} from "src/StakingRewards.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;

    address private owner;
    address private user1;
    address private user2;

    function setUp() public {
            owner = address(this); // Set the contract deployer as owner
            user1 = vm.addr(1);
            user2 = vm.addr(2);

            rewardsToken = new MockERC20("Rewards Token", "RWT", 18);
            stakingToken = new MockERC20("Staking Token", "STK", 18);

            rewardsToken.mint(owner, 1_000_000e18); // Mint some tokens for the owner
            stakingToken.mint(user1, 100_000e18);   // Mint staking tokens for user1
            stakingToken.mint(user2, 100_000e18);   // Mint staking tokens for user2

            vm.prank(owner); 
            stakingRewards = new StakingRewards(
                address(rewardsToken),
                address(stakingToken)
            );

            // Approve staking token to stakingRewards from users
            vm.prank(user1); stakingToken.approve(address(stakingRewards), 100_000e18);
            vm.prank(user2); stakingToken.approve(address(stakingRewards), 100_000e18);
        }

        function test_SR_PauseAndUnpauseStaking() public {
            vm.prank(owner); stakingRewards.pause();
            assertTrue(stakingRewards.paused(), "Staking should be paused");

            vm.prank(owner); vm.expectRevert(Pausable.EnforcedPause.selector);
            stakingRewards.stake(10_000e18);

            vm.prank(owner); stakingRewards.unpause();
            assertFalse(stakingRewards.paused(), "Staking should be unpaused");

            vm.prank(user1); stakingRewards.stake(10_000e18); // Should succeed after unpausing
        }

        function test_SR_RewardDistribution() public {
            uint amount = 10_000e18;
            uint rewardAmount = 500e18;

            vm.prank(user1); stakingRewards.stake(amount);

            vm.startPrank(owner);
            rewardsToken.transfer(address(stakingRewards), rewardAmount);
            stakingRewards.notifyRewardAmount(rewardAmount);
            vm.stopPrank();

            vm.warp(block.timestamp + 5 days); // Fast-forward time

            vm.startPrank(user1);
            uint earnedBefore = stakingRewards.earned(user1);
            stakingRewards.getReward(); // Claim reward
            uint earnedAfter = stakingRewards.earned(user1);
            assertLt(earnedAfter, earnedBefore, "Earned rewards should decrease after claiming");
            uint balanceAfter = rewardsToken.balanceOf(user1);
            assertTrue(balanceAfter > 0, "User should have received rewards tokens");
            vm.stopPrank();
        }

        function test_SR_OnlyOwnerCanPauseAndUnpause() public {
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
            vm.prank(user1); // user1 is not the owner
            stakingRewards.pause();

            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
            vm.prank(user2); // user2 is not the owner
            stakingRewards.unpause();
        }

        function test_SR_OnlyOwnerCanNotifyRewardAmount() public {
            uint256 rewardAmount = 1e18;
            vm.prank(owner); rewardsToken.transfer(address(stakingRewards), rewardAmount);

            // Only owner should be able to notify reward amount
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
            vm.prank(user1);
            stakingRewards.notifyRewardAmount(rewardAmount);

            // Successful call by owner
            vm.prank(owner);
            stakingRewards.notifyRewardAmount(rewardAmount);
        }

}

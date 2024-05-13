// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {StakingRewards} from "src/StakingRewards.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewardsDualTokenTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public optixToken;
    // MockERC20 public optixToken;

    address private owner;
    address private user1;
    address private user2;

    function setUp() public {
            owner = address(this); // Set the contract deployer as owner
            user1 = vm.addr(1);
            user2 = vm.addr(2);

            optixToken = new MockERC20("Opitx Token", "OPTIX", 18);
            // optixToken = new MockERC20("Staking Token", "STK", 18);

            optixToken.mint(owner, 1_000_000e18); // Mint some tokens for the owner
            optixToken.mint(user1, 100_000e18);   // Mint staking tokens for user1
            optixToken.mint(user2, 100_000e18);   // Mint staking tokens for user2

            vm.prank(owner); 
            stakingRewards = new StakingRewards(
                address(optixToken),
                address(optixToken)
            );

            // Approve staking token to stakingRewards from users
            vm.prank(user1); optixToken.approve(address(stakingRewards), 100_000e18);
            vm.prank(user2); optixToken.approve(address(stakingRewards), 100_000e18);
            vm.prank(owner); optixToken.approve(address(stakingRewards), 100_000e18);
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
            optixToken.transfer(address(stakingRewards), rewardAmount);
            stakingRewards.notifyRewardAmount(rewardAmount);
            vm.stopPrank();

            vm.warp(block.timestamp + 5 days); // Fast-forward time

            vm.startPrank(user1);
            uint earnedBefore = stakingRewards.earned(user1);
            stakingRewards.getReward(); // Claim reward
            uint earnedAfter = stakingRewards.earned(user1);
            assertLt(earnedAfter, earnedBefore, "Earned rewards should decrease after claiming");
            uint balanceAfter = optixToken.balanceOf(user1);
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

            // Only owner should be able to notify reward amount
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
            vm.prank(user1);
            stakingRewards.notifyRewardAmount(rewardAmount);

            // Successful call by owner
            vm.prank(owner);
            stakingRewards.notifyRewardAmount(rewardAmount);
        }

        function test_SR_UpdateRewardOnStake() public {
            uint256 amount = 1e18; // 1 token
            vm.startPrank(user1);
            optixToken.approve(address(stakingRewards), amount);
            stakingRewards.stake(amount);
            vm.stopPrank();
            
            uint256 expectedReward = 0;
            assertEq(stakingRewards.earned(user1), expectedReward, "Reward should be zero after staking with no ongoing rewards");

            // Simulate passing time and then staking by another user
            vm.warp(block.timestamp + 1 days);
            vm.startPrank(user2);
            optixToken.approve(address(stakingRewards), amount);
            stakingRewards.stake(amount);
            vm.stopPrank();
            
            expectedReward = calculateExpectedReward(1 days, amount);
            assertEq(stakingRewards.earned(user1), expectedReward, "Reward for user1 should be updated correctly after time passes and another user stakes");
        }

        function test_SR_UpdateRewardOnWithdraw() public {
            uint256 stakeAmount = 1e18; // 1 token
            vm.startPrank(user1);
            optixToken.approve(address(stakingRewards), stakeAmount);
            stakingRewards.stake(stakeAmount);
            vm.stopPrank();

            vm.warp(block.timestamp + 1 days);

            vm.startPrank(user1);
            stakingRewards.withdraw(stakeAmount / 2); // Withdraw half of the staked tokens
            vm.stopPrank();
            
            uint256 expectedReward = calculateExpectedReward(1 days, stakeAmount / 2);
            assertEq(stakingRewards.earned(user1), expectedReward, "Reward should be correctly calculated after partial withdrawal");
        }

        function test_SR_UpdateRewardOnGetReward() public {
            uint256 rewardAmount = 100000e18; // Sufficient reward tokens transferred to the contract
            // vm.prank(owner);
            // optixToken.transfer(address(stakingRewards), rewardAmount);

            uint256 stakeAmount = 1e18; // 1 token
            vm.startPrank(user1);
            optixToken.approve(address(stakingRewards), stakeAmount);
            stakingRewards.stake(stakeAmount);
            vm.stopPrank();
            
            // Notify reward amount to start the reward calculation
            vm.startPrank(owner);
            stakingRewards.notifyRewardAmount(rewardAmount); // Notify a total reward amount
            vm.stopPrank();

            // Fast forward to allow some reward accumulation
            vm.warp(block.timestamp + 1 days);

            // Calculate the expected rewards before claiming
            uint256 expectedRewards = stakingRewards.earned(user1);

            vm.startPrank(user1);
            stakingRewards.getReward(); // User claims their reward
            vm.stopPrank();
            
            // Check that all rewards have been claimed and earned rewards reset to zero
            assertEq(stakingRewards.earned(user1), 0, "Earned rewards should be zero after claiming");

            // Check the contract's reward token balance to confirm the payout
            uint256 remainingRewardInContract = stakingRewards.rewardsBalance();
            uint256 expectedRemainingInContract = rewardAmount - expectedRewards;
            assertEq(remainingRewardInContract, expectedRemainingInContract, "Incorrect reward token balance in contract after claiming");
        }

        function test_SR_rewardPerToken_NoStakes() public {
            // Test with no stakes to see if reward per token is handled correctly
            assertEq(stakingRewards.rewardPerToken(), 0, "Reward per token should be zero when no stakes are present");
        }

        function test_SR_rewardPerToken_AfterSingleStake() public {
            uint256 amount = 1e18; // 1 token
            uint256 rewardAmount = 1e18; // 1 token as reward

            // User1 stakes some tokens
            vm.startPrank(user1);
            optixToken.approve(address(stakingRewards), amount);
            stakingRewards.stake(amount);
            vm.stopPrank();

            // Transfer reward tokens to the staking contract and notify a reward amount
            vm.startPrank(owner);
            optixToken.transfer(address(stakingRewards), rewardAmount);
            stakingRewards.notifyRewardAmount(rewardAmount);
            vm.stopPrank();

            // Simulate time passing
            uint daysElapsed = 1;
            vm.warp(block.timestamp + daysElapsed * 1 days);

            // The rewardRate will be `rewardAmount / rewardsDuration`
            uint256 rewardRate = rewardAmount / stakingRewards.rewardsDuration();
            uint256 lastTimeRewardApplicable = block.timestamp;
            uint256 lastUpdateTime = block.timestamp - (daysElapsed * 1 days);
            uint256 expectedRewardPerToken = (lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18 / 1e18;

            assertEq(stakingRewards.rewardPerToken(), expectedRewardPerToken, "Reward per token should match expected calculation after single stake");
        }


        function test_SR_rewardPerToken_AfterMultipleStakes() public {
            uint256 rewardAmount = 3e18; // 3 tokens as reward
            uint256 stakeAmount1 = 1e18; // 1 token
            uint256 stakeAmount2 = 2e18; // 2 tokens

            // User1 and User2 stake tokens
            vm.startPrank(user1);
            optixToken.approve(address(stakingRewards), stakeAmount1);
            stakingRewards.stake(stakeAmount1); // 1 token
            vm.stopPrank();

            vm.startPrank(user2);
            optixToken.approve(address(stakingRewards), stakeAmount2);
            stakingRewards.stake(stakeAmount2); // 2 tokens
            vm.stopPrank();

            // Transfer reward tokens to the staking contract and notify a reward amount
            vm.startPrank(owner);
            optixToken.transfer(address(stakingRewards), rewardAmount);
            stakingRewards.notifyRewardAmount(rewardAmount);
            vm.stopPrank();

            // Simulate time passing
            uint daysElapsed = 1;
            vm.warp(block.timestamp + daysElapsed * 1 days);

            // The rewardRate will be `rewardAmount / rewardsDuration`
            uint256 rewardRate = rewardAmount / stakingRewards.rewardsDuration();
            uint256 lastTimeRewardApplicable = block.timestamp;
            uint256 lastUpdateTime = block.timestamp - (daysElapsed * 1 days);
            uint256 totalSupply = stakeAmount1 + stakeAmount2;
            uint256 expectedRewardPerToken = (lastTimeRewardApplicable - lastUpdateTime) * rewardRate * 1e18 / totalSupply;

            assertEq(stakingRewards.rewardPerToken(), expectedRewardPerToken, "Reward per token should match expected calculation after multiple stakes");
        }

        function test_SR_SetRewardsDuration_Success() public {
            uint256 newDuration = 14 days;

            // Ensure the contract is in the right state (after the reward period)
            vm.warp(stakingRewards.periodFinish() + 1); // Warp to just after the reward period finishes

            vm.prank(owner);
            stakingRewards.setRewardsDuration(newDuration);

            assertEq(stakingRewards.rewardsDuration(), newDuration, "The rewards duration should be updated to the new value");
        }

        function test_SR_SetRewardsDuration_FailIfNotOwner() public {
            uint256 newDuration = 14 days;
            address nonOwner = address(0x2);

            vm.warp(stakingRewards.periodFinish() + 1); // Warp to just after the reward period finishes

            vm.prank(nonOwner);
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
            stakingRewards.setRewardsDuration(newDuration);
        }

        function test_SR_SetRewardsDuration_FailIfPeriodNotComplete() public {
            uint256 amount = 1e18; // 1 token
            uint256 rewardAmount = 1e18; // 1 token as reward

            vm.startPrank(owner);
            optixToken.transfer(address(stakingRewards), rewardAmount);
            stakingRewards.notifyRewardAmount(rewardAmount);
            vm.stopPrank();

            uint256 newDuration = 14 days;

            // Attempt to set duration while the reward period is still active
            vm.expectRevert("Previous rewards period must be complete before changing the duration for the new period");
            vm.prank(owner);
            stakingRewards.setRewardsDuration(newDuration);

            vm.warp(stakingRewards.periodFinish() + 1); // Warp to just after the reward period finishes
            vm.prank(owner);
            stakingRewards.setRewardsDuration(newDuration);
        }


        // Helper function to calculate the expected reward based on time and staked amount
        function calculateExpectedReward(uint256 time, uint256 amount) internal view returns (uint256) {
            uint256 rewardRate = stakingRewards.rewardRate();
            uint256 rewardPerToken = rewardRate * time;
            return (rewardPerToken * amount) / 1e18; 
        }


}

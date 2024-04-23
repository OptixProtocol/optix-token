// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, console2} from "forge-std/Test.sol";
import {VestingWallet, VestingSchedule} from "../src/VestingWallet.sol";
import {OptixToken} from "../src/OptixToken.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

/// @title Tests for VestingWallet's address change functionality
/// @notice Uses forge-std for testing the VestingWallet contract
contract VestingWalletTest is Test {
    VestingWallet public vestingWallet;
    OptixToken public optixToken;

    uint tgeTimestamp = 1715950800; //13:00 UTC, 17TH MAY 2024
    uint optixTotalSupply = 1200000000; //1.2B
    uint optixDecimals = 18;

    address teamUser = 0x554c52D1327E8dCDD36BAB93029eEbF07f22B0C8;
    address foundationUser = 0xEa065ca7cbF183b2C390156Fa569aD7728ba2d9e;
    address ecosystemUser = 0x74Db12E988508f886478377EfE056eFde47Eacbf;
    address privateUser = 0xb2a76c4A18b2863C155a8E382eBD231ffED48101;
    address marketingUser = 0x5676C522B1fa65465c684F108B94FBc4132fED3b;

    address publicTokensUser = 0xAD15b8d09b95ffCfd0865AF7AE61b4E88F4fF5C2;
    address liquidityTokensUser = 0xA4747D8FE7e0Be4962ca376E4c33295110781A81;

    //months are considered to be 30 days
    uint teamCliffPeriod = 12 * 30 days; //1 yr
    uint foundationCliffPeriod = 30 days; //1 month
    uint ecosystemCliffPeriod = 30 days; //1 month
    uint privateCliffPeriod = 0;
    uint marketingCliffPeriod = 0;

    //unlock amount
    uint teamUnlockAmount = 0;
    uint foundationUnlockAmount = 0;
    uint ecosystemUnlockAmount = 0;
    uint privateUnlockAmount = 5;
    uint marketingUnlockAmount = 10;

    //vesting % linear monthly
    uint teamVesting = 2;
    uint foundationVesting = 3;
    uint ecosystemVesting = 2;
    uint privateVesting = 8;
    uint marketingVesting = 11;

    address newBeneficiary = address(0x1);

    MockERC20 mockToken;
    VestingWallet mockVesting;
    uint mockTotalSupply = 2400000000;
    uint8 mockDecimals = 18;


    /// @notice Sets up the test by deploying the token and vesting wallet contracts
    /// and initializing addresses for the beneficiary and new beneficiary
    function setUp() public {
        optixToken = new OptixToken();
        vestingWallet = new VestingWallet();

        optixToken.initialize(address(vestingWallet), publicTokensUser, liquidityTokensUser);
        vestingWallet.initialize(address(optixToken));

        //for testing boundary ranges
        mockToken = new MockERC20("Mock", "MCK", mockDecimals);
        mockVesting = new VestingWallet();
        mockToken.mint(address(mockVesting), mockTotalSupply * 10 ** mockDecimals);
        mockVesting.initialize(address(mockToken));
    }

    function test_VW_InitialBalanceAndSupply() public {
        assertEq(18, optixToken.decimals()); 
        assertEq(optixToken.totalSupply(), optixTotalSupply * 10 ** optixToken.decimals());

        //2% public tokens
        assertEq(optixToken.balanceOf(address(publicTokensUser)), optixToken.totalSupply() * 2 / 100);

        //2% liquidity tokens
        assertEq(optixToken.balanceOf(address(liquidityTokensUser)), optixToken.totalSupply() * 2 / 100);

        //96% vesting wallet
        assertEq(optixToken.balanceOf(address(vestingWallet)), optixToken.totalSupply() * 96 / 100);
        assertEq(vestingWallet.scheduledTokens(), optixToken.totalSupply() * 96 / 100);
    }

    function test_VW_InitialSchedules() public {
        checkVestingSchedule(teamUser, teamCliffPeriod, teamVesting, teamUnlockAmount);
        checkVestingSchedule(foundationUser, foundationCliffPeriod, foundationVesting, foundationUnlockAmount); //broken
        checkVestingSchedule(ecosystemUser, ecosystemCliffPeriod, ecosystemVesting, ecosystemUnlockAmount);
        checkVestingSchedule(privateUser, privateCliffPeriod, privateVesting, privateUnlockAmount); //broken
        checkVestingSchedule(marketingUser, marketingCliffPeriod, marketingVesting, marketingUnlockAmount); //broken
    }

    function test_VW_PreTGE() public {
        vm.warp(tgeTimestamp - 1 seconds);
        vm.prank(teamUser); vm.expectRevert("Vesting: start time not reached"); vestingWallet.withdraw();
        vm.prank(foundationUser); vm.expectRevert("Vesting: start time not reached"); vestingWallet.withdraw();
        vm.prank(ecosystemUser); vm.expectRevert("Vesting: start time not reached"); vestingWallet.withdraw();
        vm.prank(privateUser); vm.expectRevert("Vesting: start time not reached"); vestingWallet.withdraw();
        vm.prank(marketingUser); vm.expectRevert("Vesting: start time not reached"); vestingWallet.withdraw();
    }

    /// @notice Tests that the initial unlock amount is correctly available after the cliff period
    function test_VW_InitialUnlockAmount() public {
        vm.warp(tgeTimestamp);

        vm.prank(teamUser); vm.expectRevert("Vesting: still in cliff period"); vestingWallet.withdraw();
        vm.prank(foundationUser); vm.expectRevert("Vesting: still in cliff period"); vestingWallet.withdraw();
        vm.prank(ecosystemUser); vm.expectRevert("Vesting: still in cliff period"); vestingWallet.withdraw();

        VestingSchedule memory schedule = vestingWallet.getVestingSchedule(privateUser);
        vm.prank(privateUser); assertEq(vestingWallet.withdraw(), schedule.totalAmount * 5 / 100); //5% of total amount

        schedule = vestingWallet.getVestingSchedule(marketingUser);
        vm.prank(marketingUser); assertEq(vestingWallet.withdraw(), schedule.totalAmount * 10 / 100); //10% of total amount
    }

    /// @notice Test withdraw can begin once the cliff period has passed
    function test_VW_CliffPassed() public {
        vm.warp(tgeTimestamp+foundationCliffPeriod);
        vm.prank(foundationUser); assertEq(vestingWallet.withdraw(),0);
        vm.prank(ecosystemUser); assertEq(vestingWallet.withdraw(),0);

        vm.warp(tgeTimestamp+teamCliffPeriod);
        vm.prank(teamUser); assertEq(vestingWallet.withdraw(),0);
    }

    /// @notice Tests the linear release of tokens after the cliff and before the end of the vesting period
    function test_VW_VestingRelease() public {
        checkVestingAmount(teamUser, teamCliffPeriod, teamVesting);
        checkVestingAmount(foundationUser, foundationCliffPeriod, foundationVesting);
        checkVestingAmount(ecosystemUser, ecosystemCliffPeriod, ecosystemVesting);
        checkVestingAmount(marketingUser, marketingCliffPeriod, marketingVesting);
    }

    //////////////////////////
    // Address Change Tests //
    //////////////////////////

    /// @notice Test that a beneficiary can successfully change their vesting schedule's associated address
    function test_VW_SuccessfulAddressChange() public {
        // Change their vesting address
        vm.prank(teamUser); vestingWallet.changeAddress(newBeneficiary);

        // Verify the vesting schedule has been successfully transferred to the new beneficiary
        assertTrue(vestingWallet.hasVestingSchedule(newBeneficiary), "New beneficiary should have a schedule");
        assertFalse(vestingWallet.hasVestingSchedule(teamUser), "Old beneficiary should not have a schedule");
    }

    /// @notice Test that an unauthorized address cannot change a beneficiary's vesting schedule address
    /// @dev This test should fail if an address other than the beneficiary tries to change the vesting address
    function test_VW_Fail_UnauthorizedAddressChange() public {
        // Attempting to change the vesting address without proper authorization
        vm.expectRevert();
        vestingWallet.changeAddress(newBeneficiary);
    }

    /// @notice Test that a vesting schedule cannot be transferred to an address that already has a vesting schedule
    /// @dev The contract should revert the transaction if the new address already has a vesting schedule
    function test_VW_Fail_ChangeToAddressWithSchedule() public {
        // Simulate the beneficiary's attempt to transfer their schedule to an address that already has one
        vm.prank(teamUser);
        vm.expectRevert();
        vestingWallet.changeAddress(foundationUser); // This should fail
    }


    function test_VW_Fail_RegisterVestingSchedule_StartHasPassed() public {
        vm.warp(tgeTimestamp); 
        uint256 startTime = tgeTimestamp-1 days; // Start time is in the past
        uint256 cliffTime = startTime;
        uint256 endTime = startTime + 30 days;
        uint256 unlockAmount = 0;
        uint256 totalAmount = 100 * 10 ** mockDecimals;

        // Expect a revert due to invalid timing
        vm.expectRevert("Vesting: start time has passed");
        mockVesting.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);
    }


    function test_VW_Fail_RegisterVestingSchedule_InvalidTimes() public {
        uint256 startTime = block.timestamp + 365 days; // Start time is in the future
        uint256 cliffTime = startTime - 1 days; // Cliff time before start time, which is invalid
        uint256 endTime = startTime + 30 days;
        uint256 unlockAmount = 1e23;
        uint256 totalAmount = mockTotalSupply;

        // Expect a revert due to invalid timing
        vm.expectRevert("Vesting: cliff starts before vesting");
        mockVesting.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);
    }



    function test_VW_Fail_RegisterVestingSchedule_ExceedMaxSupply() public {
        
        uint256 startTime = tgeTimestamp;
        uint256 cliffTime = startTime + 30 days;
        uint256 endTime = startTime + 365 days;
        uint256 unlockAmount = 0; // Set an unlock amount that exceeds max
        uint256 totalAmount = mockTotalSupply; // Total amount exceeding total vested amount

    //     // Expect a revert due to exceeding max supply
        vm.expectRevert("Vesting: exceeds max supply");
        vestingWallet.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);
    }

    // Your newly refactored function
    function checkVestingSchedule(address account, uint256 cliffPeriod, uint256 monthlyVestingPercentage, uint256 unlockAmount) public view {
        VestingSchedule memory schedule = vestingWallet.getVestingSchedule(account);

        assertEq(schedule.startTimeInSec, tgeTimestamp);
        assertEq(schedule.cliffTimeInSec, tgeTimestamp + cliffPeriod);

        uint256 monthsToVestCompletely = 1e9 / monthlyVestingPercentage;
        assertLt(schedule.endTimeInSec - 5, schedule.cliffTimeInSec + (monthsToVestCompletely * 30 days / 1e7));
        assertGt(schedule.endTimeInSec + 5, schedule.cliffTimeInSec + (monthsToVestCompletely * 30 days / 1e7));
        // assertEq(schedule.unlockAmount, unlockAmount);
    }

    /// @notice Test that the vesting amount for the tokens is correct over time
    function checkVestingAmount(address account, uint256 cliffPeriod, uint monthlyVestingPercentage) public {
        VestingSchedule memory schedule;
        uint cliffTimeInSec = tgeTimestamp + cliffPeriod;
        uint256 monthsToVestCompletely = 100 / monthlyVestingPercentage;
        uint endTimeInSec = cliffTimeInSec + (monthsToVestCompletely * 30 days);

        uint256 totalVestingPeriod = endTimeInSec - cliffTimeInSec;
        // uint256 totalVestingAmount = schedule.totalAmount;

        for (uint256 i = 1; i <= 10; i++) {
            // console.log("i: ", i);
            schedule = vestingWallet.getVestingSchedule(account);

            uint256 currentTime = cliffTimeInSec + (totalVestingPeriod * i / 10);
            vm.warp(currentTime);

            // Calculate the expected vesting amount at this point in time
            uint timeSinceCliff = block.timestamp - schedule.cliffTimeInSec;
            uint vestingDuration = schedule.endTimeInSec - schedule.cliffTimeInSec;
            uint expectedAmount = schedule.totalAmount * timeSinceCliff / vestingDuration;
            expectedAmount = schedule.unlockAmount + expectedAmount;
            if (expectedAmount > schedule.totalAmount) {
                expectedAmount = schedule.totalAmount;
            }
            expectedAmount = expectedAmount - schedule.totalAmountWithdrawn;

            // Check that the user has the expected amount of tokens at this point in time
            vm.prank(account);
            uint amount = vestingWallet.withdraw();
            assertEq(amount, expectedAmount, "User did not receive the correct amount at this point in time");
        }
    }

}




    // /// @dev Fuzz test for registering vesting schedules with random parameters
    // function testFuzz_VW_RegisterVestingSchedule(uint256 startTime, uint256 cliffDuration, uint256 vestingDuration, uint256 unlockAmount, uint256 totalAmount) public {
    //     // Adjust the inputs to ensure valid vesting schedules
    //     uint256 adjustedStartTime = startTime % 365 days + block.timestamp; // Ensure start times are within a reasonable range
    //     uint256 adjustedCliffDuration = cliffDuration % 90 days; // Max cliff duration of 90 days
    //     uint256 adjustedVestingDuration = vestingDuration % 365 days + adjustedCliffDuration; // Ensure vesting duration is at least as long as the cliff
    //     uint256 adjustedTotalAmount = totalAmount % 1e24; // Cap the total amount to avoid unrealistic values
    //     uint256 adjustedUnlockAmount = unlockAmount % adjustedTotalAmount; // Ensure unlock amount does not exceed total amount

    //     vm.assume(adjustedVestingDuration > adjustedCliffDuration); // Ensure vesting duration is longer than cliff duration
    //     vm.assume(adjustedStartTime + adjustedVestingDuration > block.timestamp); // Ensure the vesting period ends in the future

    //     // Attempt to register a vesting schedule with fuzzed parameters
    //     try vestingWallet.registerVestingSchedule(address(1), adjustedStartTime, adjustedStartTime + adjustedCliffDuration, adjustedStartTime + adjustedVestingDuration, adjustedUnlockAmount, adjustedTotalAmount) {
    //         // Success, assert expected outcomes or state changes here
    //     } catch {
    //         // Handle expected failures (e.g., due to invalid parameters) here
    //     }
    // }


    // /// @dev Fuzz test for withdrawal behavior at random times
    // function testFuzz_VW_Withdraw(uint256 timeOffset) public {
    //     // Setup a known vesting schedule
    //     uint256 amount = 1e18; // Example amount
    //     uint256 unlockAmount = 2e17; // Example initial unlock amount
    //     uint256 startTime = block.timestamp;
    //     uint256 cliffTime = startTime + 30 days;
    //     uint256 endTime = startTime + 365 days;
    //     vestingWallet.registerVestingSchedule(address(this), startTime, cliffTime, endTime, unlockAmount, amount);

    //     // Warp to a random time within or beyond the vesting period
    //     uint256 adjustedTime = block.timestamp + (timeOffset % (2 * 365 days)); // Within a two-year range
    //     vm.warp(adjustedTime);

    //     // Attempt withdrawal
    //     vestingWallet.withdraw();
    //     // Assert expected outcomes based on the warped time
    // }


    // /// @dev Fuzz test for changing vesting schedule addresses to random addresses
    // function testFuzz_VW_ChangeAddress(address newAddress) public {
    //     // Setup a known vesting schedule for the test's sender
    //     uint256 amount = 1e18;
    //     vestingWallet.registerVestingSchedule(msg.sender, block.timestamp, block.timestamp + 30 days, block.timestamp + 365 days, 2e17, amount);

    //     // Attempt to change the vesting schedule's beneficiary to a fuzzed address
    //     vm.assume(newAddress != address(0)); // Exclude the zero address
    //     vm.prank(msg.sender);
    //     try vestingWallet.changeAddress(newAddress) {
    //         // Success, assert state changes or outcomes here
    //     } catch {
    //         // Handle reverts or failures expectedly
    //     }
    // }
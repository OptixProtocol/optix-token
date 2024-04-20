// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, console2} from "forge-std/Test.sol";
import {VestingWallet} from "../src/VestingWallet.sol";
import {OptixToken} from "../src/OptixToken.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

/// @title Tests for VestingWallet's address change functionality
/// @notice Uses forge-std for testing the VestingWallet contract
contract VestingWalletTest is Test {
    VestingWallet public vestingWallet;
    OptixToken public token;

    address public beneficiary;
    address public newBeneficiary;

    /// @notice Sets up the test by deploying the token and vesting wallet contracts
    /// and initializing addresses for the beneficiary and new beneficiary
    function setUp() public {
        token = new OptixToken();
        vestingWallet = new VestingWallet(); // Example max supply

        beneficiary = vm.addr(1);
        newBeneficiary = vm.addr(2);
    }

    /// @notice Registers a vesting schedule for testing
    /// @param _beneficiary The address to receive the vesting schedule
    function registerSchedule(address _beneficiary) internal {
        uint256 amount = 1e18; // Example amount
        vestingWallet.registerVestingSchedule(_beneficiary, block.timestamp, block.timestamp + 1 days, block.timestamp + 365 days, 0, amount);
    }

    function setupVestingSchedule(uint256 amount, uint256 unlockAmount, uint256 startTime, uint256 cliffTime, uint256 endTime) internal {
        // Adjust the block timestamp to the start time for consistency
        vm.warp(startTime);

        // Register a vesting schedule
        vestingWallet.registerVestingSchedule(beneficiary, startTime, cliffTime, endTime, unlockAmount, amount);
    }


    /// @notice Tests that the initial unlock amount is correctly available after the cliff period
    function testInitialUnlockAmount() public {
        uint256 amount = 1e18; // Total amount to vest
        uint256 unlockAmount = 2e17; // Initial unlock amount (20% of total)
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + 30 days; // Cliff period of 30 days
        uint256 endTime = startTime + 365 days; // 1 year vesting period

        setupVestingSchedule(amount, unlockAmount, startTime, cliffTime, endTime);

        // Fast forward time to just after the cliff
        vm.warp(cliffTime + 1 seconds);

        // Withdraw and check the initial unlock amount
        vm.prank(beneficiary);
        vestingWallet.withdraw();

        // Check that the beneficiary received the correct initial unlock amount
        assertEq(token.balanceOf(beneficiary), unlockAmount, "Beneficiary did not receive the correct initial unlock amount");
    }

    /// @notice Tests that no tokens are withdrawable before the cliff period ends
    function test_VW_CliffPeriod() public {
        uint256 amount = 1e18;
        uint256 unlockAmount = 2e17;
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + 30 days;
        uint256 endTime = startTime + 365 days;

        setupVestingSchedule(amount, unlockAmount, startTime, cliffTime, endTime);

        // Attempt to withdraw before the cliff period ends
        vm.expectRevert("Vesting: still in cliff period");
        vm.prank(beneficiary);
        vestingWallet.withdraw();
    }

    /// @notice Tests the linear release of tokens after the cliff and before the end of the vesting period
    function test_VW_VestingRelease() public {
        uint256 amount = 1e18;
        uint256 unlockAmount = 2e17; // 20% initially unlocked
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + 30 days;
        uint256 endTime = startTime + 365 days;

        setupVestingSchedule(amount, unlockAmount, startTime, cliffTime, endTime);

        // Fast forward time to halfway through the vesting period (after the cliff)
        uint256 halfwayTime = cliffTime + ((endTime - cliffTime) / 2);
        vm.warp(halfwayTime);

        // Calculate expected amount: initial unlock + half of the remaining vesting amount
        uint256 expectedAmount = unlockAmount + ((amount - unlockAmount) / 2);
        vm.prank(beneficiary);
        vestingWallet.withdraw();

        // Check that the beneficiary received the expected amount halfway through the vesting period
        assertEq(token.balanceOf(beneficiary), expectedAmount, "Beneficiary did not receive the correct amount at halfway point");
    }

    //////////////////////////
    // Address Change Tests //
    //////////////////////////

    /// @notice Test that a beneficiary can successfully change their vesting schedule's associated address
    function test_VW_SuccessfulAddressChange() public {
        // Preparing the test environment
        registerSchedule(beneficiary);

        // Simulate the call from the beneficiary to change their vesting address
        vm.prank(beneficiary); vestingWallet.changeAddress(newBeneficiary);

        // Verify the vesting schedule has been successfully transferred to the new beneficiary
        assertTrue(vestingWallet.hasVestingSchedule(newBeneficiary), "New beneficiary should have a schedule");
        assertFalse(vestingWallet.hasVestingSchedule(beneficiary), "Old beneficiary should not have a schedule");
    }

    /// @notice Test that an unauthorized address cannot change a beneficiary's vesting schedule address
    /// @dev This test should fail if an address other than the beneficiary tries to change the vesting address
    function test_VW_Fail_UnauthorizedAddressChange() public {
        // Registering a vesting schedule for the beneficiary
        registerSchedule(beneficiary);

        // Attempting to change the vesting address without proper authorization
        vm.expectRevert();
        vestingWallet.changeAddress(newBeneficiary);
    }

    /// @notice Test that a vesting schedule cannot be transferred to an address that already has a vesting schedule
    /// @dev The contract should revert the transaction if the new address already has a vesting schedule
    function test_VW_Fail_ChangeToAddressWithSchedule() public {
        // Setting up two beneficiaries with vesting schedules
        registerSchedule(beneficiary);
        registerSchedule(newBeneficiary); // New beneficiary already has a vesting schedule

        // Simulate the beneficiary's attempt to transfer their schedule to an address that already has one
        vm.prank(beneficiary);
        vm.expectRevert();
        vestingWallet.changeAddress(newBeneficiary); // This should fail
    }

    function test_VW_RegisterVestingSchedule_Valid() public {
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + 30 days;
        uint256 endTime = startTime + 365 days;
        uint256 unlockAmount = 1e23; // 10% initially unlocked
        uint256 totalAmount = 1e24; // Total amount to be vested

        // Perform the registration
        vestingWallet.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);

        // Assertions to verify the schedule was registered correctly
        // Depending on your contract's storage design, verify the stored vesting schedule
        // Example:
        // (uint256 _startTime, , , , , ) = vestingWallet.schedules(address(1));
        // assertEq(_startTime, startTime, "Start time did not match");
    }


    function test_VW_RegisterVestingSchedule_InvalidTimes() public {
        uint256 startTime = block.timestamp + 365 days; // Start time is in the future
        uint256 cliffTime = startTime - 1 days; // Cliff time before start time, which is invalid
        uint256 endTime = startTime + 30 days;
        uint256 unlockAmount = 1e23;
        uint256 totalAmount = 1e24;

        // Expect a revert due to invalid timing
        vm.expectRevert("Vesting: cliff starts before vesting");
        vestingWallet.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);
    }


    function test_VW_RegisterVestingSchedule_ExceedMaxSupply() public {
        uint256 startTime = block.timestamp;
        uint256 cliffTime = startTime + 30 days;
        uint256 endTime = startTime + 365 days;
        uint256 unlockAmount = 1e24; // Set an unlock amount that exceeds max
        uint256 totalAmount = 2e24; // Total amount exceeding max supply

        // Expect a revert due to exceeding max supply
        vm.expectRevert("Vesting: exceeds max supply");
        vestingWallet.registerVestingSchedule(address(1), startTime, cliffTime, endTime, unlockAmount, totalAmount);
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


}

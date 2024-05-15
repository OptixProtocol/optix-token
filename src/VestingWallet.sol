// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StakingRewards} from "src/StakingRewards.sol";

/// @notice Struct defining a vesting schedule
/// @dev Contains all the parameters necessary for calculating vested amounts
struct VestingSchedule {
    uint startTimeInSec;
    uint cliffTimeInSec;
    uint endTimeInSec;
    uint unlockAmount;
    uint totalAmount;
    uint totalAmountWithdrawn;
}

interface IStaking {
    function stake(uint256 amount) external;
}

/// @title VestingWallet
/// @notice Manages the vesting of ERC20 tokens for beneficiaries with a customizable vesting schedule.
contract VestingWallet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    bool isInitialized;

    uint public maxSupply; // Maximum supply of tokens that can be vested
    uint public scheduledTokens; // Total tokens currently scheduled for vesting

    mapping(address => VestingSchedule) public schedules; // Vesting schedules for given addresses
    mapping(address => address) public addressChangeRequests; // Requested address changes

    IERC20 vestingToken;    // Token that will be vested
    IStaking stakingContract;

    /* ========== CONSTRUCTOR & INITIALIZATION ========== */

    /// @notice Creates a new VestingWallet contract instance
    constructor() Ownable(msg.sender) {
    }

    function initialize(address _vestingToken, address _stakingContract) public onlyOwner {
        require(!isInitialized, 'Contract is already initialized!');
        vestingToken = IERC20(_vestingToken);
        stakingContract = IStaking(_stakingContract);

        require(vestingToken.balanceOf(address(this)) > 0, 'Vesting wallet has no tokens!');
        maxSupply = vestingToken.balanceOf(address(this));

        registerTeamSchedules();
        registerFoundationSchedules();
        registerEcosystemRewardSchedules();
        registerPrivateSchedules();
        registerMarketingSchedules();

        isInitialized = true;
        emit Initialized(maxSupply);
    }

    /* ========== VIEWS ========== */
    
    /// @notice Checks if a given address has an active vesting schedule.
    /// @param _address The address to check for an active vesting schedule.
    /// @return bool Returns true if there is an active vesting schedule for the given address, false otherwise.
    function hasVestingSchedule(address _address) public view returns (bool) {
        return schedules[_address].totalAmount > 0;
    }

    function getVestingSchedule(address _address) public view returns (VestingSchedule memory) {
        return schedules[_address];
    }

    /// @notice Calculates the amount of tokens that can be withdrawn by a beneficiary
    /// @param schedule The vesting schedule to calculate for
    /// @return The amount of tokens that can be withdrawn
    function calculateWithdrawableAmount(VestingSchedule storage schedule) internal view returns (uint) {
        if (block.timestamp < schedule.cliffTimeInSec) {
            // Before the cliff, nothing is vested.
            return 0;
        } else if (block.timestamp >= schedule.endTimeInSec) {
            // After the end, everything is vested.
            return schedule.totalAmount - schedule.totalAmountWithdrawn;
        } else {
            // Calculate the linearly vested amount considering the time elapsed since the cliff.
            uint timeSinceCliff = block.timestamp - schedule.cliffTimeInSec;
            uint vestingDuration = schedule.endTimeInSec - schedule.cliffTimeInSec;
            uint linearVestingAmount = schedule.totalAmount * timeSinceCliff / vestingDuration;

            // Total vested amount includes the initial unlock plus linearly vested amount.
            uint totalVested = schedule.unlockAmount + linearVestingAmount;

            // Ensure not to exceed the total amount vested.
            if (totalVested > schedule.totalAmount) {
                totalVested = schedule.totalAmount;
            }

            // Calculate withdrawable amount.
            uint amountWithdrawable = totalVested - schedule.totalAmountWithdrawn;
            return amountWithdrawable;
        }
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @dev Registers a vesting schedule to an address.
    /// @param _addressToRegister The address that is allowed to withdraw vested tokens for this schedule.
    /// @param _startTimeInSec The time in seconds that vesting began.
    /// @param _cliffTimeInSec The time in seconds that tokens become withdrawable.
    /// @param _endTimeInSec The time in seconds that vesting ends.
    /// @param _unlockAmount The amount of tokens initially released 
    /// @param _totalAmount The total amount of tokens that the registered address can withdraw by the end of the vesting period.
    function registerVestingSchedule(
        address _addressToRegister,
        uint _startTimeInSec,
        uint _cliffTimeInSec,
        uint _endTimeInSec,
        uint _unlockAmount,
        uint _totalAmount
    )
        public
        onlyOwner
        pastMaxSupply(_totalAmount)
        validVestingScheduleTimes(_startTimeInSec, _cliffTimeInSec, _endTimeInSec)
        addressNotNull(_addressToRegister)
        nonReentrant 
    {
        require(!hasVestingSchedule(_addressToRegister),"Vesting: Address already has a vesting schedule");
        require(_unlockAmount <= _totalAmount, "Vesting: unlock amount exceeds total amount");
        scheduledTokens = scheduledTokens + _totalAmount;
        schedules[_addressToRegister] = VestingSchedule({
            startTimeInSec: _startTimeInSec,
            cliffTimeInSec: _cliffTimeInSec,
            endTimeInSec: _endTimeInSec,
            unlockAmount: _unlockAmount,
            totalAmount: _totalAmount,
            totalAmountWithdrawn: 0
        });

        emit VestingScheduleRegistered(
            _addressToRegister,
            _startTimeInSec,
            _cliffTimeInSec,
            _endTimeInSec,
            _unlockAmount,
            _totalAmount
        );
    }

    /// @notice Allows a beneficiary to withdraw vested tokens
    function withdraw()
        public
        pastStartTime(msg.sender)
        pastCliffTime(msg.sender)
        nonReentrant
        returns (uint amountWithdrawable) 
    {
        VestingSchedule storage schedule = schedules[msg.sender];
        amountWithdrawable = calculateWithdrawableAmount(schedule);
        schedule.totalAmountWithdrawn += amountWithdrawable;
        vestingToken.safeTransfer(msg.sender, amountWithdrawable);
        emit Withdrawal(msg.sender, amountWithdrawable);
    }

    /// @dev Changes the address that the vesting schedules is associated with.
    /// @param _newRegisteredAddress Desired address to update to.
    function changeAddress(address _newRegisteredAddress)
        external
        addressNotNull(_newRegisteredAddress)
        nonReentrant
    {
        require(hasVestingSchedule(msg.sender),"Caller has no vesting schedule");
        require(!hasVestingSchedule(_newRegisteredAddress),"New address already has a vesting schedule");

        VestingSchedule memory fromSchedule = schedules[msg.sender];
        schedules[_newRegisteredAddress] = fromSchedule;
        delete schedules[msg.sender];

        emit AddressChanged(msg.sender, _newRegisteredAddress);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function registerTeamSchedules() private {
        registerVestingSchedule(0x554c52D1327E8dCDD36BAB93029eEbF07f22B0C8, 1715950800, 1747054800, 1876654800, 0, 12000000000000000000000000);
        registerVestingSchedule(0xf17B56063b9F5364b8199138F317e1D2AF6E94fD, 1715950800, 1747054800, 1876654800, 0, 12000000000000000000000000);
        registerVestingSchedule(0xd4696710A435093a0e55DfF1D6167515D95D1d4A, 1715950800, 1747054800, 1876654800, 0, 4800000000000000000000000);
        registerVestingSchedule(0xCb0f935Ee725f357aDE08d591459fb03933c6471, 1715950800, 1747054800, 1876654800, 0, 4800000000000000000000000);
        registerVestingSchedule(0xEf75d2e11888b9E035DeD70cdEa3E0108757D0fF, 1715950800, 1747054800, 1876654800, 0, 48800000000000000000000000);
        registerVestingSchedule(0x9DB2A19EB6E2D1c87430F77c963fA0366b81135c, 1715950800, 1747054800, 1876654800, 0, 48800000000000000000000000);
        registerVestingSchedule(0x0255361A55D7CE636d33d983E311cd171dd56926, 1715950800, 1747054800, 1876654800, 0, 48800000000000000000000000);
    }
    function registerFoundationSchedules() private {
        registerVestingSchedule(0xEa065ca7cbF183b2C390156Fa569aD7728ba2d9e, 1715950800, 1718542800, 1804942800, 0, 120000000000000000000000000);
    }
    function registerEcosystemRewardSchedules() private {
        registerVestingSchedule(0x74Db12E988508f886478377EfE056eFde47Eacbf, 1715950800, 1718542800, 1848142800, 0, 606000000000000000000000000);
    }
    function registerPrivateSchedules() private {
        registerVestingSchedule(0xb2a76c4A18b2863C155a8E382eBD231ffED48101, 1715950800, 1715950800, 1748350800, 1875000000000000000000000, 37500000000000000000000000);
        registerVestingSchedule(0x199398D083e9cE6344c8Da5901FEE6dAbC7239Ae, 1715950800, 1715950800, 1748350800, 1562500000000000000000000, 31250000000000000000000000);
        registerVestingSchedule(0x8f43460EFaEe1204229412c1cAd1DaF91BFf1036, 1715950800, 1715950800, 1748350800, 906250000000000000000000, 18125000000000000000000000);
        registerVestingSchedule(0x291f44f73a953f7Df8EfAa3C66E00478f30218D3, 1715950800, 1715950800, 1748350800, 312500000000000000000000, 6250000000000000000000000);
        registerVestingSchedule(0x9f4f4aDf61159547C50442A4dc49Bd25eEa281fe, 1715950800, 1715950800, 1748350800, 12500000000000000000000, 250000000000000000000000);
        registerVestingSchedule(0x8862e5fe6E4fb048e922d1BE52618D85ab24CcD7, 1715950800, 1715950800, 1748350800, 268750000000000000000000, 5375000000000000000000000);
        registerVestingSchedule(0xbf05fA4cC9d40C8613CAcc5Ba307306e299C4BBc, 1715950800, 1715950800, 1748350800, 1250000000000000000000000, 25000000000000000000000000);
        registerVestingSchedule(0x1fa221e683d1D5296403DBF50E8E84920457aC8E, 1715950800, 1715950800, 1748350800, 937500000000000000000000, 18750000000000000000000000);
        registerVestingSchedule(0xB562478a9a95A29f95e08457e75cd24eFfA7215d, 1715950800, 1715950800, 1748350800, 312500000000000000000000, 6250000000000000000000000);
        registerVestingSchedule(0xAA49E638dBee6E74f8709062AD96207DF81040B7, 1715950800, 1715950800, 1748350800, 937500000000000000000000, 18750000000000000000000000);
        registerVestingSchedule(0xdB26A7823B8E0164e1a5ea1364a941EE89Bb8F3F, 1715950800, 1715950800, 1748350800, 625000000000000000000000, 12500000000000000000000000);
        registerVestingSchedule(0x35D2d03607b9155b42CF673102FE58251AC4F644, 1715950800, 1715950800, 1748350800, 312500000000000000000000, 6250000000000000000000000);
        registerVestingSchedule(0x600eB73Cb462DA9c19235dE1e9a27da827C9c80d, 1715950800, 1715950800, 1748350800, 312500000000000000000000, 6250000000000000000000000);
        registerVestingSchedule(0x9f5E06257acf18f02025E3273FDD80F97Ef7c7e7, 1715950800, 1715950800, 1748350800, 125000000000000000000000, 2500000000000000000000000);
        registerVestingSchedule(0x211bd8FFB70dbaC35497310C32B5c034517A1328, 1715950800, 1715950800, 1748350800, 156250000000000000000000, 3125000000000000000000000);
        registerVestingSchedule(0xD1434ee987C7DA8D44bDA125c3CDbf2ab6423D50, 1715950800, 1715950800, 1748350800, 156250000000000000000000, 3125000000000000000000000);
        registerVestingSchedule(0x7bB97AB045dd6BA0387ada21a0911068032Cc5a3, 1715950800, 1715950800, 1748350800, 93750000000000000000000, 1875000000000000000000000);
        registerVestingSchedule(0x376b7BbF5A2A90836a6f1f4B66dDd69079485050, 1715950800, 1715950800, 1748350800, 218750000000000000000000, 4375000000000000000000000);
        registerVestingSchedule(0x05c9B1012e8D9a3F84dCfBe5Fb5c2CE8191e3dee, 1715950800, 1715950800, 1748350800, 406250000000000000000000, 8125000000000000000000000);
        registerVestingSchedule(0xF331D3711fB0E86a0Bc44Eb6888e78F6E59baf57, 1715950800, 1715950800, 1748350800, 256250000000000000000000, 5125000000000000000000000);
        registerVestingSchedule(0xc8348F201Deff19AD5d0a87e8153d9d376faa8e2, 1715950800, 1715950800, 1748350800, 62500000000000000000000, 1250000000000000000000000);
    }
    function registerMarketingSchedules() private {
        registerVestingSchedule(0x5676C522B1fa65465c684F108B94FBc4132fED3b, 1715950800, 1715950800, 1739514436, 2400000000000000000000000, 24000000000000000000000000);
    }

    /* ========== MODIFIERS ========== */

    modifier pendingAddressChangeRequest(address target) {
        require(addressChangeRequests[target] != address(0),"addressChangeRequests[target] != address(0)");
        _;
    }

    /// @dev Ensures the caller is past the cliff time of their vesting schedule
    modifier pastStartTime(address target) {
        require(block.timestamp >= schedules[target].startTimeInSec, "Vesting: start time not reached");
        _;
    }

    /// @dev Ensures the caller is past the cliff time of their vesting schedule
    modifier pastCliffTime(address target) {
        require(block.timestamp >= schedules[target].cliffTimeInSec, "Vesting: still in cliff period");
        _;
    }

    /// @dev Validates that the provided times for a vesting schedule are logical
    /// @param startTimeInSec When the vesting starts
    /// @param cliffTimeInSec When the tokens begin to vest
    /// @param endTimeInSec When the vesting ends
    modifier validVestingScheduleTimes(uint startTimeInSec, uint cliffTimeInSec, uint endTimeInSec) {
        require(startTimeInSec > block.timestamp, "Vesting: start time has passed");
        require(cliffTimeInSec >= startTimeInSec, "Vesting: cliff starts before vesting");
        require(endTimeInSec >= cliffTimeInSec, "Vesting: end is before cliff");
        _;
    }

    modifier addressNotNull(address target) {
        require(target != address(0),"target != address(0)");
        _;
    }

    /// @dev Ensures the total scheduled tokens do not exceed the max supply
    /// @param totalAmount The total amount being added to the schedule
    modifier pastMaxSupply(uint totalAmount) {
        require(scheduledTokens + totalAmount <= maxSupply, "Vesting: exceeds max supply");
        _;
    }


    /* ========== EVENTS ========== */

    event Initialized (uint maxSupply);
    event VestingScheduleRegistered(
        address indexed registeredAddress,
        uint startTimeInSec,
        uint cliffTimeInSec,
        uint endTimeInSec,
        uint unlockAmount, 
        uint totalAmount
    );
    event Withdrawal(address indexed registeredAddress, uint amountWithdrawn);
    event AddressChanged(address indexed oldRegisteredAddress, address indexed newRegisteredAddress);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintERC20 {
   
     function mint(address to, uint256 amount) external;
} 


contract VestingWallet is Ownable {

    
    uint public maxSupply = 1200000000 ether; //max supply 1.2B
    uint public scheduledTokens = 0;

    mapping(address => VestingSchedule) public schedules;        // vesting schedules for given addresses
    mapping(address => address) public addressChangeRequests;    // requested address changes

    IMintERC20 vestingToken;

    event VestingScheduleRegistered(
        address indexed registeredAddress,
        uint startTimeInSec,
        uint cliffTimeInSec,
        uint endTimeInSec,
        uint unlockAmount, 
        uint totalAmount
    );
    event VestingScheduleConfirmed(
        address indexed registeredAddress,
        uint startTimeInSec,
        uint cliffTimeInSec,
        uint endTimeInSec,
        uint unlockAmount,
        uint totalAmount
    );
    event Withdrawal(address indexed registeredAddress, uint amountWithdrawn);
    // event VestingEndedByOwner(address indexed registeredAddress, uint amountWithdrawn, uint amountRefunded);
    // event AddressChangeRequested(address indexed oldRegisteredAddress, address indexed newRegisteredAddress);
    event AddressChangeConfirmed(address indexed oldRegisteredAddress, address indexed newRegisteredAddress);

    struct VestingSchedule {
        uint startTimeInSec;
        uint cliffTimeInSec;
        uint endTimeInSec;
        uint unlockAmount;
        uint totalAmount;
        uint totalAmountWithdrawn;
    }



    modifier pendingAddressChangeRequest(address target) {
        require(addressChangeRequests[target] != address(0),"addressChangeRequests[target] != address(0)");
        _;
    }

    modifier pastCliffTime(address target) {
        VestingSchedule storage vestingSchedule = schedules[target];
        require(blockTimestamp() > vestingSchedule.cliffTimeInSec,"blockTimestamp() > vestingSchedule.cliffTimeInSec");
        _;
    }

    modifier validVestingScheduleTimes(uint startTimeInSec, uint cliffTimeInSec, uint endTimeInSec) {
        require(cliffTimeInSec >= startTimeInSec,"cliffTimeInSec >= startTimeInSec");
        require(endTimeInSec >= cliffTimeInSec,"endTimeInSec >= cliffTimeInSec");
        _;
    }

    modifier addressNotNull(address target) {
        require(target != address(0),"target != address(0)");
        _;
    }

    modifier pastMaxSupply(uint totalAmount) {
        require(scheduledTokens+totalAmount <= maxSupply,"scheduledTokens+totalAmount <= maxSupply");
        _;
    }

    /// @dev Assigns a vesting token to the wallet.
    /// @param _vestingToken Token that will be vested, transfer ownership so only it can register.
    constructor (address _vestingToken) Ownable(msg.sender) {
        vestingToken = IMintERC20(_vestingToken);
        transferOwnership(address(vestingToken));
    }




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
    {
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


    /// @dev Allows a registered address to withdraw tokens that have already been vested.
    function withdraw()
        public
        pastCliffTime(msg.sender)
    {
        VestingSchedule storage vestingSchedule = schedules[msg.sender];

        uint totalAmountVested = getTotalAmountVested(vestingSchedule);
        uint amountWithdrawable = totalAmountVested - vestingSchedule.totalAmountWithdrawn;
        vestingSchedule.totalAmountWithdrawn = totalAmountVested;

        if (amountWithdrawable > 0) {
            // require(vestingToken.transfer(msg.sender, amountWithdrawable),"vestingToken.transfer(msg.sender, amountWithdrawable)");
            vestingToken.mint(msg.sender, amountWithdrawable);
            emit Withdrawal(msg.sender, amountWithdrawable);
        }
    }

   

    /// @dev Changes the address that the vesting schedules is associated with.
    /// @param _newRegisteredAddress Desired address to update to.
    function changeAddress(address _newRegisteredAddress)
        public
    {
        VestingSchedule memory vestingSchedule = schedules[msg.sender];
        require(vestingSchedule.totalAmount > 0,"vestingSchedule.totalAmount > 0");

        schedules[_newRegisteredAddress] = vestingSchedule;
        delete schedules[msg.sender];
        addressChangeRequests[msg.sender] = msg.sender;
        emit AddressChangeConfirmed(msg.sender, _newRegisteredAddress);
    }



    function getTotalAmountVested(address _address) public view
        returns (uint)
    {
        return getTotalAmountVested(schedules[_address]);
    }

    /// @dev Calculates the total tokens that have been vested for a vesting schedule, assuming the schedule is past the cliff.
    /// @param vestingSchedule Vesting schedule used to calculate vested tokens.
    /// @return Total tokens vested for a vesting schedule.
    function getTotalAmountVested(VestingSchedule memory vestingSchedule) view
        internal
        returns (uint)
    {
        if (blockTimestamp() >= vestingSchedule.endTimeInSec) return vestingSchedule.totalAmount;

        uint timeSinceCliffInSec = blockTimestamp() - vestingSchedule.cliffTimeInSec;
        uint totalVestingTimeInSec = vestingSchedule.endTimeInSec - vestingSchedule.cliffTimeInSec;
        uint totalAmountVested = (timeSinceCliffInSec * vestingSchedule.totalAmount)/totalVestingTimeInSec;
        if (totalAmountVested+vestingSchedule.unlockAmount > vestingSchedule.totalAmount)
            return vestingSchedule.totalAmount;
        else 
            return totalAmountVested + vestingSchedule.unlockAmount;
    }

    function blockTimestamp() public view returns (uint) {
        return block.timestamp;
    }

 
}
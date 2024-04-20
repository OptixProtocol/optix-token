// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Staking Rewards Contract
/// @notice This contract allows users to stake tokens and earn rewards based on the staking duration and amount.
contract StakingRewards is Ownable {
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint public rewardRate = 1.7e18;                        // Initial reward rate
    uint public lastUpdateTime;                             // Last time the reward calculation was updated
    uint public rewardPerTokenStored;                       // Stored reward per token

    mapping(address => uint) public userRewardPerTokenPaid; // Reward per token paid to each user
    mapping(address => uint) public rewards;                // Reward amounts for each user

    uint public totalSupply;                                // Total supply of staked tokens
    mapping(address => uint) public balances;               // Balances of staked tokens for each user

    //uint _blockTimestamp;

    event RewardRateUpdated(uint from, uint to);
    event Staked(address indexed user, uint256 amount);

    // event RewardAdded(uint256 reward);
    // event Withdrawn(address indexed user, uint256 amount);
    // event RewardPaid(address indexed user, uint256 reward);
    // event RewardsDurationUpdated(uint256 newDuration);
    // event Recovered(address token, uint256 amount);

    /// @param _stakingToken Address of the token being staked
    /// @param _rewardsToken Address of the token being rewarded
    constructor(address _stakingToken, address _rewardsToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    /// @notice Calculates the current reward per token
    /// @return The calculated reward per token
    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((blockTimestamp() - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    /// @notice Calculates the amount of rewards earned by an account
    /// @param account The account to calculate rewards for
    /// @return The amount of rewards earned
    function earned(address account) public view returns (uint) {
        return
            ((balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    /// @notice Updates the reward for an account upon staking, withdrawing, or claiming rewards
    /// @param account The account to update the reward for
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = blockTimestamp();

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    /// @notice Stakes a certain amount of tokens
    /// @param _amount The amount of tokens to stake
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Cannot stake 0");
        totalSupply += _amount;
        balances[msg.sender] += _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Withdraws staked tokens
    /// @param _amount The amount of tokens to withdraw
    function withdraw(uint _amount) external updateReward(msg.sender) {
        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    /// @notice Claims the earned rewards
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardsToken.transfer(msg.sender, reward);
    }

    /// @notice Sets a new reward rate
    /// @param _rewardRate The new reward rate to set
    function setRewardRate(uint256 _rewardRate) public onlyOwner{
        emit RewardRateUpdated(rewardRate, _rewardRate);
        rewardRate = _rewardRate;
    }

    /// @notice Gets the current block timestamp
    /// @return The current block timestamp
    function blockTimestamp() public view returns (uint) {
        return block.timestamp;
        // return _blockTimestamp;
    }

    // function setBlockTimestamp(uint256 _newBlockTimestamp) public {
    //     _blockTimestamp = _newBlockTimestamp;
    // }
    
}


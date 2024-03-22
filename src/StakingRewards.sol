// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is Ownable {
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint public rewardRate = 1.7e18; 
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    uint public totalSupply; 
    mapping(address => uint) public balances;

    //uint _blockTimestamp;

    event RewardRateUpdated(uint from, uint to);

    constructor(address _stakingToken, address _rewardsToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((blockTimestamp() - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    function earned(address account) public view returns (uint) {
        return
            ((balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = blockTimestamp();

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        totalSupply += _amount;
        balances[msg.sender] += _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardsToken.transfer(msg.sender, reward);
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner{
        emit RewardRateUpdated(rewardRate, _rewardRate);
        rewardRate = _rewardRate;
    }

    function blockTimestamp() public view returns (uint) {
        return block.timestamp;
        // return _blockTimestamp;
    }

    // function setBlockTimestamp(uint256 _newBlockTimestamp) public {
    //     _blockTimestamp = _newBlockTimestamp;
    // }
    
}


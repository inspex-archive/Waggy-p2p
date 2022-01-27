/*
#   __      __    _____     ________   ________ _____.___.
#  /  \    /  \  /  _  \   /  _____/  /  _____/ \__  |   |
#  \   \/\/   / /  /_\  \ /   \  ___ /   \  ___  /   |   |
#   \        / /    |    \\    \_\  \\    \_\  \ \____   |
#    \__/\  /  \____|__  / \______  / \______  / / ______|
#         \/           \/         \/         \/  \/       
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./../p2p/WaggyToken.sol";

contract MasterWaggy is Ownable {
  using SafeMath for uint256;

  // Info of each user.
  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
    uint256 bonusDebt;
    address fundedBy;
    uint256 depositTime;
  }

  // Info of each pool.
  struct PoolInfo {
    ERC20 rewardToken;
    address[] users;
    uint256 lastRewardBlock;
    uint256 totalDeposit;
    uint256 fund;
  }

  event ADD_POOL(address _rewardToken);
  event DEPOSIT(address _rewardToken, address _user, uint256 _amount);
  event WITHDRAW(address _rewardToken, address _user, uint256 _amount);
  event DIVIDEND(address _rewardToken, address _user, uint256 _amount);

  mapping(address => PoolInfo) pools;
  mapping(address => mapping(address => UserInfo)) public userInfo;

  WaggyToken waggyToken;
  address[] poolsTokens;

  constructor(address _waggyToken) {
    waggyToken = WaggyToken(_waggyToken);
  }

  function addPool(address _rewardToken) external onlyOwner {
    require(_rewardToken != address(0), "Not allow address(0)");
    require(address(pools[_rewardToken].rewardToken) == address(0), "Pool already exist");

    address[] memory users;
    pools[_rewardToken] = PoolInfo({
      rewardToken: ERC20(_rewardToken),
      lastRewardBlock: block.number,
      users: users,
      totalDeposit: 0,
      fund: 0
    });

    poolsTokens.push(_rewardToken);

    emit ADD_POOL(_rewardToken);
  }

  function getPoolInfo(address _poolToken)
    external
    view
    returns (
      uint256 lastRewardBlock,
      address[] memory users,
      uint256 totalDeposit,
      uint256 fund
    )
  {
    PoolInfo storage pool = pools[_poolToken];
    lastRewardBlock = pool.lastRewardBlock;
    users = pool.users;
    totalDeposit = pool.totalDeposit;
    fund = pool.fund;
  }

  function deposit(address _poolToken, uint256 _amount) external {
    require(waggyToken.balanceOf(msg.sender) >= _amount, "Balance not enougth");
    require(address(pools[_poolToken].rewardToken) != address(0), "Pool is not exist");

    PoolInfo storage pool = pools[_poolToken];
    UserInfo storage user = userInfo[msg.sender][_poolToken];

    if (user.amount > 0) harvest(msg.sender, _poolToken);

    waggyToken.transferFrom(msg.sender, address(this), _amount);
    user.depositTime = block.timestamp;
    user.amount = user.amount.add(_amount);

    if (user.fundedBy == address(0)) {
      user.fundedBy = msg.sender;
      pool.users.push(msg.sender);
    }

    console.log("user deposit amount ", user.amount);

    pool.totalDeposit = pool.totalDeposit.add(_amount);

    console.log("pool tvl ", pool.totalDeposit);

    emit DEPOSIT(_poolToken, msg.sender, _amount);
  }

  function withdraw(
    address _for,
    address _poolToken,
    uint256 _amount
  ) external {
    require(address(pools[_poolToken].rewardToken) != address(0), "Pool is not exist");
    PoolInfo storage pool = pools[_poolToken];
    UserInfo storage user = userInfo[_for][_poolToken];

    require(_amount <= user.amount, "Balance not enougth");
    if (user.amount > 0) harvest(_for, _poolToken);
    user.depositTime = block.timestamp;
    user.amount = user.amount.sub(_amount);
    pool.totalDeposit = pool.totalDeposit.sub(_amount);
    waggyToken.transferFrom(address(this), _for, _amount);

    emit WITHDRAW(_poolToken, msg.sender, _amount);
  }

  function getPendingReward(address _for, address _poolToken) public view returns (uint256) {
    UserInfo storage user = userInfo[_for][_poolToken];
    return user.rewardDebt;
  }

  function getUserStakeInfo(address _for, address _poolToken)
    public
    view
    returns (
      uint256 totalStaking,
      uint256 rewardDebt,
      uint256 depositTime
    )
  {
    UserInfo storage user = userInfo[_for][_poolToken];
    totalStaking = user.amount;
    rewardDebt = user.rewardDebt;
    depositTime = user.depositTime;
  }

  function distributeReward(address _poolToken, uint256 _amount) external {
    PoolInfo storage pool = pools[_poolToken];
    console.log("Amount", _amount);
    uint256 diff = pool.lastRewardBlock.sub(block.timestamp);

    for (uint256 i = 0; i < pool.users.length; i++) {
      UserInfo storage user = userInfo[pool.users[i]][_poolToken];
      console.log("Address", user.fundedBy);
      uint256 depositPercent = user.amount.mul(100).div(pool.totalDeposit);
      console.log("depositPercent", depositPercent);
      uint256 reward = _amount.mul(depositPercent).div(100);
      console.log("Reward", reward);

      uint256 userDepositTime = user.depositTime.sub(block.timestamp);
      if (userDepositTime >= diff) {
        // give 100% for user stake time more than lastReward block
        user.rewardDebt = user.rewardDebt.add(reward);
      } else {
        // give follow percent follow deposit time.
        uint256 percent = diff.sub(userDepositTime).mul(100).div(userDepositTime);
        uint256 rewardDebt = percent.mul(reward).div(100);
        user.rewardDebt = user.rewardDebt.add(rewardDebt);
      }

      user.depositTime = block.timestamp;
    }
  }

  function harvest(address _for, address _poolToken) public {
    PoolInfo storage pool = pools[_poolToken];
    UserInfo storage user = userInfo[_for][_poolToken];
    uint256 rewardDebt = getPendingReward(_for, _poolToken);
    pool.rewardToken.transfer(_for, rewardDebt);
    user.rewardDebt = 0;
  }

  function claimAll() external {
    for (uint256 i = 0; i < poolsTokens.length; i++) {
      harvest(msg.sender, poolsTokens[i]);
    }
  }

  function getTotalValueLock() external view returns (uint256) {
    uint256 total;
    for (uint256 i = 0; i < poolsTokens.length; i++) {
      total = total.add(pools[poolsTokens[i]].totalDeposit);
    }
    return total;
  }

  function dividend(address _poolToken, uint256 _amount) external onlyOwner {
    PoolInfo storage pool = pools[_poolToken];
    require(pool.rewardToken.balanceOf(msg.sender) >= _amount, "Balance not enougth");
    require(pool.rewardToken.allowance(msg.sender, address(this)) >= _amount);

    pool.rewardToken.transferFrom(msg.sender, address(this), _amount);
    pool.fund = pool.fund.add(_amount);

    emit DIVIDEND(_poolToken, msg.sender, _amount);
  }
}

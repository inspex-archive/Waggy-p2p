//SPDX-License-Identifier: Unlicense
/*
#   __      __    _____     ________   ________ _____.___.
#  /  \    /  \  /  _  \   /  _____/  /  _____/ \__  |   |
#  \   \/\/   / /  /_\  \ /   \  ___ /   \  ___  /   |   |
#   \        / /    |    \\    \_\  \\    \_\  \ \____   |
#    \__/\  /  \____|__  / \______  / \______  / / ______|
#         \/           \/         \/         \/  \/       
*/
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../p2p/WaggyToken.sol";

contract MasterChef is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
  }

  // Info of each pool.
  struct PoolInfo {
    ERC20 lpToken; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. CAKEs to distribute per block.
    uint256 lastRewardBlock; // Last block number that CAKEs distribution occurs.
    uint256 accWagPerShare; // Accumulated CAKEs per share, times 1e12. See below.
  }

  // The Wag TOKEN!
  WaggyToken public wag;
  // Dev address.
  address public devaddr;
  // WAG tokens created per block.
  uint256 public wagPerBlock;
  // Bonus muliplier for early cake makers.
  uint256 public BONUS_MULTIPLIER;
  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;
  // The block number when CAKE mining starts.
  uint256 public startBlock;

  uint256 public lockRewardPercent;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

  constructor(
    address _wag,
    address _devaddr,
    uint256 _wagPerBlock,
    uint256 _startBlock
  ) {
    BONUS_MULTIPLIER = 1;
    lockRewardPercent = 900; //90%
    wag = WaggyToken(_wag);
    devaddr = _devaddr;
    wagPerBlock = _wagPerBlock;
    startBlock = _startBlock;

    // staking pool
    poolInfo.push(PoolInfo({ lpToken: ERC20(_wag), allocPoint: 1000, lastRewardBlock: startBlock, accWagPerShare: 0 }));
    totalAllocPoint = 1000;
  }

  function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
    BONUS_MULTIPLIER = multiplierNumber;
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  function add(
    uint256 _allocPoint,
    ERC20 _lpToken,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({ lpToken: _lpToken, allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accWagPerShare: 0 })
    );
    updateStakingPool();
  }

  // Update the given pool's CAKE allocation point. Can only be called by the owner.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) public onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
    poolInfo[_pid].allocPoint = _allocPoint;
    if (prevAllocPoint != _allocPoint) {
      totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
      updateStakingPool();
    }
  }

  function updateStakingPool() internal {
    uint256 length = poolInfo.length;
    uint256 points = 0;
    for (uint256 pid = 1; pid < length; ++pid) {
      points = points.add(poolInfo[pid].allocPoint);
    }
    if (points != 0) {
      points = points.div(3);
      totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
      poolInfo[0].allocPoint = points;
    }
  }

  function setLockRewardPercent(uint256 _amount) external onlyOwner {
    require(_amount <= 1000, "not allow over 100%");
    lockRewardPercent = _amount;
  }

  // Return reward multiplier over the given _from to _to block.
  function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
    return _to.sub(_from).mul(BONUS_MULTIPLIER);
  }

  // View function to see pending Wags on frontend.
  function pendingWag(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accWagPerShare = pool.accWagPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (block.number > pool.lastRewardBlock && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
      uint256 wagReward = multiplier.mul(wagPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
      accWagPerShare = accWagPerShare.add(wagReward.mul(1e12).div(lpSupply));
    }
    return user.amount.mul(accWagPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.number <= pool.lastRewardBlock) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0) {
      pool.lastRewardBlock = block.number;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
    uint256 wagReward = multiplier.mul(wagPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
    wag.mint(devaddr, wagReward.div(10));
    wag.mint(address(this), wagReward);
    pool.accWagPerShare = pool.accWagPerShare.add(wagReward.mul(1e12).div(lpSupply));
    pool.lastRewardBlock = block.number;
  }

  // Deposit LP tokens to MasterChef for CAKE allocation.
  function deposit(uint256 _pid, uint256 _amount) public {
    require(_pid != 0, "deposit Wag by staking");
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        safeWagTransfer(msg.sender, pending);
      }
    }
    if (_amount > 0) {
      pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
      user.amount = user.amount.add(_amount);
    }

    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  function claimAll() public {
    for (uint256 index = 0; index < poolInfo.length; index++) {
      claim(index);
    }
  }

  function claim(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);
      safeWagTransfer(msg.sender, pending);
    }
  }

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) public {
    require(_pid != 0, "withdraw Wag by unstaking");
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");

    updatePool(_pid);
    uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      safeWagTransfer(msg.sender, pending);
    }
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      pool.lpToken.transfer(address(msg.sender), _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  // Stake Wag tokens to MasterChef
  function enterStaking(uint256 _amount) public {
    PoolInfo storage pool = poolInfo[0];
    UserInfo storage user = userInfo[0][msg.sender];
    updatePool(0);
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        safeWagTransfer(msg.sender, pending);
      }
    }
    if (_amount > 0) {
      pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
      user.amount = user.amount.add(_amount);
    }
    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);
    emit Deposit(msg.sender, 0, _amount);
  }

  // Withdraw Wag tokens from STAKING.
  function leaveStaking(uint256 _amount) public {
    PoolInfo storage pool = poolInfo[0];
    UserInfo storage user = userInfo[0][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");
    updatePool(0);
    uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      safeWagTransfer(msg.sender, pending);
    }
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      pool.lpToken.transfer(address(msg.sender), _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);

    emit Withdraw(msg.sender, 0, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    pool.lpToken.transfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  // Safe wag transfer function, just in case if rounding error causes pool to not have enough Wags.
  function safeWagTransfer(address _to, uint256 _amount) internal {
    wag.transfer(_to, _amount);
    // lock after claim rewad
    uint256 lockAmount = _amount.mul(lockRewardPercent).div(1000);
    wag.lock(_to, lockAmount);
  }

  // Update dev address by the previous dev.
  function dev(address _devaddr) public {
    require(msg.sender == devaddr, "dev: wut?");
    devaddr = _devaddr;
  }
}

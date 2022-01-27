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
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./../p2p/WaggyToken.sol";

// TODO Lock deposit time
contract WaggyStaking is OwnableUpgradeable {
  using SafeMath for uint256;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    bool inBlackList;
  }
  // Info of each pool.
  struct PoolInfo {
    ERC20 lpToken;
    uint256 supply; // Supply this token
    uint256 allocPoint; // How many allocation points assigned to this pool. Wags to distribute per block.
    uint256 lastRewardBlock; // Last block number that Wags distribution occurs.
    uint256 accWagPerShare; // Accumulated Wags per share, times 1e12. See below.
  }

  // adminAddress
  address public adminAddress;
  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation poitns. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;

  WaggyToken public waggyToken;

  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event Claim(address indexed user, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 amount);

  function initialize(
    ERC20 _lp,
    address _adminAddress,
    address _waggyToken
  ) public initializer {
    adminAddress = _adminAddress;
    waggyToken = WaggyToken(_waggyToken);
    __Ownable_init();
    // staking pool
    poolInfo.push(
      PoolInfo({ lpToken: _lp, supply: 0, allocPoint: 1000, lastRewardBlock: block.number, accWagPerShare: 0 })
    );
    totalAllocPoint = 1000;
  }

  modifier onlyAdmin() {
    require(msg.sender == adminAddress, "admin: wut?");
    _;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  function add(uint256 _allocPoint, ERC20 _lpToken) public onlyOwner {
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({
        lpToken: _lpToken,
        supply: 0,
        allocPoint: _allocPoint,
        lastRewardBlock: block.number,
        accWagPerShare: 0
      })
    );
  }

  function removeAllPool() public onlyOwner{
    delete poolInfo;
  } 

  // Update admin address by the previous dev.
  function setAdmin(address _adminAddress) public onlyOwner {
    adminAddress = _adminAddress;
  }

  // View function to see pending Reward on frontend.
  function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    return user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Refill reward in pool
  function refillPool(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    pool.lpToken.transferFrom(msg.sender, address(this), _amount);
    pool.accWagPerShare = pool.accWagPerShare.add(_amount.mul(1e12).div(pool.supply));
    pool.lastRewardBlock = block.number;
  }

  function claimAll() public {
    for (uint256 index = 0; index < poolInfo.length; index++) {
      claim(index);
    }
  }

  function claim(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    require(!user.inBlackList, "in black list");

    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);
        pool.lpToken.transfer(address(msg.sender), pending);
      }

      emit Claim(msg.sender, pending);
    }
  }

  // Stake tokens to SmartChef
  function deposit(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    require(!user.inBlackList, "in black list");
    // refillPool(_pid, 0);
    if (user.amount > 0) {
      uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        pool.lpToken.transfer(address(msg.sender), pending);
      }
    }
    if (_amount > 0) {
      pool.supply = pool.supply.add(_amount);
      waggyToken.transferFrom(msg.sender, address(this), _amount);
      user.amount = user.amount.add(_amount);
    }
    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);

    emit Deposit(msg.sender, _amount);
  }

  // Withdraw tokens from STAKING.
  function withdraw(uint256 _pid, uint256 _amount) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: not good");
    // refillPool(_pid, _amount);
    uint256 pending = user.amount.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0 && !user.inBlackList) {
      pool.lpToken.transfer(address(msg.sender), pending);
    }
    if (_amount > 0) {
      pool.supply = pool.supply.sub(_amount);
      user.amount = user.amount.sub(_amount);
      waggyToken.transfer(msg.sender, _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accWagPerShare).div(1e12);

    emit Withdraw(msg.sender, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) public {
    UserInfo storage user = userInfo[_pid][msg.sender];
    waggyToken.transfer(msg.sender, user.amount);
    emit EmergencyWithdraw(msg.sender, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }
}

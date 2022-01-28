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
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface WNFT {
  function getWeight() external returns (uint256);

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;
}

contract GasStation is OwnableUpgradeable, ERC721Holder {
  using SafeMath for uint256;

  // Info of each user.
  struct UserInfo {
    mapping(address => uint256) nftStake;
    uint256 weights;
    uint256 rewardDebt; // Reward debt. See explanation below.
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
  PoolInfo public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(address => UserInfo) public userInfo;
  // Total allocation poitns. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;

  event Stake(address indexed user, address nftAddress, uint256 tokenId, uint256 weight);
  event UnStake(address indexed user, address nftAddress, uint256 tokenId, uint256 weight);

  function initialize(ERC20 _bnb) public initializer {
    poolInfo = PoolInfo({
      lpToken: _bnb,
      supply: 0,
      allocPoint: 1000,
      lastRewardBlock: block.number,
      accWagPerShare: 0
    });

    totalAllocPoint = 1000;
  }

  modifier onlyAdmin() {
    require(msg.sender == adminAddress, "admin: wut?");
    _;
  }

  function claim() external {
    PoolInfo storage pool = poolInfo;
    UserInfo storage user = userInfo[msg.sender];
    // Claim reward before unstake
    uint256 pending = user.weights.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    require(pending > 0, "No reward");
    pool.lpToken.transfer(address(msg.sender), pending);
  }

  // Update admin address by the previous dev.
  function setAdmin(address _adminAddress) public onlyOwner {
    adminAddress = _adminAddress;
  }

  function pendingReward(address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo;
    UserInfo storage user = userInfo[_user];
    return user.weights.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Refill reward in pool
  function refillPool(uint256 _amount) public {
    PoolInfo storage pool = poolInfo;
    pool.lpToken.transferFrom(msg.sender, address(this), _amount);
    pool.accWagPerShare = pool.accWagPerShare.add(_amount.mul(1e12).div(pool.supply));
    pool.lastRewardBlock = block.number;
  }

  function stake(address _nftAddress, uint256 _tokenId) external {
    PoolInfo storage pool = poolInfo;
    UserInfo storage user = userInfo[msg.sender];
    // claim reward before new staking
    if (user.weights > 0) {
      uint256 pending = user.weights.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
      if (pending > 0) {
        pool.lpToken.transfer(address(msg.sender), pending);
      }
    }

    WNFT wnft = WNFT(_nftAddress);
    uint256 weight = wnft.getWeight();
    require(weight > 0, "can't stake");
    wnft.safeTransferFrom(msg.sender, address(this), _tokenId);

    if (weight > 0) {
      pool.supply = pool.supply.add(weight);
      user.nftStake[_nftAddress] = user.nftStake[_nftAddress].add(1);
      user.weights = user.weights.add(weight);
    }
    user.rewardDebt = user.weights.mul(pool.accWagPerShare).div(1e12);

    emit Stake(msg.sender, _nftAddress, _tokenId, weight);
  }

  function unStake(address _nftAddress, uint256 _tokenId) external {
    PoolInfo storage pool = poolInfo;
    UserInfo storage user = userInfo[msg.sender];
    require(user.nftStake[_nftAddress] > 0, "No NFT Stake");
    // Claim reward before unstake
    uint256 pending = user.weights.mul(pool.accWagPerShare).div(1e12).sub(user.rewardDebt);
    if (pending > 0) {
      pool.lpToken.transfer(address(msg.sender), pending);
    }

    WNFT wnft = WNFT(_nftAddress);
    uint256 weight = wnft.getWeight();
    user.nftStake[_nftAddress] = user.nftStake[_nftAddress].sub(1);
    user.weights = user.weights.sub(weight);
    wnft.safeTransferFrom(address(this), msg.sender, _tokenId);

    user.rewardDebt = user.weights.mul(pool.accWagPerShare).div(1e12);

    emit UnStake(msg.sender, _nftAddress, _tokenId, weight);
  }
}

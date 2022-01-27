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
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BlackListUser is Ownable,AccessControl{
  using SafeMath for uint256;

  bytes32 public constant ADMIN_ROLE = keccak256("MINTER_ROLE");

  enum STATUS {
    NORMAL,
    TEMPORARY,
    SUSPEND
  }

  uint256 private constant ALLOW_LIMIT_TEMPORARY = 2;
  uint256 private constant ALLOW_LIMIT_SUSPEND = 2;

  struct UserInfo {
    STATUS status;
    uint256 amount;
    uint256 totalWarning;
    uint256 lastWarning;
    uint256 suspendAt;
  }

  mapping(address => UserInfo) public userInfo;
  address[] public admins;

  constructor(){
     _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  // Status 0 normal, 1 temporary,2 suspend
  function setUserStatus(address _user, uint256 _status) external onlyOwner {
    userInfo[_user].status = STATUS(_status);
  }

  function revokeRoles(address[] memory _admins) public onlyOwner {
    for (uint256 i = 0; i < _admins.length; ++i) {
      revokeRole(ADMIN_ROLE, _admins[i]);
    }
  }

  function setAdmins(address[] memory _admins) external onlyOwner {
    revokeRoles(admins);
    delete admins;
    for (uint256 i = 0; i < _admins.length; ++i) {
      admins.push(_admins[i]);
      _setupRole(ADMIN_ROLE, _admins[i]);
    }
  }

  // set warning user count.
  function warningUser(address _user) external  {
    require(hasRole(ADMIN_ROLE, msg.sender), "DOES_NOT_HAVE_MINTER_ROLE");
    UserInfo storage user = userInfo[_user];
    require(user.status == STATUS.NORMAL, "Can't warning not normal status user.");

    uint256 diffTime = block.timestamp.sub(user.lastWarning).div(1 days);
    if (diffTime == 0) {
      user.amount = user.amount.add(1);
      if (user.amount >= ALLOW_LIMIT_TEMPORARY) {
        user.status = STATUS.TEMPORARY;
        user.amount = 0;
        user.totalWarning = user.totalWarning.add(1);
        user.lastWarning = block.timestamp;
        if (user.totalWarning >= ALLOW_LIMIT_SUSPEND) {
          user.status = STATUS.SUSPEND;
          user.suspendAt = block.timestamp;
        }
      }
    } else {
      user.amount = 1;
    }
  }

  function checkUserStatus(address _user) external returns(uint256) {
    UserInfo storage user = userInfo[_user];
    if (user.status == STATUS.SUSPEND || user.status == STATUS.NORMAL) {
      return uint256(user.status);
    }
    uint256 diffTime = block.timestamp.sub(user.lastWarning).div(1 days);
    if (diffTime > 0 && user.status == STATUS.TEMPORARY) {
      user.status = STATUS.NORMAL;
      user.amount = 0;
      return uint256(user.status);
    }
    return uint256(user.status);
  }

  function getUserStatus(address _user) external view returns (uint256) {
    return uint256(userInfo[_user].status);
  }
}

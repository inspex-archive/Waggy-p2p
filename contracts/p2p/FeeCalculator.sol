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

contract FeeCalculator is Ownable {
  using SafeMath for uint256;

  uint256 public payRate = 25; //0.25%

  function calculateFee(uint256 _amount) external pure returns (uint256) {
    if (_amount < 101000000000000000000) {
      return 0;
    } else if (_amount < 1001000000000000000000) {
      return _amount.mul(25).div(10000);
    } else if (_amount < 10001000000000000000000) {
      return _amount.mul(50).div(10000);
    } else if (_amount < 50001000000000000000000) {
      return _amount.mul(100).div(10000);
    } else {
      return _amount.mul(150).div(10000);
    }
  }

  function updateFeeRate(uint256 _rate) public onlyOwner {
    payRate = _rate;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWETH {
    function withdraw(uint256 _amount) external;
}

contract WNativeRelayer is Ownable, ReentrancyGuard {
  address public wnative;
  mapping(address => bool) okCallers;

  constructor(address _wnative) {
    wnative = _wnative;
  }

  modifier onlyWhitelistedCaller() {
    require(okCallers[msg.sender] == true, "WNativeRelayer::onlyWhitelistedCaller:: !okCaller");
    _;
  }

  function setCallerOk(address[] calldata whitelistedCallers, bool isOk) external onlyOwner {
    uint256 len = whitelistedCallers.length;
    for (uint256 idx = 0; idx < len; idx++) {
      okCallers[whitelistedCallers[idx]] = isOk;
    }
  }

  function withdraw(uint256 _amount) external onlyWhitelistedCaller nonReentrant {
    IWETH(wnative).withdraw(_amount);
    (bool success, ) = msg.sender.call{value: _amount}("");
    require(success, "WNativeRelayer::onlyWhitelistedCaller:: can't withdraw");
  }

  receive() external payable {}
}
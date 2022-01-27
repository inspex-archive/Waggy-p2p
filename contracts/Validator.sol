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
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IGOV {
  function mint(address _receive, uint256 _amount) external;
}

contract Validator is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using Strings for string;

  enum CaseStatus {
    START,
    INPROGRESS,
    SUMMARY,
    APPEAL,
    DONE
  }

  string internal constant BUYER = "BUYER";
  string internal constant SELLER = "SELLER";
  string internal constant EQUIVALENT = "EQUIVALENT";

  struct UserReplyAnswer {
    bytes32 answer;
    uint256 amount;
    string remark;
    uint256 createdAt;
    bool receiveReward;
  }

  struct CaseInfo {
    mapping(address => UserReplyAnswer) usersReplyAnswer;
    address[] users;
    mapping(address => bool) winners;
    address seller;
    address buyer;
    address token;
    uint256 currentValue;
    uint256 totalValue;
    uint256 fund;
    uint256 winnerAmount;
    string result;
    uint256 resultAt;
    bytes32 randomness;
    uint256 remark;
    CaseStatus status;
  }

  event UserDecision(address sender, string txKey, uint256 amount, bytes32 answer, string remark);
  event CaseVoteDone(string txKey);
  event CaseAppeal(string txKey, address appealAddress);
  event ChangeStatus(string txKey, string status);
  event CaseGenResult(address sender, string txKey, uint256 amount, bytes32 answer, string remark);
  event AddCase(string txKey, string txId, address seller, address buyer, uint256 amount);
  event ClaimReward(string txKey, address user, bool result);
  event EvaluateResult(string txKey, string result, uint256 buyerAmount, uint256 sellerAmount, uint256 updateAt);
  event DoneResult(string txKey, string result);

  ERC20 public erc20Interface;
  IGOV gov;

  mapping(string => CaseInfo) public casesInfo;
  mapping(address => bool) public adminRole;

  uint256 public totalCollateral;
  uint256 public maxPercentValue;
  uint256 public minPercentValue;
  uint256 public fee; //20%

  modifier onlyAdmin() {
    require(adminRole[msg.sender], "only admin");
    _;
  }

  modifier delay15mins(string memory _key) {
    CaseInfo storage caseInfo = casesInfo[_key];
    uint256 timeDiff = caseInfo.resultAt + 15 minutes;
    require(block.timestamp > timeDiff, "in delay.");
    _;
  }

  constructor(
    address _gov,
    uint256 _maxPercentValue,
    uint256 _minPercentValue,
    uint256 _fee
  ) {
    gov = IGOV(_gov);
    minPercentValue = _minPercentValue;
    maxPercentValue = _maxPercentValue;
    fee = _fee;
  }

  function setAdmin(address _admin, bool _isAdmin) public onlyOwner {
    adminRole[_admin] = _isAdmin;
  }

  function setMinPercent(uint256 _value) external onlyOwner {
    minPercentValue = _value;
  }

  function setMaxPercent(uint256 _value) external onlyOwner {
    maxPercentValue = _value;
  }

  function addCase(
    address _token,
    string memory _txId,
    address _seller,
    address _buyer,
    uint256 _remark,
    uint256 _amount
  ) public returns (string memory) {
    string memory txKey = Strings.toString(
      uint256(keccak256(abi.encodePacked("waggy", block.timestamp, _token, _seller, _buyer, _remark, _amount)))
    );

    console.log("Generate Key ", txKey);
    CaseInfo storage caseInfo = casesInfo[txKey];
    caseInfo.seller = _seller;
    caseInfo.buyer = _buyer;
    caseInfo.token = _token;
    caseInfo.remark = _remark;
    caseInfo.totalValue = _amount;
    caseInfo.status = CaseStatus.INPROGRESS;
    emit AddCase(txKey, _txId, _seller, _buyer, _amount);

    return txKey;
  }

  function getTotalCollateral() external view returns (uint256) {
    return totalCollateral;
  }

  function getUserDecision(string memory _key, address _userReply) external view returns (bool) {
    CaseInfo storage caseInfo = casesInfo[_key];
    return (caseInfo.usersReplyAnswer[_userReply].createdAt != 0);
  }

  function getUserResultInCase(string memory _key, address _userAddress)
    public
    view
    returns (bool _isWin, uint256 _betAmount)
  {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.status == CaseStatus.DONE, "Status is wrong");
    UserReplyAnswer memory userReplyAnswer = caseInfo.usersReplyAnswer[_userAddress];
    bytes32 correctAnswer = keccak256(abi.encodePacked(caseInfo.result, _key, addressToString(_userAddress)));

    _isWin = (userReplyAnswer.answer == correctAnswer);
    _betAmount = userReplyAnswer.amount;
  }

  function userClaimReward(string memory _key) public delay15mins(_key) {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.status == CaseStatus.DONE, "Status is wrong");
    UserReplyAnswer storage user = caseInfo.usersReplyAnswer[msg.sender];
    require(user.receiveReward, "you lose.");

    user.receiveReward = false;

    uint256 reward = user.amount;
    if (caseInfo.fund > 0) {
      reward = reward.add(caseInfo.fund.div(caseInfo.winnerAmount));
    }
    // distribute gov reward.
    uint256 govReward = reward.mul(25).div(10000);
    gov.mint(msg.sender, govReward);
    ERC20(caseInfo.token).safeTransfer(msg.sender, reward);

  }

  function userCanClaimReward(string memory _key,address _user) public view returns (bool) {
    CaseInfo storage caseInfo = casesInfo[_key];
    UserReplyAnswer storage user = caseInfo.usersReplyAnswer[_user];
    return user.receiveReward;
  }

  function addressToString(address _addr) internal pure returns (string memory) {
    bytes32 value = bytes32(uint256(uint160(_addr)));
    bytes memory alphabet = "0123456789abcdef";

    bytes memory str = new bytes(42);
    str[0] = "0";
    str[1] = "x";
    for (uint256 i = 0; i < 20; i++) {
      str[2 + i * 2] = alphabet[uint256(uint8(value[i + 12] >> 4))];
      str[3 + i * 2] = alphabet[uint256(uint8(value[i + 12] & 0x0f))];
    }
    return string(str);
  }

  function encode(string memory _key) public view returns (bytes32) {
    string memory userAddress = addressToString(msg.sender);
    string memory key = string(abi.encodePacked(BUYER, _key, userAddress));
    console.log("abi encode ", key);
    return keccak256(abi.encodePacked(key));
  }

  function decideByAdmin(string memory _key, string memory _result) public onlyAdmin {
    CaseInfo storage caseInfo = casesInfo[_key];
    caseInfo.result = _result;

    uint256 winnerAmount;
    uint256 fund;
    for (uint256 i = 0; i < caseInfo.users.length; i++) {
      address userAddress = caseInfo.users[i];
      UserReplyAnswer storage userReplyAnswer = caseInfo.usersReplyAnswer[userAddress];
      bytes32 correctAnswer = keccak256(abi.encodePacked(caseInfo.result, _key, addressToString(userAddress)));
      if (userReplyAnswer.answer != correctAnswer) {
        fund = fund.add(userReplyAnswer.amount);
      } else {
        userReplyAnswer.receiveReward = true;
        winnerAmount = winnerAmount.add(1);
      }
    }
    caseInfo.winnerAmount = winnerAmount;
    caseInfo.status = CaseStatus.DONE;
    caseInfo.fund = fund.sub(fund.mul(10).div(100));
    caseInfo.resultAt = block.timestamp;
    totalCollateral = totalCollateral.sub(caseInfo.currentValue);

    emit DoneResult(_key, caseInfo.result);
  }

  function appeal(string memory _key) external {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.status == CaseStatus.SUMMARY, "Status is wrong");
    require(msg.sender == caseInfo.seller || msg.sender == caseInfo.buyer, "Not allow external user.");
    caseInfo.status = CaseStatus.APPEAL;
    caseInfo.resultAt = block.timestamp;
    emit CaseAppeal(_key, msg.sender);
  }

  function setCaseStatusDone(string memory _key) public onlyAdmin {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.status == CaseStatus.SUMMARY, "Status is wrong");
    caseInfo.status = CaseStatus.DONE;
    emit ChangeStatus(_key, "DONE");
  }

  // System order to evaluate
  function evaluate(string memory _key)
    public
    onlyAdmin
    returns (
      string memory,
      uint256,
      uint256,
      uint256
    )
  {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.currentValue >= caseInfo.totalValue, "User vote not done.");
    require(caseInfo.users.length > 0, "Case not exist");
    require(caseInfo.resultAt == 0, "This case already had result.");
    uint256 buyyerValueCount;
    uint256 sellerValueCount;
    bytes32 buyerAnswer;
    for (uint256 i = 0; i < caseInfo.users.length; i++) {
      address userAddress = caseInfo.users[i];
      UserReplyAnswer memory userReplyAnswer = caseInfo.usersReplyAnswer[userAddress];
      buyerAnswer = keccak256(abi.encodePacked(BUYER, _key, addressToString(userAddress)));
      if (userReplyAnswer.answer == buyerAnswer) {
        buyyerValueCount = buyyerValueCount.add(userReplyAnswer.amount);
      } else {
        sellerValueCount = sellerValueCount.add(userReplyAnswer.amount);
      }
    }
    if (buyyerValueCount > sellerValueCount) {
      caseInfo.result = BUYER;
    } else if (buyyerValueCount < sellerValueCount) {
      caseInfo.result = SELLER;
    } else {
      caseInfo.result = EQUIVALENT;
    }

    uint256 winnerAmount;
    uint256 fund;
    for (uint256 i = 0; i < caseInfo.users.length; i++) {
      address userAddress = caseInfo.users[i];
      UserReplyAnswer storage userReplyAnswer = caseInfo.usersReplyAnswer[userAddress];
      bytes32 correctAnswer = keccak256(abi.encodePacked(caseInfo.result, _key, addressToString(userAddress)));
      if (userReplyAnswer.answer != correctAnswer) {
        fund = fund.add(userReplyAnswer.amount);
      } else {
        userReplyAnswer.receiveReward = true;
        winnerAmount = winnerAmount.add(1);
      }
    }
    caseInfo.winnerAmount = winnerAmount;
    caseInfo.status = CaseStatus.SUMMARY;
    caseInfo.fund = fund.sub(fund.mul(10).div(100));
    caseInfo.resultAt = block.timestamp;
    totalCollateral = totalCollateral.sub(caseInfo.currentValue);

    emit EvaluateResult(_key, caseInfo.result, buyyerValueCount, sellerValueCount, caseInfo.resultAt);

    return (caseInfo.result, buyyerValueCount, sellerValueCount, caseInfo.resultAt);
  }

  function play(
    string memory _key,
    uint256 _amount,
    bytes32 _answer,
    string memory _remark
  ) external {
    CaseInfo storage caseInfo = casesInfo[_key];
    require(caseInfo.status == CaseStatus.INPROGRESS, "Can't Vote");
    require(caseInfo.totalValue > caseInfo.currentValue, "The case is closed");
    UserReplyAnswer memory userReplyAnswer = caseInfo.usersReplyAnswer[msg.sender];
    require(userReplyAnswer.createdAt == 0, "Not allow user reply again");

    uint256 totalValue = caseInfo.totalValue;
    uint256 maxAmount = totalValue.mul(maxPercentValue).div(100);
    uint256 minAmount = totalValue.mul(minPercentValue).div(100);
    // check amount in range
    require(_amount <= maxAmount && _amount >= minAmount, "amount is not in range limit.");
    // transfer
    ERC20(caseInfo.token).safeTransferFrom(msg.sender, address(this), _amount);
    // add collateral
    totalCollateral = totalCollateral.add(_amount);
    // save reply
    userReplyAnswer.amount = _amount;
    userReplyAnswer.answer = _answer;
    userReplyAnswer.remark = _remark;
    userReplyAnswer.createdAt = block.timestamp;
    caseInfo.usersReplyAnswer[msg.sender] = userReplyAnswer;
    caseInfo.users.push(msg.sender);
    // update progress
    caseInfo.currentValue = caseInfo.currentValue.add(_amount);
    // emit event
    emit UserDecision(msg.sender, _key, _amount, _answer, _remark);

    if (caseInfo.currentValue >= caseInfo.totalValue) {
      emit CaseVoteDone(_key);
    }
  }
}

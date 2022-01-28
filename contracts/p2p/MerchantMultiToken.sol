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

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RewardCalculator.sol";
import "./FeeCalculator.sol";
import "./../BlackListUser.sol";
import "./WNativeRelayer.sol";

enum ValidatorRemark {
  NOT_TRANSFER,
  BUYER_APPEAL,
  SELLER_APPEAL,
  BUYER_CANCEL_TRANSACTION,
  SELLER_CANCEL_TRANSACTION
}

interface IValidator {
  function addCase(
    address _token,
    string memory _txId,
    address _seller,
    address _buyer,
    uint256 _remark,
    uint256 _amount
  ) external returns (string memory);
}

interface IWBNB {
  function deposit() external payable;

  function safeTransfer(address _receipt, uint256 amount) external;

  function withdraw(uint256 wad) external;
}

interface IGOV {
  function mint(address _receive, uint256 _amount) external;
}

// Not support deflationary token โทเคนที่มีการหัก%
contract MerchantMultiToken is OwnableUpgradeable, AccessControlUpgradeable {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for ERC20Upgradeable;

  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  event SetupShop(address seller, address token, uint256 amount);
  event Deposit(address seller, address token, uint256 amount);
  event Withdraw(address seller, address token, uint256 amount);
  event DeleteShop(address seller, address token, uint256 balance);
  event AppealTransaction(address seller, address buyer, uint256 balance);
  event ApproveTransaction(address seller, address token, uint256 amount);
  event CancelTransaction(address seller, address token, uint256 amount);
  event ReleaseToken(address seller, address buyer, address token, uint256 amount, uint256 reward);
  event SellerDeposit(address seller, address merchant, uint256 amount);
  event UnlockToken(address seller, address buyer, uint256 amount);

  enum TransactionStatus {
    INIT,
    PENDING_TRANSFER_FAIT,
    APPEAL,
    CANCELED,
    FINISH
  }
  struct Transaction {
    ERC20Upgradeable token;
    TransactionStatus status;
    uint256 amount;
    string remark;
    uint256 lockAmount;
    uint256 createdAt;
    uint256 updateAt;
    string appealTxId;
  }
  struct UserInfo {
    Transaction[] transactions;
  }
  struct SuccessTransactionInfo {
    uint256 totalSellAmount;
    uint256 totalSellCount;
  }

  mapping(address => mapping(address => uint256)) public shopBalance;
  mapping(address => mapping(address => uint256)) public shopLockBalance;
  mapping(address => SuccessTransactionInfo) public successTransactionCount;
  // merchant-> buyer-> lock amount
  mapping(address => mapping(address => uint256)) public lockTokenInfo;
  mapping(address => mapping(address => uint256)) public lockUserTokenInfo;
  mapping(address => mapping(address => uint256)) public totalLockBalance;
  mapping(address => mapping(address => UserInfo)) internal buyerInfo;

  RewardCalculator public rewardCalculator;
  FeeCalculator public feeCalculator;
  address public feeCollector;
  BlackListUser public blackListUser;
  IValidator public validator;

  address[] public admins;
  IGOV public gov;
  IWBNB public wbnb;
  WNativeRelayer public wnativeRelayer;

  // create merchant with token for p2p transaction
  function initialize(
    address _gov,
    address _rewardCalculator,
    address _feeCalculator,
    address _feeCollector,
    address _blackListUser
  ) public initializer {
    __Ownable_init();
    gov = IGOV(_gov);
    rewardCalculator = RewardCalculator(_rewardCalculator);
    feeCalculator = FeeCalculator(_feeCalculator);
    feeCollector = _feeCollector;
    blackListUser = BlackListUser(_blackListUser);

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function setValidator(address _validator) external onlyOwner {
    validator = IValidator(_validator);
  }

  function setAdmins(address[] memory _admins) external onlyOwner {
    revokeRoles(admins);
    delete admins;
    for (uint256 i = 0; i < _admins.length; ++i) {
      admins.push(_admins[i]);
      _setupRole(ADMIN_ROLE, _admins[i]);
    }
  }

  function setWNativeRelayer(WNativeRelayer _wnativeRelayer) public onlyOwner {
    wnativeRelayer = _wnativeRelayer;
  }

  function setWBNB(address _wbnb) external onlyOwner {
    wbnb = IWBNB(_wbnb);
  }

  function revokeRoles(address[] memory _admins) public onlyOwner {
    for (uint256 i = 0; i < _admins.length; ++i) {
      revokeRole(ADMIN_ROLE, _admins[i]);
    }
  }

  // Merchant increase balance.

  function depositNative() public payable notSuspendUser {
    // convert bnb to wbnb
    wbnb.deposit{ value: msg.value }();
    // update balance
    setShopBalance(address(wbnb), msg.sender, getShopBalance(msg.sender, address(wbnb)).add(msg.value));

    emit Deposit(msg.sender, address(wbnb), msg.value);
  }

  function deposit(ERC20Upgradeable _token, uint256 _amount) public notSuspendUser {
    require(_token.allowance(msg.sender, address(this)) >= _amount, "credit not enougth");
    _token.safeTransferFrom(msg.sender, address(this), _amount);
    setShopBalance(address(_token), msg.sender, getShopBalance(msg.sender, address(_token)).add(_amount));

    emit Deposit(msg.sender, address(_token), _amount);
  }

  // merchant decrease balance
  function withdrawNative(uint256 _amount) public notSuspendUser {
    uint256 ownerShopBalance = shopBalance[msg.sender][address(wbnb)];
    require(ownerShopBalance > 0 && ownerShopBalance >= _amount, "balance not enougth");
    setShopBalance(address(wbnb), msg.sender, getShopBalance(msg.sender, address(wbnb)).sub(_amount));
    // transfer wbnb to wnativeRelayer
    wbnb.safeTransfer(address(wnativeRelayer), _amount);
    // order withdraw
    wnativeRelayer.withdraw(_amount);
    // trasfer bnb to user
    (bool success, ) = msg.sender.call{ value: _amount }("");
    require(success, "WNativeRelayer::onlyWhitelistedCaller:: can't withdraw");
    emit Withdraw(msg.sender, address(wbnb), _amount);
  }

  function withdraw(ERC20Upgradeable _token, uint256 _amount) public notSuspendUser {
    uint256 ownerShopBalance = shopBalance[msg.sender][address(_token)];
    require(ownerShopBalance > 0 && ownerShopBalance >= _amount, "balance not enougth");
    setShopBalance(address(_token), msg.sender, getShopBalance(msg.sender, address(_token)).sub(_amount));
    _token.safeTransfer(msg.sender, _amount);

    emit Withdraw(msg.sender, address(_token), _amount);
  }

  /*
    Step 2
    When buyer is request to buy the token is had action to approve at seller
    The seller to call function approveTransaction for lock balance, it ready for wait to fait transfer.
    _amount is value of buyer want it.
    */
  function approveTransaction(
    ERC20Upgradeable _token,
    uint256 _amount,
    address _buyer
  ) public {
    require(getShopBalance(msg.sender, address(_token)) >= _amount, "Balance not enougth");
    // sub avalible shop balance
    setShopBalance(address(_token), msg.sender, getShopBalance(msg.sender, address(_token)).sub(_amount));

    UserInfo storage buyerInfoData = buyerInfo[msg.sender][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    Transaction storage transaction;
    // check last transaction is finish
    if (transactionLength != 0) {
      transaction = buyerInfoData.transactions[transactionLength.sub(1)];
      require(
        transaction.status == TransactionStatus.FINISH || transaction.status == TransactionStatus.CANCELED,
        "Transaction status mismatch"
      );
    }
    // create new transaction pending add push in transaction list
    buyerInfoData.transactions.push(
      Transaction(_token, TransactionStatus.PENDING_TRANSFER_FAIT, _amount, "", _amount, block.number, block.number, "")
    );
    // update total lock balance
    setTotalLockBalance(msg.sender, address(_token), getTotalLockBalance(msg.sender, address(_token)).add(_amount));
    emit ApproveTransaction(msg.sender, address(_token), _amount);
  }

  // for dev recheck balance is realy lock .
  function fetchTransactionApproved(address _seller, address _buyer) public view returns (uint256) {
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength > 0, "Transaction not exist");
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];
    require(transaction.status == TransactionStatus.PENDING_TRANSFER_FAIT, "Transaction status missmatch.");
    return transaction.lockAmount;
  }

  /*
    For admin or owner when the transaction had problem, it can cancel the transaction.
    _address is address of seller 
    _amount is value of transaction 
    */
  function cancelTransactionSeller(address _seller, string memory _remark) public {
    UserInfo storage buyerInfoData = buyerInfo[_seller][msg.sender];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    // get last transaction
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];
    require(transaction.status == TransactionStatus.PENDING_TRANSFER_FAIT, "Transaction status wrong");
    require(block.number - transaction.updateAt >= 15, "Requiered 15 block");
    transaction.remark = _remark;
    transaction.status = TransactionStatus.CANCELED;
    // warning user to cancel because only buyer can action cancel.

    blackListUser.warningUser(msg.sender);
    emit CancelTransaction(msg.sender, address(transaction.token), transaction.amount);
  }

  /* 
    Step 3
    For seller release token to buyer when the seller approve a evidence of faite transfer slip 
    _address is a receipt waller address
    _amount is value of token to transfer
    */
  function releaseTokenBySeller(address _buyer, ERC20Upgradeable _token) public {
    UserInfo storage buyerInfoData = buyerInfo[msg.sender][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];
    require(transaction.status == TransactionStatus.PENDING_TRANSFER_FAIT, "Transaction missmatch");
    transaction.lockAmount = 0;
    transaction.status = TransactionStatus.FINISH;
    transaction.updateAt = block.number;

    setTotalLockBalance(
      msg.sender,
      address(transaction.token),
      getTotalLockBalance(msg.sender, address(transaction.token)).sub(transaction.amount)
    );

    uint256 fee = feeCalculator.calculateFee(transaction.amount);
    uint256 receiverAmount = transaction.amount.sub(fee);
    _token.safeTransfer(feeCollector, fee);
    if (address(_token) == address(wbnb)) {
      _token.safeTransfer(address(wnativeRelayer), receiverAmount);
      wnativeRelayer.withdraw(receiverAmount);
      (bool success, ) = _buyer.call{ value: receiverAmount }("");
      require(success, "WNativeRelayer::onlyWhitelistedCaller:: can't withdraw");
    } else {
      _token.safeTransfer(_buyer, receiverAmount);
    }

    SuccessTransactionInfo storage successTransactionInfo = successTransactionCount[msg.sender];
    successTransactionInfo.totalSellAmount = successTransactionInfo.totalSellAmount.add(transaction.amount);
    successTransactionInfo.totalSellCount = successTransactionInfo.totalSellCount.add(1);

    // pay reward after complete transaction
    uint256 reward = transaction.amount.mul(700).div(10000);
    gov.mint(msg.sender, reward);
    reward = transaction.amount.mul(300).div(10000);
    gov.mint(_buyer, reward);

    emit ReleaseToken(msg.sender, _buyer, address(_token), transaction.amount, reward);
  }

  /* 
    Option admin manual release it not has reward and statistics
    For seller release token to buyer when the seller approve a evidence of faite transfer slip 
    _address is a receipt waller address
    _amount is value of token to transfer
    */
  function releaseTokenByAdmin(
    address _seller,
    address _buyer,
    ERC20Upgradeable _token
  ) external {
    require(hasRole(ADMIN_ROLE, msg.sender), "DOES_NOT_HAVE_ADMIN_ROLE");
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];

    transaction.lockAmount = 0;
    transaction.status = TransactionStatus.FINISH;
    transaction.updateAt = block.number;
    transaction.remark = "Release by admin";

    uint256 fee = feeCalculator.calculateFee(transaction.amount);
    uint256 receiverAmount = transaction.amount.sub(fee);

    _token.safeTransfer(feeCollector, fee);
    if (address(_token) == address(wbnb)) {
      _token.safeTransfer(address(wnativeRelayer), receiverAmount);
      wnativeRelayer.withdraw(receiverAmount);
      (bool success, ) = _buyer.call{ value: receiverAmount }("");
      require(success, "WNativeRelayer::onlyWhitelistedCaller:: can't withdraw");
    } else {
      _token.safeTransfer(_buyer, receiverAmount);
    }

    setTotalLockBalance(
      _seller,
      address(_token),
      getTotalLockBalance(_seller, address(_token)).sub(transaction.amount)
    );

    emit ReleaseToken(_seller, _buyer, address(_token), transaction.amount, 0);
  }

  function unlockTokenByAdmin(address _seller, address _buyer) external {
    require(hasRole(ADMIN_ROLE, msg.sender), "DOES_NOT_HAVE_ADMIN_ROLE");
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];

    transaction.status = TransactionStatus.FINISH;
    transaction.updateAt = block.number;
    transaction.remark = "unlockToken by admin";

    setTotalLockBalance(
      _seller,
      address(transaction.token),
      getTotalLockBalance(_seller, address(transaction.token)).sub(transaction.amount)
    );
    setShopBalance(
      address(transaction.token),
      _seller,
      getShopBalance(_seller, address(transaction.token)).add(transaction.amount)
    );

    emit UnlockToken(_seller, _buyer, transaction.amount);
  }

  /* 
    Option 
  Seller or buyer appeal this transaction
    _seller is a seller waller address
    _buyer is a buyer waller address
    _remark is value of 1 is buyer is appeal 2 is seller is appeal
    */
  function appeal(
    string memory _txId,
    address _seller,
    address _buyer,
    address _token,
    uint256 _remark
  ) external {
    require(msg.sender == _seller || msg.sender == _buyer, "Not allow other appeal.");
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    Transaction storage transaction = buyerInfoData.transactions[transactionLength.sub(1)];
    require(transaction.status != TransactionStatus.CANCELED, "Transaction is Cancelled.");
    transaction.status = TransactionStatus.APPEAL;
    transaction.updateAt = block.number;
    transaction.appealTxId = validator.addCase(_token, _txId, _seller, _buyer, _remark, transaction.amount);

    emit AppealTransaction(_seller, _buyer, transaction.amount);
  }

  function setTotalLockBalance(
    address _owner,
    address _token,
    uint256 _amount
  ) internal {
    totalLockBalance[_owner][_token] = _amount;
  }

  function getTotalLockBalance(address _owner, address _token) internal view returns (uint256) {
    return totalLockBalance[_owner][_token];
  }

  function getShopBalance(address _owner, address _token) internal view returns (uint256) {
    return shopBalance[_owner][_token];
  }

  function setShopBalance(
    address _token,
    address _owner,
    uint256 _balance
  ) internal {
    shopBalance[_owner][_token] = _balance;
  }

  function getShopLockBalance(address _owner, address _buyer) internal view returns (uint256) {
    return lockTokenInfo[_owner][_buyer];
  }

  function getUserLockBalance(address _owner, address _buyer) internal view returns (uint256) {
    return lockUserTokenInfo[_owner][_buyer];
  }

  function getTransactionByIndex(
    address _seller,
    address _buyer,
    uint256 _index
  )
    public
    view
    returns (
      uint256 status,
      uint256 amount,
      string memory remark,
      uint256 lockAmount,
      uint256 createdAt,
      uint256 updateAt
    )
  {
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    Transaction memory transaction = buyerInfoData.transactions[_index];

    status = uint256(transaction.status);
    amount = transaction.amount;
    remark = transaction.remark;
    lockAmount = transaction.lockAmount;
    createdAt = transaction.createdAt;
    updateAt = transaction.updateAt;
  }

  function getTransaction(address _seller, address _buyer)
    internal
    view
    returns (
      uint256 status,
      uint256 amount,
      string memory remark,
      uint256 lockAmount,
      uint256 createdAt,
      uint256 updateAt
    )
  {
    UserInfo storage buyerInfoData = buyerInfo[_seller][_buyer];
    uint256 transactionLength = buyerInfoData.transactions.length;
    require(transactionLength != 0, "Not found transaction");
    return getTransactionByIndex(_seller, _buyer, transactionLength.sub(1));
  }

  function setShopLockBalance(
    address _seller,
    address _buyer,
    uint256 _balance
  ) internal {
    lockTokenInfo[_seller][_buyer] = _balance;
  }

  function getTransactionSuccessCount(address _seller)
    internal
    view
    returns (uint256 totalSellAmount, uint256 totalSellCount)
  {
    totalSellAmount = successTransactionCount[_seller].totalSellAmount;
    totalSellCount = successTransactionCount[_seller].totalSellCount;
  }

  modifier notSuspendUser() {
    require(blackListUser.checkUserStatus(msg.sender) == 0, "Not allow suspend user.");
    _;
  }

  function setBlackList(address _blackList) external onlyOwner {
    blackListUser = BlackListUser(_blackList);
  }

  function getFeeCollector() public view returns (address) {
    return feeCollector;
  }

  // owner claimToken for emergency event.
  function ownerClaimToken(ERC20Upgradeable _token) public onlyOwner {
    _token.transfer(owner(), _token.balanceOf(address(this)));
  }

  // update RewardCalculator
  function updateRewardCalculator(address _rewardCalculator) public onlyOwner {
    rewardCalculator = RewardCalculator(_rewardCalculator);
  }

  // update RewardCalculator
  function updateFeeCalculator(address _feeCalculator) public onlyOwner {
    feeCalculator = FeeCalculator(_feeCalculator);
  }

  function getBuyerTransaction(address _seller, address _buyer)
    public
    view
    returns (
      uint256 status,
      uint256 amount,
      string memory remark,
      uint256 lockAmount,
      uint256 createdAt,
      uint256 updatedAt
    )
  {
    (status, amount, remark, lockAmount, createdAt, updatedAt) = getTransaction(_seller, _buyer);
  }

  receive() external payable {}

  fallback() external payable {}
}

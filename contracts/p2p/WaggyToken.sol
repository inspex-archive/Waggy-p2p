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
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract WaggyToken is ERC20Upgradeable, OwnableUpgradeable, AccessControlUpgradeable {
  using SafeMath for uint256;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant MASTER_CHEFT_ROLE_ROLE = keccak256("MASTER_CHEFT_ROLE_ROLE");

  modifier onlyGovernor() {
    require(_msgSender() == governor, "WAG::onlyGovernor::not governor");
    _;
  }

  /// @dev events
  event Lock(address indexed to, uint256 value);
  event CapChanged(uint256 prevCap, uint256 newCap);
  event GovernorChanged(address prevGovernor, address newGovernor);

  /// @dev private state variables
  uint256 private _totalLock;
  mapping(address => uint256) private _locks;
  mapping(address => uint256) private _lastUnlockBlock;

  uint256 public cap;
  address public governor;

  /// @dev public immutable state variables
  uint256 public startReleaseBlock;
  uint256 public endReleaseBlock;

  address[] public minters;
  address public masterCheftRole;

  function initialize(
    address _governor,
    uint256 _startReleaseBlock,
    uint256 _endReleaseBlock
  ) public initializer {
    __ERC20_init("Waggy Token", "WAG");
    __Ownable_init();
    __AccessControl_init();
    require(_endReleaseBlock > _startReleaseBlock, "WAG::constructor::endReleaseBlock < startReleaseBlock");
    cap = 240000000000000000000000000;
    governor = _governor;
    startReleaseBlock = _startReleaseBlock;
    endReleaseBlock = _endReleaseBlock;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @dev Set endReleaseBlock
  /// @param _endReleaseBlock The new endReleaseBlock
  function setEndReleaseBlock(uint256 _endReleaseBlock) external onlyOwner {
    endReleaseBlock = _endReleaseBlock;
  }

  /// @dev Set cap. Cap must lower than previous cap. Only Governor can adjust
  /// @param _cap The new cap
  function setCap(uint256 _cap) external onlyGovernor {
    uint256 prevCap = cap;
    cap = _cap;
    emit CapChanged(prevCap, cap);
  }

  /// @dev Set a new governor
  /// @param _governor The new governor
  function setGovernor(address _governor) external onlyGovernor {
    require(governor != _governor, "WAG::setGovernor::no self set");
    address prevGov = governor;
    governor = _governor;
    emit GovernorChanged(prevGov, governor);
  }

  function setMinter(address[] memory _minters) external onlyOwner {
    revokeRoles(minters);
    delete minters;
    for (uint256 i = 0; i < _minters.length; ++i) {
      minters.push(_minters[i]);
      _setupRole(MINTER_ROLE, _minters[i]);
    }
  }

  function setMasterCheft(address _masterCheft) external onlyOwner {
    revokeRole(MASTER_CHEFT_ROLE_ROLE, masterCheftRole);
    masterCheftRole = _masterCheft;
    _setupRole(MASTER_CHEFT_ROLE_ROLE, _masterCheft);
  }

  function revokeRoles(address[] memory _minters) public onlyOwner {
    for (uint256 i = 0; i < _minters.length; ++i) {
      revokeRole(MINTER_ROLE, _minters[i]);
    }
  }

  function mint(address _receiver, uint256 _amount) external {
    // Only minters can mint
    require(
      hasRole(MINTER_ROLE, msg.sender) || hasRole(MASTER_CHEFT_ROLE_ROLE, msg.sender),
      "DOES_NOT_HAVE_MINTER_ROLE"
    );
    require(totalSupply().add(_amount) < cap, "WAG::mint::cap exceeded");
    _mint(_receiver, _amount);
  }

  /// @dev A generic transfer function with moveDelegates
  /// @param _recipient The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transfer(address _recipient, uint256 _amount) public virtual override returns (bool) {
    _transfer(_msgSender(), _recipient, _amount);
    return true;
  }

  /// @dev A generic transferFrom function with moveDelegates
  /// @param _sender The address of the account that will be debited
  /// @param _recipient The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transferFrom(
    address _sender,
    address _recipient,
    uint256 _amount
  ) public virtual override returns (bool) {
    _transfer(_sender, _recipient, _amount);
    _approve(
      _sender,
      _msgSender(),
      allowance(_sender, _msgSender()).sub(_amount, "WAG::transferFrom::transfer amount exceeds allowance")
    );
    return true;
  }

  /// @dev Return the total balance (locked + unlocked) of a given account
  /// @param _account The address that you want to know the total balance
  function totalBalanceOf(address _account) external view returns (uint256) {
    return _locks[_account].add(balanceOf(_account));
  }

  // Lock section

  /// @dev Return unlocked WAG
  function unlockedSupply() external view returns (uint256) {
    return totalSupply().sub(totalLock());
  }

  /// @dev Return totalLocked WAG
  function totalLock() public view returns (uint256) {
    return _totalLock;
  }

  /// @dev Return the locked WAG of a given account
  /// @param _account The address that you want to know the locked WAG
  function lockOf(address _account) external view returns (uint256) {
    return _locks[_account];
  }

  /// @dev Return unlock for a given account
  /// @param _account The address that you want to know the last unlock block
  function lastUnlockBlock(address _account) external view returns (uint256) {
    return _lastUnlockBlock[_account];
  }

  /// @dev Lock WAG based-on the command from MasterChef
  /// @param _account The address that will own this locked amount
  /// @param _amount The locked amount
  function lock(address _account, uint256 _amount) external {
    require(hasRole(MASTER_CHEFT_ROLE_ROLE, msg.sender), "DOES_NOT_HAVE_MASTER_CHEFT_ROLE");
    require(_account != address(this), "WAG::lock::no lock to token address");
    require(_account != address(0), "WAG::lock::no lock to address(0)");
    require(_amount <= balanceOf(_account), "WAG::lock::no lock over balance");

    _transfer(_account, address(this), _amount);

    _locks[_account] = _locks[_account].add(_amount);
    _totalLock = _totalLock.add(_amount);

    if (_lastUnlockBlock[_account] < startReleaseBlock) {
      _lastUnlockBlock[_account] = startReleaseBlock;
    }

    emit Lock(_account, _amount);
  }

  /// @dev Return how many WAG is unlocked for a given account
  /// @param _account The address that want to check canUnlockAmount
  function canUnlockAmount(address _account) public view returns (uint256) {
    // When block number less than startReleaseBlock, no WAG can be unlocked
    if (block.number < startReleaseBlock) {
      return 0;
    }
    // When block number more than endReleaseBlock, all locked WAG can be unlocked
    else if (block.number >= endReleaseBlock) {
      return _locks[_account];
    }
    // When block number is more than startReleaseBlock but less than endReleaseBlock,
    // some WAG can be released
    else {
      uint256 releasedBlock = block.number.sub(_lastUnlockBlock[_account]);
      uint256 blockLeft = endReleaseBlock.sub(_lastUnlockBlock[_account]);
      return _locks[_account].mul(releasedBlock).div(blockLeft);
    }
  }

  /// @dev Claim unlocked WAG after the release schedule is reached
  function unlock() external {
    require(_locks[msg.sender] > 0, "WAG::unlock::no locked WAG");

    uint256 amount = canUnlockAmount(msg.sender);

    _transfer(address(this), msg.sender, amount);
    _locks[msg.sender] = _locks[msg.sender].sub(amount);
    _lastUnlockBlock[msg.sender] = block.number;
    _totalLock = _totalLock.sub(amount);
  }
}

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

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AvatarNFT is Ownable, ERC721URIStorage {
  using SafeMath for uint256;
  using Counters for Counters.Counter;
  using Strings for uint256;

  event Mint(address, uint256);

  Counters.Counter private _tokenIds;
  string public baseURI;
  uint256 private nftPrice;
  mapping(address => uint256) public userOwnerTokenId;

  constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

  function setPrice(uint256 _price) external onlyOwner {
    nftPrice = _price;
  }

  // Mint all NFT on deploy and keep data for treading
  function mint(address _receiver) public payable {
    require(msg.value == nftPrice, "Price missmatch");
    require(userOwnerTokenId[msg.sender] == 0, "Maximun to mint");
    uint256 newItemId = _tokenIds.current();
    _mint(_receiver, newItemId);
    _tokenIds.increment();

    userOwnerTokenId[msg.sender] = newItemId;

    emit Mint(msg.sender, newItemId);
  }

  function claim() external onlyOwner{
    (bool sent,) = payable(owner()).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
  }

  function getWeight() external pure returns (uint256) {
    return 10;
  }

  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    require(_exists(_tokenId), "URI query for nonexistent token");
    return string(abi.encodePacked(baseURI, _tokenId.toString(), ".json"));
  }

  function setBaseURI(string memory _uri) external onlyOwner {
    baseURI = _uri;
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public virtual override {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
}

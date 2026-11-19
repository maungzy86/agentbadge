// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AgentBadge — a free collectible badge exclusively for Agent ID holders.
/// @notice Minting is gated by Agent ID ownership (access control): the caller must
///         hold an Agent ID (the on-chain name of a Binance Agentic Wallet, name.ai)
///         in the official SPACE ID Agent ID contract on BNB Chain.
///         One badge per wallet. Free to mint — the minter only pays network gas.
///         This contract holds no user funds and has no sale/royalty mechanics.
///
/// Owner permissions (fully disclosed, per hackathon safety rules):
///   - setBaseURI(string): set the metadata base URI. This is the ONLY owner power.
///   - There is no mint-by-owner, no pause, no transfer of user assets, no proxy,
///     no upgrade path, and no way for the owner to move badges or funds.
///
/// @dev Self-contained ERC-721 (no external dependencies) to keep the verified
///      source small and auditable.

interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentBadge {
    // ----- ERC-721 metadata -----
    string public constant name = "AgentBadge";
    string public constant symbol = "ABDG";

    // ----- Agent ID gate -----
    /// @notice Official Agent ID contract (SPACE ID Agent ID, ERC-721, non-transferable), BNB Chain.
    IAgentID public constant AGENT_ID =
        IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    uint256 public constant MAX_SUPPLY = 3333;

    // ----- State -----
    address public owner;
    string public baseURI;
    uint256 public totalMinted;
    mapping(address => bool) public hasMinted;

    // ----- Rarity system -----
    // Every badge rolls a rarity tier at mint time (pseudo-random, fully
    // transparent in this verified source):
    //   roll < 1   -> 4 MYTHIC    (1%)
    //   roll < 5   -> 3 LEGENDARY (4%)
    //   roll < 15  -> 2 EPIC      (10%)
    //   roll < 40  -> 1 RARE      (25%)
    //   else       -> 0 COMMON    (60%)
    mapping(uint256 => uint8) public rarityTier;
    mapping(address => uint256) public tokenIdOf;
    mapping(uint8 => uint256) public tierMinted;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // ----- Events (ERC-721 standard + mint log) -----
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner_, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner_, address indexed operator, bool approved);
    event Minted(address indexed minter, uint256 indexed tokenId, uint8 rarityTier);
    event BaseURIUpdated(string newBaseURI);

    constructor(string memory baseURI_) {
        owner = msg.sender;
        baseURI = baseURI_;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @notice The only owner power: update the metadata base URI.
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    // ----- The mint -----
    /// @notice Free mint for Agent ID holders. One badge per wallet, ever.
    function mint() external returns (uint256 tokenId) {
        require(AGENT_ID.balanceOf(msg.sender) > 0, "Agent ID required");
        require(!hasMinted[msg.sender], "already minted");
        require(totalMinted < MAX_SUPPLY, "sold out");

        tokenId = ++totalMinted;
        hasMinted[msg.sender] = true;
        tokenIdOf[msg.sender] = tokenId;
        _owners[tokenId] = msg.sender;
        _balances[msg.sender] += 1;

        uint8 tier = _rollRarity(msg.sender, tokenId);
        rarityTier[tokenId] = tier;
        tierMinted[tier] += 1;

        emit Transfer(address(0), msg.sender, tokenId);
        emit Minted(msg.sender, tokenId, tier);
    }

    /// @notice Pseudo-random rarity roll, seeded by block prevrandao + minter + tokenId.
    function _rollRarity(address minter, uint256 tokenId) internal view returns (uint8) {
        uint256 roll = uint256(keccak256(abi.encodePacked(block.prevrandao, minter, tokenId))) % 100;
        if (roll < 1) return 4;  // MYTHIC 1%
        if (roll < 5) return 3;  // LEGENDARY 4%
        if (roll < 15) return 2; // EPIC 10%
        if (roll < 40) return 1; // RARE 25%
        return 0;                // COMMON 60%
    }

    /// @notice Human-readable rarity name for a badge.
    function rarityName(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "nonexistent token");
        uint8 t = rarityTier[tokenId];
        if (t == 4) return "MYTHIC";
        if (t == 3) return "LEGENDARY";
        if (t == 2) return "EPIC";
        if (t == 1) return "RARE";
        return "COMMON";
    }

    /// @notice How many distinct Agent ID holder addresses have interacted by minting.
    function uniqueHolders() external view returns (uint256) {
        return totalMinted; // one badge per wallet, so minted count == holder count
    }

    // ----- ERC-721 views -----
    function balanceOf(address owner_) external view returns (uint256) {
        require(owner_ != address(0), "zero address");
        return _balances[owner_];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "nonexistent token");
        return o;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_owners[tokenId] != address(0), "nonexistent token");
        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner_, address operator) external view returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f;   // ERC721Metadata
    }

    // ----- ERC-721 transfers -----
    function approve(address to, uint256 tokenId) external {
        address o = _owners[tokenId];
        require(o != address(0), "nonexistent token");
        require(msg.sender == o || _operatorApprovals[o][msg.sender], "not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(o, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not authorized");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        require(!_isContract(to) || _checkOnERC721Received(from, to, tokenId, ""), "unsafe recipient");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        transferFrom(from, to, tokenId);
        require(!_isContract(to) || _checkOnERC721Received(from, to, tokenId, data), "unsafe recipient");
    }

    // ----- Internals -----
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address o = _owners[tokenId];
        return spender == o || _tokenApprovals[tokenId] == spender || _operatorApprovals[o][spender];
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(_owners[tokenId] == from, "wrong owner");
        require(to != address(0), "zero address");
        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data)
        internal
        returns (bool)
    {
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

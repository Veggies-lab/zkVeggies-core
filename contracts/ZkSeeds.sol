//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

/* ---------------------------- Internal imports ---------------------------- */
import {Strings} from "./Strings.sol";

/* ----------------------------- Solmate imports ---------------------------- */
import {ERC721} from "solmate/src/tokens/ERC721.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

contract ZkSeeds is ERC721, Owned {
    /* -------------------------------------------------------------------------- */
    /*                                  VARIABLES                                 */
    /* -------------------------------------------------------------------------- */

    /* -------------------------------- ZkVeggies ------------------------------- */
    address private zkVeggies;

    /* ------------------------------- Token infos ------------------------------ */
    uint256 public tokenId;
    string public baseUri;
    string public contractURI;

    /* ------------------------------- Sale state ------------------------------- */
    bool public mintStarted;
    bool public wlMintStarted;

    /* -------------------------------- Whitelist ------------------------------- */
    mapping(address => uint256) public whitelisted;

    /* -------------------------------- Royalties ------------------------------- */
    uint256 public royaltyPercentage = 1000; // 10% with 2 decimals

    /* ------------------------------- Mint limits ------------------------------ */
    uint256 public maxMintPerAccount;

    /* -------------------------------------------------------------------------- */
    /*                                  CONSTANTS                                 */
    /* -------------------------------------------------------------------------- */
    uint256 public constant MAX_SUPPLY = 6000;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */
    error NotMinted(uint256 id);
    error NotAllowedToBurn(uint256 id, address account);
    error MaxSupplyExceeded();
    error MaxMintAmountExceeded();
    error MintNotStarted();
    error WhitelistMintNotStarted();
    error AccountNotWhitlisted();
    error InvalidAmountLength();

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        string memory _contractURI,
        uint256 _maxMintPerAccount
    ) ERC721(_name, _symbol) Owned(msg.sender) {
        baseUri = _baseUri;
        contractURI = _contractURI;
        maxMintPerAccount = _maxMintPerAccount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 MINT LOGICS                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Mint some NFTs to a specific account
    /// @param amount the amount of NFT to mint
    /// @param to the NFT recevier address
    function mint(uint256 amount, address to) external {
        checkMintValidity(amount, to);

        for (uint256 i; i < amount;) {
            _mint(to, tokenId);
            unchecked {
                ++tokenId;
                ++i;
            }
        }
    }

    /// @notice Mint some NFTs to the message sender
    /// @param amount the amount of NFT to mint
    function mint(uint256 amount) external {
        checkMintValidity(amount, msg.sender);

        for (uint256 i; i < amount;) {
            _mint(msg.sender, tokenId);
            unchecked {
                ++tokenId;
                ++i;
            }
        }
    }

    /// @notice Mint a NFT to a specific account and check if the account is an
    ///         ERC721 receiver.
    /// @param to the NFT recevier address
    function safeMint(address to) external {
        checkMintValidity(1, to);

        _safeMint(to, tokenId);
        unchecked {
            ++tokenId;
        }
    }

    /// @notice Mint a NFT to the message sender and check if the sender is an
    ///         ERC721 receiver.
    function safeMint() external {
        checkMintValidity(1, msg.sender);

        _safeMint(msg.sender, tokenId);
        unchecked {
            ++tokenId;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              WHITELIST LOGICS                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Mint some NFTs to the message sender during the presale
    /// @param amount the amount of NFT to mint
    function whitelistMint(uint256 amount) external {
        if (!wlMintStarted) revert WhitelistMintNotStarted();
        if (tokenId + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        if (whitelisted[msg.sender] == 0) revert AccountNotWhitlisted();
        if (_balanceOf[msg.sender] + amount > whitelisted[msg.sender])
            revert MaxMintAmountExceeded();

        for (uint256 i; i < amount; ) {
            _mint(msg.sender, tokenId);
            unchecked {
                ++tokenId;
                ++i;
            }
        }
    }

    /// @notice Set the number of allowed presale mint for an account
    /// @param account The account to whitelist
    /// @param amount The number of mint allowed for the account
    function whitelist(address account, uint256 amount) public onlyOwner {
        whitelisted[account] = amount;
    }

    /// @notice Set the number of allowed presale mint for an account
    /// @param accounts The accounts to whitelist
    /// @param amounts The number of mint allowed for the accounts
    function whitelist(
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external onlyOwner {
        uint256 accountLength = accounts.length;

        if (accountLength != amounts.length) revert InvalidAmountLength();

        for (uint256 i; i < accountLength; ) {
            whitelist(accounts[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 BURN LOGICS                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Burn a NFT
    /// @dev The zkVeggies contract can burn any seed, to to avoid having to approve to plant seeds.
    /// @param id The NFT id
    function burn(uint256 id) external {
        if(ownerOf(id) != msg.sender && msg.sender != address(zkVeggies)) revert NotAllowedToBurn(id, msg.sender);
        _burn(id);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  TOKEN URI                                 */
    /* -------------------------------------------------------------------------- */

    /// @notice Compute and return a token URI
    /// @param id The id of the targeted token
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (id > tokenId) revert NotMinted(id);

        string memory cachedBaseUri = baseUri;
        return
            bytes(cachedBaseUri).length > 0
                ? string(abi.encodePacked(cachedBaseUri, Strings.toString(id)))
                : "";
    }

    /* -------------------------------------------------------------------------- */
    /*                                OWNER LOGICS                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Update the zkVeggies contract address
    /// @param _zkVeggies The new zkVeggies contract address
    function updateZkVeggies(address _zkVeggies) external onlyOwner {
        zkVeggies = _zkVeggies;
    }

    /// @notice Update the baseUri value
    /// @param _baseUri The new baseUri value
    function updateBaseUri(string calldata _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    /// @notice Set the value of mintStarted
    /// @param _mintStarted The new value of mintStarted
    function setMintStarted(bool _mintStarted) external onlyOwner {
        mintStarted = _mintStarted;
    }

    /// @notice Set the value of wlMintStarted
    /// @param _wlMintStarted The new value of wlMintStarted
    function setWlMintStarted(bool _wlMintStarted) external onlyOwner {
        wlMintStarted = _wlMintStarted;
    }

    /// @notice Batch mint tokens to an account, for referals and partnerships
    /// @param amount the amount of NFT to mint
    /// @param to the NFT recevier address
    function batchMint(uint256 amount, address to) external onlyOwner {
        if (tokenId + amount > MAX_SUPPLY) revert MaxSupplyExceeded();

        for (uint256 i; i < amount; ) {
            _mint(to, tokenId);
            unchecked {
                ++tokenId;
                ++i;
            }
        }
    }

    /// @notice Set the current maximum mint amount per account
    /// @param _maxMintPerAccount The new maximum mint amount
    function setMaxMintPerAccount(uint256 _maxMintPerAccount) external onlyOwner {
        maxMintPerAccount = _maxMintPerAccount;
    }

    /* -------------------------------------------------------------------------- */
    /*                                ROYALTY LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Set the royalties percentage (with 2 decimals). 
    ///         100 => 1%
    ///         1542 => 15.42%
    /// @param _royaltyPercentage The new royalty percentage (with 2 decimals).
    function setRoyaltiesPercentage(uint256 _royaltyPercentage) external onlyOwner {
        royaltyPercentage = _royaltyPercentage;
    }

    /// @notice Set the contract URI which gives access to the collection 
    ///         informations.
    /// @param _contractURI The new contract URI.
    function setContractURI(string calldata _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }

    /// @notice Implement the royaltyInfo function according to the EIP-2981 (NFT 
    ///      Royalty Standard).
    /// @param _tokenId The token being sold
    /// @param _salePrice The token sale price
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        return (
            owner, 
            _salePrice * royaltyPercentage / 10000
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                ERC165 LOGICS                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Implementation of the {IERC165} interface.
    /// @param interfaceId The interface ID to check
    /// @return bool It return true if the contract support the interface ID.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x2a55205a || // ERC165 Interface ID for ERC2981
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    /* -------------------------------------------------------------------------- */
    /*                              PRIVATE FUNCTIONS                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if a mint can be done respecting the rules of mint, based on
    ///      the receiver and the amount to be minted.
    /// @param amount The amount of NFT to mint
    /// @param to The mint account receiver
    function checkMintValidity(uint256 amount, address to) private view {
        if (!mintStarted) revert MintNotStarted();
        if (tokenId + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        if (_balanceOf[to] + amount > maxMintPerAccount)
            revert MaxMintAmountExceeded();
    }
}
//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

/* ---------------------------- Internal imports ---------------------------- */
import {Strings} from "./Strings.sol";
import {ZkSeeds} from "./ZkSeeds.sol";
import {ZkSeedsUtils} from "./libraries/ZkSeedsUtils.sol";

/* ----------------------------- Solmate imports ---------------------------- */
import {ERC721} from "solmate/src/tokens/ERC721.sol";
import {Owned} from "solmate/src/auth/Owned.sol";

contract ZkVeggies is Owned, ERC721 {
    /* ----------------------------- Planting struct ---------------------------- */
    struct Planting {
        uint256[3] burnedTokens;
        uint256 plantingTime;
        uint256 harvestTime;
        bool fertilized;
    }

    /* ------------------------------- Proxy state ------------------------------ */
    bool initialized;

    /* ------------------------------- Token infos ------------------------------ */
    string public contractURI;
    uint256 public tokenId;
    string public baseUri;

    /* ------------------------------ Farming state ----------------------------- */
    bool public plantationOpened;
    bool public fertilizationOpened;

    /* -------------------------------- Royalties ------------------------------- */
    uint256 public royaltyPercentage = 1000; // 10% with 2 decimals

    /* ------------------------------ Harvest data ------------------------------ */
    mapping(address => Planting[]) public plantationsOf;
    mapping(uint256 => Planting) public harvests;

    /* -------------------------- Contracts interfaces -------------------------- */
    ZkSeeds zkSeeds;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */
    error NotMinted(uint256 id);
    error PlantationNotOpened();
    error SenderNotOwner(uint256 id);
    error AlreadyFertilized(address owner, uint256 index);
    error NothingToHarvest();
    error NotHarvested();
    error NotEnoughtValueToFertilize(uint256 value, uint256 price);
    error FertilizationNotYetAvailable();
    error EthTransferFailed(bytes data);
    error PlantingDoesntExist(address owner, uint256 index);

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */
    event Plant(address indexed owner, uint256[3] indexed seeds, uint256 time);
    event Fertilize(address indexed owner, Planting planting);

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        string memory _contractURI,
        ZkSeeds _zkSeeds
    ) Owned(msg.sender) ERC721(_name, _symbol) {
        baseUri = _baseUri;
        zkSeeds = _zkSeeds;
        contractURI = _contractURI;
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        string memory _contractURI,
        uint256 _royaltyPercentage,
        address _zkSeeds
    ) public onlyOwner {
        name = _name;
        symbol = _symbol;
        baseUri = _baseUri;
        contractURI = _contractURI;
        royaltyPercentage = _royaltyPercentage;
        zkSeeds = ZkSeeds(_zkSeeds);
    }

    /* -------------------------------------------------------------------------- */
    /*                               FARMING LOGICS                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Burn 3 zkSeeds and register a planting.
    ///         Planting 3 zkSeeds to harvest a zkVeggies.
    /// @param zkSeedsIds 3 zkSeeds token id owned by the message sender.
    function plantSeeds(uint256[3] calldata zkSeedsIds) external {
        if (!plantationOpened) revert PlantationNotOpened();
        if (zkSeeds.ownerOf(zkSeedsIds[0]) != msg.sender)
            revert SenderNotOwner(zkSeedsIds[0]);
        if (zkSeeds.ownerOf(zkSeedsIds[1]) != msg.sender)
            revert SenderNotOwner(zkSeedsIds[1]);
        if (zkSeeds.ownerOf(zkSeedsIds[2]) != msg.sender)
            revert SenderNotOwner(zkSeedsIds[2]);

        // Burn seeds
        zkSeeds.burn(zkSeedsIds[0]);
        zkSeeds.burn(zkSeedsIds[1]);
        zkSeeds.burn(zkSeedsIds[2]);

        // Register plantating
        plantationsOf[msg.sender].push(
            Planting(zkSeedsIds, block.timestamp, 0, false)
        );

        // Emit Plant event
        emit Plant(msg.sender, zkSeedsIds, block.timestamp);
    }

    /// @notice Claim all the msg.sender ready planting.
    ///         Harvest all your grown zkSeeds.
    function harvestAll() external returns (uint256 mintedAmount) {
        Planting[] memory plantings = plantationsOf[msg.sender];
        uint256 plantingsLength = plantings.length;

        if (plantingsLength == 0) revert NothingToHarvest();

        for (uint256 i = 0; i < plantingsLength; ) {
            if (plantingCanBeHarvested(plantings[i])) {
                _mint(msg.sender, tokenId);
                plantationsOf[msg.sender][i].harvestTime = block.timestamp;

                // Attach harvest data to the minted token
                harvests[tokenId] = plantationsOf[msg.sender][i];

                // Delete planting information
                delete plantationsOf[msg.sender][i];

                unchecked {
                    ++mintedAmount;
                    ++tokenId;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Accelerates the growth time of a plantation. It reduce by 3,5
    ///         days the growth time.
    /// @param index The index of the msg.sender plantations.
    function fertilize(uint256 index) external payable {
        Planting[] storage plantings = plantationsOf[msg.sender];

        if (fertilizationOpened == false) revert FertilizationNotYetAvailable();
        if (plantings[index].fertilized == true)
            revert AlreadyFertilized(msg.sender, index);
        if (msg.value < 0.01 ether)
            revert NotEnoughtValueToFertilize(msg.value, 0.01 ether);
        if (plantings[index].plantingTime == 0)
            revert PlantingDoesntExist(msg.sender, index);

        plantings[index].fertilized = true;

        emit Fertilize(msg.sender, plantings[index]);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    VIEWS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the zkSeeds tokenId that represent the seed that grew to mint
    ///      the harvested zkVeggie.
    function getSeedThatGrew(
        uint256 zkVeggiesTokenId
    ) public view returns (uint256 zkSeedsTokenId) {
        Planting memory harvest = harvests[zkVeggiesTokenId];

        if (harvest.harvestTime == 0) revert NotHarvested();

        zkSeedsTokenId = harvest.burnedTokens[harvest.harvestTime % 3];
    }

    /// @dev Get the zkSeeds tokenId that represent the seed that grew to mint
    ///      the harvested zkVeggie.
    function getVeggieType(
        uint256 _tokenId
    ) public view returns (uint256 veggieType) {
        veggieType = ZkSeedsUtils.getSeedType(getSeedThatGrew(_tokenId));
    }

    /// @notice Get the amount of plantation owned by an account.
    /// @param account The targeted account.
    function getPlantingLength(address account) public view returns (uint256) {
        return plantationsOf[account].length;
    }

    /// @notice Check if an account is a garden owner or not.
    /// @param account The account to check.
    function isGardenOwner(address account) external view returns (bool) {
        bool hasPotato;
        bool hasBroccoli;
        bool hasTomato;
        bool hasCarrot;
        bool hasChilli;

        for (uint256 i; i < tokenId; ) {
            bool isOwner = ownerOf(i) == account;
            if (isOwner && ZkSeedsUtils.isPotato(getSeedThatGrew(i)))
                hasPotato = true;
            if (isOwner && ZkSeedsUtils.isBroccoli(getSeedThatGrew(i)))
                hasBroccoli = true;
            if (isOwner && ZkSeedsUtils.isTomato(getSeedThatGrew(i)))
                hasTomato = true;
            if (isOwner && ZkSeedsUtils.isCarrot(getSeedThatGrew(i)))
                hasCarrot = true;
            if (isOwner && ZkSeedsUtils.isChilli(getSeedThatGrew(i)))
                hasChilli = true;

            unchecked {
                ++i;
            }
        }

        return hasPotato && hasBroccoli && hasTomato && hasCarrot && hasChilli;
    }

    /// @dev Check if a planting can be harvested.
    /// @param planting The planting struct to check.
    function plantingCanBeHarvested(
        Planting memory planting
    ) private view returns (bool ready) {
        uint256 growthTime = 60 * 60 * 24 * 7; // 7 days
        if (planting.fertilized) growthTime /= 2;

        ready =
            planting.plantingTime > 0 &&
            planting.harvestTime == 0 &&
            block.timestamp - growthTime >= planting.plantingTime;
    }

    /// @notice Check if an account's planting is ready to harvest.
    /// @param owner The planting owner.
    /// @param index The index of the owner's planting.
    /// @return ready True if the planting is ready to be harvested.
    function plantingCanBeHarvested(
        address owner,
        uint256 index
    ) external view returns (bool ready) {
        Planting[] memory plantings = plantationsOf[owner];

        if (plantings[index].plantingTime == 0)
            revert PlantingDoesntExist(owner, index);

        uint256 growthTime = 60 * 60 * 24 * 7; // 7 days
        if (plantings[index].fertilized) growthTime /= 2;

        ready =
            plantings[index].plantingTime > 0 &&
            plantings[index].harvestTime == 0 &&
            block.timestamp - growthTime >= plantings[index].plantingTime;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  TOKEN URI                                 */
    /* -------------------------------------------------------------------------- */

    /// @notice Compute and return a token URI.
    /// @param id The id of the targeted token.
    function tokenURI(uint256 id) public view override returns (string memory) {
        if (id > tokenId) revert NotMinted(id);

        string memory cachedBaseUri = baseUri;
        return
            bytes(cachedBaseUri).length > 0
                ? string(abi.encodePacked(cachedBaseUri, Strings.toString(id)))
                : "";
    }

    /* -------------------------------------------------------------------------- */
    /*                                ROYALTY LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Implement the royaltyInfo function according to the EIP-2981 (NFT
    ///      Royalty Standard).
    /// @param _tokenId The token being sold.
    /// @param _salePrice The token sale price.
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        return (owner, (_salePrice * royaltyPercentage) / 10000);
    }

    /// @notice Set the royalties percentage (with 2 decimals).
    ///         100 => 1%
    ///         1542 => 15.42%
    /// @param _royaltyPercentage The new royalty percentage (with 2 decimals).
    function setRoyaltiesPercentage(
        uint256 _royaltyPercentage
    ) external onlyOwner {
        royaltyPercentage = _royaltyPercentage;
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
    /*                                OWNER LOGICS                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Update the baseUri value
    /// @param _baseUri The new baseUri value
    function updateBaseUri(string calldata _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    /// @notice Set the contract URI which gives access to the collection
    ///         informations.
    /// @param _contractURI The new contract URI.
    function setContractURI(string calldata _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }

    /// @notice Toogle the farming open state.
    function toggleFarmingState() external onlyOwner {
        plantationOpened = !plantationOpened;
    }

    /// @notice Toogle the fertilization open state.
    function toggleFertilizationState() external onlyOwner {
        fertilizationOpened = !fertilizationOpened;
    }

    /// @notice Withdraw contract funds
    function withdraw() external onlyOwner {
        (bool success, bytes memory data) = payable(owner).call{
            value: address(this).balance
        }("");

        if (!success) revert EthTransferFailed(data);
    }

    function batchPlant(uint256 start, uint256 end) external onlyOwner {
        for (uint256 i = start; i <= end; ) {
            uint256 one = i;
            uint256 two = i + 1;
            uint256 three = i + 2;

            zkSeeds.burn(one);
            zkSeeds.burn(two);
            zkSeeds.burn(three);

            _mint(msg.sender, tokenId);

            harvests[tokenId] = Planting([one, two, three], block.timestamp - 4 days, block.timestamp, true);

            unchecked {
                ++tokenId;
                i += 3;
            }
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ERC721, ERC721TokenReceiver } from "solmate/src/tokens/ERC721.sol";
import { ZkSeeds } from "../contracts/ZkSeeds.sol";
import { ZkVeggies } from "../contracts/ZkVeggies.sol";
import { ZkSeedsUtils } from "../contracts/libraries/ZkSeedsUtils.sol";
import { ZkVeggiesProxy } from "../contracts/ZkVeggiesProxy.sol";

contract ZkVeggiesTest is Test, ERC721TokenReceiver{
    /* ----------------------------- Planting struct ---------------------------- */
    struct Planting{
        uint256[3] burnedTokens;
        uint256 plantingTime;
        bool fertilized;
        uint256 harvestTime;
    }

    /* --------------------------------- Storage -------------------------------- */
    ZkSeeds public zkSeeds;
    ZkVeggies public zkVeggies;
    address user1 = address(1);
    address whale = address(2);
    address admin = address(1234);
    uint256 dateNow = 1683454721;

    /* ------------------------------- ZkSyncFork ------------------------------- */
    address public zkSyncOwner = 0xb3306534236F12dCF2190488E046A359C9167FB0;

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */
    error NotMinted(uint256 id);
    error MaxSupplyExceeded();
    error InvalidTokenIdArrayLength();
    error MaxMintAmountExceeded();
    error PlantationNotOpened();
    error SenderNotOwner(uint256 id);
    error NothingToHarvest();
    error NotEnoughtValueToFertilize(uint256 value, uint256 price);
    error PlantingDoesntExist(address owner, uint256 index);

    /* -------------------------------------------------------------------------- */
    /*                                    SETUP                                   */
    /* -------------------------------------------------------------------------- */

    function setUp() public {
        // Set block.timestamp
        vm.warp(dateNow);
        vm.deal(whale, 200 ether);

        // Deploy zkSeeds contracts
        zkSeeds = new ZkSeeds("zkSeeds", "ZKS", "https://zkveggies.com/", "https://zkveggies.com/seeds/infos", 11);
        zkSeeds.batchMint(9, address(this));

        // Deploy zkVeggies contracts
        ZkVeggies impl = new ZkVeggies("zkVeggies", "ZKV", "https://zkveggies.com/", "https://zkveggies.com/veggies/infos", zkSeeds);

        // Deploy proxy
        ZkVeggiesProxy proxy = new ZkVeggiesProxy(address(impl), admin, abi.encode());

        vm.prank(admin);
        proxy.initialize(
            address(this),
            "zkVeggies", 
            "ZKV", 
            "https://zkveggies.com/", 
            "https://zkveggies.com/veggies/infos", 
            1000,
            address(zkSeeds)
        );

        zkVeggies = ZkVeggies(address(proxy));

        // Set the zkVeggies address
        zkSeeds.updateZkVeggies(address(zkVeggies));
    }

    /* -------------------------------------------------------------------------- */
    /*                                 BASIC TESTS                                */
    /* -------------------------------------------------------------------------- */

    function testDebug() public {
        zkSeeds.batchMint(800, address(this));
        zkVeggies.batchPlant(200, 203);
        console.logBytes(abi.encodeWithSelector(zkVeggies.tokenURI.selector, 0));
    }

    function testBatchPlant() public {
        // Airdrop Vente
        zkSeeds.batchMint(200 - 9, address(this));


        // AirdDrop Owner
        zkSeeds.batchMint(800, zkSyncOwner);

        // Setup real owner
        zkSeeds.transferOwnership(zkSyncOwner);
        zkVeggies.transferOwnership(zkSyncOwner);
        vm.startPrank(zkSyncOwner);

        // Transfer transfered ones
        zkSeeds.transferFrom(zkSyncOwner, address(1), 998);
        zkSeeds.transferFrom(zkSyncOwner, address(1), 997);
        zkSeeds.transferFrom(zkSyncOwner, address(1), 968);

        /* ---------------------------------- START --------------------------------- */

        assertEq(zkSeeds.balanceOf(zkSyncOwner), 797);
        assertEq(zkVeggies.balanceOf(zkSyncOwner), 0);

        zkVeggies.batchPlant(200, 868);

        assertEq(zkVeggies.getSeedThatGrew(0), 202);
        assertEq(zkVeggies.getSeedThatGrew(1), 205);
        assertEq(zkVeggies.getSeedThatGrew(2), 208);

        assertEq(zkSeeds.balanceOf(zkSyncOwner), 128);
        assertEq(zkVeggies.balanceOf(zkSyncOwner), 223);
    }

    function testDefaultTokenId() public {
        assertEq(zkVeggies.tokenId(), 0);
    }

    function testName() public {
        assertEq(zkVeggies.name(), "zkVeggies");
    }

    function testSymbol() public {
        assertEq(zkVeggies.symbol(), "ZKV");
    }

    function testBaseUri() public {
        assertEq(zkVeggies.baseUri(), "https://zkveggies.com/");
    }

    function testContractUri() public {
        assertEq(zkVeggies.contractURI(), "https://zkveggies.com/veggies/infos");

        zkVeggies.setContractURI("https://test.com/");
        
        assertEq(zkVeggies.contractURI(), "https://test.com/");
    }

    function testPlantationOpened() public {
        assertEq(zkVeggies.plantationOpened(), false);

        zkVeggies.toggleFarmingState();
        assertEq(zkVeggies.plantationOpened(), true);

        zkVeggies.toggleFarmingState();
        assertEq(zkVeggies.plantationOpened(), false);

        zkVeggies.toggleFarmingState();
        assertEq(zkVeggies.plantationOpened(), true);
    }

    function testFertilizationOpened() public {
        assertEq(zkVeggies.fertilizationOpened(), false);

        zkVeggies.toggleFertilizationState();
        assertEq(zkVeggies.fertilizationOpened(), true);

        zkVeggies.toggleFertilizationState();
        assertEq(zkVeggies.fertilizationOpened(), false);

        zkVeggies.toggleFertilizationState();
        assertEq(zkVeggies.fertilizationOpened(), true);
    }

    function testRoyaltiesInfo() public {
        (address receiver, uint256 amount) = zkVeggies.royaltyInfo(0, 1 ether);

        assertEq(receiver, zkVeggies.owner());
        assertEq(amount, 0.1 ether);

        zkVeggies.setRoyaltiesPercentage(2000);

        (receiver, amount) = zkVeggies.royaltyInfo(0, 1 ether);

        assertEq(receiver, zkVeggies.owner());
        assertEq(amount, 0.2 ether);
    }

    function testErc2981SupportInterface() public {
        assertEq(zkVeggies.supportsInterface(0x2a55205a), true);
    }

    function testTokenUri() public {
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 1));
        zkVeggies.tokenURI(1);
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 100));
        zkVeggies.tokenURI(100);
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 1 ether));
        zkVeggies.tokenURI(1 ether);

        zkVeggies.toggleFarmingState();
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(5)]);
        zkVeggies.plantSeeds([uint256(6), uint256(7), uint256(8)]);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.tokenURI(0), "https://zkveggies.com/0");
        assertEq(zkVeggies.tokenURI(1), "https://zkveggies.com/1");
        assertEq(zkVeggies.tokenURI(2), "https://zkveggies.com/2");

        zkVeggies.updateBaseUri("test/");

        assertEq(zkVeggies.tokenURI(0), "test/0");
        assertEq(zkVeggies.tokenURI(1), "test/1");
        assertEq(zkVeggies.tokenURI(2), "test/2");
    }
    /* -------------------------------------------------------------------------- */
    /*                                 PLANT TESTS                                */
    /* -------------------------------------------------------------------------- */

    function testPlantSeeds() public {
        zkVeggies.toggleFarmingState();

        // Check seeds ownership before planting
        assertEq(zkSeeds.balanceOf(address(this)), 9);
        assertEq(zkSeeds.ownerOf(0), address(this));
        assertEq(zkSeeds.ownerOf(1), address(this));
        assertEq(zkSeeds.ownerOf(2), address(this));
        
        // Check plantings[0] has never been registered
        vm.expectRevert();
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check seeds ownership after planting
        assertEq(zkSeeds.balanceOf(address(this)), 6);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(0);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(1);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(2);
        
        // Check if planting has been registered
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);

        // Check if the new planting is not ready for harvest
        bool ready = zkVeggies.plantingCanBeHarvested(address(this), 0);
        assertEq(ready, false);

        // Check plantings[1] has never been registered
        vm.expectRevert();
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 1);
    }

    function testPlantSeedsTwice() public {
        zkVeggies.toggleFarmingState();

        // Check seeds ownership before planting
        assertEq(zkSeeds.balanceOf(address(this)), 9);
        assertEq(zkSeeds.ownerOf(0), address(this));
        assertEq(zkSeeds.ownerOf(1), address(this));
        assertEq(zkSeeds.ownerOf(2), address(this));

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check seeds ownership after planting
        assertEq(zkSeeds.balanceOf(address(this)), 6);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(0);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(1);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(2);

        vm.expectRevert("NOT_MINTED");
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(2)]);
    }

    function testPlantSeedsNotOwner() public {
        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(10, user1);

        // Check seeds ownership before planting
        assertEq(zkSeeds.balanceOf(address(this)), 9);
        assertEq(zkSeeds.ownerOf(10), user1);
        assertEq(zkSeeds.ownerOf(11), user1);
        assertEq(zkSeeds.ownerOf(12), user1);

        vm.expectRevert(abi.encodeWithSelector(SenderNotOwner.selector, 10));
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);

        vm.expectRevert(abi.encodeWithSelector(SenderNotOwner.selector, 12));
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(12)]);

        vm.expectRevert("NOT_MINTED");
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(50)]);
    }
    
    function testPlantSeedsWrongSeedsLength() public {
        zkVeggies.toggleFarmingState();

        // Check seeds ownership before planting
        assertEq(zkSeeds.balanceOf(address(this)), 9);
        assertEq(zkSeeds.ownerOf(0), address(this));
        assertEq(zkSeeds.ownerOf(1), address(this));
        assertEq(zkSeeds.ownerOf(2), address(this));
        
        (bool success, bytes memory data) = address(zkVeggies).call(abi.encodeWithSelector(zkVeggies.plantSeeds.selector, [uint256(0), uint256(1)]));

        // Check call failed
        assertEq(success, false);
        assertEq(data, abi.encode());

        // Check seeds ownership after planting
        assertEq(zkSeeds.balanceOf(address(this)), 9);
        assertEq(zkSeeds.ownerOf(0), address(this));
        assertEq(zkSeeds.ownerOf(1), address(this));
        assertEq(zkSeeds.ownerOf(2), address(this));
        
        (success, data) = address(zkVeggies).call(abi.encodeWithSelector(zkVeggies.plantSeeds.selector, [uint256(0), uint256(1), uint256(2), uint256(3)]));

        // Check call succeed
        assertEq(success, true);
        // Check seeds ownership after planting
        assertEq(zkSeeds.balanceOf(address(this)), 6);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(0);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(1);
        vm.expectRevert("NOT_MINTED");
        zkSeeds.ownerOf(2);
    }

    /* -------------------------------------------------------------------------- */
    /*                                HARVEST TESTS                               */
    /* -------------------------------------------------------------------------- */

    function testHarvest() public {
        zkVeggies.toggleFarmingState();

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check plantings[0] datas
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);
        
        // Expectin revert when harvest
        uint256 harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);

        vm.warp(plantingTime + 7 days - 1 seconds);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);

        vm.warp(plantingTime + 7 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);

        assertEq(zkVeggies.ownerOf(0), address(this));
        assertEq(zkVeggies.balanceOf(address(this)), 1);

        (plantingTime, harvestTime, fertilized) = zkVeggies.harvests(0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, plantingTime + 7 days);
    }

    function testMultipleHarvest() public {
        zkVeggies.toggleFarmingState();

        // Plant 6 seeds now
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(5)]);

        // Plant 3 seeds 1 day later
        vm.warp(dateNow + 1 days);
        zkVeggies.plantSeeds([uint256(6), uint256(7), uint256(8)]);

        // Check plantings[0] datas
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);
        // Check plantings[1] datas
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 1);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);
        // Check plantings[2] datas
        (uint256 plantingTime2, uint256 harvestTime2, bool fertilized2) = zkVeggies.plantationsOf(address(this), 2);
        assertEq(plantingTime2, dateNow + 1 days);
        assertEq(fertilized2, false);
        assertEq(harvestTime2, 0);

        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), false);
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 1), false);
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 2), false);
        
        /* ------------------------------ First 6 seeds ----------------------------- */

        // Expectin revert when harvest
        uint256 harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);

        // Expectin revert when harvest 1 seconds too early
        vm.warp(dateNow + 7 days - 1 seconds);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);

        // Harvest the 6 first seeds
        vm.warp(dateNow + 7 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 2);

        // Check balance and ownership
        assertEq(zkVeggies.ownerOf(0), address(this));
        assertEq(zkVeggies.ownerOf(1), address(this));
        assertEq(zkVeggies.balanceOf(address(this)), 2);
        vm.expectRevert("NOT_MINTED");
        zkVeggies.ownerOf(2);
        
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 2), false);

        /* ------------------------------ 3 last seeds ------------------------------ */

        // Expectin revert when harvest 1 seconds too early
        vm.warp(plantingTime + 8 days - 1 seconds);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);

        // Harvest the 3 other seeds
        vm.warp(plantingTime + 8 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);

        // Check balance and ownership
        assertEq(zkVeggies.ownerOf(0), address(this));
        assertEq(zkVeggies.ownerOf(1), address(this));
        assertEq(zkVeggies.ownerOf(2), address(this));
        assertEq(zkVeggies.balanceOf(address(this)), 3);

        vm.expectRevert(abi.encodeWithSelector(PlantingDoesntExist.selector, address(this), 0));
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), false);
        vm.expectRevert(abi.encodeWithSelector(PlantingDoesntExist.selector, address(this), 1));
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 1), false);
        vm.expectRevert(abi.encodeWithSelector(PlantingDoesntExist.selector, address(this), 2));
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 2), false);
    }

    function testCantHarvestTwice() public {
        zkVeggies.toggleFarmingState();
        zkVeggies.toggleFertilizationState();

        zkSeeds.batchMint(3 * 20, whale);

        vm.startPrank(whale);

        // Plant 6 seeds now
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(15)]);
        
        // Check plantings[0] datas
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(whale, 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);
        // Check plantings[1] datas
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(whale, 1);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);

        // Harvest seeds
        vm.warp(dateNow + 7 days);
        uint256 harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 2);
        assertEq(zkVeggies.balanceOf(whale), 2);

        // Re harvest
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);
        assertEq(zkVeggies.balanceOf(whale), 2);

        // Re harvest later
        vm.warp(dateNow + 20 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);
        assertEq(zkVeggies.balanceOf(whale), 2);

        // Plant other seeds, and re harvest later
        zkVeggies.plantSeeds([uint256(16), uint256(17), uint256(18)]);
        vm.warp(dateNow + 40 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);
        assertEq(zkVeggies.balanceOf(whale), 3);

        // Plant other seeds, fertilize them and re harvest later
        zkVeggies.plantSeeds([uint256(19), uint256(20), uint256(21)]);
        (bool success,) = address(zkVeggies).call{
            value: 0.01 ether
        }(
            abi.encodeWithSelector(zkVeggies.fertilize.selector, 3)
        );
        vm.warp(dateNow + 43.5 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);
        assertEq(zkVeggies.balanceOf(whale), 4);

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                               FERTILIZE TESTS                              */
    /* -------------------------------------------------------------------------- */

    // function testWithdrawFertilizeFundsToContact() public {
    //     zkVeggies.toggleFarmingState();
    //     zkVeggies.toggleFertilizationState();

    //     uint256 balanceBefore = address(zkVeggies).balance;

    //     // Check plantings[0] has never been registered
    //     vm.expectRevert();
    //     (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);

    //     zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

    //     // Check plantings[0] datas
    //     (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
    //     assertEq(plantingTime, dateNow);
    //     assertEq(fertilized, false);
    //     assertEq(harvestTime, 0);

    //     (bool success,) = address(zkVeggies).call{
    //         value: 0.01 ether
    //     }(
    //         abi.encodeWithSelector(zkVeggies.fertilize.selector, 0)
    //     );

    //     // Check contract balance after fertilization
    //     assertEq(success, true);
    //     uint256 balanceAfter = address(zkVeggies).balance;
    //     assertEq(balanceAfter, balanceBefore + 0.01 ether);

    //     // Withdraw funds
    //     uint256 ownerBalanceBefore = address(this).balance;
    //     zkVeggies.withdraw();
    //     assertEq(address(this).balance, ownerBalanceBefore + (balanceAfter - balanceBefore));
    // }

    function testWithdrawFertilizeFundsToAccount() public {
        zkVeggies.toggleFarmingState();
        zkVeggies.toggleFertilizationState();

        uint256 balanceBefore = address(zkVeggies).balance;

        // Check plantings[0] has never been registered
        vm.expectRevert();
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check plantings[0] datas
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);

        (bool success,) = address(zkVeggies).call{
            value: 0.01 ether
        }(
            abi.encodeWithSelector(zkVeggies.fertilize.selector, 0)
        );

        // Check contract balance after fertilization
        assertEq(success, true);
        uint256 balanceAfter = address(zkVeggies).balance;
        assertEq(balanceAfter, balanceBefore + 0.01 ether);

        zkVeggies.transferOwnership(user1);
        vm.startPrank(user1);

        // Withdraw funds
        uint256 ownerBalanceBefore = address(user1).balance;
        zkVeggies.withdraw();
        assertEq(address(user1).balance, ownerBalanceBefore + (balanceAfter - balanceBefore));
    }

    function testFertilize() public {
        zkVeggies.toggleFarmingState();
        zkVeggies.toggleFertilizationState();

        uint256 balanceBefore = address(zkVeggies).balance;

        // Check plantings[0] has never been registered
        vm.expectRevert();
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check plantings[0] datas
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);

        (bool success,) = address(zkVeggies).call{
            value: 0.01 ether
        }(
            abi.encodeWithSelector(zkVeggies.fertilize.selector, 0)
        );

        assertEq(success, true);
        assertEq(address(zkVeggies).balance, balanceBefore + 0.01 ether);

        // Check plantings[0] datas after fertilization
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, true);
        assertEq(harvestTime, 0);

        // Try harvest 1 second too eraly and check result
        vm.warp(dateNow + 3.5 days - 1 seconds);
        uint256 harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);
        assertEq(zkVeggies.balanceOf(address(this)), 0);

        // Harvest in time and check result
        vm.warp(dateNow + 3.5 days);
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);
        assertEq(zkVeggies.balanceOf(address(this)), 1);
    }

    function testFertilizeAfterPlanting() public {
        zkVeggies.toggleFarmingState();
        zkVeggies.toggleFertilizationState();

        // Check plantings[0] has never been registered
        vm.expectRevert();
        (uint256 plantingTime, uint256 harvestTime, bool fertilized) = zkVeggies.plantationsOf(address(this), 0);

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Check plantings[0] datas
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, false);
        assertEq(harvestTime, 0);

        // Try harvest 4 days later
        vm.warp(dateNow + 4 days);
        uint256 harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 0);
        assertEq(zkVeggies.balanceOf(address(this)), 0);

        // Fertilize 4 days later
        (bool success,) = address(zkVeggies).call{
            value: 0.01 ether
        }(
            abi.encodeWithSelector(zkVeggies.fertilize.selector, 0)
        );

        assertEq(success, true);

        // Check plantings[0] datas after fertilization
        (plantingTime, harvestTime, fertilized) = zkVeggies.plantationsOf(address(this), 0);
        assertEq(plantingTime, dateNow);
        assertEq(fertilized, true);
        assertEq(harvestTime, 0);

        // Harvest just after the 4 days late fertilization
        harvestTimeAmount = zkVeggies.harvestAll();
        assertEq(harvestTimeAmount, 1);
        assertEq(zkVeggies.balanceOf(address(this)), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                              VEGGIE TYPE TESTS                             */
    /* -------------------------------------------------------------------------- */

    function testPotato(uint256 secondsOffset) public {
        vm.assume(secondsOffset < 3650 days);

        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(18, whale);

        vm.startPrank(whale);

        // Check whale has no planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 0);

        // Plant seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);

        // Check whale has one planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 1);
        
        // Set timestamp
        vm.warp(dateNow + 7 days + secondsOffset);

        // Harvest plantation
        zkVeggies.harvestAll();

        // Check type
        assertEq(zkVeggies.getVeggieType(0), 0);

        vm.stopPrank();
    }

    function testBroccoli(uint256 secondsOffset) public {
        vm.assume(secondsOffset < 3650 days);

        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(60, whale);

        vm.startPrank(whale);

        // Check whale has no planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 0);

        // Plant seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);

        // Check whale has one planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 1);
        
        // Set timestamp
        vm.warp(dateNow + 7 days + secondsOffset);

        // Harvest plantation
        zkVeggies.harvestAll();

        // Check type
        assertEq(zkVeggies.getVeggieType(0), 1);

        vm.stopPrank();
    }

    function testTomato(uint256 secondsOffset) public {
        vm.assume(secondsOffset < 3650 days);

        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(60, whale);

        vm.startPrank(whale);

        // Check whale has no planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 0);

        // Plant seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);

        // Check whale has one planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 1);
        
        // Set timestamp
        vm.warp(dateNow + 7 days + secondsOffset);

        // Harvest plantation
        zkVeggies.harvestAll();

        // Check type
        assertEq(zkVeggies.getVeggieType(0), 2);

        vm.stopPrank();
    }

    function testCarrot(uint256 secondsOffset) public {
        vm.assume(secondsOffset < 3650 days);

        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(60, whale);

        vm.startPrank(whale);

        // Check whale has no planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 0);

        // Plant seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);

        // Check whale has one planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 1);
        
        // Set timestamp
        vm.warp(dateNow + 7 days + secondsOffset);

        // Harvest plantation
        zkVeggies.harvestAll();

        // Check type
        assertEq(zkVeggies.getVeggieType(0), 3);

        vm.stopPrank();
    }

    function testChilli(uint256 secondsOffset) public {
        vm.assume(secondsOffset < 3650 days);

        zkVeggies.toggleFarmingState();
        zkSeeds.batchMint(60, whale);

        vm.startPrank(whale);

        // Check whale has no planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 0);

        // Plant seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        // Check whale has one planting in progress
        assertEq(zkVeggies.getPlantingLength(whale), 1);
        
        // Set timestamp
        vm.warp(dateNow + 7 days + secondsOffset);

        // Harvest plantation
        zkVeggies.harvestAll();

        // Check type
        assertEq(zkVeggies.getVeggieType(0), 4);

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                               TEST GREW SEED                               */
    /* -------------------------------------------------------------------------- */

    function testGrewSeed0() public {
        zkVeggies.toggleFarmingState();

        // Plant seeds
        vm.warp(dateNow);
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);
        vm.warp(dateNow + 3 seconds);
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(5)]);
        vm.warp(dateNow + 6 seconds);
        zkVeggies.plantSeeds([uint256(6), uint256(7), uint256(8)]);

        // Set timestamp
        vm.warp(dateNow + 7 days + 4 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 7 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 10 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        assertEq(zkVeggies.getSeedThatGrew(0), 0);
        assertEq(zkVeggies.getSeedThatGrew(1), 3);
        assertEq(zkVeggies.getSeedThatGrew(2), 6);
    }

    function testGrewSeed1() public {
        zkVeggies.toggleFarmingState();

        // Plant seeds
        vm.warp(dateNow);
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);
        vm.warp(dateNow + 3 seconds);
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(5)]);
        vm.warp(dateNow + 6 seconds);
        zkVeggies.plantSeeds([uint256(6), uint256(7), uint256(8)]);

        // Set timestamp
        vm.warp(dateNow + 7 days + 5 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 8 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 11 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        assertEq(zkVeggies.getSeedThatGrew(0), 1);
        assertEq(zkVeggies.getSeedThatGrew(1), 4);
        assertEq(zkVeggies.getSeedThatGrew(2), 7);
    }

    function testGrewSeed2() public {
        zkVeggies.toggleFarmingState();

        // Plant seeds
        vm.warp(dateNow);
        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);
        vm.warp(dateNow + 3 seconds);
        zkVeggies.plantSeeds([uint256(3), uint256(4), uint256(5)]);
        vm.warp(dateNow + 6 seconds);
        zkVeggies.plantSeeds([uint256(6), uint256(7), uint256(8)]);

        // Set timestamp
        vm.warp(dateNow + 7 days);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 3 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        // Set timestamp
        vm.warp(dateNow + 7 days + 6 seconds);
        // Harvest seeds
        zkVeggies.harvestAll();

        assertEq(zkVeggies.getSeedThatGrew(0), 2);
        assertEq(zkVeggies.getSeedThatGrew(1), 5);
        assertEq(zkVeggies.getSeedThatGrew(2), 8);
    }

    /* -------------------------------------------------------------------------- */
    /*                                GARDEN TESTS                                */
    /* -------------------------------------------------------------------------- */

    function testIsGardenOwner() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), true);

        vm.stopPrank();
    }

    function testIsGardenOwnerNoPotato() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        // zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.stopPrank();
    }

    function testIsGardenOwnerNoBroccoli() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        // zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.stopPrank();
    }

    function testIsGardenOwnerNoTomato() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        // zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.stopPrank();
    }

    function testIsGardenOwnerNoCarrot() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        // zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.stopPrank();
    }

    function testIsGardenOwnerNoChilli() public {
        zkSeeds.batchMint(3 * 50, whale);
        zkVeggies.toggleFarmingState();

        vm.startPrank(whale);

        // Plant 3 potato seeds
        zkVeggies.plantSeeds([uint256(10), uint256(11), uint256(12)]);
        // Plant 3 broccoli seeds
        zkVeggies.plantSeeds([uint256(13), uint256(14), uint256(23)]);
        // Plant 3 tomato seeds
        zkVeggies.plantSeeds([uint256(15), uint256(16), uint256(25)]);
        // Plant 3 carrot seeds
        zkVeggies.plantSeeds([uint256(17), uint256(18), uint256(27)]);
        // Plant 3 chilli seeds
        // zkVeggies.plantSeeds([uint256(19), uint256(29), uint256(39)]);

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.warp(dateNow + 7 days);
        zkVeggies.harvestAll();

        assertEq(zkVeggies.isGardenOwner(whale), false);

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                          PLANTING CAN BE HARVESTED                         */
    /* -------------------------------------------------------------------------- */

    function testPlantingCanBeHarvested() public {
        zkVeggies.toggleFarmingState();
        zkVeggies.toggleFertilizationState();

        zkVeggies.plantSeeds([uint256(0), uint256(1), uint256(2)]);

        // Can't harvest juste after planting
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), false);

        // Can harvest 7 days after planting
        vm.warp(dateNow + 7 days);
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), true);

        // Can't harvest 3.5 days after planting
        vm.warp(dateNow + 3.5 days);
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), false);

        // Can harvest 3.5 days after planting if fertilized
        vm.warp(dateNow + 3.5 days);
        (bool success,) = address(zkVeggies).call{value: 0.1 ether}(abi.encodeWithSelector(zkVeggies.fertilize.selector, 0));
        assertEq(success, true);
        assertEq(zkVeggies.plantingCanBeHarvested(address(this), 0), true);
    }
}
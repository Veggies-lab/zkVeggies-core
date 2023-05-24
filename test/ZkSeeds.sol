// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ERC721TokenReceiver } from "solmate/src/tokens/ERC721.sol";
import { ZkSeeds } from "../contracts/ZkSeeds.sol";

import "forge-std/console.sol";

contract ZkSeedsTest is Test, ERC721TokenReceiver{
    ZkSeeds public zkSeeds;

    address public user1 = address(1);
    address public user2 = address(2);
    address public user3 = address(3);

    error NotMinted(uint256 id);
    error MaxSupplyExceeded();
    error MaxMintAmountExceeded();
    error MintNotStarted();
    error WhitelistMintNotStarted();
    error AccountNotWhitlisted();
    error InvalidAmountLength();

    /* -------------------------------------------------------------------------- */
    /*                                    SETUP                                   */
    /* -------------------------------------------------------------------------- */

    function setUp() public {
        zkSeeds = new ZkSeeds("zkSeeds", "ZKS", "https://zkveggies.com/", "https://zkveggies.com/seeds/infos", 11);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 BASIC TESTS                                */
    /* -------------------------------------------------------------------------- */

    function testDefaultTokenId() public {
        assertEq(zkSeeds.tokenId(), 0);
    }

    function testName() public {
        assertEq(zkSeeds.name(), "zkSeeds");
    }

    function testSymbol() public {
        assertEq(zkSeeds.symbol(), "ZKS");
    }

    function testBaseUri() public {
        assertEq(zkSeeds.baseUri(), "https://zkveggies.com/");
    }

    function testTokenUri() public {
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 1));
        zkSeeds.tokenURI(1);
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 100));
        zkSeeds.tokenURI(100);
        vm.expectRevert(abi.encodeWithSelector(NotMinted.selector, 1 ether));
        zkSeeds.tokenURI(1 ether);

        zkSeeds.setMintStarted(true);
        zkSeeds.mint(5);

        assertEq(zkSeeds.tokenURI(0), "https://zkveggies.com/0");
        assertEq(zkSeeds.tokenURI(1), "https://zkveggies.com/1");
        assertEq(zkSeeds.tokenURI(2), "https://zkveggies.com/2");
        assertEq(zkSeeds.tokenURI(3), "https://zkveggies.com/3");
        assertEq(zkSeeds.tokenURI(4), "https://zkveggies.com/4");
        assertEq(zkSeeds.tokenURI(5), "https://zkveggies.com/5");

        zkSeeds.updateBaseUri("test/");

        assertEq(zkSeeds.tokenURI(0), "test/0");
        assertEq(zkSeeds.tokenURI(1), "test/1");
        assertEq(zkSeeds.tokenURI(2), "test/2");
        assertEq(zkSeeds.tokenURI(3), "test/3");
        assertEq(zkSeeds.tokenURI(4), "test/4");
        assertEq(zkSeeds.tokenURI(5), "test/5");
    }


    /* -------------------------------------------------------------------------- */
    /*                                 MINT TESTS                                 */
    /* -------------------------------------------------------------------------- */

    function testBasicMint1() public {
        zkSeeds.setMintStarted(true);
        // mint more tokens
        zkSeeds.mint(1);
    }

    function testBasicMint() public {
        assertEq(zkSeeds.balanceOf(address(this)), 0);
        zkSeeds.setMintStarted(true);

        // mint 1 token
        zkSeeds.mint(1);

        assertEq(zkSeeds.balanceOf(address(this)), 1);

        // mint one more tokens for me
        zkSeeds.mint(1, address(this));

        // Mint token for user1
        zkSeeds.mint(1, user1);

        assertEq(zkSeeds.balanceOf(address(this)), 2);
        assertEq(zkSeeds.balanceOf(user1), 1);
    }

    function testMultipleMint() public {
        zkSeeds.setMintStarted(true);
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint 10 token
        zkSeeds.mint(5);

        assertEq(zkSeeds.balanceOf(address(this)), 5);

        // mint more tokens
        zkSeeds.mint(5);
        zkSeeds.mint(5, user1);

        assertEq(zkSeeds.balanceOf(address(this)), 10);
        assertEq(zkSeeds.balanceOf(user1), 5);
    }

    function testMultipleMintWhenMaxMintPerAccountIs1() public {
        uint256 newMaxMintPerAccount = 1;

        // Set a new max mint per account
        zkSeeds.setMaxMintPerAccount(newMaxMintPerAccount);

        zkSeeds.setMintStarted(true);
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint tokens
        zkSeeds.mint(1);

        assertEq(zkSeeds.balanceOf(address(this)), 1);

        // mint one more token for me
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.mint(1);

        // Mint a token for user1
        zkSeeds.mint(1, user1);

        assertEq(zkSeeds.balanceOf(address(this)), 1);
        assertEq(zkSeeds.balanceOf(user1), 1);
    }

    function testMultipleMintAfterMaxMintPerAccountUpdate(uint256 newMaxMintPerAccount) public {
        vm.assume(newMaxMintPerAccount > 1);
        vm.assume(newMaxMintPerAccount < 3000);
        // Set a new max mint per account
        zkSeeds.setMaxMintPerAccount(newMaxMintPerAccount);

        zkSeeds.setMintStarted(true);
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint tokens
        zkSeeds.mint(newMaxMintPerAccount/2);

        assertEq(zkSeeds.balanceOf(address(this)), newMaxMintPerAccount/2);

        // mint more tokens
        zkSeeds.mint(newMaxMintPerAccount/2);
        zkSeeds.mint(newMaxMintPerAccount/2, user1);

        assertEq(zkSeeds.balanceOf(address(this)), (newMaxMintPerAccount/2)*2);
        assertEq(zkSeeds.balanceOf(user1), newMaxMintPerAccount/2);

        // mint too many more token for me
        uint256 amountToExceedMax = (newMaxMintPerAccount - zkSeeds.balanceOf(address(this))) + 1;
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.mint(amountToExceedMax);

        // mint too many more token for user1
        amountToExceedMax = (newMaxMintPerAccount - zkSeeds.balanceOf(address(user1))) + 1;
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.mint(amountToExceedMax, user1);
    }

    function testSafeMint() public {
        zkSeeds.setMintStarted(true);
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint 1 token
        zkSeeds.safeMint();

        assertEq(zkSeeds.balanceOf(address(this)), 1);

        // mint more tokens
        zkSeeds.safeMint(address(this));
        zkSeeds.safeMint(user1);

        assertEq(zkSeeds.balanceOf(address(this)), 2);
        assertEq(zkSeeds.balanceOf(user1), 1);

        // Test unsafe receiver
        vm.expectRevert();

        zkSeeds.safeMint(address(zkSeeds));
    }

    /* -------------------------------------------------------------------------- */
    /*                                PRESALE TESTS                               */
    /* -------------------------------------------------------------------------- */

    function testWhitelistAccount() public {
        assertEq(zkSeeds.whitelisted(user1), 0);

        // Add 3 allowed mint for user1 during presale
        zkSeeds.whitelist(user1, 3);

        assertEq(zkSeeds.whitelisted(user1), 3);

        // Add 6 allowed mint for user1 during presale
        zkSeeds.whitelist(user1, 6);

        assertEq(zkSeeds.whitelisted(user1), 6);
    }

    function testBasicPresaleMint() public {
        // Start the presale
        zkSeeds.setWlMintStarted(true);

        // Whitelist address(this) and user1
        zkSeeds.whitelist(address(this), 2);
        zkSeeds.whitelist(user1, 1);

        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint 1 token
        zkSeeds.whitelistMint(1);

        assertEq(zkSeeds.balanceOf(address(this)), 1);

        // mint more tokens
        zkSeeds.whitelistMint(1);
        vm.prank(user1);
        zkSeeds.whitelistMint(1);

        assertEq(zkSeeds.balanceOf(address(this)), 2);
        assertEq(zkSeeds.balanceOf(user1), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                              MINT RULES TESTS                              */
    /* -------------------------------------------------------------------------- */

    function testTokenIdIncrement() public {
        zkSeeds.setMintStarted(true);

        uint256 maxSupply = zkSeeds.MAX_SUPPLY();

        for(uint160 i = 1; i <= maxSupply; ++i){
            zkSeeds.mint(1, address(i));
            assertEq(zkSeeds.tokenId(), i);
        }
    }
    
    function testMintExceedMaxAmountPerAccount() public {
        zkSeeds.setMintStarted(true);

        uint256 maxMint = zkSeeds.maxMintPerAccount();

        // Exceed max token with mint
        zkSeeds.mint(maxMint);
        assertEq(zkSeeds.balanceOf(address(this)), maxMint);
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.mint(1);

        // Exceed max token with mint to
        zkSeeds.mint(maxMint, user1);
        assertEq(zkSeeds.balanceOf(user1), maxMint);
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.mint(1, user1);
        
        // Exceed max token with safe mint
        vm.startPrank(user2);
        for(uint256 i; i < maxMint; ++i){
            zkSeeds.safeMint();
        }
        assertEq(zkSeeds.balanceOf(user2), maxMint);
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.safeMint();
        
        // Exceed max token with safe mint
        for(uint256 i; i < maxMint; ++i){
            zkSeeds.safeMint(user3);
        }
        assertEq(zkSeeds.balanceOf(user3), maxMint);
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.safeMint(user3);

        vm.stopPrank();
    }
    
    function testMintExceedMaxSupply() public {
        zkSeeds.setMintStarted(true);

        uint256 maxSupply = zkSeeds.MAX_SUPPLY();

        for(uint160 i = 1; i <= maxSupply; ++i){
            zkSeeds.mint(1, address(i));
        }

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.mint(1);

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.mint(1, user1);

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.safeMint();

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.safeMint(user1);
    }

    function testBasicMintWhenNotStarted() public {
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // Mint 1 token
        vm.expectRevert(abi.encodeWithSelector(MintNotStarted.selector));
        zkSeeds.mint(1);

        // Mint 1 token to user1
        vm.expectRevert(abi.encodeWithSelector(MintNotStarted.selector));
        zkSeeds.mint(1, user1);
        
        // Safe mint 1 token
        vm.expectRevert(abi.encodeWithSelector(MintNotStarted.selector));
        zkSeeds.safeMint(user1);

        // Safe mint 1 token to user1
        vm.expectRevert(abi.encodeWithSelector(MintNotStarted.selector));
        zkSeeds.safeMint();
    }

    /* -------------------------------------------------------------------------- */
    /*                         WHITELIST MINT RULES TESTS                         */
    /* -------------------------------------------------------------------------- */

    function testTokenIdIncrementWhitelist() public {
        zkSeeds.setWlMintStarted(true);

        uint256 maxSupply = zkSeeds.MAX_SUPPLY();

        for(uint160 i = 1; i <= maxSupply; ++i){
            zkSeeds.whitelist(address(i), 1);
            vm.prank(address(i));
            zkSeeds.whitelistMint(1);
            assertEq(zkSeeds.tokenId(), i);
        }
    }

    function testPresaleMintWhenNotStarted() public {
        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint 1 token during presale
        vm.expectRevert(abi.encodeWithSelector(WhitelistMintNotStarted.selector));
        zkSeeds.whitelistMint(1);
    }

    function testPresaleMintWhenNotWhitelisted() public {
        // Start the presale
        zkSeeds.setWlMintStarted(true);

        assertEq(zkSeeds.balanceOf(address(this)), 0);

        // mint 1 token during presale
        vm.expectRevert(abi.encodeWithSelector(AccountNotWhitlisted.selector));
        zkSeeds.whitelistMint(1);
    }

    function testPresaleExceedPresaleMintAmount() public {
        // Start the presale
        zkSeeds.setWlMintStarted(true);

        /* ------------------------------ First usecase ----------------------------- */

        // Whitelist address(this) and user1
        zkSeeds.whitelist(address(this), 2);

        // Mint a first NFT
        zkSeeds.whitelistMint(1);
        // Mint a second one
        zkSeeds.whitelistMint(1);
        // Mint a thired one
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.whitelistMint(1);


        /* ----------------------------- second usecase ----------------------------- */

        // Whitelist address(this) and user1
        zkSeeds.whitelist(user1, 5);

        vm.startPrank(user1);

        // Mint a first NFT
        zkSeeds.whitelistMint(5);
        // Mint a thired one
        vm.expectRevert(abi.encodeWithSelector(MaxMintAmountExceeded.selector));
        zkSeeds.whitelistMint(1);

        vm.stopPrank();
    }
    
    function testWhitelistMintExceedMaxSupply() public {
        zkSeeds.setWlMintStarted(true);

        uint256 maxSupply = zkSeeds.MAX_SUPPLY();

        for(uint160 i = 1; i <= maxSupply; ++i){
            zkSeeds.whitelist(address(i), 1);
            vm.prank(address(i));
            zkSeeds.whitelistMint(1);
        }

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.whitelistMint(1);
    }

    /* -------------------------------------------------------------------------- */
    /*                              ONLY OWNER TESTS                              */
    /* -------------------------------------------------------------------------- */

    /* ------- Check that fail when a call is made by a non-owner account ------- */

    function testOnlyOwnerWhitelist() public {
        zkSeeds.whitelist(user1, 1);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.whitelist(user1, 1);
    }

    function testOnlyOwnerMultipleWhitelist() public {
        address[] memory accounts = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory amounts2 = new uint256[](2);

        accounts[0] = user1;
        amounts[0] = 1;

        zkSeeds.whitelist(accounts, amounts);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmountLength.selector));
        zkSeeds.whitelist(accounts, amounts2);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.whitelist(accounts, amounts);
    }

    function testOnlyOwnerUpdateBaseUri() public {
        zkSeeds.updateBaseUri("test");

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.updateBaseUri("test");
    }

    function testOnlyOwnerSetMintStarted() public {
        zkSeeds.setMintStarted(true);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.setMintStarted(true);
    }

    function testOnlyOwnerSetWlMintStarted() public {
        zkSeeds.setWlMintStarted(true);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.setWlMintStarted(true);
    }

    function testOnlyOwnerSetMaxMintPerAccount() public {
        zkSeeds.setMaxMintPerAccount(2);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        zkSeeds.setMaxMintPerAccount(2);
    }

    function testBatchMint() public {
        assertEq(zkSeeds.balanceOf(user1), 0);
        assertEq(zkSeeds.balanceOf(user2), 0);

        // mint 1000 token
        zkSeeds.batchMint(200, user1);

        assertEq(zkSeeds.balanceOf(user1), 200);

        // mint more tokens
        zkSeeds.batchMint(200, user2);

        assertEq(zkSeeds.balanceOf(user2), 200);

        vm.expectRevert(abi.encodeWithSelector(MaxSupplyExceeded.selector));
        zkSeeds.batchMint(5601, user3);
    }

    /* --------------------------- Only owner features -------------------------- */

    function testWhitelist() public {
        assertEq(zkSeeds.whitelisted(user1), 0);
        zkSeeds.whitelist(user1, 10);
        assertEq(zkSeeds.whitelisted(user1), 10);
    }

    function testMassiveWhitelist() public {
        address[] memory accounts = new address[](1000);
        uint256[] memory amounts = new uint256[](1000);

        for(uint160 i = 1; i < 1000; ++i){
            accounts[i] = address(i);
            amounts[i] = 10;
        }

        zkSeeds.whitelist(accounts, amounts);
    }

    function testMultipleWhitelist() public {
        address[] memory accounts = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        accounts[0] = address(this);
        accounts[1] = user1;
        accounts[2] = user2;
        
        amounts[0] = 600;
        amounts[1] = 10;
        amounts[2] = 20;


        assertEq(zkSeeds.whitelisted(address(this)), 0);
        assertEq(zkSeeds.whitelisted(user1), 0);
        assertEq(zkSeeds.whitelisted(user2), 0);

        zkSeeds.whitelist(accounts, amounts);

        assertEq(zkSeeds.whitelisted(address(this)), 600);
        assertEq(zkSeeds.whitelisted(user1), 10);
        assertEq(zkSeeds.whitelisted(user2), 20);
    }

    function testUpdateMaxMintPerAccount() public {
        assertEq(zkSeeds.maxMintPerAccount(), 11);
        zkSeeds.setMaxMintPerAccount(2);
        assertEq(zkSeeds.maxMintPerAccount(), 2);
    }

    function testUpdateBaseUri() public {
        assertEq(zkSeeds.baseUri(), "https://zkveggies.com/");
        zkSeeds.updateBaseUri("test");
        assertEq(zkSeeds.baseUri(), "test");
    }

    function testSetMintStarted() public {
        assertEq(zkSeeds.mintStarted(), false);
        zkSeeds.setMintStarted(true);
        assertEq(zkSeeds.mintStarted(), true);
    }

    function testSetWlMintStarted() public {
        assertEq(zkSeeds.wlMintStarted(), false);
        zkSeeds.setWlMintStarted(true);
        assertEq(zkSeeds.wlMintStarted(), true);
    }

}

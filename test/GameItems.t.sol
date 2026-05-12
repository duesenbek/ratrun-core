// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/GameItems.sol";

contract GameItemsTest is Test {
    GameItems public items;

    address public admin   = address(this);
    address public minter  = makeAddr("minter");
    address public burner  = makeAddr("burner");
    address public player  = makeAddr("player");
    address public attacker = makeAddr("attacker");

    string constant URI = "https://ratrun.io/api/items/{id}.json";

    function setUp() public {
        items = new GameItems(URI);

        // Grant roles
        items.grantRole(items.MINTER_ROLE(), minter);
        items.grantRole(items.BURNER_ROLE(), burner);
    }

    // ─────────────────────────────────────────────
    // MINT
    // ─────────────────────────────────────────────

    function test_Mint_Success() public {
        vm.prank(minter);
        items.mint(player, GameItems.SCRAP, 100, "");

        assertEq(items.balanceOf(player, GameItems.SCRAP), 100);
    }

    function test_Mint_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit GameItems.ItemMinted(player, GameItems.SCRAP, 100, GameItems.Rarity.COMMON);

        vm.prank(minter);
        items.mint(player, GameItems.SCRAP, 100, "");
    }

    // ─────────────────────────────────────────────
    // BATCH MINT
    // ─────────────────────────────────────────────

    function test_MintBatch_Success() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = GameItems.SCRAP;
        ids[1] = GameItems.BATTERY;
        ids[2] = GameItems.CHIP;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 500;
        amounts[1] = 10;
        amounts[2] = 5;

        vm.prank(minter);
        items.mintBatch(player, ids, amounts, "");

        assertEq(items.balanceOf(player, GameItems.SCRAP),   500);
        assertEq(items.balanceOf(player, GameItems.BATTERY), 10);
        assertEq(items.balanceOf(player, GameItems.CHIP),    5);
    }

    // ─────────────────────────────────────────────
    // BURN
    // ─────────────────────────────────────────────

    function test_Burn_Success() public {
        // Mint first
        vm.prank(minter);
        items.mint(player, GameItems.BATTERY, 10, "");

        // Burn via burner role
        vm.expectEmit(true, true, false, true);
        emit GameItems.ItemBurned(player, GameItems.BATTERY, 5);

        vm.prank(burner);
        items.burnFrom(player, GameItems.BATTERY, 5);

        assertEq(items.balanceOf(player, GameItems.BATTERY), 5);
    }

    function test_Burn_RevertsIfInsufficientBalance() public {
        vm.prank(minter);
        items.mint(player, GameItems.WIRE, 3, "");

        vm.prank(burner);
        vm.expectRevert();
        items.burnFrom(player, GameItems.WIRE, 10); // burn more than balance
    }

    // ─────────────────────────────────────────────
    // UNAUTHORIZED MINT
    // ─────────────────────────────────────────────

    function test_UnauthorizedMint_Reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        items.mint(attacker, GameItems.SERVER, 1, "");
    }

    function test_UnauthorizedBurn_Reverts() public {
        vm.prank(minter);
        items.mint(player, GameItems.GPU, 1, "");

        vm.prank(attacker);
        vm.expectRevert();
        items.burnFrom(player, GameItems.GPU, 1);
    }

    // ─────────────────────────────────────────────
    // BALANCES
    // ─────────────────────────────────────────────

    function test_Balances_StartsAtZero() public view {
        assertEq(items.balanceOf(player, GameItems.RELIC), 0);
    }

    function test_Balances_AfterMintAndBurn() public {
        vm.startPrank(minter);
        items.mint(player, GameItems.DRILL, 20, "");
        vm.stopPrank();

        vm.prank(burner);
        items.burnFrom(player, GameItems.DRILL, 7);

        assertEq(items.balanceOf(player, GameItems.DRILL), 13);
    }

    // ─────────────────────────────────────────────
    // RARITY
    // ─────────────────────────────────────────────

    function test_Rarity_CorrectlyAssigned() public view {
        assertEq(uint256(items.itemRarity(GameItems.SCRAP)),   uint256(GameItems.Rarity.COMMON));
        assertEq(uint256(items.itemRarity(GameItems.CHIP)),    uint256(GameItems.Rarity.UNCOMMON));
        assertEq(uint256(items.itemRarity(GameItems.RELIC)),   uint256(GameItems.Rarity.RARE));
        assertEq(uint256(items.itemRarity(GameItems.GPU)),     uint256(GameItems.Rarity.EPIC));
        assertEq(uint256(items.itemRarity(GameItems.SERVER)),  uint256(GameItems.Rarity.LEGENDARY));
    }

    // ─────────────────────────────────────────────
    // SUPPLY TRACKING
    // ─────────────────────────────────────────────

    function test_TotalSupply_TrackedCorrectly() public {
        vm.prank(minter);
        items.mint(player, GameItems.SCRAP, 1000, "");

        assertEq(items.totalSupply(GameItems.SCRAP), 1000);

        vm.prank(burner);
        items.burnFrom(player, GameItems.SCRAP, 400);

        assertEq(items.totalSupply(GameItems.SCRAP), 600);
    }

    // ─────────────────────────────────────────────
    // URI
    // ─────────────────────────────────────────────

    function test_URI_CanBeUpdatedByAdmin() public {
        string memory newUri = "https://new.ratrun.io/{id}";
        items.setURI(newUri);
        // ERC1155 stores URI internally; just ensure no revert
    }

    function test_URI_CannotBeUpdatedByNonAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        items.setURI("https://hack.example.com/{id}");
    }

    // ─────────────────────────────────────────────
    // FUZZ
    // ─────────────────────────────────────────────

    function testFuzz_Mint_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.prank(minter);
        items.mint(player, GameItems.SCRAP, amount, "");
        assertEq(items.balanceOf(player, GameItems.SCRAP), amount);
    }
}

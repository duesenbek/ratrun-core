// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/GameItems.sol";

contract GameItemsTest is Test {
    GameItems public items;

    address public admin = address(this);
    address public minter = makeAddr("minter");
    address public burner = makeAddr("burner");
    address public player = makeAddr("player");
    address public attacker = makeAddr("attacker");

    string constant URI = "";

    uint256 constant SCRAP = 0;
    uint256 constant BATTERY = 1;
    uint256 constant WIRE = 2;
    uint256 constant CHIP = 3;
    uint256 constant RELIC = 4;
    uint256 constant DRILL = 5;
    uint256 constant GPU = 6;
    uint256 constant SERVER = 7;

    function setUp() public {
        items = new GameItems(URI);
        items.grantRole(items.MINTER_ROLE(), minter);
        items.grantRole(items.BURNER_ROLE(), burner);
    }

    function test_Mint_Success() public {
        vm.prank(minter);
        items.mint(player, SCRAP, 100, "");
        assertEq(items.balanceOf(player, SCRAP), 100);
    }

    function test_Mint_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit GameItems.ItemMinted(player, SCRAP, 100, GameItems.Rarity.COMMON);
        vm.prank(minter);
        items.mint(player, SCRAP, 100, "");
    }

    function test_MintBatch_Success() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = SCRAP;
        ids[1] = BATTERY;
        ids[2] = CHIP;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 500;
        amounts[1] = 10;
        amounts[2] = 5;

        vm.prank(minter);
        items.mintBatch(player, ids, amounts, "");

        assertEq(items.balanceOf(player, SCRAP), 500);
        assertEq(items.balanceOf(player, BATTERY), 10);
        assertEq(items.balanceOf(player, CHIP), 5);
    }

    function test_Burn_Success() public {
        vm.prank(minter);
        items.mint(player, BATTERY, 10, "");

        vm.expectEmit(true, true, false, true);
        emit GameItems.ItemBurned(player, BATTERY, 5);

        vm.prank(burner);
        items.burnFrom(player, BATTERY, 5);

        assertEq(items.balanceOf(player, BATTERY), 5);
    }

    function test_Burn_RevertsIfInsufficientBalance() public {
        vm.prank(minter);
        items.mint(player, WIRE, 3, "");

        vm.prank(burner);
        vm.expectRevert();
        items.burnFrom(player, WIRE, 10);
    }

    function test_UnauthorizedMint_Reverts() public {
        vm.prank(attacker);
        vm.expectRevert();
        items.mint(attacker, SERVER, 1, "");
    }

    function test_UnauthorizedBurn_Reverts() public {
        vm.prank(minter);
        items.mint(player, GPU, 1, "");

        vm.prank(attacker);
        vm.expectRevert();
        items.burnFrom(player, GPU, 1);
    }

    function test_Balances_StartsAtZero() public view {
        assertEq(items.balanceOf(player, RELIC), 0);
    }

    function test_Balances_AfterMintAndBurn() public {
        vm.startPrank(minter);
        items.mint(player, DRILL, 20, "");
        vm.stopPrank();

        vm.prank(burner);
        items.burnFrom(player, DRILL, 7);

        assertEq(items.balanceOf(player, DRILL), 13);
    }

    function test_Rarity_CorrectlyAssigned() public view {
        assertEq(
            uint256(items.itemRarity(SCRAP)),
            uint256(GameItems.Rarity.COMMON)
        );
        assertEq(
            uint256(items.itemRarity(CHIP)),
            uint256(GameItems.Rarity.UNCOMMON)
        );
        assertEq(
            uint256(items.itemRarity(RELIC)),
            uint256(GameItems.Rarity.RARE)
        );
        assertEq(
            uint256(items.itemRarity(GPU)),
            uint256(GameItems.Rarity.EPIC)
        );
        assertEq(
            uint256(items.itemRarity(SERVER)),
            uint256(GameItems.Rarity.LEGENDARY)
        );
    }

    function test_TotalSupply_TrackedCorrectly() public {
        vm.prank(minter);
        items.mint(player, SCRAP, 1000, "");

        assertEq(items.totalSupply(SCRAP), 1000);

        vm.prank(burner);
        items.burnFrom(player, SCRAP, 400);

        assertEq(items.totalSupply(SCRAP), 600);
    }

    function test_URI_CanBeUpdatedByAdmin() public {
        string memory newUri = "ipfs://Qmdummy/{id}";
        items.setURI(newUri);
    }

    function test_URI_CannotBeUpdatedByNonAdmin() public {
        vm.prank(attacker);
        vm.expectRevert();
        items.setURI("https://hack.example.com/{id}");
    }

    function testFuzz_Mint_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.prank(minter);
        items.mint(player, SCRAP, amount, "");
        assertEq(items.balanceOf(player, SCRAP), amount);
    }
}

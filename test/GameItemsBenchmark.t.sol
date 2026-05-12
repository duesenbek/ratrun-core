// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/GameItems.sol";

contract GameItemsBenchmarkTest is Test {
    GameItems public items;
    address public player = makeAddr("player");
    address public minter = makeAddr("minter");

    function setUp() public {
        items = new GameItems("testURI");
        items.grantRole(items.MINTER_ROLE(), minter);

        vm.startPrank(minter);
        items.mint(player, GameItems.SCRAP,   100, "");
        items.mint(player, GameItems.BATTERY, 50, "");
        items.mint(player, GameItems.WIRE,    25, "");
        items.mint(player, GameItems.CHIP,    10, "");
        items.mint(player, GameItems.RELIC,   5, "");
        items.mint(player, GameItems.DRILL,   2, "");
        items.mint(player, GameItems.GPU,     1, "");
        items.mint(player, GameItems.SERVER,  1, "");
        vm.stopPrank();
    }

    function test_TotalInventoryBalance_Correctness() public {
        uint256 expectedTotal = 100 + 50 + 25 + 10 + 5 + 2 + 1 + 1; // 194
        assertEq(items.totalInventoryBalance(player), expectedTotal);
    }
}

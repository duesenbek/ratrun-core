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
        items.mint(player, 0, 100, ""); // SCRAP
        items.mint(player, 1, 50, ""); // BATTERY
        items.mint(player, 2, 25, ""); // WIRE
        items.mint(player, 3, 10, ""); // CHIP
        items.mint(player, 4, 5, ""); // RELIC
        items.mint(player, 5, 2, ""); // DRILL
        items.mint(player, 6, 1, ""); // GPU
        items.mint(player, 7, 1, ""); // SERVER
        vm.stopPrank();
    }

    function test_TotalInventoryBalance_Correctness() public {
        uint256 expectedTotal = 100 + 50 + 25 + 10 + 5 + 2 + 1 + 1; // 194
        assertEq(items.totalInventoryBalance(player), expectedTotal);
    }
}

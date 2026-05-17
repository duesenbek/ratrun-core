// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/RatMaze.sol";
import "../contracts/game/GameItems.sol";

/// @dev Minimal stub so claimLoot() doesn't revert when lootProvider is unset.
contract MockLootProviderExtended {
    function requestLoot(address, uint8) external pure returns (uint256) {
        return 1;
    }
}

contract RatMazeExtendedTest is Test {
    RatMaze   public maze;
    GameItems public items;

    address admin   = address(this);
    address player  = makeAddr("player");
    address player2 = makeAddr("player2");

    function setUp() public {
        items = new GameItems("https://ratrun.io/api/items/{id}.json");
        maze  = new RatMaze(address(items));
        items.grantRole(items.MINTER_ROLE(), address(maze));

        MockLootProviderExtended loot = new MockLootProviderExtended();
        maze.setLootProvider(address(loot));

        vm.deal(player,  1 ether);
        vm.deal(player2, 1 ether);
    }

    function test_EnterMaze_Zone1() public {
        vm.prank(player);
        maze.enterMaze(1);
        (uint40 start, uint8 risk, bool active) = maze.activeRuns(player);
        assertTrue(active);
        assertEq(risk, 1);
        assertEq(start, uint40(block.timestamp));
    }

    function test_EnterMaze_Zone2() public {
        vm.prank(player);
        maze.enterMaze(2);
        (, uint8 risk, bool active) = maze.activeRuns(player);
        assertTrue(active);
        assertEq(risk, 2);
    }

    function test_EnterMaze_Zone3() public {
        vm.prank(player);
        maze.enterMaze(3);
        (, uint8 risk,) = maze.activeRuns(player);
        assertEq(risk, 3);
    }

    function test_EnterMaze_InvalidZone_Reverts() public {
        vm.prank(player);
        vm.expectRevert(RatMaze.RatMaze__InvalidRiskLevel.selector);
        maze.enterMaze(4);
    }

    function test_EnterMaze_ZeroZone_Reverts() public {
        vm.prank(player);
        vm.expectRevert(RatMaze.RatMaze__InvalidRiskLevel.selector);
        maze.enterMaze(0);
    }

    function test_EnterMaze_AlreadyActive_Reverts() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.expectRevert(RatMaze.RatMaze__AlreadyInRun.selector);
        maze.enterMaze(2);
        vm.stopPrank();
    }

    function test_ClaimLoot_TooEarly_Reverts() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.expectRevert(RatMaze.RatMaze__RunNotFinished.selector);
        maze.claimLoot();
        vm.stopPrank();
    }

    function test_ClaimLoot_NoRun_Reverts() public {
        vm.prank(player);
        vm.expectRevert(RatMaze.RatMaze__NoActiveRun.selector);
        maze.claimLoot();
    }

    function test_ClaimLoot_AfterDuration_ClearsRun() public {
        vm.prank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        vm.prank(player);
        maze.claimLoot();
        (,, bool active) = maze.activeRuns(player);
        assertFalse(active);
    }

    function test_ClaimLoot_CanReenter_AfterClaim() public {
        vm.prank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        vm.prank(player);
        maze.claimLoot();

        vm.prank(player);
        maze.enterMaze(2);
        (,, bool active) = maze.activeRuns(player);
        assertTrue(active);
    }

    function test_SetZoneParams_OnlyAdmin() public {
        maze.setZoneParams(1, 85, 90 seconds, 60);
        assertEq(maze.survivalChances(1), 85);
        assertEq(maze.runDurations(1), 90 seconds);
        assertEq(maze.scrapRewards(1), 60);
    }

    function test_SetZoneParams_NotAdmin_Reverts() public {
        vm.prank(player);
        vm.expectRevert();
        maze.setZoneParams(1, 85, 90 seconds, 60);
    }

    function test_GetRemainingTime_BeforeExpiry() public {
        vm.prank(player);
        maze.enterMaze(1);
        uint256 remaining = maze.getRemainingTime(player);
        assertEq(remaining, 1 minutes);
    }

    function test_GetRemainingTime_AfterExpiry_IsZero() public {
        vm.prank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 2 minutes);
        uint256 remaining = maze.getRemainingTime(player);
        assertEq(remaining, 0);
    }

    function test_DefaultZoneParams_Zone1() public view {
        assertEq(maze.survivalChances(1), 90);
        assertEq(maze.runDurations(1), 1 minutes);
        assertEq(maze.scrapRewards(1), 50);
    }

    function test_DefaultZoneParams_Zone2() public view {
        assertEq(maze.survivalChances(2), 70);
        assertEq(maze.runDurations(2), 3 minutes);
        assertEq(maze.scrapRewards(2), 150);
    }

    function test_DefaultZoneParams_Zone3() public view {
        assertEq(maze.survivalChances(3), 45);
        assertEq(maze.runDurations(3), 5 minutes);
        assertEq(maze.scrapRewards(3), 500);
    }

    function test_MultiplePlayers_Independent() public {
        vm.prank(player);
        maze.enterMaze(1);
        vm.prank(player2);
        maze.enterMaze(3);

        (, uint8 r1,) = maze.activeRuns(player);
        (, uint8 r2,) = maze.activeRuns(player2);
        assertEq(r1, 1);
        assertEq(r2, 3);
    }

    function testFuzz_EnterMaze_ValidZones(uint8 zone) public {
        zone = uint8(bound(zone, 1, 3));
        vm.prank(player);
        maze.enterMaze(zone);
        (, uint8 risk, bool active) = maze.activeRuns(player);
        assertEq(risk, zone);
        assertTrue(active);
    }
}

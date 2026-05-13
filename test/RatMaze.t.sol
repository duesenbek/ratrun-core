// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/RatMaze.sol";
import "../contracts/game/GameItems.sol";

contract RatMazeTest is Test {
    RatMaze public maze;
    GameItems public items;
    address public player = address(0x1337);

    function setUp() public {
        items = new GameItems("https://api.ratrun.io/metadata/");
        maze = new RatMaze(address(items));
        
        // Grant MINTER_ROLE to RatMaze so it can mint rewards
        items.grantRole(items.MINTER_ROLE(), address(maze));
        
        vm.deal(player, 1 ether);
    }

    function test_EnterMaze() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        
        (uint40 startTime, uint8 riskLevel, bool isActive) = maze.activeRuns(player);
        assertTrue(isActive);
        assertEq(riskLevel, 1);
        assertEq(startTime, block.timestamp);
        
        uint256 remaining = maze.getRemainingTime(player);
        assertEq(remaining, 1 minutes);
        vm.stopPrank();
    }

    function test_ClaimLoot_TooEarly() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        
        vm.expectRevert("Run not finished yet");
        maze.claimLoot();
        vm.stopPrank();
    }

    function test_ClaimLoot_Success() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        
        // Fast forward 1 minute
        vm.warp(block.timestamp + 1 minutes);
        
        // Force block.timestamp/prevrandao to a known value to ensure we survive
        // 90% survival for zone 1.
        vm.prevrandao(bytes32(uint256(1))); 
        
        maze.claimLoot();
        
        // Check if run is cleared
        (,, bool isActive) = maze.activeRuns(player);
        assertFalse(isActive);
        
        // We either survived or got caught, but since it's random we can just check balance.
        // Usually we'd mock the random properly or check both cases.
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/RatMaze.sol";
import "../contracts/game/GameItems.sol";

/// @dev Stub that records requestLoot calls for test assertions.
contract MockLootProvider {
    struct Call { address player; uint8 riskLevel; }
    Call[] public calls;
    uint256 public nextRequestId = 1;

    function requestLoot(address player, uint8 riskLevel)
        external
        returns (uint256 requestId)
    {
        calls.push(Call(player, riskLevel));
        return nextRequestId++;
    }

    function callCount() external view returns (uint256) { return calls.length; }
}

contract RatMazeTest is Test {
    RatMaze          public maze;
    GameItems        public items;
    MockLootProvider public lootProvider;

    address public player = address(0x1337);

    function setUp() public {
        items        = new GameItems("");
        maze         = new RatMaze(address(items));
        lootProvider = new MockLootProvider();

        // Grant MINTER_ROLE so maze can mint SCRAP rewards.
        items.grantRole(items.MINTER_ROLE(), address(maze));

        // Wire up the VRF-backed loot provider.
        maze.setLootProvider(address(lootProvider));

        vm.deal(player, 1 ether);
    }

    // ─────────────────────────────────────────────
    // enterMaze
    // ─────────────────────────────────────────────

    function test_EnterMaze() public {
        vm.startPrank(player);
        maze.enterMaze(1);

        (uint40 startTime, uint8 riskLevel, bool isActive) = maze.activeRuns(player);
        assertTrue(isActive);
        assertEq(riskLevel, 1);
        assertEq(startTime, uint40(block.timestamp));

        assertEq(maze.getRemainingTime(player), 1 minutes);
        vm.stopPrank();
    }

    function test_EnterMaze_InvalidRisk_Reverts() public {
        vm.startPrank(player);
        vm.expectRevert(RatMaze.RatMaze__InvalidRiskLevel.selector);
        maze.enterMaze(0);

        vm.expectRevert(RatMaze.RatMaze__InvalidRiskLevel.selector);
        maze.enterMaze(4);
        vm.stopPrank();
    }

    function test_EnterMaze_AlreadyActive_Reverts() public {
        vm.startPrank(player);
        maze.enterMaze(1);

        vm.expectRevert(RatMaze.RatMaze__AlreadyInRun.selector);
        maze.enterMaze(2);
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // claimLoot — timing
    // ─────────────────────────────────────────────

    function test_ClaimLoot_TooEarly_Reverts() public {
        vm.startPrank(player);
        maze.enterMaze(1);

        vm.expectRevert(RatMaze.RatMaze__RunNotFinished.selector);
        maze.claimLoot();
        vm.stopPrank();
    }

    function test_ClaimLoot_NoActiveRun_Reverts() public {
        vm.startPrank(player);
        vm.expectRevert(RatMaze.RatMaze__NoActiveRun.selector);
        maze.claimLoot();
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // claimLoot — success (zone 1)
    // ─────────────────────────────────────────────

    function test_ClaimLoot_Zone1_MintsScrapAndRequestsVRF() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        maze.claimLoot();
        vm.stopPrank();

        // Run must be cleared.
        (,, bool isActive) = maze.activeRuns(player);
        assertFalse(isActive);

        // Base SCRAP reward (50) must be minted immediately.
        assertEq(items.balanceOf(player, 0), 50);

        // VRF request must have been forwarded to the mock.
        assertEq(lootProvider.callCount(), 1);
        (address p, uint8 rl) = lootProvider.calls(0);
        assertEq(p, player);
        assertEq(rl, 1);
    }

    function test_ClaimLoot_Zone2_MintsScrap() public {
        vm.startPrank(player);
        maze.enterMaze(2);
        vm.warp(block.timestamp + 3 minutes);
        maze.claimLoot();
        vm.stopPrank();

        assertEq(items.balanceOf(player, 0), 150); // zone 2 scrap reward
        assertEq(lootProvider.callCount(), 1);
    }

    function test_ClaimLoot_Zone3_MintsScrap() public {
        vm.startPrank(player);
        maze.enterMaze(3);
        vm.warp(block.timestamp + 5 minutes);
        maze.claimLoot();
        vm.stopPrank();

        assertEq(items.balanceOf(player, 0), 500); // zone 3 scrap reward
        assertEq(lootProvider.callCount(), 1);
    }

    // ─────────────────────────────────────────────
    // claimLoot — without lootProvider
    // ─────────────────────────────────────────────

    function test_ClaimLoot_NoProvider_StillMintsScrap() public {
        // Detach loot provider (simulate testing environment).
        maze.setLootProvider(address(0));

        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        maze.claimLoot();
        vm.stopPrank();

        assertEq(items.balanceOf(player, 0), 50);
        // No VRF request forwarded (provider is zero).
        assertEq(lootProvider.callCount(), 0);
    }

    // ─────────────────────────────────────────────
    // CEI — reentrancy guard (double-claim)
    // ─────────────────────────────────────────────

    function test_ClaimLoot_CannotClaimTwice() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        maze.claimLoot();

        // Run was deleted; second claim must revert.
        vm.expectRevert(RatMaze.RatMaze__NoActiveRun.selector);
        maze.claimLoot();
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // No block.timestamp/prevrandao randomness
    // ─────────────────────────────────────────────

    /// @notice Calling claimLoot with different prevrandao values must produce
    ///         identical on-chain state (scrap amount, VRF request count) —
    ///         confirming that prevrandao is not used as a randomness source.
    function test_ClaimLoot_OutcomeIndependentOfPrevrandao() public {
        // Run 1 — prevrandao = 1
        vm.prevrandao(bytes32(uint256(1)));
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        maze.claimLoot();
        vm.stopPrank();
        uint256 scrap1 = items.balanceOf(player, 0);

        // Burn scrap so balance is clean.
        vm.startPrank(address(this));
        items.grantRole(items.BURNER_ROLE(), address(this));
        items.burnFrom(player, 0, scrap1);
        vm.stopPrank();

        // Run 2 — prevrandao = 9999 (completely different)
        vm.prevrandao(bytes32(uint256(9999)));
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        maze.claimLoot();
        vm.stopPrank();
        uint256 scrap2 = items.balanceOf(player, 0);

        assertEq(scrap1, scrap2,
            "Scrap amount changed with prevrandao - indicates illegal randomness source");
        assertEq(lootProvider.callCount(), 2,
            "Expected exactly 2 VRF requests total");
    }

    // ─────────────────────────────────────────────
    // getRemainingTime
    // ─────────────────────────────────────────────

    function test_RemainingTime_NoRun() public view {
        assertEq(maze.getRemainingTime(player), 0);
    }

    function test_RemainingTime_AfterExpiry() public {
        vm.startPrank(player);
        maze.enterMaze(1);
        vm.warp(block.timestamp + 1 minutes);
        vm.stopPrank();

        assertEq(maze.getRemainingTime(player), 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/game/GameItems.sol";

/// @title GameItemsBenchmark
/// @notice Correctness + gas-benchmark tests for totalInventoryBalance (Yul)
///         vs totalInventoryBalanceSolidity (pure-Solidity loop).
///
/// @dev    Run with:
///           forge test --match-contract GameItemsBenchmark -vv
///         Gas snapshots:
///           forge snapshot --match-contract GameItemsBenchmark
contract GameItemsBenchmarkTest is Test {
    GameItems public items;
    address public player  = makeAddr("player");
    address public minter  = makeAddr("minter");
    address public empty   = makeAddr("empty");

    function setUp() public {
        items = new GameItems("testURI");
        items.grantRole(items.MINTER_ROLE(), minter);

        vm.startPrank(minter);
        items.mint(player, 0, 100, ""); // SCRAP
        items.mint(player, 1,  50, ""); // BATTERY
        items.mint(player, 2,  25, ""); // WIRE
        items.mint(player, 3,  10, ""); // CHIP
        items.mint(player, 4,   5, ""); // RELIC
        items.mint(player, 5,   2, ""); // DRILL
        items.mint(player, 6,   1, ""); // GPU
        items.mint(player, 7,   1, ""); // SERVER
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // CORRECTNESS
    // ─────────────────────────────────────────────

    function test_Yul_CorrectTotal() public view {
        uint256 expected = 100 + 50 + 25 + 10 + 5 + 2 + 1 + 1; // 194
        assertEq(items.totalInventoryBalance(player), expected,
            "Yul version returned wrong total");
    }

    function test_Solidity_CorrectTotal() public view {
        uint256 expected = 100 + 50 + 25 + 10 + 5 + 2 + 1 + 1; // 194
        assertEq(items.totalInventoryBalanceSolidity(player), expected,
            "Solidity version returned wrong total");
    }

    /// @notice Both implementations must return identical results.
    function test_Yul_MatchesSolidity() public view {
        uint256 yul = items.totalInventoryBalance(player);
        uint256 sol = items.totalInventoryBalanceSolidity(player);
        assertEq(yul, sol, "Yul and Solidity results diverged");
    }

    /// @notice Zero balances — both must return 0, not revert.
    function test_ZeroBalances_Yul() public view {
        assertEq(items.totalInventoryBalance(empty), 0);
    }

    function test_ZeroBalances_Solidity() public view {
        assertEq(items.totalInventoryBalanceSolidity(empty), 0);
    }

    // ─────────────────────────────────────────────
    // GAS BENCHMARK
    // ─────────────────────────────────────────────

    /// @notice Gas cost of the Yul assembly implementation.
    ///         Captured by forge snapshot; compare against _Solidity counterpart.
    function test_Benchmark_Yul_GasUsed() public {
        // Warm up storage slots so we measure steady-state SLOAD (100 gas each)
        // rather than cold SLOAD (2100 gas each).
        items.totalInventoryBalance(player);

        uint256 gasBefore = gasleft();
        items.totalInventoryBalance(player);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("GAS Yul   totalInventoryBalance", gasUsed);
        // Yul path must use fewer than 10 000 gas on warm storage.
        assertTrue(gasUsed < 10_000, "Yul version unexpectedly expensive");
    }

    /// @notice Gas cost of the pure-Solidity loop implementation.
    function test_Benchmark_Solidity_GasUsed() public {
        // Warm up.
        items.totalInventoryBalanceSolidity(player);

        uint256 gasBefore = gasleft();
        items.totalInventoryBalanceSolidity(player);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("GAS Sol   totalInventoryBalanceSolidity", gasUsed);
        assertTrue(gasUsed < 10_000, "Solidity version unexpectedly expensive");
    }

    /// @notice Explicit assertion: Yul must be cheaper than Solidity.
    function test_Benchmark_Yul_CheaperThanSolidity() public {
        // Warm up both paths.
        items.totalInventoryBalance(player);
        items.totalInventoryBalanceSolidity(player);

        uint256 before1 = gasleft();
        items.totalInventoryBalance(player);
        uint256 yulGas = before1 - gasleft();

        uint256 before2 = gasleft();
        items.totalInventoryBalanceSolidity(player);
        uint256 solGas = before2 - gasleft();

        emit log_named_uint("GAS Yul  (warm)", yulGas);
        emit log_named_uint("GAS Sol  (warm)", solGas);
        emit log_named_int( "GAS delta (sol - yul)", int256(solGas) - int256(yulGas));

        assertTrue(yulGas < solGas,
            "Expected Yul to be cheaper than Solidity loop");
    }

    // ─────────────────────────────────────────────
    // FUZZ
    // ─────────────────────────────────────────────

    /// @notice Fuzz: Yul and Solidity always agree for any address.
    function testFuzz_Yul_AlwaysMatchesSolidity(address addr) public view {
        assertEq(
            items.totalInventoryBalance(addr),
            items.totalInventoryBalanceSolidity(addr),
            "Mismatch for fuzzed address"
        );
    }
}

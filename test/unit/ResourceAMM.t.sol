// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/market/ResourceAMM.sol";
import "../../contracts/market/LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Minimal ERC20 token for test setup.
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

/// @title ResourceAMM_UnitTest
/// @notice Unit tests for ResourceAMM (The Night Market).
/// @dev    Tests cover: liquidity add/remove, swaps, fees, slippage, k invariant.
contract ResourceAMM_UnitTest is Test {
    // ─────────────────────────────────────────────
    // SETUP
    // ─────────────────────────────────────────────

    MockERC20   internal scrap;
    MockERC20   internal battery;
    ResourceAMM internal amm;
    address     internal treasury = makeAddr("treasury");
    address     internal alice    = makeAddr("alice");
    address     internal bob      = makeAddr("bob");

    uint256 internal constant INITIAL_SCRAP   = 1_000_000e18;
    uint256 internal constant INITIAL_BATTERY = 500_000e18;

    function setUp() public {
        scrap   = new MockERC20("Scrap",   "SCRAP");
        battery = new MockERC20("Battery", "BATTERY");

        amm = new ResourceAMM(
            IERC20(address(scrap)),
            IERC20(address(battery)),
            "Night Market SCRAP/BATTERY LP",
            "nmSCRAP-BAT",
            treasury
        );

        // Fund alice
        scrap.mint(alice, 10_000_000e18);
        battery.mint(alice, 10_000_000e18);

        // Fund bob
        scrap.mint(bob, 1_000_000e18);
        battery.mint(bob, 1_000_000e18);
    }

    // ─────────────────────────────────────────────
    // ADD LIQUIDITY
    // ─────────────────────────────────────────────

    function test_AddLiquidity_FirstDeposit() public {
        vm.startPrank(alice);
        scrap.approve(address(amm), INITIAL_SCRAP);
        battery.approve(address(amm), INITIAL_BATTERY);

        (uint256 a0, uint256 a1, uint256 shares) = amm.addLiquidity(
            INITIAL_SCRAP,
            INITIAL_BATTERY,
            0,
            0,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(a0, INITIAL_SCRAP,   "amount0 mismatch");
        assertEq(a1, INITIAL_BATTERY, "amount1 mismatch");
        assertGt(shares, 0, "zero shares minted");

        (uint256 r0, uint256 r1) = amm.getReserves();
        assertEq(r0, INITIAL_SCRAP,   "reserve0 mismatch");
        assertEq(r1, INITIAL_BATTERY, "reserve1 mismatch");
    }

    function test_AddLiquidity_SubsequentDeposit_MaintainsRatio() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        // Bob adds proportional liquidity
        uint256 bobScrap   = 100_000e18;
        uint256 bobBattery = 500_000e18; // ratio is 2:1 scrap:battery, so optimal is 50_000e18 battery

        vm.startPrank(bob);
        scrap.approve(address(amm), bobScrap);
        battery.approve(address(amm), bobBattery);

        (, uint256 a1, ) = amm.addLiquidity(
            bobScrap,
            bobBattery,
            0,
            0,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();

        // Should have used proportional battery amount (50_000e18), not the full 500_000e18
        assertLe(a1, 50_001e18, "used more battery than ratio requires");
    }

    function test_AddLiquidity_RevertOn_DeadlineExpired() public {
        vm.startPrank(alice);
        scrap.approve(address(amm), INITIAL_SCRAP);
        battery.approve(address(amm), INITIAL_BATTERY);

        vm.expectRevert(ResourceAMM.AMM__DeadlineExpired.selector);
        amm.addLiquidity(
            INITIAL_SCRAP,
            INITIAL_BATTERY,
            0,
            0,
            alice,
            block.timestamp - 1 // expired
        );
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // REMOVE LIQUIDITY
    // ─────────────────────────────────────────────

    function test_RemoveLiquidity_FullWithdraw() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        LPToken lp = amm.lpToken();
        uint256 shares = lp.balanceOf(alice);

        uint256 scrapBefore   = scrap.balanceOf(alice);
        uint256 batteryBefore = battery.balanceOf(alice);

        vm.startPrank(alice);
        lp.approve(address(amm), shares);
        (uint256 a0, uint256 a1) = amm.removeLiquidity(
            shares,
            0,
            0,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(a0, 0, "zero scrap returned");
        assertGt(a1, 0, "zero battery returned");
        assertEq(scrap.balanceOf(alice),   scrapBefore   + a0, "scrap balance mismatch");
        assertEq(battery.balanceOf(alice), batteryBefore + a1, "battery balance mismatch");
    }

    function test_RemoveLiquidity_RevertOn_Slippage() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        LPToken lp = amm.lpToken();
        uint256 shares = lp.balanceOf(alice);

        vm.startPrank(alice);
        lp.approve(address(amm), shares);
        vm.expectRevert(ResourceAMM.AMM__SlippageExceeded.selector);
        amm.removeLiquidity(
            shares,
            type(uint256).max, // impossible min
            0,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // SWAP
    // ─────────────────────────────────────────────

    function test_Swap_ZeroForOne_OutputCalculation() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        uint256 swapIn  = 1_000e18;
        uint256 preview = amm.getAmountOut(swapIn, true);

        uint256 balBefore = battery.balanceOf(bob);

        vm.startPrank(bob);
        scrap.approve(address(amm), swapIn);
        uint256 out = amm.swapExactInput(
            swapIn,
            preview,
            true,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(out, preview, "swap output mismatch");
        assertEq(battery.balanceOf(bob), balBefore + out, "battery not received");
    }

    function test_Swap_OneForZero() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        uint256 swapIn  = 500e18;
        uint256 preview = amm.getAmountOut(swapIn, false);

        vm.startPrank(bob);
        battery.approve(address(amm), swapIn);
        uint256 out = amm.swapExactInput(
            swapIn,
            preview,
            false,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(out, preview, "reverse swap output mismatch");
    }

    function test_Swap_RevertOn_SlippageTooHigh() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        vm.startPrank(bob);
        scrap.approve(address(amm), 1_000e18);
        vm.expectRevert(ResourceAMM.AMM__SlippageExceeded.selector);
        amm.swapExactInput(
            1_000e18,
            type(uint256).max, // impossible min out
            true,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────
    // K INVARIANT
    // ─────────────────────────────────────────────

    function test_K_Invariant_AfterSwap() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        (uint256 r0Before, uint256 r1Before) = amm.getReserves();
        uint256 kBefore = r0Before * r1Before;

        vm.startPrank(bob);
        scrap.approve(address(amm), 10_000e18);
        amm.swapExactInput(10_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        (uint256 r0After, uint256 r1After) = amm.getReserves();
        uint256 kAfter = r0After * r1After;

        // k_after >= k_before (fees increase k)
        assertGe(kAfter, kBefore, "k invariant violated");
    }

    // ─────────────────────────────────────────────
    // TREASURY FEES
    // ─────────────────────────────────────────────

    function test_TreasuryFees_Accumulate() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        vm.startPrank(bob);
        scrap.approve(address(amm), 100_000e18);
        amm.swapExactInput(100_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        assertGt(amm.treasuryFees0(), 0, "no treasury fees accumulated");
    }

    function test_CollectTreasuryFees() public {
        _bootstrapLiquidity(alice, INITIAL_SCRAP, INITIAL_BATTERY);

        vm.startPrank(bob);
        scrap.approve(address(amm), 100_000e18);
        amm.swapExactInput(100_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        uint256 fee0 = amm.treasuryFees0();
        assertGt(fee0, 0);

        amm.collectTreasuryFees();

        assertEq(amm.treasuryFees0(), 0, "fees not zeroed");
        assertEq(scrap.balanceOf(treasury), fee0, "treasury did not receive fees");
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────

    function _bootstrapLiquidity(
        address provider,
        uint256 amount0,
        uint256 amount1
    ) internal {
        vm.startPrank(provider);
        scrap.approve(address(amm), amount0);
        battery.approve(address(amm), amount1);
        amm.addLiquidity(amount0, amount1, 0, 0, provider, block.timestamp + 1);
        vm.stopPrank();
    }
}

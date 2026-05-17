// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/market/ResourceAMM.sol";
import "../../contracts/market/LPToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ResourceAMM_UnitTest is Test {
    MockERC20 internal scrap;
    MockERC20 internal battery;
    MockERC20 internal token0; // sorted
    MockERC20 internal token1; // sorted
    ResourceAMM internal amm;
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_0 = 1_000_000e18;
    uint256 internal constant INITIAL_1 = 500_000e18;

    function setUp() public {
        scrap = new MockERC20("Scrap", "SCRAP");
        battery = new MockERC20("Battery", "BATTERY");

        // Determine sort order
        if (address(scrap) < address(battery)) {
            token0 = scrap;
            token1 = battery;
        } else {
            token0 = battery;
            token1 = scrap;
        }

        amm = new ResourceAMM(
            IERC20(address(scrap)),
            IERC20(address(battery)),
            "Night Market SCRAP/BATTERY LP",
            "nmSCRAP-BAT",
            treasury
        );

        token0.mint(alice, 10_000_000e18);
        token1.mint(alice, 10_000_000e18);
        token0.mint(bob, 1_000_000e18);
        token1.mint(bob, 1_000_000e18);

        vm.prank(alice);
        token0.approve(address(amm), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(amm), type(uint256).max);
    }

    function test_AddLiquidity_FirstDeposit() public {
        vm.startPrank(alice);
        (uint256 a0, uint256 a1, uint256 shares) = amm.addLiquidity(
            INITIAL_0,
            INITIAL_1,
            0,
            0,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(a0, INITIAL_0, "amount0 mismatch");
        assertEq(a1, INITIAL_1, "amount1 mismatch");
        assertGt(shares, 0, "zero shares minted");

        (uint256 r0, uint256 r1) = amm.getReserves();
        assertEq(r0, INITIAL_0, "reserve0 mismatch");
        assertEq(r1, INITIAL_1, "reserve1 mismatch");
    }

    function test_AddLiquidity_SubsequentDeposit_MaintainsRatio() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        vm.startPrank(bob);
        (, uint256 a1, ) = amm.addLiquidity(
            100_000e18,
            500_000e18,
            0,
            0,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertLe(a1, 50_001e18, "used more token1 than ratio requires");
    }

    function test_AddLiquidity_RevertOn_DeadlineExpired() public {
        vm.startPrank(alice);
        vm.expectRevert(ResourceAMM.AMM__DeadlineExpired.selector);
        amm.addLiquidity(
            INITIAL_0,
            INITIAL_1,
            0,
            0,
            alice,
            block.timestamp - 1
        );
        vm.stopPrank();
    }

    function test_RemoveLiquidity_FullWithdraw() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        LPToken lp = amm.lpToken();
        uint256 shares = lp.balanceOf(alice);

        uint256 bal0Before = token0.balanceOf(alice);
        uint256 bal1Before = token1.balanceOf(alice);

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

        assertGt(a0, 0, "zero token0 returned");
        assertGt(a1, 0, "zero token1 returned");
        assertEq(
            token0.balanceOf(alice),
            bal0Before + a0,
            "token0 balance mismatch"
        );
        assertEq(
            token1.balanceOf(alice),
            bal1Before + a1,
            "token1 balance mismatch"
        );
    }

    function test_RemoveLiquidity_RevertOn_Slippage() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        LPToken lp = amm.lpToken();
        uint256 shares = lp.balanceOf(alice);

        vm.startPrank(alice);
        lp.approve(address(amm), shares);
        vm.expectRevert(ResourceAMM.AMM__SlippageExceeded.selector);
        amm.removeLiquidity(
            shares,
            type(uint256).max,
            0,
            alice,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_Swap_ZeroForOne_OutputCalculation() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        uint256 swapIn = 1_000e18;
        uint256 preview = amm.getAmountOut(swapIn, true);
        uint256 bal1Before = token1.balanceOf(bob);

        vm.startPrank(bob);
        uint256 out = amm.swapExactInput(
            swapIn,
            preview,
            true,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(out, preview, "swap output mismatch");
        assertEq(
            token1.balanceOf(bob),
            bal1Before + out,
            "token1 not received"
        );
    }

    function test_Swap_OneForZero() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        uint256 swapIn = 500e18;
        uint256 preview = amm.getAmountOut(swapIn, false);

        vm.startPrank(bob);
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
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        vm.startPrank(bob);
        vm.expectRevert(ResourceAMM.AMM__SlippageExceeded.selector);
        amm.swapExactInput(
            1_000e18,
            type(uint256).max,
            true,
            bob,
            block.timestamp + 1
        );
        vm.stopPrank();
    }

    function test_K_Invariant_AfterSwap() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        (uint256 r0Before, uint256 r1Before) = amm.getReserves();
        uint256 kBefore = r0Before * r1Before;

        vm.startPrank(bob);
        amm.swapExactInput(10_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        (uint256 r0After, uint256 r1After) = amm.getReserves();
        assertGe(r0After * r1After, kBefore, "k invariant violated");
    }

    function test_TreasuryFees_Accumulate() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        vm.startPrank(bob);
        amm.swapExactInput(100_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        assertGt(amm.treasuryFees0(), 0, "no treasury fees accumulated");
    }

    function test_CollectTreasuryFees() public {
        _bootstrapLiquidity(alice, INITIAL_0, INITIAL_1);

        vm.startPrank(bob);
        amm.swapExactInput(100_000e18, 0, true, bob, block.timestamp + 1);
        vm.stopPrank();

        uint256 fee0 = amm.treasuryFees0();
        assertGt(fee0, 0);

        amm.collectTreasuryFees();

        assertEq(amm.treasuryFees0(), 0, "fees not zeroed");
        assertEq(
            token0.balanceOf(treasury),
            fee0,
            "treasury did not receive fees"
        );
    }

    function _bootstrapLiquidity(
        address provider,
        uint256 amount0,
        uint256 amount1
    ) internal {
        vm.startPrank(provider);
        amm.addLiquidity(amount0, amount1, 0, 0, provider, block.timestamp + 1);
        vm.stopPrank();
    }
}

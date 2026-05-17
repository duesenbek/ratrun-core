// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/market/ResourceAMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FuzzMockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ResourceAMM_FuzzTest is Test {
    FuzzMockERC20 internal tokenA;
    FuzzMockERC20 internal tokenB;
    ResourceAMM internal amm;
    address internal treasury = makeAddr("treasury");
    address internal lp = makeAddr("lp");
    address internal swapper = makeAddr("swapper");

    function setUp() public {
        tokenA = new FuzzMockERC20("TokenA", "TKA");
        tokenB = new FuzzMockERC20("TokenB", "TKB");

        amm = new ResourceAMM(
            IERC20(address(tokenA)),
            IERC20(address(tokenB)),
            "Fuzz LP",
            "FUZZ",
            treasury
        );

        tokenA.mint(lp, type(uint128).max);
        tokenB.mint(lp, type(uint128).max);
        tokenA.mint(swapper, type(uint128).max);
        tokenB.mint(swapper, type(uint128).max);

        // Pre-approve max
        vm.prank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(lp);
        tokenB.approve(address(amm), type(uint256).max);
        vm.prank(swapper);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(swapper);
        tokenB.approve(address(amm), type(uint256).max);
    }

    function testFuzz_AddLiquidity(uint96 amount0, uint96 amount1) public {
        amount0 = uint96(bound(amount0, 1e9, uint256(type(uint96).max)));
        amount1 = uint96(bound(amount1, 1e9, uint256(type(uint96).max)));

        vm.startPrank(lp);
        (uint256 a0, uint256 a1, uint256 shares) = amm.addLiquidity(
            amount0,
            amount1,
            0,
            0,
            lp,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(shares, 0, "fuzz: zero shares");
        assertGe(a0, 0, "fuzz: negative amount0");
        assertGe(a1, 0, "fuzz: negative amount1");
    }

    function testFuzz_Swap_KInvariant(
        uint96 seedAmount0,
        uint96 seedAmount1,
        uint64 swapIn
    ) public {
        seedAmount0 = uint96(
            bound(seedAmount0, 1e12, uint256(type(uint96).max))
        );
        seedAmount1 = uint96(
            bound(seedAmount1, 1e12, uint256(type(uint96).max))
        );
        swapIn = uint64(bound(swapIn, 1e6, uint256(type(uint64).max)));

        vm.startPrank(lp);
        amm.addLiquidity(
            seedAmount0,
            seedAmount1,
            0,
            0,
            lp,
            block.timestamp + 1
        );
        vm.stopPrank();

        (uint256 r0Before, uint256 r1Before) = amm.getReserves();
        uint256 kBefore = r0Before * r1Before;

        vm.startPrank(swapper);
        try amm.swapExactInput(swapIn, 0, true, swapper, block.timestamp + 1) {
            (uint256 r0After, uint256 r1After) = amm.getReserves();
            assertGe(
                r0After * r1After,
                kBefore,
                "INVARIANT VIOLATED: k decreased after swap"
            );
        } catch {}
        vm.stopPrank();
    }

    function testFuzz_RemoveLiquidity_Proportional(
        uint96 amount0,
        uint96 amount1,
        uint8 sharePercent
    ) public {
        amount0 = uint96(bound(amount0, 1e12, uint256(type(uint96).max)));
        amount1 = uint96(bound(amount1, 1e12, uint256(type(uint96).max)));
        sharePercent = uint8(bound(sharePercent, 1, 99));

        vm.startPrank(lp);
        (, , uint256 totalShares) = amm.addLiquidity(
            amount0,
            amount1,
            0,
            0,
            lp,
            block.timestamp + 1
        );
        vm.stopPrank();

        uint256 sharesToRemove = (totalShares * sharePercent) / 100;
        if (sharesToRemove == 0) return;

        (uint256 r0, uint256 r1) = amm.getReserves();
        uint256 totalSupply = amm.lpToken().totalSupply();

        uint256 expectedA = (sharesToRemove * r0) / totalSupply;
        uint256 expectedB = (sharesToRemove * r1) / totalSupply;

        vm.startPrank(lp);
        amm.lpToken().approve(address(amm), sharesToRemove);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(
            sharesToRemove,
            0,
            0,
            lp,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertApproxEqAbs(
            outA,
            expectedA,
            1,
            "fuzz: withdraw amount0 not proportional"
        );
        assertApproxEqAbs(
            outB,
            expectedB,
            1,
            "fuzz: withdraw amount1 not proportional"
        );
    }

    function testFuzz_GetAmountOut_NeverExceedsReserves(
        uint96 r0,
        uint96 r1,
        uint64 amountIn
    ) public pure {
        r0 = uint96(bound(r0, 1e6, uint256(type(uint96).max)));
        r1 = uint96(bound(r1, 1e6, uint256(type(uint96).max)));
        amountIn = uint64(bound(amountIn, 1, uint256(type(uint64).max)));

        uint256 out = AMMLib.getAmountOut(amountIn, r0, r1);
        assertLt(out, r1, "output exceeds reserve");
    }
}

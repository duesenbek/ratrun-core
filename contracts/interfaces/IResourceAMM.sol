// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IResourceAMM
/// @notice Interface for The Night Market AMM pool.
interface IResourceAMM {
    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event Swap(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        bool    zeroForOne,
        address indexed to
    );
    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    // ─────────────────────────────────────────────
    // CORE FUNCTIONS
    // ─────────────────────────────────────────────
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 shares);

    function removeLiquidity(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function swapExactInput(
        uint256 amountIn,
        uint256 amountOutMin,
        bool    zeroForOne,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    // ─────────────────────────────────────────────
    // VIEW HELPERS
    // ─────────────────────────────────────────────
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);

    function getAmountOut(uint256 amountIn, bool zeroForOne)
        external view returns (uint256 amountOut);

    function getAmountIn(uint256 amountOut, bool zeroForOne)
        external view returns (uint256 amountIn);

    function quote(uint256 amount0, uint256 reserve0, uint256 reserve1)
        external pure returns (uint256 amount1);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AMMLib
/// @notice Pure math library for the Night Market AMM (x*y=k constant product).
/// @dev    All functions are internal pure — no state, no calls.
library AMMLib {
    // ─────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────

    /// @dev Fee denominator (10000 = 100%). Fee = 30 bps (0.3%).
    uint256 internal constant FEE_DENOMINATOR = 10_000;

    /// @dev Protocol fee numerator: 30 bps = 0.30%.
    uint256 internal constant FEE_NUMERATOR   = 9_970; // (10000 - 30)

    /// @dev Minimum liquidity locked forever to prevent division by zero.
    uint256 internal constant MINIMUM_LIQUIDITY = 1_000;

    // ─────────────────────────────────────────────
    // CORE AMM MATH
    // ─────────────────────────────────────────────

    /// @notice Return the output amount for a given exact input (fee applied).
    /// @dev    Standard Uniswap V2 formula:
    ///         amountOut = (amountIn * 9970 * reserveOut) / (reserveIn * 10000 + amountIn * 9970)
    /// @param  amountIn   Exact input token amount.
    /// @param  reserveIn  Reserve of the input token.
    /// @param  reserveOut Reserve of the output token.
    /// @return amountOut  Output token amount after 0.3% fee.
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn   > 0, "AMMLib: INSUFFICIENT_INPUT");
        require(reserveIn  > 0 && reserveOut > 0, "AMMLib: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator       = amountInWithFee * reserveOut;
        uint256 denominator     = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Return the required input amount for a given exact output.
    /// @dev    Inverse of getAmountOut.
    ///         amountIn = (reserveIn * amountOut * 10000) / ((reserveOut - amountOut) * 9970) + 1
    /// @param  amountOut  Exact output token amount desired.
    /// @param  reserveIn  Reserve of the input token.
    /// @param  reserveOut Reserve of the output token.
    /// @return amountIn   Required input amount (ceiling).
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut  > 0, "AMMLib: INSUFFICIENT_OUTPUT");
        require(reserveIn  > 0 && reserveOut > amountOut, "AMMLib: INSUFFICIENT_LIQUIDITY");

        uint256 numerator   = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * FEE_NUMERATOR;
        amountIn = (numerator / denominator) + 1;
    }

    /// @notice Given an amount of token0 and reserves, return the equivalent token1.
    /// @dev    Simple ratio: amount1 = amount0 * reserve1 / reserve0.
    ///         Used for balanced liquidity adds.
    function quote(
        uint256 amount0,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 amount1) {
        require(amount0  > 0, "AMMLib: INSUFFICIENT_AMOUNT");
        require(reserve0 > 0 && reserve1 > 0, "AMMLib: INSUFFICIENT_LIQUIDITY");
        amount1 = (amount0 * reserve1) / reserve0;
    }

    /// @notice Compute initial LP shares for the first deposit.
    /// @dev    Geometric mean: sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY.
    ///         MINIMUM_LIQUIDITY is minted to address(0) to prevent manipulation.
    /// @return shares LP shares to mint to the provider.
    function initialShares(
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint256 shares) {
        uint256 product = amount0 * amount1;
        shares = sqrt(product);
        require(shares > MINIMUM_LIQUIDITY, "AMMLib: INSUFFICIENT_INITIAL_LIQUIDITY");
        shares -= MINIMUM_LIQUIDITY;
    }

    /// @notice Compute subsequent LP shares proportional to existing supply.
    /// @dev    shares = min(amount0/reserve0, amount1/reserve1) * totalSupply.
    ///         Takes the minimum to prevent dilution attacks.
    function subsequentShares(
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal pure returns (uint256 shares) {
        uint256 shares0 = (amount0 * totalSupply) / reserve0;
        uint256 shares1 = (amount1 * totalSupply) / reserve1;
        shares = shares0 < shares1 ? shares0 : shares1;
    }

    // ─────────────────────────────────────────────
    // BABYLONIAN SQRT
    // ─────────────────────────────────────────────

    /// @notice Integer square root (Babylonian method).
    /// @dev    Gas-efficient iterative approach. Used for initial LP shares.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IResourceAMM.sol";
import "../libraries/AMMLib.sol";
import "./LPToken.sol";

/// @title ResourceAMM
/// @notice "The Night Market" — a Uniswap V2-style constant-product AMM for RatRun ERC20 resources.
/// @dev    Architecture summary:
///         - x * y = k invariant enforced on every swap.
///         - 0.30% fee per swap (9970/10000), split:
///             • LP portion stays in reserves (auto-compounded via reserve growth).
///             • Treasury portion extracted to `treasury` address each swap.
///         - Liquidity mints/burns proportional LPToken shares.
///         - Deadline modifier prevents stale transaction execution.
///         - CEI (Checks-Effects-Interactions) pattern throughout.
///         - SafeERC20 + ReentrancyGuard for safety.
///         - Custom errors for gas-efficient reverts.
///
/// @dev    Storage layout:
///         - reserve0, reserve1:    cached token balances (packed into one slot via uint128).
///         - token0, token1:        immutable — set at deployment, never change.
///         - lpToken:               immutable LP share token.
///         - treasury:              protocol fee recipient.
///         - TREASURY_FEE_BPS:      1 bps out of every 30 bps fee goes to treasury.
contract ResourceAMM is IResourceAMM, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using AMMLib for uint256;

    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error AMM__DeadlineExpired();
    error AMM__InsufficientOutputAmount();
    error AMM__InsufficientInputAmount();
    error AMM__InsufficientLiquidity();
    error AMM__InvalidTokens();
    error AMM__ZeroAmount();
    error AMM__ZeroAddress();
    error AMM__SlippageExceeded();
    error AMM__K_Violated();

    // ─────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────

    /// @dev 5 bps of the 30 bps total fee routes to the treasury.
    uint256 public constant TREASURY_FEE_BPS = 5;
    uint256 public constant TOTAL_FEE_BPS = 30;
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MINIMUM_LIQUIDITY = AMMLib.MINIMUM_LIQUIDITY;

    // ─────────────────────────────────────────────
    // IMMUTABLES
    // ─────────────────────────────────────────────

    /// @notice The two ERC20 tokens forming this pool (token0 < token1 by address).
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    /// @notice LP share token for this pool.
    LPToken public immutable lpToken;

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    /// @notice Cached reserve of token0. Updated after every interaction.
    uint128 public reserve0;

    /// @notice Cached reserve of token1. Updated after every interaction.
    uint128 public reserve1;

    /// @notice Protocol treasury — receives TREASURY_FEE_BPS share of swap fees.
    address public treasury;

    /// @notice Accumulated treasury fees for token0 (claimable by treasury).
    uint256 public treasuryFees0;

    /// @notice Accumulated treasury fees for token1 (claimable by treasury).
    uint256 public treasuryFees1;

    // ─────────────────────────────────────────────
    // MODIFIER
    // ─────────────────────────────────────────────

    modifier beforeDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert AMM__DeadlineExpired();
        _;
    }

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param tokenA_    One of the two pool tokens.
    /// @param tokenB_    The other pool token.
    /// @param lpName_    LP token name.
    /// @param lpSymbol_  LP token symbol.
    /// @param treasury_  Initial treasury address.
    constructor(
        IERC20 tokenA_,
        IERC20 tokenB_,
        string memory lpName_,
        string memory lpSymbol_,
        address treasury_
    ) Ownable(msg.sender) {
        if (
            address(tokenA_) == address(0) ||
            address(tokenB_) == address(0) ||
            address(tokenA_) == address(tokenB_)
        ) revert AMM__InvalidTokens();
        if (treasury_ == address(0)) revert AMM__ZeroAddress();

        // Canonical ordering — lower address becomes token0
        (token0, token1) = address(tokenA_) < address(tokenB_)
            ? (tokenA_, tokenB_)
            : (tokenB_, tokenA_);

        treasury = treasury_;

        // Deploy LP token, grant AMM_ROLE to this contract
        lpToken = new LPToken(lpName_, lpSymbol_, address(this));
        lpToken.grantRole(lpToken.AMM_ROLE(), address(this));
    }

    // ─────────────────────────────────────────────
    // ADD LIQUIDITY
    // ─────────────────────────────────────────────

    /// @inheritdoc IResourceAMM
    /// @dev CEI: Check deadline/amounts → Effect: update reserves + mint LP → Interact: pull tokens.
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    )
        external
        override
        nonReentrant
        beforeDeadline(deadline)
        returns (uint256 amount0, uint256 amount1, uint256 shares)
    {
        if (amount0Desired == 0 || amount1Desired == 0)
            revert AMM__ZeroAmount();
        if (to == address(0)) revert AMM__ZeroAddress();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 totalSupply = lpToken.totalSupply();

        // ── Compute optimal amounts ───────────────
        if (totalSupply == 0) {
            // First deposit — take desired amounts directly
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            // Subsequent deposits — maintain current ratio
            uint256 amount1Optimal = AMMLib.quote(
                amount0Desired,
                _reserve0,
                _reserve1
            );
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert AMM__SlippageExceeded();
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = AMMLib.quote(
                    amount1Desired,
                    _reserve1,
                    _reserve0
                );
                if (amount0Optimal < amount0Min) revert AMM__SlippageExceeded();
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }

        // ── Compute LP shares ─────────────────────
        if (totalSupply == 0) {
            shares = AMMLib.initialShares(amount0, amount1);
            // Mint MINIMUM_LIQUIDITY to address(0) — permanently locked
            lpToken.mint(address(0xdead), MINIMUM_LIQUIDITY);
        } else {
            shares = AMMLib.subsequentShares(
                amount0,
                amount1,
                _reserve0,
                _reserve1,
                totalSupply
            );
        }

        if (shares == 0) revert AMM__InsufficientLiquidity();

        // ── Effects: update reserves ──────────────
        _updateReserves(_reserve0 + amount0, _reserve1 + amount1);

        // ── Interactions: pull tokens + mint LP ───
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);
        lpToken.mint(to, shares);

        emit LiquidityAdded(to, amount0, amount1, shares);
    }

    // ─────────────────────────────────────────────
    // REMOVE LIQUIDITY
    // ─────────────────────────────────────────────

    /// @inheritdoc IResourceAMM
    function removeLiquidity(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    )
        external
        override
        nonReentrant
        beforeDeadline(deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0) revert AMM__ZeroAmount();
        if (to == address(0)) revert AMM__ZeroAddress();

        uint256 totalSupply = lpToken.totalSupply();
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        // Proportional withdrawal
        amount0 = (shares * _reserve0) / totalSupply;
        amount1 = (shares * _reserve1) / totalSupply;

        if (amount0 < amount0Min || amount1 < amount1Min)
            revert AMM__SlippageExceeded();
        if (amount0 == 0 || amount1 == 0) revert AMM__InsufficientLiquidity();

        // ── Effects ───────────────────────────────
        _updateReserves(_reserve0 - amount0, _reserve1 - amount1);

        // ── Interactions ──────────────────────────
        lpToken.burn(msg.sender, shares);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);

        emit LiquidityRemoved(to, amount0, amount1, shares);
    }

    // ─────────────────────────────────────────────
    // SWAP
    // ─────────────────────────────────────────────

    /// @inheritdoc IResourceAMM
    /// @dev zeroForOne = true  → selling token0, buying token1.
    ///      zeroForOne = false → selling token1, buying token0.
    function swapExactInput(
        uint256 amountIn,
        uint256 amountOutMin,
        bool zeroForOne,
        address to,
        uint256 deadline
    )
        external
        override
        nonReentrant
        beforeDeadline(deadline)
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert AMM__InsufficientInputAmount();
        if (to == address(0)) revert AMM__ZeroAddress();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        // ── Compute output (fee-deducted) ─────────
        amountOut = zeroForOne
            ? AMMLib.getAmountOut(amountIn, _reserve0, _reserve1)
            : AMMLib.getAmountOut(amountIn, _reserve1, _reserve0);

        if (amountOut < amountOutMin) revert AMM__SlippageExceeded();

        // ── Compute treasury fee ──────────────────
        // Treasury receives TREASURY_FEE_BPS out of every TOTAL_FEE_BPS.
        // We calculate the fee on the gross amountIn.
        uint256 treasuryFee = (amountIn * TREASURY_FEE_BPS) / FEE_DENOMINATOR;

                // ── Effects: update reserves ──────────────
        if (zeroForOne) {
            // Selling token0, buying token1
            treasuryFees0 += treasuryFee;
            _updateReserves(
                _reserve0 + amountIn - treasuryFee,
                _reserve1 - amountOut
            );
        } else {
            // Selling token1, buying token0
            treasuryFees1 += treasuryFee;
            _updateReserves(
                _reserve0 - amountOut,
                _reserve1 + amountIn - treasuryFee
            );
        }

        // k invariant sanity check (CEI: check BEFORE interactions)
        _checkK(_reserve0, _reserve1);

        // ── Interactions ──────────────────────────
        IERC20 tokenIn = zeroForOne ? token0 : token1;
        IERC20 tokenOut = zeroForOne ? token1 : token0;

        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(to, amountOut);

        emit Swap(msg.sender, amountIn, amountOut, zeroForOne, to);
    }

    // ─────────────────────────────────────────────
    // TREASURY FEE CLAIM
    // ─────────────────────────────────────────────

    /// @notice Withdraw accumulated treasury fees to the treasury address.
    /// @dev    Callable by anyone — fees always route to `treasury`.
    function collectTreasuryFees() external nonReentrant {
        uint256 fee0 = treasuryFees0;
        uint256 fee1 = treasuryFees1;

        // Reset before transfer (CEI)
        treasuryFees0 = 0;
        treasuryFees1 = 0;

        if (fee0 > 0) token0.safeTransfer(treasury, fee0);
        if (fee1 > 0) token1.safeTransfer(treasury, fee1);
    }

    /// @notice Update the treasury address.
    /// @param  newTreasury New treasury recipient.
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert AMM__ZeroAddress();
        treasury = newTreasury;
    }

    // ─────────────────────────────────────────────
    // VIEW HELPERS
    // ─────────────────────────────────────────────

    /// @inheritdoc IResourceAMM
    function getReserves()
        external
        view
        override
        returns (uint256 r0, uint256 r1)
    {
        r0 = reserve0;
        r1 = reserve1;
    }

    /// @inheritdoc IResourceAMM
    function getAmountOut(
        uint256 amountIn,
        bool zeroForOne
    ) external view override returns (uint256) {
        return
            zeroForOne
                ? AMMLib.getAmountOut(amountIn, reserve0, reserve1)
                : AMMLib.getAmountOut(amountIn, reserve1, reserve0);
    }

    /// @inheritdoc IResourceAMM
    function getAmountIn(
        uint256 amountOut,
        bool zeroForOne
    ) external view override returns (uint256) {
        return
            zeroForOne
                ? AMMLib.getAmountIn(amountOut, reserve0, reserve1)
                : AMMLib.getAmountIn(amountOut, reserve1, reserve0);
    }

    /// @inheritdoc IResourceAMM
    function quote(
        uint256 amount0,
        uint256 reserveA,
        uint256 reserveB
    ) external pure override returns (uint256) {
        return AMMLib.quote(amount0, reserveA, reserveB);
    }

    // ─────────────────────────────────────────────
    // INTERNAL HELPERS
    // ─────────────────────────────────────────────

    /// @dev Update the cached reserves. Both values must fit in uint128.
    function _updateReserves(
        uint256 newReserve0,
        uint256 newReserve1
    ) internal {
        reserve0 = uint128(newReserve0);
        reserve1 = uint128(newReserve1);
    }

        /// @dev Assert k_after >= k_before. Reverts if the invariant is broken.
    ///      Reserves are uint128, so product fits in uint256 safely.
    function _checkK(uint256 prevReserve0, uint256 prevReserve1) internal view {
        unchecked {
            uint256 kBefore = prevReserve0 * prevReserve1;
            uint256 kAfter = uint256(reserve0) * uint256(reserve1);
            if (kAfter < kBefore) revert AMM__K_Violated();
        }
    }
}

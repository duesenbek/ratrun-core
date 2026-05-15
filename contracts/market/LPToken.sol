// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title LPToken
/// @notice ERC20 LP token representing proportional ownership in a Night Market pool.
/// @dev    Minting and burning are exclusively gated to the paired ResourceAMM contract
///         via the AMM_ROLE. LPs receive shares proportional to their liquidity
///         contribution; as fees accumulate in the pool the share price rises.
contract LPToken is ERC20, AccessControl {
    // ─────────────────────────────────────────────
    // ROLES
    // ─────────────────────────────────────────────

    /// @notice Role held exclusively by the paired ResourceAMM pool.
    bytes32 public constant AMM_ROLE = keccak256("AMM_ROLE");

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event SharesMinted(address indexed to,   uint256 amount);
    event SharesBurned(address indexed from, uint256 amount);

    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error LPToken__ZeroAmount();
    error LPToken__ZeroAddress();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param name_   Token name  (e.g. "Night Market SCRAP/BATTERY LP").
    /// @param symbol_ Token symbol (e.g. "nmSCRAP-BAT").
    /// @param admin_  Admin that will manage role assignments.
    constructor(
        string memory name_,
        string memory symbol_,
        address admin_
    ) ERC20(name_, symbol_) {
        if (admin_ == address(0)) revert LPToken__ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    // ─────────────────────────────────────────────
    // MINT / BURN — AMM-only
    // ─────────────────────────────────────────────

    /// @notice Mint LP shares to a liquidity provider.
    /// @dev    Called exclusively by the paired ResourceAMM on addLiquidity().
    /// @param  to     Recipient of the LP shares.
    /// @param  amount Number of shares to mint.
    function mint(address to, uint256 amount) external onlyRole(AMM_ROLE) {
        if (to     == address(0)) revert LPToken__ZeroAddress();
        if (amount == 0)          revert LPToken__ZeroAmount();
        _mint(to, amount);
        emit SharesMinted(to, amount);
    }

    /// @notice Burn LP shares from a liquidity provider.
    /// @dev    Called exclusively by the paired ResourceAMM on removeLiquidity().
    /// @param  from   Holder whose shares are burned.
    /// @param  amount Number of shares to burn.
    function burn(address from, uint256 amount) external onlyRole(AMM_ROLE) {
        if (from   == address(0)) revert LPToken__ZeroAddress();
        if (amount == 0)          revert LPToken__ZeroAmount();
        _burn(from, amount);
        emit SharesBurned(from, amount);
    }
}

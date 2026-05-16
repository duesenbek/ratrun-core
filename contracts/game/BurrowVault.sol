// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BurrowVault
/// @notice ERC4626 tokenised vault — "send gear into the underground burrow to earn passive scrap."
/// @dev Players deposit an ERC20 asset; yield accrues as the vault balance grows.
///      ReentrancyGuard prevents flash-loan re-entry on deposit/withdraw.
contract BurrowVault is ERC4626, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event Deposited(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdrawn(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param asset_    The ERC20 token deposited into the burrow (e.g. a SCRAP token).
    /// @param name_     Vault share token name  (e.g. "Burrow Scrap Share").
    /// @param symbol_   Vault share token symbol (e.g. "bSCRAP").
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC4626(asset_) ERC20(name_, symbol_) Ownable(msg.sender) {}

    // ─────────────────────────────────────────────
    // ERC4626 OVERRIDES — emit our custom events
    // ─────────────────────────────────────────────

    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        emit Deposited(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override nonReentrant returns (uint256 assets) {
        assets = super.mint(shares, receiver);
        emit Deposited(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256 shares) {
        shares = super.withdraw(assets, receiver, owner);
        emit Withdrawn(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256 assets) {
        assets = super.redeem(shares, receiver, owner);
        emit Withdrawn(msg.sender, receiver, owner, assets, shares);
    }

    // ─────────────────────────────────────────────
    // YIELD INJECTION (owner only — simulates reward distribution)
    // ─────────────────────────────────────────────

    /// @notice Owner injects yield by transferring assets directly into the vault.
    ///         This increases totalAssets() → share price rises → all holders earn.
    function injectYield(uint256 amount) external onlyOwner {
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
    }

    // ─────────────────────────────────────────────
    // PREVIEW HELPERS (inherited from ERC4626 — listed for docs clarity)
    // ─────────────────────────────────────────────
    // previewDeposit(uint256 assets) → shares
    // previewMint(uint256 shares)    → assets
    // previewWithdraw(uint256 assets)→ shares
    // previewRedeem(uint256 shares)  → assets
}

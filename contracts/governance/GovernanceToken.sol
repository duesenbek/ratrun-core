// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GovernanceToken
/// @notice "RAT" — ERC20Votes governance token for The Rat Council DAO.
/// @dev    Architecture summary:
///         - ERC20Votes (OpenZeppelin) provides vote delegation and historical
///           snapshot queries required by Governor.
///         - ERC20Permit enables gas-efficient off-chain approvals.
///         - Minting is gated by MINTER_ROLE — Treasury distributes tokens
///           as protocol rewards; governance can authorize new minters.
///         - Transferable to enable a liquid governance market.
///         - No maximum supply enforced at contract level — governance
///           controls emission through Treasury proposals.
contract GovernanceToken is ERC20Votes, ERC20Permit, AccessControl {
    // ─────────────────────────────────────────────
    // ROLES
    // ─────────────────────────────────────────────
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error GovernanceToken__ZeroAddress();
    error GovernanceToken__ZeroAmount();

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event RatMinted(address indexed to, uint256 amount);
    event RatBurned(address indexed from, uint256 amount);

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param admin_        Initial admin (governance multisig or deployer).
    /// @param initialSupply Initial RAT tokens minted to admin (bootstraps voting).
    constructor(address admin_, uint256 initialSupply)
        ERC20("Rat Governance Token", "RAT")
        ERC20Permit("Rat Governance Token")
    {
        if (admin_ == address(0)) revert GovernanceToken__ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);

        if (initialSupply > 0) {
            _mint(admin_, initialSupply);
            emit RatMinted(admin_, initialSupply);
        }
    }

    // ─────────────────────────────────────────────
    // MINT
    // ─────────────────────────────────────────────

    /// @notice Mint RAT tokens to `to`. Only MINTER_ROLE.
    /// @dev    Called by Treasury when distributing protocol rewards.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to     == address(0)) revert GovernanceToken__ZeroAddress();
        if (amount == 0)          revert GovernanceToken__ZeroAmount();
        _mint(to, amount);
        emit RatMinted(to, amount);
    }

    // ─────────────────────────────────────────────
    // BURN
    // ─────────────────────────────────────────────

    /// @notice Burn RAT tokens from caller's own balance.
    function burn(uint256 amount) external {
        if (amount == 0) revert GovernanceToken__ZeroAmount();
        _burn(msg.sender, amount);
        emit RatBurned(msg.sender, amount);
    }

    // ─────────────────────────────────────────────
    // OVERRIDES required by Solidity multi-inheritance
    // ─────────────────────────────────────────────

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./GovernanceToken.sol";

/// @title Treasury
/// @notice Protocol treasury for the RatRun DAO. Holds and distributes protocol funds.
/// @dev    Architecture:
///         - Controlled exclusively through the TimelockController (governance).
///           No multisig, no admin backdoors — all spending is DAO-voted.
///         - Holds ERC20 tokens (SCRAP, RAT, etc.) and native ETH.
///         - execute() allows the timelock to send any ERC20 or ETH to any recipient.
///         - mintReward() distributes RAT tokens as protocol incentives — requires
///           the Treasury to hold MINTER_ROLE on GovernanceToken.
///         - ReentrancyGuard on state-changing functions.
///         - SafeERC20 for all token transfers.
///         - Full event coverage for on-chain accounting.
///
///         Security:
///         - All external calls gated by onlyTimelock modifier.
///         - No tx.origin usage.
///         - CEI pattern throughout.
///         - Custom errors for clarity.
contract Treasury is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error Treasury__OnlyTimelock();
    error Treasury__ZeroAddress();
    error Treasury__ZeroAmount();
    error Treasury__InsufficientBalance();
    error Treasury__ETHTransferFailed();

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    /// @notice The TimelockController that governs this treasury.
    /// @dev    All fund movements require a timelock-executed proposal.
    address public immutable timelock;

    /// @notice Protocol governance token — Treasury can mint rewards.
    GovernanceToken public immutable govToken;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event ERC20Transferred(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event ETHTransferred(
        address indexed to,
        uint256 amount
    );
    event RewardMinted(
        address indexed to,
        uint256 amount
    );
    event ReceivedETH(address indexed from, uint256 amount);

    // ─────────────────────────────────────────────
    // MODIFIER
    // ─────────────────────────────────────────────

    /// @dev Restricts calls to the TimelockController only.
    ///      The timelock executes proposals that have passed the DAO vote.
    modifier onlyTimelock() {
        if (msg.sender != timelock) revert Treasury__OnlyTimelock();
        _;
    }

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param timelock_ TimelockController address — sole authority over treasury.
    /// @param govToken_ GovernanceToken address — for reward minting.
    constructor(address timelock_, address govToken_) {
        if (timelock_ == address(0)) revert Treasury__ZeroAddress();
        if (govToken_ == address(0)) revert Treasury__ZeroAddress();
        timelock = timelock_;
        govToken = GovernanceToken(govToken_);
    }

    // ─────────────────────────────────────────────
    // RECEIVE ETH
    // ─────────────────────────────────────────────

    receive() external payable {
        emit ReceivedETH(msg.sender, msg.value);
    }

    // ─────────────────────────────────────────────
    // FUND MOVEMENTS — Timelock-only
    // ─────────────────────────────────────────────

    /// @notice Transfer ERC20 tokens from the treasury to `to`.
    /// @dev    Only callable via TimelockController (DAO-approved proposal).
    /// @param  token  ERC20 token address.
    /// @param  to     Recipient address.
    /// @param  amount Token amount (in token's native decimals).
    function transferERC20(
        IERC20  token,
        address to,
        uint256 amount
    ) external onlyTimelock nonReentrant {
        if (to     == address(0)) revert Treasury__ZeroAddress();
        if (amount == 0)          revert Treasury__ZeroAmount();
        if (token.balanceOf(address(this)) < amount) revert Treasury__InsufficientBalance();

        token.safeTransfer(to, amount);
        emit ERC20Transferred(address(token), to, amount);
    }

    /// @notice Transfer native ETH from the treasury to `to`.
    /// @dev    Only callable via TimelockController.
    /// @param  to     Recipient address.
    /// @param  amount ETH amount in wei.
    function transferETH(
        address payable to,
        uint256 amount
    ) external onlyTimelock nonReentrant {
        if (to     == address(0)) revert Treasury__ZeroAddress();
        if (amount == 0)          revert Treasury__ZeroAmount();
        if (address(this).balance < amount) revert Treasury__InsufficientBalance();

        // CEI: update state before external call (ETH has no state to update here)
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert Treasury__ETHTransferFailed();

        emit ETHTransferred(to, amount);
    }

    /// @notice Mint RAT governance tokens as protocol rewards.
    /// @dev    Treasury must hold MINTER_ROLE on GovernanceToken.
    ///         Used for rewarding players, LPs, or contributors via proposals.
    /// @param  to     Reward recipient.
    /// @param  amount RAT amount to mint.
    function mintReward(
        address to,
        uint256 amount
    ) external onlyTimelock nonReentrant {
        if (to     == address(0)) revert Treasury__ZeroAddress();
        if (amount == 0)          revert Treasury__ZeroAmount();

        govToken.mint(to, amount);
        emit RewardMinted(to, amount);
    }

    // ─────────────────────────────────────────────
    // VIEW
    // ─────────────────────────────────────────────

    /// @notice ETH balance held by the treasury.
    function ethBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice ERC20 balance held by the treasury for a given token.
    function tokenBalance(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

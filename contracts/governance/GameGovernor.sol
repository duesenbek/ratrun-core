// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/// @title GameGovernor
/// @notice "The Rat Council" — OpenZeppelin Governor for the RatRun DAO.
/// @dev    Architecture:
///         - Inherits the full OZ Governor stack for battle-tested governance.
///         - GovernorSettings:            voting delay, voting period, proposal threshold.
///         - GovernorCountingSimple:      For, Against, Abstain vote counting.
///         - GovernorVotes:               Snapshot-based voting weight from GovernanceToken.
///         - GovernorVotesQuorumFraction: Percentage quorum relative to total supply.
///         - GovernorTimelockControl:     All passed proposals queue through TimelockController.
///
///         Settings (matching spec):
///         - Voting delay:          1 day (7200 blocks at 12s/block on Base Sepolia).
///         - Voting period:         5 days (36000 blocks).
///         - Proposal threshold:    1% of total supply (set via constructor).
///         - Quorum:                4% of total supply.
///
///         DAO Controls:
///         - Loot rates (via LootDrop.setCooldownDuration / LootDrop.setGameItems).
///         - Treasury spending (via Treasury.execute).
///         - AMM fees (via ResourceAMM.setTreasury / future fee governance).
///         - Protocol upgrades (via TimelockController role management).
contract GameGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param token_     GovernanceToken (ERC20Votes) address.
    /// @param timelock_  TimelockController address — all passed proposals queue here.
    constructor(
        IVotes              token_,
        TimelockController  timelock_
    )
        Governor("GameGovernor")
        GovernorSettings(
            7_200,  // voting delay:  ~1 day  (at 12s/block)
            36_000, // voting period: ~5 days
            0       // proposal threshold: overridden by quorum fraction below
        )
        GovernorVotes(token_)
        GovernorVotesQuorumFraction(4) // 4% quorum
        GovernorTimelockControl(timelock_)
    {}

    // ─────────────────────────────────────────────
    // PROPOSAL THRESHOLD — 1% of circulating supply
    // ─────────────────────────────────────────────

    /// @notice Minimum RAT tokens required to submit a proposal.
    /// @dev    1% of the current total supply (dynamic — scales with supply).
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return token().getPastTotalSupply(block.number - 1) / 100;
    }

    // ─────────────────────────────────────────────
    // REQUIRED OVERRIDES (multi-inheritance resolution)
    // ─────────────────────────────────────────────

    function votingDelay()
        public view override(Governor, GovernorSettings) returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public view override(Governor, GovernorSettings) returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public view override(Governor, GovernorVotesQuorumFraction) returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public view override(Governor, GovernorTimelockControl) returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public view override(Governor, GovernorTimelockControl) returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal view override(Governor, GovernorTimelockControl) returns (address)
    {
        return super._executor();
    }
}

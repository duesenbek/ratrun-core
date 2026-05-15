// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/governance/GovernanceToken.sol";
import "../contracts/governance/GameGovernor.sol";
import "../contracts/governance/Treasury.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeployGovernance
/// @notice Deploys the full Rat Council DAO stack on Base Sepolia.
/// @dev    Deployment order:
///         1. GovernanceToken (RAT) — with initial supply to deployer.
///         2. TimelockController    — min delay 2 days; proposers/executors set later.
///         3. GameGovernor          — wraps GovernanceToken + Timelock.
///         4. Treasury              — owned by Timelock.
///
///         Post-deployment:
///         - Grant TimelockController PROPOSER_ROLE to GameGovernor.
///         - Grant TimelockController EXECUTOR_ROLE to address(0) (anyone).
///         - Grant GovernanceToken MINTER_ROLE to Treasury.
///         - Renounce deployer's TimelockController admin.
///
///         Run: forge script script/DeployGovernance.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL \
///                  --broadcast --verify --etherscan-api-key $BASESCAN_KEY -vvv
contract DeployGovernance is Script {
    // ─────────────────────────────────────────────
    // CONFIG
    // ─────────────────────────────────────────────
    uint256 constant INITIAL_SUPPLY   = 1_000_000e18; // 1M RAT to deployer
    uint256 constant TIMELOCK_DELAY   = 2 days;       // min timelock delay

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("=== DeployGovernance ===");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);

        // ── 1. GovernanceToken (RAT) ──────────────
        GovernanceToken rat = new GovernanceToken(deployer, INITIAL_SUPPLY);
        console2.log("GovernanceToken (RAT) deployed:", address(rat));

        // ── 2. TimelockController ─────────────────
        address[] memory proposers = new address[](0); // set after governor deploy
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute after delay

        TimelockController timelock = new TimelockController(
            TIMELOCK_DELAY,
            proposers,
            executors,
            deployer // initial admin — will be renounced
        );
        console2.log("TimelockController deployed:", address(timelock));

        // ── 3. GameGovernor ───────────────────────
        GameGovernor governor = new GameGovernor(IVotes(address(rat)), timelock);
        console2.log("GameGovernor deployed:", address(governor));

        // ── 4. Treasury ───────────────────────────
        Treasury treasury = new Treasury(address(timelock), address(rat));
        console2.log("Treasury deployed:", address(treasury));

        // ── 5. Wire up roles ──────────────────────
        // Governor can propose to timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        console2.log("PROPOSER_ROLE granted to governor");

        // Treasury can mint RAT rewards
        rat.grantRole(rat.MINTER_ROLE(), address(treasury));
        console2.log("MINTER_ROLE granted to treasury");

        // Renounce deployer timelock admin (decentralize)
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        console2.log("Timelock admin renounced");

        vm.stopBroadcast();

        console2.log("=== DeployGovernance complete ===");
        console2.log("RAT token:       ", address(rat));
        console2.log("Timelock:        ", address(timelock));
        console2.log("Governor:        ", address(governor));
        console2.log("Treasury:        ", address(treasury));
    }
}

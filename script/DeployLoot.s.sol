// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/loot/LootDrop.sol";

/// @title DeployLoot
/// @notice Deploys LootDrop and wires it into the existing GameItems contract.
/// @dev    Prerequisites:
///         - GAME_ITEMS_ADDRESS in .env (deployed GameItems on Base Sepolia)
///         - VRF_WRAPPER_ADDRESS in .env (Chainlink VRFV2PlusWrapper on Base Sepolia)
///           Base Sepolia wrapper: 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
///
///         Post-deployment steps (manual):
///         - Grant LootDrop MINTER_ROLE on GameItems:
///           gameItems.grantRole(MINTER_ROLE, address(lootDrop))
///         - Grant MAZE_ROLE on LootDrop to the RatMaze contract:
///           lootDrop.grantRole(MAZE_ROLE, address(ratMaze))
///         - Fund LootDrop with LINK tokens for VRF payments.
///
///         Run: forge script script/DeployLoot.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL \
///                  --broadcast --verify --etherscan-api-key $BASESCAN_KEY -vvv
contract DeployLoot is Script {
    // ─────────────────────────────────────────────
    // CONFIG — override with real addresses
    // ─────────────────────────────────────────────

    /// @dev Chainlink VRFV2PlusWrapper on Base Sepolia.
    ///      Update from: https://docs.chain.link/vrf/v2-5/supported-networks
    address constant VRF_WRAPPER = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;

    address constant GAME_ITEMS = 0xdEadbeef00000000000000000000000000000004; // replace
    address constant RAT_MAZE = 0xDEadbEeF00000000000000000000000000000005; // replace

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== DeployLoot ===");
        console2.log("Deployer:   ", deployer);
        console2.log("GameItems:  ", GAME_ITEMS);
        console2.log("VRF Wrapper:", VRF_WRAPPER);

        vm.startBroadcast(deployerKey);

        // ── Deploy LootDrop ───────────────────────
        LootDrop lootDrop = new LootDrop(deployer, GAME_ITEMS, VRF_WRAPPER);
        console2.log("LootDrop deployed:", address(lootDrop));

        // ── Grant MAZE_ROLE to RatMaze ────────────
        lootDrop.grantRole(lootDrop.MAZE_ROLE(), RAT_MAZE);
        console2.log("MAZE_ROLE granted to RatMaze:", RAT_MAZE);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== MANUAL STEPS REQUIRED ===");
        console2.log(
            "1. Call gameItems.grantRole(MINTER_ROLE, ",
            address(lootDrop),
            ")"
        );
        console2.log("2. Fund LootDrop with LINK for VRF payments.");
        console2.log("=== DeployLoot complete ===");
    }
}

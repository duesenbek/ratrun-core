// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/market/MarketFactory.sol";
import "../contracts/market/ResourceAMM.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title DeployMarket
/// @notice Deploys MarketFactory and the initial SCRAP/BATTERY Night Market pool.
/// @dev    Target network: Base Sepolia.
///         Run: forge script script/DeployMarket.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL \
///                  --broadcast --verify --etherscan-api-key $BASESCAN_KEY -vvv
///
/// Prerequisites:
///   - DEPLOYER_PRIVATE_KEY in .env
///   - SCRAP_TOKEN_ADDRESS   in .env (or use existing GameItems SCRAP ERC20 wrapper)
///   - BATTERY_TOKEN_ADDRESS in .env
///   - TREASURY_ADDRESS      in .env
contract DeployMarket is Script {
        // ─────────────────────────────────────────────
    // CONFIG — read from .env
    // ─────────────────────────────────────────────
    address TREASURY = vm.envAddress("TREASURY_ADDRESS");
    address SCRAP_TOKEN = vm.envAddress("SCRAP_TOKEN_ADDRESS");
    address BATTERY_TOKEN = vm.envAddress("BATTERY_TOKEN_ADDRESS");

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== DeployMarket ===");
        console2.log("Deployer:", deployer);
        console2.log("Treasury:", TREASURY);

        vm.startBroadcast(deployerKey);

        // 1. Deploy MarketFactory
        MarketFactory factory = new MarketFactory(TREASURY);
        console2.log("MarketFactory deployed:", address(factory));

        // 2. Deploy SCRAP/BATTERY pool via factory
        address pool = factory.deployPool(
            IERC20(SCRAP_TOKEN),
            IERC20(BATTERY_TOKEN),
            "Night Market SCRAP/BATTERY LP",
            "nmSCRAP-BAT"
        );
        console2.log("SCRAP/BATTERY Pool deployed:", pool);
        console2.log("Pool LP token:", address(ResourceAMM(pool).lpToken()));

        // 3. Log deterministic address (for verification)
        address predicted = factory.computePoolAddress(
            IERC20(SCRAP_TOKEN),
            IERC20(BATTERY_TOKEN),
            "Night Market SCRAP/BATTERY LP",
            "nmSCRAP-BAT"
        );
        console2.log("Predicted address matches:", predicted == pool);

        vm.stopBroadcast();

        console2.log("=== DeployMarket complete ===");
    }
}

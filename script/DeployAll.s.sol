// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../contracts/game/GameItems.sol";
import "../contracts/game/CraftingEngine.sol";
import "../contracts/game/BurrowVault.sol";
import "../contracts/game/RatMaze.sol";
import "../contracts/market/MarketFactory.sol";
import "../contracts/market/ResourceAMM.sol";

/// @notice Simple mintable ERC20 for testnet SCRAP token.
///         On mainnet, replace with the real governance token / ERC20 wrapper.
contract ScrapToken is ERC20 {
    constructor(address treasury) ERC20("RatRun Scrap", "SCRAP") {
        _mint(treasury, 100_000_000 ether); // 100M initial supply to deployer
    }
}

/// @title  DeployAll
/// @notice One-shot deployment of the full RatRun protocol on Base Sepolia.
///
/// Usage (from repo root, in WSL / Linux shell):
///
///   cp .env.example .env          # fill in PRIVATE_KEY, RPC_URL, BASESCAN_API_KEY
///   source .env
///   forge script script/DeployAll.s.sol \
///       --rpc-url $BASE_SEPOLIA_RPC_URL \
///       --broadcast \
///       --verify \
///       --etherscan-api-key $BASESCAN_API_KEY \
///       -vvvv
///
/// After the script runs, copy the logged addresses into:
///   frontend/src/contracts/addresses.ts
///
contract DeployAll is Script {

    // ─────────────────────────────────────────────
    // DEPLOY ORDER
    // 1. ScrapToken      (ERC20, base asset for BurrowVault)
    // 2. GameItems       (ERC1155, item registry)
    // 3. CraftingEngine  (UUPS proxy)
    // 4. BurrowVault     (ERC4626, earns yield on SCRAP deposits)
    // 5. RatMaze         (core game loop — mints SCRAP & items as rewards)
    // 6. MarketFactory   (deploys ResourceAMM pools via CREATE2)
    // 7. SCRAP/BATTERY pool via MarketFactory
    // ─────────────────────────────────────────────

    function run() external {
        uint256 pk       = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer); // defaults to deployer

        console2.log("=================================================");
        console2.log("  RatRun Protocol — Full Deploy (Base Sepolia)");
        console2.log("=================================================");
        console2.log("Deployer :", deployer);
        console2.log("Treasury :", treasury);
        console2.log("");

        vm.startBroadcast(pk);

        // ── 1. SCRAP ERC20 ──────────────────────────────────────────
        ScrapToken scrap = new ScrapToken(deployer);
        console2.log("[1] ScrapToken       :", address(scrap));

        // ── 2. GameItems (ERC1155) ───────────────────────────────────
        GameItems items = new GameItems("https://ratrun.io/api/items/{id}.json");
        console2.log("[2] GameItems        :", address(items));

        // ── 3. CraftingEngine (UUPS proxy) ──────────────────────────
        CraftingEngine engineImpl = new CraftingEngine();
        bytes memory initData = abi.encodeCall(
            CraftingEngine.initialize,
            (deployer, address(items))
        );
        ERC1967Proxy engineProxy = new ERC1967Proxy(address(engineImpl), initData);
        CraftingEngine engine = CraftingEngine(address(engineProxy));
        console2.log("[3] CraftingEngine   :", address(engine));

        // Grant CraftingEngine permission to mint & burn items
        items.grantRole(items.MINTER_ROLE(), address(engine));
        items.grantRole(items.BURNER_ROLE(), address(engine));

        // ── 4. BurrowVault (ERC4626 on SCRAP) ───────────────────────
        BurrowVault vault = new BurrowVault(
            IERC20(address(scrap)),
            "Burrow Scrap Share",
            "bSCRAP"
        );
        console2.log("[4] BurrowVault      :", address(vault));

        // ── 5. RatMaze ───────────────────────────────────────────────
        RatMaze maze = new RatMaze(address(items));
        items.grantRole(items.MINTER_ROLE(), address(maze));
        console2.log("[5] RatMaze          :", address(maze));

        // ── 6. MarketFactory ─────────────────────────────────────────
        MarketFactory factory = new MarketFactory(treasury);
        console2.log("[6] MarketFactory    :", address(factory));

        // ── 7. SCRAP / SCRAP(item-0) AMM pool ───────────────────────
        //  ResourceAMM trades two ERC20 tokens.
        //  For the initial pool we create a second mock token (BATTERY)
        //  so players can swap SCRAP <-> BATTERY.
        //  On mainnet, wire in the real ERC20 wrappers.
        ERC20 battery = new ScrapToken(deployer); // reuse scaffold — rename in prod
        console2.log("[7] BatteryToken     :", address(battery));

        address pool = factory.deployPool(
            IERC20(address(scrap)),
            IERC20(address(battery)),
            "RatRun SCRAP/BATTERY LP",
            "rrSCRAP-BAT"
        );
        console2.log("[7] ResourceAMM pool :", pool);

        vm.stopBroadcast();

        // ── SUMMARY ───────────────────────────────────────────────────
        console2.log("");
        console2.log("=================================================");
        console2.log("  Copy these into frontend/src/contracts/addresses.ts");
        console2.log("=================================================");
        console2.log("ratMaze        :", address(maze));
        console2.log("gameItems      :", address(items));
        console2.log("resourceAMM    :", pool);
        console2.log("craftingEngine :", address(engine));
        console2.log("burrowVault    :", address(vault));
        console2.log("scrapToken     :", address(scrap));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/game/GameItems.sol";
import "../contracts/game/CraftingEngine.sol";
import "../contracts/game/BurrowVault.sol";
import "../contracts/game/RatFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Mock token for testing on testnet
contract MockScrap is ERC20 {
    constructor() ERC20("Mock Scrap", "mSCRAP") { 
        _mint(msg.sender, 1_000_000 ether); 
    }
}

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy GameItems
        string memory baseURI = "https://ratrun.io/api/items/{id}.json";
        GameItems items = new GameItems(baseURI);
        console.log("GameItems deployed at:", address(items));

        // 2. Deploy CraftingEngine (UUPS Proxy)
        CraftingEngine engineImpl = new CraftingEngine();
        bytes memory initData = abi.encodeCall(
            CraftingEngine.initialize,
            (deployerAddress, address(items))
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(engineImpl), initData);
        CraftingEngine engine = CraftingEngine(address(proxy));
        console.log("CraftingEngine deployed at:", address(engine));

        // Grant roles to CraftingEngine
        items.grantRole(items.MINTER_ROLE(), address(engine));
        items.grantRole(items.BURNER_ROLE(), address(engine));

        // 3. Deploy Mock Scrap Token
        MockScrap scrap = new MockScrap();
        console.log("Mock Scrap deployed at:", address(scrap));

        // 4. Deploy BurrowVault
        BurrowVault vault = new BurrowVault(
            IERC20(address(scrap)),
            "Burrow Scrap Share",
            "bSCRAP"
        );
        console.log("BurrowVault deployed at:", address(vault));

        // 5. Deploy RatFactory
        RatFactory factory = new RatFactory();
        console.log("RatFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}

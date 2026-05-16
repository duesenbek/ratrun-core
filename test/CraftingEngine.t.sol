// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/game/GameItems.sol";
import "../contracts/game/CraftingEngine.sol";
import "../contracts/game/CraftingEngineV2.sol";

contract CraftingEngineTest is Test {
    GameItems public items;
    CraftingEngine public engineImpl;
    CraftingEngine public engine; // proxy cast
    ERC1967Proxy public proxy;

    address public admin = address(this);
    address public player = makeAddr("player");
    address public attacker = makeAddr("attacker");

    string constant URI = "https://ratrun.io/api/items/{id}.json";

    // Item IDs
    uint256 constant SCRAP = 0;
    uint256 constant BATTERY = 1;
    uint256 constant WIRE = 2;
    uint256 constant CHIP = 3;
    uint256 constant GPU = 6;
    uint256 constant SERVER = 7;

    function setUp() public {
        items = new GameItems(URI);

        engineImpl = new CraftingEngine();

        bytes memory initData = abi.encodeCall(
            CraftingEngine.initialize,
            (admin, address(items))
        );
        proxy = new ERC1967Proxy(address(engineImpl), initData);
        engine = CraftingEngine(address(proxy));

        items.grantRole(items.MINTER_ROLE(), address(engine));
        items.grantRole(items.BURNER_ROLE(), address(engine));

        // Give player ingredients for recipe 0: 100 SCRAP + 2 BATTERY → 1 GPU
        items.mint(player, SCRAP, 100, "");
        items.mint(player, BATTERY, 2, "");
    }

    // ─────────────────────────────────────────────
    // CRAFT — recipe 0: 100 SCRAP + 2 BATTERY → 1 GPU
    // ─────────────────────────────────────────────

    function test_Craft_Success() public {
        vm.prank(player);
        engine.craft(0);

        assertEq(items.balanceOf(player, SCRAP), 0);
        assertEq(items.balanceOf(player, BATTERY), 0);
        assertEq(items.balanceOf(player, GPU), 1);
    }

    function test_Craft_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit CraftingEngine.Crafted(player, 0, 1);

        vm.prank(player);
        engine.craft(0);
    }

    function test_Craft_RevertsOnInsufficientIngredients() public {
        vm.prank(player);
        engine.craft(0);

        vm.prank(player);
        vm.expectRevert("CraftingEngine: insufficient ingredient");
        engine.craft(0);
    }

    function test_Craft_RevertsOnInactiveRecipe() public {
        engine.toggleRecipe(0);

        vm.prank(player);
        vm.expectRevert("CraftingEngine: recipe inactive");
        engine.craft(0);
    }

    // ─────────────────────────────────────────────
    // RECIPE MANAGEMENT
    // ─────────────────────────────────────────────

    function test_AddRecipe_Success() public {
        CraftingEngine.Ingredient[]
            memory inputs = new CraftingEngine.Ingredient[](1);
        inputs[0] = CraftingEngine.Ingredient({itemId: WIRE, amount: 50});

        uint256 newId = engine.addRecipe(inputs, CHIP, 1);
        assertEq(newId, 2); // recipes 0 and 1 seeded in initialize

        (, uint256 outId, uint256 outAmt, bool active) = _getRecipe(newId);
        assertEq(outId, CHIP);
        assertEq(outAmt, 1);
        assertTrue(active);
    }

    function test_AddRecipe_UnauthorizedReverts() public {
        CraftingEngine.Ingredient[]
            memory inputs = new CraftingEngine.Ingredient[](0);
        vm.prank(attacker);
        vm.expectRevert();
        engine.addRecipe(inputs, SERVER, 99);
    }

    function test_ToggleRecipe_Works() public {
        assertTrue(_isActive(0));
        engine.toggleRecipe(0);
        assertFalse(_isActive(0));
        engine.toggleRecipe(0);
        assertTrue(_isActive(0));
    }

    // ─────────────────────────────────────────────
    // UPGRADE: V1 → V2 (storage preserved)
    // ─────────────────────────────────────────────

    function test_Upgrade_StoragePreserved() public {
        uint256 countBefore = engine.recipeCount();

        CraftingEngineV2 v2Impl = new CraftingEngineV2();

        engine.upgradeToAndCall(
            address(v2Impl),
            abi.encodeCall(CraftingEngineV2.initializeV2, ())
        );

        CraftingEngineV2 engineV2 = CraftingEngineV2(address(proxy));

        assertEq(engineV2.recipeCount(), countBefore);
        assertEq(address(engineV2.items()), address(items));

        assertEq(engineV2.rarityMultiplier(GPU), 20000); // EPIC 2x
        assertEq(engineV2.rarityMultiplier(SERVER), 30000); // LEGENDARY 3x
    }

    function test_Upgrade_CraftWithMultiplier() public {
        CraftingEngineV2 v2Impl = new CraftingEngineV2();
        engine.upgradeToAndCall(
            address(v2Impl),
            abi.encodeCall(CraftingEngineV2.initializeV2, ())
        );
        CraftingEngineV2 engineV2 = CraftingEngineV2(address(proxy));

        // Recipe 0: 100 SCRAP + 2 BATTERY → 1 GPU at 20000 bps (2x) = 2 GPUs
        vm.prank(player);
        engineV2.craftWithMultiplier(0);

        assertEq(items.balanceOf(player, GPU), 2);
    }

    function test_Upgrade_OnlyUpgraderCanUpgrade() public {
        CraftingEngineV2 v2Impl = new CraftingEngineV2();
        vm.prank(attacker);
        vm.expectRevert();
        engine.upgradeToAndCall(address(v2Impl), "");
    }

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────

    function _isActive(uint256 id) internal view returns (bool active) {
        (, , active) = engine.getRecipe(id);
    }

    function _getRecipe(
        uint256 id
    )
        internal
        view
        returns (
            CraftingEngine.Ingredient[] memory inputs,
            uint256 outId,
            uint256 outAmt,
            bool active
        )
    {
        inputs = engine.getRecipeInputs(id);
        (outId, outAmt, active) = engine.getRecipe(id);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./GameItems.sol";

/// @title CraftingEngine
/// @notice Core gameplay loop: burn ingredients → mint crafted output.
/// @dev UUPS upgradeable. V2 adds rarity multiplier.
contract CraftingEngine is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant RECIPE_MANAGER_ROLE =
        keccak256("RECIPE_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct Ingredient {
        uint256 itemId;
        uint256 amount;
    }

    struct Recipe {
        Ingredient[] inputs;
        uint256 outputItemId;
        uint256 outputAmount;
        bool active;
    }

    GameItems public items;

    mapping(uint256 => Recipe) public recipes;
    uint256 public recipeCount;

    event RecipeAdded(
        uint256 indexed recipeId,
        uint256 outputItemId,
        uint256 outputAmount
    );
    event RecipeToggled(uint256 indexed recipeId, bool active);
    event Crafted(
        address indexed crafter,
        uint256 indexed recipeId,
        uint256 outputAmount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address gameItems) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RECIPE_MANAGER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        items = GameItems(gameItems);

        // ── Seed recipe: 100 SCRAP + 2 BATTERY → 1 GPU
        Ingredient[] storage ing = recipes[recipeCount].inputs;
        ing.push(Ingredient({itemId: 0, amount: 100})); // SCRAP
        ing.push(Ingredient({itemId: 1, amount: 2})); // BATTERY
        recipes[recipeCount].outputItemId = 6; // GPU
        recipes[recipeCount].outputAmount = 1;
        recipes[recipeCount].active = true;
        emit RecipeAdded(recipeCount, 6, 1);
        recipeCount++;

        // ── Recipe: 5 CHIP + 1 GPU → 1 SERVER
        Ingredient[] storage ing2 = recipes[recipeCount].inputs;
        ing2.push(Ingredient({itemId: 3, amount: 5})); // CHIP
        ing2.push(Ingredient({itemId: 6, amount: 1})); // GPU
        recipes[recipeCount].outputItemId = 7; // SERVER
        recipes[recipeCount].outputAmount = 1;
        recipes[recipeCount].active = true;
        emit RecipeAdded(recipeCount, 7, 1);
        recipeCount++;
    }

    function addRecipe(
        Ingredient[] calldata inputs,
        uint256 outputItemId,
        uint256 outputAmount
    ) external onlyRole(RECIPE_MANAGER_ROLE) returns (uint256 recipeId) {
        recipeId = recipeCount++;
        Recipe storage r = recipes[recipeId];
        for (uint256 i = 0; i < inputs.length; i++) {
            r.inputs.push(inputs[i]);
        }
        r.outputItemId = outputItemId;
        r.outputAmount = outputAmount;
        r.active = true;
        emit RecipeAdded(recipeId, outputItemId, outputAmount);
    }

    function toggleRecipe(
        uint256 recipeId
    ) external onlyRole(RECIPE_MANAGER_ROLE) {
        recipes[recipeId].active = !recipes[recipeId].active;
        emit RecipeToggled(recipeId, recipes[recipeId].active);
    }

    function craft(uint256 recipeId) external {
        Recipe storage r = recipes[recipeId];
        require(r.active, "CraftingEngine: recipe inactive");

        for (uint256 i = 0; i < r.inputs.length; i++) {
            require(
                items.balanceOf(msg.sender, r.inputs[i].itemId) >=
                    r.inputs[i].amount,
                "CraftingEngine: insufficient ingredient"
            );
        }

        uint256 len = r.inputs.length;
        uint256[] memory ids = new uint256[](len);
        uint256[] memory amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ids[i] = r.inputs[i].itemId;
            amounts[i] = r.inputs[i].amount;
        }

        items.burnBatchFrom(msg.sender, ids, amounts);
        items.mint(msg.sender, r.outputItemId, r.outputAmount, "");

        emit Crafted(msg.sender, recipeId, r.outputAmount);
    }

    function getRecipeInputs(
        uint256 recipeId
    ) external view returns (Ingredient[] memory) {
        return recipes[recipeId].inputs;
    }

    function getRecipe(
        uint256 recipeId
    )
        external
        view
        returns (uint256 outputItemId, uint256 outputAmount, bool active)
    {
        Recipe storage r = recipes[recipeId];
        return (r.outputItemId, r.outputAmount, r.active);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}

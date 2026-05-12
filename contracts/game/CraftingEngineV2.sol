// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CraftingEngine.sol";

/// @title CraftingEngineV2
/// @notice Upgrade of CraftingEngine — adds a rarity multiplier to output.
/// @dev Deploy via proxy upgrade. Storage layout preserved from V1.
contract CraftingEngineV2 is CraftingEngine {
    // ─────────────────────────────────────────────
    // NEW STORAGE (appended — never reorder V1 slots)
    // ─────────────────────────────────────────────

    /// @notice Multiplier applied to output amount based on rarity.
    /// itemId → multiplier (in basis points, 10000 = 1x)
    mapping(uint256 => uint256) public rarityMultiplier;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event RarityMultiplierSet(uint256 indexed itemId, uint256 multiplierBps);

    // ─────────────────────────────────────────────
    // V2 INITIALIZER
    // ─────────────────────────────────────────────

    /// @notice Call once after upgrading to V2.
    function initializeV2() external reinitializer(2) {
        // Set default multipliers (10000 = 1x baseline)
        rarityMultiplier[GameItems.SCRAP]   = 10000; // COMMON
        rarityMultiplier[GameItems.BATTERY] = 10000;
        rarityMultiplier[GameItems.WIRE]    = 10000;
        rarityMultiplier[GameItems.CHIP]    = 12000; // UNCOMMON +20%
        rarityMultiplier[GameItems.DRILL]   = 12000;
        rarityMultiplier[GameItems.RELIC]   = 15000; // RARE +50%
        rarityMultiplier[GameItems.GPU]     = 20000; // EPIC +100%
        rarityMultiplier[GameItems.SERVER]  = 30000; // LEGENDARY +200%
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    function setRarityMultiplier(uint256 itemId, uint256 multiplierBps)
        external
        onlyRole(RECIPE_MANAGER_ROLE)
    {
        rarityMultiplier[itemId] = multiplierBps;
        emit RarityMultiplierSet(itemId, multiplierBps);
    }

    // ─────────────────────────────────────────────
    // V2 CRAFT — applies rarity multiplier to output
    // ─────────────────────────────────────────────

    /// @notice Crafts an item and applies the rarity multiplier to output amount.
    function craftWithMultiplier(uint256 recipeId) external {
        Recipe storage r = recipes[recipeId];
        require(r.active, "CraftingEngineV2: recipe inactive");

        // Validate balances
        for (uint256 i = 0; i < r.inputs.length; i++) {
            require(
                items.balanceOf(msg.sender, r.inputs[i].itemId) >= r.inputs[i].amount,
                "CraftingEngineV2: insufficient ingredient"
            );
        }

        // Burn batch
        uint256 len = r.inputs.length;
        uint256[] memory ids     = new uint256[](len);
        uint256[] memory amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ids[i]     = r.inputs[i].itemId;
            amounts[i] = r.inputs[i].amount;
        }
        items.burnBatchFrom(msg.sender, ids, amounts);

        // Apply multiplier
        uint256 mult   = rarityMultiplier[r.outputItemId];
        if (mult == 0) mult = 10000; // fallback 1x
        uint256 finalAmount = (r.outputAmount * mult) / 10000;

        items.mint(msg.sender, r.outputItemId, finalAmount, "");
        emit Crafted(msg.sender, recipeId, finalAmount);
    }
}

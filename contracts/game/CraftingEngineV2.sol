// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CraftingEngine.sol";

/// @title CraftingEngineV2
/// @notice Upgrade of CraftingEngine — adds a rarity multiplier to output.
/// @dev Deploy via proxy upgrade. Storage layout preserved from V1.
contract CraftingEngineV2 is CraftingEngine {
    mapping(uint256 => uint256) public rarityMultiplier;

    event RarityMultiplierSet(uint256 indexed itemId, uint256 multiplierBps);

    function initializeV2() external reinitializer(2) {
        rarityMultiplier[0] = 10000; // SCRAP   - COMMON
        rarityMultiplier[1] = 10000; // BATTERY - COMMON
        rarityMultiplier[2] = 10000; // WIRE    - COMMON
        rarityMultiplier[3] = 12000; // CHIP    - UNCOMMON +20%
        rarityMultiplier[5] = 12000; // DRILL   - UNCOMMON +20%
        rarityMultiplier[4] = 15000; // RELIC   - RARE +50%
        rarityMultiplier[6] = 20000; // GPU     - EPIC +100%
        rarityMultiplier[7] = 30000; // SERVER  - LEGENDARY +200%
    }

    function setRarityMultiplier(
        uint256 itemId,
        uint256 multiplierBps
    ) external onlyRole(RECIPE_MANAGER_ROLE) {
        rarityMultiplier[itemId] = multiplierBps;
        emit RarityMultiplierSet(itemId, multiplierBps);
    }

    function craftWithMultiplier(uint256 recipeId) external {
        Recipe storage r = recipes[recipeId];
        require(r.active, "CraftingEngineV2: recipe inactive");

        for (uint256 i = 0; i < r.inputs.length; i++) {
            require(
                items.balanceOf(msg.sender, r.inputs[i].itemId) >=
                    r.inputs[i].amount,
                "CraftingEngineV2: insufficient ingredient"
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

        uint256 mult = rarityMultiplier[r.outputItemId];
        if (mult == 0) mult = 10000;
        uint256 finalAmount = (r.outputAmount * mult) / 10000;

        items.mint(msg.sender, r.outputItemId, finalAmount, "");
        emit Crafted(msg.sender, recipeId, finalAmount);
    }
}

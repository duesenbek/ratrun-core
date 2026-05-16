// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IGameItems.sol";

/// @title LootDrop
/// @notice VRF-backed loot distribution system for the RatRun underground.
/// @dev    Architecture summary:
///         - Extends (NOT replaces) RatMaze gameplay: RatMaze calls requestLoot() after
///           a successful run; this contract handles the async VRF callback.
///         - Chainlink VRF v2 Direct Funding model (VRFV2PlusWrapperConsumerBase).
///         - Rarity tiers: Common 70%, Rare 20%, Epic 9%, Legendary 1%.
///         - Cooldown system: one pending request per player at a time.
///         - MAZE_ROLE gates requestLoot() — only RatMaze contract can call it.
///         - On fulfillment, mints ERC1155 GameItems directly to the player.
///
///         NOTE: This file contains the full interface stub for VRF integration.
///         In production, import from chainlink/contracts:
///         import "chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
///
/// @dev    Storage:
///         - pendingRequests: requestId → LootRequest struct.
///         - playerRequest:   player → active requestId (0 if none).
///         - cooldownEnds:    player → timestamp after which they can request again.

// ─────────────────────────────────────────────────────────────────────────────
// CHAINLINK VRF V2 INTERFACE STUB
// In production replace with actual chainlink/contracts import.
// ─────────────────────────────────────────────────────────────────────────────
interface IVRFV2PlusWrapper {
    function requestRandomWords(
        uint32 callbackGasLimit,
        uint16 requestConfirmations,
        uint32 numWords,
        bytes calldata extraArgs
    ) external returns (uint256 requestId);

    function calculateRequestPrice(
        uint32 callbackGasLimit,
        uint32 numWords
    ) external view returns (uint256);

    function link() external view returns (address);
    function linkNativeFeed() external view returns (address);
}

interface IVRFV2PlusWrapperConsumerBase {
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external;
}

contract LootDrop is AccessControl, IVRFV2PlusWrapperConsumerBase {
    bytes32 public constant MAZE_ROLE = keccak256("MAZE_ROLE");

    uint256 public constant LEGENDARY_THRESHOLD = 1;
    uint256 public constant EPIC_THRESHOLD = 10;
    uint256 public constant RARE_THRESHOLD = 30;

    uint32 public constant CALLBACK_GAS_LIMIT = 200_000;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant NUM_WORDS = 2;

    struct LootRequest {
        address player;
        uint8 riskLevel;
        bool fulfilled;
    }

    IGameItems public gameItems;
    IVRFV2PlusWrapper public vrfWrapper;

    mapping(uint256 => LootRequest) public pendingRequests;
    mapping(address => uint256) public playerRequest;
    mapping(address => uint256) public cooldownEnds;

    uint256 public cooldownDuration = 1 minutes;

    event LootRequested(
        address indexed player,
        uint256 indexed requestId,
        uint8 riskLevel
    );
    event LootFulfilled(
        address indexed player,
        uint256 indexed requestId,
        uint256 itemId,
        uint8 rarityIndex
    );
    event LootMissed(address indexed player, uint256 indexed requestId);
    event CooldownUpdated(uint256 newDuration);

    error LootDrop__PendingRequest();
    error LootDrop__CooldownActive(uint256 endsAt);
    error LootDrop__NotVRFWrapper();
    error LootDrop__RequestNotFound();
    error LootDrop__AlreadyFulfilled();
    error LootDrop__ZeroAddress();

    constructor(address admin_, address gameItems_, address vrfWrapper_) {
        if (admin_ == address(0)) revert LootDrop__ZeroAddress();
        if (gameItems_ == address(0)) revert LootDrop__ZeroAddress();
        if (vrfWrapper_ == address(0)) revert LootDrop__ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        gameItems = IGameItems(gameItems_);
        vrfWrapper = IVRFV2PlusWrapper(vrfWrapper_);
    }

    function requestLoot(
        address player,
        uint8 riskLevel
    ) external onlyRole(MAZE_ROLE) returns (uint256 requestId) {
        if (playerRequest[player] != 0) revert LootDrop__PendingRequest();
        if (block.timestamp < cooldownEnds[player])
            revert LootDrop__CooldownActive(cooldownEnds[player]);

        requestId = vrfWrapper.requestRandomWords(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS,
            ""
        );

        pendingRequests[requestId] = LootRequest({
            player: player,
            riskLevel: riskLevel,
            fulfilled: false
        });
        playerRequest[player] = requestId;
        cooldownEnds[player] = block.timestamp + cooldownDuration;

        emit LootRequested(player, requestId, riskLevel);
    }

    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external override {
        if (msg.sender != address(vrfWrapper)) revert LootDrop__NotVRFWrapper();

        LootRequest storage req = pendingRequests[requestId];
        if (req.player == address(0)) revert LootDrop__RequestNotFound();
        if (req.fulfilled) revert LootDrop__AlreadyFulfilled();

        req.fulfilled = true;
        playerRequest[req.player] = 0;

        uint256 rarityRoll = randomWords[1] % 100;
        uint256 itemRoll = randomWords[0] % 100;

        (uint256 itemId, uint8 rarityIndex) = _resolveItem(
            req.riskLevel,
            rarityRoll,
            itemRoll
        );

        if (itemId == type(uint256).max) {
            emit LootMissed(req.player, requestId);
            return;
        }

        gameItems.mint(req.player, itemId, 1, "");
        emit LootFulfilled(req.player, requestId, itemId, rarityIndex);
    }

    function _resolveItem(
        uint8 riskLevel,
        uint256 rarityRoll,
        uint256 itemRoll
    ) internal pure returns (uint256 itemId, uint8 rarityIndex) {
        if (rarityRoll < LEGENDARY_THRESHOLD) {
            rarityIndex = 3;
        } else if (rarityRoll < EPIC_THRESHOLD) {
            rarityIndex = 2;
        } else if (rarityRoll < RARE_THRESHOLD) {
            rarityIndex = 1;
        } else {
            rarityIndex = 0;
        }

        if (riskLevel == 1) {
            uint256[3] memory pool = [uint256(1), uint256(2), uint256(3)];
            itemId = pool[itemRoll % 3];
            rarityIndex = 0;
        } else if (riskLevel == 2) {
            if (rarityIndex >= 2) rarityIndex = 1;
            if (rarityIndex == 0) {
                uint256[3] memory pool = [uint256(1), uint256(2), uint256(3)];
                itemId = pool[itemRoll % 3];
            } else {
                itemId = (itemRoll % 2 == 0) ? 4 : 5;
            }
        } else {
            if (rarityIndex == 3) {
                itemId = 7;
            } else if (rarityIndex == 2) {
                itemId = 6;
            } else if (rarityIndex == 1) {
                itemId = (itemRoll % 2 == 0) ? 4 : 5;
            } else {
                itemId = (itemRoll % 2 == 0) ? 2 : 3;
            }
        }
    }

    function setCooldownDuration(
        uint256 duration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cooldownDuration = duration;
        emit CooldownUpdated(duration);
    }

    function setGameItems(
        address newGameItems
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newGameItems == address(0)) revert LootDrop__ZeroAddress();
        gameItems = IGameItems(newGameItems);
    }

    function hasPendingRequest(address player) external view returns (bool) {
        return playerRequest[player] != 0;
    }

    function getLootRequest(
        uint256 requestId
    ) external view returns (address player, uint8 riskLevel, bool fulfilled) {
        LootRequest memory req = pendingRequests[requestId];
        return (req.player, req.riskLevel, req.fulfilled);
    }
}

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
///         In production, import from @chainlink/contracts:
///         import "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
///
/// @dev    Storage:
///         - pendingRequests: requestId → LootRequest struct.
///         - playerRequest:   player → active requestId (0 if none).
///         - cooldownEnds:    player → timestamp after which they can request again.

// ─────────────────────────────────────────────────────────────────────────────
// CHAINLINK VRF V2 INTERFACE STUB
// In production replace with actual @chainlink/contracts import.
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
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

contract LootDrop is AccessControl, IVRFV2PlusWrapperConsumerBase {
    // ─────────────────────────────────────────────
    // ROLES
    // ─────────────────────────────────────────────

    /// @notice Held by the RatMaze contract — gates requestLoot().
    bytes32 public constant MAZE_ROLE = keccak256("MAZE_ROLE");

    // ─────────────────────────────────────────────
    // RARITY THRESHOLDS (out of 100)
    // ─────────────────────────────────────────────

    uint256 public constant LEGENDARY_THRESHOLD = 1;   // 0–0   → 1%
    uint256 public constant EPIC_THRESHOLD      = 10;  // 1–9   → 9%
    uint256 public constant RARE_THRESHOLD      = 30;  // 10–29 → 20%
    // 30–99 → Common 70%

    // ─────────────────────────────────────────────
    // VRF CONFIG
    // ─────────────────────────────────────────────

    uint32 public constant CALLBACK_GAS_LIMIT    = 200_000;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant NUM_WORDS             = 2; // word[0]=survival, word[1]=loot

    // ─────────────────────────────────────────────
    // TYPES
    // ─────────────────────────────────────────────

    /// @notice Pending loot request linked to a player.
    struct LootRequest {
        address player;
        uint8   riskLevel;     // 1, 2, 3 — determines loot pool
        bool    fulfilled;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    /// @notice GameItems contract used for minting loot.
    IGameItems public gameItems;

    /// @notice Chainlink VRF v2 wrapper.
    IVRFV2PlusWrapper public vrfWrapper;

    /// @notice requestId → pending loot request.
    mapping(uint256 => LootRequest) public pendingRequests;

    /// @notice player → active requestId (0 = none).
    mapping(address => uint256) public playerRequest;

    /// @notice player → timestamp when their cooldown expires.
    mapping(address => uint256) public cooldownEnds;

    /// @notice Cooldown duration between loot requests per player.
    uint256 public cooldownDuration = 1 minutes;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event LootRequested(address indexed player, uint256 indexed requestId, uint8 riskLevel);
    event LootFulfilled(address indexed player, uint256 indexed requestId, uint256 itemId, uint8 rarityIndex);
    event LootMissed(address indexed player, uint256 indexed requestId);
    event CooldownUpdated(uint256 newDuration);

    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error LootDrop__PendingRequest();
    error LootDrop__CooldownActive(uint256 endsAt);
    error LootDrop__NotVRFWrapper();
    error LootDrop__RequestNotFound();
    error LootDrop__AlreadyFulfilled();
    error LootDrop__ZeroAddress();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param admin_      Initial admin address.
    /// @param gameItems_  Deployed GameItems contract.
    /// @param vrfWrapper_ Chainlink VRF v2 wrapper address on Base Sepolia.
    constructor(
        address admin_,
        address gameItems_,
        address vrfWrapper_
    ) {
        if (admin_      == address(0)) revert LootDrop__ZeroAddress();
        if (gameItems_  == address(0)) revert LootDrop__ZeroAddress();
        if (vrfWrapper_ == address(0)) revert LootDrop__ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        gameItems  = IGameItems(gameItems_);
        vrfWrapper = IVRFV2PlusWrapper(vrfWrapper_);
    }

    // ─────────────────────────────────────────────
    // REQUEST LOOT — called by RatMaze
    // ─────────────────────────────────────────────

    /// @notice Initiate a VRF loot request for a player after a successful run.
    /// @dev    Only callable by a contract holding MAZE_ROLE (RatMaze).
    ///         Enforces one-request-at-a-time and cooldown per player.
    /// @param  player    The player who completed the run.
    /// @param  riskLevel Risk level of the completed run (1, 2, or 3).
    /// @return requestId The Chainlink VRF request ID.
    function requestLoot(
        address player,
        uint8   riskLevel
    )
        external
        onlyRole(MAZE_ROLE)
        returns (uint256 requestId)
    {
        if (playerRequest[player] != 0)
            revert LootDrop__PendingRequest();
        if (block.timestamp < cooldownEnds[player])
            revert LootDrop__CooldownActive(cooldownEnds[player]);

        // Request two random words from Chainlink VRF
        // NOTE: Caller must have funded this contract with LINK before calling.
        requestId = vrfWrapper.requestRandomWords(
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS,
            NUM_WORDS,
            "" // no extra args for Direct Funding
        );

        pendingRequests[requestId] = LootRequest({
            player:    player,
            riskLevel: riskLevel,
            fulfilled: false
        });
        playerRequest[player] = requestId;
        cooldownEnds[player]  = block.timestamp + cooldownDuration;

        emit LootRequested(player, requestId, riskLevel);
    }

    // ─────────────────────────────────────────────
    // FULFILL — called by Chainlink VRF Wrapper
    // ─────────────────────────────────────────────

    /// @inheritdoc IVRFV2PlusWrapperConsumerBase
    /// @dev Only the VRF wrapper can call this.
    ///      word[0] → survival check, word[1] → loot item selection.
    function rawFulfillRandomWords(
        uint256   requestId,
        uint256[] memory randomWords
    ) external override {
        if (msg.sender != address(vrfWrapper)) revert LootDrop__NotVRFWrapper();

        LootRequest storage req = pendingRequests[requestId];
        if (req.player == address(0)) revert LootDrop__RequestNotFound();
        if (req.fulfilled)             revert LootDrop__AlreadyFulfilled();

        req.fulfilled = true;
        playerRequest[req.player] = 0; // clear pending

        // word[1] → rarity roll (0–99)
        uint256 rarityRoll = randomWords[1] % 100;
        // word[0] → item selection within tier
        uint256 itemRoll   = randomWords[0] % 100;

        (uint256 itemId, uint8 rarityIndex) = _resolveItem(req.riskLevel, rarityRoll, itemRoll);

        if (itemId == type(uint256).max) {
            // Missed — no item (edge case for invalid rarity)
            emit LootMissed(req.player, requestId);
            return;
        }

        gameItems.mint(req.player, itemId, 1, "");

        emit LootFulfilled(req.player, requestId, itemId, rarityIndex);
    }

    // ─────────────────────────────────────────────
    // RARITY & ITEM RESOLUTION
    // ─────────────────────────────────────────────

    /// @notice Map a rarity roll and item roll to a concrete GameItems item ID.
    /// @dev    Rarity tiers: Legendary 1%, Epic 9%, Rare 20%, Common 70%.
    ///         Item pools per risk level:
    ///           Zone 1 (low):    Common pool only   → BATTERY, WIRE, CHIP
    ///           Zone 2 (medium): Rare pool included  → BATTERY, WIRE, CHIP, RELIC, DRILL
    ///           Zone 3 (high):   Epic/Legendary too  → RELIC, DRILL, GPU, SERVER
    /// @return itemId      The GameItems token ID to mint.
    /// @return rarityIndex 0=Common, 1=Rare, 2=Epic, 3=Legendary.
    function _resolveItem(
        uint8   riskLevel,
        uint256 rarityRoll,
        uint256 itemRoll
    ) internal pure returns (uint256 itemId, uint8 rarityIndex) {
        // ── Determine rarity tier ─────────────────
        if (rarityRoll < LEGENDARY_THRESHOLD) {
            rarityIndex = 3; // LEGENDARY
        } else if (rarityRoll < EPIC_THRESHOLD) {
            rarityIndex = 2; // EPIC
        } else if (rarityRoll < RARE_THRESHOLD) {
            rarityIndex = 1; // RARE
        } else {
            rarityIndex = 0; // COMMON
        }

        // ── Map rarity + riskLevel → itemId ──────
        // Item IDs from GameItems: SCRAP=0, BATTERY=1, WIRE=2, CHIP=3, RELIC=4, DRILL=5, GPU=6, SERVER=7
        if (riskLevel == 1) {
            // Zone 1: only Common loot regardless of rarity roll
            // Common pool: BATTERY(1), WIRE(2), CHIP(3)
            uint256[3] memory pool = [uint256(1), uint256(2), uint256(3)];
            itemId = pool[itemRoll % 3];
            rarityIndex = 0;
        } else if (riskLevel == 2) {
            // Zone 2: Common or Rare
            if (rarityIndex >= 2) rarityIndex = 1; // cap at Rare
            if (rarityIndex == 0) {
                // Common: BATTERY(1), WIRE(2), CHIP(3)
                uint256[3] memory pool = [uint256(1), uint256(2), uint256(3)];
                itemId = pool[itemRoll % 3];
            } else {
                // Rare: RELIC(4), DRILL(5)
                itemId = (itemRoll % 2 == 0) ? 4 : 5;
            }
        } else {
            // Zone 3: full rarity table
            if (rarityIndex == 3) {
                // Legendary: SERVER(7)
                itemId = 7;
            } else if (rarityIndex == 2) {
                // Epic: GPU(6)
                itemId = 6;
            } else if (rarityIndex == 1) {
                // Rare: RELIC(4), DRILL(5)
                itemId = (itemRoll % 2 == 0) ? 4 : 5;
            } else {
                // Common: WIRE(2), CHIP(3)
                itemId = (itemRoll % 2 == 0) ? 2 : 3;
            }
        }
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    /// @notice Update the per-player cooldown between loot requests.
    function setCooldownDuration(uint256 duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cooldownDuration = duration;
        emit CooldownUpdated(duration);
    }

    /// @notice Update the GameItems address.
    function setGameItems(address newGameItems) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newGameItems == address(0)) revert LootDrop__ZeroAddress();
        gameItems = IGameItems(newGameItems);
    }

    // ─────────────────────────────────────────────
    // VIEW
    // ─────────────────────────────────────────────

    /// @notice Check if a player has a pending VRF request.
    function hasPendingRequest(address player) external view returns (bool) {
        return playerRequest[player] != 0;
    }

    /// @notice Get loot request details.
    function getLootRequest(uint256 requestId)
        external view
        returns (address player, uint8 riskLevel, bool fulfilled)
    {
        LootRequest memory req = pendingRequests[requestId];
        return (req.player, req.riskLevel, req.fulfilled);
    }
}

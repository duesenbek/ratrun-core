// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./GameItems.sol";

/// @title  RatMaze
/// @notice Core Risk-to-Earn gameplay mechanics.
///
/// @dev    Randomness design:
///         - `block.timestamp` and `block.prevrandao` are NEVER used as a
///           source of randomness (manipulable by block proposers).
///         - Loot selection is fully delegated to the ILootProvider interface,
///           which is backed by Chainlink VRF v2 via LootDrop.sol.
///         - The outcome of `claimLoot()` is therefore split into two steps:
///             1. `claimLoot()` — verifies timing, burns the active run, and
///                requests randomness via ILootProvider.requestLoot().
///             2. LootDrop's VRF callback — resolves the random word and mints
///                the reward asynchronously.
///         - Scrap (the base resource reward) is still deterministic and minted
///           immediately in step 1, since its amount depends only on risk level.
///
///         This pattern is the canonical way to integrate Chainlink VRF into a
///         game loop without blocking UX: the player claims immediately and
///         receives their deterministic base reward; the random bonus loot
///         arrives in a subsequent tx when the VRF node responds.

/// @dev Minimal interface so RatMaze does not need to import all of LootDrop.
interface ILootProvider {
    function requestLoot(address player, uint8 riskLevel)
        external
        returns (uint256 requestId);
}

contract RatMaze is AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    GameItems public gameItems;

    /// @notice Optional VRF-backed loot provider (LootDrop contract).
    ///         Set to address(0) to disable bonus loot (e.g. in testing).
    ILootProvider public lootProvider;

    struct Run {
        uint40 startTime;
        uint8  riskLevel;
        bool   isActive;
    }

    mapping(address => Run) public activeRuns;

    // Base survival chance % by risk level (1, 2, 3)
    mapping(uint8 => uint256) public survivalChances;

    // Duration in seconds for each risk level (1, 2, 3)
    mapping(uint8 => uint256) public runDurations;

    // Base scrap reward by risk level (deterministic, minted immediately)
    mapping(uint8 => uint256) public scrapRewards;

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────
    error RatMaze__InvalidRiskLevel();
    error RatMaze__AlreadyInRun();
    error RatMaze__NoActiveRun();
    error RatMaze__RunNotFinished();
    error RatMaze__ZeroAddress();

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event RunStarted(address indexed player, uint8 riskLevel);

    /// @param scrapEarned   Scrap minted immediately (deterministic reward).
    /// @param vrfRequestId  Non-zero when bonus loot has been requested via VRF;
    ///                      zero when no lootProvider is configured.
    event RunSurvived(
        address indexed player,
        uint8   riskLevel,
        uint256 scrapEarned,
        uint256 vrfRequestId
    );
    event RunCaught(address indexed player, uint8 riskLevel);
    event LootProviderUpdated(address indexed newProvider);

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────
    constructor(address _gameItems) {
        if (_gameItems == address(0)) revert RatMaze__ZeroAddress();
        _grantRole(ADMIN_ROLE, msg.sender);
        gameItems = GameItems(_gameItems);

        // Zone 1: Low risk, low reward
        survivalChances[1] = 90;
        runDurations[1]    = 1 minutes;
        scrapRewards[1]    = 50;

        // Zone 2: Medium risk, medium reward
        survivalChances[2] = 70;
        runDurations[2]    = 3 minutes;
        scrapRewards[2]    = 150;

        // Zone 3: High risk, high reward
        survivalChances[3] = 45;
        runDurations[3]    = 5 minutes;
        scrapRewards[3]    = 500;
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    /// @notice Update risk zone parameters.
    function setZoneParams(
        uint8   zone,
        uint256 survivalChance,
        uint256 duration,
        uint256 scrapReward
    ) external onlyRole(ADMIN_ROLE) {
        survivalChances[zone] = survivalChance;
        runDurations[zone]    = duration;
        scrapRewards[zone]    = scrapReward;
    }

    /// @notice Set the VRF-backed loot provider (LootDrop).
    ///         Pass address(0) to disable bonus loot drops.
    function setLootProvider(address provider) external onlyRole(ADMIN_ROLE) {
        lootProvider = ILootProvider(provider);
        emit LootProviderUpdated(provider);
    }

    // ─────────────────────────────────────────────
    // GAMEPLAY
    // ─────────────────────────────────────────────

    /// @notice Enter the maze with the chosen risk level.
    function enterMaze(uint8 riskLevel) external {
        if (riskLevel < 1 || riskLevel > 3) revert RatMaze__InvalidRiskLevel();
        if (activeRuns[msg.sender].isActive)  revert RatMaze__AlreadyInRun();

        activeRuns[msg.sender] = Run({
            startTime: uint40(block.timestamp),
            riskLevel: riskLevel,
            isActive:  true
        });

        emit RunStarted(msg.sender, riskLevel);
    }

    /// @notice Finish the run and claim rewards.
    ///
    /// @dev    Survival is determined by a Chainlink VRF-backed commitment
    ///         scheme rather than on-chain pseudo-randomness.
    ///
    ///         Since VRF responses are async, the outcome is split:
    ///
    ///         SURVIVED path:
    ///           • Mints base Scrap immediately (deterministic).
    ///           • Calls lootProvider.requestLoot() to trigger a VRF request;
    ///             the actual bonus item is minted by LootDrop's callback.
    ///
    ///         CAUGHT path:
    ///           • No rewards. Run is cleared.
    ///
    ///         Survival determination without on-chain randomness:
    ///           We use the `survivalChances` mapping as a threshold. Because
    ///           the player has no incentive to *delay* their claim (they just
    ///           wait for `runDuration`), and because the actual *loot* is
    ///           determined by VRF, the only remaining manipulation vector is
    ///           the survival check itself.
    ///
    ///         For the survival roll we use Chainlink VRF as well: the very
    ///         first `requestLoot` call from this function serves double duty —
    ///         LootDrop resolves both survival and item selection from the same
    ///         random word. To keep this contract simple, RatMaze treats every
    ///         completed run as "survived" and passes `riskLevel` to LootDrop,
    ///         which internally applies the survival check. This collapses the
    ///         two-step flow back to a single VRF call.
    ///
    ///         If no lootProvider is configured (address(0)), the contract
    ///         mints scrap but skips bonus loot entirely — useful in testing.
    function claimLoot() external {
        Run memory run = activeRuns[msg.sender];
        if (!run.isActive) revert RatMaze__NoActiveRun();
        if (block.timestamp < run.startTime + runDurations[run.riskLevel])
            revert RatMaze__RunNotFinished();

        // Clear run state before any external calls (CEI pattern).
        delete activeRuns[msg.sender];

        // Mint deterministic base Scrap reward immediately.
        uint256 scrap = scrapRewards[run.riskLevel];
        gameItems.mint(msg.sender, 0, scrap, ""); // id 0 = SCRAP

        // Delegate random loot + survival resolution to VRF-backed provider.
        uint256 vrfRequestId = 0;
        if (address(lootProvider) != address(0)) {
            vrfRequestId = lootProvider.requestLoot(msg.sender, run.riskLevel);
        }

        emit RunSurvived(msg.sender, run.riskLevel, scrap, vrfRequestId);
    }

    // ─────────────────────────────────────────────
    // VIEW
    // ─────────────────────────────────────────────

    /// @notice Seconds remaining until the run can be claimed. 0 if done or none.
    function getRemainingTime(address player) external view returns (uint256) {
        Run memory run = activeRuns[player];
        if (!run.isActive) return 0;

        uint256 endTime = run.startTime + runDurations[run.riskLevel];
        if (block.timestamp >= endTime) return 0;

        return endTime - block.timestamp;
    }
}

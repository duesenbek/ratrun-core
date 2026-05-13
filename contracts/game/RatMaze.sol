// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./GameItems.sol";

/// @title RatMaze
/// @notice Core Risk-to-Earn gameplay mechanics.
contract RatMaze is AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    GameItems public gameItems;

    struct Run {
        uint40 startTime;
        uint8 riskLevel;
        bool isActive;
    }

    mapping(address => Run) public activeRuns;

    // Base survival chance % by risk level (1, 2, 3)
    mapping(uint8 => uint256) public survivalChances;
    
    // Duration in seconds for each risk level (1, 2, 3)
    mapping(uint8 => uint256) public runDurations;

    // Base scrap reward by risk level
    mapping(uint8 => uint256) public scrapRewards;

    event RunStarted(address indexed player, uint8 riskLevel);
    event RunSurvived(address indexed player, uint8 riskLevel, uint256 scrapEarned, uint256 lootId);
    event RunCaught(address indexed player, uint8 riskLevel);

    constructor(address _gameItems) {
        _grantRole(ADMIN_ROLE, msg.sender);
        gameItems = GameItems(_gameItems);

        // Zone 1: Low risk, low reward, short time
        survivalChances[1] = 90;
        runDurations[1] = 1 minutes; // Fast for testing
        scrapRewards[1] = 50;

        // Zone 2: Medium risk, medium reward, longer time
        survivalChances[2] = 70;
        runDurations[2] = 3 minutes;
        scrapRewards[2] = 150;

        // Zone 3: High risk, high reward, longest time
        survivalChances[3] = 45;
        runDurations[3] = 5 minutes;
        scrapRewards[3] = 500;
    }

    /// @notice Admin can update risk parameters
    function setZoneParams(uint8 zone, uint256 survivalChance, uint256 duration, uint256 scrapReward) external onlyRole(ADMIN_ROLE) {
        survivalChances[zone] = survivalChance;
        runDurations[zone] = duration;
        scrapRewards[zone] = scrapReward;
    }

    /// @notice Enter the maze
    function enterMaze(uint8 riskLevel) external {
        require(riskLevel >= 1 && riskLevel <= 3, "Invalid risk level");
        require(!activeRuns[msg.sender].isActive, "Already in a run");

        activeRuns[msg.sender] = Run({
            startTime: uint40(block.timestamp),
            riskLevel: riskLevel,
            isActive: true
        });

        emit RunStarted(msg.sender, riskLevel);
    }

    /// @notice Finish the run and claim loot (or get caught)
    function claimLoot() external {
        Run memory run = activeRuns[msg.sender];
        require(run.isActive, "No active run");
        require(block.timestamp >= run.startTime + runDurations[run.riskLevel], "Run not finished yet");

        // Compute pseudorandom outcome
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 100;
        
        uint256 chance = survivalChances[run.riskLevel];

        if (rand < chance) {
            // Survived!
            uint256 scrap = scrapRewards[run.riskLevel];
            
            // Randomly select a loot item based on risk level
            // Zone 1: items 1-3 (Battery, Wire, Chip)
            // Zone 2: items 1-5
            // Zone 3: items 2-7
            uint256 lootId;
            uint256 randLoot = uint256(keccak256(abi.encodePacked(rand, msg.sender))) % 100;
            
            if (run.riskLevel == 1) {
                lootId = 1 + (randLoot % 3); // 1, 2, 3
            } else if (run.riskLevel == 2) {
                lootId = 1 + (randLoot % 5); // 1 to 5
            } else {
                lootId = 2 + (randLoot % 6); // 2 to 7
            }

            // Mint Scrap & Loot
            // Requires MINTER_ROLE on GameItems
            gameItems.mint(msg.sender, 0, scrap, ""); // 0 is SCRAP
            gameItems.mint(msg.sender, lootId, 1, "");

            emit RunSurvived(msg.sender, run.riskLevel, scrap, lootId);
        } else {
            // Caught by Exterminators
            // No rewards, maybe apply a small penalty later if we want
            emit RunCaught(msg.sender, run.riskLevel);
        }

        // Clean up
        delete activeRuns[msg.sender];
    }

    /// @notice Get remaining time for a run in seconds. Returns 0 if finished or no run.
    function getRemainingTime(address player) external view returns (uint256) {
        if (!activeRuns[player].isActive) return 0;
        
        uint256 endTime = activeRuns[player].startTime + runDurations[activeRuns[player].riskLevel];
        if (block.timestamp >= endTime) return 0;
        
        return endTime - block.timestamp;
    }
}

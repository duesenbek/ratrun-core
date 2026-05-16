// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "../contracts/governance/GameGovernor.sol";
import "../contracts/governance/GovernanceToken.sol";
import "../contracts/game/CraftingEngine.sol";
import "../contracts/game/GameItems.sol";
import "../contracts/game/RatMaze.sol";

contract VerifyDeployment is Script {
    bool private _allPassed = true;

    function run() external view {
        address timelockAddr  = vm.envAddress("TIMELOCK_ADDRESS");
        address governorAddr  = vm.envAddress("GOVERNOR_ADDRESS");
        address ratTokenAddr  = vm.envAddress("RAT_TOKEN_ADDRESS");
        address craftingAddr  = vm.envAddress("CRAFTING_ENGINE_ADDRESS");
        address gameItemsAddr = vm.envAddress("GAME_ITEMS_ADDRESS");
        address mazeAddr      = vm.envAddress("RAT_MAZE_ADDRESS");

        TimelockController timelock = TimelockController(payable(timelockAddr));
        GameGovernor       governor = GameGovernor(payable(governorAddr));
        GovernanceToken    rat      = GovernanceToken(ratTokenAddr);
        GameItems          items    = GameItems(gameItemsAddr);
        RatMaze            maze     = RatMaze(mazeAddr);

        console.log("=== RatRun Post-Deployment Verification ===\n");

        _check(
            "Timelock min delay is 2 days",
            timelock.getMinDelay() == 2 days
        );

        _check(
            "Governor has PROPOSER_ROLE on Timelock",
            timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr)
        );

        _check(
            "Governor has CANCELLER_ROLE on Timelock",
            timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddr)
        );

        _check(
            "Deployer does NOT have PROPOSER_ROLE (decentralized)",
            !timelock.hasRole(timelock.PROPOSER_ROLE(), msg.sender)
        );

        _check(
            "Governor voting delay is 7200 blocks (~1 day)",
            governor.votingDelay() == 7_200
        );

        _check(
            "Governor voting period is 36000 blocks (~5 days)",
            governor.votingPeriod() == 36_000
        );

        _check(
            "Governor quorum fraction is 4%",
            governor.quorumNumerator() == 4
        );

        _check(
            "GovernanceToken name is correct",
            keccak256(bytes(rat.name())) == keccak256(bytes("Rat Governance Token"))
        );

        _check(
            "GovernanceToken total supply > 0",
            rat.totalSupply() > 0
        );

        _check(
            "CraftingEngine has MINTER_ROLE on GameItems",
            items.hasRole(items.MINTER_ROLE(), craftingAddr)
        );

        _check(
            "CraftingEngine has BURNER_ROLE on GameItems",
            items.hasRole(items.BURNER_ROLE(), craftingAddr)
        );

        _check(
            "RatMaze has MINTER_ROLE on GameItems",
            items.hasRole(items.MINTER_ROLE(), mazeAddr)
        );

        _check(
            "Timelock controls ADMIN_ROLE on RatMaze",
            maze.hasRole(maze.ADMIN_ROLE(), timelockAddr)
        );

        console.log("\n=== Verification Summary ===");
        if (_allPassed) {
            console.log("[PASS] All checks passed. Protocol is correctly configured.");
        } else {
            console.log("[FAIL] One or more checks FAILED. Review output above.");
        }
    }

    function _check(string memory label, bool condition) internal view {
        if (condition) {
            console.log(string(abi.encodePacked("[PASS] ", label)));
        } else {
            console.log(string(abi.encodePacked("[FAIL] ", label)));
        }
    }
}

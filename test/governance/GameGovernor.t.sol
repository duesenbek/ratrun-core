// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../../contracts/governance/GovernanceToken.sol";
import "../../contracts/governance/GameGovernor.sol";
import "../../contracts/governance/Treasury.sol";
import "../../contracts/game/RatMaze.sol";
import "../../contracts/game/GameItems.sol";

contract GameGovernorTest is Test {
    GovernanceToken public rat;
    TimelockController public timelock;
    GameGovernor public governor;
    Treasury public treasury;
    RatMaze public maze;
    GameItems public items;

    address deployer = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address poorUser = makeAddr("poorUser"); // no tokens — below threshold

    uint256 constant INITIAL = 10_000_000e18;

    function setUp() public {
        rat = new GovernanceToken(deployer, INITIAL);
        items = new GameItems("");
        maze = new RatMaze(address(items));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            deployer
        );

        governor = new GameGovernor(IVotes(address(rat)), timelock);
        treasury = new Treasury(address(timelock), address(rat));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        maze.grantRole(maze.ADMIN_ROLE(), address(timelock));
        rat.grantRole(rat.MINTER_ROLE(), address(treasury));

        rat.transfer(alice, 2_000_000e18);
        rat.transfer(bob, 500_000e18);
        rat.transfer(carol, 500_000e18);

        vm.prank(alice);
        rat.delegate(alice);
        vm.prank(bob);
        rat.delegate(bob);
        vm.prank(carol);
        rat.delegate(carol);
        rat.delegate(deployer);

        vm.roll(block.number + 2);
    }

    function _proposal()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(maze);
        calldatas[0] = abi.encodeCall(
            RatMaze.setZoneParams,
            (2, 65, 4 minutes, 200)
        );
        desc = "Proposal #1: tune zone 2";
    }

    function test_VotingDelay_Is7200Blocks() public view {
        assertEq(governor.votingDelay(), 7_200);
    }

    function test_VotingPeriod_Is36000Blocks() public view {
        assertEq(governor.votingPeriod(), 36_000);
    }

    function test_Quorum_Is4Pct() public {
        vm.roll(block.number + 1);
        uint256 q = governor.quorum(block.number - 1);
        uint256 supply = rat.getPastTotalSupply(block.number - 1);
        assertEq(q, (supply * 4) / 100);
    }

    function test_ProposalThreshold_Is1Pct() public {
        vm.roll(block.number + 1);
        uint256 threshold = governor.proposalThreshold();
        uint256 supply = rat.getPastTotalSupply(block.number - 1);
        assertEq(threshold, supply / 100);
    }

    function test_Name() public view {
        assertEq(governor.name(), "GameGovernor");
    }

    function test_Propose_Success() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();
        vm.prank(alice);
        uint256 id = governor.propose(t, v, c, d);
        assertGt(id, 0);
    }

    function test_Propose_BelowThreshold_Reverts() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();
        // poorUser has 0 tokens — below 1% threshold
        vm.prank(poorUser);
        vm.expectRevert();
        governor.propose(t, v, c, d);
    }

    function test_FullLifecycle_ProposeVoteQueueExecute() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();

        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, d);

        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(
            uint8(governor.state(pid)),
            uint8(IGovernor.ProposalState.Active)
        );

        vm.prank(alice);
        governor.castVote(pid, 1);
        vm.prank(bob);
        governor.castVote(pid, 1);
        vm.prank(carol);
        governor.castVote(pid, 1);
        governor.castVote(pid, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(
            uint8(governor.state(pid)),
            uint8(IGovernor.ProposalState.Succeeded)
        );

        governor.queue(t, v, c, keccak256(bytes(d)));
        assertEq(
            uint8(governor.state(pid)),
            uint8(IGovernor.ProposalState.Queued)
        );

        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(t, v, c, keccak256(bytes(d)));
        assertEq(
            uint8(governor.state(pid)),
            uint8(IGovernor.ProposalState.Executed)
        );

        assertEq(maze.survivalChances(2), 65);
        assertEq(maze.runDurations(2), 4 minutes);
        assertEq(maze.scrapRewards(2), 200);
    }

    function test_Proposal_Defeated_NoQuorum() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();
        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, d);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(pid, 0);

        vm.roll(block.number + governor.votingPeriod() + 1);
        assertEq(
            uint8(governor.state(pid)),
            uint8(IGovernor.ProposalState.Defeated)
        );
    }

    function test_TimelockDelay_Enforced() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();

        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, d);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(pid, 1);
        vm.prank(bob);
        governor.castVote(pid, 1);
        vm.prank(carol);
        governor.castVote(pid, 1);
        governor.castVote(pid, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(t, v, c, keccak256(bytes(d)));

        vm.expectRevert();
        governor.execute(t, v, c, keccak256(bytes(d)));
    }

    function test_CastVote_Against() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();
        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, d);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(pid, 0);
        (uint256 against, , ) = governor.proposalVotes(pid);
        assertGt(against, 0);
    }

    function test_CastVote_Abstain() public {
        (
            address[] memory t,
            uint256[] memory v,
            bytes[] memory c,
            string memory d
        ) = _proposal();
        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, d);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(alice);
        governor.castVote(pid, 2);
        (, , uint256 abstain) = governor.proposalVotes(pid);
        assertGt(abstain, 0);
    }
}

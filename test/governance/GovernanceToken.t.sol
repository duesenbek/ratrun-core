// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/governance/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public rat;

    address admin = address(this);
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    uint256 constant INITIAL = 1_000_000e18;

    function setUp() public {
        rat = new GovernanceToken(admin, INITIAL);
    }

    function test_InitialState() public view {
        assertEq(rat.totalSupply(), INITIAL);
        assertEq(rat.balanceOf(admin), INITIAL);
        assertEq(rat.name(), "Rat Governance Token");
        assertEq(rat.symbol(), "RAT");
    }

    function test_AdminHasMinterRole() public view {
        assertTrue(rat.hasRole(rat.MINTER_ROLE(), admin));
    }

    function test_AdminHasAdminRole() public view {
        assertTrue(rat.hasRole(rat.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Mint_Success() public {
        rat.mint(alice, 500e18);
        assertEq(rat.balanceOf(alice), 500e18);
        assertEq(rat.totalSupply(), INITIAL + 500e18);
    }

    function test_Mint_ZeroAddress_Reverts() public {
        vm.expectRevert(GovernanceToken.GovernanceToken__ZeroAddress.selector);
        rat.mint(address(0), 1e18);
    }

    function test_Mint_ZeroAmount_Reverts() public {
        vm.expectRevert(GovernanceToken.GovernanceToken__ZeroAmount.selector);
        rat.mint(alice, 0);
    }

    function test_Mint_OnlyMinter_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        rat.mint(alice, 1e18);
    }

    function test_Burn_Success() public {
        rat.transfer(alice, 500e18);
        uint256 supplyBefore = rat.totalSupply();
        vm.prank(alice);
        rat.burn(200e18);
        assertEq(rat.balanceOf(alice), 300e18);
        assertEq(rat.totalSupply(), supplyBefore - 200e18);
    }

    function test_Burn_ZeroAmount_Reverts() public {
        vm.expectRevert(GovernanceToken.GovernanceToken__ZeroAmount.selector);
        rat.burn(0);
    }

    function test_Delegate_UpdatesVotingPower() public {
        rat.delegate(admin);
        assertEq(rat.getVotes(admin), INITIAL);
    }

    function test_Delegate_Transfer_UpdatesVotes() public {
        rat.delegate(admin);
        rat.transfer(alice, 1_000e18);
        assertEq(rat.getVotes(admin), INITIAL - 1_000e18);
    }

    function test_DelegateTo_Other() public {
        rat.transfer(alice, 1_000e18);
        vm.prank(alice);
        rat.delegate(bob);
        assertEq(rat.getVotes(bob), 1_000e18);
        assertEq(rat.getVotes(alice), 0);
    }

    function test_Permit_Works() public {
        uint256 pk = 0xBEEF;
        address signer = vm.addr(pk);
        rat.transfer(signer, 100e18);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            rat.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer, bob, 50e18, rat.nonces(signer), deadline
            ))
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        rat.permit(signer, bob, 50e18, deadline, v, r, s);
        assertEq(rat.allowance(signer, bob), 50e18);
    }

    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(GovernanceToken.GovernanceToken__ZeroAddress.selector);
        new GovernanceToken(address(0), INITIAL);
    }

    function test_Constructor_ZeroSupply_NoMint() public {
        GovernanceToken t = new GovernanceToken(admin, 0);
        assertEq(t.totalSupply(), 0);
    }

    function testFuzz_Mint_IncreasesSupply(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        uint256 before = rat.totalSupply();
        rat.mint(alice, amount);
        assertEq(rat.totalSupply(), before + amount);
    }

    function testFuzz_Burn_DecreasesSupply(uint256 amount) public {
        amount = bound(amount, 1, INITIAL);
        uint256 before = rat.totalSupply();
        rat.burn(amount);
        assertEq(rat.totalSupply(), before - amount);
    }
}

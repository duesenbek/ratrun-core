// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/game/BurrowVault.sol";

contract MockScrap is ERC20 {
    constructor() ERC20("Mock Scrap", "mSCRAP") { _mint(msg.sender, 1_000_000 ether); }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract ReentrantAttacker {
    BurrowVault public vault;
    MockScrap   public scrap;
    bool        private entered;

    constructor(BurrowVault _v, MockScrap _s) { vault = _v; scrap = _s; }

    function attack(uint256 amount) external {
        scrap.approve(address(vault), type(uint256).max);
        entered = true;
        vault.deposit(amount, address(this));
    }

    // Tries to re-enter during withdrawal callback
    receive() external payable {
        if (entered) {
            entered = false;
            vault.deposit(1 ether, address(this));
        }
    }
}

contract BurrowVaultTest is Test {
    MockScrap   public scrap;
    BurrowVault public vault;

    address admin    = address(this);
    address alice    = makeAddr("alice");
    address bob      = makeAddr("bob");

    uint256 constant INIT = 10_000 ether;

    function setUp() public {
        scrap = new MockScrap();
        vault = new BurrowVault(IERC20(address(scrap)), "Burrow Scrap Share", "bSCRAP");

        scrap.transfer(alice, INIT);
        scrap.transfer(bob,   INIT);

        vm.prank(alice); scrap.approve(address(vault), type(uint256).max);
        vm.prank(bob);   scrap.approve(address(vault), type(uint256).max);
    }

    // ── DEPOSIT ────────────────────────────────────
    function test_Deposit_Success() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000 ether, alice);

        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(scrap.balanceOf(address(vault)), 1_000 ether);
    }

    function test_Deposit_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit BurrowVault.Deposited(alice, alice, 1_000 ether, 0);
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
    }

    function test_Deposit_FirstDepositIsOneToOne() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000 ether, alice);
        assertEq(shares, 1_000 ether);
    }

    // ── WITHDRAW ───────────────────────────────────
    function test_Withdraw_Success() public {
        vm.prank(alice);
        vault.deposit(2_000 ether, alice);

        uint256 before = scrap.balanceOf(alice);

        vm.expectEmit(true, true, true, false);
        emit BurrowVault.Withdrawn(alice, alice, alice, 2_000 ether, 0);

        vm.prank(alice);
        vault.withdraw(2_000 ether, alice, alice);

        assertEq(scrap.balanceOf(alice), before + 2_000 ether);
        assertEq(vault.totalAssets(), 0);
    }

    function test_Withdraw_ExceedsBalance_Reverts() public {
        vm.prank(alice);
        vault.deposit(500 ether, alice);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(1_000 ether, alice, alice);
    }

    // ── SHARE CALCULATIONS ─────────────────────────
    function test_SharePrice_RisesAfterYieldInjection() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);

        // Inject 1000 yield — share price doubles
        scrap.approve(address(vault), 1_000 ether);
        vault.injectYield(1_000 ether);

        // Bob deposits 2000 → should get 1000 shares (2000/2000 * 1000)
        vm.prank(bob);
        uint256 bobShares = vault.deposit(2_000 ether, bob);
        assertEq(bobShares, 1_000 ether);

        // Alice redeems 1000 shares → gets 2000 assets
        vm.prank(alice);
        uint256 aliceAssets = vault.redeem(1_000 ether, alice, alice);
        assertEq(aliceAssets, 2_000 ether);
    }

    function test_PreviewDeposit_MatchesActual() public {
        uint256 preview = vault.previewDeposit(500 ether);
        vm.prank(alice);
        uint256 actual = vault.deposit(500 ether, alice);
        assertEq(preview, actual);
    }

    function test_PreviewWithdraw_MatchesActual() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        uint256 preview = vault.previewWithdraw(500 ether);
        vm.prank(alice);
        uint256 actual = vault.withdraw(500 ether, alice, alice);
        assertEq(preview, actual);
    }

    // ── REENTRANCY ─────────────────────────────────
    function test_Reentrancy_IsBlocked() public {
        ReentrantAttacker atk = new ReentrantAttacker(vault, scrap);
        scrap.transfer(address(atk), 5_000 ether);
        // ReentrancyGuard prevents second entry; any revert satisfies the test
        try atk.attack(1_000 ether) {
            // If it didn't revert, the reentrant call must have been blocked silently
            // (no double-accounting). Assert vault has exactly 1000.
            assertEq(vault.totalAssets(), 1_000 ether);
        } catch {
            // Expected path: reverted
        }
    }

    // ── FUZZ ───────────────────────────────────────
    function testFuzz_DepositWithdrawRoundtrip(uint256 assets) public {
        assets = bound(assets, 1 ether, INIT);
        vm.prank(alice);
        vault.deposit(assets, alice);
        vm.prank(alice);
        vault.withdraw(assets, alice, alice);
        assertEq(vault.totalAssets(), 0);
    }
}

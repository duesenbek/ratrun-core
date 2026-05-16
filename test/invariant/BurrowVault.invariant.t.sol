// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../contracts/game/BurrowVault.sol";

contract VaultAsset is ERC20 {
    constructor() ERC20("Asset", "AST") { _mint(msg.sender, 1_000_000_000e18); }
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract VaultInvariantHandler is Test {
    BurrowVault public vault;
    VaultAsset  public asset;
    address[]   public actors;

    uint256 public ghost_deposited;
    uint256 public ghost_withdrawn;

    constructor(BurrowVault _vault, VaultAsset _asset) {
        vault = _vault;
        asset = _asset;
        for (uint256 i = 0; i < 4; i++) {
            address a = makeAddr(string(abi.encodePacked("va", i)));
            actors.push(a);
            asset.mint(a, 10_000_000e18);
            vm.prank(a);
            asset.approve(address(vault), type(uint256).max);
        }
    }

    function deposit(uint256 seed, uint256 assets) external {
        address actor = actors[seed % actors.length];
        assets = bound(assets, 1e12, 500_000e18);
        vm.prank(actor);
        uint256 shares = vault.deposit(assets, actor);
        ghost_deposited += assets;
        assertGt(shares, 0);
    }

    function redeem(uint256 seed, uint256 pct) external {
        address actor = actors[seed % actors.length];
        uint256 bal   = vault.balanceOf(actor);
        if (bal == 0) return;
        pct = bound(pct, 1, 100);
        uint256 shares = (bal * pct) / 100;
        if (shares == 0) return;
        vm.prank(actor);
        uint256 assets = vault.redeem(shares, actor, actor);
        ghost_withdrawn += assets;
    }

    function injectYield(uint256 amount) external {
        amount = bound(amount, 1e12, 100_000e18);
        asset.mint(address(vault), amount);
    }
}

contract BurrowVaultInvariantTest is Test {
    BurrowVault          public vault;
    VaultAsset           public asset;
    VaultInvariantHandler public handler;

    function setUp() public {
        asset   = new VaultAsset();
        vault   = new BurrowVault(IERC20(address(asset)), "bAST", "bAST");
        handler = new VaultInvariantHandler(vault, asset);
        targetContract(address(handler));
    }

    function invariant_TotalAssets_MatchesBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }

    function invariant_ZeroSupply_ZeroAssets() public view {
        if (vault.totalSupply() == 0) {
            assertEq(vault.totalAssets(), 0);
        }
    }

    function invariant_SharePrice_NeverFallsBelowOne() public view {
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;
        uint256 priceX18 = (vault.totalAssets() * 1e18) / supply;
        assertGe(priceX18, 1e18 - 2);
    }

    function invariant_MaxWithdraw_LeqTotalAssets() public view {
        for (uint256 i = 0; i < 4; i++) {
            address a = handler.actors(i);
            assertLe(vault.maxWithdraw(a), vault.totalAssets());
        }
    }
}

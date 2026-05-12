// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/game/RatFactory.sol";
import "../contracts/game/BurrowVault.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") { _mint(msg.sender, 1_000_000 ether); }
}

contract RatFactoryTest is Test {
    RatFactory  public factory;
    MockToken   public token;

    address owner   = address(this);
    address nonOwner = makeAddr("nonOwner");

    bytes32 constant SALT_A = keccak256("ratrun.vault.v1");
    bytes32 constant SALT_B = keccak256("ratrun.vault.v2");

    function setUp() public {
        factory = new RatFactory();
        token   = new MockToken();
    }

    // ── CREATE (non-deterministic) ─────────────────
    function test_Deploy_CreateWorks() public {
        address vault = factory.deployVault(
            IERC20(address(token)),
            "Burrow Share",
            "bTKN"
        );
        assertNotEq(vault, address(0));
        assertEq(factory.vaultCount(), 1);
        assertEq(factory.deployedVaults(0), vault);
    }

    function test_Deploy_EmitsEvent() public {
        vm.expectEmit(false, true, false, false);
        emit RatFactory.VaultDeployed(address(0), address(token), bytes32(0), false);

        factory.deployVault(IERC20(address(token)), "Burrow Share", "bTKN");
    }

    function test_Deploy_OnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        factory.deployVault(IERC20(address(token)), "Burrow Share", "bTKN");
    }

    // ── CREATE2 (deterministic) ────────────────────
    function test_Create2_DeployWorks() public {
        address vault = factory.deployVaultDeterministic(
            IERC20(address(token)),
            "Burrow Share",
            "bTKN",
            SALT_A
        );
        assertNotEq(vault, address(0));
        assertEq(factory.vaultCount(), 1);
    }

    function test_Create2_DeterministicAddress() public {
        // Predict before deploy
        address predicted = factory.computeVaultAddress(
            IERC20(address(token)),
            "Burrow Share",
            "bTKN",
            SALT_A
        );

        // Deploy
        address actual = factory.deployVaultDeterministic(
            IERC20(address(token)),
            "Burrow Share",
            "bTKN",
            SALT_A
        );

        assertEq(predicted, actual, "CREATE2 address must be deterministic");
    }

    function test_Create2_SameSalt_Reverts() public {
        factory.deployVaultDeterministic(
            IERC20(address(token)), "Burrow Share", "bTKN", SALT_A
        );
        // Second deploy with same salt must fail
        vm.expectRevert("RatFactory: CREATE2 failed");
        factory.deployVaultDeterministic(
            IERC20(address(token)), "Burrow Share", "bTKN", SALT_A
        );
    }

    function test_Create2_DifferentSalts_DifferentAddresses() public {
        address vaultA = factory.deployVaultDeterministic(
            IERC20(address(token)), "Vault A", "bA", SALT_A
        );
        address vaultB = factory.deployVaultDeterministic(
            IERC20(address(token)), "Vault B", "bB", SALT_B
        );
        assertNotEq(vaultA, vaultB);
        assertEq(factory.vaultCount(), 2);
    }

    function test_Create2_OnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        factory.deployVaultDeterministic(
            IERC20(address(token)), "Vault", "bV", SALT_A
        );
    }

    // ── VAULT IS FUNCTIONAL AFTER FACTORY DEPLOY ───
    function test_DeployedVault_Functional() public {
        address vaultAddr = factory.deployVaultDeterministic(
            IERC20(address(token)), "Burrow Share", "bTKN", SALT_A
        );
        BurrowVault vault = BurrowVault(vaultAddr);

        token.approve(vaultAddr, 1_000 ether);
        uint256 shares = vault.deposit(1_000 ether, owner);
        assertGt(shares, 0);
    }

    // ── GET DEPLOYED VAULTS ────────────────────────
    function test_GetDeployedVaults_ReturnsAll() public {
        factory.deployVault(IERC20(address(token)), "V1", "b1");
        factory.deployVaultDeterministic(IERC20(address(token)), "V2", "b2", SALT_A);

        address[] memory vaults = factory.getDeployedVaults();
        assertEq(vaults.length, 2);
    }
}

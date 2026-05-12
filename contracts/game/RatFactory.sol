// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BurrowVault.sol";

/// @title RatFactory
/// @notice Deploys BurrowVault contracts via CREATE and CREATE2.
/// @dev CREATE2 allows deterministic, predictable vault addresses —
///      address can be computed off-chain before deployment.
contract RatFactory is Ownable {
    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    /// @notice All deployed vault addresses.
    address[] public deployedVaults;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event VaultDeployed(address indexed vault, address indexed asset, bytes32 salt, bool deterministic);

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────
    constructor() Ownable(msg.sender) {}

    // ─────────────────────────────────────────────
    // CREATE — standard deployment
    // ─────────────────────────────────────────────

    /// @notice Deploy a new BurrowVault using regular CREATE.
    function deployVault(
        IERC20 asset,
        string calldata name,
        string calldata symbol
    ) external onlyOwner returns (address vault) {
        vault = address(new BurrowVault(asset, name, symbol));
        deployedVaults.push(vault);
        emit VaultDeployed(vault, address(asset), bytes32(0), false);
    }

    // ─────────────────────────────────────────────
    // CREATE2 — deterministic deployment
    // ─────────────────────────────────────────────

    /// @notice Deploy a new BurrowVault using CREATE2 with a user-provided salt.
    /// @dev    Address can be predicted off-chain with computeVaultAddress().
    function deployVaultDeterministic(
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    ) external onlyOwner returns (address vault) {
        bytes memory bytecode = abi.encodePacked(
            type(BurrowVault).creationCode,
            abi.encode(asset, name, symbol)
        );

        assembly {
            vault := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        require(vault != address(0), "RatFactory: CREATE2 failed");
        deployedVaults.push(vault);
        emit VaultDeployed(vault, address(asset), salt, true);
    }

    // ─────────────────────────────────────────────
    // PREDICT ADDRESS
    // ─────────────────────────────────────────────

    /// @notice Compute the address of a vault BEFORE deploying it.
    /// @dev    Matches the address produced by deployVaultDeterministic().
    function computeVaultAddress(
        IERC20 asset,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    ) external view returns (address predicted) {
        bytes memory bytecode = abi.encodePacked(
            type(BurrowVault).creationCode,
            abi.encode(asset, name, symbol)
        );
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        predicted = address(uint160(uint256(hash)));
    }

    // ─────────────────────────────────────────────
    // VIEW
    // ─────────────────────────────────────────────

    function getDeployedVaults() external view returns (address[] memory) {
        return deployedVaults;
    }

    function vaultCount() external view returns (uint256) {
        return deployedVaults.length;
    }
}

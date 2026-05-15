// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ResourceAMM.sol";

/// @title MarketFactory
/// @notice Deploys Night Market AMM pools via CREATE2 — mirrors RatFactory.sol architecture.
/// @dev    Key design decisions:
///         - CREATE2 enables deterministic, off-chain-computable pool addresses.
///         - Duplicate pool prevention: sorted token pair mapped to deployed address.
///         - Owners can deploy new pools; anyone can query existing ones.
///         - Style intentionally mirrors RatFactory.sol for project consistency.
contract MarketFactory is Ownable {
    // ─────────────────────────────────────────────
    // CUSTOM ERRORS
    // ─────────────────────────────────────────────
    error MarketFactory__PoolExists();
    error MarketFactory__IdenticalTokens();
    error MarketFactory__ZeroAddress();
    error MarketFactory__CREATE2Failed();

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    /// @notice All deployed pool addresses.
    address[] public deployedPools;

    /// @notice Canonical (sorted) token pair → pool address. Zero if not deployed.
    mapping(address => mapping(address => address)) public getPool;

    /// @notice Protocol treasury address passed to each new pool.
    address public treasury;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event PoolDeployed(
        address indexed pool,
        address indexed token0,
        address indexed token1,
        bytes32 salt
    );
    event TreasuryUpdated(address indexed newTreasury);

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    /// @param treasury_ Initial treasury address for fee collection.
    constructor(address treasury_) Ownable(msg.sender) {
        if (treasury_ == address(0)) revert MarketFactory__ZeroAddress();
        treasury = treasury_;
    }

    // ─────────────────────────────────────────────
    // DEPLOY — CREATE2 deterministic pool
    // ─────────────────────────────────────────────

    /// @notice Deploy a new ResourceAMM pool for `tokenA` / `tokenB` using CREATE2.
    /// @dev    Salt is derived from the sorted token pair — ensures one pool per pair.
    ///         Address can be predicted off-chain with computePoolAddress().
    /// @param  tokenA   First token of the pair.
    /// @param  tokenB   Second token of the pair.
    /// @param  lpName   LP token name  (e.g. "Night Market SCRAP/CHIP LP").
    /// @param  lpSymbol LP token symbol (e.g. "nmSCRAP-CHIP").
    /// @return pool     Address of the newly deployed ResourceAMM contract.
    function deployPool(
        IERC20 tokenA,
        IERC20 tokenB,
        string calldata lpName,
        string calldata lpSymbol
    ) external onlyOwner returns (address pool) {
        if (address(tokenA) == address(0) || address(tokenB) == address(0))
            revert MarketFactory__ZeroAddress();
        if (address(tokenA) == address(tokenB))
            revert MarketFactory__IdenticalTokens();

        // Canonical sort
        (address t0, address t1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        if (getPool[t0][t1] != address(0)) revert MarketFactory__PoolExists();

        // Salt = keccak256(sorted pair)
        bytes32 salt = keccak256(abi.encodePacked(t0, t1));

        // CREATE2 deployment
        bytes memory bytecode = abi.encodePacked(
            type(ResourceAMM).creationCode,
            abi.encode(IERC20(t0), IERC20(t1), lpName, lpSymbol, treasury)
        );

        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (pool == address(0)) revert MarketFactory__CREATE2Failed();

        // Register
        getPool[t0][t1] = pool;
        getPool[t1][t0] = pool; // both directions
        deployedPools.push(pool);

        emit PoolDeployed(pool, t0, t1, salt);
    }

    // ─────────────────────────────────────────────
    // PREDICT ADDRESS
    // ─────────────────────────────────────────────

    /// @notice Compute the address of a pool BEFORE deploying it.
    /// @dev    Matches the address produced by deployPool().
    ///         Useful for front-ends and scripts to predict addresses off-chain.
    /// @param  tokenA   First token.
    /// @param  tokenB   Second token.
    /// @param  lpName   LP name (must match deployment params exactly).
    /// @param  lpSymbol LP symbol (must match deployment params exactly).
    /// @return predicted Deterministic pool address.
    function computePoolAddress(
        IERC20 tokenA,
        IERC20 tokenB,
        string calldata lpName,
        string calldata lpSymbol
    ) external view returns (address predicted) {
        (address t0, address t1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        bytes32 salt = keccak256(abi.encodePacked(t0, t1));
        bytes memory bytecode = abi.encodePacked(
            type(ResourceAMM).creationCode,
            abi.encode(IERC20(t0), IERC20(t1), lpName, lpSymbol, treasury)
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
    // ADMIN
    // ─────────────────────────────────────────────

    /// @notice Update the treasury address used by future pool deployments.
    /// @param  newTreasury New treasury address.
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert MarketFactory__ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    // ─────────────────────────────────────────────
    // VIEW
    // ─────────────────────────────────────────────

    /// @notice Return all deployed pool addresses.
    function getDeployedPools() external view returns (address[] memory) {
        return deployedPools;
    }

    /// @notice Total number of deployed pools.
    function poolCount() external view returns (uint256) {
        return deployedPools.length;
    }
}

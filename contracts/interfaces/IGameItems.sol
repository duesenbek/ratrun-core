// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IGameItems
/// @notice Interface for the RatRun ERC1155 inventory system.
interface IGameItems {
    // ─────────────────────────────────────────────
    // ITEM IDs
    // ─────────────────────────────────────────────
    function SCRAP()   external view returns (uint256);
    function BATTERY() external view returns (uint256);
    function WIRE()    external view returns (uint256);
    function CHIP()    external view returns (uint256);
    function RELIC()   external view returns (uint256);
    function DRILL()   external view returns (uint256);
    function GPU()     external view returns (uint256);
    function SERVER()  external view returns (uint256);

    // ─────────────────────────────────────────────
    // CORE ERC1155
    // ─────────────────────────────────────────────
    function balanceOf(address account, uint256 id) external view returns (uint256);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function burnFrom(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function burnBatchFrom(
        address account,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    function totalSupply(uint256 id) external view returns (uint256);
}

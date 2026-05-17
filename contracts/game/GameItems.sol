// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

/// @title GameItems
/// @notice ERC1155 inventory system for the RatRun underground economy.
/// @dev Items have a rarity tier. Minting/burning is gated by roles.
contract GameItems is ERC1155, AccessControl, ERC1155Burnable, ERC1155Supply {
    // ─────────────────────────────────────────────
    // ROLES
    // ─────────────────────────────────────────────
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // ─────────────────────────────────────────────
    // ITEM IDs
    // ─────────────────────────────────────────────
    uint256 public constant SCRAP   = 0;
    uint256 public constant BATTERY = 1;
    uint256 public constant WIRE    = 2;
    uint256 public constant CHIP    = 3;
    uint256 public constant RELIC   = 4;
    uint256 public constant DRILL   = 5;
    uint256 public constant GPU     = 6;
    uint256 public constant SERVER  = 7;

    // ─────────────────────────────────────────────
    // RARITY
    // ─────────────────────────────────────────────
    enum Rarity {
        COMMON,
        UNCOMMON,
        RARE,
        EPIC,
        LEGENDARY
    }

    /// @notice Rarity tier for each item ID.
    mapping(uint256 => Rarity) public itemRarity;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────
    event ItemMinted(address indexed to, uint256 indexed id, uint256 amount, Rarity rarity);
    event ItemBurned(address indexed from, uint256 indexed id, uint256 amount);

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────
    constructor(string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);

        itemRarity[SCRAP]   = Rarity.COMMON;
        itemRarity[BATTERY] = Rarity.COMMON;
        itemRarity[WIRE]    = Rarity.COMMON;
        itemRarity[CHIP]    = Rarity.UNCOMMON;
        itemRarity[RELIC]   = Rarity.RARE;
        itemRarity[DRILL]   = Rarity.UNCOMMON;
        itemRarity[GPU]     = Rarity.EPIC;
        itemRarity[SERVER]  = Rarity.LEGENDARY;
    }

    // ─────────────────────────────────────────────
    // METADATA
    // ─────────────────────────────────────────────

    function setURI(string memory newuri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    // ─────────────────────────────────────────────
    // MINT
    // ─────────────────────────────────────────────

    function mint(address to, uint256 id, uint256 amount, bytes memory data)
        external onlyRole(MINTER_ROLE)
    {
        _mint(to, id, amount, data);
        emit ItemMinted(to, id, amount, itemRarity[id]);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            emit ItemMinted(to, ids[i], amounts[i], itemRarity[ids[i]]);
        }
    }

    // ─────────────────────────────────────────────
    // BURN (role-gated — called by CraftingEngine)
    // ─────────────────────────────────────────────

    function burnFrom(address account, uint256 id, uint256 amount)
        external onlyRole(BURNER_ROLE)
    {
        _burn(account, id, amount);
        emit ItemBurned(account, id, amount);
    }

    function burnBatchFrom(address account, uint256[] memory ids, uint256[] memory amounts)
        external onlyRole(BURNER_ROLE)
    {
        _burnBatch(account, ids, amounts);
        for (uint256 i = 0; i < ids.length; i++) {
            emit ItemBurned(account, ids[i], amounts[i]);
        }
    }

    // ─────────────────────────────────────────────
    // YUL — optimised batch balance sum
    // ─────────────────────────────────────────────

    /// @notice Sum all 8 item balances for `account` using Yul assembly.
    ///
    /// @dev  ERC1155 `_balances` is `mapping(uint256 => mapping(address => uint256))`
    ///       at storage slot 0 (OpenZeppelin ERC1155 v5.x).
    ///
    ///       Storage slot for _balances[id][account]:
    ///         innerSlot = keccak256(abi.encode(id,        0))          -- outer map
    ///         finalSlot = keccak256(abi.encode(account, innerSlot))    -- inner map
    ///
    ///       All 8 ids are unrolled; 8 sloads, zero Solidity calls.
    ///       Gas saving vs. Solidity loop: ~600–800 gas (8 * ~80–100 gas saved
    ///       per iteration by avoiding Solidity overhead: bounds checks, ABI
    ///       encoding for balanceOf, return-data copy).
    ///
    /// @param account The player whose inventory we sum.
    /// @return total  Aggregate balance across all 8 item types (ids 0-7).
    function totalInventoryBalance(address account)
        external
        view
        returns (uint256 total)
    {
        assembly {
            // We reuse the 64-byte Solidity scratch space at 0x00-0x3f.
            // Layout per iteration:
            //   [0x00, 0x20) = id  (for outer keccak)
            //   [0x20, 0x40) = 0   (outer mapping slot, _balances = slot 0)
            // Then:
            //   [0x00, 0x20) = account (for inner keccak, address is 20 bytes
            //                           but mstore writes 32 bytes, padded left)
            //   [0x20, 0x40) = innerSlot

            let acc := 0

            // ── id = 0 ──────────────────────────────────────────────────────
            mstore(0x00, 0)
            mstore(0x20, 0)
            let inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 1 ──────────────────────────────────────────────────────
            mstore(0x00, 1)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 2 ──────────────────────────────────────────────────────
            mstore(0x00, 2)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 3 ──────────────────────────────────────────────────────
            mstore(0x00, 3)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 4 ──────────────────────────────────────────────────────
            mstore(0x00, 4)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 5 ──────────────────────────────────────────────────────
            mstore(0x00, 5)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 6 ──────────────────────────────────────────────────────
            mstore(0x00, 6)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            // ── id = 7 ──────────────────────────────────────────────────────
            mstore(0x00, 7)
            mstore(0x20, 0)
            inner := keccak256(0x00, 0x40)
            mstore(0x00, account)
            mstore(0x20, inner)
            acc := add(acc, sload(keccak256(0x00, 0x40)))

            total := acc
        }
    }

    /// @notice Pure-Solidity equivalent — benchmark baseline.
    /// @dev    Intentionally identical logic to totalInventoryBalance but
    ///         implemented in idiomatic Solidity so gas snapshots can be
    ///         compared in GameItemsBenchmark.t.sol.
    function totalInventoryBalanceSolidity(address account)
        external
        view
        returns (uint256 total)
    {
        for (uint256 i = 0; i < 8; i++) {
            total += balanceOf(account, i);
        }
    }

    // ─────────────────────────────────────────────
    // OVERRIDES
    // ─────────────────────────────────────────────
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

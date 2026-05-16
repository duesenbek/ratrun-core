// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/loot/LootDrop.sol";
import "../../contracts/game/GameItems.sol";

contract MockVRFWrapper {
    uint256 private _nextRequestId = 1;
    address public lastConsumer;
    uint256 public lastRequestId;

    function requestRandomWords(
        uint32,
        uint16,
        uint32,
        bytes calldata
    ) external returns (uint256 requestId) {
        requestId = _nextRequestId++;
        lastConsumer = msg.sender;
        lastRequestId = requestId;
    }

    function calculateRequestPrice(uint32, uint32) external pure returns (uint256) {
        return 0.1 ether;
    }

    function link() external pure returns (address) { return address(0); }
    function linkNativeFeed() external pure returns (address) { return address(0); }

    function fulfillRequest(address consumer, uint256 requestId, uint256[] memory words) external {
        LootDrop(consumer).rawFulfillRandomWords(requestId, words);
    }
}

contract LootDropTest is Test {
    LootDrop        public lootDrop;
    GameItems       public items;
    MockVRFWrapper  public vrf;

    address admin  = address(this);
    address maze   = makeAddr("maze");
    address player = makeAddr("player");

    function setUp() public {
        items    = new GameItems("https://ratrun.io/api/items/{id}.json");
        vrf      = new MockVRFWrapper();
        lootDrop = new LootDrop(admin, address(items), address(vrf));

        items.grantRole(items.MINTER_ROLE(), address(lootDrop));
        lootDrop.grantRole(lootDrop.MAZE_ROLE(), maze);
    }

    function test_Constructor_SetsFields() public view {
        assertEq(address(lootDrop.gameItems()), address(items));
        assertEq(address(lootDrop.vrfWrapper()), address(vrf));
    }

    function test_Constructor_ZeroAdmin_Reverts() public {
        vm.expectRevert(LootDrop.LootDrop__ZeroAddress.selector);
        new LootDrop(address(0), address(items), address(vrf));
    }

    function test_Constructor_ZeroItems_Reverts() public {
        vm.expectRevert(LootDrop.LootDrop__ZeroAddress.selector);
        new LootDrop(admin, address(0), address(vrf));
    }

    function test_Constructor_ZeroVRF_Reverts() public {
        vm.expectRevert(LootDrop.LootDrop__ZeroAddress.selector);
        new LootDrop(admin, address(items), address(0));
    }

    function test_RequestLoot_OnlyMaze() public {
        vm.expectRevert();
        lootDrop.requestLoot(player, 1);
    }

    function test_RequestLoot_Success() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 1);
        assertGt(reqId, 0);
        assertTrue(lootDrop.hasPendingRequest(player));
    }

    function test_RequestLoot_PendingRequest_Reverts() public {
        vm.prank(maze);
        lootDrop.requestLoot(player, 1);

        vm.prank(maze);
        vm.expectRevert(LootDrop.LootDrop__PendingRequest.selector);
        lootDrop.requestLoot(player, 1);
    }

    function test_RequestLoot_Cooldown_Reverts() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 1);

        uint256[] memory words = new uint256[](2);
        words[0] = 42;
        words[1] = 80;
        vrf.fulfillRequest(address(lootDrop), reqId, words);

        vm.prank(maze);
        vm.expectRevert();
        lootDrop.requestLoot(player, 1);
    }

    function test_FulfillRandomWords_OnlyVRF() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 1);

        uint256[] memory words = new uint256[](2);
        words[0] = 0;
        words[1] = 0;

        vm.expectRevert(LootDrop.LootDrop__NotVRFWrapper.selector);
        lootDrop.rawFulfillRandomWords(reqId, words);
    }

    function test_FulfillRandomWords_Zone1_CommonLoot() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 1);

        uint256[] memory words = new uint256[](2);
        words[0] = 0;
        words[1] = 99;
        vrf.fulfillRequest(address(lootDrop), reqId, words);

        assertFalse(lootDrop.hasPendingRequest(player));
        (,, bool fulfilled) = lootDrop.getLootRequest(reqId);
        assertTrue(fulfilled);
    }

    function test_FulfillRandomWords_Zone3_LegendaryLoot() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 3);

        uint256[] memory words = new uint256[](2);
        words[0] = 0;
        words[1] = 0;
        vrf.fulfillRequest(address(lootDrop), reqId, words);

        assertEq(items.balanceOf(player, items.SERVER()), 1);
    }

    function test_FulfillRandomWords_AlreadyFulfilled_Reverts() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 1);

        uint256[] memory words = new uint256[](2);
        words[0] = 5;
        words[1] = 50;
        vrf.fulfillRequest(address(lootDrop), reqId, words);

        vm.prank(address(vrf));
        vm.expectRevert(LootDrop.LootDrop__AlreadyFulfilled.selector);
        lootDrop.rawFulfillRandomWords(reqId, words);
    }

    function test_FulfillRandomWords_UnknownRequest_Reverts() public {
        uint256[] memory words = new uint256[](2);
        words[0] = 0;
        words[1] = 0;
        vm.prank(address(vrf));
        vm.expectRevert(LootDrop.LootDrop__RequestNotFound.selector);
        lootDrop.rawFulfillRandomWords(9999, words);
    }

    function test_SetCooldownDuration_OnlyAdmin() public {
        lootDrop.setCooldownDuration(5 minutes);
        assertEq(lootDrop.cooldownDuration(), 5 minutes);
    }

    function test_SetCooldownDuration_NotAdmin_Reverts() public {
        vm.prank(player);
        vm.expectRevert();
        lootDrop.setCooldownDuration(5 minutes);
    }

    function test_SetGameItems_OnlyAdmin() public {
        GameItems newItems = new GameItems("https://new.io/{id}.json");
        lootDrop.setGameItems(address(newItems));
        assertEq(address(lootDrop.gameItems()), address(newItems));
    }

    function test_SetGameItems_ZeroAddress_Reverts() public {
        vm.expectRevert(LootDrop.LootDrop__ZeroAddress.selector);
        lootDrop.setGameItems(address(0));
    }

    function test_GetLootRequest_Fields() public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 2);
        (address p, uint8 risk, bool f) = lootDrop.getLootRequest(reqId);
        assertEq(p, player);
        assertEq(risk, 2);
        assertFalse(f);
    }

    function testFuzz_Rarity_Zone3_AlwaysMints(uint256 w0, uint256 w1) public {
        vm.prank(maze);
        uint256 reqId = lootDrop.requestLoot(player, 3);
        uint256[] memory words = new uint256[](2);
        words[0] = w0;
        words[1] = w1;
        vrf.fulfillRequest(address(lootDrop), reqId, words);
        (,, bool fulfilled) = lootDrop.getLootRequest(reqId);
        assertTrue(fulfilled);
    }
}

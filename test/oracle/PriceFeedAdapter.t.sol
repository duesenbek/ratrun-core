// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/oracle/PriceFeedAdapter.sol";
import "../../contracts/oracle/MockAggregatorV3.sol";

contract PriceFeedAdapterTest is Test {
    MockAggregatorV3 public mock;
    PriceFeedAdapter public adapter;

    uint256 constant THRESHOLD = 1 hours;

    function setUp() public {
        mock    = new MockAggregatorV3(2000e8, 8);
        adapter = new PriceFeedAdapter(address(mock), THRESHOLD);
    }

    function test_GetLatestPrice_ReturnsFreshPrice() public view {
        assertEq(adapter.getLatestPrice(), 2000e8);
    }

    function test_Decimals_Returns8() public view {
        assertEq(adapter.decimals(), 8);
    }

    function test_StalenessThreshold_Stored() public view {
        assertEq(adapter.stalenessThreshold(), THRESHOLD);
    }

    function test_StalePrice_Reverts() public {
        vm.warp(block.timestamp + THRESHOLD + 1);
        vm.expectRevert();
        adapter.getLatestPrice();
    }

    function test_NegativePrice_Reverts() public {
        mock.setPrice(-1);
        vm.expectRevert();
        adapter.getLatestPrice();
    }

    function test_ZeroPrice_Reverts() public {
        mock.setPrice(0);
        vm.expectRevert();
        adapter.getLatestPrice();
    }

    function test_StaleRound_Reverts() public {
        mock.setStaleRound(true);
        vm.expectRevert();
        adapter.getLatestPrice();
    }

    function test_PriceUpdate_Reflects() public {
        mock.setPrice(3000e8);
        assertEq(adapter.getLatestPrice(), 3000e8);
    }

    function test_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(PriceFeedAdapter.PriceFeed__ZeroAddress.selector);
        new PriceFeedAdapter(address(0), THRESHOLD);
    }

    function test_Constructor_ZeroThreshold_Reverts() public {
        vm.expectRevert(PriceFeedAdapter.PriceFeed__ZeroThreshold.selector);
        new PriceFeedAdapter(address(mock), 0);
    }

    function test_ExactlyAtThreshold_Passes() public {
        vm.warp(block.timestamp + THRESHOLD);
        int256 price = adapter.getLatestPrice();
        assertEq(price, 2000e8);
    }

    function testFuzz_FreshPrice_AlwaysReturns(int256 price) public {
        vm.assume(price > 0);
        mock.setPrice(price);
        assertEq(adapter.getLatestPrice(), price);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChainlinkFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

interface IUniswapV2Factory {
    function getPair(address, address) external view returns (address);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract ForkIntegrationTest is Test {
    address constant CHAINLINK_ETH_USD     = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant CHAINLINK_USDC_USD    = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant USDC                  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH                  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_FACTORY    = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER     = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 forkId;

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string("https://eth.llamarpc.com"));
        forkId = vm.createFork(rpc);
        vm.selectFork(forkId);
    }

    function test_Fork_ChainlinkETHUSD_PositivePrice() public view {
        (, int256 price,, uint256 updatedAt,) = IChainlinkFeed(CHAINLINK_ETH_USD).latestRoundData();
        assertGt(price, 0, "ETH/USD must be positive");
        assertLt(block.timestamp - updatedAt, 3 hours, "ETH/USD feed too stale");
    }

    function test_Fork_ChainlinkETHUSD_Has8Decimals() public view {
        assertEq(IChainlinkFeed(CHAINLINK_ETH_USD).decimals(), 8);
    }

    function test_Fork_ChainlinkUSDCUSD_IsNearPeg() public view {
        (, int256 price,,,) = IChainlinkFeed(CHAINLINK_USDC_USD).latestRoundData();
        assertGt(price, 0.99e8, "USDC/USD below 0.99");
        assertLt(price, 1.01e8, "USDC/USD above 1.01");
    }

    function test_Fork_USDC_TotalSupply_Nonzero() public view {
        assertGt(IERC20(USDC).totalSupply(), 0);
    }

    function test_Fork_UniswapV2_USDC_WETH_PairExists() public view {
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(USDC, WETH);
        assertNotEq(pair, address(0));
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
        assertGt(uint256(r0) + uint256(r1), 0);
    }

    function test_Fork_UniswapV2_Router_Exists() public view {
        assertGt(UNISWAP_V2_ROUTER.code.length, 0, "Router has no code");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../contracts/market/MarketFactory.sol";
import "../../contracts/market/ResourceAMM.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract MarketFactoryTest is Test {
    MarketFactory public factory;
    MockERC20     public tokenA;
    MockERC20     public tokenB;
    MockERC20     public tokenC;

    address owner    = address(this);
    address treasury = makeAddr("treasury");
    address alice    = makeAddr("alice");

    function setUp() public {
        factory = new MarketFactory(treasury);
        tokenA  = new MockERC20("TokenA", "TKA");
        tokenB  = new MockERC20("TokenB", "TKB");
        tokenC  = new MockERC20("TokenC", "TKC");
    }

    function test_Constructor_SetsTreasury() public view {
        assertEq(factory.treasury(), treasury);
    }

    function test_DeployPool_Success() public {
        address pool = factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        assertNotEq(pool, address(0));
    }

    function test_DeployPool_Registered() public {
        address pool = factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        assertEq(factory.deployedPools(0), pool);
        assertEq(factory.poolCount(), 1);
    }

    function test_DeployPool_BothDirections_Mapped() public {
        address pool = factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        (address t0, address t1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));
        assertEq(factory.getPool(t0, t1), pool);
        assertEq(factory.getPool(t1, t0), pool);
    }

    function test_DeployPool_DuplicateReverts() public {
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        vm.expectRevert(MarketFactory.MarketFactory__PoolExists.selector);
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP2", "LP2");
    }

    function test_DeployPool_ReversedDuplicateReverts() public {
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        vm.expectRevert(MarketFactory.MarketFactory__PoolExists.selector);
        factory.deployPool(IERC20(address(tokenB)), IERC20(address(tokenA)), "LP2", "LP2");
    }

    function test_DeployPool_IdenticalTokensReverts() public {
        vm.expectRevert(MarketFactory.MarketFactory__IdenticalTokens.selector);
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenA)), "LP", "LP");
    }

    function test_DeployPool_ZeroAddressReverts() public {
        vm.expectRevert(MarketFactory.MarketFactory__ZeroAddress.selector);
        factory.deployPool(IERC20(address(0)), IERC20(address(tokenB)), "LP", "LP");
    }

    function test_DeployPool_OnlyOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
    }

    function test_ComputePoolAddress_MatchesDeploy() public {
        address predicted = factory.computePoolAddress(
            IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP"
        );
        address actual = factory.deployPool(
            IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP"
        );
        assertEq(predicted, actual);
    }

    function test_DeployMultiplePools() public {
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP-AB", "LPAB");
        factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenC)), "LP-AC", "LPAC");
        factory.deployPool(IERC20(address(tokenB)), IERC20(address(tokenC)), "LP-BC", "LPBC");
        assertEq(factory.poolCount(), 3);
        assertEq(factory.getDeployedPools().length, 3);
    }

    function test_SetTreasury_OnlyOwner() public {
        factory.setTreasury(alice);
        assertEq(factory.treasury(), alice);
    }

    function test_SetTreasury_ZeroAddress_Reverts() public {
        vm.expectRevert(MarketFactory.MarketFactory__ZeroAddress.selector);
        factory.setTreasury(address(0));
    }

    function test_SetTreasury_NotOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.setTreasury(alice);
    }

    function test_DeployedPool_HasCorrectTokens() public {
        address pool = factory.deployPool(IERC20(address(tokenA)), IERC20(address(tokenB)), "LP", "LP");
        ResourceAMM amm = ResourceAMM(pool);
        address t0 = address(amm.token0());
        address t1 = address(amm.token1());
        assertTrue(
            (t0 == address(tokenA) && t1 == address(tokenB)) ||
            (t0 == address(tokenB) && t1 == address(tokenA))
        );
    }

    function test_Constructor_ZeroTreasury_Reverts() public {
        vm.expectRevert(MarketFactory.MarketFactory__ZeroAddress.selector);
        new MarketFactory(address(0));
    }
}

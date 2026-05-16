// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../contracts/governance/GovernanceToken.sol";
import "../../contracts/governance/Treasury.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MK") { _mint(msg.sender, 1_000_000e18); }
}

contract TreasuryTest is Test {
    GovernanceToken    public rat;
    TimelockController public timelock;
    Treasury           public treasury;
    MockToken          public mockToken;

    address admin   = address(this);
    address alice   = makeAddr("alice");
    address bob     = makeAddr("bob");

    function setUp() public {
        rat = new GovernanceToken(admin, 1_000_000e18);

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = admin;
        executors[0] = address(0);
        timelock = new TimelockController(0, proposers, executors, admin);

        treasury = new Treasury(address(timelock), address(rat));
        rat.grantRole(rat.MINTER_ROLE(), address(treasury));

        mockToken = new MockToken();
        mockToken.transfer(address(treasury), 100_000e18);
        vm.deal(address(treasury), 10 ether);
    }

    function test_Timelock_IsSet() public view {
        assertEq(treasury.timelock(), address(timelock));
    }

    function test_GovToken_IsSet() public view {
        assertEq(address(treasury.govToken()), address(rat));
    }

    function test_ReceiveETH() public {
        uint256 before = address(treasury).balance;
        payable(address(treasury)).transfer(1 ether);
        assertEq(address(treasury).balance, before + 1 ether);
    }

    function test_TransferERC20_OnlyTimelock() public {
        vm.expectRevert(Treasury.Treasury__OnlyTimelock.selector);
        treasury.transferERC20(IERC20(address(mockToken)), alice, 1_000e18);
    }

    function test_TransferERC20_ViaTimelock() public {
        uint256 before = mockToken.balanceOf(alice);
        vm.prank(address(timelock));
        treasury.transferERC20(IERC20(address(mockToken)), alice, 1_000e18);
        assertEq(mockToken.balanceOf(alice), before + 1_000e18);
    }

    function test_TransferERC20_ZeroAddress_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__ZeroAddress.selector);
        treasury.transferERC20(IERC20(address(mockToken)), address(0), 1_000e18);
    }

    function test_TransferERC20_ZeroAmount_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__ZeroAmount.selector);
        treasury.transferERC20(IERC20(address(mockToken)), alice, 0);
    }

    function test_TransferERC20_InsufficientBalance_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__InsufficientBalance.selector);
        treasury.transferERC20(IERC20(address(mockToken)), alice, type(uint256).max);
    }

    function test_TransferETH_OnlyTimelock() public {
        vm.expectRevert(Treasury.Treasury__OnlyTimelock.selector);
        treasury.transferETH(payable(alice), 1 ether);
    }

    function test_TransferETH_ViaTimelock() public {
        uint256 before = alice.balance;
        vm.prank(address(timelock));
        treasury.transferETH(payable(alice), 1 ether);
        assertEq(alice.balance, before + 1 ether);
    }

    function test_TransferETH_ZeroAmount_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__ZeroAmount.selector);
        treasury.transferETH(payable(alice), 0);
    }

    function test_TransferETH_InsufficientBalance_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__InsufficientBalance.selector);
        treasury.transferETH(payable(alice), 1000 ether);
    }

    function test_MintReward_OnlyTimelock() public {
        vm.expectRevert(Treasury.Treasury__OnlyTimelock.selector);
        treasury.mintReward(alice, 1_000e18);
    }

    function test_MintReward_ViaTimelock() public {
        uint256 before = rat.balanceOf(alice);
        vm.prank(address(timelock));
        treasury.mintReward(alice, 1_000e18);
        assertEq(rat.balanceOf(alice), before + 1_000e18);
    }

    function test_MintReward_ZeroAddress_Reverts() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.Treasury__ZeroAddress.selector);
        treasury.mintReward(address(0), 1_000e18);
    }

    function test_EthBalance_View() public view {
        assertEq(treasury.ethBalance(), 10 ether);
    }

    function test_TokenBalance_View() public view {
        assertEq(treasury.tokenBalance(IERC20(address(mockToken))), 100_000e18);
    }

    function test_Constructor_ZeroTimelock_Reverts() public {
        vm.expectRevert(Treasury.Treasury__ZeroAddress.selector);
        new Treasury(address(0), address(rat));
    }

    function test_Constructor_ZeroToken_Reverts() public {
        vm.expectRevert(Treasury.Treasury__ZeroAddress.selector);
        new Treasury(address(timelock), address(0));
    }
}

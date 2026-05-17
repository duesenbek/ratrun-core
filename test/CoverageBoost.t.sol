// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ═══════════════════════════════════════════════════════════════════════════════
// COVERAGE BOOST — добавь этот файл как test/CoverageBoost.t.sol
// Закрывает непокрытые строки в:
//   • AMMLib.sol        (77% → ~95%)
//   • BurrowVault.sol   (78% → ~95%)
//   • GameGovernor.sol  (80% → ~95%)
//   • CraftingEngineV2  (89% → ~97%)
// ═══════════════════════════════════════════════════════════════════════════════

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/libraries/AMMLib.sol";
import "../contracts/game/BurrowVault.sol";
import "../contracts/governance/GameGovernor.sol";
import "../contracts/governance/GovernanceToken.sol";
import "../contracts/game/CraftingEngine.sol";
import "../contracts/game/CraftingEngineV2.sol";
import "../contracts/game/GameItems.sol";
import "../contracts/game/RatMaze.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Вспомогательный контракт для прямого тестирования AMMLib
// ─────────────────────────────────────────────────────────────────────────────
contract AMMLibHarness {
    function getAmountOut(
        uint256 amountIn,
        uint256 rIn,
        uint256 rOut
    ) external pure returns (uint256) {
        return AMMLib.getAmountOut(amountIn, rIn, rOut);
    }
    function getAmountIn(
        uint256 amountOut,
        uint256 rIn,
        uint256 rOut
    ) external pure returns (uint256) {
        return AMMLib.getAmountIn(amountOut, rIn, rOut);
    }
    function quote(
        uint256 a0,
        uint256 r0,
        uint256 r1
    ) external pure returns (uint256) {
        return AMMLib.quote(a0, r0, r1);
    }
    function initialShares(
        uint256 a0,
        uint256 a1
    ) external pure returns (uint256) {
        return AMMLib.initialShares(a0, a1);
    }
    function subsequentShares(
        uint256 a0,
        uint256 a1,
        uint256 r0,
        uint256 r1,
        uint256 ts
    ) external pure returns (uint256) {
        return AMMLib.subsequentShares(a0, a1, r0, r1, ts);
    }
    function sqrt(uint256 y) external pure returns (uint256) {
        return AMMLib.sqrt(y);
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. AMMLib coverage
// ═══════════════════════════════════════════════════════════════════════════════
contract AMMLibCoverageTest is Test {
    AMMLibHarness h;

    function setUp() public {
        h = new AMMLibHarness();
    }

    // ── getAmountOut ──────────────────────────────────────────────────────────

    function test_AMMLib_GetAmountOut_ZeroInput_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_INPUT");
        h.getAmountOut(0, 1000 ether, 1000 ether);
    }

    function test_AMMLib_GetAmountOut_ZeroReserveIn_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.getAmountOut(1 ether, 0, 1000 ether);
    }

    function test_AMMLib_GetAmountOut_ZeroReserveOut_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.getAmountOut(1 ether, 1000 ether, 0);
    }

    function test_AMMLib_GetAmountOut_Correct() public view {
        // 1 ether in, reserves 1000/1000 → ~0.997 ether out (after 0.3% fee)
        uint256 out = h.getAmountOut(1 ether, 1000 ether, 1000 ether);
        assertGt(out, 0);
        assertLt(out, 1 ether); // must be less than input due to fee
    }

    // ── getAmountIn ───────────────────────────────────────────────────────────

    function test_AMMLib_GetAmountIn_ZeroOutput_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_OUTPUT");
        h.getAmountIn(0, 1000 ether, 1000 ether);
    }

    function test_AMMLib_GetAmountIn_ZeroReserveIn_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.getAmountIn(1 ether, 0, 1000 ether);
    }

    function test_AMMLib_GetAmountIn_OutputExceedsReserve_Reverts() public {
        // amountOut must be < reserveOut
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.getAmountIn(1000 ether, 1000 ether, 1000 ether);
    }

    function test_AMMLib_GetAmountIn_OutputEqualsReserve_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.getAmountIn(500 ether, 1000 ether, 500 ether);
    }

    function test_AMMLib_GetAmountIn_Correct() public view {
        // Want 1 ether out from reserves 1000/1000
        uint256 amtIn = h.getAmountIn(1 ether, 1000 ether, 1000 ether);
        assertGt(amtIn, 1 ether); // must pay more than output due to fee
    }

    // ── quote ─────────────────────────────────────────────────────────────────

    function test_AMMLib_Quote_ZeroAmount_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_AMOUNT");
        h.quote(0, 100 ether, 200 ether);
    }

    function test_AMMLib_Quote_ZeroReserve0_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.quote(1 ether, 0, 200 ether);
    }

    function test_AMMLib_Quote_ZeroReserve1_Reverts() public {
        vm.expectRevert("AMMLib: INSUFFICIENT_LIQUIDITY");
        h.quote(1 ether, 100 ether, 0);
    }

    function test_AMMLib_Quote_Correct() public view {
        // 1 ether of token0, reserves 100/200 → should get 2 ether of token1
        uint256 out = h.quote(1 ether, 100 ether, 200 ether);
        assertEq(out, 2 ether);
    }

    // ── initialShares ─────────────────────────────────────────────────────────

    function test_AMMLib_InitialShares_BelowMinimum_Reverts() public {
        // sqrt(1 * 1) = 1, which is <= MINIMUM_LIQUIDITY (1000)
        vm.expectRevert("AMMLib: INSUFFICIENT_INITIAL_LIQUIDITY");
        h.initialShares(1, 1);
    }

    function test_AMMLib_InitialShares_Correct() public view {
        // sqrt(1e18 * 1e18) = 1e18, minus 1000 = 1e18 - 1000
        uint256 shares = h.initialShares(1e18, 1e18);
        assertEq(shares, 1e18 - 1000);
    }

    // ── subsequentShares ──────────────────────────────────────────────────────

    function test_AMMLib_SubsequentShares_TakesMinimum() public view {
        // shares0 = (100 * 1000) / 1000 = 100
        // shares1 = (200 * 1000) / 1000 = 200  → min = 100
        uint256 shares = h.subsequentShares(100, 200, 1000, 1000, 1000);
        assertEq(shares, 100);
    }

    // ── sqrt ──────────────────────────────────────────────────────────────────

    function test_AMMLib_Sqrt_Zero() public view {
        assertEq(h.sqrt(0), 0);
    }

    function test_AMMLib_Sqrt_One() public view {
        assertEq(h.sqrt(1), 1);
    }

    function test_AMMLib_Sqrt_Two() public view {
        assertEq(h.sqrt(2), 1);
    }

    function test_AMMLib_Sqrt_Three() public view {
        assertEq(h.sqrt(3), 1);
    }

    function test_AMMLib_Sqrt_Four() public view {
        assertEq(h.sqrt(4), 2);
    }

    function test_AMMLib_Sqrt_LargeNumber() public view {
        uint256 result = h.sqrt(1e18);
        assertEq(result, 1e9);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. BurrowVault coverage
// ═══════════════════════════════════════════════════════════════════════════════
contract BurrowVaultCoverageTest is Test {
    MockToken scrap;
    BurrowVault vault;

    address alice = makeAddr("alice");

    function setUp() public {
        scrap = new MockToken();
        vault = new BurrowVault(
            IERC20(address(scrap)),
            "Burrow Share",
            "bSCRAP"
        );

        scrap.mint(alice, 100_000 ether);
        vm.prank(alice);
        scrap.approve(address(vault), type(uint256).max);

        scrap.approve(address(vault), type(uint256).max);
    }

    // покрывает mint() override
    function test_BurrowVault_Mint_Success() public {
        // mint(shares, receiver) — задаём shares, получаем assets
        uint256 sharesToMint = 500 ether;
        vm.prank(alice);
        uint256 assets = vault.mint(sharesToMint, alice);
        assertEq(vault.balanceOf(alice), sharesToMint);
        assertEq(assets, sharesToMint); // 1:1 на первом депозите
    }

    // покрывает redeem() override
    function test_BurrowVault_Redeem_Success() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);

        uint256 shares = vault.balanceOf(alice);
        uint256 before = scrap.balanceOf(alice);

        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice, alice);

        assertGt(assets, 0);
        assertEq(scrap.balanceOf(alice), before + assets);
        assertEq(vault.balanceOf(alice), 0);
    }

    // покрывает Withdrawn event из redeem()
    function test_BurrowVault_Redeem_EmitsWithdrawnEvent() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        uint256 shares = vault.balanceOf(alice);

        vm.expectEmit(true, true, true, false);
        emit BurrowVault.Withdrawn(alice, alice, alice, 0, shares);
        vm.prank(alice);
        vault.redeem(shares, alice, alice);
    }

    // покрывает previewMint()
    function test_BurrowVault_PreviewMint_MatchesActual() public {
        uint256 sharesToMint = 300 ether;
        uint256 preview = vault.previewMint(sharesToMint);
        vm.prank(alice);
        uint256 actual = vault.mint(sharesToMint, alice);
        assertEq(preview, actual);
    }

    // покрывает previewRedeem()
    function test_BurrowVault_PreviewRedeem_MatchesActual() public {
        vm.prank(alice);
        vault.deposit(1_000 ether, alice);
        uint256 shares = vault.balanceOf(alice);
        uint256 preview = vault.previewRedeem(shares);
        vm.prank(alice);
        uint256 actual = vault.redeem(shares, alice, alice);
        assertEq(preview, actual);
    }

    // покрывает injectYield onlyOwner revert
    function test_BurrowVault_InjectYield_NotOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.injectYield(100 ether);
    }

    // покрывает maxDeposit (унаследован, но вызов даёт строку в trace)
    function test_BurrowVault_MaxDeposit_IsMaxUint() public view {
        assertEq(vault.maxDeposit(alice), type(uint256).max);
    }

    // покрывает totalAssets на пустом vault
    function test_BurrowVault_TotalAssets_StartsZero() public view {
        assertEq(vault.totalAssets(), 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. GameGovernor coverage
// ═══════════════════════════════════════════════════════════════════════════════
contract GameGovernorCoverageTest is Test {
    GovernanceToken rat;
    TimelockController timelock;
    GameGovernor governor;
    RatMaze maze;
    GameItems items;

    address deployer = address(this);
    address alice = makeAddr("alice");

    uint256 constant INITIAL = 10_000_000e18;

    function setUp() public {
        rat = new GovernanceToken(deployer, INITIAL);
        items = new GameItems("https://ratrun.io/api/items/{id}.json");
        maze = new RatMaze(address(items));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(
            2 days,
            proposers,
            executors,
            deployer
        );
        governor = new GameGovernor(IVotes(address(rat)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        rat.transfer(alice, 2_000_000e18);
        vm.prank(alice);
        rat.delegate(alice);
        rat.delegate(deployer);
        vm.roll(block.number + 2);
    }

    // покрывает COUNTING_MODE()
    function test_Governor_CountingMode() public view {
        string memory mode = governor.COUNTING_MODE();
        assertGt(bytes(mode).length, 0);
    }

    // покрывает supportsInterface()
    function test_Governor_SupportsInterface_IERC165() public view {
        // IERC165 interface id = 0x01ffc9a7
        assertTrue(governor.supportsInterface(0x01ffc9a7));
    }

    function test_Governor_SupportsInterface_Unknown_ReturnsFalse()
        public
        view
    {
        assertFalse(governor.supportsInterface(0xdeadbeef));
    }

    // покрывает executor()
    function test_Governor_Executor_IsTimelock() public view {
        // _executor() внутренняя, но вызывается через proposalExecutor хелпер
        // проверяем через timelock адрес
        assertEq(address(governor.timelock()), address(timelock));
    }

    // покрывает proposalNeedsQueuing()
    function test_Governor_ProposalNeedsQueuing_True() public {
        address[] memory t = new address[](1);
        uint256[] memory v = new uint256[](1);
        bytes[] memory c = new bytes[](1);
        t[0] = address(maze);
        c[0] = abi.encodeCall(RatMaze.setZoneParams, (2, 65, 4 minutes, 200));

        vm.prank(alice);
        uint256 pid = governor.propose(t, v, c, "test");
        // После создания предложения — всегда нужна очередь (GovernorTimelockControl)
        assertTrue(governor.proposalNeedsQueuing(pid));
    }

    // покрывает cancel() — отмена активного предложения proposer-ом
    function test_Governor_Cancel_ByProposer() public {
        address[] memory t = new address[](1);
        uint256[] memory v = new uint256[](1);
        bytes[] memory c = new bytes[](1);
        t[0] = address(maze);
        c[0] = abi.encodeCall(RatMaze.setZoneParams, (2, 65, 4 minutes, 200));
        string memory d = "cancel test";

        vm.prank(alice);
        governor.propose(t, v, c, d);

        // proposer может отменить до начала голосования
        vm.prank(alice);
        governor.cancel(t, v, c, keccak256(bytes(d)));
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. CraftingEngineV2 coverage
// ═══════════════════════════════════════════════════════════════════════════════
contract CraftingEngineV2CoverageTest is Test {
    GameItems items;
    ERC1967Proxy proxy;
    CraftingEngineV2 engineV2;

    address admin = address(this);
    address player = makeAddr("player");

    uint256 constant SCRAP = 0;
    uint256 constant BATTERY = 1;
    uint256 constant GPU = 6;

    function setUp() public {
        items = new GameItems("https://ratrun.io/api/items/{id}.json");

        CraftingEngine v1Impl = new CraftingEngine();
        bytes memory initData = abi.encodeCall(
            CraftingEngine.initialize,
            (admin, address(items))
        );
        proxy = new ERC1967Proxy(address(v1Impl), initData);

        // Upgrade to V2
        CraftingEngineV2 v2Impl = new CraftingEngineV2();
        CraftingEngine(address(proxy)).upgradeToAndCall(
            address(v2Impl),
            abi.encodeCall(CraftingEngineV2.initializeV2, ())
        );
        engineV2 = CraftingEngineV2(address(proxy));

        items.grantRole(items.MINTER_ROLE(), address(engineV2));
        items.grantRole(items.BURNER_ROLE(), address(engineV2));

        items.mint(player, SCRAP, 100, "");
        items.mint(player, BATTERY, 2, "");
    }

    // покрывает setRarityMultiplier()
    function test_V2_SetRarityMultiplier_Success() public {
        engineV2.setRarityMultiplier(GPU, 25000); // 2.5x
        assertEq(engineV2.rarityMultiplier(GPU), 25000);
    }

    // покрывает setRarityMultiplier event
    function test_V2_SetRarityMultiplier_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit CraftingEngineV2.RarityMultiplierSet(GPU, 25000);
        engineV2.setRarityMultiplier(GPU, 25000);
    }

    // покрывает setRarityMultiplier unauthorized
    function test_V2_SetRarityMultiplier_Unauthorized_Reverts() public {
        vm.prank(player);
        vm.expectRevert();
        engineV2.setRarityMultiplier(GPU, 25000);
    }

    // покрывает craftWithMultiplier с нулевым multiplier (ветка mult == 0 → 10000)
    function test_V2_CraftWithMultiplier_ZeroMultiplier_FallsBackTo1x() public {
        // itemId 99 не инициализирован → multiplier = 0 → fallback 10000 (1x)
        // Добавляем рецепт с outputItemId = 99
        CraftingEngine.Ingredient[]
            memory inputs = new CraftingEngine.Ingredient[](1);
        inputs[0] = CraftingEngine.Ingredient({itemId: SCRAP, amount: 10});
        uint256 recipeId = engineV2.addRecipe(inputs, 99, 5);

        items.mint(player, SCRAP, 100, "");

        vm.prank(player);
        engineV2.craftWithMultiplier(recipeId);

        // mult = 0 → fallback 10000 → finalAmount = 5 * 10000 / 10000 = 5
        assertEq(items.balanceOf(player, 99), 5);
    }

    // покрывает craftWithMultiplier с inactive рецептом
    function test_V2_CraftWithMultiplier_InactiveRecipe_Reverts() public {
        engineV2.toggleRecipe(0);
        vm.prank(player);
        vm.expectRevert("CraftingEngineV2: recipe inactive");
        engineV2.craftWithMultiplier(0);
    }

    // покрывает craftWithMultiplier с недостаточными ингредиентами
    function test_V2_CraftWithMultiplier_InsufficientIngredients_Reverts()
        public
    {
        // player уже потратил ингредиенты — craft сначала, потом ещё раз
        vm.prank(player);
        engineV2.craftWithMultiplier(0);

        vm.prank(player);
        vm.expectRevert("CraftingEngineV2: insufficient ingredient");
        engineV2.craftWithMultiplier(0);
    }
}

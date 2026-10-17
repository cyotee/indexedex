// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {
    TestBase_BalancerV3_8020WeightedPool
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3_8020WeightedPool.sol";

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IVaultAdmin} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVaultAdmin.sol";
import {IVaultErrors} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVaultErrors.sol";
import {IVaultExtension} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVaultExtension.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenConfig, PoolRoleAccounts, PoolConfig} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {WeightedPoolFactory} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {IUnbalancedLiquidityInvariantRatioBounds} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IUnbalancedLiquidityInvariantRatioBounds.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {BalancerV3SinglePoolStandardExchange} from "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";

/// @dev Same-tx helper: push `used` then claim a fat max (E6). Atomic so a blocked refund reverts the push.
contract SinglePoolE6Helper {
    function exchangeOutAfterTransfer(
        IStandardExchange adapter_,
        IERC20 tokenIn_,
        uint256 transferAmt_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_
    ) external returns (uint256 amountIn_) {
        if (transferAmt_ > 0) {
            tokenIn_.transferFrom(msg.sender, address(adapter_), transferAmt_);
        }
        amountIn_ = adapter_.exchangeOut(
            tokenIn_, maxAmountIn_, tokenOut_, amountOut_, recipient_, true, block.timestamp + 1 hours
        );
    }
}

/// @notice WP-SEC-I-BAL-SINGLE-001 / SEC-SE-BAL-001: I1 skip-pull, E6 claimed-max refund, M3 leftover max approve.
/// @dev CREATE3 adapter on gold `TestBase_BalancerV3_8020WeightedPool` (real vault + router + pool).
///      I1 seeds booked inventory and does **not** transfer in-call. Happy push+true is not I1.
contract Adversarial_BalancerV3SinglePoolSE_Test is TestBase_BalancerV3_8020WeightedPool {
    uint256 internal constant BOOKED = 1_000e18;
    uint256 internal constant DUST_JOIN = 1e18;

    IStandardExchange internal adapter;
    IERC20 internal bpt;
    address internal attacker;
    SinglePoolE6Helper internal e6Helper;

    function setUp() public virtual override {
        TestBase_BalancerV3_8020WeightedPool.setUp();
        if (address(create3Factory) == address(0)) {
            (create3Factory, diamondPackageFactory) = InitDevService.initEnv(address(this));
            diamondFactory = diamondPackageFactory;
        }
        initDaiUsdc8020WeightedPool();

        attacker = makeAddr("attacker");
        e6Helper = new SinglePoolE6Helper();
        adapter = _deployAdapter();
        bpt = IERC20(address(daiUsdc8020WeightedPool));
    }

    function _deployAdapter() internal returns (IStandardExchange adapter_) {
        IERC20[] memory poolTokens_ = new IERC20[](2);
        poolTokens_[0] = IERC20(daiUsdc8020WeightedPoolTokens[0]);
        poolTokens_[1] = IERC20(daiUsdc8020WeightedPoolTokens[1]);
        adapter_ = IStandardExchange(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"),
                abi.encode(
                    IRouter(address(router)),
                    address(daiUsdc8020WeightedPool),
                    IERC20(address(daiUsdc8020WeightedPool)),
                    poolTokens_
                ),
                keccak256("BalancerV3SinglePoolStandardExchange")
            )
        );
    }

    /// @dev Donate residual then honest !pretransferred join so end-sync books R == leftover B.
    function _bookDaiResidual(uint256 residual_) internal {
        dai.mint(address(adapter), residual_);
        vm.startPrank(alice);
        dai.approve(address(adapter), DUST_JOIN);
        uint256 out_ = adapter.exchangeIn(
            dai, DUST_JOIN, bpt, 0, alice, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "book residual: honest join ok");
        assertGe(dai.balanceOf(address(adapter)), residual_, "seed remains after honest join");
    }

    function _assertNoMaxAllowances(IStandardExchange subject_, IERC20 token_) internal view {
        assertTrue(
            token_.allowance(address(subject_), address(router)) != type(uint256).max,
            "M3: ERC20 router allowance must not stay max"
        );
        assertTrue(
            token_.allowance(address(subject_), address(permit2)) != type(uint256).max,
            "M3: ERC20 Permit2 allowance must not stay max"
        );
        (uint160 permitAmt_,,) =
            IPermit2(address(permit2)).allowance(address(subject_), address(token_), address(router));
        assertTrue(permitAmt_ != type(uint160).max, "M3: Permit2 packed allowance must not stay uint160.max");
        assertEq(token_.allowance(address(subject_), address(router)), 0, "M3: router allowance reset");
        assertEq(token_.allowance(address(subject_), address(permit2)), 0, "M3: Permit2 ERC20 allowance reset");
        assertEq(permitAmt_, 0, "M3: Permit2 packed amount reset");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory, no in-call transfer, pretransferred=true        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 exchangeIn: booked pair inventory cannot free-credit a join.
    function test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bookDaiResidual(BOOKED);

        uint256 invBefore_ = dai.balanceOf(address(adapter));
        assertGe(invBefore_, BOOKED, "absolute inventory present (anti-theater)");
        uint256 claimed_ = BOOKED;
        uint256 attBptBefore_ = bpt.balanceOf(attacker);
        assertEq(dai.balanceOf(attacker), 0, "attacker drained");
        assertEq(dai.allowance(attacker, address(adapter)), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        adapter.exchangeIn(dai, claimed_, bpt, 0, attacker, true, block.timestamp + 1 hours);

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        adapter.exchangeIn(dai, claimed_, bpt, 0, address(caller), true, block.timestamp + 1 hours);

        assertEq(bpt.balanceOf(attacker), attBptBefore_, "I1: no free BPT");
        assertEq(dai.balanceOf(address(adapter)), invBefore_, "I1: inventory unchanged (no in-call transfer)");
    }

    /// @notice I1 exchangeOut: booked inventory cannot fund an exact-out join.
    function test_I1_exchangeOut_pretransferred_inventoryNoInCallTransfer_revertsDelta0() public {
        _bookDaiResidual(BOOKED);

        uint256 invBefore_ = dai.balanceOf(address(adapter));
        uint256 claimed_ = 50e18;
        uint256 amountOut_ = 1e18;
        uint256 attBptBefore_ = bpt.balanceOf(attacker);
        uint256 attDaiBefore_ = dai.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        adapter.exchangeOut(dai, claimed_, bpt, amountOut_, attacker, true, block.timestamp + 1 hours);

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 quoted_ = adapter.previewExchangeOut(dai, bpt, amountOut_);
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, quoted_, uint256(0))
        );
        adapter.exchangeOut(dai, claimed_, bpt, amountOut_, address(caller), true, block.timestamp + 1 hours);

        assertEq(bpt.balanceOf(attacker), attBptBefore_, "I1 out: no free BPT");
        assertEq(dai.balanceOf(attacker), attDaiBefore_, "I1 out: attacker not refunded R");
        assertEq(dai.balanceOf(address(adapter)), invBefore_, "I1 out: inventory unchanged");
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: fat claimed max + transfer only used; refund must not pay R       */
    /* ---------------------------------------------------------------------- */

    /// @notice E6: seed booked R; transfer only `used`; fat max refund must not skim R.
    /// @dev Avoid adapter.previewExchangeOut — router query* staticcall reverts on this mock.
    function test_E6_refund_fatMax_transferOnlyUsed_doesNotPayBooked() public {
        _bookDaiResidual(BOOKED);

        uint256 amountOut_ = 1e18;
        uint256 used_ = 10e18;
        uint256 fatMax_ = used_ + 50e18;
        assertLe(fatMax_ - used_, BOOKED, "current CODE refund can pay from R without reverting");

        uint256 bookedBefore_ = dai.balanceOf(address(adapter));
        dai.mint(attacker, used_);
        vm.prank(attacker);
        dai.approve(address(e6Helper), used_);

        uint256 helperBefore_ = dai.balanceOf(address(e6Helper));
        vm.prank(attacker);
        uint256 usedActual_ = e6Helper.exchangeOutAfterTransfer(
            adapter, dai, used_, fatMax_, bpt, amountOut_, address(e6Helper)
        );
        assertLe(usedActual_, used_, "used within transferred credit");
        assertGe(dai.balanceOf(address(adapter)), BOOKED, "E6: booked R stays");
        assertEq(dai.balanceOf(address(e6Helper)) - helperBefore_, used_ - usedActual_, "E6: refund credit-used");
        assertGt(bpt.balanceOf(address(e6Helper)), 0, "E6: funded join");
        assertEq(dai.balanceOf(address(adapter)), bookedBefore_, "E6: only unbooked consumed");
    }

    function test_APEX_D38_pausedJoinRevertsBalancerErrorThenSucceeds() public {
        uint256 amountIn_ = 20e18;
        authorizer.grantRole(vault.getActionId(IVaultAdmin.pausePool.selector), address(this));
        authorizer.grantRole(vault.getActionId(IVaultAdmin.unpausePool.selector), address(this));
        vault.pausePool(address(daiUsdc8020WeightedPool));
        vm.startPrank(alice);
        dai.approve(address(adapter), amountIn_);
        vm.expectRevert(abi.encodeWithSelector(IVaultErrors.PoolPaused.selector, address(daiUsdc8020WeightedPool)));
        adapter.exchangeIn(dai, amountIn_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        vault.unpausePool(address(daiUsdc8020WeightedPool));
        vm.startPrank(alice);
        uint256 out_ = adapter.exchangeIn(dai, amountIn_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out_, 0, "unpaused join issues real BPT");
        assertEq(bpt.balanceOf(alice) > 0, true);
    }

    /* ---------------------------------------------------------------------- */
    /*  M3: leftover router / Permit2 allowance after a successful op         */
    /* ---------------------------------------------------------------------- */

    /// @notice Whole BPT supply remains quotable, including locked initialization BPT.
    function test_liquidation_fullSupplyQuote() public view {
        uint256 quoted = adapter.previewExchangeIn(bpt, bpt.totalSupply(), dai);
        assertGt(quoted, 0, "full supply has a liquidation quote");
    }

    /// @notice A funded large withdrawal executes a native batch and clears its approvals.
    function test_liquidation_largeExactInAndExactOut() public {
        _assertLargeLiquidation(dai);
    }

    function test_liquidation_lowWeightFace_largeExactInAndExactOut() public {
        _assertLargeLiquidation(usdc);
    }

    function test_liquidation_nearTotalReserve_bothFaces() public view {
        uint256 reserve = bpt.balanceOf(lp);
        assertLt(reserve, bpt.totalSupply(), "initialization liquidity stays locked");
        assertGt(adapter.previewExchangeIn(bpt, reserve, dai), 0);
        assertGt(adapter.previewExchangeIn(bpt, reserve, usdc), 0);
    }

    function test_liquidation_supplyBelowOneShare_bothFaces() public {
        uint256 remainingSupply = 1e14;
        vm.startPrank(lp);
        bpt.approve(address(router), type(uint256).max);
        router.removeLiquidityProportional(address(bpt), bpt.totalSupply() - remainingSupply, new uint256[](2), false, "");
        vm.stopPrank();
        assertEq(bpt.totalSupply(), remainingSupply);
        assertGt(adapter.previewExchangeIn(bpt, remainingSupply, dai), 0);
        assertGt(adapter.previewExchangeIn(bpt, remainingSupply, usdc), 0);
    }

    function test_liquidation_mixedDecimals_6_18() public { _assertMixedDecimals(6, 18); }
    function test_liquidation_mixedDecimals_9_6() public { _assertMixedDecimals(9, 6); }

    function _assertMixedDecimals(uint8 firstDecimals, uint8 secondDecimals) private {
        IERC20[] memory faces = _deployDecimalLiquidationPool(firstDecimals, secondDecimals);
        uint256 original = vm.snapshotState();
        for (uint256 i; i < faces.length; ++i) {
            assertGt(adapter.previewExchangeIn(bpt, bpt.totalSupply(), faces[i]), 0);
            _assertLargeLiquidation(faces[i]);
            assertTrue(vm.revertToState(original));
        }
    }

    function _deployDecimalLiquidationPool(uint8 firstDecimals, uint8 secondDecimals)
        private returns (IERC20[] memory faces)
    {
        address[] memory ordered = new address[](2);
        ordered[0] = address(new MintableERC20Decimals("Liquidation A", "LQA", firstDecimals));
        ordered[1] = address(new MintableERC20Decimals("Liquidation B", "LQB", secondDecimals));
        ordered = BetterAddress._sort(ordered);
        faces = new IERC20[](2);
        TokenConfig[] memory configs = new TokenConfig[](2);
        uint256[] memory weights = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            MintableERC20Decimals token = MintableERC20Decimals(ordered[i]);
            faces[i] = IERC20(ordered[i]);
            configs[i] = standardTokenConfig(faces[i]);
            weights[i] = 5e17;
            amounts[i] = 1000 * 10 ** uint256(token.decimals());
            token.mint(lp, amounts[i]);
            _approveForAllUsers(faces[i]);
            _approveSpenderForAllUsers(address(router), faces[i]);
        }
        WeightedPoolFactory factory = deployWeightedPoolFactory(IVault(address(vault)), 365 days, "LiquidationDecimals", "LD");
        PoolRoleAccounts memory roles;
        address decimalPool = factory.create("Liquidation decimals", "LQD", configs, weights, roles,
            1e16, address(0), false, false, keccak256("liquidation-decimals-pool"));
        vm.startPrank(lp);
        _initPool(decimalPool, amounts, 0);
        vm.stopPrank();
        bpt = IERC20(decimalPool);
        adapter = IStandardExchange(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory,
                "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"),
            abi.encode(IRouter(address(router)), decimalPool, bpt, faces), keccak256("liquidation-decimals-adapter")
        ));
    }

    function _assertLargeLiquidation(IERC20 output) internal {
        uint256 amount = bpt.totalSupply() * 45 / 100;
        vm.prank(lp);
        bpt.transfer(alice, amount + 1e18);
        uint256 quote = adapter.previewExchangeIn(bpt, amount, output);
        uint256 snap = vm.snapshotState();
        uint256 before = output.balanceOf(alice);
        vm.startPrank(alice);
        bpt.approve(address(adapter), type(uint256).max);
        uint256 received = adapter.exchangeIn(bpt, amount, output, quote, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(received, quote);
        assertEq(output.balanceOf(alice) - before, quote);
        _assertNoMaxAllowances(adapter, bpt);
        vm.revertToState(snap);
        uint256 usedQuote = adapter.previewExchangeOut(bpt, output, quote);
        uint256 bptBefore = bpt.balanceOf(alice);
        vm.startPrank(alice);
        bpt.approve(address(adapter), bptBefore);
        uint256 used = adapter.exchangeOut(bpt, bptBefore, output, quote, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(used, usedQuote);
        assertEq(bptBefore - bpt.balanceOf(alice), usedQuote);
        assertEq(output.balanceOf(alice) - before, quote);
        _assertNoMaxAllowances(adapter, bpt);
    }

    /// @notice A quote beyond the bounded execution route does not authorize partial payout.
    function test_liquidation_overCapacity_revertsAtomically() public {
        uint256 supply = bpt.totalSupply();
        uint256 amount = supply * 99 / 100;
        vm.prank(lp);
        bpt.transfer(alice, amount);
        uint256 quote = adapter.previewExchangeIn(bpt, amount, dai);
        assertGt(quote, 0);
        uint256 ratio = ((supply - amount) * 1e18 + supply - 1) / supply;
        uint256 bptBefore = bpt.balanceOf(alice);
        uint256 assetsBefore = dai.balanceOf(alice);
        vm.startPrank(alice);
        bpt.approve(address(adapter), amount);
        vm.expectRevert(abi.encodeWithSelector(BasePoolMath.InvariantRatioBelowMin.selector, ratio, 7e17));
        adapter.exchangeIn(bpt, amount, dai, quote, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(bpt.balanceOf(alice), bptBefore);
        assertEq(dai.balanceOf(alice), assetsBefore);
        assertEq(bpt.totalSupply(), supply);
    }

    /// @notice M3: successful join must not leave max router/Permit2 allowance on adapter inventory.
    function test_M_allowance_not_max_after_exchangeIn() public {
        uint256 amountIn_ = 20e18;
        vm.startPrank(alice);
        dai.approve(address(adapter), amountIn_);
        uint256 out_ = adapter.exchangeIn(dai, amountIn_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out_, 0, "honest join");

        _assertNoMaxAllowances(adapter, dai);
    }

    /// @notice M3: successful exact-out join must not leave max allowance.
    function test_M_allowance_not_max_after_exchangeOut() public {
        uint256 amountOut_ = 1e18;
        uint256 maxIn_ = 20e18;
        vm.startPrank(alice);
        dai.approve(address(adapter), maxIn_);
        uint256 in_ = adapter.exchangeOut(dai, maxIn_, bpt, amountOut_, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(in_, 0, "honest exact-out");
        assertLe(in_, maxIn_, "used <= max");

        _assertNoMaxAllowances(adapter, dai);
    }

    /* ---------------------------------------------------------------------- */
    /*  R14.8 — paused exact-out twin, real invariant-ratio and no-unbalanced */
    /* ---------------------------------------------------------------------- */

    /// @dev R14.8: the exact-out join twin of the paused-then-succeeds check.
    function test_APEX_D38_exactOutPausedJoinRevertsPoolPausedThenSucceeds() public {
        uint256 amountOut_ = 1e18;
        uint256 maxIn_ = 50e18;
        authorizer.grantRole(vault.getActionId(IVaultAdmin.pausePool.selector), address(this));
        authorizer.grantRole(vault.getActionId(IVaultAdmin.unpausePool.selector), address(this));
        vault.pausePool(address(daiUsdc8020WeightedPool));
        vm.startPrank(alice);
        dai.approve(address(adapter), maxIn_);
        vm.expectRevert(abi.encodeWithSelector(IVaultErrors.PoolPaused.selector, address(daiUsdc8020WeightedPool)));
        adapter.exchangeOut(dai, maxIn_, bpt, amountOut_, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();

        vault.unpausePool(address(daiUsdc8020WeightedPool));
        vm.startPrank(alice);
        uint256 in_ = adapter.exchangeOut(dai, maxIn_, bpt, amountOut_, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(in_, 0, "unpaused exact-out issues BPT");
        assertLe(in_, maxIn_, "used <= max");
    }

    /// @dev R14.8: a real above-max-invariant-ratio exact-in join on the 80/20 pool reverts
    ///      `InvariantRatioAboveMax` (0x3e8960dc, BasePoolMath.sol). No `vm.mockCallRevert`.
    ///      dai is the 80% token; a single-sided add of ~7.5x the dai balance lifts the ratio past 300%.
    function test_APEX_aboveMaxInvariantRatio_exactInReverts() public {
        uint256 maxRatio_ =
            IUnbalancedLiquidityInvariantRatioBounds(address(daiUsdc8020WeightedPool)).getMaximumInvariantRatio();
        assertEq(maxRatio_, 3e18, "weighted 300% maximum invariant ratio");
        uint256 amountIn_ = 6_000e18; // (6800/800)^0.8 ~ 5.5x > 3x
        dai.mint(alice, amountIn_);
        vm.startPrank(alice);
        dai.approve(address(adapter), amountIn_);
        vm.expectPartialRevert(bytes4(0x3e8960dc));
        adapter.exchangeIn(dai, amountIn_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @dev R14.8: a standalone pool registered with `disableUnbalancedLiquidity=true` rejects a
    ///      single-token (unbalanced) join with `DoesNotSupportUnbalancedLiquidity()` (0xd4f5779c).
    ///      This is the contrast case to the packaged path, which the hooks force to enable it.
    function test_APEX_disableUnbalancedLiquidity_singleTokenJoinReverts() public {
        (IStandardExchange adapter2_, address pool2_) = _deployNoUnbalancedPoolAndAdapter();
        PoolConfig memory cfg_ = IVaultExtension(address(vault)).getPoolConfig(pool2_);
        assertTrue(cfg_.liquidityManagement.disableUnbalancedLiquidity, "standalone pool disables unbalanced liquidity");

        uint256 amountIn_ = 20e18;
        vm.startPrank(alice);
        dai.approve(address(adapter2_), amountIn_);
        vm.expectRevert(IVaultErrors.DoesNotSupportUnbalancedLiquidity.selector);
        adapter2_.exchangeIn(dai, amountIn_, IERC20(pool2_), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _deployNoUnbalancedPoolAndAdapter() internal returns (IStandardExchange adapter2_, address pool2_) {
        WeightedPoolFactory f_ =
            deployWeightedPoolFactory(IVault(address(vault)), 365 days, "NoUnbalFactory v1", "NoUnbalPool v1");
        address[] memory toks_ = new address[](2);
        toks_[0] = address(dai);
        toks_[1] = address(usdc);
        toks_ = BetterAddress._sort(toks_);
        TokenConfig[] memory tcs_ = new TokenConfig[](2);
        uint256[] memory weights_ = new uint256[](2);
        uint256[] memory amts_ = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            tcs_[i] = standardTokenConfig(IERC20(toks_[i]));
            if (toks_[i] == address(dai)) {
                weights_[i] = 0.8e18;
                amts_[i] = 800e18;
            } else {
                weights_[i] = 0.2e18;
                amts_[i] = 200e18;
            }
        }
        PoolRoleAccounts memory roles_;
        pool2_ = f_.create(
            "NoUnbal 80/20", "NUB", tcs_, weights_, roles_, 1e16, address(0), false, true, keccak256("noUnbal-pool")
        );
        vm.startPrank(lp);
        mintPoolTokens(toks_, amts_);
        _initPool(pool2_, amts_, 0);
        vm.stopPrank();

        IERC20[] memory poolTokens_ = new IERC20[](2);
        poolTokens_[0] = IERC20(toks_[0]);
        poolTokens_[1] = IERC20(toks_[1]);
        adapter2_ = IStandardExchange(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(
                    create3Factory,
                    "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"
                ),
                abi.encode(IRouter(address(router)), pool2_, IERC20(pool2_), poolTokens_),
                keccak256("BalancerV3SinglePoolStandardExchange-noUnbalanced")
            )
        );
    }

    /// @notice RC-01: a callback pool token cannot complete a nested money entry, and approvals stay finite.
    function test_RC01_callback_nestedMoneyEntry_hitsAdapterLock_outerSucceeds() public {
        AdapterLockProbeToken probe = new AdapterLockProbeToken(address(router), address(permit2));
        (IStandardExchange locked_, address pool_) = _deployProbePool(probe);
        uint256 amountIn_ = 20e18;
        probe.mint(alice, amountIn_);
        bytes memory payload_ = abi.encodeWithSelector(
            BalancerV3SinglePoolStandardExchange.exchangeIn.selector,
            IERC20(address(probe)),
            1 ether,
            IERC20(pool_),
            0,
            alice,
            false,
            block.timestamp + 1 hours
        );
        probe.arm(address(locked_), payload_, false);
        vm.startPrank(alice);
        probe.approve(address(locked_), amountIn_);
        uint256 out_ = locked_.exchangeIn(IERC20(address(probe)), amountIn_, IERC20(pool_), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out_, 0, "outer join completes");
        assertGt(probe.attempts(), 0, "callback stages ran");
        assertEq(probe.lockedHits(), probe.attempts(), "every nested money entry hit IsLocked");
        assertFalse(probe.succeeded(), "nested entry did not succeed");
        assertEq(probe.inFlightRouter(), amountIn_, "in-flight router allowance is the route budget");
        assertEq(probe.inFlightPermit2(), amountIn_, "in-flight Permit2 allowance is the route budget");
        assertTrue(probe.inFlightRouter() != type(uint256).max, "approval is not unlimited");
        _assertNoMaxAllowances(locked_, IERC20(address(probe)));
        assertEq(probe.balanceOf(address(locked_)), 0, "join input was consumed");
    }

    /// @notice RC-01: propagating the adapter lock rolls the outer operation back.
    function test_RC01_callback_propagatedLock_rollsBack() public {
        AdapterLockProbeToken probe = new AdapterLockProbeToken(address(router), address(permit2));
        (IStandardExchange locked_, address pool_) = _deployProbePool(probe);
        uint256 amountIn_ = 20e18;
        probe.mint(alice, amountIn_);
        probe.arm(
            address(locked_),
            abi.encodeWithSelector(
                BalancerV3SinglePoolStandardExchange.exchangeOut.selector,
                IERC20(address(probe)),
                1 ether,
                IERC20(pool_),
                1,
                alice,
                false,
                block.timestamp + 1 hours
            ),
            true
        );
        vm.startPrank(alice);
        probe.approve(address(locked_), amountIn_);
        uint256 before_ = probe.balanceOf(alice);
        // SafeERC20 wraps the token revert. The swallowed test records the nested IsLocked payload.
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        locked_.exchangeIn(IERC20(address(probe)), amountIn_, IERC20(pool_), 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(probe.balanceOf(alice), before_, "propagated lock restores the caller");
        assertEq(probe.allowance(address(locked_), address(router)), 0, "approvals roll back");
    }

    /// @notice RC-01: an amount above uint160 cannot truncate into an unlimited Permit2 approval.
    function test_RC01_permit2AmountOverflow_revertsBeforeApproval() public {
        uint256 huge_ = uint256(type(uint160).max) + 1;
        dai.mint(alice, huge_);
        vm.startPrank(alice);
        dai.approve(address(adapter), huge_);
        uint256 before_ = dai.balanceOf(alice);
        vm.expectRevert(abi.encodeWithSelector(BalancerV3SinglePoolStandardExchange.Permit2AmountOverflow.selector, huge_));
        adapter.exchangeIn(dai, huge_, bpt, 0, alice, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(dai.balanceOf(alice), before_, "overflow leaves balances unchanged");
        assertEq(dai.allowance(address(adapter), address(router)), 0, "overflow leaves no router allowance");
    }

    function _deployProbePool(AdapterLockProbeToken probe_)
        internal
        returns (IStandardExchange locked_, address pool_)
    {
        WeightedPoolFactory factory_ =
            deployWeightedPoolFactory(IVault(address(vault)), 365 days, "ProbeFactory", "ProbePool");
        address[] memory toks_ = new address[](2);
        toks_[0] = address(probe_);
        toks_[1] = address(usdc);
        toks_ = BetterAddress._sort(toks_);
        TokenConfig[] memory configs_ = new TokenConfig[](2);
        uint256[] memory weights_ = new uint256[](2);
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i; i < 2; ++i) {
            configs_[i] = standardTokenConfig(IERC20(toks_[i]));
            if (toks_[i] == address(probe_)) {
                weights_[i] = 0.8e18;
                amounts_[i] = 800e18;
                probe_.mint(lp, amounts_[i]);
            } else {
                weights_[i] = 0.2e18;
                amounts_[i] = 200e18;
                usdc.mint(lp, amounts_[i]);
            }
        }
        PoolRoleAccounts memory roles_;
        pool_ = factory_.create(
            "Probe 80/20", "PRB", configs_, weights_, roles_, 1e16, address(0), false, false, keccak256("rc01-probe-pool")
        );
        _approveForAllUsers(IERC20(address(probe_)));
        _approveSpenderForAllUsers(address(vault), IERC20(address(probe_)));
        _approveSpenderForAllUsers(address(router), IERC20(address(probe_)));
        vm.startPrank(lp);
        _initPool(pool_, amounts_, 0);
        vm.stopPrank();
        IERC20[] memory poolTokens_ = new IERC20[](2);
        poolTokens_[0] = IERC20(toks_[0]);
        poolTokens_[1] = IERC20(toks_[1]);
        locked_ = IStandardExchange(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(
                    create3Factory,
                    "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"
                ),
                abi.encode(IRouter(address(router)), pool_, IERC20(pool_), poolTokens_),
                keccak256("BalancerV3SinglePoolStandardExchange-rc01-probe")
            )
        );
    }
}

contract AdapterLockProbeToken is MintableERC20Decimals {
    address public immutable router;
    address public immutable permit2;
    address public adapter;
    bytes public payload;
    bool public armed;
    bool public propagate;
    bool public succeeded;
    uint256 public attempts;
    uint256 public lockedHits;
    uint256 public inFlightRouter;
    uint256 public inFlightPermit2;
    bool private probing;

    constructor(address router_, address permit2_) MintableERC20Decimals("Probe", "PRB", 18) {
        router = router_;
        permit2 = permit2_;
    }

    function arm(address adapter_, bytes memory payload_, bool propagate_) external {
        adapter = adapter_;
        payload = payload_;
        propagate = propagate_;
        armed = true;
        attempts = 0;
        lockedHits = 0;
        succeeded = false;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        if (armed && amount != 0 && msg.sender == adapter) {
            if (spender == router) inFlightRouter = amount;
            if (spender == permit2) inFlightPermit2 = amount;
        }
        if (msg.sender == adapter) _probe();
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        if (msg.sender == adapter) _probe();
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (msg.sender == adapter || from == adapter) _probe();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _probe() internal {
        if (!armed || probing || adapter == address(0)) return;
        probing = true;
        ++attempts;
        (bool ok, bytes memory ret) = adapter.call(payload);
        succeeded = succeeded || ok;
        if (!ok && ret.length >= 4 && bytes4(ret) == IReentrancyLock.IsLocked.selector) ++lockedHits;
        probing = false;
        if (propagate && !ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IVaultAdmin} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVaultAdmin.sol";
import {IProtocolFeeController} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IProtocolFeeController.sol";
import {IStandardExchangeTransitionQuote as Quote, IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IBalancerV3PoolLiquidityQuote} from "contracts/protocols/dexes/balancer/v3/pools/IBalancerV3PoolLiquidityQuote.sol";
import {BalancerV3PoolStandardExchangeTransitionQuoteTarget as Adapter} from "contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTransitionQuoteTarget.sol";
import {BalancerV3StableBufferPoolQuoteTarget as Subject} from "contracts/protocols/dexes/balancer/v3/pools/stable/BalancerV3StableBufferPoolQuoteTarget.sol";
import {ICommonBufferMultiVaultStablePool} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {IMixedBufferMultiVaultStablePool} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";

interface ITransitionQuoteAuthorizer {
    function grantRole(bytes32 action, address account) external;
}

interface ITransitionQuoteAuthentication {
    function getActionId(bytes4 selector) external view returns (bytes32);
}

/// @notice Exact sequential quote/execution checks shared by the real stable buffer pool fixtures.
/// @dev Every transition is quoted before either operation executes. Snapshot equality covers
/// all adapter and protocol-owned fields, including signed deltas, rates, scaling and fees.
abstract contract TestBase_BalancerV3StableBufferTransitionQuote is Test {
    struct TransitionFixture {
        address pool;
        IERC20 asset;
        address holder;
        address seedOwner;
        IRateProvider rate;
        IVault vault;
        address authorizer;
        IFacet poolFacet;
        IDiamondFactoryPackage pkg;
        bool mixed;
    }

    struct TransitionStep {
        bytes state;
        uint256 amountIn;
        uint256 amountOut;
        uint256 assetsAfter;
        uint256 rateAfter;
    }

    function _transitionFixture() internal virtual returns (TransitionFixture memory);
    function _primeTransitionBook(bool bufferIn) internal virtual;

    function _fundTransitionHolder(TransitionFixture memory f) private {
        vm.startPrank(f.seedOwner);
        IERC20(f.pool).transfer(f.holder, 40e18);
        f.asset.transfer(f.holder, 20e18);
        vm.stopPrank();
        vm.startPrank(f.holder);
        IERC20(f.pool).approve(f.pool, type(uint256).max);
        f.asset.approve(f.pool, type(uint256).max);
        vm.stopPrank();
    }

    function _transitionFees(TransitionFixture memory f, uint256 aggregate) private {
        ITransitionQuoteAuthorizer auth = ITransitionQuoteAuthorizer(f.authorizer);
        address swapFeeManager = f.vault.getPoolRoleAccounts(f.pool).swapFeeManager;
        if (swapFeeManager == address(0)) {
            auth.grantRole(
                ITransitionQuoteAuthentication(address(f.vault)).getActionId(IVaultAdmin.setStaticSwapFeePercentage.selector),
                address(this)
            );
        } else {
            vm.prank(swapFeeManager);
        }
        IVaultAdmin(address(f.vault)).setStaticSwapFeePercentage(f.pool, 1e16);
        IProtocolFeeController controller = f.vault.getProtocolFeeController();
        auth.grantRole(
            ITransitionQuoteAuthentication(address(controller)).getActionId(IProtocolFeeController.setProtocolSwapFeePercentage.selector),
            address(this)
        );
        controller.setProtocolSwapFeePercentage(f.pool, aggregate);
    }

    function _quoteStep(TransitionFixture memory f, bytes memory state, Quote.Operation op, uint256 amount)
        private view returns (TransitionStep memory step)
    {
        (step.state, step.amountIn, step.amountOut, step.assetsAfter) = Quote(f.pool).quoteTransition(state, op, amount);
        step.rateAfter = IStandardExchangeRateQuote(address(f.rate)).quoteRate(f.pool, address(f.asset), step.state);
    }

    function _executeStep(TransitionFixture memory f, Quote.Operation op, TransitionStep memory step) private {
        uint256 assetsBefore = f.asset.balanceOf(f.holder);
        uint256 sharesBefore = IERC20(f.pool).balanceOf(f.holder);
        vm.startPrank(f.holder);
        if (op == Quote.Operation.WithdrawExactOut) {
            uint256 used = IStandardExchangeOut(f.pool).exchangeOut(
                IERC20(f.pool), step.amountIn, f.asset, step.amountOut, f.holder, false, block.timestamp
            );
            assertEq(used, step.amountIn, "exact-out BPT input");
        } else {
            bool joining = op == Quote.Operation.DepositExactIn;
            uint256 paid = IStandardExchangeIn(f.pool).exchangeIn(
                joining ? f.asset : IERC20(f.pool), step.amountIn,
                joining ? IERC20(f.pool) : f.asset, step.amountOut, f.holder, false, block.timestamp
            );
            assertEq(paid, step.amountOut, "exact-in output, strict quoted min");
        }
        vm.stopPrank();
        if (op == Quote.Operation.DepositExactIn) {
            assertEq(assetsBefore - f.asset.balanceOf(f.holder), step.amountIn, "deposit debit");
            assertEq(IERC20(f.pool).balanceOf(f.holder) - sharesBefore, step.amountOut, "mint credit");
        } else {
            assertEq(f.asset.balanceOf(f.holder) - assetsBefore, step.amountOut, "withdrawal credit");
            assertEq(sharesBefore - IERC20(f.pool).balanceOf(f.holder), step.amountIn, "burn debit");
        }
        _assertTransitionState(f, step);
    }

    function _assertTransitionState(TransitionFixture memory f, TransitionStep memory step) private view {
        (bytes memory actual, uint256 assets) = Quote(f.pool).quoteState(address(f.asset), f.holder);
        assertEq(step.state, actual, "ALL adapter and virtual-book fields equal fresh execution snapshot");
        assertEq(step.assetsAfter, assets, "holder assets after");
        assertEq(Quote(f.pool).quoteShareBalance(step.state), IERC20(f.pool).balanceOf(f.holder), "holder shares");
        assertEq(Quote(f.pool).quoteTotalSupply(step.state), IERC20(f.pool).totalSupply(), "issued supply");
        assertEq(step.rateAfter, f.rate.getRate(), "projected rate equals live production rate provider");
        assertGt(step.rateAfter, 0, "rate comparison must not be zero/zero");
        assertEq(Quote(f.pool).quoteAssets(step.state, 1e18),
            IStandardExchangeIn(f.pool).previewExchangeIn(IERC20(f.pool), 1e18, f.asset), "unit share value");
    }

    function _twoTransitionSteps(Quote.Operation firstOp, uint256 aggregate, uint256 firstAmount, uint256 secondAmount)
        internal
    {
        TransitionFixture memory f = _transitionFixture();
        _fundTransitionHolder(f);
        _transitionFees(f, aggregate);
        (bytes memory state,) = Quote(f.pool).quoteState(address(f.asset), f.holder);
        TransitionStep memory first = _quoteStep(f, state, firstOp, firstAmount);
        TransitionStep memory second = _quoteStep(f, first.state, Quote.Operation.RedeemExactIn, secondAmount);
        // Capture both rates before execution, as the generic consumer does.
        assertEq(abi.decode(state, (Adapter.PoolQuoteState)).aggregateSwapFee, aggregate, "configured aggregate fee snapshot");
        uint256 feesBefore = f.vault.getAggregateSwapFeeAmount(f.pool, f.asset);
        _executeStep(f, firstOp, first);
        _executeStep(f, Quote.Operation.RedeemExactIn, second);
        _assertVirtualChange(state, second.state);
        if (aggregate != 0) {
            assertGt(f.vault.getAggregateSwapFeeAmount(f.pool, f.asset), feesBefore, "control charged nonzero aggregate fee");
        } else {
            assertEq(f.vault.getAggregateSwapFeeAmount(f.pool, f.asset), feesBefore, "zero aggregate control");
        }
    }

    function _assertVirtualChange(bytes memory beforeState, bytes memory afterState) private pure {
        Adapter.PoolQuoteState memory initial = abi.decode(beforeState, (Adapter.PoolQuoteState));
        Adapter.PoolQuoteState memory finalState = abi.decode(afterState, (Adapter.PoolQuoteState));
        Subject.StableBufferQuoteState memory virtualBefore = abi.decode(initial.poolState, (Subject.StableBufferQuoteState));
        Subject.StableBufferQuoteState memory virtualAfter = abi.decode(finalState.poolState, (Subject.StableBufferQuoteState));
        assertLt(virtualAfter.virtualBuffer, virtualBefore.virtualBuffer, "removal scaled virtual buffer");
        for (uint256 i; i < virtualBefore.hookShareDeltas.length; ++i) {
            int256 h = virtualBefore.hookShareDeltas[i];
            if (h > 0) assertLt(virtualAfter.hookShareDeltas[i], h, "positive delta scaled");
            if (h < 0) assertGt(virtualAfter.hookShareDeltas[i], h, "negative delta scaled toward zero");
        }
    }

    function test_transition_twoRedeems_allFields() public {
        _twoTransitionSteps(Quote.Operation.RedeemExactIn, 0, 10e18, 7e18);
    }

    function test_transition_twoRedeems_nonzeroAggregateFees() public {
        _twoTransitionSteps(Quote.Operation.RedeemExactIn, 5e17, 10e18, 7e18);
    }

    function test_transition_depositThenRedeem_nonzeroAggregateFees() public {
        _twoTransitionSteps(Quote.Operation.DepositExactIn, 5e17, 5e18, 7e18);
    }

    function test_transition_exactOutThenRedeem_nonzeroAggregateFees() public {
        _twoTransitionSteps(Quote.Operation.WithdrawExactOut, 5e17, 5e18, 7e18);
    }

    function test_transition_positiveHookDeltas() public {
        _primeTransitionBook(true);
        _assertDeltaSign(true);
        _twoTransitionSteps(Quote.Operation.RedeemExactIn, 5e17, 10e18, 7e18);
    }

    function test_transition_negativeHookDeltas() public {
        _primeTransitionBook(false);
        _assertDeltaSign(false);
        _twoTransitionSteps(Quote.Operation.RedeemExactIn, 5e17, 10e18, 7e18);
    }

    function _assertDeltaSign(bool positive) private {
        TransitionFixture memory f = _transitionFixture();
        (bytes memory state,) = Quote(f.pool).quoteState(address(f.asset), f.holder);
        Adapter.PoolQuoteState memory q = abi.decode(state, (Adapter.PoolQuoteState));
        Subject.StableBufferQuoteState memory subject = abi.decode(q.poolState, (Subject.StableBufferQuoteState));
        if (positive) assertGt(subject.hookShareDeltas[0], 0, "real reconcile created positive delta");
        else assertLt(subject.hookShareDeltas[0], 0, "real pre-seat created negative delta");
    }

    function testFuzz_transition_twoRedeems(uint96 first, uint96 second) public {
        _twoTransitionSteps(Quote.Operation.RedeemExactIn, 5e17, bound(first, 5e18, 15e18), bound(second, 5e18, 15e18));
    }

    function test_transition_rejectsMissingVirtualBook() public {
        TransitionFixture memory f = _transitionFixture();
        (bytes memory state,) = Quote(f.pool).quoteState(address(f.asset), f.holder);
        Adapter.PoolQuoteState memory q = abi.decode(state, (Adapter.PoolQuoteState));
        q.poolState = "";
        vm.expectRevert(Quote.InvalidQuoteState.selector);
        Quote(f.pool).quoteAssets(abi.encode(q), 1e18);
    }

    function test_transition_subjectSurface() public {
        TransitionFixture memory f = _transitionFixture();
        assertTrue(IERC165(f.pool).supportsInterface(type(IBalancerV3PoolLiquidityQuote).interfaceId));
        bytes4[] memory interfaces = new bytes4[](3);
        interfaces[0] = type(IBalancerV3Pool).interfaceId;
        interfaces[1] = f.mixed ? type(IMixedBufferMultiVaultStablePool).interfaceId : type(ICommonBufferMultiVaultStablePool).interfaceId;
        interfaces[2] = type(IBalancerV3PoolLiquidityQuote).interfaceId;
        assertEq(f.poolFacet.facetInterfaces().length, interfaces.length, "facet interface count");
        assertTrue(Behavior_IFacet.areValid_IFacet_facetInterfaces(f.poolFacet, interfaces, f.poolFacet.facetInterfaces()));
        bytes4[] memory expected = _poolSelectors(f.mixed);
        assertEq(f.poolFacet.facetFuncs().length, expected.length, "facet selector count");
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(f.poolFacet, expected, f.poolFacet.facetFuncs()));
        assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(f.poolFacet));
        IDiamond.FacetCut[] memory cuts = f.pkg.facetCuts();
        for (uint256 i; i < expected.length; ++i) {
            assertEq(IDiamondLoupe(f.pool).facetAddress(expected[i]), address(f.poolFacet), "proxy selector");
            bool found;
            for (uint256 j; j < cuts.length; ++j) {
                if (cuts[j].facetAddress != address(f.poolFacet)) continue;
                for (uint256 k; k < cuts[j].functionSelectors.length; ++k) {
                    if (cuts[j].functionSelectors[k] == expected[i]) found = true;
                }
            }
            assertTrue(found, "package cut includes selector");
        }
        (bytes memory state,) = Quote(f.pool).quoteState(address(f.asset), f.holder);
        TransitionStep memory step = _quoteStep(f, state, Quote.Operation.ReceiveShares, 20e18);
        // Exercise all three quote selectors through the diamond without an execution.
        _quoteStep(f, step.state, Quote.Operation.RedeemExactIn, 1e18);
    }

    function _poolSelectors(bool mixed) private pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](mixed ? 25 : 21);
        uint256 i;
        funcs[i++] = IBalancerV3Pool.computeInvariant.selector;
        funcs[i++] = IBalancerV3Pool.computeBalance.selector;
        funcs[i++] = IBalancerV3Pool.onSwap.selector;
        if (mixed) funcs[i++] = bytes4(keccak256("unpairedCount()"));
        funcs[i++] = bytes4(keccak256("vaultCount()"));
        funcs[i++] = bytes4(keccak256("tokenCount()"));
        if (mixed) {
            funcs[i++] = bytes4(keccak256("unpairedToken(uint256)"));
            funcs[i++] = bytes4(keccak256("unpairedRateProvider(uint256)"));
            funcs[i++] = bytes4(keccak256("unpairedIndex(uint256)"));
        }
        funcs[i++] = bytes4(keccak256("bufferToken()"));
        funcs[i++] = bytes4(keccak256("bufferIndex()"));
        funcs[i++] = bytes4(keccak256("virtualBuffer()"));
        funcs[i++] = bytes4(keccak256("shareToken(uint256)"));
        funcs[i++] = bytes4(keccak256("standardExchangeVault(uint256)"));
        funcs[i++] = bytes4(keccak256("vaultShareRateProvider(uint256)"));
        funcs[i++] = bytes4(keccak256("shareIndex(uint256)"));
        funcs[i++] = bytes4(keccak256("hookShareDelta(uint256)"));
        funcs[i++] = bytes4(keccak256("resolveTokenIndex(uint256)"));
        funcs[i++] = bytes4(keccak256("shallowestVault()"));
        funcs[i++] = bytes4(keccak256("deepestVault()"));
        funcs[i++] = bytes4(keccak256("derivedShareDepth(uint256)"));
        funcs[i++] = bytes4(keccak256("getAmplificationParameter()"));
        funcs[i++] = IBalancerV3PoolLiquidityQuote.quotePoolState.selector;
        funcs[i++] = IBalancerV3PoolLiquidityQuote.quotePoolLiquidity.selector;
        funcs[i] = IBalancerV3PoolLiquidityQuote.quotePoolStateAfterLiquidity.selector;
    }
}

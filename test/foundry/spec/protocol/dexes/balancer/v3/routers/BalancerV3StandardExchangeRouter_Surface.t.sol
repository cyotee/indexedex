// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";

import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
import {
    IBalancerV3StandardExchangeRouterPermit2Witness
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPermit2Witness.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/**
 * @title BalancerV3StandardExchangeRouter_Surface_Test
 * @notice WP-J-ROUTER-UAB-001 / TCA-SE-UAB-010: formal Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** matrix.
 * @dev Closes PAT-J-CTRL for Balancer SE Router money/query/prepay/witness facets.
 *      Coordinator router is out of scope (WP-J-RTR-001). J3 calls production proxy, not facet impl.
 */
contract BalancerV3StandardExchangeRouter_Surface_Test is TestBase_BalancerV3StandardExchangeRouter {
    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _assertFacetFuncsOnLoupe(IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(address(seRouter));
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "J2 loupe maps selector to CREATE3/facet cut");
            assertTrue(loupeFacet_ != address(0), "J2 not zero");
            assertTrue(loupeFacet_ != address(seRouter), "J2 not self-facet");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: interface / Target money+admin selectors ⊆ facetFuncs             */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: ExactIn money selectors are cut into facetFuncs.
    function test_J1_exactInSwap_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exactInSwapFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactInSwap.swapSingleTokenExactIn.selector),
            "J1 swapSingleTokenExactIn"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactInSwap.swapSingleTokenExactInWithPermit.selector),
            "J1 swapSingleTokenExactInWithPermit"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactInSwap.swapSingleTokenExactInHook.selector),
            "J1 swapSingleTokenExactInHook"
        );
        assertEq(funcs_.length, 3, "J1 ExactInSwap facetFuncs length");
    }

    /// @notice J1: ExactOut money selectors are cut.
    function test_J1_exactOutSwap_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exactOutSwapFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOut.selector),
            "J1 swapSingleTokenExactOut"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOutWithPermit.selector),
            "J1 swapSingleTokenExactOutWithPermit"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOutHook.selector),
            "J1 swapSingleTokenExactOutHook"
        );
        assertEq(funcs_.length, 3, "J1 ExactOutSwap facetFuncs length");
    }

    /// @notice J1: ExactIn query surface is cut.
    function test_J1_exactInQuery_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exactInQueryFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactInSwapQuery.querySwapSingleTokenExactIn.selector),
            "J1 querySwapSingleTokenExactIn"
        );
        assertTrue(
            _contains(
                funcs_, IBalancerV3StandardExchangeRouterExactInSwapQuery.querySwapSingleTokenExactInHook.selector
            ),
            "J1 querySwapSingleTokenExactInHook"
        );
        assertEq(funcs_.length, 2, "J1 ExactInQuery facetFuncs length");
    }

    /// @notice J1: ExactOut query surface is cut.
    function test_J1_exactOutQuery_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = exactOutQueryFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterExactOutSwapQuery.querySwapSingleTokenExactOut.selector),
            "J1 querySwapSingleTokenExactOut"
        );
        assertTrue(
            _contains(
                funcs_, IBalancerV3StandardExchangeRouterExactOutSwapQuery.querySwapSingleTokenExactOutHook.selector
            ),
            "J1 querySwapSingleTokenExactOutHook"
        );
        assertEq(funcs_.length, 2, "J1 ExactOutQuery facetFuncs length");
    }

    /// @notice J1: Batch ExactIn money+query selectors are cut.
    function test_J1_batchExactIn_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = batchExactInFacet.facetFuncs();
        assertTrue(_contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactIn.swapExactIn.selector), "J1 swapExactIn");
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactIn.swapExactInWithPermit.selector),
            "J1 swapExactInWithPermit"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactIn.swapExactInHook.selector),
            "J1 swapExactInHook"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactIn.querySwapExactIn.selector),
            "J1 querySwapExactIn"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactIn.querySwapExactInHook.selector),
            "J1 querySwapExactInHook"
        );
        assertEq(funcs_.length, 5, "J1 BatchExactIn facetFuncs length");
    }

    /// @notice J1: Batch ExactOut money+query selectors are cut.
    function test_J1_batchExactOut_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = batchExactOutFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOut.selector), "J1 swapExactOut"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOutWithPermit.selector),
            "J1 swapExactOutWithPermit"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOutHook.selector),
            "J1 swapExactOutHook"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactOut.querySwapExactOut.selector),
            "J1 querySwapExactOut"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeBatchRouterExactOut.querySwapExactOutHook.selector),
            "J1 querySwapExactOutHook"
        );
        assertEq(funcs_.length, 5, "J1 BatchExactOut facetFuncs length");
    }

    /// @notice J1: Prepay session + liquidity controls are cut.
    function test_J1_prepay_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = prepayFacet.facetFuncs();
        assertTrue(_contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.isPrepaid.selector), "J1 isPrepaid");
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.currentStandardExchange.selector),
            "J1 currentStandardExchange"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.passPrepayAuth.selector), "J1 passPrepayAuth"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.restorePrepayAuth.selector),
            "J1 restorePrepayAuth"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepaySessionActive.selector),
            "J1 prepaySessionActive"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayAuthTop.selector), "J1 prepayAuthTop"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayAuthDepth.selector), "J1 prepayAuthDepth"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayInitialize.selector), "J1 prepayInitialize"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayAddLiquidityUnbalanced.selector),
            "J1 prepayAddLiquidityUnbalanced"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayRemoveLiquidityProportional.selector),
            "J1 prepayRemoveLiquidityProportional"
        );
        assertTrue(
            _contains(
                funcs_, IBalancerV3StandardExchangeRouterPrepay.prepayRemoveLiquiditySingleTokenExactIn.selector
            ),
            "J1 prepayRemoveLiquiditySingleTokenExactIn"
        );
        assertEq(funcs_.length, 11, "J1 Prepay facetFuncs length");
    }

    /// @notice J1: Prepay vault-hook selectors are cut.
    function test_J1_prepayHooks_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = prepayHooksFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepayHooks.prepayInitializeHook.selector),
            "J1 prepayInitializeHook"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepayHooks.prepayAddLiquidityHook.selector),
            "J1 prepayAddLiquidityHook"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPrepayHooks.prepayRemoveLiquidityHook.selector),
            "J1 prepayRemoveLiquidityHook"
        );
        assertEq(funcs_.length, 3, "J1 PrepayHooks facetFuncs length");
    }

    /// @notice J1: Permit2 witness getters are cut.
    function test_J1_permit2Witness_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = permit2WitnessFacet.facetFuncs();
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPermit2Witness.WITNESS_TYPE_STRING.selector),
            "J1 WITNESS_TYPE_STRING"
        );
        assertTrue(
            _contains(funcs_, IBalancerV3StandardExchangeRouterPermit2Witness.WITNESS_TYPEHASH.selector),
            "J1 WITNESS_TYPEHASH"
        );
        assertEq(funcs_.length, 2, "J1 Permit2Witness facetFuncs length");
    }

    /// @notice J1: SenderGuard getSender is cut (router diamond dependency).
    function test_J1_senderGuard_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = senderGuardFacet.facetFuncs();
        assertTrue(_contains(funcs_, ISenderGuard.getSender.selector), "J1 getSender");
        assertEq(funcs_.length, 1, "J1 SenderGuard facetFuncs length");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production proxy                            */
    /* ---------------------------------------------------------------------- */

    function test_J2_exactInSwap_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(exactInSwapFacet, address(exactInSwapFacet));
    }

    function test_J2_exactOutSwap_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(exactOutSwapFacet, address(exactOutSwapFacet));
    }

    function test_J2_exactInQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(exactInQueryFacet, address(exactInQueryFacet));
    }

    function test_J2_exactOutQuery_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(exactOutQueryFacet, address(exactOutQueryFacet));
    }

    function test_J2_batchExactIn_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(batchExactInFacet, address(batchExactInFacet));
    }

    function test_J2_batchExactOut_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(batchExactOutFacet, address(batchExactOutFacet));
    }

    function test_J2_prepay_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(prepayFacet, address(prepayFacet));
    }

    function test_J2_prepayHooks_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(prepayHooksFacet, address(prepayHooksFacet));
    }

    function test_J2_permit2Witness_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(permit2WitnessFacet, address(permit2WitnessFacet));
    }

    function test_J2_senderGuard_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(senderGuardFacet, address(senderGuardFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed calls (not facet impl address)         */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: views + money product-fail on production diamond proxy.
    function test_J3_proxySmoke_viewsAndMoneySelectors() public {
        IDiamondLoupe loupe_ = IDiamondLoupe(address(seRouter));

        // View surface via proxy (not facet impl)
        // isPrepaid is a capability marker (always true), not session state.
        assertTrue(seRouter.isPrepaid(), "J3 isPrepaid capability on proxy");
        assertEq(address(seRouter.currentStandardExchange()), address(0), "J3 currentSE on proxy");
        assertFalse(seRouter.prepaySessionActive(), "J3 prepaySessionActive on proxy");
        assertEq(seRouter.prepayAuthDepth(), 0, "J3 prepayAuthDepth on proxy");
        assertEq(seRouter.prepayAuthTop(), address(0), "J3 prepayAuthTop on proxy");

        string memory witnessStr_ =
            IBalancerV3StandardExchangeRouterPermit2Witness(address(seRouter)).WITNESS_TYPE_STRING();
        assertTrue(bytes(witnessStr_).length > 0, "J3 WITNESS_TYPE_STRING on proxy");
        assertTrue(
            IBalancerV3StandardExchangeRouterPermit2Witness(address(seRouter)).WITNESS_TYPEHASH() != bytes32(0),
            "J3 WITNESS_TYPEHASH on proxy"
        );

        // Money selector product fail on proxy (SwapDeadline — not FunctionNotFound / missing cut)
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        uint256 amountIn_ = 1e18;
        _mintAndApprove(address(token0), alice, amountIn_);
        uint256 expired_ = block.timestamp - 1;

        vm.prank(alice);
        vm.expectRevert(ISenderGuard.SwapDeadline.selector);
        seRouter.swapSingleTokenExactIn(
            daiUsdcPool, token0, _noVault(), token1, _noVault(), amountIn_, 0, expired_, false, ""
        );

        // Loupe: money / query / prepay selectors route to cut facets, not proxy self
        address loupeExactIn_ =
            loupe_.facetAddress(IBalancerV3StandardExchangeRouterExactInSwap.swapSingleTokenExactIn.selector);
        assertEq(loupeExactIn_, address(exactInSwapFacet), "J3 exactIn loupe");
        assertTrue(loupeExactIn_ != address(seRouter), "J3 exactIn not self");

        address loupeExactOut_ =
            loupe_.facetAddress(IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOut.selector);
        assertEq(loupeExactOut_, address(exactOutSwapFacet), "J3 exactOut loupe");

        address loupeQueryIn_ =
            loupe_.facetAddress(IBalancerV3StandardExchangeRouterExactInSwapQuery.querySwapSingleTokenExactIn.selector);
        assertEq(loupeQueryIn_, address(exactInQueryFacet), "J3 queryIn loupe");

        address loupeBatchIn_ = loupe_.facetAddress(IBalancerV3StandardExchangeBatchRouterExactIn.swapExactIn.selector);
        assertEq(loupeBatchIn_, address(batchExactInFacet), "J3 batchExactIn loupe");

        address loupePrepay_ = loupe_.facetAddress(IBalancerV3StandardExchangeRouterPrepay.passPrepayAuth.selector);
        assertEq(loupePrepay_, address(prepayFacet), "J3 prepay loupe");

        address loupeWitness_ =
            loupe_.facetAddress(IBalancerV3StandardExchangeRouterPermit2Witness.WITNESS_TYPEHASH.selector);
        assertEq(loupeWitness_, address(permit2WitnessFacet), "J3 witness loupe");
    }

    /// @notice J facet metadata parity on CREATE3 ExactInSwap facet.
    function test_J_facetMetadata_exactInSwap_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = exactInSwapFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("BalancerV3StandardExchangeRouterExactInSwapFacet")),
            "J metadata name"
        );
        assertTrue(ifaces_.length >= 1, "J interfaces");
        assertEq(exactInSwapFacet.facetFuncs().length, funcs_.length, "J funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(exactInSwapFacet.facetFuncs())),
            "J metadata funcs == facetFuncs"
        );
    }

    /// @notice J facet metadata parity on CREATE3 Prepay facet (session-auth money surface).
    function test_J_facetMetadata_prepay_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = prepayFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("BalancerV3StandardExchangeRouterPrepayFacet")),
            "J prepay metadata name"
        );
        assertTrue(ifaces_.length >= 1, "J prepay interfaces");
        assertEq(prepayFacet.facetFuncs().length, funcs_.length, "J prepay funcs length");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(prepayFacet.facetFuncs())),
            "J prepay metadata funcs == facetFuncs"
        );
    }
}

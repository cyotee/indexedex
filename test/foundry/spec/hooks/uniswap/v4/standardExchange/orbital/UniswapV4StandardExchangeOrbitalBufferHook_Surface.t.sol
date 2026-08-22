// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_Surface_Test
 * @notice WP-J-HOOK-001: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke for SE orbital buffer (sebuf).
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_Surface_Test is TestBase {
    IFacet internal hooksFacet;
    IFacet internal depositFacet;
    IFacet internal withdrawFacet;
    IFacet internal seFacet;

    function setUp() public override {
        super.setUp();
        hooksFacet = PkgFactory.deployHooksFacet(create3Factory);
        depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
        seFacet = PkgFactory.deploySeFacet(create3Factory);
    }

    function _contains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _assertFacetFuncsOnLoupe(IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(hook);
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "J2 loupe maps selector to CREATE3 facet");
            assertTrue(loupeFacet_ != address(0), "J2 not zero");
            assertTrue(loupeFacet_ != hook, "J2 not self-facet");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*  J1: Target / interface money+view selectors ⊆ facetFuncs             */
    /* ---------------------------------------------------------------------- */

    function test_J1_hooks_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = hooksFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHooks.beforeSwap.selector), "J1 beforeSwap");
        assertTrue(_contains(funcs_, IHooks.beforeInitialize.selector), "J1 beforeInitialize");
        assertTrue(_contains(funcs_, IHooks.beforeAddLiquidity.selector), "J1 beforeAddLiquidity");
        assertTrue(_contains(funcs_, IHook.poolManager.selector), "J1 poolManager");
        assertTrue(_contains(funcs_, IHook.token0.selector), "J1 token0");
        assertTrue(_contains(funcs_, IHook.token1.selector), "J1 token1");
        assertTrue(_contains(funcs_, IHook.token2.selector), "J1 token2");
        assertTrue(_contains(funcs_, IHook.standardExchange.selector), "J1 standardExchange");
        assertTrue(_contains(funcs_, IHook.isBuffered.selector), "J1 isBuffered");
        assertTrue(_contains(funcs_, IHook.radius.selector), "J1 radius");
        assertTrue(_contains(funcs_, IHook.rawReserve.selector), "J1 rawReserve");
        assertTrue(_contains(funcs_, IHook.seClaim.selector), "J1 seClaim");
        assertTrue(_contains(funcs_, IHook.effectiveReserve.selector), "J1 effectiveReserve");
        assertTrue(_contains(funcs_, IHook.previewSwapExactIn.selector), "J1 previewSwapExactIn");
        assertTrue(_contains(funcs_, IHook.previewSwapExactOut.selector), "J1 previewSwapExactOut");
        assertEq(funcs_.length, 37, "J1 HooksFacet facetFuncs length");
    }

    function test_J1_deposit_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = depositFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHook.addLiquidity.selector), "J1 addLiquidity");
        assertTrue(_contains(funcs_, IHook.depositSingle.selector), "J1 depositSingle");
        assertTrue(_contains(funcs_, IHook.previewAddLiquidity.selector), "J1 previewAddLiquidity");
        assertTrue(_contains(funcs_, IHook.previewDepositSingle.selector), "J1 previewDepositSingle");
        assertTrue(_contains(funcs_, IHook.previewZapSplit.selector), "J1 previewZapSplit");
        assertTrue(_contains(funcs_, IHook.depositFlexible.selector), "J1 depositFlexible");
        assertTrue(_contains(funcs_, IHook.previewDepositFlexible.selector), "J1 previewDepositFlexible");
        assertEq(funcs_.length, 7, "J1 DepositFacet facetFuncs length");
    }

    function test_J1_withdraw_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = withdrawFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHook.removeLiquidity.selector), "J1 removeLiquidity");
        assertTrue(_contains(funcs_, IHook.previewRemoveLiquidity.selector), "J1 previewRemoveLiquidity");
        assertTrue(_contains(funcs_, IHook.withdrawFlexible.selector), "J1 withdrawFlexible");
        assertTrue(_contains(funcs_, IHook.previewWithdrawFlexible.selector), "J1 previewWithdrawFlexible");
        assertEq(funcs_.length, 4, "J1 WithdrawFacet facetFuncs length");
    }

    function test_J1_se_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = seFacet.facetFuncs();
        assertTrue(_contains(funcs_, IStandardExchangeIn.previewExchangeIn.selector), "J1 previewExchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeIn.exchangeIn.selector), "J1 exchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeOut.previewExchangeOut.selector), "J1 previewExchangeOut");
        assertTrue(_contains(funcs_, IStandardExchangeOut.exchangeOut.selector), "J1 exchangeOut");
        assertTrue(_contains(funcs_, IHook.ownerSwapExactIn.selector), "J1 ownerSwapExactIn");
        assertTrue(_contains(funcs_, IHook.ownerSwapExactOut.selector), "J1 ownerSwapExactOut");
        assertEq(funcs_.length, 6, "J1 SeFacet facetFuncs length");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production hook proxy                      */
    /* ---------------------------------------------------------------------- */

    function test_J2_hooks_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(hooksFacet, address(hooksFacet));
    }

    function test_J2_deposit_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(depositFacet, address(depositFacet));
    }

    function test_J2_withdraw_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(withdrawFacet, address(withdrawFacet));
    }

    function test_J2_se_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(seFacet, address(seFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed calls (not facet impl address)        */
    /* ---------------------------------------------------------------------- */

    function test_J3_proxySmoke_bindingAndReserveViews() public view {
        IHook proxy_ = orbital;
        IDiamondLoupe loupe_ = IDiamondLoupe(hook);

        assertEq(address(proxy_.poolManager()), address(pm), "J3 poolManager on proxy");
        assertEq(proxy_.token0(), address(token0), "J3 token0 on proxy");
        assertEq(proxy_.token1(), address(token1), "J3 token1 on proxy");
        assertEq(proxy_.token2(), address(token2), "J3 token2 on proxy");
        assertEq(proxy_.standardExchange(0), se0, "J3 se0 on proxy");
        assertTrue(proxy_.isBuffered(0), "J3 leg0 buffered");
        assertEq(proxy_.radius(), 0, "J3 inert radius");
        assertEq(proxy_.rawReserve(0), 0, "J3 inert rawReserve0");
        assertEq(proxy_.seClaim(0), 0, "J3 inert seClaim0");

        address loupeHooks_ = loupe_.facetAddress(IHook.radius.selector);
        assertEq(loupeHooks_, address(hooksFacet), "J3 radius loupe");
        assertTrue(loupeHooks_ != hook, "J3 not self-facet");

        address loupeDep_ = loupe_.facetAddress(IHook.addLiquidity.selector);
        assertEq(loupeDep_, address(depositFacet), "J3 addLiquidity loupe");

        address loupeWd_ = loupe_.facetAddress(IHook.removeLiquidity.selector);
        assertEq(loupeWd_, address(withdrawFacet), "J3 removeLiquidity loupe");

        address loupeSe_ = loupe_.facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(loupeSe_, address(seFacet), "J3 se exchangeIn loupe");
    }

    function test_J_facetMetadata_hooks_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = hooksFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4StandardExchangeOrbitalBufferHookHooksFacet"))
        );
        assertTrue(ifaces_.length >= 1, "J interfaces");
        assertEq(hooksFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(hooksFacet.facetFuncs())));
    }

    function test_J_facetMetadata_deposit_matches_CREATE3_facet() public view {
        (string memory name_,, bytes4[] memory funcs_) = depositFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4StandardExchangeOrbitalBufferHookDepositFacet"))
        );
        assertEq(depositFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(depositFacet.facetFuncs())));
    }

    function test_J_facetMetadata_se_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = seFacet.facetMetadata();
        assertEq(keccak256(bytes(name_)), keccak256(bytes("UniswapV4StandardExchangeOrbitalBufferHookSeFacet")));
        assertTrue(ifaces_.length >= 2, "J SE interfaces");
        assertEq(seFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(seFacet.facetFuncs())));
    }
}

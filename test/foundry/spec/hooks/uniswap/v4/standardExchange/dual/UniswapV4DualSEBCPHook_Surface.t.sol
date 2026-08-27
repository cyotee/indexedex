// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {
    TestBase_UniswapV4DualSEBCPHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";

/**
 * @title UniswapV4DualSEBCPHook_Surface_Test
 * @notice WP-J-HOOK-001: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke for dual SE CP buffer hook.
 */
contract UniswapV4DualSEBCPHook_Surface_Test is TestBase {
    IFacet internal hooksFacet;
    IFacet internal depositFacet;
    IFacet internal withdrawFacet;
    IFacet internal seFacet;

    function setUp() public override {
        super.setUp();
        hooksFacet = DualFactory.deployHooksFacet(create3Factory);
        depositFacet = DualFactory.deployDepositFacet(create3Factory);
        withdrawFacet = DualFactory.deployWithdrawFacet(create3Factory);
        seFacet = DualFactory.deploySeFacet(create3Factory);
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
        assertTrue(_contains(funcs_, IHook.standardExchange0.selector), "J1 standardExchange0");
        assertTrue(_contains(funcs_, IHook.standardExchange1.selector), "J1 standardExchange1");
        assertTrue(_contains(funcs_, IHook.token0.selector), "J1 token0");
        assertTrue(_contains(funcs_, IHook.token1.selector), "J1 token1");
        assertTrue(_contains(funcs_, IHook.claimSupply0.selector), "J1 claimSupply0");
        assertTrue(_contains(funcs_, IHook.claimSupply1.selector), "J1 claimSupply1");
        assertTrue(_contains(funcs_, bytes4(keccak256("previewSwapExactIn(bool,uint256)"))), "J1 previewSwapExactIn bool");
        assertTrue(_contains(funcs_, bytes4(keccak256("previewSwapExactOut(bool,uint256)"))), "J1 previewSwapExactOut bool");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.tokens.selector), "J1 tokens");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.firstJoinMustBeFullBook.selector), "J1 firstJoinMustBeFullBook");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.isLive.selector), "J1 isLive");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.previewSwapExactIn.selector), "J1 previewSwapExactIn addr");
        assertTrue(_contains(funcs_, IDetfReserveQuote.previewSynthetic.selector), "J1 previewSynthetic");
        assertEq(funcs_.length, 41, "J1 HooksFacet facetFuncs length");
    }

    function test_J1_deposit_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = depositFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHook.deposit.selector), "J1 deposit");
        assertTrue(_contains(funcs_, IHook.depositSingle.selector), "J1 depositSingle");
        assertTrue(_contains(funcs_, IHook.depositWithPermit2Signature.selector), "J1 depositWithPermit2Signature");
        assertTrue(_contains(funcs_, IHook.depositWithPermit2Allowance.selector), "J1 depositWithPermit2Allowance");
        assertTrue(
            _contains(funcs_, IHook.depositSingleWithPermit2Signature.selector),
            "J1 depositSingleWithPermit2Signature"
        );
        assertTrue(
            _contains(funcs_, IHook.depositSingleWithPermit2Allowance.selector),
            "J1 depositSingleWithPermit2Allowance"
        );
        assertTrue(_contains(funcs_, IHook.previewDeposit.selector), "J1 previewDeposit");
        assertTrue(_contains(funcs_, IHook.previewDepositSingle.selector), "J1 previewDepositSingle");
        assertTrue(_contains(funcs_, IHook.previewZapSplit.selector), "J1 previewZapSplit");
        assertTrue(_contains(funcs_, IHook.depositFlexible.selector), "J1 depositFlexible");
        assertTrue(_contains(funcs_, IHook.previewDepositFlexible.selector), "J1 previewDepositFlexible");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.joinUnbalanced.selector), "J1 joinUnbalanced");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.joinSingleAssetExactIn.selector), "J1 joinSingleAssetExactIn");
        assertEq(funcs_.length, 19, "J1 DepositFacet facetFuncs length");
    }

    function test_J1_withdraw_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = withdrawFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHook.withdraw.selector), "J1 withdraw");
        assertTrue(_contains(funcs_, IHook.previewWithdraw.selector), "J1 previewWithdraw");
        assertTrue(_contains(funcs_, IHook.withdrawFlexible.selector), "J1 withdrawFlexible");
        assertTrue(_contains(funcs_, IHook.previewWithdrawFlexible.selector), "J1 previewWithdrawFlexible");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.exitProportional.selector), "J1 exitProportional");
        assertTrue(_contains(funcs_, IDetfReserveQuote.previewBurnToToken.selector), "J1 previewBurnToToken");
        assertEq(funcs_.length, 11, "J1 WithdrawFacet facetFuncs length");
    }

    function test_J1_se_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = seFacet.facetFuncs();
        assertTrue(_contains(funcs_, IStandardExchangeIn.previewExchangeIn.selector), "J1 previewExchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeIn.exchangeIn.selector), "J1 exchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeOut.previewExchangeOut.selector), "J1 previewExchangeOut");
        assertTrue(_contains(funcs_, IStandardExchangeOut.exchangeOut.selector), "J1 exchangeOut");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.ownerSwapExactIn.selector), "J1 ownerSwapExactIn");
        assertTrue(_contains(funcs_, IUniswapV4SeBufferHook.ownerSwapExactOut.selector), "J1 ownerSwapExactOut");
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

    function test_J3_proxySmoke_bindingAndClaimViews() public view {
        IHook proxy_ = dual;
        IDiamondLoupe loupe_ = IDiamondLoupe(hook);

        assertEq(proxy_.poolManager(), address(pm), "J3 poolManager on proxy");
        assertEq(proxy_.feeOracle(), address(indexedexManager), "J3 feeOracle on proxy");
        assertEq(proxy_.standardExchange0(), seA, "J3 se0 on proxy");
        assertEq(proxy_.standardExchange1(), seB, "J3 se1 on proxy");
        assertTrue(
            (proxy_.token0() == address(tokenA) && proxy_.token1() == address(tokenB))
                || (proxy_.token0() == address(tokenB) && proxy_.token1() == address(tokenA)),
            "J3 tokens on proxy"
        );
        assertEq(proxy_.claimSupply0(), 0, "J3 inert claim0");
        assertEq(proxy_.claimSupply1(), 0, "J3 inert claim1");
        assertEq(proxy_.tradingFeeDenominator(), 100_000, "J3 fee denom");

        address loupeHooks_ = loupe_.facetAddress(IHook.standardExchange0.selector);
        assertEq(loupeHooks_, address(hooksFacet), "J3 hooks view loupe");
        assertTrue(loupeHooks_ != hook, "J3 not self-facet");

        address loupeDep_ = loupe_.facetAddress(IHook.deposit.selector);
        assertEq(loupeDep_, address(depositFacet), "J3 deposit loupe");

        address loupeWd_ = loupe_.facetAddress(IHook.withdraw.selector);
        assertEq(loupeWd_, address(withdrawFacet), "J3 withdraw loupe");

        address loupeSe_ = loupe_.facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertEq(loupeSe_, address(seFacet), "J3 se exchangeIn loupe");
    }

    function test_J_facetMetadata_hooks_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = hooksFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet"))
        );
        assertTrue(ifaces_.length >= 1, "J interfaces");
        assertEq(hooksFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(hooksFacet.facetFuncs())));
    }

    function test_J_facetMetadata_deposit_matches_CREATE3_facet() public view {
        (string memory name_,, bytes4[] memory funcs_) = depositFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet"))
        );
        assertEq(depositFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(depositFacet.facetFuncs())));
    }

    function test_J_facetMetadata_se_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = seFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet"))
        );
        assertTrue(ifaces_.length >= 2, "J SE interfaces");
        assertEq(seFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(seFacet.facetFuncs())));
    }
}

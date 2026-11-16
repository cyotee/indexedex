// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

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

    function _assertExactSelectors(bytes4[] memory actual_, bytes4[] memory expected_) internal pure {
        assertEq(actual_.length, expected_.length, "selector set length");
        for (uint256 i; i < expected_.length; ++i) {
            assertTrue(_contains(actual_, expected_[i]), "missing expected selector");
            for (uint256 j; j < i; ++j) {
                assertTrue(actual_[i] != actual_[j], "duplicate actual selector");
                assertTrue(expected_[i] != expected_[j], "duplicate expected selector");
            }
        }
    }

    function _assertFacetFuncsOnLoupe(IFacet facet_, address expectedFacet_) internal view {
        bytes4[] memory funcs_ = facet_.facetFuncs();
        IDiamondLoupe loupe_ = IDiamondLoupe(hook);
        _assertExactSelectors(loupe_.facetFunctionSelectors(expectedFacet_), funcs_);
        for (uint256 i; i < funcs_.length; ++i) {
            address loupeFacet_ = loupe_.facetAddress(funcs_[i]);
            assertEq(loupeFacet_, expectedFacet_, "J2 loupe maps selector to CREATE3 facet");
            assertTrue(loupeFacet_ != address(0), "J2 not zero");
            assertTrue(loupeFacet_ != hook, "J2 not self-facet");
        }
    }

    /// @dev Every role selector must occur once in the complete role union, including across facets.
    function _assertRoleSelectorUnion() internal view {
        bytes4[][] memory roles_ = new bytes4[][](4);
        roles_[0] = hooksFacet.facetFuncs();
        roles_[1] = depositFacet.facetFuncs();
        roles_[2] = withdrawFacet.facetFuncs();
        roles_[3] = seFacet.facetFuncs();
        bytes4[] memory union_ = new bytes4[](95); // 43 hooks + 19 deposit + 24 withdraw + 9 SE.
        uint256 count_;
        for (uint256 i; i < roles_.length; ++i) {
            for (uint256 j; j < roles_[i].length; ++j) {
                bytes4 selector_ = roles_[i][j];
                for (uint256 k; k < count_; ++k) {
                    assertTrue(union_[k] != selector_, "duplicate role selector");
                }
                assertLt(count_, union_.length, "unexpected role selector");
                union_[count_++] = selector_;
            }
        }
        assertEq(count_, union_.length, "complete role selector union");

        IDiamondLoupe loupe_ = IDiamondLoupe(hook);
        address[4] memory facets_ = [address(hooksFacet), address(depositFacet), address(withdrawFacet), address(seFacet)];
        for (uint256 i; i < facets_.length; ++i) {
            _assertFacetFuncsOnLoupe(IFacet(facets_[i]), facets_[i]);
        }
        for (uint256 i; i < union_.length; ++i) {
            assertTrue(loupe_.facetAddress(union_[i]) != address(0), "missing union selector on proxy");
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
        assertTrue(_contains(funcs_, IHook.rateProviders.selector), "D60 rateProviders");
        assertTrue(_contains(funcs_, IHook.rateProvider.selector), "D60 rateProvider(address)");
        assertEq(funcs_.length, 43, "J1 HooksFacet facetFuncs length"); // D60: + 2 getters
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
        bytes4[] memory expected_ = new bytes4[](24);
        expected_[0] = IHook.withdraw.selector;
        expected_[1] = IHook.previewWithdraw.selector;
        expected_[2] = IHook.withdrawFlexible.selector;
        expected_[3] = IHook.previewWithdrawFlexible.selector;
        expected_[4] = IUniswapV4SeBufferHook.exitProportional.selector;
        expected_[5] = IUniswapV4SeBufferHook.previewExitProportional.selector;
        expected_[6] = IUniswapV4SeBufferHook.exitSingleAssetExactBptIn.selector;
        expected_[7] = IUniswapV4SeBufferHook.previewExitSingleAssetExactBptIn.selector;
        expected_[8] = IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut.selector;
        expected_[9] = IUniswapV4SeBufferHook.previewExitSingleAssetExactTokenOut.selector;
        expected_[10] = IDetfReserveQuote.previewBurnToToken.selector;
        expected_[11] = IStandardExchangeIn.previewExchangeIn.selector;
        expected_[12] = IStandardizedYield.exchangeRate.selector;
        expected_[13] = IStandardizedYield.yieldToken.selector;
        expected_[14] = IStandardizedYield.assetInfo.selector;
        expected_[15] = IStandardizedYield.getTokensIn.selector;
        expected_[16] = IStandardizedYield.getTokensOut.selector;
        expected_[17] = IStandardizedYield.isValidTokenIn.selector;
        expected_[18] = IStandardizedYield.isValidTokenOut.selector;
        expected_[19] = IStandardizedYield.previewDeposit.selector;
        expected_[20] = IStandardizedYield.previewRedeem.selector;
        expected_[21] = IStandardizedYield.getRewardTokens.selector;
        expected_[22] = IStandardizedYield.accruedRewards.selector;
        expected_[23] = IStandardizedYield.rewardIndexesStored.selector;
        _assertExactSelectors(funcs_, expected_);
    }

    function test_J1_se_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = seFacet.facetFuncs();
        bytes4[] memory expected_ = new bytes4[](9);
        expected_[0] = IUniswapV4SeBufferHook.ownerSwapExactOut.selector;
        expected_[1] = IStandardExchangeIn.exchangeIn.selector;
        expected_[2] = IStandardExchangeOut.previewExchangeOut.selector;
        expected_[3] = IStandardExchangeOut.exchangeOut.selector;
        expected_[4] = IUniswapV4SeBufferHook.ownerSwapExactIn.selector;
        expected_[5] = IStandardizedYield.deposit.selector;
        expected_[6] = IStandardizedYield.redeem.selector;
        expected_[7] = IStandardizedYield.rewardIndexesCurrent.selector;
        expected_[8] = IStandardizedYield.claimRewards.selector;
        _assertExactSelectors(funcs_, expected_);
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
        _assertRoleSelectorUnion();
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
        assertEq(
            loupe_.facetAddress(IStandardExchangeIn.previewExchangeIn.selector),
            address(withdrawFacet),
            "J3 shared exact-input quote belongs to withdraw facet"
        );
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

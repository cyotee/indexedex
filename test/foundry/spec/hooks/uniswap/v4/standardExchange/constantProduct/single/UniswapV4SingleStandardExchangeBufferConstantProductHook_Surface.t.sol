// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface_Test
 * @notice WP-J-HOOK-001: Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy** smoke for single SE CP buffer hook.
 * @dev Guards silent-missing API: product selectors cut into CREATE3 facets and routed via diamond loupe.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface_Test is TestBase {
    IFacet internal seFacet;
    IFacet internal depositFacet;
    IFacet internal withdrawFacet;

    function setUp() public override {
        super.setUp();
        // CREATE3 is idempotent — re-resolve same salts as package deploy.
        seFacet = PkgFactory.deploySeFacet(create3Factory);
        depositFacet = PkgFactory.deployDepositFacet(create3Factory);
        withdrawFacet = PkgFactory.deployWithdrawFacet(create3Factory);
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

    /// @notice J1: SE + hooks + product view selectors are cut into SeFacet.
    function test_J1_se_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = seFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHooks.beforeSwap.selector), "J1 beforeSwap");
        assertTrue(_contains(funcs_, IHooks.beforeInitialize.selector), "J1 beforeInitialize");
        assertTrue(_contains(funcs_, IHooks.beforeAddLiquidity.selector), "J1 beforeAddLiquidity");
        assertTrue(_contains(funcs_, IHook.poolManager.selector), "J1 poolManager");
        assertTrue(_contains(funcs_, IHook.standardExchange.selector), "J1 standardExchange");
        assertTrue(_contains(funcs_, IHook.pairToken.selector), "J1 pairToken");
        assertTrue(_contains(funcs_, IHook.rawToken.selector), "J1 rawToken");
        assertTrue(_contains(funcs_, IHook.rawReserve.selector), "J1 rawReserve");
        assertTrue(_contains(funcs_, IHook.seClaimSupply.selector), "J1 seClaimSupply");
        assertTrue(_contains(funcs_, IHook.isLive.selector), "J1 isLive");
        assertTrue(_contains(funcs_, IHook.previewSwapExactIn.selector), "J1 previewSwapExactIn");
        assertTrue(_contains(funcs_, IStandardExchangeIn.exchangeIn.selector), "J1 exchangeIn");
        assertTrue(_contains(funcs_, IStandardExchangeOut.exchangeOut.selector), "J1 exchangeOut");
        assertTrue(_contains(funcs_, IStandardExchangeIn.previewExchangeIn.selector), "J1 previewExchangeIn");
        assertTrue(_contains(funcs_, IHook.ownerSwapExactIn.selector), "J1 ownerSwapExactIn");
        assertTrue(_contains(funcs_, IHook.ownerSwapExactOut.selector), "J1 ownerSwapExactOut");
        assertEq(funcs_.length, 37, "J1 SeFacet facetFuncs length");
    }

    /// @notice J1: deposit / zap / SE-share multipath money entrypoints are cut.
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
        assertTrue(_contains(funcs_, IHook.depositWithSeShares.selector), "J1 depositWithSeShares");
        assertTrue(_contains(funcs_, IHook.previewDepositWithSeShares.selector), "J1 previewDepositWithSeShares");
        assertEq(funcs_.length, 11, "J1 DepositFacet facetFuncs length");
    }

    /// @notice J1: withdraw / SE-share multipath money entrypoints are cut.
    function test_J1_withdraw_targetSelectors_subseteq_facetFuncs() public view {
        bytes4[] memory funcs_ = withdrawFacet.facetFuncs();
        assertTrue(_contains(funcs_, IHook.withdraw.selector), "J1 withdraw");
        assertTrue(_contains(funcs_, IHook.withdrawSingle.selector), "J1 withdrawSingle");
        assertTrue(_contains(funcs_, IHook.previewWithdraw.selector), "J1 previewWithdraw");
        assertTrue(_contains(funcs_, IHook.previewWithdrawSingle.selector), "J1 previewWithdrawSingle");
        assertTrue(_contains(funcs_, IHook.withdrawSeShares.selector), "J1 withdrawSeShares");
        assertTrue(_contains(funcs_, IHook.previewWithdrawSeShares.selector), "J1 previewWithdrawSeShares");
        assertEq(funcs_.length, 6, "J1 WithdrawFacet facetFuncs length");
    }

    /* ---------------------------------------------------------------------- */
    /*  J2: facetFuncs ⊆ loupe on production hook proxy                      */
    /* ---------------------------------------------------------------------- */

    function test_J2_se_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(seFacet, address(seFacet));
    }

    function test_J2_deposit_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(depositFacet, address(depositFacet));
    }

    function test_J2_withdraw_facetFuncs_subseteq_loupe_onProxy() public view {
        _assertFacetFuncsOnLoupe(withdrawFacet, address(withdrawFacet));
    }

    /* ---------------------------------------------------------------------- */
    /*  J3: proxy smoke — loupe-routed calls (not facet impl address)        */
    /* ---------------------------------------------------------------------- */

    /// @notice J3: binding + reserve views execute on the production diamond proxy.
    function test_J3_proxySmoke_bindingAndReserveViews() public view {
        IHook proxy_ = single;
        IDiamondLoupe loupe_ = IDiamondLoupe(hook);

        assertEq(proxy_.poolManager(), address(pm), "J3 poolManager on proxy");
        assertEq(proxy_.feeOracle(), address(indexedexManager), "J3 feeOracle on proxy");
        assertEq(proxy_.standardExchange(), se, "J3 standardExchange on proxy");
        assertEq(proxy_.pairToken(), address(pairToken), "J3 pairToken on proxy");
        assertEq(proxy_.rawToken(), address(rawToken), "J3 rawToken on proxy");
        assertTrue(proxy_.currency0() < proxy_.currency1(), "J3 currency order on proxy");
        assertEq(proxy_.rawReserve(), 0, "J3 inert rawReserve");
        assertEq(proxy_.seClaimSupply(), 0, "J3 inert seClaimSupply");
        assertFalse(proxy_.isLive(), "J3 not live until deposit");
        assertEq(proxy_.tradingFeeDenominator(), 100_000, "J3 fee denom on proxy");

        address loupeSe_ = loupe_.facetAddress(IHook.standardExchange.selector);
        assertEq(loupeSe_, address(seFacet), "J3 se view loupe");
        assertTrue(loupeSe_ != hook, "J3 not self-facet");

        address loupeDep_ = loupe_.facetAddress(IHook.deposit.selector);
        assertEq(loupeDep_, address(depositFacet), "J3 deposit loupe");

        address loupeWd_ = loupe_.facetAddress(IHook.withdraw.selector);
        assertEq(loupeWd_, address(withdrawFacet), "J3 withdraw loupe");
    }

    /// @notice J facet metadata parity on CREATE3 product facets.
    function test_J_facetMetadata_se_matches_CREATE3_facet() public view {
        (string memory name_, bytes4[] memory ifaces_, bytes4[] memory funcs_) = seFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet")),
            "J metadata name"
        );
        assertTrue(ifaces_.length >= 1, "J interfaces");
        assertEq(seFacet.facetFuncs().length, funcs_.length, "J funcs match metadata");
        assertEq(
            keccak256(abi.encodePacked(funcs_)),
            keccak256(abi.encodePacked(seFacet.facetFuncs())),
            "J metadata funcs == facetFuncs"
        );
    }

    function test_J_facetMetadata_deposit_matches_CREATE3_facet() public view {
        (string memory name_,, bytes4[] memory funcs_) = depositFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4SingleStandardExchangeBufferConstantProductHookDepositFacet"))
        );
        assertEq(depositFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(depositFacet.facetFuncs())));
    }

    function test_J_facetMetadata_withdraw_matches_CREATE3_facet() public view {
        (string memory name_,, bytes4[] memory funcs_) = withdrawFacet.facetMetadata();
        assertEq(
            keccak256(bytes(name_)),
            keccak256(bytes("UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawFacet"))
        );
        assertEq(withdrawFacet.facetFuncs().length, funcs_.length);
        assertEq(keccak256(abi.encodePacked(funcs_)), keccak256(abi.encodePacked(withdrawFacet.facetFuncs())));
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeTransitionQuote as Transition, IStandardExchangeExternalQuote as ExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {IUniswapV4FullSpreadPonsFamilyHookExecutionProtection as Diagnostics} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookExecutionProtection.sol";
import {IUniswapV4FullSpreadPonsFamilyHookDFPkg as Package} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
import {IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding as InBinding, IUniswapV4FullSpreadPonsFamilyHookOutExecutionBinding as OutBinding} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";
import {IUniswapV4FullSpreadPonsFamilyHookPositionImport as Import} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookInTarget.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService as Factory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookAdmissionAndIdentityTest[]
contract UniswapV4FullSpreadPonsFamilyHookAdmissionAndIdentityTest is Acceptance {
    function test_nonzeroHookAndMalformedKeyRejected() public {
        PoolKey memory wrong = poolKey;
        wrong.hooks = IHooks(address(0x1234));
        vm.expectRevert(Package.InvalidPoolKey.selector);
        uniswapV4StandardExchangeDFPkg.deployVault(wrong);
        wrong = poolKey;
        wrong.currency1 = wrong.currency0;
        vm.expectRevert(Package.InvalidPoolKey.selector);
        uniswapV4StandardExchangeDFPkg.deployVault(wrong);
    }

    function test_separatePoolInstancesHaveIndependentState() public {
        _bootstrap();
        PoolKey memory second = poolKey;
        second.tickSpacing = 120;
        ponsHook.registerPool(second, address(token1), address(this), address(this), 100, false, ponsHook.currentFeePolicy());
        poolManager.initialize(second, uint160(1) << 96);
        IStandardExchangeProxy other = IStandardExchangeProxy(uniswapV4StandardExchangeDFPkg.deployVault(second));
        assertTrue(address(other) != address(vault));
        assertEq(other.totalSupply(), 0);
        assertEq(other.reserveOfToken(address(token0)), 0);
        assertGt(vault.totalSupply(), 0);
    }

    function test_fixedProtectionDiagnosticsSeparateFromSleeveInterface() public view {
        (uint16 repair, uint16 composition, uint16 shortfall, uint16 alignment, uint16 repairComposition) = Diagnostics(address(vault)).executionProtectionBps();
        assertEq(repair, 25); assertEq(composition, 50); assertEq(shortfall, 10);
        assertEq(alignment, 1); assertEq(repairComposition, 1);
        assertTrue(type(Diagnostics).interfaceId != type(Reserve).interfaceId);
        assertEq(Reserve(address(vault)).targetLiquidReservePercentage(), 0.2e18);
    }

    function test_targetInterfaceControlsAllInstalledOnRegistryProxy() public {
        bytes4[] memory controls = _controls();
        IDiamond.FacetCut[] memory cuts = uniswapV4StandardExchangeDFPkg.facetCuts();
        uint256 familySelectors;
        for (uint256 i = 5; i < cuts.length; ++i) {
            familySelectors += cuts[i].functionSelectors.length;
            IFacet facet = IFacet(cuts[i].facetAddress);
            assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(facet));
            bytes4[] memory expected = new bytes4[](cuts[i].functionSelectors.length);
            uint256 count;
            for (uint256 j; j < controls.length; ++j) {
                if (IDiamondLoupe(address(vault)).facetAddress(controls[j]) == address(facet)) expected[count++] = controls[j];
            }
            assertEq(count, expected.length);
            assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet, expected, facet.facetFuncs()));
        }
        assertEq(familySelectors, controls.length);
        for (uint256 i; i < controls.length; ++i) assertTrue(IDiamondLoupe(address(vault)).facetAddress(controls[i]) != address(0));
    }

    function test_remainingQueryAndNativeSYSelectorsSmokeOnProxy() public {
        _bootstrap();
        Reserve reserve = Reserve(address(vault));
        assertTrue(reserve.canOpenPoolManagerUnlock());
        assertEq(reserve.localReserve(address(token0)), token0.balanceOf(address(vault)));
        reserve.deployedReserve(); reserve.actualLiquidReservePercentage(address(token0));
        assertEq(address(reserve.twapOracle()), address(twapOracle));
        (bytes memory state,) = Transition(address(vault)).quoteState(address(token0), address(this));
        assertEq(Transition(address(vault)).quoteShareBalance(state), vault.balanceOf(address(this)));
        assertEq(Transition(address(vault)).quoteTotalSupply(state), vault.totalSupply());
        assertEq(Transition(address(vault)).quoteAssets(state, 0), 0);
        Transition(address(vault)).quoteTransition(state, Transition.Operation.ReceiveShares, 0);
        ExternalQuote(address(vault)).quoteExternalDeposit(state, address(token0), 0);
        ExternalQuote(address(vault)).quoteExternalExchange(state, address(token1), 0);
        SY sy = SY(address(vault));
        sy.exchangeRate(); sy.yieldToken(); sy.assetInfo();
        assertEq(sy.getTokensIn().length, 2); assertEq(sy.getTokensOut().length, 2);
        assertTrue(sy.isValidTokenIn(address(token0))); assertTrue(sy.isValidTokenOut(address(token1)));
        assertEq(sy.previewDeposit(address(token0), 0), 0); assertEq(sy.previewRedeem(address(token0), 0), 0);
        assertEq(sy.getRewardTokens().length, 0); assertEq(sy.accruedRewards(address(this)).length, 0);
        assertEq(sy.rewardIndexesCurrent().length, 0); assertEq(sy.rewardIndexesStored().length, 0);
        assertEq(sy.claimRewards(address(this)).length, 0);
    }

    function test_occupiedPackageIdentityRejectsChangedBinding() public {
        Package.PkgInit memory init = Factory.buildArgsUniswapV4FullSpreadPonsFamilyHookPkgInit(_univ4SePkgInitCore());
        init = Factory.attachTwapOracle(init, twapOracle);
        init.expectedHook = address(ponsHook);
        init = Factory.attachUniswapV4FullSpreadPonsFamilyHookMultiFacets(init,
            uniswapV4StandardExchangeInMultiFacet, uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet, uniswapV4StandardExchangeOutMultiQueryFacet);
        assertEq(this.deployWithBinding(init), address(uniswapV4StandardExchangeDFPkg));
        init.weth = IWETH(address(token0));
        vm.expectRevert(Factory.InvalidComponentBinding.selector);
        this.deployWithBinding(init);
    }

    function deployWithBinding(Package.PkgInit memory init_) external returns (address) {
        vm.prank(owner);
        return address(Factory.deployUniswapV4FullSpreadPonsFamilyHookDFPkg(indexedexManager, init_));
    }

    function test_historicalAndSameAbiFlagsSingletonRejected() public {
        PoolKey memory wrong = poolKey;
        // A second genuine Pons instance has the full ABI and required address flags,
        // but is not the package-bound singleton (as with a historical factory stack).
        _initializePonsHook();
        wrong.hooks = IHooks(address(ponsHook));
        vm.expectRevert(Package.InvalidPoolKey.selector);
        uniswapV4StandardExchangeDFPkg.deployVault(wrong);
    }

    function test_unregisteredPoolAndNonzeroLpFeeRejected() public {
        PoolKey memory wrong = poolKey;
        wrong.tickSpacing = 30;
        poolManager.initialize(wrong, uint160(1) << 96);
        vm.expectRevert(Package.InvalidPoolKey.selector);
        uniswapV4StandardExchangeDFPkg.deployVault(wrong);
        wrong = poolKey;
        wrong.fee = 500;
        vm.expectRevert(Package.InvalidPoolKey.selector);
        uniswapV4StandardExchangeDFPkg.deployVault(wrong);
    }

    function _controls() private pure returns (bytes4[] memory c) {
        c = new bytes4[](46);
        c[0] = IStandardExchangeIn.exchangeIn.selector; c[1] = IUnlockCallback.unlockCallback.selector;
        c[2] = InBinding.UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.selector;
        c[3] = IStandardExchangeOut.exchangeOut.selector; c[4] = OutBinding.UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.selector;
        c[5] = Transition.quoteAssets.selector; c[6] = Transition.quoteShareBalance.selector;
        c[7] = Transition.quoteTransition.selector; c[8] = ExternalQuote.quoteExternalExchange.selector;
        c[9] = Transition.quoteTotalSupply.selector; c[10] = ExternalQuote.quoteExternalDeposit.selector;
        c[11] = IStandardExchangeOut.previewExchangeOut.selector; c[12] = Transition.quoteState.selector;
        c[13] = IStandardExchangeInMulti.previewExchangeInManyToOne.selector; c[14] = IStandardExchangeIn.previewExchangeIn.selector;
        c[15] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;
        c[16] = IStandardExchangeInMulti.exchangeInManyToOne.selector; c[17] = IStandardExchangeOutMulti.exchangeOutOneToMany.selector;
        c[18] = Reserve.canOpenPoolManagerUnlock.selector; c[19] = Reserve.localReserve.selector;
        c[20] = Reserve.deployedReserve.selector; c[21] = Reserve.targetLiquidReservePercentage.selector;
        c[22] = Reserve.actualLiquidReservePercentage.selector; c[23] = Reserve.rebalanceLiquidReserve.selector;
        c[24] = Reserve.twapOracle.selector; c[25] = Diagnostics.executionProtectionBps.selector;
        c[26] = Import.importPosition.selector;
        c[27] = SY.deposit.selector; c[28] = SY.redeem.selector; c[29] = SY.exchangeRate.selector;
        c[30] = SY.yieldToken.selector; c[31] = SY.assetInfo.selector; c[32] = SY.getTokensIn.selector;
        c[33] = SY.getTokensOut.selector; c[34] = SY.isValidTokenIn.selector; c[35] = SY.isValidTokenOut.selector;
        c[36] = SY.previewDeposit.selector; c[37] = SY.previewRedeem.selector; c[38] = SY.getRewardTokens.selector;
        c[39] = SY.accruedRewards.selector; c[40] = SY.rewardIndexesCurrent.selector;
        c[41] = SY.rewardIndexesStored.selector; c[42] = SY.claimRewards.selector;
        c[43] = IStandardExchangeUnlockContextQuote.quoteStateWithUnavailableUnlock.selector;
        c[44] = IStandardExchangeExactOutputQuantityQuote.quoteInputForExactShares.selector;
        c[45] = IStandardExchangeExactOutputQuantityQuote.quoteSharesForExactAssets.selector;
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookAdmissionAndIdentityTest[]

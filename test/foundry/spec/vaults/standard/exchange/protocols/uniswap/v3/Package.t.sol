// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3MintCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC8109Introspection} from "@crane/contracts/introspection/ERC8109/IERC8109Introspection.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeFrozenQuoteInputs} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {VaultTypeUtils} from "contracts/registries/vault/VaultTypeUtils.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as Family} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as LegacyReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as PositionImport} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice Package boundary regressions: real manager, registry, pool, and proxy.
contract UniswapV3FullSpreadV4Accounting_Package_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    address internal vault;
    IUniswapV3Pool internal pool;

    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Token A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Token B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        vault = address(_deployVault(pool));
    }

    /// @notice Product-interface controls catch selectors omitted from declarations or the live cut.
    function test_newFacetsServeCompleteTargetDerivedSurface() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IStandardExchangeBundleIn.exchangeBundleInForSingleOut.selector;
        selectors[1] = IStandardExchangeBundleOut.exchangeBundleOut.selector;
        _assertFacet(uniswapV3StandardExchangeInMultiFacet, selectors);
        selectors[0] = IStandardExchangeBundleIn.previewExchangeBundleInForSingleOut.selector;
        selectors[1] = IStandardExchangeBundleOut.previewExchangeBundleOut.selector;
        _assertFacet(uniswapV3StandardExchangeInMultiQueryFacet, selectors);
        selectors = new bytes4[](4);
        selectors[0] = Family.donate.selector;
        selectors[1] = Family.compound.selector;
        selectors[2] = Family.setOperator.selector;
        selectors[3] = Family.setOperatorFor.selector;
        _assertFacet(uniswapV3StandardExchangeOutMultiFacet, selectors);
        selectors = new bytes4[](3);
        selectors[0] = IBasicVault.reserves.selector;
        selectors[1] = IBasicVault.reserveOfToken.selector;
        selectors[2] = LegacyReserve.canOpenBoundPoolOps.selector;
        _assertFacet(uniswapV3StandardExchangeLiquidReserveFacet, selectors);
    }

    /// @notice The existing one-token API, callbacks, and import stay reachable independently.
    function test_oneTokenCallbacksAndImportRemainCutExactlyOnce() public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = IStandardExchangeIn.exchangeIn.selector;
        selectors[1] = IUniswapV3MintCallback.uniswapV3MintCallback.selector;
        selectors[2] = IUniswapV3SwapCallback.uniswapV3SwapCallback.selector;
        _assertFacet(uniswapV3StandardExchangeInFacet, selectors);
        selectors = new bytes4[](4);
        selectors[0] = IStandardExchangeIn.previewExchangeIn.selector;
        selectors[1] = IStandardExchangeStateQuote.quoteExchangeState.selector;
        selectors[2] = IStandardExchangeStateQuote.quoteExchangeIn.selector;
        selectors[3] = IStandardExchangeStateQuote.quoteExchangeSupply.selector;
        _assertFacet(uniswapV3StandardExchangeInQueryFacet, selectors);
        selectors = new bytes4[](1);
        selectors[0] = IStandardExchangeOut.exchangeOut.selector;
        _assertFacet(uniswapV3StandardExchangeOutFacet, selectors);
        selectors[0] = IStandardExchangeOut.previewExchangeOut.selector;
        _assertFacet(uniswapV3StandardExchangeOutQueryFacet, selectors);
        selectors = new bytes4[](2);
        selectors[0] = PositionImport.importPosition.selector;
        selectors[1] = PositionImport.previewImportPosition.selector;
        _assertFacet(uniswapV3StandardExchangePositionImportFacet, selectors);
        (bool success, bytes memory result) = vault.staticcall(abi.encodeCall(
            IStandardExchangeIn.previewExchangeIn, (IERC20(pool.token0()), 0, IERC20(vault))
        ));
        assertTrue(success);
        assertEq(result.length, 64, "previewExchangeIn keeps both return words");
    }

    /// @notice Retired routes cannot accidentally return through an old facet or ERC-165 declaration.
    function test_retiredSelectorsAndInterfacesAreAbsent() public view {
        bytes4[19] memory absent = [
            LegacyReserve.localReserve.selector, LegacyReserve.deployedReserve.selector,
            LegacyReserve.targetLiquidReservePercentage.selector, LegacyReserve.actualLiquidReservePercentage.selector,
            LegacyReserve.rebalanceLiquidReserve.selector, IStandardExchangeInMulti.exchangeInManyToOne.selector,
            IStandardExchangeInMulti.previewExchangeInManyToOne.selector,
            IStandardExchangeOutMulti.exchangeOutOneToMany.selector,
            IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector,
            IStandardExchangeTransitionQuote.quoteState.selector, IStandardExchangeTransitionQuote.quoteAssets.selector,
            IStandardExchangeTransitionQuote.quoteTransition.selector,
            IStandardExchangeTransitionQuote.quoteShareBalance.selector,
            IStandardExchangeTransitionQuote.quoteTotalSupply.selector,
            IStandardExchangeExternalQuote.quoteExternalDeposit.selector,
            IStandardExchangeExternalQuote.quoteExternalExchange.selector,
            IStandardExchangeFrozenQuoteInputs.captureFrozenQuoteInputs.selector,
            bytes4(keccak256("getRate()")), bytes4(keccak256("unlockCallback(bytes)"))
        ];
        for (uint256 i; i < absent.length; ++i) _assertAbsent(absent[i]);
        bytes4[] memory yieldSelectors = NativeStandardYieldSelectors._append(new bytes4[](0));
        for (uint256 i; i < yieldSelectors.length; ++i) _assertAbsent(yieldSelectors[i]);
        bytes4[7] memory interfaces = [
            type(IStandardizedYield).interfaceId, type(LegacyReserve).interfaceId,
            type(IStandardExchangeInMulti).interfaceId, type(IStandardExchangeOutMulti).interfaceId,
            type(IStandardExchangeTransitionQuote).interfaceId, type(IStandardExchangeExternalQuote).interfaceId,
            type(IStandardExchangeFrozenQuoteInputs).interfaceId
        ];
        for (uint256 i; i < interfaces.length; ++i) {
            assertFalse(IERC165(vault).supportsInterface(interfaces[i]));
        }
    }

    /// @notice Fee resolution keeps the historical type key without configuring a liquid reserve.
    function test_usageFeeResolvesStableKeyWithoutLiquidSetting() public {
        bytes4 usageKey = type(LegacyReserve).interfaceId;
        assertEq(VaultTypeUtils._decodeVaultFeeType(IStandardVault(vault).vaultFeeTypeIds(), VaultFeeType.USAGE), usageKey);
        assertEq(indexedexManager.defaultLiquidReservePercentageOfTypeId(usageKey), 0);
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(1e15);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFeeOfTypeId(usageKey, 7e15);
        vm.stopPrank();
        assertEq(indexedexManager.usageFeeOfVault(vault), 7e15);
    }

    /// @notice Registry initialization preserves tokens, ERC-20, permit, and family discovery.
    function test_registryProxyPreservesSharedSurface() public view {
        assertTrue(indexedexManager.isVault(vault));
        address[] memory tokens = IBasicVault(vault).vaultTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], pool.token0());
        assertEq(tokens[1], pool.token1());
        assertEq(IERC20(vault).totalSupply(), 0);
        assertEq(IERC20Permit(vault).nonces(address(this)), 0);
        assertTrue(IERC165(vault).supportsInterface(type(Family).interfaceId));
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeBundleIn).interfaceId));
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeBundleOut).interfaceId));
        assertTrue(IERC165(vault).supportsInterface(type(IStandardExchangeStateQuote).interfaceId));
        assertEq(IBasicVault(vault).reserves().length, 2);
        assertEq(IBasicVault(vault).reserveOfToken(address(0x1234)), 0);
        assertTrue(LegacyReserve(vault).canOpenBoundPoolOps());
        IDiamond.FacetCut[] memory cuts = uniswapV3StandardExchangeDFPkg.facetCuts();
        assertEq(cuts.length, 14);
        assertEq(cuts[3].functionSelectors.length, 1);
        assertEq(cuts[3].functionSelectors[0], IBasicVault.vaultTokens.selector);
    }

    function _assertFacet(IFacet facet, bytes4[] memory expected) internal {
        bytes4[] memory actual = facet.facetFuncs();
        assertEq(actual.length, expected.length);
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(facet, expected, actual));
        assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(facet));
        IDiamond.FacetCut[] memory cuts = uniswapV3StandardExchangeDFPkg.facetCuts();
        for (uint256 i; i < expected.length; ++i) {
            assertEq(IERC8109Introspection(vault).facetAddress(expected[i]), address(facet));
            uint256 occurrences;
            for (uint256 j; j < cuts.length; ++j) {
                for (uint256 k; k < cuts[j].functionSelectors.length; ++k) {
                    if (cuts[j].functionSelectors[k] == expected[i]) {
                        ++occurrences;
                        assertEq(cuts[j].facetAddress, address(facet));
                    }
                }
            }
            assertEq(occurrences, 1, "selector must be cut exactly once");
        }
    }

    function _assertAbsent(bytes4 selector) internal view {
        assertEq(IERC8109Introspection(vault).facetAddress(selector), address(0));
        IDiamond.FacetCut[] memory cuts = uniswapV3StandardExchangeDFPkg.facetCuts();
        for (uint256 i; i < cuts.length; ++i) {
            for (uint256 j; j < cuts[i].functionSelectors.length; ++j) {
                assertTrue(cuts[i].functionSelectors[j] != selector);
            }
        }
    }
}

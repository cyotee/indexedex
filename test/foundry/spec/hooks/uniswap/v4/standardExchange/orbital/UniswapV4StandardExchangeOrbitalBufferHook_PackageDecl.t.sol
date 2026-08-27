// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookInitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/facets/UniswapV4StandardExchangeOrbitalBufferHookInitFacet.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";

contract UniswapV4StandardExchangeOrbitalBufferHook_PackageDecl_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    function test_facetCuts_isBootstrapOnly() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.facetCuts();
        assertEq(cuts.length, 4);
        assertEq(cuts[0].facetAddress, address(multiStepOwnableFacet));
        assertEq(cuts[1].facetAddress, address(multiAssetBasicVaultFacet));
        assertEq(cuts[2].facetAddress, address(multiAssetStandardVaultFacet));
        assertEq(cuts[3].facetAddress, address(hookPkg));
        assertEq(uint256(cuts[0].action), uint256(IDiamond.FacetCutAction.Add));
        assertEq(uint256(cuts[1].action), uint256(IDiamond.FacetCutAction.Add));
        assertEq(uint256(cuts[2].action), uint256(IDiamond.FacetCutAction.Add));
        assertEq(uint256(cuts[3].action), uint256(IDiamond.FacetCutAction.Add));
        _assertSelectorsEq(cuts[0].functionSelectors, multiStepOwnableFacet.facetFuncs());
        _assertSelectorsEq(cuts[3].functionSelectors, _s58());
        _assertSelectorsEq(cuts[1].functionSelectors, multiAssetBasicVaultFacet.facetFuncs());
        _assertSelectorsEq(cuts[2].functionSelectors, multiAssetStandardVaultFacet.facetFuncs());
    }

    function test_productionFacetCuts_sevenAdds() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.productionFacetCuts();
        assertEq(cuts.length, 7);
        assertEq(cuts[0].facetAddress, address(hookPkg.HOOKS_FACET()));
        assertEq(cuts[1].facetAddress, address(hookPkg.DEPOSIT_FACET()));
        assertEq(cuts[2].facetAddress, address(hookPkg.WITHDRAW_FACET()));
        assertEq(cuts[3].facetAddress, address(hookPkg.SE_FACET()));
        assertEq(cuts[4].facetAddress, address(erc20Facet));
        assertEq(cuts[5].facetAddress, address(erc5267Facet));
        assertEq(cuts[6].facetAddress, address(erc2612Facet));
        _assertSelectorsEq(cuts[0].functionSelectors, hookPkg.HOOKS_FACET().facetFuncs());
        _assertSelectorsEq(cuts[1].functionSelectors, hookPkg.DEPOSIT_FACET().facetFuncs());
        _assertSelectorsEq(cuts[2].functionSelectors, hookPkg.WITHDRAW_FACET().facetFuncs());
        _assertSelectorsEq(cuts[3].functionSelectors, hookPkg.SE_FACET().facetFuncs());
        _assertSelectorsEq(cuts[4].functionSelectors, erc20Facet.facetFuncs());
        _assertSelectorsEq(cuts[5].functionSelectors, erc5267Facet.facetFuncs());
        _assertSelectorsEq(cuts[6].functionSelectors, erc2612Facet.facetFuncs());
        for (uint256 i; i < cuts.length; ++i) {
            assertEq(uint256(cuts[i].action), uint256(IDiamond.FacetCutAction.Add));
        }
    }

    function test_facetCuts_ne_productionFacetCuts() public view {
        IDiamond.FacetCut[] memory boot = hookPkg.facetCuts();
        IDiamond.FacetCut[] memory prod = hookPkg.productionFacetCuts();
        assertTrue(boot.length != prod.length);
        assertTrue(boot[0].facetAddress != prod[0].facetAddress);
    }

    function test_facetInterfaces_nineProductionIds() public view {
        bytes4[] memory ids = hookPkg.facetInterfaces();
        assertEq(ids.length, 12);
        assertEq(ids[0], type(IERC20).interfaceId);
        assertEq(ids[1], type(IERC20Metadata).interfaceId);
        assertEq(ids[2], type(IERC20Permit).interfaceId);
        assertEq(ids[3], type(IERC5267).interfaceId);
        assertEq(ids[4], type(IStandardExchangeIn).interfaceId);
        assertEq(ids[5], type(IStandardExchangeOut).interfaceId);
        assertEq(ids[6], type(IBasicVault).interfaceId);
        assertEq(ids[7], type(IStandardVault).interfaceId);
        assertEq(ids[8], type(IMultiStepOwnable).interfaceId);
        assertEq(ids[9], bytes4(keccak256("UniswapV4StandardExchangeOrbitalBufferHook")));
        assertEq(ids[10], type(IUniswapV4SeBufferHook).interfaceId);
        assertEq(ids[11], type(IDetfReserveQuote).interfaceId);
    }

    function test_facetAddresses_ten() public view {
        address[] memory facets = hookPkg.facetAddresses();
        assertEq(facets.length, 11);
        assertEq(facets[0], address(multiStepOwnableFacet));
        assertEq(facets[1], address(multiAssetBasicVaultFacet));
        assertEq(facets[2], address(multiAssetStandardVaultFacet));
        assertEq(facets[3], address(hookPkg));
        assertEq(facets[4], address(hookPkg.HOOKS_FACET()));
        assertEq(facets[5], address(hookPkg.DEPOSIT_FACET()));
        assertEq(facets[6], address(hookPkg.WITHDRAW_FACET()));
        assertEq(facets[7], address(hookPkg.SE_FACET()));
        assertEq(facets[8], address(erc20Facet));
        assertEq(facets[9], address(erc5267Facet));
        assertEq(facets[10], address(erc2612Facet));
    }

    function test_facetFuncs_isS58() public view {
        _assertSelectorsEq(IFacet(address(hookPkg)).facetFuncs(), _s58());
    }

    function test_facetName_isInitFacetType() public view {
        assertEq(
            IFacet(address(hookPkg)).facetName(),
            type(UniswapV4StandardExchangeOrbitalBufferHookInitFacet).name
        );
    }

    function test_packageName_unchanged() public view {
        assertEq(
            hookPkg.packageName(), type(UniswapV4StandardExchangeOrbitalBufferHookDFPkg).name
        );
    }

    function test_postDeploy_returnsTrue_noInit() public {
        assertTrue(hookPkg.postDeploy(address(0x1)));
    }

    function test_calcSalt_unchanged() public {
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        bytes32 s1 = hookPkg.calcSalt(hookPkg.processArgs(abi.encode(args)));
        args.tickSpacing = 120;
        args.sqrtPriceX96 = 1;
        bytes32 s2 = hookPkg.calcSalt(hookPkg.processArgs(abi.encode(args)));
        assertEq(s1, s2, "tick/sqrt excluded from salt");
        args.ownerOnlyLiquidity = !args.ownerOnlyLiquidity;
        bytes32 s3 = hookPkg.calcSalt(hookPkg.processArgs(abi.encode(args)));
        assertTrue(s1 != s3, "ownerOnlyLiquidity in salt");
    }

    function _s58() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](6);
        s[0] = IHooks.beforeInitialize.selector;
        s[1] = IUniswapV4HookStagedPairInit.deployPair.selector;
        s[2] = IUniswapV4HookStagedPairInit.finalizeInitialization.selector;
        s[3] = IUniswapV4HookStagedPairInit.isPairPoolLive.selector;
        s[4] = IUniswapV4HookStagedPairInit.pairPoolKey.selector;
        s[5] = IUniswapV4HookStagedPairInit.isInitializationFinalized.selector;
    }

    function _assertSelectorsEq(bytes4[] memory a, bytes4[] memory b) internal pure {
        assertEq(a.length, b.length, "selector count");
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i], "selector");
        }
    }
}

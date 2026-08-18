// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHookPackage
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookPackage.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookDFPkg
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookDFPkg.sol";
import {
    UniswapV4WeightedSwapHookInitFacet
} from "contracts/hooks/uniswap/v4/weighted/facets/UniswapV4WeightedSwapHookInitFacet.sol";
import {IUniswapV4WeightedSwapHook} from
    "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";

/**
 * @notice Package deploy / pair-door suite (replaces monomorph factory tests).
 */
contract UniswapV4WeightedSwapHook_Factory_Test is TestBase_UniswapV4WeightedSwapHook {
    /// @notice Doors come from `_ensureProductDoorsAndFinalize`, not `postDeploy`.
    function test_F1_deployCreatesAllDoors_n2() public {
        (address hook,,) = _deployN2();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 1); // binom(2,2)=1
        assertEq(keys[0].fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
        assertEq(keys[0].tickSpacing, 1);
        _assertPoolLive(keys[0]);
        assertTrue(_registry().isVault(hook));
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(
            loupe.facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector) != address(0)
        );
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
    }

    /// @notice Doors come from `_ensureProductDoorsAndFinalize`, not `postDeploy`.
    function test_F2_deployCreatesAllDoors_n3() public {
        (address hook,,,) = _deployN3();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 3); // binom(3,2)=3
        for (uint256 i; i < keys.length; ++i) {
            _assertPoolLive(keys[i]);
        }
        assertEq(
            IDiamondLoupe(hook).facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector),
            address(0)
        );
    }

    /// @notice Doors come from `_ensureProductDoorsAndFinalize`, not `postDeploy`.
    function test_F3_deployCreatesAllDoors_n4() public {
        (address hook,,,,) = _deployN4();
        PoolKey[] memory keys = _pairPoolKeys(hook);
        assertEq(keys.length, 6); // binom(4,2)=6
        for (uint256 i; i < keys.length; ++i) {
            _assertPoolLive(keys[i]);
        }
    }

    function test_F4_invalidMineNonceReverts() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 goodNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        uint256 bad = goodNonce + 1;
        for (uint256 i; i < 50; ++i) {
            // deploy with bad mineNonce should revert (flags mismatch)
            try this.externalDeploy(args, bad) {
                // if it accidentally matched flags, keep scanning
            } catch {
                return; // expected path
            }
            ++bad;
        }
    }

    function externalDeploy(IUniswapV4WeightedSwapHookPackage.PkgArgs memory args, uint256 mineNonce)
        external
        returns (address)
    {
        return PkgFactory.deployHook(hookPkg, args, mineNonce);
    }

    function test_F5_idempotentRedeploySameArgs() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h1 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        address h2 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(h1, h2);
    }

    function test_F6_postDeploy_returnsTrue_noInit() public {
        assertTrue(hookPkg.postDeploy(address(0x1)));
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
        address[] memory tokens = new address[](2);
        tokens[0] = address(t0);
        tokens[1] = address(t1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5e17;
        weights[1] = 5e17;
        address[] memory providers = new address[](2);
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(vaultFeeOracle),
            tokens: tokens,
            weights: weights,
            rateProviders: providers,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        address hook = _deployBootstrapOnly(args);
        assertTrue(hookPkg.postDeploy(hook));
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook);
        assertFalse(init.isPairPoolLive(tokens[0], tokens[1]));
        assertFalse(init.isInitializationFinalized());
    }

    function test_F7_flagsMatchRequired() public {
        (address hook,,) = _deployN2();
        uint160 flags = PkgFactory.requiredFlags();
        assertEq(uint160(hook) & flags, flags);
        assertTrue(hookPkg.isExpectedInstance(hook, ""));
    }

    function test_F8_computeKeysMatchLiveDoors() public {
        (address hook, MintableDec t0, MintableDec t1) = _deployN2();
        PoolKey[] memory keys = PairPoolLib.computePairKeys(
            IUniswapV4WeightedSwapHook(hook).tokens(), hook, int24(int256(Math.TICK_SPACING))
        );
        assertEq(keys.length, 1);
        assertEq(Currency.unwrap(keys[0].currency0), address(t0));
        assertEq(Currency.unwrap(keys[0].currency1), address(t1));
        _assertPoolLive(keys[0]);
    }

    function test_facetCuts_isBootstrapOnly() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.facetCuts();
        assertEq(cuts.length, 3);
        assertEq(cuts[0].facetAddress, address(multiAssetBasicVaultFacet));
        assertEq(cuts[1].facetAddress, address(multiAssetStandardVaultFacet));
        assertEq(cuts[2].facetAddress, address(hookPkg));
        assertEq(uint256(cuts[0].action), uint256(IDiamond.FacetCutAction.Add));
        assertEq(uint256(cuts[1].action), uint256(IDiamond.FacetCutAction.Add));
        assertEq(uint256(cuts[2].action), uint256(IDiamond.FacetCutAction.Add));
        _assertSelectorsEq(cuts[2].functionSelectors, _s58());
        _assertSelectorsEq(cuts[0].functionSelectors, multiAssetBasicVaultFacet.facetFuncs());
        _assertSelectorsEq(cuts[1].functionSelectors, multiAssetStandardVaultFacet.facetFuncs());
    }

    function test_productionFacetCuts_fiveAdds() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.productionFacetCuts();
        assertEq(cuts.length, 5);
        assertEq(cuts[0].facetAddress, address(hookPkg.HOOKS_FACET()));
        assertEq(cuts[1].facetAddress, address(hookPkg.LIQUIDITY_FACET()));
        assertEq(cuts[2].facetAddress, address(erc20Facet));
        assertEq(cuts[3].facetAddress, address(erc5267Facet));
        assertEq(cuts[4].facetAddress, address(erc2612Facet));
        _assertSelectorsEq(cuts[0].functionSelectors, hookPkg.HOOKS_FACET().facetFuncs());
        _assertSelectorsEq(cuts[1].functionSelectors, hookPkg.LIQUIDITY_FACET().facetFuncs());
        _assertSelectorsEq(cuts[2].functionSelectors, erc20Facet.facetFuncs());
        _assertSelectorsEq(cuts[3].functionSelectors, erc5267Facet.facetFuncs());
        _assertSelectorsEq(cuts[4].functionSelectors, erc2612Facet.facetFuncs());
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

    function test_facetInterfaces_sixProductionIds() public view {
        bytes4[] memory ids = hookPkg.facetInterfaces();
        assertEq(ids.length, 6);
        assertEq(ids[0], type(IERC20).interfaceId);
        assertEq(ids[1], type(IERC20Metadata).interfaceId);
        assertEq(ids[2], type(IERC20Permit).interfaceId);
        assertEq(ids[3], type(IERC5267).interfaceId);
        assertEq(ids[4], type(IBasicVault).interfaceId);
        assertEq(ids[5], type(IStandardVault).interfaceId);
    }

    function test_facetAddresses_eight() public view {
        address[] memory facets = hookPkg.facetAddresses();
        assertEq(facets.length, 8);
        assertEq(facets[0], address(multiAssetBasicVaultFacet));
        assertEq(facets[1], address(multiAssetStandardVaultFacet));
        assertEq(facets[2], address(hookPkg));
        assertEq(facets[3], address(hookPkg.HOOKS_FACET()));
        assertEq(facets[4], address(hookPkg.LIQUIDITY_FACET()));
        assertEq(facets[5], address(erc20Facet));
        assertEq(facets[6], address(erc5267Facet));
        assertEq(facets[7], address(erc2612Facet));
    }

    function test_facetFuncs_isS58() public view {
        _assertSelectorsEq(IFacet(address(hookPkg)).facetFuncs(), _s58());
    }

    function test_facetName_isInitFacetType() public view {
        assertEq(
            IFacet(address(hookPkg)).facetName(), type(UniswapV4WeightedSwapHookInitFacet).name
        );
    }

    function test_packageName_unchanged() public view {
        assertEq(hookPkg.packageName(), type(UniswapV4WeightedSwapHookDFPkg).name);
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


// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";
import {
    UniswapV4OrbitalSwapHookDFPkg
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookDFPkg.sol";
import {
    UniswapV4OrbitalSwapHookInitFacet
} from "contracts/hooks/uniswap/v4/orbital/facets/UniswapV4OrbitalSwapHookInitFacet.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

contract UniswapV4OrbitalSwapHook_Factory_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_F1_hookHasRequiredFlags() public view {
        uint160 flags = uint160(hook) & Hooks.ALL_HOOK_MASK;
        assertEq(flags, PkgFactory.requiredFlags());
        assertEq(flags, hookPkg.requiredHookFlags() & Hooks.ALL_HOOK_MASK);
        assertEq(IUniswapV4HookFlags(hook).requiredHookFlags() & Hooks.ALL_HOOK_MASK, flags);
    }

    /// @notice S42: gold setUp leaves three product doors live and production ABI cut.
    /// @dev Doors come from `_ensureProductDoorsAndFinalize`, not `postDeploy`.
    function test_F2_setUpLeavesThreeDoorsAndFinalized() public view {
        _assertThreeProductDoorsLive();
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertTrue(
            loupe.facetAddress(IUniswapV4OrbitalSwapHook.addLiquidity.selector) != address(0),
            "addLiquidity after S42"
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector),
            address(0),
            "init selector gone after finalize"
        );
        assertEq(poolKey01.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
    }

    function test_F3_isVaultRegistered() public view {
        IVaultRegistryVaultQuery reg = _registry();
        assertTrue(reg.isVault(hook));
        address[] memory vaults = reg.vaultsOfPackage(address(hookPkg));
        bool found;
        for (uint256 i; i < vaults.length; ++i) {
            if (vaults[i] == hook) found = true;
        }
        assertTrue(found, "vaultsOfPackage");
    }

    function test_F4_calcAddressMatchesDeploy() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 b = new SimpleMintableERC20("B", "B");
        SimpleMintableERC20 c = new SimpleMintableERC20("C", "C");
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(a),
            token1: address(b),
            token2: address(c),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(hookPkg)), abi.encode(args), mineNonce
        );
        address deployed = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(deployed, predicted);
    }

    function test_F5_idempotentSameArgsNonce() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("X", "X");
        SimpleMintableERC20 b = new SimpleMintableERC20("Y", "Y");
        SimpleMintableERC20 c = new SimpleMintableERC20("Z", "Z");
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(a),
            token1: address(b),
            token2: address(c),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h1 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        address h2 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(h1, h2);
    }

    function test_F6_saltIndependentOfPackageAddress() public {
        // Salt uses PRODUCT_ID + bindings only — package address excluded.
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        bytes32 s1 = hookPkg.calcSalt(processed);
        bytes32 expected = keccak256(
            abi.encode(
                hookPkg.PRODUCT_ID(),
                args.poolManager,
                args.feeOracle,
                args.token0,
                args.token1,
                args.token2
            )
        );
        assertEq(s1, expected);
        // tickSpacing / sqrtPrice not in salt: change process fields, salt stable
        args.tickSpacing = 120;
        args.sqrtPriceX96 = 1;
        bytes32 s2 = hookPkg.calcSalt(hookPkg.processArgs(abi.encode(args)));
        assertEq(s1, s2, "tick/sqrt excluded from salt");
    }

    function test_F7_noDiamondCutOnLiveInstance() public view {
        // PostDeploy removes temporary cut surface; diamondCut selector must not be present.
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        address facet = IDiamondLoupe(hook).facetAddress(cutSel);
        assertEq(facet, address(0), "live instance must not expose diamondCut");
    }

    function test_F8_isExpectedInstanceThin() public view {
        assertTrue(hookPkg.isExpectedInstance(hook, ""));
        assertFalse(hookPkg.isExpectedInstance(address(0xdead), ""));
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
        _assertSelectorsEq(cuts[2].functionSelectors, _s49());
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

    function test_facetFuncs_isS49() public view {
        _assertSelectorsEq(IFacet(address(hookPkg)).facetFuncs(), _s49());
    }

    function test_facetName_isInitFacetType() public view {
        assertEq(
            IFacet(address(hookPkg)).facetName(), type(UniswapV4OrbitalSwapHookInitFacet).name
        );
    }

    function test_packageName_unchanged() public view {
        assertEq(hookPkg.packageName(), type(UniswapV4OrbitalSwapHookDFPkg).name);
    }

    function test_postDeploy_returnsTrue_noInit() public {
        assertTrue(hookPkg.postDeploy(address(0x1)));
    }

    function test_calcSalt_unchanged() public {
        test_F6_saltIndependentOfPackageAddress();
    }

    function _s49() internal pure returns (bytes4[] memory s) {
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

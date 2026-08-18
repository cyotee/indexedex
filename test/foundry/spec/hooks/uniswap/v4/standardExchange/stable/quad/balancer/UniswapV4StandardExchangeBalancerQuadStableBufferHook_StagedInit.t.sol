// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookInitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/facets/UniswapV4StandardExchangeBalancerQuadStableBufferHookInitFacet.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHook_StagedInit_Test
 * @notice S58 package-as-init surface, S43 bootstrap-only deploy, six-door finalize matrix.
 */
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_StagedInit_Test is
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook
{
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant PAIR_POOL_DEPLOYED_TOPIC =
        keccak256("PairPoolDeployed(address,address,address,bytes32)");

    function test_S58_facetFuncs() public view {
        bytes4[] memory funcs = IFacet(address(hookPkg)).facetFuncs();
        assertEq(funcs.length, 6);
        assertEq(funcs[0], IHooks.beforeInitialize.selector);
        assertEq(funcs[1], IUniswapV4HookStagedPairInit.deployPair.selector);
        assertEq(funcs[2], IUniswapV4HookStagedPairInit.finalizeInitialization.selector);
        assertEq(funcs[3], IUniswapV4HookStagedPairInit.isPairPoolLive.selector);
        assertEq(funcs[4], IUniswapV4HookStagedPairInit.pairPoolKey.selector);
        assertEq(funcs[5], IUniswapV4HookStagedPairInit.isInitializationFinalized.selector);
        assertEq(
            IFacet(address(hookPkg)).facetName(),
            type(UniswapV4StandardExchangeBalancerQuadStableBufferHookInitFacet).name
        );
    }

    function test_facetCuts_isBootstrapOnly() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.facetCuts();
        assertEq(cuts.length, 3);
        assertEq(cuts[0].facetAddress, address(multiAssetBasicVaultFacet));
        assertEq(cuts[1].facetAddress, address(multiAssetStandardVaultFacet));
        assertEq(cuts[2].facetAddress, address(hookPkg));
        assertEq(uint8(cuts[0].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(uint8(cuts[1].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(uint8(cuts[2].action), uint8(IDiamond.FacetCutAction.Add));
        bytes4[] memory initFuncs = IFacet(address(hookPkg)).facetFuncs();
        assertEq(cuts[2].functionSelectors.length, initFuncs.length);
        for (uint256 i; i < initFuncs.length; ++i) {
            assertEq(cuts[2].functionSelectors[i], initFuncs[i]);
        }
    }

    function test_productionFacetCuts_sixAdds() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.productionFacetCuts();
        assertEq(cuts.length, 6);
        assertEq(cuts[0].facetAddress, address(hookPkg.HOOKS_FACET()));
        assertEq(cuts[1].facetAddress, address(hookPkg.LIQUIDITY_FACET()));
        assertEq(cuts[2].facetAddress, address(hookPkg.SE_FACET()));
        assertEq(cuts[3].facetAddress, address(erc20Facet));
        assertEq(cuts[4].facetAddress, address(erc5267Facet));
        assertEq(cuts[5].facetAddress, address(erc2612Facet));
        _assertSelectorsEq(cuts[0].functionSelectors, hookPkg.HOOKS_FACET().facetFuncs());
        _assertSelectorsEq(cuts[1].functionSelectors, hookPkg.LIQUIDITY_FACET().facetFuncs());
        _assertSelectorsEq(cuts[2].functionSelectors, hookPkg.SE_FACET().facetFuncs());
        _assertSelectorsEq(cuts[3].functionSelectors, erc20Facet.facetFuncs());
        _assertSelectorsEq(cuts[4].functionSelectors, erc5267Facet.facetFuncs());
        _assertSelectorsEq(cuts[5].functionSelectors, erc2612Facet.facetFuncs());
        for (uint256 i; i < 6; ++i) {
            assertEq(uint8(cuts[i].action), uint8(IDiamond.FacetCutAction.Add));
        }
    }

    function test_facetCuts_ne_productionFacetCuts() public view {
        IDiamond.FacetCut[] memory boot = hookPkg.facetCuts();
        IDiamond.FacetCut[] memory prod = hookPkg.productionFacetCuts();
        assertTrue(boot.length != prod.length);
    }

    function test_facetInterfaces_tenProductionIds() public view {
        bytes4[] memory ids = hookPkg.facetInterfaces();
        assertEq(ids.length, 10);
        assertEq(ids[0], type(IERC20).interfaceId);
        assertEq(ids[1], type(IERC20Metadata).interfaceId);
        assertEq(ids[2], type(IERC20Permit).interfaceId);
        assertEq(ids[3], type(IERC5267).interfaceId);
    }

    function test_S43_deployAlone_noProductDoors() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        assertFalse(init.isPairPoolLive(toks[0], toks[2]));
        assertFalse(init.isPairPoolLive(toks[0], toks[3]));
        assertFalse(init.isPairPoolLive(toks[1], toks[2]));
        assertFalse(init.isPairPoolLive(toks[1], toks[3]));
        assertFalse(init.isPairPoolLive(toks[2], toks[3]));
        assertFalse(init.isInitializationFinalized());
        assertTrue(h != address(0));
    }

    function test_S43_deployAlone_vaultConfigWorks() public {
        (address h,,) = _freshBootstrap();
        IStandardVault(h).vaultConfig();
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(h));
    }

    function test_S43_deployAlone_initSelectorsExist() public {
        (address h,,) = _freshBootstrap();
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(hookPkg)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(hookPkg)
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isPairPoolLive.selector), address(hookPkg)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.pairPoolKey.selector), address(hookPkg)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector),
            address(hookPkg)
        );
    }

    function test_S43_deployAlone_productionSelectorsUnmatched() public {
        (address h,,) = _freshBootstrap();
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(
            loupe.facetAddress(
                IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinProportional.selector
            ),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.token.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
        assertEq(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,) = _freshBootstrap();
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        PoolKey memory expected =
            PairPoolLib.pairKey(toks[0], toks[1], PairPoolLib.TICK_SPACING, IHooks(h));
        PoolKey memory actual = init.pairPoolKey(toks[0], toks[1]);
        _assertKeyEq(actual, expected);
        _assertKeyEq(init.pairPoolKey(toks[1], toks[0]), actual);
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        assertEq(actual.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
        assertEq(actual.tickSpacing, PairPoolLib.TICK_SPACING);
    }

    function test_deployPair_emitsOnce() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        (address c0, address c1) = toks[0] < toks[1] ? (toks[0], toks[1]) : (toks[1], toks[0]);
        PoolKey memory key = init.pairPoolKey(toks[0], toks[1]);
        bytes32 poolId = PoolId.unwrap(key.toId());
        vm.expectEmit(true, true, true, true, h);
        emit IUniswapV4HookStagedPairInit.PairPoolDeployed(h, c0, c1, poolId);
        PoolKey memory returned = init.deployPair(toks[0], toks[1]);
        _assertKeyEq(returned, key);
        assertTrue(init.isPairPoolLive(toks[0], toks[1]));
    }

    function test_deployPair_skipIfLive_noEvent() public {
        (, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        PoolKey memory first = init.deployPair(toks[0], toks[1]);
        vm.recordLogs();
        PoolKey memory second = init.deployPair(toks[1], toks[0]);
        _assertKeyEq(first, second);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
    }

    function test_deployPair_rejectsNonProductPair() public {
        (, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        address stranger = address(new SimpleMintableERC20("X", "X"));
        vm.expectRevert(UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPair.selector);
        init.deployPair(toks[0], stranger);
        vm.expectRevert(UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.InvalidPair.selector);
        init.deployPair(toks[0], toks[0]);
    }

    function test_finalize_revertsMissingDoors_zeroAndFive() public {
        (, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();

        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        // missing (t2, t3)
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_finalize_success_removesInit_addsProduction() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        _openSixDoors(init, toks);
        IDiamond.FacetCut[] memory cuts = _expectedFinalizeCuts();
        vm.expectEmit(false, false, false, true, h);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        vm.expectEmit(true, false, false, true, h);
        emit IUniswapV4HookStagedPairInit.InitializationFinalized(h);
        assertTrue(init.finalizeInitialization());

        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(
                IUniswapV4StandardExchangeBalancerQuadStableBufferHook.joinProportional.selector
            ),
            address(hookPkg.LIQUIDITY_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeBalancerQuadStableBufferHook.token.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
        assertEq(
            loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(hookPkg.SE_FACET())
        );
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
        assertEq(loupe.facetAddress(IBasicVault.vaultTokens.selector), address(multiAssetBasicVaultFacet));
    }

    function test_finalize_secondCallUnmatched() public {
        (, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        _openSixDoors(init, toks);
        assertTrue(init.finalizeInitialization());
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector, IUniswapV4HookStagedPairInit.finalizeInitialization.selector
            )
        );
        init.finalizeInitialization();
    }

    function test_finalize_extraFeeOrTickDoesNotCount() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        (address c0, address c1) = toks[0] < toks[1] ? (toks[0], toks[1]) : (toks[1], toks[0]);

        PoolKey memory extraFeeThis = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 3000,
            tickSpacing: PairPoolLib.TICK_SPACING,
            hooks: IHooks(h)
        });
        vm.expectRevert();
        pm.initialize(extraFeeThis, TickMath.getSqrtPriceAtTick(0));

        PoolKey memory extraTickThis = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(h)
        });
        vm.expectRevert();
        pm.initialize(extraTickThis, TickMath.getSqrtPriceAtTick(0));

        PoolKey memory extra = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        pm.initialize(extra, TickMath.getSqrtPriceAtTick(0));
        assertTrue(PairPoolLib.isPoolLive(pm, extra));
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_permissionless_strangerMayDoorAndFinalize() public {
        (, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        address stranger = address(0x5110);
        vm.startPrank(stranger);
        _openSixDoors(init, toks);
        assertTrue(init.finalizeInitialization());
        vm.stopPrank();
    }

    function test_postDeploy_returnsTrue_noInit() public {
        assertTrue(hookPkg.postDeploy(address(0x1)));
    }

    function test_firstDeployerWins_unfinalized() public {
        (address[4] memory toks, address se) = _fourNewTokensAndSe();
        address[4] memory ses;
        ses[0] = se;
        address[4] memory rps;
        IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.PkgArgs memory args =
            _pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP);
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function _freshBootstrap()
        internal
        returns (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks)
    {
        address se;
        (toks, se) = _fourNewTokensAndSe();
        address[4] memory ses;
        ses[0] = se;
        address[4] memory rps;
        h = _deployBootstrapOnly(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
        init = IUniswapV4HookStagedPairInit(h);
    }

    function _fourNewTokensAndSe() internal returns (address[4] memory toks, address se) {
        SimpleMintableERC20[4] memory raw;
        raw[0] = new SimpleMintableERC20("A", "A");
        raw[1] = new SimpleMintableERC20("B", "B");
        raw[2] = new SimpleMintableERC20("C", "C");
        raw[3] = new SimpleMintableERC20("D", "D");
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (address(raw[j]) < address(raw[i])) {
                    (raw[i], raw[j]) = (raw[j], raw[i]);
                }
            }
        }
        toks[0] = address(raw[0]);
        toks[1] = address(raw[1]);
        toks[2] = address(raw[2]);
        toks[3] = address(raw[3]);
        SimpleYieldERC4626 v = new SimpleYieldERC4626(raw[0]);
        se = _deployERC4626SE(address(v));
    }

    function _openSixDoors(IUniswapV4HookStagedPairInit init, address[4] memory toks) internal {
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
    }

    function _expectedFinalizeCuts() internal view returns (IDiamond.FacetCut[] memory cuts) {
        IDiamond.FacetCut[] memory adds = hookPkg.productionFacetCuts();
        cuts = new IDiamond.FacetCut[](7);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(hookPkg),
            action: IDiamond.FacetCutAction.Remove,
            functionSelectors: IFacet(address(hookPkg)).facetFuncs()
        });
        cuts[1] = adds[0];
        cuts[2] = adds[1];
        cuts[3] = adds[2];
        cuts[4] = adds[3];
        cuts[5] = adds[4];
        cuts[6] = adds[5];
    }

    function _assertKeyEq(PoolKey memory a, PoolKey memory b) internal pure {
        assertEq(Currency.unwrap(a.currency0), Currency.unwrap(b.currency0));
        assertEq(Currency.unwrap(a.currency1), Currency.unwrap(b.currency1));
        assertEq(a.fee, b.fee);
        assertEq(a.tickSpacing, b.tickSpacing);
        assertEq(address(a.hooks), address(b.hooks));
    }

    function _assertSelectorsEq(bytes4[] memory a, bytes4[] memory b) internal pure {
        assertEq(a.length, b.length);
        for (uint256 i; i < a.length; ++i) {
            assertEq(a[i], b[i]);
        }
    }
}

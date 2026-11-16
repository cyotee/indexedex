// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_UniswapV4CurveQuadStableSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/stable/quad/curve/TestBase_UniswapV4CurveQuadStableSwapHook.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4CurveQuadStableSwapHookPackage
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHookPackage.sol";
import {
    UniswapV4CurveQuadStableSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookPairPoolLib.sol";
import {
    UniswapV4CurveQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookMath.sol";
import {
    UniswapV4CurveQuadStableSwapHookInitFacet
} from "contracts/hooks/uniswap/v4/stable/quad/curve/facets/UniswapV4CurveQuadStableSwapHookInitFacet.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHook_StagedInit_Test
 * @notice S58 package-as-init surface, S43 bootstrap-only deploy, six-door finalize matrix.
 */
contract UniswapV4CurveQuadStableSwapHook_StagedInit_Test is TestBase_UniswapV4CurveQuadStableSwapHook {
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
            type(UniswapV4CurveQuadStableSwapHookInitFacet).name
        );
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
        assertTrue(_registry().isVault(h));
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
        assertEq(loupe.facetAddress(IUniswapV4CurveQuadStableSwapHook.addLiquidity.selector), address(0));
        assertEq(loupe.facetAddress(IUniswapV4CurveQuadStableSwapHook.token0.selector), address(0));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,) = _freshBootstrap();
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks) = _freshBootstrap();
        PoolKey memory expected = PairPoolLib.pairKey(h, toks[0], toks[1], DEMO_FEE);
        PoolKey memory actual = init.pairPoolKey(toks[0], toks[1]);
        _assertKeyEq(actual, expected);
        _assertKeyEq(init.pairPoolKey(toks[1], toks[0]), actual);
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        assertEq(actual.fee, DEMO_FEE);
        assertEq(actual.tickSpacing, int24(int256(Math.TICK_SPACING)));
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
            loupe.facetAddress(IUniswapV4CurveQuadStableSwapHook.addLiquidity.selector),
            address(hookPkg.LIQUIDITY_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4CurveQuadStableSwapHook.token0.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
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
            tickSpacing: int24(int256(Math.TICK_SPACING)),
            hooks: IHooks(h)
        });
        vm.expectRevert();
        pm.initialize(extraFeeThis, TickMath.getSqrtPriceAtTick(0));

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
        address[4] memory toks = _fourNewTokens();
        address[4] memory providers;
        IUniswapV4CurveQuadStableSwapHookPackage.PkgArgs memory args =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers);
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function _freshBootstrap()
        internal
        returns (address h, IUniswapV4HookStagedPairInit init, address[4] memory toks)
    {
        toks = _fourNewTokens();
        address[4] memory providers;
        h = _deployBootstrapOnly(
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers)
        );
        init = IUniswapV4HookStagedPairInit(h);
    }

    function _fourNewTokens() internal returns (address[4] memory toks) {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        toks[0] = address(x0);
        toks[1] = address(x1);
        toks[2] = address(x2);
        toks[3] = address(x3);
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
        cuts = new IDiamond.FacetCut[](6);
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
    }

    function _assertKeyEq(PoolKey memory a, PoolKey memory b) internal pure {
        assertEq(Currency.unwrap(a.currency0), Currency.unwrap(b.currency0));
        assertEq(Currency.unwrap(a.currency1), Currency.unwrap(b.currency1));
        assertEq(a.fee, b.fee);
        assertEq(a.tickSpacing, b.tickSpacing);
        assertEq(address(a.hooks), address(b.hooks));
    }
}

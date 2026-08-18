// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    UniswapV4OrbitalSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookPairPoolLib.sol";
import {
    UniswapV4OrbitalSwapHookTarget
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookTarget.sol";

/**
 * @title UniswapV4OrbitalSwapHook_StagedInit_Test
 * @notice S43 bootstrap-only deploy plus door / finalize matrix.
 */
contract UniswapV4OrbitalSwapHook_StagedInit_Test is TestBase_UniswapV4OrbitalSwapHook {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant PAIR_POOL_DEPLOYED_TOPIC =
        keccak256("PairPoolDeployed(address,address,address,bytes32)");

    function test_S43_deployAlone_noProductDoors() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        assertFalse(init.isPairPoolLive(t0, t1));
        assertFalse(init.isPairPoolLive(t1, t2));
        assertFalse(init.isPairPoolLive(t0, t2));
        assertFalse(init.isInitializationFinalized());
        assertTrue(h != address(0));
    }

    function test_S43_deployAlone_vaultConfigWorks() public {
        (address h,,,,) = _freshBootstrap();
        IStandardVault(h).vaultConfig();
        assertTrue(_registry().isVault(h));
    }

    function test_S43_deployAlone_initSelectorsExist() public {
        (address h,,,,) = _freshBootstrap();
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(hookPkg)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(hookPkg)
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg));
    }

    function test_S43_deployAlone_productionSelectorsUnmatched() public {
        (address h,,,,) = _freshBootstrap();
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IUniswapV4OrbitalSwapHook.addLiquidity.selector), address(0));
        assertEq(loupe.facetAddress(IUniswapV4OrbitalSwapHook.token0.selector), address(0));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,,,) = _freshBootstrap();
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        PoolKey memory expected = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        PoolKey memory actual = init.pairPoolKey(t0, t1);
        _assertKeyEq(actual, expected);
        _assertKeyEq(init.pairPoolKey(t1, t0), actual);
        assertFalse(init.isPairPoolLive(t0, t1));
    }

    function test_deployPair_emitsOnce() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        (address c0, address c1) = t0 < t1 ? (t0, t1) : (t1, t0);
        PoolKey memory key = init.pairPoolKey(t0, t1);
        bytes32 poolId = PoolId.unwrap(key.toId());
        vm.expectEmit(true, true, true, true, h);
        emit IUniswapV4HookStagedPairInit.PairPoolDeployed(h, c0, c1, poolId);
        PoolKey memory returned = init.deployPair(t0, t1);
        _assertKeyEq(returned, key);
        assertTrue(init.isPairPoolLive(t0, t1));
    }

    function test_deployPair_skipIfLive_noEvent() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        PoolKey memory first = init.deployPair(t0, t1);
        vm.recordLogs();
        PoolKey memory second = init.deployPair(t1, t0);
        _assertKeyEq(first, second);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
    }

    function test_deployPair_orderIndependent() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) = _freshBootstrap();
        init.deployPair(t0, t2);
        init.deployPair(t1, t2);
        init.deployPair(t0, t1);
        assertTrue(init.isPairPoolLive(t0, t1));
        assertTrue(init.isPairPoolLive(t1, t2));
        assertTrue(init.isPairPoolLive(t0, t2));
    }

    function test_deployPair_invalidPairReverts() public {
        (, IUniswapV4HookStagedPairInit init, address t0,,) = _freshBootstrap();
        vm.expectRevert(UniswapV4OrbitalSwapHookTarget.InvalidPoolToken.selector);
        init.deployPair(t0, t0);
        vm.expectRevert(UniswapV4OrbitalSwapHookTarget.InvalidPoolToken.selector);
        init.deployPair(t0, address(0xB0B0));
        vm.expectRevert(UniswapV4OrbitalSwapHookTarget.InvalidPoolToken.selector);
        init.deployPair(address(0), t0);
    }

    function test_finalize_revertsMissingDoors() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) = _freshBootstrap();
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();

        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_finalize_success_returnsTrue() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);

        IDiamond.FacetCut[] memory cuts = _expectedFinalizeCuts();
        vm.expectEmit(false, false, false, true, h);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        vm.expectEmit(true, false, false, true, h);
        emit IUniswapV4HookStagedPairInit.InitializationFinalized(h);
        bool ok = init.finalizeInitialization();
        assertTrue(ok);
    }

    function test_finalize_removesInit_addsProduction() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
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
            loupe.facetAddress(IUniswapV4OrbitalSwapHook.addLiquidity.selector),
            address(hookPkg.LIQUIDITY_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4OrbitalSwapHook.token0.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
        assertEq(loupe.facetAddress(IBasicVault.vaultTokens.selector), address(multiAssetBasicVaultFacet));
    }

    function test_finalize_secondCallUnmatchedOrAlreadyFinalized() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        assertTrue(init.finalizeInitialization());
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector, IUniswapV4HookStagedPairInit.finalizeInitialization.selector
            )
        );
        init.finalizeInitialization();
        assertEq(
            IDiamondLoupe(h).facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(0)
        );
    }

    function test_finalize_rawInitializeCounts() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        PoolKey memory k01 = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        PoolKey memory k12 = PairPoolLib.pairKey(t1, t2, 60, IHooks(h));
        PoolKey memory k02 = PairPoolLib.pairKey(t0, t2, 60, IHooks(h));
        vm.recordLogs();
        pm.initialize(k01, price);
        pm.initialize(k12, price);
        pm.initialize(k02, price);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
        assertTrue(init.finalizeInitialization());
    }

    function test_finalize_extraTickSpacingDoesNotCount() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        PoolKey memory extra = PairPoolLib.pairKey(t0, t1, 120, IHooks(h));
        pm.initialize(extra, TickMath.getSqrtPriceAtTick(0));
        assertFalse(init.isPairPoolLive(t0, t1));
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_permissionless_strangerMayDoorAndFinalize() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) = _freshBootstrap();
        address stranger = address(0x5110);
        vm.startPrank(stranger);
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        assertTrue(init.finalizeInitialization());
        vm.stopPrank();
    }

    function test_noDiamondCutSelector_beforeAndAfter() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) =
            _freshBootstrap();
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        assertTrue(init.finalizeInitialization());
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
        assertEq(IDiamondLoupe(hook).facetAddress(cutSel), address(0));
    }

    function test_firstDeployerWins_unfinalized() public {
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
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function _freshBootstrap()
        internal
        returns (
            address h,
            IUniswapV4HookStagedPairInit init,
            address t0,
            address t1,
            address t2
        )
    {
        SimpleMintableERC20 a = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 b = new SimpleMintableERC20("B", "B");
        SimpleMintableERC20 c = new SimpleMintableERC20("C", "C");
        t0 = address(a);
        t1 = address(b);
        t2 = address(c);
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: t0,
            token1: t1,
            token2: t2,
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        h = _deployBootstrapOnly(args);
        init = IUniswapV4HookStagedPairInit(h);
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

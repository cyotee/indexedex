// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {CustomRevert} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/CustomRevert.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";

contract _SeOrbitalModifyLiqUnlock is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function go(PoolKey memory key) external {
        pm.unlock(abi.encode(key));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        PoolKey memory key = abi.decode(data, (PoolKey));
        pm.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: 0}),
            ""
        );
        return "";
    }
}

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHook_StagedInit_Test
 * @notice S43 bootstrap-only deploy plus door / finalize / J-surface matrix.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_StagedInit_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
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
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeOrbitalBufferHook.token0.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
        assertEq(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
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
        vm.expectRevert(UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolToken.selector);
        init.deployPair(t0, t0);
        vm.expectRevert(UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolToken.selector);
        init.deployPair(t0, address(0xB0B0));
        vm.expectRevert(UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolToken.selector);
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
            loupe.facetAddress(IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector),
            address(hookPkg.DEPOSIT_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeOrbitalBufferHook.token0.selector),
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
        SimpleMintableERC20 a = new SimpleMintableERC20("A2", "A2");
        SimpleMintableERC20 b = new SimpleMintableERC20("B2", "B2");
        SimpleMintableERC20 c = new SimpleMintableERC20("C2", "C2");
        SimpleYieldERC4626 v = new SimpleYieldERC4626(a);
        address se = _deployERC4626SE(address(v));
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(a),
            token1: address(b),
            token2: address(c),
            se0: se,
            se1: address(0),
            se2: address(0),
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        address first = _deployBootstrapOnly(args);
        address second = _deployBootstrapOnly(args);
        assertEq(first, second);
        assertFalse(IUniswapV4HookStagedPairInit(first).isInitializationFinalized());
    }

    function test_J_swapBeforeFinalize_unmatched() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeSwap.selector), address(0));
        PoolKey memory key = init.deployPair(t0, t1);
        SimpleMintableERC20(t0).mint(user, 10 ether);
        SimpleMintableERC20(t1).mint(user, 10 ether);
        vm.startPrank(user);
        SimpleMintableERC20(t0).approve(address(swapRouter), type(uint256).max);
        SimpleMintableERC20(t1).approve(address(swapRouter), type(uint256).max);
        bool zeroForOne = t0 == Currency.unwrap(key.currency0);
        vm.expectRevert();
        swapRouter.swapExactIn(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(1 ether),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            ""
        );
        vm.stopPrank();
    }

    function test_J_addLiquidityBeforeFinalize_unmatched() public {
        (address h,,,,) = _freshBootstrap();
        assertEq(
            IDiamondLoupe(h).facetAddress(
                IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector
            ),
            address(0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector,
                IUniswapV4StandardExchangeOrbitalBufferHook.addLiquidity.selector
            )
        );
        IUniswapV4StandardExchangeOrbitalBufferHook(h).addLiquidity(
            1, 1, 1, user, 0, block.timestamp + 1, ""
        );
    }

    function test_J_seBeforeFinalize_unmatched() public {
        (address h,,,,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector
            )
        );
        IStandardExchangeIn(h).exchangeIn(
            IERC20(address(token0)), 1, IERC20(address(token1)), 0, user, false, block.timestamp + 1
        );
    }

    function test_J_modifyLiquidityBeforeFinalize() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeAddLiquidity.selector), address(0));
        PoolKey memory key = init.deployPair(t0, t1);
        _SeOrbitalModifyLiqUnlock caller = new _SeOrbitalModifyLiqUnlock(pm);
        bytes memory hookReason =
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IHooks.beforeAddLiquidity.selector);
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                h,
                IHooks.beforeAddLiquidity.selector,
                hookReason,
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        caller.go(key);
    }

    function test_J_afterFinalize_noInitSelectors() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.finalizeInitialization.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.isPairPoolLive.selector), address(0));
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.pairPoolKey.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
    }

    function test_J_afterFinalize_noDiamondCut() public view {
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(hook).facetAddress(cutSel), address(0));
    }

    function test_beforeInitialize_sameChecks_afterFinalize() public {
        PoolKey memory badFee = poolKey01;
        badFee.fee = 3000;
        vm.prank(address(pm));
        vm.expectRevert(UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolFee.selector);
        IHooks(hook).beforeInitialize(address(this), badFee, TickMath.getSqrtPriceAtTick(0));

        PoolKey memory unbound =
            PairPoolLib.pairKey(address(token0), address(0xB0B0), 60, IHooks(hook));
        vm.prank(address(pm));
        vm.expectRevert(UniswapV4StandardExchangeOrbitalBufferHookCommon.InvalidPoolToken.selector);
        IHooks(hook).beforeInitialize(address(this), unbound, TickMath.getSqrtPriceAtTick(0));
    }

    function test_permissionlessFinalizeRace() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1, address t2) = _freshBootstrap();
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        address a1 = address(0xA11CE);
        address a2 = address(0xA22CE);
        vm.prank(a1);
        assertTrue(init.finalizeInitialization());
        vm.prank(a2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector,
                IUniswapV4HookStagedPairInit.finalizeInitialization.selector
            )
        );
        init.finalizeInitialization();
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
        SimpleYieldERC4626 vaultA = new SimpleYieldERC4626(a);
        address seA = _deployERC4626SE(address(vaultA));
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory args =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: t0,
            token1: t1,
            token2: t2,
            se0: seA,
            se1: address(0),
            se2: address(0),
            rp0: address(0),
            rp1: address(0),
            rp2: address(0),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        h = _deployBootstrapOnly(args);
        init = IUniswapV4HookStagedPairInit(h);
    }

    function _expectedFinalizeCuts() internal view returns (IDiamond.FacetCut[] memory cuts) {
        IDiamond.FacetCut[] memory adds = hookPkg.productionFacetCuts();
        cuts = new IDiamond.FacetCut[](8);
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
        cuts[7] = adds[6];
    }

    function _assertKeyEq(PoolKey memory a, PoolKey memory b) internal pure {
        assertEq(Currency.unwrap(a.currency0), Currency.unwrap(b.currency0));
        assertEq(Currency.unwrap(a.currency1), Currency.unwrap(b.currency1));
        assertEq(a.fee, b.fee);
        assertEq(a.tickSpacing, b.tickSpacing);
        assertEq(address(a.hooks), address(b.hooks));
    }
}

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
    TestBase_UniswapV4WeightedSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/weighted/TestBase_UniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4WeightedSwapHookPackage
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookPackage.sol";
import {
    UniswapV4WeightedSwapHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookPairPoolLib.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    UniswapV4WeightedSwapHookCommon
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";

/**
 * @title UniswapV4WeightedSwapHook_StagedInit_Test
 * @notice S43 bootstrap-only deploy plus door / finalize matrix (n=2 and n>=3).
 */
contract UniswapV4WeightedSwapHook_StagedInit_Test is TestBase_UniswapV4WeightedSwapHook {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant PAIR_POOL_DEPLOYED_TOPIC =
        keccak256("PairPoolDeployed(address,address,address,bytes32)");

    function test_S43_deployAlone_noProductDoors() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        assertFalse(init.isInitializationFinalized());
        assertTrue(h != address(0));
    }

    function test_S43_deployAlone_vaultConfigWorks() public {
        (address h,,) = _freshBootstrapN(2);
        IStandardVault(h).vaultConfig();
        assertTrue(_registry().isVault(h));
    }

    function test_S43_deployAlone_initSelectorsExist() public {
        (address h,,) = _freshBootstrapN(2);
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
        (address h,,) = _freshBootstrapN(2);
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector), address(0));
        assertEq(loupe.facetAddress(IUniswapV4WeightedSwapHook.tokens.selector), address(0));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,) = _freshBootstrapN(2);
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        PoolKey memory expected = PairPoolLib.pairKey(
            toks[0], toks[1], int24(int256(Math.TICK_SPACING)), IHooks(h)
        );
        PoolKey memory actual = init.pairPoolKey(toks[0], toks[1]);
        _assertKeyEq(actual, expected);
        _assertKeyEq(init.pairPoolKey(toks[1], toks[0]), actual);
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
    }

    function test_deployPair_emitsOnce() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
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
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        PoolKey memory first = init.deployPair(toks[0], toks[1]);
        vm.recordLogs();
        PoolKey memory second = init.deployPair(toks[1], toks[0]);
        _assertKeyEq(first, second);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
    }

    function test_deployPair_orderIndependent() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(3);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[0], toks[1]);
        assertTrue(init.isPairPoolLive(toks[0], toks[1]));
        assertTrue(init.isPairPoolLive(toks[1], toks[2]));
        assertTrue(init.isPairPoolLive(toks[0], toks[2]));
    }

    function test_deployPair_reverseArgs_sameDoor() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        PoolKey memory ab = init.deployPair(toks[0], toks[1]);
        PoolKey memory ba = init.pairPoolKey(toks[1], toks[0]);
        _assertKeyEq(ab, ba);
        assertTrue(init.isPairPoolLive(toks[1], toks[0]));
    }

    function test_deployPair_unboundOrSameTokenReverts() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        vm.expectRevert(UniswapV4WeightedSwapHookCommon.InvalidPair.selector);
        init.deployPair(toks[0], toks[0]);
        vm.expectRevert(UniswapV4WeightedSwapHookCommon.InvalidPair.selector);
        init.deployPair(toks[0], address(0xB0B0));
        vm.expectRevert(UniswapV4WeightedSwapHookCommon.InvalidPair.selector);
        init.deployPair(address(0), toks[0]);
    }

    function test_finalize_revertsMissingOneOfCn2() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(3);
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();

        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[1], toks[2]);
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_n2_onePair_finalize() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        init.deployPair(toks[0], toks[1]);
        IDiamond.FacetCut[] memory cuts = _expectedFinalizeCuts();
        vm.expectEmit(false, false, false, true, h);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        vm.expectEmit(true, false, false, true, h);
        emit IUniswapV4HookStagedPairInit.InitializationFinalized(h);
        assertTrue(init.finalizeInitialization());
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector),
            address(hookPkg.LIQUIDITY_FACET())
        );
    }

    function test_n3_threePairs_finalize() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(3);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[0], toks[2]);
        assertTrue(init.finalizeInitialization());
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
        assertEq(
            loupe.facetAddress(IUniswapV4WeightedSwapHook.tokens.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
        assertEq(loupe.facetAddress(IBasicVault.vaultTokens.selector), address(multiAssetBasicVaultFacet));
    }

    function test_finalize_removesInit_addsProduction() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        init.deployPair(toks[0], toks[1]);
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
            loupe.facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector),
            address(hookPkg.LIQUIDITY_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4WeightedSwapHook.tokens.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
    }

    function test_finalize_secondCallUnmatchedOrAlreadyFinalized() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        init.deployPair(toks[0], toks[1]);
        assertTrue(init.finalizeInitialization());
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector, IUniswapV4HookStagedPairInit.finalizeInitialization.selector
            )
        );
        init.finalizeInitialization();
    }

    function test_finalize_rawInitializeCounts() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        PoolKey memory key = PairPoolLib.pairKey(
            toks[0], toks[1], int24(int256(Math.TICK_SPACING)), IHooks(h)
        );
        vm.recordLogs();
        pm.initialize(key, price);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
        assertTrue(init.finalizeInitialization());
    }

    function test_finalize_extraTickSpacingDoesNotCount() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        // Extra spacing + this hook is rejected by today's beforeInitialize (tickSpacing must be 1).
        // PoolManager wraps the hook's InvalidPoolKey in WrappedError.
        PoolKey memory extraThis = PairPoolLib.pairKey(toks[0], toks[1], 60, IHooks(h));
        vm.expectRevert();
        pm.initialize(extraThis, TickMath.getSqrtPriceAtTick(0));

        // A live PoolManager pool on the same tokens at another spacing is not the product door.
        // address(0) hooks require a static fee (DYNAMIC_FEE is invalid without a hook).
        (address c0, address c1) = toks[0] < toks[1] ? (toks[0], toks[1]) : (toks[1], toks[0]);
        PoolKey memory extra = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        pm.initialize(extra, TickMath.getSqrtPriceAtTick(0));
        assertFalse(init.isPairPoolLive(toks[0], toks[1]));
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_permissionless_strangerMayDoorAndFinalize() public {
        (, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        address stranger = address(0x5110);
        vm.startPrank(stranger);
        init.deployPair(toks[0], toks[1]);
        assertTrue(init.finalizeInitialization());
        vm.stopPrank();
    }

    function test_noDiamondCutSelector_beforeAndAfter() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
        init.deployPair(toks[0], toks[1]);
        assertTrue(init.finalizeInitialization());
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
    }

    function test_firstDeployerWins_unfinalized() public {
        (IUniswapV4WeightedSwapHookPackage.PkgArgs memory args,) = _nArgs(2);
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function test_J_swapBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeSwap.selector), address(0));
    }

    function test_J_addLiquidityBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(
            IDiamondLoupe(h).facetAddress(IUniswapV4WeightedSwapHook.joinProportional.selector),
            address(0)
        );
    }

    function test_J_tokensBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(IDiamondLoupe(h).facetAddress(IUniswapV4WeightedSwapHook.tokens.selector), address(0));
    }

    function _freshBootstrapN(uint8 n)
        internal
        returns (address h, IUniswapV4HookStagedPairInit init, address[] memory toks)
    {
        IUniswapV4WeightedSwapHookPackage.PkgArgs memory args;
        (args, toks) = _nArgs(n);
        h = _deployBootstrapOnly(args);
        init = IUniswapV4HookStagedPairInit(h);
    }

    function _nArgs(uint8 n)
        internal
        returns (IUniswapV4WeightedSwapHookPackage.PkgArgs memory args, address[] memory toks)
    {
        require(n == 2 || n == 3, "n");
        if (n == 2) {
            MintableDec a = new MintableDec("TokenA", "TKA", 18);
            MintableDec b = new MintableDec("TokenB", "TKB", 18);
            (MintableDec t0, MintableDec t1) = address(a) < address(b) ? (a, b) : (b, a);
            toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            uint256[] memory weights = new uint256[](2);
            weights[0] = 5e17;
            weights[1] = 5e17;
            address[] memory providers = new address[](2);
            args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(vaultFeeOracle),
                tokens: toks,
                weights: weights,
                rateProviders: providers,
                tickSpacing: 0,
                sqrtPriceX96: 0
            });
        } else {
            MintableDec a = new MintableDec("USD Coin", "USDC", 6);
            MintableDec b = new MintableDec("Wrapped Ether", "WETH", 18);
            MintableDec c = new MintableDec("Dai", "DAI", 18);
            (MintableDec t0, MintableDec t1, MintableDec t2) = _sortThree(a, b, c);
            toks = new address[](3);
            toks[0] = address(t0);
            toks[1] = address(t1);
            toks[2] = address(t2);
            uint256[] memory weights = new uint256[](3);
            weights[0] = 4e17;
            weights[1] = 3e17;
            weights[2] = 3e17;
            address[] memory providers = new address[](3);
            args = IUniswapV4WeightedSwapHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(vaultFeeOracle),
                tokens: toks,
                weights: weights,
                rateProviders: providers,
                tickSpacing: 0,
                sqrtPriceX96: 0
            });
        }
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

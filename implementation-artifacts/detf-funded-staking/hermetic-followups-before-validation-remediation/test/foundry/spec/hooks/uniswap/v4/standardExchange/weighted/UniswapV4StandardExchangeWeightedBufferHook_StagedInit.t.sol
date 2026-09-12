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
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_StagedInit_Test
 * @notice S43 bootstrap-only deploy plus door / finalize / J-surface matrix (n=2 and n>=3).
 */
contract UniswapV4StandardExchangeWeightedBufferHook_StagedInit_Test is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook
{
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant PAIR_POOL_DEPLOYED_TOPIC =
        keccak256("PairPoolDeployed(address,address,address,bytes32)");

    function test_S58_pkgFacetFuncs_exactlySix() public view {
        bytes4[] memory funcs = IFacet(address(hookPkg)).facetFuncs();
        assertEq(funcs.length, 6);
        assertEq(funcs[0], IHooks.beforeInitialize.selector);
        assertEq(funcs[1], IUniswapV4HookStagedPairInit.deployPair.selector);
        assertEq(funcs[2], IUniswapV4HookStagedPairInit.finalizeInitialization.selector);
        assertEq(funcs[3], IUniswapV4HookStagedPairInit.isPairPoolLive.selector);
        assertEq(funcs[4], IUniswapV4HookStagedPairInit.pairPoolKey.selector);
        assertEq(funcs[5], IUniswapV4HookStagedPairInit.isInitializationFinalized.selector);
    }

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
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.tokens.selector),
            address(0)
        );
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeSwap.selector), address(0));
        assertEq(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,) = _freshBootstrapN(2);
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address[] memory toks) = _freshBootstrapN(2);
        PoolKey memory expected =
            PairPoolLib.pairKey(toks[0], toks[1], PairPoolLib.TICK_SPACING, IHooks(h));
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
        vm.expectRevert(UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPair.selector);
        init.deployPair(toks[0], toks[0]);
        vm.expectRevert(UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPair.selector);
        init.deployPair(toks[0], address(0xB0B0));
        vm.expectRevert(UniswapV4StandardExchangeWeightedBufferHookTarget.InvalidPair.selector);
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
        assertEq(
            loupe.facetAddress(IUniswapV4HookStagedPairInit.isInitializationFinalized.selector),
            address(0)
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector),
            address(hookPkg.JOIN_FACET())
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
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.tokens.selector),
            address(hookPkg.HOOKS_FACET())
        );
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.HOOKS_FACET()));
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
        assertEq(loupe.facetAddress(IBasicVault.vaultTokens.selector), address(multiAssetBasicVaultFacet));
        assertEq(IUniswapV4StandardExchangeWeightedBufferHook(h).pairDoorCount(), 3);
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
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector),
            address(hookPkg.JOIN_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector),
            address(hookPkg.EXIT_FACET())
        );
        assertEq(
            loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(hookPkg.SE_FACET())
        );
        assertEq(
            loupe.facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.tokens.selector),
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
        PoolKey memory key =
            PairPoolLib.pairKey(toks[0], toks[1], PairPoolLib.TICK_SPACING, IHooks(h));
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
        PoolKey memory extraThis = PairPoolLib.pairKey(toks[0], toks[1], 60, IHooks(h));
        vm.expectRevert();
        pm.initialize(extraThis, TickMath.getSqrtPriceAtTick(0));

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
        SimpleMintableERC20 a = new SimpleMintableERC20("A2", "A2");
        SimpleMintableERC20 b = new SimpleMintableERC20("B2", "B2");
        (SimpleMintableERC20 t0, SimpleMintableERC20 t1) =
            address(a) < address(b) ? (a, b) : (b, a);
        SimpleYieldERC4626 v = new SimpleYieldERC4626(t0);
        address se = _deployERC4626SE(address(v));
        address[] memory toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se;
        address[] memory rps = new address[](2);
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args =
            _pkgArgs(toks, w, ses, rps);
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function test_J_swapBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeSwap.selector), address(0));
    }

    function test_J_joinBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(
            IDiamondLoupe(h).facetAddress(
                IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector
            ),
            address(0)
        );
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector,
                IUniswapV4StandardExchangeWeightedBufferHook.joinProportional.selector
            )
        );
        IUniswapV4StandardExchangeWeightedBufferHook(h).joinProportional(
            amounts, user, 0, block.timestamp + 1
        );
    }

    function test_J_exitBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(
            IDiamondLoupe(h).facetAddress(
                IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector
            ),
            address(0)
        );
        uint256[] memory mins = new uint256[](2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Proxy.NoTargetFor.selector,
                IUniswapV4StandardExchangeWeightedBufferHook.exitProportional.selector
            )
        );
        IUniswapV4StandardExchangeWeightedBufferHook(h).exitProportional(
            1, user, mins, block.timestamp + 1
        );
    }

    function test_J_seBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
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

    function test_J_tokensBeforeFinalize_unmatched() public {
        (address h,,) = _freshBootstrapN(2);
        assertEq(
            IDiamondLoupe(h).facetAddress(IUniswapV4StandardExchangeWeightedBufferHook.tokens.selector),
            address(0)
        );
    }

    function _freshBootstrapN(uint8 n)
        internal
        returns (address h, IUniswapV4HookStagedPairInit init, address[] memory toks)
    {
        require(n == 2 || n == 3, "n");
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory args;
        if (n == 2) {
            SimpleMintableERC20 a = new SimpleMintableERC20("A", "A");
            SimpleMintableERC20 b = new SimpleMintableERC20("B", "B");
            (SimpleMintableERC20 t0, SimpleMintableERC20 t1) =
                address(a) < address(b) ? (a, b) : (b, a);
            SimpleYieldERC4626 v = new SimpleYieldERC4626(t0);
            address se = _deployERC4626SE(address(v));
            toks = new address[](2);
            toks[0] = address(t0);
            toks[1] = address(t1);
            uint256[] memory w = new uint256[](2);
            w[0] = 0.5e18;
            w[1] = 0.5e18;
            address[] memory ses = new address[](2);
            ses[0] = se;
            address[] memory rps = new address[](2);
            args = _pkgArgs(toks, w, ses, rps);
        } else {
            SimpleMintableERC20 a = new SimpleMintableERC20("A3", "A3");
            SimpleMintableERC20 b = new SimpleMintableERC20("B3", "B3");
            SimpleMintableERC20 c = new SimpleMintableERC20("C3", "C3");
            SimpleMintableERC20[3] memory raw = [a, b, c];
            for (uint256 i; i < 3; ++i) {
                for (uint256 j; j + 1 < 3; ++j) {
                    if (address(raw[j]) > address(raw[j + 1])) {
                        (raw[j], raw[j + 1]) = (raw[j + 1], raw[j]);
                    }
                }
            }
            SimpleYieldERC4626 v = new SimpleYieldERC4626(raw[0]);
            address se = _deployERC4626SE(address(v));
            toks = new address[](3);
            toks[0] = address(raw[0]);
            toks[1] = address(raw[1]);
            toks[2] = address(raw[2]);
            uint256[] memory w = new uint256[](3);
            w[0] = 4e17;
            w[1] = 3e17;
            w[2] = 3e17;
            address[] memory ses = new address[](3);
            ses[0] = se;
            address[] memory rps = new address[](3);
            args = _pkgArgs(toks, w, ses, rps);
        }
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

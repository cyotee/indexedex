// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {Vm} from "forge-std/Vm.sol";

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPairPoolLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget as SeTarget
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookInitFacet
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/facets/UniswapV4SingleStandardExchangeBufferConstantProductHookInitFacet.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_StagedInit_Test
 * @notice S43 bootstrap-only deploy plus one-door / finalize matrix.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_StagedInit_Test is TestBase {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant PAIR_POOL_DEPLOYED_TOPIC =
        keccak256("PairPoolDeployed(address,address,address,bytes32)");

    function test_facetCuts_isBootstrapOnly() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.facetCuts();
        assertEq(cuts.length, 4);
        assertEq(cuts[0].facetAddress, address(multiStepOwnableFacet));
        assertEq(cuts[1].facetAddress, address(multiAssetBasicVaultFacet));
        assertEq(cuts[2].facetAddress, address(multiAssetStandardVaultFacet));
        assertEq(cuts[3].facetAddress, address(hookPkg));
        assertEq(uint8(cuts[0].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(uint8(cuts[1].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(uint8(cuts[2].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(uint8(cuts[3].action), uint8(IDiamond.FacetCutAction.Add));
        _assertSelectorEq(cuts[0].functionSelectors, multiStepOwnableFacet.facetFuncs());
        _assertSelectorEq(cuts[3].functionSelectors, IFacet(address(hookPkg)).facetFuncs());
    }

    function test_productionFacetCuts_sixAdds() public view {
        IDiamond.FacetCut[] memory cuts = hookPkg.productionFacetCuts();
        assertEq(cuts.length, 6);
        assertEq(cuts[0].facetAddress, address(hookPkg.SE_FACET()));
        assertEq(cuts[1].facetAddress, address(hookPkg.DEPOSIT_FACET()));
        assertEq(cuts[2].facetAddress, address(hookPkg.WITHDRAW_FACET()));
        assertEq(cuts[3].facetAddress, address(erc20Facet));
        assertEq(cuts[4].facetAddress, address(erc5267Facet));
        assertEq(cuts[5].facetAddress, address(erc2612Facet));
        _assertSelectorEq(cuts[0].functionSelectors, hookPkg.SE_FACET().facetFuncs());
        _assertSelectorEq(cuts[1].functionSelectors, hookPkg.DEPOSIT_FACET().facetFuncs());
        _assertSelectorEq(cuts[2].functionSelectors, hookPkg.WITHDRAW_FACET().facetFuncs());
        _assertSelectorEq(cuts[3].functionSelectors, erc20Facet.facetFuncs());
        _assertSelectorEq(cuts[4].functionSelectors, erc5267Facet.facetFuncs());
        _assertSelectorEq(cuts[5].functionSelectors, erc2612Facet.facetFuncs());
    }

    function test_facetCuts_ne_productionFacetCuts() public view {
        assertTrue(
            keccak256(abi.encode(hookPkg.facetCuts()))
                != keccak256(abi.encode(hookPkg.productionFacetCuts()))
        );
    }

    function test_facetFuncs_isS58() public view {
        bytes4[] memory funcs = IFacet(address(hookPkg)).facetFuncs();
        assertEq(funcs.length, 6);
        assertEq(funcs[0], IHooks.beforeInitialize.selector);
        assertEq(funcs[1], IUniswapV4HookStagedPairInit.deployPair.selector);
        assertEq(funcs[2], IUniswapV4HookStagedPairInit.finalizeInitialization.selector);
        assertEq(funcs[3], IUniswapV4HookStagedPairInit.isPairPoolLive.selector);
        assertEq(funcs[4], IUniswapV4HookStagedPairInit.pairPoolKey.selector);
        assertEq(funcs[5], IUniswapV4HookStagedPairInit.isInitializationFinalized.selector);
    }

    function test_facetName_isInitFacetType() public view {
        assertEq(
            IFacet(address(hookPkg)).facetName(),
            type(UniswapV4SingleStandardExchangeBufferConstantProductHookInitFacet).name
        );
    }

    function test_packageName_unchanged() public view {
        assertEq(
            hookPkg.packageName(),
            type(UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg).name
        );
    }

    function test_postDeploy_returnsTrue_noInit() public {
        assertTrue(hookPkg.postDeploy(address(0x1)));
    }

    function test_S43_deployAlone_noProductDoors() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        assertFalse(init.isPairPoolLive(t0, t1));
        assertFalse(init.isPairPoolLive(t1, t0));
        assertFalse(init.isInitializationFinalized());
        assertTrue(h != address(0));
    }

    function test_S43_deployAlone_vaultConfigWorks() public {
        (address h,,,) = _freshBootstrap();
        IStandardVault(h).vaultConfig();
        assertTrue(_registry().isVault(h));
    }

    function test_S43_deployAlone_initSelectorsExist() public {
        (address h,,,) = _freshBootstrap();
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
        (address h,,,) = _freshBootstrap();
        IDiamondLoupe loupe = IDiamondLoupe(h);
        assertEq(loupe.facetAddress(IHook.deposit.selector), address(0));
        assertEq(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
        assertEq(loupe.facetAddress(IHook.currency0.selector), address(0));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_deployAlone_erc165_claimsIERC20() public {
        (address h,,,) = _freshBootstrap();
        assertTrue(IERC165(h).supportsInterface(type(IERC20).interfaceId));
        assertEq(IDiamondLoupe(h).facetAddress(IERC20.transfer.selector), address(0));
    }

    function test_S43_pairPoolKey_alwaysConstructed() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        PoolKey memory expected = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        PoolKey memory actual = init.pairPoolKey(t0, t1);
        _assertKeyEq(actual, expected);
        _assertKeyEq(init.pairPoolKey(t1, t0), actual);
        assertFalse(init.isPairPoolLive(t0, t1));
    }

    function test_deployPair_emitsOnce() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
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
        (, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
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
        (, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        PoolKey memory a = init.deployPair(t1, t0);
        PoolKey memory b = init.deployPair(t0, t1);
        _assertKeyEq(a, b);
        assertTrue(init.isPairPoolLive(t0, t1));
        assertTrue(init.isPairPoolLive(t1, t0));
    }

    function test_deployPair_invalidPairReverts() public {
        (, IUniswapV4HookStagedPairInit init, address t0,) = _freshBootstrap();
        vm.expectRevert(SeTarget.InvalidPoolToken.selector);
        init.deployPair(t0, t0);
        vm.expectRevert(SeTarget.InvalidPoolToken.selector);
        init.deployPair(t0, address(0xB0B0));
        vm.expectRevert(SeTarget.InvalidPoolToken.selector);
        init.deployPair(address(0), t0);
        vm.expectRevert(SeTarget.InvalidPoolToken.selector);
        init.deployPair(address(rawToken), address(pairToken));
    }

    function test_finalize_revertsMissingDoors() public {
        (, IUniswapV4HookStagedPairInit init,,) = _freshBootstrap();
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_finalize_success_returnsTrue() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        init.deployPair(t0, t1);

        IDiamond.FacetCut[] memory cuts = _expectedFinalizeCuts();
        vm.expectEmit(false, false, false, true, h);
        emit IDiamond.DiamondCut(cuts, address(0), "");
        vm.expectEmit(true, false, false, true, h);
        emit IUniswapV4HookStagedPairInit.InitializationFinalized(h);
        bool ok = init.finalizeInitialization();
        assertTrue(ok);
    }

    function test_finalize_removesInit_addsProduction() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        init.deployPair(t0, t1);
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
        assertEq(loupe.facetAddress(IHook.deposit.selector), address(hookPkg.DEPOSIT_FACET()));
        assertEq(loupe.facetAddress(IHook.currency0.selector), address(hookPkg.SE_FACET()));
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.SE_FACET()));
        assertEq(loupe.facetAddress(IStandardExchangeIn.exchangeIn.selector), address(hookPkg.SE_FACET()));
        assertEq(loupe.facetAddress(IERC20.transfer.selector), address(erc20Facet));
        assertEq(
            loupe.facetAddress(IStandardVault.vaultConfig.selector),
            address(multiAssetStandardVaultFacet)
        );
        assertEq(loupe.facetAddress(IBasicVault.vaultTokens.selector), address(multiAssetBasicVaultFacet));
    }

    function test_finalize_secondCallUnmatchedOrAlreadyFinalized() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        init.deployPair(t0, t1);
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
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        PoolKey memory key = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        vm.recordLogs();
        pm.initialize(key, price);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].topics.length == 0 || logs[i].topics[0] != PAIR_POOL_DEPLOYED_TOPIC);
        }
        assertTrue(init.isPairPoolLive(t0, t1));
        assertTrue(init.finalizeInitialization());
    }

    function test_deployPair_revertsIfAlreadyInitializedByExtraKey() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        PoolKey memory extra = PairPoolLib.pairKey(t0, t1, 120, IHooks(h));
        pm.initialize(extra, TickMath.getSqrtPriceAtTick(0));
        vm.expectRevert(SeTarget.AlreadyInitialized.selector);
        init.deployPair(t0, t1);
    }

    function test_finalize_extraTickSpacingDoesNotCount() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        PoolKey memory extra = PairPoolLib.pairKey(t0, t1, 120, IHooks(h));
        pm.initialize(extra, TickMath.getSqrtPriceAtTick(0));
        assertFalse(init.isPairPoolLive(t0, t1));
        vm.expectRevert(IUniswapV4HookStagedPairInit.ProductDoorsNotLive.selector);
        init.finalizeInitialization();
    }

    function test_permissionless_strangerMayDoorAndFinalize() public {
        (, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        address stranger = address(0x5110);
        vm.startPrank(stranger);
        init.deployPair(t0, t1);
        assertTrue(init.finalizeInitialization());
        vm.stopPrank();
    }

    function test_noDiamondCutSelector_beforeAndAfter() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
        init.deployPair(t0, t1);
        assertTrue(init.finalizeInitialization());
        assertEq(IDiamondLoupe(h).facetAddress(cutSel), address(0));
        assertEq(IDiamondLoupe(hook).facetAddress(cutSel), address(0));
    }

    function test_firstDeployerWins_unfinalized() public {
        (address t0, address t1, address se_) = _freshLegs();
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _pkgArgs(se_, t0, t1);
        address h1 = _deployBootstrapOnly(args);
        address h2 = _deployBootstrapOnly(args);
        assertEq(h1, h2);
        assertFalse(IUniswapV4HookStagedPairInit(h1).isInitializationFinalized());
    }

    function test_J_swapBeforeFinalize_unmatched() public {
        (address h,,,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHooks.beforeSwap.selector), address(0));
        (bool ok,) = h.call(abi.encodeWithSelector(IHooks.beforeSwap.selector));
        assertFalse(ok);
    }

    function test_J_depositBeforeFinalize_unmatched() public {
        (address h,,,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IHook.deposit.selector), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IHook.deposit.selector)
        );
        IHook(h).deposit(1 ether, 1 ether, address(this), 0, block.timestamp + 1);
    }

    function test_J_exchangeInBeforeFinalize_unmatched() public {
        (address h,,,) = _freshBootstrap();
        assertEq(IDiamondLoupe(h).facetAddress(IStandardExchangeIn.exchangeIn.selector), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Proxy.NoTargetFor.selector, IStandardExchangeIn.exchangeIn.selector)
        );
        IStandardExchangeIn(h).exchangeIn(
            IERC20(address(1)), 1, IERC20(address(2)), 0, address(this), false, block.timestamp + 1
        );
    }

    function test_J_afterFinalize_noInitSelectors() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        init.deployPair(t0, t1);
        assertTrue(init.finalizeInitialization());
        IDiamondLoupe loupe = IDiamondLoupe(h);
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
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.SE_FACET()));
    }

    function test_beforeInitialize_sameChecks_afterFinalize() public {
        (address h, IUniswapV4HookStagedPairInit init, address t0, address t1) = _freshBootstrap();
        init.deployPair(t0, t1);
        assertTrue(init.finalizeInitialization());
        PoolKey memory key = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        vm.expectRevert();
        pm.initialize(key, TickMath.getSqrtPriceAtTick(0));

        vm.prank(address(pm));
        vm.expectRevert(SeTarget.AlreadyInitialized.selector);
        IHooks(h).beforeInitialize(address(this), key, 0);
    }

    function test_beforeInitialize_feeZero_onBootstrapLib() public {
        (address h,, address t0, address t1) = _freshBootstrap();
        PoolKey memory badFee = PairPoolLib.pairKey(t0, t1, 60, IHooks(h));
        badFee.fee = 3000;
        vm.prank(address(pm));
        vm.expectRevert(SeTarget.InvalidPoolFee.selector);
        IHooks(h).beforeInitialize(address(this), badFee, 0);
    }

    function test_setUpLeavesDoorAndFinalized() public view {
        IDiamondLoupe loupe = IDiamondLoupe(hook);
        assertEq(loupe.facetAddress(IHook.deposit.selector), address(hookPkg.DEPOSIT_FACET()));
        assertEq(loupe.facetAddress(IUniswapV4HookStagedPairInit.deployPair.selector), address(0));
        assertEq(loupe.facetAddress(IHooks.beforeInitialize.selector), address(hookPkg.SE_FACET()));
        assertTrue(PairPoolLib.isPoolLive(pm, poolKey));
    }

    function _freshBootstrap()
        internal
        returns (address h, IUniswapV4HookStagedPairInit init, address t0, address t1)
    {
        address se_;
        (t0, t1, se_) = _freshLegs();
        h = _deployBootstrapOnly(_pkgArgs(se_, t0, t1));
        init = IUniswapV4HookStagedPairInit(h);
    }

    function _freshLegs() internal returns (address t0, address t1, address se_) {
        SimpleMintableERC20 raw_ = new SimpleMintableERC20("Raw2", "RAW2");
        SimpleMintableERC20 pair_ = new SimpleMintableERC20("Pair2", "PAIR2");
        t0 = address(raw_);
        t1 = address(pair_);
        SimpleYieldERC4626 vault_ = new SimpleYieldERC4626(pair_);
        se_ = _deployERC4626SE(address(vault_));
    }

    function _pkgArgs(address se_, address raw_, address pair_)
        internal
        view
        returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory)
    {
        return IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange: se_,
            pairToken: pair_,
            rawToken: raw_,
            ownerOnlyLiquidity: _pkgOwnerOnlyLiquidity(),
            owner: _pkgOwner()
        });
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

    function _assertSelectorEq(bytes4[] memory a, bytes4[] memory b) internal pure {
        assertEq(a.length, b.length);
        assertEq(keccak256(abi.encodePacked(a)), keccak256(abi.encodePacked(b)));
    }
}

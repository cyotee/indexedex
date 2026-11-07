// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote} from
    "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

contract RebasingAwareERC4626_Buffers_Curve is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    IERC4626 internal rebasingWrapper;
    RebasingERC20Harness internal rebasingUnderlying;

    // The control binds a real wrapper over non-rebasing token0, never its share or a rebasing asset.
    function test_F16_curveProcessArgsAcceptsMemberAndRejectsForgedDecimals() public {
        _deployWrapper();
        IPkg.PkgArgs memory args = _controlArgs();
        assertGt(hookPkg.processArgs(abi.encode(args)).length, 0);
        args.tokenDecimals[0] = 6;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _controlArgs();
        args.seDecimals[0] = 18;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _controlArgs();
        args.tokenDecimals[0] = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_curveProcessArgsRejectsNonmemberAndIdentity() public {
        _deployWrapper();
        IPkg.PkgArgs memory args = _controlArgs();
        args.standardExchanges[0] = address(rebasingWrapper);
        vm.expectRevert(IPkg.InvalidSE.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _controlArgs();
        args.standardExchanges[0] = args.tokens[0];
        args.seDecimals[0] = args.tokenDecimals[0];
        vm.expectRevert(IPkg.InvalidSE.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_curveNonRebasingWrapperJoinExit() public {
        uint256 lp = _seedControl();
        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < amounts.length; ++i) amounts[i] = 10 ether;
        vm.prank(user);
        (uint256 joined,) = IHook(hook).joinProportional(amounts, user, 1, block.timestamp + 1 hours);
        assertGt(joined, 0, "caller funds every incumbent component");
        uint256[] memory expected = IHook(hook).previewExitProportional(lp + joined);
        vm.prank(user);
        uint256[] memory out = IHook(hook).exitProportional(lp + joined, user, new uint256[](amounts.length), block.timestamp + 1 hours);
        for (uint256 i; i < out.length; ++i) { assertGt(out[i], 0); assertEq(out[i], expected[i]); }
    }

    function test_F16_curveNonRebasingWrapperQuoteSwap() public {
        _seedControl();
        uint256 pred = IHook(hook).previewSwapExactIn(address(token0), address(token1), 1 ether);
        uint256 beforeOut = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), 1 ether);
        assertGt(pred, 0);
        assertEq(token1.balanceOf(user) - beforeOut, pred);
        pred = IHook(hook).previewSwapExactIn(address(token1), address(token0), 1 ether);
        beforeOut = token0.balanceOf(user);
        _swapExactIn(address(token1), address(token0), 1 ether);
        assertGt(pred, 0);
        assertEq(token0.balanceOf(user) - beforeOut, pred);
    }

    function test_F16_curveDisabledNonRebasingWrapperExit() public {
        uint256 lp = _seedControl();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(wrapper), true);
        vm.startPrank(user);
        token0.approve(address(wrapper), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(wrapper)));
        wrapper.deposit(1 ether, user);
        uint256[] memory out = IHook(hook).exitProportional(lp / 2, user, new uint256[](4), block.timestamp + 1 hours);
        vm.stopPrank();
        for (uint256 i; i < out.length; ++i) assertGt(out[i], 0);
    }

    function _seedControl() internal returns (uint256 lp) {
        _deployWrapper();
        _deployHookWithArgs(_controlArgs());
        vm.startPrank(user);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        vm.stopPrank();
        // The base acquires caller-owned SE shares before its flexible genesis join.
        lp = _firstMintEqual(80 ether);
        assertGt(lp, 0);
        assertEq(wrapper.balanceOf(hook), 76e28, "95 percent retained own-share inventory");
        assertEq(token0.balanceOf(hook), 4 ether, "actual 5 percent redemption proceeds");
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
    }

    /// @notice Rebasing behavior is a standalone wrapper proof, not a lawful hook binding.
    function test_F16_standaloneOwnShareAndRebaseProcessing() public {
        _deployWrapper();
        rebasingUnderlying.mint(user, 400 ether);
        vm.startPrank(user);
        rebasingUnderlying.approve(address(rebasingWrapper), type(uint256).max);
        (uint256 shares,) = IStandardExchangeIn(address(rebasingWrapper)).exchangeIn(
            IERC20(address(rebasingUnderlying)), 200 ether, IERC20(address(rebasingWrapper)),
            1, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(shares, 0);
        assertEq(rebasingWrapper.balanceOf(user), shares);
        (bytes memory state,) = IStandardExchangeTransitionQuote(address(rebasingWrapper)).quoteState(
            address(rebasingUnderlying), user
        );
        assertEq(state.length, 288);
        uint256 sample = shares / 10;
        uint256 stale = IStandardExchangeTransitionQuote(address(rebasingWrapper)).quoteAssets(state, sample);
        uint256 beforeAssets = rebasingWrapper.totalAssets();
        rebasingUnderlying.rebase(address(rebasingWrapper), int256(5 ether));
        assertEq(rebasingWrapper.totalAssets(), beforeAssets + 5 ether);
        assertTrue(rebasingWrapper.convertToAssets(sample) != stale);
        rebasingUnderlying.rebase(address(rebasingWrapper), -int256(1 ether));
        assertEq(rebasingWrapper.totalAssets(), beforeAssets + 4 ether);
        rebasingUnderlying.mint(address(rebasingWrapper), 2 ether);
        assertEq(rebasingWrapper.totalAssets(), rebasingUnderlying.balanceOf(address(rebasingWrapper)));
        assertEq(rebasingWrapper.balanceOf(user), shares, "rebase cannot invent wrapper shares");

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(rebasingWrapper), 1e16);
        assertEq(IStandardVault(address(rebasingWrapper)).vaultFeeTypeIds(), bytes32(0));
        vm.startPrank(user);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(rebasingWrapper)).exchangeIn(
            IERC20(address(rebasingUnderlying)), 1 ether, IERC20(address(rebasingWrapper)),
            0, user, true, block.timestamp
        );
        rebasingUnderlying.setRebaseOnTransfer(int256(1 ether), address(rebasingWrapper));
        uint256 heldBefore = rebasingWrapper.totalAssets();
        vm.expectRevert();
        rebasingWrapper.deposit(1 ether, user);
        assertEq(rebasingWrapper.totalAssets(), heldBefore, "failed transfer rebase rolls back");
        rebasingUnderlying.setRebaseOnTransfer(0, address(0));
        assertGt(rebasingWrapper.deposit(1 ether, user), 0);
        vm.stopPrank();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(rebasingWrapper), true);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(rebasingWrapper)));
        rebasingWrapper.deposit(1 ether, user);
        IERC20(address(rebasingWrapper)).approve(address(rebasingWrapper), sample);
        (uint256 quote,) = IStandardExchangeIn(address(rebasingWrapper)).previewExchangeIn(
            IERC20(address(rebasingWrapper)), sample, IERC20(address(rebasingUnderlying))
        );
        uint256 beforeOut = rebasingUnderlying.balanceOf(user);
        uint256 sharesBeforeRedeem = rebasingWrapper.balanceOf(user);
        (uint256 out,) = IStandardExchangeIn(address(rebasingWrapper)).exchangeIn(
            IERC20(address(rebasingWrapper)), sample, IERC20(address(rebasingUnderlying)),
            quote, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(out, quote);
        assertEq(rebasingUnderlying.balanceOf(user) - beforeOut, out);
        assertEq(sharesBeforeRedeem - rebasingWrapper.balanceOf(user), sample);
    }

    function _deployWrapper() internal {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        IFacet metaF = create3Factory.deployRebasingAwareVaultMetadataFacet();
        IFacet quoteF = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        rebasingUnderlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        rebasingWrapper = wpkg.deployVault(IERC20Metadata(address(rebasingUnderlying)), 10, bytes32(uint256(13)));
        wrapper = wpkg.deployVault(IERC20Metadata(address(token0)), 10, bytes32(uint256(113)));
    }

    function _controlArgs() internal returns (IPkg.PkgArgs memory args) {
        args = _defaultPkgArgs();
        args.standardExchanges[0] = address(wrapper);
        args.seDecimals[0] = IERC20Metadata(address(wrapper)).decimals();
        args.rateProviders = RateProviderFixtureLib.providersFor4(create3Factory, diamondPackageFactory, args.tokens, args.standardExchanges);
    }
}

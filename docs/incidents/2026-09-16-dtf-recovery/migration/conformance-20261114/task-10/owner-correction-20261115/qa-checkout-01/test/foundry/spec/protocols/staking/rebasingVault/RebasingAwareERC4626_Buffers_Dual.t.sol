// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4DualSEBCPHook as TestBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
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

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

contract RebasingAwareERC4626_Buffers_Dual is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;
    IERC4626 internal wrapper;
    IERC4626 internal wrapper1;
    IERC4626 internal rebasingWrapper;
    RebasingERC20Harness internal rebasingUnderlying;

    function test_F16_dualProcessArgsAcceptsMemberPairsAndBothWrapperLegs() public {
        _deploySubjects();
        IPkg.PkgArgs memory args = _controlArgs();
        assertGt(hookPkg.processArgs(abi.encode(args)).length, 0);
        assertEq(args.token0, address(tokenA));
        assertEq(args.token1, address(tokenB));
        assertEq(args.standardExchange0, address(wrapper));
        assertEq(args.standardExchange1, address(wrapper1));
    }

    function test_F16_dualProcessArgsRejectsNonmemberAndIdentity() public {
        _deploySubjects();
        IPkg.PkgArgs memory args = _controlArgs();
        args.standardExchange0 = address(rebasingWrapper);
        vm.expectRevert(IPkg.TokenNotInVaultTokens.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _controlArgs();
        args.token0 = address(wrapper);
        vm.expectRevert(IPkg.TokenNotInVaultTokens.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_dualNonRebasingWrapperJoinExit() public {
        uint256 lp = _seedControl();
        vm.prank(user);
        (uint256 joined,,) = dual.deposit(10 ether, 10 ether, user, 1, block.timestamp);
        assertGt(joined, 0, "caller supplies all share and local components");
        vm.prank(user);
        (uint256 o0, uint256 o1) = dual.withdraw(lp + joined, user, 1, 1, block.timestamp);
        assertGt(o0, 0);
        assertGt(o1, 0);
    }

    function test_F16_dualNonRebasingWrapperQuoteSwap() public {
        _seedControl();
        address c0 = dual.currency0();
        address c1 = dual.currency1();
        (uint256 pred,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), 1 ether, IERC20(c1));
        uint256 beforeOut = IERC20(c1).balanceOf(user);
        vm.prank(user);
        (uint256 out,) = IStandardExchangeIn(hook).exchangeIn(IERC20(c0), 1 ether, IERC20(c1), pred, user, false, block.timestamp);
        assertGt(out, 0);
        assertEq(out, pred);
        assertEq(IERC20(c1).balanceOf(user) - beforeOut, out);
        (pred,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c1), 1 ether, IERC20(c0));
        beforeOut = IERC20(c0).balanceOf(user);
        vm.prank(user);
        (out,) = IStandardExchangeIn(hook).exchangeIn(IERC20(c1), 1 ether, IERC20(c0), pred, user, false, block.timestamp);
        assertGt(out, 0);
        assertEq(out, pred);
        assertEq(IERC20(c0).balanceOf(user) - beforeOut, out);
    }

    function test_F16_dualDisabledNonRebasingWrapperExit() public {
        uint256 lp = _seedControl();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(wrapper), true);
        vm.startPrank(user);
        tokenA.approve(address(wrapper), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(wrapper)));
        wrapper.deposit(1 ether, user);
        (uint256 o0, uint256 o1) = dual.withdraw(lp / 2, user, 1, 1, block.timestamp);
        vm.stopPrank();
        assertGt(o0, 0);
        assertGt(o1, 0);
    }

    /// @dev Only the wrappers over non-rebasing members tokenA/tokenB are hook-bound.
    function _seedControl() internal returns (uint256 lp) {
        _deploySubjects();
        IPkg.PkgArgs memory args = _controlArgs();
        hook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(hook, args.token0, args.token1);
        dual = IDualHook(hook);
        vm.startPrank(user);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);
        vm.stopPrank();
        lp = _depositBoth(80 ether, 80 ether);
        assertGt(lp, 0);
        assertEq(wrapper.balanceOf(hook), 76e28);
        assertEq(wrapper1.balanceOf(hook), 76e28);
        assertEq(tokenA.balanceOf(hook), 4 ether);
        assertEq(tokenB.balanceOf(hook), 4 ether);
    }

    function _controlArgs() internal returns (IPkg.PkgArgs memory args) {
        args = _defaultPkgArgs();
        args.standardExchange0 = address(wrapper);
        args.standardExchange1 = address(wrapper1);
        args.rateProvider0 = RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, address(wrapper), address(tokenA));
        args.rateProvider1 = RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, address(wrapper1), address(tokenB));
    }

    function _deploySubjects() internal {
        wrapper = _deployWrapper(IERC20Metadata(address(tokenA)), bytes32(uint256(21)));
        wrapper1 = _deployWrapper(IERC20Metadata(address(tokenB)), bytes32(uint256(22)));
        rebasingUnderlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        rebasingWrapper = _deployWrapper(IERC20Metadata(address(rebasingUnderlying)), bytes32(uint256(32)));
    }

    /// @notice Rebasing behavior is a standalone wrapper proof, not a lawful hook binding.
    function test_F16_standaloneOwnShareAndRebaseProcessing() public {
        _deploySubjects();
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

    function _deployWrapper(IERC20Metadata asset, bytes32 salt) internal returns (IERC4626) {
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
        return wpkg.deployVault(asset, 10, salt);
    }

}

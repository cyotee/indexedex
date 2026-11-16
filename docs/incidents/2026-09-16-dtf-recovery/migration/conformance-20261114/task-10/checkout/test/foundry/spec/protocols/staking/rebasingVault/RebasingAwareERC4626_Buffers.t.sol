// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";

import {TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {
    IStandardExchangeTransitionQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";

import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

contract RebasingAwareERC4626_Buffers is TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    IERC4626 internal rebasingWrapper;
    RebasingERC20Harness internal rebasingUnderlying;
    IHook internal wrapperHook;

    function test_F16_cpProcessArgsAcceptsMemberAndRejectsForgedDecimals() public {
        _deployWrapper();
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _controlArgs();
        assertGt(hookPkg.processArgs(abi.encode(args)).length, 0);
        args.pairTokenDecimals = 6;
        vm.expectRevert(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_cpProcessArgsRejectsNonmemberAndIdentity() public {
        _deployWrapper();
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _controlArgs();
        args.standardExchange = address(rebasingWrapper);
        vm.expectRevert(bytes4(keccak256("TokenNotInVaultTokens()")));
        hookPkg.processArgs(abi.encode(args));
        args = _controlArgs();
        args.pairToken = address(wrapper);
        args.pairTokenDecimals = IERC20Metadata(address(wrapper)).decimals();
        vm.expectRevert(bytes4(keccak256("TokenNotInVaultTokens()")));
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_cpNonRebasingWrapperJoinExit() public {
        uint256 lp = _seedControl();
        vm.prank(user);
        (uint256 joined,,) = wrapperHook.deposit(10 ether, 10 ether, user, 1, block.timestamp);
        assertGt(joined, 0, "new caller funds shares and local pair components");
        (uint256 rawQuote, uint256 shareQuote) = wrapperHook.previewWithdrawSeShares(lp + joined);
        uint256 pairBefore = pairToken.balanceOf(user);
        vm.prank(user);
        (uint256 rawOut, uint256 shareOut) = wrapperHook.withdrawSeShares(lp + joined, user, rawQuote, shareQuote, block.timestamp);
        assertGt(rawOut, 0);
        assertGt(shareOut, 0);
        assertEq(rawOut, rawQuote);
        assertEq(shareOut, shareQuote);
        assertEq(pairToken.balanceOf(user), pairBefore, "share exit converts local claim instead of paying mixed output");
    }

    function test_F16_cpNonRebasingWrapperQuoteSwap() public {
        _seedControl();
        (uint256 pred,) = IStandardExchangeIn(address(wrapperHook)).previewExchangeIn(IERC20(address(rawToken)), 1 ether, IERC20(address(pairToken)));
        uint256 beforeOut = pairToken.balanceOf(user);
        vm.prank(user);
        (uint256 out,) = IStandardExchangeIn(address(wrapperHook)).exchangeIn(IERC20(address(rawToken)), 1 ether, IERC20(address(pairToken)), pred, user, false, block.timestamp);
        assertGt(out, 0);
        assertEq(out, pred);
        assertEq(pairToken.balanceOf(user) - beforeOut, out);
        (pred,) = IStandardExchangeIn(address(wrapperHook)).previewExchangeIn(IERC20(address(pairToken)), 1 ether, IERC20(address(rawToken)));
        beforeOut = rawToken.balanceOf(user);
        vm.prank(user);
        (out,) = IStandardExchangeIn(address(wrapperHook)).exchangeIn(IERC20(address(pairToken)), 1 ether, IERC20(address(rawToken)), pred, user, false, block.timestamp);
        assertGt(out, 0);
        assertEq(out, pred);
        assertEq(rawToken.balanceOf(user) - beforeOut, out);

        WrapperExactOutRouter swapRouter = new WrapperExactOutRouter(pm);
        PoolKey memory key = PoolKey({currency0: Currency.wrap(wrapperHook.currency0()), currency1: Currency.wrap(wrapperHook.currency1()), fee: 0, tickSpacing: 60, hooks: IHooks(address(wrapperHook))});
        bool zeroForOne = wrapperHook.currency0() == address(rawToken);
        beforeOut = pairToken.balanceOf(user);
        vm.startPrank(user);
        rawToken.approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(key, SwapParams({zeroForOne: zeroForOne, amountSpecified: -int256(5e17), sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1}), "");
        vm.stopPrank();
        assertGt(pairToken.balanceOf(user) - beforeOut, 0);
    }

    function test_F16_cpDisabledNonRebasingWrapperExit() public {
        uint256 lp = _seedControl();
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(wrapper), true);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(wrapper)));
        wrapper.deposit(1 ether, user);
        uint256 lpBefore = IERC20(address(wrapperHook)).balanceOf(user);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(wrapper)));
        wrapperHook.withdrawSeShares(lp / 2, user, 1, 1, block.timestamp);
        assertEq(IERC20(address(wrapperHook)).balanceOf(user), lpBefore, "disabled share conversion cannot burn LP");
        (uint256 rawOut, uint256 pairOut) = wrapperHook.withdraw(lp / 2, user, 1, 1, block.timestamp);
        vm.stopPrank();
        assertGt(rawOut, 0);
        assertGt(pairOut, 0);
    }

    function test_F16_zeroWrapperFeesWithOuterFee() public {
        _deployWrapper();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(1e16);
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
        assertEq(IStandardVault(address(hook)).vaultFeeTypeIds(), bytes32(0));
    }

    /// @dev Only non-rebasing pairToken is hook-bound; the rebasing subject stays independent.
    function _seedControl() internal returns (uint256 lp) {
        _deployWrapper();
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _controlArgs();
        uint256 nonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address deployed = PkgFactory.deployHook(hookPkg, args, nonce);
        _ensureProductDoorsAndFinalize(deployed, address(rawToken), address(pairToken));
        wrapperHook = IHook(deployed);
        vm.startPrank(user);
        pairToken.approve(address(wrapper), type(uint256).max);
        uint256 shares = wrapper.deposit(80 ether, user);
        IERC20(address(wrapper)).approve(deployed, type(uint256).max);
        rawToken.approve(deployed, type(uint256).max);
        pairToken.approve(deployed, type(uint256).max);
        (lp,,) = wrapperHook.depositWithSeShares(80 ether, shares, user, 1, block.timestamp);
        vm.stopPrank();
        assertGt(lp, 0);
        assertEq(wrapper.balanceOf(deployed), shares - shares / 20);
        assertEq(pairToken.balanceOf(deployed), 4 ether);
    }

    function _controlArgs() internal returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args) {
        args = _defaultPkgArgs();
        args.standardExchange = address(wrapper);
        args.rateProvider = RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, address(wrapper), address(pairToken));
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
        rebasingWrapper = wpkg.deployVault(IERC20Metadata(address(rebasingUnderlying)), 10, bytes32(uint256(7)));
        wrapper = wpkg.deployVault(IERC20Metadata(address(pairToken)), 10, bytes32(uint256(107)));
    }

}

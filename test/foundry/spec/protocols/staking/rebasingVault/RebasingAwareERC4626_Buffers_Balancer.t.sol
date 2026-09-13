// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
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

contract RebasingAwareERC4626_Buffers_Balancer is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    RebasingERC20Harness internal underlying;

    function test_F16_balancerProcessArgsAcceptsWrapperShareInventory() public {
        _deployWrapper();
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
        uint256 wIdx;
        for (uint256 i; i < args.tokens.length; ++i) {
            if (args.tokens[i] == address(wrapper)) {
                wIdx = i;
                break;
            }
        }
        args.tokenDecimals[wIdx] = 18;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_balancerProcessArgsRejectsOrdinaryOverlapAndHighDecimals() public {
        IPkg.PkgArgs memory overlap = _defaultPkgArgs();
        overlap.standardExchanges[0] = overlap.tokens[0];
        overlap.seDecimals[0] = overlap.tokenDecimals[0];
        vm.expectRevert(IPkg.InvalidSE.selector);
        hookPkg.processArgs(abi.encode(overlap));

        IPkg.PkgArgs memory high = _defaultPkgArgs();
        high.tokenDecimals[0] = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(high));
    }

    function test_F16_balancerWrapperShareInventoryJoinExit() public {
        _deployWrapper();
        _wrapUser(80e18);
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        _deployHookWithArgs(args);
        vm.startPrank(user);
        IERC20(address(wrapper)).approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        uint256[] memory amounts = new uint256[](args.tokens.length);
        for (uint256 i; i < amounts.length; ++i) {
            amounts[i] = _wadNative(args.tokens[i], 50 ether);
        }
        (uint256 lp,) = IHook(hook).joinProportional(amounts, user, 0, block.timestamp + 1 days);
        assertGt(lp, 0);
        uint256 beforeAssets = wrapper.totalAssets();
        vm.stopPrank();
        underlying.rebase(address(wrapper), int256(5e18));
        assertGt(wrapper.totalAssets(), beforeAssets);
        uint256[] memory mins = new uint256[](amounts.length);
        vm.prank(user);
        uint256[] memory out = IHook(hook).exitProportional(lp, user, mins, block.timestamp + 1 days);
        assertGt(out[0] + out[1] + out[2] + out[3], 0);
    }

    function test_F16_balancerWrapperShareInventoryQuoteSwap() public {
        _deployWrapper();
        _wrapUser(200e18);
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        _deployHookWithArgs(args);
        vm.startPrank(user);
        IERC20(address(wrapper)).approve(hook, type(uint256).max);
        IERC20(address(wrapper)).approve(address(swapRouter), type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        uint256[] memory amounts = new uint256[](args.tokens.length);
        for (uint256 i; i < amounts.length; ++i) {
            amounts[i] = _wadNative(args.tokens[i], 80 ether);
        }
        (uint256 lp,) = IHook(hook).joinProportional(amounts, user, 0, block.timestamp + 1 days);
        assertGt(lp, 0);
        vm.stopPrank();

        uint256 swapIn = IERC20(address(wrapper)).balanceOf(user) / 8;
        uint256 pred = IHook(hook).previewSwapExactIn(address(wrapper), address(token1), swapIn);
        assertGt(pred, 0);
        uint256 before = token1.balanceOf(user);
        _swapExactIn(address(wrapper), address(token1), swapIn);
        assertGt(token1.balanceOf(user) - before, 0);
    }

    function test_F16_balancerAmendmentMatrixLiveHook() public {
        _deployWrapper();
        _wrapUser(200e18);
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        _deployHookWithArgs(args);
        vm.startPrank(user);
        IERC20(address(wrapper)).approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token3.approve(hook, type(uint256).max);
        uint256[] memory amounts = new uint256[](args.tokens.length);
        for (uint256 i; i < amounts.length; ++i) {
            amounts[i] = _wadNative(args.tokens[i], 80 ether);
        }
        (uint256 lp,) = IHook(hook).joinProportional(amounts, user, 0, block.timestamp + 1 days);
        assertGt(lp, 0);
        vm.stopPrank();

        (bytes memory qState,) = IStandardExchangeTransitionQuote(address(wrapper)).quoteState(
            address(underlying), hook
        );
        uint256 sample = IERC20(address(wrapper)).balanceOf(hook) / 10;
        uint256 stale = IStandardExchangeTransitionQuote(address(wrapper)).quoteAssets(qState, sample);
        underlying.rebase(address(wrapper), int256(5e18));
        assertTrue(wrapper.convertToAssets(sample) != stale);
        underlying.rebase(address(wrapper), -int256(1e18));
        underlying.mint(address(wrapper), 2e18);

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(hook, 1e16);
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));

        vm.prank(user);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(wrapper)).exchangeIn(
            IERC20(address(underlying)), 1e18, IERC20(address(wrapper)), 0, user, true, block.timestamp
        );

        underlying.setRebaseOnTransfer(int256(1e18), address(wrapper));
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        vm.expectRevert();
        wrapper.deposit(1e18, user);
        vm.stopPrank();
        underlying.setRebaseOnTransfer(0, address(0));
        vm.prank(user);
        assertGt(wrapper.deposit(1e18, user), 0);

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(wrapper), true);
        vm.prank(user);
        vm.expectRevert();
        wrapper.deposit(1e18, user);
        uint256[] memory mins = new uint256[](amounts.length);
        vm.prank(user);
        uint256[] memory out = IHook(hook).exitProportional(lp / 2, user, mins, block.timestamp + 1 days);
        assertGt(out[0] + out[1] + out[2] + out[3], 0);
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
        underlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        wrapper = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(14)));
    }

    function _wrapUser(uint256 assets) internal {
        underlying.mint(user, assets * 2);
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(assets, user);
        vm.stopPrank();
    }

    function _wrapperMixedArgs() internal view returns (IPkg.PkgArgs memory args) {
        args = _defaultPkgArgs();
        address[] memory toks = new address[](4);
        toks[0] = address(wrapper);
        toks[1] = address(token1);
        toks[2] = address(token2);
        toks[3] = address(token3);
        _sort(toks);
        address[] memory ses = new address[](4);
        address[] memory rps = new address[](4);
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == address(wrapper)) ses[i] = address(wrapper);
        }
        args.tokens = toks;
        args.standardExchanges = ses;
        args.rateProviders = rps;
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(toks);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(ses);
    }

    function _sort(address[] memory toks) private pure {
        for (uint256 i; i < toks.length; ++i) {
            for (uint256 j = i + 1; j < toks.length; ++j) {
                if (toks[j] < toks[i]) {
                    (toks[i], toks[j]) = (toks[j], toks[i]);
                }
            }
        }
    }

    function _wadNative(address token, uint256 wad18) internal view returns (uint256) {
        uint8 d = IERC20Metadata(token).decimals();
        if (d == 18) return wad18;
        if (d > 18) return wad18 * (10 ** (d - 18));
        return wad18 / (10 ** (18 - d));
    }
}

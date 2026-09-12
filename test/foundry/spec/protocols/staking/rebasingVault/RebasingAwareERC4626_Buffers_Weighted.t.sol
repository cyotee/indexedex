// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";

contract RebasingAwareERC4626_Buffers_Weighted is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    RebasingERC20Harness internal underlying;

    function test_F16_weightedProcessArgsAcceptsWrapperShareInventory() public {
        _deployWrapper();
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
        args.tokenDecimals[0] = 18;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_weightedProcessArgsRejectsOrdinaryOverlapAndHighDecimals() public {
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

    function test_F16_weightedWrapperShareInventoryJoinExit() public {
        _deployWrapper();
        _wrapUser(80e18);
        IPkg.PkgArgs memory args = _wrapperMixedArgs();
        _deployHookWithArgs(args);
        uint256 wAmt = IERC20(address(wrapper)).balanceOf(user) / 2;
        uint256 rawAmt = 50 ether;
        token1.mint(user, rawAmt);
        vm.startPrank(user);
        IERC20(address(wrapper)).approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        uint256[] memory amounts = new uint256[](2);
        if (args.tokens[0] == address(wrapper)) {
            amounts[0] = wAmt;
            amounts[1] = rawAmt;
        } else {
            amounts[0] = rawAmt;
            amounts[1] = wAmt;
        }
        (uint256 lp,) = IHook(hook).joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0);
        uint256 beforeAssets = wrapper.totalAssets();
        vm.stopPrank();
        underlying.rebase(address(wrapper), int256(5e18));
        assertGt(wrapper.totalAssets(), beforeAssets);
        uint256[] memory mins = new uint256[](2);
        vm.prank(user);
        uint256[] memory out = IHook(hook).exitProportional(lp, user, mins, block.timestamp + 1 hours);
        assertGt(out[0], 0);
        assertGt(out[1], 0);
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
        wrapper = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(11)));
    }

    function _wrapUser(uint256 assets) internal {
        underlying.mint(user, assets * 2);
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(assets, user);
        vm.stopPrank();
    }

    function _wrapperMixedArgs() internal view returns (IPkg.PkgArgs memory args) {
        address w = address(wrapper);
        address raw = address(token1);
        address[] memory toks = new address[](2);
        uint256[] memory weights = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        if (w < raw) {
            toks[0] = w;
            toks[1] = raw;
            ses[0] = w;
        } else {
            toks[0] = raw;
            toks[1] = w;
            ses[1] = w;
        }
        args = _pkgArgs(toks, weights, ses, rps);
    }
}

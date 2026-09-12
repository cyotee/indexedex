// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

import {TestBase_UniswapV4StandardExchangeOrbitalBufferHook as TestBase} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";

contract RebasingAwareERC4626_Buffers_Orbital is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    RebasingERC20Harness internal underlying;

    function test_F16_orbitalProcessArgsAcceptsWrapperShareInventory() public {
        _deployWrapper();
        IPkg.PkgArgs memory args = _wrapperLeg0Args();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
        args.decimals0 = 18;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_orbitalProcessArgsRejectsOrdinaryOverlapAndHighDecimals() public {
        IPkg.PkgArgs memory overlap = _defaultPkgArgs();
        overlap.se0 = overlap.token0;
        vm.expectRevert(IPkg.InvalidSE.selector);
        hookPkg.processArgs(abi.encode(overlap));

        IPkg.PkgArgs memory high = _defaultPkgArgs();
        high.decimals0 = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(high));
    }

    function test_F16_orbitalWrapperShareInventoryJoinExit() public {
        _deployWrapper();
        _wrapUser(80e18);
        IPkg.PkgArgs memory args = _wrapperLeg0Args();
        address wHook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(wHook, address(wrapper), address(token1), address(token2));
        hook = wHook;
        orbital = IHook(wHook);
        uint256 wAmt = IERC20(address(wrapper)).balanceOf(user) / 2;
        vm.startPrank(user);
        IERC20(address(wrapper)).approve(wHook, type(uint256).max);
        token1.approve(wHook, type(uint256).max);
        token2.approve(wHook, type(uint256).max);
        (uint256 lp,,,) =
            orbital.addLiquidity(wAmt, 50 ether, 50 ether, user, 0, block.timestamp + 1 hours, "");
        assertGt(lp, 0);
        uint256 beforeAssets = wrapper.totalAssets();
        vm.stopPrank();
        underlying.rebase(address(wrapper), int256(5e18));
        assertGt(wrapper.totalAssets(), beforeAssets);
        vm.prank(user);
        (uint256 a0, uint256 a1, uint256 a2) =
            orbital.removeLiquidity(lp, user, 0, 0, 0, block.timestamp + 1 hours);
        assertGt(a0, 0);
        assertGt(a1, 0);
        assertGt(a2, 0);
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
        wrapper = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(12)));
    }

    function _wrapUser(uint256 assets) internal {
        underlying.mint(user, assets * 2);
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(assets, user);
        vm.stopPrank();
    }

    function _wrapperLeg0Args() internal view returns (IPkg.PkgArgs memory args) {
        args = _defaultPkgArgs();
        args.token0 = address(wrapper);
        args.se0 = address(wrapper);
        args.decimals0 = IERC20Metadata(address(wrapper)).decimals();
    }
}

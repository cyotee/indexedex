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
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";

contract RebasingAwareERC4626_Buffers_Dual is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    IERC4626 internal wrapper1;

    function test_F16_dualProcessArgsAcceptsWrapperShareInventory() public {
        wrapper = _deployWrapper(IERC20Metadata(address(tokenA)), bytes32(uint256(21)));
        IPkg.PkgArgs memory args = _mixedArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
    }

    function test_F16_dualProcessArgsAcceptsBothWrapperLegs() public {
        wrapper = _deployWrapper(IERC20Metadata(address(tokenA)), bytes32(uint256(21)));
        wrapper1 = _deployWrapper(IERC20Metadata(address(tokenB)), bytes32(uint256(22)));
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchange0 = address(wrapper);
        args.token0 = address(wrapper);
        args.standardExchange1 = address(wrapper1);
        args.token1 = address(wrapper1);
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
    }

    function test_F16_dualProcessArgsRejectsNonWrapperPairSeOverlap() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.token0 = seA;
        args.standardExchange0 = seA;
        vm.expectRevert(IPkg.TokenNotInVaultTokens.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_dualWrapperShareInventoryJoinExit() public {
        wrapper = _deployWrapper(IERC20Metadata(address(tokenA)), bytes32(uint256(21)));
        _wrapUser(wrapper, IERC20(address(tokenA)), 80e18);
        IPkg.PkgArgs memory args = _mixedArgs();
        address wHook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(wHook, args.token0, args.token1);
        IDualHook wDual = IDualHook(wHook);
        address c0 = wDual.currency0();
        address c1 = wDual.currency1();
        uint256 a0 = c0 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 50 ether;
        uint256 a1 = c1 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 50 ether;
        vm.startPrank(user);
        IERC20(c0).approve(wHook, type(uint256).max);
        IERC20(c1).approve(wHook, type(uint256).max);
        (uint256 lp,,) = wDual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0);
        (uint256 o0, uint256 o1) = wDual.withdraw(lp, user, 0, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(o0, 0);
        assertGt(o1, 0);
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

    function _wrapUser(IERC4626 w, IERC20 asset, uint256 assets) internal {
        vm.startPrank(user);
        asset.approve(address(w), type(uint256).max);
        w.deposit(assets, user);
        vm.stopPrank();
    }

    function _mixedArgs() internal view returns (IPkg.PkgArgs memory args) {
        args = _defaultPkgArgs();
        args.standardExchange0 = address(wrapper);
        args.token0 = address(wrapper);
    }
}

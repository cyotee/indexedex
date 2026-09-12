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
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {
    IStandardExchangeTransitionQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

contract RebasingAwareERC4626_Buffers is TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    RebasingERC20Harness internal underlying;
    IHook internal wrapperHook;

    function test_bufferAmendmentPresent() public {
        string memory path = string.concat(
            vm.projectRoot(),
            "/contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md"
        );
        assertTrue(vm.exists(path), "amendment required");
    }

    function test_F16_cpProcessArgsAcceptsWrapperShareDecimals() public {
        _deployWrapper();
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _wrapperArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        assertGt(processed.length, 0);
        args.pairTokenDecimals = 18;
        vm.expectRevert(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_F16_cpWrapperShareInventoryJoinExit() public {
        _deployWrapper();
        _wrapUser(80e18);
        _deployWrapperHook();
        uint256 shares = IERC20(address(wrapper)).balanceOf(user);
        rawToken.mint(user, 50 ether);
        vm.startPrank(user);
        rawToken.approve(address(wrapperHook), type(uint256).max);
        IERC20(address(wrapper)).approve(address(wrapperHook), type(uint256).max);
        (uint256 lp,,) =
            wrapperHook.depositWithSeShares(10 ether, shares / 2, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0);
        (uint256 rawOut, uint256 seOut) =
            wrapperHook.withdrawSeShares(lp, user, 0, 0, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(rawOut, 0);
        assertGt(seOut, 0);
    }

    function test_F16_quoteAndRebaseAndRawPretransfer() public {
        _deployWrapper();
        _wrapUser(40e18);
        (bytes memory qState,) =
            IStandardExchangeTransitionQuote(address(wrapper)).quoteState(address(underlying), user);
        assertEq(qState.length, 288);

        vm.prank(user);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(wrapper)).exchangeIn(
            IERC20(address(underlying)), 1e18, IERC20(address(wrapper)), 0, user, true, block.timestamp
        );

        uint256 before = wrapper.totalAssets();
        underlying.rebase(address(wrapper), int256(5e18));
        assertGt(wrapper.totalAssets(), before);
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
    }

    function test_F16_zeroWrapperFeesWithOuterFee() public {
        _deployWrapper();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(1e16);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(wrapper), 1e16);
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
        assertEq(IStandardVault(address(hook)).vaultFeeTypeIds(), bytes32(0));
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
        wrapper = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(7)));
    }

    function _wrapUser(uint256 assets) internal {
        underlying.mint(user, assets * 2);
        vm.startPrank(user);
        underlying.approve(address(wrapper), type(uint256).max);
        wrapper.deposit(assets, user);
        vm.stopPrank();
    }

    function _wrapperArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args)
    {
        args = _defaultPkgArgs();
        args.standardExchange = address(wrapper);
        args.pairToken = address(wrapper);
        args.pairTokenDecimals = IERC20Metadata(address(wrapper)).decimals();
    }

    function _deployWrapperHook() internal {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args = _wrapperArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address wHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(wHook, address(rawToken), address(wrapper));
        wrapperHook = IHook(wHook);
    }
}

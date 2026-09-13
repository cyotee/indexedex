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

contract RebasingAwareERC4626_Buffers_Dual is TestBase {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    IERC4626 internal wrapper;
    IERC4626 internal wrapper1;
    RebasingERC20Harness internal rebaseA;

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
        args.token0 = address(tokenA);
        args.standardExchange0 = address(tokenA);
        vm.expectRevert();
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

    function test_F16_dualWrapperShareInventoryQuoteSwap() public {
        rebaseA = new RebasingERC20Harness("RebaseA", "RA", 18);
        wrapper = _deployWrapper(IERC20Metadata(address(rebaseA)), bytes32(uint256(31)));
        rebaseA.mint(user, 400e18);
        _wrapUser(wrapper, IERC20(address(rebaseA)), 200e18);
        IPkg.PkgArgs memory args = _mixedArgs();
        address wHook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(wHook, args.token0, args.token1);
        IDualHook wDual = IDualHook(wHook);
        address c0 = wDual.currency0();
        address c1 = wDual.currency1();
        uint256 a0 = c0 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 80 ether;
        uint256 a1 = c1 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 80 ether;
        vm.startPrank(user);
        IERC20(c0).approve(wHook, type(uint256).max);
        IERC20(c1).approve(wHook, type(uint256).max);
        (uint256 lp,,) = wDual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0);
        vm.stopPrank();

        uint256 swapIn = c0 == address(wrapper) ? IERC20(c0).balanceOf(user) / 8 : 1 ether;
        uint256 pred = IStandardExchangeIn(wHook).previewExchangeIn(IERC20(c0), swapIn, IERC20(c1));
        assertGt(pred, 0);
        uint256 before = IERC20(c1).balanceOf(user);
        vm.prank(user);
        uint256 got = IStandardExchangeIn(wHook).exchangeIn(
            IERC20(c0), swapIn, IERC20(c1), 0, user, false, block.timestamp + 1 hours
        );
        assertEq(got, pred);
        assertEq(IERC20(c1).balanceOf(user) - before, got);
    }

    function test_F16_dualAmendmentMatrixLiveHook() public {
        rebaseA = new RebasingERC20Harness("RebaseA", "RA", 18);
        wrapper = _deployWrapper(IERC20Metadata(address(rebaseA)), bytes32(uint256(32)));
        rebaseA.mint(user, 400e18);
        _wrapUser(wrapper, IERC20(address(rebaseA)), 200e18);
        IPkg.PkgArgs memory args = _mixedArgs();
        address wHook = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(wHook, args.token0, args.token1);
        IDualHook wDual = IDualHook(wHook);
        address c0 = wDual.currency0();
        address c1 = wDual.currency1();
        uint256 a0 = c0 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 80 ether;
        uint256 a1 = c1 == address(wrapper) ? IERC20(address(wrapper)).balanceOf(user) / 2 : 80 ether;
        vm.startPrank(user);
        IERC20(c0).approve(wHook, type(uint256).max);
        IERC20(c1).approve(wHook, type(uint256).max);
        (uint256 lp,,) = wDual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertGt(lp, 0);
        vm.stopPrank();

        (bytes memory qState,) = IStandardExchangeTransitionQuote(address(wrapper)).quoteState(
            address(rebaseA), wHook
        );
        uint256 sample = IERC20(address(wrapper)).balanceOf(wHook) / 10;
        uint256 stale = IStandardExchangeTransitionQuote(address(wrapper)).quoteAssets(qState, sample);
        rebaseA.rebase(address(wrapper), int256(5e18));
        assertTrue(wrapper.convertToAssets(sample) != stale);
        rebaseA.rebase(address(wrapper), -int256(1e18));
        rebaseA.mint(address(wrapper), 2e18);

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(wHook, 1e16);
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));

        vm.prank(user);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(wrapper)).exchangeIn(
            IERC20(address(rebaseA)), 1e18, IERC20(address(wrapper)), 0, user, true, block.timestamp
        );

        rebaseA.setRebaseOnTransfer(int256(1e18), address(wrapper));
        vm.startPrank(user);
        rebaseA.approve(address(wrapper), type(uint256).max);
        vm.expectRevert();
        wrapper.deposit(1e18, user);
        vm.stopPrank();
        rebaseA.setRebaseOnTransfer(0, address(0));
        vm.prank(user);
        assertGt(wrapper.deposit(1e18, user), 0);

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(wrapper), true);
        vm.prank(user);
        vm.expectRevert();
        wrapper.deposit(1e18, user);
        vm.prank(user);
        (uint256 o0, uint256 o1) = wDual.withdraw(lp / 2, user, 0, 0, block.timestamp + 1 hours);
        assertGt(o0 + o1, 0);
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

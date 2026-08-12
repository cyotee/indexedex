// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg,
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

contract UniswapV4StandardExchangeOrbitalDETF_DeployTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function test_deploy_inert() public view {
        _assertInert();
        assertEq(detfInfo.pairToken0(), address(token0));
        assertEq(detfInfo.pairToken1(), address(token1));
        assertEq(detfInfo.standardExchange0(), se0);
        assertEq(detfInfo.standardExchange1(), address(0));
        assertEq(detfInfo.detfBindingIndex(), 2);
        assertEq(detfInfo.rateAsset(), address(token0));
        assertTrue(detfInfo.reserveHook() != address(0));
        assertTrue(detfInfo.bondNftVault() != address(0));
        assertTrue(detfInfo.rebasingClaimToken() != address(0));
        assertEq(detfInfo.creationPair0PerDetfWad(), DEFAULT_CREATION);
        assertEq(detfInfo.creationPair1PerDetfWad(), DEFAULT_CREATION);
        assertEq(uint256(detfInfo.thresholdMode()), 0); // Policy
    }

    function test_deploy_rejects_both_bare() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.standardExchange0 = IStandardExchangeProxy(address(0));
        args.standardExchange1 = IStandardExchangeProxy(address(0));
        args.name = "bothBare";
        args.symbol = "bb";
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETDFPkg.BothBareForbidden.selector);
        indexedexManager.deployVault(
            IStandardVaultPkg(address(detfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    function test_deploy_rejects_zero_creation_rate() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.creationPair0PerDetfWad = 0;
        args.name = "zeroRate";
        args.symbol = "zr";
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETDFPkg.InvalidCreationRate.selector);
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_rejects_rp_without_se() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.rateProvider1 = address(0xBEEF); // SE1 is bare
        args.name = "rpNoSe";
        args.symbol = "rp";
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETDFPkg.RateProviderWithoutSE.selector);
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_rejects_same_se_twice() public {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args = _defaultDetfArgs();
        args.standardExchange1 = IStandardExchangeProxy(se0);
        args.pairToken1 = IERC20(address(token0)); // will hit SamePairTokens first if same tokens
        // Use different pairs but same SE
        args.pairToken1 = IERC20(address(token1));
        args.standardExchange1 = IStandardExchangeProxy(se0);
        args.name = "sameSE";
        args.symbol = "sse";
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4StandardExchangeOrbitalDETDFPkg.SameStandardExchange.selector);
        indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_deploy_free_binding_index_0() public {
        address d_ = _deployDetfInstance(_freeBindingArgs(0));
        assertEq(IUniswapV4StandardExchangeOrbitalDETF(d_).detfBindingIndex(), 0);
        assertFalse(IUniswapV4StandardExchangeOrbitalDETF(d_).isReserveLive());
    }

    function test_deploy_two_se() public {
        address d_ = _deployDetfInstance(_twoSeArgs());
        assertEq(IUniswapV4StandardExchangeOrbitalDETF(d_).standardExchange0(), se0);
        assertEq(IUniswapV4StandardExchangeOrbitalDETF(d_).standardExchange1(), se1);
    }
}

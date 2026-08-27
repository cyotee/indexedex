// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice T7.1 Dual revert, custom close length, deploy wiring.
contract UniswapV4Detf_Deploy is TestBase_UniswapV4Detf {
    function test_T7_1_dualHook_reverts() public {
        address dual_ = _deployDualHook();
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "DualReject";
        args.symbol = "DUALR";
        args.hook = dual_;
        vm.startPrank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function test_T7_1_customCloseLengthNotOne_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CloseLen0";
        args.symbol = "CL0";
        args.closeRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.closeRoutes = new IUniswapV4Detf.IoRoute[](0);
        address predicted_ = _predictDetf(args);
        // hook already bound to setUp DETF; deploy a second hook for this predicted address
        vm.startPrank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args);
        vm.stopPrank();
        predicted_;
    }

    function test_T7_1_customCloseLengthTwo_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CloseLen2";
        args.symbol = "CL2";
        args.closeRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.closeRoutes = new IUniswapV4Detf.IoRoute[](2);
        args.closeRoutes[0] = IUniswapV4Detf.IoRoute({
            token: IERC20(address(pairToken)),
            vault: IStandardExchange(se)
        });
        args.closeRoutes[1] = IUniswapV4Detf.IoRoute({
            token: IERC20(se),
            vault: IStandardExchange(se)
        });
        vm.startPrank(owner);
        vm.expectRevert();
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function test_deploy_inert_until_first_bond() public {
        assertFalse(detfInfo.isReserveLive(), "inert");
        assertTrue(detfInfo.isReserveWired(), "nft+claim wired");
        assertEq(detfInfo.reservePool(), reserveHook, "reservePool=hook");
        assertEq(detfInfo.hook(), reserveHook, "hook");
    }
}

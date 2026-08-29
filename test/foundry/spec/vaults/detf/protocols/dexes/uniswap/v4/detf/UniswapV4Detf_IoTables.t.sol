// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {UniswapV4Detf_IoTablesGoldBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesGoldBase.sol";
import {UniswapV4Detf_IoTablesOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesOpenBase.sol";

/// @notice CP gold IoTables concrete: gold-only §7.1 IDs plus Open-layer T7.2/T7.10/T7.14/T7.19.
/// @dev T7.11 execute and T7.15 FoT N/A are CP-only (Orbital/Weighted skip T7.11/T7.15; Quad T8.3 owns custom close execute).
contract UniswapV4Detf_IoTables is
    TestBase_UniswapV4Detf,
    UniswapV4Detf_IoTablesGoldBase,
    UniswapV4Detf_IoTablesOpenBase
{
    /// @notice T7.11: Custom close length 1. Calls `closeBondMature`. Leftovers `ownerSwapExactIn` in `tokens()` order.
    function test_T7_11_customClose_leftoverOwnerSwap() public {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "CustomClose1";
        args.symbol = "CC1";
        args.closeRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.closeRoutes = new IUniswapV4Detf.IoRoute[](1);
        args.closeRoutes[0] = IUniswapV4Detf.IoRoute({
            token: IERC20(address(pairToken)),
            vault: IStandardExchange(se)
        });
        address custom_ = _deployHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(custom_);
        IUniswapV4Detf.IoRoute[] memory close_ = info.closeRoutes();
        assertEq(close_.length, 1, "custom close length 1");
        assertEq(address(close_[0].token), address(pairToken), "close-route pair");
        _approveUserForDetf(custom_);

        vm.startPrank(detfUser);
        (uint256 tokenId, uint256 shares) = info.bond(
            IERC20(address(pairToken)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        info.mint(
            IERC20(address(pairToken)),
            20 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "lp");
        assertTrue(info.isReserveLive(), "live");

        address[] memory toks_ = IUniswapV4SeBufferHook(info.hook()).tokens();
        assertEq(toks_[0], custom_, "DETF index 0");

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256[] memory minOut_ = new uint256[](1);
        uint256 pairBefore_ = IERC20(address(pairToken)).balanceOf(detfUser);

        vm.prank(detfUser);
        uint256[] memory paid_ = info.closeBondMature(
            tokenId, minOut_, detfUser, block.timestamp + 1 hours
        );

        assertEq(paid_.length, 1, "custom close pays one pair");
        assertGt(paid_[0], 0, "close-route pair out");
        assertEq(
            IERC20(address(pairToken)).balanceOf(detfUser) - pairBefore_,
            paid_[0],
            "user received close-route pair"
        );
        assertEq(IERC20(custom_).balanceOf(custom_), 0, "DETF slot 0 not paid as close basket");
        assertLe(IERC20(address(pairToken)).balanceOf(custom_), 10, "close leftovers swapped or paid");
    }

    /// @notice T7.15 N/A no deploy-time FoT detection (token policy: docs+UI only).
    /// @dev FoT is forbidden as a product claim. There is no consistent on-chain FoT check, so
    ///      `processArgs` / `deployVault` do not revert on a FoT pair. Never a FoT-success money path.
    function test_T7_15_L2_FoT_forbidden() public pure {
        return;
    }
}

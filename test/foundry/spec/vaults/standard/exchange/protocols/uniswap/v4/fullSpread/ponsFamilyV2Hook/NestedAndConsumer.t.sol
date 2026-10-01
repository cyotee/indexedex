// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {UniswapV4FullSpreadPonsFamilyHookCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookNestedAndConsumerTest[]
contract UniswapV4FullSpreadPonsFamilyHookNestedAndConsumerTest is Acceptance {
    using PoolIdLibrary for *;

    function test_blockedIssuanceDoesNotChargeHook() public {
        _bootstrap();
        uint256 fee0 = ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency0));
        uint256 fee1 = ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency1));
        uint256 tax0 = ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency0));
        uint256 tax1 = ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency1));
        _nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token0, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp)));
        assertEq(ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency0)), fee0);
        assertEq(ponsHook.pendingFees(poolKey.toId(), Currency.unwrap(poolKey.currency1)), fee1);
        assertEq(ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency0)), tax0);
        assertEq(ponsHook.pendingCreatorTax(poolKey.toId(), Currency.unwrap(poolKey.currency1)), tax1);
        _assertBooked();
    }
    function test_realOuterUnlockF1ForwardAndExactShareInverseBothDirections() public {
        _bootstrap();
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            uint256 quote = abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
                (input, 1e18, IERC20(address(vault))))), (uint256));
            uint256 result = abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
                (input, 1e18, IERC20(address(vault)), quote, address(this), false, block.timestamp))), (uint256));
            assertEq(result, quote);
            uint256 needed = abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
                (input, IERC20(address(vault)), 1e18))), (uint256));
            uint256 balance = vault.balanceOf(address(this));
            result = abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.exchangeOut,
                (input, needed, IERC20(address(vault)), 1e18, address(this), false, block.timestamp))), (uint256));
            assertEq(result, needed);
            assertEq(vault.balanceOf(address(this)) - balance, 1e18);
            _assertBooked();
        }
    }

    function test_realOuterUnlockF2RedemptionAndInsufficientCover() public {
        _bootstrap();
        uint256 quote = abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.previewExchangeIn,
            (IERC20(address(vault)), 1e18, token0))), (uint256));
        uint256 beforeBalance = token0.balanceOf(address(this));
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), 1e18, token0, quote, address(this), false, block.timestamp))), (uint256)), quote);
        assertEq(token0.balanceOf(address(this)) - beforeBalance, quote);
        _assertBooked();
        uint256 tooManyShares = vault.balanceOf(address(this)) / 2;
        vm.expectPartialRevert(Common.UniswapV4Exchange_InsufficientLocalReserve.selector);
        _nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), tooManyShares, token1, 0, address(this), false, block.timestamp)));
    }

    function test_realOuterUnlockDualJoinAndF3Payout() public {
        _bootstrap();
        uint256[] memory amounts = _amounts(1e18, 1e18);
        uint256 quote = abi.decode(_nested(abi.encodeCall(IStandardExchangeInMulti.previewExchangeInManyToOne,
            (_tokens(), amounts, IERC20(address(vault))))), (uint256));
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_tokens(), amounts, IERC20(address(vault)), quote, address(this), false, block.timestamp))), (uint256)), quote);
        uint256 burn = abi.decode(_nested(abi.encodeCall(IStandardExchangeOutMulti.previewExchangeOutOneToMany,
            (IERC20(address(vault)), _tokens(), amounts))), (uint256));
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,
            (IERC20(address(vault)), burn, _tokens(), amounts, address(this), false, block.timestamp))), (uint256)), burn);
        assertEq(token0.balanceOf(address(this)) - balance0, 1e18);
        assertEq(token1.balanceOf(address(this)) - balance1, 1e18);
        _assertBooked();
    }

    function test_blockedDirectSwapAndTwoLegExactOutRejected() public {
        _bootstrap();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token0), address(token1)));
        _nested(abi.encodeCall(IStandardExchangeOut.exchangeOut, (token0, 1e18, token1, 1e15, address(this), false, block.timestamp)));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(vault), address(token0)));
        _nested(abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(address(vault)), 1e18, token0, 1e15, address(this), false, block.timestamp)));
        vm.expectRevert(Common.UniswapV4Exchange_PoolManagerInteractionBlocked.selector);
        _nested(abi.encodeCall(Reserve.rebalanceLiquidReserve, ()));
    }

    function test_blockedExactOutputRefundOnlyCallerCredit() public {
        _bootstrap();
        uint256 used = abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (token0, IERC20(address(vault)), 1e18))), (uint256));
        uint256 beforeBalance = token0.balanceOf(address(this));
        token0.transfer(address(vault), used + 1e18);
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (token0, used + 1e18, IERC20(address(vault)), 1e18, address(this), true, block.timestamp))), (uint256)), used);
        assertEq(beforeBalance - token0.balanceOf(address(this)), used);
        _assertBooked();
    }

    function test_crossModeDepositRedemptionCyclesDoNotCreateCallerAssets() public {
        _bootstrap();
        uint256 balance = token0.balanceOf(address(this));
        uint256 shares = vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        uint256 paid = abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), shares, token0, 0, address(this), false, block.timestamp))), (uint256));
        assertEq(token0.balanceOf(address(this)), balance - 1e18 + paid);
        assertLt(paid, 1e18);
        balance = token1.balanceOf(address(this));
        shares = abi.decode(_nested(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token1, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp))), (uint256));
        paid = vault.exchangeIn(IERC20(address(vault)), shares, token1, 0, address(this), false, block.timestamp);
        assertEq(token1.balanceOf(address(this)), balance - 1e18 + paid);
        assertLt(paid, 1e18);
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookNestedAndConsumerTest[]

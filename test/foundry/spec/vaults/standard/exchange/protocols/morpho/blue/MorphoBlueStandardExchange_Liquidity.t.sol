// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {
    IMorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchange.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

/**
 * @title MorphoBlueStandardExchange_Liquidity
 * @notice U1–U5: conservative maxWithdraw, InsufficientLiquidity on execute, full-NAV preview, wrap still works.
 */
contract MorphoBlueStandardExchange_Liquidity is TestBase_MorphoBlueStandardExchange {
    using MorphoBalancesLib for IMorpho;

    function _utilize() internal {
        _wrapExactIn(user, 1_000 ether);
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        uint256 borrowAmt = expected > 10 ? expected - 10 : expected;
        _borrowFromMarket(2_000 ether, borrowAmt);
    }

    function test_U1_maxWithdraw_shrinksTowardIdle() public {
        _wrapExactIn(user, 1_000 ether);
        uint256 maxBefore = se4626.maxWithdraw(user);
        assertGt(maxBefore, 0, "U1 funded maxWithdraw");
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        _borrowFromMarket(2_000 ether, expected > 10 ? expected - 10 : expected);
        uint256 maxAfter = se4626.maxWithdraw(user);
        assertLt(maxAfter, maxBefore, "U1 maxWithdraw shrinks");
        assertLe(maxAfter, _idleOf(se) + 10 + morpho.expectedTotalSupplyAssets(marketParams)
            - morpho.expectedTotalBorrowAssets(marketParams), "U1 cap is cash");
    }

    function test_U2_unwrapAboveMaxWithdraw_revertsInsufficientLiquidity() public {
        _utilize();
        uint256 maxW = se4626.maxWithdraw(user);
        uint256 requested = maxW + 1 ether;
        uint256 available = _idleOf(se) + _freeCash();
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMorphoBlueStandardExchange.InsufficientLiquidity.selector, requested, available
            )
        );
        seOut.exchangeOut(
            IERC20(se), type(uint256).max, IERC20(address(loanToken)), requested, user, false, _deadline()
        );
    }

    function test_U3_previewR2_fullNav_whileExecuteWouldRevert() public {
        _utilize();
        uint256 maxW = se4626.maxWithdraw(user);
        uint256 requested = maxW + 1 ether;
        uint256 preview = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), requested);
        assertGt(preview, 0, "U3 preview still quotes");
        uint256 nav = se4626.totalAssets();
        assertGt(nav, maxW, "U3 full NAV > conservative maxWithdraw");
    }

    function test_U4_deposit_stillSucceedsWhileUtilized() public {
        _utilize();
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), 50 ether, IERC20(se));
        uint256 out = _wrapExactIn(user, 50 ether);
        assertEq(out, preview, "U4 wrap while utilized");
    }

    function test_U5_partialWithdraw_equalMaxWithdraw_succeeds() public {
        _utilize();
        uint256 maxW = se4626.maxWithdraw(user);
        assertGt(maxW, 0, "U5 some cash");
        uint256 loanBefore = loanToken.balanceOf(user);
        vm.prank(user);
        uint256 used = seOut.exchangeOut(
            IERC20(se), type(uint256).max, IERC20(address(loanToken)), maxW, user, false, _deadline()
        );
        assertGt(used, 0, "U5 burned shares");
        assertEq(loanToken.balanceOf(user), loanBefore + maxW, "U5 paid maxWithdraw");
    }

    function _freeCash() internal view returns (uint256) {
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        uint256 totalS = morpho.expectedTotalSupplyAssets(marketParams);
        uint256 totalB = morpho.expectedTotalBorrowAssets(marketParams);
        uint256 cash = totalS > totalB ? totalS - totalB : 0;
        return expected < cash ? expected : cash;
    }
}

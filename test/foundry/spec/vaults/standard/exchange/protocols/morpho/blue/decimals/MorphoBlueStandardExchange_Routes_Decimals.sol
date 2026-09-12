// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/**
 * @title MorphoBlueStandardExchange_Routes_Decimals
 * @notice P1–P6 money paths on a non-18 loan token. Combo ID is the concrete suite name (`U6`/`U9`).
 * @dev P7 is wrap/redeem conservation at 6-dec on gold; this program is the full catalog, not P7.
 */
abstract contract MorphoBlueStandardExchange_Routes_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    using MorphoBalancesLib for IMorpho;

    function test_P1_R1_in_previewEqExec_morphoSupplyUp_idleRounding() public {
        uint256 amount = _u(100);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), amount, IERC20(se));
        uint256 supplyBefore = _expectedSupplyOf(se);
        uint256 out = _wrapExactIn(user, amount);
        assertEq(out, preview, "P1 preview == exec");
        uint256 supplyAfter = _expectedSupplyOf(se);
        assertGe(supplyAfter, supplyBefore + amount - 1, "P1 morpho expected supply up");
        assertLe(_idleOf(se), 10, "P1 idle ~ rounding");
        assertEq(
            IBasicVault(se).reserveOfToken(address(loanToken)),
            _idleOf(se),
            "P1 reserveOfToken == idle"
        );
        assertEq(se4626.totalAssets(), _idleOf(se) + supplyAfter, "P1 totalAssets == live NAV");
    }

    function test_P2_R1_out_exactShares() public {
        uint256 sharesOut = _u(50);
        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), sharesOut);
        vm.prank(user);
        uint256 used = seOut.exchangeOut(
            IERC20(address(loanToken)), previewIn, IERC20(se), sharesOut, user, false, _deadline()
        );
        assertEq(used, previewIn, "P2 preview == exec");
        assertEq(IERC20(se).balanceOf(user), sharesOut, "P2 user shares");
    }

    function test_P3_R2_in_redeemShares() public {
        uint256 amount = _u(100);
        uint256 shares = _wrapExactIn(user, amount);
        uint256 supplyBefore = _expectedSupplyOf(se);
        uint256 preview = seIn.previewExchangeIn(IERC20(se), shares, IERC20(address(loanToken)));
        uint256 loanBefore = loanToken.balanceOf(user);
        vm.prank(user);
        uint256 assetsOut = seIn.exchangeIn(
            IERC20(se), shares, IERC20(address(loanToken)), preview, user, false, _deadline()
        );
        assertEq(assetsOut, preview, "P3 preview == exec");
        assertEq(loanToken.balanceOf(user), loanBefore + assetsOut, "P3 loan received");
        assertLe(_expectedSupplyOf(se), supplyBefore, "P3 morpho supply down");
    }

    function test_P4_R2_out_withdrawExactAssets() public {
        uint256 amount = _u(100);
        _wrapExactIn(user, amount);
        uint256 assetsOut = _u(40);
        uint256 previewShares = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), assetsOut);
        uint256 loanBefore = loanToken.balanceOf(user);
        vm.prank(user);
        uint256 used = seOut.exchangeOut(
            IERC20(se), previewShares, IERC20(address(loanToken)), assetsOut, user, false, _deadline()
        );
        assertEq(used, previewShares, "P4 preview == exec");
        assertEq(loanToken.balanceOf(user), loanBefore + assetsOut, "P4 exact assets");
    }

    function test_P5_IERC4626_matches_P1_P4_amounts() public {
        uint256 amount = _u(100);
        uint256 p1Preview = seIn.previewExchangeIn(IERC20(address(loanToken)), amount, IERC20(se));
        assertEq(se4626.previewDeposit(amount), p1Preview, "P5 deposit == R1 exact-in");

        uint256 mintShares = _u(25);
        uint256 p2Preview = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), mintShares);
        assertEq(se4626.previewMint(mintShares), p2Preview, "P5 mint == R1 exact-out");

        _wrapExactIn(user, amount);
        uint256 userShares = IERC20(se).balanceOf(user);
        uint256 redeemPreview =
            seIn.previewExchangeIn(IERC20(se), userShares / 2, IERC20(address(loanToken)));
        assertEq(se4626.previewRedeem(userShares / 2), redeemPreview, "P5 redeem == R2 exact-in");

        uint256 withdrawAssets = _u(10);
        uint256 withdrawPreview =
            seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), withdrawAssets);
        assertEq(se4626.previewWithdraw(withdrawAssets), withdrawPreview, "P5 withdraw == R2 exact-out");

        uint256 depPreview = se4626.previewDeposit(amount);
        vm.prank(user);
        uint256 depShares = se4626.deposit(amount, user);
        assertEq(depShares, depPreview, "P5 deposit exec == preview");
    }

    function test_P6_invalidRoute_LtoL_StoS_collateral_random() public {
        IERC20 random_ = IERC20(address(new ERC20Mock()));
        uint256 one = _u(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(loanToken), address(loanToken)
            )
        );
        seIn.previewExchangeIn(IERC20(address(loanToken)), one, IERC20(address(loanToken)));

        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, se, se));
        seIn.previewExchangeIn(IERC20(se), one, IERC20(se));

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(collateralToken), se
            )
        );
        seIn.previewExchangeIn(IERC20(address(collateralToken)), one, IERC20(se));

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(random_), se)
        );
        seOut.previewExchangeOut(random_, IERC20(se), one);
    }
}

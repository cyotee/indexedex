// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {
    TestBase_MorphoBlueStandardExchange
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange.sol";

contract ERC20Mock6 is ERC20Mock {
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/**
 * @title MorphoBlueStandardExchange_Routes
 * @notice P1–P7: In/Out R1/R2 preview==exec, IERC4626 parity, invalid routes, non-18 loanToken.
 */
contract MorphoBlueStandardExchange_Routes is TestBase_MorphoBlueStandardExchange {
    using MorphoBalancesLib for IMorpho;

    uint256 internal constant AMOUNT = 100 ether;

    function test_P1_R1_in_previewEqExec_morphoSupplyUp_idleRounding() public {
        uint256 preview = seIn.previewExchangeIn(IERC20(address(loanToken)), AMOUNT, IERC20(se));
        uint256 supplyBefore = _expectedSupplyOf(se);
        uint256 out = _wrapExactIn(user, AMOUNT);
        assertEq(out, preview, "P1 preview == exec");
        uint256 supplyAfter = _expectedSupplyOf(se);
        assertGe(supplyAfter, supplyBefore + AMOUNT - 1, "P1 morpho expected supply up");
        assertLe(_idleOf(se), 10, "P1 idle ~ rounding");
        assertEq(
            IBasicVault(se).reserveOfToken(address(loanToken)),
            _idleOf(se),
            "P1 reserveOfToken == idle"
        );
        assertEq(se4626.totalAssets(), _idleOf(se) + supplyAfter, "P1 totalAssets == live NAV");
    }

    function test_P2_R1_out_exactShares() public {
        uint256 sharesOut = 50 ether;
        uint256 previewIn = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), sharesOut);
        vm.prank(user);
        uint256 used = seOut.exchangeOut(
            IERC20(address(loanToken)),
            previewIn,
            IERC20(se),
            sharesOut,
            user,
            false,
            _deadline()
        );
        assertEq(used, previewIn, "P2 preview == exec");
        assertEq(IERC20(se).balanceOf(user), sharesOut, "P2 user shares");
    }

    function test_P3_R2_in_redeemShares() public {
        uint256 shares = _wrapExactIn(user, AMOUNT);
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
        _wrapExactIn(user, AMOUNT);
        uint256 assetsOut = 40 ether;
        uint256 previewShares = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), assetsOut);
        uint256 loanBefore = loanToken.balanceOf(user);
        vm.prank(user);
        uint256 used = seOut.exchangeOut(
            IERC20(se),
            previewShares,
            IERC20(address(loanToken)),
            assetsOut,
            user,
            false,
            _deadline()
        );
        assertEq(used, previewShares, "P4 preview == exec");
        assertEq(loanToken.balanceOf(user), loanBefore + assetsOut, "P4 exact assets");
    }

    function test_P5_IERC4626_matches_P1_P4_amounts() public {
        uint256 p1Preview = seIn.previewExchangeIn(IERC20(address(loanToken)), AMOUNT, IERC20(se));
        assertEq(se4626.previewDeposit(AMOUNT), p1Preview, "P5 deposit == R1 exact-in");

        uint256 mintShares = 25 ether;
        uint256 p2Preview = seOut.previewExchangeOut(IERC20(address(loanToken)), IERC20(se), mintShares);
        assertEq(se4626.previewMint(mintShares), p2Preview, "P5 mint == R1 exact-out");

        _wrapExactIn(user, AMOUNT);
        uint256 userShares = IERC20(se).balanceOf(user);
        uint256 redeemPreview = seIn.previewExchangeIn(IERC20(se), userShares / 2, IERC20(address(loanToken)));
        assertEq(se4626.previewRedeem(userShares / 2), redeemPreview, "P5 redeem == R2 exact-in");

        uint256 withdrawAssets = 10 ether;
        uint256 withdrawPreview = seOut.previewExchangeOut(IERC20(se), IERC20(address(loanToken)), withdrawAssets);
        assertEq(se4626.previewWithdraw(withdrawAssets), withdrawPreview, "P5 withdraw == R2 exact-out");

        uint256 depPreview = se4626.previewDeposit(AMOUNT);
        vm.prank(user);
        uint256 depShares = se4626.deposit(AMOUNT, user);
        assertEq(depShares, depPreview, "P5 deposit exec == preview");
    }

    function test_P6_invalidRoute_LtoL_StoS_collateral_random() public {
        IERC20 random_ = IERC20(address(new ERC20Mock()));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(loanToken), address(loanToken)
            )
        );
        seIn.previewExchangeIn(IERC20(address(loanToken)), 1 ether, IERC20(address(loanToken)));

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, se, se)
        );
        seIn.previewExchangeIn(IERC20(se), 1 ether, IERC20(se));

        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(collateralToken), se
            )
        );
        seIn.previewExchangeIn(IERC20(address(collateralToken)), 1 ether, IERC20(se));

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(random_), se)
        );
        seOut.previewExchangeOut(random_, IERC20(se), 1 ether);
    }

    function test_P7_non18_loanToken_mintRedeem_conservation() public {
        ERC20Mock6 loan6 = new ERC20Mock6();
        ERC20Mock coll6 = new ERC20Mock();
        MarketParams memory p = MarketParams({
            loanToken: address(loan6),
            collateralToken: address(coll6),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        morpho.createMarket(p);
        address se6 = _deployVault(morpho, p);
        uint256 amount6 = 1_000_000 * 1e6;
        loan6.setBalance(user, amount6 * 2);
        vm.prank(user);
        loan6.approve(se6, type(uint256).max);

        IStandardExchangeIn in6 = IStandardExchangeIn(se6);
        uint256 preview = in6.previewExchangeIn(IERC20(address(loan6)), amount6, IERC20(se6));
        vm.prank(user);
        uint256 shares = in6.exchangeIn(
            IERC20(address(loan6)), amount6, IERC20(se6), preview, user, false, _deadline()
        );
        assertEq(shares, preview, "P7 wrap preview");

        uint256 redeemPreview = in6.previewExchangeIn(IERC20(se6), shares, IERC20(address(loan6)));
        vm.prank(user);
        uint256 assetsOut = in6.exchangeIn(
            IERC20(se6), shares, IERC20(address(loan6)), 0, user, false, _deadline()
        );
        assertEq(assetsOut, redeemPreview, "P7 redeem preview");
        assertGe(assetsOut + 1, amount6, "P7 conservation +/- 1");
        assertLe(assetsOut, amount6, "P7 no extra mint");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveV3StataStandardExchangeInTarget as StataIn} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol";
import {AaveV3StataStandardExchangeOutTarget as StataOut} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";

/**
 * @title Adversarial_AaveV3StataSE_SecurePull_Decimals
 * @notice I1 / FreeMint / A0–A3 / E1 / E4 / E5 / H2 / H3 on real Crane Stata (not mockCall).
 * @dev J1–J3 N/A. Combo ID is recorded by the concrete suite (`U6` / `U9`).
 */
abstract contract Adversarial_AaveV3StataSE_SecurePull_Decimals is
    TestBase_AaveV3StataStandardExchange_Decimals
{
    function _testAmt() internal pure returns (uint256) {
        return _u(40);
    }

    /// @dev Stata → SE shares for catalog donation / non-dilution / round-trip cases.
    function _mintSeShares(address to_, uint256 underlyingAmt_) internal returns (uint256 shares_) {
        uint256 stataShares_ = _acquireStata(to_, underlyingAmt_);
        vm.startPrank(to_);
        IERC20(realStata).approve(realVault, stataShares_);
        shares_ = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares_, IERC20(realVault), 0, to_, false, _deadline()
        );
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 / FreeMint: pretransfer without delta cannot mint SE shares        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 booked: seed inventory, honest pull books residual via full-set sync; free pretransfer reverts U=0.
    function test_I1_pretransferred_stataInventoryNoInCallTransfer_reverts() public {
        uint256 residual_ = _u(50);
        uint256 pull_ = _u(1);
        uint256 residualStata_ = _acquireStata(address(this), residual_);
        IERC20(realStata).transfer(realVault, residualStata_);

        uint256 pullStata_ = _acquireStata(attacker, pull_);
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, pullStata_);
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), pullStata_, IERC20(realVault), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 supplyBefore_ = IERC20(realVault).totalSupply();
        uint256 attackerSeBefore_ = IERC20(realVault).balanceOf(attacker);
        uint256 invBefore_ = IERC20(realStata).balanceOf(realVault);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualStata_, uint256(0)
            )
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), residualStata_, IERC20(realVault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(realVault).balanceOf(attacker), attackerSeBefore_, "I1: attacker SE unchanged");
        assertEq(IERC20(realStata).balanceOf(realVault), invBefore_, "I1: inventory unmoved");
    }

    /// @notice Free mint path (stata → SE) blocked when inventory is booked (after money-route sync).
    function test_FreeMint_stataToSe_pretransferredInventory_reverts() public {
        uint256 claimedUnderlying_ = _u(25);
        uint256 claimed_ = _acquireStata(address(this), claimedUnderlying_ * 2);
        IERC20(realStata).transfer(realVault, claimed_);
        claimed_ = claimed_ / 2;

        uint256 dust_ = _acquireStata(attacker, _u(1));
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, dust_);
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), dust_, IERC20(realVault), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 supplyBefore_ = IERC20(realVault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), claimed_, IERC20(realVault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "FreeMint blocked");
    }

    /// @notice Free mint via booked base inventory + pretransferred without new unbooked inflow.
    function test_FreeMint_baseToSe_pretransferredInventory_reverts() public {
        uint256 claimed_ = _u(10);
        _fundUnderlying(claimed_, realVault);

        _fundUnderlying(_u(1), attacker);
        vm.startPrank(attacker);
        IERC20(realBase).approve(realVault, _u(1));
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), _u(1), IERC20(realVault), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        uint256 supplyBefore_ = IERC20(realVault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), claimed_, IERC20(realVault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "base FreeMint blocked");
    }

    /// @notice A0: pretransferred with zero inventory / zero delta reverts (no free mint).
    function test_A0_pretransferred_noDelta_reverts() public {
        uint256 claimed_ = _u(1);
        assertEq(IERC20(realStata).balanceOf(realVault), 0, "empty inventory");

        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), claimed_, IERC20(realVault), 0, attacker, true, _deadline()
        );
    }

    /// @notice Positive control: honest !pretransferred stata→SE mints shares.
    function test_I_positive_honestStataPullMint_succeeds() public {
        uint256 amount_ = _testAmt();
        uint256 stataShares_ = _acquireStata(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, stataShares_);
        uint256 out_ = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares_, IERC20(realVault), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(out_, stataShares_, "1:1 first deposit");
        assertEq(IERC20(realVault).balanceOf(attacker), out_, "attacker SE");
    }

    /* ---------------------------------------------------------------------- */
    /*  A1–A3 / E1 / E4 / E5 / H2–H3 residual                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate base underlying without deposit call — no free SE shares.
    function test_A1_donateBase_cannotMintFreeShares() public {
        uint256 amount_ = _testAmt();
        _fundUnderlying(amount_, attacker);
        uint256 sharesBefore_ = IERC20(realVault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(realVault).totalSupply();

        vm.prank(attacker);
        IERC20(realBase).transfer(realVault, amount_);

        assertEq(IERC20(realVault).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "A1: supply unchanged");
        assertEq(IERC20(realBase).balanceOf(realVault), amount_, "A1: base idle");
    }

    /// @notice A2: donate SE shares (product token) to diamond — idle inventory; no free mint/theft.
    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        uint256 shares_ = _mintSeShares(attacker, _testAmt());
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, _testAmt() / 2);
        uint256 supplyBefore_ = IERC20(realVault).totalSupply();
        uint256 victimBefore_ = IERC20(realVault).balanceOf(victim);

        vm.prank(attacker);
        IERC20(realVault).transfer(realVault, donate_);

        assertEq(IERC20(realVault).balanceOf(attacker), shares_ - donate_, "A2 attacker spent donation");
        assertEq(IERC20(realVault).balanceOf(realVault), donate_, "A2 idle product on diamond");
        assertEq(IERC20(realVault).balanceOf(victim), victimBefore_, "A2 victim shares untouched");
        assertEq(victimBefore_, victimShares_, "A2 victim mint stable");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "A2 transfer does not mint/burn");
    }

    /// @notice A3: donate stata reserve without deposit call — no free SE shares.
    function test_A3_donateStata_cannotMintFreeShares() public {
        uint256 amount_ = _testAmt() / 2;
        uint256 stataShares_ = _acquireStata(attacker, amount_);

        uint256 supplyBefore_ = IERC20(realVault).totalSupply();
        uint256 attackerSharesBefore_ = IERC20(realVault).balanceOf(attacker);
        uint256 vaultStataBefore_ = IERC20(realStata).balanceOf(realVault);

        vm.prank(attacker);
        IERC20(realStata).transfer(realVault, stataShares_);

        assertEq(IERC20(realStata).balanceOf(realVault), vaultStataBefore_ + stataShares_, "A3 stata sits idle");
        assertEq(IERC20(realVault).balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    /// @notice E1: stata→SE→stata conservation (no free lunch).
    function test_E1_mintRedeemRoundTrip_bounded() public {
        uint256 paid = _acquireStata(attacker, _testAmt());
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, paid);
        uint256 shares = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), paid, IERC20(realVault), 1, attacker, false, _deadline()
        );
        uint256 expected = Math.mulDiv(shares, IERC20(realStata).balanceOf(realVault), IERC20(realVault).totalSupply());
        uint256 beforeStata = IERC20(realStata).balanceOf(attacker);
        uint256 received = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realVault), shares, IERC20(realStata), expected, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(received, expected, "independent proportional redemption");
        assertEq(IERC20(realStata).balanceOf(attacker) - beforeStata, received, "actual receipt");
        assertEq(IERC20(realVault).balanceOf(attacker), 0, "all user shares burned");
        assertLe(received, paid, "no profitable round trip");
    }

    /// @notice E4: existing SE share holder balance units not diluted by others' mints.
    function test_E4_holderBalance_notDilutedByOthersMint() public {
        uint256 victimShares_ = _mintSeShares(victim, _testAmt());
        assertEq(IERC20(realVault).balanceOf(victim), victimShares_, "victim seeded");

        uint256 attackerShares_ = _mintSeShares(attacker, _testAmt() / 2);
        assertGt(attackerShares_, 0, "attacker mint");
        assertEq(IERC20(realVault).balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    /// @notice E5: zero payment reverts without minting shares or changing inventory.
    function test_E5_zeroAmount_noFreeMint() public {
        uint256 supplyBefore_ = IERC20(realVault).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(StataIn.InvalidStataPayment.selector);
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), 0, IERC20(realVault), 0, attacker, false, _deadline()
        );
        assertEq(IERC20(realVault).balanceOf(attacker), 0, "E5 no free shares");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "E5 supply unchanged");
        assertEq(IERC20(realVault).balanceOf(realVault), 0, "E5 residual vault shares");
    }

    /// @notice E5: unsupported output reports the route-specific error.
    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        ERC20PermitMintableStub junk_ = new ERC20PermitMintableStub("Junk", "JNK", 18, address(this), 0);
        uint256 amount_ = _testAmt() / 10;
        uint256 stataShares_ = _acquireStata(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, stataShares_);
        vm.expectRevert(abi.encodeWithSelector(StataIn.InvalidStataRoute.selector, realStata, address(junk_)));
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares_, IERC20(address(junk_)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
    }

    /// @notice H2: failed exchangeIn (minOut too high) is atomic — attacker inventory unchanged.
    function test_H2_minOutTooHigh_balancesUnchanged() public {
        uint256 amount_ = _testAmt();
        uint256 stataShares_ = _acquireStata(attacker, amount_);
        uint256 stataBefore_ = IERC20(realStata).balanceOf(attacker);
        uint256 seBefore_ = IERC20(realVault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(realVault).totalSupply();

        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, stataShares_);
        vm.expectRevert(abi.encodeWithSelector(StataIn.StataSlippage.selector, stataShares_ + 1, stataShares_));
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares_, IERC20(realVault), stataShares_ + 1, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(IERC20(realStata).balanceOf(attacker), stataBefore_, "H2 stata unchanged");
        assertEq(IERC20(realVault).balanceOf(attacker), seBefore_, "H2 SE unchanged");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(IERC20(realVault).balanceOf(realVault), 0, "H2 no free vault shares");
    }

    /// @notice H3: minOut fail leaves no free residual product on diamond.
    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = _testAmt() / 2;
        uint256 stataShares_ = _acquireStata(attacker, amount_);

        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, stataShares_);
        vm.expectRevert(abi.encodeWithSelector(StataIn.StataSlippage.selector, uint256(type(uint128).max), stataShares_));
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares_, IERC20(realVault), type(uint128).max, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(IERC20(realVault).balanceOf(realVault), 0, "H3 residual vault shares");
        assertEq(IERC20(realVault).balanceOf(attacker), 0, "H3 attacker no free mint");
        assertEq(IERC20(realStata).balanceOf(attacker), stataShares_, "H3 atomic stata");
    }

    /// @notice H2/H3: exchangeOut without SE balance reverts atomically (no free stata drain).
    function test_H2_exchangeOut_withoutShares_balancesUnchanged() public {
        uint256 amountOut_ = _u(1);
        uint256 seeded_ = _acquireStata(address(this), amountOut_ * 2);
        IERC20(realStata).transfer(realVault, seeded_);
        uint256 attackerSe_ = IERC20(realVault).balanceOf(attacker);
        uint256 attackerStata_ = IERC20(realStata).balanceOf(attacker);
        uint256 vaultStata_ = IERC20(realStata).balanceOf(realVault);
        uint256 supplyBefore_ = IERC20(realVault).totalSupply();

        vm.expectRevert(StataOut.InvalidStataPayment.selector);
        IStandardExchangeOut(realVault).previewExchangeOut(IERC20(realVault), IERC20(realStata), amountOut_);
        vm.prank(attacker);
        vm.expectRevert(StataOut.InvalidStataPayment.selector);
        IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), amountOut_, IERC20(realStata), amountOut_, attacker, false, _deadline()
        );

        assertEq(IERC20(realVault).balanceOf(attacker), attackerSe_, "H2 out SE unchanged");
        assertEq(IERC20(realStata).balanceOf(attacker), attackerStata_, "H2 out stata unchanged");
        assertEq(IERC20(realStata).balanceOf(realVault), vaultStata_, "H2 vault stata unmoved");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore_, "H2 out supply unchanged");
        assertEq(IERC20(realVault).balanceOf(realVault), 0, "H2 out residual SE");
    }
}

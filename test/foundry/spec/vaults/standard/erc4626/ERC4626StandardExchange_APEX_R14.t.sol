// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {CappedPausableERC4626} from "contracts/test/stubs/CappedPausableERC4626.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

/// @notice APEX R14 (D22/D31/R14.12/R14.15) on the registry-deployed ERC-4626 SE with a real
///         capped/pausable underlying: booking, sweep, no dilution, local-first exits.
contract ERC4626StandardExchange_APEX_R14_Test is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    CappedPausableERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new CappedPausableERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);
        for (uint256 i; i < 2; ++i) {
            address who = i == 0 ? alice : bob;
            underlying.mint(who, 1_000 ether);
            vm.startPrank(who);
            underlying.approve(se, type(uint256).max);
            underlying.approve(address(protocolVault), type(uint256).max);
            IERC20(address(protocolVault)).approve(se, type(uint256).max);
            vm.stopPrank();
        }
    }

    function _wrap(address who, uint256 amount) internal returns (uint256 shares) {
        vm.prank(who);
        shares = seIn.exchangeIn(IERC20(address(underlying)), amount, IERC20(se), 0, who, false, block.timestamp);
    }

    function _booked() internal view returns (uint256) {
        return IBasicVault(se).reserveOfToken(address(underlying));
    }

    /// @dev D22: capped underlying deposits `min(actualIn, capacity)`, books the remainder, mints on
    ///      the full input and matches the uncapped preview; zero capacity books everything.
    function test_APEX_R14_cappedUnderlying_booksRemainder_mintsOnFullInput() public {
        protocolVault.setDepositCap(60 ether);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(underlying)), 100 ether, IERC20(se));
        uint256 shares = _wrap(alice, 100 ether);
        assertEq(shares, preview, "preview equals execution under the cap");
        assertEq(protocolVault.totalAssets(), 60 ether, "deposited exactly the capacity");
        assertEq(_booked(), 40 ether, "remainder booked as local reserve");
        assertEq(underlying.balanceOf(se), 40 ether, "remainder held");
        assertEq(shares, 100 ether, "first depositor mints 1:1 on the full input");

        protocolVault.setPaused(true);
        uint256 shares2 = _wrap(bob, 10 ether);
        assertApproxEqRel(shares2, 10 ether, 0.002e18, "paused: mints on the full input at unchanged price (usage-fee dilution only)");
        assertEq(_booked(), 50 ether, "paused books everything");
        assertEq(protocolVault.totalAssets(), 60 ether, "no deposit while paused");
    }

    /// @dev D31: the next investing operation sweeps previously booked reserve first, re-reads the
    ///      capacity, then invests the caller's input; only the caller's uninvested part is newly booked.
    function test_APEX_R14_sweepOnNextExchangeIn_80booked_100capacity_50caller() public {
        protocolVault.setPaused(true);
        _wrap(alice, 80 ether);
        assertEq(_booked(), 80 ether);
        protocolVault.setPaused(false);
        protocolVault.setDepositCap(100 ether);
        uint256 aliceValueBefore = seIn.previewExchangeIn(IERC20(se), 80 ether, IERC20(address(underlying)));
        uint256 preview = seIn.previewExchangeIn(IERC20(address(underlying)), 50 ether, IERC20(se));
        uint256 bobShares = _wrap(bob, 50 ether);
        assertEq(bobShares, preview, "preview equals execution across the sweep");
        assertEq(protocolVault.totalAssets(), 100 ether, "80 swept + 20 of the caller invested");
        assertEq(_booked(), 30 ether, "only the caller's uninvested 30 is booked");
        assertApproxEqRel(bobShares, 50 ether, 0.002e18, "shares for the caller's 50 only (usage-fee dilution only)");
        // Only the configured usage fee (dilution mint to feeTo) moves the first holder's entitlement.
        assertApproxEqRel(
            seIn.previewExchangeIn(IERC20(se), 80 ether, IERC20(address(underlying))),
            aliceValueBefore,
            0.001e18,
            "the sweep creates no entitlement change for the first holder beyond the usage fee"
        );
    }

    /// @dev R14.12/R14.14: a receipt deposit after local booking is priced on the full backing, so
    ///      it cannot dilute the locally backed holder.
    function test_APEX_R14_receiptDepositAfterLocalBooking_noDilution() public {
        protocolVault.setDepositCap(50 ether);
        _wrap(alice, 100 ether); // 50 deposited, 50 booked, 100 shares
        uint256 aliceClaimBefore = seIn.previewExchangeIn(IERC20(se), 100 ether, IERC20(address(underlying)));
        assertApproxEqRel(aliceClaimBefore, 100 ether, 0.002e18, "alice is backed by 50 receipts + 50 local (usage-fee dilution only)");
        // Bob mints receipts directly (allowed by the raised cap) and deposits them through the SE.
        protocolVault.setDepositCap(0);
        vm.startPrank(bob);
        uint256 receipts = protocolVault.deposit(100 ether, bob);
        uint256 bobShares = seIn.exchangeIn(IERC20(address(protocolVault)), receipts, IERC20(se), 0, bob, false, block.timestamp);
        vm.stopPrank();
        assertApproxEqRel(bobShares, 100 ether, 0.002e18, "receipt deposit priced on local-plus-receipt backing");
        // Only the configured usage fee (dilution mint to feeTo) moves alice's entitlement.
        assertApproxEqRel(
            seIn.previewExchangeIn(IERC20(se), 100 ether, IERC20(address(underlying))),
            aliceClaimBefore,
            0.001e18,
            "alice's entitlement is unchanged by bob's receipt deposit beyond the usage fee"
        );
    }

    /// @dev R14.15: underlying exits spend local cash first and withdraw only the shortfall;
    ///      receipt exits require actual receipts.
    function test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts() public {
        protocolVault.setDepositCap(50 ether);
        _wrap(alice, 100 ether); // 50 receipts, 50 local
        // Exact-in: 20 shares → 20 underlying, all from local cash.
        uint256 receiptsBefore = IERC20(address(protocolVault)).balanceOf(se);
        uint256 preview = seIn.previewExchangeIn(IERC20(se), 20 ether, IERC20(address(underlying)));
        vm.prank(alice);
        uint256 out = seIn.exchangeIn(IERC20(se), 20 ether, IERC20(address(underlying)), 0, alice, false, block.timestamp);
        assertEq(out, preview, "preview equals execution");
        assertApproxEqRel(out, 20 ether, 0.002e18, "entitlement on the full backing (usage-fee dilution only)");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), receiptsBefore, "receipts untouched: paid from local");
        assertEq(_booked(), 50 ether - out, "local cash spent first");
        // Exact-out: 40 underlying → 30 local + 10 withdrawn from the protocol vault.
        uint256 needShares = seOut.previewExchangeOut(IERC20(se), IERC20(address(underlying)), 40 ether);
        vm.prank(alice);
        uint256 spent = seOut.exchangeOut(IERC20(se), needShares, IERC20(address(underlying)), 40 ether, alice, false, block.timestamp);
        assertEq(spent, needShares);
        assertEq(_booked(), 0, "local cash exhausted first");
        assertApproxEqAbs(IERC20(address(protocolVault)).balanceOf(se), receiptsBefore - (40 ether - (50 ether - out)), 2, "only the shortfall left the vault");
        // Receipt-out beyond held receipts reverts with the inventory error, never paid from local cash.
        protocolVault.setPaused(true);
        _wrap(bob, 100 ether); // all local
        uint256 held = IERC20(address(protocolVault)).balanceOf(se);
        uint256 want = held + 1 ether;
        uint256 sharesNeeded = seOut.previewExchangeOut(IERC20(se), IERC20(address(protocolVault)), want);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC4626StandardExchangeCommon.InsufficientReceiptInventory.selector, want, held));
        seOut.exchangeOut(IERC20(se), sharesNeeded, IERC20(address(protocolVault)), want, bob, false, block.timestamp);
    }

    /// @dev D22 on the exact-output wrap route: capacity precheck and booking apply there too.
    function test_APEX_R14_exactOutWrap_underCap_booksRemainder() public {
        protocolVault.setDepositCap(30 ether);
        uint256 need = seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), 50 ether);
        vm.prank(alice);
        uint256 used = seOut.exchangeOut(IERC20(address(underlying)), need, IERC20(se), 50 ether, alice, false, block.timestamp);
        assertEq(used, need);
        assertEq(IERC20(se).balanceOf(alice), 50 ether, "exact shares");
        assertEq(protocolVault.totalAssets(), 30 ether, "capacity respected");
        assertEq(_booked(), used - 30 ether, "remainder booked");
    }

    /// @dev RC-02 exact-out: non-unit rate, mixed local cash and vault shortfall, exact asset payout.
    function test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue() public {
        _seedNonUnitMixed();
        uint256 due = 1 ether + 2;
        uint256 shortfall = 2;
        uint256 roundedShares = protocolVault.previewWithdraw(shortfall);
        assertGt(protocolVault.previewRedeem(roundedShares), shortfall, "redeeming rounded shares would overpay");

        uint256 need = seOut.previewExchangeOut(IERC20(se), IERC20(address(underlying)), due);
        uint256 before = underlying.balanceOf(alice);
        uint256 receiptsBefore = IERC20(address(protocolVault)).balanceOf(se);
        vm.prank(alice);
        uint256 spent = seOut.exchangeOut(
            IERC20(se), need, IERC20(address(underlying)), due, alice, false, block.timestamp
        );
        assertEq(spent, need, "exact-out burns the quoted shares");
        assertEq(underlying.balanceOf(alice) - before, due, "recipient receives exactly the accounted due");
        assertEq(receiptsBefore - IERC20(address(protocolVault)).balanceOf(se), roundedShares, "fixture charge matches preview");
        assertEq(_booked(), 0, "local cash was spent and the shortfall was not over-withdrawn into book");
    }

    /// @dev RC-02 exact-in: the returned amount is the recipient delta, including a vault shortfall.
    function test_RC02_exactIn_localFirst_nonUnitRate_returnMatchesRecipient() public {
        _seedNonUnitMixed();
        uint256 shares = IERC20(se).balanceOf(alice);
        uint256 preview = seIn.previewExchangeIn(IERC20(se), shares, IERC20(address(underlying)));
        assertGt(preview, _booked(), "exit crosses local cash or prices the non-unit receipt");
        uint256 before = underlying.balanceOf(alice);
        vm.prank(alice);
        uint256 got = seIn.exchangeIn(
            IERC20(se), shares, IERC20(address(underlying)), 0, alice, false, block.timestamp
        );
        assertEq(got, preview, "exact-in return matches preview");
        assertEq(underlying.balanceOf(alice) - before, got, "exact-in recipient delta matches the return");
    }

    function _seedNonUnitMixed() internal {
        protocolVault.setDepositCap(3 ether);
        _wrap(alice, 4 ether);
        underlying.mint(address(this), 2 ether);
        underlying.approve(address(protocolVault), 2 ether);
        protocolVault.simulateYield(2 ether);
        assertEq(_booked(), 1 ether, "capacity left booked local cash");
        assertEq(protocolVault.totalSupply(), 3 ether, "receipt supply is the capped deposit");
        assertEq(protocolVault.totalAssets(), 5 ether, "yield made the receipt rate 5/3");
    }
}

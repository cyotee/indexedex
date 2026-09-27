// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPoolConfigurator} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolConfigurator.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";

/// @notice APEX R14.5 / D22 / D31 / R14.14 / R7.6 on the registry-deployed Stata SE bound to the real
///         Crane Aave V3.6 pool: supply-cap booking, sweep on reopening, local-first exits, exact-out
///         prepaid credit and refund.
contract AaveV3StataStandardExchange_APEX_R14_Test is TestBase_AaveV3StataStandardExchange_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) { return 18; }

    function _setSupplyCap(uint256 wholeTokens) internal {
        vm.prank(roleList.marketOwner);
        contracts.aclManager.addPoolAdmin(address(this));
        IPoolConfigurator(report.poolConfiguratorProxy).setSupplyCap(realBase, wholeTokens);
    }

    function _wrap(uint256 amount) internal returns (uint256 shares) {
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);
        shares = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, address(this), false, _deadline()
        );
    }

    function _booked() internal view returns (uint256) {
        return IBasicVault(realVault).reserveOfToken(realBase);
    }

    /// @dev R14.5: with the real Aave supply cap reached (`maxDeposit == 0`) an underlying-to-SE
    ///      deposit books the full input, mints backed shares matching preview, and makes no supply.
    function test_APEX_R14_supplyCapReached_booksUnderlying_mintsOnFullInput() public {
        uint256 first = _wrap(_u(10));
        _setSupplyCap(1); // 1 whole token, already exceeded by the pool's existing supply
        assertEq(stataTokenV2.maxDeposit(realVault), 0, "capacity closed");
        uint256 stataBefore = IERC20(realStata).balanceOf(realVault);
        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realBase), _u(5), IERC20(realVault));
        uint256 shares = _wrap(_u(5));
        assertEq(shares, preview, "preview equals execution at capacity 0");
        assertApproxEqRel(shares, first / 2, 0.001e18, "shares for the full 5 at the unchanged price");
        assertEq(IERC20(realStata).balanceOf(realVault), stataBefore, "no Stata minted at capacity 0");
        assertEq(_booked(), _u(5), "input booked as local reserve");
        // Local reserve is backing: the SY rate and receipt-unit quotes did not drop.
        assertGt(IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realVault), shares, IERC20(realBase)), 0);
        assertApproxEqRel(
            IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realVault), shares, IERC20(realBase)), _u(5), 0.001e18,
            "locally backed shares keep their underlying value"
        );
    }

    /// @dev R14.15: an underlying exit spends the booked local cash first; a Stata exit beyond held
    ///      receipts reverts with the inventory error.
    function test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts() public {
        _wrap(_u(10));
        _setSupplyCap(1);
        uint256 shares = _wrap(_u(5)); // all booked locally
        uint256 stataBefore = IERC20(realStata).balanceOf(realVault);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realVault), shares / 2, IERC20(realBase), 0, address(this), false, _deadline()
        );
        assertGt(out, 0);
        assertEq(IERC20(realStata).balanceOf(realVault), stataBefore, "paid from local cash, receipts untouched");
        assertEq(_booked(), _u(5) - out, "local reserve spent first");
        // Receipt output needs receipts: ask for more Stata than held.
        uint256 held = IERC20(realStata).balanceOf(realVault);
        uint256 want = held + 1;
        uint256 need = IStandardExchangeOut(realVault).previewExchangeOut(IERC20(realVault), IERC20(realStata), want);
        vm.expectRevert(abi.encodeWithSignature("InsufficientReceiptInventory(uint256,uint256)", want, held));
        IStandardExchangeOut(realVault).exchangeOut(IERC20(realVault), need, IERC20(realStata), want, address(this), false, _deadline());
    }

    /// @dev D31: raising the cap lets the next underlying deposit sweep the booked reserve first.
    function test_APEX_R14_sweepBookedReserveWhenCapacityReopens() public {
        _wrap(_u(10));
        _setSupplyCap(1);
        _wrap(_u(5));
        assertEq(_booked(), _u(5));
        _setSupplyCap(0); // unbounded
        uint256 stataBefore = IERC20(realStata).balanceOf(realVault);
        _wrap(_u(1));
        assertEq(_booked(), 0, "booked reserve swept before the caller's input");
        assertGt(IERC20(realStata).balanceOf(realVault), stataBefore, "swept reserve became Stata");
    }

    /// @dev R7.6 / D15: exact-out with `prepaid_` credits `min(unbooked, maximum)`, refunds
    ///      `credit - spent` to the contract caller, and rejects an EOA.
    function test_APEX_R7_exactOutPrepaid_refundsCreditMinusUsed_eoaRejected() public {
        uint256 shares = _wrap(_u(10));
        uint256 desired = _u(1);
        uint256 required = IStandardExchangeOut(realVault).previewExchangeOut(IERC20(realVault), IERC20(realBase), desired);
        uint256 fatMax = required * 2;
        assertLe(fatMax, shares);
        // EOA with resting self-shares is rejected.
        address eoa = address(0xE0A);
        IERC20(realVault).transfer(eoa, fatMax);
        vm.startPrank(eoa);
        IERC20(realVault).transfer(realVault, fatMax);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardExchangeOut(realVault).exchangeOut(IERC20(realVault), fatMax, IERC20(realBase), desired, eoa, true, _deadline());
        vm.stopPrank();
        // Contract caller: bounded credit and refund.
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        IERC20(realVault).approve(address(caller), fatMax);
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(realVault), fatMax, IERC20(realBase), desired, address(caller), true, _deadline())
        );
        uint256 spent = abi.decode(caller.consumePretransfer(IERC20(realVault), address(this), realVault, fatMax, data), (uint256));
        assertEq(spent, required, "spent equals quote");
        assertEq(IERC20(realVault).balanceOf(address(caller)), fatMax - required, "refund is credit - spent");
        assertEq(IERC20(realBase).balanceOf(address(caller)), desired, "exact output");
    }

    /// @notice RC-03: booked aToken is in the shared adapter backing and the SE preview.
    function test_RC03_bookedAToken_sameBacking_adapterAndSe() public {
        _wrap(_u(10));
        _fundUnderlying(_u(5), address(this));
        IERC20(realBase).approve(address(contracts.poolProxy), _u(5));
        contracts.poolProxy.supply(realBase, _u(5), address(this), 0);
        uint256 donated = IERC20(aToken).balanceOf(address(this));
        assertGt(donated, 0, "hermetic supply minted aToken");
        IERC20(aToken).transfer(realVault, donated);
        _wrap(_u(1));
        uint256 bookedAToken = IBasicVault(realVault).reserveOfToken(aToken);
        assertGt(bookedAToken, 0, "full-set sync booked the aToken");

        uint256 held = IERC20(realStata).balanceOf(realVault);
        uint256 bookedUnderlying = IBasicVault(realVault).reserveOfToken(realBase);
        uint256 excluded = held + (bookedUnderlying == 0 ? 0 : stataTokenV2.convertToShares(bookedUnderlying));
        uint256 included = IERC4626(realVault).totalAssets();
        assertGt(included, excluded, "adapter backing includes booked aToken");

        uint256 depositAmt = stataTokenV2.convertToShares(_u(1));
        if (depositAmt == 0) depositAmt = 1;
        assertEq(
            IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realStata), depositAmt, IERC20(realVault)),
            IERC4626(realVault).convertToShares(depositAmt),
            "SE issuance preview uses the adapter backing"
        );
    }
}

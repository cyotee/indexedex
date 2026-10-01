// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {AaveV3StataStandardExchangeCommon} from "./AaveV3StataStandardExchangeCommon.sol";

/// @notice Exact-output redemption through the same proportional Stata backing as exact-input/SY exits.
contract AaveV3StataStandardExchangeOutTarget is AaveV3StataStandardExchangeCommon, ReentrancyLockModifiers, IStandardExchangeOut {
    using SafeERC20 for IERC20;
    error InvalidStataRoute(address tokenIn, address tokenOut);
    error InvalidStataPayment();
    error StataMaximumExceeded(uint256 maximum, uint256 required);
    /// @notice Wrap exact-out under-delivered the requested SE shares (mirrors the exact-input StataSlippage guard).
    error StataSlippage(uint256 minimum, uint256 received);

    function _stata() internal view returns (IStataTokenV2) {
        return IStataTokenV2(IAaveV3StataStandardVault(address(this)).stataToken());
    }

    function previewExchangeOut(IERC20 in_, IERC20 out_, uint256 amount_) external view returns (uint256) {
        IStataTokenV2 stata_ = _stata();
        // Wrap exact-out: underlying (the SE face) → SE, mint exact SE shares out.
        if (address(in_) == stata_.asset() && address(out_) == address(this)) {
            if (amount_ == 0) return 0;
            return _previewUnderlyingInForSeOut(amount_);
        }
        return _requiredShares(in_, out_, amount_);
    }

    /// @dev Underlying in required to mint exactly `seOut` SE shares (wrap exact-out). Inverse of the
    ///      exact-input wrap: invert the receipt-delta → share proportion (ceil), then the Stata
    ///      deposit (`previewMint`, ceil) so the resulting deposit mints at least `seOut` shares. First
    ///      deposit (supply==0 or backing==0) is 1:1 shares↔stata, exactly as `receiptUnitsForMint`.
    ///      The usage fee is a dilution mint on top and does not raise the underlying required.
    function _previewUnderlyingInForSeOut(uint256 seOut) internal view returns (uint256 underlyingIn) {
        IStataTokenV2 stata_ = _stata();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 backing_ = _stataBacking();
        uint256 stataDelta_ =
            (supply_ == 0 || backing_ == 0) ? seOut : Math.mulDiv(seOut, backing_, supply_, Math.Rounding.Ceil);
        return stata_.previewMint(stataDelta_);
    }

    function _requiredShares(IERC20 in_, IERC20 out_, uint256 amount_) internal view returns (uint256) {
        IStataTokenV2 stata_ = _stata();
        if (address(in_) != address(this) || (address(out_) != address(stata_) && address(out_) != stata_.asset() && address(out_) != stata_.aToken())) {
            revert InvalidStataRoute(address(in_), address(out_));
        }
        if (amount_ == 0) return 0;
        uint256 needed_ = address(out_) == address(stata_) ? amount_ : stata_.previewWithdraw(amount_);
        uint256 backing_ = _stataBacking();
        uint256 supply_ = ERC20Repo._totalSupply();
        // Idle donated receipts do not authorize an unfunded zero-share exit.
        if (supply_ == 0 || backing_ == 0) revert InvalidStataPayment();
        return Math.mulDiv(needed_, supply_, backing_, Math.Rounding.Ceil);
    }

    function exchangeOut(IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address to_, bool prepaid_, uint256 deadline_)
        external nonReentrant returns (uint256 spent_)
    {
        if (amount_ == 0 || to_ == address(0) || block.timestamp > deadline_) revert InvalidStataPayment();
        IStataTokenV2 stataWrap_ = _stata();
        // Wrap exact-out: underlying (the SE face) → SE, mint exactly `amount_` SE shares out. Mirrors
        // the generic ERC-4626 SE OUT target; the existing unwrap routes below are unchanged.
        if (address(in_) == stataWrap_.asset() && address(out_) == address(this)) {
            return _wrapUnderlyingForExactShares(stataWrap_, in_, maximum_, amount_, to_, prepaid_);
        }
        spent_ = _requiredShares(in_, out_, amount_);
        if (spent_ > maximum_) revert StataMaximumExceeded(maximum_, spent_);
        // D15/R7.6: prepaid self-shares are credited up to `min(unbooked, maximum_)` (this vault
        // books no self-shares); `spent_ > credit` reverts; refund only `credit - spent_`.
        uint256 credit_;
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            credit_ = LocalCreditLib.budget(
                LocalCreditLib.available(IERC20(address(this)).balanceOf(address(this)), 0), maximum_
            );
            if (spent_ > credit_) revert ISecurePullErrors.TransferDeltaInsufficient(spent_, credit_);
        }
        _secureSelfBurn(msg.sender, spent_, prepaid_);
        IStataTokenV2 stata_ = _stata();
        if (address(out_) == address(stata_)) {
            uint256 held_ = IERC20(address(stata_)).balanceOf(address(this));
            if (amount_ > held_) revert InsufficientReceiptInventory(amount_, held_);
            out_.safeTransfer(to_, amount_);
        } else if (address(out_) == stata_.asset()) {
            _payUnderlying(stata_, amount_, to_);
        } else {
            // Preserve the existing underlying withdrawal/supply route for exact aToken output.
            _payUnderlying(stata_, amount_, address(this));
            IERC20 base_ = IERC20(stata_.asset());
            base_.forceApprove(address(stata_.POOL()), amount_);
            stata_.POOL().supply(stata_.asset(), amount_, to_, 0);
            base_.forceApprove(address(stata_.POOL()), 0);
        }
        if (credit_ > spent_) IERC20(address(this)).safeTransfer(msg.sender, credit_ - spent_);
        _collectAndForwardRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @dev Wrap exact-out execution (underlying → SE). Inverse of the exact-input wrap: pull only the
    ///      underlying required, invest it into Stata (D22: sweep booked reserve first, then this input;
    ///      any capacity remainder stays booked and is valued at the end-of-route sync), price the full
    ///      credited input at the pre-credit backing, then mint exactly `amount_` SE shares with the
    ///      usage fee. Prepaid underlying is credited up to `min(unbooked, maximum_)` and only the unused
    ///      credit is refunded (D15/R7.6); non-prepaid pulls exactly `spent_`.
    function _wrapUnderlyingForExactShares(
        IStataTokenV2 stata_,
        IERC20 in_,
        uint256 maximum_,
        uint256 amount_,
        address to_,
        bool prepaid_
    ) internal returns (uint256 spent_) {
        spent_ = _previewUnderlyingInForSeOut(amount_);
        if (spent_ > maximum_) revert StataMaximumExceeded(maximum_, spent_);
        uint256 credit_;
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            credit_ = LocalCreditLib.budget(
                LocalCreditLib.available(in_.balanceOf(address(this)), _bookedReserve(in_)), maximum_
            );
            if (spent_ > credit_) revert ISecurePullErrors.TransferDeltaInsufficient(spent_, credit_);
        } else {
            _secureTokenTransfer(in_, spent_, false);
        }
        // Backing before this caller's credit: the pulled/prepaid underlying is unbooked and excluded.
        uint256 backingBefore_ = _stataBacking();
        _investUnderlyingIntoStata(stata_, in_, spent_);
        // D22: value the full credited input, even when Aave capacity books part of it locally.
        uint256 sharesFromDelta_ = _convertStataDeltaToShares(stata_.previewDeposit(spent_), backingBefore_);
        if (sharesFromDelta_ < amount_) revert StataSlippage(amount_, sharesFromDelta_);
        _mintSharesWithUsageFee(to_, amount_);
        if (credit_ > spent_) in_.safeTransfer(msg.sender, credit_ - spent_);
        _collectAndForwardRewards();
        _syncAllExpectedHoldReserves();
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4BufferHookFlexibleLiquidity} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4BufferHookFlexibleLiquidity.sol";

/// @notice Standard Exchange liquidity routes reuse a buffer hook's installed join/exit selectors.
/// @dev Delegate execution preserves the payer, liquidity-owner restriction and host reentrancy lock.
///      Invoke before entering the swap lock; joins and exits acquire that same host lock themselves.
library UniswapV4BufferHookLiquidityRouteLib {
    error InvalidLiquidityRoute();
    error ZeroLiquidityAmount();
    error LiquidityMinimumNotMet(uint256 minimum, uint256 received);
    error LiquidityMaximumExceeded(uint256 maximum, uint256 required);
    error InvalidComponentSupply();
    error ComponentLengthMismatch();
    error InvalidMintFee();
    error ExactNetLiquidityUnavailable();
    error InvalidBootstrapReceipt();

    /// @notice Native units required to back a gross mint against the pre-intake book and supply.
    function componentContribution(uint256 grossLp_, uint256 booked_, uint256 supply_)
        internal pure returns (uint256)
    {
        if (supply_ == 0) revert InvalidComponentSupply();
        return Math.mulDiv(grossLp_, booked_, supply_, Math.Rounding.Ceil);
    }

    /// @notice A zero component does not limit a mint; it is never a denominator.
    /// @dev An unrepresentable positive-component quotient reverts, rather than wrapping.
    function componentMintLimit(uint256 available_, uint256 booked_, uint256 supply_)
        internal pure returns (uint256)
    {
        if (supply_ == 0) revert InvalidComponentSupply();
        return booked_ == 0 ? type(uint256).max : Math.mulDiv(available_, supply_, booked_);
    }

    /// @notice Common gross LP supported by an already assembled, caller-owned basket.
    /// @dev Empty/all-zero books with outstanding supply are not genesis and support no mint.
    ///      Each index is independent native units; this helper never sums components.
    function maxComponentMint(uint256[] memory available_, uint256[] memory booked_, uint256 supply_)
        internal pure returns (uint256 grossLp_)
    {
        if (supply_ == 0) revert InvalidComponentSupply();
        if (available_.length != booked_.length) revert ComponentLengthMismatch();
        bool positive_;
        grossLp_ = type(uint256).max;
        for (uint256 i; i < booked_.length; ++i) {
            if (booked_[i] == 0) continue;
            positive_ = true;
            grossLp_ = Math.min(grossLp_, componentMintLimit(available_[i], booked_[i], supply_));
        }
        if (!positive_) return 0;
    }

    /// @notice Allocate one component using actual pre-burn supply, including locked and fee LP.
    function componentAllocation(uint256 burnedLp_, uint256 booked_, uint256 supply_)
        internal pure returns (uint256)
    {
        if (supply_ == 0 || burnedLp_ > supply_) revert InvalidComponentSupply();
        return Math.mulDiv(burnedLp_, booked_, supply_);
    }

    /// @notice Split the backed mint; the fee is not an additional mint.
    /// @dev Fee activation/configuration remains the family's responsibility. No new fee cap.
    function splitMintFee(uint256 grossLp_, uint256 feeWad_, address feeTo_, bool active_)
        internal pure returns (uint256 netLp_, uint256 feeLp_)
    {
        if (!active_ || feeTo_ == address(0)) return (grossLp_, 0);
        if (feeWad_ > 1e18) revert InvalidMintFee();
        feeLp_ = Math.mulDiv(grossLp_, feeWad_, 1e18);
        netLp_ = grossLp_ - feeLp_;
    }

    /// @notice Smallest gross mint whose rounded split delivers the requested net LP.
    function grossForNet(uint256 netLp_, uint256 feeWad_, address feeTo_, bool active_)
        internal pure returns (uint256 grossLp_)
    {
        if (!active_ || feeTo_ == address(0)) return netLp_;
        if (feeWad_ > 1e18) revert InvalidMintFee();
        if (netLp_ == 0) return 0;
        (uint256 maximumNet_,) = splitMintFee(type(uint256).max, feeWad_, feeTo_, true);
        if (netLp_ > maximumNet_) revert ExactNetLiquidityUnavailable();
        // The feasibility check also excludes a positive net request at a 100% fee.
        grossLp_ = Math.mulDiv(netLp_ - 1, 1e18, 1e18 - feeWad_) + 1;
        (uint256 received_,) = splitMintFee(grossLp_, feeWad_, feeTo_, true);
        (uint256 prior_,) = splitMintFee(grossLp_ - 1, feeWad_, feeTo_, true);
        if (received_ < netLp_ || prior_ >= netLp_) revert ExactNetLiquidityUnavailable();
    }

    /// @notice Subtract the floor once from a family's total seed supply, before splitting fees.
    /// @dev Callers whose seed function already excludes its floor must not call this again.
    function genesisGross(uint256 seedSupply_, uint256 lockedFloor_) internal pure returns (uint256) {
        if (seedSupply_ <= lockedFloor_) revert ZeroLiquidityAmount();
        return seedSupply_ - lockedFloor_;
    }

    /// @notice Five percent of actual incoming shares, rounded down, with retained native shares.
    function bootstrapSplit(uint256 suppliedShares_)
        internal pure returns (uint256 redeemShares_, uint256 retainedShares_)
    {
        redeemShares_ = suppliedShares_ / 20;
        if (redeemShares_ == 0) revert ZeroLiquidityAmount();
        retainedShares_ = suppliedShares_ - redeemShares_;
    }

    /// @notice Require a completed 5% redemption and return only this caller's seed basket.
    /// @dev Balances include ambient custody, but only exact operation deltas are credited.
    function bootstrapReceipt(
        uint256 suppliedShares_,
        ExchangeInAmount.Result memory result_,
        uint256 sharesBefore_,
        uint256 sharesAfter_,
        uint256 pairBefore_,
        uint256 pairAfter_
    ) internal pure returns (uint256 retainedShares_, uint256 localPair_) {
        (uint256 redeemShares_, uint256 retained_) = bootstrapSplit(suppliedShares_);
        if (sharesBefore_ < suppliedShares_ || result_.amountRefunded != 0 || result_.amountOut == 0) {
            revert InvalidBootstrapReceipt();
        }
        ExchangeInAmount.requireReceipt(
            redeemShares_, result_, sharesBefore_, sharesAfter_, pairBefore_, pairAfter_
        );
        return (retained_, result_.amountOut);
    }

    function isLiquidityRoute(IERC20 in_, IERC20 out_) internal view returns (bool) {
        return address(in_) == address(this) || address(out_) == address(this);
    }

    function _isJoin(IERC20 in_, IERC20 out_) private view returns (bool) {
        if (address(in_) == address(out_)) revert InvalidLiquidityRoute();
        if (address(out_) == address(this)) return true;
        if (address(in_) == address(this)) return false;
        revert InvalidLiquidityRoute();
    }

    function previewIn(IERC20 in_, uint256 amount_, IERC20 out_) internal view returns (uint256) {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(address(this));
        return _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactIn(address(in_), amount_)
            : host_.previewExitSingleAssetExactBptIn(address(out_), amount_);
    }

    function previewOut(IERC20 in_, IERC20 out_, uint256 amount_) internal view returns (uint256 required_) {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(address(this));
        required_ = _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactOut(address(in_), amount_)
            : host_.previewExitSingleAssetExactTokenOut(address(out_), amount_);
        // Some hosts deliberately expose unsupported exact-output quote stubs returning zero.
        if (amount_ != 0 && required_ == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    /// @dev A nonzero pair selects an already installed flexible SE-share route.
    function previewInWithSe(IERC20 in_, uint256 amount_, IERC20 out_, address pair_) internal view returns (uint256) {
        if (pair_ == address(0)) return previewIn(in_, amount_, out_);
        IUniswapV4BufferHookFlexibleLiquidity host_ = IUniswapV4BufferHookFlexibleLiquidity(address(this));
        return _isJoin(in_, out_)
            ? host_.previewJoinSingleAssetExactInFlexible(pair_, amount_, true)
            : host_.previewExitSingleAssetExactBptInFlexible(pair_, amount_, true);
    }

    function exchangeInWithSe(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool prepaid_, uint256 deadline_, address pair_
    ) internal returns (uint256 received_) {
        if (pair_ == address(0)) return exchangeIn(in_, amount_, out_, minimum_, receiver_, prepaid_, deadline_);
        if (amount_ == 0) revert ZeroLiquidityAmount();
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        }
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4BufferHookFlexibleLiquidity.joinSingleAssetExactInFlexible, (pair_, amount_, true, receiver_, minimum_, deadline_))
            : abi.encodeCall(IUniswapV4BufferHookFlexibleLiquidity.exitSingleAssetExactBptInFlexible, (pair_, amount_, true, receiver_, minimum_, deadline_));
        received_ = _delegate(call_);
        if (received_ < minimum_) revert LiquidityMinimumNotMet(minimum_, received_);
    }

    function exchangeIn(
        IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool prepaid_, uint256 deadline_
    ) internal returns (uint256 received_) {
        if (amount_ == 0) revert ZeroLiquidityAmount();
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        }
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4SeBufferHook.joinSingleAssetExactIn, (address(in_), amount_, receiver_, minimum_, deadline_))
            : abi.encodeCall(IUniswapV4SeBufferHook.exitSingleAssetExactBptIn, (address(out_), amount_, receiver_, minimum_, deadline_));
        received_ = _delegate(call_);
        if (received_ < minimum_) revert LiquidityMinimumNotMet(minimum_, received_);
    }

    function exchangeOut(
        IERC20 in_, uint256 maximum_, IERC20 out_, uint256 amount_, address receiver_, bool prepaid_, uint256 deadline_
    ) internal returns (uint256 paid_) {
        if (amount_ == 0) revert ZeroLiquidityAmount();
        uint256 quoted_ = previewOut(in_, out_, amount_);
        if (quoted_ > maximum_) revert LiquidityMaximumExceeded(maximum_, quoted_);
        if (prepaid_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            revert ISecurePullErrors.TransferDeltaInsufficient(quoted_, 0);
        }
        bytes memory call_ = _isJoin(in_, out_)
            ? abi.encodeCall(IUniswapV4SeBufferHook.joinSingleAssetExactOut, (address(in_), amount_, receiver_, quoted_, deadline_))
            : abi.encodeCall(IUniswapV4SeBufferHook.exitSingleAssetExactTokenOut, (address(out_), amount_, receiver_, quoted_, deadline_));
        paid_ = _delegate(call_);
        if (paid_ > quoted_) revert LiquidityMaximumExceeded(quoted_, paid_);
    }

    function _delegate(bytes memory call_) private returns (uint256) {
        (bool ok_, bytes memory result_) = address(this).delegatecall(call_);
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        return abi.decode(result_, (uint256));
    }
}

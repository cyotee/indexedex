// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

/// @notice Reads `amountOut` from the widened exchange-in tuple. The refund word is not output.
library ExchangeInAmount {
    error InvalidExchangeReceipt();

    struct Result {
        uint256 amountOut;
        uint256 amountRefunded;
    }

    /// @notice Preserve both native-unit words; the refund is in tokenIn, not tokenOut.
    function previewResult(IStandardExchangeIn exchange_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal view returns (Result memory result_)
    {
        (result_.amountOut, result_.amountRefunded) = exchange_.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
        consumedInput(amountIn_, result_.amountRefunded);
    }

    function exchangeResult(
        IStandardExchangeIn exchange_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (Result memory result_) {
        (result_.amountOut, result_.amountRefunded) = exchange_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_
        );
        consumedInput(amountIn_, result_.amountRefunded);
    }

    /// @dev Transition quotes report consumed input rather than refunded input.
    function fromConsumedInput(uint256 supplied_, uint256 consumed_, uint256 output_)
        internal pure returns (Result memory result_)
    {
        if (consumed_ > supplied_) revert InvalidExchangeReceipt();
        return Result(output_, supplied_ - consumed_);
    }

    function consumedInput(uint256 supplied_, uint256 refunded_) internal pure returns (uint256) {
        if (refunded_ > supplied_) revert InvalidExchangeReceipt();
        return supplied_ - refunded_;
    }

    /// @notice Retained native input, counting the forwarded input and its refund exactly once.
    /// @dev The adapter decides whether this inventory belongs to the pool or the current caller.
    function localCredit(uint256 supplied_, uint256 forwarded_, uint256 refunded_) internal pure returns (uint256) {
        if (forwarded_ > supplied_) revert InvalidExchangeReceipt();
        return supplied_ - consumedInput(forwarded_, refunded_);
    }

    /// @notice Reconcile the tuple against operation-local balances of distinct input/output tokens.
    /// @dev Snapshot after funding, before the exchange, and before any payout or booking.
    ///      Both the output and input refund must be received by the snapshot holder.
    function requireReceipt(
        uint256 supplied_,
        Result memory result_,
        uint256 inputBefore_,
        uint256 inputAfter_,
        uint256 outputBefore_,
        uint256 outputAfter_
    ) internal pure returns (uint256 consumed_) {
        consumed_ = consumedInput(supplied_, result_.amountRefunded);
        if (
            inputBefore_ < supplied_ || inputAfter_ > inputBefore_ || outputAfter_ < outputBefore_
                || inputBefore_ - inputAfter_ != consumed_ || outputAfter_ - outputBefore_ != result_.amountOut
        ) revert InvalidExchangeReceipt();
    }

    function previewOut(IStandardExchangeIn exchange_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal
        view
        returns (uint256 amountOut_)
    {
        (amountOut_,) = exchange_.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }

    function exchangeOut(
        IStandardExchangeIn exchange_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        (amountOut_,) = exchange_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, pretransferred_, deadline_
        );
    }
}

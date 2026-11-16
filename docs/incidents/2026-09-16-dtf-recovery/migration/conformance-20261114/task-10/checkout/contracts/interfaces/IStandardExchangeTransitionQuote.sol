// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Sequential, read-only quotes for a holder's buffered asset inventory.
interface IStandardExchangeTransitionQuote {
    enum Operation {
        DepositExactIn,
        RedeemExactIn,
        WithdrawExactOut,
        ReceiveShares
    }

    error UnsupportedQuoteAsset(address asset);
    error InvalidQuoteState();
    error InsufficientQuoteShares(uint256 required, uint256 available);

    function quoteState(address asset, address holder)
        external view returns (bytes memory state, uint256 holderAssets);

    /// @notice Value shares at a projected state without executing an inventory withdrawal.
    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256 assets);

    function quoteShareBalance(bytes calldata state) external view returns (uint256 shares);

    /// @notice Actual issued supply at the projected state, including funded fees.
    function quoteTotalSupply(bytes calldata state) external view returns (uint256 shares);

    /// @dev Deposits mint shares to holder; withdrawals pay assets to holder.
    /// ReceiveShares credits already-issued shares to the projected holder without
    /// changing supply, backing, fees, or pool state. Both amounts are share units.
    /// The next state includes downstream changes and can feed another transition.
    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (
            bytes memory nextState,
            uint256 amountIn,
            uint256 amountOut,
            uint256 holderAssetsAfter
        );
}

/// @notice Project a separate caller's standard swap/redemption into the asset
/// selected by quoteState, retaining the buffered holder's own SE inventory.
/// @dev The returned state includes provider fees and liquidity/sleeve changes.
/// This optional quote extension does not alter standard route authorization.
interface IStandardExchangeExternalQuote {
    /// @notice Project a separate recipient minting SE shares from an accepted
    /// input. The snapshot asset remains the accounting/output asset; input may
    /// be the other pool currency or the protocol's own receipt/LP token.
    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 sharesOut, uint256 holderAssetsAfter);

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external view returns (bytes memory nextState, uint256 amountOut, uint256 holderAssetsAfter);
}

/// @notice Project an SE-dependent rate without reading the stale live SE book.
interface IStandardExchangeRateQuote {
    function quoteRate(address exchange, address asset, bytes calldata state) external view returns (uint256 rate);
}

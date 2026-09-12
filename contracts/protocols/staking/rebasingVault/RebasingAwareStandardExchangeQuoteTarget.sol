// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";
import {RebasingAwareERC4626Common} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol";

contract RebasingAwareStandardExchangeQuoteTarget is
    IStandardExchangeTransitionQuote,
    IStandardExchangeExternalQuote,
    IStandardExchangeRateQuote
{
    function quoteState(address asset, address holder)
        external
        view
        returns (bytes memory state, uint256 holderAssets)
    {
        return RebasingAwareERC4626Common.snapshotQuoteState(asset, holder);
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256 assets) {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        if (shares == 0) return 0;
        return RebasingAwareERC4626Common.holderValue(shares, RebasingAwareERC4626Common.bookFromQuote(q));
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256 shares) {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        return q.holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256 shares) {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        return q.supply;
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external
        view
        returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 holderAssetsAfter)
    {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        RebasingAwareERC4626Common.Book memory book = RebasingAwareERC4626Common.bookFromQuote(q);
        if (amount == 0) {
            return (abi.encode(q), 0, 0, RebasingAwareERC4626Common.holderValue(q.holderShares, book));
        }
        if (operation == Operation.ReceiveShares) {
            if (q.holderShares + amount < q.holderShares || q.holderShares + amount > q.supply) {
                revert InvalidQuoteState();
            }
            q.holderShares += amount;
            amountIn = amount;
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            if (book.assets == 0 && book.supply > 0) {
                revert IRebasingAwareERC4626.ZeroReserveWithOutstandingShares();
            }
            uint256 shares = RebasingAwareERC4626Common.sharesForDeposit(amount, book);
            RebasingAwareERC4626Common.assertEntryCapacity(book, amount, shares);
            q.assets += amount;
            q.supply += shares;
            q.holderShares += shares;
            amountIn = amount;
            amountOut = shares;
        } else if (operation == Operation.RedeemExactIn) {
            if (amount > q.holderShares) revert InsufficientQuoteShares(amount, q.holderShares);
            uint256 assets = RebasingAwareERC4626Common.assetsForRedeem(amount, book);
            if (assets > q.assets) revert InvalidQuoteState();
            q.assets -= assets;
            q.supply -= amount;
            q.holderShares -= amount;
            amountIn = amount;
            amountOut = assets;
        } else if (operation == Operation.WithdrawExactOut) {
            uint256 shares = RebasingAwareERC4626Common.sharesForWithdraw(amount, book);
            if (shares > q.holderShares) revert InsufficientQuoteShares(shares, q.holderShares);
            if (amount > q.assets) revert InvalidQuoteState();
            q.assets -= amount;
            q.supply -= shares;
            q.holderShares -= shares;
            amountIn = shares;
            amountOut = amount;
        } else {
            revert InvalidQuoteState();
        }
        book = RebasingAwareERC4626Common.bookFromQuote(q);
        RebasingAwareERC4626Common.assertDomain(book);
        holderAssetsAfter = RebasingAwareERC4626Common.holderValue(q.holderShares, book);
        nextState = abi.encode(q);
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amountIn)
        external
        view
        returns (bytes memory nextState, uint256 sharesOut, uint256 holderAssetsAfter)
    {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        RebasingAwareERC4626Common.Book memory book = RebasingAwareERC4626Common.bookFromQuote(q);
        if (amountIn == 0) {
            return (abi.encode(q), 0, RebasingAwareERC4626Common.holderValue(q.holderShares, book));
        }
        if (tokenIn != address(RebasingAwareERC4626Repo._asset())) {
            revert UnsupportedQuoteAsset(tokenIn);
        }
        if (book.assets == 0 && book.supply > 0) {
            revert IRebasingAwareERC4626.ZeroReserveWithOutstandingShares();
        }
        sharesOut = RebasingAwareERC4626Common.sharesForDeposit(amountIn, book);
        RebasingAwareERC4626Common.assertEntryCapacity(book, amountIn, sharesOut);
        q.assets += amountIn;
        q.supply += sharesOut;
        book = RebasingAwareERC4626Common.bookFromQuote(q);
        RebasingAwareERC4626Common.assertDomain(book);
        holderAssetsAfter = RebasingAwareERC4626Common.holderValue(q.holderShares, book);
        nextState = abi.encode(q);
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amountIn)
        external
        view
        returns (bytes memory nextState, uint256 amountOut, uint256 holderAssetsAfter)
    {
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        RebasingAwareERC4626Common.Book memory book = RebasingAwareERC4626Common.bookFromQuote(q);
        if (amountIn == 0) {
            return (abi.encode(q), 0, RebasingAwareERC4626Common.holderValue(q.holderShares, book));
        }
        if (tokenIn != address(this)) revert UnsupportedQuoteAsset(tokenIn);
        uint256 available = q.supply - q.holderShares;
        if (amountIn > available) revert InsufficientQuoteShares(amountIn, available);
        amountOut = RebasingAwareERC4626Common.assetsForRedeem(amountIn, book);
        if (amountOut > q.assets) revert InvalidQuoteState();
        q.assets -= amountOut;
        q.supply -= amountIn;
        book = RebasingAwareERC4626Common.bookFromQuote(q);
        RebasingAwareERC4626Common.assertDomain(book);
        holderAssetsAfter = RebasingAwareERC4626Common.holderValue(q.holderShares, book);
        nextState = abi.encode(q);
    }

    function quoteRate(address exchange, address asset, bytes calldata state)
        external
        view
        returns (uint256 rate)
    {
        if (exchange != address(this)) revert UnsupportedQuoteAsset(exchange);
        IRebasingAwareERC4626.QuoteState memory q = RebasingAwareERC4626Common.decodeQuoteState(state);
        if (asset != q.asset) revert UnsupportedQuoteAsset(asset);
        return RebasingAwareERC4626Common.wadRate(RebasingAwareERC4626Common.bookFromQuote(q));
    }
}

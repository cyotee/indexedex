// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultProjection as Projection} from "./UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultAccounting as Accounting} from "./UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget is IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote,
    IStandardExchangeUnlockContextQuote, IStandardExchangeExactOutputQuantityQuote
{
    function quoteState(address asset_, address holder_) external view returns (bytes memory, uint256) {
        Projection.State memory q = Projection.snapshot(asset_, holder_);
        return (abi.encode(q), Projection.assets(q, q.shares));
    }
    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        return Projection.assets(Projection.decode(state_), shares_);
    }
    function quoteShareBalance(bytes calldata state_) external view returns (uint256) { return Projection.decode(state_).shares; }
    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) { return Projection.decode(state_).book.supply; }
    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory, uint256 amountIn_, uint256 amountOut_, uint256)
    {
        Projection.State memory q;
        (q, amountIn_, amountOut_) = Projection.transition(Projection.decode(state_), operation_, amount_);
        return (abi.encode(q), amountIn_, amountOut_, Projection.assets(q, q.shares));
    }
    function quoteStateWithUnavailableUnlock(bytes calldata state_, address manager_) external view returns (bytes memory) {
        Projection.State memory q = Projection.decode(state_);
        if (manager_ != address(Repo._layout().manager)) return state_;
        q.blocked = true;
        return abi.encode(q);
    }
    function quoteInputForExactShares(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        Projection.State memory q = Projection.prepared(Projection.decode(state_));
        return Accounting.inputForShares(q.book.supply, Projection.value(q), shares_);
    }
    function quoteSharesForExactAssets(bytes calldata state_, uint256 assets_) external view returns (uint256) {
        Projection.State memory q = Projection.prepared(Projection.decode(state_));
        return Accounting.sharesForAssets(q.book.supply, Projection.value(q), assets_);
    }
    function quoteExternalDeposit(bytes calldata state_, address tokenIn_, uint256 amount_)
        external view returns (bytes memory, uint256 shares_, uint256)
    {
        if (tokenIn_ != address(Money.target())) revert UnsupportedQuoteAsset(tokenIn_);
        Projection.State memory q;
        (q,, shares_) = Projection.transition(Projection.decode(state_), Operation.DepositExactIn, amount_);
        q.shares -= shares_;
        return (abi.encode(q), shares_, Projection.assets(q, q.shares));
    }
    function quoteExternalExchange(bytes calldata state_, address tokenIn_, uint256 amount_)
        external view returns (bytes memory, uint256 assets_, uint256)
    {
        if (tokenIn_ != address(this)) revert UnsupportedQuoteAsset(tokenIn_);
        Projection.State memory q = Projection.decode(state_);
        uint256 holderShares = q.shares;
        if (amount_ > q.book.supply - holderShares) revert InsufficientQuoteShares(amount_, q.book.supply - holderShares);
        q.shares = amount_;
        (q,, assets_) = Projection.transition(q, Operation.RedeemExactIn, amount_);
        q.shares = holderShares;
        return (abi.encode(q), assets_, Projection.assets(q, holderShares));
    }
}

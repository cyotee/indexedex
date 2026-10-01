// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @notice Optional unavailable-unlock projection for opaque SE snapshots.
/// @dev No family-specific type, address, storage layout or snapshot decoding. Once support is
/// advertised, snapshot/projection/transition failures propagate without an idle fallback.
library UniswapV4SeBufferHookContextQuoteLib {
    function rateFromState(address exchange, address pair, address provider, bytes memory state) public view returns (uint256) {
        LegLib.ExternalQuote memory q;
        q.exchange = Transition(exchange); q.pair = pair; q.state = state;
        return LegLib.rateAfterExchange(q, pair, provider);
    }

    function rate(address exchange, address pair, address provider, address unavailableManager) external view returns (uint256 value) {
        bytes memory state = snapshot(exchange, pair, address(this), unavailableManager);
        if (state.length != 0) return rateFromState(exchange, pair, provider, state);
        (bool ok, bytes memory data) = provider.staticcall(abi.encodeCall(IRateProvider.getRate, ()));
        if (!ok || data.length != 32) revert LegLib.RateProviderFailed();
        value = abi.decode(data, (uint256));
        if (value == 0) revert LegLib.RateProviderFailed();
    }
    function supported(address exchange) public view returns (bool) {
        (bool ok, bytes memory result) = exchange.staticcall(abi.encodeCall(IERC165.supportsInterface,
            (type(IStandardExchangeUnlockContextQuote).interfaceId)));
        return ok && result.length == 32 && abi.decode(result, (bool));
    }

    function project(address exchange, bytes memory state, address unavailableManager) public view returns (bytes memory) {
        if (unavailableManager == address(0) || !supported(exchange)) return state;
        return IStandardExchangeUnlockContextQuote(exchange).quoteStateWithUnavailableUnlock(state, unavailableManager);
    }

    function snapshot(address exchange, address pair, address holder, address unavailableManager)
        public view returns (bytes memory state)
    {
        if (!supported(exchange)) return bytes("");
        (state,) = Transition(exchange).quoteState(pair, holder);
        return project(exchange, state, unavailableManager);
    }

    /// @dev Only substitute quantity quotes when the projection actually changes context.
    /// A foreign manager or an already-blocked live book retains ordinary preview semantics.
    function exactOutputState(address exchange, address pair, address unavailableManager)
        public view returns (bytes memory state)
    {
        if (unavailableManager == address(0) || exchange == address(0) || exchange == pair || !supported(exchange)) return bytes("");
        (bytes memory live,) = Transition(exchange).quoteState(pair, address(this));
        state = project(exchange, live, unavailableManager);
        if (keccak256(state) == keccak256(live)) return bytes("");
        _requireQuantity(exchange);
    }

    function _requireQuantity(address exchange) private view {
        (bool ok, bytes memory data) = exchange.staticcall(abi.encodeCall(IERC165.supportsInterface,
            (type(IStandardExchangeExactOutputQuantityQuote).interfaceId)));
        if (!ok || data.length != 32 || !abi.decode(data, (bool))) revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function inputForSharesFromState(address exchange, address pair, uint256 shares, bytes memory state)
        public view returns (uint256)
    {
        if (shares == 0 || exchange == pair) return shares;
        if (state.length == 0) return IStandardExchangeOut(exchange).previewExchangeOut(IERC20(pair), IERC20(exchange), shares);
        _requireQuantity(exchange);
        return IStandardExchangeExactOutputQuantityQuote(exchange).quoteInputForExactShares(state, shares);
    }

    function withdrawFromState(address exchange, address pair, uint256 assets, bytes memory state)
        public view returns (uint256 shares)
    {
        if (assets == 0 || exchange == pair) return assets;
        if (state.length == 0) return IStandardExchangeOut(exchange).previewExchangeOut(IERC20(exchange), IERC20(pair), assets);
        _requireQuantity(exchange);
        shares = IStandardExchangeExactOutputQuantityQuote(exchange).quoteSharesForExactAssets(state, assets);
        // The reserve-holding hook must also be able to fund this blocked payout.
        (, uint256 spent,,) = Transition(exchange).quoteTransition(state, Transition.Operation.WithdrawExactOut, assets);
        if (spent != shares) revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function deposit(address exchange, address pair, address holder, uint256 amount, address unavailableManager)
        public view returns (uint256 shares, bytes memory next)
    {
        if (amount == 0) return (0, bytes(""));
        if (exchange == pair) return (amount, bytes(""));
        bytes memory state = snapshot(exchange, pair, holder, unavailableManager);
        if (state.length == 0) return (IStandardExchangeIn(exchange).previewExchangeIn(IERC20(pair), amount, IERC20(exchange)), state);
        (next,, shares,) = Transition(exchange).quoteTransition(state, Transition.Operation.DepositExactIn, amount);
    }

    function redeem(address exchange, address pair, address holder, uint256 shares, address unavailableManager)
        public view returns (uint256 assets, bytes memory next)
    {
        if (shares == 0) return (0, bytes(""));
        if (exchange == pair) return (shares, bytes(""));
        bytes memory state = snapshot(exchange, pair, holder, unavailableManager);
        if (state.length == 0) return (IStandardExchangeIn(exchange).previewExchangeIn(IERC20(exchange), shares, IERC20(pair)), state);
        (next,, assets,) = Transition(exchange).quoteTransition(state, Transition.Operation.RedeemExactIn, shares);
    }

    /// @dev A passthrough wrapper receives its specified shares before redeeming; it owns no reserve.
    function redeemReceived(address exchange, address pair, uint256 shares, address unavailableManager)
        external view returns (uint256 assets)
    {
        if (shares == 0) return 0;
        if (exchange == pair) return shares;
        bytes memory state = snapshot(exchange, pair, address(0), unavailableManager);
        if (state.length == 0) return IStandardExchangeIn(exchange).previewExchangeIn(IERC20(exchange), shares, IERC20(pair));
        (state,,,) = Transition(exchange).quoteTransition(state, Transition.Operation.ReceiveShares, shares);
        (,, assets,) = Transition(exchange).quoteTransition(state, Transition.Operation.RedeemExactIn, shares);
    }

    function withdraw(address exchange, address pair, address holder, uint256 amount, address unavailableManager)
        external view returns (uint256 shares)
    {
        if (amount == 0) return 0;
        if (exchange == pair) return amount;
        bytes memory state = snapshot(exchange, pair, holder, unavailableManager);
        if (state.length == 0) return IStandardExchangeOut(exchange).previewExchangeOut(IERC20(exchange), IERC20(pair), amount);
        _requireQuantity(exchange);
        return IStandardExchangeExactOutputQuantityQuote(exchange).quoteSharesForExactAssets(state, amount);
    }

    /// @dev Quantity only: the caller supplies the required assets during execution.
    function inputForShares(address exchange, address pair, uint256 shares, address unavailableManager)
        external view returns (uint256 assets)
    {
        if (shares == 0) return 0;
        if (exchange == pair) return shares;
        bytes memory state = snapshot(exchange, pair, address(0), unavailableManager);
        if (state.length == 0) return IStandardExchangeOut(exchange).previewExchangeOut(IERC20(pair), IERC20(exchange), shares);
        _requireQuantity(exchange);
        return IStandardExchangeExactOutputQuantityQuote(exchange).quoteInputForExactShares(state, shares);
    }
}

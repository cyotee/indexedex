// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook} from "./interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";

/// @notice Fixed-four caller-funded basket assembly and post-trade component LP acceptance.
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore is
    NativeStandardYieldQuoteBase, UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase
{
    struct JoinBasket {
        ClaimLib.Basket incoming;
        ClaimLib.Basket book;
        uint256 gross;
    }

    function _nativeJoinBasket(uint256[] calldata localAmounts, uint256[] calldata shareAmounts)
        private view returns (ClaimLib.Basket memory incoming)
    {
        _requireAmountsLen4(localAmounts);
        _requireAmountsLen4(shareAmounts);
        for (uint8 i; i < 4; ++i) {
            if (shareAmounts[i] != 0 && Repo._layout().standardExchanges[i] == address(0)) {
                revert SeShareNotBuffered();
            }
            incoming.local[i] = localAmounts[i];
            incoming.shares[i] = shareAmounts[i];
        }
        if (!_isLive()) revert NotLive();
    }

    function _entryPreviewJoinNativeComponents(uint256[] calldata localAmounts, uint256[] calldata shareAmounts)
        internal view returns (uint256 net)
    {
        ClaimLib.Basket memory incoming = _nativeJoinBasket(localAmounts, shareAmounts);
        ClaimLib.Basket memory book;
        // Always pay for imbalance, including deficient but nonzero legs, exactly once.
        (incoming, book) = ClaimLib.previewPreparedNativeJoin(incoming);
        (net,) = _splitMintFee(ClaimLib.grossMint(incoming, book, _totalSupply()));
    }

    function _entryJoinNativeComponents(
        uint256[] calldata localAmounts, uint256[] calldata shareAmounts,
        address to, uint256 minimum, uint256 deadline
    ) internal onlyLiquidityOwner nonReentrant returns (uint256 net)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        JoinBasket memory state;
        state.incoming = _nativeJoinBasket(localAmounts, shareAmounts);
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            if (localAmounts[i] != 0) _pull(l.tokens[i], localAmounts[i]);
            if (shareAmounts[i] != 0) _pull(l.standardExchanges[i], shareAmounts[i]);
        }
        (state.incoming,) = ClaimLib.assemblePreparedNativeJoin(state.incoming);
        // Paid trades change incumbent ownership; conversions use only caller custody.
        state.book = ClaimLib.books();
        state.gross = ClaimLib.grossMint(state.incoming, state.book, _totalSupply());
        if (state.gross == 0) revert ZeroAmount();
        ClaimLib.Basket memory accepted =
            ClaimLib.acceptedBasket(state.incoming, state.book, _totalSupply(), state.gross);
        uint256 fee;
        (net, fee) = _mintBackedLp(to, state.gross);
        if (net < minimum) revert Slippage();
        ClaimLib.acceptBasket(state.incoming, accepted, msg.sender);
        _syncVaultReserves();
        emit IHook.JoinNativeComponents(msg.sender, to, net, localAmounts, shareAmounts, fee);
    }

    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256 amountOut)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            address pair = _liquiditySePair(tokenIn, tokenOut);
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            if (address(tokenOut) == address(this)) return _entryPreviewJoinSingleAssetExactIn(address(tokenIn), amountIn);
            return pair == address(0) ? _quoteExitSingleExactBptIn(address(tokenOut), amountIn)
                : _quoteExitSingleExactBptInFlexible(pair, amountIn, true);
        }
        (amountOut,) = ClaimLib.previewSwapExactInContext(address(tokenIn), address(tokenOut), amountIn, address(0));
    }

    function _previewExchangeInResult(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view returns (uint256 output, uint256 refund)
    {
        if (address(tokenOut) != address(this)) return (_previewExchangeIn(tokenIn, amountIn, tokenOut), 0);
        if (address(tokenIn) == address(this)) revert LiquidityRoute.InvalidLiquidityRoute();
        if (!_isLive() || amountIn == 0) return (0, 0);
        (bool ok, uint8 index, bool asShare) = _tryResolveJoinToken(address(tokenIn));
        if (!ok) return (0, 0);
        JoinBasket memory quote = _singleJoinBasket(index, amountIn, asShare);
        if (quote.gross == 0) return (0, amountIn);
        (output,) = _splitMintFee(quote.gross);
        ClaimLib.Basket memory accepted = ClaimLib.acceptedBasket(quote.incoming, quote.book, _totalSupply(), quote.gross);
        refund = asShare ? quote.incoming.shares[index] - accepted.shares[index]
            : quote.incoming.local[index] - accepted.local[index] + quote.incoming.refunds[index];
    }

    function _liquiditySePair(IERC20 in_, IERC20 out_) internal view returns (address) {
        address edge = address(in_) == address(this) ? address(out_) : address(in_);
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) if (edge != address(0) && edge == l.standardExchanges[i]) return l.tokens[i];
        return address(0);
    }

    function _validateSeShareFlags(bool[] memory flags) internal view {
        if (flags.length != 4) revert ArrayLengthMismatch();
        for (uint8 i; i < 4; ++i) if (flags[i] && Repo._layout().standardExchanges[i] == address(0)) revert SeShareNotBuffered();
    }

    function _needsPreparation(uint256[] memory amounts, ClaimLib.Basket memory book) private pure returns (bool) {
        for (uint8 i; i < 4; ++i) {
            if (amounts[i] == 0 && (book.shares[i] != 0 || book.local[i] != 0)) return true;
        }
        return false;
    }

    function _quoteJoinBasket(uint256[] memory amounts, bool[] memory flags, bool prepare)
        internal view returns (JoinBasket memory quote)
    {
        _requireAmountsLen4(amounts);
        _validateSeShareFlags(flags);
        quote.book = ClaimLib.books();
        if (prepare && _totalSupply() != 0 && _needsPreparation(amounts, quote.book)) {
            (quote.incoming, quote.book) = ClaimLib.previewPreparedJoin(_toFixed4(amounts), flags);
        } else {
            quote.incoming = ClaimLib.previewBasket(_toFixed4(amounts), flags, _totalSupply() == 0);
        }
        quote.gross = ClaimLib.grossMint(quote.incoming, quote.book, _totalSupply());
    }

    function _usedComponents(uint256[] memory amounts, bool[] memory flags, ClaimLib.Basket memory incoming, ClaimLib.Basket memory accepted)
        private pure returns (uint256[] memory used)
    {
        used = new uint256[](4);
        for (uint8 i; i < 4; ++i) {
            uint256 refund = flags[i] ? incoming.shares[i] - accepted.shares[i]
                : incoming.local[i] - accepted.local[i] + incoming.refunds[i];
            used[i] = amounts[i] > refund ? amounts[i] - refund : 0;
        }
    }

    function _joinComponents(uint256[] memory amounts, bool[] memory flags, address to, uint256 minimum, uint256 requestedGross, bool prepare)
        internal returns (uint256 net, uint256[] memory used)
    {
        if (to == address(0)) revert ZeroAddress();
        _requireAmountsLen4(amounts);
        _validateSeShareFlags(flags);
        Repo.Layout storage l = Repo._layout();
        uint256 supply = _totalSupply();
        JoinBasket memory state;
        // Custody from pulls/conversions is caller-owned until paid trades or acceptance.
        state.book = ClaimLib.books();
        for (uint8 i; i < 4; ++i) {
            if (amounts[i] != 0) _pull(flags[i] ? l.standardExchanges[i] : l.tokens[i], amounts[i]);
        }
        if (prepare && supply != 0 && _needsPreparation(amounts, state.book)) {
            (state.incoming, state.book) = ClaimLib.assemblePreparedJoin(_toFixed4(amounts), flags);
        } else state.incoming = ClaimLib.assembleBasket(_toFixed4(amounts), flags, supply == 0);
        // Snapshot the completed paid-swap book, before accepting the contribution.
        state.book = ClaimLib.books();
        state.gross = ClaimLib.grossMint(state.incoming, state.book, supply);
        if (state.gross == 0) revert ZeroAmount();
        if (requestedGross != 0) {
            if (state.gross < requestedGross) revert Slippage();
            state.gross = requestedGross;
        }
        (net,) = _splitMintFee(state.gross);
        if (net < minimum) revert Slippage();
        ClaimLib.Basket memory accepted = ClaimLib.acceptedBasket(state.incoming, state.book, supply, state.gross);
        used = _usedComponents(amounts, flags, state.incoming, accepted);
        uint256 fee;
        (net, fee) = _mintBackedLp(to, state.gross);
        if (supply == 0) _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        if (net < minimum || (requestedGross != 0 && net != minimum)) revert Slippage();
        ClaimLib.acceptBasket(state.incoming, accepted, msg.sender);
        _syncVaultReserves();
        emit IHook.JoinFlexible(msg.sender, to, net, amounts, flags, used, fee);
    }

    function _entryPreviewJoinProportional(uint256[] calldata amounts) internal view returns (uint256 net, uint256[] memory used) {
        return _computeJoinProportionalFlexible(amounts, new bool[](4), _totalSupply());
    }

    function _entryJoinProportional(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net, uint256[] memory used)
    {
        _requireDeadline(deadline);
        (net, used) = _joinComponents(amounts, new bool[](4), to, minimum, 0, false);
    }

    function _computeJoinProportionalFlexible(uint256[] memory amounts, bool[] memory flags, uint256 supply)
        internal view returns (uint256 net, uint256[] memory used)
    {
        JoinBasket memory quote = _quoteJoinBasket(amounts, flags, false);
        if (quote.gross == 0) return (0, new uint256[](4));
        (net,) = _splitMintFee(quote.gross);
        used = _usedComponents(amounts, flags, quote.incoming, ClaimLib.acceptedBasket(quote.incoming, quote.book, supply, quote.gross));
    }

    function _entryPreviewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags)
        internal view returns (uint256 net, uint256[] memory used)
    {
        return _computeJoinProportionalFlexible(amounts, flags, _totalSupply());
    }

    function _entryJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net, uint256[] memory used)
    {
        _requireDeadline(deadline);
        return _joinComponents(amounts, flags, to, minimum, 0, false);
    }

    function _entryPreviewJoinUnbalanced(uint256[] calldata amounts) internal view returns (uint256) {
        (address[] memory tokensIn, uint256[] memory ordered) = _tokensAmountsFromOrdered(amounts);
        return _previewJoinUnbalanced(tokensIn, ordered);
    }

    function _entryPreviewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts) internal view returns (uint256) {
        return _previewJoinUnbalanced(tokensIn, amounts);
    }

    function _previewJoinUnbalanced(address[] memory tokensIn, uint256[] memory amounts) private view returns (uint256 net) {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (_totalSupply() == 0) for (uint8 i; i < 4; ++i) if (!acc.filled[i]) return 0;
        JoinBasket memory quote = _quoteJoinBasket(Math.toDynamic(acc.edge), _seFlags(acc), true);
        (net,) = _splitMintFee(quote.gross);
    }

    function _entryJoinUnbalanced(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        (address[] memory tokensIn, uint256[] memory ordered) = _tokensAmountsFromOrdered(amounts);
        return _joinUnbalanced(tokensIn, ordered, to, minimum, deadline);
    }

    function _entryJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        return _joinUnbalanced(tokensIn, amounts, to, minimum, deadline);
    }

    function _joinUnbalanced(address[] memory tokensIn, uint256[] memory amounts, address to, uint256 minimum, uint256 deadline)
        private returns (uint256 net)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(acc);
        (net,) = _joinComponents(Math.toDynamic(acc.edge), _seFlags(acc), to, minimum, 0, true);
    }

    function _singleJoinBasket(uint8 index, uint256 amount, bool asShare) internal view returns (JoinBasket memory quote) {
        uint256[] memory amounts = new uint256[](4);
        bool[] memory flags = new bool[](4);
        amounts[index] = amount;
        flags[index] = asShare;
        return _quoteJoinBasket(amounts, flags, true);
    }

    function _entryPreviewJoinSingleAssetExactIn(address tokenIn, uint256 amount) internal view returns (uint256 net) {
        if (!_isLive() || amount == 0) return 0;
        (bool ok, uint8 index, bool asShare) = _tryResolveJoinToken(tokenIn);
        if (!ok) return 0;
        (net,) = _splitMintFee(_singleJoinBasket(index, amount, asShare).gross);
    }

    function _entryPreviewDepositSingle(address tokenIn, uint256 amount) internal view returns (uint256) {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amount);
    }

    function _joinSingleAssetExactIn(address tokenIn, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal returns (uint256 net)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!_isLive()) revert NotLive();
        (uint8 index, bool asShare) = _resolveJoinToken(tokenIn);
        return _joinSingle(index, amount, asShare, to, minimum, 0);
    }

    function _joinSingle(uint8 index, uint256 amount, bool asShare, address to, uint256 minimum, uint256 requestedGross)
        private returns (uint256 net)
    {
        uint256[] memory amounts = new uint256[](4);
        bool[] memory flags = new bool[](4);
        amounts[index] = amount;
        flags[index] = asShare;
        (net,) = _joinComponents(amounts, flags, to, minimum, requestedGross, true);
    }

    function _entryJoinSingleAssetExactIn(address tokenIn, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        return _joinSingleAssetExactIn(tokenIn, amount, to, minimum, deadline);
    }

    function _entryDepositSingle(address tokenIn, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        return _joinSingleAssetExactIn(tokenIn, amount, to, minimum, deadline);
    }

    function _entryPreviewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amount, bool asShare)
        internal view returns (uint256 net)
    {
        uint8 index = _tokenIndex(tokenIn);
        if (asShare && Repo._layout().standardExchanges[index] == address(0)) revert SeShareNotBuffered();
        if (!_isLive() || amount == 0) return 0;
        (net,) = _splitMintFee(_singleJoinBasket(index, amount, asShare).gross);
    }

    function _entryPreviewDepositSingleFlexible(address tokenIn, uint256 amount, bool asShare) internal view returns (uint256) {
        return _entryPreviewJoinSingleAssetExactInFlexible(tokenIn, amount, asShare);
    }

    function _joinSingleAssetExactInFlexible(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal returns (uint256)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!_isLive()) revert NotFullBook();
        uint8 index = _tokenIndex(tokenIn);
        if (asShare && Repo._layout().standardExchanges[index] == address(0)) revert SeShareNotBuffered();
        return _joinSingle(index, amount, asShare, to, minimum, 0);
    }

    function _entryJoinSingleAssetExactInFlexible(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        return _joinSingleAssetExactInFlexible(tokenIn, amount, asShare, to, minimum, deadline);
    }

    function _entryDepositSingleFlexible(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256)
    {
        return _joinSingleAssetExactInFlexible(tokenIn, amount, asShare, to, minimum, deadline);
    }

    function _grossForNet(uint256 requested) private view returns (uint256) {
        (bool active, address recipient,, uint256 fee) = _feeOnAndShare();
        return LiquidityRoute.grossForNet(requested, fee, recipient, active);
    }

    function _entryPreviewJoinSingleAssetExactOut(address tokenIn, uint256 requested) internal view returns (uint256) {
        return _quoteSingleJoinExactOut(tokenIn, _grossForNet(requested), type(uint256).max);
    }

    /// @dev Forward-size caller-only SE conversion, not an SE exchangeOut operation.
    /// Every candidate is checked against its paid-swap component book.
    /// The upper bound is always forward-feasible; narrowing need not assume the SE conversion
    /// is globally monotone or promise globally minimal input. Candidates never exceed this max.
    function _quoteSingleJoinExactOut(address tokenIn, uint256 gross, uint256 maximum) private view returns (uint256) {
        if (gross == 0) revert ZeroAmount();
        if (maximum == 0) revert Slippage();
        if (!_isLive()) revert NotFullBook();
        uint8 index = _tokenIndex(tokenIn);
        ClaimLib.Basket memory book = ClaimLib.books();
        uint256 high = FullMath.mulDiv(book.local[index], gross, _totalSupply(), FullMath.Rounding.Ceil);
        if (high == 0) high = 1;
        if (high > maximum) high = maximum;
        uint256 low;
        while (_singleJoinBasket(index, high, false).gross < gross) {
            low = high;
            if (high == maximum) revert Slippage();
            high = high > maximum / 2 ? maximum : high * 2;
        }
        while (high - low > 1) {
            uint256 mid = low + (high - low) / 2;
            if (_singleJoinBasket(index, mid, false).gross >= gross) high = mid;
            else low = mid;
        }
        return high;
    }

    function _entryJoinSingleAssetExactOut(address tokenIn, uint256 requested, address to, uint256 maximum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 amountIn)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 gross = _grossForNet(requested);
        amountIn = _quoteSingleJoinExactOut(tokenIn, gross, maximum);
        if (amountIn > maximum) revert Slippage();
        uint8 index = _tokenIndex(tokenIn);
        uint256[] memory amounts = new uint256[](4);
        amounts[index] = amountIn;
        uint256[] memory used;
        (, used) = _joinComponents(amounts, new bool[](4), to, requested, gross, true);
        return used[index];
    }
}

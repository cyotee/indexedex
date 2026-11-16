// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {IUniswapV4StandardExchangeBalancerQuadStableBufferHook as IHook} from "./interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {UniswapV4BalancerStableLiquidityUnitsCore} from "./UniswapV4BalancerStableLiquidityUnitsCore.sol";

/// @notice Standard aliases share the units engine's native component acceptance.
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore is UniswapV4BalancerStableLiquidityUnitsCore {
    using SafeERC20 for IERC20;

    function _entryPreviewJoinProportional(uint256[] calldata amounts) internal view returns (uint256 shares, uint256[] memory used) {
        return _quoteFlexibleJoin(amounts, new bool[](amounts.length), _totalSupply());
    }

    function _entryJoinProportional(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares, uint256[] memory used)
    {
        _requireDeadline(deadline);
        uint256 supplyBefore = _totalSupply();
        (shares, used) = _joinBasket(amounts, new bool[](amounts.length), to, minimum, 0, false);
        _emitJoin(to, shares, used, supplyBefore);
    }

    function _emitJoin(address to, uint256 shares, uint256[] memory used, uint256 supplyBefore) private {
        int256[] memory deltas = new int256[](used.length);
        for (uint256 i; i < used.length; ++i) deltas[i] = int256(used[i]);
        uint256 gross = _totalSupply() - supplyBefore - (supplyBefore == 0 ? Math.MINIMUM_LIQUIDITY : 0);
        emit IHook.Join(msg.sender, to, shares, deltas, gross - shares);
    }

    function _entryPreviewJoinUnbalanced(uint256[] calldata amounts) internal view returns (uint256 shares) {
        (Basket memory available, Basket memory book) = _previewUnbalancedBasket(amounts, new bool[](amounts.length));
        (shares,) = _previewMint(_basketGross(available, book, _totalSupply()));
    }

    function _entryJoinUnbalanced(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        uint256 supplyBefore = _totalSupply();
        uint256[] memory used;
        (shares, used) = _joinUnbalancedBasket(amounts, new bool[](amounts.length), to, minimum, 0);
        _emitJoin(to, shares, used, supplyBefore);
    }

    /// @dev Paid native-component trades precede the proportional join snapshot.
    function _previewSingleBasket(address token, uint256 amount) internal view returns (Basket memory available, Basket memory book) {
        if (_totalSupply() == 0 || !_bindingIsFullBook()) revert NotFullBook();
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        uint256[] memory amounts = new uint256[](Repo._numTokens());
        bool[] memory flags = new bool[](amounts.length);
        amounts[index] = amount; flags[index] = shareUnit;
        return _previewUnbalancedBasket(amounts, flags);
    }

    function _singleJoin(address token, uint256 amount, address to, uint256 minimum, uint256 grossCap) internal returns (uint256) {
        if (amount < Repo._numTokens()) revert ZeroAmount();
        if (_totalSupply() == 0 || !_bindingIsFullBook()) revert NotFullBook();
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        uint256[] memory amounts = new uint256[](Repo._numTokens());
        bool[] memory flags = new bool[](amounts.length);
        amounts[index] = amount; flags[index] = shareUnit;
        (uint256 shares,) = _joinUnbalancedBasket(amounts, flags, to, minimum, grossCap);
        return shares;
    }

    function _entryPreviewJoinSingleAssetExactIn(address token, uint256 amount) internal view returns (uint256 shares) {
        (shares,) = _previewSingleJoinResult(token, amount);
    }

    function _previewSingleJoinResult(address token, uint256 amount) internal view returns (uint256 shares, uint256 refund) {
        if (amount < Repo._numTokens()) return (0, amount);
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        (Basket memory available, Basket memory book) = _previewSingleBasket(token, amount);
        uint256 gross = _basketGross(available, book, _totalSupply());
        (shares,) = _previewMint(gross);
        Basket memory accepted = _acceptedBasket(book, available, _totalSupply(), gross);
        refund = shareUnit || Repo._layout().standardExchanges[index] == address(0)
            ? available.inventory[index] - accepted.inventory[index]
            : available.local[index] - accepted.local[index];
    }

    function _entryPreviewDepositSingle(address token, uint256 amount) internal view returns (uint256) {
        return _entryPreviewJoinSingleAssetExactIn(token, amount);
    }

    function _entryJoinSingleAssetExactIn(address token, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        uint256 supplyBefore = _totalSupply();
        uint256 inputBefore = IERC20(token).balanceOf(msg.sender);
        shares = _singleJoin(token, amount, to, minimum, 0);
        emit IHook.DepositSingle(msg.sender, to, token, inputBefore - IERC20(token).balanceOf(msg.sender),
            shares, _totalSupply() - supplyBefore - shares);
    }

    function _entryDepositSingle(address token, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        uint256 supplyBefore = _totalSupply();
        uint256 inputBefore = IERC20(token).balanceOf(msg.sender);
        shares = _singleJoin(token, amount, to, minimum, 0);
        emit IHook.DepositSingle(msg.sender, to, token, inputBefore - IERC20(token).balanceOf(msg.sender),
            shares, _totalSupply() - supplyBefore - shares);
    }

    function _entryPreviewJoinSingleAssetExactOut(address token, uint256 net) internal view returns (uint256 amount) {
        if (net == 0) revert ZeroAmount();
        (uint8 i, bool shareUnit) = _indexOfPairOrSe(token);
        uint256 gross = _grossForNet(net);
        uint256 value = Math.singleJoinExactOutAmountIn(_ratedWadAll(), gross, i, _amp(), _totalSupply(), _bindingDexSwapFee());
        if (shareUnit) amount = ClaimLib.nativeForRatedWad(i, value, true);
        else amount = Math.descaleUp(value, Repo._layout().ratedScales[i]);
        // This view has no caller budget. Only return an independently forward-verified amount.
        for (uint256 attempt; attempt < 8; ++attempt) {
            uint256 quoted = _entryPreviewJoinSingleAssetExactIn(token, amount);
            if (quoted >= net) return amount;
            if (quoted == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            uint256 scaled = FixedPointMathLib.fullMulDivUp(amount, net, quoted) + 1;
            // A strict multiplicative step crosses native rounding plateaus.
            // The returned budget is forward-verified, not globally minimal.
            amount = scaled > amount * 2 ? scaled : amount * 2;
        }
        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function _entryJoinSingleAssetExactOut(address token, uint256 net, address to, uint256 maximum, uint256 deadline)
        internal nonReentrant returns (uint256 amount)
    {
        _requireDeadline(deadline);
        if (net == 0) revert ZeroAmount();
        uint256 gross = _grossForNet(net);
        if (_entryPreviewJoinSingleAssetExactIn(token, maximum) < net) revert Slippage();
        // Forward-budget exact net: cap acceptance, refund every unaccepted component.
        uint256 beforeInput = IERC20(token).balanceOf(msg.sender);
        _singleJoin(token, maximum, to, net, gross);
        amount = beforeInput - IERC20(token).balanceOf(msg.sender);
        emit IHook.DepositSingle(msg.sender, to, token, amount, net, gross - net);
    }

    function _entryPreviewExitProportional(uint256 shares) internal view returns (uint256[] memory) {
        return _previewOutputs(_allocatedBasket(shares, _totalSupply()), new bool[](Repo._numTokens()));
    }

    function _entryExitProportional(uint256 shares, address to, uint256[] calldata minimum, uint256 deadline)
        internal nonReentrant returns (uint256[] memory amounts)
    {
        _requireDeadline(deadline);
        amounts = _exitBasket(shares, to, new bool[](Repo._numTokens()), minimum);
        int256[] memory deltas = new int256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) deltas[i] = -int256(amounts[i]);
        emit IHook.Exit(msg.sender, to, shares, deltas, 0);
    }

    function _previewSingleExit(address token, uint256 shares) internal view returns (uint256 output) {
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        Basket memory allocation = _allocatedBasket(shares, _totalSupply());
        Basket memory remaining = _bookBasket();
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < remaining.inventory.length; ++i) {
            remaining.inventory[i] -= allocation.inventory[i]; remaining.local[i] -= allocation.local[i];
            if (l.standardExchanges[i] != address(0)) {
                allocation.states[i] = ContextQuote.snapshot(l.standardExchanges[i], l.tokens[i], address(this), address(0));
            }
        }
        remaining.states = allocation.states;
        remaining.unprojected = allocation.unprojected;
        bool[] memory flags = new bool[](Repo._numTokens());
        flags[index] = shareUnit;
        uint256[] memory pairs = _previewOutputs(allocation, flags);
        output = pairs[index];
        uint256 convertedPair;
        for (uint8 i; i < pairs.length; ++i) {
            if (i == index || pairs[i] == 0) continue;
            uint256 budget = Math.quoteExactInRated(_ratedBasket(remaining), i, index,
                _localInflow(i, Math.applyTradingFeeNet(pairs[i], _bindingDexSwapFee())), _amp());
            uint256 pairBudget = Math.descale(budget, l.ratedScales[index]);
            uint256 local = pairBudget < remaining.local[index] ? pairBudget : remaining.local[index];
            uint256 out;
            if (l.standardExchanges[index] == address(0)) {
                out = pairBudget; remaining.inventory[index] -= out;
            } else {
                uint256 spend = pairBudget > local
                    ? _basketOutputShares(remaining, index, budget - Math.scaleTo(local, l.ratedScales[index])) : 0;
                if (spend > remaining.inventory[index]) revert WouldZeroReserve();
                out = local + _previewOutputConversion(remaining, index, true, spend).amountOut;
                remaining.inventory[index] -= spend; remaining.local[index] -= local;
            }
            if (shareUnit) convertedPair += out;
            else output += out;
            if (l.standardExchanges[i] == address(0)) remaining.inventory[i] += pairs[i];
            else remaining.local[i] += pairs[i];
        }
        if (shareUnit) {
            ExchangeInAmount.Result memory receipt = _previewOutputConversion(remaining, index, false, convertedPair);
            if (receipt.amountRefunded != 0) revert BufferFailed();
            output += receipt.amountOut;
        }
    }

    function _exitSingleAssetFrom(address holder, address token, uint256 shares, address to, uint256 minimum, uint256 deadline, uint256 exactOutput)
        internal returns (uint256 output)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        Basket memory basket = _allocatedBasket(shares, _totalSupply());
        _burnLp(holder, shares); _debitBasket(basket);
        bool[] memory flags = new bool[](Repo._numTokens());
        flags[index] = shareUnit;
        uint256[] memory pairs = _convertOutputs(basket, flags);
        output = pairs[index];
        uint256 convertedPair;
        for (uint8 i; i < pairs.length; ++i) {
            if (i != index && pairs[i] != 0) {
                uint256 received = _tradeBasket(i, index, pairs[i]);
                if (shareUnit) convertedPair += received;
                else output += received;
            }
        }
        if (shareUnit) {
            ExchangeInAmount.Result memory receipt = _convert(index, false, convertedPair);
            if (receipt.amountRefunded != 0) revert BufferFailed();
            output += receipt.amountOut;
        }
        if (output < minimum) revert Slippage();
        if (exactOutput != 0) {
            if (output < exactOutput) revert Slippage();
            uint256 surplus = output - exactOutput;
            if (shareUnit) Repo._layout().seReserves[index] += surplus;
            else Repo._layout().rawReserves[index] += surplus;
            output = exactOutput;
        }
        _syncVaultReserves();
        if (output != 0) IERC20(token).safeTransfer(to, output);
        emit IHook.WithdrawSingle(msg.sender, to, token, output, shares, 0);
    }

    function _entryPreviewExitSingleAssetExactBptIn(address token, uint256 shares) internal view returns (uint256) { return _previewSingleExit(token, shares); }
    function _entryPreviewWithdrawSingle(address token, uint256 shares) internal view returns (uint256) { return _previewSingleExit(token, shares); }
    function _entryExitSingleAssetExactBptIn(address token, uint256 shares, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, token, shares, to, minimum, deadline, 0); }
    function _entryWithdrawSingle(address token, uint256 shares, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, token, shares, to, minimum, deadline, 0); }

    function _entryPreviewExitSingleAssetExactTokenOut(address token, uint256 amount) internal view returns (uint256 shares) {
        (uint8 index, bool shareUnit) = _indexOfPairOrSe(token);
        uint256 rated = shareUnit ? ClaimLib.ratedWadForNativeUp(index, amount) : Math.scaleToUp(amount, Repo._layout().ratedScales[index]);
        shares = Math.singleExitExactTokenOutShares(_ratedWadAll(), rated, index, _amp(), _totalSupply(), _bindingDexSwapFee());
        for (uint256 attempt; attempt < 8; ++attempt) {
            uint256 quoted = _previewSingleExit(token, shares);
            if (quoted >= amount) return shares;
            if (quoted == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            shares = FixedPointMathLib.fullMulDivUp(shares, amount, quoted) + 1;
            if (shares >= _totalSupply()) revert WouldZeroReserve();
        }
        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
    function _entryPreviewWithdrawSingleExactOut(address token, uint256 amount) internal view returns (uint256) { return _entryPreviewExitSingleAssetExactTokenOut(token, amount); }
    function _entryExitSingleAssetExactTokenOut(address token, uint256 amount, address to, uint256 maximum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        shares = _entryPreviewExitSingleAssetExactTokenOut(token, amount);
        if (shares > maximum) revert Slippage();
        _exitSingleAssetFrom(msg.sender, token, shares, to, amount, deadline, amount);
    }
    function _entryWithdrawSingleExactOut(address token, uint256 amount, address to, uint256 maximum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        shares = _entryPreviewExitSingleAssetExactTokenOut(token, amount);
        if (shares > maximum) revert Slippage();
        _exitSingleAssetFrom(msg.sender, token, shares, to, amount, deadline, amount);
    }
}

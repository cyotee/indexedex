// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {IUniswapV4BalancerStableLiquidityUnits as IUnits} from "./interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget as Target} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol";

abstract contract UniswapV4BalancerStableLiquidityUnitsCore is Target {
    using SafeERC20 for IERC20;

    struct Basket {
        uint256[] inventory;
        uint256[] local;
        bytes[] states;
        bool[] unprojected;
        uint256[] pairRefunds;
    }

    function _tradeBasket(uint8 i, uint8 j, uint256 amount) internal returns (uint256 output) {
        Repo.Layout storage l = Repo._layout();
        uint256 inflow = _localInflow(i, Math.applyTradingFeeNet(amount, _bindingDexSwapFee()));
        uint256 shares;
        (output, shares) = ClaimLib.quoteSwapExactIn(i, j, _ratedWadAll(), inflow, _amp());
        uint256 local = shares == 0 ? output : l.rawReserves[j];
        l.rawReserves[j] -= local;
        uint256 actual = local + _unwrapSeShares(j, shares, address(this));
        if (actual < output) revert UnwrapFailed();
        output = actual;
        l.rawReserves[i] += amount;
    }

    function _localInflow(uint8 i, uint256 amount) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0) && l.rateProviders[i] != address(0)) {
            amount = Math.ratedPairUnits(amount, _getRateFailClosed(l.rateProviders[i]), l.invScales[i], l.ratedScales[i]);
        }
        return Math.scaleTo(amount, l.ratedScales[i]);
    }

    function _ratedBasket(Basket memory book) internal view returns (uint256[] memory rated) {
        Repo.Layout storage l = Repo._layout();
        rated = new uint256[](l.tokens.length);
        for (uint8 i; i < rated.length; ++i) {
            rated[i] = _ratedComponent(i, book.inventory[i], book.local[i], book);
        }
    }

    function _ratedComponent(uint8 i, uint256 inventory, uint256 local, Basket memory book) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.rateProviders[i] != address(0)) inventory = Math.ratedPairUnits(inventory,
            _basketRate(book, i), l.standardExchanges[i] == address(0) ? l.invScales[i] : ClaimLib.shareScale(l.standardExchanges[i]), l.ratedScales[i]);
        return Math.scaleTo(inventory + local, l.ratedScales[i]);
    }

    function _basketRate(Basket memory book, uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        return book.states[i].length == 0 ? _getRateFailClosed(l.rateProviders[i])
            : ContextQuote.rateFromState(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], book.states[i]);
    }

    function _basketOutputShares(Basket memory book, uint8 i, uint256 rated) internal view returns (uint256) {
        if (rated == 0) return 0;
        uint256 sharesWad = FixedPointMathLib.fullMulDiv(rated, 1e18, _basketRate(book, i));
        return FixedPointMathLib.fullMulDiv(sharesWad, 1e18, ClaimLib.shareScale(Repo._layout().standardExchanges[i]));
    }

    function _validateUnits(bool[] memory flags) internal view {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.tokens.length) revert InvalidN();
        for (uint256 i; i < flags.length; ++i) if (flags[i] && l.standardExchanges[i] == address(0)) revert InvalidPair();
    }

    function _emptyBasket() internal view returns (Basket memory basket) {
        basket.inventory = new uint256[](Repo._numTokens());
        basket.local = new uint256[](Repo._numTokens());
        basket.states = new bytes[](Repo._numTokens());
        basket.unprojected = new bool[](Repo._numTokens());
        basket.pairRefunds = new uint256[](Repo._numTokens());
    }

    function _bookBasket() internal view returns (Basket memory basket) {
        Repo.Layout storage l = Repo._layout();
        basket = _emptyBasket();
        for (uint8 i; i < l.tokens.length; ++i) {
            basket.inventory[i] = _nativeAt(i);
            if (l.standardExchanges[i] != address(0)) basket.local[i] = l.rawReserves[i];
        }
    }

    function _quoteBook(uint256[] memory amounts, bool[] memory flags) internal view returns (Basket memory book) {
        book = _bookBasket();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < amounts.length; ++i) {
            address se = l.standardExchanges[i];
            if (se == address(0)) continue;
            book.states[i] = ContextQuote.snapshot(se, l.tokens[i], address(this), address(0));
            if (flags[i] && amounts[i] != 0 && book.states[i].length != 0) {
                (book.states[i],,,) = Transition(se).quoteTransition(book.states[i], Transition.Operation.ReceiveShares, amounts[i]);
            }
        }
    }

    function _previewConversion(uint8 i, bool redeem, uint256 amount) internal view returns (ExchangeInAmount.Result memory result) {
        if (amount == 0) return result;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (!redeem && _disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        return ExchangeInAmount.previewResult(IStandardExchangeIn(se), IERC20(redeem ? se : l.tokens[i]), amount, IERC20(redeem ? l.tokens[i] : se));
    }

    function _previewOutputConversion(Basket memory basket, uint8 i, bool redeem, uint256 amount)
        internal view returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        if (basket.unprojected[i]) revert Transition.InvalidQuoteState();
        if (basket.states[i].length == 0) {
            result = _previewConversion(i, redeem, amount);
            if (amount != result.amountRefunded) basket.unprojected[i] = true;
            return result;
        }
        address se = Repo._layout().standardExchanges[i];
        if (!redeem && _disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        uint256 consumed;
        uint256 output;
        (basket.states[i], consumed, output,) = Transition(se).quoteTransition(
            basket.states[i], redeem ? Transition.Operation.RedeemExactIn : Transition.Operation.DepositExactIn, amount
        );
        return ExchangeInAmount.fromConsumedInput(amount, consumed, output);
    }

    /// @dev Forward sizing only selects caller funds; acceptance never uses this estimate as backing.
    function _retainedPair(uint8 i, uint256 amount, Basket memory book) internal view returns (uint256) {
        if (amount == 0) return 0;
        if (book.inventory[i] == 0) return amount;
        if (book.local[i] == 0) return 0;
        uint256 shares = _previewConversionAt(book, i, false, amount).amountOut;
        uint256 needed = FixedPointMathLib.fullMulDivUp(shares, book.local[i], book.inventory[i]);
        return needed == 0 ? 0 : FixedPointMathLib.fullMulDivUp(amount, needed, amount + needed);
    }

    function _redemptionForLocal(uint8 i, uint256 shares, uint256 local, Basket memory book) internal view returns (uint256) {
        if (shares == 0 || book.local[i] == 0) return 0;
        if (book.inventory[i] == 0) return shares;
        uint256 needed = FixedPointMathLib.fullMulDivUp(shares, book.local[i], book.inventory[i]);
        if (local >= needed) return 0;
        uint256 receipt = _previewConversionAt(book, i, true, shares).amountOut;
        if (receipt == 0) revert UnwrapFailed();
        return FixedPointMathLib.fullMulDivUp(shares, needed - local, receipt + needed);
    }

    /// @dev Sizing probes must not advance the sequential quote state.
    function _previewConversionAt(Basket memory book, uint8 i, bool redeem, uint256 amount)
        internal view returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        if (book.states[i].length == 0) return _previewConversion(i, redeem, amount);
        address se = Repo._layout().standardExchanges[i];
        if (!redeem && _disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        (, uint256 consumed, uint256 output,) = Transition(se).quoteTransition(
            book.states[i], redeem ? Transition.Operation.RedeemExactIn : Transition.Operation.DepositExactIn, amount
        );
        return ExchangeInAmount.fromConsumedInput(amount, consumed, output);
    }

    function _previewBasket(uint256[] memory amounts, bool[] memory flags, Basket memory book, bool first)
        internal view returns (Basket memory basket)
    {
        _requireAmountsLength(amounts);
        _validateUnits(flags);
        Repo.Layout storage l = Repo._layout();
        basket = _emptyBasket();
        basket.states = book.states;
        basket.unprojected = book.unprojected;
        for (uint8 i; i < amounts.length; ++i) {
            if (l.standardExchanges[i] == address(0)) { basket.inventory[i] = amounts[i]; continue; }
            if (first) {
                uint256 incoming = amounts[i];
                if (!flags[i]) {
                    ExchangeInAmount.Result memory deposit = _previewOutputConversion(book, i, false, incoming);
                    incoming = deposit.amountOut;
                    basket.pairRefunds[i] = deposit.amountRefunded;
                }
                (uint256 spend, uint256 retained) = Components.bootstrapSplit(incoming);
                ExchangeInAmount.Result memory receipt = _previewOutputConversion(book, i, true, spend);
                if (receipt.amountRefunded != 0 || receipt.amountOut == 0) revert UnwrapFailed();
                basket.inventory[i] = retained;
                basket.local[i] = receipt.amountOut;
                continue;
            }
            if (flags[i]) basket.inventory[i] = amounts[i];
            else {
                uint256 retained = _retainedPair(i, amounts[i], book);
                ExchangeInAmount.Result memory receipt = _previewOutputConversion(book, i, false, amounts[i] - retained);
                basket.inventory[i] = receipt.amountOut;
                basket.local[i] = retained + receipt.amountRefunded;
            }
            uint256 spend = flags[i] ? _redemptionForLocal(i, basket.inventory[i], basket.local[i], book) : 0;
            if (spend != 0) {
                ExchangeInAmount.Result memory receipt = _previewOutputConversion(book, i, true, spend);
                basket.inventory[i] -= spend - receipt.amountRefunded;
                basket.local[i] += receipt.amountOut;
            }
        }
    }

    function _assembleBasket(uint256[] memory amounts, bool[] memory flags, Basket memory book, bool first)
        internal returns (Basket memory basket)
    {
        Repo.Layout storage l = Repo._layout();
        basket = _emptyBasket();
        for (uint8 i; i < amounts.length; ++i) {
            if (l.standardExchanges[i] == address(0)) { basket.inventory[i] = amounts[i]; continue; }
            if (first) {
                uint256 incoming = amounts[i];
                if (!flags[i]) {
                    ExchangeInAmount.Result memory deposit = _convert(i, false, incoming);
                    incoming = deposit.amountOut;
                    basket.pairRefunds[i] = deposit.amountRefunded;
                }
                (uint256 spend, uint256 retained) = Components.bootstrapSplit(incoming);
                ExchangeInAmount.Result memory receipt = _convert(i, true, spend);
                if (receipt.amountRefunded != 0 || receipt.amountOut == 0) revert UnwrapFailed();
                basket.inventory[i] = retained;
                basket.local[i] = receipt.amountOut;
                continue;
            }
            if (flags[i]) basket.inventory[i] = amounts[i];
            else {
                uint256 retained = _retainedPair(i, amounts[i], book);
                ExchangeInAmount.Result memory receipt = _convert(i, false, amounts[i] - retained);
                basket.inventory[i] = receipt.amountOut;
                basket.local[i] = retained + receipt.amountRefunded;
            }
            uint256 spend = flags[i] ? _redemptionForLocal(i, basket.inventory[i], basket.local[i], book) : 0;
            if (spend != 0) {
                ExchangeInAmount.Result memory receipt = _convert(i, true, spend);
                basket.inventory[i] -= spend - receipt.amountRefunded;
                basket.local[i] += receipt.amountOut;
            }
        }
    }

    function _basketGross(Basket memory basket, Basket memory book, uint256 supply) internal view returns (uint256 gross) {
        if (supply == 0) {
            if (!Math.isFullBookReserves(basket.inventory)) revert NotFullBook();
            return Math.firstMintShares(_initialLiquidityValues(basket.inventory, new bool[](basket.inventory.length)), _amp());
        }
        uint256[] memory available = new uint256[](basket.inventory.length * 2);
        uint256[] memory booked = new uint256[](available.length);
        for (uint256 i; i < basket.inventory.length; ++i) {
            available[2 * i] = basket.inventory[i]; available[2 * i + 1] = basket.local[i];
            booked[2 * i] = book.inventory[i]; booked[2 * i + 1] = book.local[i];
        }
        return Components.maxComponentMint(available, booked, supply);
    }

    function _acceptedBasket(Basket memory book, Basket memory available, uint256 supply, uint256 gross)
        internal pure returns (Basket memory accepted)
    {
        if (supply == 0) return available;
        accepted.inventory = new uint256[](book.inventory.length);
        accepted.local = new uint256[](book.inventory.length);
        for (uint256 i; i < book.inventory.length; ++i) {
            accepted.inventory[i] = Components.componentContribution(gross, book.inventory[i], supply);
            accepted.local[i] = Components.componentContribution(gross, book.local[i], supply);
        }
    }

    function _quoteFlexibleJoin(uint256[] memory amounts, bool[] memory flags, uint256 supply)
        internal view returns (uint256 shares, uint256[] memory used)
    {
        _requireAmountsLength(amounts); _validateUnits(flags);
        Basket memory book = _quoteBook(amounts, flags);
        Basket memory available = _previewBasket(amounts, flags, book, supply == 0);
        uint256 gross = _basketGross(available, book, supply);
        (shares,) = _previewMint(gross);
        Basket memory accepted = _acceptedBasket(book, available, supply, gross);
        used = _usedInputs(amounts, flags, available, accepted);
    }

    function _usedInputs(uint256[] memory amounts, bool[] memory flags, Basket memory available, Basket memory accepted)
        internal view returns (uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        used = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            uint256 refund = flags[i] || l.standardExchanges[i] == address(0)
                ? available.inventory[i] - accepted.inventory[i] : available.local[i] - accepted.local[i];
            if (!flags[i]) refund += available.pairRefunds[i];
            used[i] = amounts[i] > refund ? amounts[i] - refund : 0;
        }
    }

    function _commitBasket(Basket memory available, Basket memory accepted, address payer) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            address se = l.standardExchanges[i];
            if (se == address(0)) l.rawReserves[i] += accepted.inventory[i];
            else { l.seReserves[i] += accepted.inventory[i]; l.rawReserves[i] += accepted.local[i]; }
        }
        for (uint256 i; i < l.tokens.length; ++i) {
            address se = l.standardExchanges[i];
            uint256 refund = available.inventory[i] - accepted.inventory[i];
            if (refund != 0) IERC20(se == address(0) ? l.tokens[i] : se).safeTransfer(payer, refund);
            refund = available.local[i] - accepted.local[i];
            refund += available.pairRefunds[i];
            if (refund != 0) IERC20(l.tokens[i]).safeTransfer(payer, refund);
        }
    }

    function _joinBasket(uint256[] memory amounts, bool[] memory flags, address to, uint256 minimum, uint256 grossCap, bool funded)
        internal returns (uint256 shares, uint256[] memory used)
    {
        if (to == address(0)) revert ZeroAddress();
        _requireAmountsLength(amounts); _validateUnits(flags);
        uint256 supply = _totalSupply();
        Basket memory book = _bookBasket();
        Repo.Layout storage l = Repo._layout();
        if (!funded) for (uint256 i; i < amounts.length; ++i) _pull(flags[i] ? l.standardExchanges[i] : l.tokens[i], amounts[i]);
        Basket memory available = _assembleBasket(amounts, flags, book, supply == 0);
        uint256 gross = _basketGross(available, book, supply);
        if (grossCap != 0) { if (gross < grossCap) revert Slippage(); gross = grossCap; }
        (shares,) = _previewMint(gross);
        if (shares == 0 || shares < minimum) revert Slippage();
        Basket memory accepted = _acceptedBasket(book, available, supply, gross);
        used = _usedInputs(amounts, flags, available, accepted);
        _mintBacked(to, gross);
        if (supply == 0) _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        _commitBasket(available, accepted, msg.sender);
        _syncVaultReserves();
    }

    function _entryPreviewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags)
        internal view returns (uint256 shares, uint256[] memory used)
    { return _quoteFlexibleJoin(amounts, flags, _totalSupply()); }

    function _entryJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares, uint256[] memory used)
    {
        _requireDeadline(deadline);
        (shares, used) = _joinBasket(amounts, flags, to, minimum, 0, false);
        emit IUnits.JoinFlexible(msg.sender, to, shares, used, flags);
    }

    function _allocatedBasket(uint256 shares, uint256 supply) internal view returns (Basket memory basket) {
        if (shares == 0) revert ZeroAmount();
        basket = _bookBasket();
        for (uint256 i; i < basket.inventory.length; ++i) {
            basket.inventory[i] = Components.componentAllocation(shares, basket.inventory[i], supply);
            basket.local[i] = Components.componentAllocation(shares, basket.local[i], supply);
        }
    }

    function _previewOutputs(Basket memory basket, bool[] memory flags) internal view returns (uint256[] memory amounts) {
        Repo.Layout storage l = Repo._layout();
        amounts = new uint256[](l.tokens.length);
        for (uint8 i; i < amounts.length; ++i) {
            if (l.standardExchanges[i] == address(0)) amounts[i] = basket.inventory[i];
            else if (flags[i]) {
                ExchangeInAmount.Result memory receipt = _previewOutputConversion(basket, i, false, basket.local[i]);
                if (receipt.amountRefunded != 0) revert BufferFailed();
                amounts[i] = basket.inventory[i] + receipt.amountOut;
            } else {
                ExchangeInAmount.Result memory receipt = _previewOutputConversion(basket, i, true, basket.inventory[i]);
                if (receipt.amountRefunded != 0) revert UnwrapFailed();
                amounts[i] = basket.local[i] + receipt.amountOut;
            }
        }
    }

    function _debitBasket(Basket memory basket) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            if (l.standardExchanges[i] == address(0)) l.rawReserves[i] -= basket.inventory[i];
            else { l.seReserves[i] -= basket.inventory[i]; l.rawReserves[i] -= basket.local[i]; }
        }
    }

    function _convertOutputs(Basket memory basket, bool[] memory flags) internal returns (uint256[] memory amounts) {
        Repo.Layout storage l = Repo._layout();
        amounts = new uint256[](l.tokens.length);
        for (uint8 i; i < amounts.length; ++i) {
            if (l.standardExchanges[i] == address(0)) amounts[i] = basket.inventory[i];
            else {
                uint256 input = flags[i] ? basket.local[i] : basket.inventory[i];
                ExchangeInAmount.Result memory receipt = _convert(i, !flags[i], input);
                if (receipt.amountRefunded != 0 || (input != 0 && receipt.amountOut == 0)) revert UnwrapFailed();
                amounts[i] = (flags[i] ? basket.inventory[i] : basket.local[i]) + receipt.amountOut;
            }
        }
    }

    function _exitBasket(uint256 shares, address to, bool[] memory flags, uint256[] memory minimum)
        internal returns (uint256[] memory amounts)
    {
        if (to == address(0)) revert ZeroAddress();
        _validateUnits(flags); _requireAmountsLength(minimum);
        Basket memory basket = _allocatedBasket(shares, _totalSupply());
        _burnLp(msg.sender, shares);
        _debitBasket(basket);
        amounts = _convertOutputs(basket, flags);
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < amounts.length; ++i) {
            if (amounts[i] < minimum[i]) revert Slippage();
            if (amounts[i] != 0) IERC20(flags[i] ? l.standardExchanges[i] : l.tokens[i]).safeTransfer(to, amounts[i]);
        }
        _syncVaultReserves();
    }

    function _entryPreviewExitProportionalFlexible(uint256 shares, bool[] calldata flags) internal view returns (uint256[] memory) {
        _validateUnits(flags);
        return _previewOutputs(_allocatedBasket(shares, _totalSupply()), flags);
    }

    function _entryExitProportionalFlexible(uint256 shares, address to, bool[] calldata flags, uint256[] calldata minimum, uint256 deadline)
        internal nonReentrant returns (uint256[] memory amounts)
    {
        _requireDeadline(deadline);
        amounts = _exitBasket(shares, to, flags, minimum);
        emit IUnits.ExitFlexible(msg.sender, to, shares, amounts, flags);
    }

    function _orderedInputs(address[] memory tokens_, uint256[] memory amounts)
        internal view returns (uint256[] memory ordered, bool[] memory flags)
    {
        uint256 n = Repo._numTokens();
        if (tokens_.length == 0 || tokens_.length != amounts.length || tokens_.length > n) revert InvalidN();
        ordered = new uint256[](n); flags = new bool[](n);
        uint256 seen;
        for (uint256 i; i < tokens_.length; ++i) {
            (uint8 index, bool shareUnit) = _indexOfPairOrSe(tokens_[i]);
            if (seen & (1 << index) != 0) revert InvalidPair();
            seen |= 1 << index; ordered[index] = amounts[i]; flags[index] = shareUnit;
        }
    }

    /// @dev Rates size paid trades only. LP backing is checked independently in native components.
    function _prepareUnbalanced(Basket memory available, Basket memory book) internal view {
        uint256 n = available.inventory.length;
        uint256[] memory values = _ratedBasket(available);
        uint256[] memory rated = _ratedBasket(book);
        uint256 totalValue;
        uint256 totalBook;
        for (uint8 i; i < n; ++i) {
            totalValue += values[i];
            totalBook += rated[i];
        }
        if (totalValue == 0) return;
        if (totalBook == 0) revert NotFullBook();
        uint256[] memory excess = new uint256[](n);
        uint256[] memory deficit = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            uint256 target = FixedPointMathLib.fullMulDiv(totalValue, rated[i], totalBook);
            if (values[i] > target) excess[i] = values[i] - target;
            else deficit[i] = target - values[i];
        }
        for (uint256 i; i < n; ++i) {
            uint256 inventory = available.inventory[i];
            uint256 local = available.local[i];
            for (uint256 j; j < n && excess[i] != 0; ++j) {
                uint256 value = excess[i] < deficit[j] ? excess[i] : deficit[j];
                if (value == 0) continue;
                uint256 soldInventory = FixedPointMathLib.fullMulDiv(inventory, value, values[i]);
                uint256 soldLocal = FixedPointMathLib.fullMulDiv(local, value, values[i]);
                if (soldInventory != 0 || soldLocal != 0) {
                    _prepareInKindTrade(available, book, uint8(i), uint8(j), soldInventory, soldLocal);
                }
                excess[i] -= value;
                deficit[j] -= value;
            }
        }
    }

    /// @dev A paid in-kind swap changes ownership, not SE supply. No redemption is projected.
    function _prepareInKindTrade(Basket memory available, Basket memory book, uint8 i, uint8 j, uint256 inventory, uint256 local)
        internal view
    {
        uint256[] memory rated = _ratedBasket(book);
        uint256 inflow = _ratedComponent(i, inventory, local, book);
        if (inflow == 0) return;
        uint256 budget = Math.quoteExactInRated(rated, i, j,
            Math.applyTradingFeeNet(inflow, _bindingDexSwapFee()), _amp());
        if (budget >= rated[j]) revert WouldZeroReserve();
        Repo.Layout storage l = Repo._layout();
        uint256 scale = l.standardExchanges[j] == address(0) ? l.invScales[j] : ClaimLib.shareScale(l.standardExchanges[j]);
        uint256 outputValue = Math.scaleToUp(book.inventory[j], scale);
        if (l.rateProviders[j] != address(0)) outputValue = FixedPointMathLib.fullMulDivUp(outputValue, _basketRate(book, j), 1e18);
        outputValue += Math.scaleToUp(book.local[j], l.ratedScales[j]);
        // Upper-valued denominator and downward native slices cannot overpay the curve budget.
        uint256 boughtInventory = FixedPointMathLib.fullMulDiv(book.inventory[j], budget, outputValue);
        uint256 boughtLocal = FixedPointMathLib.fullMulDiv(book.local[j], budget, outputValue);
        if (boughtInventory == 0 && boughtLocal == 0) return;
        available.inventory[i] -= inventory;
        available.local[i] -= local;
        book.inventory[i] += inventory;
        book.local[i] += local;
        book.inventory[j] -= boughtInventory;
        book.local[j] -= boughtLocal;
        available.inventory[j] += boughtInventory;
        available.local[j] += boughtLocal;
    }

    function _previewUnbalancedBasket(uint256[] memory amounts, bool[] memory flags)
        internal view returns (Basket memory available, Basket memory book)
    {
        _requireAmountsLength(amounts); _validateUnits(flags);
        book = _quoteBook(amounts, flags);
        if (_totalSupply() == 0) return (_previewBasket(amounts, flags, book, true), book);
        if (!_bindingIsFullBook()) revert NotFullBook();
        available = _previewBasket(amounts, flags, book, false);
        _prepareUnbalanced(available, book);
    }

    function _joinUnbalancedBasket(uint256[] memory amounts, bool[] memory flags, address to, uint256 minimum, uint256 cap)
        internal returns (uint256 shares, uint256[] memory used)
    {
        if (_totalSupply() == 0) return _joinBasket(amounts, flags, to, minimum, cap, false);
        if (to == address(0)) revert ZeroAddress();
        _requireAmountsLength(amounts); _validateUnits(flags);
        if (!_bindingIsFullBook()) revert NotFullBook();
        Repo.Layout storage l = Repo._layout();
        uint256[] memory beforeInput = new uint256[](amounts.length);
        for (uint8 i; i < amounts.length; ++i) {
            address token = flags[i] ? l.standardExchanges[i] : l.tokens[i];
            beforeInput[i] = IERC20(token).balanceOf(msg.sender);
            _pull(token, amounts[i]);
        }
        Basket memory book = _bookBasket();
        Basket memory available = _assembleBasket(amounts, flags, book, false);
        _prepareUnbalanced(available, book);
        // Complete paid ownership transfers before taking the mint's component snapshot.
        for (uint256 i; i < amounts.length; ++i) {
            if (l.standardExchanges[i] == address(0)) l.rawReserves[i] = book.inventory[i];
            else { l.seReserves[i] = book.inventory[i]; l.rawReserves[i] = book.local[i]; }
        }
        book = _bookBasket();
        uint256 supply = _totalSupply();
        uint256 gross = _basketGross(available, book, supply);
        if (cap != 0) { if (gross < cap) revert Slippage(); gross = cap; }
        (shares,) = _previewMint(gross);
        if (shares == 0 || shares < minimum) revert Slippage();
        Basket memory accepted = _acceptedBasket(book, available, supply, gross);
        _mintBacked(to, gross);
        _commitBasket(available, accepted, msg.sender);
        _syncVaultReserves();
        used = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            uint256 afterInput = IERC20(flags[i] ? l.standardExchanges[i] : l.tokens[i]).balanceOf(msg.sender);
            used[i] = beforeInput[i] > afterInput ? beforeInput[i] - afterInput : 0;
        }
    }

    function _entryPreviewJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts) internal view returns (uint256 shares) {
        (uint256[] memory ordered, bool[] memory flags) = _orderedInputs(tokens_, amounts);
        (Basket memory available, Basket memory book) = _previewUnbalancedBasket(ordered, flags);
        (shares,) = _previewMint(_basketGross(available, book, _totalSupply()));
    }

    function _entryJoinUnbalanced(address[] calldata tokens_, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        (uint256[] memory ordered, bool[] memory flags) = _orderedInputs(tokens_, amounts);
        uint256[] memory used;
        (shares, used) = _joinUnbalancedBasket(ordered, flags, to, minimum, 0);
        emit IUnits.JoinFlexible(msg.sender, to, shares, used, flags);
    }
}

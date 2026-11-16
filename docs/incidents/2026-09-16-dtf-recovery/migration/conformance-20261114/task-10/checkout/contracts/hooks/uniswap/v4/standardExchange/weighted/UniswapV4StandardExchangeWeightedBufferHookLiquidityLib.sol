// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from "./UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Math} from "./UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPullLib as PullLib} from "./UniswapV4StandardExchangeWeightedBufferHookPullLib.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as IHook} from "./interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @notice Weighted-family component acceptance and caller-only basket conversion.
library UniswapV4StandardExchangeWeightedBufferHookLiquidityLib {
    using SafeERC20 for IERC20;
    error ZeroAmount();
    error Slippage();
    error UnwrapFailed();
    error SeShareNotBuffered();
    error ArrayLengthMismatch();
    error NotLive();

    struct Book { uint256[] shares; uint256[] local; bytes[] states; bool[] unprojected; }

    function snapshot() public view returns (Book memory b) {
        Repo.Layout storage l = Repo._layout();
        b.shares = l.seReserves;
        b.local = l.rawReserves;
        b.states = new bytes[](l.numTokens);
        b.unprojected = new bool[](l.numTokens);
    }

    function empty() private view returns (Book memory b) {
        b.shares = new uint256[](Repo._layout().numTokens);
        b.local = new uint256[](Repo._layout().numTokens);
        b.states = new bytes[](Repo._layout().numTokens);
        b.unprojected = new bool[](Repo._layout().numTokens);
    }

    function feeSplit(uint256 gross) public view returns (uint256 net, uint256 fee) {
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(Repo._layout().feeOracle);
        uint256 percentage = oracle.usageFeeOfVault(address(this));
        return Components.splitMintFee(gross, percentage, address(oracle.feeTo()), percentage != 0);
    }

    function grossForNet(uint256 net) public view returns (uint256) {
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(Repo._layout().feeOracle);
        uint256 percentage = oracle.usageFeeOfVault(address(this));
        return Components.grossForNet(net, percentage, address(oracle.feeTo()), percentage != 0);
    }

    function _previewConvert(uint8 i, bool sharesIn, uint256 amount) private view returns (ExchangeInAmount.Result memory r) {
        if (amount == 0) return r;
        Repo.Layout storage l = Repo._layout();
        if (!sharesIn && ClaimLib.isDisabled(i)) return ExchangeInAmount.Result(0, amount);
        return ExchangeInAmount.previewResult(IStandardExchangeIn(l.standardExchanges[i]), IERC20(sharesIn ? l.standardExchanges[i] : l.tokens[i]), amount, IERC20(sharesIn ? l.tokens[i] : l.standardExchanges[i]));
    }

    function _previewStateConvert(uint8 i, bool sharesIn, uint256 amount, bytes memory state)
        private view returns (ExchangeInAmount.Result memory r, bytes memory next)
    {
        if (amount == 0) return (r, state);
        if (state.length == 0) return (_previewConvert(i, sharesIn, amount), state);
        if (!sharesIn && ClaimLib.isDisabled(i)) return (ExchangeInAmount.Result(0, amount), state);
        uint256 consumed;
        uint256 output;
        (next, consumed, output,) = Transition(Repo._layout().standardExchanges[i]).quoteTransition(
            state, sharesIn ? Transition.Operation.RedeemExactIn : Transition.Operation.DepositExactIn, amount
        );
        r = ExchangeInAmount.fromConsumedInput(amount, consumed, output);
    }

    function _quoteStates(Book memory old, Book memory caller, uint8 projectedIndex, bytes memory projectedState) private view {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (l.standardExchanges[i] == address(0)) continue;
            old.states[i] = i == projectedIndex ? projectedState
                : ContextQuote.snapshot(l.standardExchanges[i], l.tokens[i], address(this), address(0));
            if (caller.shares[i] != 0 && old.states[i].length != 0) {
                (old.states[i],,,) = Transition(l.standardExchanges[i]).quoteTransition(
                    old.states[i], Transition.Operation.ReceiveShares, caller.shares[i]
                );
            }
        }
        caller.states = old.states;
        caller.unprojected = old.unprojected;
    }

    function _previewAt(Book memory book, uint8 i, bool sharesIn, uint256 amount)
        private view returns (ExchangeInAmount.Result memory r)
    {
        if (amount == 0) return r;
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        (r,) = _previewStateConvert(i, sharesIn, amount, book.states[i]);
    }

    function _convertPreview(Book memory book, uint8 i, bool sharesIn, uint256 amount)
        private view returns (ExchangeInAmount.Result memory r)
    {
        if (amount == 0) return r;
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        bytes memory next;
        (r, next) = _previewStateConvert(i, sharesIn, amount, book.states[i]);
        // An ordinary forward quote is enough for one conversion, not for a
        // later quote against the state that conversion would have changed.
        if (book.states[i].length == 0 && amount != r.amountRefunded) book.unprojected[i] = true;
        book.states[i] = next;
    }

    function _validate(uint256[] memory amounts, bool[] memory flags, uint256 supply) private view {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens || flags.length != l.numTokens) revert ArrayLengthMismatch();
        if (supply == 0 && Math.countPositive(amounts) < 2) revert ZeroAmount();
        for (uint8 i; i < l.numTokens; ++i) {
            if (flags[i] && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        }
    }

    /// @dev Choose a caller-budgeted split using forward quotes, never a provider rate.
    function _pairSpend(uint8 i, uint256 amount, Book memory old) private view returns (uint256) {
        if (amount == 0 || old.shares[i] == 0) return 0;
        if (old.local[i] == 0) return amount;
        uint256 quotedShares = _previewAt(old, i, false, amount).amountOut;
        if (quotedShares == 0) return 0;
        uint256 matchingLocal = FullMath.mulDiv(quotedShares, old.local[i], old.shares[i]);
        uint256 spend = FullMath.mulDiv(amount, amount, amount + matchingLocal);
        return _previewAt(old, i, false, spend).amountOut == 0 ? 0 : spend;
    }

    function _shareSpend(uint8 i, Book memory caller, Book memory old) private view returns (uint256) {
        uint256 shares = caller.shares[i];
        if (shares == 0 || old.local[i] == 0) return 0;
        if (old.shares[i] == 0) return shares;
        uint256 requiredLocal = FullMath.mulDiv(shares, old.local[i], old.shares[i], FullMath.Rounding.Ceil);
        if (caller.local[i] >= requiredLocal) return 0;
        uint256 receipt = _previewAt(caller, i, true, shares).amountOut;
        if (receipt == 0) return 0;
        uint256 spend = FullMath.mulDiv(shares, requiredLocal - caller.local[i], receipt + requiredLocal, FullMath.Rounding.Ceil);
        // Native pair-token quantization can round the selected fraction to zero
        // even when redeeming the entire input would pay one unit.
        return _previewAt(caller, i, true, spend).amountOut == 0 ? 0 : spend;
    }

    function _redeemPreview(uint8 i, Book memory caller, uint256 spend, bool genesis) private view {
        if (spend == 0) return;
        ExchangeInAmount.Result memory r = _convertPreview(caller, i, true, spend);
        if (r.amountRefunded != 0 || r.amountOut == 0) revert UnwrapFailed();
        caller.shares[i] -= spend;
        caller.local[i] += r.amountOut;
        genesis;
    }

    function _redeem(uint8 i, Book memory caller, uint256 spend) private {
        if (spend == 0) return;
        ExchangeInAmount.Result memory r = ClaimLib.convert(i, true, spend);
        if (r.amountRefunded != 0 || r.amountOut == 0) revert UnwrapFailed();
        caller.shares[i] -= spend;
        caller.local[i] += r.amountOut;
    }

    function _assemblePreview(Book memory caller, Book memory old, bool genesis) private view {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (l.standardExchanges[i] == address(0)) continue;
            if (genesis) {
                if (caller.local[i] != 0) {
                    uint256 amount = caller.local[i];
                    ExchangeInAmount.Result memory r = _convertPreview(caller, i, false, amount);
                    if (r.amountOut == 0) revert ZeroAmount();
                    caller.local[i] = r.amountRefunded;
                    caller.shares[i] += r.amountOut;
                }
                if (caller.shares[i] == 0) continue;
                (uint256 spend,) = Components.bootstrapSplit(caller.shares[i]);
                _redeemPreview(i, caller, spend, true);
            } else {
                // An in-kind paid output already contains native components.
                // Let the common mint bound and refunds handle rounding or
                // imbalance; do not churn it through the SE to improve a quote.
                if (caller.shares[i] != 0 && caller.local[i] != 0) continue;
                bool sharesIn = caller.shares[i] != 0;
                uint256 spend = sharesIn ? 0 : _pairSpend(i, caller.local[i], old);
                if (spend != 0) {
                    ExchangeInAmount.Result memory r = _convertPreview(caller, i, false, spend);
                    caller.local[i] -= spend - r.amountRefunded;
                    caller.shares[i] += r.amountOut;
                }
                if (sharesIn) _redeemPreview(i, caller, _shareSpend(i, caller, old), false);
            }
        }
    }

    function _assemble(Book memory caller, Book memory old, bool genesis) private {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (l.standardExchanges[i] == address(0)) continue;
            if (genesis) {
                if (caller.local[i] != 0) {
                    ExchangeInAmount.Result memory r = ClaimLib.convert(i, false, caller.local[i]);
                    if (r.amountOut == 0) revert ZeroAmount();
                    caller.local[i] = r.amountRefunded;
                    caller.shares[i] += r.amountOut;
                }
                if (caller.shares[i] == 0) continue;
                (uint256 spend,) = Components.bootstrapSplit(caller.shares[i]);
                _redeem(i, caller, spend);
            } else {
                if (caller.shares[i] != 0 && caller.local[i] != 0) continue;
                bool sharesIn = caller.shares[i] != 0;
                uint256 spend = sharesIn ? 0 : _pairSpend(i, caller.local[i], old);
                if (spend != 0) {
                    ExchangeInAmount.Result memory r = ClaimLib.convert(i, false, spend);
                    caller.local[i] -= spend - r.amountRefunded;
                    caller.shares[i] += r.amountOut;
                }
                if (sharesIn) _redeem(i, caller, _shareSpend(i, caller, old));
            }
        }
    }

    function _gross(Book memory caller, Book memory old, uint256 supply) private view returns (uint256 gross) {
        Repo.Layout storage l = Repo._layout();
        if (supply == 0) {
            uint256[] memory seed = new uint256[](l.numTokens);
            for (uint8 i; i < l.numTokens; ++i) seed[i] = Math.scaleTo(l.standardExchanges[i] == address(0) ? caller.local[i] : caller.shares[i], l.invScales[i]);
            if (Math.countPositive(seed) < 2) revert ZeroAmount();
            if (Math.isFullBookReserves(seed)) (gross,) = Math.firstMintSharesFull(l.weights, seed);
            else (gross,) = Math.firstMintSharesPartial(l.weights, seed);
            return gross;
        }
        uint256[] memory available = new uint256[](uint256(l.numTokens) * 2);
        uint256[] memory booked = new uint256[](available.length);
        for (uint8 i; i < l.numTokens; ++i) {
            available[2*i] = caller.shares[i]; booked[2*i] = old.shares[i];
            available[2*i+1] = caller.local[i]; booked[2*i+1] = old.local[i];
        }
        return Components.maxComponentMint(available, booked, supply);
    }

    function _input(uint256[] memory amounts, bool[] memory flags) private view returns (Book memory caller) {
        caller = empty();
        for (uint8 i; i < amounts.length; ++i) {
            if (flags[i]) caller.shares[i] = amounts[i]; else caller.local[i] = amounts[i];
        }
    }

    function _usedAmounts(uint256[] memory amounts, bool[] memory flags, Book memory caller, Book memory old, uint256 supply, uint256 gross) private pure returns (uint256[] memory used) {
        used = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            uint256 available = flags[i] ? caller.shares[i] : caller.local[i];
            uint256 booked = flags[i] ? old.shares[i] : old.local[i];
            bool seedLeg = old.shares[i] == 0 && old.local[i] == 0;
            uint256 accepted = supply == 0 || seedLeg ? available : Components.componentContribution(gross, booked, supply);
            uint256 returned = available - accepted;
            used[i] = returned < amounts[i] ? amounts[i] - returned : 0;
        }
    }

    function _accept(Book memory caller, Book memory old, uint256 supply, uint256 gross) private {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            // A zero component has no requirement. Funding a previously empty leg is
            // accepted only together with a backed common mint, never a standalone mint.
            bool seedLeg = old.shares[i] == 0 && old.local[i] == 0;
            uint256 shares = supply == 0 || seedLeg ? caller.shares[i] : Components.componentContribution(gross, old.shares[i], supply);
            uint256 local = supply == 0 || seedLeg ? caller.local[i] : Components.componentContribution(gross, old.local[i], supply);
            l.seReserves[i] += shares;
            l.rawReserves[i] += local;
            caller.shares[i] -= shares;
            caller.local[i] -= local;
        }
    }

    /// @dev Rated values only size paid trades. They never determine the LP
    /// mint: _gross and _accept still require every native book component.
    function _preparationPlan(Book memory caller, Book memory old)
        private view returns (uint256[] memory values, uint256[] memory excess, uint256[] memory deficit)
    {
        uint8 n = Repo._layout().numTokens;
        values = new uint256[](n);
        excess = new uint256[](n);
        deficit = new uint256[](n);
        uint256[] memory booked = new uint256[](n);
        uint256 totalBook;
        uint256 totalCaller;
        for (uint8 i; i < n; ++i) {
            booked[i] = _rated(old, i);
            // Empty legs retain their existing seed behavior. There is no
            // incumbent inventory there with which to perform a paid swap.
            if (booked[i] == 0) continue;
            values[i] = _rated(caller, i);
            totalBook += booked[i];
            totalCaller += values[i];
        }
        if (totalBook == 0) return (values, excess, deficit);
        for (uint8 i; i < n; ++i) {
            uint256 target = FullMath.mulDiv(totalCaller, booked[i], totalBook);
            if (values[i] > target) excess[i] = values[i] - target;
            else deficit[i] = target - values[i];
        }
    }

    /// @dev Like the paid basket stage of a single exit, exchange only the
    /// caller's offered components against the remaining native book. Neither
    /// side needs to redeem SE shares merely to transfer their ownership.
    function _prepare(Book memory caller, Book memory old) private view {
        (uint256[] memory values, uint256[] memory excess, uint256[] memory deficit) = _preparationPlan(caller, old);
        for (uint8 i; i < values.length; ++i) {
            for (uint8 j; j < values.length && excess[i] != 0; ++j) {
                uint256 value = FullMath.min(excess[i], deficit[j]);
                if (value == 0) continue;
                uint256 shares = FullMath.mulDiv(caller.shares[i], value, values[i]);
                uint256 local = FullMath.mulDiv(caller.local[i], value, values[i]);
                _tradeComponents(caller, old, i, j, shares, local);
                values[i] -= value;
                excess[i] -= value;
                deficit[j] -= value;
            }
        }
    }

    function _missingPreparedLeg(Book memory caller, Book memory old) private pure returns (bool) {
        for (uint256 i; i < old.shares.length; ++i) {
            if ((old.shares[i] != 0 || old.local[i] != 0) && caller.shares[i] == 0 && caller.local[i] == 0) return true;
        }
        return false;
    }

    function _needsPreparation(uint256[] memory amounts, Book memory old) private pure returns (bool) {
        for (uint256 i; i < amounts.length; ++i) {
            if (amounts[i] == 0 && (old.shares[i] != 0 || old.local[i] != 0)) return true;
        }
        return false;
    }

    function _tradeComponents(Book memory caller, Book memory old, uint8 i, uint8 j, uint256 shares, uint256 local)
        private view
    {
        if (shares == 0 && local == 0) return;
        Repo.Layout storage l = Repo._layout();
        uint256 inflow;
        if (l.standardExchanges[i] == address(0)) {
            uint256 units = l.rateProviders[i] == address(0) ? local
                : FullMath.mulDiv(local, ClaimLib.getRateFailClosed(l.rateProviders[i]), 1e18);
            inflow = Math.scaleTo(units, l.ratedScales[i]);
        } else {
            uint256 shareValue = shares == 0 ? 0
                : Math.ratedPairUnits(shares, _quoteRate(old, i), l.invScales[i], l.ratedScales[i]);
            inflow = Math.scaleTo(local + shareValue, l.ratedScales[i]);
        }
        uint256 balanceOut = _rated(old, j);
        uint256 fee = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        inflow = Math.applyTradingFeeNet(inflow, fee);
        if (inflow == 0) return;
        uint256 budget = Math.quoteLiquidityExactIn(_rated(old, i), l.weights[i], balanceOut, l.weights[j], inflow);
        uint256 outputValue;
        if (l.standardExchanges[j] == address(0)) {
            uint256 rate = l.rateProviders[j] == address(0) ? 1e18 : ClaimLib.getRateFailClosed(l.rateProviders[j]);
            outputValue = Math.componentValueUp(old.local[j], 0, l.ratedScales[j], l.ratedScales[j], rate);
        } else {
            outputValue = Math.componentValueUp(old.shares[j], old.local[j], l.invScales[j], l.ratedScales[j], _quoteRate(old, j));
        }
        uint256 sharesOut = FullMath.mulDiv(old.shares[j], budget, outputValue);
        uint256 localOut = FullMath.mulDiv(old.local[j], budget, outputValue);
        // Dust which cannot buy a native component remains the caller's input.
        if (sharesOut == 0 && localOut == 0) return;
        old.shares[i] += shares;
        old.local[i] += local;
        caller.shares[i] -= shares;
        caller.local[i] -= local;
        old.shares[j] -= sharesOut;
        old.local[j] -= localOut;
        caller.shares[j] += sharesOut;
        caller.local[j] += localOut;
    }

    function previewJoin(uint256[] memory amounts, bool[] memory flags, bool rebalance)
        public view returns (uint256 net, uint256[] memory used)
    {
        return _previewJoin(amounts, flags, rebalance, type(uint8).max, bytes(""));
    }

    function _nativeInput(uint256[] memory localAmounts, uint256[] memory shareAmounts)
        private view returns (Book memory caller)
    {
        Repo.Layout storage l = Repo._layout();
        if (!l.initializationFinalized || ERC20Repo._totalSupply() == 0) revert NotLive();
        if (localAmounts.length != l.numTokens || shareAmounts.length != l.numTokens) revert ArrayLengthMismatch();
        caller = empty();
        caller.local = localAmounts;
        caller.shares = shareAmounts;
        for (uint8 i; i < l.numTokens; ++i) {
            if (shareAmounts[i] != 0 && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        }
    }

    /// @notice Prepare the complete caller basket once, then price ownership in native components.
    function previewJoinNativeComponents(uint256[] memory localAmounts, uint256[] memory shareAmounts)
        external view returns (uint256 net)
    {
        Book memory caller = _nativeInput(localAmounts, shareAmounts);
        Book memory old = snapshot();
        uint256 supply = ERC20Repo._totalSupply();
        _prepare(caller, old);
        if (_missingPreparedLeg(caller, old)) return 0;
        _assemblePreview(caller, old, false);
        uint256 gross = _gross(caller, old, supply);
        _joinBound(gross, supply, true);
        (net,) = feeSplit(gross);
    }

    function joinNativeComponents(
        uint256[] memory localAmounts, uint256[] memory shareAmounts, address to, uint256 minimum
    ) external returns (uint256 net) {
        Book memory caller = _nativeInput(localAmounts, shareAmounts);
        Book memory old = snapshot();
        uint256 supply = ERC20Repo._totalSupply();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (caller.local[i] != 0) PullLib.pull(l.tokens[i], msg.sender, caller.local[i]);
            if (caller.shares[i] != 0) PullLib.pull(l.standardExchanges[i], msg.sender, caller.shares[i]);
        }
        _prepare(caller, old);
        if (_missingPreparedLeg(caller, old)) revert IStandardExchangeErrors.MinAmountNotMet(1, 0);
        l.seReserves = old.shares;
        l.rawReserves = old.local;
        _assemble(caller, old, false);
        uint256 gross = _gross(caller, old, supply);
        _joinBound(gross, supply, true);
        return _finishJoin(caller, old, supply, gross, to, minimum);
    }

    function previewReceivedShares(uint8 index, uint256 amount, bytes memory state) external view returns (uint256 net) {
        if (amount == 0 || ERC20Repo._totalSupply() == 0) return 0;
        uint256[] memory amounts = new uint256[](Repo._layout().numTokens);
        bool[] memory flags = new bool[](amounts.length);
        amounts[index] = amount;
        flags[index] = true;
        (net,) = _previewJoin(amounts, flags, true, index, state);
    }

    function _previewJoin(uint256[] memory amounts, bool[] memory flags, bool rebalance, uint8 projectedIndex, bytes memory projectedState) private view returns (uint256 net, uint256[] memory used) {
        uint256 supply = ERC20Repo._totalSupply();
        _validate(amounts, flags, supply);
        Book memory old = snapshot();
        Book memory caller = _input(amounts, flags);
        // A live join prepares paid in-kind trades before its one conversion
        // per leg. Native issuance needs no post-conversion rate. Ordinary
        // forward quotes therefore suffice, including zero-share dust quotes.
        // Genesis and externally changed state still require projection.
        if (supply == 0 || projectedIndex != type(uint8).max) {
            _quoteStates(old, caller, projectedIndex, projectedState);
        }
        if (rebalance && supply != 0 && _needsPreparation(amounts, old)) {
            _prepare(caller, old);
            if (_missingPreparedLeg(caller, old)) return (0, new uint256[](amounts.length));
        }
        _assemblePreview(caller, old, supply == 0);
        uint256 gross = _gross(caller, old, supply);
        _joinBound(gross, supply, rebalance);
        (net,) = feeSplit(gross);
        used = _usedAmounts(amounts, flags, caller, old, supply, gross);
    }

    function join(uint256[] memory amounts, bool[] memory flags, bool rebalance, address to, uint256 minimum, uint256 exactNet) external returns (uint256 net, uint256[] memory used) {
        uint256 supply = ERC20Repo._totalSupply();
        _validate(amounts, flags, supply);
        Book memory old = snapshot();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) if (amounts[i] != 0) PullLib.pull(flags[i] ? l.standardExchanges[i] : l.tokens[i], msg.sender, amounts[i]);
        Book memory caller = _input(amounts, flags);
        if (rebalance && supply != 0 && _needsPreparation(amounts, old)) {
            _prepare(caller, old);
            if (_missingPreparedLeg(caller, old)) revert IStandardExchangeErrors.MinAmountNotMet(1, 0);
            // Trades are paid by the caller. Their remaining basket buys a
            // common fraction of the incumbent native book after those trades.
            l.seReserves = old.shares;
            l.rawReserves = old.local;
        }
        _assemble(caller, old, supply == 0);
        uint256 gross = _gross(caller, old, supply);
        if (exactNet != 0) {
            uint256 requested = grossForNet(exactNet);
            if (gross < requested) revert Slippage();
            gross = requested;
        }
        _joinBound(gross, supply, rebalance);
        used = _usedAmounts(amounts, flags, caller, old, supply, gross);
        net = _finishJoin(caller, old, supply, gross, to, minimum);
    }

    function _finishJoin(Book memory caller, Book memory old, uint256 supply, uint256 gross, address to, uint256 minimum)
        private returns (uint256 net)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 fee;
        (net, fee) = feeSplit(gross);
        if (net == 0) revert IStandardExchangeErrors.MinAmountNotMet(1, 0);
        if (net < minimum) revert Slippage();
        address recipient = fee == 0 ? address(0) : address(IVaultFeeOracleQuery(l.feeOracle).feeTo());
        _accept(caller, old, supply, gross);
        if (supply == 0) ERC20Repo._mint(address(0), Math.MINIMUM_LIQUIDITY);
        if (fee != 0) {
            ERC20Repo._mint(recipient, fee);
            emit IHook.ProtocolFeeMinted(recipient, fee);
        }
        ERC20Repo._mint(to, net);
        for (uint8 i; i < l.numTokens; ++i) {
            if (caller.shares[i] != 0) IERC20(l.standardExchanges[i]).safeTransfer(msg.sender, caller.shares[i]);
            if (caller.local[i] != 0) IERC20(l.tokens[i]).safeTransfer(msg.sender, caller.local[i]);
        }
    }

    function _joinBound(uint256 gross, uint256 supply, bool rebalance) private view {
        if (rebalance && supply != 0 && !Repo._layout().ownerOnlyLiquidity && gross > FullMath.mulDiv(supply, Math.MAX_INVARIANT_RATIO - Math.WAD, Math.WAD)) revert Math.MaxInvariantRatio();
    }

    function _rated(Book memory b, uint8 i) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            uint256 units = l.rateProviders[i] == address(0) ? b.local[i] : FullMath.mulDiv(b.local[i], ClaimLib.getRateFailClosed(l.rateProviders[i]), 1e18);
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        uint256 sharesValue = b.shares[i] == 0 ? 0 : Math.ratedPairUnits(b.shares[i], _quoteRate(b, i), l.invScales[i], l.ratedScales[i]);
        return Math.scaleTo(b.local[i] + sharesValue, l.ratedScales[i]);
    }

    function _quoteRate(Book memory book, uint8 i) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        return book.states[i].length == 0 ? ClaimLib.getRateFailClosed(l.rateProviders[i])
            : ContextQuote.rateFromState(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], book.states[i]);
    }

    function _quoteInputValue(Book memory book, uint8 i, uint256 amount) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (book.unprojected[i]) revert Transition.InvalidQuoteState();
        if (book.states[i].length == 0) return ClaimLib.mapPairInToRatedWad(i, amount);
        (ExchangeInAmount.Result memory r,) = _previewStateConvert(i, false, amount, book.states[i]);
        return Math.scaleTo(r.amountRefunded + Math.ratedPairUnits(
            r.amountOut, _quoteRate(book, i), l.invScales[i], l.ratedScales[i]
        ), l.ratedScales[i]);
    }

    function _quoteOutputShares(Book memory book, uint8 i, uint256 ratedWad) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (ratedWad == 0) return 0;
        uint256 sharesWad = FullMath.mulDiv(ratedWad, Math.RATE_PRECISION, _quoteRate(book, i));
        return FullMath.mulDiv(sharesWad, Math.RATE_PRECISION, l.invScales[i]);
    }

    function _swapPreview(Book memory book, uint8 i, uint8 j, uint256 amount) private view returns (uint256 out) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 fee = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        uint256 inflow = _quoteInputValue(book, i, Math.applyTradingFeeNet(amount, fee));
        if (inflow == 0) return 0;
        uint256 budget = Math.quoteLiquidityExactIn(_rated(book, i), l.weights[i], _rated(book, j), l.weights[j], inflow);
        uint256 nativeBudget = Math.descale(budget, l.ratedScales[j]);
        uint256 local = FullMath.min(book.local[j], nativeBudget);
        out = local;
        book.local[j] -= local;
        if (l.standardExchanges[j] != address(0) && nativeBudget > local) {
            uint256 shares = _quoteOutputShares(book, j, budget - Math.scaleTo(local, l.ratedScales[j]));
            if (shares > book.shares[j]) revert Slippage();
            book.shares[j] -= shares;
            ExchangeInAmount.Result memory r = _convertPreview(book, j, true, shares);
            if (r.amountRefunded != 0) revert UnwrapFailed();
            out += r.amountOut;
        }
        if (l.standardExchanges[i] == address(0)) book.local[i] += amount;
        else {
            ExchangeInAmount.Result memory r = _convertPreview(book, i, false, amount);
            book.shares[i] += r.amountOut;
            book.local[i] += r.amountRefunded;
        }
    }

    function swap(uint8 i, uint8 j, uint256 amount) public returns (uint256 out) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        Book memory book = snapshot();
        uint256 fee = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        uint256 inflow = ClaimLib.mapPairInToRatedWad(i, Math.applyTradingFeeNet(amount, fee));
        if (inflow == 0) return 0;
        uint256 budget = Math.quoteLiquidityExactIn(_rated(book, i), l.weights[i], _rated(book, j), l.weights[j], inflow);
        uint256 nativeBudget = Math.descale(budget, l.ratedScales[j]);
        uint256 local = FullMath.min(l.rawReserves[j], nativeBudget);
        l.rawReserves[j] -= local;
        out = local;
        if (l.standardExchanges[j] != address(0) && nativeBudget > local) {
            uint256 spend = ClaimLib.nativeForRatedWad(j, budget - Math.scaleTo(local, l.ratedScales[j]), false);
            l.seReserves[j] -= spend;
            if (spend != 0) out += ClaimLib.unwrap(l.standardExchanges[j], l.tokens[j], spend, address(this));
        }
        if (out == 0) revert ZeroAmount();
        ClaimLib.bufferPool(i, amount);
    }






    function previewExit(uint256 burned, bool[] memory flags) public view returns (uint256[] memory amounts) {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.numTokens) revert ArrayLengthMismatch();
        uint256 supply = ERC20Repo._totalSupply();
        amounts = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            uint256 local = Components.componentAllocation(burned, l.rawReserves[i], supply);
            uint256 shares = Components.componentAllocation(burned, l.seReserves[i], supply);
            if (l.standardExchanges[i] == address(0)) {
                if (flags[i]) revert SeShareNotBuffered();
                amounts[i] = local;
            } else {
                ExchangeInAmount.Result memory r = _previewConvert(i, !flags[i], flags[i] ? local : shares);
                if (r.amountRefunded != 0) revert UnwrapFailed();
                amounts[i] = (flags[i] ? shares : local) + r.amountOut;
            }
        }
    }

    function exit(address holder, uint256 burned, bool[] memory flags, address to, uint256[] memory minima) external returns (uint256[] memory amounts) {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.numTokens || minima.length != l.numTokens) revert ArrayLengthMismatch();
        Book memory caller = _allocate(burned);
        ERC20Repo._burn(holder, burned);
        amounts = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            amounts[i] = _payout(i, caller, flags[i]);
            if (amounts[i] < minima[i]) revert Slippage();
            if (amounts[i] != 0) IERC20(flags[i] ? l.standardExchanges[i] : l.tokens[i]).safeTransfer(to, amounts[i]);
        }
    }

    function _allocate(uint256 burned) private returns (Book memory caller) {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        caller = empty();
        for (uint8 i; i < l.numTokens; ++i) {
            caller.shares[i] = Components.componentAllocation(burned, l.seReserves[i], supply);
            caller.local[i] = Components.componentAllocation(burned, l.rawReserves[i], supply);
            l.seReserves[i] -= caller.shares[i]; l.rawReserves[i] -= caller.local[i];
        }
    }

    function _payout(uint8 i, Book memory caller, bool asShare) private returns (uint256 amount) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            if (asShare) revert SeShareNotBuffered();
            return caller.local[i];
        }
        if (!asShare) {
            _redeem(i, caller, caller.shares[i]);
            return caller.local[i];
        }
        ExchangeInAmount.Result memory r = ClaimLib.convert(i, false, caller.local[i]);
        if (r.amountRefunded != 0 || (caller.local[i] != 0 && r.amountOut == 0)) revert UnwrapFailed();
        return caller.shares[i] + r.amountOut;
    }

    function previewSingleExit(uint8 target, uint256 burned, bool asShare) public view returns (uint256 out) {
        Repo.Layout storage l = Repo._layout();
        Book memory old = snapshot();
        Book memory caller = empty();
        bool[] memory unprojected = new bool[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (l.standardExchanges[i] != address(0)) {
                old.states[i] = ContextQuote.snapshot(l.standardExchanges[i], l.tokens[i], address(this), address(0));
            }
        }
        caller.states = old.states;
        caller.unprojected = old.unprojected;
        uint256 supply = ERC20Repo._totalSupply();
        for (uint8 i; i < l.numTokens; ++i) {
            caller.shares[i] = Components.componentAllocation(burned, old.shares[i], supply);
            caller.local[i] = Components.componentAllocation(burned, old.local[i], supply);
            old.shares[i] -= caller.shares[i]; old.local[i] -= caller.local[i];
            if (i != target || !asShare) {
                unprojected[i] = caller.shares[i] != 0 && old.states[i].length == 0;
                _redeemPreview(i, caller, caller.shares[i], false);
            }
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (i == target || caller.local[i] == 0) continue;
            // A prior SE conversion changed the state used by this trade's rate
            // or deposit quote. A live read is not a projected-state substitute.
            if (unprojected[i] || unprojected[target]) revert Transition.InvalidQuoteState();
            uint256 targetShares = old.shares[target];
            caller.local[target] += _swapPreview(old, i, target, caller.local[i]);
            if (old.states[target].length == 0 && old.shares[target] < targetShares) unprojected[target] = true;
        }
        if (!asShare) return caller.local[target];
        if (l.standardExchanges[target] == address(0)) revert SeShareNotBuffered();
        if (caller.local[target] != 0 && unprojected[target]) revert Transition.InvalidQuoteState();
        (ExchangeInAmount.Result memory r,) = _previewStateConvert(target, false, caller.local[target], old.states[target]);
        if (r.amountRefunded != 0) revert UnwrapFailed();
        return caller.shares[target] + r.amountOut;
    }

    function singleExit(address holder, uint8 target, uint256 burned, bool asShare, address to, uint256 minimum, uint256 exactOutput) external returns (uint256 out) {
        Repo.Layout storage l = Repo._layout();
        Book memory caller = _allocate(burned);
        ERC20Repo._burn(holder, burned);
        for (uint8 i; i < l.numTokens; ++i) if (i != target || !asShare) _redeem(i, caller, caller.shares[i]);
        for (uint8 i; i < l.numTokens; ++i) if (i != target && caller.local[i] != 0) caller.local[target] += swap(i, target, caller.local[i]);
        out = _payout(target, caller, asShare);
        if (out < minimum) revert Slippage();
        if (exactOutput != 0) {
            if (out < exactOutput) revert Slippage();
            // Output rounding surplus remains backed, without an SE cleanup deposit.
            l.rawReserves[target] += out - exactOutput;
            out = exactOutput;
        }
        IERC20(asShare ? l.standardExchanges[target] : l.tokens[target]).safeTransfer(to, out);
    }
}

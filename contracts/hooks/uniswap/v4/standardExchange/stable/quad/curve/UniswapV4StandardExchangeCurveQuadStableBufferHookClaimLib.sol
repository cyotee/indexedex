// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {VaultRegistryAwareRepo} from "contracts/registries/vault/VaultRegistryAwareRepo.sol";

import {DETFDecimalScaleLib} from "contracts/vaults/detf/common/core/DETFDecimalScaleLib.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";

import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib
 * @notice SE buffer / unwrap + claim / rate helpers (external lib keeps diamond under EIP-170).
 * @dev Buffer uses exchangeIn(pair→SE); unwrap uses exchangeIn(SE→pair) with exchangeOut fallback.
 *      High-level library calls use DELEGATECALL so address(this) remains the hook.
 */
library UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib {
    using SafeERC20 for IERC20;

    struct Basket {
        uint256[4] shares;
        uint256[4] local;
        // Unspent genesis pair input is the caller's refund, not seed backing.
        uint256[4] refunds;
    }

    error UnknownStandardExchange(address exchange);

    /// @dev The deployment registry is the authority, not a caller-selected fee oracle.
    function disabled(uint8 i) public view returns (bool) {
        address se = Repo._layout().standardExchanges[i];
        if (se == address(0)) return false;
        IVaultRegistryDisableQuery registry =
            IVaultRegistryDisableQuery(address(VaultRegistryAwareRepo._vaultRegistry()));
        if (registry.packageOfVault(se) == address(0)) revert UnknownStandardExchange(se);
        return registry.isDisabled(se);
    }

    function books() public view returns (Basket memory book) {
        Repo.Layout storage l = Repo._layout();
        book.shares = l.seReserves;
        book.local = l.rawReserves;
    }

    /// @dev Quote-selected conversion is bounded by this caller's input. No incumbent asset moves.
    function conversion(uint8 i, uint256 amount, bool asShare, bool first)
        public view returns (uint256 spend)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0) || amount == 0) return 0;
        if (first) {
            if (!asShare) return amount;
            (spend,) = Components.bootstrapSplit(amount);
            return spend;
        }
        return _conversionForBook(i, amount, asShare, l.seReserves[i], l.rawReserves[i]);
    }

    function _conversionForBook(uint8 i, uint256 amount, bool asShare, uint256 shares, uint256 local)
        private view returns (uint256 spend)
    {
        if (amount == 0 || (asShare ? local == 0 : shares == 0)) return 0;
        if (!asShare && disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(Repo._layout().standardExchanges[i]);
        ExchangeInAmount.Result memory full = _previewConversion(i, amount, asShare);
        if (full.amountOut == 0) return 0;
        if (asShare) {
            if (shares == 0) return amount;
            uint256 pairedShares = FullMath.mulDiv(shares, full.amountOut, amount);
            spend = FullMath.mulDiv(amount, local, local + pairedShares, FullMath.Rounding.Ceil);
        } else {
            if (local == 0) return amount;
            uint256 sharesForLocal = FullMath.mulDiv(local, full.amountOut, amount);
            spend = FullMath.mulDiv(amount, shares, shares + sharesForLocal);
        }
        if (_previewConversion(i, spend, asShare).amountOut == 0) return 0;
    }

    error InvalidRoute();

    function _previewConversion(uint8 i, uint256 amount, bool redeem)
        private view returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        return ExchangeInAmount.previewResult(
            IStandardExchangeIn(se), IERC20(redeem ? se : l.tokens[i]),
            amount, IERC20(redeem ? l.tokens[i] : se)
        );
    }

    /// @dev Reconcile both tuple words against exact operation-local custody deltas.
    function convert(uint8 i, uint256 amount, bool redeem)
        public returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (!redeem && disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        IERC20 input = IERC20(redeem ? se : l.tokens[i]);
        IERC20 output = IERC20(redeem ? l.tokens[i] : se);
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(address(this));
        input.forceApprove(se, amount);
        result = ExchangeInAmount.exchangeResult(
            IStandardExchangeIn(se), input, amount, output, 0, address(this), false, block.timestamp
        );
        input.forceApprove(se, 0);
        ExchangeInAmount.requireReceipt(
            amount, result, inputBefore, input.balanceOf(address(this)), outputBefore, output.balanceOf(address(this))
        );
    }

    function previewBasket(uint256[4] memory amounts, bool[] memory flags, bool first)
        public view returns (Basket memory basket)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            if (l.standardExchanges[i] == address(0)) {
                basket.local[i] = amounts[i];
                continue;
            }
            if (first) {
                (basket.shares[i], basket.local[i], basket.refunds[i]) =
                    _previewSeed(i, amounts[i], flags[i]);
                continue;
            }
            uint256 spend = conversion(i, amounts[i], flags[i], first);
            ExchangeInAmount.Result memory result = _previewConversion(i, spend, flags[i]);
            if (flags[i]) {
                basket.shares[i] = ExchangeInAmount.localCredit(amounts[i], spend, result.amountRefunded);
                basket.local[i] = result.amountOut;
            } else {
                basket.shares[i] = result.amountOut;
                basket.local[i] = ExchangeInAmount.localCredit(amounts[i], spend, result.amountRefunded);
            }
        }
    }

    /// @dev Follow conversion state only when the SE advertises that capability.
    /// Ordinary previews remain ordinary previews on an opaque exchange.
    function _preparedInput(uint256[4] memory amounts, bool[] memory flags)
        private view returns (Basket memory incoming, Basket memory book)
    {
        for (uint8 i; i < 4; ++i) {
            if (flags[i]) incoming.shares[i] = amounts[i];
            else incoming.local[i] = amounts[i];
        }
        return _prepareJoinBasket(incoming, books(), _joinRates());
    }

    function _missingPreparedLeg(Basket memory incoming, Basket memory book) private pure returns (bool) {
        for (uint8 i; i < 4; ++i) {
            if ((book.shares[i] != 0 || book.local[i] != 0) && incoming.shares[i] == 0 && incoming.local[i] == 0) return true;
        }
        return false;
    }

    function previewPreparedJoin(uint256[4] memory amounts, bool[] memory flags)
        external view returns (Basket memory incoming, Basket memory book)
    {
        (incoming, book) = _preparedInput(amounts, flags);
        return _previewPreparedComponents(incoming, book);
    }

    function previewPreparedNativeJoin(Basket memory incoming)
        external view returns (Basket memory, Basket memory)
    {
        (Basket memory prepared, Basket memory book) = _prepareJoinBasket(incoming, books(), _joinRates());
        return _previewPreparedComponents(prepared, book);
    }

    function _previewPreparedComponents(Basket memory incoming, Basket memory book)
        private view returns (Basket memory, Basket memory)
    {
        if (_missingPreparedLeg(incoming, book)) return (incoming, book);
        for (uint8 i; i < 4; ++i) {
            if (Repo._layout().standardExchanges[i] == address(0) || (incoming.shares[i] != 0 && incoming.local[i] != 0)) continue;
            bool redeem = incoming.shares[i] != 0;
            uint256 amount = redeem ? incoming.shares[i] : incoming.local[i];
            uint256 spend = _conversionForBook(i, amount, redeem, book.shares[i], book.local[i]);
            ExchangeInAmount.Result memory result = _previewConversion(i, spend, redeem);
            if (redeem) {
                incoming.shares[i] -= spend - result.amountRefunded;
                incoming.local[i] += result.amountOut;
            } else {
                incoming.local[i] -= spend - result.amountRefunded;
                incoming.shares[i] += result.amountOut;
            }
        }
        return (incoming, book);
    }

    function assemblePreparedJoin(uint256[4] memory amounts, bool[] memory flags)
        external returns (Basket memory incoming, Basket memory book)
    {
        (incoming, book) = _preparedInput(amounts, flags);
        return _assemblePreparedComponents(incoming, book);
    }

    function assemblePreparedNativeJoin(Basket memory incoming)
        external returns (Basket memory, Basket memory)
    {
        (Basket memory prepared, Basket memory book) = _prepareJoinBasket(incoming, books(), _joinRates());
        return _assemblePreparedComponents(prepared, book);
    }

    function _assemblePreparedComponents(Basket memory incoming, Basket memory book)
        private returns (Basket memory, Basket memory)
    {
        if (_missingPreparedLeg(incoming, book)) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        l.seReserves = book.shares;
        l.rawReserves = book.local;
        for (uint8 i; i < 4; ++i) {
            if (l.standardExchanges[i] == address(0) || (incoming.shares[i] != 0 && incoming.local[i] != 0)) continue;
            bool redeem = incoming.shares[i] != 0;
            uint256 amount = redeem ? incoming.shares[i] : incoming.local[i];
            uint256 spend = _conversionForBook(i, amount, redeem, book.shares[i], book.local[i]);
            ExchangeInAmount.Result memory result = convert(i, spend, redeem);
            if (redeem) {
                incoming.shares[i] -= spend - result.amountRefunded;
                incoming.local[i] += result.amountOut;
            } else {
                incoming.local[i] -= spend - result.amountRefunded;
                incoming.shares[i] += result.amountOut;
            }
        }
        return (incoming, book);
    }

    function assembleBasket(uint256[4] memory amounts, bool[] memory flags, bool first)
        external returns (Basket memory basket)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            if (l.standardExchanges[i] == address(0)) {
                basket.local[i] = amounts[i];
                continue;
            }
            uint256 supplied = amounts[i];
            if (first && !flags[i]) {
                ExchangeInAmount.Result memory acquired = convert(i, supplied, false);
                supplied = acquired.amountOut;
                basket.refunds[i] = acquired.amountRefunded;
            }
            uint256 spend = conversion(i, supplied, first || flags[i], first);
            uint256 sharesBefore = IERC20(l.standardExchanges[i]).balanceOf(address(this));
            uint256 pairBefore = IERC20(l.tokens[i]).balanceOf(address(this));
            ExchangeInAmount.Result memory result = convert(i, spend, first || flags[i]);
            if (first) {
                (basket.shares[i], basket.local[i]) = Components.bootstrapReceipt(
                    supplied, result, sharesBefore,
                    IERC20(l.standardExchanges[i]).balanceOf(address(this)), pairBefore,
                    IERC20(l.tokens[i]).balanceOf(address(this))
                );
            } else if (flags[i]) {
                basket.shares[i] = ExchangeInAmount.localCredit(amounts[i], spend, result.amountRefunded);
                basket.local[i] = result.amountOut;
            } else {
                basket.shares[i] = result.amountOut;
                basket.local[i] = ExchangeInAmount.localCredit(amounts[i], spend, result.amountRefunded);
            }
        }
    }

    function _previewSeed(uint8 i, uint256 amount, bool asShare)
        private view returns (uint256 retained, uint256 local, uint256 refund)
    {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        bytes memory state;
        uint256 supplied = amount;
        if (asShare) {
            state = ContextQuote.snapshot(se, l.tokens[i], address(this), address(0));
            if (state.length != 0) {
                (state,,,) = Transition(se).quoteTransition(state, Transition.Operation.ReceiveShares, amount);
            }
        } else {
            if (disabled(i)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
            ExchangeInAmount.Result memory acquired;
            (acquired, state) = ContextQuote.depositResult(se, l.tokens[i], address(this), amount, address(0));
            supplied = acquired.amountOut;
            refund = acquired.amountRefunded;
        }
        uint256 spend;
        (spend, retained) = Components.bootstrapSplit(supplied);
        ExchangeInAmount.Result memory redeemed;
        if (state.length == 0) redeemed = _previewConversion(i, spend, true);
        else {
            (, uint256 consumed, uint256 output,) =
                Transition(se).quoteTransition(state, Transition.Operation.RedeemExactIn, spend);
            redeemed = ExchangeInAmount.fromConsumedInput(spend, consumed, output);
        }
        if (redeemed.amountRefunded != 0 || redeemed.amountOut == 0) revert Components.InvalidBootstrapReceipt();
        local = redeemed.amountOut;
    }

    /// @notice Prepare an unbalanced caller basket with paid, in-kind Curve trades.
    /// @dev Like singleExitBasket, a sale moves real S/L units between two owners of
    /// the same custody. No SE withdrawal or invented projected SE state is needed.
    /// Rates select trades only; grossMint still limits every native component.
    function prepareJoinBasket(Basket memory incoming, Basket memory book)
        public view returns (Basket memory, Basket memory)
    {
        return _prepareJoinBasket(incoming, book, _joinRates());
    }

    function _joinRates() private view returns (uint256[4] memory rates) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            if (l.rateProviders[i] == address(0) && l.standardExchanges[i] != address(0)) {
                revert RateProviderRequired();
            }
            rates[i] = l.rateProviders[i] == address(0) ? 1e18 : _getRateFailClosed(l.rateProviders[i]);
        }
    }

    function _basketValues(Basket memory basket, uint256[4] memory rates)
        private view returns (uint256[4] memory values)
    {
        for (uint8 i; i < 4; ++i) {
            values[i] = componentValueWith(i, basket.shares[i], basket.local[i], rates[i]);
        }
    }

    function _prepareJoinBasket(Basket memory incoming, Basket memory book, uint256[4] memory rates)
        private view returns (Basket memory, Basket memory)
    {
        uint256[4] memory values = _basketValues(book, rates);
        uint256[4] memory supplied = _basketValues(incoming, rates);
        uint256 totalBook;
        uint256 totalIn;
        for (uint8 i; i < 4; ++i) {
            totalBook += values[i];
            // An empty incumbent leg does not become a required paid-sale component.
            if (values[i] != 0) totalIn += supplied[i];
        }
        if (totalBook == 0 || totalIn == 0) return (incoming, book);
        uint256[4] memory target;
        for (uint8 i; i < 4; ++i) target[i] = FullMath.mulDiv(totalIn, values[i], totalBook);
        uint256 fee = IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
        for (uint8 i; i < 4; ++i) {
            if (target[i] == 0) continue;
            for (uint8 j; j < 4; ++j) {
                if (i == j || supplied[i] <= target[i] || supplied[j] >= target[j]) continue;
                uint256 sale = supplied[i] - target[i];
                uint256 deficit = target[j] - supplied[j];
                if (sale > deficit) sale = deficit;
                uint256 sharesIn = FullMath.mulDiv(incoming.shares[i], sale, supplied[i]);
                uint256 localIn = FullMath.mulDiv(incoming.local[i], sale, supplied[i]);
                uint256 paid = componentValueWith(i, sharesIn, localIn, rates[i]);
                if (paid == 0) continue;
                values = _basketValues(book, rates);
                uint256 budget = _joinSwapBudget(values, i, j, Math.applyTradingFeeNet(paid, fee));
                if (budget == 0) continue;
                if (budget >= values[j]) revert Math.WouldZeroReserve();
                // Buy both positive components, rounded down, at the quoted leg budget.
                uint256 sharesOut = FullMath.mulDiv(book.shares[j], budget, values[j]);
                uint256 localOut = FullMath.mulDiv(book.local[j], budget, values[j]);
                if (sharesOut == 0 && localOut == 0) continue;
                if (componentValueWith(j, sharesOut, localOut, rates[j]) > budget) revert Math.MathDomain();
                incoming.shares[i] -= sharesIn;
                incoming.local[i] -= localIn;
                book.shares[i] += sharesIn;
                book.local[i] += localIn;
                book.shares[j] -= sharesOut;
                book.local[j] -= localOut;
                incoming.shares[j] += sharesOut;
                incoming.local[j] += localOut;
                supplied[i] = componentValueWith(i, incoming.shares[i], incoming.local[i], rates[i]);
                supplied[j] = componentValueWith(j, incoming.shares[j], incoming.local[j], rates[j]);
            }
        }
        return (incoming, book);
    }

    /// @dev The ordinary Curve swap's D+1 / output-1 rounding. An unrepresentable
    /// preparation trade moves nothing, so forward exact-output sizing can grow
    /// past dust without pretending the caller bought a native component.
    function _joinSwapBudget(uint256[4] memory values, uint8 i, uint8 j, uint256 net)
        private view returns (uint256)
    {
        uint256 amp = Repo._layout().baseAmp * Repo.AMP_PRECISION;
        uint256 y = Math.getY(i, j, values[i] + net, values, amp, Math.getD(values, amp) + 1);
        if (y >= values[j] || values[j] - y <= 1) return 0;
        return values[j] - y - 1;
    }

    function grossMint(Basket memory incoming, Basket memory book, uint256 supply)
        public view returns (uint256 gross)
    {
        if (supply == 0) {
            Repo.Layout storage l = Repo._layout();
            uint256[4] memory seed;
            for (uint8 i; i < 4; ++i) {
                uint256 units = l.standardExchanges[i] == address(0) ? incoming.local[i] : incoming.shares[i];
                seed[i] = Math.scaleTo(units, l.invScales[i]);
            }
            return Math.firstMintShares(seed); // Already excludes the locked floor.
        }
        uint256[] memory available = new uint256[](8);
        uint256[] memory booked = new uint256[](8);
        for (uint8 i; i < 4; ++i) {
            available[i * 2] = incoming.shares[i];
            available[i * 2 + 1] = incoming.local[i];
            booked[i * 2] = book.shares[i];
            booked[i * 2 + 1] = book.local[i];
        }
        return Components.maxComponentMint(available, booked, supply);
    }

    function acceptedBasket(Basket memory incoming, Basket memory book, uint256 supply, uint256 gross)
        public pure returns (Basket memory accepted)
    {
        if (supply == 0) return incoming;
        for (uint8 i; i < 4; ++i) {
            accepted.shares[i] = Components.componentContribution(gross, book.shares[i], supply);
            accepted.local[i] = Components.componentContribution(gross, book.local[i], supply);
        }
    }

    function componentValueWith(uint8 i, uint256 shares, uint256 local, uint256 rate)
        public view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 units = l.standardExchanges[i] == address(0)
            ? Math.ratedPairUnits(local, rate, l.invScales[i], l.ratedScales[i])
            : local + Math.ratedPairUnits(shares, rate, l.invScales[i], l.ratedScales[i]);
        return Math.scaleTo(units, l.ratedScales[i]);
    }

    /// @notice Follow an advertised external-deposit state without substituting an invented SE state.
    function projectedShareJoin(uint8 index, uint256 amount, bytes memory state, uint256 supply)
        external view returns (uint256 gross)
    {
        if (amount == 0 || supply == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        Transition exchange = Transition(l.standardExchanges[index]);
        (state,,,) = exchange.quoteTransition(state, Transition.Operation.ReceiveShares, amount);
        uint256[4] memory rates = _joinRates();
        rates[index] = ContextQuote.rateFromState(l.standardExchanges[index], l.tokens[index], l.rateProviders[index], state);
        Basket memory incoming;
        incoming.shares[index] = amount;
        Basket memory book;
        (incoming, book) = _prepareJoinBasket(incoming, books(), rates);
        if (_missingPreparedLeg(incoming, book)) return 0;
        uint256 remaining = incoming.shares[index];
        if (remaining != 0 && book.local[index] != 0 && incoming.local[index] == 0) {
            (,, uint256 fullOut,) = exchange.quoteTransition(state, Transition.Operation.RedeemExactIn, remaining);
            if (fullOut == 0) return 0;
            uint256 pairedShares = FullMath.mulDiv(book.shares[index], fullOut, remaining);
            uint256 spend = FullMath.mulDiv(remaining, book.local[index], book.local[index] + pairedShares, FullMath.Rounding.Ceil);
            (, uint256 consumed, uint256 output,) = exchange.quoteTransition(state, Transition.Operation.RedeemExactIn, spend);
            if (output == 0) return 0;
            incoming.shares[index] -= consumed;
            incoming.local[index] = output;
        }
        return grossMint(incoming, book, supply);
    }

    function acceptBasket(Basket memory incoming, Basket memory accepted, address payer)
        external
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            l.seReserves[i] += accepted.shares[i];
            l.rawReserves[i] += accepted.local[i];
        }
        for (uint8 i; i < 4; ++i) {
            uint256 refund = incoming.shares[i] - accepted.shares[i];
            if (refund != 0) IERC20(l.standardExchanges[i]).safeTransfer(payer, refund);
            refund = incoming.local[i] - accepted.local[i] + incoming.refunds[i];
            if (refund != 0) IERC20(l.tokens[i]).safeTransfer(payer, refund);
        }
    }

    function allocatedBasket(uint256 burned, uint256 supply) public view returns (Basket memory allocated) {
        Basket memory book = books();
        for (uint8 i; i < 4; ++i) {
            allocated.shares[i] = Components.componentAllocation(burned, book.shares[i], supply);
            allocated.local[i] = Components.componentAllocation(burned, book.local[i], supply);
        }
    }

    function previewPayout(uint8 i, uint256 shares, uint256 local, bool asShare)
        public view returns (uint256 output)
    {
        if (Repo._layout().standardExchanges[i] == address(0)) return local;
        if (asShare) {
            if (local != 0 && disabled(i)) {
                revert IVaultRegistryDisableQuery.VaultDisabled(Repo._layout().standardExchanges[i]);
            }
            ExchangeInAmount.Result memory result = _previewConversion(i, local, false);
            if (result.amountRefunded != 0) revert BufferFailed();
            return shares + result.amountOut;
        }
        ExchangeInAmount.Result memory result = _previewConversion(i, shares, true);
        if (result.amountRefunded != 0 || (shares != 0 && result.amountOut == 0)) revert UnwrapFailed();
        return local + result.amountOut;
    }

    function payBasket(Basket memory allocated, bool[] memory flags, address recipient)
        external returns (uint256[4] memory output)
    {
        Repo.Layout storage l = Repo._layout();
        // Remove the entire entitlement before conversion. Remaining holders never fund an exit.
        for (uint8 i; i < 4; ++i) {
            l.seReserves[i] -= allocated.shares[i];
            l.rawReserves[i] -= allocated.local[i];
        }
        for (uint8 i; i < 4; ++i) {
            address se = l.standardExchanges[i];
            address token = flags[i] ? se : l.tokens[i];
            if (se == address(0)) output[i] = allocated.local[i];
            else {
                uint256 spend = flags[i] ? allocated.local[i] : allocated.shares[i];
                ExchangeInAmount.Result memory result = convert(i, spend, !flags[i]);
                if (result.amountRefunded != 0 || (spend != 0 && result.amountOut == 0)) revert UnwrapFailed();
                output[i] = (flags[i] ? allocated.shares[i] : allocated.local[i]) + result.amountOut;
            }
            if (output[i] != 0 && recipient != address(this)) IERC20(token).safeTransfer(recipient, output[i]);
        }
    }

    /// @dev Allocate first, then trade only the exiting basket against the remaining four-leg book.
    /// The swaps transfer actual component inventory; only the final requested edge is converted.
    function singleExitBasket(uint8 outIndex, uint256 burned, uint256 supply)
        public view returns (Basket memory remaining, Basket memory payout)
    {
        Repo.Layout storage l = Repo._layout();
        Basket memory allocated = allocatedBasket(burned, supply);
        remaining = books();
        if (burned == 0 || burned >= supply) revert Math.MathDomain();
        for (uint8 i; i < 4; ++i) {
            remaining.shares[i] -= allocated.shares[i];
            remaining.local[i] -= allocated.local[i];
        }
        payout.shares[outIndex] = allocated.shares[outIndex];
        payout.local[outIndex] = allocated.local[outIndex];
        uint256 fee = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        for (uint8 i; i < 4; ++i) {
            if (i == outIndex) continue;
            uint256[4] memory values = basketRated(remaining);
            uint256 input = componentValue(i, allocated.shares[i], allocated.local[i]);
            input = Math.applyTradingFeeNet(input, fee);
            if (input == 0) {
                if (allocated.shares[i] != 0 || allocated.local[i] != 0) revert ZeroAmount();
                continue;
            }
            uint256 budget = Math.quoteExactInRated(values, i, outIndex, input, l.baseAmp * Repo.AMP_PRECISION);
            (uint256 shares, uint256 local) = outputComponents(outIndex, budget, remaining);
            remaining.shares[i] += allocated.shares[i];
            remaining.local[i] += allocated.local[i];
            remaining.shares[outIndex] -= shares;
            remaining.local[outIndex] -= local;
            payout.shares[outIndex] += shares;
            payout.local[outIndex] += local;
        }
    }

    function componentValue(uint8 i, uint256 shares, uint256 local) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 units;
        if (l.standardExchanges[i] == address(0)) {
            units = l.rateProviders[i] == address(0) ? local : rated(i, local);
        } else {
            units = local + (shares == 0 ? 0 : rated(i, shares));
        }
        return Math.scaleTo(units, l.ratedScales[i]);
    }

    function basketRated(Basket memory book) public view returns (uint256[4] memory values) {
        for (uint8 i; i < 4; ++i) values[i] = componentValue(i, book.shares[i], book.local[i]);
    }

    function outputComponents(uint8 i, uint256 budget, Basket memory book)
        public view returns (uint256 shares, uint256 local)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            local = l.rateProviders[i] == address(0)
                ? Math.descale(budget, l.ratedScales[i]) : nativeForRatedWad(i, budget, false);
            if (local >= book.local[i]) revert Math.WouldZeroReserve();
            return (0, local);
        }
        uint256 pairBudget = Math.descale(budget, l.ratedScales[i]);
        local = pairBudget < book.local[i] ? pairBudget : book.local[i];
        if (local < pairBudget) {
            shares = nativeForRatedWad(i, Math.scaleTo(pairBudget - local, l.ratedScales[i]), false);
            if (shares >= book.shares[i]) revert Math.WouldZeroReserve();
        }
    }

    function previewSingleExit(uint8 i, uint256 burned, uint256 supply, bool asShare)
        external view returns (uint256)
    {
        (, Basket memory payout) = singleExitBasket(i, burned, supply);
        return previewPayout(i, payout.shares[i], payout.local[i], asShare);
    }

    function paySingleExit(uint8 i, uint256 burned, uint256 supply, bool asShare, address recipient)
        external returns (uint256 output)
    {
        return _paySingleExit(i, burned, supply, asShare, recipient, 0);
    }

    function paySingleExitExactTokenOut(uint8 i, uint256 burned, uint256 supply, address recipient, uint256 requested)
        external returns (uint256 output)
    {
        return _paySingleExit(i, burned, supply, false, recipient, requested);
    }

    function _paySingleExit(uint8 i, uint256 burned, uint256 supply, bool asShare, address recipient, uint256 requested)
        private returns (uint256 output)
    {
        (Basket memory remaining, Basket memory payout) = singleExitBasket(i, burned, supply);
        Repo.Layout storage l = Repo._layout();
        l.seReserves = remaining.shares;
        l.rawReserves = remaining.local;
        if (l.standardExchanges[i] == address(0)) output = payout.local[i];
        else {
            uint256 spend = asShare ? payout.local[i] : payout.shares[i];
            ExchangeInAmount.Result memory result = convert(i, spend, !asShare);
            if (result.amountRefunded != 0 || (spend != 0 && result.amountOut == 0)) revert UnwrapFailed();
            output = (asShare ? payout.shares[i] : payout.local[i]) + result.amountOut;
        }
        if (requested != 0) {
            if (output < requested) revert UnwrapFailed();
            // The exact-token trade settles the requested output. Integer trade-budget surplus
            // remains local, as on the ordinary exact-output swap adapter; no extra LP is minted.
            l.rawReserves[i] += output - requested;
            output = requested;
        }
        if (output != 0) IERC20(asShare ? l.standardExchanges[i] : l.tokens[i]).safeTransfer(recipient, output);
    }

    /// @notice Normalize the redeemable reserve claim into DETF creation units.
    function syntheticValue(IDetfReserveQuote.DetfQuoteCtx calldata ctx, address out_)
        external view returns (uint256)
    {
        uint256 pairOut = IDetfReserveQuote(address(this)).previewBurnToToken(ctx.ownedLp, out_);
        if (pairOut == 0) return 0;
        uint256 pairWad = DETFDecimalScaleLib.nativeToWad(out_, pairOut);
        uint256 mid_ = (pairWad * 1e18) / ctx.detfTotalSupply;
        return (mid_ * 1e18) / ctx.creationPairPerDetfWad;
    }

    /// @notice Native SY input/output tokens, with shared SE tokens listed only once.
    function nativeSyTokens() external view returns (address[] memory tokens_) {
        Repo.Layout storage l_ = Repo._layout();
        tokens_ = new address[](uint256(Repo.N_TOKENS) * 2);
        uint256 count_;
        for (uint256 i_; i_ < Repo.N_TOKENS; ++i_) tokens_[count_++] = l_.tokens[i_];
        for (uint256 i_; i_ < Repo.N_TOKENS; ++i_) {
            address se_ = l_.standardExchanges[i_];
            if (se_ == address(0)) continue;
            bool found_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == se_) { found_ = true; break; }
            if (!found_) tokens_[count_++] = se_;
        }
        assembly ("memory-safe") { mstore(tokens_, count_) }
    }

    /// @dev Reuse a single-leg join's immediately preceding SE quote. No other
    /// leg executes between quotation and buffering, so its minimum is unchanged.
    function bufferQuotedJoin(uint8 index, uint256 amount, uint256 minimum) external {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        address token = l.tokens[index];
        if (minimum == 0) revert BufferFailed();
        IERC20(token).forceApprove(se, amount);(uint256 received,) = IStandardExchangeIn(se).exchangeIn(IERC20(token), amount, IERC20(se), minimum, address(this), false, block.timestamp
        );
        IERC20(token).forceApprove(se, 0);
        if (received < minimum) revert BufferFailed();
    }

    error BufferFailed();
    error UnwrapFailed();
    error RateProviderFailed();
    error RateProviderRequired();
    error SeInvertUnavailable();
    error ZeroAmount();
    error InvalidPair();
    error SwapNotLive();
    error InvalidFeeWad();

    /// @dev Preserve the PM-context versus ordinary quote boundary and raw funding snapshot.
    function previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, address manager)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn == tokenOut) revert InvalidPair();
        uint8 i = Repo._indexOf(Repo._layout(), tokenIn);
        uint8 j = Repo._indexOf(Repo._layout(), tokenOut);
        uint256[4] memory values = manager == address(0) ? _ratedWadAllForSwapIn(i, amountIn) : ratedWadAllWithContext(manager);
        if (values[i] == 0 || values[j] == 0) revert SwapNotLive();
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 netIn = Math.applyTradingFeeNet(amountIn, feeWad);
        uint256 ratedInflow = manager == address(0) || l.standardExchanges[i] == address(0) || l.standardExchanges[i] == l.tokens[i]
            ? mapPairInToRatedWad(i, netIn) : pairInWithContext(i, netIn, manager);
        return quoteSwapExactInContext(i, j, values, ratedInflow, l.baseAmp * Repo.AMP_PRECISION, manager);
    }

    function _ratedWadAllForSwapIn(uint8, uint256) private view returns (uint256[4] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 k; k < 4; ++k) scaled[k] = Math.scaleTo(ratedPairUnits(k), l.ratedScales[k]);
    }

    function mapPairInToRatedWad(uint8 i, uint256 pairAmount) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            uint256 units = l.rateProviders[i] == address(0) ? pairAmount : rated(i, pairAmount);
            return Math.scaleTo(units, l.ratedScales[i]);
        }
        if (disabled(i)) return Math.scaleTo(pairAmount, l.ratedScales[i]);
        ExchangeInAmount.Result memory result = _previewConversion(i, pairAmount, false);
        uint256 units = result.amountRefunded;
        if (result.amountOut != 0) units += rated(i, result.amountOut);
        return Math.scaleTo(units, l.ratedScales[i]);
    }

    function ratedPairUnits(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            return l.rateProviders[i] == address(0) ? l.rawReserves[i] : rated(i, l.rawReserves[i]);
        }
        return l.rawReserves[i] + (l.seReserves[i] == 0 ? 0 : rated(i, l.seReserves[i]));
    }

    function _getRateFailClosed(address provider) private view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }


    /// @notice D60: `units` of leg `i` (raw pair units on a plain leg, SE shares on a buffered leg) valued in
    ///         pair units through the leg's provider. External so the hooks facet does not inline the math.
    function rated(uint8 i, uint256 units) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        return Math.ratedPairUnits(units, _getRateFailClosed(rp), l.invScales[i], l.ratedScales[i]);
    }

    /// @notice D60: same as `rated` with a caller-supplied (projected) rate.
    function ratedWith(uint8 i, uint256 units, uint256 rate) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return Math.ratedPairUnits(units, rate, l.invScales[i], l.ratedScales[i]);
    }

    /// @notice D60: pair units of leg `i` back to the leg's native units (shares on a buffered leg), rounding up.
    function unrated(uint8 i, uint256 pairUnits) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        return Math.sharesForPairUnitsUp(pairUnits, _getRateFailClosed(rp), l.invScales[i], l.ratedScales[i]);
    }

    /// @dev EI payout budgets round native shares down; EO funding rounds up.
    function nativeForRatedWad(uint8 i, uint256 ratedWad, bool roundUp) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        FullMath.Rounding rounding = roundUp ? FullMath.Rounding.Ceil : FullMath.Rounding.Floor;
        uint256 sharesWad = FullMath.mulDiv(ratedWad, Math.RATE_PRECISION, _getRateFailClosed(rp), rounding);
        return FullMath.mulDiv(sharesWad, Math.RATE_PRECISION, l.invScales[i], rounding);
    }

    function ratedWadForNativeUp(uint8 i, uint256 units) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address rp = l.rateProviders[i];
        if (rp == address(0)) revert RateProviderRequired();
        uint256 wad = FullMath.mulDiv(units, l.invScales[i], Math.RATE_PRECISION, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(wad, _getRateFailClosed(rp), Math.RATE_PRECISION, FullMath.Rounding.Ceil);
    }

    function _nativeAt(uint8 i) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return l.standardExchanges[i] == address(0) ? l.rawReserves[i] : l.seReserves[i];
    }

    function quoteSwapExactIn(uint8 i, uint8 j, uint256[4] memory rated, uint256 inflow, uint256 amp)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        return quoteSwapExactInContext(i, j, rated, inflow, amp, address(0));
    }

    function quoteSwapExactInContext(uint8 i, uint8 j, uint256[4] memory rated, uint256 inflow, uint256 amp, address manager)
        public view returns (uint256 amountOut, uint256 sharesOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (inflow == 0) revert Math.ZeroAmount();
        uint256 budget = Math.quoteExactInRated(rated, i, j, inflow, amp);
        if (budget >= rated[j]) revert Math.WouldZeroReserve();
        return _outputBudget(j, budget, manager);
    }

    function _outputBudget(uint8 j, uint256 budget, address manager) private view returns (uint256 amountOut, uint256 sharesOut) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[j];
        uint256 pairBudget = Math.descale(budget, l.ratedScales[j]);
        if (se == address(0)) {
            amountOut = l.rateProviders[j] == address(0) ? pairBudget : nativeForRatedWad(j, budget, false);
            if (amountOut >= l.rawReserves[j]) revert Math.WouldZeroReserve();
        } else {
            uint256 local = pairBudget < l.rawReserves[j] ? pairBudget : l.rawReserves[j];
            uint256 deficit = pairBudget - local;
            amountOut = local;
            if (deficit != 0) {
                uint256 deficitWad = Math.scaleTo(deficit, l.ratedScales[j]);
                if (manager == address(0)) sharesOut = nativeForRatedWad(j, deficitWad, false);
                else sharesOut = FullMath.mulDiv(FullMath.mulDiv(deficitWad, 1e18,
                    ContextQuote.rate(se, l.tokens[j], l.rateProviders[j], manager)), 1e18, l.invScales[j]);
                if (sharesOut >= l.seReserves[j]) revert Math.WouldZeroReserve();
                ExchangeInAmount.Result memory result;
                if (manager == address(0)) result = _previewConversion(j, sharesOut, true);
                else (result,) = ContextQuote.redeemResult(se, l.tokens[j], address(this), sharesOut, manager);
                if (result.amountRefunded != 0 || (sharesOut != 0 && result.amountOut == 0)) revert UnwrapFailed();
                amountOut += result.amountOut;
            }
        }
        if (amountOut == 0) revert Math.ZeroAmount();
    }

    function ratedWadAllWithContext(address manager) public view returns (uint256[4] memory values) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) {
            address se = l.standardExchanges[i];
            uint256 units;
            if (se == address(0) || se == l.tokens[i]) units = ratedPairUnits(i);
            else {
                if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
                units = l.rawReserves[i] + Math.ratedPairUnits(l.seReserves[i], ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]);
            }
            values[i] = Math.scaleTo(units, l.ratedScales[i]);
        }
    }

    function pairInWithContext(uint8 i, uint256 amount, address manager) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (disabled(i)) return Math.scaleTo(amount, l.ratedScales[i]);
        (ExchangeInAmount.Result memory result,) = ContextQuote.depositResult(l.standardExchanges[i], l.tokens[i], address(this), amount, manager);
        uint256 units = result.amountRefunded;
        if (result.amountOut != 0) units += Math.ratedPairUnits(result.amountOut,
            ContextQuote.rate(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], manager), l.invScales[i], l.ratedScales[i]);
        return Math.scaleTo(units, l.ratedScales[i]);
    }

    function quoteSwapExactOut(uint8 i, uint8 j, uint256[4] memory rated, uint256 amountOut, uint256 feeWad, uint256 amp)
        external view returns (uint256 amountIn)
    {
        return quoteSwapExactOutContext(i, j, rated, amountOut, feeWad, amp, address(0));
    }

    function quoteSwapExactOutContext(uint8 i, uint8 j, uint256[4] memory rated, uint256 amountOut, uint256 feeWad, uint256 amp, address manager)
        public view returns (uint256 amountIn)
    {
        uint256 debit = _exactOutputDebit(j, amountOut, manager);
        uint256 needed = Math.quoteExactOutRated(rated, i, j, debit, amp);
        amountIn = Math.grossUpExactOut(_inputForRatedContext(i, needed, manager), feeWad);
        if (amountIn == 0) revert Math.ZeroAmount();
    }

    function _exactOutputDebit(uint8 j, uint256 amountOut, address manager) private view returns (uint256 debit) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[j];
        if (se == address(0)) {
            if (amountOut >= l.rawReserves[j]) revert Math.WouldZeroReserve();
            return l.rateProviders[j] == address(0) ? Math.scaleToUp(amountOut, l.ratedScales[j]) : ratedWadForNativeUp(j, amountOut);
        }
        uint256 local = amountOut < l.rawReserves[j] ? amountOut : l.rawReserves[j];
        debit = Math.scaleToUp(local, l.ratedScales[j]);
        if (local == amountOut) return debit;
        bytes memory state = ContextQuote.exactOutputState(se, l.tokens[j], manager);
        uint256 shares = ContextQuote.withdrawFromState(se, l.tokens[j], amountOut - local, state);
        if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        if (shares >= l.seReserves[j]) revert Math.WouldZeroReserve();
        if (state.length == 0) return debit + ratedWadForNativeUp(j, shares);
        uint256 wad = FullMath.mulDiv(shares, l.invScales[j], Math.RATE_PRECISION, FullMath.Rounding.Ceil);
        return debit + FullMath.mulDiv(wad, ContextQuote.rateFromState(se, l.tokens[j], l.rateProviders[j], state), Math.RATE_PRECISION, FullMath.Rounding.Ceil);
    }

    function _inputForRatedContext(uint8 i, uint256 needed, address manager) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0) || disabled(i)) return pairInputForRated(i, needed);
        bytes memory state = ContextQuote.exactOutputState(se, l.tokens[i], manager);
        if (state.length == 0) return pairInputForRated(i, needed);
        uint256 shares = _sharesForRatedContext(i, needed, state);
        if (shares == 0) return 0;
        uint256 input = ContextQuote.inputForSharesFromState(se, l.tokens[i], shares, state);
        if (input == 0) revert SeInvertUnavailable();
        (,, uint256 minted,) = Transition(se).quoteTransition(state, Transition.Operation.DepositExactIn, input);
        if (minted < shares) revert SeInvertUnavailable();
        return input;
    }

    function _sharesForRatedContext(uint8 i, uint256 needed, bytes memory state) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 rate = ContextQuote.rateFromState(l.standardExchanges[i], l.tokens[i], l.rateProviders[i], state);
        uint256 sharesWad = FullMath.mulDiv(needed, Math.RATE_PRECISION, rate, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(sharesWad, Math.RATE_PRECISION, l.invScales[i], FullMath.Rounding.Ceil);
    }

    function pairInputForRated(uint8 i, uint256 ratedWad) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 pair = Math.descaleUp(ratedWad, l.ratedScales[i]);
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            address rp = l.rateProviders[i];
            return rp == address(0) ? pair : Math.sharesForPairUnitsUp(pair, _getRateFailClosed(rp), l.invScales[i], l.ratedScales[i]);
        }
        if (se == l.tokens[i] || disabled(i)) return pair;
        return bufferInputForShares(se, l.tokens[i], nativeForRatedWad(i, ratedWad, true));
    }

    function getRateFailClosed(address rp) external view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        (bool ok, bytes memory data) =
            rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length < 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function seClaimOf(address se, address pairToken, uint256 seAmount) external view returns (uint256) {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        return quotedAmountOut;
    }

    function previewBufferShares(address se, address pairToken, uint256 amountInRaw)
        external
        view
        returns (uint256 sharesOut)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        return quotedAmountOut;
    }

    function previewUnwrap(address se, address pairToken, uint256 seAmount)
        external
        view
        returns (uint256 amountOut)
    {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        return quotedAmountOut;
    }

    function invertUnwrapExactTokenOut(address se, address pairToken, uint256 amountOutNative)
        external
        view
        returns (uint256 sharesIn)
    {
        if (amountOutNative == 0) return 0;
        if (se == pairToken) return amountOutNative;
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOutNative);
    }

    function invertBufferExactSharesOut(address se, address pairToken, uint256 sharesOut)
        external
        view
        returns (uint256 amountInRaw)
    {
        return bufferInputForShares(se, pairToken, sharesOut);
    }

    /// @dev Context-capable exchanges require their actual inverse in every manager state.
    /// Non-context legs retain the b019f232 forward-verified compatibility calculation.
    function bufferInputForShares(address se, address pairToken, uint256 sharesOut)
        internal view returns (uint256)
    {
        if (sharesOut == 0) return 0;
        if (se == pairToken) return sharesOut;
        uint256 high = IStandardExchangeOut(se).previewExchangeOut(IERC20(pairToken), IERC20(se), sharesOut);
        if (high != 0 && ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(pairToken), high, IERC20(se)) >= sharesOut) {
            return high;
        }
        if (ContextQuote.supported(se)) revert SeInvertUnavailable();
        if (high == 0) high = sharesOut;
        uint256 low;
        while (ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(pairToken), high, IERC20(se)) < sharesOut) {
            low = high;
            if (high > type(uint256).max / 2) revert SeInvertUnavailable();
            high *= 2;
        }
        while (high - low > 1) {
            uint256 mid = low + (high - low) / 2;
            if (ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(pairToken), mid, IERC20(se)) >= sharesOut) high = mid;
            else low = mid;
        }
        return high;
    }

    function buffer(address se, address pairToken, uint256 amountInRaw) public returns (uint256 sharesOut) {
        if (amountInRaw == 0) return 0;(uint256 minOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(pairToken).forceApprove(se, amountInRaw);
        uint256 balBefore = IERC20(se).balanceOf(address(this));(sharesOut,) = IStandardExchangeIn(se).exchangeIn(IERC20(pairToken),
            amountInRaw,
            IERC20(se),
            minOut,
            address(this),
            false,
            block.timestamp
        );
        IERC20(pairToken).forceApprove(se, 0);
        uint256 delta = IERC20(se).balanceOf(address(this)) - balBefore;
        if (delta > sharesOut) sharesOut = delta;
        if (sharesOut < minOut) revert BufferFailed();
    }

    function unwrap(address se, address pairToken, uint256 seAmount, address to)
        external
        returns (uint256 amountOut)
    {
        if (seAmount == 0) return 0;(uint256 minOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        if (minOut == 0) revert UnwrapFailed();
        IERC20(se).forceApprove(se, seAmount);(amountOut,) = IStandardExchangeIn(se).exchangeIn(IERC20(se), seAmount, IERC20(pairToken), minOut, to, false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        if (amountOut < minOut) revert UnwrapFailed();
    }

    function unwrapExactTokenOut(address se, address pairToken, uint256 amountOut, address to)
        external
        returns (uint256 seIn)
    {
        if (amountOut == 0) return 0;
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), amountOut);
        uint256 beforeBalance = IERC20(pairToken).balanceOf(address(this));
        IERC20(se).forceApprove(se, seIn);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(pairToken), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        uint256 received = IERC20(pairToken).balanceOf(address(this)) - beforeBalance;
        if (spent > seIn || received < amountOut) revert UnwrapFailed();
        if (to != address(this)) IERC20(pairToken).safeTransfer(to, amountOut);
        uint256 surplus = received - amountOut;
        if (surplus != 0 && ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(pairToken), surplus, IERC20(se)) != 0) {
            buffer(se, pairToken, surplus);
        }
        return spent;
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw, address hook)
        external
        view
        returns (uint256)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;(uint256 sharesOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        uint256 seBalBefore = IERC20(se).balanceOf(hook);uint256 claimBefore = seBalBefore == 0
            ? 0
            : ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(se), seBalBefore, IERC20(pairToken));(uint256 claimAfter,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore + sharesOut, IERC20(pairToken));
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }
}

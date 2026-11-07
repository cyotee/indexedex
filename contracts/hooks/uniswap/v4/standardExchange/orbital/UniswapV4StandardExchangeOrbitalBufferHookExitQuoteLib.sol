// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";

/// @notice Sequential withdrawal, swap and deposit quotes for the Orbital LP.
library UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib {
    struct Leg {
        address se;
        address asset;
        address rateProvider;
        bytes state;
        bool unprojected;
        uint8 decimals;
        uint256 rate;
        uint256 shares;
        uint256 local;
        uint256 effective;
        uint256 withdrawn;
        /// @dev Shares redeemed to pay this leg's last simulated swap output. Zero for a raw leg.
        uint256 redeemShares;
    }

    function preview(uint256 lp, uint256 supply, address tokenOut) external view returns (uint256 amountOut) {
        if (lp == 0 || supply == 0 || lp >= supply) return 0;
        Repo.Layout storage l = Repo._layout();
        address pair = l.legs.pairOfStandardExchange[tokenOut];
        bool asShare = pair != address(0);
        if (!asShare) pair = tokenOut;
        uint8 outIndex = Repo._indexOf(l, pair);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, lp, supply);
        amountOut = legs[outIndex].withdrawn;
        for (uint8 i; i < 3; ++i) {
            if (i != outIndex && legs[i].withdrawn != 0) amountOut += _swap(legs, i, outIndex);
        }
        if (asShare && amountOut > 0) {
            if (Repo._isDisabled(tokenOut)) revert IVaultRegistryDisableQuery.VaultDisabled(tokenOut);
            (ExchangeInAmount.Result memory result,) = ClaimLib.conversionQuote(tokenOut, pair, amountOut, false, legs[outIndex].state, false);
            if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
            amountOut = result.amountOut;
        }
    }

    function _withdraw(uint8 index, uint256 lp, uint256 supply) private view returns (Leg memory leg) {
        Repo.Layout storage l = Repo._layout();
        leg.asset = Repo._tokenAt(l, index);
        leg.se = Repo._seAt(l, index);
        leg.rateProvider = Repo._rpAt(l, index);
        leg.decimals = Repo._decimalsAt(l, index);
        leg.local = l.reserves[leg.asset];
        uint256 localOut = LiquidityRoute.componentAllocation(lp, leg.local, supply);
        leg.local -= localOut;
        leg.withdrawn = localOut;
        if (leg.se != address(0)) {
            leg.state = ContextQuote.snapshot(leg.se, leg.asset, address(this), address(0));
            leg.shares = l.seShares[leg.se];
            uint256 removed = LiquidityRoute.componentAllocation(lp, leg.shares, supply);
            leg.shares -= removed;
            if (removed != 0) {
                ExchangeInAmount.Result memory result;
                (result, leg.state) = ClaimLib.conversionQuote(leg.se, leg.asset, removed, true, leg.state, false);
                if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
                if (leg.state.length == 0 && removed != result.amountRefunded) leg.unprojected = true;
                leg.withdrawn += result.amountOut;
            }
        }
        _refresh(leg);
    }

    function _refresh(Leg memory leg) private view {
        if (leg.se == address(0)) {
            leg.effective = ClaimLib.effectiveNative(address(0), leg.rateProvider, leg.asset, leg.local, 0);
            return;
        }
        if (leg.rateProvider == address(0)) revert ClaimLib.RateProviderRequired();
        if (leg.unprojected) revert Transition.InvalidQuoteState();
        leg.rate = leg.state.length == 0 ? ClaimLib.getRateFailClosed(leg.rateProvider)
            : ContextQuote.rateFromState(leg.se, leg.asset, leg.rateProvider, leg.state);
        leg.effective = leg.local + ClaimLib.ratedNative(leg.shares, leg.rate, leg.se, leg.asset);
    }

    function _swap(Leg[3] memory legs, uint8 from, uint8 to) private view returns (uint256 received) {
        Leg memory input = legs[from];
        ExchangeInAmount.Result memory result;
        bytes memory next;
        uint256 added = input.withdrawn;
        bool buffer = input.se != address(0) && !Repo._isDisabled(input.se);
        if (buffer) {
            (result, next) = ClaimLib.conversionQuote(input.se, input.asset, input.withdrawn, false, input.state, false);
            added = result.amountRefunded + ClaimLib.ratedNative(result.amountOut, input.rate, input.se, input.asset);
        }
        received = _receiveOutput(legs[to], _saleBudget(legs, from, to, added, true));
        if (buffer) {
            input.shares += result.amountOut;
            input.local += result.amountRefunded;
            input.state = next;
            if (next.length == 0 && input.withdrawn != result.amountRefunded) input.unprojected = true;
        } else input.local += input.withdrawn;
        _refresh(input);
    }

    function _receiveOutput(Leg memory output, uint256 budget) private view returns (uint256 received) {
        uint256 local = FullMath.min(output.local, budget);
        output.local -= local;
        received = local;
        output.redeemShares = 0;
        if (budget > local) {
            if (output.se == address(0)) revert Math.Drain();
            uint256 shares = ClaimLib.sharesForNativeUp(budget - local, output.rate, output.se, output.asset);
            if (shares == 0 || shares >= output.shares) revert Math.Drain();
            output.redeemShares = shares;
            ExchangeInAmount.Result memory result;
            (result, output.state) = ClaimLib.conversionQuote(output.se, output.asset, shares, true, output.state, false);
            output.shares -= ExchangeInAmount.consumedInput(shares, result.amountRefunded);
            if (output.state.length == 0 && shares != result.amountRefunded) output.unprojected = true;
            received += result.amountOut;
        }
        if (received == 0) revert Math.Drain();
        _refresh(output);
    }

    function _sale(Leg[3] memory legs, uint8 from, uint8 to, uint256 added) private view returns (uint256 out) {
        out = _saleBudget(legs, from, to, added, true);
        if (legs[to].se != address(0)) out = _unwrapPayout(legs[to], out);
        if (out == 0) revert Math.Drain();
    }

    function _saleBudget(Leg[3] memory legs, uint8 from, uint8 to, uint256 added, bool capped) private view returns (uint256 out) {
        Repo.Layout storage l = Repo._layout();
        uint256 x = _toWad(legs[from].effective, legs[from].decimals);
        uint256 y = _toWad(legs[to].effective, legs[to].decimals);
        uint256 z = _toWad(legs[3 - from - to].effective, legs[3 - from - to].decimals);
        uint256 net = Math.applyTradingFeeNet(
            _toWad(added, legs[from].decimals), IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this))
        );
        uint256 output = capped ? _cappedSphereOut(l.R, x, y, z, net)
            : Math.sphereExactInOutWad(l.R, Math.recomputeL2(l.R, x, y, z), x, y, z, net);
        out = Math.fromWadFloor(output, legs[to].decimals);
        if (out == 0 || out >= legs[to].effective) revert Math.Drain();
    }

    /// @dev Rated units back to native shares through the leg's rate, then the SE's own unwrap quote for
    ///      the payout (a buffering-operation quote, not a reserve valuation). Separate frame for stack depth.
    function _unwrapPayout(Leg memory leg, uint256 budget) private view returns (uint256) {
        uint256 local = FullMath.min(leg.local, budget);
        if (budget == local) return local;
        uint256 shares = ClaimLib.sharesForNativeUp(budget - local, leg.rate, leg.se, leg.asset);
        (ExchangeInAmount.Result memory result,) = ClaimLib.conversionQuote(leg.se, leg.asset, shares, true, leg.state, false);
        return local + result.amountOut;
    }

    /// @dev Clamp inflow so xPrime stays strictly inside the sphere. Wrap-sized
    /// custom-bond sales otherwise revert MathDomain (xPrime >= R).
    function _cappedSphereOut(uint256 R, uint256 x, uint256 y, uint256 z, uint256 net)
        private
        view
        returns (uint256)
    {
        if (net == 0 || x + 1 >= R || y + 1 >= R || z + 1 >= R) revert Math.Drain();
        if (net > R - x - 1) net = R - x - 1;
        if (net == 0) revert Math.Drain();
        return Math.sphereExactInOutWad(R, Math.recomputeL2(R, x, y, z), x, y, z, net);
    }

    function _toWad(uint256 amount, uint8 decimals) private pure returns (uint256) {
        return decimals <= 18 ? amount * (10 ** (18 - decimals)) : amount / (10 ** (decimals - 18));
    }
    struct JoinQuote {
        uint256[3] shares;
        uint256[3] local;
        uint256[3] bookShares;
        uint256[3] bookLocal;
        uint256[3] purchased;
        uint256[3] rates;
    }

    /// @dev Simulate the same sequential paid sales as execution, then freeze the
    /// incumbent component book. Opaque SE state is optional, never fabricated.
    function quotePreparedJoin(uint256[3] memory amounts, bool[3] memory flags)
        public view returns (JoinQuote memory q)
    {
        return _quotePreparedJoin(amounts, flags, 3, bytes(""));
    }

    function _quotePreparedJoin(uint256[3] memory amounts, bool[3] memory flags, uint8 stateIndex, bytes memory state)
        private view returns (JoinQuote memory q)
    {
        Repo.Layout storage l = Repo._layout();
        if (stateIndex < 3 && flags[stateIndex] && state.length != 0) {
            (state,,,) = Transition(Repo._seAt(l, stateIndex)).quoteTransition(
                state, Transition.Operation.ReceiveShares, amounts[stateIndex]
            );
        }
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            q.bookShares[i] = l.seShares[se];
            q.bookLocal[i] = l.reserves[Repo._tokenAt(l, i)];
            if (flags[i]) q.shares[i] = amounts[i];
            else q.local[i] = amounts[i];
            if (se != address(0) && (q.bookShares[i] != 0 || q.shares[i] != 0)) {
                q.rates[i] = i == stateIndex && state.length != 0
                    ? ContextQuote.rateFromState(se, Repo._tokenAt(l, i), Repo._rpAt(l, i), state)
                    : ClaimLib.getRateFailClosed(Repo._rpAt(l, i));
            }
        }
        q = prepareInKind(q, amounts);
        for (uint8 i; i < 3; ++i) {
            if ((q.bookShares[i] != 0 || q.bookLocal[i] != 0) && q.shares[i] == 0 && q.local[i] == 0) return q;
        }
        // Paid trades precede caller-only SE conversion; no later trade prices an unprojected state.
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            if (se == address(0) || amounts[i] == 0) continue;
            uint256 remaining = flags[i] ? q.shares[i] : q.local[i];
            ClaimLib.Contribution memory c = ClaimLib.quoteHeldContribution(se, Repo._tokenAt(l, i),
                q.bookShares[i], q.bookLocal[i], remaining, flags[i], false,
                i == stateIndex ? state : bytes(""), i != stateIndex);
            q.shares[i] = c.shares;
            q.local[i] = c.local;
        }
    }

    /// @dev Paid output stays in its native share/local components. Rates price the
    /// trade only; LP entitlement is computed later from the six native components.
    function prepareInKind(JoinQuote memory q, uint256[3] memory amounts)
        public view returns (JoinQuote memory)
    {
        Repo.Layout storage l = Repo._layout();
        uint256[3] memory weights;
        uint256 total;
        for (uint8 i; i < 3; ++i) {
            weights[i] = Math.toWad(_joinValue(q, i, q.bookShares[i], q.bookLocal[i]), Repo._decimalsAt(l, i));
            total += weights[i];
        }
        uint256 emptyWeight = total / 3;
        for (uint8 i; i < 3; ++i) {
            if (amounts[i] != 0 && weights[i] == 0) {
                weights[i] = emptyWeight;
                total += emptyWeight;
            }
        }
        for (uint8 i; i < 3; ++i) {
            if (amounts[i] == 0) continue;
            uint256 shares = q.shares[i];
            uint256 local = q.local[i];
            for (uint8 j; j < 3; ++j) {
                if (amounts[j] != 0 || weights[j] == 0) continue;
                uint256 saleShares = FullMath.mulDiv(shares, weights[j], total);
                uint256 saleLocal = FullMath.mulDiv(local, weights[j], total);
                uint256 paid = _joinValue(q, i, saleShares, saleLocal);
                if (paid == 0) continue;
                uint256 output = _joinSaleBudget(q, i, j, paid);
                if (output == 0) continue;
                uint256 outputValue = _joinValue(q, j, q.bookShares[j], q.bookLocal[j]);
                uint256 boughtShares = FullMath.mulDiv(q.bookShares[j], output, outputValue);
                uint256 boughtLocal = FullMath.mulDiv(q.bookLocal[j], output, outputValue);
                if (boughtShares == 0 && boughtLocal == 0) continue;
                q.shares[i] -= saleShares;
                q.local[i] -= saleLocal;
                q.bookShares[i] += saleShares;
                q.bookLocal[i] += saleLocal;
                q.bookShares[j] -= boughtShares;
                q.bookLocal[j] -= boughtLocal;
                q.shares[j] += boughtShares;
                q.local[j] += boughtLocal;
                q.purchased[j] += boughtLocal;
            }
        }
        return q;
    }

    /// @dev One ordered excess-to-deficit pass, including nonempty deficient legs.
    /// Sales are fractions of the caller's original native components, not rated LP credit.
    function prepareNativeInKind(JoinQuote memory q) public view returns (JoinQuote memory) {
        Repo.Layout storage l = Repo._layout();
        uint256[3] memory weights;
        uint256[3] memory offered;
        uint256[3] memory deficits;
        uint256 totalBook;
        uint256 totalOffered;
        for (uint8 i; i < 3; ++i) {
            weights[i] = Math.toWad(_joinValue(q, i, q.bookShares[i], q.bookLocal[i]), Repo._decimalsAt(l, i));
            offered[i] = Math.toWad(_joinValue(q, i, q.shares[i], q.local[i]), Repo._decimalsAt(l, i));
            totalBook += weights[i];
            totalOffered += offered[i];
        }
        if (totalBook == 0 || totalOffered == 0) return q;
        uint256[3] memory excess;
        uint256 totalDeficit;
        for (uint8 i; i < 3; ++i) {
            uint256 target = FullMath.mulDiv(totalOffered, weights[i], totalBook);
            if (offered[i] > target) excess[i] = offered[i] - target;
            else {
                deficits[i] = target - offered[i];
                totalDeficit += deficits[i];
            }
        }
        if (totalDeficit == 0) return q;
        for (uint8 i; i < 3; ++i) {
            if (excess[i] == 0) continue;
            uint256 shares = q.shares[i];
            uint256 local = q.local[i];
            for (uint8 j; j < 3; ++j) {
                if (deficits[j] == 0) continue;
                uint256 sale = FullMath.mulDiv(excess[i], deficits[j], totalDeficit);
                uint256 saleShares = FullMath.mulDiv(shares, sale, offered[i]);
                uint256 saleLocal = FullMath.mulDiv(local, sale, offered[i]);
                uint256 paid = _joinValue(q, i, saleShares, saleLocal);
                if (paid == 0) continue;
                uint256 output = _joinSaleBudget(q, i, j, paid);
                uint256 outputValue = _joinValue(q, j, q.bookShares[j], q.bookLocal[j]);
                uint256 boughtShares = FullMath.mulDiv(q.bookShares[j], output, outputValue);
                uint256 boughtLocal = FullMath.mulDiv(q.bookLocal[j], output, outputValue);
                if (boughtShares == 0 && boughtLocal == 0) continue;
                q.shares[i] -= saleShares;
                q.local[i] -= saleLocal;
                q.bookShares[i] += saleShares;
                q.bookLocal[i] += saleLocal;
                q.bookShares[j] -= boughtShares;
                q.bookLocal[j] -= boughtLocal;
                q.shares[j] += boughtShares;
                q.local[j] += boughtLocal;
                q.purchased[j] += boughtLocal;
            }
        }
        return q;
    }

    function _joinValue(JoinQuote memory q, uint8 i, uint256 shares, uint256 local)
        private view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return ClaimLib.effectiveNative(se, Repo._rpAt(l, i), Repo._tokenAt(l, i), local, 0);
        return local + ClaimLib.ratedNative(shares, q.rates[i], se, Repo._tokenAt(l, i));
    }

    function _joinSaleBudget(JoinQuote memory q, uint8 from, uint8 to, uint256 paid)
        private view returns (uint256 output)
    {
        Repo.Layout storage l = Repo._layout();
        uint256[3] memory e;
        for (uint8 i; i < 3; ++i) {
            e[i] = Math.toWad(_joinValue(q, i, q.bookShares[i], q.bookLocal[i]), Repo._decimalsAt(l, i));
        }
        uint256 net = Math.applyTradingFeeNet(Math.toWad(paid, Repo._decimalsAt(l, from)),
            IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this)));
        output = Math.fromWadFloor(Math.sphereLiquidityExactInOutWad(l.R,
            Math.recomputeL2(l.R, e[from], e[to], e[3 - from - to]), e[from], e[to], e[3 - from - to], net),
            Repo._decimalsAt(l, to));
        if (Math.toWad(output, Repo._decimalsAt(l, to)) >= e[to]) revert Math.Drain();
    }

    /// @notice Caller-owned SE shares buy the missing legs before mint acceptance.
    function previewShareDeposit(address tokenIn, uint256 amountIn) external view returns (uint256 net) {
        Repo.Layout storage l = Repo._layout();
        uint8 index = Repo._indexOf(l, l.legs.pairOfStandardExchange[tokenIn]);
        (net,) = _singleDeposit(index, amountIn, true, bytes(""));
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn) external view returns (uint256 net) {
        Repo.Layout storage l = Repo._layout();
        uint8 index = Repo._indexOf(l, pairToken);
        LegLib.ExternalQuote memory q = _externalDeposit(Repo._seAt(l, index), pairToken, tokenIn, amountIn);
        (net,) = _singleDeposit(index, q.assets, true, q.state);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = Repo._indexOf(l, pairToken);
        uint8 rawIndex = Repo._indexOf(l, detfToken);
        if (index == rawIndex || Repo._seAt(l, rawIndex) != address(0)) revert Math.MathDomain();
        LegLib.ExternalQuote memory q = _externalDeposit(Repo._seAt(l, index), pairToken, tokenIn, amountIn);
        return _bondAtExternalState(q, index, rawIndex, multiplier);
    }

    function _externalDeposit(address se, address pair, address tokenIn, uint256 amountIn)
        private view returns (LegLib.ExternalQuote memory q)
    {
        if (tokenIn != se && Repo._isDisabled(se)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        if (tokenIn == se) {
            // Transferring already-owned shares does not change the SE's global state.
            q.exchange = Transition(se);
            q.pair = pair;
            q.assets = amountIn;
        } else {
            // Ordinary external-deposit projection does not require the separate
            // PoolManager-unlock extension. Never substitute live state here.
            q = LegLib.afterExternalDeposit(se, pair, tokenIn, amountIn, address(this));
        }
        q.heldShares = Repo._layout().seShares[se];
    }

    function _bondAtExternalState(LegLib.ExternalQuote memory q, uint8 index, uint8 rawIndex, uint256 multiplier)
        private view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf)
    {
        (ExchangeInAmount.Result memory value,) = ClaimLib.conversionQuote(address(q.exchange), q.pair, q.assets, true, q.state, true);
        pairValue = value.amountOut;
        if (ERC20Repo._totalSupply() == 0) return (pairValue, 0, 0);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        legs[index].state = q.state;
        _refresh(legs[index]);
        (ExchangeInAmount.Result memory backing,) = ClaimLib.conversionQuote(address(q.exchange), q.pair, legs[index].shares, true, q.state, false);
        uint256 totalPair = legs[index].local + backing.amountOut;
        if (totalPair != 0) liquidityDetf = FullMath.mulDiv(legs[rawIndex].local, pairValue, totalPair);
        purchasedDetf = _saleBudget(legs, index, rawIndex,
            _claimIn(legs[index], FullMath.mulDiv(pairValue, multiplier, 1e18)), false);
    }

    /// @notice Quote caller-paid preparation and the proportional component mint.
    function previewDepositReceipt(address tokenIn, uint256 amount)
        external view returns (uint256 net, uint256 refund)
    {
        Repo.Layout storage l = Repo._layout();
        address pair = l.legs.pairOfStandardExchange[tokenIn];
        bool asShare = pair != address(0);
        return _singleDeposit(Repo._indexOf(l, asShare ? pair : tokenIn), amount, asShare, bytes(""));
    }

    function _singleDeposit(uint8 index, uint256 amount, bool asShare, bytes memory state)
        private view returns (uint256 net, uint256 refund)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || amount == 0) return (0, amount);
        uint256[3] memory amounts;
        bool[3] memory flags;
        amounts[index] = amount;
        flags[index] = asShare;
        JoinQuote memory q = _quotePreparedJoin(amounts, flags, state.length == 0 ? 3 : index, state);
        uint256[] memory available = new uint256[](6);
        uint256[] memory booked = new uint256[](6);
        for (uint8 i; i < 3; ++i) {
            booked[2 * i] = q.bookShares[i];
            booked[2 * i + 1] = q.bookLocal[i];
            available[2 * i] = q.shares[i];
            available[2 * i + 1] = q.local[i];
        }
        uint256 gross = LiquidityRoute.maxComponentMint(available, booked, supply);
        (net,,) = ClaimLib.netMint(gross);
        refund = (asShare ? q.shares[index] : q.local[index]) - LiquidityRoute.componentContribution(
            gross, booked[2 * index + (asShare ? 0 : 1)], supply
        );
    }

    function _claimIn(Leg memory leg, uint256 amount) private view returns (uint256) {
        if (amount == 0 || leg.se == address(0) || Repo._isDisabled(leg.se)) return amount;
        (ExchangeInAmount.Result memory result,) = ClaimLib.conversionQuote(leg.se, leg.asset, amount, false, leg.state, false);
        return result.amountRefunded + ClaimLib.ratedNative(result.amountOut, leg.rate, leg.se, leg.asset);
    }




}

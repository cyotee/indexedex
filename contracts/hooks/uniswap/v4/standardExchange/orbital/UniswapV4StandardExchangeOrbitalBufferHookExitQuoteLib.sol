// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
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
        uint8 decimals;
        uint256 rate;
        uint256 shares;
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
            (,, amountOut,) = Transition(tokenOut).quoteTransition(
                legs[outIndex].state, Transition.Operation.DepositExactIn, amountOut
            );
        }
    }

    function _withdraw(uint8 index, uint256 lp, uint256 supply) private view returns (Leg memory leg) {
        Repo.Layout storage l = Repo._layout();
        address token = Repo._tokenAt(l, index);
        leg.asset = token;
        leg.se = Repo._seAt(l, index);
        leg.decimals = Repo._decimalsAt(l, index);
        if (leg.se == address(0)) {
            leg.effective = l.reserves[token];
            leg.withdrawn = leg.effective * lp / supply;
            leg.effective -= leg.withdrawn;
        } else {
            leg.rateProvider = Repo._rpAt(l, index);
            (leg.state,) = Transition(leg.se).quoteState(token, address(this));
            leg.shares = Transition(leg.se).quoteShareBalance(leg.state);
            uint256 removed = leg.shares * lp / supply;
            if (removed != 0) {
                (leg.state,, leg.withdrawn,) = Transition(leg.se).quoteTransition(
                    leg.state, Transition.Operation.RedeemExactIn, removed
                );
            }
            _refresh(leg);
        }
    }

    function _refresh(Leg memory leg) private view {
        leg.shares = Transition(leg.se).quoteShareBalance(leg.state);
        // D60: a buffered leg always carries a rate provider; the held reserve is shares x rate, never the
        // SE's own valuation. `rateAfterExchange` fails closed on a missing or zero rate.
        if (leg.rateProvider == address(0)) revert ClaimLib.RateProviderRequired();
        LegLib.ExternalQuote memory q;
        q.exchange = Transition(leg.se);
        q.state = leg.state;
        leg.rate = LegLib.rateAfterExchange(q, leg.asset, leg.rateProvider);
        leg.effective = ClaimLib.ratedNative(leg.shares, leg.rate, leg.se, leg.asset);
    }

    function _swap(Leg[3] memory legs, uint8 from, uint8 to) private view returns (uint256 received) {
        Leg memory input = legs[from];
        Leg memory output = legs[to];
        uint256 added = input.withdrawn;
        bytes memory nextInput;
        if (input.se != address(0)) {
            uint256 minted;
            (nextInput,, minted,) = Transition(input.se).quoteTransition(
                input.state, Transition.Operation.DepositExactIn, input.withdrawn
            );
            // Mirror the family's retained face-to-effective conversion at the
            // post-withdrawal state, before buffering this residual input.
            added = ClaimLib.ratedNative(minted, input.rate, input.se, input.asset);
            if (added == 0) added = input.withdrawn;
        }
        uint256 effectiveOut = _saleBudget(legs, from, to, added);
        received = _receiveOutput(output, effectiveOut);
        legs[to].redeemShares = output.redeemShares;
        if (input.se == address(0)) input.effective += input.withdrawn;
        else {
            input.state = nextInput;
            _refresh(input);
        }
    }

    function _receiveOutput(Leg memory output, uint256 effectiveOut) private view returns (uint256 received) {
        if (output.se == address(0)) {
            output.effective -= effectiveOut;
            received = effectiveOut;
        } else {
            uint256 shares = ClaimLib.sharesForNativeUp(effectiveOut, output.rate, output.se, output.asset);
            uint256 cap = output.shares > 1 ? output.shares - 1 : 0;
            if (shares == 0 || shares > cap) revert Math.Drain();
            output.redeemShares = shares;
            (bytes memory next,, uint256 paid,) = Transition(output.se).quoteTransition(
                output.state, Transition.Operation.RedeemExactIn, shares
            );
            if (paid == 0) revert Math.Drain();
            output.state = next;
            received = paid;
            _refresh(output);
        }
    }

    function _sale(Leg[3] memory legs, uint8 from, uint8 to, uint256 added) private view returns (uint256 out) {
        out = _saleBudget(legs, from, to, added);
        if (legs[to].se != address(0)) out = _unwrapPayout(legs[to], out);
        if (out == 0) revert Math.Drain();
    }

    function _saleBudget(Leg[3] memory legs, uint8 from, uint8 to, uint256 added) private view returns (uint256 out) {
        Repo.Layout storage l = Repo._layout();
        uint256 x = _toWad(legs[from].effective, legs[from].decimals);
        uint256 y = _toWad(legs[to].effective, legs[to].decimals);
        uint256 z = _toWad(legs[3 - from - to].effective, legs[3 - from - to].decimals);
        uint256 net = Math.applyTradingFeeNet(
            _toWad(added, legs[from].decimals), IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this))
        );
        out = Math.fromWadFloor(_cappedSphereOut(l.R, x, y, z, net), legs[to].decimals);
        if (out == 0 || out >= legs[to].effective) revert Math.Drain();
    }

    /// @dev Rated units back to native shares through the leg's rate, then the SE's own unwrap quote for
    ///      the payout (a buffering-operation quote, not a reserve valuation). Separate frame for stack depth.
    function _unwrapPayout(Leg memory leg, uint256 out) private view returns (uint256) {
        return Transition(leg.se).quoteAssets(leg.state, ClaimLib.sharesForNativeUp(out, leg.rate, leg.se, leg.asset));
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
    /// @notice Quote the retained zap after receiving and redeeming an SE-share payment.
    /// @dev Project redemption and both zap swaps before pricing the final deposit.
    function previewShareDeposit(address tokenIn, uint256 amountIn) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint8 index = Repo._indexOf(l, l.legs.pairOfStandardExchange[tokenIn]);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        Leg memory input = legs[index];
        (input.state,,,) = Transition(tokenIn).quoteTransition(
            input.state, Transition.Operation.ReceiveShares, amountIn
        );
        (input.state,, amountIn,) = Transition(tokenIn).quoteTransition(
            input.state, Transition.Operation.RedeemExactIn, amountIn
        );
        _refresh(input);
        return _depositAtState(legs, index, amountIn);
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        uint8 index = Repo._indexOf(Repo._layout(), pairToken);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        Leg memory input = legs[index];
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(input.se, pairToken, tokenIn, amountIn, address(this));
        (input.state,,,) = Transition(input.se).quoteTransition(q.state, Transition.Operation.ReceiveShares, q.assets);
        (input.state,, amountIn,) = Transition(input.se).quoteTransition(input.state, Transition.Operation.RedeemExactIn, q.assets);
        _refresh(input);
        return _depositAtState(legs, index, amountIn);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = Repo._indexOf(l, pairToken);
        uint8 rawIndex = Repo._indexOf(l, detfToken);
        if (index == rawIndex || Repo._seAt(l, rawIndex) != address(0)) revert Math.MathDomain();
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(Repo._seAt(l, index), pairToken, tokenIn, amountIn, address(this));
        return _bondAtExternalState(q, index, rawIndex, multiplier);
    }

    function _bondAtExternalState(LegLib.ExternalQuote memory q, uint8 index, uint8 rawIndex, uint256 multiplier)
        private view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf)
    {
        pairValue = q.exchange.quoteAssets(q.state, q.assets);
        if (IERC20(address(this)).totalSupply() == 0) return (pairValue, 0, 0);
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        legs[index].state = q.state;
        _refresh(legs[index]);
        liquidityDetf = LegLib.matchingLiquidityDetf(q, legs[rawIndex].effective, pairValue, _depositSupply(legs), 0);
        uint256 boosted = FullMath.mulDiv(pairValue, multiplier, 1e18);
        purchasedDetf = _sale(legs, index, rawIndex, _claimIn(legs[index], boosted));
    }

    struct DepositQuote {
        uint8 input;
        uint8 j;
        uint8 k;
        uint256 supply;
        uint256 saleJ;
        uint256 saleK;
        uint256 shares;
        uint256[3] offered;
        uint256[3] used;
        uint256 sharesJ;
        uint256 sharesK;
    }

    /// @notice Plan a ratio zap against the SE state produced by each preceding swap.
    function planDeposit(address tokenIn, uint256 amount) external view returns (DepositQuote memory q) {
        Leg[3] memory legs;
        for (uint8 i; i < 3; ++i) legs[i] = _withdraw(i, 0, 1);
        q = _depositQuote(legs, Repo._indexOf(Repo._layout(), tokenIn));
        _planDeposit(legs, q, amount);
    }

    function _depositAtState(Leg[3] memory legs, uint8 index, uint256 amount) private view returns (uint256) {
        DepositQuote memory q = _depositQuote(legs, index);
        uint256 radius = Repo._layout().R;
        uint256 e0 = Math.toWad(legs[0].effective, legs[0].decimals);
        uint256 e1 = Math.toWad(legs[1].effective, legs[1].decimals);
        uint256 e2 = Math.toWad(legs[2].effective, legs[2].decimals);
        if (radius == 0 || e0 == 0 || e1 == 0 || e2 == 0
            || e0 + 1 >= radius || e1 + 1 >= radius || e2 + 1 >= radius
            || (legs[index].effective > 0 && amount > legs[index].effective
                && (legs[q.j].effective < amount / 4 || legs[q.k].effective < amount / 4)))
        {
            return _partialDepositAtState(legs, q, amount);
        }
        _planDeposit(legs, q, amount);
        return q.shares;
    }

    function _depositQuote(Leg[3] memory legs, uint8 index) private view returns (DepositQuote memory q) {
        q.input = index;
        q.j = index == 0 ? 1 : 0;
        q.k = 3 - index - q.j;
        q.supply = _depositSupply(legs);
    }

    function _planDeposit(Leg[3] memory legs, DepositQuote memory q, uint256 amount) private view {
        _depositSales(legs, q, amount);
        _depositOutputs(legs, q);
        _planRawTerminal(legs, q);
    }

    /// @dev Terminal admission after rated swaps. Inventory is the projected post-swap
    ///      raw book, not live balances and not rated `effective`.
    function _planRawTerminal(Leg[3] memory legs, DepositQuote memory q) private view {
        if (q.supply == 0) return;
        uint256 b0 = _rawHeld(legs[0]);
        uint256 b1 = _rawHeld(legs[1]);
        uint256 b2 = _rawHeld(legs[2]);
        if (b0 == 0 || b1 == 0 || b2 == 0) return;
        uint256 c0 = _rawOffer(legs[0], q.offered[0]);
        uint256 c1 = _rawOffer(legs[1], q.offered[1]);
        uint256 c2 = _rawOffer(legs[2], q.offered[2]);
        q.shares = Math.rawFullBookShares(q.supply, c0, b0, c1, b1, c2, b2);
        if (q.shares == 0) return;
        q.used[0] = _faceForRawOffer(legs[0], _bufferedRequired(q.shares, b0, q.supply, legs[0], q.offered[0]), q.offered[0]);
        q.used[1] = _faceForRawOffer(legs[1], _bufferedRequired(q.shares, b1, q.supply, legs[1], q.offered[1]), q.offered[1]);
        q.used[2] = _faceForRawOffer(legs[2], _bufferedRequired(q.shares, b2, q.supply, legs[2], q.offered[2]), q.offered[2]);
    }

    function _rawHeld(Leg memory leg) private pure returns (uint256) {
        if (leg.se == address(0)) return leg.effective;
        return leg.shares;
    }

    /// @dev Projected share mint for a terminal face offer. Zero mint is zero credit.
    function _rawOffer(Leg memory leg, uint256 face) private view returns (uint256 minted) {
        if (face == 0 || leg.se == address(0) || leg.se == leg.asset) return face;
        (,, minted,) = Transition(leg.se).quoteTransition(leg.state, Transition.Operation.DepositExactIn, face);
    }

    /// @dev Live fee-bearing pools can mint a few share wei under the quote. Ask for that
    ///      cushion only when the offered face already quotes it, so the search cannot revert.
    function _bufferedRequired(
        uint256 shares,
        uint256 incumbent,
        uint256 supply,
        Leg memory leg,
        uint256 offered
    ) private view returns (uint256) {
        uint256 required = Math.rawRequiredInventory(shares, incumbent, supply);
        if (required == 0 || leg.se == address(0) || leg.se == leg.asset) return required;
        uint256 cushion = 1024;
        if (required > type(uint256).max - cushion) return required;
        if (_rawOffer(leg, offered) < required + cushion) return required;
        return required + cushion;
    }

    function _faceForRawOffer(Leg memory leg, uint256 required, uint256 available) private view returns (uint256) {
        if (required == 0) return 0;
        if (leg.se == address(0) || leg.se == leg.asset) {
            if (required > available) revert Math.MathDomain();
            return required;
        }
        uint256 above = _rawOffer(leg, available);
        if (above < required || available == 0) revert Math.MathDomain();
        uint256 low = 1;
        uint256 high = available;
        uint256 below;
        uint256 probes;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (above > below && probes < 8) {
                mid = low - 1 + FullMath.mulDiv(required - below, high - low + 1, above - below);
                mid = FullMath.max(low, FullMath.min(mid, high - 1));
                unchecked { ++probes; }
            }
            uint256 got = _rawOffer(leg, mid);
            if (got >= required) {
                high = mid;
                above = got;
            } else {
                low = mid + 1;
                below = got;
            }
        }
        if (_rawOffer(leg, low) < required) revert Math.MathDomain();
        return low;
    }

    function _depositSales(Leg[3] memory legs, DepositQuote memory q, uint256 amount) private view {
        Math.ZapSplitArgs memory a;
        a.e0 = Math.toWad(legs[0].effective, legs[0].decimals);
        a.e1 = Math.toWad(legs[1].effective, legs[1].decimals);
        a.e2 = Math.toWad(legs[2].effective, legs[2].decimals);
        a.R = Repo._layout().R;
        uint8 decimals = legs[q.input].decimals;
        a.amountInWad = Math.toWad(amount, decimals);
        if (a.R == 0 || a.e0 == 0 || a.e1 == 0 || a.e2 == 0 || a.amountInWad < 3
            || a.e0 + 1 >= a.R || a.e1 + 1 >= a.R || a.e2 + 1 >= a.R)
        {
            q.offered[q.input] = amount;
            return;
        }
        a.L2 = Math.recomputeL2(a.R, a.e0, a.e1, a.e2);
        a.feeWad = IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
        a.inIdx = q.input;
        Math.ZapSplitResult memory z = Math.zapSplitWad(a);
        if (z.sJWad == 0 || z.sKWad == 0) {
            q.offered[q.input] = amount;
            return;
        }
        q.saleJ = Math.fromWadCeil(z.sJWad, decimals);
        q.saleK = Math.fromWadCeil(z.sKWad, decimals);
        if (q.saleJ + q.saleK > amount) {
            q.saleJ = Math.fromWadFloor(z.sJWad, decimals);
            q.saleK = Math.fromWadFloor(z.sKWad, decimals);
            if (q.saleJ + q.saleK > amount) {
                if (q.saleJ >= amount) q.saleJ = amount / 2;
                q.saleK = amount - q.saleJ;
            }
        }
        q.offered[q.input] = amount - q.saleJ - q.saleK;
    }

    function _depositOutputs(Leg[3] memory legs, DepositQuote memory q) private view {
        if (q.saleJ > 0) {
            legs[q.input].withdrawn = q.saleJ;
            q.offered[q.j] = _swap(legs, q.input, q.j);
            q.sharesJ = legs[q.j].redeemShares;
        }
        if (q.saleK > 0) {
            legs[q.input].withdrawn = q.saleK;
            q.offered[q.k] = _swap(legs, q.input, q.k);
            q.sharesK = legs[q.k].redeemShares;
        }
    }

    function _claimIn(Leg memory leg, uint256 amount) private view returns (uint256) {
        if (amount == 0 || leg.se == address(0)) return amount;
        (,, uint256 minted,) = Transition(leg.se).quoteTransition(leg.state, Transition.Operation.DepositExactIn, amount);
        if (minted == 0) return amount;
        uint256 rated = ClaimLib.ratedNative(minted, leg.rate, leg.se, leg.asset);
        return rated == 0 ? amount : rated;
    }

    function _depositSupply(Leg[3] memory legs) private view returns (uint256 supply) {
        supply = IERC20(address(this)).totalSupply();
        Repo.Layout storage l = Repo._layout();
        IVaultFeeOracleQuery oracle = IVaultFeeOracleQuery(l.feeOracle);
        uint256 usage = oracle.usageFeeOfVault(address(this));
        uint256 ownerShare = usage * Repo.FEE_DENOMINATOR / 1e18;
        if (address(oracle.feeTo()) == address(0) || usage == 0 || usage >= 1e18 || ownerShare == 0 || l.kLast == 0) return supply;
        uint256 a = Math.toWad(legs[0].effective, legs[0].decimals);
        uint256 b = Math.toWad(legs[1].effective, legs[1].decimals);
        uint256 c = Math.toWad(legs[2].effective, legs[2].decimals);
        uint8 mode = a > 0 && b > 0 && c > 0 ? 0 : 1;
        if (mode != l.kLastMode) return supply;
        uint256 root = mode == 0 ? Math.cbrt(a * b * c) : a + b + c;
        uint256 previous = mode == 0 ? Math.cbrt(l.kLast) : l.kLast;
        supply += Math.protocolLpShares(supply, root, previous, ownerShare);
    }

    function _partialDepositAtState(Leg[3] memory legs, DepositQuote memory q, uint256 amount)
        private view returns (uint256)
    {
        Leg memory leg = legs[q.input];
        uint256 radius = Repo._layout().R;
        uint256 effectiveWad = Math.toWad(leg.effective, leg.decimals);
        if (radius == 0 || effectiveWad == 0 || effectiveWad + 1 >= radius) return 0;
        uint256 room = Math.fromWadFloor(radius - effectiveWad - 1, leg.decimals);
        if (amount > room) amount = room;
        uint256 proRata = Math.toWad(amount, leg.decimals) * q.supply / effectiveWad;
        uint256 used = Math.fromWadFloor(Math.fullBookUsedWad(proRata, effectiveWad, q.supply), leg.decimals);
        if (used == 0) return 0;
        uint256[3] memory usedWad;
        usedWad[q.input] = Math.toWad(used, leg.decimals);
        Math.SphereNavArgs memory nav;
        nav.supply = q.supply;
        nav.R = radius;
        nav.r0Wad = Math.toWad(legs[0].effective, legs[0].decimals);
        nav.r1Wad = Math.toWad(legs[1].effective, legs[1].decimals);
        nav.r2Wad = Math.toWad(legs[2].effective, legs[2].decimals);
        nav.used0Wad = usedWad[0];
        nav.used1Wad = usedWad[1];
        nav.used2Wad = usedWad[2];
        return Math.sphereNavShares(nav);
    }

}

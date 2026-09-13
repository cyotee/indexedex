// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";

/// @notice Sequential proportional withdrawal and residual swap quotes for the Orbital LP.
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
        if (leg.rateProvider != address(0)) {
            LegLib.ExternalQuote memory q;
            q.exchange = Transition(leg.se);
            q.state = leg.state;
            leg.rate = LegLib.rateAfterExchange(q, leg.asset, leg.rateProvider);
        }
        leg.effective = leg.rate == 0
            ? Transition(leg.se).quoteAssets(leg.state, leg.shares)
            : leg.shares * leg.rate / 1e18;
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
            added = input.rate == 0
                ? Transition(input.se).quoteAssets(input.state, input.shares + minted) - input.effective
                : minted * input.rate / 1e18;
        }
        uint256 faceOut = _sale(legs, from, to, added);
        received = _receiveOutput(output, faceOut);
        if (input.se == address(0)) input.effective += input.withdrawn;
        else {
            input.state = nextInput;
            _refresh(input);
        }
    }

    function _receiveOutput(Leg memory output, uint256 faceOut) private view returns (uint256 received) {
        if (output.se == address(0)) {
            output.effective -= faceOut;
            received = faceOut;
        } else {
            (bytes memory next, uint256 needed, uint256 paid,) = Transition(output.se).quoteTransition(
                output.state, Transition.Operation.WithdrawExactOut, faceOut
            );
            uint256 cap = output.shares > 1 ? output.shares - 1 : 0;
            if (needed > cap) {
                (next,, paid,) = Transition(output.se).quoteTransition(
                    output.state, Transition.Operation.RedeemExactIn, cap
                );
                if (paid < faceOut) revert Math.Drain();
            }
            output.state = next;
            received = paid;
            _refresh(output);
        }
    }

    function _sale(Leg[3] memory legs, uint8 from, uint8 to, uint256 added) private view returns (uint256 out) {
        Repo.Layout storage l = Repo._layout();
        uint256 x = _toWad(legs[from].effective, legs[from].decimals);
        uint256 y = _toWad(legs[to].effective, legs[to].decimals);
        uint8 witness = 3 - from - to;
        uint256 z = _toWad(legs[witness].effective, legs[witness].decimals);
        uint256 net = Math.applyTradingFeeNet(
            _toWad(added, legs[from].decimals), IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeOfVault(address(this))
        );
        uint256 outWad = Math.sphereExactInOutWad(l.R, Math.recomputeL2(l.R, x, y, z), x, y, z, net);
        uint8 decimals = legs[to].decimals;
        out = decimals <= 18 ? outWad / (10 ** (18 - decimals)) : outWad * (10 ** (decimals - 18));
        if (legs[to].rate != 0) {
            uint256 shares = (out * 1e18 + legs[to].rate - 1) / legs[to].rate;
            out = Transition(legs[to].se).quoteAssets(legs[to].state, shares);
        }
        if (out == 0 || out >= legs[to].effective) revert Math.Drain();
    }

    function _toWad(uint256 amount, uint8 decimals) private pure returns (uint256) {
        return decimals <= 18 ? amount * (10 ** (18 - decimals)) : amount / (10 ** (decimals - 18));
    }
    /// @notice Quote the retained zap after receiving and redeeming an SE-share payment.
    /// @dev Only the initial redemption is projected here. The subsequent zap keeps
    /// the family's existing split, claim conversion, protocol fee and LP formulas.
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
        uint256 algebraicJ;
        uint256[3] offered;
        uint256[3] reserves;
    }

    function _depositAtState(Leg[3] memory legs, uint8 index, uint256 amount) private view returns (uint256) {
        DepositQuote memory q;
        q.input = index;
        q.j = index == 0 ? 1 : 0;
        q.k = 3 - index - q.j;
        for (uint8 i; i < 3; ++i) q.reserves[i] = legs[i].effective;
        q.supply = _depositSupply(legs);
        if (amount > legs[index].effective && (legs[q.j].effective < amount / 4 || legs[q.k].effective < amount / 4)) {
            return _partialDepositAtState(legs, q, amount);
        }
        _depositSales(legs, q, amount);
        _depositOutputs(legs, q);
        Math.FullBookArgs memory fb;
        fb.a0Wad = Math.toWad(_claimIn(legs[0], q.offered[0]), legs[0].decimals);
        fb.a1Wad = Math.toWad(_claimIn(legs[1], q.offered[1]), legs[1].decimals);
        fb.a2Wad = Math.toWad(_claimIn(legs[2], q.offered[2]), legs[2].decimals);
        fb.e0Wad = Math.toWad(q.reserves[0], legs[0].decimals);
        fb.e1Wad = Math.toWad(q.reserves[1], legs[1].decimals);
        fb.e2Wad = Math.toWad(q.reserves[2], legs[2].decimals);
        fb.supply = q.supply;
        return Math.fullBookShares(fb);
    }

    function _depositSales(Leg[3] memory legs, DepositQuote memory q, uint256 amount) private view {
        Math.ZapSplitArgs memory a;
        a.e0 = Math.toWad(legs[0].effective, legs[0].decimals);
        a.e1 = Math.toWad(legs[1].effective, legs[1].decimals);
        a.e2 = Math.toWad(legs[2].effective, legs[2].decimals);
        a.R = Repo._layout().R;
        a.L2 = Math.recomputeL2(a.R, a.e0, a.e1, a.e2);
        a.feeWad = IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
        a.inIdx = q.input;
        uint8 decimals = legs[q.input].decimals;
        a.amountInWad = Math.toWad(amount, decimals);
        Math.ZapSplitResult memory z = Math.zapSplitWad(a);
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
        q.algebraicJ = z.aJWad;
    }

    function _depositOutputs(Leg[3] memory legs, DepositQuote memory q) private view {
        uint256 actualJ;
        if (q.saleJ > 0) actualJ = _depositSale(legs, q, q.j, q.saleJ);
        uint256 addedJ = _claimIn(legs[q.input], q.saleJ);
        uint256 removedJ = _claimDebit(legs[q.j], actualJ);
        q.reserves[q.input] += addedJ;
        q.reserves[q.j] -= removedJ;
        if (q.saleK > 0) q.offered[q.k] = _depositSale(legs, q, q.k, q.saleK);
        q.offered[q.j] = actualJ;
        if (legs[q.j].se == address(0) && q.algebraicJ > 0) {
            uint256 algebraic = Math.fromWadFloor(q.algebraicJ, legs[q.j].decimals);
            if (algebraic > 0) q.offered[q.j] = algebraic;
        }
        q.reserves[q.input] += _claimIn(legs[q.input], q.saleK);
        q.reserves[q.j] = legs[q.j].effective - _claimDebit(legs[q.j], q.offered[q.j]);
        q.reserves[q.k] -= _claimDebit(legs[q.k], q.offered[q.k]);
    }

    function _depositSale(Leg[3] memory legs, DepositQuote memory q, uint8 outIndex, uint256 amount)
        private view returns (uint256 faceOut)
    {
        uint256 x = Math.toWad(q.reserves[q.input], legs[q.input].decimals);
        uint256 y = Math.toWad(q.reserves[outIndex], legs[outIndex].decimals);
        uint8 witness = 3 - q.input - outIndex;
        uint256 z = Math.toWad(q.reserves[witness], legs[witness].decimals);
        uint256 net = Math.applyTradingFeeNet(
            Math.toWad(_claimIn(legs[q.input], amount), legs[q.input].decimals),
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this))
        );
        uint256 radius = Repo._layout().R;
        faceOut = Math.fromWadFloor(
            Math.sphereExactInOutWad(radius, Math.recomputeL2(radius, x, y, z), x, y, z, net),
            legs[outIndex].decimals
        );
        if (legs[outIndex].rate != 0) {
            uint256 shares = (faceOut * 1e18 + legs[outIndex].rate - 1) / legs[outIndex].rate;
            faceOut = Transition(legs[outIndex].se).quoteAssets(legs[outIndex].state, shares);
        }
    }

    function _claimIn(Leg memory leg, uint256 amount) private view returns (uint256) {
        if (amount == 0 || leg.se == address(0)) return amount;
        (,, uint256 minted,) = Transition(leg.se).quoteTransition(leg.state, Transition.Operation.DepositExactIn, amount);
        if (leg.rate != 0) return minted * leg.rate / 1e18;
        uint256 afterClaim = Transition(leg.se).quoteAssets(leg.state, leg.shares + minted);
        return afterClaim > leg.effective ? afterClaim - leg.effective : 0;
    }

    function _claimDebit(Leg memory leg, uint256 amount) private view returns (uint256) {
        if (amount == 0 || leg.se == address(0)) return amount;
        (, uint256 shares,,) = Transition(leg.se).quoteTransition(leg.state, Transition.Operation.WithdrawExactOut, amount);
        return leg.rate == 0 ? Transition(leg.se).quoteAssets(leg.state, shares) : shares * leg.rate / 1e18;
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
        if (effectiveWad + 1 >= radius) revert Math.MathDomain();
        uint256 room = Math.fromWadFloor(radius - effectiveWad - 1, leg.decimals);
        if (amount > room) amount = room;
        uint256 proRata = Math.toWad(amount, leg.decimals) * q.supply / effectiveWad;
        uint256 used = Math.fromWadFloor(Math.fullBookUsedWad(proRata, effectiveWad, q.supply), leg.decimals);
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

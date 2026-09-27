// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib
 * @notice D78 claim-in / invert for pair-side buffer composition (ERC-4626 SE peer).
 * @dev D60: the pair leg of the swap invariant is SE shares x the configured rate provider
 *      (WAD whole pair tokens per whole share). The hook never derives a rate from the SE's
 *      own quotes; SE quotes are used only to count shares minted or pair paid out.
 *      External library: DELEGATECALL keeps `Repo._layout()` on the hook diamond.
 */
library UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib {
    error InsufficientTokenOut();
    error RateProviderFailed();
    error RateProviderRequired();

    /* ------------------------------ D60 rated valuation ------------------------------ */

    /// @notice Fail-closed provider read. Identity leg without a provider reads as 1e18 (raw balance).
    function rate() external view returns (uint256) {
        return _rate(Repo._layout());
    }

    /// @notice SE shares (or identity pair units) valued in pair-token units at the provider rate.
    function ratedOf(uint256 shares) external view returns (uint256) {
        return _ratedOf(Repo._layout(), shares);
    }

    /// @notice Shares needed to represent `pairUnits` at the provider rate, rounding up.
    function sharesForPairUnitsUp(uint256 pairUnits) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (pairUnits == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return pairUnits;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.sharesForPairUnitsUp(pairUnits, _rate(l), invScale, ratedScale);
    }

    /// @notice The hook's SE balance valued at the provider rate; a non-empty book never reads zero.
    function ratedReserve() external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        if (seBal == 0) return 0;
        uint256 claim = _ratedOf(l, seBal);
        return claim == 0 ? 1 : claim;
    }

    function _rate(Repo.Layout storage l) private view returns (uint256 rate_) {
        address rp = l.rateProvider;
        if (rp == address(0)) {
            if (l.pairToken == l.standardExchange) return Math.RATE_PRECISION;
            revert RateProviderRequired();
        }
        (bool ok, bytes memory data) = rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate_ = abi.decode(data, (uint256));
        if (rate_ == 0) revert RateProviderFailed();
    }

    function _scales(Repo.Layout storage l) private view returns (uint256 invScale, uint256 ratedScale) {
        uint8 seDec = l.pairToken == l.standardExchange ? _pairDecimals(l) : l.seDecimals;
        invScale = 10 ** (36 - uint256(seDec));
        ratedScale = 10 ** (36 - uint256(_pairDecimals(l)));
    }

    function _pairDecimals(Repo.Layout storage l) private view returns (uint8) {
        return l.currency0 == l.pairToken ? l.decimalsCurrency0 : l.decimalsCurrency1;
    }

    function _ratedOf(Repo.Layout storage l, uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, _rate(l), invScale, ratedScale);
    }

    function _ratedWith(Repo.Layout storage l, uint256 shares, uint256 rate_) private view returns (uint256) {
        if (shares == 0) return 0;
        if (l.pairToken == l.standardExchange && l.rateProvider == address(0)) return shares;
        (uint256 invScale, uint256 ratedScale) = _scales(l);
        return Math.ratedPairUnits(shares, rate_, invScale, ratedScale);
    }

    /// @dev The provider's rate for a projected SE `state` (D41 / D48 `IStandardExchangeRateQuote`), so a
    ///      preview rates the post-buffer book the way execution will read it; a provider without projected
    ///      quotes answers with its live rate. Fails closed like `_rate`.
    function _rateForState(Repo.Layout storage l, bytes memory state) private view returns (uint256) {
        if (l.rateProvider == address(0)) return _rate(l);
        LegLib.ExternalQuote memory q;
        q.exchange = IStandardExchangeTransitionQuote(l.standardExchange);
        q.state = state;
        q.pair = l.pairToken;
        return LegLib.rateAfterExchange(q, l.pairToken, l.rateProvider);
    }

    /* ------------------------------ transition quotes ------------------------------ */

    function supportsTransitionQuote(address se, address pairToken, address holder) external view returns (bool) {
        return _supportsTransitionQuote(se, pairToken, holder);
    }

    function _supportsTransitionQuote(address se, address pairToken, address holder) private view returns (bool) {
        if (!IERC165(se).supportsInterface(type(IStandardExchangeTransitionQuote).interfaceId)) return false;
        // D37: probe with staticcall. Identity SE (share == pair) and other
        // unquotable assets must not hard-revert the join; fallback 1:1 claim.
        (bool ok, bytes memory ret) = se.staticcall(
            abi.encodeCall(IStandardExchangeTransitionQuote.quoteState, (pairToken, holder))
        );
        return ok && ret.length > 0;
    }

    function _previewPairToShares(address se, address pairToken, uint256 amountInRaw)
        private
        view
        returns (uint256)
    {
        if (amountInRaw == 0) return 0;
        if (se == pairToken) return amountInRaw;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
    }

    /// @notice Projected SE state after depositing `amountInRaw` pair tokens, with the holder's
    ///         projected share balance valued at the provider rate (D60) as `ratedHolderClaimAfter`.
    /// @dev H2: Uni V3/V4 `quoteTransition(DepositExactIn)` reverts `InvalidQuoteState`
    ///      when the deposit mints 0 shares (1 wei of an 18-dec pair into a large book).
    ///      `previewExchangeIn` returns 0 for that dust; skip the transition call.
    function quoteMintableDepositExactIn(
        address se,
        address pairToken,
        bytes memory state,
        uint256 amountInRaw
    )
        external
        view
        returns (bytes memory nextState, uint256 amountIn, uint256 amountOut, uint256 ratedHolderClaimAfter)
    {
        Repo.Layout storage l = Repo._layout();
        if (amountInRaw == 0 || _previewPairToShares(se, pairToken, amountInRaw) == 0) {
            return (state, 0, 0, _ratedClaimOfState(l, se, state));
        }
        (nextState, amountIn, amountOut,) = IStandardExchangeTransitionQuote(se).quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw
        );
        ratedHolderClaimAfter = _ratedClaimOfState(l, se, nextState);
    }

    /// @notice Rated holder claim for an already projected `state`: shares x the provider's rate for that state.
    function ratedClaimOfState(address se, bytes memory state) external view returns (uint256) {
        return _ratedClaimOfState(Repo._layout(), se, state);
    }

    function _ratedClaimOfState(Repo.Layout storage l, address se, bytes memory state) private view returns (uint256) {
        uint256 shares_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state);
        if (shares_ == 0) return 0;
        return _ratedWith(l, shares_, _rateForState(l, state));
    }

    /// @notice Swap-side book at a projected external SE `state` (a route that redeems or deposits before the
    ///         hook swaps): the held shares valued at that state's rate, and the claim `assets` pair tokens add
    ///         when buffered from that state (post-buffer projected rate), computed the way `_claimIn` does.
    function projectedClaimIn(address se, bytes memory state, uint256 heldShares, uint256 assets)
        external view returns (uint256 reserveBefore, uint256 claimIn)
    {
        Repo.Layout storage l = Repo._layout();
        reserveBefore = _ratedWith(l, heldShares, _rateForState(l, state));
        if (assets == 0) return (reserveBefore, 0);
        if (l.pairToken == se) return (reserveBefore, _ratedOf(l, assets));
        if (_previewPairToShares(se, l.pairToken, assets) == 0) return (reserveBefore, 0);
        (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
            .quoteTransition(state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets);
        uint256 after_ = _ratedWith(l, heldShares + minted_, _rateForState(l, next_));
        claimIn = after_ > reserveBefore ? after_ - reserveBefore : 0;
    }

    /* ------------------------------ buffer claim-in ------------------------------ */

    /// @dev Pair units the swap reserve gains when `amountInRaw` pair tokens are buffered: the rated book after
    ///      the buffer minus the rated book before it. With a transition-quoting SE the post-buffer book is
    ///      `(held + minted) x rateAfter`, where `rateAfter` is the provider's projected rate for that state
    ///      (an SE usage fee or first-deposit rounding moves the rate; execution reads the moved rate). Without a
    ///      transition quote the gain is `previewExchangeIn(pair -> se) x live rate`. Identity leg: the pair units.
    function _claimIn(Repo.Layout storage l, uint256 amountInRaw) private view returns (uint256) {
        if (amountInRaw == 0) return 0;
        address se = l.standardExchange;
        address pairToken = l.pairToken;
        if (se == pairToken) return _ratedOf(l, amountInRaw);
        uint256 sharesOut = _previewPairToShares(se, pairToken, amountInRaw);
        if (sharesOut == 0) return 0;
        if (!_supportsTransitionQuote(se, pairToken, address(this))) return _ratedOf(l, sharesOut);
        (bytes memory state_,) = IStandardExchangeTransitionQuote(se).quoteState(pairToken, address(this));
        uint256 held_ = IStandardExchangeTransitionQuote(se).quoteShareBalance(state_);
        (bytes memory next_,, uint256 minted_,) = IStandardExchangeTransitionQuote(se)
            .quoteTransition(state_, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amountInRaw);
        uint256 after_ = _ratedWith(l, held_ + minted_, _rateForState(l, next_));
        uint256 before_ = _ratedOf(l, held_);
        return after_ > before_ ? after_ - before_ : 0;
    }

    function previewBufferClaimIn(uint256 amountInRaw) external view returns (uint256) {
        return _claimIn(Repo._layout(), amountInRaw);
    }

    function invertBufferClaimIn(uint256 claimInNeeded) external view returns (uint256 amountInRaw) {
        if (claimInNeeded == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 hi = claimInNeeded;
        uint256 guard;
        while (_claimIn(l, hi) < claimInNeeded && guard < 64) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (_claimIn(l, hi) < claimInNeeded) {
            revert InsufficientTokenOut();
        }
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (_claimIn(l, mid) >= claimInNeeded) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib
 * @notice SE buffer / unwrap + claim / rate helpers (external lib keeps diamond under EIP-170).
 * @dev Buffer uses exchangeIn(pair→SE); unwrap uses exchangeIn(SE→pair) with exchangeOut fallback.
 *      High-level library calls use DELEGATECALL so address(this) remains the hook.
 */
library UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib {
    using SafeERC20 for IERC20;

    error BufferFailed();
    error UnwrapFailed();
    error RateProviderFailed();
    error RateProviderRequired();
    error SeInvertUnavailable();

    function ratedPairUnits(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address rp = l.rateProviders[i];
        // D60: raw leg = raw balance (times the rate when a provider is configured); buffered leg = shares x rate.
        if (se == address(0)) {
            uint256 raw = IERC20(l.tokens[i]).balanceOf(address(this));
            return rp == address(0) ? raw : Math.ratedPairUnits(raw, _readRate(rp), l.invScales[i], l.ratedScales[i]);
        }
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        if (rp == address(0)) revert RateProviderRequired();
        return Math.ratedPairUnits(seBal, _readRate(rp), shareScale(se), l.ratedScales[i]);
    }


    /// @notice D60: the SE share scale the rate provider prices against, 10^(36 - shareDecimals) from the
    ///         share token's metadata. This package keeps its inventory scale at the pair's decimals, so the
    ///         rated conversions read the share metadata directly.
    function shareScale(address se) public view returns (uint256) {
        return Math.baseScaleFromDecimals(IERC20Metadata(se).decimals());
    }

    function nativeForRatedWad(uint8 i, uint256 wad, bool roundUp) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
        FullMath.Rounding rounding = roundUp ? FullMath.Rounding.Ceil : FullMath.Rounding.Floor;
        uint256 sharesWad = FullMath.mulDiv(wad, 1e18, _readRate(l.rateProviders[i]), rounding);
        return FullMath.mulDiv(sharesWad, 1e18, shareScale(l.standardExchanges[i]), rounding);
    }

    function ratedWadForNativeUp(uint8 i, uint256 shares) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
        uint256 wad = FullMath.mulDiv(shares, shareScale(l.standardExchanges[i]), 1e18, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(wad, _readRate(l.rateProviders[i]), 1e18, FullMath.Rounding.Ceil);
    }

    function _nativeAt(uint8 i) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return IERC20(l.standardExchanges[i] == address(0) ? l.tokens[i] : l.standardExchanges[i]).balanceOf(address(this));
    }

    function quoteSwapExactIn(uint8 i, uint8 j, uint256[] memory rated, uint256 inflow, uint256 amp)
        external view returns (uint256 amountOut, uint256 sharesOut)
    {
        return quoteSwapExactInContext(i, j, rated, inflow, amp, address(0));
    }

    function quoteSwapExactInContext(uint8 i, uint8 j, uint256[] memory rated, uint256 inflow, uint256 amp, address manager)
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
        if (se != address(0) && se != l.tokens[j]) {
            if (manager == address(0)) sharesOut = nativeForRatedWad(j, budget, false);
            else sharesOut = FullMath.mulDiv(FullMath.mulDiv(budget, 1e18,
                ContextQuote.rate(se, l.tokens[j], l.rateProviders[j], manager)), 1e18, shareScale(se));
            if (sharesOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
            if (manager == address(0)) amountOut = sharesOut == 0 ? 0 : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(l.tokens[j]));
            else (amountOut,) = ContextQuote.redeem(se, l.tokens[j], address(this), sharesOut, manager);
        } else {
            amountOut = Math.descale(budget, l.ratedScales[j]);
            if (amountOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
        }
        if (amountOut == 0) revert Math.ZeroAmount();
    }

    function ratedWadAllWithContext(address manager) external view returns (uint256[] memory values) {
        Repo.Layout storage l = Repo._layout();
        values = new uint256[](Repo._numTokens());
        for (uint8 i; i < values.length; ++i) {
            address se = l.standardExchanges[i];
            uint256 units;
            if (se == address(0) || se == l.tokens[i]) units = ratedPairUnits(i);
            else {
                if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
                units = Math.ratedPairUnits(IERC20(se).balanceOf(address(this)), ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), shareScale(se), l.ratedScales[i]);
            }
            values[i] = Math.scaleTo(units, l.ratedScales[i]);
        }
    }

    function pairInWithContext(uint8 i, uint256 amount, address manager) external view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        (uint256 shares,) = ContextQuote.deposit(se, l.tokens[i], address(this), amount, manager);
        if (shares == 0) return 0;
        if (l.rateProviders[i] == address(0)) revert RateProviderRequired();
        return Math.scaleTo(Math.ratedPairUnits(shares, ContextQuote.rate(se, l.tokens[i], l.rateProviders[i], manager), shareScale(se), l.ratedScales[i]), l.ratedScales[i]);
    }

    function quoteSwapExactOut(uint8 i, uint8 j, uint256[] memory rated, uint256 amountOut, uint256 feeWad, uint256 amp)
        external view returns (uint256 amountIn)
    {
        return quoteSwapExactOutContext(i, j, rated, amountOut, feeWad, amp, address(0));
    }

    function quoteSwapExactOutContext(uint8 i, uint8 j, uint256[] memory rated, uint256 amountOut, uint256 feeWad, uint256 amp, address manager)
        public view returns (uint256 amountIn)
    {
        uint256 debit = _exactOutputDebit(j, amountOut, manager);
        uint256 needed = Math.quoteExactOutRated(rated, i, j, debit, amp);
        amountIn = Math.grossUpExactOut(_inputForRatedContext(i, needed, manager), feeWad);
        if (amountIn == 0) revert Math.ZeroAmount();
    }

    function _exactOutputDebit(uint8 j, uint256 amountOut, address manager) private view returns (uint256 debit) {
        Repo.Layout storage l = Repo._layout();
        debit = Math.scaleToUp(amountOut, l.ratedScales[j]);
        address se = l.standardExchanges[j];
        if (se != address(0) && se != l.tokens[j]) {
            bytes memory state = ContextQuote.exactOutputState(se, l.tokens[j], manager);
            uint256 shares = ContextQuote.withdrawFromState(se, l.tokens[j], amountOut, state);
            if (shares == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            if (shares >= _nativeAt(j)) revert Math.WouldZeroReserve();
            if (state.length == 0) return ratedWadForNativeUp(j, shares);
            uint256 wad = FullMath.mulDiv(shares, shareScale(se), 1e18, FullMath.Rounding.Ceil);
            debit = FullMath.mulDiv(wad, ContextQuote.rateFromState(se, l.tokens[j], l.rateProviders[j], state), 1e18, FullMath.Rounding.Ceil);
        } else if (amountOut >= _nativeAt(j)) revert Math.WouldZeroReserve();
    }

    function _inputForRatedContext(uint8 i, uint256 needed, address manager) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
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
        address se = l.standardExchanges[i];
        uint256 rate = ContextQuote.rateFromState(se, l.tokens[i], l.rateProviders[i], state);
        uint256 sharesWad = FullMath.mulDiv(needed, 1e18, rate, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(sharesWad, 1e18, shareScale(se), FullMath.Rounding.Ceil);
    }

    function pairInputForRated(uint8 i, uint256 ratedWad) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 pair = Math.descaleUp(ratedWad, l.ratedScales[i]);
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            address rp = l.rateProviders[i];
            return rp == address(0) ? pair : Math.sharesForPairUnitsUp(pair, _readRate(rp), l.invScales[i], l.ratedScales[i]);
        }
        if (se == l.tokens[i]) return pair;
        return bufferInputForShares(se, l.tokens[i], nativeForRatedWad(i, ratedWad, true));
    }

    function getRateFailClosed(address rp) external view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        return _readRate(rp);
    }

    function _readRate(address rp) private view returns (uint256 rate) {
        (bool ok, bytes memory data) =
            rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length != 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function seClaimOf(address se, address pairToken, uint256 seAmount) external view returns (uint256) {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }

    function previewBufferShares(address se, address pairToken, uint256 amountInRaw)
        external
        view
        returns (uint256 sharesOut)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == pairToken) return amountInRaw;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
    }

    function previewUnwrap(address se, address pairToken, uint256 seAmount)
        external
        view
        returns (uint256 amountOut)
    {
        if (seAmount == 0 || se == address(0)) return 0;
        if (se == pairToken) return seAmount;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
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
        if (high != 0 && IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), high, IERC20(se)) >= sharesOut) return high;
        if (ContextQuote.supported(se)) revert SeInvertUnavailable();
        if (high == 0) high = sharesOut;
        uint256 low;
        while (IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), high, IERC20(se)) < sharesOut) {
            low = high;
            if (high > type(uint256).max / 2) revert SeInvertUnavailable();
            high *= 2;
        }
        while (high - low > 1) {
            uint256 mid = low + (high - low) / 2;
            if (IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), mid, IERC20(se)) >= sharesOut) high = mid;
            else low = mid;
        }
        return high;
    }

    function buffer(address se, address pairToken, uint256 amountInRaw) public returns (uint256 sharesOut) {
        if (amountInRaw == 0) return 0;
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(pairToken).forceApprove(se, amountInRaw);
        uint256 balBefore = IERC20(se).balanceOf(address(this));
        sharesOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(pairToken),
            amountInRaw,
            IERC20(se),
            minOut,
            address(this),
            false,
            block.timestamp
        );
        IERC20(pairToken).forceApprove(se, 0);
        uint256 delta = IERC20(se).balanceOf(address(this)) - balBefore;
        if (delta != sharesOut) revert BufferFailed();
        if (sharesOut < minOut) revert BufferFailed();
    }

    function unwrap(address se, address pairToken, uint256 seAmount, address to)
        external
        returns (uint256 amountOut)
    {
        if (seAmount == 0) return 0;
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
        if (minOut == 0) return 0;
        IERC20(se).forceApprove(se, seAmount);
        amountOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seAmount, IERC20(pairToken), minOut, to, false, block.timestamp
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
        if (surplus != 0 && IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), surplus, IERC20(se)) != 0) {
            buffer(se, pairToken, surplus);
        }
        return spent;
    }

    function previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw, address hook)
        external
        view
        returns (uint256)
    {
        if (amountInRaw == 0 || se == address(0)) return 0;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;
        uint256 seBalBefore = IERC20(se).balanceOf(hook);
        uint256 claimBefore = seBalBefore == 0
            ? 0
            : IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore, IERC20(pairToken));
        uint256 claimAfter =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBalBefore + sharesOut, IERC20(pairToken));
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }
}

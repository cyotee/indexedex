// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookClaimLib
 * @notice SE claim / rate / buffer-unwrap helpers (external previews + fail-closed rates).
 * @dev Pure Math must not call SE/RP — composition lives here.
 */
library UniswapV4StandardExchangeOrbitalBufferHookClaimLib {
    error RateProviderFailed();
    error RateProviderRequired();
    error SeInvertUnavailable();
    error InsufficientTokenOut();

    /// @dev Immutable inputs to repeated previews against one unchanged SE book.
    struct BufferClaimQuote {
        address se;
        address token;
        uint256 rate;
        uint256 heldShares;
        uint256 heldClaim;
    }

    function bufferClaimQuote(address se, address rp, address token, address hook)
        internal view returns (BufferClaimQuote memory quote)
    {
        quote.se = se;
        quote.token = token;
        // D60: a buffered leg always carries a rate provider (package init rejects an SE leg without one);
        // a raw leg may carry one. The hook never derives a rate from the SE's own quotes.
        if (rp != address(0)) quote.rate = getRateFailClosed(rp);
        else if (se != address(0)) revert RateProviderRequired();
        hook;
    }

    function previewBufferClaimIn(BufferClaimQuote memory quote, uint256 amountInRaw)
        internal view returns (uint256)
    {
        if (amountInRaw == 0 || quote.se == address(0)) return 0;
        if (quote.se == quote.token) return amountInRaw;
        uint256 sharesOut = IStandardExchangeIn(quote.se).previewExchangeIn(
            IERC20(quote.token), amountInRaw, IERC20(quote.se)
        );
        if (sharesOut == 0) return amountInRaw;
        if (quote.rate == 0) revert RateProviderRequired();
        return ratedNative(sharesOut, quote.rate, quote.se, quote.token);
    }


    /// @notice D60: raw SE shares to the leg token's native units through a WAD rate of whole tokens per
    ///         whole share, honoring share and token decimals.
    function ratedNative(uint256 shares, uint256 rate, address se, address token) internal view returns (uint256) {
        uint8 sd = IERC20Metadata(se).decimals();
        uint8 td = IERC20Metadata(token).decimals();
        if (sd >= td) return FullMath.mulDiv(shares, rate, 1e18 * (10 ** uint256(sd - td)));
        return FullMath.mulDiv(shares * (10 ** uint256(td - sd)), rate, 1e18);
    }

    /// @notice D60: inverse of `ratedNative`, rounding up.
    function sharesForNativeUp(uint256 native, uint256 rate, address se, address token) internal view returns (uint256) {
        uint8 sd = IERC20Metadata(se).decimals();
        uint8 td = IERC20Metadata(token).decimals();
        if (sd >= td) return FullMath.mulDiv(native, 1e18 * (10 ** uint256(sd - td)), rate, FullMath.Rounding.Ceil);
        return FullMath.mulDiv(native, 1e18, rate * (10 ** uint256(td - sd)), FullMath.Rounding.Ceil);
    }

    function getRateFailClosed(address rp) internal view returns (uint256 rate) {
        if (rp == address(0)) return 0;
        (bool ok, bytes memory data) = rp.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || data.length < 32) revert RateProviderFailed();
        rate = abi.decode(data, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    /// @notice SE claim of `seBal` shares → pool token (unwrap preview; fee-inclusive).
    function seClaimOf(address se, address token, uint256 seBal) internal view returns (uint256) {
        if (se == address(0) || seBal == 0) return 0;
        if (se == token) return seBal;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(token));
    }

    /// @notice Effective native reserve for a leg: raw face, or shares×rate, or SE claim.
    function effectiveNative(
        address se,
        address rp,
        address token,
        uint256 rawReserve,
        uint256 seBal
    ) internal view returns (uint256) {
        // D60: raw leg = raw balance, times the rate when a provider is configured; buffered leg = shares x rate.
        if (se == address(0)) {
            return rp == address(0) ? rawReserve : (rawReserve * getRateFailClosed(rp)) / 1e18;
        }
        if (seBal == 0) return 0;
        if (rp == address(0)) revert RateProviderRequired();
        return ratedNative(seBal, getRateFailClosed(rp), se, token);
    }

    /// @notice Preview claim-in (effective native) from buffering `amountInRaw` pool tokens into SE.
    function previewBufferClaimIn(
        address se,
        address rp,
        address token,
        uint256 amountInRaw,
        address hook
    ) internal view returns (uint256 dInNative) {
        if (amountInRaw == 0 || se == address(0)) return 0;
        if (se == token) return amountInRaw;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(token), amountInRaw, IERC20(se));
        if (sharesOut == 0) return amountInRaw;
        if (rp == address(0)) revert RateProviderRequired();
        hook;
        return ratedNative(sharesOut, getRateFailClosed(rp), se, token);
    }

    /// @notice Preview pool-token out from unwrapping SE shares that deliver `dOutNative` effective.
    function previewUnwrapForEffectiveOut(
        address se,
        address rp,
        address token,
        uint256 dOutNative
    ) internal view returns (uint256 amountOutNative, uint256 sharesOut) {
        if (dOutNative == 0 || se == address(0)) return (0, 0);
        if (rp == address(0)) revert RateProviderRequired();
        uint256 rate = getRateFailClosed(rp);
        // ceil shares for exact effective out when selling; the unwrap amount is the SE's buffering quote
        sharesOut = sharesForNativeUp(dOutNative, rate, se, token);
        amountOutNative = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(token));
        return (amountOutNative, sharesOut);
    }

    /// @notice Preview pool-token out from burning `sharesOut` SE shares (pro-rata remove).
    function previewUnwrapShares(address se, address token, uint256 sharesOut)
        internal
        view
        returns (uint256)
    {
        if (sharesOut == 0 || se == address(0)) return 0;
        if (se == token) return sharesOut;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(token));
    }

    /// @notice Shares needed so unwrap delivers at least `amountOutNative` pool tokens (exact-out).
    function invertUnwrapExactTokenOut(address se, address token, uint256 amountOutNative)
        internal
        view
        returns (uint256 sharesIn)
    {
        if (amountOutNative == 0) return 0;
        if (se == token) return amountOutNative;
        return IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(token), amountOutNative);
    }
}

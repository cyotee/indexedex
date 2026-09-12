// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookClaimLib
 * @notice SE claim / rate / buffer-unwrap helpers (external previews + fail-closed rates).
 * @dev Pure Math must not call SE/RP — composition lives here.
 */
library UniswapV4StandardExchangeOrbitalBufferHookClaimLib {
    error RateProviderFailed();
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
        if (rp != address(0)) quote.rate = getRateFailClosed(rp);
        else if (se != address(0)) {
            quote.heldShares = IERC20(se).balanceOf(hook);
            quote.heldClaim = seClaimOf(se, token, quote.heldShares);
        }
    }

    function previewBufferClaimIn(BufferClaimQuote memory quote, uint256 amountInRaw)
        internal view returns (uint256)
    {
        if (amountInRaw == 0 || quote.se == address(0)) return 0;
        if (quote.se == quote.token) return amountInRaw;
        uint256 sharesOut = IStandardExchangeIn(quote.se).previewExchangeIn(
            IERC20(quote.token), amountInRaw, IERC20(quote.se)
        );
        if (sharesOut == 0) return 0;
        if (quote.rate != 0) return (sharesOut * quote.rate) / 1e18;
        uint256 afterClaim = seClaimOf(quote.se, quote.token, quote.heldShares + sharesOut);
        return afterClaim > quote.heldClaim ? afterClaim - quote.heldClaim : 0;
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
        if (se == address(0)) return rawReserve;
        if (seBal == 0) return 0;
        if (rp != address(0)) {
            uint256 rate = getRateFailClosed(rp);
            return (seBal * rate) / 1e18;
        }
        return seClaimOf(se, token, seBal);
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
        if (sharesOut == 0) return 0;
        if (rp != address(0)) {
            return (sharesOut * getRateFailClosed(rp)) / 1e18;
        }
        // Claim delta = post claim − pre claim for hook's SE balance + sharesOut.
        uint256 seBalBefore = IERC20(se).balanceOf(hook);
        uint256 claimBefore = seClaimOf(se, token, seBalBefore);
        uint256 claimAfter = seClaimOf(se, token, seBalBefore + sharesOut);
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }

    /// @notice Preview pool-token out from unwrapping SE shares that deliver `dOutNative` effective.
    function previewUnwrapForEffectiveOut(
        address se,
        address rp,
        address token,
        uint256 dOutNative
    ) internal view returns (uint256 amountOutNative, uint256 sharesOut) {
        if (dOutNative == 0 || se == address(0)) return (0, 0);
        if (rp != address(0)) {
            uint256 rate = getRateFailClosed(rp);
            // ceil shares for exact effective out when selling
            sharesOut = (dOutNative * 1e18 + rate - 1) / rate;
            amountOutNative = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), sharesOut, IERC20(token));
            return (amountOutNative, sharesOut);
        }
        // No RP: invert claim-out via exchangeOut when possible; else full revert (D31a).
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(token), dOutNative) returns (
            uint256 seIn
        ) {
            sharesOut = seIn;
            amountOutNative = dOutNative;
            return (amountOutNative, sharesOut);
        } catch {
            revert SeInvertUnavailable();
        }
    }

    /// @notice Preview pool-token out from burning `sharesOut` SE shares (pro-rata remove).
    function previewUnwrapShares(address se, address token, uint256 sharesOut)
        internal
        view
        returns (uint256)
    {
        if (sharesOut == 0 || se == address(0)) return 0;
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
        try IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(token), amountOutNative)
        returns (uint256 seIn) {
            return seIn;
        } catch {
            revert SeInvertUnavailable();
        }
    }
}

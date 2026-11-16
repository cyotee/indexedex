// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeCurveQuadStableBufferHookInExecutionBase} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookInExecutionBase.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookExitQuoteBase.sol";

import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget
 * @notice Join/exit + one-token aliases on inventory domain (StableSwap single-asset + prop).
 * @dev Firm M2: joinUnbalanced / joinSingleAssetExactOut / exitSingleAssetExactTokenOut shipped closed-form.
 *      B6: flexible SE-share / pair LP paths with per-leg flags.
 *      Full book only for single-asset and post-seed proportional. First mint requires all four > 0.
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget is
    UniswapV4StandardExchangeCurveQuadStableBufferHookInExecutionBase
{
    using SafeERC20 for IERC20;

    /* ----------------- firm: single-asset exact token out exit -------------- */

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return _quoteExitSingleExactTokenOut(tokenOut, amountOut, _totalSupply());
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 sharesIn) {
        sharesIn = _exitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return previewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }

    function withdrawSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 sharesIn) {
        sharesIn = _exitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function _exitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        internal returns (uint256 sharesIn)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 supply = _totalSupply();
        sharesIn = _quoteExitSingleExactTokenOut(tokenOut, amountOut, _totalSupply());
        if (sharesIn > sharesInMax) revert Slippage();
        _burnLp(msg.sender, sharesIn);
        ClaimLib.paySingleExitExactTokenOut(_tokenIndex(tokenOut), sharesIn, supply, to, amountOut);
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingleExactOut(
            msg.sender, to, tokenOut, amountOut, sharesIn, 0
        );
    }

    function _quoteExitSingleExactTokenOut(address tokenOut, uint256 amountOut, uint256 supply)
        internal view returns (uint256 sharesIn)
    {
        if (amountOut == 0 || supply <= Repo.MINIMUM_LIQUIDITY) revert ZeroAmount();
        uint8 idx = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[idx] != address(0) && IStandardExchangeOut(l.standardExchanges[idx]).previewExchangeOut(
            IERC20(l.standardExchanges[idx]), IERC20(tokenOut), amountOut) == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        uint256 low;
        uint256 cap = supply - Repo.MINIMUM_LIQUIDITY;
        uint256 high = supply / 100;
        if (high == 0) high = 1;
        if (high > cap) high = cap;
        while (ClaimLib.previewSingleExit(idx, high, supply, false) < amountOut) {
            low = high;
            if (high == cap) revert Slippage();
            high = high > cap / 2 ? cap : high * 2;
        }
        while (high - low > 1) {
            uint256 mid = low + (high - low) / 2;
            if (ClaimLib.previewSingleExit(idx, mid, supply, false) >= amountOut) high = mid;
            else low = mid;
        }
        return high;
    }

    /* -------------------------- proportional exit --------------------------- */

    function previewBurnToToken(uint256 lpAmount, address tokenOut) public view returns (uint256) {
        if (lpAmount == 0 || _totalSupply() == 0 || !_isLive()) return 0;
        (bool ok, uint8 idx, bool wantSe) = _tryResolveJoinToken(tokenOut);
        if (!ok) return 0;
        ClaimLib.Basket memory allocated = ClaimLib.allocatedBasket(lpAmount, _totalSupply());
        return ClaimLib.previewPayout(idx, allocated.shares[idx], allocated.local[idx], wantSe);
    }

    function previewExitProportional(uint256 shares) public view returns (uint256[] memory amounts) {
        return _previewComponentExit(shares, new bool[](4));
    }

    function _previewComponentExit(uint256 shares, bool[] memory flags) internal view returns (uint256[] memory amounts) {
        _validateSeShareFlags(flags);
        ClaimLib.Basket memory allocated = ClaimLib.allocatedBasket(shares, _totalSupply());
        amounts = new uint256[](4);
        for (uint8 i; i < 4; ++i) amounts[i] = ClaimLib.previewPayout(i, allocated.shares[i], allocated.local[i], flags[i]);
    }

    function _componentExit(uint256 shares, address to, bool[] memory flags, uint256[] memory minima)
        internal returns (uint256[] memory amounts)
    {
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        _validateSeShareFlags(flags);
        _requireAmountsLen4(minima);
        uint256 supply = _totalSupply();
        if (shares >= supply) revert WouldZeroReserve();
        ClaimLib.Basket memory allocated = ClaimLib.allocatedBasket(shares, supply);
        _burnLp(msg.sender, shares);
        uint256[4] memory output = ClaimLib.payBasket(allocated, flags, to);
        for (uint8 i; i < 4; ++i) if (output[i] < minima[i]) revert Slippage();
        amounts = Math.toDynamic(output);
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.ExitFlexible(msg.sender, to, shares, flags, amounts, 0);
    }

    function exitProportional(uint256 shares, address to, uint256[] calldata amountsMin, uint256 deadline)
        public onlyLiquidityRemover nonReentrant returns (uint256[] memory amounts)
    {
        _requireDeadline(deadline);
        return _componentExit(shares, to, new bool[](4), amountsMin);
    }

    /* ----------------------- single-asset exact BPT in ---------------------- */

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return _quoteExitSingleExactBptIn(tokenOut, sharesIn);
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return previewExitSingleAssetExactBptIn(tokenOut, sharesIn);
    }

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        public view returns (uint256[] memory amounts)
    {
        return _previewComponentExit(shares, receiveSeShare);
    }

    function exitProportionalFlexible(uint256 shares, address to, bool[] calldata receiveSeShare, uint256[] calldata amountsMin, uint256 deadline)
        public onlyLiquidityRemover nonReentrant returns (uint256[] memory amounts)
    {
        _requireDeadline(deadline);
        return _componentExit(shares, to, receiveSeShare, amountsMin);
    }

    function _requireExitFloors(uint256[4] memory invOut) internal view {
        uint256[4] memory natives = _nativeAll();
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] >= natives[i]) revert WouldZeroReserve();
        }
    }

    function _requireEdgeMins(uint256[4] memory edgeOut, uint256[] calldata amountsMin) internal pure {
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (edgeOut[i] < amountsMin[i]) revert Slippage();
        }
    }

    function _requirePostFullBook() internal view {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
    }

    function _payExitFlexibleLegs(uint256[4] memory invOut, bool[] memory receiveSeShare, address to)
        internal
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            uint256 amt = invOut[i];
            if (amt == 0) continue;
            address se = l.standardExchanges[i];
            if (se != address(0)) {
                if (receiveSeShare[i]) {
                    IERC20(se).safeTransfer(to, amt);
                } else {
                    _unwrapSeShares(i, amt, to);
                }
            } else {
                _debitRawIntentional(i, amt);
                IERC20(l.tokens[i]).safeTransfer(to, amt);
            }
        }
    }

    function _invToEdgeOutPreview(uint256[4] memory invOut, bool[] memory receiveSeShare)
        internal
        view
        returns (uint256[4] memory edgeOut)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0)) {
                edgeOut[i] = invOut[i];
            } else if (receiveSeShare[i]) {
                edgeOut[i] = invOut[i];
            } else {(edgeOut[i],) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }

    function previewExitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare
    ) public view returns (uint256 amountOut) {
        return _quoteExitSingleExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
    }

    function exitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptInFlexible(
            tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline
        );
    }

    function withdrawSingleFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public onlyLiquidityRemover nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptInFlexible(
            tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline
        );
    }

    function previewWithdrawSingleFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        public
        view
        returns (uint256 amountOut)
    {
        return previewExitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
    }

    /// @notice D60: the configured rate providers, one per leg (address(0) on a raw leg without one).
    function rateProviders() public view returns (address[] memory rps) {
        Repo.Layout storage l = Repo._layout();
        rps = new address[](Repo.N_TOKENS);
        for (uint256 i; i < Repo.N_TOKENS; ++i) rps[i] = l.rateProviders[i];
    }

    /// @notice D60: the rate provider configured for `token_`, address(0) when none or unknown token.
    function rateProvider(address token_) public view returns (address) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            if (l.tokens[i] == token_) return l.rateProviders[i];
        }
        return address(0);
    }
}

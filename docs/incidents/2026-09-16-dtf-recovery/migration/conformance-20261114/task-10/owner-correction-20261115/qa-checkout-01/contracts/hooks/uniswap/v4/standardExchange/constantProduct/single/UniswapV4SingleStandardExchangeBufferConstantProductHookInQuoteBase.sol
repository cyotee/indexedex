// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

interface ISingleBufferQuoteErrors {
    error ZeroAmount();
    error InvalidToken();
    error UnsupportedRoute();
    error NotLive();
    error InsufficientTokenOut();
}

/// @notice Internal-only quotes shared by the split single-buffer SE and SY hosts.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase is NativeStandardYieldQuoteBase {
    struct SingleZapQuote {
        bytes state;
        uint256 rawReserve;
        uint256 pairReserve;
        uint256 rawAdded;
        uint256 pairAdded;
        uint256 shareReserve;
        uint256 localReserve;
        uint256 sharesAdded;
    }

    function _previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        internal view override returns (uint256)
    {
        if (LiquidityRoute.isLiquidityRoute(tokenIn, tokenOut)) {
            if (address(tokenIn) == address(tokenOut)) revert LiquidityRoute.InvalidLiquidityRoute();
            if (address(tokenOut) == address(this)) return _singlePreviewJoin(address(tokenIn), amountIn);
            return _singlePreviewExit(address(tokenOut), amountIn);
        }
        bool zfo = _singleRoute(address(tokenIn), address(tokenOut));
        if (amountIn == 0) revert ISingleBufferQuoteErrors.ZeroAmount();
        return _singleSwapQuote(zfo, amountIn, false);
    }

    function _singlePreviewJoin(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        if (ERC20Repo._totalSupply() == 0 || amountIn == 0) return 0;
        return _singlePreviewDeposit(tokenIn, amountIn);
    }

    function _singleIsLive() private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return ERC20Repo._totalSupply() != 0 && l.bookedRaw != 0 && (l.bookedSeShares != 0 || l.localPairReserve != 0);
    }

    function _singlePreviewDeposit(address tokenIn, uint256 amountIn) internal view returns (uint256) {
        return ClaimLib.previewSingleComponentJoin(tokenIn, amountIn);
    }

    function _singlePreviewExit(address tokenOut, uint256 shares) internal view returns (uint256) {
        if (shares == 0 || ERC20Repo._totalSupply() == 0) return 0;
        return _singleWithdrawalPlan(shares, _singleExitSupply(), tokenOut);
    }

    function _singleExitSupply() private view returns (uint256) { return ERC20Repo._totalSupply(); }

    function _singleWithdrawalPlan(uint256 lpAmount, uint256, address tokenOut) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (tokenOut != l.rawToken && tokenOut != l.pairToken) revert ISingleBufferQuoteErrors.InvalidToken();
        return ClaimLib.previewSingleComponentExit(lpAmount, tokenOut == l.pairToken);
    }

    function _singleZapState(address tokenIn, uint256 amountIn) internal view returns (SingleZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.standardExchange) {
            (bytes memory state,) = Transition(l.standardExchange).quoteState(l.pairToken, address(this));
            return _singleShareZapState(state, amountIn);
        }
        (uint256 sold, uint256 other, uint256 kept) = _singleZapSplit(tokenIn, amountIn);
        return ClaimLib.singleZapState(tokenIn, sold, other, kept);
    }

    function _singleShareZapState(bytes memory state, uint256 shares) internal view returns (SingleZapQuote memory q) {
        return ClaimLib.singleShareZapState(state, shares);
    }

    function _singleFinishDeposit(SingleZapQuote memory q, uint256 supply) internal view returns (SingleZapQuote memory updated, uint256 minted, uint256 finalSupply) {
        return ClaimLib.singleFinishDeposit(q, supply);
    }

    function _singleMintableDeposit(bytes memory state, uint256 amount)
        internal view returns (bytes memory, uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        return ClaimLib.quoteMintableDepositExactIn(l.standardExchange, l.pairToken, state, amount);
    }

    function _singlePairRawOut(uint256 claimIn, uint256 pairReserve, uint256 rawReserve) internal view returns (uint256) {
        return ClaimLib.singlePairRawOut(claimIn, pairReserve, rawReserve);
    }

    function _singleZapSplit(address tokenIn, uint256 amountIn) internal view returns (uint256 saleAmt, uint256 amountOtherOut, uint256 keptIn) {
        Repo.Layout storage l = Repo._layout();
        bool zfo = _singleRoute(tokenIn, tokenIn == l.rawToken ? l.pairToken : l.rawToken);
        if (tokenIn == l.rawToken) {
            uint256 rInN = Math.toWad(l.bookedRaw, _singleDecimals(l.rawToken));
            saleAmt = Math.fromWadFloor(Math.swapDepositSaleAmt(Math.toWad(amountIn, _singleDecimals(l.rawToken)), rInN), _singleDecimals(l.rawToken));
        } else {
            uint256 claimInFull = ClaimLib.previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(ClaimLib.ratedReserve(), _singleDecimals(l.pairToken));
            uint256 saleClaim = Math.fromWadFloor(Math.swapDepositSaleAmt(Math.toWad(claimInFull, _singleDecimals(l.pairToken)), rInN), _singleDecimals(l.pairToken));
            saleAmt = claimInFull == 0 ? amountIn / 2 : (amountIn * saleClaim) / claimInFull;
        }
        if (saleAmt > amountIn) saleAmt = amountIn;
        if (saleAmt == 0 || saleAmt >= amountIn) saleAmt = amountIn / 2;
        amountOtherOut = _singleSwapQuote(zfo, saleAmt, true);
        keptIn = amountIn - saleAmt;
    }

    function _singleExchangeQuotePlan(bool zeroForOne, uint256 amountIn, address manager)
        internal view returns (ClaimLib.ExactInOutput memory output)
    {
        if (amountIn == 0) revert ISingleBufferQuoteErrors.ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == (l.currency0 == l.rawToken);
        uint256 rawBal = l.bookedRaw;
        uint256 seClaim = manager == address(0) ? ClaimLib.ratedReserve() : ClaimLib.ratedReserveWithContext(manager);
        if (rawIn) {
            uint256 rInN = Math.toWad(rawBal, _singleDecimals(l.rawToken));
            uint256 rOutN = Math.toWad(seClaim, _singleDecimals(l.pairToken));
            uint256 aInN = Math.toWad(amountIn, _singleDecimals(l.rawToken));
            uint256 budget = Math.fromWadFloor(Math.saleQuote(aInN, rInN, rOutN), _singleDecimals(l.pairToken));
            output = manager == address(0) ? ClaimLib.previewBudget(budget) : ClaimLib.previewBudgetWithContext(budget, manager);
        } else {
            uint256 claimIn = manager == address(0) ? ClaimLib.previewBufferClaimIn(amountIn) : ClaimLib.previewBufferClaimInWithContext(amountIn, manager);
            output.amountOut = _singlePairRawOut(claimIn, seClaim, l.bookedRaw);
        }
    }

    function _singleSwapQuote(bool zfo, uint256 amount, bool zap) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 rawBal = l.bookedRaw;
        uint256 claim = ClaimLib.ratedReserve();
        if (zfo == (l.currency0 == l.rawToken)) {
            uint256 budget = Math.fromWadFloor(Math.saleQuote(Math.toWad(amount, _singleDecimals(l.rawToken)),
                Math.toWad(rawBal, _singleDecimals(l.rawToken)), Math.toWad(claim, _singleDecimals(l.pairToken))), _singleDecimals(l.pairToken));
            if (zap && (budget == 0 || ClaimLib.sharesForPairUnitsDown(budget) == 0)) return 0;
            return ClaimLib.previewBudget(budget).amountOut;
        }
        return _singlePairRawOut(ClaimLib.previewBufferClaimIn(amount), claim, rawBal);
    }

    function _singleSupply() internal view returns (uint256) { return ERC20Repo._totalSupply(); }

    function _singleSupplyForProduct(uint256) internal view returns (uint256) { return ERC20Repo._totalSupply(); }

    function _singleFeeShare() internal view returns (bool feeOn, uint256 share) {
        (IFeeCollectorProxy to, uint256 fee) = IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        feeOn = address(to) != address(0) && fee != 0;
        share = (fee * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }

    function _singleReserve(address token) private view returns (uint256) {
        return token == Repo._layout().rawToken ? Repo._layout().bookedRaw : ClaimLib.ratedReserve();
    }
    function _singleRawReserve(address token) internal view returns (uint256) {
        return token == Repo._layout().rawToken ? Repo._layout().bookedRaw : Repo._layout().bookedSeShares;
    }
    function _singleRawDelta(bool for0, uint256 used0, uint256 used1) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 used = for0 ? used0 : used1;
        if ((for0 ? l.currency0 : l.currency1) == l.rawToken || l.pairToken == l.standardExchange || used == 0) return used;(uint256 quotedAmountOut,) = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.pairToken), used, IERC20(l.standardExchange));
        return quotedAmountOut;
    }
    function _singleDecimals(address token) internal view returns (uint8 d) {
        return ClaimLib.singleDecimals(token);
    }
    function _singleRoute(address tokenIn, address tokenOut) private view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.currency0 && tokenOut == l.currency1) return true;
        if (tokenIn == l.currency1 && tokenOut == l.currency0) return false;
        revert ISingleBufferQuoteErrors.UnsupportedRoute();
    }
    function _singleOrderX(uint256 raw, uint256 pair) internal view returns (uint256) {
        return ClaimLib.singleOrderX(raw, pair);
    }
    function _singleOrderY(uint256 raw, uint256 pair) internal view returns (uint256) {
        return ClaimLib.singleOrderY(raw, pair);
    }
    function _singleClamp(uint256 x, uint256 y, uint256 amount0, uint256 amount1) internal pure returns (uint256 used0, uint256 used1) {
        return ClaimLib.singleClamp(x, y, amount0, amount1);
    }
}

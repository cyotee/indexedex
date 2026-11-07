// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";

/// @notice Composed deposit projections, separated from the native SY quote surface.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositProjectionTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
{
    function previewJoinProportional(uint256[] calldata amounts) external view returns (uint256 shares, uint256[] memory usedAmounts) {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != 2) revert InvalidRoute();
        uint256 amt0 = l.currency0 == l.rawToken ? amounts[0] : amounts[1];
        uint256 amt1 = l.currency0 == l.rawToken ? amounts[1] : amounts[0];
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = previewDeposit(amt0, amt1);
        usedAmounts = new uint256[](2);
        usedAmounts[0] = l.currency0 == l.rawToken ? used0 : used1;
        usedAmounts[1] = l.currency0 == l.rawToken ? used1 : used0;
    }
    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts) external view returns (uint256 shares) {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (ERC20Repo._totalSupply() == 0 && (acc.raw == 0 || (acc.pair == 0 && acc.seShare == 0))) return 0;
        if (acc.seShare > 0) {
            (shares,,) = previewDepositWithSeShares(acc.raw, acc.seShare);
            return shares;
        }
        Repo.Layout storage l = Repo._layout();
        uint256 amt0 = l.currency0 == l.rawToken ? acc.raw : acc.pair;
        uint256 amt1 = l.currency0 == l.rawToken ? acc.pair : acc.raw;
        (shares,,) = previewDeposit(amt0, amt1);
    }
    function previewDeposit(uint256 amount0, uint256 amount1) public view returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        Repo.Layout storage l = Repo._layout();
        bool rawFirst = l.currency0 == l.rawToken;
        uint256 usedRaw;
        uint256 usedPair;
        (lpAmount, usedRaw, usedPair) = ClaimLib.previewComponentJoin(
            rawFirst ? amount0 : amount1, rawFirst ? amount1 : amount0, false
        );
        (used0, used1) = rawFirst ? (usedRaw, usedPair) : (usedPair, usedRaw);
    }

    function previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        external view returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken || rawTokenOut != l.rawToken) revert UnsupportedRoute();
        LegLib.ExternalQuote memory q = LegLib.afterExternalExchange(l.standardExchange, pairToken, tokenIn, amountIn, address(this));
        q.heldShares = l.bookedSeShares;
        return _swapAtExternalState(q);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken || detfToken != l.rawToken) revert UnsupportedRoute();
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchange, pairToken, tokenIn, amountIn, address(this));
        q.heldShares = l.bookedSeShares;
        pairValue = q.exchange.quoteAssets(q.state, q.assets);
        if (!_isLive()) return (pairValue, 0, 0);
        {
            uint256 pairClaim = l.localPairReserve + q.exchange.quoteAssets(q.state, l.bookedSeShares);
            if (pairClaim != 0) liquidityDetf = FullMath.mulDiv(l.bookedRaw, pairValue, pairClaim);
        }
        q.assets = FullMath.mulDiv(pairValue, multiplier, 1e18);
        purchasedDetf = _swapAtExternalState(q);
    }

    function _swapAtExternalState(LegLib.ExternalQuote memory q) private view returns (uint256) {
        (uint256 beforeClaim, uint256 claimIn) = ClaimLib.projectedClaimIn(address(q.exchange), q.state, q.heldShares, q.assets);
        if (beforeClaim == 0 && q.heldShares > 0) beforeClaim = 1;
        return _singlePairRawOut(claimIn, beforeClaim, Repo._layout().bookedRaw);
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256 sharesOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken) revert InvalidRoute();
        if (ERC20Repo._totalSupply() == 0 || amountIn == 0) return 0;
        LegLib.ExternalQuote memory externalQuote = LegLib.afterExternalDeposit(
            l.standardExchange, pairToken, tokenIn, amountIn, address(this)
        );
        uint256 supply = ERC20Repo._totalSupply();
        SingleZapQuote memory q = _singleShareZapState(externalQuote.state, externalQuote.assets);
        (q, sharesOut,) = _singleFinishDeposit(q, supply);
    }

    function previewDepositWithSeShares(uint256 amountRaw, uint256 amountSe)
        public view returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        return ClaimLib.previewComponentJoin(amountRaw, amountSe, true);
    }
}

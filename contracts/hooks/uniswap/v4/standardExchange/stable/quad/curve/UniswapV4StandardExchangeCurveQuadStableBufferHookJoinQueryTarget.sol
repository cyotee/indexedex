// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";

import {NativeStandardYieldPreviewTarget as NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";


import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol";

/// @notice Read-only liquidity quotes. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget is UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore, NativeStandardYieldTarget {
    function previewJoinNativeComponents(uint256[] calldata localAmounts, uint256[] calldata shareAmounts)
        public view returns (uint256 netLp)
    {
        return _entryPreviewJoinNativeComponents(localAmounts, shareAmounts);
    }

function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256 amountOut, uint256 amountRefunded) {
        return _previewExchangeInResult(tokenIn, amountIn, tokenOut);
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = _tokenIndex(pairToken);
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[index], pairToken, tokenIn, amountIn, address(this));
        uint256 gross = ClaimLib.projectedShareJoin(
            index, q.assets, q.state, _totalSupply()
        );
        (uint256 net,) = _splitMintFee(gross);
        return net;
    }

    function previewJoinProportional(uint256[] calldata amounts)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _entryPreviewJoinProportional(amounts);
    }

    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        return _entryPreviewJoinUnbalanced(amounts);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinUnbalanced(tokensIn, amounts);
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _entryPreviewJoinSingleAssetExactOut(tokenIn, sharesOut);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewDepositSingle(tokenIn, amountIn);
    }

    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _entryPreviewJoinProportionalFlexible(amounts, amountIsSeShare);
    }

    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }

    function previewDepositSingleFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _entryPreviewDepositSingleFlexible(tokenIn, amountIn, amountIsSeShare);
    }

    function previewSynthetic(IDetfReserveQuote.DetfQuoteCtx calldata ctx, address numeraire)
        external
        view
        returns (uint256 wad)
    {
        if (ctx.ownedLp == 0 || ctx.detfTotalSupply == 0 || ctx.creationPairPerDetfWad == 0) {
            return 0;
        }
        if (!_isLive()) return 0;
        address out_ = numeraire;
        if (out_ == address(0)) {
        address[] memory n = _bindingSyntheticNumeraires();
            if (n.length == 0) return 0;
            out_ = n[0];
        }
        return ClaimLib.syntheticValue(ctx, out_);
    }

    /// @notice Geometric native-inventory denomination; no projected protocol growth mint.
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _totalSupply();
        if (supply_ == 0) return 1e18;
        return FullMath.mulDiv(_rootKNow(), 1e18, supply_);
    }

    function yieldToken() external pure override returns (address) { return address(0); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        return ClaimLib.nativeSyTokens();
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
}

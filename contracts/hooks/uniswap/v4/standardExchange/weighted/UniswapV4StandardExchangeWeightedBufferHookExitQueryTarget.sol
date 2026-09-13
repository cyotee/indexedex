// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {DETFDecimalScaleLib} from "contracts/vaults/detf/common/core/DETFDecimalScaleLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";

import {UniswapV4StandardExchangeWeightedBufferHookExitCore} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitCore.sol";

/// @notice Read-only liquidity quotes. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget is UniswapV4StandardExchangeWeightedBufferHookExitCore, NativeStandardYieldTarget {
    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _entryPreviewBurnToToken(lpAmount, tokenOut);
    }

    function previewExitProportional(uint256 shares)
        public
        view
        returns (uint256[] memory amounts)
    {
        return _entryPreviewExitProportional(shares);
    }

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return _entryPreviewExitSingleAssetExactBptIn(tokenOut, sharesIn);
    }

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return _entryPreviewWithdrawSingle(tokenOut, sharesIn);
    }

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return _entryPreviewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return _entryPreviewWithdrawSingleExactOut(tokenOut, amountOut);
    }

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        public
        view
        returns (uint256[] memory amounts)
    {
        return _entryPreviewExitProportionalFlexible(shares, receiveSeShare);
    }

    function previewExitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare
    ) public view returns (uint256 amountOut) {
        return _entryPreviewExitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
    }

    function previewWithdrawSingleFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        public
        view
        returns (uint256 amountOut)
    {
        return _entryPreviewWithdrawSingleFlexible(tokenOut, sharesIn, receiveSeShare);
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
            address[] memory nums_ = syntheticNumeraires();
            if (nums_.length == 0) return 0;
            out_ = nums_[0];
        }
        uint256 pairOut = IDetfReserveQuote(address(this)).previewBurnToToken(ctx.ownedLp, out_);
        if (pairOut == 0) return 0;
        uint256 den_ = ctx.detfTotalSupply + ctx.pendingExpansion;
        if (den_ == 0) return 0;
        uint256 pairWad = DETFDecimalScaleLib.nativeToWad(out_, pairOut);
        uint256 mid_ = (pairWad * 1e18) / den_;
        return (mid_ * 1e18) / ctx.creationPairPerDetfWad;
    }

    function yieldToken() external pure override returns (address) { return address(0); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }

    /// @notice The same weighted native-inventory unit used for LP issuance and protocol LP fees.
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _previewSupplyAfterProtocolMint();
        if (supply_ == 0) return 1e18;
        (,, uint256 liquidity_) = _measureK();
        return FullMath.mulDiv(liquidity_, 1e18, supply_);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l_ = Repo._layout();
        tokens_ = new address[](uint256(l_.numTokens) * 2);
        uint256 count_;
        for (uint256 i_; i_ < l_.numTokens; ++i_) tokens_[count_++] = l_.tokens[i_];
        for (uint256 i_; i_ < l_.numTokens; ++i_) {
            address se_ = l_.standardExchanges[i_];
            if (se_ == address(0)) continue;
            bool found_;
            for (uint256 j_; j_ < count_; ++j_) if (tokens_[j_] == se_) { found_ = true; break; }
            if (!found_) tokens_[count_++] = se_;
        }
        assembly ("memory-safe") { mstore(tokens_, count_) }
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
}

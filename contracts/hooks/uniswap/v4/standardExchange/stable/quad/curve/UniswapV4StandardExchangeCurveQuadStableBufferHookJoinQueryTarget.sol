// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";

import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {DETFDecimalScaleLib} from "contracts/vaults/detf/common/core/DETFDecimalScaleLib.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";


import {UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol";

/// @notice Read-only liquidity quotes. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookJoinQueryTarget is UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore, NativeStandardYieldTarget {
    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint8 index = _tokenIndex(pairToken);
        LegLib.ExternalQuote memory q = LegLib.afterExternalDeposit(l.standardExchanges[index], pairToken, tokenIn, amountIn, address(this));
        uint256[4] memory inv = _invWadAll();
        inv[index] = Math.scaleTo(q.heldShares, l.invScales[index]);
        uint256 supply = _previewSupplyAfterProtocolMint(inv);
        uint256 fee = _feeOracle().dexSwapFeeOfVault(address(this));
        if (fee >= Math.WAD) revert InvalidFeeWad();
        return Math.singleJoinExactInShares(inv, Math.scaleTo(q.assets, l.invScales[index]), index, _amp(), supply, fee);
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
            address[] memory n = syntheticNumeraires();
            if (n.length == 0) return 0;
            out_ = n[0];
        }
        uint256 pairOut = IDetfReserveQuote(address(this)).previewBurnToToken(ctx.ownedLp, out_);
        if (pairOut == 0) return 0;
        uint256 pairWad = DETFDecimalScaleLib.nativeToWad(out_, pairOut);
        uint256 mid_ = (pairWad * 1e18) / ctx.detfTotalSupply;
        return (mid_ * 1e18) / ctx.creationPairPerDetfWad;
    }

    /// @notice Geometric native-inventory unit used for initial LP issuance and protocol LP fees.
    function exchangeRate() external view override returns (uint256) {
        uint256 supply_ = _previewSupplyAfterProtocolMint();
        if (supply_ == 0) return 1e18;
        return FullMath.mulDiv(_rootKNow(), 1e18, supply_);
    }

    function yieldToken() external pure override returns (address) { return address(0); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l_ = Repo._layout();
        tokens_ = new address[](uint256(Repo.N_TOKENS) * 2);
        uint256 count_;
        for (uint256 i_; i_ < Repo.N_TOKENS; ++i_) tokens_[count_++] = l_.tokens[i_];
        for (uint256 i_; i_ < Repo.N_TOKENS; ++i_) {
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultRepo
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultCommon
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget
/// @notice Preview counterpart of the exact-out surface: returns the `amountIn` that `exchangeOut`
///         would consume for exactly `amountOut_`, using the same route/candidate selection.
abstract contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget is DualLiquidityLinkedCrossVersionUniswapVaultCommon {
    /// @notice Quotes the input required to receive exactly `amountOut_` of `tokenOut_`.
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        public
        view
        virtual
        returns (uint256 amountIn_)
    {
        TokenKind kindIn_ = _classify(tokenIn_);
        TokenKind kindOut_ = _classify(tokenOut_);

        if (kindOut_ == TokenKind.Shares) {
            amountIn_ = _quoteDepositOut(kindIn_, tokenIn_, amountOut_);
        } else if (kindIn_ == TokenKind.Shares) {
            amountIn_ = _quoteRedeemOut(kindOut_, tokenOut_, amountOut_);
        } else {
            amountIn_ = _quoteSwapOut(kindIn_, kindOut_, tokenIn_, tokenOut_, amountOut_);
        }
    }

    function _quoteDepositOut(TokenKind kindIn_, IERC20 tokenIn_, uint256 amountOut_)
        private
        view
        returns (uint256 amountIn_)
    {
        (uint256 grossShares_,) = _grossUpShares(amountOut_);
        uint256 bptNeeded_ = _bptForSharesUp(grossShares_);
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        if (kindIn_ == TokenKind.ReserveBpt) {
            return bptNeeded_;
        }
        if (kindIn_ == TokenKind.VaultAShare || kindIn_ == TokenKind.VaultBShare || kindIn_ == TokenKind.PairVaultShare)
        {
            return _quoteJoinReserveOut(tokenIn_, bptNeeded_);
        }
        if (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) {
            (IStandardExchangeProxy legVault_, IERC20 legShare_) =
                kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultAShare) : (repo_.vaultB, repo_.vaultBShare);
            uint256 legShareNeeded_ = _quoteJoinReserveOut(legShare_, bptNeeded_);
            uint256 viaLeg_ = legVault_.previewExchangeOut(tokenIn_, legShare_, legShareNeeded_);
            uint256 pairShareNeeded_ = _quoteJoinReserveOut(repo_.pairVaultShare, bptNeeded_);
            uint256 viaPair_ = repo_.pairVault.previewExchangeOut(tokenIn_, repo_.pairVaultShare, pairShareNeeded_);
            return viaLeg_ <= viaPair_ ? viaLeg_ : viaPair_;
        }
        if (kindIn_ == TokenKind.CommonToken) {
            uint256 pairShareNeeded_ = _quoteJoinReserveOut(repo_.pairVaultShare, bptNeeded_);
            uint256 linkedViaA_ =
                repo_.pairVault.previewExchangeOut(repo_.tokenA, repo_.pairVaultShare, pairShareNeeded_);
            uint256 commonViaA_ = repo_.vaultA.previewExchangeOut(repo_.commonToken, repo_.tokenA, linkedViaA_);
            uint256 linkedViaB_ =
                repo_.pairVault.previewExchangeOut(repo_.tokenB, repo_.pairVaultShare, pairShareNeeded_);
            uint256 commonViaB_ = repo_.vaultB.previewExchangeOut(repo_.commonToken, repo_.tokenB, linkedViaB_);
            return commonViaA_ <= commonViaB_ ? commonViaA_ : commonViaB_;
        }
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, IERC20(address(this)));
    }

    function _quoteRedeemOut(TokenKind kindOut_, IERC20 tokenOut_, uint256 amountOut_)
        private
        view
        returns (uint256 amountIn_)
    {
        if (kindOut_ == TokenKind.ReserveBpt) {
            return _sharesForBptUp(amountOut_);
        }
        if (
            kindOut_ == TokenKind.VaultAShare || kindOut_ == TokenKind.VaultBShare
                || kindOut_ == TokenKind.PairVaultShare
        ) {
            uint256 payIndex_ = kindOut_ == TokenKind.VaultAShare ? 0 : (kindOut_ == TokenKind.VaultBShare ? 1 : 2);
            uint256 bptDue_ = _bptDueForVaultShareExactOut(payIndex_, amountOut_);
            return _sharesForBptUp(bptDue_);
        }
        // shares -> linked/common asset exact-out is unsupported (nonlinear inversion).
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
    }

    function _quoteSwapOut(TokenKind kindIn_, TokenKind kindOut_, IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        private
        view
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        bool linkedPair_ = (kindIn_ == TokenKind.TokenA && kindOut_ == TokenKind.TokenB)
            || (kindIn_ == TokenKind.TokenB && kindOut_ == TokenKind.TokenA);
        bool commonToLinked_ =
            kindIn_ == TokenKind.CommonToken && (kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB);
        bool linkedToCommon_ =
            (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) && kindOut_ == TokenKind.CommonToken;

        if (commonToLinked_ || linkedToCommon_) {
            TokenKind linkedKind_ = kindIn_ == TokenKind.CommonToken ? kindOut_ : kindIn_;
            IStandardExchangeProxy leg_ = linkedKind_ == TokenKind.TokenA ? repo_.vaultA : repo_.vaultB;
            return leg_.previewExchangeOut(tokenIn_, tokenOut_, amountOut_);
        }
        if (linkedPair_) {
            (IStandardExchangeProxy vaultIn_, IStandardExchangeProxy vaultOut_) =
                kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultB) : (repo_.vaultB, repo_.vaultA);
            uint256 directIn_ = repo_.pairVault.previewExchangeOut(tokenIn_, tokenOut_, amountOut_);
            uint256 commonNeeded_ = vaultOut_.previewExchangeOut(repo_.commonToken, tokenOut_, amountOut_);
            uint256 twoHopIn_ = vaultIn_.previewExchangeOut(tokenIn_, repo_.commonToken, commonNeeded_);
            return directIn_ <= twoHopIn_ ? directIn_ : twoHopIn_;
        }
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, tokenOut_);
    }
}

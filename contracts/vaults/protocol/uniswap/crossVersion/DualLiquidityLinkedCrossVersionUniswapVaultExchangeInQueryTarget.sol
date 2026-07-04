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

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget
/// @notice Preview counterpart of the deposit routes. `previewExchangeIn` returns the USER share
///         slice (net of the usage fee), mirroring `exchangeIn` exactly, including best-of-candidate
///         selection so a quote never disagrees with execution.
abstract contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget is DualLiquidityLinkedCrossVersionUniswapVaultCommon {
    /// @notice Quotes the output for `amountIn_` of `tokenIn_`. When `tokenOut_` is the vault share
    ///         token the result is shares minted (net of fee); otherwise it is the swap output.
    /// @dev Mirrors `exchangeIn` exactly, including best-of-candidate selection.
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        public
        view
        virtual
        returns (uint256 amountOut_)
    {
        TokenKind kindIn_ = _classify(tokenIn_);
        TokenKind kindOut_ = _classify(tokenOut_);

        if (kindOut_ == TokenKind.Shares) {
            uint256 bptOut_ = _quoteDepositBpt(kindIn_, tokenIn_, amountIn_);
            (amountOut_,) = _previewSharesForBpt(bptOut_);
        } else if (kindIn_ == TokenKind.Shares) {
            amountOut_ = _quoteRedeem(kindOut_, tokenOut_, amountIn_);
        } else {
            amountOut_ = _quoteSwap(kindIn_, kindOut_, tokenIn_, tokenOut_, amountIn_);
        }
    }

    /// @dev Quotes a redemption payout, mirroring `_redeem` including the max-return leg selection.
    ///      Returns the ACTUAL payout the redeemer receives (the redeposited legs' value stays in
    ///      the reserve and is intentionally excluded), per the family's disclosure rule.
    function _quoteRedeem(TokenKind kindOut_, IERC20 tokenOut_, uint256 sharesIn_)
        private
        view
        returns (uint256 amountOut_)
    {
        uint256 bptDue_ = _quoteBptForShares(sharesIn_);
        if (kindOut_ == TokenKind.ReserveBpt) {
            return bptDue_;
        }

        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256[] memory amounts_ = _previewExitReserveProportional(bptDue_);

        if (
            kindOut_ == TokenKind.VaultAShare || kindOut_ == TokenKind.VaultBShare
                || kindOut_ == TokenKind.PairVaultShare
        ) {
            uint256 payIndex_ = kindOut_ == TokenKind.VaultAShare ? 0 : (kindOut_ == TokenKind.VaultBShare ? 1 : 2);
            return amounts_[payIndex_];
        }
        if (kindOut_ == TokenKind.CommonToken || kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB) {
            return _quoteAssetRedeemPayout(repo_, tokenOut_, amounts_);
        }
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
    }

    /// @dev Best-of eligible leg quotes for shares → underlying asset. Stack-isolated helper.
    function _quoteAssetRedeemPayout(
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_,
        IERC20 tokenOut_,
        uint256[] memory amounts_
    ) private view returns (uint256 bestOut_) {
        bool found_;
        for (uint256 i = 0; i < 3; i++) {
            if (amounts_[i] == 0) continue;
            if (!_legEligibleForAsset(repo_, i, tokenOut_)) continue;
            uint256 q_ = _previewLegToAsset(repo_, i, amounts_[i], tokenOut_);
            if (!found_ || q_ > bestOut_) {
                bestOut_ = q_;
                found_ = true;
            }
        }
        if (!found_ || bestOut_ == 0) {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), tokenOut_);
        }
    }

    function _legEligibleForAsset(
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_,
        uint256 i_,
        IERC20 tokenOut_
    ) private view returns (bool) {
        address t = address(tokenOut_);
        if (i_ == 0) return t == address(repo_.commonToken) || t == address(repo_.tokenA);
        if (i_ == 1) return t == address(repo_.commonToken) || t == address(repo_.tokenB);
        return t == address(repo_.tokenA) || t == address(repo_.tokenB);
    }

    function _previewLegToAsset(
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_,
        uint256 i_,
        uint256 amountIn_,
        IERC20 tokenOut_
    ) private view returns (uint256) {
        IStandardExchangeProxy vault_ = i_ == 0 ? repo_.vaultA : (i_ == 1 ? repo_.vaultB : repo_.pairVault);
        IERC20 share_ = i_ == 0 ? repo_.vaultAShare : (i_ == 1 ? repo_.vaultBShare : repo_.pairVaultShare);
        return vault_.previewExchangeIn(share_, amountIn_, tokenOut_);
    }

    /// @dev Quotes a token↔token swap, selecting the same best-of route `exchangeIn` would execute.
    function _quoteSwap(TokenKind kindIn_, TokenKind kindOut_, IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountIn_)
        private
        view
        returns (uint256 amountOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        bool linkedPair_ = (kindIn_ == TokenKind.TokenA && kindOut_ == TokenKind.TokenB)
            || (kindIn_ == TokenKind.TokenB && kindOut_ == TokenKind.TokenA);
        bool commonToLinked_ =
            kindIn_ == TokenKind.CommonToken && (kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB);
        bool linkedToCommon_ =
            (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) && kindOut_ == TokenKind.CommonToken;

        if (linkedPair_) {
            (IStandardExchangeProxy vaultIn_, IStandardExchangeProxy vaultOut_) =
                kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultB) : (repo_.vaultB, repo_.vaultA);
            uint256 directOut_ = repo_.pairVault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
            uint256 midOut_ = vaultIn_.previewExchangeIn(tokenIn_, amountIn_, repo_.commonToken);
            uint256 hopOut_ = vaultOut_.previewExchangeIn(repo_.commonToken, midOut_, tokenOut_);
            amountOut_ = directOut_ >= hopOut_ ? directOut_ : hopOut_;
        } else if (commonToLinked_ || linkedToCommon_) {
            TokenKind linkedKind_ = kindIn_ == TokenKind.CommonToken ? kindOut_ : kindIn_;
            IStandardExchangeProxy leg_ = linkedKind_ == TokenKind.TokenA ? repo_.vaultA : repo_.vaultB;
            amountOut_ = leg_.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, tokenOut_);
        }
    }

    /// @dev Returns the BPT a deposit of `amountIn_` `tokenIn_` would add to the reserve, selecting
    ///      the same best-of candidate `exchangeIn` would execute. Reverts on unsupported tokenIn.
    function _quoteDepositBpt(TokenKind kindIn_, IERC20 tokenIn_, uint256 amountIn_)
        private
        view
        returns (uint256 bptOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        if (kindIn_ == TokenKind.ReserveBpt) {
            return amountIn_;
        }
        if (kindIn_ == TokenKind.VaultAShare || kindIn_ == TokenKind.VaultBShare || kindIn_ == TokenKind.PairVaultShare)
        {
            return _quoteJoinReserve(tokenIn_, amountIn_);
        }
        if (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) {
            return _quoteLinkedTokenBpt(kindIn_, tokenIn_, amountIn_);
        }
        if (kindIn_ == TokenKind.CommonToken) {
            uint256 viaA_ = _quoteCommonVia(repo_.vaultA, repo_.tokenA, amountIn_);
            uint256 viaB_ = _quoteCommonVia(repo_.vaultB, repo_.tokenB, amountIn_);
            return viaA_ >= viaB_ ? viaA_ : viaB_;
        }
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(tokenIn_, IERC20(address(this)));
    }

    /// @dev max(BPT via own leg vault, BPT via pair vault) for a linked-token deposit.
    function _quoteLinkedTokenBpt(TokenKind kindIn_, IERC20 token_, uint256 amountIn_)
        private
        view
        returns (uint256 bptOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (IStandardExchangeProxy legVault_, IERC20 legShare_) =
            kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultAShare) : (repo_.vaultB, repo_.vaultBShare);

        uint256 legShareOut_ = legVault_.previewExchangeIn(token_, amountIn_, legShare_);
        uint256 legBpt_ = _quoteJoinReserve(legShare_, legShareOut_);

        uint256 pairShareOut_ = repo_.pairVault.previewExchangeIn(token_, amountIn_, repo_.pairVaultShare);
        uint256 pairBpt_ = _quoteJoinReserve(repo_.pairVaultShare, pairShareOut_);

        bptOut_ = legBpt_ >= pairBpt_ ? legBpt_ : pairBpt_;
    }

    /// @dev BPT from common -> linkedToken (via `legVault_`) -> pair share -> reserve.
    function _quoteCommonVia(IStandardExchangeProxy legVault_, IERC20 linkedToken_, uint256 amountIn_)
        private
        view
        returns (uint256 bptOut_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 linkedOut_ = legVault_.previewExchangeIn(repo_.commonToken, amountIn_, linkedToken_);
        uint256 pairShareOut_ = repo_.pairVault.previewExchangeIn(linkedToken_, linkedOut_, repo_.pairVaultShare);
        bptOut_ = _quoteJoinReserve(repo_.pairVaultShare, pairShareOut_);
    }
}

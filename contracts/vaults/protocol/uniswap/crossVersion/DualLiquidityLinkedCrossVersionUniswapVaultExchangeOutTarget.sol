// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    ReentrancyLockModifiers
} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultRepo
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultCommon
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol";

/// @title DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget
/// @notice Exact-out surface: caller names the exact `amountOut` and caps input at `maxAmountIn`.
/// @dev Every supported route is closed-form invertible by chaining the legs' `previewExchangeOut`
///      backward from the target, then executing forward with matching `exchangeOut` calls so each
///      hop's exact output equals the next hop's exact input (no dust, no numeric search). The one
///      route whose inversion is nonlinear — redeeming shares into a linked/common asset — reverts
///      `UnsupportedRoute`; use exact-in `exchangeIn` for that direction.
/// @dev Parameters are threaded through `IStandardExchangeOut.OutArgs` to keep stack depth within
///      limits without `viaIR`.
abstract contract DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget is DualLiquidityLinkedCrossVersionUniswapVaultCommon, ReentrancyLockModifiers {
    using DualLiquidityLinkedCrossVersionUniswapVaultRepo for DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage;

    /// @notice Exchanges up to `maxAmountIn_` of `tokenIn_` for exactly `amountOut_` of `tokenOut_`.
    function exchangeOut(
        IERC20 tokenIn_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountIn_) {
        IStandardExchangeOut.OutArgs memory req_ = IStandardExchangeOut.OutArgs({
            tokenIn: tokenIn_,
            maxAmountIn: maxAmountIn_,
            tokenOut: tokenOut_,
            amountOut: amountOut_,
            recipient: recipient_,
            pretransferred: pretransferred_,
            deadline: deadline_
        });

        _requireActive(req_.deadline, req_.amountOut);
        _requireReserveLive();
        TokenKind kindIn_ = _classify(req_.tokenIn);
        TokenKind kindOut_ = _classify(req_.tokenOut);
        uint256[6] memory rest_ = _snapshotIntermediates();

        if (kindOut_ == TokenKind.Shares) {
            amountIn_ = _depositOut(kindIn_, req_);
        } else if (kindIn_ == TokenKind.Shares) {
            amountIn_ = _redeemOut(kindOut_, req_);
        } else {
            amountIn_ = _swapOut(kindIn_, kindOut_, req_);
        }

        _sweepResidual(rest_);
    }

    /* ====================================================================== */
    /*                          Deposit exact-out                             */
    /* ====================================================================== */

    /// @dev Produces exactly `req.amountOut` vault shares (plus the fee slice) for the cheapest input.
    function _depositOut(TokenKind kindIn_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        (uint256 grossShares_, uint256 feeShares_) = _grossUpShares(req_.amountOut);
        uint256 bptNeeded_ = _bptForSharesUp(grossShares_);
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        if (kindIn_ == TokenKind.ReserveBpt) {
            // Pretransferred BPT is indistinguishable from the reserve the proxy already holds, so a
            // direct BPT deposit must be pulled (mirrors the exact-in BPT deposit route).
            if (req_.pretransferred) {
                revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(req_.tokenIn, IERC20(address(this)));
            }
            amountIn_ = bptNeeded_;
            _enforceMax(amountIn_, req_.maxAmountIn);
            _receiveOut(req_.tokenIn, amountIn_, false);
        } else if (
            kindIn_ == TokenKind.VaultAShare || kindIn_ == TokenKind.VaultBShare || kindIn_ == TokenKind.PairVaultShare
        ) {
            amountIn_ = _quoteJoinReserveOut(req_.tokenIn, bptNeeded_);
            _enforceMax(amountIn_, req_.maxAmountIn);
            _receiveOut(req_.tokenIn, amountIn_, req_.pretransferred);
            _joinOut(req_.tokenIn, amountIn_, bptNeeded_, req_.deadline);
        } else if (kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) {
            amountIn_ = _depositOutLinked(kindIn_, bptNeeded_, req_);
        } else if (kindIn_ == TokenKind.CommonToken) {
            amountIn_ = _depositOutCommon(bptNeeded_, req_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(req_.tokenIn, IERC20(address(this)));
        }

        ERC20Repo._mint(req_.recipient, req_.amountOut);
        if (feeShares_ > 0) {
            ERC20Repo._mint(address(repo_.feeOracle.feeTo()), feeShares_);
        }
    }

    /// @dev Linked-token deposit exact-out: cheaper of (own leg → reserve) or (pair vault → reserve).
    function _depositOutLinked(TokenKind kindIn_, uint256 bptNeeded_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (IStandardExchangeProxy legVault_, IERC20 legShare_) =
            kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultAShare) : (repo_.vaultB, repo_.vaultBShare);

        uint256 legShareNeeded_ = _quoteJoinReserveOut(legShare_, bptNeeded_);
        uint256 pairShareNeeded_ = _quoteJoinReserveOut(repo_.pairVaultShare, bptNeeded_);

        bool viaLeg_;
        {
            uint256 viaLegIn_ = legVault_.previewExchangeOut(req_.tokenIn, legShare_, legShareNeeded_);
            uint256 viaPairIn_ =
                repo_.pairVault.previewExchangeOut(req_.tokenIn, repo_.pairVaultShare, pairShareNeeded_);
            viaLeg_ = viaLegIn_ <= viaPairIn_;
            amountIn_ = viaLeg_ ? viaLegIn_ : viaPairIn_;
        }

        _enforceMax(amountIn_, req_.maxAmountIn);
        _receiveOut(req_.tokenIn, amountIn_, req_.pretransferred);
        if (viaLeg_) {
            _legOut(legVault_, req_.tokenIn, amountIn_, legShare_, legShareNeeded_, address(this), req_.deadline);
            _joinOut(legShare_, legShareNeeded_, bptNeeded_, req_.deadline);
        } else {
            _legOut(
                repo_.pairVault,
                req_.tokenIn,
                amountIn_,
                repo_.pairVaultShare,
                pairShareNeeded_,
                address(this),
                req_.deadline
            );
            _joinOut(repo_.pairVaultShare, pairShareNeeded_, bptNeeded_, req_.deadline);
        }
    }

    /// @dev Common-token deposit exact-out: common → linked → pair share → reserve, cheaper of via-A/B.
    function _depositOutCommon(uint256 bptNeeded_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 pairShareNeeded_ = _quoteJoinReserveOut(repo_.pairVaultShare, bptNeeded_);

        IStandardExchangeProxy legVault_;
        IERC20 linked_;
        uint256 linkedNeeded_;
        {
            uint256 linkedViaA_ =
                repo_.pairVault.previewExchangeOut(repo_.tokenA, repo_.pairVaultShare, pairShareNeeded_);
            uint256 linkedViaB_ =
                repo_.pairVault.previewExchangeOut(repo_.tokenB, repo_.pairVaultShare, pairShareNeeded_);
            uint256 commonViaA_ = repo_.vaultA.previewExchangeOut(repo_.commonToken, repo_.tokenA, linkedViaA_);
            uint256 commonViaB_ = repo_.vaultB.previewExchangeOut(repo_.commonToken, repo_.tokenB, linkedViaB_);
            bool viaA_ = commonViaA_ <= commonViaB_;
            legVault_ = viaA_ ? repo_.vaultA : repo_.vaultB;
            linked_ = viaA_ ? repo_.tokenA : repo_.tokenB;
            linkedNeeded_ = viaA_ ? linkedViaA_ : linkedViaB_;
            amountIn_ = viaA_ ? commonViaA_ : commonViaB_;
        }

        _enforceMax(amountIn_, req_.maxAmountIn);
        _receiveOut(repo_.commonToken, amountIn_, req_.pretransferred);
        _legOut(legVault_, repo_.commonToken, amountIn_, linked_, linkedNeeded_, address(this), req_.deadline);
        _legOut(
            repo_.pairVault,
            linked_,
            linkedNeeded_,
            repo_.pairVaultShare,
            pairShareNeeded_,
            address(this),
            req_.deadline
        );
        _joinOut(repo_.pairVaultShare, pairShareNeeded_, bptNeeded_, req_.deadline);
    }

    /* ====================================================================== */
    /*                          Redeem exact-out                              */
    /* ====================================================================== */

    /// @dev Burns the fewest shares to deliver exactly `req.amountOut` of `req.tokenOut`.
    function _redeemOut(TokenKind kindOut_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        if (kindOut_ == TokenKind.ReserveBpt) {
            amountIn_ = _sharesForBptUp(req_.amountOut);
            _enforceMax(amountIn_, req_.maxAmountIn);
            _burnSharesForBpt(amountIn_, msg.sender);
            repo_.reserveBpt.transfer(req_.recipient, req_.amountOut);
            return amountIn_;
        }

        if (
            kindOut_ == TokenKind.VaultAShare || kindOut_ == TokenKind.VaultBShare
                || kindOut_ == TokenKind.PairVaultShare
        ) {
            return _redeemOutVaultShare(kindOut_, req_);
        }

        // Redeeming shares into a linked/common asset requires inverting a nonlinear leg swap after a
        // BPT-dependent proportional exit (and the best leg can change with the burn amount). That is
        // not closed-form; use exact-in `exchangeIn` for this direction.
        revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), req_.tokenOut);
    }

    /// @dev Vault-share payout exact-out: linear proportional-exit inversion, then pay exactly
    ///      `req.amountOut` of the requested leg and redeposit everything else.
    function _redeemOutVaultShare(TokenKind kindOut_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        uint256 payIndex_ = kindOut_ == TokenKind.VaultAShare ? 0 : (kindOut_ == TokenKind.VaultBShare ? 1 : 2);

        uint256 bptDue_ = _bptDueForVaultShareExactOut(payIndex_, req_.amountOut);
        amountIn_ = _sharesForBptUp(bptDue_);
        _enforceMax(amountIn_, req_.maxAmountIn);

        uint256 bptActual_ = _quoteBptForShares(amountIn_);
        _burnSharesForBpt(amountIn_, msg.sender);
        uint256[] memory amounts_ = _exitReserveProportional(bptActual_);

        IERC20[3] memory shares_ = [repo_.vaultAShare, repo_.vaultBShare, repo_.pairVaultShare];
        // Cap payout at exited amount (rounding can leave exit slightly under the exact-out quote).
        uint256 pay_ = amounts_[payIndex_];
        if (pay_ < req_.amountOut) {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(IERC20(address(this)), req_.tokenOut);
        }
        shares_[payIndex_].transfer(req_.recipient, req_.amountOut);

        // Redeposit every leftover leg in a single unbalanced add: the pay-leg leftover is dust that
        // would underflow Balancer's math as a lone add, so it rides along with the two full legs.
        // Quote→join, else refund remainder to recipient (never strand prepaid inventory).
        uint256 a_ = payIndex_ == 0 ? pay_ - req_.amountOut : amounts_[0];
        uint256 b_ = payIndex_ == 1 ? pay_ - req_.amountOut : amounts_[1];
        uint256 pair_ = payIndex_ == 2 ? pay_ - req_.amountOut : amounts_[2];
        _redepositAmounts(a_, b_, pair_, req_.recipient);
    }

    /* ====================================================================== */
    /*                            Swap exact-out                              */
    /* ====================================================================== */

    /// @dev Token↔token swap exact-out. common↔linked is a single hop; tokenA↔tokenB picks the
    ///      cheaper of the direct pair swap or the two-hop route via the common token.
    function _swapOut(TokenKind kindIn_, TokenKind kindOut_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();

        bool linkedPair_ = (kindIn_ == TokenKind.TokenA && kindOut_ == TokenKind.TokenB)
            || (kindIn_ == TokenKind.TokenB && kindOut_ == TokenKind.TokenA);
        bool commonSide_ =
            (kindIn_ == TokenKind.CommonToken && (kindOut_ == TokenKind.TokenA || kindOut_ == TokenKind.TokenB))
                || ((kindIn_ == TokenKind.TokenA || kindIn_ == TokenKind.TokenB) && kindOut_ == TokenKind.CommonToken);

        if (commonSide_) {
            TokenKind linkedKind_ = kindIn_ == TokenKind.CommonToken ? kindOut_ : kindIn_;
            IStandardExchangeProxy leg_ = linkedKind_ == TokenKind.TokenA ? repo_.vaultA : repo_.vaultB;
            amountIn_ = leg_.previewExchangeOut(req_.tokenIn, req_.tokenOut, req_.amountOut);
            _enforceMax(amountIn_, req_.maxAmountIn);
            _receiveOut(req_.tokenIn, amountIn_, req_.pretransferred);
            _legOut(leg_, req_.tokenIn, amountIn_, req_.tokenOut, req_.amountOut, req_.recipient, req_.deadline);
        } else if (linkedPair_) {
            amountIn_ = _swapOutLinked(kindIn_, req_);
        } else {
            revert DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute(req_.tokenIn, req_.tokenOut);
        }
    }

    function _swapOutLinked(TokenKind kindIn_, IStandardExchangeOut.OutArgs memory req_)
        private
        returns (uint256 amountIn_)
    {
        DualLiquidityLinkedCrossVersionUniswapVaultRepo.Storage storage repo_ = DualLiquidityLinkedCrossVersionUniswapVaultRepo._layoutStruct();
        (IStandardExchangeProxy vaultIn_, IStandardExchangeProxy vaultOut_) =
            kindIn_ == TokenKind.TokenA ? (repo_.vaultA, repo_.vaultB) : (repo_.vaultB, repo_.vaultA);

        uint256 directIn_ = repo_.pairVault.previewExchangeOut(req_.tokenIn, req_.tokenOut, req_.amountOut);
        uint256 commonNeeded_ = vaultOut_.previewExchangeOut(repo_.commonToken, req_.tokenOut, req_.amountOut);
        uint256 twoHopIn_ = vaultIn_.previewExchangeOut(req_.tokenIn, repo_.commonToken, commonNeeded_);

        if (directIn_ <= twoHopIn_) {
            amountIn_ = directIn_;
            _enforceMax(amountIn_, req_.maxAmountIn);
            _receiveOut(req_.tokenIn, amountIn_, req_.pretransferred);
            _legOut(
                repo_.pairVault, req_.tokenIn, amountIn_, req_.tokenOut, req_.amountOut, req_.recipient, req_.deadline
            );
        } else {
            amountIn_ = twoHopIn_;
            _enforceMax(amountIn_, req_.maxAmountIn);
            _receiveOut(req_.tokenIn, amountIn_, req_.pretransferred);
            _legOut(vaultIn_, req_.tokenIn, amountIn_, repo_.commonToken, commonNeeded_, address(this), req_.deadline);
            _legOut(
                vaultOut_,
                repo_.commonToken,
                commonNeeded_,
                req_.tokenOut,
                req_.amountOut,
                req_.recipient,
                req_.deadline
            );
        }
    }

    /* ====================================================================== */
    /*                          Shared helpers                                */
    /* ====================================================================== */

    /// @dev Approves and runs a leg exact-out, delivering exactly `amountOut_` to `recipient_`.
    function _legOut(
        IStandardExchangeProxy vault_,
        IERC20 tokenIn_,
        uint256 maxIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_,
        uint256 deadline_
    ) private {
        tokenIn_.approve(address(vault_), maxIn_);
        vault_.exchangeOut(tokenIn_, maxIn_, tokenOut_, amountOut_, recipient_, false, deadline_);
    }

    /// @dev Adds exactly `maxIn_` (the exact-out quote for `bptOut_`, rounded up) of `vaultShare_` into
    ///      the reserve, minting at least `bptOut_` BPT to this contract. Excess BPT accrues.
    function _joinOut(
        IERC20 vaultShare_,
        uint256 maxIn_,
        uint256 bptOut_,
        uint256 /* deadline_ */
    )
        private
    {
        _joinReserveOut(vaultShare_, maxIn_, bptOut_);
    }

    /// @dev Pulls exactly `amountIn_` from the caller, or refunds any pretransferred excess.
    function _receiveOut(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_) private {
        if (!pretransferred_) {
            tokenIn_.transferFrom(msg.sender, address(this), amountIn_);
        } else {
            uint256 held_ = tokenIn_.balanceOf(address(this));
            if (held_ > amountIn_) {
                tokenIn_.transfer(msg.sender, held_ - amountIn_);
            }
        }
    }

    function _enforceMax(uint256 amountIn_, uint256 maxAmountIn_) private pure {
        if (amountIn_ > maxAmountIn_) {
            revert IStandardExchangeErrors.MaxAmountExceeded(maxAmountIn_, amountIn_);
        }
    }
}

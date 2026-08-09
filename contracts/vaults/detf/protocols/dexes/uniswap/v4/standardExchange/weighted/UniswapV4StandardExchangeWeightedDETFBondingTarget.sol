// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {
    UniswapV4StandardExchangeWeightedDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFExchangeInTarget.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

/// @title UniswapV4StandardExchangeWeightedDETFBondingTarget
/// @notice First bond (all externals + capitalToken + refund), later single-external bonds,
///         mature-only sell/close, claim deposit/redeem, compound.
abstract contract UniswapV4StandardExchangeWeightedDETFBondingTarget is
    UniswapV4StandardExchangeWeightedDETFExchangeInTarget
{
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                                Bond                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice Multi-leg bond surface.
    function bond(
        IERC20[] calldata tokenIns_,
        uint256[] calldata amountsIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireNotDisabled();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
        if (tokenIns_.length != amountsIn_.length) revert Repo.ZeroAmount();

        if (Repo._layoutStruct().isReserveLive) {
            try this.realizeExpansionExternal() {} catch {}
            if (tokenIns_.length != 1) revert Repo.LaterBondSingleExternalOnly();
            return _bondSingle(
                tokenIns_[0], amountsIn_[0], lockDuration_, recipient_, pretransferred_, deadline_
            );
        }
        // First bond: all m externals required.
        return _firstBond(
            tokenIns_, amountsIn_, capitalToken_, lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

    /// @notice Single-token convenience bond.
    function bond(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireActive(deadline_, amountIn_);
        if (!Repo._layoutStruct().isReserveLive) {
            revert Repo.FirstBondRequiresAllExternalPairs();
        }
        try this.realizeExpansionExternal() {} catch {}
        return _bondSingle(tokenIn_, amountIn_, lockDuration_, recipient_, pretransferred_, deadline_);
    }

    function _firstBond(
        IERC20[] calldata tokenIns_,
        uint256[] calldata amountsIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!Repo._isPairToken(capitalToken_)) revert Repo.InvalidCapitalToken();

        // Settle each input to product-order pair notionals.
        uint256[] memory pairNatives_ = new uint256[](s.m);
        for (uint256 k; k < tokenIns_.length; ++k) {
            if (amountsIn_[k] == 0) continue;
            PairLegRating memory r_ =
                _settleToPairLeg(tokenIns_[k], amountsIn_[k], pretransferred_, deadline_);
            pairNatives_[r_.fundedProductIndex] += r_.pairNotionalNative;
        }
        // Require all externals funded.
        for (uint8 i; i < s.m; ++i) {
            if (pairNatives_[i] == 0) revert Repo.FirstBondRequiresAllExternalPairs();
        }

        // Size join DETF from min creation-rate DETF across legs; refund excess pair capital.
        uint256 detfForJoin_ = type(uint256).max;
        for (uint8 i; i < s.m; ++i) {
            uint256 detfFrom_ = Math.mulDiv(
                _toWad(pairNatives_[i], _decimalsOf(address(s.pairTokens[i]))),
                ONE_WAD,
                s.creationPairPerDetfWad[i]
            );
            if (detfFrom_ < detfForJoin_) detfForJoin_ = detfFrom_;
        }
        if (detfForJoin_ == 0 || detfForJoin_ == type(uint256).max) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        // Clamp pair amounts used; refund excess to caller.
        uint256[] memory usedPairs_ = new uint256[](s.m);
        for (uint8 i; i < s.m; ++i) {
            uint8 dec_ = _decimalsOf(address(s.pairTokens[i]));
            uint256 neededWad_ = Math.mulDiv(detfForJoin_, s.creationPairPerDetfWad[i], ONE_WAD);
            uint256 neededNative_ = _fromWadFloor(neededWad_, dec_);
            if (neededNative_ > pairNatives_[i]) neededNative_ = pairNatives_[i];
            usedPairs_[i] = neededNative_;
            uint256 excess_ = pairNatives_[i] - neededNative_;
            if (excess_ > 0) {
                s.pairTokens[i].safeTransfer(msg.sender, excess_);
            }
        }

        // Mint join DETF + multipath join; LP → bond NFT holder.
        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(usedPairs_, detfForJoin_);
        (shares_,) = _joinProportional(binding_, _bondLpHolder());
        if (shares_ == 0 || shares_ < HOOK_MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
        // Full book post-condition.
        if (!IHook(s.reserveHook).isFullBook()) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        Repo._setReserveLive();
        _mintBondFreeLegs(detfForJoin_, recipient_);

        // effectiveShares: DETF-value of all m funded externals at open mids × lock bonus (NFT applies bonus).
        uint256 effectiveBase_;
        for (uint8 i; i < s.m; ++i) {
            effectiveBase_ += _pairNotionalToDetfWad(i, usedPairs_[i]);
        }
        if (effectiveBase_ == 0) effectiveBase_ = shares_;

        tokenId_ = _openBondNft(shares_, effectiveBase_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, capitalToken_);
        Repo._addUserBondedLp(shares_);
        emit IUniswapV4StandardExchangeWeightedDETF.ReserveLive(tokenId_, shares_);
        _tryCompoundProtocolRewards();
    }

    function _bondSingle(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        // Live: no synthetic mint gate; exactly one external.
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        shares_ = _liveBondJoinSingle(r_);
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        _mintBondFreeLegs(_quoteDetfAgainstReserve(r_.fundedProductIndex, pairBoosted_), recipient_);

        uint256 rateWad_ = _pairNotionalToDetfWad(r_.fundedProductIndex, r_.pairNotionalNative);
        if (rateWad_ == 0) rateWad_ = shares_;
        tokenId_ = _openBondNft(shares_, rateWad_, lockDuration_, recipient_);
        address cap_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        Repo._setCapitalToken(tokenId_, cap_);
        Repo._addUserBondedLp(shares_);
        _tryCompoundProtocolRewards();
    }

    function _liveBondJoinSingle(PairLegRating memory r_) internal returns (uint256 lpOut_) {
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        uint256 detfForJoin_ = _quoteDetfAgainstReserve(r_.fundedProductIndex, pairBoosted_);
        if (detfForJoin_ == 0) {
            Repo.Storage storage s = Repo._layoutStruct();
            detfForJoin_ = Math.mulDiv(
                _toWad(r_.pairNotionalNative, _decimalsOf(address(s.pairTokens[r_.fundedProductIndex]))),
                ONE_WAD,
                s.creationPairPerDetfWad[r_.fundedProductIndex]
            );
        }
        address pair_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        address holder_ = _bondLpHolder();

        // Prefer multipath DETF+pair when possible; else sequential depositSingle.
        if (_isSingleAssetEligible()) {
            uint256 lpPair_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
            _mintDetf(address(this), detfForJoin_);
            uint256 lpDetf_ = detfForJoin_ > 0 ? _depositSingle(address(this), detfForJoin_, holder_) : 0;
            lpOut_ = lpPair_ + lpDetf_;
        } else {
            // Multipath: only DETF + this pair max (adds liquidity; does not remove other legs).
            Repo.Storage storage s2 = Repo._layoutStruct();
            uint256[] memory pairAmts_ = new uint256[](s2.m);
            pairAmts_[r_.fundedProductIndex] = r_.pairNotionalNative;
            _mintDetf(address(this), detfForJoin_);
            uint256[] memory binding_ = _packBinding(pairAmts_, detfForJoin_);
            lpOut_ = _joinUnbalanced(binding_, holder_);
        }
    }

    function _openBondNft(uint256 lpOut_, uint256 effectiveBase_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        uint256 lock_ = _effectiveLockDuration(lockDuration_);
        tokenId_ = DETFBondLifecycleLib._createBondPositionWithEffectiveBase(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
            lpOut_,
            effectiveBase_,
            lock_,
            recipient_
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                         Mature-only sell / close                       */
    /* ---------------------------------------------------------------------- */

    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        _requireMature(tokenId_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        try this.realizeExpansionExternal() {} catch {}

        principalShares_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (principalShares_ > 0 && address(s.rebasingClaimToken) != address(0)) {
            address claim_ = address(s.rebasingClaimToken);
            IERC20 lp_ = IERC20(s.reserveHook);
            uint256 bondBal_ = lp_.balanceOf(address(s.bondNftVault));
            uint256 move_ = principalShares_ < bondBal_ ? principalShares_ : bondBal_;
            if (move_ > 0) {
                s.bondNftVault.transferHeldToken(lp_, claim_, move_);
            }
        }

        if (address(s.rebasingClaimToken) == address(0)) {
            principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
            );
        } else {
            (principalShares_,) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
                s.rebasingClaimToken,
                tokenId_,
                msg.sender,
                recipient_
            );
        }
        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(principalShares_);
        _tryCompoundProtocolRewards();
    }

    function closeBondMature(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        _requireMature(tokenId_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();

        try this.realizeExpansionExternal() {} catch {}

        uint256 lp_ = s.bondNftVault.originalSharesOf(tokenId_);
        address capital_ = s.capitalTokenOf[tokenId_];
        if (capital_ == address(0) || !Repo._isPairToken(capital_)) {
            revert Repo.InvalidCapitalToken();
        }

        _pullBondLp(lp_);
        DETFBondLifecycleLib._sellPositionToDetfNft(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
        );

        // Prefer single-asset exit to capitalToken when full-book (avoids thin-book MaxInvariantRatio
        // on multipath remove + DETF redeposit after sole-bond close). Normative multipath used when
        // single-asset path reverts.
        amountOut_ = _closeLpToCapitalToken(lp_, capital_);
        if (amountOut_ > 0) IERC20(capital_).safeTransfer(recipient_, amountOut_);

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lp_);
        _tryCompoundProtocolRewards();
    }

    /// @dev Settle bond LP → single capitalToken (single-asset exit preferred; multipath fallback).
    function _closeLpToCapitalToken(uint256 lp_, address capital_) internal returns (uint256 amountOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        IERC20(s.reserveHook).forceApprove(s.reserveHook, lp_);
        if (hook_.isFullBook()) {
            try hook_.exitSingleAssetExactBptIn(capital_, lp_, address(this), 0, block.timestamp + 1) returns (
                uint256 out_
            ) {
                return out_;
            } catch {
                try hook_.withdrawSingle(capital_, lp_, address(this), 0, block.timestamp + 1) returns (
                    uint256 out2_
                ) {
                    return out2_;
                } catch {}
            }
        }
        // Multipath fallback: prop exit → redeposit DETF (best-effort) → consolidate → capitalToken.
        uint256[] memory mins_ = new uint256[](s.n);
        uint256[] memory residual_ = hook_.exitProportional(lp_, address(this), mins_, block.timestamp + 1);
        (uint256 aDetf_, uint256[] memory pairAmts_) = _unpackBinding(residual_);
        uint256[] memory dust_ = new uint256[](pairAmts_.length);
        for (uint256 i; i < pairAmts_.length; ++i) {
            uint256 d_ = pairAmts_[i] / 100;
            if (d_ == 0 && pairAmts_[i] > 0) d_ = 1;
            if (d_ > pairAmts_[i]) d_ = pairAmts_[i];
            dust_[i] = d_;
            pairAmts_[i] -= d_;
        }
        if (aDetf_ > 0) {
            try this.redepositDetfExternal(aDetf_, dust_) {}
            catch {
                for (uint256 i; i < pairAmts_.length; ++i) {
                    pairAmts_[i] += dust_[i];
                }
                // Best-effort: leave DETF on diamond if sell also fails (do not brick close).
                try this.swapDetfToCapitalExternal(aDetf_, capital_) returns (uint256 sold_) {
                    amountOut_ += sold_;
                } catch {}
            }
        }
        amountOut_ += _consolidateToPair(capital_, pairAmts_);
    }

    /// @dev External self-call for redeposit (fresh stack + try/catch from close path).
    function redepositDetfExternal(uint256 amountNative_, uint256[] calldata pairDust_) external {
        if (msg.sender != address(this)) revert NotSelf();
        uint256[] memory dust_ = pairDust_;
        _redepositDetfSelfLegWithPairDust(amountNative_, dust_);
    }

    function swapDetfToCapitalExternal(uint256 detfAmt_, address capital_)
        external
        returns (uint256 out_)
    {
        if (msg.sender != address(this)) revert NotSelf();
        out_ = _weightedExactIn(address(this), capital_, detfAmt_, address(this));
    }

    function claimRewards(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rewards_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        // Realize on fresh stack to avoid n-leg FD StackOverflow after deep bond paths.
        try this.realizeExpansionExternal() {} catch {}
        // L-REW-1: owner-only; non-owner reverts (no soft-success).
        address holder_ = s.bondNftVault.ownerOf(tokenId_);
        if (msg.sender != holder_) {
            revert Repo.NotAuthorized(msg.sender);
        }
        // L-REW-2/3: execute claim; return 0 only when allowed and no rewards.
        rewards_ = s.bondNftVault.claimRewards(tokenId_, recipient_);
        _tryCompoundProtocolRewards();
    }

    /// @dev External self-call entry for expansion realize (stack reset).
    function realizeExpansionExternal() external {
        if (msg.sender != address(this)) revert NotSelf();
        _realizeExpansionIfNeeded();
    }

    /* ---------------------------------------------------------------------- */
    /*                                Claim                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Direct claim deposit. Reverts if not single-asset eligible (unlike compound skip).
    /// @dev Settle → depositSingle → LP on protocol holder → mintFromNFTSale(lpShares).
    function depositClaim(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimOut_) {
        _requireReserveLive();
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        _requireSingleAssetEligible(); // REVERT — not compound skip

        address holder_ = _protocolLpHolder();
        uint256 lpMinted_;
        if (address(tokenIn_) == address(this)) {
            uint256 pulled_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            lpMinted_ = _depositSingle(address(this), pulled_, holder_);
        } else {
            PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
            address pair_ = address(s.pairTokens[r_.fundedProductIndex]);
            lpMinted_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
        }
        if (lpMinted_ == 0) revert Repo.ZeroAmount();

        // LP is already on claim holder when holder_ == rebasingClaimToken.
        claimOut_ = s.rebasingClaimToken.mintFromNFTSale(lpMinted_, recipient_);
        if (claimOut_ < minClaimOut_) revert Repo.SlippageExceeded(minClaimOut_, claimOut_);
    }

    function redeemClaim(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenOut_) == address(this)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }

        uint256 lpOut_ = _burnClaimPullProtocolLp(claimAmount_);
        uint256[] memory binding_ = _exitProportional(lpOut_, address(this));
        (uint256 aDetf_, uint256[] memory pairAmts_) = _unpackBinding(binding_);
        _redepositDetfSelfLeg(aDetf_);
        amountOut_ = _settleClaimResidual(tokenOut_, pairAmts_, recipient_);

        if (amountOut_ < minOut_) revert Repo.SlippageExceeded(minOut_, amountOut_);
    }

    function _burnClaimPullProtocolLp(uint256 claimAmount_) private returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();

        uint256 principalLp_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (principalLp_ == 0) revert Repo.ZeroAmount();

        uint256 protocolLp_ = _protocolLp();
        lpOut_ = principalLp_ < protocolLp_ ? principalLp_ : protocolLp_;
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();
        _pullProtocolLp(lpOut_);
    }

    function _settleClaimResidual(IERC20 tokenOut_, uint256[] memory pairAmts_, address recipient_)
        private
        returns (uint256 amountOut_)
    {
        address tout = address(tokenOut_);
        if (Repo._isPairToken(tout)) {
            amountOut_ = _consolidateToPair(tout, pairAmts_);
            if (amountOut_ > 0) tokenOut_.safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }
        if (_isShareOrSeTokenOut(tokenOut_)) {
            address mid_ = _pairForShareOut(tokenOut_);
            uint256 midAmt_ = _consolidateToPair(mid_, pairAmts_);
            return _seWrap(mid_, midAmt_, tokenOut_, recipient_);
        }
        revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
    }

    function claimLiquidity(uint256 lpAmount_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        address bond_ = address(s.bondNftVault);
        address claim_ = address(s.rebasingClaimToken);
        if (msg.sender != bond_ && msg.sender != claim_ && msg.sender != address(this)) {
            revert Repo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert Repo.ZeroAmount();
        if (msg.sender == bond_) {
            _pullBondLp(lpAmount_);
        } else {
            _ensureProtocolLpOnDiamond(lpAmount_);
        }
        uint256[] memory binding_ = _exitProportional(lpAmount_, address(this));
        (uint256 aDetf_, uint256[] memory pairAmts_) = _unpackBinding(binding_);
        _redepositDetfSelfLeg(aDetf_);
        // Default claimLiquidity payout: first pair token (no whole-DETF rateAsset).
        address pay_ = address(s.pairTokens[0]);
        amountOut_ = _consolidateToPair(pay_, pairAmts_);
        if (amountOut_ > 0) {
            IERC20(pay_).safeTransfer(recipient_ == address(0) ? msg.sender : recipient_, amountOut_);
        }
    }

    function compoundProtocolRewards()
        public
        virtual
        nonReentrant
        returns (uint256 detfIn_, uint256 lpOut_)
    {
        return _tryCompoundProtocolRewards();
    }
}

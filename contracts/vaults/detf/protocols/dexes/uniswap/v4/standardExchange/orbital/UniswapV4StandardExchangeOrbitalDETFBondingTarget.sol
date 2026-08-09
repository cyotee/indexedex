// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as HookRepo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFExchangeInTarget
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFExchangeInTarget.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFBondingTarget
/// @notice Dual-leg first bond, live single/dual bonds, mature-only sell/close, claim, compound.
/// @dev Info getters live on UniswapV4StandardExchangeOrbitalDETFInfoTarget (size split).
abstract contract UniswapV4StandardExchangeOrbitalDETFBondingTarget is
    UniswapV4StandardExchangeOrbitalDETFExchangeInTarget
{
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                                Bond                                    */
    /* ---------------------------------------------------------------------- */

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
    function bond(
        IERC20 tokenIn0_,
        uint256 amountIn0_,
        IERC20 tokenIn1_,
        uint256 amountIn1_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireNotDisabled();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);

        if (Repo._layoutStruct().isReserveLive) {
            _realizeExpansionIfNeeded();
        }

        bool dual_ = address(tokenIn1_) != address(0) && amountIn1_ > 0;
        if (!dual_) {
            if (amountIn0_ == 0) revert Repo.ZeroAmount();
            return _bondSingle(tokenIn0_, amountIn0_, lockDuration_, recipient_, pretransferred_, deadline_);
        }
        if (amountIn0_ == 0 || amountIn1_ == 0) revert Repo.ZeroAmount();
        return _bondDual(
            tokenIn0_, amountIn0_, tokenIn1_, amountIn1_, lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
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
        if (Repo._layoutStruct().isReserveLive) {
            _realizeExpansionIfNeeded();
        }
        return _bondSingle(tokenIn_, amountIn_, lockDuration_, recipient_, pretransferred_, deadline_);
    }

    function _bondSingle(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        if (!Repo._layoutStruct().isReserveLive) {
            // First bond requires both pairs.
            revert Repo.FirstBondRequiresBothPairs();
        }
        // Live: no synthetic mint gate; single-leg OK.
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        shares_ = _liveBondJoinSingle(r_);
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        _mintBondFreeLegs(_quoteDetfAgainstReserve(r_.fundedPairLeg, pairBoosted_), recipient_);

        // PRD Q18: effectiveShares base = open-time sphere mid rateAsset value; NFT applies lock bonus.
        uint256 rateWad_ = _pairNotionalToRateAssetWad(r_.fundedPairLeg, r_.pairNotionalNative);
        if (rateWad_ == 0) rateWad_ = shares_; // fallback if mid quote is zero pre-liquidity
        tokenId_ = _openBondNft(shares_, rateWad_, lockDuration_, recipient_);
        address cap_ = r_.fundedPairLeg == 0
            ? address(Repo._layoutStruct().pairToken0)
            : address(Repo._layoutStruct().pairToken1);
        Repo._setCapital(tokenId_, IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Single, cap_, address(0));
        Repo._addUserBondedLp(shares_);
        _tryCompoundProtocolRewards();
    }

    function _bondDual(
        IERC20 tokenIn0_,
        uint256 amountIn0_,
        IERC20 tokenIn1_,
        uint256 amountIn1_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        PairLegRating memory r0_ = _settleToPairLeg(tokenIn0_, amountIn0_, pretransferred_, deadline_);
        PairLegRating memory r1_ = _settleToPairLeg(tokenIn1_, amountIn1_, pretransferred_, deadline_);
        // Ensure legs map to distinct pairs.
        if (r0_.fundedPairLeg == r1_.fundedPairLeg) revert Repo.InvalidRoute(tokenIn0_, tokenIn1_);

        uint256 p0Native_ = r0_.fundedPairLeg == 0 ? r0_.pairNotionalNative : r1_.pairNotionalNative;
        uint256 p1Native_ = r0_.fundedPairLeg == 1 ? r0_.pairNotionalNative : r1_.pairNotionalNative;

        if (!Repo._layoutStruct().isReserveLive) {
            shares_ = _firstBondJoin(p0Native_, p1Native_);
            Repo._setReserveLive();
            // Free legs from join-sized gross (min creation-rate DETF).
            uint256 detfFrom0_ =
                Math.mulDiv(_toWad(p0Native_, _pair0Decimals()), ONE_WAD, Repo._layoutStruct().creationPair0PerDetfWad);
            uint256 detfFrom1_ =
                Math.mulDiv(_toWad(p1Native_, _pair1Decimals()), ONE_WAD, Repo._layoutStruct().creationPair1PerDetfWad);
            uint256 joinGross_ = detfFrom0_ < detfFrom1_ ? detfFrom0_ : detfFrom1_;
            _mintBondFreeLegs(joinGross_, recipient_);
            emit IUniswapV4StandardExchangeOrbitalDETF.ReserveLive(0, shares_);
        } else {
            shares_ = _liveBondJoinDual(p0Native_, p1Native_);
            uint256 b0_ = Math.mulDiv(p0Native_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
            uint256 b1_ = Math.mulDiv(p1Native_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
            uint256 gross_ =
                _quoteDetfAgainstReserve(0, b0_) + _quoteDetfAgainstReserve(1, b1_);
            _mintBondFreeLegs(gross_, recipient_);
        }

        // Dual: sum open-time sphere mids of both external legs → rateAsset WAD (DETF join excluded).
        uint256 rateWad_ = _pairNotionalToRateAssetWad(0, p0Native_) + _pairNotionalToRateAssetWad(1, p1Native_);
        if (rateWad_ == 0) rateWad_ = shares_;
        tokenId_ = _openBondNft(shares_, rateWad_, lockDuration_, recipient_);
        Repo._setCapital(
            tokenId_,
            IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Dual,
            address(Repo._layoutStruct().pairToken0),
            address(Repo._layoutStruct().pairToken1)
        );
        Repo._addUserBondedLp(shares_);
        _tryCompoundProtocolRewards();
    }

    function _firstBondJoin(uint256 p0Native_, uint256 p1Native_) internal returns (uint256 lpOut_) {
        if (p0Native_ == 0 || p1Native_ == 0) revert Repo.FirstBondRequiresBothPairs();
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 detfFrom0_ = Math.mulDiv(_toWad(p0Native_, _pair0Decimals()), ONE_WAD, s.creationPair0PerDetfWad);
        uint256 detfFrom1_ = Math.mulDiv(_toWad(p1Native_, _pair1Decimals()), ONE_WAD, s.creationPair1PerDetfWad);
        uint256 detfForJoin_ = detfFrom0_ < detfFrom1_ ? detfFrom0_ : detfFrom1_;
        if (detfForJoin_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();

        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _addLiquidity(p0Native_, p1Native_, detfForJoin_, _bondLpHolder());
        if (lpOut_ == 0 || lpOut_ < HookRepo.MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
    }

    function _liveBondJoinSingle(PairLegRating memory r_) internal returns (uint256 lpOut_) {
        // Full book multipath requires three non-zero maxes (hook FullBookRequiresThreeLegs).
        // Single-leg capital: depositSingle(pair) + depositSingle(DETF join) when zap-eligible.
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        uint256 detfForJoin_ = _quoteDetfAgainstReserve(r_.fundedPairLeg, pairBoosted_);
        if (detfForJoin_ == 0) {
            uint256 creation_ = r_.fundedPairLeg == 0
                ? Repo._layoutStruct().creationPair0PerDetfWad
                : Repo._layoutStruct().creationPair1PerDetfWad;
            uint8 dec_ = r_.fundedPairLeg == 0 ? _pair0Decimals() : _pair1Decimals();
            detfForJoin_ = Math.mulDiv(_toWad(r_.pairNotionalNative, dec_), ONE_WAD, creation_);
        }
        address pair_ = r_.fundedPairLeg == 0
            ? address(Repo._layoutStruct().pairToken0)
            : address(Repo._layoutStruct().pairToken1);
        address holder_ = _bondLpHolder();
        uint256 lpPair_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
        _mintDetf(address(this), detfForJoin_);
        uint256 lpDetf_ = detfForJoin_ > 0 ? _depositSingle(address(this), detfForJoin_, holder_) : 0;
        lpOut_ = lpPair_ + lpDetf_;
    }

    function _liveBondJoinDual(uint256 p0Native_, uint256 p1Native_) internal returns (uint256 lpOut_) {
        uint256 b0_ = Math.mulDiv(p0Native_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        uint256 b1_ = Math.mulDiv(p1Native_, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        // Join DETF sized from sum of leg quotes (simplified multipath join).
        uint256 detfForJoin_ = _quoteDetfAgainstReserve(0, b0_) + _quoteDetfAgainstReserve(1, b1_);
        if (detfForJoin_ == 0) revert Repo.ZeroAmount();
        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _addLiquidity(p0Native_, p1Native_, detfForJoin_, _bondLpHolder());
    }

    /// @param lpOut_ Fungible hook LP principal (originalShares).
    /// @param effectiveBase_ RateAsset open-time mid WAD before lock bonus (PRD Q18).
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

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        _requireMature(tokenId_); // DETF-wide mature-only standard
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _realizeExpansionIfNeeded();

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

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
    function closeBondMature(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amount0_, uint256 amount1_)
    {
        _requireMature(tokenId_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();

        _realizeExpansionIfNeeded();

        uint256 lp_ = s.bondNftVault.originalSharesOf(tokenId_);
        Repo.CapitalMeta memory cap_ = s.capitalOf[tokenId_];

        // Pull LP first (physical), then retire NFT ledger (sell harvests free DETF rewards to recipient).
        _pullBondLp(lp_);
        DETFBondLifecycleLib._sellPositionToDetfNft(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
        );

        (uint256 aDetf_, uint256 a0_, uint256 a1_) = _removeLiquidity(lp_, address(this));
        // When sole redeemable LP is closed, book may be MIN-only (not zap-eligible). Co-join
        // tiny pair dust with DETF so multipath full-book redeposit can succeed; pay residual after.
        uint256 dust0_ = a0_ / 1000;
        uint256 dust1_ = a1_ / 1000;
        if (dust0_ == 0 && a0_ > 0) dust0_ = 1;
        if (dust1_ == 0 && a1_ > 0) dust1_ = 1;
        // Cap dust so user still receives the bulk residual composition.
        if (dust0_ > a0_) dust0_ = a0_;
        if (dust1_ > a1_) dust1_ = a1_;
        _redepositDetfSelfLegWithPairDust(aDetf_, dust0_, dust1_);
        a0_ -= dust0_;
        a1_ -= dust1_;

        if (cap_.mode == IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Single) {
            address capital_ = cap_.capitalToken0;
            uint256 out_ = _consolidateTo(capital_, a0_, a1_);
            if (out_ > 0) IERC20(capital_).safeTransfer(recipient_, out_);
            if (capital_ == address(s.pairToken0)) amount0_ = out_;
            else amount1_ = out_;
        } else {
            // Dual: residual composition as-is (after redeposit dust).
            if (a0_ > 0) s.pairToken0.safeTransfer(recipient_, a0_);
            if (a1_ > 0) s.pairToken1.safeTransfer(recipient_, a1_);
            amount0_ = a0_;
            amount1_ = a1_;
        }

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lp_);
        _tryCompoundProtocolRewards();
    }

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
    function claimRewards(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rewards_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _realizeExpansionIfNeeded();
        // L-REW-1: owner-only; non-owner reverts (no soft-success).
        address holder_ = s.bondNftVault.ownerOf(tokenId_);
        if (msg.sender != holder_) {
            revert Repo.NotAuthorized(msg.sender);
        }
        // L-REW-2/3: execute claim; return 0 only when allowed and no rewards.
        rewards_ = s.bondNftVault.claimRewards(tokenId_, recipient_);
        _tryCompoundProtocolRewards();
    }

    /* ---------------------------------------------------------------------- */
    /*                                Claim                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev Pair residual after remove + DETF redeposit (packed to free redeemClaim stack).
    struct ClaimResidual {
        uint256 a0;
        uint256 a1;
    }

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
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

        uint256 lpOut_ = _burnClaimPullProtocolLp(claimAmount_);
        ClaimResidual memory res = _removeAndRedepositClaimLp(lpOut_);
        amountOut_ = _settleClaimResidual(tokenOut_, res, recipient_);

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

    function _removeAndRedepositClaimLp(uint256 lpOut_) private returns (ClaimResidual memory res) {
        uint256 aDetf_;
        (aDetf_, res.a0, res.a1) = _removeLiquidity(lpOut_, address(this));
        _redepositDetfSelfLeg(aDetf_);
    }

    function _settleClaimResidual(IERC20 tokenOut_, ClaimResidual memory res, address recipient_)
        private
        returns (uint256 amountOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        address tout = address(tokenOut_);
        if (tout == address(s.pairToken0) || tout == address(s.pairToken1)) {
            amountOut_ = _consolidateTo(tout, res.a0, res.a1);
            if (amountOut_ > 0) tokenOut_.safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }
        if (_isShareOrSeTokenOut(tokenOut_)) {
            address mid_ = _pairForShareOut(tokenOut_);
            uint256 midAmt_ = _consolidateTo(mid_, res.a0, res.a1);
            return _seWrap(mid_, midAmt_, tokenOut_, recipient_);
        }
        if (tout == address(s.rateAsset)) {
            amountOut_ = _consolidateTo(tout, res.a0, res.a1);
            if (amountOut_ > 0) tokenOut_.safeTransfer(recipient_, amountOut_);
            return amountOut_;
        }
        revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
    }

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
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
        (uint256 aDetf_, uint256 a0_, uint256 a1_) = _removeLiquidity(lpAmount_, address(this));
        _redepositDetfSelfLeg(aDetf_);
        address rate_ = address(s.rateAsset);
        amountOut_ = _consolidateTo(rate_, a0_, a1_);
        if (amountOut_ > 0) {
            IERC20(rate_).safeTransfer(recipient_ == address(0) ? msg.sender : recipient_, amountOut_);
        }
    }

    /// @notice IUniswapV4StandardExchangeOrbitalDETF surface
    function compoundProtocolRewards()
        public
        virtual
        nonReentrant
        returns (uint256 detfIn_, uint256 lpOut_)
    {
        // Public compound IS a realize path; skip without revert when not zap-eligible.
        return _tryCompoundProtocolRewards();
    }
}

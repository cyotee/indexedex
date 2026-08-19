// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as HookRepo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFCommon
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

/// @title UniswapV4StandardExchangeOrbitalDETFBondingTarget
/// @notice Dual-leg first bond, live single/dual bonds, mature-only sell/close, claim, compound.
/// @dev Info getters live on UniswapV4StandardExchangeOrbitalDETFInfoTarget (size split).
/// @dev Option 1e: sibling of Exchange Targets under Common (not Bonding→In→Out tower).
abstract contract UniswapV4StandardExchangeOrbitalDETFBondingTarget is UniswapV4StandardExchangeOrbitalDETFCommon {

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
        _requireNotDisabled();
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
        uint256 joinG_ = _quoteBondJoinDetf(r_.fundedPairLeg, r_.pairNotionalNative);
        MintSplit memory split_ = _splitBondDetf(joinG_);
        shares_ = _liveBondJoinSingleUnboosted(r_, joinG_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        address cap_ = r_.fundedPairLeg == 0
            ? address(Repo._layoutStruct().pairToken0)
            : address(Repo._layoutStruct().pairToken1);
        Repo._setCapital(tokenId_, IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Single, cap_, address(0));
        Repo._addUserBondedLp(shares_);
        _topUpFeeCreatorShares();
        _creditBondPot(split_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
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
        if (!Repo._layoutStruct().isReserveLive) {
            _rejectPretransferredFirstBond(pretransferred_, amountIn0_ + amountIn1_);
        }
        PairLegRating memory r0_ = _settleToPairLeg(tokenIn0_, amountIn0_, pretransferred_, deadline_);
        PairLegRating memory r1_ = _settleToPairLeg(tokenIn1_, amountIn1_, pretransferred_, deadline_);
        // Ensure legs map to distinct pairs.
        if (r0_.fundedPairLeg == r1_.fundedPairLeg) revert Repo.InvalidRoute(tokenIn0_, tokenIn1_);

        uint256 p0Native_ = r0_.fundedPairLeg == 0 ? r0_.pairNotionalNative : r1_.pairNotionalNative;
        uint256 p1Native_ = r0_.fundedPairLeg == 1 ? r0_.pairNotionalNative : r1_.pairNotionalNative;

        uint256 joinG_;
        if (!Repo._layoutStruct().isReserveLive) {
            joinG_ = _firstBondJoinDetf(p0Native_, p1Native_);
            MintSplit memory splitFirst_ = _splitBondDetf(joinG_);
            shares_ = _firstBondJoin(p0Native_, p1Native_, joinG_);
            if (splitFirst_.userDetf > 0) _mintDetf(recipient_, splitFirst_.userDetf);
            Repo._setReserveLive();
            emit IUniswapV4StandardExchangeOrbitalDETF.ReserveLive(0, shares_);
            tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
            Repo._setCapital(
                tokenId_,
                IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Dual,
                address(Repo._layoutStruct().pairToken0),
                address(Repo._layoutStruct().pairToken1)
            );
            Repo._addUserBondedLp(shares_);
            _topUpFeeCreatorShares();
            _creditBondPot(splitFirst_);
            _tryCompoundProtocolRewards();
            _syncAllExpectedHoldReserves();
            return (tokenId_, shares_);
        }

        joinG_ = _quoteBondJoinDetf(0, p0Native_) + _quoteBondJoinDetf(1, p1Native_);
        MintSplit memory split_ = _splitBondDetf(joinG_);
        shares_ = _liveBondJoinDualUnboosted(p0Native_, p1Native_, joinG_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
        tokenId_ = _openBondNft(shares_, lockDuration_, recipient_);
        Repo._setCapital(
            tokenId_,
            IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Dual,
            address(Repo._layoutStruct().pairToken0),
            address(Repo._layoutStruct().pairToken1)
        );
        Repo._addUserBondedLp(shares_);
        _topUpFeeCreatorShares();
        _creditBondPot(split_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _firstBondJoinDetf(uint256 p0Native_, uint256 p1Native_) internal view returns (uint256 detfForJoin_) {
        if (p0Native_ == 0 || p1Native_ == 0) revert Repo.FirstBondRequiresBothPairs();
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 detfFrom0_ = Math.mulDiv(_toWad(p0Native_, _pair0Decimals()), ONE_WAD, s.creationPair0PerDetfWad);
        uint256 detfFrom1_ = Math.mulDiv(_toWad(p1Native_, _pair1Decimals()), ONE_WAD, s.creationPair1PerDetfWad);
        detfForJoin_ = detfFrom0_ < detfFrom1_ ? detfFrom0_ : detfFrom1_;
        if (detfForJoin_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();
    }

    function _firstBondJoin(uint256 p0Native_, uint256 p1Native_, uint256 detfForJoin_)
        internal
        returns (uint256 lpOut_)
    {
        _requireReserveWired();
        if (p0Native_ == 0 || p1Native_ == 0) revert Repo.FirstBondRequiresBothPairs();
        if (detfForJoin_ == 0) revert Repo.FirstBondBelowMinimumLiquidity();
        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _addLiquidity(p0Native_, p1Native_, detfForJoin_, _bondLpHolder());
        if (lpOut_ == 0 || lpOut_ < HookRepo.MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
    }

    function _liveBondJoinSingleUnboosted(PairLegRating memory r_, uint256 detfForJoin_)
        internal
        returns (uint256 lpOut_)
    {
        address pair_ = r_.fundedPairLeg == 0
            ? address(Repo._layoutStruct().pairToken0)
            : address(Repo._layoutStruct().pairToken1);
        address holder_ = _bondLpHolder();
        uint256 lpPair_ = _depositSingle(pair_, r_.pairNotionalNative, holder_);
        if (detfForJoin_ > 0) _mintDetf(address(this), detfForJoin_);
        uint256 lpDetf_ = detfForJoin_ > 0 ? _depositSingle(address(this), detfForJoin_, holder_) : 0;
        lpOut_ = lpPair_ + lpDetf_;
    }

    function _liveBondJoinDualUnboosted(uint256 p0Native_, uint256 p1Native_, uint256 detfForJoin_)
        internal
        returns (uint256 lpOut_)
    {
        if (detfForJoin_ == 0) revert Repo.ZeroAmount();
        _mintDetf(address(this), detfForJoin_);
        lpOut_ = _addLiquidity(p0Native_, p1Native_, detfForJoin_, _bondLpHolder());
    }

    /// @dev D10: 4626 originalShares = LP; lock bonus applies only to effectiveShares.
    function _openBondNft(uint256 lpOut_, uint256 lockDuration_, address recipient_)
        private
        returns (uint256 tokenId_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return 0;
        uint256 lock_ = _effectiveLockDuration(lockDuration_);
        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), lpOut_, lock_, recipient_
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
        _requireMature(tokenId_);
        _requireNotStandingRewardNft(tokenId_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _realizeExpansionIfNeeded();

        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        DETFBondLifecycleLib._sellPositionToDetfNft(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
        );
        principalShares_ = s.rebasingClaimToken.mintFromNFTSale(assets_, protocolBefore_, recipient_);
        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(assets_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @notice D25+L2: proportional withdraw, burn DETF self-leg, pay remaining pairs.
    function closeBondMature(
        uint256 tokenId_,
        uint256[] calldata minAmountsOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256[] memory amountsOut_) {
        _requireMature(tokenId_);
        _requireNotStandingRewardNft(tokenId_);
        _requireActive(deadline_, 1);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (minAmountsOut_.length != 3) revert Repo.InvalidRoute(IERC20(address(0)), IERC20(address(0)));
        if (minAmountsOut_[0] != 0) revert Repo.InvalidRoute(IERC20(address(this)), IERC20(address(0)));

        Repo.Storage storage s = Repo._layoutStruct();
        _realizeExpansionIfNeeded();

        uint256 lpOut_ = s.bondNftVault.convertToAssets(s.bondNftVault.originalSharesOf(tokenId_));
        if (lpOut_ == 0) revert Repo.ZeroAmount();
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);
        _pullBondLp(lpOut_);
        (uint256 aDetf_, uint256 a0_, uint256 a1_) = _removeLiquidity(lpOut_, address(this));
        if (aDetf_ > 0) _burnDetf(address(this), aDetf_);
        if (a0_ < minAmountsOut_[1] || a1_ < minAmountsOut_[2]) {
            revert Repo.SlippageExceeded(minAmountsOut_[1] + minAmountsOut_[2], a0_ + a1_);
        }
        if (a0_ > 0) s.pairToken0.safeTransfer(recipient_, a0_);
        if (a1_ > 0) s.pairToken1.safeTransfer(recipient_, a1_);

        amountsOut_ = new uint256[](3);
        amountsOut_[1] = a0_;
        amountsOut_[2] = a1_;

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lpOut_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function previewCloseBondMature(uint256 tokenId_)
        external
        view
        returns (uint256[] memory amountsOut_)
    {
        amountsOut_ = new uint256[](3);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return amountsOut_;
        uint256 orig_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (orig_ == 0) return amountsOut_;
        uint256 lpOut_ = s.bondNftVault.convertToAssets(orig_);
        if (lpOut_ == 0) return amountsOut_;
        (uint256 a0_, uint256 a1_, uint256 a2_) = IHook(s.reserveHook).previewRemoveLiquidity(lpOut_);
        (, uint256 p0_, uint256 p1_) = _unpackBinding(a0_, a1_, a2_);
        amountsOut_[1] = p0_;
        amountsOut_[2] = p1_;
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
        _syncAllExpectedHoldReserves();
    }

    /* ---------------------------------------------------------------------- */
    /*                                Claim                                   */
    /* ---------------------------------------------------------------------- */

    /// @notice Direct claim deposit. Reverts if not zap-eligible (unlike compound skip).
    function depositClaim(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimOut_) {
        _requireReserveLive();
        _requireNotDisabled();
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        _requireZapEligible();

        if (address(tokenIn_) == address(this)) {
            return _buyClaim(amountIn_, minClaimOut_, recipient_, pretransferred_, deadline_);
        }
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        address pair_ = r_.fundedPairLeg == 0 ? address(s.pairToken0) : address(s.pairToken1);
        uint256 lpMinted_ = _depositSingle(pair_, r_.pairNotionalNative, _bondLpHolder());
        if (lpMinted_ == 0) revert Repo.ZeroAmount();
        uint256 protocolBefore_ = _protocolOriginalShares();
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpMinted_);
        claimOut_ = s.rebasingClaimToken.mintFromNFTSale(lpMinted_, protocolBefore_, recipient_);
        if (claimOut_ < minClaimOut_) revert Repo.SlippageExceeded(minClaimOut_, claimOut_);
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function buyClaim(
        uint256 detfAmount_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimMinted_) {
        return _buyClaim(detfAmount_, minClaimOut_, recipient_, pretransferred_, deadline_);
    }

    function previewBuyClaim(uint256 detfAmount_) external view returns (uint256 claimMinted_) {
        if (detfAmount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0) || !s.isReserveLive) return 0;
        try IHook(s.reserveHook).previewDepositSingle(address(this), detfAmount_) returns (uint256 lp_) {
            uint256 proto_ = _protocolOriginalShares();
            return proto_ == 0 ? lp_ : (lp_ * s.rebasingClaimToken.totalShares()) / proto_;
        } catch {
            return 0;
        }
    }

    function _buyClaim(
        uint256 detfAmount_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 claimMinted_) {
        _requireReserveLive();
        _requireNotDisabled();
        _requireActive(deadline_, detfAmount_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _requireZapEligible();

        uint256 pulled_ = _pullToken(IERC20(address(this)), detfAmount_, pretransferred_);
        uint256 lpMinted_ = _depositSingle(address(this), pulled_, _bondLpHolder());
        if (lpMinted_ == 0) revert Repo.ZeroAmount();
        uint256 protocolBefore_ = _protocolOriginalShares();
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpMinted_);
        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(lpMinted_, protocolBefore_, recipient_);
        if (claimMinted_ < minClaimOut_) revert Repo.SlippageExceeded(minClaimOut_, claimMinted_);
        _topUpFeeCreatorShares();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @notice D15: redeem claim for DETF only. Pending on id 0 first; leftover compounds; shortfall from LP.
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
        if (address(tokenOut_) != address(this)) {
            revert Repo.InvalidRoute(IERC20(address(this)), tokenOut_);
        }

        Repo.Storage storage s = Repo._layoutStruct();
        uint256 lpOut_ = _burnClaimToNftLp(claimAmount_);
        uint256 owed_ = _previewProportionalDetf(lpOut_);
        uint256 harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));

        if (harvested_ >= owed_) {
            amountOut_ = owed_;
            uint256 leftover_ = harvested_ - owed_;
            if (leftover_ > 0 && IHook(s.reserveHook).isZapEligible()) {
                uint256 lpBack_ = _depositSingle(address(this), leftover_, _bondLpHolder());
                if (lpBack_ > 0) s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
            }
            if (lpOut_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
            }
        } else {
            _pullBondLp(lpOut_);
            (uint256 detfFromLp_, uint256 a0_, uint256 a1_) = _removeLiquidity(lpOut_, address(this));
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            uint256 lpBack_;
            if (IHook(s.reserveHook).isZapEligible()) {
                if (leftoverDetf_ > 0) {
                    lpBack_ += _depositSingle(address(this), leftoverDetf_, _bondLpHolder());
                }
                if (a0_ > 0) lpBack_ += _depositSingle(address(s.pairToken0), a0_, _bondLpHolder());
                if (a1_ > 0) lpBack_ += _depositSingle(address(s.pairToken1), a1_, _bondLpHolder());
            } else if (leftoverDetf_ > 0) {
                lpBack_ += _redepositDetfSelfLegWithPairDust(leftoverDetf_, a0_, a1_);
            }
            if (lpBack_ > 0) s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpBack_);
        }

        if (amountOut_ < minOut_) revert Repo.SlippageExceeded(minOut_, amountOut_);
        if (amountOut_ > 0) IERC20(address(this)).safeTransfer(recipient_, amountOut_);
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function _burnClaimToNftLp(uint256 claimAmount_) private returns (uint256 lpOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) revert Repo.ClaimTokenNotConfigured();
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert Repo.ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        uint256 origOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (origOut_ == 0) revert Repo.ZeroAmount();
        lpOut_ = s.bondNftVault.convertToAssets(origOut_);
        if (lpOut_ == 0) revert Repo.EmptyProtocolLp();
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), origOut_);
    }

    function _previewProportionalDetf(uint256 lpIn_) internal view returns (uint256 detfOut_) {
        if (lpIn_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        (uint256 a0_, uint256 a1_, uint256 a2_) = IHook(s.reserveHook).previewRemoveLiquidity(lpIn_);
        (detfOut_,,) = _unpackBinding(a0_, a1_, a2_);
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
        _pullBondLp(lpAmount_);
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

    function completeReserveBondNft() public returns (address bondNftVault) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (s.reserveHook == address(0)) revert Repo.ReserveHookNotFinalized();
        try IUniswapV4HookStagedPairInit(s.reserveHook).isInitializationFinalized() returns (bool done_) {
            if (!done_) revert Repo.ReserveHookNotFinalized();
        } catch {
            // unmatched selector after finalize = finalized
        }
        if (address(s.bondNftVault) != address(0)) revert Repo.ReserveBondNftAlreadyWired();

        address detf_ = address(this);
        IDETFNFTVault bondVault_ = IDETFNFTVault(
            IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg).deployVault(
                string(abi.encodePacked(ERC20Repo._name(), " Bond")),
                string(abi.encodePacked(ERC20Repo._symbol(), "-BOND")),
                IDetf(detf_),
                IERC20(s.reserveHook),
                IERC20(detf_),
                0,
                detf_
            )
        );
        address feeTo_ = address(s.feeOracle.feeTo());
        uint256 detfNftId_;
        try bondVault_.initializeReservedBondNfts(feeTo_, s.creator) returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            try bondVault_.initializeDETFNFT() returns (uint256 id2_) {
                detfNftId_ = id2_;
            } catch {
                detfNftId_ = 0;
            }
        }
        uint256 feeRecipientNftId_ = DETF_FEE_TO_BOND_NFT_ID;
        Repo._setBondNft(bondVault_, detfNftId_, feeRecipientNftId_);
        emit IUniswapV4StandardExchangeOrbitalDETF.ReserveBondNftWired(
            s.reserveHook, address(bondVault_), detfNftId_, feeRecipientNftId_
        );
        return address(bondVault_);
    }

    function completeReserveClaim() public returns (address rebasingClaimToken) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) revert Repo.ReserveBondNftNotWired();
        if (address(s.rebasingClaimToken) != address(0)) revert Repo.ReserveClaimAlreadyWired();

        address detf_ = address(this);
        IRebasingClaimToken claimToken_ = IRebasingClaimToken(
            IRebasingClaimTokenDFPkg(s.rebasingClaimTokenPkg).deployToken(
                IDetf(detf_), s.bondNftVault, s.rateAsset, s.detfNftId, detf_
            )
        );
        Repo._setClaim(claimToken_);
        emit IUniswapV4StandardExchangeOrbitalDETF.ReserveClaimWired(s.reserveHook, address(claimToken_));
        return address(claimToken_);
    }
}

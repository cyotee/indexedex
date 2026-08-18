// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFCommon,
    IQuadDetfCompoundSelf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/// @title UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget
/// @notice First bond (all three + capitalToken + refund), later single-pair joinUnbalanced,
///         mature-only sell/close.
abstract contract UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget is
    UniswapV4StandardExchangeCurveQuadStableDETFCommon
{
    using BetterSafeERC20 for IERC20;

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
            try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
            if (tokenIns_.length != 1) revert Repo.LaterBondSinglePairOnly();
            return _bondSingle(
                tokenIns_[0],
                amountsIn_[0],
                capitalToken_,
                lockDuration_,
                recipient_,
                pretransferred_,
                deadline_
            );
        }
        return _firstBond(
            tokenIns_, amountsIn_, capitalToken_, lockDuration_, recipient_, pretransferred_, deadline_
        );
    }

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
        if (!Repo._layoutStruct().isReserveLive) {
            revert Repo.FirstBondRequiresAllExternalPairs();
        }
        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}
        return _bondSingle(
            tokenIn_, amountIn_, address(0), lockDuration_, recipient_, pretransferred_, deadline_
        );
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
        _requireReserveWired();
        Repo.Storage storage s = Repo._layoutStruct();
        if (!Repo._isPairToken(capitalToken_)) revert Repo.InvalidCapitalToken();
        _rejectPretransferredFirstBond(pretransferred_, amountsIn_);

        uint256[] memory pairNatives_ = new uint256[](s.m);
        for (uint256 k; k < tokenIns_.length; ++k) {
            if (amountsIn_[k] == 0) continue;
            PairLegRating memory r_ =
                _settleToPairLeg(tokenIns_[k], amountsIn_[k], pretransferred_, deadline_);
            pairNatives_[r_.fundedProductIndex] += r_.pairNotionalNative;
        }
        for (uint8 i; i < s.m; ++i) {
            if (pairNatives_[i] == 0) revert Repo.FirstBondRequiresAllExternalPairs();
        }

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

        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(usedPairs_, detfForJoin_);
        (shares_,) = _joinProportional(binding_, _bondLpHolder());
        if (shares_ == 0 || shares_ < HOOK_MINIMUM_LIQUIDITY) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }
        if (!IHook(s.reserveHook).isFullBook()) {
            revert Repo.FirstBondBelowMinimumLiquidity();
        }

        Repo._setReserveLive();
        _mintBondFreeLegs(detfForJoin_, recipient_);

        uint256 effectiveBase_;
        for (uint8 i; i < s.m; ++i) {
            uint256 mid_ = _previewExactIn(address(s.pairTokens[i]), address(this), usedPairs_[i]);
            if (mid_ == 0) mid_ = _pairNotionalToDetfWad(i, usedPairs_[i]);
            effectiveBase_ += mid_;
        }
        if (effectiveBase_ == 0) effectiveBase_ = shares_;

        tokenId_ = _openBondNft(shares_, effectiveBase_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, capitalToken_);
        Repo._addUserBondedLp(shares_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveLive(tokenId_, shares_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    function _bondSingle(
        IERC20 tokenIn_,
        uint256 amountIn_,
        address capitalToken_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        PairLegRating memory r_ = _settleToPairLeg(tokenIn_, amountIn_, pretransferred_, deadline_);
        address fundedPair_ = address(Repo._layoutStruct().pairTokens[r_.fundedProductIndex]);
        if (capitalToken_ != address(0) && capitalToken_ != fundedPair_) {
            revert Repo.InvalidCapitalToken();
        }
        shares_ = _liveBondJoinSingle(r_);
        uint256 pairBoosted_ =
            Math.mulDiv(r_.pairNotionalNative, ONE_WAD + _seigniorageIncentiveWad(), ONE_WAD);
        _mintBondFreeLegs(_quoteDetfAgainstReserve(r_.fundedProductIndex, pairBoosted_), recipient_);

        uint256 rateWad_ = _previewExactIn(fundedPair_, address(this), r_.pairNotionalNative);
        if (rateWad_ == 0) rateWad_ = _pairNotionalToDetfWad(r_.fundedProductIndex, r_.pairNotionalNative);
        if (rateWad_ == 0) rateWad_ = shares_;
        tokenId_ = _openBondNft(shares_, rateWad_, lockDuration_, recipient_);
        Repo._setCapitalToken(tokenId_, fundedPair_);
        Repo._addUserBondedLp(shares_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @dev Later bond: always joinUnbalanced DETF + one pair; zeros on the other two.
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
        Repo.Storage storage s2 = Repo._layoutStruct();
        uint256[] memory pairAmts_ = new uint256[](s2.m);
        pairAmts_[r_.fundedProductIndex] = r_.pairNotionalNative;
        _mintDetf(address(this), detfForJoin_);
        uint256[] memory binding_ = _packBinding(pairAmts_, detfForJoin_);
        lpOut_ = _joinUnbalanced(binding_, _bondLpHolder());
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

    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        _requireMature(tokenId_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

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
        _syncAllExpectedHoldReserves();
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

        try IQuadDetfCompoundSelf(address(this)).realizeExpansionExternal() {} catch {}

        uint256 lp_ = s.bondNftVault.originalSharesOf(tokenId_);
        address capital_ = s.capitalTokenOf[tokenId_];
        if (capital_ == address(0) || !Repo._isPairToken(capital_)) {
            revert Repo.InvalidCapitalToken();
        }

        _pullBondLp(lp_);
        DETFBondLifecycleLib._sellPositionToDetfNft(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), tokenId_, msg.sender, recipient_
        );

        amountOut_ = _closeLpToCapitalToken(lp_, capital_);
        if (amountOut_ > 0) IERC20(capital_).safeTransfer(recipient_, amountOut_);

        Repo._clearCapital(tokenId_);
        Repo._subUserBondedLp(lp_);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @dev Prop-remove + redeposit DETF + consolidate. NEVER withdrawSingle / exitSingleAssetExact*.
    function _closeLpToCapitalToken(uint256 lp_, address capital_) internal returns (uint256 amountOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IHook hook_ = IHook(s.reserveHook);
        IERC20(s.reserveHook).forceApprove(s.reserveHook, lp_);
        uint256[] memory mins_ = new uint256[](s.n);
        uint256[] memory residual_ = hook_.exitProportional(lp_, address(this), mins_, block.timestamp + 1);
        (uint256 aDetf_, uint256[] memory pairAmts_) = _unpackBinding(residual_);
        _redepositDetfSelfLeg(aDetf_);
        amountOut_ = _consolidateToPair(capital_, pairAmts_);
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
        uint256 detfNftId_;
        try bondVault_.initializeDETFNFT() returns (uint256 id_) {
            detfNftId_ = id_;
        } catch {
            detfNftId_ = 0;
        }
        uint256 feeRecipientNftId_;
        address feeTo_ = address(s.feeOracle.feeTo());
        if (feeTo_ != address(0)) {
            uint256 lock_;
            try s.feeOracle.bondTermsOfVault(detf_) returns (BondTerms memory terms_) {
                lock_ = terms_.minLockDuration == 0 ? 1 : terms_.minLockDuration;
            } catch {
                lock_ = 1;
            }
            try bondVault_.createPosition(1, lock_, feeTo_) returns (uint256 id_) {
                feeRecipientNftId_ = id_;
            } catch {
                feeRecipientNftId_ = 0;
            }
        }
        Repo._setBondNft(bondVault_, detfNftId_, feeRecipientNftId_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveBondNftWired(
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
                IDetf(detf_), s.bondNftVault, s.pairTokens[0], s.detfNftId, detf_
            )
        );
        Repo._setClaim(claimToken_);
        emit IUniswapV4StandardExchangeCurveQuadStableDETF.ReserveClaimWired(
            s.reserveHook, address(claimToken_)
        );
        return address(claimToken_);
    }
}

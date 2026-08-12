// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {
    MultiVaultWeightedDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @title IMultiVaultWeightedDetfBonding
interface IMultiVaultWeightedDetfBonding {
    function bond(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 lockDuration,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

    /// @notice Pre-live only: mint DETF self-leg into join, initialize weighted reserve with vault shares, return BPT.
    /// @dev Does not set live. Caller bonds BPT next to go live. No free seigniorage DETF to user.
    function initializeReserve(uint256[] calldata vaultShareAmounts, uint256 deadline)
        external
        returns (uint256 bptOut);

    function sellPositionToDetfNft(uint256 tokenId, uint256 minClaimOut, address recipient)
        external
        returns (uint256 claimMinted);

    function acceptedBondTokens() external view returns (address[] memory);

    function buyClaim(
        uint256 detfAmount,
        uint256 minClaimOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 claimMinted);

    function previewBuyClaim(uint256 detfAmount) external view returns (uint256 claimMinted);

    function closeBondMature(
        uint256 tokenId,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewCloseBondMature(uint256 tokenId, IERC20 tokenOut) external view returns (uint256 amountOut);

    /// @notice Redeem rebasing claim for a configured rateAsset via protocol reserve BPT unwind.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 tokenOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function previewRedeemClaim(uint256 claimAmount, IERC20 tokenOut) external view returns (uint256 amountOut);

    function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 amountOut);

    function protocolBondOriginalShares() external view returns (uint256);
}

/// @title MultiVaultWeightedDetfBondingTarget
/// @notice BPT-first live path; vault-share bonds post-live; sell → claim; claim redeem to any rateAsset.
abstract contract MultiVaultWeightedDetfBondingTarget is MultiVaultWeightedDetfCommon, IMultiVaultWeightedDetfBonding {
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function initializeReserve(uint256[] calldata vaultShareAmounts_, uint256 deadline_)
        public
        virtual
        nonReentrant
        returns (uint256 bptOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (s.isReserveLive) revert MultiVaultWeightedDetfRepo.AlreadyLive();
        if (IERC20(s.reservePool).totalSupply() != 0) {
            revert MultiVaultWeightedDetfRepo.AlreadyLive();
        }
        if (vaultShareAmounts_.length != s.vaultCount) {
            revert MultiVaultWeightedDetfRepo.InvalidVaultCount(vaultShareAmounts_.length);
        }
        if (block.timestamp > deadline_) {
            revert MultiVaultWeightedDetfRepo.DeadlineExpired(deadline_);
        }

        // Pull all vault shares; mint DETF self-leg for weight pairing (into pool only).
        uint256 primaryLeg_;
        uint256 primaryAmount_;
        for (uint256 i; i < s.vaultCount; ++i) {
            if (vaultShareAmounts_[i] == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
            _pullToken(s.vaultShares[i], vaultShareAmounts_[i], false);
            if (vaultShareAmounts_[i] > primaryAmount_) {
                primaryAmount_ = vaultShareAmounts_[i];
                primaryLeg_ = i;
            }
        }

        uint256 detfForPool_ = _quoteDetfBootstrapPublic(primaryLeg_, primaryAmount_);
        // Scale DETF by total vault weight / primary so multi-leg join is roughly weight-matched.
        // For N=1 this equals single-vault bootstrap quote.
        _mintDetf(address(this), detfForPool_);

        uint256[] memory amounts_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            amounts_[i] = vaultShareAmounts_[i];
        }
        bptOut_ = _initializeReserve(detfForPool_, amounts_);
        s.reserveBpt.safeTransfer(msg.sender, bptOut_);
    }

    function _quoteDetfBootstrapPublic(uint256 legIndex_, uint256 vaultShares_)
        internal
        view
        returns (uint256)
    {
        return _quoteDetfOutForVaultShares(legIndex_, vaultShares_);
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function bond(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 lockDuration_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        _requireActive(deadline_, amountIn_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(tokenIn_) == address(this)) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(this));
        }

        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        uint256 bptPrincipal_;

        if (address(tokenIn_) == address(s.reserveBpt)) {
            bptPrincipal_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        } else {
            // Vault-share bond: only after live (builds additional BPT via join).
            if (!s.isReserveLive) {
                revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
            }
            (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenIn_);
            if (!found_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(this));
            }
            uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            uint256 detfForPool_ = _quoteDetfOutForVaultShares(legIndex_, vaultShares_);
            MintSplit memory split_ = _splitMintedDetf(detfForPool_);
            _mintDetf(address(this), detfForPool_);
            bptPrincipal_ = _joinReserveBothDetfAndShare(legIndex_, detfForPool_, vaultShares_);
            if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);
            if (split_.feeToDetf > 0) _mintDetf(_feeTo(), split_.feeToDetf);
            if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        }

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );
        shares_ = bptPrincipal_;

        if (!s.isReserveLive) {
            MultiVaultWeightedDetfRepo._setReserveLive();
        }

        // Lazy protocol compound after reward-affecting bond / inventory mint (best-effort).
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function sellPositionToDetfNft(uint256 tokenId_, uint256 minClaimOut_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 claimMinted_)
    {
        _requireMature(tokenId_);
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MultiVaultWeightedDetfRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _updateExpansionMintOnRewards();

        uint256 protocolBefore_ = _protocolOriginalShares();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        DETFBondLifecycleLib._sellPositionToDetfNft(s.bondNftVault, tokenId_, msg.sender, recipient_);
        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(assets_, protocolBefore_, recipient_);
        if (claimMinted_ < minClaimOut_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        tokens_ = new address[](uint256(s.vaultCount) + 1);
        tokens_[0] = address(s.reserveBpt);
        for (uint256 i; i < s.vaultCount; ++i) {
            tokens_[i + 1] = address(s.vaultShares[i]);
        }
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function protocolBondOriginalShares() external view returns (uint256) {
        return _protocolOriginalShares();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function buyClaim(
        uint256 detfAmount_,
        uint256 minClaimOut_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 claimMinted_) {
        _requireReserveLive();
        _requireActive(deadline_, detfAmount_);
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MultiVaultWeightedDetfRepo.ClaimTokenNotConfigured();
        }
        if (recipient_ == address(0)) recipient_ = msg.sender;

        _pullToken(IERC20(address(this)), detfAmount_, pretransferred_);
        uint256 bptIn_ = _singleSidedJoinDetf(detfAmount_);
        if (bptIn_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();

        claimMinted_ = s.rebasingClaimToken.mintFromNFTSale(bptIn_, recipient_);
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptIn_);
        if (claimMinted_ < minClaimOut_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(0));
        }

        _updateExpansionMintOnRewards();
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewBuyClaim(uint256 detfAmount_) external view returns (uint256 claimMinted_) {
        if (detfAmount_ == 0) return 0;
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 bptIn_ = _previewJoinDetfOnly(detfAmount_);
        claimMinted_ = _previewClaimMinted(bptIn_, _protocolOriginalShares());
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function closeBondMature(
        uint256 tokenId_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireMature(tokenId_);
        _requireActive(deadline_, 1);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        _updateExpansionMintOnRewards();

        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        uint256 protocol_ = _protocolOriginalShares();
        uint256 bal_ = s.reserveBpt.balanceOf(address(this));
        if (bal_ < protocol_ + assets_) {
            revert MultiVaultWeightedDetfRepo.InsufficientReserveBpt(protocol_ + assets_, bal_);
        }

        (bool found_, uint256 legIndex_) = _resolveBurnLeg(tokenOut_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(0), address(tokenOut_));
        }

        DETFBondLifecycleLib._sellPositionToDetfNft(s.bondNftVault, tokenId_, msg.sender, recipient_);
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), assets_);

        amountOut_ = _exitRedepositSettle(assets_, legIndex_, tokenOut_, minOut_, recipient_, deadline_);

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewCloseBondMature(uint256 tokenId_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) return 0;
        (bool found_, uint256 legIndex_) = _resolveBurnLeg(tokenOut_);
        if (!found_) return 0;
        amountOut_ = _previewExitSettle(assets_, legIndex_, tokenOut_);
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
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

        (bool found_, uint256 legIndex_) = _resolveBurnLeg(tokenOut_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(0), address(tokenOut_));
        }

        uint256 bptOut_ = _burnClaimConvertToAssets(claimAmount_);
        amountOut_ = _exitRedepositSettle(bptOut_, legIndex_, tokenOut_, minOut_, recipient_, deadline_);
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewRedeemClaim(uint256 claimAmount_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        if (claimAmount_ == 0) return 0;
        (bool found_, uint256 legIndex_) = _resolveBurnLeg(tokenOut_);
        if (!found_) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount_);
        amountOut_ = _previewExitSettle(bptOut_, legIndex_, tokenOut_);
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function claimLiquidity(uint256 lpAmount_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 amountOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (
            msg.sender != address(this) && msg.sender != address(s.bondNftVault)
                && msg.sender != address(s.rebasingClaimToken)
        ) {
            revert MultiVaultWeightedDetfRepo.NotAuthorized(msg.sender);
        }
        if (lpAmount_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        if (recipient_ == address(0)) recipient_ = msg.sender;

        IERC20 tokenOut_ = s.rateAssets[0];
        (bool found_, uint256 legIndex_) = _resolveBurnLeg(tokenOut_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(0), address(tokenOut_));
        }
        amountOut_ = _exitRedepositSettle(lpAmount_, legIndex_, tokenOut_, 0, recipient_, block.timestamp);
        _syncAllExpectedHoldReserves();
    }

    function _burnClaimConvertToAssets(uint256 claimAmount_) private returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MultiVaultWeightedDetfRepo.ClaimTokenNotConfigured();
        }
        uint256 totalSharesBefore_ = s.rebasingClaimToken.totalShares();
        uint256 sharesBurned_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (sharesBurned_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        uint256 totalAssets_ = _protocolOriginalShares();
        uint256 totalShares_ = totalSharesBefore_ == 0 ? sharesBurned_ : totalSharesBefore_;
        bptOut_ = (sharesBurned_ * totalAssets_) / totalShares_;
        if (bptOut_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();

        uint256 userPile_ = _userPileReserved();
        uint256 bal_ = s.reserveBpt.balanceOf(address(this));
        uint256 physicalAvail_ = bal_ > userPile_ ? bal_ - userPile_ : 0;
        if (physicalAvail_ < bptOut_) {
            revert MultiVaultWeightedDetfRepo.InsufficientReserveBpt(bptOut_, physicalAvail_);
        }
        s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), bptOut_);
    }

    function _previewClaimBptOut(uint256 claimAmount_) private view returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) return 0;
        uint256 shares_ = s.rebasingClaimToken.convertToShares(claimAmount_);
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 totalAssets_ = _protocolOriginalShares();
        if (shares_ == 0 || totalShares_ == 0) return 0;
        bptOut_ = (shares_ * totalAssets_) / totalShares_;
    }

    function _previewClaimMinted(uint256 assets_, uint256 totalAssets_) private view returns (uint256) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 totalShares_ = s.rebasingClaimToken.totalShares();
        uint256 sharesOut_ = totalAssets_ == 0 ? assets_ : (assets_ * totalShares_) / totalAssets_;
        return s.rebasingClaimToken.convertToClaim(sharesOut_);
    }

    function _previewJoinDetfOnly(uint256 detfAmount_) private view returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0 || detfAmount_ == 0) return 0;
        IVault bal_ = _reserveVault();
        (,, uint256[] memory balances_,) = bal_.getPoolTokenInfo(s.reservePool);
        uint256 detfBal_ = balances_[s.detfIndex];
        if (detfBal_ == 0) return 0;
        bptOut_ = (detfAmount_ * bptSupply_) / detfBal_;
    }

    function _resolveBurnLeg(IERC20 tokenOut_) private view returns (bool found_, uint256 legIndex_) {
        (found_, legIndex_) = MultiVaultWeightedDetfRepo._findRateAssetLeg(tokenOut_);
        if (found_) return (true, legIndex_);
        return MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenOut_);
    }

    function _exitRedepositSettle(
        uint256 bptIn_,
        uint256 legIndex_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        (uint256 detfLeg_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);
        // Rejoin DETF + non-output legs together so a lone self-leg join cannot
        // trip Balancer InvariantRatioAboveMax.
        uint256 bptBack_ = _rejoinDetfAndOtherLegs(detfLeg_, vaultSharesOut_, legIndex_);
        if (bptBack_ > 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
        }
        uint256 shareAmt_ = vaultSharesOut_[legIndex_];
        if (address(tokenOut_) == address(s.vaultShares[legIndex_])) {
            if (shareAmt_ < minOut_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(s.vaultShares[legIndex_]), address(tokenOut_));
            }
            if (shareAmt_ > 0) tokenOut_.safeTransfer(recipient_, shareAmt_);
            return shareAmt_;
        }
        amountOut_ = _exchangeShareToRateAsset(legIndex_, shareAmt_, tokenOut_, minOut_, recipient_, deadline_);
    }

    function _rejoinDetfAndOtherLegs(
        uint256 detfLeg_,
        uint256[] memory vaultSharesOut_,
        uint256 outLeg_
    ) private returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        bool any_;
        if (detfLeg_ > 0) {
            // Cap DETF join to ~2.5x remaining pool DETF so first-bonder close
            // cannot exceed Balancer InvariantRatioAboveMax. Leftover DETF stays
            // idle on the diamond (not user free DETF, not burned).
            (,, uint256[] memory balances_,) = _reserveVault().getPoolTokenInfo(s.reservePool);
            uint256 remaining_ = balances_[s.detfIndex];
            uint256 joinDetf_ = detfLeg_;
            // Majority/first-bonder close empties the pool; do not rejoin more DETF than remains.
            if (remaining_ == 0 || joinDetf_ > remaining_) {
                joinDetf_ = 0;
            } else {
                uint256 maxJoin_ = remaining_ * 25 / 10;
                if (joinDetf_ > maxJoin_) joinDetf_ = maxJoin_;
            }
            if (joinDetf_ > 0) {
                amountsIn_[s.detfIndex] = joinDetf_;
                IERC20(address(this)).safeTransfer(address(_reserveVault()), joinDetf_);
                any_ = true;
            }
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (i == outLeg_) continue;
            if (vaultSharesOut_[i] == 0) continue;
            amountsIn_[s.vaultShareIndexes[i]] = vaultSharesOut_[i];
            s.vaultShares[i].safeTransfer(address(_reserveVault()), vaultSharesOut_[i]);
            any_ = true;
        }
        // N=1: pair a dust of the settlement share only when we actually rejoin DETF.
        if (amountsIn_[s.detfIndex] > 0 && vaultSharesOut_.length > outLeg_ && vaultSharesOut_[outLeg_] > 1) {
            uint256 dust_ = vaultSharesOut_[outLeg_] / 1000;
            if (dust_ == 0) dust_ = 1;
            if (dust_ >= vaultSharesOut_[outLeg_]) dust_ = vaultSharesOut_[outLeg_] - 1;
            if (dust_ > 0) {
                amountsIn_[s.vaultShareIndexes[outLeg_]] += dust_;
                s.vaultShares[outLeg_].safeTransfer(address(_reserveVault()), dust_);
                vaultSharesOut_[outLeg_] -= dust_;
                any_ = true;
            }
        }
        if (!any_) return 0;
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _previewExitSettle(uint256 bptIn_, uint256, IERC20) private view returns (uint256) {
        if (bptIn_ == 0) return 0;
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        if (bptSupply_ == 0) return 0;
        return bptIn_;
    }

    function _exchangeShareToRateAsset(
        uint256 legIndex_,
        uint256 shareAmt_,
        IERC20 rateAssetOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256 amountOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        IERC20 share_ = s.vaultShares[legIndex_];
        if (shareAmt_ == 0) {
            if (minOut_ > 0) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(share_), address(rateAssetOut_));
            }
            return 0;
        }
        share_.safeTransfer(address(s.underlyingVaults[legIndex_]), shareAmt_);
        amountOut_ = s.underlyingVaults[legIndex_].exchangeIn(
            share_, shareAmt_, rateAssetOut_, minOut_, recipient_, true, deadline_
        );
        if (amountOut_ < minOut_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(share_), address(rateAssetOut_));
        }
    }
}

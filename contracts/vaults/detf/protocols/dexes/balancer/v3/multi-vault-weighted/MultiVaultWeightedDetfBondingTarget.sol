// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {
    MultiVaultWeightedDetfCommon
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";

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

    /// @notice First bond: fund EVERY vault-share leg plus unboosted DETF `G`. Goes live.
    function initializeReserve(
        uint256[] calldata vaultShareAmounts,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    ) external returns (uint256 tokenId, uint256 shares);

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
        uint256[] calldata minAmountsOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut);

    function previewCloseBondMature(uint256 tokenId) external view returns (uint256[] memory amountsOut);

    /// @notice Redeem rebasing claim for DETF only (D15).
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

    /// @notice Bond NFT only. Settle `token` and single-sided join BPT to the Bond NFT. No DETF mint. No expansion.
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        external
        returns (uint256 lpOut);

    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        external
        view
        returns (uint256 lpOut);

    /// @notice Bond NFT only. D2 top-up after donate credits id 0.
    function notifyReserveDonated() external;

    /// @notice Forwards to Bond NFT donate with `minLpOut = 0`. Pretransfer destination is the NFT.
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;
}

/// @title MultiVaultWeightedDetfBondingTarget
/// @notice BPT-first live path; vault-share bonds post-live; sell → claim; claim redeem to any rateAsset.
abstract contract MultiVaultWeightedDetfBondingTarget is MultiVaultWeightedDetfCommon, IMultiVaultWeightedDetfBonding {
    using BetterSafeERC20 for IERC20;

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function initializeReserve(
        uint256[] calldata vaultShareAmounts_,
        uint256 lockDuration_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 tokenId_, uint256 shares_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (s.isReserveLive) revert MultiVaultWeightedDetfRepo.AlreadyLive();
        if (IERC20(s.reservePool).totalSupply() != 0) {
            revert MultiVaultWeightedDetfRepo.AlreadyLive();
        }
        if (vaultShareAmounts_.length != s.vaultCount) {
            revert MultiVaultWeightedDetfRepo.InvalidVaultCount(vaultShareAmounts_.length);
        }
        _requireActive(deadline_, 1);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        uint256[] memory amounts_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            if (vaultShareAmounts_[i] == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
            amounts_[i] = _pullToken(s.vaultShares[i], vaultShareAmounts_[i], false);
        }

        // D24 empty = family weights. L1 + D4 pot. Join remains full G.
        uint256 detfForPool_ = _quoteBondJoinDetfAllLegs(amounts_);
        MintSplit memory split_ = _splitBondDetf(detfForPool_);

        _mintDetf(address(this), detfForPool_);
        uint256 bptOut_ = _initializeReserve(detfForPool_, amounts_);

        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptOut_, effectiveLock_, recipient_
        );
        shares_ = bptOut_;
        _custodyBptOnNft(bptOut_);

        MultiVaultWeightedDetfRepo._setReserveLive();
        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
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
        if (!s.isReserveLive) {
            _rejectPretransferredFirstBond(pretransferred_, amountIn_);
        }
        uint256 effectiveLock_ = _effectiveLockDuration(lockDuration_);

        uint256 bptPrincipal_;

        if (address(tokenIn_) == address(s.reserveBpt)) {
            // Existing LP only after live. First bond must fund every vault-share leg.
            if (!s.isReserveLive) {
                revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
            }
            bptPrincipal_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
            tokenId_ = DETFBondLifecycleLib._createBondPosition(
                s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
            );
            shares_ = bptPrincipal_;
            _custodyBptOnNft(bptPrincipal_);
            _topUpFeeCreatorShares();
            _tryCompoundProtocolRewards();
            _syncAllExpectedHoldReserves();
            return (tokenId_, shares_);
        }

        return _bondVaultShare(tokenIn_, amountIn_, effectiveLock_, recipient_, pretransferred_);
    }

    function _bondVaultShare(
        IERC20 tokenIn_,
        uint256 amountIn_,
        uint256 effectiveLock_,
        address recipient_,
        bool pretransferred_
    ) private returns (uint256 tokenId_, uint256 shares_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(tokenIn_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(tokenIn_), address(this));
        }
        if (!s.isReserveLive && s.vaultCount != 1) {
            revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
        }
        uint256 vaultShares_ = _pullToken(tokenIn_, amountIn_, pretransferred_);
        uint256 detfForPool_ = _quoteBondJoinDetf(legIndex_, vaultShares_);
        MintSplit memory split_ = _splitBondDetf(detfForPool_);
        _mintDetf(address(this), detfForPool_);
        uint256 bptPrincipal_ = _joinReserveBothDetfAndShare(legIndex_, detfForPool_, vaultShares_);
        if (split_.userDetf > 0) _mintDetf(recipient_, split_.userDetf);

        tokenId_ = DETFBondLifecycleLib._createBondPosition(
            s.bondNftVault, bptPrincipal_, effectiveLock_, recipient_
        );
        shares_ = bptPrincipal_;
        _custodyBptOnNft(bptPrincipal_);

        if (!s.isReserveLive) {
            MultiVaultWeightedDetfRepo._setReserveLive();
        }

        _topUpFeeCreatorShares();
        if (split_.inventoryDetf > 0) _mintDetf(address(s.bondNftVault), split_.inventoryDetf);
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
        _requireNotStandingRewardNft(tokenId_);
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

        _topUpFeeCreatorShares();
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

        _topUpFeeCreatorShares();
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
    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external
        nonReentrant
        returns (uint256 lpOut_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(token_) == s.reservePool || address(token_) == address(s.reserveBpt)) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(token_), address(this));
        }
        if (address(token_) == address(this)) {
            uint256 pulled_ = _pullToken(token_, amount_, false);
            lpOut_ = _joinReserveDetfOnly(pulled_);
        } else {
            (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findVaultShareIndex(token_);
            if (!found_) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(token_), address(this));
            }
            uint256 vaultShares_ = _pullToken(token_, amount_, false);
            lpOut_ = _joinReserveVaultShareOnly(legIndex_, vaultShares_);
        }
        _sendJoinBptToNft(lpOut_);
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_)
        external
        view
        returns (uint256 lpOut_)
    {
        return _previewJoinDonatedCapital(token_, amount_);
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function notifyReserveDonated() external {
        _requireBondNft();
        _topUpFeeCreatorShares();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function donate(IERC20 token_, uint256 amount_, bool pretransferred_) external {
        _requireNotDisabled();
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        address nft_ = address(s.bondNftVault);
        if (nft_ == address(0)) revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
        IDetfNftReserveDonation(nft_).donate(
            msg.sender, token_, amount_, 0, pretransferred_, block.timestamp + 1
        );
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
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

        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = _reserveTokenCount();
        if (minAmountsOut_.length != n_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(0), address(0));
        }
        if (minAmountsOut_[s.detfIndex] != 0) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(this), address(0));
        }
        _updateExpansionMintOnRewards();

        uint256 lpOut_ = s.bondNftVault.convertToAssets(s.bondNftVault.originalSharesOf(tokenId_));
        if (lpOut_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        s.bondNftVault.retireMaturePosition(tokenId_, recipient_);

        (uint256 detfOut_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(lpOut_);
        if (detfOut_ > 0) {
            uint256 bptRejoin_ = _joinReserveDetfUntilDust(detfOut_);
            if (bptRejoin_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
            DETFBondLifecycleLib._addReservePoolBptToDetfNft(
                IERC20(s.reservePool),
                IDetfSelfNftInventoryPolicy(address(s.bondNftVault)),
                s.bondNftVault.detfNFTId(),
                bptRejoin_
            );
            _topUpFeeCreatorShares();
        }

        amountsOut_ = new uint256[](n_);
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.vaultShareIndexes[i];
            uint256 amt_ = vaultSharesOut_[i];
            if (amt_ < minAmountsOut_[idx_]) {
                revert MultiVaultWeightedDetfRepo.InvalidRoute(address(s.vaultShares[i]), address(0));
            }
            amountsOut_[idx_] = amt_;
            if (amt_ > 0) {
                s.vaultShares[i].safeTransfer(recipient_, amt_);
            }
        }

        _tryCompoundProtocolRewards();
        _syncAllExpectedHoldReserves();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewCloseBondMature(uint256 tokenId_)
        external
        view
        returns (uint256[] memory amountsOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        amountsOut_ = new uint256[](_reserveTokenCount());
        uint256 assets_ = s.bondNftVault.originalSharesOf(tokenId_);
        if (assets_ == 0) return amountsOut_;
        uint256 lpOut_ = s.bondNftVault.convertToAssets(assets_);
        amountsOut_ = _previewProportionalAmounts(lpOut_);
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function redeemClaim(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        amountOut_ = _redeemClaimForDetf(claimAmount_, tokenOut_, minOut_, recipient_, deadline_);
    }

    /// @dev D15: claim → DETF. Pending on id 0 first; leftover pending compounded; shortfall from LP.
    function _redeemClaimForDetf(
        uint256 claimAmount_,
        IERC20 tokenOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        _updateExpansionMintOnRewards();

        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(tokenOut_) != address(this)) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(s.rebasingClaimToken), address(tokenOut_));
        }

        uint256 bptOut_ = _burnClaimConvertToAssets(claimAmount_);
        uint256 owed_ = _previewProportionalDetf(bptOut_);
        uint256 harvested_ = s.bondNftVault.reallocateDetfNftRewards(address(this));

        if (harvested_ >= owed_) {
            amountOut_ = owed_;
            uint256 leftover_ = harvested_ - owed_;
            if (leftover_ > 0) {
                uint256 bptBack_ = _joinReserveDetfOnly(leftover_);
                if (bptBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
                }
            }
            if (bptOut_ > 0) {
                s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptOut_);
            }
        } else {
            (uint256 detfFromLp_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptOut_);
            uint256 shortfall_ = owed_ - harvested_;
            uint256 fromLp_ = detfFromLp_ < shortfall_ ? detfFromLp_ : shortfall_;
            amountOut_ = harvested_ + fromLp_;
            uint256 leftoverDetf_ = detfFromLp_ - fromLp_;
            uint256[] memory rejoinShares_ = vaultSharesOut_;
            if (leftoverDetf_ > 0 || _anyPositive(rejoinShares_)) {
                uint256 bptBack_ = _joinReserveDetfAndShares(leftoverDetf_, rejoinShares_);
                if (bptBack_ > 0) {
                    s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), bptBack_);
                }
            }
        }

        if (amountOut_ < minOut_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(this), address(tokenOut_));
        }
        if (amountOut_ > 0) {
            IERC20(address(this)).safeTransfer(recipient_, amountOut_);
        }
        _topUpFeeCreatorShares();
        _syncAllExpectedHoldReserves();
    }

    function _anyPositive(uint256[] memory amounts_) private pure returns (bool) {
        for (uint256 i; i < amounts_.length; ++i) {
            if (amounts_[i] > 0) return true;
        }
        return false;
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function previewRedeemClaim(uint256 claimAmount_, IERC20 tokenOut_)
        external
        view
        returns (uint256 amountOut_)
    {
        if (claimAmount_ == 0) return 0;
        if (address(tokenOut_) != address(this)) return 0;
        uint256 bptOut_ = _previewClaimBptOut(claimAmount_);
        amountOut_ = _previewProportionalDetf(bptOut_);
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
        uint256 bal_ = s.reserveBpt.balanceOf(address(s.bondNftVault));
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

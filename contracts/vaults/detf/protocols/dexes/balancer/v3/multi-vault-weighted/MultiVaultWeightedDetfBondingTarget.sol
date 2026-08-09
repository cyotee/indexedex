// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
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

    function sellPositionToDetfNft(uint256 tokenId, address recipient)
        external
        returns (uint256 principalShares);

    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 rebasingClaimMinted);

    function acceptedBondTokens() external view returns (address[] memory);

    /// @notice Redeem rebasing claim for a configured rateAsset via protocol reserve BPT unwind.
    function redeemClaim(
        uint256 claimAmount,
        IERC20 rateAssetOut,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);
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
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function sellPositionToDetfNft(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 principalShares_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        principalShares_ = DETFBondLifecycleLib._sellPositionToDetfNft(
            s.bondNftVault, tokenId_, msg.sender, recipient_
        );
        // Sell moves principal onto detf NFT; attempt compound of any pending protocol rewards.
        _tryCompoundProtocolRewards();
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function sellNFT(uint256 tokenId_, address recipient_)
        public
        virtual
        nonReentrant
        returns (uint256 rebasingClaimMinted_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (recipient_ == address(0)) recipient_ = msg.sender;
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MultiVaultWeightedDetfRepo.ClaimTokenNotConfigured();
        }
        (, rebasingClaimMinted_) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
            s.bondNftVault, s.rebasingClaimToken, tokenId_, msg.sender, recipient_
        );
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        // reserve BPT + N vault shares
        tokens_ = new address[](uint256(s.vaultCount) + 1);
        tokens_[0] = address(s.reserveBpt);
        for (uint256 i; i < s.vaultCount; ++i) {
            tokens_[i + 1] = address(s.vaultShares[i]);
        }
    }

    /// @inheritdoc IMultiVaultWeightedDetfBonding
    function redeemClaim(
        uint256 claimAmount_,
        IERC20 rateAssetOut_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) public virtual nonReentrant returns (uint256 amountOut_) {
        _requireReserveLive();
        _requireActive(deadline_, claimAmount_);
        if (recipient_ == address(0)) recipient_ = msg.sender;

        (bool found_, uint256 legIndex_) = MultiVaultWeightedDetfRepo._findRateAssetLeg(rateAssetOut_);
        if (!found_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(0), address(rateAssetOut_));
        }

        uint256 bptIn_ = _burnClaimForBpt(claimAmount_);
        uint256 shareAmt_ = _unwindBptToVaultShare(bptIn_, legIndex_);
        amountOut_ = _exchangeShareToRateAsset(legIndex_, shareAmt_, rateAssetOut_, minOut_, recipient_, deadline_);
    }

    /// @dev Burns rebasing claim for principal share units (BPT principal from mintFromNFTSale).
    ///      Never treats claimAmount as free BPT authority — claim token is mandatory.
    function _burnClaimForBpt(uint256 claimAmount_) private returns (uint256 bptIn_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.rebasingClaimToken) == address(0)) {
            revert MultiVaultWeightedDetfRepo.ClaimTokenNotConfigured();
        }
        // burnShares returns external share units minted 1:1 with bond principal BPT at sale.
        uint256 principalBpt_ = s.rebasingClaimToken.burnShares(claimAmount_, msg.sender, false);
        if (principalBpt_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        uint256 detfBpt_ = s.reserveBpt.balanceOf(address(this));
        // Cap by DETF-held BPT (principal inventory); never invent authority beyond burned shares.
        bptIn_ = principalBpt_ < detfBpt_ ? principalBpt_ : detfBpt_;
        if (bptIn_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
    }

    function _unwindBptToVaultShare(uint256 bptIn_, uint256 legIndex_) private returns (uint256 shareAmt_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        (uint256 detfLeg_, uint256[] memory vaultSharesOut_) = _exitReserveProportional(bptIn_);
        if (detfLeg_ > 0) {
            _burnDetf(address(this), detfLeg_);
        }
        for (uint256 i; i < s.vaultCount; ++i) {
            if (i == legIndex_) continue;
            if (vaultSharesOut_[i] > 0) {
                _joinReserveVaultShareOnly(i, vaultSharesOut_[i]);
            }
        }
        shareAmt_ = vaultSharesOut_[legIndex_];
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
        share_.safeTransfer(address(s.underlyingVaults[legIndex_]), shareAmt_);
        amountOut_ = s.underlyingVaults[legIndex_].exchangeIn(
            share_, shareAmt_, rateAssetOut_, minOut_, recipient_, true, deadline_
        );
        if (amountOut_ < minOut_) {
            revert MultiVaultWeightedDetfRepo.InvalidRoute(address(share_), address(rateAssetOut_));
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {ISeigniorageDETF} from "contracts/interfaces/ISeigniorageDETF.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {SeigniorageNFTVaultRepo} from "contracts/vaults/seigniorage/SeigniorageNFTVaultRepo.sol";
import {SeigniorageNFTVaultCommon} from "contracts/vaults/seigniorage/SeigniorageNFTVaultCommon.sol";

/**
 * @title SeigniorageNFTVaultTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of the Seigniorage NFT Vault.
 * @dev Manages NFT-based bonding positions with time-locked rewards.
 *      Users lock BPT (LP) tokens for a duration and receive boosted reward shares.
 *      The DETF owns this vault and is the only entity that can create lock positions.
 */
contract SeigniorageNFTVaultTarget is SeigniorageNFTVaultCommon, ReentrancyLockModifiers, MultiStepOwnableModifiers {
    using BetterSafeERC20 for IERC20;
    using SeigniorageNFTVaultRepo for SeigniorageNFTVaultRepo.Storage;
    using ERC721Repo for ERC721Repo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                              Lock Shares                               */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageNFTVault
     * @dev Only the owner (DETF) can call this function to create lock positions.
     *      The DETF holds the actual BPT; this vault tracks the user's share of that BPT.
     *      Shares are calculated proportionally using the DETF's pre-underwrite BPT reserve.
     */
    function lockFromDetf(uint256 bptOut, uint256 bptReserveBefore, uint256 lockDuration, address recipient)
        external
        onlyOwner
        lock
        returns (uint256 tokenId)
    {
        if (bptOut == 0) revert BaseSharesZero();

        SeigniorageNFTVaultRepo.Storage storage layout = SeigniorageNFTVaultRepo._layout();
        _validateLockDuration(layout, lockDuration);

        uint256 bonusMultiplier = _calcBonusMultiplier(lockDuration);

        // Update global rewards before creating position
        SeigniorageNFTVaultRepo._updateGlobalRewards(layout);

        // Convert BPT amount to shares using the DETF reserve *before* the mint.
        uint256 originalShares = SeigniorageNFTVaultRepo._convertToSharesGivenReserve(layout, bptOut, bptReserveBefore);

        // Calculate bonus multiplier and effective shares
        uint256 effectiveShares = (originalShares * bonusMultiplier) / ONE_WAD;

        // Mint NFT to recipient (ERC721Repo._mint auto-generates tokenId)
        tokenId = ERC721Repo._mint(recipient);

        // Create position with current reward debt
        SeigniorageNFTVaultRepo._createPosition(
            layout, tokenId, originalShares, effectiveShares, bonusMultiplier, block.timestamp + lockDuration
        );

        emit NewLock(tokenId, recipient, originalShares, bonusMultiplier, block.timestamp + lockDuration);
    }

    function _calcBonusMultiplier(uint256 lockDuration_) internal view returns (uint256 bonusMultiplier_) {
        BondTerms memory terms = _bondTerms();

        // Expected invariant, but guard to avoid division-by-zero.
        if (terms.maxLockDuration <= terms.minLockDuration) {
            return ONE_WAD + terms.maxBonusPercentage;
        }

        uint256 normalized =
            ((lockDuration_ - terms.minLockDuration) * ONE_WAD) / (terms.maxLockDuration - terms.minLockDuration);
        uint256 curveFactor = (normalized * normalized) / ONE_WAD;

        uint256 bonus;
        if (terms.maxBonusPercentage >= terms.minBonusPercentage) {
            bonus = terms.minBonusPercentage + ((terms.maxBonusPercentage - terms.minBonusPercentage) * curveFactor)
                / ONE_WAD;
        } else {
            bonus = terms.maxBonusPercentage;
        }

        bonusMultiplier_ = ONE_WAD + bonus;
    }

    /* ---------------------------------------------------------------------- */
    /*                                Unlock                                  */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageNFTVault
     * @dev Calls DETF.claimLiquidity() to extract value from the 80/20 pool.
     *      The DETF handles pool withdrawal and sends rate target tokens to recipient.
     */
    function unlock(uint256 tokenId, address recipient) external lock returns (uint256 lpAmount) {
        _validateUnlockCaller(tokenId, recipient);

        SeigniorageNFTVaultRepo.Storage storage layout = SeigniorageNFTVaultRepo._layout();

        uint256 unlockTime = SeigniorageNFTVaultRepo._unlockTimeOf(layout, tokenId);
        if (block.timestamp < unlockTime) {
            revert LockDurationNotExpired(block.timestamp, unlockTime);
        }

        // Update and harvest rewards
        SeigniorageNFTVaultRepo._updateGlobalRewards(layout);
        uint256 rewards = _harvestRewardsInternal(layout, tokenId, recipient);

        // Use the canonical share ledger (effectiveShares) for principal redemption.
        uint256 shares = SeigniorageNFTVaultRepo._effectiveSharesOf(layout, tokenId);

        // Convert shares back to LP amount
        lpAmount = SeigniorageNFTVaultRepo._convertToAssets(layout, shares);

        // Remove position and burn NFT
        SeigniorageNFTVaultRepo._removePosition(layout, tokenId);

        // If the DETF is unlocking on behalf of the bond holder (allowed by _validateUnlockCaller),
        // the ERC721 burn still requires approval. Grant a one-off approval so the burn can proceed.
        if (msg.sender == address(layout.detfToken)) {
            ERC721Repo.Storage storage nftLayout = ERC721Repo._layout();
            nftLayout.approvedForTokenId[tokenId] = msg.sender;
        }
        ERC721Repo._burn(tokenId);

        // Call DETF to claim liquidity from the 80/20 pool
        // DETF removes liquidity, extracts reserve vault as rate target, sends to recipient
        lpAmount = layout.detfToken.claimLiquidity(lpAmount, recipient);

        emit Unlock(tokenId, recipient, lpAmount, rewards);
    }

    function _validateOwnership(uint256 tokenId_) internal view {
        address owner = ERC721Repo._ownerOf(tokenId_);
        if (owner != msg.sender) revert NotBondHolder(owner, msg.sender);
    }

    function _validateUnlockCaller(uint256 tokenId_, address recipient_) internal view {
        address owner = ERC721Repo._ownerOf(tokenId_);
        if (owner == msg.sender) return;

        // Allow the DETF (vault owner) to call unlock on behalf of the bond holder,
        // but only to the actual bond holder as the recipient.
        if (msg.sender == address(SeigniorageNFTVaultRepo._detfToken()) && recipient_ == owner) return;

        revert NotBondHolder(owner, msg.sender);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Withdraw Rewards                             */
    /* ---------------------------------------------------------------------- */

    /**
     * @inheritdoc ISeigniorageNFTVault
     */
    function withdrawRewards(uint256 tokenId, address recipient) external lock returns (uint256 rewards) {
        _validateOwnership(tokenId);

        SeigniorageNFTVaultRepo.Storage storage layout = SeigniorageNFTVaultRepo._layout();
        SeigniorageNFTVaultRepo._updateGlobalRewards(layout);

        rewards = _harvestRewardsInternal(layout, tokenId, recipient);
        emit RewardsClaimed(tokenId, recipient, rewards);
    }

    /**
     * @dev Internal function to harvest rewards for a position.
     */
    function _harvestRewardsInternal(
        SeigniorageNFTVaultRepo.Storage storage layout_,
        uint256 tokenId_,
        address recipient_
    ) internal returns (uint256 rewards_) {
        uint256 effectiveShares = SeigniorageNFTVaultRepo._effectiveSharesOf(layout_, tokenId_);
        uint256 rewardPerShare = layout_.rewardPerShares;
        uint256 paidPerShare = SeigniorageNFTVaultRepo._userRewardPerSharePaid(layout_, tokenId_);

        if (rewardPerShare <= paidPerShare) {
            return 0;
        }

        rewards_ = (effectiveShares * (rewardPerShare - paidPerShare)) / ONE_WAD;
        if (rewards_ == 0) {
            return 0;
        }

        SeigniorageNFTVaultRepo._setUserRewardPerSharePaid(layout_, tokenId_, rewardPerShare);
        layout_.lastRewardTokenBalance -= rewards_;
        IERC20(address(layout_.rewardToken)).safeTransfer(recipient_, rewards_);
    }

    /* ---------------------------------------------------------------------- */
    /*                              View Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the pending rewards for a position.
     * @param tokenId The NFT token ID
     * @return pending Amount of pending reward tokens
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256 pending) {
        return SeigniorageNFTVaultRepo._earned(tokenId);
    }

    /**
     * @notice Returns the lock info for a position.
     * @param tokenId The NFT token ID
     * @return info The LockInfo struct
     */
    function lockInfoOf(uint256 tokenId) external view returns (LockInfo memory info) {
        SeigniorageNFTVaultRepo.Storage storage layout = SeigniorageNFTVaultRepo._layout();

        uint256 originalShares = SeigniorageNFTVaultRepo._originalSharesOf(layout, tokenId);
        uint256 effectiveShares = SeigniorageNFTVaultRepo._effectiveSharesOf(layout, tokenId);
        uint256 bonusMultiplier = SeigniorageNFTVaultRepo._bonusMultiplierOf(layout, tokenId);

        info.sharesAwarded = originalShares;
        info.rewardPerShare = layout.rewardPerShares;
        // Return the multiplier used at lock-time (stable / exact), falling back for legacy positions.
        if (bonusMultiplier != 0) {
            info.bonusPercentage = bonusMultiplier;
        } else {
            info.bonusPercentage = originalShares > 0 ? (effectiveShares * ONE_WAD) / originalShares : ONE_WAD;
        }
        info.unlockTime = SeigniorageNFTVaultRepo._unlockTimeOf(layout, tokenId);
    }

    /**
     * @notice Returns the token URI for an NFT.
     * @param tokenId The NFT token ID
     * @return The token URI (base64 encoded JSON with SVG)
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 originalShares = SeigniorageNFTVaultRepo._originalSharesOf(tokenId);
        if (originalShares == 0) revert PositionNotFound(tokenId);
        return SeigniorageNFTVaultRepo._generateTokenURI(tokenId);
    }

    /**
     * @notice Returns total effective shares across all positions.
     * @return Total effective shares
     */
    function totalShares() external view returns (uint256) {
        return SeigniorageNFTVaultRepo._totalShares();
    }

    /**
     * @notice Returns the current accumulated reward per share.
     * @return Accumulated reward per share (scaled by 1e18)
     */
    function rewardPerShares() external view returns (uint256) {
        return SeigniorageNFTVaultRepo._rewardPerShares();
    }

    function currentRewardPerShare() external view returns (uint256) {
        return SeigniorageNFTVaultRepo._rewardPerShares();
    }

    function minimumLockDuration() external view returns (uint256) {
        return _bondTerms().minLockDuration;
    }

    function maximumLockDuration() external view returns (uint256) {
        return _bondTerms().maxLockDuration;
    }

    function minBonusPercentage() external view returns (uint256) {
        return _bondTerms().minBonusPercentage;
    }

    function maxBonusPercentage() external view returns (uint256) {
        return _bondTerms().maxBonusPercentage;
    }

    function rewardSharesOf(uint256 tokenId) external view returns (uint256) {
        return SeigniorageNFTVaultRepo._effectiveSharesOf(tokenId);
    }

    function rewardPerShareOf(uint256 tokenId) external view returns (uint256) {
        return SeigniorageNFTVaultRepo._userRewardPerSharePaid(tokenId);
    }

    function unlockTimeOf(uint256 tokenId) external view returns (uint256) {
        return SeigniorageNFTVaultRepo._unlockTimeOf(tokenId);
    }

    function bonusPercentageOf(uint256 tokenId) external view returns (uint256) {
        SeigniorageNFTVaultRepo.Storage storage layout = SeigniorageNFTVaultRepo._layout();
        uint256 originalShares = SeigniorageNFTVaultRepo._originalSharesOf(layout, tokenId);
        if (originalShares == 0) revert PositionNotFound(tokenId);

        uint256 multiplier = SeigniorageNFTVaultRepo._bonusMultiplierOf(layout, tokenId);
        if (multiplier == 0) {
            uint256 effectiveShares = SeigniorageNFTVaultRepo._effectiveSharesOf(layout, tokenId);
            multiplier = (effectiveShares * ONE_WAD) / originalShares;
        }
        return multiplier > ONE_WAD ? multiplier - ONE_WAD : 0;
    }

    /* ---------------------------------------------------------------------- */
    /*                        ERC721 Transfer Guards                          */
    /* ---------------------------------------------------------------------- */

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public virtual {
        if (to == address(SeigniorageNFTVaultRepo._detfToken())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(SeigniorageNFTVaultRepo._detfToken())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(SeigniorageNFTVaultRepo._detfToken())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._transferFrom(from, to, tokenId);
    }

    /**
     * @notice Returns the DETF token contract.
     * @return The DETF contract
     */
    function detfToken() external view returns (ISeigniorageDETF) {
        return SeigniorageNFTVaultRepo._detfToken();
    }

    /**
     * @notice Returns the LP token (BPT) contract.
     * @return The LP token contract
     */
    function lpToken() external view returns (IERC20) {
        return SeigniorageNFTVaultRepo._lpToken();
    }

    /**
     * @notice Returns the reward token (sRBT) contract.
     * @return The reward token contract
     */
    function rewardToken() external view returns (IERC20MintBurn) {
        return SeigniorageNFTVaultRepo._rewardToken();
    }

    /**
     * @notice Returns the claim token (rate target) contract.
     * @return The claim token contract
     */
    function claimToken() external view returns (IERC20) {
        return SeigniorageNFTVaultRepo._claimToken();
    }
}

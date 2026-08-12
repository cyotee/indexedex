// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";

import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFNFTVaultRepo} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultRepo.sol";
import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";
import {DETFNFTVaultService} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultService.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

/**
 * @title DETFNFTVaultTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of the Protocol NFT Vault.
 * @dev Manages NFT-based bonding positions with time-locked reward-token accrual.
 *      Users lock LP tokens for a duration and receive boosted reward shares.
 *      The DETF diamond owns this vault and is the only entity that can create lock positions.
 */
contract DETFNFTVaultTarget is DETFNFTVaultCommon, ReentrancyLockModifiers, MultiStepOwnableModifiers {
    // IDETFNFTVault
    using DETFNFTVaultRepo for DETFNFTVaultRepo.Storage;
    using ERC721Repo for ERC721Repo.Storage;
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    event NewLock(
        uint256 indexed tokenId, address indexed recipient, uint256 shares, uint256 bonusMultiplier, uint256 unlockTime
    );

    /* ---------------------------------------------------------------------- */
    /*                       Create Position (Owner Only)                     */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  * @dev Only the owner (DETF diamond) can call this function.
    //  */
    function createPosition(uint256 shares, uint256 lockDuration, address recipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 tokenId)
    {
        // Peer path: original = effective base = shares (LP); bonus applied to both.
        tokenId = _createPositionInternal(shares, shares, lockDuration, recipient);
    }

    /// @notice Open bond with LP principal + separate reward-weight base (before lock bonus).
    function createPositionWithEffectiveBase(
        uint256 originalShares,
        uint256 effectiveBase,
        uint256 lockDuration,
        address recipient
    ) external onlyOwner nonReentrant returns (uint256 tokenId) {
        tokenId = _createPositionInternal(originalShares, effectiveBase, lockDuration, recipient);
    }

    function _createPositionInternal(
        uint256 originalShares_,
        uint256 effectiveBase_,
        uint256 lockDuration_,
        address recipient_
    ) private returns (uint256 tokenId) {
        if (originalShares_ == 0) revert BaseSharesZero();
        if (effectiveBase_ == 0) revert BaseSharesZero();

        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();
        _validateLockDuration(layoutStruct, lockDuration_);

        uint256 bonusMultiplier = _calcBonusMultiplier(lockDuration_);
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);

        // Reward ledger weight = effectiveBase * lock bonus (PRD open-time mids path).
        uint256 effectiveShares = DETFBondNFTMathLib._calcEffectiveShares(effectiveBase_, bonusMultiplier);

        tokenId = ERC721Repo._mint(recipient_);
        DETFNFTVaultRepo._createPosition(
            layoutStruct,
            tokenId,
            originalShares_,
            effectiveShares,
            bonusMultiplier,
            block.timestamp + lockDuration_
        );

        emit NewLock(tokenId, recipient_, originalShares_, bonusMultiplier, block.timestamp + lockDuration_);
    }

    /// @notice Mints and records the protocol-owned NFT (once).
    function initializeDETFNFT() external onlyOwner nonReentrant returns (uint256 tokenId) {
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();

        tokenId = DETFNFTVaultRepo._detfNFTId(layoutStruct);
        if (tokenId != 0 && ERC721Repo._ownerOf(tokenId) != address(0)) {
            return tokenId;
        }

        tokenId = ERC721Repo._mint(address(this));
        DETFNFTVaultRepo._setDETFNFTId(layoutStruct, tokenId);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redeem Position                               */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function redeemPosition(uint256 tokenId, address recipient, uint256 deadline)
        external
        onlyOwner
        nonReentrant
        returns (uint256 wethOut)
    {
        if (DETFBondNFTMathLib._isDeadlineExceeded(deadline, block.timestamp)) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();

        // Cannot redeem protocol NFT normally
        if (_isDETFNFT(tokenId)) {
            revert DETFNFTRestricted(tokenId);
        }

        // Mature-only: public user close is DETF `closeBondMature`; this path is DETF-only.
        {
            uint256 unlockTime = layoutStruct.unlockTimeOf[tokenId];
            if (block.timestamp < unlockTime) {
                revert BondNotMature(unlockTime);
            }
        }

        // Update and harvest rewards
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);
        uint256 rewards = _harvestRewardsInternal(layoutStruct, tokenId, recipient);

        // Get BPT amount (LP) from the canonical share ledger (effectiveShares)
        uint256 lpAmount = DETFNFTVaultRepo._convertToAssets(layoutStruct, layoutStruct.effectiveSharesOf[tokenId]);
        DETFNFTVaultRepo._removePosition(layoutStruct, tokenId);

        // Grant approval for burn if DETF is calling
        if (msg.sender == address(layoutStruct.detf)) {
            ERC721Repo._layoutStruct().approvedForTokenId[tokenId] = msg.sender;
        }
        ERC721Repo._burn(tokenId);

        // Canonical Bond NFT → WETH redemption:
        // delegate to the DETF diamond, which custody-holds BPT and executes the pool unwind.
        wethOut = layoutStruct.detf.claimLiquidity(lpAmount, recipient);

        emit IDETFNFTVault.PositionRedeemed(tokenId, recipient, wethOut, rewards);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Claim Rewards                                 */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function claimRewards(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rewards) {
        // Bond holder OR package owner (DETF diamond orchestrating holder claim).
        address owner = ERC721Repo._ownerOf(tokenId);
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();
        if (!DETFBondNFTMathLib._isCallerOwner(owner, msg.sender) && msg.sender != address(layoutStruct.detf)) {
            revert NotBondHolder(owner, msg.sender);
        }

        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);

        rewards = _harvestRewardsInternal(layoutStruct, tokenId, recipient);

        emit IDETFNFTVault.RewardsClaimed(tokenId, recipient, rewards);
    }

    /**
     * @dev Internal function to harvest rewards for a position.
     *      Uses service library structs to avoid stack-too-deep.
     */
    function _harvestRewardsInternal(DETFNFTVaultRepo.Storage storage layoutStruct_, uint256 tokenId_, address recipient_)
        internal
        returns (uint256 rewards_)
    {
        // Build params struct to reduce stack usage (math fields only)
        DETFNFTVaultService.HarvestParams memory params = DETFNFTVaultService.HarvestParams({
            effectiveShares: layoutStruct_.effectiveSharesOf[tokenId_],
            rewardPerShares: layoutStruct_.rewardPerShares,
            paidPerShare: layoutStruct_.userRewardPerSharePaid[tokenId_]
        });

        //     // Calculate rewards using service
        DETFNFTVaultService.HarvestResult memory result = DETFNFTVaultService._calcHarvestRewards(params);

        if (!result.hasRewards) {
            return 0;
        }

        rewards_ = result.rewards;

        // Execute transfer using service
        DETFNFTVaultService._executeHarvestTransfer(layoutStruct_, tokenId_, recipient_, rewards_);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Protocol NFT Operations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Only callable by the DETF diamond owner.
     */
    function addToDETFNFT(uint256 tokenId, uint256 shares) external onlyOwner {
        if (tokenId != DETFNFTVaultRepo._detfNFTId()) {
            revert DETFNFTRestricted(tokenId);
        }

        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);
        DETFNFTVaultRepo._addToPosition(layoutStruct, tokenId, shares);
    }

    /// @notice Debit protocol-NFT principal 1:1 (original and effective). `tokenId` must be `detfNFTId`.
    function removeFromDETFNFT(uint256 tokenId, uint256 shares) external onlyOwner {
        if (tokenId != DETFNFTVaultRepo._detfNFTId()) {
            revert DETFNFTRestricted(tokenId);
        }

        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);
        DETFNFTVaultRepo._removeFromPosition(layoutStruct, tokenId, shares);
    }

    /**
     * @notice Sells a user bond NFT into the protocol-owned position.
     */
    function sellPositionToDetfNft(uint256 tokenId, address seller, address rewardsRecipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 principalShares, uint256 rewardsClaimed)
    {
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();

        // Cannot sell protocol NFT, and token must exist.
        if (_isDETFNFT(tokenId)) {
            revert DETFNFTRestricted(tokenId);
        }

        address owner = ERC721Repo._ownerOf(tokenId);
        if (owner != seller) {
            revert NotBondHolder(owner, seller);
        }

        principalShares = layoutStruct.originalSharesOf[tokenId];
        if (principalShares == 0) {
            revert PositionNotFound(tokenId);
        }

        {
            uint256 unlockTime = layoutStruct.unlockTimeOf[tokenId];
            if (block.timestamp < unlockTime) {
                revert BondNotMature(unlockTime);
            }
        }

        if (rewardsRecipient == address(0)) {
            rewardsRecipient = seller;
        }

        // Update + harvest rewards to recipient (per TASK.md).
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);
        rewardsClaimed = _harvestRewardsInternal(layoutStruct, tokenId, rewardsRecipient);

        // Remove the sold position (burns bonus shares by removing effectiveShares).
        DETFNFTVaultRepo._removePosition(layoutStruct, tokenId);

        // Transfer principal-only shares into the protocol NFT position.
        DETFNFTVaultRepo._addToPosition(layoutStruct, layoutStruct.detfNFTId, principalShares);

        // Burn the sold bond NFT.
        ERC721Repo._layoutStruct().approvedForTokenId[tokenId] = msg.sender;
        ERC721Repo._burn(tokenId);
    }


    /* ---------------------------------------------------------------------- */
    /*                          View Functions                                */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function getPosition(uint256 tokenId) external view returns (IDETFNFTVault.Position memory) {
        return _getPosition(tokenId);
    }

    /**
     * @notice Returns pending rewards for a position.
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return DETFNFTVaultRepo._earned(tokenId);
    }

    /**
     * @notice Returns the lock info for a position.
     */
    function lockInfoOf(uint256 tokenId) external view returns (IDETFNFTVault.LockInfo memory info) {
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();

        uint256 originalShares = DETFNFTVaultRepo._originalSharesOf(layoutStruct, tokenId);
        uint256 effectiveShares = DETFNFTVaultRepo._effectiveSharesOf(layoutStruct, tokenId);
        uint256 bonusMultiplier = DETFNFTVaultRepo._bonusMultiplierOf(layoutStruct, tokenId);

        info.sharesAwarded = originalShares;
        info.rewardPerShare = layoutStruct.rewardPerShares;
        info.bonusPercentage = bonusMultiplier != 0
            ? bonusMultiplier
            : (originalShares > 0 ? (effectiveShares * ONE_WAD) / originalShares : ONE_WAD);
        info.unlockTime = DETFNFTVaultRepo._unlockTimeOf(layoutStruct, tokenId);
    }

    /**
     * @notice Returns the token URI for an NFT.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 originalShares = DETFNFTVaultRepo._originalSharesOf(tokenId);
        if (originalShares == 0) revert PositionNotFound(tokenId);
        return DETFNFTVaultRepo._generateTokenURI(tokenId);
    }

    /**
     * @notice Returns total effective shares across all positions.
     */
    function totalShares() external view returns (uint256) {
        return DETFNFTVaultRepo._totalShares();
    }

    /**
     * @notice Returns the current accumulated reward per share.
     */
    function rewardPerShares() external view returns (uint256) {
        return DETFNFTVaultRepo._rewardPerShares();
    }

    /**
     * @notice Returns the DETF diamond.
     */
    function detf() external view returns (IDetf) {
        return DETFNFTVaultRepo._detf();
    }

    /**
     * @notice Returns the LP token (BPT) contract.
     */
    function lpToken() external view returns (IERC20) {
        return DETFNFTVaultRepo._lpToken();
    }

    /**
     * @notice Returns the reward token contract.
     */
    function rewardToken() external view returns (IERC20) {
        return DETFNFTVaultRepo._rewardToken();
    }

    /**
     * @notice Returns the protocol-owned NFT ID.
     */
    function detfNFTId() external view returns (uint256) {
        return DETFNFTVaultRepo._detfNFTId();
    }

    /* ---------------------------------------------------------------------- */
    /*                   IDETFNFTVault View Functions                     */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function positionOf(uint256 tokenId) external view returns (IDETFNFTVault.Position memory position) {
        return _getPosition(tokenId);
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function originalSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return DETFNFTVaultRepo._originalSharesOf(tokenId);
    }

    function totalOriginalShares() external view returns (uint256 shares) {
        return DETFNFTVaultRepo._totalOriginalShares();
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function effectiveSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return DETFNFTVaultRepo._effectiveSharesOf(tokenId);
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function unlockTimeOf(uint256 tokenId) external view returns (uint256 unlockTime) {
        return DETFNFTVaultRepo._unlockTimeOf(tokenId);
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function isUnlocked(uint256 tokenId) external view returns (bool unlocked) {
        uint256 unlockTime = DETFNFTVaultRepo._unlockTimeOf(tokenId);
        return block.timestamp >= unlockTime;
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function convertToShares(uint256 lpAmount) external view returns (uint256 shares) {
        return DETFNFTVaultRepo._convertToShares(lpAmount);
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    /**
     * @notice Owner (DETF) transfers foreign ERC-20 held by this vault (reserve LP custody).
     */
    function transferHeldToken(IERC20 token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0) || address(token) == address(0)) revert NotAuthorized(address(0));
        if (amount == 0) revert BaseSharesZero();
        token.safeTransfer(to, amount);
    }

    function convertToAssets(uint256 shares) external view returns (uint256 lpAmount) {
        return DETFNFTVaultRepo._convertToAssets(shares);
    }

    // /**
    //  * @inheritdoc IDETFNFTVault
    //  */
    function reallocateDetfNftRewards(address recipient) external nonReentrant returns (uint256 amount) {
        DETFNFTVaultRepo.Storage storage layoutStruct = DETFNFTVaultRepo._layoutStruct();

        // Allow FeeCollector or the DETF diamond itself to collect the detf-owned NFT's accrued reward-token share.
        if (msg.sender != address(StandardVaultRepo._feeOracle().feeTo()) && msg.sender != address(layoutStruct.detf)) {
            revert NotAuthorized(msg.sender);
        }

        uint256 protocolTokenId = layoutStruct.detfNFTId;

        // Update global rewards
        DETFNFTVaultRepo._updateGlobalRewards(layoutStruct);

        // Harvest protocol NFT rewards
        amount = _harvestRewardsInternal(layoutStruct, protocolTokenId, recipient);

        emit IDETFNFTVault.DetfNftRewardsReallocated(recipient, amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                            ERC721 Functions                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Returns the number of NFTs owned by an address.
     */
    function balanceOf(address owner) public view returns (uint256 balance) {
        return ERC721Repo._balanceOf(owner);
    }

    /**
     * @notice Returns the owner of an NFT.
     */
    function ownerOf(uint256 tokenId) public view returns (address owner) {
        return ERC721Repo._ownerOf(tokenId);
    }

    /**
     * @notice Approves an address to transfer an NFT.
     */
    function approve(address to, uint256 tokenId) public virtual {
        ERC721Repo._approve(to, tokenId);
    }

    /**
     * @notice Returns the approved address for an NFT.
     */
    function getApproved(uint256 tokenId) public view returns (address operator) {
        return ERC721Repo._getApproved(tokenId);
    }

    /**
     * @notice Sets approval for all NFTs for an operator.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        ERC721Repo._setApprovalForAll(operator, approved);
    }

    /**
     * @notice Returns if an operator is approved for all NFTs of an owner.
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return ERC721Repo._isApprovedForAll(owner, operator);
    }

    /* ---------------------------------------------------------------------- */
    /*                        ERC721 Transfer Guards                          */
    /* ---------------------------------------------------------------------- */

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public virtual {
        if (to == address(DETFNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(DETFNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(DETFNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._transferFrom(from, to, tokenId);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";

import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolNFTVault} from "contracts/interfaces/IProtocolNFTVault.sol";
import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {ProtocolNFTVaultRepo} from "contracts/vaults/protocol/ProtocolNFTVaultRepo.sol";
import {ProtocolNFTVaultCommon} from "contracts/vaults/protocol/ProtocolNFTVaultCommon.sol";
import {ProtocolNFTVaultService} from "contracts/vaults/protocol/ProtocolNFTVaultService.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

/**
 * @title ProtocolNFTVaultTarget
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Implementation of the Protocol NFT Vault.
 * @dev Manages NFT-based bonding positions with time-locked reward-token accrual.
 *      Users lock LP tokens for a duration and receive boosted reward shares.
 *      The Protocol DETF owns this vault and is the only entity that can create lock positions.
 */
contract ProtocolNFTVaultTarget is ProtocolNFTVaultCommon, ReentrancyLockModifiers, MultiStepOwnableModifiers {
    // IProtocolNFTVault
    using ProtocolNFTVaultRepo for ProtocolNFTVaultRepo.Storage;
    using ERC721Repo for ERC721Repo.Storage;

    /* ---------------------------------------------------------------------- */
    /*                              Events                                    */
    /* ---------------------------------------------------------------------- */

    event NewLock(
        uint256 indexed tokenId, address indexed recipient, uint256 shares, uint256 bonusMultiplier, uint256 unlockTime
    );

    event ProtocolNFTSaleMarked(uint256 indexed tokenId);

    /* ---------------------------------------------------------------------- */
    /*                          State Variables                               */
    /* ---------------------------------------------------------------------- */

    // NOTE: `protocolNFTSold` moved to ProtocolNFTVaultRepo for upgrade-safe storage.

    /* ---------------------------------------------------------------------- */
    /*                       Create Position (Owner Only)                     */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  * @dev Only the owner (Protocol DETF) can call this function.
    //  */
    function createPosition(uint256 shares, uint256 lockDuration, address recipient)
        external
        onlyOwner
        lock
        returns (uint256 tokenId)
    {
        if (shares == 0) revert BaseSharesZero();

        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();
        _validateLockDuration(layout, lockDuration);

        uint256 bonusMultiplier = _calcBonusMultiplier(lockDuration);

        // Update global rewards before creating position
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);

        // Calculate effective shares with bonus
        uint256 effectiveShares = (shares * bonusMultiplier) / ONE_WAD;

        // Mint NFT
        tokenId = ERC721Repo._mint(recipient);

        // Create position with current reward debt
        ProtocolNFTVaultRepo._createPosition(
            layout, tokenId, shares, effectiveShares, bonusMultiplier, block.timestamp + lockDuration
        );

        emit NewLock(tokenId, recipient, shares, bonusMultiplier, block.timestamp + lockDuration);
    }

    /// @notice Mints and records the protocol-owned NFT (once).
    function initializeProtocolNFT() external onlyOwner lock returns (uint256 tokenId) {
        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        tokenId = ProtocolNFTVaultRepo._protocolNFTId(layout);
        if (ERC721Repo._ownerOf(tokenId) != address(0)) {
            return tokenId;
        }

        tokenId = ERC721Repo._mint(address(this));
        ProtocolNFTVaultRepo._setProtocolNFTId(layout, tokenId);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Redeem Position                               */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function redeemPosition(uint256 tokenId, address recipient, uint256 deadline)
        external
        lock
        returns (uint256 wethOut)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        // Validate caller using service struct
        {
            ProtocolNFTVaultService.RedeemParams memory params = ProtocolNFTVaultService.RedeemParams({
                tokenId: tokenId, recipient: recipient, caller: msg.sender, protocolDETF: address(layout.protocolDETF)
            });
            address owner = ERC721Repo._ownerOf(tokenId);
            if (!ProtocolNFTVaultService._validateRedeemCaller(params, owner)) {
                revert NotBondHolder(owner, msg.sender);
            }
        }

        // Cannot redeem protocol NFT normally
        if (_isProtocolNFT(tokenId)) {
            revert ProtocolNFTRestricted(tokenId);
        }

        // Check lock expiry
        {
            uint256 unlockTime = layout.unlockTimeOf[tokenId];
            if (block.timestamp < unlockTime) {
                revert LockDurationNotExpired(block.timestamp, unlockTime);
            }
        }

        // Update and harvest rewards
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);
        uint256 rewards = _harvestRewardsInternal(layout, tokenId, recipient);

        // Get BPT amount (LP) from the canonical share ledger (effectiveShares)
        uint256 lpAmount = ProtocolNFTVaultRepo._convertToAssets(layout, layout.effectiveSharesOf[tokenId]);
        ProtocolNFTVaultRepo._removePosition(layout, tokenId);

        // Grant approval for burn if DETF is calling
        if (msg.sender == address(layout.protocolDETF)) {
            ERC721Repo._layout().approvedForTokenId[tokenId] = msg.sender;
        }
        ERC721Repo._burn(tokenId);

        // Canonical Bond NFT → WETH redemption:
        // delegate to ProtocolDETF, which custody-holds BPT and executes the pool unwind.
        wethOut = layout.protocolDETF.claimLiquidity(lpAmount, recipient);

        emit IProtocolNFTVault.PositionRedeemed(tokenId, recipient, wethOut, rewards);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Claim Rewards                                 */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function claimRewards(uint256 tokenId, address recipient) external lock returns (uint256 rewards) {
        // Validate ownership
        address owner = ERC721Repo._ownerOf(tokenId);
        if (owner != msg.sender) {
            revert NotBondHolder(owner, msg.sender);
        }

        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);

        rewards = _harvestRewardsInternal(layout, tokenId, recipient);

        emit IProtocolNFTVault.RewardsClaimed(tokenId, recipient, rewards);
    }

    /**
     * @dev Internal function to harvest rewards for a position.
     *      Uses service library structs to avoid stack-too-deep.
     */
    function _harvestRewardsInternal(ProtocolNFTVaultRepo.Storage storage layout_, uint256 tokenId_, address recipient_)
        internal
        returns (uint256 rewards_)
    {
        // Build params struct to reduce stack usage
        ProtocolNFTVaultService.HarvestParams memory params = ProtocolNFTVaultService.HarvestParams({
            tokenId: tokenId_,
            recipient: recipient_,
            effectiveShares: layout_.effectiveSharesOf[tokenId_],
            rewardPerShares: layout_.rewardPerShares,
            paidPerShare: layout_.userRewardPerSharePaid[tokenId_]
        });

        //     // Calculate rewards using service
        ProtocolNFTVaultService.HarvestResult memory result = ProtocolNFTVaultService._calcHarvestRewards(params);

        if (!result.hasRewards) {
            return 0;
        }

        rewards_ = result.rewards;

        // Execute transfer using service
        ProtocolNFTVaultService._executeHarvestTransfer(layout_, tokenId_, recipient_, rewards_);
    }

    /* ---------------------------------------------------------------------- */
    /*                      Protocol NFT Operations                           */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Only callable by the Protocol DETF owner.
     */
    function addToProtocolNFT(uint256 tokenId, uint256 shares) external onlyOwner {
        if (tokenId != ProtocolNFTVaultRepo._protocolNFTId()) {
            revert ProtocolNFTRestricted(tokenId);
        }

        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);
        ProtocolNFTVaultRepo._addToPosition(layout, tokenId, shares);
    }

    /**
     * @notice Sells a user bond NFT into the protocol-owned position.
     */
    function sellPositionToProtocol(uint256 tokenId, address seller, address rewardsRecipient)
        external
        onlyOwner
        lock
        returns (uint256 principalShares, uint256 rewardsClaimed)
    {
        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        // Cannot sell protocol NFT, and token must exist.
        if (_isProtocolNFT(tokenId)) {
            revert ProtocolNFTRestricted(tokenId);
        }

        address owner = ERC721Repo._ownerOf(tokenId);
        if (owner != seller) {
            revert NotBondHolder(owner, seller);
        }

        principalShares = layout.originalSharesOf[tokenId];
        if (principalShares == 0) {
            revert PositionNotFound(tokenId);
        }

        if (rewardsRecipient == address(0)) {
            rewardsRecipient = seller;
        }

        // Update + harvest rewards to recipient (per TASK.md).
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);
        rewardsClaimed = _harvestRewardsInternal(layout, tokenId, rewardsRecipient);

        // Remove the sold position (burns bonus shares by removing effectiveShares).
        ProtocolNFTVaultRepo._removePosition(layout, tokenId);

        // Transfer principal-only shares into the protocol NFT position.
        ProtocolNFTVaultRepo._addToPosition(layout, layout.protocolNFTId, principalShares);

        // Burn the sold bond NFT.
        ERC721Repo._layout().approvedForTokenId[tokenId] = msg.sender;
        ERC721Repo._burn(tokenId);
    }

    /**
     * @notice Marks the protocol NFT as sold.
     * @dev Called when RICHIR is minted against this position.
     */
    function markProtocolNFTSold(uint256 tokenId) external onlyOwner {
        if (tokenId != ProtocolNFTVaultRepo._protocolNFTId()) {
            revert ProtocolNFTRestricted(tokenId);
        }

        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();
        ProtocolNFTVaultRepo._setProtocolNFTSold(layout, true);
        emit ProtocolNFTSaleMarked(tokenId);
    }

    /* ---------------------------------------------------------------------- */
    /*                          View Functions                                */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function getPosition(uint256 tokenId) external view returns (IProtocolNFTVault.Position memory) {
        return _getPosition(tokenId);
    }

    /**
     * @notice Returns pending rewards for a position.
     */
    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return ProtocolNFTVaultRepo._earned(tokenId);
    }

    /**
     * @notice Returns the lock info for a position.
     */
    function lockInfoOf(uint256 tokenId) external view returns (LockInfo memory info) {
        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        uint256 originalShares = ProtocolNFTVaultRepo._originalSharesOf(layout, tokenId);
        uint256 effectiveShares = ProtocolNFTVaultRepo._effectiveSharesOf(layout, tokenId);
        uint256 bonusMultiplier = ProtocolNFTVaultRepo._bonusMultiplierOf(layout, tokenId);

        info.sharesAwarded = originalShares;
        info.rewardPerShare = layout.rewardPerShares;
        info.bonusPercentage = bonusMultiplier != 0
            ? bonusMultiplier
            : (originalShares > 0 ? (effectiveShares * ONE_WAD) / originalShares : ONE_WAD);
        info.unlockTime = ProtocolNFTVaultRepo._unlockTimeOf(layout, tokenId);
    }

    /**
     * @notice Returns the token URI for an NFT.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 originalShares = ProtocolNFTVaultRepo._originalSharesOf(tokenId);
        if (originalShares == 0) revert PositionNotFound(tokenId);
        return ProtocolNFTVaultRepo._generateTokenURI(tokenId);
    }

    /**
     * @notice Returns total effective shares across all positions.
     */
    function totalShares() external view returns (uint256) {
        return ProtocolNFTVaultRepo._totalShares();
    }

    /**
     * @notice Returns the current accumulated reward per share.
     */
    function rewardPerShares() external view returns (uint256) {
        return ProtocolNFTVaultRepo._rewardPerShares();
    }

    /**
     * @notice Returns the Protocol DETF contract.
     */
    function protocolDETF() external view returns (IProtocolDETF) {
        return ProtocolNFTVaultRepo._protocolDETF();
    }

    /**
     * @notice Returns whether the protocol NFT has been sold.
     */
    function protocolNFTSold() external view returns (bool) {
        return ProtocolNFTVaultRepo._protocolNFTSold();
    }

    /**
     * @notice Returns the LP token (BPT) contract.
     */
    function lpToken() external view returns (IERC20) {
        return ProtocolNFTVaultRepo._lpToken();
    }

    /**
     * @notice Returns the reward token contract.
     */
    function rewardToken() external view returns (IERC20) {
        return ProtocolNFTVaultRepo._rewardToken();
    }

    /**
     * @notice Returns the protocol-owned NFT ID.
     */
    function protocolNFTId() external view returns (uint256) {
        return ProtocolNFTVaultRepo._protocolNFTId();
    }

    /* ---------------------------------------------------------------------- */
    /*                   IProtocolNFTVault View Functions                     */
    /* ---------------------------------------------------------------------- */

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function positionOf(uint256 tokenId) external view returns (IProtocolNFTVault.Position memory position) {
        return _getPosition(tokenId);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function originalSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return ProtocolNFTVaultRepo._originalSharesOf(tokenId);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function effectiveSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return ProtocolNFTVaultRepo._effectiveSharesOf(tokenId);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function unlockTimeOf(uint256 tokenId) external view returns (uint256 unlockTime) {
        return ProtocolNFTVaultRepo._unlockTimeOf(tokenId);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function isUnlocked(uint256 tokenId) external view returns (bool unlocked) {
        uint256 unlockTime = ProtocolNFTVaultRepo._unlockTimeOf(tokenId);
        return block.timestamp >= unlockTime;
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function convertToShares(uint256 lpAmount) external view returns (uint256 shares) {
        return ProtocolNFTVaultRepo._convertToShares(lpAmount);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function convertToAssets(uint256 shares) external view returns (uint256 lpAmount) {
        return ProtocolNFTVaultRepo._convertToAssets(shares);
    }

    // /**
    //  * @inheritdoc IProtocolNFTVault
    //  */
    function reallocateProtocolRewards(address recipient) external returns (uint256 amount) {
        ProtocolNFTVaultRepo.Storage storage layout = ProtocolNFTVaultRepo._layout();

        // Allow FeeCollector or the Protocol DETF itself to collect the protocol NFT's accrued reward-token share.
        if (msg.sender != address(StandardVaultRepo._feeOracle().feeTo()) && msg.sender != address(layout.protocolDETF)) {
            revert NotAuthorized(msg.sender);
        }

        uint256 protocolTokenId = layout.protocolNFTId;

        // Update global rewards
        ProtocolNFTVaultRepo._updateGlobalRewards(layout);

        // Harvest protocol NFT rewards
        amount = _harvestRewardsInternal(layout, protocolTokenId, recipient);

        emit IProtocolNFTVault.ProtocolRewardsReallocated(recipient, amount);
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
        if (to == address(ProtocolNFTVaultRepo._protocolDETF())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(ProtocolNFTVaultRepo._protocolDETF())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(ProtocolNFTVaultRepo._protocolDETF())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._transferFrom(from, to, tokenId);
    }
}

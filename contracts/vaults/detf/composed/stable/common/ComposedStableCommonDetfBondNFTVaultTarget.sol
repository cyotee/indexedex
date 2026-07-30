// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC721Repo} from "@crane/contracts/tokens/ERC721/ERC721Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";

import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/core/DETFBondNFTMathLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {ComposedStableCommonDetfBondNFTVaultRepo} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultRepo.sol";
import {ComposedStableCommonDetfBondNFTVaultCommon} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultCommon.sol";
import {ComposedStableCommonDetfBondNFTVaultService} from "contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultService.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

contract ComposedStableCommonDetfBondNFTVaultTarget is
    ComposedStableCommonDetfBondNFTVaultCommon,
    ReentrancyLockModifiers,
    MultiStepOwnableModifiers,
    IComposedStableCommonDetfBondNFTVault
{
    using ComposedStableCommonDetfBondNFTVaultRepo for ComposedStableCommonDetfBondNFTVaultRepo.Storage;
    using ERC721Repo for ERC721Repo.Storage;

    event NewLock(
        uint256 indexed tokenId, address indexed recipient, uint256 shares, uint256 bonusMultiplier, uint256 unlockTime
    );

    event DETFNFTSaleMarked(uint256 indexed tokenId);

    function createPosition(uint256 shares, uint256 lockDuration, address recipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 tokenId)
    {
        if (shares == 0) revert BaseSharesZero();

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        _validateLockDuration(layoutStruct, lockDuration);

        uint256 bonusMultiplier = _calcBonusMultiplier(lockDuration);
        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);

        uint256 effectiveShares = DETFBondNFTMathLib._calcEffectiveShares(shares, bonusMultiplier);
        tokenId = ERC721Repo._mint(recipient);

        ComposedStableCommonDetfBondNFTVaultRepo._createPosition(
            layoutStruct, tokenId, shares, effectiveShares, bonusMultiplier, block.timestamp + lockDuration
        );

        emit NewLock(tokenId, recipient, shares, bonusMultiplier, block.timestamp + lockDuration);
    }

    function initializeDETFNFT() external onlyOwner nonReentrant returns (uint256 tokenId) {
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();

        tokenId = ComposedStableCommonDetfBondNFTVaultRepo._detfNFTId(layoutStruct);
        if (ERC721Repo._ownerOf(tokenId) != address(0)) {
            return tokenId;
        }

        tokenId = ERC721Repo._mint(address(this));
        ComposedStableCommonDetfBondNFTVaultRepo._setDETFNFTId(layoutStruct, tokenId);
        ComposedStableCommonDetfBondNFTVaultRepo._createPosition(layoutStruct, tokenId, 0, 0, ONE_WAD, 0);
    }

    function redeemPosition(uint256 tokenId, address recipient, uint256 deadline)
        external
        nonReentrant
        returns (uint256 wethOut)
    {
        if (DETFBondNFTMathLib._isDeadlineExceeded(deadline, block.timestamp)) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();

        {
            ComposedStableCommonDetfBondNFTVaultService.RedeemParams memory params =
                ComposedStableCommonDetfBondNFTVaultService.RedeemParams({
                    tokenId: tokenId,
                    recipient: recipient,
                    caller: msg.sender,
                    detf: address(layoutStruct.detf)
                });
            address owner = ERC721Repo._ownerOf(tokenId);
            if (!ComposedStableCommonDetfBondNFTVaultService._validateRedeemCaller(params, owner)) {
                revert NotBondHolder(owner, msg.sender);
            }
        }

        if (_isDETFNFT(tokenId)) {
            revert DETFNFTRestricted(tokenId);
        }

        {
            uint256 unlockTime = layoutStruct.unlockTimeOf[tokenId];
            if (DETFBondNFTMathLib._isUnlockPending(unlockTime, block.timestamp)) {
                revert LockDurationNotExpired(block.timestamp, unlockTime);
            }
        }

        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);
        uint256 rewards = _harvestRewardsInternal(layoutStruct, tokenId, recipient);

        uint256 lpAmount =
            ComposedStableCommonDetfBondNFTVaultRepo._convertToAssets(layoutStruct, layoutStruct.effectiveSharesOf[tokenId]);
        ComposedStableCommonDetfBondNFTVaultRepo._removePosition(layoutStruct, tokenId);

        if (msg.sender == address(layoutStruct.detf)) {
            ERC721Repo._layoutStruct().approvedForTokenId[tokenId] = msg.sender;
        }
        ERC721Repo._burn(tokenId);

        wethOut = layoutStruct.detf.claimLiquidity(lpAmount, recipient);

        emit IDETFNFTVault.PositionRedeemed(tokenId, recipient, wethOut, rewards);
    }

    function claimRewards(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rewards) {
        address owner = ERC721Repo._ownerOf(tokenId);
        if (!DETFBondNFTMathLib._isCallerOwner(owner, msg.sender)) {
            revert NotBondHolder(owner, msg.sender);
        }

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);

        rewards = _harvestRewardsInternal(layoutStruct, tokenId, recipient);
        emit IDETFNFTVault.RewardsClaimed(tokenId, recipient, rewards);
    }

    function _harvestRewardsInternal(
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct_,
        uint256 tokenId_,
        address recipient_
    ) internal returns (uint256 rewards_) {
        ComposedStableCommonDetfBondNFTVaultService.HarvestParams memory params =
            ComposedStableCommonDetfBondNFTVaultService.HarvestParams({
                tokenId: tokenId_,
                recipient: recipient_,
                effectiveShares: layoutStruct_.effectiveSharesOf[tokenId_],
                rewardPerShares: layoutStruct_.rewardPerShares,
                paidPerShare: layoutStruct_.userRewardPerSharePaid[tokenId_]
            });

        ComposedStableCommonDetfBondNFTVaultService.HarvestResult memory result =
            ComposedStableCommonDetfBondNFTVaultService._calcHarvestRewards(params);

        if (!result.hasRewards) {
            return 0;
        }

        rewards_ = result.rewards;
        ComposedStableCommonDetfBondNFTVaultService._executeHarvestTransfer(layoutStruct_, tokenId_, recipient_, rewards_);
    }

    function addToDETFNFT(uint256 tokenId, uint256 shares) external onlyOwner {
        if (tokenId != ComposedStableCommonDetfBondNFTVaultRepo._detfNFTId()) {
            revert DETFNFTRestricted(tokenId);
        }

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);
        ComposedStableCommonDetfBondNFTVaultRepo._addToPosition(layoutStruct, tokenId, shares);
    }

    function addToFeeRecipientNFT(uint256 tokenId, uint256 shares) external onlyOwner {
        if (tokenId != ComposedStableCommonDetfBondNFTVaultRepo._feeRecipientNFTId()) {
            revert PositionNotFound(tokenId);
        }

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);
        ComposedStableCommonDetfBondNFTVaultRepo._addToPosition(layoutStruct, tokenId, shares);
    }

    function sellPositionToDetfNft(uint256 tokenId, address seller, address rewardsRecipient)
        external
        onlyOwner
        nonReentrant
        returns (uint256 principalShares, uint256 rewardsClaimed)
    {
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();

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

        if (rewardsRecipient == address(0)) {
            rewardsRecipient = seller;
        }

        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);
        rewardsClaimed = _harvestRewardsInternal(layoutStruct, tokenId, rewardsRecipient);

        ComposedStableCommonDetfBondNFTVaultRepo._removePosition(layoutStruct, tokenId);
        ComposedStableCommonDetfBondNFTVaultRepo._addToPosition(layoutStruct, layoutStruct.detfNFTId, principalShares);

        ERC721Repo._layoutStruct().approvedForTokenId[tokenId] = msg.sender;
        ERC721Repo._burn(tokenId);
    }

    function markDETFNFTSold(uint256 tokenId) external onlyOwner {
        if (tokenId != ComposedStableCommonDetfBondNFTVaultRepo._detfNFTId()) {
            revert DETFNFTRestricted(tokenId);
        }

        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();
        ComposedStableCommonDetfBondNFTVaultRepo._setDETFNFTSold(layoutStruct, true);
        emit DETFNFTSaleMarked(tokenId);
    }

    function getPosition(uint256 tokenId) external view returns (IDETFNFTVault.Position memory) {
        return _getPosition(tokenId);
    }

    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._earned(tokenId);
    }

    function lockInfoOf(uint256 tokenId) external view returns (LockInfo memory info) {
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();

        uint256 originalShares = ComposedStableCommonDetfBondNFTVaultRepo._originalSharesOf(layoutStruct, tokenId);
        uint256 effectiveShares = ComposedStableCommonDetfBondNFTVaultRepo._effectiveSharesOf(layoutStruct, tokenId);
        uint256 bonusMultiplier = ComposedStableCommonDetfBondNFTVaultRepo._bonusMultiplierOf(layoutStruct, tokenId);

        info.sharesAwarded = originalShares;
        info.rewardPerShare = layoutStruct.rewardPerShares;
        info.bonusPercentage = bonusMultiplier != 0
            ? bonusMultiplier
            : (originalShares > 0 ? (effectiveShares * ONE_WAD) / originalShares : ONE_WAD);
        info.unlockTime = ComposedStableCommonDetfBondNFTVaultRepo._unlockTimeOf(layoutStruct, tokenId);
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        uint256 originalShares = ComposedStableCommonDetfBondNFTVaultRepo._originalSharesOf(tokenId);
        if (originalShares == 0) revert PositionNotFound(tokenId);
        return ComposedStableCommonDetfBondNFTVaultRepo._generateTokenURI(tokenId);
    }

    function totalShares() external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._totalShares();
    }

    function rewardPerShares() external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._rewardPerShares();
    }

    function detf() external view returns (IDetf) {
        return ComposedStableCommonDetfBondNFTVaultRepo._detf();
    }

    function detfNFTSold() external view returns (bool) {
        return ComposedStableCommonDetfBondNFTVaultRepo._detfNFTSold();
    }

    function lpToken() external view returns (IERC20) {
        return ComposedStableCommonDetfBondNFTVaultRepo._lpToken();
    }

    function rewardToken() external view returns (IERC20) {
        return ComposedStableCommonDetfBondNFTVaultRepo._rewardToken();
    }

    function detfNFTId() external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._detfNFTId();
    }

    function feeRecipientNFTId() external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._feeRecipientNFTId();
    }

    function deploymentTimestamp() external view returns (uint256) {
        return ComposedStableCommonDetfBondNFTVaultRepo._deploymentTimestamp();
    }

    function positionOf(uint256 tokenId) external view returns (IDETFNFTVault.Position memory position) {
        return _getPosition(tokenId);
    }

    function originalSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return ComposedStableCommonDetfBondNFTVaultRepo._originalSharesOf(tokenId);
    }

    function effectiveSharesOf(uint256 tokenId) external view returns (uint256 shares) {
        return ComposedStableCommonDetfBondNFTVaultRepo._effectiveSharesOf(tokenId);
    }

    function unlockTimeOf(uint256 tokenId) external view returns (uint256 unlockTime) {
        return ComposedStableCommonDetfBondNFTVaultRepo._unlockTimeOf(tokenId);
    }

    function isUnlocked(uint256 tokenId) external view returns (bool unlocked) {
        uint256 unlockTime = ComposedStableCommonDetfBondNFTVaultRepo._unlockTimeOf(tokenId);
        return block.timestamp >= unlockTime;
    }

    function convertToShares(uint256 lpAmount) external view returns (uint256 shares) {
        return ComposedStableCommonDetfBondNFTVaultRepo._convertToShares(lpAmount);
    }

    function convertToAssets(uint256 shares) external view returns (uint256 lpAmount) {
        return ComposedStableCommonDetfBondNFTVaultRepo._convertToAssets(shares);
    }

    function reallocateDetfNftRewards(address recipient) external returns (uint256 amount) {
        ComposedStableCommonDetfBondNFTVaultRepo.Storage storage layoutStruct = ComposedStableCommonDetfBondNFTVaultRepo._layoutStruct();

        // Allow fee collector, configured protocol DETF address, or bond-vault owner (DETF diamond
        // after ownership transfer — family companions are deployed before the diamond exists).
        if (
            msg.sender != address(StandardVaultRepo._feeOracle().feeTo())
                && msg.sender != address(layoutStruct.detf)
                && msg.sender != MultiStepOwnableRepo._owner()
        ) {
            revert NotAuthorized(msg.sender);
        }

        uint256 protocolTokenId = layoutStruct.detfNFTId;
        ComposedStableCommonDetfBondNFTVaultRepo._updateGlobalRewards(layoutStruct);
        amount = _harvestRewardsInternal(layoutStruct, protocolTokenId, recipient);

        emit IDETFNFTVault.DetfNftRewardsReallocated(recipient, amount);
    }

    function balanceOf(address owner) public view returns (uint256 balance) {
        return ERC721Repo._balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        return ERC721Repo._ownerOf(tokenId);
    }

    function approve(address to, uint256 tokenId) public payable virtual {
        ERC721Repo._approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address operator) {
        return ERC721Repo._getApproved(tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        ERC721Repo._setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return ERC721Repo._isApprovedForAll(owner, operator);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public payable virtual {
        if (to == address(ComposedStableCommonDetfBondNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId, data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public payable virtual {
        if (to == address(ComposedStableCommonDetfBondNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public payable virtual {
        if (to == address(ComposedStableCommonDetfBondNFTVaultRepo._detf())) {
            revert IERC721Errors.ERC721InvalidReceiver(to);
        }
        ERC721Repo._transferFrom(from, to, tokenId);
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDetfErrors} from 'contracts/interfaces/IDetfErrors.sol';
import {ISeigniorageNFTVault} from 'contracts/interfaces/ISeigniorageNFTVault.sol';
import {DETFBondNFTMathLib} from 'contracts/vaults/detf/core/DETFBondNFTMathLib.sol';
import {ISeigniorageBondNFT} from 'contracts/vaults/seigniorage/nft/ISeigniorageBondNFT.sol';
import {BondTerms} from 'contracts/interfaces/VaultFeeTypes.sol';
import {ERC721Repo} from '@crane/contracts/tokens/ERC721/ERC721Repo.sol';
import {MultiStepOwnableRepo} from '@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol';
import {SeigniorageBondNFTRepo} from 'contracts/vaults/seigniorage/nft/SeigniorageBondNFTRepo.sol';
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {SeigniorageBondNFTCommon} from 'contracts/vaults/seigniorage/nft/SeigniorageBondNFTCommon.sol';

contract SeigniorageBondNFTTarget is SeigniorageBondNFTCommon, ReentrancyLockModifiers, MultiStepOwnableModifiers, ISeigniorageBondNFT {

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
        if (shares == 0) revert BaseSharesZero();
        BondTerms memory terms = _bondTerms();
        SeigniorageBondNFTRepo.Storage storage layoutStruct = SeigniorageBondNFTRepo._layoutStruct();
        _validateLockDuration(terms, lockDuration);

        uint256 bonusMultiplier = _calcBonusMultiplier(terms, lockDuration);

        // Update global rewards before creating position
        SeigniorageBondNFTRepo._updateGlobalRewards(layoutStruct);

        // Calculate effective shares with bonus
        uint256 effectiveShares = DETFBondNFTMathLib._calcEffectiveShares(shares, bonusMultiplier);

        // Mint NFT
        tokenId = ERC721Repo._mint(recipient);

        // Create position with current reward debt
        SeigniorageBondNFTRepo._createPosition(
            layoutStruct, tokenId, shares, effectiveShares, bonusMultiplier, block.timestamp + lockDuration
        );

        emit NewBond(tokenId, recipient, shares, bonusMultiplier, block.timestamp + lockDuration);
    }

    function redeemPosition(uint256 tokenId, address recipient, uint256 deadline)
        external
        nonReentrant
        returns (uint256 wethOut)
    {
        if (DETFBondNFTMathLib._isDeadlineExceeded(deadline, block.timestamp)) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SeigniorageBondNFTRepo.Storage storage layoutStruct = SeigniorageBondNFTRepo._layoutStruct();

        // Validate caller using service struct
        {
            RedeemParams memory params = RedeemParams({
                tokenId: tokenId,
                recipient: recipient,
                caller: msg.sender,
                detf: address(MultiStepOwnableRepo._owner())
            });
            address owner = ERC721Repo._ownerOf(tokenId);
            if (!_validateRedeemCaller(params, owner)) {
                revert NotBondHolder(owner, msg.sender);
            }
        }

        // Cannot redeem protocol NFT normally
        if (_isDETFOwnedNFT(tokenId)) {
            revert IDetfErrors.DETFNFTRestricted(tokenId);
        }

        // Check lock expiry
        {
            uint256 unlockTime = layoutStruct.unlockTimeOf[tokenId];
            if (DETFBondNFTMathLib._isUnlockPending(unlockTime, block.timestamp)) {
                revert ISeigniorageNFTVault.LockDurationNotExpired(block.timestamp, unlockTime);
            }
        }

        // Update and harvest rewards
        SeigniorageBondNFTRepo._updateGlobalRewards(layoutStruct);
        _harvestRewardsInternal(layoutStruct, tokenId, recipient);

        // // Get BPT amount (LP) from the canonical share ledger (effectiveShares)
        // uint256 lpAmount = DETFNFTVaultRepo._convertToAssets(layoutStruct, layoutStruct.effectiveSharesOf[tokenId]);
        // DETFNFTVaultRepo._removePosition(layoutStruct, tokenId);

        // // Grant approval for burn if DETF is calling
        // if (msg.sender == address(layoutStruct.detf)) {
        //     ERC721Repo._layoutStruct().approvedForTokenId[tokenId] = msg.sender;
        // }
        // ERC721Repo._burn(tokenId);

        // // Canonical Bond NFT → WETH redemption:
        // // delegate to the DETF diamond, which custody-holds BPT and executes the pool unwind.
        // wethOut = layoutStruct.detf.claimLiquidity(lpAmount, recipient);

        // emit IDETFNFTVault.PositionRedeemed(tokenId, recipient, wethOut, rewards);
    }

}
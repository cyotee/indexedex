// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/inventory/IDetfSelfNftInventoryPolicy.sol";

/// @notice Shared bond / detf-NFT lifecycle helpers for true DETFs.
/// @dev Protocol BPT compound is **DETF-orchestrated** (see `DETFProtocolCompoundLib`).
///      Callers that compound detf-owned NFT rewards own the full pipeline after harvest:
///      single-sided DETF join → credit BPT via `_addReservePoolBptToDetfNft`.
///      Preferred pull pattern: harvest only on the successful compound path so join
///      failure leaves pending rewards intact (lazy hooks must not fail the outer user path).
library DETFBondLifecycleLib {
    using BetterSafeERC20 for IERC20;

    error NoSeigniorageToCapture();

    function _createBondPosition(
        IDetfSelfNftInventoryPolicy vault_,
        uint256 shares_,
        uint256 lockDuration_,
        address recipient_
    ) internal returns (uint256 tokenId_) {
        if (recipient_ == address(0)) {
            recipient_ = msg.sender;
        }

        tokenId_ = vault_.createPosition(shares_, lockDuration_, recipient_);
    }

    function _sellPositionToRebasingClaim(
        IDetfSelfNftInventoryPolicy vault_,
        IRebasingClaimToken rebasingClaimToken_,
        uint256 tokenId_,
        address seller_,
        address recipient_
    ) internal returns (uint256 principalShares_, uint256 rebasingClaimMinted_) {
        principalShares_ = _sellPositionToDetfNft(vault_, tokenId_, seller_, recipient_);

        rebasingClaimMinted_ = rebasingClaimToken_.mintFromNFTSale(principalShares_, recipient_);
    }

    function _sellPositionToDetfNft(
        IDetfSelfNftInventoryPolicy vault_,
        uint256 tokenId_,
        address seller_,
        address recipient_
    ) internal returns (uint256 principalShares_) {
        (principalShares_,) = vault_.sellPositionToDetfNft(tokenId_, seller_, recipient_);
    }

    /// @notice Harvest free DETF rewards from the detf-owned NFT to this contract.
    /// @dev Free-DETF harvest only — **not** protocol BPT compound. Compound remains
    ///      DETF-orchestrated: after a successful harvest on the compound path, the caller
    ///      must single-sided join DETF into the reserve and credit BPT with
    ///      `_addReservePoolBptToDetfNft`. Prefer not calling this until join will succeed
    ///      (or reverse on join failure) so reward debt never wipes without BPT credit.
    ///      Reverts `NoSeigniorageToCapture` when harvest returns zero.
    function _collectDetfNftRewards(IDetfSelfNftInventoryPolicy vault_) internal returns (uint256 rewardAmount_) {
        rewardAmount_ = vault_.reallocateDetfNftRewards(address(this));
        if (rewardAmount_ == 0) {
            revert NoSeigniorageToCapture();
        }
    }

    /// @notice Credit reserve BPT principal onto the detf-owned NFT after a successful join.
    /// @dev Stage 00 / Phase 1 compound step 6: family join produces `bptAmount_`, then
    ///      this helper approves + `addToDETFNFT`. Do not call if join failed.
    function _addReservePoolBptToDetfNft(
        IERC20 reservePoolToken_,
        IDetfSelfNftInventoryPolicy vault_,
        uint256 detfNftId_,
        uint256 bptAmount_
    ) internal {
        reservePoolToken_.forceApprove(address(vault_), bptAmount_);
        vault_.addToDETFNFT(detfNftId_, bptAmount_);
    }
}
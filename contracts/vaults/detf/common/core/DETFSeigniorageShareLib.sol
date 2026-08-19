// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

import {IDetfBondInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfBondInventoryPolicy.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";

/// @notice D2 fee/creator effective-share top-up. One formula; families must not clone it.
library DETFSeigniorageShareLib {
    uint256 internal constant ONE_WAD = 1e18;

    /// @notice Floor `mulDiv` deltas so ids 1 and 2 hold `f` and `c` of implied total `T`.
    /// @dev `O` is everyone except ids 1 and 2, after the O-changing event. Never negative.
    function _topUpDeltas(uint256 othersEffective_, uint256 feeToEffective_, uint256 creatorEffective_, uint256 f_, uint256 c_)
        internal
        pure
        returns (uint256 dFeeTo_, uint256 dCreator_)
    {
        if (othersEffective_ == 0 || f_ + c_ >= ONE_WAD) {
            return (0, 0);
        }
        if (f_ == 0 && c_ == 0) {
            return (0, 0);
        }
        uint256 impliedTotal_ = Math.mulDiv(othersEffective_, ONE_WAD, ONE_WAD - f_ - c_);
        uint256 feeToTarget_ = Math.mulDiv(impliedTotal_, f_, ONE_WAD);
        uint256 creatorTarget_ = Math.mulDiv(impliedTotal_, c_, ONE_WAD);
        dFeeTo_ = feeToTarget_ > feeToEffective_ ? feeToTarget_ - feeToEffective_ : 0;
        dCreator_ = creatorTarget_ > creatorEffective_ ? creatorTarget_ - creatorEffective_ : 0;
    }

    /// @notice Apply D2 on a live NFT vault after an O-changing event.
    function _topUpFeeCreatorShares(IDetfBondInventoryPolicy vault_, uint256 f_, uint256 c_) internal {
        uint256 feeToEff_ = vault_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorEff_ = vault_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 totalEff_ = vault_.totalShares();
        uint256 others_ = totalEff_ - feeToEff_ - creatorEff_;
        (uint256 dF_, uint256 dC_) = _topUpDeltas(others_, feeToEff_, creatorEff_, f_, c_);
        if (dF_ > 0) {
            vault_.addEffectiveSharesOnly(DETF_FEE_TO_BOND_NFT_ID, dF_);
        }
        if (dC_ > 0) {
            vault_.addEffectiveSharesOnly(DETF_CREATOR_BOND_NFT_ID, dC_);
        }
    }
}

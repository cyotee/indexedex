// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @title DETFFundedBondRepo
/// @notice Purchased bonds own staking gons; reserve LP has no per-bond allocation.
library DETFFundedBondRepo {
    bytes32 internal constant STORAGE_SLOT =
        bytes32(uint256(keccak256("indexedex.detf.funded.bonds")) - 1);

    struct Storage {
        address detf;
        IERC20 lpToken;
        bool reservedIdsWired;
        uint256 attributedGons;
        mapping(uint256 tokenId => StakingMath.BondPosition position) positions;
    }

    error InvalidInitialization();
    error UnfundedEscrow(uint256 held, uint256 attributed);

    /// @notice Resolve an explicit storage namespace.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly { layoutStruct_.slot := slot_ }
    }

    /// @notice Resolve the canonical storage namespace.
    function _layoutStruct() internal pure returns (Storage storage) { return _layoutStruct(STORAGE_SLOT); }

    /// @notice Initialize the owning DETF and its protocol-owned reserve LP.
    function _initialize(Storage storage layoutStruct_, address detf_, IERC20 lpToken_) internal {
        if (layoutStruct_.detf != address(0) || detf_ == address(0) || address(lpToken_) == address(0)) {
            revert InvalidInitialization();
        }
        layoutStruct_.detf = detf_;
        layoutStruct_.lpToken = lpToken_;
    }

    /// @notice Initialize canonical storage.
    function _initialize(address detf_, IERC20 lpToken_) internal {
        _initialize(_layoutStruct(), detf_, lpToken_);
    }

    /// @notice Attribute only measured funded gons to a fixed purchase.
    function _open(
        Storage storage layoutStruct_, uint256 tokenId_, uint256 principal_, uint256 gons_,
        uint256 duration_, uint256 heldGons_
    ) internal {
        layoutStruct_.positions[tokenId_] = StakingMath.BondPosition({
            principal: principal_, claimedPrincipal: 0, stakingGons: gons_,
            startTimestamp: block.timestamp, vestingDuration: duration_
        });
        layoutStruct_.attributedGons += gons_;
        _requireFunded(layoutStruct_, heldGons_);
    }

    /// @notice Open a purchase in canonical storage.
    function _open(uint256 tokenId_, uint256 principal_, uint256 gons_, uint256 duration_, uint256 heldGons_)
        internal
    {
        _open(_layoutStruct(), tokenId_, principal_, gons_, duration_, heldGons_);
    }

    /// @notice Every position's remaining gons must be physically held by the escrow.
    function _requireFunded(Storage storage layoutStruct_, uint256 heldGons_) internal view {
        if (heldGons_ < layoutStruct_.attributedGons) {
            revert UnfundedEscrow(heldGons_, layoutStruct_.attributedGons);
        }
    }

    /// @notice Check canonical escrow accounting.
    function _requireFunded(uint256 heldGons_) internal view { _requireFunded(_layoutStruct(), heldGons_); }
}

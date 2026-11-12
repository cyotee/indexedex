// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Migration lifecycle and configuration, separate from canonical supply and execution history.
library UniswapV4DetfMigrationRepo {
    using BetterSafeERC20 for IERC20;
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.uniswap.v4.migration"))) - 1);

    struct Storage {
        bool activated;
        address weth;
        address originalDtf;
        address rewardToken;
        address expectedSynchronizer;
        uint256 bootstrapSelfMinted;
        bytes frozen;
        mapping(address => uint256) donationInventory;
        mapping(address => uint256) residualInventory;
        mapping(address => uint256) operationFloor;
        bool budgetOpen;
        mapping(address => Migration.IndependentAllocation) allocations;
        mapping(address => Migration.IndependentIssuance) issuances;
        mapping(bytes32 => address) configuredOriginal;
        mapping(bytes32 => address) issuedOriginal;
        mapping(address => mapping(uint256 => Migration.NftEntitlement)) nftEntitlements;
        mapping(address => mapping(uint256 => Migration.NftSurrender)) nftSurrenders;
        mapping(address => mapping(uint256 => Migration.NftCustody)) nftCustodies;
        mapping(bytes32 => bool) nftOriginal;
        NftReceipt expectedNft;
        mapping(bytes32 => Migration.WeightedLiquidEntitlement) weightedLiquidEntitlements;
        mapping(bytes32 => Migration.WeightedLiquidSurrender) weightedLiquidSurrenders;
        uint256 ownerFirstBondTokenId;
        mapping(bytes32 => Migration.WeightedSyEntitlement) weightedSyEntitlements;
        mapping(bytes32 => Migration.WeightedSySurrender) weightedSySurrenders;
        mapping(bytes32 => Migration.DtfCustodySeEntitlement) dtfCustodySeEntitlements;
        mapping(bytes32 => Migration.DtfCustodySeSurrender) dtfCustodySeSurrenders;
    }

    struct NftReceipt {
        address collection;
        address holder;
        uint256 tokenId;
        bool accepted;
    }

    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage s_) {
        assembly { s_.slot := slot_ }
    }

    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    function _snapshot() internal view returns (Snapshot.Snapshot memory) {
        bytes memory frozen_ = _layoutStruct().frozen;
        if (frozen_.length == 0) revert Snapshot.SnapshotNotCaptured();
        return abi.decode(frozen_, (Snapshot.Snapshot));
    }

    /// @dev Both parent issuance routes settle participation under the parent lock BEFORE this call.
    /// Reuse the sole child exact-pull/stake/gons path, then remove operation-local approval.
    function _fundBond(uint256 credit_, address recipient_) internal returns (uint256 id_) {
        Storage storage m_ = _layoutStruct();
        address bond_ = address(ParentRepo._layoutStruct().bondNftVault);
        ERC20Repo._mint(address(this), credit_);
        IERC20(address(this)).forceApprove(bond_, credit_);
        m_.expectedSynchronizer = bond_;
        id_ = IUniswapV4DetfMigrationBondNFTVault(bond_).createMigrationPosition(credit_, recipient_);
        delete m_.expectedSynchronizer;
        IERC20(address(this)).forceApprove(bond_, 0);
    }
}

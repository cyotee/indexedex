// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {UniswapV4DetfMigrationRepo as MigrationRepo} from "../UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfMigrationRecoveryRepo as Repo} from "../UniswapV4DetfMigrationRecoveryRepo.sol";
import {IMigrationLegacyNft, IMigrationWeightedNft, IMigrationEarlierNft} from "./IMigrationLegacyNft.sol";
import {MigrationLegacyNftLib as NftLib} from "./MigrationLegacyNftLib.sol";
import {
    IMigrationWeightedClaims, IMigrationWeightedReceipt, IMigrationLegacyExchange,
    IMigrationEarlierClaims, IMigrationEarlierSale, IMigrationEarlierReceipt
} from "./IMigrationLegacyRecovery.sol";

/// @notice Finite admitted source calls. The parent supplies the common lock/current-owner guard.
library MigrationLegacyRecoveryLib {
    using BetterSafeERC20 for IERC20;

    address internal constant WEIGHTED_RECEIPT = 0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c;
    address internal constant WEIGHTED_DETF = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;
    address internal constant EARLIER_DETF = 0xaf0E1967c8F755c747615c5427108Bc549CA1122;
    address internal constant EARLIER_RECEIPT = 0x4AC89aD061A531FA62ddceED53520C2750113b01;
    address internal constant DTF = 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01;

    function requireCustody(address collection_, uint256 id_) internal view returns (uint256 original_) {
        NftLib.requireSource(collection_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.NftSurrender storage s_ = m_.nftSurrenders[collection_][id_];
        Migration.NftCustody storage c_ = m_.nftCustodies[collection_][id_];
        if (id_ < 3 || !s_.consumed || s_.configurationId == bytes32(0) || s_.originalUnits == 0
            || c_.collection != collection_ || c_.tokenId != id_ || c_.configurationId != s_.configurationId
            || Repo._layoutStruct().positions[collection_][id_].sold
            || IMigrationLegacyNft(collection_).ownerOf(id_) != address(this)) {
            revert Recovery.InvalidRecoveryCustody(collection_, id_);
        }
        return s_.originalUnits;
    }

    function claimWeighted(uint256 id_, Recovery.Stage stage_) internal {
        uint256 original_ = requireCustody(NftLib.WEIGHTED, id_);
        IMigrationWeightedNft.Position memory p_ = IMigrationWeightedNft(NftLib.WEIGHTED).positionOf(id_);
        if (p_.principal != original_ || p_.claimedPrincipal > original_) {
            revert Recovery.InvalidRecoveryCustody(NftLib.WEIGHTED, id_);
        }
        IMigrationWeightedReceipt receipt_ = IMigrationWeightedReceipt(WEIGHTED_RECEIPT);
        uint256 g0_ = receipt_.gonsOf(address(this));
        uint256 principal_;
        uint256 rewards_;
        if (stage_ == Recovery.Stage.WeightedClaim) {
            (principal_, rewards_) = IMigrationWeightedClaims(NftLib.WEIGHTED).claimBond(id_, address(this));
        } else if (stage_ == Recovery.Stage.WeightedPrincipal) {
            principal_ = IMigrationWeightedClaims(NftLib.WEIGHTED).claimPrincipal(id_, address(this));
        } else {
            rewards_ = IMigrationWeightedClaims(NftLib.WEIGHTED).claimRewards(id_, address(this));
        }
        uint256 g1_ = receipt_.gonsOf(address(this));
        uint256 k_ = receipt_.stakingState().gonsPerUnit;
        uint256 amount_ = principal_ + rewards_;
        if (k_ == 0 || g1_ < g0_ || g1_ - g0_ != amount_ * k_
            || g1_ / k_ - g0_ / k_ != amount_) revert Recovery.RecoveryDeltaMismatch(WEIGHTED_RECEIPT);
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._reconcileWeighted(r_, WEIGHTED_RECEIPT, k_);
        r_.inventory[WEIGHTED_RECEIPT] += amount_;
        r_.weightedGons += g1_ - g0_;
        r_.positions[NftLib.WEIGHTED][id_].principalClaimed += principal_;
        r_.positions[NftLib.WEIGHTED][id_].rewardsClaimed += rewards_;
        // A final source claim may burn. Surrender history and its delivered bond remain untouched.
        emit Recovery.MigrationRecoveryClaimed(NftLib.WEIGHTED, id_, principal_, rewards_);
    }

    function unstakeWeighted(uint256 amount_, uint256 deadline_) internal {
        Repo.Storage storage r_ = Repo._layoutStruct();
        if (amount_ == 0 || r_.weightedGons == 0) {
            revert Recovery.RecoveryInventoryInsufficient(WEIGHTED_RECEIPT, amount_, r_.inventory[WEIGHTED_RECEIPT]);
        }
        IMigrationWeightedReceipt receipt_ = IMigrationWeightedReceipt(WEIGHTED_RECEIPT);
        uint256 g0_ = receipt_.gonsOf(address(this));
        uint256 b0_ = IERC20(WEIGHTED_DETF).balanceOf(address(this));
        uint256 out_ = receipt_.exchangeIn(
            WEIGHTED_RECEIPT, amount_, WEIGHTED_DETF, amount_, address(this), false, deadline_
        );
        uint256 g1_ = receipt_.gonsOf(address(this));
        uint256 k_ = receipt_.stakingState().gonsPerUnit;
        if (k_ == 0) revert Recovery.RecoveryDeltaMismatch(WEIGHTED_RECEIPT);
        // The admitted exchange synchronizes the source index. Authorize against the
        // pre-exit attributed gons at that index, not the old claim's native amount.
        // Any excess debit or later selected failure reverts the source call as well.
        Repo._reconcileWeighted(r_, WEIGHTED_RECEIPT, k_);
        Repo._debit(r_, WEIGHTED_RECEIPT, amount_);
        uint256 debit_ = requireGonDebit(g0_, g1_, r_.weightedGons);
        if (debit_ != (amount_ == g0_ / k_ ? g0_ : amount_ * k_)
            || out_ != amount_ || IERC20(WEIGHTED_DETF).balanceOf(address(this)) - b0_ != amount_) {
            revert Recovery.RecoveryDeltaMismatch(WEIGHTED_RECEIPT);
        }
        r_.weightedGons -= debit_;
        r_.inventory[WEIGHTED_DETF] += amount_;
        emit Recovery.MigrationRecoveryConverted(WEIGHTED_RECEIPT, WEIGHTED_DETF, amount_, amount_);
    }

    /// @dev Check actual debit, including legacy full-account dust retirement. Native budgeting
    /// alone cannot establish this floor if an unbooked sub-native remainder is ever present.
    function requireGonDebit(uint256 before_, uint256 after_, uint256 attributed_)
        internal pure returns (uint256 debit_)
    {
        debit_ = before_ - after_;
        if (debit_ > attributed_ || after_ < before_ - attributed_) {
            revert Recovery.RecoveryGonsProtected(debit_, attributed_);
        }
    }

    function convertWeighted(uint256 amount_, uint256 minimum_, uint256 deadline_) internal {
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._debit(r_, WEIGHTED_DETF, amount_);
        IERC20 token_ = IERC20(WEIGHTED_DETF);
        uint256 in0_ = token_.balanceOf(address(this));
        uint256 out0_ = IERC20(DTF).balanceOf(address(this));
        token_.forceApprove(WEIGHTED_DETF, amount_);
        uint256 out_ = IMigrationLegacyExchange(WEIGHTED_DETF).exchangeIn(
            WEIGHTED_DETF, amount_, DTF, minimum_, address(this), false, deadline_
        );
        token_.forceApprove(WEIGHTED_DETF, 0);
        if (in0_ - token_.balanceOf(address(this)) != amount_ || out_ == 0 || out_ < minimum_
            || IERC20(DTF).balanceOf(address(this)) - out0_ != out_) {
            revert Recovery.RecoveryDeltaMismatch(DTF);
        }
        r_.inventory[DTF] += out_;
        emit Recovery.MigrationRecoveryConverted(WEIGHTED_DETF, DTF, amount_, out_);
    }

    function claimEarlier(uint256 id_) internal {
        uint256 original_ = requireCustody(NftLib.EARLIER, id_);
        IMigrationEarlierNft nft_ = IMigrationEarlierNft(NftLib.EARLIER);
        if (nft_.getPosition(id_).originalShares != original_) {
            revert Recovery.InvalidRecoveryCustody(NftLib.EARLIER, id_);
        }
        uint256 before_ = IERC20(EARLIER_DETF).balanceOf(address(this));
        uint256 rewards_ = IMigrationEarlierClaims(NftLib.EARLIER).claimRewards(id_, address(this));
        if (IERC20(EARLIER_DETF).balanceOf(address(this)) - before_ != rewards_
            || nft_.ownerOf(id_) != address(this) || nft_.getPosition(id_).originalShares != original_) {
            revert Recovery.RecoveryDeltaMismatch(EARLIER_DETF);
        }
        Repo.Storage storage r_ = Repo._layoutStruct();
        r_.inventory[EARLIER_DETF] += rewards_;
        r_.positions[NftLib.EARLIER][id_].rewardsClaimed += rewards_;
        emit Recovery.MigrationRecoveryClaimed(NftLib.EARLIER, id_, 0, rewards_);
    }

    function sellEarlier(uint256 id_, uint256 minimum_) internal {
        uint256 original_ = requireCustody(NftLib.EARLIER, id_);
        IMigrationEarlierNft nft_ = IMigrationEarlierNft(NftLib.EARLIER);
        IMigrationEarlierNft.Position memory p_ = nft_.getPosition(id_);
        if (p_.originalShares != original_) revert Recovery.InvalidRecoveryCustody(NftLib.EARLIER, id_);
        if (block.timestamp < p_.unlockTime) revert Recovery.RecoveryPositionLocked(id_, p_.unlockTime);
        uint256 rewards0_ = IERC20(EARLIER_DETF).balanceOf(address(this));
        uint256 shares0_ = IMigrationEarlierReceipt(EARLIER_RECEIPT).sharesOf(address(this));
        uint256 retired_ = IMigrationEarlierSale(EARLIER_DETF).sellPositionToDetfNft(id_, address(this));
        uint256 shares_ = IMigrationEarlierReceipt(EARLIER_RECEIPT).sharesOf(address(this)) - shares0_;
        uint256 rewards_ = IERC20(EARLIER_DETF).balanceOf(address(this)) - rewards0_;
        p_ = nft_.getPosition(id_);
        if (retired_ != original_ || shares_ == 0 || shares_ < minimum_ || nft_.ownerOf(id_) != address(0)
            || p_.originalShares != 0 || p_.effectiveShares != 0 || p_.bonusMultiplier != 0
            || p_.unlockTime != 0 || p_.rewardDebt != 0) revert Recovery.RecoveryDeltaMismatch(EARLIER_RECEIPT);
        Repo.Storage storage r_ = Repo._layoutStruct();
        r_.inventory[EARLIER_DETF] += rewards_;
        r_.inventory[EARLIER_RECEIPT] += shares_;
        r_.positions[NftLib.EARLIER][id_].rewardsClaimed += rewards_;
        r_.positions[NftLib.EARLIER][id_].receiptShares = shares_;
        r_.positions[NftLib.EARLIER][id_].sold = true;
        emit Recovery.MigrationRecoverySold(id_, original_, shares_, rewards_);
    }
}

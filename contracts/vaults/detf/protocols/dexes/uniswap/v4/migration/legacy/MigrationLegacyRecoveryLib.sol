// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration as Migration} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "../interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {UniswapV4DetfMigrationRepo as MigrationRepo} from "../UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfMigrationRecoveryRepo as Repo} from "../UniswapV4DetfMigrationRecoveryRepo.sol";
import {IMigrationLegacyNft, IMigrationWeightedNft, IMigrationEarlierNft} from "./IMigrationLegacyNft.sol";
import {MigrationLegacyNftLib as NftLib} from "./MigrationLegacyNftLib.sol";
import {
    IMigrationWeightedClaims, IMigrationWeightedReceipt, IMigrationWeightedSynchronization,
    IMigrationWeightedSy, IMigrationLegacyExchange,
    IMigrationDtfCustodySe, IMigrationClaimVault,
    IMigrationEarlierClaims, IMigrationEarlierSale, IMigrationEarlierReceipt
} from "./IMigrationLegacyRecovery.sol";

/// @notice Finite admitted source calls. The parent supplies the common lock/current-owner guard.
library MigrationLegacyRecoveryLib {
    using BetterSafeERC20 for IERC20;

    address internal constant WEIGHTED_RECEIPT = 0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c;
    address internal constant WEIGHTED_DETF = 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7;
    address internal constant WEIGHTED_SY = 0xB55604CF4dcdABB362078e106D20F98512391EdF;
    address internal constant DTF_CUSTODY_SE = 0x2E9C1F705aB967c5Af59249203d7495bDabb223b;
    address internal constant CLAIM_VAULT = 0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0;
    address internal constant EARLIER_DETF = 0xaf0E1967c8F755c747615c5427108Bc549CA1122;
    address internal constant EARLIER_RECEIPT = 0x4AC89aD061A531FA62ddceED53520C2750113b01;
    address internal constant DTF = 0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01;

    struct EarlierReceiptObservation {
        uint256 rate;
        uint256 total;
        uint256 walletShares;
        uint256 custodyShares;
        uint256 walletDisplay;
        uint256 custodyDisplay;
    }

    function observeEarlierReceipt(address wallet_) private view returns (EarlierReceiptObservation memory o_) {
        IMigrationEarlierReceipt receipt_ = IMigrationEarlierReceipt(EARLIER_RECEIPT);
        o_.rate = receipt_.redemptionRate();
        o_.total = receipt_.totalShares();
        o_.walletShares = receipt_.sharesOf(wallet_);
        o_.custodyShares = receipt_.sharesOf(address(this));
        o_.walletDisplay = IERC20(EARLIER_RECEIPT).balanceOf(wallet_);
        o_.custodyDisplay = IERC20(EARLIER_RECEIPT).balanceOf(address(this));
    }

    /// @dev Only authenticated public calls determine q. No internal-share getter or
    /// displayed-balance cap: the source may transfer one more displayed unit than balanceOf.
    function pullEarlierReceipt(address wallet_, uint256 nativeAmount_, uint256 remaining_)
        internal returns (uint256 q_, uint256 rate_)
    {
        EarlierReceiptObservation memory before_ = observeEarlierReceipt(wallet_);
        rate_ = before_.rate;
        if (rate_ == 0 || nativeAmount_ == 0) revert Migration.EarlierReceiptCustodyFailed();
        q_ = Math.mulDiv(nativeAmount_, 1e27, rate_);
        if (q_ == 0 || q_ > remaining_) revert Migration.InvalidEarlierReceiptQuantity(q_, remaining_);
        if (!IERC20(EARLIER_RECEIPT).transferFrom(wallet_, address(this), nativeAmount_)) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
        EarlierReceiptObservation memory after_ = observeEarlierReceipt(wallet_);
        requireEarlierReceiptMeasurement(nativeAmount_, q_, before_, after_);
    }

    /// @dev Endpoint floors bound the ACTUAL internal movement, including both carries.
    /// Invert that interval using full precision; a singleton proves the transfer's
    /// intervening rate, which equal pre/post quote reads alone do not establish.
    /// Checked interval construction, H+1 and lower-bound increment must all fit uint256.
    function requireEarlierReceiptMeasurement(
        uint256 nativeAmount_, uint256 q_,
        EarlierReceiptObservation memory before_, EarlierReceiptObservation memory after_
    ) internal pure {
        if (before_.rate == 0 || before_.rate != after_.rate || before_.total != after_.total
            || after_.walletShares > before_.walletShares || after_.custodyShares < before_.custodyShares
            || after_.walletDisplay > before_.walletDisplay || after_.custodyDisplay < before_.custodyDisplay) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
        uint256 dw_ = before_.walletShares - after_.walletShares;
        uint256 dm_ = after_.custodyShares - before_.custodyShares;
        uint256 floor_ = q_ / 1e9;
        uint256 ceiling_ = floor_ + (q_ % 1e9 == 0 ? 0 : 1);
        if (dw_ < floor_ || dw_ > ceiling_ || dm_ < floor_ || dm_ > ceiling_) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
        uint256 max_ = dw_ > dm_ ? dw_ : dm_;
        uint256 min_ = dw_ < dm_ ? dw_ : dm_;
        if (max_ == 0) revert Migration.EarlierReceiptCustodyFailed();
        uint256 low_ = (max_ - 1) * 1e9 + 1;
        uint256 highPlusOne_ = (min_ + 1) * 1e9;
        if (low_ >= highPlusOne_) revert Migration.EarlierReceiptCustodyFailed();
        uint256 rateLow_ = Math.mulDiv(nativeAmount_, 1e27, highPlusOne_) + 1;
        uint256 rateHigh_ = Math.mulDiv(nativeAmount_, 1e27, low_);
        if (rateLow_ != before_.rate || rateHigh_ != before_.rate) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
        uint256 displayFloor_ = Math.mulDiv(q_, before_.rate, 1e27);
        uint256 displayCeiling_ = displayFloor_ + (mulmod(q_, before_.rate, 1e27) == 0 ? 0 : 1);
        dw_ = before_.walletDisplay - after_.walletDisplay;
        dm_ = after_.custodyDisplay - before_.custodyDisplay;
        if (dw_ < displayFloor_ || dw_ > displayCeiling_ || dm_ < displayFloor_ || dm_ > displayCeiling_) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
    }

    /// @dev E remains external NFT-sale shares; B remains standalone internal shares.
    /// Check the composed internal attribution on both booking routes without changing either unit.
    function requireEarlierReceiptInventory() internal view {
        Repo.Storage storage r_ = Repo._layoutStruct();
        uint256 externalInternal_ = r_.inventory[EARLIER_RECEIPT] * 1e9;
        if (r_.earlierReceiptInternalShares > type(uint256).max - externalInternal_) {
            revert Migration.EarlierReceiptCustodyFailed();
        }
    }

    /// @dev Parent holds its shared guard throughout settlement, measurement and subsequent bond funding.
    /// Role allocations to EITHER endpoint must settle before baselines; they are not surrender.
    function pullWeightedReceipt(address wallet_, uint256 nativeAmount_)
        internal returns (uint256 receivedGons_, uint256 k_)
    {
        IMigrationWeightedSynchronization(WEIGHTED_DETF).synchronizeRewards();
        IMigrationWeightedReceipt receipt_ = IMigrationWeightedReceipt(WEIGHTED_RECEIPT);
        IERC20 token_ = IERC20(WEIGHTED_RECEIPT);
        k_ = receipt_.stakingState().gonsPerUnit;
        uint256 walletGons_ = receipt_.gonsOf(wallet_);
        uint256 custodyGons_ = receipt_.gonsOf(address(this));
        if (k_ == 0 || token_.balanceOf(wallet_) != walletGons_ / k_
            || token_.balanceOf(address(this)) != custodyGons_ / k_) {
            revert Migration.WeightedReceiptCustodyFailed();
        }
        receivedGons_ = nativeAmount_ * k_;
        token_.safeTransferFrom(wallet_, address(this), nativeAmount_);
        uint256 walletAfter_ = receipt_.gonsOf(wallet_);
        uint256 custodyAfter_ = receipt_.gonsOf(address(this));
        if (receipt_.stakingState().gonsPerUnit != k_
            || walletAfter_ > walletGons_ || walletGons_ - walletAfter_ != receivedGons_
            || custodyAfter_ < custodyGons_ || custodyAfter_ - custodyGons_ != receivedGons_
            || token_.balanceOf(wallet_) != walletAfter_ / k_
            || token_.balanceOf(address(this)) != custodyAfter_ / k_) {
            revert Migration.WeightedReceiptCustodyFailed();
        }
    }

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

    function redeemWeightedSy(uint256 shares_, uint256 minimum_) internal {
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._debit(r_, WEIGHTED_SY, shares_);
        IERC20 sy_ = IERC20(WEIGHTED_SY);
        IMigrationWeightedReceipt receipt_ = IMigrationWeightedReceipt(WEIGHTED_RECEIPT);
        uint256 sharesBefore_ = sy_.balanceOf(address(this));
        uint256 gonsBefore_ = receipt_.gonsOf(address(this));
        uint256 wrapperBefore_ = receipt_.gonsOf(WEIGHTED_SY);
        uint256 out_ = IMigrationWeightedSy(WEIGHTED_SY).redeem(
            address(this), shares_, WEIGHTED_RECEIPT, minimum_, false
        );
        uint256 sharesAfter_ = sy_.balanceOf(address(this));
        uint256 gonsAfter_ = receipt_.gonsOf(address(this));
        uint256 wrapperAfter_ = receipt_.gonsOf(WEIGHTED_SY);
        uint256 k_ = receipt_.stakingState().gonsPerUnit;
        if (k_ == 0 || sharesAfter_ > sharesBefore_ || sharesBefore_ - sharesAfter_ != shares_
            || gonsAfter_ < gonsBefore_ || wrapperAfter_ > wrapperBefore_ || out_ == 0 || out_ < minimum_) {
            revert Recovery.RecoveryDeltaMismatch(WEIGHTED_SY);
        }
        uint256 received_ = gonsAfter_ - gonsBefore_;
        // Reproduce the archived source's two floors at its synchronized divisor, not a live
        // pre-call balance/rate or a simplified shares*1e36/k quote.
        uint256 expected_ = Math.mulDiv(shares_, Math.mulDiv(1e36, 1e18, k_), 1e18);
        if (out_ != expected_ || received_ != out_ * k_ || wrapperBefore_ - wrapperAfter_ != received_
            || gonsAfter_ / k_ - gonsBefore_ / k_ != out_) {
            revert Recovery.RecoveryDeltaMismatch(WEIGHTED_RECEIPT);
        }
        Repo._reconcileWeighted(r_, WEIGHTED_RECEIPT, k_);
        r_.weightedGons += received_;
        r_.inventory[WEIGHTED_RECEIPT] += out_;
        emit Recovery.MigrationRecoveryConverted(WEIGHTED_SY, WEIGHTED_RECEIPT, shares_, out_);
        emit Recovery.MigrationWeightedSyRedeemed(shares_, out_, received_, k_, shares_ * 1e36 - received_);
    }

    function redeemDtfCustodySe(uint256 shares_, uint256 minimum_) internal {
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._debit(r_, DTF_CUSTODY_SE, shares_);
        IERC20 sharesToken_ = IERC20(DTF_CUSTODY_SE);
        uint256 sharesBefore_ = sharesToken_.balanceOf(address(this));
        uint256 assetsBefore_ = IERC20(DTF).balanceOf(address(this));
        uint256 out_ = IMigrationDtfCustodySe(DTF_CUSTODY_SE).redeem(shares_, address(this), address(this));
        uint256 sharesAfter_ = sharesToken_.balanceOf(address(this));
        uint256 assetsAfter_ = IERC20(DTF).balanceOf(address(this));
        if (sharesAfter_ > sharesBefore_ || sharesBefore_ - sharesAfter_ != shares_
            || assetsAfter_ < assetsBefore_ || out_ == 0 || out_ < minimum_
            || assetsAfter_ - assetsBefore_ != out_) {
            revert Recovery.RecoveryDeltaMismatch(DTF_CUSTODY_SE);
        }
        r_.inventory[DTF] += out_;
        emit Recovery.MigrationRecoveryConverted(DTF_CUSTODY_SE, DTF, shares_, out_);
    }

    function redeemClaimVault(uint256 shares_, uint256 minimum_) internal {
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._debit(r_, CLAIM_VAULT, shares_);
        IERC20 sharesToken_ = IERC20(CLAIM_VAULT);
        uint256 sharesBefore_ = sharesToken_.balanceOf(address(this));
        uint256 supplyBefore_ = sharesToken_.totalSupply();
        uint256 assetsBefore_ = IERC20(WEIGHTED_SY).balanceOf(address(this));
        uint256 sourceBefore_ = IERC20(WEIGHTED_SY).balanceOf(CLAIM_VAULT);
        uint256 out_ = IMigrationClaimVault(CLAIM_VAULT).redeem(shares_, address(this), address(this));
        uint256 sharesAfter_ = sharesToken_.balanceOf(address(this));
        uint256 supplyAfter_ = sharesToken_.totalSupply();
        uint256 assetsAfter_ = IERC20(WEIGHTED_SY).balanceOf(address(this));
        uint256 sourceAfter_ = IERC20(WEIGHTED_SY).balanceOf(CLAIM_VAULT);
        if (sharesAfter_ > sharesBefore_ || sharesBefore_ - sharesAfter_ != shares_
            || supplyAfter_ > supplyBefore_ || supplyBefore_ - supplyAfter_ != shares_
            || assetsAfter_ < assetsBefore_ || out_ == 0 || out_ < minimum_
            || assetsAfter_ - assetsBefore_ != out_
            || sourceAfter_ > sourceBefore_ || sourceBefore_ - sourceAfter_ != out_) {
            revert Recovery.RecoveryDeltaMismatch(CLAIM_VAULT);
        }
        r_.inventory[WEIGHTED_SY] += out_;
        emit Recovery.MigrationRecoveryConverted(CLAIM_VAULT, WEIGHTED_SY, shares_, out_);
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
        requireEarlierReceiptInventory();
        r_.positions[NftLib.EARLIER][id_].rewardsClaimed += rewards_;
        r_.positions[NftLib.EARLIER][id_].receiptShares = shares_;
        r_.positions[NftLib.EARLIER][id_].sold = true;
        emit Recovery.MigrationRecoverySold(id_, original_, shares_, rewards_);
    }
}

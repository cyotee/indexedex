// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {UniswapV4DetfMigrationRecoveryRepo as Repo} from "./UniswapV4DetfMigrationRecoveryRepo.sol";
import {UniswapV4DetfMigrationRepo as MigrationRepo} from "./UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {MigrationLegacyNftLib as NftLib} from "./legacy/MigrationLegacyNftLib.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "./legacy/MigrationLegacyRecoveryLib.sol";
import {IMigrationWeightedReceipt, IMigrationEarlierReceipt} from "./legacy/IMigrationLegacyRecovery.sol";

/// @notice Selected recovery remains available after activation and follows actual Crane ownership.
contract UniswapV4DetfMigrationRecoveryTarget is UniswapV4DetfMigrationPolicy, Recovery {
    using AddressSetRepo for AddressSet;
    using BetterSafeERC20 for IERC20;

    function heldSeLpEntitlement(bytes32 originalId_)
        external view returns (Migration.HeldSeLpEntitlement memory)
    { return MigrationRepo._layoutStruct().heldSeLpEntitlements[originalId_]; }

    function heldSeLpSurrender(bytes32 originalId_)
        external view returns (Migration.HeldSeLpSurrender memory)
    { return MigrationRepo._layoutStruct().heldSeLpSurrenders[originalId_]; }

    function previewHeldSeLpSurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.HeldSeLpEntitlement storage config_ = m_.heldSeLpEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidHeldSeLpEntitlement(originalId_);
        Legacy.requireHeldSeLpSource(config_.original.source);
        Migration.HeldSeLpSurrender storage s_ = m_.heldSeLpSurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidHeldSeLpQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidHeldSeLpEntitlement(originalId_);
    }

    function surrenderMigrationHeldSeLp(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!MigrationRepo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewHeldSeLpSurrender(originalId_, amount_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.HeldSeLpEntitlement storage config_ = m_.heldSeLpEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalHeldSeLpWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(config_.original.source);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        // The authenticated sources return bool and spend even maximum allowances.
        if (!token_.transferFrom(msg.sender, address(this), amount_)) revert Migration.HeldSeLpCustodyFailed();
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.HeldSeLpCustodyFailed();
        }
        Migration.HeldSeLpSurrender storage s_ = m_.heldSeLpSurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        // Native18 fixed-source holding only. Neither preexisting balances nor
        // unrelated sources become credit, and no conversion/debit route is installed.
        Repo._layoutStruct().inventory[config_.original.source] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = MigrationRepo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationHeldSeLpSurrendered(
            originalId_, config_.configurationId, msg.sender, config_.original.source, amount_, credit_, bondTokenId_
        );
    }

    function earlierLiquidEntitlement(bytes32 originalId_)
        external view returns (Migration.EarlierLiquidEntitlement memory)
    { return MigrationRepo._layoutStruct().earlierLiquidEntitlements[originalId_]; }

    function earlierLiquidSurrender(bytes32 originalId_)
        external view returns (Migration.EarlierLiquidSurrender memory)
    { return MigrationRepo._layoutStruct().earlierLiquidSurrenders[originalId_]; }

    function previewEarlierLiquidSurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.EarlierLiquidEntitlement storage config_ = m_.earlierLiquidEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidEarlierLiquidEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.EARLIER_DETF) {
            revert Migration.UnsupportedEarlierLiquidSource(block.chainid, config_.original.source);
        }
        Migration.EarlierLiquidSurrender storage s_ = m_.earlierLiquidSurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidEarlierLiquidQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidEarlierLiquidEntitlement(originalId_);
    }

    function surrenderMigrationEarlierLiquid(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!MigrationRepo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewEarlierLiquidSurrender(originalId_, amount_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.EarlierLiquidEntitlement storage config_ = m_.earlierLiquidEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalEarlierLiquidWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(Legacy.EARLIER_DETF);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.EarlierLiquidCustodyFailed();
        }
        Migration.EarlierLiquidSurrender storage s_ = m_.earlierLiquidSurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        // Same native18 ED inventory as measured earlier-NFT rewards; add only this pull.
        // No ED conversion/debit/donation route is installed.
        Repo._layoutStruct().inventory[Legacy.EARLIER_DETF] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = MigrationRepo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationEarlierLiquidSurrendered(
            originalId_, config_.configurationId, msg.sender, amount_, credit_, bondTokenId_
        );
    }

    function migrationRecoveryInventory(address token_) external view returns (uint256) {
        return Repo._layoutStruct().inventory[token_];
    }

    function migrationRecoveryGons() external view returns (uint256) {
        return Repo._layoutStruct().weightedGons;
    }

    function migrationEarlierReceiptInternalShares() external view returns (uint256) {
        return Repo._layoutStruct().earlierReceiptInternalShares;
    }

    function earlierReceiptEntitlement(bytes32 originalId_)
        external view returns (Migration.EarlierReceiptEntitlement memory)
    { return MigrationRepo._layoutStruct().earlierReceiptEntitlements[originalId_]; }

    function earlierReceiptSurrender(bytes32 originalId_)
        external view returns (Migration.EarlierReceiptSurrender memory)
    { return MigrationRepo._layoutStruct().earlierReceiptSurrenders[originalId_]; }

    function previewEarlierReceiptSurrender(bytes32 originalId_, uint256 nativeAmount_)
        external view returns (uint256 credit_)
    {
        _requireEarlierReceipt(originalId_);
        uint256 rate_ = IMigrationEarlierReceipt(Legacy.EARLIER_RECEIPT).redemptionRate();
        if (rate_ == 0 || nativeAmount_ == 0) revert Migration.EarlierReceiptCustodyFailed();
        return _earlierReceiptCredit(originalId_, Math.mulDiv(nativeAmount_, 1e27, rate_));
    }

    function surrenderMigrationEarlierReceipt(
        bytes32 originalId_, uint256 nativeAmount_, uint256 minimum_, uint256 deadline_
    ) external nonReentrant returns (uint256 bondTokenId_, uint256 credit_) {
        if (!MigrationRepo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        _requireEarlierReceipt(originalId_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.EarlierReceiptEntitlement storage config_ = m_.earlierReceiptEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalEarlierReceiptWallet(msg.sender, config_.original.originalWallet);
        }
        Migration.EarlierReceiptSurrender storage s_ = m_.earlierReceiptSurrenders[originalId_];
        if (s_.remainingUnits == 0 || s_.remainingCredit == 0) {
            revert Migration.InvalidEarlierReceiptEntitlement(originalId_);
        }
        (uint256 q_, uint256 rate_) = Legacy.pullEarlierReceipt(msg.sender, nativeAmount_, s_.remainingUnits);
        credit_ = _earlierReceiptCredit(originalId_, q_);
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        s_.consumedUnits += q_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= q_;
        s_.remainingCredit -= credit_;
        Repo._layoutStruct().earlierReceiptInternalShares += q_;
        Legacy.requireEarlierReceiptInventory();
        // Measurement ends before funding/receiver effects. A later legitimate
        // ER donation is unbooked; it must not be attributed to this surrender.
        _realizeExpansionIfNeeded();
        bondTokenId_ = MigrationRepo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationEarlierReceiptSurrendered(
            originalId_, config_.configurationId, msg.sender, nativeAmount_, q_, rate_, credit_, bondTokenId_
        );
    }

    function _requireEarlierReceipt(bytes32 originalId_) private view {
        Migration.EarlierReceiptEntitlement storage config_ =
            MigrationRepo._layoutStruct().earlierReceiptEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidEarlierReceiptEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.EARLIER_RECEIPT) {
            revert Migration.UnsupportedEarlierReceiptSource(block.chainid, config_.original.source);
        }
    }

    function _earlierReceiptCredit(bytes32 originalId_, uint256 q_) private view returns (uint256 credit_) {
        Migration.EarlierReceiptSurrender storage s_ =
            MigrationRepo._layoutStruct().earlierReceiptSurrenders[originalId_];
        if (q_ == 0 || q_ > s_.remainingUnits) {
            revert Migration.InvalidEarlierReceiptQuantity(q_, s_.remainingUnits);
        }
        credit_ = q_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, q_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidEarlierReceiptEntitlement(originalId_);
    }

    function migrationNftRecovery(address collection_, uint256 tokenId_) external view returns (NftRecovery memory) {
        return Repo._layoutStruct().positions[collection_][tokenId_];
    }

    function weightedReceiptEntitlement(bytes32 originalId_)
        external view returns (Migration.WeightedReceiptEntitlement memory)
    { return MigrationRepo._layoutStruct().weightedReceiptEntitlements[originalId_]; }

    function weightedReceiptSurrender(bytes32 originalId_)
        external view returns (Migration.WeightedReceiptSurrender memory)
    { return MigrationRepo._layoutStruct().weightedReceiptSurrenders[originalId_]; }

    function previewWeightedReceiptSurrender(bytes32 originalId_, uint256 nativeAmount_)
        external view returns (uint256 credit_)
    {
        _requireWeightedReceipt(originalId_);
        uint256 k_ = IMigrationWeightedReceipt(Legacy.WEIGHTED_RECEIPT).stakingState().gonsPerUnit;
        if (k_ == 0) revert Migration.WeightedReceiptCustodyFailed();
        return _weightedReceiptCredit(originalId_, nativeAmount_ * k_);
    }

    function surrenderMigrationWeightedReceipt(
        bytes32 originalId_, uint256 nativeAmount_, uint256 minimum_, uint256 deadline_
    ) external nonReentrant returns (uint256 bondTokenId_, uint256 credit_) {
        if (!MigrationRepo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        _requireWeightedReceipt(originalId_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.WeightedReceiptEntitlement storage config_ = m_.weightedReceiptEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalWeightedReceiptWallet(msg.sender, config_.original.originalWallet);
        }
        Migration.WeightedReceiptSurrender storage s_ = m_.weightedReceiptSurrenders[originalId_];
        if (nativeAmount_ == 0 || s_.remainingUnits == 0 || s_.remainingCredit == 0) {
            revert Migration.InvalidWeightedReceiptEntitlement(originalId_);
        }
        // Protected WD settlement is inside the same reverting operation and BEFORE both
        // endpoint baselines. WS's own synchronization must not change the measured divisor.
        (uint256 q_, uint256 k_) = Legacy.pullWeightedReceipt(msg.sender, nativeAmount_);
        credit_ = _weightedReceiptCredit(originalId_, q_);
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        s_.consumedUnits += q_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= q_;
        s_.remainingCredit -= credit_;
        Repo.Storage storage r_ = Repo._layoutStruct();
        Repo._reconcileWeighted(r_, Legacy.WEIGHTED_RECEIPT, k_);
        r_.weightedGons += q_;
        r_.inventory[Legacy.WEIGHTED_RECEIPT] += nativeAmount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = MigrationRepo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationWeightedReceiptSurrendered(
            originalId_, config_.configurationId, msg.sender, nativeAmount_, q_, k_, credit_, bondTokenId_
        );
    }

    function _requireWeightedReceipt(bytes32 originalId_) private view {
        Migration.WeightedReceiptEntitlement storage config_ =
            MigrationRepo._layoutStruct().weightedReceiptEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidWeightedReceiptEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.WEIGHTED_RECEIPT) {
            revert Migration.UnsupportedWeightedReceiptSource(block.chainid, config_.original.source);
        }
    }

    function _weightedReceiptCredit(bytes32 originalId_, uint256 q_) private view returns (uint256 credit_) {
        Migration.WeightedReceiptSurrender storage s_ =
            MigrationRepo._layoutStruct().weightedReceiptSurrenders[originalId_];
        if (q_ == 0 || q_ > s_.remainingUnits) {
            revert Migration.InvalidWeightedReceiptQuantity(q_, s_.remainingUnits);
        }
        credit_ = q_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, q_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidWeightedReceiptEntitlement(originalId_);
    }

    function recoverMigrationNfts(Step[] calldata steps_, uint256 deadline_) external nonReentrant {
        MultiStepOwnableRepo._onlyOwner();
        _requireIdleChildren();
        NftLib.requireSource(NftLib.WEIGHTED);
        _requireActive(deadline_, steps_.length);
        for (uint256 i_; i_ < steps_.length; ++i_) {
            Step calldata step_ = steps_[i_];
            if (step_.stage <= Stage.WeightedRewards) {
                if (step_.amount != 0 || step_.minimum != 0) revert InvalidRecoveryStep();
                Legacy.claimWeighted(step_.tokenId, step_.stage);
            } else if (step_.stage == Stage.EarlierClaim || step_.stage == Stage.EarlierSale) {
                if (step_.amount != 0) revert InvalidRecoveryStep();
                if (step_.stage == Stage.EarlierClaim) {
                    if (step_.minimum != 0) revert InvalidRecoveryStep();
                    Legacy.claimEarlier(step_.tokenId);
                } else Legacy.sellEarlier(step_.tokenId, step_.minimum);
            } else {
                if (step_.tokenId != 0) revert InvalidRecoveryStep();
                if (step_.stage == Stage.WeightedUnstake) {
                    if (step_.minimum != 0) revert InvalidRecoveryStep();
                    Legacy.unstakeWeighted(step_.amount, deadline_);
                } else if (step_.stage == Stage.WeightedConvert) {
                    Legacy.convertWeighted(step_.amount, step_.minimum, deadline_);
                } else if (step_.stage == Stage.WeightedSyRedeem) {
                    Legacy.redeemWeightedSy(step_.amount, step_.minimum);
                } else if (step_.stage == Stage.DtfCustodySeRedeem) {
                    Legacy.redeemDtfCustodySe(step_.amount, step_.minimum);
                } else if (step_.stage == Stage.ClaimVaultRedeem) {
                    Legacy.redeemClaimVault(step_.amount, step_.minimum);
                } else _donateRecovery(step_.amount, step_.minimum);
            }
        }
        _syncAllExpectedHoldReserves();
    }

    function claimVaultEntitlement(bytes32 originalId_)
        external view returns (Migration.ClaimVaultEntitlement memory)
    { return MigrationRepo._layoutStruct().claimVaultEntitlements[originalId_]; }

    function claimVaultSurrender(bytes32 originalId_)
        external view returns (Migration.ClaimVaultSurrender memory)
    { return MigrationRepo._layoutStruct().claimVaultSurrenders[originalId_]; }

    function previewClaimVaultSurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.ClaimVaultEntitlement storage config_ = m_.claimVaultEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidClaimVaultEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.CLAIM_VAULT) {
            revert Migration.UnsupportedClaimVaultSource(block.chainid, config_.original.source);
        }
        Migration.ClaimVaultSurrender storage s_ = m_.claimVaultSurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidClaimVaultQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidClaimVaultEntitlement(originalId_);
    }

    function surrenderMigrationClaimVault(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!MigrationRepo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewClaimVaultSurrender(originalId_, amount_);
        MigrationRepo.Storage storage m_ = MigrationRepo._layoutStruct();
        Migration.ClaimVaultEntitlement storage config_ = m_.claimVaultEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalClaimVaultWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(Legacy.CLAIM_VAULT);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.ClaimVaultCustodyFailed();
        }
        Migration.ClaimVaultSurrender storage s_ = m_.claimVaultSurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        Repo._layoutStruct().inventory[Legacy.CLAIM_VAULT] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = MigrationRepo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationClaimVaultSurrendered(
            originalId_, config_.configurationId, msg.sender, amount_, credit_, bondTokenId_
        );
    }

    function _donateRecovery(uint256 amount_, uint256 minimum_) private {
        _requireNotDisabled();
        _requireReserveLive();
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        address token_ = Legacy.DTF;
        if (token_ == address(this) || !s_.donateTable.tokens._contains(token_)
            || (!s_.hookPairTokens._contains(token_) && !s_.hookStandardExchanges._contains(token_))) {
            revert Migration.InvalidGenesisLeg(token_);
        }
        Repo._debit(token_, amount_);
        uint256 lpBefore_ = IERC20(s_.hook).balanceOf(_bondLpHolder());
        _beginBudget();
        // This transfers only selected recovered capital into the existing reserve residual domain.
        // All other recovery inventory, older donation budgets and unsolicited balances stay floors.
        MigrationRepo._layoutStruct().operationFloor[token_] -= amount_;
        _sweepDustBody();
        _endBudget();
        uint256 lpOut_ = IERC20(s_.hook).balanceOf(_bondLpHolder()) - lpBefore_;
        if (lpOut_ == 0 || lpOut_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, lpOut_);
        emit MigrationRecoveryDonated(token_, amount_, lpOut_);
    }
}

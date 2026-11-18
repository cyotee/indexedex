// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721Receiver} from "@crane/contracts/interfaces/IERC721Receiver.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {IUniswapV4DetfMigration as Migration} from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {UniswapV4DetfMigrationWeightedPricingLib as PricingLib} from "./UniswapV4DetfMigrationWeightedPricingLib.sol";
import {IMigrationLegacyNft} from "./legacy/IMigrationLegacyNft.sol";
import {MigrationLegacyNftLib as NftLib} from "./legacy/MigrationLegacyNftLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "./legacy/MigrationLegacyRecoveryLib.sol";
import {UniswapV4DetfMigrationRecoveryRepo as RecoveryRepo} from "./UniswapV4DetfMigrationRecoveryRepo.sol";

/// @notice Permanent lifecycle reads and permissionless measured capital contributions.
contract UniswapV4DetfMigrationWeightedHookTarget is UniswapV4DetfMigrationPolicy {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    function migrationActivated() external view returns (bool) { return Repo._layoutStruct().activated; }
    function migrationOwnerFirstBondTokenId() external view returns (uint256) {
        return Repo._layoutStruct().ownerFirstBondTokenId;
    }
    function migrationSyRewardToken() external view returns (address) { return Repo._layoutStruct().rewardToken; }
    function migrationBootstrapSelfMinted() external view returns (uint256) {
        return Repo._layoutStruct().bootstrapSelfMinted;
    }
    function migrationDonationInventory(IERC20 token_) external view returns (uint256) {
        return Repo._layoutStruct().donationInventory[address(token_)];
    }
    function migrationWeightedPricing() external view returns (Pricing.Book memory) { return Repo._legacyWeightedPricing(); }
    function migrationWeightedPricingV3() external view returns (Pricing.BookV3 memory) { return Repo._weightedPricing(); }
    function previewOriginalCredit(uint256 eth_, uint256 dtf_) external view returns (uint256) {
        return PricingLib.evaluateOriginals(Repo._weightedPricing(), eth_, dtf_);
    }
    function independentAllocation(address recipient_) external view returns (Migration.IndependentAllocation memory) {
        return Repo._layoutStruct().allocations[recipient_];
    }
    function independentIssuance(address recipient_) external view returns (Migration.IndependentIssuance memory) {
        return Repo._layoutStruct().issuances[recipient_];
    }

    function weightedLiquidEntitlement(bytes32 originalId_)
        external view returns (Migration.WeightedLiquidEntitlement memory)
    { return Repo._layoutStruct().weightedLiquidEntitlements[originalId_]; }

    function weightedLiquidSurrender(bytes32 originalId_)
        external view returns (Migration.WeightedLiquidSurrender memory)
    { return Repo._layoutStruct().weightedLiquidSurrenders[originalId_]; }

    function previewWeightedLiquidSurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.WeightedLiquidEntitlement storage config_ = m_.weightedLiquidEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidWeightedLiquidEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.WEIGHTED_DETF) {
            revert Migration.UnsupportedWeightedLiquidSource(block.chainid, config_.original.source);
        }
        Migration.WeightedLiquidSurrender storage s_ = m_.weightedLiquidSurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidWeightedLiquidQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidWeightedLiquidEntitlement(originalId_);
    }

    function surrenderMigrationWeightedLiquid(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!Repo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewWeightedLiquidSurrender(originalId_, amount_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.WeightedLiquidEntitlement storage config_ = m_.weightedLiquidEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalWeightedLiquidWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(Legacy.WEIGHTED_DETF);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.WeightedLiquidCustodyFailed();
        }
        Migration.WeightedLiquidSurrender storage s_ = m_.weightedLiquidSurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        RecoveryRepo._layoutStruct().inventory[Legacy.WEIGHTED_DETF] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = Repo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationWeightedLiquidSurrendered(
            originalId_, config_.configurationId, msg.sender, amount_, credit_, bondTokenId_
        );
    }

    function weightedSyEntitlement(bytes32 originalId_)
        external view returns (Migration.WeightedSyEntitlement memory)
    { return Repo._layoutStruct().weightedSyEntitlements[originalId_]; }

    function claimedSyWeights(bytes32 originalId_)
        external view returns (uint256 originalWeight, uint256 eligibleWeight)
    {
        Migration.ClaimedSyWeights storage weights_ = Repo._layoutStruct().claimedSyWeights[originalId_];
        return (weights_.originalWeight, weights_.eligibleWeight);
    }

    function weightedSySurrender(bytes32 originalId_)
        external view returns (Migration.WeightedSySurrender memory)
    { return Repo._layoutStruct().weightedSySurrenders[originalId_]; }

    function previewWeightedSySurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.WeightedSyEntitlement storage config_ = m_.weightedSyEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidWeightedSyEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.WEIGHTED_SY) {
            revert Migration.UnsupportedWeightedSySource(block.chainid, config_.original.source);
        }
        Migration.WeightedSySurrender storage s_ = m_.weightedSySurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidWeightedSyQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidWeightedSyEntitlement(originalId_);
    }

    function surrenderMigrationWeightedSy(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!Repo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewWeightedSySurrender(originalId_, amount_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.WeightedSyEntitlement storage config_ = m_.weightedSyEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalWeightedSyWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(Legacy.WEIGHTED_SY);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.WeightedSyCustodyFailed();
        }
        Migration.WeightedSySurrender storage s_ = m_.weightedSySurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        RecoveryRepo._layoutStruct().inventory[Legacy.WEIGHTED_SY] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = Repo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationWeightedSySurrendered(
            originalId_, config_.configurationId, msg.sender, amount_, credit_, bondTokenId_
        );
    }

    function dtfCustodySeEntitlement(bytes32 originalId_)
        external view returns (Migration.DtfCustodySeEntitlement memory)
    { return Repo._layoutStruct().dtfCustodySeEntitlements[originalId_]; }

    function dtfCustodySeSurrender(bytes32 originalId_)
        external view returns (Migration.DtfCustodySeSurrender memory)
    { return Repo._layoutStruct().dtfCustodySeSurrenders[originalId_]; }

    function previewDtfCustodySeSurrender(bytes32 originalId_, uint256 amount_)
        public view returns (uint256 credit_)
    {
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.DtfCustodySeEntitlement storage config_ = m_.dtfCustodySeEntitlements[originalId_];
        if (!config_.configured) revert Migration.InvalidDtfCustodySeEntitlement(originalId_);
        if (block.chainid != 4663 || config_.original.source != Legacy.DTF_CUSTODY_SE) {
            revert Migration.UnsupportedDtfCustodySeSource(block.chainid, config_.original.source);
        }
        Migration.DtfCustodySeSurrender storage s_ = m_.dtfCustodySeSurrenders[originalId_];
        if (amount_ == 0 || amount_ > s_.remainingUnits) {
            revert Migration.InvalidDtfCustodySeQuantity(amount_, s_.remainingUnits);
        }
        credit_ = amount_ == s_.remainingUnits
            ? s_.remainingCredit : Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits);
        if (credit_ == 0) revert Migration.InvalidDtfCustodySeEntitlement(originalId_);
    }

    function surrenderMigrationDtfCustodySe(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!Repo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        credit_ = previewDtfCustodySeSurrender(originalId_, amount_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.DtfCustodySeEntitlement storage config_ = m_.dtfCustodySeEntitlements[originalId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalDtfCustodySeWallet(msg.sender, config_.original.originalWallet);
        }
        if (credit_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, credit_);
        IERC20 token_ = IERC20(Legacy.DTF_CUSTODY_SE);
        uint256 walletBefore_ = token_.balanceOf(msg.sender);
        uint256 custodyBefore_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 walletAfter_ = token_.balanceOf(msg.sender);
        uint256 custodyAfter_ = token_.balanceOf(address(this));
        if (walletAfter_ > walletBefore_ || walletBefore_ - walletAfter_ != amount_
            || custodyAfter_ < custodyBefore_ || custodyAfter_ - custodyBefore_ != amount_) {
            revert Migration.DtfCustodySeCustodyFailed();
        }
        Migration.DtfCustodySeSurrender storage s_ = m_.dtfCustodySeSurrenders[originalId_];
        s_.consumedUnits += amount_;
        s_.deliveredCredit += credit_;
        s_.remainingUnits -= amount_;
        s_.remainingCredit -= credit_;
        RecoveryRepo._layoutStruct().inventory[Legacy.DTF_CUSTODY_SE] += amount_;
        _realizeExpansionIfNeeded();
        bondTokenId_ = Repo._fundBond(credit_, msg.sender);
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationDtfCustodySeSurrendered(
            originalId_, config_.configurationId, msg.sender, amount_, credit_, bondTokenId_
        );
    }

    function migrationNftOriginalId(address collection_, uint256 tokenId_) external view returns (bytes32) {
        return NftLib.originalId(collection_, tokenId_);
    }
    function nftCustody(address collection_, uint256 tokenId_)
        external view returns (Migration.NftCustody memory)
    { return Repo._layoutStruct().nftCustodies[collection_][tokenId_]; }
    function previewNftSurrender(address collection_, uint256 tokenId_)
        external view returns (uint256 remaining_, uint256 credit_)
    { (, remaining_, credit_,) = NftLib.preview(collection_, tokenId_); }

    function surrenderMigrationNft(address collection_, uint256 tokenId_, uint256 minimum_, uint256 deadline_)
        external nonReentrant returns (uint256 bondTokenId_, uint256 credit_)
    {
        if (!Repo._layoutStruct().activated) revert Migration.MigrationSurrenderClosed();
        _requireIdleChildren();
        _requireNotDisabled();
        _requireReserveLive();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        (address holder_, uint256 remaining_, uint256 quoted_, bytes32 before_) =
            NftLib.preview(collection_, tokenId_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        Migration.NftEntitlement memory config_ = m_.nftEntitlements[collection_][tokenId_];
        if (msg.sender != config_.original.originalWallet) {
            revert Migration.NotOriginalNftWallet(msg.sender, config_.original.originalWallet);
        }
        if (msg.sender != holder_) revert Migration.NotNftHolder(msg.sender, holder_);
        if (quoted_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, quoted_);
        // Keep the guard over legacy synchronization as well as its pre-transfer receiver call.
        m_.expectedNft = Repo.NftReceipt(collection_, holder_, tokenId_, false);
        IMigrationLegacyNft(collection_).safeTransferFrom(holder_, address(this), tokenId_);
        if (!m_.expectedNft.accepted || IMigrationLegacyNft(collection_).ownerOf(tokenId_) != address(this)) {
            revert Migration.NftCustodyFailed(collection_, tokenId_);
        }
        (, bytes32 after_) = NftLib.position(collection_, tokenId_, config_.original.originalUnits);
        if (after_ != before_) revert Migration.NftCustodyFailed(collection_, tokenId_);
        delete m_.expectedNft;
        m_.nftSurrenders[collection_][tokenId_] = Migration.NftSurrender(
            true, config_.configurationId, holder_, config_.original.originalUnits, remaining_, quoted_, 0,
            block.timestamp
        );
        m_.nftCustodies[collection_][tokenId_] =
            Migration.NftCustody(collection_, tokenId_, config_.configurationId);
        _realizeExpansionIfNeeded();
        uint256[] memory credits_ = NftLib.contributionCredits(collection_, tokenId_, remaining_);
        for (uint256 i_; i_ < credits_.length; ++i_) {
            uint256 id_ = Repo._fundBond(credits_[i_], holder_);
            if (i_ == 0) bondTokenId_ = id_;
            m_.nftContributionSurrenders[collection_][tokenId_].push(
                Migration.NftContributionSurrender(credits_[i_], id_)
            );
            emit Migration.MigrationNftContributionSurrendered(collection_, tokenId_, i_, credits_[i_], id_);
        }
        m_.nftSurrenders[collection_][tokenId_].bondTokenId = bondTokenId_;
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationNftSurrendered(
            collection_, tokenId_, holder_, config_.configurationId, remaining_, quoted_, bondTokenId_
        );
        return (bondTokenId_, quoted_);
    }

    /// @dev The admitted sources have not transferred ownership yet. This callback only accepts
    /// the one expected pull; final ownership/position verification happens after transfer returns.
    function onERC721Received(address operator_, address from_, uint256 tokenId_, bytes calldata data_)
        external returns (bytes4)
    {
        Repo.NftReceipt storage expected_ = Repo._layoutStruct().expectedNft;
        if (!ReentrancyLockRepo._isLocked() || expected_.collection == address(0)
            || msg.sender != expected_.collection || operator_ != address(this) || from_ != expected_.holder
            || tokenId_ != expected_.tokenId || data_.length != 0 || expected_.accepted) {
            revert Migration.UnexpectedNftCallback();
        }
        expected_.accepted = true;
        return IERC721Receiver.onERC721Received.selector;
    }

    function donateMigrationCapital(
        IERC20[] calldata tokens_, uint256[] calldata amounts_, uint256 nativeAmount_,
        uint256 minLpOut_, uint256 deadline_
    ) external payable nonReentrant returns (uint256 lpOut_) {
        _requireIdleChildren();
        _requireNotDisabled();
        if (block.timestamp > deadline_) revert ParentRepo.DeadlineExpired(deadline_);
        if (msg.value != nativeAmount_) revert Migration.UnexpectedMigrationNativeValue(nativeAmount_, msg.value);
        if (tokens_.length != amounts_.length || (tokens_.length == 0 && nativeAmount_ == 0)) {
            revert ParentRepo.ZeroAmount();
        }
        bool live_ = ParentRepo._layoutStruct().isReserveLive;
        if (!live_ && minLpOut_ != 0) revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, 0);
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            for (uint256 j_; j_ < i_; ++j_) {
                if (tokens_[j_] == tokens_[i_]) revert Migration.InvalidGenesisLeg(address(tokens_[i_]));
            }
            _requireDonationToken(address(tokens_[i_]));
            _requireActive(deadline_, amounts_[i_]);
            _pullToken(tokens_[i_], amounts_[i_], false);
            m_.donationInventory[address(tokens_[i_])] += amounts_[i_];
            emit Migration.MigrationCapitalReceived(msg.sender, address(tokens_[i_]), amounts_[i_]);
        }
        if (nativeAmount_ != 0) {
            _requireDonationToken(m_.weth);
            uint256 before_ = IERC20(m_.weth).balanceOf(address(this));
            IWETH(m_.weth).deposit{value: nativeAmount_}();
            if (IERC20(m_.weth).balanceOf(address(this)) - before_ != nativeAmount_) revert ParentRepo.ZeroAmount();
            m_.donationInventory[m_.weth] += nativeAmount_;
            emit Migration.MigrationCapitalReceived(msg.sender, m_.weth, nativeAmount_);
        }
        if (live_) {
            uint256 beforeLp_ = IERC20(ParentRepo._layoutStruct().hook).balanceOf(_bondLpHolder());
            uint256[] memory residuals_ = _beginIsolatedBudget();
            // Join only this call's receipts. Leave their refunds and all older
            // residuals for the fee recipient's separate maintenance transaction.
            for (uint256 i_; i_ < tokens_.length; ++i_) _releaseDonation(address(tokens_[i_]), amounts_[i_]);
            if (nativeAmount_ != 0) _releaseDonation(m_.weth, nativeAmount_);
            _tryJoinNativeResidual(_hook().tokens());
            _endIsolatedBudget(residuals_);
            lpOut_ = IERC20(ParentRepo._layoutStruct().hook).balanceOf(_bondLpHolder()) - beforeLp_;
            if (lpOut_ < minLpOut_) revert IStandardExchangeErrors.MinAmountNotMet(minLpOut_, lpOut_);
        }
        _syncAllExpectedHoldReserves();
    }

    function _releaseDonation(address token_, uint256 amount_) private {
        Repo.Storage storage m_ = Repo._layoutStruct();
        m_.donationInventory[token_] -= amount_;
        m_.operationFloor[token_] -= amount_;
        emit Migration.MigrationCapitalConsumed(token_, amount_);
    }

    function _requireDonationToken(address token_) private view {
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        // Genesis accepts actual pair/share representations, not a broadened route enum.
        if (token_ == address(this) || !s_.donateTable.tokens._contains(token_)) {
            revert Migration.InvalidGenesisLeg(token_);
        }
        if (!s_.hookPairTokens._contains(token_) && !s_.hookStandardExchanges._contains(token_)) {
            revert Migration.InvalidGenesisLeg(token_);
        }
    }
}

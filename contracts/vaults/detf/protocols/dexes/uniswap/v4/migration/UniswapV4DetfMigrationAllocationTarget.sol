// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {ERC2535Repo} from "@crane/contracts/introspection/ERC2535/ERC2535Repo.sol";
import {ERC165Repo} from "@crane/contracts/introspection/ERC165/ERC165Repo.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4DetfMigrationPolicy} from "./UniswapV4DetfMigrationPolicy.sol";
import {UniswapV4DetfMigrationRepo as Repo} from "./UniswapV4DetfMigrationRepo.sol";
import {UniswapV4DetfRepo as ParentRepo} from "../detf/UniswapV4DetfRepo.sol";
import {UniswapV4DetfTarget} from "../detf/UniswapV4DetfTarget.sol";
import {UniswapV4DetfCommon} from "../detf/UniswapV4DetfCommon.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation}
    from "./interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from "./interfaces/IUniswapV4DetfMigrationSnapshot.sol";
import {UniswapV4DetfMigrationSnapshotLib as SnapshotLib} from "./UniswapV4DetfMigrationSnapshotLib.sol";
import {MigrationLegacyNftLib as NftLib} from "./legacy/MigrationLegacyNftLib.sol";
import {MigrationLegacyRecoveryLib as Legacy} from "./legacy/MigrationLegacyRecoveryLib.sol";

/// @notice The removable current-owner administration surface; no legacy attribution shortcuts.
contract UniswapV4DetfMigrationAllocationTarget is UniswapV4DetfTarget, UniswapV4DetfMigrationPolicy {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    function _pendingExpansionDetf() internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._pendingExpansionDetf(); }
    function _realizeExpansionIfNeeded() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._realizeExpansionIfNeeded(); }
    function _isMintingAllowedToken(IERC20 token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (bool) { return UniswapV4DetfMigrationPolicy._isMintingAllowedToken(token_); }
    function _residualBalance(address token_) internal view override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) returns (uint256) { return UniswapV4DetfMigrationPolicy._residualBalance(token_); }
    function _sweepDustBody() internal override(UniswapV4DetfCommon, UniswapV4DetfMigrationPolicy) { UniswapV4DetfMigrationPolicy._sweepDustBody(); }

    modifier administration() {
        MultiStepOwnableRepo._onlyOwner();
        if (Repo._layoutStruct().activated) revert Migration.MigrationAlreadyActivated();
        _requireIdleChildren();
        _;
    }

    function captureMigrationSnapshot() external administration nonReentrant returns (bytes32 id_) {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.frozen.length != 0) revert Snapshot.SnapshotAlreadyCaptured();
        Snapshot.Snapshot memory book_ = SnapshotLib.capture(Snapshot.Source(
            address(this), address(ParentRepo._layoutStruct().feeOracle), m_.weth, m_.originalDtf
        ));
        m_.frozen = abi.encode(book_);
        emit Migration.MigrationSnapshotCaptured(book_.id, block.number);
        return book_.id;
    }

    function configureIndependentAllocations(Migration.IndependentAllocationInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.IndependentAllocationInput calldata input_ = inputs_[i_];
            if (input_.recipient == address(0) || input_.entitlements.length == 0) {
                revert Migration.InvalidIndependentAllocation(input_.recipient);
            }
            Migration.IndependentAllocation storage config_ = m_.allocations[input_.recipient];
            for (uint256 j_; j_ < config_.entitlements.length; ++j_) {
                delete m_.configuredOriginal[config_.entitlements[j_].original.entitlementId];
            }
            delete config_.entitlements;
            config_.totalCredit = 0;
            config_.evidenceId = input_.evidenceId;
            config_.configurationId = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            for (uint256 j_; j_ < input_.entitlements.length; ++j_) {
                Migration.OriginalEntitlement calldata original_ = input_.entitlements[j_];
                address issuedTo_ = m_.issuedOriginal[original_.entitlementId];
                if (original_.entitlementId == bytes32(0)
                    || m_.configuredOriginal[original_.entitlementId] != address(0)
                    || m_.nftOriginal[original_.entitlementId]
                    || m_.weightedLiquidEntitlements[original_.entitlementId].configured
                    || m_.weightedSyEntitlements[original_.entitlementId].configured
                    || m_.dtfCustodySeEntitlements[original_.entitlementId].configured
                    || m_.claimVaultEntitlements[original_.entitlementId].configured
                    || m_.weightedReceiptEntitlements[original_.entitlementId].configured
                    || m_.earlierReceiptEntitlements[original_.entitlementId].configured
                    || m_.earlierLiquidEntitlements[original_.entitlementId].configured
                    || (issuedTo_ != address(0) && issuedTo_ != input_.recipient)) {
                    revert Migration.DuplicateOriginalEntitlement(original_.entitlementId);
                }
                uint256 credit_ = SnapshotLib.evaluateOriginals(book_, original_.originalEth, original_.originalDtf);
                config_.entitlements.push(Migration.QuotedOriginalEntitlement(original_, credit_));
                config_.totalCredit += credit_;
                m_.configuredOriginal[original_.entitlementId] = input_.recipient;
            }
            emit Migration.IndependentAllocationConfigured(
                input_.recipient, config_.configurationId, input_.evidenceId, config_.totalCredit
            );
        }
    }

    function issueIndependentAllocations(Migration.IndependentIssuanceRequest[] calldata requests_)
        external administration nonReentrant returns (uint256[] memory ids_)
    {
        _requireReserveLive();
        Repo.Storage storage m_ = Repo._layoutStruct();
        ids_ = new uint256[](requests_.length);
        for (uint256 i_; i_ < requests_.length; ++i_) {
            address recipient_ = requests_[i_].recipient;
            Migration.IndependentAllocation storage config_ = m_.allocations[recipient_];
            if (m_.issuances[recipient_].issued) revert Migration.IndependentAllocationAlreadyIssued(recipient_);
            if (config_.configurationId != requests_[i_].configurationId) {
                revert Migration.IndependentConfigurationMismatch(
                    recipient_, requests_[i_].configurationId, config_.configurationId
                );
            }
            uint256 credit_ = config_.totalCredit;
            if (credit_ == 0) revert Migration.InvalidIndependentAllocation(recipient_);
            // Existing participation settles before any new principal or standing weight is added.
            _realizeExpansionIfNeeded();
            ids_[i_] = Repo._fundBond(credit_, recipient_);
            m_.issuances[recipient_] = Migration.IndependentIssuance(
                true, config_.configurationId, credit_, ids_[i_], block.timestamp
            );
            for (uint256 j_; j_ < config_.entitlements.length; ++j_) {
                bytes32 originalId_ = config_.entitlements[j_].original.entitlementId;
                if (m_.issuedOriginal[originalId_] != address(0) || m_.nftOriginal[originalId_]
                    || m_.weightedLiquidEntitlements[originalId_].configured
                    || m_.weightedSyEntitlements[originalId_].configured
                    || m_.dtfCustodySeEntitlements[originalId_].configured) {
                    revert Migration.DuplicateOriginalEntitlement(originalId_);
                }
                if (m_.claimVaultEntitlements[originalId_].configured
                    || m_.weightedReceiptEntitlements[originalId_].configured
                    || m_.earlierReceiptEntitlements[originalId_].configured
                    || m_.earlierLiquidEntitlements[originalId_].configured) {
                    revert Migration.DuplicateOriginalEntitlement(originalId_);
                }
                m_.issuedOriginal[originalId_] = recipient_;
            }
            emit Migration.IndependentAllocationIssued(
                recipient_, config_.configurationId, ids_[i_], credit_, block.timestamp
            );
        }
        _syncAllExpectedHoldReserves();
    }

    function configureNftEntitlements(Migration.NftEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.NftEntitlementInput calldata input_ = inputs_[i_];
            bytes32 original_ = NftLib.originalId(input_.collection, input_.tokenId);
            if (input_.tokenId < 3 || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown
                || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidNftEntitlement(input_.collection, input_.tokenId);
            }
            if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
                || m_.weightedLiquidEntitlements[original_].configured
                || m_.weightedSyEntitlements[original_].configured
                || m_.dtfCustodySeEntitlements[original_].configured) {
                revert Migration.DuplicateOriginalEntitlement(original_);
            }
            if (m_.claimVaultEntitlements[original_].configured
                || m_.weightedReceiptEntitlements[original_].configured
                || m_.earlierReceiptEntitlements[original_].configured
                || m_.earlierLiquidEntitlements[original_].configured) {
                revert Migration.DuplicateOriginalEntitlement(original_);
            }
            if (m_.nftSurrenders[input_.collection][input_.tokenId].consumed) {
                revert Migration.NftAlreadyConsumed(input_.collection, input_.tokenId);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.nftEntitlements[input_.collection][input_.tokenId] =
                Migration.NftEntitlement(input_, config_, original_, credit_);
            m_.nftOriginal[original_] = true;
            emit Migration.NftEntitlementConfigured(
                input_.collection, input_.tokenId, config_, input_.originalWallet, original_, credit_
            );
        }
    }


    function configureWeightedSyEntitlements(Migration.WeightedSyEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.WeightedSyEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.WEIGHTED_SY) {
                revert Migration.UnsupportedWeightedSySource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidWeightedSyEntitlement(original_);
            }
            _requireUnallocatedOrigin(original_, input_.source);
            Migration.WeightedSySurrender storage surrender_ = m_.weightedSySurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.WeightedSyIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.weightedSyEntitlements[original_] =
                Migration.WeightedSyEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.WeightedSyEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }

    function configureDtfCustodySeEntitlements(Migration.DtfCustodySeEntitlementInput[] calldata inputs_)
        external administration nonReentrant
    {
        Snapshot.Snapshot memory book_ = Repo._snapshot();
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < inputs_.length; ++i_) {
            Migration.DtfCustodySeEntitlementInput calldata input_ = inputs_[i_];
            if (block.chainid != 4663 || input_.source != Legacy.DTF_CUSTODY_SE) {
                revert Migration.UnsupportedDtfCustodySeSource(block.chainid, input_.source);
            }
            bytes32 original_ = input_.originalId;
            if (original_ == bytes32(0) || input_.originalWallet == address(0)
                || input_.originalUnits == 0 || !input_.contributionsKnown || input_.evidenceId == bytes32(0)) {
                revert Migration.InvalidDtfCustodySeEntitlement(original_);
            }
            _requireUnallocatedOrigin(original_, input_.source);
            Migration.DtfCustodySeSurrender storage surrender_ = m_.dtfCustodySeSurrenders[original_];
            if (surrender_.consumedUnits != 0 || surrender_.deliveredCredit != 0) {
                revert Migration.DtfCustodySeIdentityConsumed(original_);
            }
            uint256 credit_ = SnapshotLib.evaluateOriginals(book_, input_.originalEth, input_.originalDtf);
            bytes32 config_ = keccak256(abi.encode(block.chainid, address(this), book_.id, input_));
            m_.dtfCustodySeEntitlements[original_] =
                Migration.DtfCustodySeEntitlement(true, input_, config_, credit_);
            surrender_.remainingUnits = input_.originalUnits;
            surrender_.remainingCredit = credit_;
            emit Migration.DtfCustodySeEntitlementConfigured(
                original_, config_, input_.originalWallet, input_.originalUnits, credit_
            );
        }
    }

    function _requireUnallocatedOrigin(bytes32 original_, address source_) private view {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.configuredOriginal[original_] != address(0) || m_.issuedOriginal[original_] != address(0)
            || m_.nftOriginal[original_]
            || (source_ != Legacy.WEIGHTED_DETF && m_.weightedLiquidEntitlements[original_].configured)
            || (source_ != Legacy.WEIGHTED_SY && m_.weightedSyEntitlements[original_].configured)
            || (source_ != Legacy.DTF_CUSTODY_SE && m_.dtfCustodySeEntitlements[original_].configured)
            || (source_ != Legacy.CLAIM_VAULT && m_.claimVaultEntitlements[original_].configured)
            || m_.weightedReceiptEntitlements[original_].configured
            || m_.earlierReceiptEntitlements[original_].configured
            || m_.earlierLiquidEntitlements[original_].configured) {
            revert Migration.DuplicateOriginalEntitlement(original_);
        }
    }

    function activateMigration() external administration nonReentrant {
        if (Repo._layoutStruct().ownerFirstBondTokenId == 0) revert Migration.MigrationOwnerFirstBondRequired();
        bytes4[] memory selectors_ = _administrationSelectors();
        IDiamond.FacetCut[] memory cuts_ = new IDiamond.FacetCut[](selectors_.length);
        for (uint256 i_; i_ < selectors_.length; ++i_) {
            bytes4[] memory one_ = new bytes4[](1);
            one_[0] = selectors_[i_];
            cuts_[i_] = IDiamond.FacetCut(
                ERC2535Repo._layoutStruct().facetAddress[selectors_[i_]], IDiamond.FacetCutAction.Remove, one_
            );
            if (cuts_[i_].facetAddress == address(0)) revert ParentRepo.NotAuthorized(address(0));
        }
        ERC2535Repo._processFacetCuts(cuts_);
        ERC165Repo._layoutStruct().isSupportedInterface[type(Allocation).interfaceId] = false;
        Repo._layoutStruct().activated = true;
        emit Migration.MigrationActivated(msg.sender);
    }

    function _administrationSelectors() internal pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](13);
        selectors_[0] = Allocation.bootstrapMigrationReserve.selector;
        selectors_[1] = Allocation.captureMigrationSnapshot.selector;
        selectors_[2] = Allocation.configureIndependentAllocations.selector;
        selectors_[3] = Allocation.issueIndependentAllocations.selector;
        selectors_[4] = Allocation.activateMigration.selector;
        selectors_[5] = Allocation.configureNftEntitlements.selector;
        selectors_[6] = Allocation.configureWeightedSyEntitlements.selector;
        selectors_[7] = Allocation.configureDtfCustodySeEntitlements.selector;
        selectors_[8] = Allocation.configureWeightedLiquidEntitlements.selector;
        selectors_[9] = Allocation.configureClaimVaultEntitlements.selector;
        selectors_[10] = Allocation.configureWeightedReceiptEntitlements.selector;
        selectors_[11] = Allocation.configureEarlierReceiptEntitlements.selector;
        selectors_[12] = Allocation.configureEarlierLiquidEntitlements.selector;
    }

    function bootstrapMigrationReserve(
        Migration.GenesisLeg[] calldata legs_, uint256 anchorIndex_, uint256 minimum_, uint256 deadline_
    ) external administration nonReentrant returns (uint256 selfMinted_, uint256 lpOut_) {
        _requireNotDisabled();
        _requireReserveWired();
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        if (s_.isReserveLive) revert ParentRepo.AlreadyLive();
        if (legs_.length != s_.hookPairTokens._length() || anchorIndex_ >= legs_.length) {
            revert Migration.InvalidGenesisLeg(address(0));
        }
        address[] memory tokens_ = new address[](legs_.length + 1);
        uint256[] memory amounts_ = new uint256[](tokens_.length);
        address[] memory pairs_ = new address[](legs_.length);
        uint256[] memory equivalents_ = new uint256[](legs_.length);
        // Preview on one pre-conversion book, then require each actual receipt to match.
        for (uint256 i_; i_ < legs_.length; ++i_) {
            (pairs_[i_], equivalents_[i_]) = _genesisPreview(legs_[i_]);
            for (uint256 j_; j_ < i_; ++j_) {
                if (pairs_[j_] == pairs_[i_]) revert Migration.InvalidGenesisLeg(address(legs_[i_].token));
            }
        }
        selfMinted_ = _openingBondQuote(pairs_[anchorIndex_], equivalents_[anchorIndex_]);
        if (selfMinted_ == 0) revert ParentRepo.FirstBondBelowMinimumLiquidity();
        for (uint256 i_; i_ < legs_.length; ++i_) {
            if (i_ != anchorIndex_ && equivalents_[i_] < _firstBondOtherPayment(selfMinted_, pairs_[i_])) {
                revert Migration.InvalidGenesisLeg(pairs_[i_]);
            }
            _requireActive(deadline_, legs_[i_].amount);
            tokens_[i_] = _hook().standardExchangeOf(pairs_[i_]);
            amounts_[i_] = _convertGenesis(legs_[i_], pairs_[i_], equivalents_[i_], deadline_);
        }
        tokens_[legs_.length] = address(this);
        amounts_[legs_.length] = selfMinted_;
        _mintDetf(address(this), selfMinted_);
        address[] memory tracked_ = _budgetTokens();
        uint256[] memory before_ = new uint256[](tracked_.length);
        for (uint256 i_; i_ < tracked_.length; ++i_) before_[i_] = IERC20(tracked_[i_]).balanceOf(address(this));
        uint256 lpBefore_ = IERC20(s_.hook).balanceOf(_bondLpHolder());
        for (uint256 i_; i_ < tokens_.length; ++i_) IERC20(tokens_[i_]).forceApprove(s_.hook, amounts_[i_]);
        lpOut_ = _hook().joinUnbalanced(tokens_, amounts_, _bondLpHolder(), minimum_, deadline_);
        for (uint256 i_; i_ < tokens_.length; ++i_) IERC20(tokens_[i_]).forceApprove(s_.hook, 0);
        if (lpOut_ == 0 || IERC20(s_.hook).balanceOf(_bondLpHolder()) - lpBefore_ != lpOut_ || !_hook().isLive()) {
            revert ParentRepo.FirstBondBelowMinimumLiquidity();
        }
        Repo.Storage storage m_ = Repo._layoutStruct();
        for (uint256 i_; i_ < tracked_.length; ++i_) {
            address token_ = tracked_[i_];
            uint256 after_ = IERC20(token_).balanceOf(address(this));
            if (token_ == address(this)) {
                m_.residualInventory[token_] += selfMinted_ - (before_[i_] - after_);
            } else if (after_ >= before_[i_]) {
                m_.donationInventory[token_] += after_ - before_[i_];
            } else {
                m_.donationInventory[token_] -= before_[i_] - after_;
                emit Migration.MigrationCapitalConsumed(token_, before_[i_] - after_);
            }
        }
        m_.bootstrapSelfMinted = selfMinted_;
        ParentRepo._setReserveLive();
        s_.lastExpansionTimestamp = block.timestamp;
        _syncAllExpectedHoldReserves();
        emit Migration.MigrationReserveBootstrapped(selfMinted_, lpOut_, block.timestamp);
    }

    function _genesisPreview(Migration.GenesisLeg calldata leg_)
        private view returns (address pair_, uint256 equivalent_)
    {
        ParentRepo.Storage storage s_ = ParentRepo._layoutStruct();
        address token_ = address(leg_.token);
        uint256 available_ = Repo._layoutStruct().donationInventory[token_];
        if (leg_.amount == 0 || leg_.amount > available_) {
            revert Migration.InsufficientDonationInventory(token_, leg_.amount, available_);
        }
        if (s_.hookPairTokens._contains(token_)) pair_ = token_;
        else if (s_.hookStandardExchanges._contains(token_)) pair_ = _hookPairOfVault(IStandardExchange(token_));
        else revert Migration.InvalidGenesisLeg(token_);
        address se_ = _hook().standardExchangeOf(pair_);
        if (token_ == se_) return (pair_, _pairEq(IStandardExchange(se_), leg_.token, leg_.amount));
        ExchangeInAmount.Result memory quote_ = ExchangeInAmount.previewResult(
            IStandardExchangeIn(se_), leg_.token, leg_.amount, IERC20(se_)
        );
        equivalent_ = ExchangeInAmount.consumedInput(leg_.amount, quote_.amountRefunded);
    }

    function _convertGenesis(Migration.GenesisLeg calldata leg_, address pair_, uint256 expected_, uint256 deadline_)
        private returns (uint256 shares_)
    {
        address se_ = _hook().standardExchangeOf(pair_);
        if (address(leg_.token) == se_) {
            if (leg_.amount < leg_.minSharesOut) revert ParentRepo.ZeroAmount();
            return leg_.amount;
        }
        uint256 beforeInput_ = leg_.token.balanceOf(address(this));
        uint256 beforeShares_ = IERC20(se_).balanceOf(address(this));
        leg_.token.forceApprove(se_, leg_.amount);
        ExchangeInAmount.Result memory receipt_ = ExchangeInAmount.exchangeResult(
            IStandardExchangeIn(se_), leg_.token, leg_.amount, IERC20(se_), leg_.minSharesOut,
            address(this), false, deadline_
        );
        leg_.token.forceApprove(se_, 0);
        uint256 consumed_ = ExchangeInAmount.requireReceipt(
            leg_.amount, receipt_, beforeInput_, leg_.token.balanceOf(address(this)),
            beforeShares_, IERC20(se_).balanceOf(address(this))
        );
        if (consumed_ != expected_ || receipt_.amountOut == 0) revert Migration.InvalidGenesisLeg(address(leg_.token));
        Repo.Storage storage m_ = Repo._layoutStruct();
        m_.donationInventory[address(leg_.token)] -= consumed_;
        m_.donationInventory[se_] += receipt_.amountOut;
        emit Migration.MigrationCapitalConsumed(address(leg_.token), consumed_);
        return receipt_.amountOut;
    }
}

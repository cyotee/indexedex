// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfMigrationWeightedPricing} from "./IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice R3 cross-child accounting handshake. The getter's ABI is uint8, not a new lock API.
interface IUniswapV4DetfMigrationAccounting {
    /// @dev Ordinals are shared by bond, receipt, both SYs and RT. Never reorder.
    enum AccountingPhase {
        Idle,
        Synchronizing,
        Acquiring,
        Accounting,
        Paying
    }

    error MigrationAccountingBusy(address component, uint8 phase);
    error MigrationRewardsClosed();
    error UnexpectedGonsPerUnit(uint256 expected, uint256 actual);

    /// @notice Current phase, using AccountingPhase ordinals; all five children must be Idle at activation.
    function migrationAccountingPhase() external view returns (uint8);
}

/// @notice Permanent Migration queries and donation surface, alongside compatible ordinary parent APIs.
/// @dev Only the current Crane owner administers Migration. Pending-owner acceptance uses Crane's
/// actual behavior; ownershipBufferPeriod is not an added acceptance delay. Administration selectors
/// are declared separately below so activation can remove them without removing these reads.
interface IUniswapV4DetfMigration is
    IUniswapV4Detf,
    IDETFStandardizedYield,
    IDETFStakingPreview,
    IDETFFundedRewards,
    IMultiStepOwnable
{
    /// @notice One original economic quote unit, before recipient consolidation.
    /// @dev ETH and original DTF amounts are native 18-decimal inputs. entitlementId/evidenceId
    /// identify verified independent compensation inputs, not an authenticated legacy-transfer proof.
    struct OriginalEntitlement {
        bytes32 entitlementId;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
    }

    /// @notice Complete replacement input. No caller-supplied output credit is accepted.
    struct IndependentAllocationInput {
        address recipient;
        bytes32 evidenceId;
        OriginalEntitlement[] entitlements;
    }

    /// @notice Original input and its separately evaluated native nine-decimal user-DETF credit.
    struct QuotedOriginalEntitlement {
        OriginalEntitlement original;
        uint256 credit;
    }

    /// @notice Replaceable configuration; totalCredit is the sum of the individual stored credits.
    /// @dev configurationId = keccak256(abi.encode(block.chainid, address(this), snapshot.id, input)),
    /// where input is the complete IndependentAllocationInput, with its original array order.
    /// Identical replacement has the same identity. It is not an issuance/consumption flag.
    struct IndependentAllocation {
        bytes32 configurationId;
        bytes32 evidenceId;
        QuotedOriginalEntitlement[] entitlements;
        uint256 totalCredit;
    }

    /// @notice Select the current recipient configuration without supplying a price, credit or new beneficiary.
    struct IndependentIssuanceRequest {
        address recipient;
        bytes32 configurationId;
    }

    /// @notice Immutable successful execution history, separate from replaceable configuration.
    /// @dev credit is native nine-decimal DETF; issuedAt is the actual creation timestamp in seconds.
    struct IndependentIssuance {
        bool issued;
        bytes32 configurationId;
        uint256 credit;
        uint256 bondTokenId;
        uint256 issuedAt;
    }

    /// @notice Verified original purchase inputs, never a caller-supplied output award.
    /// @dev contributionsKnown attests that BOTH components are known (a known zero is valid).
    /// originalUnits are weighted fixed principal or earlier NewLock accounting shares.
    /// originalWallet is the recorded acquiring wallet, never inferred from current ownership.
    struct NftEntitlementInput {
        address collection;
        uint256 tokenId;
        address originalWallet;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct NftEntitlement {
        NftEntitlementInput original;
        bytes32 configurationId;
        bytes32 originalId;
        uint256 credit;
    }

    /// @notice One separately quoted original; array order is also bond issuance order.
    struct NftContribution {
        uint256 originalEth;
        uint256 originalDtf;
        uint256 credit;
    }

    /// @notice Actual separately funded principal and bond from the single whole-NFT surrender.
    struct NftContributionSurrender {
        uint256 credit;
        uint256 bondTokenId;
    }

    /// @notice Immutable execution facts, unaffected by later configuration replacement.
    struct NftSurrender {
        bool consumed;
        bytes32 configurationId;
        address holder;
        uint256 originalUnits;
        uint256 remainingUnits;
        uint256 credit;
        uint256 bondTokenId;
        uint256 surrenderedAt;
    }

    /// @notice Recovery custody is separate from configuration and irreversible consumption.
    struct NftCustody {
        address collection;
        uint256 tokenId;
        bytes32 configurationId;
    }

    /// @notice One original allocation in native nine-decimal weighted liquid DETF units.
    /// @dev originalId is the wallet-independent canonical economic-origin collision key,
    /// shared with independent/NFT allocations of that origin, not a new representation alias.
    /// Both contribution components must be known; originalUnits must never be inferred from holdings.
    struct WeightedLiquidEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct WeightedLiquidEntitlement {
        bool configured;
        WeightedLiquidEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    /// @notice Execution facts and the unconsumed quote; no replacement can change past delivery.
    struct WeightedLiquidSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice Original weighted SY exposure in native nine-decimal static shares, not receipt units.
    /// @dev originalId is the same wallet-independent economic origin used across representations.
    /// Holdings establish custody only; originalUnits and BOTH known contribution components are inputs.
    struct WeightedSyEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct WeightedSyEntitlement {
        bool configured;
        WeightedSyEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    /// @notice Complete eligible remainder prepared as measured native9 SY before Stage1 loading.
    /// @dev Both weights are native18 raw parent units; ETH/DTF are the FULL original components.
    /// original.originalUnits is the measured SY backing the entire eligible remainder, not raw weight.
    struct ClaimedSyEntitlementInput {
        WeightedSyEntitlementInput original;
        uint256 originalWeight;
        uint256 eligibleWeight;
    }

    struct ClaimedSyWeights {
        uint256 originalWeight;
        uint256 eligibleWeight;
    }

    struct WeightedSySurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice Original weighted SY exposure in native 28-decimal shares of the fixed DTF-custody SE.
    /// @dev originalId is the same wallet-independent economic origin used across representations.
    /// Holdings establish custody only; originalUnits and BOTH known contribution components are inputs.
    struct DtfCustodySeEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct DtfCustodySeEntitlement {
        bool configured;
        DtfCustodySeEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    struct DtfCustodySeSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice Direct native19 claim-vault shares, not TokenStaking weights or infrastructure backing.
    /// @dev Original components and quantity are explicit inputs; live SY value never reprices credit.
    struct ClaimVaultEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct ClaimVaultEntitlement {
        bool configured;
        ClaimVaultEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    struct ClaimVaultSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice One documented original WS allocation; originalUnits is Q0 in eligible ownership GONS.
    /// @dev Native approvals/transfers have nine decimals and move n*k gons at the synchronized
    /// operation divisor. Q0 is supplied from original allocation evidence, never a live balance
    /// or an invented original divisor. Original ETH/DTF grouping excludes reward allocations.
    struct WeightedReceiptEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct WeightedReceiptEntitlement {
        bool configured;
        WeightedReceiptEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    /// @notice Remaining/consumed units are eligible gons; credit is frozen native9 new DETF.
    /// @dev Positive Q/C may be unrepresentable by any positive native transfer at the current k.
    /// Preserve both without forfeiture, ceiling-up custody or a promise of future representability.
    struct WeightedReceiptSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice Documented original ER allocation in exact INTERNAL ownership shares.
    /// @dev Displayed native18 approval units and floored external shares are not Q0.
    /// evidenceId binds the original acquisition, eligible/excluded allocation and both
    /// known original components; a live rate or current balance cannot supply those inputs.
    struct EarlierReceiptEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct EarlierReceiptEntitlement {
        bool configured;
        EarlierReceiptEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    /// @notice Q/q are internal ER shares; C is frozen native9 new DETF.
    /// @dev Preserve positive Q/C even when no valid displayed transfer represents Q.
    struct EarlierReceiptSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    /// @notice One documented earlier liquid original. Q0/Q/q are ED native18, C is new DETF native9.
    /// @dev originalId is the wallet-independent economic origin shared by all representations.
    /// BOTH original ETH/DTF components must be known; holdings and NFT rewards are not originals.
    struct EarlierLiquidEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct EarlierLiquidEntitlement {
        bool configured;
        EarlierLiquidEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    struct EarlierLiquidSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    error UnsupportedEarlierLiquidSource(uint256 chainId, address source);
    error InvalidEarlierLiquidEntitlement(bytes32 originalId);
    error NotOriginalEarlierLiquidWallet(address caller, address originalWallet);
    error InvalidEarlierLiquidQuantity(uint256 requested, uint256 remaining);
    error EarlierLiquidCustodyFailed();
    error EarlierLiquidIdentityConsumed(bytes32 originalId);

    event EarlierLiquidEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalUnits, uint256 credit
    );
    event MigrationEarlierLiquidSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 units, uint256 credit, uint256 bondTokenId
    );

    function earlierLiquidEntitlement(bytes32 originalId_) external view returns (EarlierLiquidEntitlement memory);
    function earlierLiquidSurrender(bytes32 originalId_) external view returns (EarlierLiquidSurrender memory);
    function previewEarlierLiquidSurrender(bytes32 originalId_, uint256 amount_)
        external view returns (uint256 credit_);
    /// @notice Stage2 exact approved ED custody and frozen credit only. ED conversion is not admitted.
    function surrenderMigrationEarlierLiquid(
        bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_);

    /// @notice Original W-SW SE shares, E-P physical LP or W-P physical LP, all native18.
    /// @dev Only the three fixed chain4663 sources are supported. originalId is the
    /// wallet-independent economic origin, shared with every other representation.
    /// Known ETH/DTF components are original inputs, never holdings, rewards or live NAV.
    struct HeldSeLpEntitlementInput {
        bytes32 originalId;
        address originalWallet;
        address source;
        uint256 originalUnits;
        uint256 originalEth;
        uint256 originalDtf;
        bytes32 evidenceId;
        bool contributionsKnown;
    }

    struct HeldSeLpEntitlement {
        bool configured;
        HeldSeLpEntitlementInput original;
        bytes32 configurationId;
        uint256 credit;
    }

    /// @notice Q0/Q/q are the recorded source's native18 units; C is new DETF native9.
    struct HeldSeLpSurrender {
        uint256 consumedUnits;
        uint256 deliveredCredit;
        uint256 remainingUnits;
        uint256 remainingCredit;
    }

    error UnsupportedHeldSeLpSource(uint256 chainId, address source);
    error InvalidHeldSeLpEntitlement(bytes32 originalId);
    error NotOriginalHeldSeLpWallet(address caller, address originalWallet);
    error InvalidHeldSeLpQuantity(uint256 requested, uint256 remaining);
    error HeldSeLpCustodyFailed();
    error HeldSeLpIdentityConsumed(bytes32 originalId);

    event HeldSeLpEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        address source, uint256 originalUnits, uint256 credit
    );
    event MigrationHeldSeLpSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        address source, uint256 native18Units, uint256 credit, uint256 bondTokenId
    );

    function heldSeLpEntitlement(bytes32 originalId_) external view returns (HeldSeLpEntitlement memory);
    function heldSeLpSurrender(bytes32 originalId_) external view returns (HeldSeLpSurrender memory);
    function previewHeldSeLpSurrender(bytes32 originalId_, uint256 amount_) external view returns (uint256 credit_);
    /// @notice Stage2 exact approved custody/credit only. No SE/LP conversion is admitted.
    function surrenderMigrationHeldSeLp(
        bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_);

    /// @notice One selected representation of an external reserve leg, funded from booked donations.
    /// @dev amount is native token units; minSharesOut is native units of that leg's SE shares.
    /// The self leg is generated internally and must not be supplied in this array.
    struct GenesisLeg {
        IERC20 token;
        uint256 amount;
        uint256 minSharesOut;
    }

    error MigrationAlreadyActivated();
    error MigrationSurrenderClosed();
    error MigrationOwnerFirstBondRequired();
    error InvalidIndependentAllocation(address recipient);
    error IndependentAllocationAlreadyIssued(address recipient);
    error IndependentConfigurationMismatch(address recipient, bytes32 expected, bytes32 actual);
    error DuplicateOriginalEntitlement(bytes32 entitlementId);
    error InvalidGenesisLeg(address token);
    error InsufficientDonationInventory(address token, uint256 requested, uint256 available);
    error UnexpectedMigrationNativeValue(uint256 expected, uint256 actual);
    error UnsupportedMigrationNft(uint256 chainId, address collection);
    error InvalidNftEntitlement(address collection, uint256 tokenId);
    error NftAlreadyConsumed(address collection, uint256 tokenId);
    error NotOriginalNftWallet(address caller, address originalWallet);
    error NotNftHolder(address caller, address holder);
    error NftCustodyFailed(address collection, uint256 tokenId);
    error UnexpectedNftCallback();
    error UnsupportedWeightedLiquidSource(uint256 chainId, address source);
    error InvalidWeightedLiquidEntitlement(bytes32 originalId);
    error NotOriginalWeightedLiquidWallet(address caller, address originalWallet);
    error InvalidWeightedLiquidQuantity(uint256 requested, uint256 remaining);
    error WeightedLiquidCustodyFailed();
    error WeightedLiquidIdentityConsumed(bytes32 originalId);
    error UnsupportedWeightedSySource(uint256 chainId, address source);
    error InvalidWeightedSyEntitlement(bytes32 originalId);
    error NotOriginalWeightedSyWallet(address caller, address originalWallet);
    error InvalidWeightedSyQuantity(uint256 requested, uint256 remaining);
    error WeightedSyCustodyFailed();
    error WeightedSyIdentityConsumed(bytes32 originalId);
    error UnsupportedDtfCustodySeSource(uint256 chainId, address source);
    error InvalidDtfCustodySeEntitlement(bytes32 originalId);
    error NotOriginalDtfCustodySeWallet(address caller, address originalWallet);
    error InvalidDtfCustodySeQuantity(uint256 requested, uint256 remaining);
    error DtfCustodySeCustodyFailed();
    error DtfCustodySeIdentityConsumed(bytes32 originalId);
    error UnsupportedClaimVaultSource(uint256 chainId, address source);
    error InvalidClaimVaultEntitlement(bytes32 originalId);
    error NotOriginalClaimVaultWallet(address caller, address originalWallet);
    error InvalidClaimVaultQuantity(uint256 requested, uint256 remaining);
    error ClaimVaultCustodyFailed();
    error ClaimVaultIdentityConsumed(bytes32 originalId);
    error UnsupportedWeightedReceiptSource(uint256 chainId, address source);
    error InvalidWeightedReceiptEntitlement(bytes32 originalId);
    error NotOriginalWeightedReceiptWallet(address caller, address originalWallet);
    error InvalidWeightedReceiptQuantity(uint256 requestedGons, uint256 remainingGons);
    error WeightedReceiptCustodyFailed();
    error WeightedReceiptIdentityConsumed(bytes32 originalId);
    error UnsupportedEarlierReceiptSource(uint256 chainId, address source);
    error InvalidEarlierReceiptEntitlement(bytes32 originalId);
    error NotOriginalEarlierReceiptWallet(address caller, address originalWallet);
    error InvalidEarlierReceiptQuantity(uint256 requestedInternalShares, uint256 remainingInternalShares);
    error EarlierReceiptCustodyFailed();
    error EarlierReceiptIdentityConsumed(bytes32 originalId);

    event MigrationCapitalReceived(address indexed donor, address indexed token, uint256 amount);
    event MigrationCapitalConsumed(address indexed token, uint256 amount);
    event MigrationCapitalRetained(address indexed token, uint256 amount);
    event MigrationReserveBootstrapped(uint256 selfMinted, uint256 lpOut, uint256 timestamp);
    event IndependentAllocationConfigured(
        address indexed recipient, bytes32 indexed configurationId, bytes32 evidenceId, uint256 totalCredit
    );
    event IndependentAllocationIssued(
        address indexed recipient, bytes32 indexed configurationId, uint256 indexed bondTokenId,
        uint256 credit, uint256 issuedAt
    );
    event MigrationActivated(address indexed owner);
    event MigrationOwnerFirstBondPurchased(address indexed owner, uint256 indexed bondTokenId);
    event MigrationSyRewardTokenWired(address indexed rewardToken, address indexed receipt);
    event NftEntitlementConfigured(
        address indexed collection, uint256 indexed tokenId, bytes32 indexed configurationId,
        address originalWallet, bytes32 originalId, uint256 credit
    );
    event MigrationNftSurrendered(
        address indexed collection, uint256 indexed tokenId, address indexed holder,
        bytes32 configurationId, uint256 remainingUnits, uint256 credit, uint256 bondTokenId
    );
    event MigrationNftContributionSurrendered(
        address indexed collection, uint256 indexed tokenId, uint256 indexed contributionIndex,
        uint256 credit, uint256 bondTokenId
    );
    event WeightedLiquidEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalUnits, uint256 credit
    );
    event MigrationWeightedLiquidSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 units, uint256 credit, uint256 bondTokenId
    );
    event WeightedSyEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalUnits, uint256 credit
    );
    event MigrationWeightedSySurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 units, uint256 credit, uint256 bondTokenId
    );
    event DtfCustodySeEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalUnits, uint256 credit
    );
    event MigrationDtfCustodySeSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 units, uint256 credit, uint256 bondTokenId
    );
    event ClaimVaultEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalUnits, uint256 credit
    );
    event MigrationClaimVaultSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 units, uint256 credit, uint256 bondTokenId
    );

    event WeightedReceiptEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalGons, uint256 credit
    );
    event MigrationWeightedReceiptSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 nativeAmount, uint256 eligibleGons, uint256 gonsPerUnit, uint256 credit, uint256 bondTokenId
    );

    event EarlierReceiptEntitlementConfigured(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 originalInternalShares, uint256 credit
    );
    event MigrationEarlierReceiptSurrendered(
        bytes32 indexed originalId, bytes32 indexed configurationId, address indexed originalWallet,
        uint256 nativeAmount, uint256 internalShares, uint256 rate, uint256 credit, uint256 bondTokenId
    );

    function earlierReceiptEntitlement(bytes32 originalId_) external view returns (EarlierReceiptEntitlement memory);
    function earlierReceiptSurrender(bytes32 originalId_) external view returns (EarlierReceiptSurrender memory);
    /// @notice Indicative frozen-credit view; surrender additionally proves the actual transfer rate.
    function previewEarlierReceiptSurrender(bytes32 originalId_, uint256 nativeAmount_)
        external view returns (uint256 credit_);
    /// @notice Stage2 original-wallet approved ER pull; no conversion or inventory debit is admitted.
    function surrenderMigrationEarlierReceipt(
        bytes32 originalId_, uint256 nativeAmount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_);

    function weightedReceiptEntitlement(bytes32 originalId_) external view returns (WeightedReceiptEntitlement memory);
    function weightedReceiptSurrender(bytes32 originalId_) external view returns (WeightedReceiptSurrender memory);
    /// @notice Indicative view at the current divisor; does not synchronize the legacy source.
    function previewWeightedReceiptSurrender(bytes32 originalId_, uint256 nativeAmount_)
        external view returns (uint256 credit_);
    /// @notice Stage2 original-wallet native9 approved pull; consume only exact n*k eligible gons.
    function surrenderMigrationWeightedReceipt(
        bytes32 originalId_, uint256 nativeAmount_, uint256 minimum_, uint256 deadline_
    ) external returns (uint256 bondTokenId_, uint256 credit_);

    function claimVaultEntitlement(bytes32 originalId_) external view returns (ClaimVaultEntitlement memory);
    function claimVaultSurrender(bytes32 originalId_) external view returns (ClaimVaultSurrender memory);
    function previewClaimVaultSurrender(bytes32 originalId_, uint256 amount_) external view returns (uint256 credit_);
    /// @notice Stage2 original-wallet approved native19 shares into one exact-funded fresh90-day bond.
    function surrenderMigrationClaimVault(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_);

    function weightedSyEntitlement(bytes32 originalId_) external view returns (WeightedSyEntitlement memory);
    /// @notice Bound native18 weights; both zero for the ordinary complete SY representation.
    function claimedSyWeights(bytes32 originalId_)
        external view returns (uint256 originalWeight, uint256 eligibleWeight);
    function weightedSySurrender(bytes32 originalId_) external view returns (WeightedSySurrender memory);
    function previewWeightedSySurrender(bytes32 originalId_, uint256 amount_) external view returns (uint256 credit_);
    /// @notice Stage2 only: pull configured original-wallet WY shares for one fresh exactly funded cliff bond.
    function surrenderMigrationWeightedSy(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_);

    function dtfCustodySeEntitlement(bytes32 originalId_) external view returns (DtfCustodySeEntitlement memory);
    function dtfCustodySeSurrender(bytes32 originalId_) external view returns (DtfCustodySeSurrender memory);
    function previewDtfCustodySeSurrender(bytes32 originalId_, uint256 amount_) external view returns (uint256 credit_);
    /// @notice Stage2 only: pull configured original-wallet native 28-decimal DTF-custody SE shares for one fresh exactly funded cliff bond.
    function surrenderMigrationDtfCustodySe(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_);

    function weightedLiquidEntitlement(bytes32 originalId_)
        external view returns (WeightedLiquidEntitlement memory);
    function weightedLiquidSurrender(bytes32 originalId_)
        external view returns (WeightedLiquidSurrender memory);
    function previewWeightedLiquidSurrender(bytes32 originalId_, uint256 amount_)
        external view returns (uint256 credit_);
    /// @notice After activation, only the configured original wallet may surrender WD for its own fresh bond.
    function surrenderMigrationWeightedLiquid(bytes32 originalId_, uint256 amount_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_);

    /// @notice Canonical known-origin collision key, bound to chain, instance and frozen snapshot.
    /// @dev Independent allocation IDs must use this key for this origin. Opaque aliases do not
    /// prove disjoint exposure; original economic exposure reconciliation remains required.
    /// The key excludes the original wallet so corrections cannot create another economic origin.
    function migrationNftOriginalId(address collection_, uint256 tokenId_) external view returns (bytes32);
    function nftEntitlement(address collection_, uint256 tokenId_) external view returns (NftEntitlement memory);
    function nftSurrender(address collection_, uint256 tokenId_) external view returns (NftSurrender memory);
    function nftCustody(address collection_, uint256 tokenId_) external view returns (NftCustody memory);
    function nftContributions(address collection_, uint256 tokenId_) external view returns (NftContribution[] memory);
    function nftContributionSurrenders(address collection_, uint256 tokenId_)
        external view returns (NftContributionSurrender[] memory);
    function previewNftContributionSurrender(address collection_, uint256 tokenId_)
        external view returns (uint256 remainingUnits_, uint256[] memory credits_);
    function previewNftSurrender(address collection_, uint256 tokenId_)
        external view returns (uint256 remainingUnits_, uint256 credit_);

    /// @notice Stage 2 original-wallet whole-NFT custody; one fresh 90-day bond per configured original.
    /// @dev Returns the first bond ID and aggregate credit. Per-original results are retained separately.
    /// No beneficiary, historical quantity, arbitrary target or credit argument.
    function surrenderMigrationNft(address collection_, uint256 tokenId_, uint256 minimum_, uint256 deadline_)
        external returns (uint256 bondTokenId_, uint256 credit_);

    /// @notice Sole finalized reward/new-money/surrender gate. Activation does not reset clocks or indices.
    function migrationActivated() external view returns (bool);

    /// @notice Completed paid Stage1 owner purchase; persists across owner/NFT transfers and retirement.
    /// @dev Zero until the ordinary purchase, principal funding and reward settlement all succeed.
    function migrationOwnerFirstBondTokenId() external view returns (uint256);

    /// @notice Once-wired RT child; receipt must reject RT caller admission while this is zero.
    function migrationSyRewardToken() external view returns (address);

    /// @notice Complete manual book. Reverts MigrationWeightedPricingNotSet before initialization.
    function migrationWeightedPricing() external view returns (IUniswapV4DetfMigrationWeightedPricing.Book memory);

    /// @notice Quote one original entitlement's two components on the same unchanged book; mints nothing.
    function previewOriginalCredit(uint256 originalEth_, uint256 originalDtf_) external view returns (uint256);

    /// @notice Latest replaceable configuration, including after issuance or activation.
    function independentAllocation(address recipient_) external view returns (IndependentAllocation memory);

    /// @notice Actual once-only issuance; configuration replacement never changes this record.
    function independentIssuance(address recipient_) external view returns (IndependentIssuance memory);

    /// @notice Booked donated units only, excluding unsolicited balances and other custody domains.
    function migrationDonationInventory(IERC20 token_) external view returns (uint256);

    /// @notice Native nine-decimal DETF minted solely for the initial reserve self leg.
    function migrationBootstrapSelfMinted() external view returns (uint256);

    /// @notice Permissionless measured all-leg/native funding; no personal credit or LP beneficiary.
    /// @dev Require msg.value == nativeAmount_. Wrap exactly that value with configured WETH.
    /// Before reserve liveness minLpOut_ must be zero and lpOut_ is zero; book the received inputs.
    /// After liveness join only this batch's measured budget, enforce minimum/deadline, and retain
    /// refunds in protocol donation custody. Duplicate ERC20 inputs reject. An explicit WETH input
    /// and wrapped native value have separate measured receipts and must not be double counted.
    function donateMigrationCapital(
        IERC20[] calldata tokens_, uint256[] calldata amounts_, uint256 nativeAmount_,
        uint256 minLpOut_, uint256 deadline_
    ) external payable returns (uint256 lpOut_);
}

/// @notice Entire current-core administration surface; current-owner-only and removed at activation.
/// @dev Only the two admitted NFT sources, weighted liquid, weighted SY and fixed DTF-custody SE; no attribution shortcut.
/// Do not place permanent reads on the implementing allocation facet.
interface IUniswapV4DetfMigrationAllocation {
    /// @notice Replace complete originals for exactly W-SW, E-P or W-P; removed at activation.
    function configureHeldSeLpEntitlements(
        IUniswapV4DetfMigration.HeldSeLpEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 complete native18 ED original and known components; no issuance or conversion.
    function configureEarlierLiquidEntitlements(
        IUniswapV4DetfMigration.EarlierLiquidEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 complete original internal-share allocation; computes C0 on the frozen book.
    function configureEarlierReceiptEntitlements(
        IUniswapV4DetfMigration.EarlierReceiptEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 complete original-gon allocation and known original components; loading never issues.
    function configureWeightedReceiptEntitlements(
        IUniswapV4DetfMigration.WeightedReceiptEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 complete original-wallet direct-share configuration; no raw-weight authority or issuance.
    function configureClaimVaultEntitlements(
        IUniswapV4DetfMigration.ClaimVaultEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 full replacement on the frozen book; static WY shares, no issuance or live valuation.
    function configureWeightedSyEntitlements(
        IUniswapV4DetfMigration.WeightedSyEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Replace one fully prepared eligible remainder; floor(full original quote * eligible/original).
    /// @dev No prior Migration delivery, raw-weight pull, preparation credit or arbitrary credit input.
    /// Shares the ordinary SY original identity and remaining-credit ledger; removed at activation.
    function configureClaimedSyEntitlements(
        IUniswapV4DetfMigration.ClaimedSyEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage1 full replacement on the frozen book; native 28-decimal DTF-custody SE shares, no issuance or live valuation.
    function configureDtfCustodySeEntitlements(
        IUniswapV4DetfMigration.DtfCustodySeEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Stage 1 full replacement initializes Q/C from original units and the frozen quote without issuance.
    /// @dev Surrender is closed while this selector exists; execution facts are never cleared.
    function configureWeightedLiquidEntitlements(
        IUniswapV4DetfMigration.WeightedLiquidEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Replace complete original NFT inputs on the frozen book without minting.
    /// @dev Consumed identities and recovery custody cannot be reset or redirected by replacement.
    function configureNftEntitlements(IUniswapV4DetfMigration.NftEntitlementInput[] calldata inputs_, bytes32 expectedBookId_) external;
    /// @notice Complete replacement with two originals: ETH first, DTF second, both nonzero.
    /// @dev Each is quoted separately and receives its own bond on the same atomic Stage2 surrender.
    /// The scalar entitlement credit is their sum; configureNftEntitlements retains one-bond semantics.
    function configureNftContributionEntitlements(
        IUniswapV4DetfMigration.NftEntitlementInput[] calldata inputs_, bytes32 expectedBookId_
    ) external;
    /// @notice Current owner selects/executes the one-time pooled genesis, not an arbitrary donor.
    /// @dev Exactly one representation per external hook leg; anchorIndex_ indexes legs_.
    /// Consume only booked budgets; derive selfMinted_ from actual consumed anchor capital using
    /// configured opening/creation rules. LP goes to the fixed bond child; retain all refunds.
    function bootstrapMigrationReserve(
        IUniswapV4DetfMigration.GenesisLeg[] calldata legs_, uint256 anchorIndex_,
        uint256 minLpOut_, uint256 deadline_
    ) external returns (uint256 selfMinted_, uint256 lpOut_);

    /// @notice Current owner replaces complete manual inputs until activation, even after the paid purchase.
    function setMigrationWeightedPricing(IUniswapV4DetfMigrationWeightedPricing.Inputs calldata next_)
        external returns (bytes32 bookId_);

    /// @notice Whole-batch atomic full-value replacement, including already issued recipients.
    /// @dev Quote each distinct original separately using the frozen book, then sum. Identical
    /// payloads are idempotent. Configuration neither mints nor changes prior issuance/bonds.
    function configureIndependentAllocations(
        IUniswapV4DetfMigration.IndependentAllocationInput[] calldata allocations_, bytes32 expectedBookId_
    ) external;

    /// @notice Issue each selected current configuration exactly once into a fresh funded cliff NFT.
    /// @dev Settle prior participation before new principal; use stored credit, not a supplied amount.
    /// Reject stale configuration identities, repeat issuance and zero credit; any item failure
    /// reverts the whole batch. bondTokenIds_ follows request order. No retroactive top-up.
    function issueIndependentAllocations(
        IUniswapV4DetfMigration.IndependentIssuanceRequest[] calldata requests_
    ) external returns (uint256[] memory bondTokenIds_);

    /// @notice Atomically finalize and remove this entire installed administration surface.
    /// @dev Require all five fixed children Idle. Resolve actual owning facets for Remove cuts;
    /// no initializer, external callback, asset transfer, beneficiary scan or restoration route.
    function activateMigration() external;
}

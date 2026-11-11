// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4DetfMigrationSnapshot} from "./IUniswapV4DetfMigrationSnapshot.sol";

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

    /// @notice One selected representation of an external reserve leg, funded from booked donations.
    /// @dev amount is native token units; minSharesOut is native units of that leg's SE shares.
    /// The self leg is generated internally and must not be supplied in this array.
    struct GenesisLeg {
        IERC20 token;
        uint256 amount;
        uint256 minSharesOut;
    }

    error MigrationAlreadyActivated();
    error InvalidIndependentAllocation(address recipient);
    error IndependentAllocationAlreadyIssued(address recipient);
    error IndependentConfigurationMismatch(address recipient, bytes32 expected, bytes32 actual);
    error DuplicateOriginalEntitlement(bytes32 entitlementId);
    error InvalidGenesisLeg(address token);
    error InsufficientDonationInventory(address token, uint256 requested, uint256 available);
    error UnexpectedMigrationNativeValue(uint256 expected, uint256 actual);

    event MigrationCapitalReceived(address indexed donor, address indexed token, uint256 amount);
    event MigrationCapitalConsumed(address indexed token, uint256 amount);
    event MigrationCapitalRetained(address indexed token, uint256 amount);
    event MigrationReserveBootstrapped(uint256 selfMinted, uint256 lpOut, uint256 timestamp);
    event MigrationSnapshotCaptured(bytes32 indexed snapshotId, uint256 blockNumber);
    event IndependentAllocationConfigured(
        address indexed recipient, bytes32 indexed configurationId, bytes32 evidenceId, uint256 totalCredit
    );
    event IndependentAllocationIssued(
        address indexed recipient, bytes32 indexed configurationId, uint256 indexed bondTokenId,
        uint256 credit, uint256 issuedAt
    );
    event MigrationActivated(address indexed owner);
    event MigrationSyRewardTokenWired(address indexed rewardToken, address indexed receipt);

    /// @notice Sole finalized reward/new-money gate. Activation does not reset clocks or indices.
    function migrationActivated() external view returns (bool);

    /// @notice Once-wired RT child; receipt must reject RT caller admission while this is zero.
    function migrationSyRewardToken() external view returns (address);

    /// @notice Package-bound source: this parent, its installed fee oracle, WETH and original DTF.
    function migrationSnapshotSource() external view returns (IUniswapV4DetfMigrationSnapshot.Source memory);

    /// @notice Complete immutable quote book. Reverts SnapshotNotCaptured before capture.
    function migrationSnapshot() external view returns (IUniswapV4DetfMigrationSnapshot.Snapshot memory);

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
/// @dev No E1/E2-dependent source configuration, surrender tuple, arbitrary-credit issuer or price setter.
/// Do not place permanent reads on the implementing allocation facet.
interface IUniswapV4DetfMigrationAllocation {
    /// @notice Current owner selects/executes the one-time pooled genesis, not an arbitrary donor.
    /// @dev Exactly one representation per external hook leg; anchorIndex_ indexes legs_.
    /// Consume only booked budgets; derive selfMinted_ from actual consumed anchor capital using
    /// configured opening/creation rules. LP goes to the fixed bond child; retain all refunds.
    function bootstrapMigrationReserve(
        IUniswapV4DetfMigration.GenesisLeg[] calldata legs_, uint256 anchorIndex_,
        uint256 minLpOut_, uint256 deadline_
    ) external returns (uint256 selfMinted_, uint256 lpOut_);

    /// @notice Capture once from configured contracts after funding, without caller-provided prices.
    function captureMigrationSnapshot() external returns (bytes32 snapshotId_);

    /// @notice Whole-batch atomic full-value replacement, including already issued recipients.
    /// @dev Quote each distinct original separately using the frozen book, then sum. Identical
    /// payloads are idempotent. Configuration neither mints nor changes prior issuance/bonds.
    function configureIndependentAllocations(
        IUniswapV4DetfMigration.IndependentAllocationInput[] calldata allocations_
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

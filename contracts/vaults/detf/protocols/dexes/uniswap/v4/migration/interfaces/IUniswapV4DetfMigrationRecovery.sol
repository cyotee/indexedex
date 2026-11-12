// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @notice Retained current-owner recovery of admitted chain-4663 NFTs, weighted liquid, SY and fixed DTF-custody SE.
interface IUniswapV4DetfMigrationRecovery {
    enum Stage {
        WeightedClaim,
        WeightedPrincipal,
        WeightedRewards,
        WeightedUnstake,
        WeightedConvert,
        EarlierClaim,
        EarlierSale,
        Donate,
        WeightedSyRedeem,
        DtfCustodySeRedeem,
        ClaimVaultRedeem
    }

    /// @dev NFT stages use tokenId; conversions/donation use amount. minimum is native DTF
    /// output, external earlier receipt shares, reserve LP, native WS output for SY redemption,
    /// native9 SY for claim-vault redemption, or native18 DTF for DTF-custody SE redemption. Unused fields must
    /// be zero. No target, selector, recipient, pretransfer flag or route can be supplied.
    struct Step {
        Stage stage;
        uint256 tokenId;
        uint256 amount;
        uint256 minimum;
    }

    /// @dev Components are never summed across units or counted as new compensation.
    struct NftRecovery {
        uint256 principalClaimed;
        uint256 rewardsClaimed;
        uint256 receiptShares;
        bool sold;
    }

    error InvalidRecoveryStep();
    error InvalidRecoveryCustody(address collection, uint256 tokenId);
    error RecoveryInventoryInsufficient(address token, uint256 requested, uint256 available);
    error RecoveryDeltaMismatch(address token);
    error RecoveryGonsProtected(uint256 debit, uint256 attributed);
    error RecoveryPositionLocked(uint256 tokenId, uint256 unlockTime);

    event MigrationRecoveryClaimed(
        address indexed collection, uint256 indexed tokenId, uint256 principal, uint256 rewards
    );
    event MigrationRecoverySold(uint256 indexed tokenId, uint256 originalShares, uint256 receiptShares, uint256 rewards);
    event MigrationRecoveryConverted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    /// @notice Actual WS gons received from selected WY; conversion dust stays at the legacy wrapper.
    /// @dev The synchronized divisor values recovery only, never configured compensation.
    event MigrationWeightedSyRedeemed(
        uint256 shares, uint256 receiptUnits, uint256 receivedGons, uint256 divisor, uint256 conversionDustGons
    );
    /// @notice Native representation of existing attributed gons at a synchronized divisor.
    /// @dev Not a claim, receipt transfer, principal issuance or compensation.
    event MigrationRecoveryRevalued(
        address indexed token, uint256 previousAmount, uint256 currentAmount, uint256 attributedGons, uint256 divisor
    );
    /// @dev Selected capital leaves recovery inventory once. Any unjoined remainder is held
    /// in the existing reserve residual domain, not spendable recovery inventory.
    event MigrationRecoveryDonated(address indexed token, uint256 amount, uint256 lpOut);

    /// @notice Execute only selected stages atomically. A later transaction cannot undo prior stages.
    function recoverMigrationNfts(Step[] calldata steps_, uint256 deadline_) external;
    /// @notice Undonated native token amounts; earlier receipt inventory is external shares (scale 1e9).
    /// @dev Weighted receipts reflect the last recovery claim/unstake synchronization.
    /// Later index growth is reconciled during the next such operation, not by this view.
    function migrationRecoveryInventory(address token_) external view returns (uint256);
    /// @notice Attributed weighted receipt gons; their synchronized whole value is convertible.
    /// @dev Actual source debit must still preserve every unbooked gon, including fractions.
    function migrationRecoveryGons() external view returns (uint256);
    /// @notice Standalone ER custody B in exact internal shares, separate from NFT external inventory E.
    /// @dev Whole external representation is B/1e9; fractional internal representation is B%1e9.
    /// Total booked internal ownership is checked E*1e9+B; neither query changes the other's unit.
    function migrationEarlierReceiptInternalShares() external view returns (uint256);
    function migrationNftRecovery(address collection_, uint256 tokenId_) external view returns (NftRecovery memory);
}

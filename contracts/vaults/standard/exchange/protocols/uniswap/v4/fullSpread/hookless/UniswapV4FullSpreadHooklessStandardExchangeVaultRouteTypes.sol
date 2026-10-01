// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// tag::UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes[]
/// @notice Hook-independent memory representations; no execution targets or storage.
library UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes {
    struct Uint2048 {
        uint256[8] limb;
    }

    struct Ratio {
        Uint2048 numerator;
        Uint2048 denominator;
    }

    enum Workflow {
        None,
        DirectExactInput,
        DirectExactOutput,
        Composition,
        BlockedIssue,
        Redeem,
        LinearExit,
        DualJoin,
        DualExit,
        Import,
        Maintenance
    }

    enum MaintenanceStatus {
        Unchanged,
        Placed,
        Improved,
        Deferred
    }

    struct Book {
        uint256[2] free;
        uint256[2] deployed;
        uint256[2] earned;
        uint256[2] credit;
        uint256[2] payout;
        uint256[2] refund;
        uint256[2] booked;
        uint256 supply;
    }

    struct PositionState {
        uint160 sqrtPriceX96;
        uint160 lowerX96;
        uint160 upperX96;
        int24 tick;
        int24 lower;
        int24 upper;
        uint128 liquidity;
        uint128 activeLiquidity;
        int128 liquidityChange;
        uint128 lowerLiquidityGross;
        uint128 upperLiquidityGross;
        uint128 maxLiquidityPerTick;
    }

    struct Snapshot {
        Book book;
        PositionState position;
        uint256 sleeveWad;
        uint256[2] absoluteFloor;
        bool idle;
    }

    struct Placement {
        bool funded;
        bool certified;
        int128 liquidityDelta;
        uint256[2] debt;
        uint256[2] proceeds;
        uint256[2] roundingLoss;
        Snapshot afterState;
    }

    struct Progress {
        Ratio compositionExcess;
        Ratio sleeveExcess;
    }

    struct Swap {
        bool zeroForOne;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
        uint256 feeGrowthInsideX128;
        uint32 steps;
        uint160 sqrtPriceAfterX96;
        int24 tickAfter;
        uint128 liquidityAfter;
    }

    struct Plan {
        Workflow workflow;
        bool valid;
        Swap swap;
        Placement fundingRemoval;
        Placement placement;
        uint256 shares;
        uint256[2] contribution;
        uint32 refinements;
        uint32 evaluations;
        MaintenanceStatus maintenance;
    }
}
// end::UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes[]

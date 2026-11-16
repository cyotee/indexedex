// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {Pool} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {
    IUniswapV4PairTokenStandardExchangeVault as IVault
} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultTypes[]
/// @notice Family-local data contracts for one complete operation and its exact projection.
/// @dev Only Config and Inventory are persistent economic data. Manager fee checkpoints
/// and supply in snapshots are observations, never a second authoritative storage ledger.
library UniswapV4PairTokenStandardExchangeVaultTypes {
    uint256 internal constant QUOTE_MAX_SWAP_STEPS = 64;
    uint256 internal constant QUOTE_MAX_INITIALIZED_TICK_CROSSINGS = 12;
    uint256 internal constant QUOTE_MAX_BITMAP_WORDS = 16;
    uint256 internal constant DUST = 1000;

    // tag::Config[]
    /// @dev Immutable after initialization. Position salt is always bytes32(0).
    struct Config {
        IPoolManager poolManager;
        PoolKey poolKey;
        address registry;
        address wrappedNative;
        address rateAsset;
        int24 tickLower;
        int24 tickUpper;
        uint16 maxZapBps;
        int24 maxZapTickMove;
        uint8 rateAssetDecimals;
    }
    // end::Config[]

    // tag::Amounts[]
    /// @dev Nonnegative raw amounts in actual PoolKey currency order.
    struct Amounts {
        uint256 amount0;
        uint256 amount1;
    }
    // end::Amounts[]

    // tag::WrappedReservations[]
    /// @dev Subsets of the corresponding currency0 reservation, not additional assets.
    /// Nonzero only while a native leg is temporarily represented by the bound wrapper.
    struct WrappedReservations {
        uint256 callerInput;
        uint256 exitAllocation;
        uint256 refund;
    }
    // end::WrappedReservations[]

    // tag::Inventory[]
    /// @dev Disjoint custody categories. Unbooked excess is derived after solvency checks.
    /// At external return only booked may remain nonzero. Shared basic-vault reserves
    /// are a published copy of booked, updated only after payouts and refunds.
    struct Inventory {
        Amounts booked;
        Amounts callerInput;
        Amounts exitAllocation;
        Amounts refund;
        WrappedReservations wrapped;
    }
    // end::Inventory[]

    enum OperationKind {
        None,
        DepositPair,
        DepositZap,
        RedeemPair,
        RedeemSingle,
        Compound,
        Donate
    }

    enum Phase {
        None,
        MaintenanceCollection,
        MaintenanceSwap,
        MaintenanceAddition,
        MaintenanceCheckpoint,
        EntrySwap,
        EntryCheckpoint,
        EntryAddition,
        ExitRemoval,
        ExitSale
    }

    enum ActionKind {
        ModifyLiquidity,
        Swap
    }

    enum FailureKind {
        None,
        WorkLimit,
        PriceLimit,
        LiquidityLimit,
        DeltaLimit,
        Economic
    }

    // tag::Operation[]
    /// @dev Economic request only; caller authority, minima, deadline and delivery
    /// validation remain execution concerns. amounts holds paired maxima, or the
    /// single actual-currency input. shares is populated only for withdrawals.
    /// token is the single input/output form (zero can mean raw native); paired
    /// operations and compound use zero. kind disambiguates these cases.
    struct Operation {
        OperationKind kind;
        Amounts amounts;
        uint256 shares;
        address token;
    }
    // end::Operation[]

    // tag::PoolState[]
    /// @dev Preserve the stored tick at exact boundaries; do not derive it from price.
    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 protocolFee;
        uint24 lpFee;
        uint128 liquidity;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }
    // end::PoolState[]

    // tag::Snapshot[]
    /// @dev Position uses canonical manager checkpoints. supply comes from ERC20Repo.
    struct Snapshot {
        Config config;
        uint256 supply;
        Inventory inventory;
        PoolState pool;
        Position.State position;
    }
    // end::Snapshot[]

    // tag::TickState[]
    /// @dev A keyed lazy cache entry. initial is immutable within a candidate.
    struct TickState {
        int24 tick;
        Pool.TickInfo initial;
        Pool.TickInfo current;
    }
    // end::TickState[]

    // tag::BitmapWord[]
    /// @dev A keyed lazy cache entry, including words read only in later phases.
    struct BitmapWord {
        int16 wordPos;
        uint256 initial;
        uint256 current;
    }
    // end::BitmapWord[]

    // tag::ProjectedState[]
    /// @dev Arrays may be preallocated; only the count prefixes are populated.
    /// Caches cover at most 12 crossed ticks plus two boundaries and 16 distinct words.
    /// Every swap shares swapSteps and tickCrossings; repeat crossings count again.
    /// A fallback candidate must start from fresh copies, never a rejected overlay.
    struct ProjectedState {
        Snapshot state;
        TickState[] ticks;
        BitmapWord[] words;
        uint256 tickCount;
        uint256 wordCount;
        uint256 swapSteps;
        uint256 tickCrossings;
    }
    // end::ProjectedState[]

    // tag::Witness[]
    /// @dev Hash abi.encode(config, pool, position), then ordered tick and word values
    /// for the complete plan's read set. The planner finalizes all phase witnesses
    /// after discovering that complete set, including later-only reads.
    /// Expected preceding vault actions are included; unrelated changes are not.
    /// Inventory and supply are excluded; Execution validates their independent
    /// ledger checkpoints, including burns and caller reservations.
    struct Witness {
        bytes32 stateHash;
        bytes32 ticksHash;
        bytes32 wordsHash;
    }
    // end::Witness[]

    // tag::Action[]
    /// @dev Exact manager action. ModifyLiquidity uses liquidityDelta (zero is a
    /// nonempty-position poke); Swap uses direction, amountIn and price limit.
    /// callerDelta is net settlement; subtract each widened feesAccrued component
    /// separately to recover principal. Never subtract packed BalanceDelta words.
    /// afterState covers the entire read set, not just records this action wrote.
    struct Action {
        Phase phase;
        ActionKind kind;
        int128 liquidityDelta;
        bool zeroForOne;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
        BalanceDelta callerDelta;
        BalanceDelta feesAccrued;
        Witness afterState;
    }
    // end::Action[]

    // tag::Failure[]
    /// @dev Typed planning failure, never a caught execution exception. Only WorkLimit
    /// has whole-candidate fallback scope; other limits require maintenance phases.
    /// revertData preserves the failed candidate's exact economic-domain error.
    struct Failure {
        Phase phase;
        FailureKind kind;
        bytes revertData;
    }
    // end::Failure[]

    // tag::Plan[]
    /// @dev One selected complete candidate, or its failure. Read keys are unique and
    /// ordered identically for every witness. No partial candidate is executable.
    /// credit is G+J for paired entry and G for zap; uncredited is zap J.
    /// shares is final issuance or the shares burned; fees includes every checkpoint once.
    struct Plan {
        Operation operation;
        IVault.WithdrawalMode mode;
        IVault.MaintenanceReason reason;
        Failure failure;
        Witness initialState;
        int24[] ticks;
        int16[] words;
        Action[] actions;
        Snapshot finalState;
        Amounts accepted;
        Amounts credit;
        Amounts uncredited;
        Amounts payout;
        Amounts fees;
        // Entry decomposition at the frozen pre-addition price: R, G and J.
        // qQuote is the paired candidate (including genesis), zero for other operations.
        uint256 qQuote;
        Amounts reserves;
        Amounts growth;
        Amounts residual;
        uint256 shares;
        uint256 swapSteps;
        uint256 tickCrossings;
    }
    // end::Plan[]
}
// end::UniswapV4PairTokenStandardExchangeVaultTypes[]

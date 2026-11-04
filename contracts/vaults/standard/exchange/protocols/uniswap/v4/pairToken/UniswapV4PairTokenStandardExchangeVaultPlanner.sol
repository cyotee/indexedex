// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "./UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "./UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultPlanner[]
/// @notice Complete economic plans for the one-position, one-supply exchange.
/// @dev No manager mutation, token call, exception recovery, or second swap replay.
/// Authorization, custody receipts, deadlines and minima are execution concerns.
library UniswapV4PairTokenStandardExchangeVaultPlanner {
    // tag::DirectCallNotAllowed-3921c703[]
    /// @custom:signature DirectCallNotAllowed()
    /// @custom:selector 0x3921c703
    error DirectCallNotAllowed();
    // end::DirectCallNotAllowed-3921c703[]
    // tag::ZapSizeExceeded-63413124[]
    /// @custom:signature ZapSizeExceeded(uint256,uint256)
    /// @custom:selector 0x63413124
    error ZapSizeExceeded(uint256 amount, uint256 maximum);
    // end::ZapSizeExceeded-63413124[]
    // tag::ZapTickMoveExceeded-7c4645c4[]
    /// @custom:signature ZapTickMoveExceeded(uint256,uint256)
    /// @custom:selector 0x7c4645c4
    error ZapTickMoveExceeded(uint256 movement, uint256 maximum);
    // end::ZapTickMoveExceeded-7c4645c4[]
    // tag::IncompleteExitSale-f31ce201[]
    /// @custom:signature IncompleteExitSale(uint256,uint256)
    /// @custom:selector 0xf31ce201
    error IncompleteExitSale(uint256 requested, uint256 consumed);
    // end::IncompleteExitSale-f31ce201[]

    // Maintenance: collection, swap, and either addition or final checkpoint (3).
    // Longest suffix: entry swap, entry checkpoint, entry addition (3).
    // Pair entry needs 1; withdrawals need at most removal and sale (2).
    uint256 private constant MAX_ACTIONS = 6;

    struct Candidate {
        Types.Plan result;
        Types.ProjectedState overlay;
        Types.ProjectedState initial;
        Types.ProjectedState[] captures;
        uint256 actionCount;
        uint160 lower;
        uint160 upper;
    }

    struct Entry {
        uint256 supply;
        uint256 qQuote;
        Types.Amounts reserves;
        Types.Amounts principal;
        Types.Amounts growth;
        Types.Amounts residual;
    }

    // tag::plan[]
    /// @notice Select a complete normal plan, or the permitted fresh withdrawal alternative.
    /// @dev The caller has loaded original_ for the correct zero-salt owner position.
    /// Typed failures bubble their exact revert data only after candidate selection.
    /// @custom:signature plan(UniswapV4PairTokenStandardExchangeVaultTypes.Snapshot,UniswapV4PairTokenStandardExchangeVaultTypes.Operation)
    /// @custom:selector 0x64309acc
    function plan(Types.Snapshot memory original_, Types.Operation memory operation_)
        public
        view
        returns (Types.Plan memory result)
    {
        _requireDelegateCall();
        _validate(original_, operation_);
        result = _candidate(original_, operation_, IVault.WithdrawalMode.FullCompound);
        if (result.failure.kind == Types.FailureKind.None) return result;
        if (_withdrawal(operation_.kind)) {
            IVault.MaintenanceReason reason = maintenanceReason(result.failure);
            if (reason != IVault.MaintenanceReason.None) {
                result = _candidate(original_, operation_, IVault.WithdrawalMode.CollectOnly);
                result.reason = reason;
            }
        }
        if (result.failure.kind != Types.FailureKind.None) {
            bytes memory data = result.failure.revertData;
            assembly ("memory-safe") {
                revert(add(data, 32), mload(data))
            }
        }
    }
    // end::plan[]

    /// @dev Compare the executing library's exact runtime with the current account.
    /// No self-link, hard-coded runtime header offset, or code-size assumption is used.
    function _requireDelegateCall() private view {
        bytes32 executingCodeHash;
        assembly ("memory-safe") {
            let scratch := mload(0x40)
            codecopy(scratch, 0, codesize())
            executingCodeHash := keccak256(scratch, codesize())
        }
        if (address(this).codehash == executingCodeHash) revert DirectCallNotAllowed();
    }

    // tag::maintenanceReason[]
    /// @notice The exhaustive fallback classifier; work exhaustion spans the entire candidate.
    /// @dev Exposed internally for independent phase/kind controls, not failure injection.
    function maintenanceReason(Types.Failure memory failure_)
        internal
        pure
        returns (IVault.MaintenanceReason)
    {
        if (failure_.kind == Types.FailureKind.WorkLimit) {
            return IVault.MaintenanceReason.MaintenanceWorkLimit;
        }
        if (failure_.phase == Types.Phase.MaintenanceSwap) {
            if (failure_.kind == Types.FailureKind.PriceLimit) {
                return IVault.MaintenanceReason.MaintenancePriceLimit;
            }
            if (failure_.kind == Types.FailureKind.DeltaLimit) {
                return IVault.MaintenanceReason.MaintenanceDeltaLimit;
            }
        }
        if (
            failure_.phase == Types.Phase.MaintenanceAddition
                && failure_.kind == Types.FailureKind.LiquidityLimit
        ) return IVault.MaintenanceReason.MaintenanceLiquidityLimit;
        return IVault.MaintenanceReason.None;
    }
    // end::maintenanceReason[]

    function _candidate(
        Types.Snapshot memory original_,
        Types.Operation memory operation_,
        IVault.WithdrawalMode mode_
    ) private view returns (Types.Plan memory) {
        Candidate memory work;
        work.result.operation = operation_;
        work.result.mode = mode_;
        work.result.actions = new Types.Action[](MAX_ACTIONS);
        work.captures = new Types.ProjectedState[](MAX_ACTIONS);
        work.overlay = Projection.fresh(original_);
        work.initial = Projection.capture(work.overlay);
        work.lower = TickMath.getSqrtPriceAtTick(original_.config.tickLower);
        work.upper = TickMath.getSqrtPriceAtTick(original_.config.tickUpper);
        if (!_maintenance(work)) return work.result;
        if (operation_.kind == Types.OperationKind.DepositPair) {
            if (!_pairedEntry(work)) return work.result;
        } else if (operation_.kind == Types.OperationKind.DepositZap) {
            if (!_zapEntry(work)) return work.result;
        } else if (_withdrawal(operation_.kind)) {
            if (!_exit(work)) return work.result;
        }
        // The economic final state is after payout/refund, not an extra custody book.
        delete work.overlay.state.inventory.callerInput;
        delete work.overlay.state.inventory.exitAllocation;
        delete work.overlay.state.inventory.refund;
        delete work.overlay.state.inventory.wrapped;
        work.result.finalState = work.overlay.state;
        work.result.swapSteps = work.overlay.swapSteps;
        work.result.tickCrossings = work.overlay.tickCrossings;
        (work.result.ticks, work.result.words) = Projection.readKeys(work.overlay);
        work.result.initialState = Projection.witness(work.initial, work.overlay);
        Types.Action[] memory actions = new Types.Action[](work.actionCount);
        for (uint256 i; i < work.actionCount; ++i) {
            actions[i] = work.result.actions[i];
            actions[i].afterState = Projection.witness(work.captures[i], work.overlay);
        }
        work.result.actions = actions;
        return work.result;
    }

    function _validate(Types.Snapshot memory original_, Types.Operation memory operation_) private pure {
        if (
            operation_.kind == Types.OperationKind.None || operation_.kind == Types.OperationKind.Donate
        ) revert IVault.InvalidAccountingState();
        if (
            original_.supply == 0
                && (original_.position.liquidity != 0 || original_.inventory.booked.amount0 != 0
                    || original_.inventory.booked.amount1 != 0)
        ) revert IVault.InvalidAccountingState();
        if (_withdrawal(operation_.kind) && (operation_.shares == 0 || operation_.shares > original_.supply)) {
            revert Math.InvalidAllocation();
        }
        if (operation_.kind == Types.OperationKind.DepositZap && original_.supply == 0) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Incumbent-only maintenance                        */
    /* -------------------------------------------------------------------------- */

    function _maintenance(Candidate memory work_) private view returns (bool) {
        if (work_.overlay.state.position.liquidity != 0) {
            if (!_modify(work_, 0, Types.Phase.MaintenanceCollection)) return false;
        }
        if (work_.result.mode == IVault.WithdrawalMode.CollectOnly) return true;
        Types.Amounts memory book = work_.overlay.state.inventory.booked;
        if (book.amount0 <= Types.DUST && book.amount1 <= Types.DUST) return true;
        (bool fits, bool zeroForOne, uint256 amount) = Math.tryCompoundSwap(
            work_.overlay.state.pool.sqrtPriceX96, work_.lower, work_.upper,
            book.amount0, book.amount1, work_.overlay.state.pool.liquidity,
            work_.overlay.state.config.maxZapBps
        );
        if (!fits) return _liquidityFailure(work_, Types.Phase.MaintenanceAddition);
        if (amount != 0 && !_swap(work_, zeroForOne, amount, Types.Phase.MaintenanceSwap)) return false;
        uint128 addition;
        (fits, addition) = _affordable(work_, work_.overlay.state.inventory.booked);
        if (!fits) return _liquidityFailure(work_, Types.Phase.MaintenanceAddition);
        if (addition != 0) return _modify(work_, int256(uint256(addition)), Types.Phase.MaintenanceAddition);
        // Initial collection was already current if no ratio swap took place.
        // A positive add itself checkpoints fees on pre-update owned liquidity.
        if (amount != 0 && work_.overlay.state.position.liquidity != 0) {
            return _modify(work_, 0, Types.Phase.MaintenanceCheckpoint);
        }
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Caller-only issuance                          */
    /* -------------------------------------------------------------------------- */

    function _pairedEntry(Candidate memory work_) private view returns (bool) {
        Entry memory entry = _entrySnapshot(work_);
        (entry.qQuote, work_.result.accepted.amount0, work_.result.accepted.amount1) = Math.pairedQuote(
            entry.supply, entry.reserves.amount0, entry.reserves.amount1,
            work_.result.operation.amounts.amount0, work_.result.operation.amounts.amount1
        );
        // Assignment, not addition: an incoming native reservation may already exist.
        work_.overlay.state.inventory.callerInput = Types.Amounts(
            work_.result.accepted.amount0, work_.result.accepted.amount1
        );
        if (!_entryAddition(work_, entry.supply == 0)) return false;
        _entryCredit(work_, entry, false);
        return true;
    }

    function _zapEntry(Candidate memory work_) private view returns (bool) {
        bool is0 = _token0(work_.overlay.state.config, work_.result.operation.token);
        Types.Amounts memory reserves = _reserves(work_);
        Types.Amounts memory amounts = work_.result.operation.amounts;
        uint256 amount = is0 ? amounts.amount0 : amounts.amount1;
        if (
            amount == 0 || (is0 ? amounts.amount1 : amounts.amount0) != 0
                || reserves.amount0 == 0 || reserves.amount1 == 0
        ) revert IVault.InvalidAccountingState();
        uint256 maximum = FullMath.mulDiv(
            is0 ? reserves.amount0 : reserves.amount1, work_.overlay.state.config.maxZapBps, 10000
        );
        if (amount > maximum) revert ZapSizeExceeded(amount, maximum);
        work_.result.accepted = Types.Amounts(amounts.amount0, amounts.amount1);
        work_.overlay.state.inventory.callerInput = Types.Amounts(amounts.amount0, amounts.amount1);
        int24 tickBefore = work_.overlay.state.pool.tick;
        if (amount / 2 != 0) {
            if (!_swap(work_, is0, amount / 2, Types.Phase.EntrySwap)) return false;
            int256 movement = int256(work_.overlay.state.pool.tick) - int256(tickBefore);
            uint256 absolute = uint256(movement < 0 ? -movement : movement);
            uint256 maximumMove = uint256(int256(work_.overlay.state.config.maxZapTickMove));
            if (absolute > maximumMove) revert ZapTickMoveExceeded(absolute, maximumMove);
            if (work_.overlay.state.position.liquidity != 0) {
                if (!_modify(work_, 0, Types.Phase.EntryCheckpoint)) return false;
            }
        }
        Entry memory entry = _entrySnapshot(work_);
        if (!_entryAddition(work_, false)) return false;
        _entryCredit(work_, entry, true);
        return true;
    }

    function _entrySnapshot(Candidate memory work_) private view returns (Entry memory entry) {
        entry.supply = work_.overlay.state.supply;
        entry.principal = _principal(work_);
        entry.reserves = Types.Amounts(
            entry.principal.amount0 + work_.overlay.state.inventory.booked.amount0,
            entry.principal.amount1 + work_.overlay.state.inventory.booked.amount1
        );
    }

    function _entryAddition(Candidate memory work_, bool genesis_) private view returns (bool) {
        (bool fits, uint128 addition) = _affordable(work_, work_.overlay.state.inventory.callerInput);
        if (!fits) return _liquidityFailure(work_, Types.Phase.EntryAddition);
        if (addition == 0) {
            if (genesis_) revert Math.ZeroShares();
            return true;
        }
        return _modify(work_, int256(uint256(addition)), Types.Phase.EntryAddition);
    }

    function _entryCredit(Candidate memory work_, Entry memory entry_, bool zap_) private view {
        Types.Amounts memory principal = _principal(work_);
        entry_.growth = Types.Amounts(
            principal.amount0 - entry_.principal.amount0, principal.amount1 - entry_.principal.amount1
        );
        entry_.residual = work_.overlay.state.inventory.callerInput;
        work_.result.qQuote = entry_.qQuote;
        work_.result.reserves = Types.Amounts(entry_.reserves.amount0, entry_.reserves.amount1);
        work_.result.growth = Types.Amounts(entry_.growth.amount0, entry_.growth.amount1);
        work_.result.residual = Types.Amounts(entry_.residual.amount0, entry_.residual.amount1);
        work_.result.credit = Types.Amounts(entry_.growth.amount0, entry_.growth.amount1);
        if (zap_) {
            work_.result.uncredited = Types.Amounts(entry_.residual.amount0, entry_.residual.amount1);
            work_.result.shares = Math.zapCredit(
                entry_.supply, entry_.reserves.amount0, entry_.reserves.amount1,
                entry_.growth.amount0, entry_.growth.amount1
            );
        } else {
            work_.result.credit.amount0 += entry_.residual.amount0;
            work_.result.credit.amount1 += entry_.residual.amount1;
            work_.result.shares = entry_.supply == 0 ? entry_.qQuote : Math.credit(
                entry_.supply, entry_.reserves.amount0, entry_.reserves.amount1,
                work_.result.credit.amount0, work_.result.credit.amount1, entry_.qQuote
            );
        }
        // Checked final supply, after the paired cap rather than an irrelevant qCredit.
        work_.overlay.state.supply = entry_.supply + work_.result.shares;
        work_.overlay.state.inventory.booked.amount0 += entry_.residual.amount0;
        work_.overlay.state.inventory.booked.amount1 += entry_.residual.amount1;
        delete work_.overlay.state.inventory.callerInput;
    }

    /* -------------------------------------------------------------------------- */
    /*                       Proportional allocation and exit sale                */
    /* -------------------------------------------------------------------------- */

    function _exit(Candidate memory work_) private view returns (bool) {
        Types.Snapshot memory state = work_.overlay.state;
        uint256 shares = work_.result.operation.shares;
        (uint128 removed, uint256 idle0, uint256 idle1) = Math.allocation(
            state.supply, shares, state.position.liquidity,
            state.inventory.booked.amount0, state.inventory.booked.amount1
        );
        work_.result.shares = shares;
        state.supply -= shares;
        state.inventory.booked.amount0 -= idle0;
        state.inventory.booked.amount1 -= idle1;
        state.inventory.exitAllocation = Types.Amounts(idle0, idle1);
        if (removed != 0 && !_modify(work_, -int256(uint256(removed)), Types.Phase.ExitRemoval)) return false;
        if (work_.result.operation.kind == Types.OperationKind.RedeemSingle) {
            bool output0 = _token0(state.config, work_.result.operation.token);
            uint256 unwanted = output0
                ? state.inventory.exitAllocation.amount1 : state.inventory.exitAllocation.amount0;
            if (unwanted != 0) {
                if (!_swap(work_, !output0, unwanted, Types.Phase.ExitSale)) return false;
                uint256 remaining = output0
                    ? state.inventory.exitAllocation.amount1 : state.inventory.exitAllocation.amount0;
                if (remaining != 0) revert IncompleteExitSale(unwanted, unwanted - remaining);
            }
            if ((output0 ? state.inventory.exitAllocation.amount0 : state.inventory.exitAllocation.amount1) == 0) {
                revert IVault.ZeroPayout();
            }
        } else if (state.inventory.exitAllocation.amount0 == 0 && state.inventory.exitAllocation.amount1 == 0) {
            revert IVault.ZeroPayout();
        }
        work_.result.payout = Types.Amounts(
            state.inventory.exitAllocation.amount0, state.inventory.exitAllocation.amount1
        );
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                      Manager actions and disjoint ledger                   */
    /* -------------------------------------------------------------------------- */

    function _modify(Candidate memory work_, int256 delta_, Types.Phase phase_) private view returns (bool) {
        Types.Action memory action;
        action.phase = phase_;
        action.kind = Types.ActionKind.ModifyLiquidity;
        (action.callerDelta, action.feesAccrued, work_.result.failure) =
            Projection.modify(work_.overlay, delta_, phase_);
        if (work_.result.failure.kind != Types.FailureKind.None) return false;
        action.liquidityDelta = int128(delta_);
        int256 fee0 = int256(action.feesAccrued.amount0());
        int256 fee1 = int256(action.feesAccrued.amount1());
        int256 principal0 = int256(action.callerDelta.amount0()) - fee0;
        int256 principal1 = int256(action.callerDelta.amount1()) - fee1;
        if (fee0 < 0 || fee1 < 0) revert IVault.InvalidAccountingState();
        // Nothing between the frozen checkpoint and caller add/removal can earn fees.
        if (
            (phase_ == Types.Phase.EntryAddition || phase_ == Types.Phase.ExitRemoval)
                && (fee0 != 0 || fee1 != 0)
        ) revert IVault.EconomicStateChanged();
        work_.overlay.state.inventory.booked.amount0 += uint256(fee0);
        work_.overlay.state.inventory.booked.amount1 += uint256(fee1);
        work_.result.fees.amount0 += uint256(fee0);
        work_.result.fees.amount1 += uint256(fee1);
        Types.Amounts memory inventory = phase_ == Types.Phase.EntryAddition
            ? work_.overlay.state.inventory.callerInput
            : phase_ == Types.Phase.ExitRemoval
                ? work_.overlay.state.inventory.exitAllocation : work_.overlay.state.inventory.booked;
        if (
            (delta_ > 0 && (principal0 > 0 || principal1 > 0))
                || (delta_ < 0 && (principal0 < 0 || principal1 < 0))
                || (delta_ == 0 && (principal0 != 0 || principal1 != 0))
        ) revert IVault.InvalidAccountingState();
        _apply(inventory, principal0, principal1);
        _capture(work_, action);
        return true;
    }

    function _swap(Candidate memory work_, bool zeroForOne_, uint256 amount_, Types.Phase phase_)
        private
        view
        returns (bool)
    {
        Types.Action memory action;
        action.phase = phase_;
        action.kind = Types.ActionKind.Swap;
        action.zeroForOne = zeroForOne_;
        action.amountIn = amount_;
        action.sqrtPriceLimitX96 = zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        (action.callerDelta, work_.result.failure) = Projection.swap(
            work_.overlay, zeroForOne_, amount_, action.sqrtPriceLimitX96, phase_
        );
        if (work_.result.failure.kind != Types.FailureKind.None) return false;
        Types.Amounts memory inventory = phase_ == Types.Phase.EntrySwap
            ? work_.overlay.state.inventory.callerInput
            : phase_ == Types.Phase.ExitSale
                ? work_.overlay.state.inventory.exitAllocation : work_.overlay.state.inventory.booked;
        _apply(inventory, int256(action.callerDelta.amount0()), int256(action.callerDelta.amount1()));
        _capture(work_, action);
        return true;
    }

    function _apply(Types.Amounts memory inventory_, int256 delta0_, int256 delta1_) private pure {
        inventory_.amount0 = delta0_ < 0
            ? inventory_.amount0 - uint256(-delta0_) : inventory_.amount0 + uint256(delta0_);
        inventory_.amount1 = delta1_ < 0
            ? inventory_.amount1 - uint256(-delta1_) : inventory_.amount1 + uint256(delta1_);
    }

    function _capture(Candidate memory work_, Types.Action memory action_) private view {
        work_.result.actions[work_.actionCount] = action_;
        work_.captures[work_.actionCount] = Projection.capture(work_.overlay);
        ++work_.actionCount;
    }

    function _affordable(Candidate memory work_, Types.Amounts memory amounts_)
        private
        view
        returns (bool fits, uint128 liquidity)
    {
        return Math.tryLiquidityForAmounts(
            work_.overlay.state.pool.sqrtPriceX96, work_.lower, work_.upper,
            amounts_.amount0, amounts_.amount1
        );
    }

    function _principal(Candidate memory work_) private view returns (Types.Amounts memory amounts) {
        (amounts.amount0, amounts.amount1) = Math.principal(
            work_.overlay.state.pool.sqrtPriceX96, work_.lower, work_.upper,
            work_.overlay.state.position.liquidity
        );
    }

    function _reserves(Candidate memory work_) private view returns (Types.Amounts memory amounts) {
        amounts = _principal(work_);
        amounts.amount0 += work_.overlay.state.inventory.booked.amount0;
        amounts.amount1 += work_.overlay.state.inventory.booked.amount1;
    }

    function _liquidityFailure(Candidate memory work_, Types.Phase phase_) private pure returns (bool) {
        work_.result.failure = Types.Failure(
            phase_, Types.FailureKind.LiquidityLimit, abi.encodeWithSelector(Math.LiquidityOverflow.selector)
        );
        return false;
    }

    function _token0(Types.Config memory config_, address token_) private view returns (bool) {
        address currency0 = Currency.unwrap(config_.poolKey.currency0);
        if (token_ == currency0 || (currency0 == address(0) && token_ == config_.wrappedNative)) return true;
        if (token_ == Currency.unwrap(config_.poolKey.currency1)) return false;
        revert IStandardExchangeErrors.InvalidRoute(token_, address(this));
    }

    function _withdrawal(Types.OperationKind kind_) private pure returns (bool) {
        return kind_ == Types.OperationKind.RedeemPair || kind_ == Types.OperationKind.RedeemSingle;
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultPlanner[]

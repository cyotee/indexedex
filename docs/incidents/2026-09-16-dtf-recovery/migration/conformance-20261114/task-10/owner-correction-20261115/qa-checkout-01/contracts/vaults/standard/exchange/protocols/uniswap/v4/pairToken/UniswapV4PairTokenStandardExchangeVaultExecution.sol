// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "./UniswapV4PairTokenStandardExchangeVaultMath.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "./UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultPlanner as Planner} from "./UniswapV4PairTokenStandardExchangeVaultPlanner.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "./interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultExecution[]
/// @notice Guarded custody and real-manager execution of one immutable selected plan.
/// @dev Every manager action gets a one-use callback commitment and closes its deltas.
/// The operation guard remains held across all unlocks, token calls and final payouts.
library UniswapV4PairTokenStandardExchangeVaultExecution {
    using SafeERC20 for IERC20;

    // tag::InvalidCallback-f7a632f5[]
    /// @custom:signature InvalidCallback()
    /// @custom:selector 0xf7a632f5
    error InvalidCallback();
    // end::InvalidCallback-f7a632f5[]
    // tag::InvalidNativeValue-1fa0ca33[]
    /// @custom:signature InvalidNativeValue(uint256,uint256)
    /// @custom:selector 0x1fa0ca33
    error InvalidNativeValue(uint256 expected, uint256 actual);
    // end::InvalidNativeValue-1fa0ca33[]
    // tag::NativeTransferFailed-f4b3b1bc[]
    /// @custom:signature NativeTransferFailed()
    /// @custom:selector 0xf4b3b1bc
    error NativeTransferFailed();
    // end::NativeTransferFailed-f4b3b1bc[]
    // tag::SettlementMismatch-d5e2090b[]
    /// @custom:signature SettlementMismatch()
    /// @custom:selector 0xd5e2090b
    error SettlementMismatch();
    // end::SettlementMismatch-d5e2090b[]

    struct Request {
        Types.Operation operation;
        address recipient;
        uint256 minimum0;
        uint256 minimum1;
        uint256 deadline;
        bool pretransferred;
    }

    struct Run {
        Types.Plan plan;
        Types.Snapshot state;
        Types.Witness witness;
        uint256 cursor;
        Types.Amounts fees;
        Types.Amounts maintenanceCosts;
        Types.Amounts entryCosts;
        uint128 maintenanceLiquidity;
        uint128 removed;
        Types.Amounts idle;
        Types.Amounts allocation;
        uint256 sold;
        uint256 proceeds;
    }

    struct Entry {
        uint256 quote;
        Types.Snapshot checkpoint;
        Types.Amounts principal;
        Types.Amounts reserves;
    }

    struct Callback {
        Types.OperationKind operation;
        Types.Snapshot beforeState;
        Types.Witness beforeWitness;
        Types.Action action;
        int24[] ticks;
        int16[] words;
    }

    /* -------------------------------------------------------------------------- */
    /*                          Stable internal entrypoints                        */
    /* -------------------------------------------------------------------------- */

    function depositPair(
        uint256 amount0Max_,
        uint256 amount1Max_,
        uint256 minShares_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256) {
        Request memory request;
        request.operation.kind = Types.OperationKind.DepositPair;
        request.operation.amounts = Types.Amounts(amount0Max_, amount1Max_);
        request.recipient = recipient_;
        request.minimum0 = minShares_;
        request.deadline = deadline_;
        Run memory run = UniswapV4PairTokenStandardExchangeVaultExecutionPreparation.prepare(request);
        _maintenance(run);
        _enter(run, request);
        _finish(run);
        emit IVault.PairDeposited(
            msg.sender, recipient_, run.plan.accepted.amount0, run.plan.accepted.amount1,
            run.entryCosts.amount0, run.entryCosts.amount1, run.plan.shares
        );
        return run.plan.shares;
    }

    function redeemPair(
        uint256 shares_,
        uint256 min0_,
        uint256 min1_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256, uint256) {
        Request memory request;
        request.operation.kind = Types.OperationKind.RedeemPair;
        request.operation.shares = shares_;
        request.recipient = recipient_;
        request.minimum0 = min0_;
        request.minimum1 = min1_;
        request.deadline = deadline_;
        Run memory run = UniswapV4PairTokenStandardExchangeVaultExecutionPreparation.prepare(request);
        _maintenance(run);
        _exit(run, request);
        _finish(run);
        emit IVault.PairRedeemed(
            msg.sender, recipient_, shares_, run.removed, run.idle.amount0, run.idle.amount1,
            run.plan.payout.amount0, run.plan.payout.amount1
        );
        return (run.plan.payout.amount0, run.plan.payout.amount1);
    }

    function exchangeIn(
        address tokenIn_,
        uint256 amountIn_,
        address tokenOut_,
        uint256 minimum_,
        address recipient_,
        bool pretransferred_,
        uint256 deadline_,
        bool allowNative_
    ) internal returns (uint256) {
        Repo._requireIdle();
        Request memory request;
        Types.Config memory config = Repo._layoutStruct().config;
        bool inputShare = tokenIn_ == address(this);
        bool outputShare = tokenOut_ == address(this);
        if (inputShare == outputShare) revert IStandardExchangeErrors.InvalidRoute(tokenIn_, tokenOut_);
        address token = inputShare ? tokenOut_ : tokenIn_;
        if (!_validToken(config, token, allowNative_)) {
            revert IStandardExchangeErrors.InvalidRoute(tokenIn_, tokenOut_);
        }
        request.operation.token = token;
        if (inputShare) {
            request.operation.kind = Types.OperationKind.RedeemSingle;
            request.operation.shares = amountIn_;
        } else {
            request.operation.kind = Types.OperationKind.DepositZap;
            if (_token0(config, token)) request.operation.amounts.amount0 = amountIn_;
            else request.operation.amounts.amount1 = amountIn_;
        }
        request.recipient = recipient_;
        request.minimum0 = minimum_;
        request.deadline = deadline_;
        request.pretransferred = pretransferred_;
        return _exchange(request);
    }

    // tag::donate-e69d849d[]
    /// @custom:signature donate(address,uint256)
    /// @custom:selector 0xe69d849d
    function donate(address token_, uint256 amount_) public {
        Run memory run;
        run.state = _start(Types.OperationKind.Donate, true);
        if (!_validToken(run.state.config, token_, true)) {
            revert IStandardExchangeErrors.InvalidRoute(token_, address(this));
        }
        if (amount_ == 0 || run.state.supply == 0) revert IVault.InvalidAccountingState();
        bool is0 = _token0(run.state.config, token_);
        _value(token_ == address(0) ? amount_ : 0);
        // The complete donation plan has no manager actions. Check the final sum
        // before any pull, and freeze the canonical position/boundary read set.
        uint256 finalBook = (is0 ? run.state.inventory.booked.amount0 : run.state.inventory.booked.amount1) + amount_;
        if (token_ == address(0)) run.state.inventory.callerInput.amount0 = amount_;
        _store(run.state);
        _solvent(run.state);
        Types.ProjectedState memory projected = Projection.fresh(run.state);
        (run.plan.ticks, run.plan.words) = Projection.readKeys(projected);
        run.witness = Projection.witness(projected);
        _fund(run, token_, amount_, token_ == address(0));
        if (is0) {
            run.state.inventory.booked.amount0 = finalBook;
            run.state.inventory.callerInput.amount0 = 0;
        } else {
            run.state.inventory.booked.amount1 = finalBook;
            run.state.inventory.callerInput.amount1 = 0;
        }
        _store(run.state);
        _check(run);
        _publish(run.state);
        emit IVault.Donated(msg.sender, token_, amount_);
    }
    // end::donate-e69d849d[]

    function compound() internal returns (uint256, uint256) {
        Request memory request;
        request.operation.kind = Types.OperationKind.Compound;
        Run memory run = UniswapV4PairTokenStandardExchangeVaultExecutionPreparation.prepare(request);
        _maintenance(run);
        _finish(run);
        return (run.fees.amount0, run.fees.amount1);
    }

    /// @notice Authenticate and consume exactly one committed real-manager action.
    function unlockCallback(bytes calldata payload_) internal returns (bytes memory) {
        Repo.Storage storage layoutStruct = Repo._layoutStruct();
        if (
            msg.sender != address(layoutStruct.config.poolManager)
                || layoutStruct.operation == Types.OperationKind.None || layoutStruct.callbackHash == bytes32(0)
                || layoutStruct.callbackHash != keccak256(abi.encode(layoutStruct.operation, payload_))
        ) revert InvalidCallback();
        Callback memory call = abi.decode(payload_, (Callback));
        if (call.operation != layoutStruct.operation) revert InvalidCallback();
        delete layoutStruct.callbackHash;
        if (!TransientStateLibrary.isUnlocked(layoutStruct.config.poolManager)) revert InvalidCallback();
        _checkState(call.beforeState, call.ticks, call.words, call.beforeWitness);
        _zeroDeltas(call.beforeState.config);
        (BalanceDelta actual, BalanceDelta fees) = _managerAction(call.beforeState.config, call.action);
        if (actual != call.action.callerDelta || fees != call.action.feesAccrued) {
            revert IVault.EconomicStateChanged();
        }
        _account(call.beforeState.inventory, call.action, actual, fees);
        _store(call.beforeState);
        // Validate the complete after-action witness before and after settlement;
        // it includes future-only words/ticks, not merely this action's writes.
        _checkState(call.beforeState, call.ticks, call.words, call.action.afterState);
        _settle(call, call.beforeState.config.poolKey.currency0, int256(actual.amount0()));
        _settle(call, call.beforeState.config.poolKey.currency1, int256(actual.amount1()));
        _zeroDeltas(call.beforeState.config);
        if (TransientStateLibrary.getNonzeroDeltaCount(call.beforeState.config.poolManager) != 0) {
            revert SettlementMismatch();
        }
        _solvent(call.beforeState);
        _checkState(call.beforeState, call.ticks, call.words, call.action.afterState);
        return abi.encode(actual, fees, call.beforeState.inventory);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Preflight and input isolation                     */
    /* -------------------------------------------------------------------------- */

    function _exchange(Request memory request_) private returns (uint256 result) {
        Run memory run = UniswapV4PairTokenStandardExchangeVaultExecutionPreparation.prepare(request_);
        _maintenance(run);
        if (request_.operation.kind == Types.OperationKind.DepositZap) {
            _enter(run, request_);
            result = run.plan.shares;
            emit IVault.ZapCredit(
                msg.sender, request_.recipient, request_.operation.token,
                run.plan.accepted.amount0 + run.plan.accepted.amount1,
                run.plan.credit.amount0, run.plan.credit.amount1,
                run.plan.uncredited.amount0, run.plan.uncredited.amount1, result
            );
        } else {
            _exit(run, request_);
            result = _token0(run.state.config, request_.operation.token)
                ? run.plan.payout.amount0 : run.plan.payout.amount1;
            emit IVault.WithdrawalSale(
                msg.sender, request_.recipient, request_.operation.token, request_.operation.shares,
                run.allocation.amount0, run.allocation.amount1, run.sold, run.proceeds, result
            );
        }
        _finish(run);
    }

    function prepare(Request memory request_) internal returns (Run memory run) {
        Repo._requireIdle();
        if (request_.operation.kind != Types.OperationKind.Compound) {
            if (request_.deadline < block.timestamp) {
                revert IStandardExchangeErrors.DeadlineExceeded(request_.deadline, block.timestamp);
            }
            if (request_.recipient == address(0) || request_.recipient == address(this)) {
                revert IERC20Errors.ERC20InvalidReceiver(request_.recipient);
            }
        }
        bool entry = request_.operation.kind == Types.OperationKind.DepositPair
            || request_.operation.kind == Types.OperationKind.DepositZap;
        run.state = _start(request_.operation.kind, entry);
        _reserveInitial(run, request_);
        _store(run.state);
        _solvent(run.state);
        // Planning is complete before a false-flag ERC20 pull or manager mutation.
        run.plan = Planner.plan(run.state, request_.operation);
        for (uint256 i; i < run.plan.actions.length; ++i) {
            _settleable(run.plan.actions[i].callerDelta);
        }
        run.witness = run.plan.initialState;
        _check(run);
    }

    function _start(Types.OperationKind kind_, bool inbound_) private returns (Types.Snapshot memory state) {
        Repo.Storage storage layoutStruct = Repo._layoutStruct();
        Repo._requireIdle(layoutStruct);
        if (!layoutStruct.initialized || layoutStruct.callbackHash != bytes32(0) || _reserved(layoutStruct.inventory)) {
            revert IVault.InvalidAccountingState();
        }
        if (TransientStateLibrary.isUnlocked(layoutStruct.config.poolManager)) revert IVault.ManagerAlreadyUnlocked();
        layoutStruct.operation = kind_;
        if (inbound_ && IVaultRegistryDisableQuery(layoutStruct.config.registry).isDisabled(address(this))) {
            revert IVault.IssuanceDisabled();
        }
        return Projection.loadSnapshot(layoutStruct.config, layoutStruct.inventory, ERC20Repo._totalSupply(), address(this));
    }

    function _reserveInitial(Run memory run_, Request memory request_) private view {
        if (request_.operation.kind == Types.OperationKind.DepositPair) {
            uint256 value = _native(run_.state.config) ? request_.operation.amounts.amount0 : 0;
            _value(value);
            run_.state.inventory.refund.amount0 = value;
        } else if (request_.operation.kind == Types.OperationKind.DepositZap) {
            uint256 amount = request_.operation.amounts.amount0 + request_.operation.amounts.amount1;
            if (amount == 0) revert IVault.InvalidAccountingState();
            if (request_.operation.token == address(0)) {
                _value(amount);
                if (request_.pretransferred) revert IVault.InvalidAccountingState();
                run_.state.inventory.callerInput.amount0 = amount;
            } else {
                _value(0);
                if (request_.pretransferred) {
                    LocalCreditLib.requirePretransferCaller(msg.sender);
                    _solvent(run_.state);
                    _claim(run_.state, request_.operation.token, amount);
                }
            }
        } else {
            _value(0);
            if (request_.operation.kind != Types.OperationKind.Compound) {
                _shareAuthority(request_.operation.shares, request_.pretransferred);
            }
        }
    }

    function _claim(Types.Snapshot memory state_, address token_, uint256 amount_) private view {
        uint256 booked;
        bool is0 = _token0(state_.config, token_);
        bool wrapped = _native(state_.config) && token_ == state_.config.wrappedNative;
        if (wrapped) {
            booked = _wrapped(state_.inventory);
        } else {
            booked = is0 ? _total0(state_.inventory) : _total1(state_.inventory);
        }
        uint256 available = LocalCreditLib.available(IERC20(token_).balanceOf(address(this)), booked);
        uint256 budget = LocalCreditLib.budget(available, amount_);
        if (budget != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, budget);
        if (is0) state_.inventory.callerInput.amount0 += amount_;
        else state_.inventory.callerInput.amount1 += amount_;
        if (wrapped) state_.inventory.wrapped.callerInput += amount_;
    }

    function _shareAuthority(uint256 shares_, bool internal_) private view {
        if (shares_ == 0) revert IVault.InvalidAccountingState();
        address holder = msg.sender;
        if (internal_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            holder = address(this);
        }
        uint256 balance = ERC20Repo._balanceOf(holder);
        if (internal_) {
            uint256 budget = LocalCreditLib.budget(LocalCreditLib.available(balance, 0), shares_);
            if (budget != shares_) revert ISecurePullErrors.TransferDeltaInsufficient(shares_, budget);
            return;
        }
        if (balance < shares_) {
            revert IERC20Errors.ERC20InsufficientBalance(holder, balance, shares_);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                         Selected phases and actual credit                   */
    /* -------------------------------------------------------------------------- */

    function _maintenance(Run memory run_) private {
        while (run_.cursor < run_.plan.actions.length) {
            Types.Phase phase = run_.plan.actions[run_.cursor].phase;
            if (
                phase != Types.Phase.MaintenanceCollection && phase != Types.Phase.MaintenanceSwap
                    && phase != Types.Phase.MaintenanceAddition && phase != Types.Phase.MaintenanceCheckpoint
            ) break;
            _action(run_);
        }
        emit IVault.Compounded(
            run_.fees.amount0, run_.fees.amount1,
            run_.maintenanceCosts.amount0, run_.maintenanceCosts.amount1, run_.maintenanceLiquidity
        );
    }

    function _enter(Run memory run_, Request memory request_) private {
        Entry memory entry;
        if (request_.operation.kind == Types.OperationKind.DepositPair) {
            entry = _entrySnapshot(run_.state);
            Types.Amounts memory accepted;
            (entry.quote, accepted.amount0, accepted.amount1) = Math.pairedQuote(
                entry.checkpoint.supply, entry.reserves.amount0, entry.reserves.amount1,
                request_.operation.amounts.amount0, request_.operation.amounts.amount1
            );
            _equalAmounts(accepted, run_.plan.accepted);
            if (_native(run_.state.config)) {
                run_.state.inventory.refund.amount0 -= accepted.amount0;
                run_.state.inventory.callerInput.amount0 = accepted.amount0;
                _store(run_.state);
            } else {
                _fund(run_, Currency.unwrap(run_.state.config.poolKey.currency0), accepted.amount0, false);
            }
            _fund(run_, Currency.unwrap(run_.state.config.poolKey.currency1), accepted.amount1, false);
        } else {
            uint256 amount = request_.operation.amounts.amount0 + request_.operation.amounts.amount1;
            _equalAmounts(request_.operation.amounts, run_.plan.accepted);
            _fund(run_, request_.operation.token, amount, request_.pretransferred || request_.operation.token == address(0));
            while (
                run_.cursor < run_.plan.actions.length
                    && run_.plan.actions[run_.cursor].phase != Types.Phase.EntryAddition
            ) {
                _action(run_);
            }
            entry = _entrySnapshot(run_.state);
        }
        _check(run_);
        while (run_.cursor < run_.plan.actions.length) _action(run_);
        _mintCredit(run_, request_, entry);
        if (run_.state.inventory.refund.amount0 != 0) {
            uint256 refund = run_.state.inventory.refund.amount0;
            run_.state.inventory.refund.amount0 = 0;
            _store(run_.state);
            _send(run_, address(0), msg.sender, refund);
        }
    }

    function _entrySnapshot(Types.Snapshot memory state_) private view returns (Entry memory entry) {
        entry.checkpoint = abi.decode(abi.encode(state_), (Types.Snapshot));
        entry.principal = _principal(state_);
        entry.reserves = Types.Amounts(
            entry.principal.amount0 + state_.inventory.booked.amount0,
            entry.principal.amount1 + state_.inventory.booked.amount1
        );
    }

    function _mintCredit(Run memory run_, Request memory request_, Entry memory entry_) private {
        Types.Amounts memory principal = _principal(run_.state);
        Types.Amounts memory credit = Types.Amounts(
            principal.amount0 - entry_.principal.amount0, principal.amount1 - entry_.principal.amount1
        );
        Types.Amounts memory residual = run_.state.inventory.callerInput;
        uint256 shares;
        if (request_.operation.kind == Types.OperationKind.DepositPair) {
            credit.amount0 += residual.amount0;
            credit.amount1 += residual.amount1;
            shares = entry_.checkpoint.supply == 0 ? entry_.quote : Math.credit(
                entry_.checkpoint.supply, entry_.reserves.amount0, entry_.reserves.amount1,
                credit.amount0, credit.amount1, entry_.quote
            );
            if (entry_.checkpoint.supply == 0 && run_.state.position.liquidity == 0) {
                revert IVault.InvalidAccountingState();
            }
        } else {
            shares = Math.zapCredit(
                entry_.checkpoint.supply, entry_.reserves.amount0, entry_.reserves.amount1,
                credit.amount0, credit.amount1
            );
            _equalAmounts(residual, run_.plan.uncredited);
        }
        _equalAmounts(credit, run_.plan.credit);
        if (shares == 0 || shares != run_.plan.shares) revert IVault.EconomicStateChanged();
        _minimum(request_.minimum0, shares);
        _check(run_);
        run_.state.supply += shares;
        ERC20Repo._mint(request_.recipient, shares);
        run_.state.inventory.booked.amount0 += residual.amount0;
        run_.state.inventory.booked.amount1 += residual.amount1;
        delete run_.state.inventory.callerInput;
        _store(run_.state);
        _check(run_);
    }

    function _exit(Run memory run_, Request memory request_) private {
        _check(run_);
        (run_.removed, run_.idle.amount0, run_.idle.amount1) = Math.allocation(
            run_.state.supply, request_.operation.shares, run_.state.position.liquidity,
            run_.state.inventory.booked.amount0, run_.state.inventory.booked.amount1
        );
        _shareAuthority(request_.operation.shares, request_.pretransferred);
        ERC20Repo._burn(request_.pretransferred ? address(this) : msg.sender, request_.operation.shares);
        run_.state.supply -= request_.operation.shares;
        run_.state.inventory.booked.amount0 -= run_.idle.amount0;
        run_.state.inventory.booked.amount1 -= run_.idle.amount1;
        run_.state.inventory.exitAllocation = Types.Amounts(run_.idle.amount0, run_.idle.amount1);
        _store(run_.state);
        if (run_.cursor < run_.plan.actions.length && run_.plan.actions[run_.cursor].phase == Types.Phase.ExitRemoval) {
            _action(run_);
        }
        run_.allocation = Types.Amounts(
            run_.state.inventory.exitAllocation.amount0, run_.state.inventory.exitAllocation.amount1
        );
        while (run_.cursor < run_.plan.actions.length) _action(run_);
        _equalAmounts(run_.state.inventory.exitAllocation, run_.plan.payout);
        if (request_.operation.kind == Types.OperationKind.RedeemPair) {
            if (run_.plan.payout.amount0 == 0 && run_.plan.payout.amount1 == 0) revert IVault.ZeroPayout();
            _minimum(request_.minimum0, run_.plan.payout.amount0);
            _minimum(request_.minimum1, run_.plan.payout.amount1);
            _payout(run_, Currency.unwrap(run_.state.config.poolKey.currency0), request_.recipient, true);
            _payout(run_, Currency.unwrap(run_.state.config.poolKey.currency1), request_.recipient, false);
        } else {
            bool is0 = _token0(run_.state.config, request_.operation.token);
            uint256 amount = is0 ? run_.plan.payout.amount0 : run_.plan.payout.amount1;
            if (amount == 0) revert IVault.ZeroPayout();
            if ((is0 ? run_.plan.payout.amount1 : run_.plan.payout.amount0) != 0) {
                revert IVault.InvalidAccountingState();
            }
            _minimum(request_.minimum0, amount);
            _payout(run_, request_.operation.token, request_.recipient, is0);
        }
        emit IVault.WithdrawalMaintenanceSelected(run_.plan.mode, run_.plan.reason);
    }

    /* -------------------------------------------------------------------------- */
    /*                          One-use manager action dispatch                    */
    /* -------------------------------------------------------------------------- */

    function _action(Run memory run_) private {
        _check(run_);
        Types.Action memory action = run_.plan.actions[run_.cursor];
        Repo.Storage storage layoutStruct = Repo._layoutStruct();
        if (TransientStateLibrary.isUnlocked(run_.state.config.poolManager)) revert IVault.ManagerAlreadyUnlocked();
        Callback memory call = Callback(
            layoutStruct.operation, run_.state, run_.witness, action, run_.plan.ticks, run_.plan.words
        );
        bytes memory payload = abi.encode(call);
        layoutStruct.callbackHash = keccak256(abi.encode(layoutStruct.operation, payload));
        bytes memory returned = run_.state.config.poolManager.unlock(payload);
        if (layoutStruct.callbackHash != bytes32(0)) revert InvalidCallback();
        if (TransientStateLibrary.isUnlocked(run_.state.config.poolManager)) revert SettlementMismatch();
        (BalanceDelta actual, BalanceDelta fees, Types.Inventory memory inventory) =
            abi.decode(returned, (BalanceDelta, BalanceDelta, Types.Inventory));
        if (actual != action.callerDelta || fees != action.feesAccrued) revert IVault.EconomicStateChanged();
        run_.state.inventory = inventory;
        run_.witness = action.afterState;
        _check(run_);
        run_.state = Projection.loadSnapshot(
            run_.state.config, run_.state.inventory, run_.state.supply, address(this)
        );
        _record(run_, action, actual, fees);
        ++run_.cursor;
    }

    function _managerAction(Types.Config memory config_, Types.Action memory action_)
        private returns (BalanceDelta actual, BalanceDelta fees)
    {
        if (action_.kind == Types.ActionKind.ModifyLiquidity) {
            return config_.poolManager.modifyLiquidity(
                config_.poolKey,
                ModifyLiquidityParams(config_.tickLower, config_.tickUpper, action_.liquidityDelta, bytes32(0)),
                ""
            );
        }
        int256 specified;
        unchecked {
            specified = -int256(action_.amountIn);
        }
        actual = config_.poolManager.swap(
            config_.poolKey, SwapParams(action_.zeroForOne, specified, action_.sqrtPriceLimitX96), ""
        );
    }

    function _account(
        Types.Inventory memory inventory_,
        Types.Action memory action_,
        BalanceDelta actual_,
        BalanceDelta fees_
    ) private pure {
        int256 d0 = int256(actual_.amount0());
        int256 d1 = int256(actual_.amount1());
        if (action_.kind == Types.ActionKind.ModifyLiquidity) {
            int256 f0 = int256(fees_.amount0());
            int256 f1 = int256(fees_.amount1());
            if (f0 < 0 || f1 < 0) revert IVault.InvalidAccountingState();
            d0 -= f0;
            d1 -= f1;
            if (
                d0 < type(int128).min || d0 > type(int128).max
                    || d1 < type(int128).min || d1 > type(int128).max
            ) revert IVault.InvalidAccountingState();
            if (
                (action_.liquidityDelta > 0 && (d0 > 0 || d1 > 0))
                    || (action_.liquidityDelta < 0 && (d0 < 0 || d1 < 0))
                    || (action_.liquidityDelta == 0 && (d0 != 0 || d1 != 0))
            ) revert IVault.InvalidAccountingState();
            if (
                (action_.phase == Types.Phase.EntryAddition || action_.phase == Types.Phase.ExitRemoval)
                    && (f0 != 0 || f1 != 0)
            ) revert IVault.EconomicStateChanged();
            inventory_.booked.amount0 += uint256(f0);
            inventory_.booked.amount1 += uint256(f1);
        }
        Types.Amounts memory source;
        if (action_.phase == Types.Phase.EntryAddition || action_.phase == Types.Phase.EntrySwap) {
            source = inventory_.callerInput;
        } else if (action_.phase == Types.Phase.ExitRemoval || action_.phase == Types.Phase.ExitSale) {
            source = inventory_.exitAllocation;
        } else {
            source = inventory_.booked;
        }
        source.amount0 = _delta(source.amount0, d0);
        source.amount1 = _delta(source.amount1, d1);
    }

    function _record(Run memory run_, Types.Action memory action_, BalanceDelta actual_, BalanceDelta fees_)
        private pure
    {
        run_.fees.amount0 += uint256(int256(fees_.amount0()));
        run_.fees.amount1 += uint256(int256(fees_.amount1()));
        if (action_.phase == Types.Phase.MaintenanceAddition || action_.phase == Types.Phase.EntryAddition) {
            Types.Amounts memory costs = action_.phase == Types.Phase.MaintenanceAddition
                ? run_.maintenanceCosts : run_.entryCosts;
            costs.amount0 += uint256(int256(fees_.amount0()) - int256(actual_.amount0()));
            costs.amount1 += uint256(int256(fees_.amount1()) - int256(actual_.amount1()));
            if (action_.phase == Types.Phase.MaintenanceAddition) {
                run_.maintenanceLiquidity += uint128(action_.liquidityDelta);
            }
        } else if (action_.phase == Types.Phase.ExitSale) {
            int256 spent = action_.zeroForOne ? int256(actual_.amount0()) : int256(actual_.amount1());
            int256 received = action_.zeroForOne ? int256(actual_.amount1()) : int256(actual_.amount0());
            run_.sold += uint256(-spent);
            run_.proceeds += uint256(received);
        }
    }

    function _settle(Callback memory call_, Currency currency_, int256 delta_) private {
        IPoolManager manager = call_.beforeState.config.poolManager;
        if (TransientStateLibrary.currencyDelta(manager, address(this), currency_) != delta_) {
            revert SettlementMismatch();
        }
        uint256 beforeBalance = _balance(Currency.unwrap(currency_));
        if (delta_ < 0) {
            uint256 debt = uint256(-delta_);
            // The negative int128 endpoint is a valid packed delta, but settle()
            // casts the POSITIVE paid amount to int128. Do not split settlement.
            if (debt > uint256(uint128(type(int128).max))) revert SettlementMismatch();
            uint256 paid;
            manager.sync(currency_);
            if (Currency.unwrap(currency_) == address(0)) {
                // Native sync MUST be immediately before value settlement.
                paid = manager.settle{value: debt}();
            } else {
                IERC20(Currency.unwrap(currency_)).safeTransfer(address(manager), debt);
                _checkState(call_.beforeState, call_.ticks, call_.words, call_.action.afterState);
                paid = manager.settle();
            }
            if (paid != debt || _balance(Currency.unwrap(currency_)) != beforeBalance - debt) {
                revert SettlementMismatch();
            }
        } else if (delta_ > 0) {
            manager.take(currency_, address(this), uint256(delta_));
            if (_balance(Currency.unwrap(currency_)) != beforeBalance + uint256(delta_)) {
                revert SettlementMismatch();
            }
        }
        if (TransientStateLibrary.currencyDelta(manager, address(this), currency_) != 0) {
            revert SettlementMismatch();
        }
        _checkState(call_.beforeState, call_.ticks, call_.words, call_.action.afterState);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Exact token and wrapper receipts                   */
    /* -------------------------------------------------------------------------- */

    function _fund(Run memory run_, address token_, uint256 amount_, bool reserved_) private {
        _check(run_);
        if (amount_ == 0) return;
        bool is0 = _token0(run_.state.config, token_);
        bool wrapped = _native(run_.state.config) && token_ == run_.state.config.wrappedNative;
        if (!reserved_) {
            uint256 beforeBalance = _balance(token_);
            IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);
            _check(run_);
            uint256 afterBalance = _balance(token_);
            uint256 received = afterBalance >= beforeBalance ? afterBalance - beforeBalance : 0;
            if (received != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received);
            if (is0) run_.state.inventory.callerInput.amount0 += amount_;
            else run_.state.inventory.callerInput.amount1 += amount_;
            if (wrapped) run_.state.inventory.wrapped.callerInput += amount_;
            _store(run_.state);
        }
        if (wrapped) _unwrap(run_, amount_);
        _solvent(run_.state);
        _check(run_);
    }

    function _unwrap(Run memory run_, uint256 amount_) private {
        _check(run_);
        uint256 nativeBefore = address(this).balance;
        uint256 wrappedBefore = IERC20(run_.state.config.wrappedNative).balanceOf(address(this));
        IWETH(run_.state.config.wrappedNative).withdraw(amount_);
        _check(run_);
        if (
            address(this).balance != nativeBefore + amount_
                || IERC20(run_.state.config.wrappedNative).balanceOf(address(this)) != wrappedBefore - amount_
        ) revert SettlementMismatch();
        run_.state.inventory.wrapped.callerInput -= amount_;
        _store(run_.state);
    }

    function _payout(Run memory run_, address token_, address recipient_, bool is0_) private {
        uint256 amount = is0_ ? run_.state.inventory.exitAllocation.amount0 : run_.state.inventory.exitAllocation.amount1;
        if (amount == 0) return;
        if (_native(run_.state.config) && token_ == run_.state.config.wrappedNative) {
            _check(run_);
            uint256 nativeBefore = address(this).balance;
            uint256 wrappedBefore = IERC20(token_).balanceOf(address(this));
            IWETH(token_).deposit{value: amount}();
            _check(run_);
            if (
                address(this).balance != nativeBefore - amount
                    || IERC20(token_).balanceOf(address(this)) != wrappedBefore + amount
            ) revert SettlementMismatch();
            run_.state.inventory.wrapped.exitAllocation = amount;
            _store(run_.state);
            _solvent(run_.state);
        }
        if (is0_) run_.state.inventory.exitAllocation.amount0 = 0;
        else run_.state.inventory.exitAllocation.amount1 = 0;
        run_.state.inventory.wrapped.exitAllocation = 0;
        _store(run_.state);
        _send(run_, token_, recipient_, amount);
    }

    function _send(Run memory run_, address token_, address recipient_, uint256 amount_) private {
        _check(run_);
        uint256 beforeBalance = _balance(token_);
        if (token_ == address(0)) {
            (bool success,) = recipient_.call{value: amount_}("");
            if (!success) revert NativeTransferFailed();
        } else {
            uint256 recipientBefore = IERC20(token_).balanceOf(recipient_);
            IERC20(token_).safeTransfer(recipient_, amount_);
            if (IERC20(token_).balanceOf(recipient_) != recipientBefore + amount_) revert SettlementMismatch();
        }
        if (_balance(token_) != beforeBalance - amount_) revert SettlementMismatch();
        _check(run_);
        _solvent(run_.state);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Invariants and final reserve publication               */
    /* -------------------------------------------------------------------------- */

    function _finish(Run memory run_) private {
        if (run_.cursor != run_.plan.actions.length) revert IVault.InvalidAccountingState();
        _check(run_);
        _equalAmounts(run_.fees, run_.plan.fees);
        if (
            run_.state.supply != run_.plan.finalState.supply
                || keccak256(abi.encode(run_.state.inventory)) != keccak256(abi.encode(run_.plan.finalState.inventory))
                || keccak256(abi.encode(run_.state.pool, run_.state.position))
                    != keccak256(abi.encode(run_.plan.finalState.pool, run_.plan.finalState.position))
        ) revert IVault.EconomicStateChanged();
        if (
            run_.state.supply == 0
                && (run_.state.position.liquidity != 0 || run_.state.inventory.booked.amount0 != 0
                    || run_.state.inventory.booked.amount1 != 0)
        ) revert IVault.InvalidAccountingState();
        _publish(run_.state);
    }

    function _publish(Types.Snapshot memory state_) private {
        if (_reserved(state_.inventory)) revert IVault.InvalidAccountingState();
        _solvent(state_);
        _zeroDeltas(state_.config);
        Repo.Storage storage layoutStruct = Repo._layoutStruct();
        if (layoutStruct.callbackHash != bytes32(0)) revert InvalidCallback();
        address face0 = _native(state_.config)
            ? state_.config.wrappedNative : Currency.unwrap(state_.config.poolKey.currency0);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(face0), state_.inventory.booked.amount0);
        MultiAssetBasicVaultRepo._updateReserve(
            IERC20(Currency.unwrap(state_.config.poolKey.currency1)), state_.inventory.booked.amount1
        );
        layoutStruct.operation = Types.OperationKind.None;
    }

    function _check(Run memory run_) private view {
        _checkState(run_.state, run_.plan.ticks, run_.plan.words, run_.witness);
    }

    function _checkState(
        Types.Snapshot memory expected_,
        int24[] memory ticks_,
        int16[] memory words_,
        Types.Witness memory witness_
    ) private view {
        Repo.Storage storage layoutStruct = Repo._layoutStruct();
        if (
            layoutStruct.operation == Types.OperationKind.None || layoutStruct.callbackHash != bytes32(0)
                || ERC20Repo._totalSupply() != expected_.supply
                || keccak256(abi.encode(layoutStruct.inventory)) != keccak256(abi.encode(expected_.inventory))
                || keccak256(abi.encode(layoutStruct.config)) != keccak256(abi.encode(expected_.config))
                || !Projection.check(expected_, address(this), ticks_, words_, witness_)
        ) revert IVault.EconomicStateChanged();
    }

    function _store(Types.Snapshot memory state_) private {
        Repo._layoutStruct().inventory = state_.inventory;
    }

    function _solvent(Types.Snapshot memory state_) private view {
        Types.Inventory memory inventory = state_.inventory;
        uint256 wrapped = _wrapped(inventory);
        if (
            inventory.wrapped.callerInput > inventory.callerInput.amount0
                || inventory.wrapped.exitAllocation > inventory.exitAllocation.amount0
                || inventory.wrapped.refund > inventory.refund.amount0
        ) revert IVault.InvalidAccountingState();
        uint256 total0 = _total0(inventory);
        if (_native(state_.config)) {
            if (
                address(this).balance < total0 - wrapped
                    || (wrapped != 0 && IERC20(state_.config.wrappedNative).balanceOf(address(this)) < wrapped)
            ) revert IVault.InvalidAccountingState();
        } else if (
            wrapped != 0 || IERC20(Currency.unwrap(state_.config.poolKey.currency0)).balanceOf(address(this)) < total0
        ) revert IVault.InvalidAccountingState();
        if (IERC20(Currency.unwrap(state_.config.poolKey.currency1)).balanceOf(address(this)) < _total1(inventory)) {
            revert IVault.InvalidAccountingState();
        }
    }

    function _zeroDeltas(Types.Config memory config_) private view {
        if (
            TransientStateLibrary.currencyDelta(config_.poolManager, address(this), config_.poolKey.currency0) != 0
                || TransientStateLibrary.currencyDelta(config_.poolManager, address(this), config_.poolKey.currency1) != 0
        ) revert SettlementMismatch();
    }

    function _settleable(BalanceDelta delta_) private pure {
        // Paid values, unlike signed caller deltas, have a positive int128 bound.
        if (
            int256(delta_.amount0()) < -int256(type(int128).max)
                || int256(delta_.amount1()) < -int256(type(int128).max)
        ) revert SettlementMismatch();
    }

    function _principal(Types.Snapshot memory state_) private view returns (Types.Amounts memory amounts) {
        (amounts.amount0, amounts.amount1) = Math.principal(
            state_.pool.sqrtPriceX96, TickMath.getSqrtPriceAtTick(state_.config.tickLower),
            TickMath.getSqrtPriceAtTick(state_.config.tickUpper), state_.position.liquidity
        );
    }

    function _validToken(Types.Config memory config_, address token_, bool allowNative_) private pure returns (bool) {
        if (token_ == address(0)) return allowNative_ && _native(config_);
        return token_ == Currency.unwrap(config_.poolKey.currency0)
            || token_ == Currency.unwrap(config_.poolKey.currency1)
            || (_native(config_) && token_ == config_.wrappedNative);
    }

    function _native(Types.Config memory config_) private pure returns (bool) {
        return Currency.unwrap(config_.poolKey.currency0) == address(0);
    }

    function _token0(Types.Config memory config_, address token_) private pure returns (bool) {
        return token_ == Currency.unwrap(config_.poolKey.currency0)
            || (_native(config_) && token_ == config_.wrappedNative);
    }

    function _balance(address token_) private view returns (uint256) {
        return token_ == address(0) ? address(this).balance : IERC20(token_).balanceOf(address(this));
    }

    function _value(uint256 expected_) private view {
        if (msg.value != expected_) revert InvalidNativeValue(expected_, msg.value);
    }

    function _minimum(uint256 minimum_, uint256 actual_) private pure {
        if (actual_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, actual_);
    }

    function _equalAmounts(Types.Amounts memory actual_, Types.Amounts memory expected_) private pure {
        if (actual_.amount0 != expected_.amount0 || actual_.amount1 != expected_.amount1) {
            revert IVault.EconomicStateChanged();
        }
    }

    function _delta(uint256 inventory_, int256 delta_) private pure returns (uint256) {
        if (delta_ >= 0) return inventory_ + uint256(delta_);
        uint256 debt = uint256(-delta_);
        if (inventory_ < debt) revert IVault.InvalidAccountingState();
        return inventory_ - debt;
    }

    function _total0(Types.Inventory memory inventory_) private pure returns (uint256) {
        return inventory_.booked.amount0 + inventory_.callerInput.amount0
            + inventory_.exitAllocation.amount0 + inventory_.refund.amount0;
    }

    function _total1(Types.Inventory memory inventory_) private pure returns (uint256) {
        return inventory_.booked.amount1 + inventory_.callerInput.amount1
            + inventory_.exitAllocation.amount1 + inventory_.refund.amount1;
    }

    function _wrapped(Types.Inventory memory inventory_) private pure returns (uint256) {
        return inventory_.wrapped.callerInput + inventory_.wrapped.exitAllocation + inventory_.wrapped.refund;
    }

    function _reserved(Types.Inventory memory inventory_) private pure returns (bool) {
        return inventory_.callerInput.amount0 != 0 || inventory_.callerInput.amount1 != 0
            || inventory_.exitAllocation.amount0 != 0 || inventory_.exitAllocation.amount1 != 0
            || inventory_.refund.amount0 != 0 || inventory_.refund.amount1 != 0
            || inventory_.wrapped.callerInput != 0 || inventory_.wrapped.exitAllocation != 0
            || inventory_.wrapped.refund != 0;
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultExecution[]

/// @notice Fixed linked preparation boundary; direct calls are rejected by Solidity's library guard.
library UniswapV4PairTokenStandardExchangeVaultExecutionPreparation {
    // tag::prepare-075f9b34[]
    /// @custom:signature prepare(UniswapV4PairTokenStandardExchangeVaultExecution.Request)
    /// @custom:selector 0x075f9b34
    function prepare(UniswapV4PairTokenStandardExchangeVaultExecution.Request memory request_)
        public returns (UniswapV4PairTokenStandardExchangeVaultExecution.Run memory)
    {
        return UniswapV4PairTokenStandardExchangeVaultExecution.prepare(request_);
    }
    // end::prepare-075f9b34[]
}


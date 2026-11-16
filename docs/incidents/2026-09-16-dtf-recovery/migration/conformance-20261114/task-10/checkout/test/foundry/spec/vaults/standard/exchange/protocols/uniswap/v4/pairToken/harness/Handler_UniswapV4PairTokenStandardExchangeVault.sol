// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {CommonBase} from "forge-std/Base.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary, PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Position} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {PoolActor} from "./PoolActor.sol";

// tag::Handler_UniswapV4PairTokenStandardExchangeVault[]
/// @notice Public-route ownership controls for a registered real ERC20/ERC20 vault.
/// @dev No family Math/Planner oracle, synthetic share issuance, SUT writes or mocks.
/// Random capital is 1e6..1e16 raw units; explicit endpoint vectors admit <=1e34.
/// Shares, principal, credit and their cross-products are never narrowed to those bounds.
/// All rational inequalities use two-word products. The independent amount0 formula
/// floors/ceils the complete L*Q96*(upper-price)/(upper*price) rational by nested
/// division (floor(floor(n/a)/b) == floor(n/(a*b)), likewise for ceilings).
/// ERC20-only is intentional here: the separate native suite owns representation tests.
contract Handler_UniswapV4PairTokenStandardExchangeVault is CommonBase, StdAssertions {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    enum Action { Pair, Zap, PairExit, SingleExit, Donation, Unsolicited, Transfer, Trade, Compound, Restart }

    struct Amounts { uint256 a0; uint256 a1; }
    struct SignedAmounts { int256 a0; int256 a1; }
    struct Snapshot {
        uint256 supply;
        uint128 liquidity;
        uint160 price;
        Amounts book;
        Amounts wallet;
        Amounts manager;
        uint256 shares;
    }
    struct Trace {
        uint160 price;
        uint160 removalPrice;
        uint128 added;
        uint128 removed;
        uint128 maintenanceAdded;
        uint256 checkpointCount;
        uint256 callerAdds;
        uint256 callerSwaps;
        uint256 removals;
        uint256 modes;
        Amounts maintenanceCosts;
        Amounts costs;
        SignedAmounts maintenanceNet;
        SignedAmounts maintenanceSwap;
        SignedAmounts callerNet;
        SignedAmounts callerSwap;
        bytes pairEvent;
        bytes zapEvent;
        bytes exitEvent;
        bytes saleEvent;
        bytes modeEvent;
        uint256 shareEvents;
        uint256 shareAmount;
        address token;
    }
    struct EntryControl {
        Amounts used;
        Amounts residual;
        Amounts growth;
        Amounts reserve;
        uint128 preLiquidity;
        uint256 quote;
        uint256 credit;
        uint256 minted;
    }
    struct ExitControl {
        Amounts payout;
        Amounts allocation;
        Amounts principal;
        Amounts idle;
        Amounts preBook;
        uint128 preLiquidity;
    }
    struct ExitRequest {
        address holder;
        bool single;
        bool is0;
        uint256 burned;
    }
    struct SwapEvent {
        int128 delta0;
        int128 delta1;
        uint160 price;
        uint128 liquidity;
        int24 tick;
        uint24 fee;
    }

    IVault public immutable vault;
    IPoolManager public immutable manager;
    IERC20 public immutable shares;
    ERC20PermitMintableStub public immutable token0;
    ERC20PermitMintableStub public immutable token1;
    PoolActor public immutable poolActor;
    address private immutable creator;
    PoolKey private key;
    int24 private immutable lower;
    int24 private immutable upper;
    uint160 private immutable sqrtLower;
    uint160 private immutable sqrtUpper;
    address[4] public holders;
    mapping(address => uint256) public ghostHolderShares;
    uint256 public ghostSupply;
    uint256 public unsolicited0;
    uint256 public unsolicited1;
    uint256 public zapResidual0;
    uint256 public zapResidual1;
    uint256 public entrySwapFees0;
    uint256 public entrySwapFees1;
    int256 public marketDelta0;
    int256 public marketDelta1;
    uint256[10] public successes;
    uint256 public partialEntryFills;
    uint256 public cappedPairs;
    uint256 public uncappedPairs;
    uint256 public roundingEntries;
    uint256 public rejectedZeroCredit;
    uint256 public rejectedZeroPayout;
    uint256 public terminalResets;
    uint256 public genesisCount;
    bool public handlerFailed;
    bytes public failureData;

    /// @notice Attach only an empty, already registered real family instance.
    constructor(IVault vault_, PoolActor actor_) {
        creator = msg.sender;
        vault = vault_;
        manager = vault_.poolManager();
        key = vault_.poolKey();
        require(Currency.unwrap(key.currency0) != address(0), "ERC20 invariant domain");
        token0 = ERC20PermitMintableStub(Currency.unwrap(key.currency0));
        token1 = ERC20PermitMintableStub(Currency.unwrap(key.currency1));
        shares = IERC20(address(vault_));
        poolActor = actor_;
        lower = TickMath.minUsableTick(key.tickSpacing);
        upper = TickMath.maxUsableTick(key.tickSpacing);
        sqrtLower = TickMath.getSqrtPriceAtTick(lower);
        sqrtUpper = TickMath.getSqrtPriceAtTick(upper);
        holders = [address(0xA11CE), address(0xB0B), address(0xCA401), address(0xDA7E)];
        require(shares.totalSupply() == 0, "handler requires fresh proxy");
    }

    /// @notice Paired public entry with independently bounded maxima and a distinct holder.
    function pairedEntry(uint256 who, uint256 a0, uint256 a1) external {
        _dispatch(Action.Pair, who, _capital(a0), _capital(a1));
    }

    /// @notice Public SE zap in either direction, with input <= 0.1% of the current basket.
    function zap(uint256 who, uint256 direction, uint256 amount) external {
        // The +2 marks a bounded random input. Even economic reads run inside
        // the assertion frame so a broken query cannot be silently discarded.
        _dispatch(Action.Zap, who, direction % 2 + 2, amount);
    }

    /// @notice Burn up to half an active holder's shares via paired public redemption.
    function pairedExit(uint256 who, uint256 fraction) external {
        _dispatch(Action.PairExit, who, fraction, 0);
    }

    /// @notice Burn up to half an active holder's shares and sell only its allocation.
    function singleExit(uint256 who, uint256 direction, uint256 fraction) external {
        _dispatch(Action.SingleExit, who, direction % 2, fraction);
    }

    /// @notice Pull a same-call donation, never adopting prior unsolicited transfers.
    function donate(uint256 who, uint256 direction, uint256 amount) external {
        _dispatch(Action.Donation, who, direction % 2, _capital(amount));
    }

    /// @notice Transfer real underlying tokens directly, tracking both unbooked amounts.
    function unsolicited(uint256 who, uint256 a0, uint256 a1) external {
        _dispatch(Action.Unsolicited, who, _capital(a0), _capital(a1));
    }

    /// @notice Transfer ordinary shares between different tracked holders.
    function transferShares(uint256 who, uint256 to, uint256 amount) external {
        _dispatch(Action.Transfer, who, to, amount);
    }

    /// @notice A genuine externally owned PoolActor trades; market deltas are not NAV promises.
    function trade(uint256 direction, uint256 amount) external {
        _dispatch(Action.Trade, 0, direction % 2, _capital(amount));
    }

    /// @notice Public maintenance reconciles manager receipts without minting shares.
    function compound() external { _dispatch(Action.Compound, 0, 0, 0); }

    /// @notice Consolidate by public transfers, close every share, then publicly restart.
    function closeAndRestart(uint256 recipient) external { _dispatch(Action.Restart, recipient, 0, 0); }

    /// @notice Exact bounded vectors for deterministic tests, not invariant-fuzzer selectors.
    function scenario(Action action, uint256 who, uint256 a, uint256 b) external {
        require(msg.sender == creator, "scenario owner");
        require(a <= 1e34 && b <= 1e34, "scenario capital bound");
        _dispatch(action, who, a, b);
        require(!handlerFailed, string(failureData));
    }

    /// @notice Isolated assertion frame; unexpected failures are latched by the outer call.
    /// @dev Only this handler may execute it. It is not a targetSelector. With Foundry's
    /// default fail_on_revert=false, reverting the fuzz wrapper would discard evidence.
    function execute(Action action, uint256 who, uint256 a, uint256 b) external {
        require(msg.sender == address(this), "internal assertion frame");
        address holder = holders[who % holders.length];
        if (action == Action.Pair) _pair(holder, a, b);
        else if (action == Action.Zap) _zap(holder, a % 2 == 0, a < 2 ? b : _zapAmount(a % 2 == 0, b));
        else if (action == Action.PairExit) _exit(_active(who), false, false, a, false);
        else if (action == Action.SingleExit) _exit(_active(who), true, a == 0, b, false);
        else if (action == Action.Donation) _donate(holder, a == 0, b);
        else if (action == Action.Unsolicited) _unsolicited(holder, a, b);
        else if (action == Action.Transfer) _transfer(_active(who), a, b);
        else if (action == Action.Trade) _trade(a == 0, b);
        else if (action == Action.Compound) _compound();
        else _restart(who);
        assertStable();
    }

    function _dispatch(Action action, uint256 who, uint256 a, uint256 b) private {
        if (handlerFailed) return;
        (bool ok, bytes memory reason) = address(this).call(abi.encodeCall(this.execute, (action, who, a, b)));
        if (!ok) {
            handlerFailed = true;
            failureData = reason;
        }
    }

    function _zapAmount(bool is0, uint256 seed) private view returns (uint256) {
        (uint256 r0, uint256 r1) = vault.basket();
        uint256 cap = (is0 ? r0 : r1) / 1000;
        if (cap > 1e16) cap = 1e16;
        return cap == 0 ? 1 : 1 + seed % cap;
    }

    function _pair(address holder, uint256 a0, uint256 a1) private {
        _fund(holder, a0, a1);
        Snapshot memory before_ = _snapshot(holder);
        vm.recordLogs();
        vm.prank(holder);
        uint256 result = vault.depositPair(a0, a1, 0, holder, block.timestamp);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Trace memory trace = _trace(logs, before_, holder, true);
        EntryControl memory e = _entry(before_, trace, holder, true);
        e.quote = before_.supply == 0 ? _sqrt(a0 * a1) : _pairQuote(before_.supply, e.reserve, a0, a1);
        if (before_.supply == 0) {
            require(e.used.a0 == a0 && e.used.a1 == a1 && trace.added != 0, "public genesis");
            require(e.minted == e.quote, "complete genesis shares");
            ++genesisCount;
        } else {
            _accepted(before_.supply, e, a0, a1);
            e.credit = _credit(before_.supply, e.reserve, _plus(e.growth, e.residual), e.quote);
            require(e.minted == e.credit, "paired capped credit");
            if (e.credit < e.quote) ++cappedPairs;
            else ++uncappedPairs;
            _nonDilution(before_.supply, e, true);
        }
        require(result == e.minted, "pair returned shares");
        require(keccak256(trace.pairEvent) == keccak256(abi.encode(
            e.used.a0, e.used.a1, trace.costs.a0, trace.costs.a1, e.minted
        )), "PairDeposited decomposition");
        _mintGhost(holder, e.minted);
        ++successes[uint256(Action.Pair)];
    }

    function _zap(address holder, bool is0, uint256 amount) private {
        _fund(holder, is0 ? amount : 0, is0 ? 0 : amount);
        Snapshot memory before_ = _snapshot(holder);
        bytes memory callData = abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            IERC20(is0 ? address(token0) : address(token1)), amount, shares, 0, holder, false, block.timestamp
        ));
        bytes32 rollback = _stateHash();
        vm.recordLogs();
        vm.prank(holder);
        (bool ok, bytes memory output) = address(vault).call(callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        if (!ok) {
            // Only zero minted credit is admitted in the tiny random-input domain.
            // Arbitrary planner/accounting/manager/transfer failures are not ignored.
            require(keccak256(output) == keccak256(abi.encodeWithSignature("ZeroShares()")), "unexpected zap failure");
            require(_stateHash() == rollback, "zap failure rollback");
            (bool previewOK, bytes memory previewError) = address(vault).staticcall(
                abi.encodeCall(IVault.previewZapCredit, (is0 ? address(token0) : address(token1), amount))
            );
            require(!previewOK && keccak256(previewError) == keccak256(output), "zero credit classification");
            ++rejectedZeroCredit;
            return;
        }
        Trace memory trace = _trace(logs, before_, holder, true);
        EntryControl memory e = _entry(before_, trace, holder, false);
        require(e.used.a0 == (is0 ? amount : 0) && e.used.a1 == (is0 ? 0 : amount), "zap exact input");
        require(trace.token == (is0 ? address(token0) : address(token1)), "zap event input token");
        require(trace.callerSwaps == (amount / 2 == 0 ? 0 : 1), "caller half-swap count");
        uint256 consumed = uint256(-(is0 ? trace.callerSwap.a0 : trace.callerSwap.a1));
        require(consumed <= amount / 2, "half input exceeded");
        if (consumed < amount / 2) ++partialEntryFills;
        e.credit = _credit(before_.supply, e.reserve, e.growth, type(uint256).max);
        require(e.minted == e.credit && abi.decode(output, (uint256)) == e.minted, "uncapped zap credit");
        _nonDilution(before_.supply, e, false);
        require(keccak256(trace.zapEvent) == keccak256(abi.encode(
            amount, e.growth.a0, e.growth.a1, e.residual.a0, e.residual.a1, e.minted
        )), "ZapCredit decomposition");
        zapResidual0 += e.residual.a0;
        zapResidual1 += e.residual.a1;
        _mintGhost(holder, e.minted);
        ++successes[uint256(Action.Zap)];
    }

    function _entry(Snapshot memory before_, Trace memory t, address holder, bool paired)
        private returns (EntryControl memory e)
    {
        Snapshot memory after_ = _snapshot(holder);
        require(t.checkpointCount == 1 && t.removed == 0 && t.callerAdds <= 1, "entry phases");
        require(t.price == after_.price, "entry final price");
        require(after_.liquidity >= t.added, "caller addition exceeds position");
        e.preLiquidity = after_.liquidity - t.added;
        require(e.preLiquidity == before_.liquidity + t.maintenanceAdded, "maintenance not caller liquidity");
        e.used = Amounts(before_.wallet.a0 - after_.wallet.a0, before_.wallet.a1 - after_.wallet.a1);
        e.residual = _minus(_apply(e.used, t.callerSwap), t.costs);
        Amounts memory prePrincipal = _principal(after_.price, e.preLiquidity, false);
        e.growth = _minus(_principal(after_.price, after_.liquidity, false), prePrincipal);
        Amounts memory preBook = _minus(after_.book, e.residual);
        // A second independent reconstruction prevents final-book subtraction from
        // merely accepting a mislabeled caller residual or incumbent fee receipt.
        Amounts memory callerFees = _positive(_addSigned(
            _subSigned(t.callerNet, t.callerSwap), _signed(t.costs)
        ));
        Amounts memory maintained = _apply(before_.book, t.maintenanceNet);
        require(_equal(preBook, _plus(maintained, callerFees)), "incumbent book/fee isolation");
        if (paired) require(callerFees.a0 == 0 && callerFees.a1 == 0, "unexpected paired post-checkpoint fee");
        else {
            entrySwapFees0 += callerFees.a0;
            entrySwapFees1 += callerFees.a1;
        }
        e.reserve = _plus(prePrincipal, preBook);
        e.minted = after_.shares - before_.shares;
        require(e.minted != 0 && after_.supply == before_.supply + e.minted, "actual mint conservation");
        require(t.shareEvents == 1 && t.shareAmount == e.minted, "one actual mint event");
        if (t.costs.a0 > e.growth.a0 || t.costs.a1 > e.growth.a1) ++roundingEntries;
        _managerNet(before_, after_, t);
    }

    function _exit(address holder, bool single, bool is0, uint256 seed, bool terminal) private {
        uint256 balance = shares.balanceOf(holder);
        uint256 maximum = terminal ? balance : balance / 2;
        if (maximum == 0) maximum = balance;
        require(maximum != 0, "no active exit holder");
        _runExit(ExitRequest(holder, single, is0, terminal ? maximum : 1 + seed % maximum));
    }

    function _runExit(ExitRequest memory request) private {
        address holder = request.holder;
        Snapshot memory before_ = _snapshot(holder);
        address outputToken = request.is0 ? address(token0) : address(token1);
        bytes memory callData = _exitCallData(request);
        (bool planned, bytes memory modeData) = address(vault).staticcall(abi.encodeCall(
            IVault.previewWithdrawalMode, (request.burned, !request.single, request.single ? outputToken : address(0))
        ));
        bytes32 rollback = _stateHash();
        vm.recordLogs();
        vm.prank(holder);
        (bool ok, bytes memory returned) = address(vault).call(callData);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        if (!ok) {
            require(keccak256(returned) == keccak256(abi.encodeWithSelector(IVault.ZeroPayout.selector)), "unexpected exit failure");
            require(!planned && keccak256(modeData) == keccak256(returned), "zero payout classification");
            require(_stateHash() == rollback, "exit failure rollback");
            ++rejectedZeroPayout;
            return;
        }
        require(planned, "execution disagrees with withdrawal plan");
        Trace memory t = _trace(logs, before_, holder, false);
        require(t.modes == 1 && keccak256(t.modeEvent) == keccak256(modeData), "maintenance mode");
        if (request.single) require(t.token == outputToken, "sale event output token");
        _exitEvidence(request, before_, t, returned);
    }

    function _exitCallData(ExitRequest memory request) private view returns (bytes memory) {
        if (!request.single) {
            return abi.encodeCall(IVault.redeemPair, (request.burned, 0, 0, request.holder, block.timestamp));
        }
        return abi.encodeCall(IStandardExchangeIn.exchangeIn, (
            shares, request.burned, IERC20(request.is0 ? address(token0) : address(token1)),
            0, request.holder, false, block.timestamp
        ));
    }

    function _exitEvidence(ExitRequest memory request, Snapshot memory before_, Trace memory t, bytes memory returned) private {
        address holder = request.holder;
        uint256 burned = request.burned;
        Snapshot memory after_ = _snapshot(holder);
        ExitControl memory e;
        e.payout = _minus(after_.wallet, before_.wallet);
        e.allocation = _apply(e.payout, SignedAmounts(-t.callerSwap.a0, -t.callerSwap.a1));
        e.principal = _principal(t.removals == 0 ? t.price : t.removalPrice, t.removed, false);
        e.idle = _minus(e.allocation, e.principal);
        e.preBook = _plus(after_.book, e.idle);
        e.preLiquidity = after_.liquidity + t.removed;
        require(e.preLiquidity == before_.liquidity + t.maintenanceAdded, "exit pre-liquidity");
        require(t.removed == FullMath.mulDiv(e.preLiquidity, burned, before_.supply), "exact liquidity floor");
        require(e.idle.a0 == FullMath.mulDiv(e.preBook.a0, burned, before_.supply), "exact idle0 floor");
        require(e.idle.a1 == FullMath.mulDiv(e.preBook.a1, burned, before_.supply), "exact idle1 floor");
        require(_equal(e.preBook, _apply(before_.book, t.maintenanceNet)), "exit incumbent book");
        require(_equal(_positive(_subSigned(t.callerNet, t.callerSwap)), e.principal), "no duplicate removal fees");
        require(t.checkpointCount == 1 && t.added == 0 && t.removals <= 1, "exit phases");
        require(before_.shares - after_.shares == burned && before_.supply - after_.supply == burned, "actual burn");
        require(t.shareEvents == 1 && t.shareAmount == burned && e.payout.a0 + e.payout.a1 != 0, "positive payout burn");
        _exitEvent(t, e, burned, request.single, request.is0, returned);
        _managerNet(before_, after_, t);
        ghostHolderShares[holder] -= burned;
        ghostSupply -= burned;
        if (after_.supply == 0) {
            _terminal();
            ++terminalResets;
        }
        ++successes[uint256(request.single ? Action.SingleExit : Action.PairExit)];
    }

    function _exitEvent(
        Trace memory t, ExitControl memory e, uint256 burned, bool single, bool is0, bytes memory returned
    ) private pure {
        if (!single) {
            require(t.callerSwaps == 0, "paired exit sale");
            require(keccak256(t.exitEvent) == keccak256(abi.encode(
                burned, t.removed, e.idle.a0, e.idle.a1, e.payout.a0, e.payout.a1
            )), "PairRedeemed decomposition");
            require(keccak256(returned) == keccak256(abi.encode(e.payout.a0, e.payout.a1)), "pair payout return");
        } else {
            uint256 sold = is0 ? e.allocation.a1 : e.allocation.a0;
            uint256 proceeds = uint256(is0 ? t.callerSwap.a0 : t.callerSwap.a1);
            uint256 payout = is0 ? e.payout.a0 : e.payout.a1;
            require((is0 ? e.payout.a1 : e.payout.a0) == 0, "single payout opposing token");
            require((is0 ? t.callerSwap.a1 : t.callerSwap.a0) == -int256(sold), "complete allocation sale");
            require(payout == (is0 ? e.allocation.a0 : e.allocation.a1) + proceeds, "allocated sale payout");
            require(keccak256(t.saleEvent) == keccak256(abi.encode(
                burned, e.allocation.a0, e.allocation.a1, sold, proceeds, payout
            )), "WithdrawalSale decomposition");
            require(abi.decode(returned, (uint256)) == payout, "single payout return");
        }
    }

    function _donate(address holder, bool is0, uint256 amount) private {
        _fund(holder, is0 ? amount : 0, is0 ? 0 : amount);
        Snapshot memory before_ = _snapshot(holder);
        vm.recordLogs();
        vm.prank(holder);
        vault.donate(is0 ? address(token0) : address(token1), amount);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Snapshot memory after_ = _snapshot(holder);
        Amounts memory donation = Amounts(is0 ? amount : 0, is0 ? 0 : amount);
        require(_equal(_minus(before_.wallet, after_.wallet), donation), "donor actual delivery");
        require(_equal(after_.book, _plus(before_.book, donation)), "donation book delta");
        require(_equal(before_.manager, after_.manager) && before_.liquidity == after_.liquidity, "donation manager");
        require(before_.supply == after_.supply && before_.shares == after_.shares, "donation no mint");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            require(logs[i].emitter != address(vault) || logs[i].topics[0] != IERC20Events.Transfer.selector,
                "donation emitted share transfer");
            if (logs[i].emitter == address(vault) && logs[i].topics[0] == IVault.Donated.selector) {
                require(logs[i].topics[1] == bytes32(uint256(uint160(holder))), "donor event");
                require(logs[i].topics[2] == bytes32(uint256(uint160(is0 ? address(token0) : address(token1)))), "donation token");
                require(abi.decode(logs[i].data, (uint256)) == amount, "donation amount");
                ++count;
            }
        }
        require(count == 1, "donation event count");
        ++successes[uint256(Action.Donation)];
    }

    function _unsolicited(address holder, uint256 a0, uint256 a1) private {
        _fund(holder, a0, a1);
        Snapshot memory before_ = _snapshot(holder);
        vm.startPrank(holder);
        require(token0.transfer(address(vault), a0), "unsolicited transfer0");
        require(token1.transfer(address(vault), a1), "unsolicited transfer1");
        vm.stopPrank();
        Snapshot memory after_ = _snapshot(holder);
        require(_equal(before_.book, after_.book) && before_.supply == after_.supply, "unsolicited not booked");
        require(before_.liquidity == after_.liquidity && _equal(before_.manager, after_.manager), "unsolicited no manager");
        require(_equal(_minus(before_.wallet, after_.wallet), Amounts(a0, a1)), "unsolicited actual amount");
        unsolicited0 += a0;
        unsolicited1 += a1;
        ++successes[uint256(Action.Unsolicited)];
    }

    function _transfer(address from, uint256 recipientSeed, uint256 amountSeed) private {
        address to = holders[recipientSeed % holders.length];
        if (to == from) to = holders[(recipientSeed % holders.length + 1) % holders.length];
        uint256 amount = 1 + amountSeed % ghostHolderShares[from];
        Snapshot memory before_ = _snapshot(from);
        uint256 recipientBefore = shares.balanceOf(to);
        vm.recordLogs();
        vm.prank(from);
        require(shares.transfer(to, amount), "ordinary share transfer");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(vault)
            && logs[0].topics[0] == IERC20Events.Transfer.selector, "ordinary transfer event count");
        require(logs[0].topics[1] == bytes32(uint256(uint160(from)))
            && logs[0].topics[2] == bytes32(uint256(uint160(to)))
            && abi.decode(logs[0].data, (uint256)) == amount, "ordinary transfer event data");
        Snapshot memory after_ = _snapshot(from);
        require(before_.shares - after_.shares == amount && shares.balanceOf(to) - recipientBefore == amount, "share transfer deltas");
        require(before_.supply == after_.supply && _equal(before_.book, after_.book), "transfer no issuance/book");
        require(before_.liquidity == after_.liquidity && _equal(before_.manager, after_.manager), "transfer no manager");
        ghostHolderShares[from] -= amount;
        ghostHolderShares[to] += amount;
        ++successes[uint256(Action.Transfer)];
    }

    function _trade(bool zeroForOne, uint256 amount) private {
        _fund(address(poolActor), amount, amount);
        Snapshot memory before_ = _snapshot(address(poolActor));
        vm.recordLogs();
        BalanceDelta delta = poolActor.swap(key, SwapParams(
            zeroForOne, -int256(amount),
            zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        ));
        _tradeEvent(vm.getRecordedLogs(), delta);
        Snapshot memory after_ = _snapshot(address(poolActor));
        SignedAmounts memory actual = SignedAmounts(int256(delta.amount0()), int256(delta.amount1()));
        require(_equal(after_.wallet, _apply(before_.wallet, actual)), "external trade actual wallet");
        require(_equal(after_.manager, _apply(before_.manager, SignedAmounts(-actual.a0, -actual.a1))), "external trade manager");
        require(before_.supply == after_.supply && before_.liquidity == after_.liquidity, "market cannot issue shares");
        require(_equal(before_.book, after_.book), "external fees not double booked");
        marketDelta0 += actual.a0;
        marketDelta1 += actual.a1;
        ++successes[uint256(Action.Trade)];
    }

    function _compound() private {
        Snapshot memory before_ = _snapshot(holders[0]);
        vm.recordLogs();
        (uint256 f0, uint256 f1) = vault.compound();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Trace memory t = _trace(logs, before_, holders[0], false);
        Snapshot memory after_ = _snapshot(holders[0]);
        Amounts memory fees = _maintenanceFees(t);
        require(f0 == fees.a0 && f1 == fees.a1, "compound fee return");
        require(before_.supply == after_.supply && t.shareEvents == 0, "compound no shares");
        require(after_.liquidity == before_.liquidity + t.maintenanceAdded, "compound owned liquidity");
        require(_equal(after_.book, _apply(before_.book, t.maintenanceNet)), "compound actual booked receipts");
        require(t.added == 0 && t.removed == 0 && t.callerSwaps == 0, "compound phases");
        _managerNet(before_, after_, t);
        ++successes[uint256(Action.Compound)];
    }

    function _restart(uint256 who) private {
        address last = holders[who % holders.length];
        for (uint256 i; i < holders.length; ++i) {
            address from = holders[i];
            if (from != last && ghostHolderShares[from] != 0) {
                _transfer(from, who, ghostHolderShares[from] - 1);
            }
        }
        _exit(last, false, false, 0, true);
        // Clean empty maintenance must preserve unsolicited assets and make no pool call.
        _compound();
        _terminal();
        _pair(last, 1e18, 1e18);
        require(ghostSupply == 1e18 && ghostHolderShares[last] == 1e18, "restart genesis excludes old excess");
        ++successes[uint256(Action.Restart)];
    }

    function _terminal() private view {
        (uint256 b0, uint256 b1) = vault.localReserves();
        require(shares.totalSupply() == 0 && vault.positionLiquidity() == 0 && b0 == 0 && b1 == 0, "terminal reset");
        require(token0.balanceOf(address(vault)) == unsolicited0, "terminal unsolicited0");
        require(token1.balanceOf(address(vault)) == unsolicited1, "terminal unsolicited1");
    }

    function _tradeEvent(Vm.Log[] memory logs, BalanceDelta delta) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(manager)) continue;
            require(logs[i].topics[0] == IPoolManager.Swap.selector, "external swap event");
            require(logs[i].topics[1] == PoolId.unwrap(key.toId())
                && logs[i].topics[2] == bytes32(uint256(uint160(address(poolActor)))), "external swap identity");
            SwapEvent memory observed = abi.decode(logs[i].data, (SwapEvent));
            (uint160 actualP, int24 actualTick,, uint24 actualFee) = manager.getSlot0(key.toId());
            require(observed.delta0 == delta.amount0() && observed.delta1 == delta.amount1(), "external swap deltas");
            require(observed.price == actualP && observed.tick == actualTick && observed.fee == actualFee, "external swap slot0");
            require(observed.liquidity == manager.getLiquidity(key.toId()), "external swap active liquidity");
            ++count;
        }
        require(count == 1, "one external swap");
    }

    /// @notice Stable-boundary S1-A41/A65: ghost ownership, canonical position, custody and reservations.
    function assertStable() public view {
        require(!handlerFailed, "latched operation failure");
        uint256 sum;
        for (uint256 i; i < holders.length; ++i) {
            uint256 balance = shares.balanceOf(holders[i]);
            require(balance == ghostHolderShares[holders[i]], "holder ghost mismatch");
            sum += balance;
        }
        require(sum == ghostSupply && sum == shares.totalSupply(), "sum == supply == ghost");
        require(shares.balanceOf(address(0)) == 0 && shares.balanceOf(address(0xdead)) == 0, "no dead supply");
        require(shares.balanceOf(address(vault)) == 0 && shares.balanceOf(address(this)) == 0, "no hidden share holder");
        require(vault.tickLower() == lower && vault.tickUpper() == upper, "canonical full range");
        bytes32 positionId = Position.calculatePositionKey(address(vault), lower, upper, bytes32(0));
        uint128 owned = manager.getPositionLiquidity(key.toId(), positionId);
        require(owned == vault.positionLiquidity(), "canonical owned position");
        (uint256 b0, uint256 b1) = vault.localReserves();
        require(token0.balanceOf(address(vault)) == b0 + unsolicited0, "raw0 == book0 + unsolicited0");
        require(token1.balanceOf(address(vault)) == b1 + unsolicited1, "raw1 == book1 + unsolicited1");
        require(IBasicVault(address(vault)).reserveOfToken(address(token0)) == b0, "published book0");
        require(IBasicVault(address(vault)).reserveOfToken(address(token1)) == b1, "published book1");
        (uint160 price,,,) = manager.getSlot0(key.toId());
        Amounts memory principal = _principal(price, owned, false);
        (uint256 r0, uint256 r1) = vault.basket();
        require(r0 == principal.a0 + b0 && r1 == principal.a1 + b1, "actual removable basket");
        require(!TransientStateLibrary.isUnlocked(manager), "stable manager locked");
        _zeroDeltas(address(vault));
        _zeroDeltas(address(poolActor));
        _assertReservations();
    }

    function _assertReservations() private view {
        // Obtain field slots from Solidity's actual Repo layout, not copied offsets.
        // This binds only a read-only pointer in the non-SUT handler. vm.load reads
        // the real proxy; it never writes its storage or invokes a privileged route.
        Repo.Storage storage layout = Repo._layoutStruct();
        Types.Inventory storage inventory = layout.inventory;
        uint256 slot;
        assembly ("memory-safe") { slot := inventory.slot }
        // Inventory = two booked words, three Amounts reservations, three wrapped words.
        for (uint256 i = 2; i < 11; ++i) {
            require(vm.load(address(vault), bytes32(slot + i)) == bytes32(0), "nonzero stable reservation");
        }
        require(vm.load(address(vault), bytes32(slot + 11)) == bytes32(uint256(1)), "initialized idle guard");
        require(vm.load(address(vault), bytes32(slot + 12)) == bytes32(0), "pending callback");
    }

    function _zeroDeltas(address account) private view {
        require(TransientStateLibrary.currencyDelta(manager, account, key.currency0) == 0, "manager delta0");
        require(TransientStateLibrary.currencyDelta(manager, account, key.currency1) == 0, "manager delta1");
    }

    function _trace(Vm.Log[] memory logs, Snapshot memory before_, address holder, bool minting)
        private view returns (Trace memory t)
    {
        t.price = before_.price;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory item = logs[i];
            if (item.emitter == address(manager)) _poolLog(t, item);
            else if (item.emitter == address(token0) || item.emitter == address(token1)) _receipt(t, item);
            else if (item.emitter == address(vault)) _familyLog(t, item, holder, minting);
        }
        require(t.checkpointCount == 1, "one Compounded checkpoint");
    }

    function _poolLog(Trace memory t, Vm.Log memory item) private view {
        require(item.topics[1] == PoolId.unwrap(key.toId()), "manager pool id");
        require(item.topics[2] == bytes32(uint256(uint160(address(vault)))), "manager position owner");
        if (item.topics[0] == IPoolManager.Swap.selector) {
            (int128 d0, int128 d1, uint160 price,,,) =
                abi.decode(item.data, (int128, int128, uint160, uint128, int24, uint24));
            t.price = price;
            if (t.checkpointCount == 0) t.maintenanceSwap = _addSigned(t.maintenanceSwap, SignedAmounts(d0, d1));
            else {
                require(t.callerAdds == 0, "swap after caller addition");
                t.callerSwap = _addSigned(t.callerSwap, SignedAmounts(d0, d1));
                ++t.callerSwaps;
            }
        } else if (item.topics[0] == IPoolManager.ModifyLiquidity.selector) {
            (int24 lo, int24 hi, int256 delta, bytes32 salt) = abi.decode(item.data, (int24, int24, int256, bytes32));
            require(lo == lower && hi == upper && salt == bytes32(0), "canonical modified position");
            if (delta > 0) {
                require(uint256(delta) <= type(uint128).max, "positive delta range");
                uint128 addition = uint128(uint256(delta));
                Amounts memory cost = _principal(t.price, addition, true);
                if (t.checkpointCount == 0) {
                    t.maintenanceAdded += addition;
                    t.maintenanceCosts = _plus(t.maintenanceCosts, cost);
                } else {
                    require(t.removals == 0, "re-add after withdrawal");
                    t.added += addition;
                    t.costs = _plus(t.costs, cost);
                    ++t.callerAdds;
                }
            } else if (delta < 0) {
                require(t.checkpointCount == 1 && uint256(-delta) <= type(uint128).max, "negative modify phase");
                t.removed += uint128(uint256(-delta));
                t.removalPrice = t.price;
                ++t.removals;
            }
        } else revert("unexpected manager action");
    }

    function _receipt(Trace memory t, Vm.Log memory item) private view {
        if (item.topics[0] != IERC20Events.Transfer.selector) return;
        address from = address(uint160(uint256(item.topics[1])));
        address to = address(uint160(uint256(item.topics[2])));
        int256 amount = int256(abi.decode(item.data, (uint256)));
        int256 net;
        if (from == address(manager) && to == address(vault)) net = amount;
        if (from == address(vault) && to == address(manager)) net = -amount;
        if (item.emitter == address(token0)) {
            if (t.checkpointCount == 0) t.maintenanceNet.a0 += net;
            else t.callerNet.a0 += net;
        } else {
            if (t.checkpointCount == 0) t.maintenanceNet.a1 += net;
            else t.callerNet.a1 += net;
        }
    }

    function _familyLog(Trace memory t, Vm.Log memory item, address holder, bool minting) private pure {
        bytes32 topic = item.topics[0];
        if (topic == IVault.Compounded.selector) {
            require(t.checkpointCount == 0, "duplicate maintenance checkpoint");
            Amounts memory fees = _maintenanceFees(t);
            require(keccak256(item.data) == keccak256(abi.encode(
                fees.a0, fees.a1, t.maintenanceCosts.a0, t.maintenanceCosts.a1, t.maintenanceAdded
            )), "Compounded actual receipt decomposition");
            ++t.checkpointCount;
        } else if (topic == IERC20Events.Transfer.selector) {
            require(item.topics[1] == bytes32(uint256(uint160(minting ? address(0) : holder))), "mint/burn sender");
            require(item.topics[2] == bytes32(uint256(uint160(minting ? holder : address(0)))), "mint/burn receiver");
            require(abi.decode(item.data, (uint256)) != 0, "positive share transfer event");
            t.shareAmount += abi.decode(item.data, (uint256));
            ++t.shareEvents;
        } else if (topic == IVault.WithdrawalMaintenanceSelected.selector) {
            t.modeEvent = item.data;
            ++t.modes;
        } else if (
            topic == IVault.PairDeposited.selector || topic == IVault.PairRedeemed.selector
                || topic == IVault.ZapCredit.selector || topic == IVault.WithdrawalSale.selector
        ) {
            require(item.topics[1] == bytes32(uint256(uint160(holder))), "family caller");
            require(item.topics[2] == bytes32(uint256(uint160(holder))), "family recipient");
            if (topic == IVault.PairDeposited.selector) { require(t.pairEvent.length == 0, "duplicate pair"); t.pairEvent = item.data; }
            else if (topic == IVault.PairRedeemed.selector) { require(t.exitEvent.length == 0, "duplicate exit"); t.exitEvent = item.data; }
            else if (topic == IVault.ZapCredit.selector) {
                require(t.zapEvent.length == 0, "duplicate zap");
                t.zapEvent = item.data;
                t.token = address(uint160(uint256(item.topics[3])));
            } else {
                require(t.saleEvent.length == 0, "duplicate sale");
                t.saleEvent = item.data;
                t.token = address(uint160(uint256(item.topics[3])));
            }
        }
    }

    function _maintenanceFees(Trace memory t) private pure returns (Amounts memory) {
        return _positive(_addSigned(_subSigned(t.maintenanceNet, t.maintenanceSwap), _signed(t.maintenanceCosts)));
    }

    function _managerNet(Snapshot memory before_, Snapshot memory after_, Trace memory t) private pure {
        SignedAmounts memory net = _addSigned(t.maintenanceNet, t.callerNet);
        require(_equal(after_.manager, _apply(before_.manager, SignedAmounts(-net.a0, -net.a1))), "manager logs vs actual custody");
    }

    function _snapshot(address holder) private view returns (Snapshot memory s) {
        s.supply = shares.totalSupply();
        (s.liquidity,,) = manager.getPositionInfo(key.toId(), address(vault), lower, upper, bytes32(0));
        (s.price,,,) = manager.getSlot0(key.toId());
        (s.book.a0, s.book.a1) = vault.localReserves();
        s.wallet = Amounts(token0.balanceOf(holder), token1.balanceOf(holder));
        s.manager = Amounts(token0.balanceOf(address(manager)), token1.balanceOf(address(manager)));
        s.shares = shares.balanceOf(holder);
    }

    function _stateHash() private view returns (bytes32 digest) {
        digest = keccak256(abi.encode(_snapshot(address(vault)), _snapshot(address(poolActor)),
            unsolicited0, unsolicited1, ghostSupply, token0.totalSupply(), token1.totalSupply()));
        for (uint256 i; i < holders.length; ++i) {
            digest = keccak256(abi.encode(digest, _snapshot(holders[i]),
                token0.allowance(holders[i], address(vault)), token1.allowance(holders[i], address(vault))));
        }
        digest = keccak256(abi.encode(digest, _poolStateHash()));
        digest = _tickHash(digest, lower);
        digest = _tickHash(digest, upper);
        // No test action creates any other initialized ticks.
        Repo.Storage storage layout = Repo._layoutStruct();
        Types.Inventory storage inventory = layout.inventory;
        uint256 slot;
        assembly ("memory-safe") { slot := inventory.slot }
        for (uint256 i; i < 13; ++i) digest = keccak256(abi.encode(digest, vm.load(address(vault), bytes32(slot + i))));
    }

    function _poolStateHash() private view returns (bytes32 digest) {
        (uint160 p, int24 tick, uint24 protocol, uint24 fee) = manager.getSlot0(key.toId());
        (uint256 f0, uint256 f1) = manager.getFeeGrowthGlobals(key.toId());
        digest = keccak256(abi.encode(p, tick, protocol, fee, f0, f1, manager.getLiquidity(key.toId())));
        (uint128 liquidity, uint256 last0, uint256 last1) =
            manager.getPositionInfo(key.toId(), address(vault), lower, upper, bytes32(0));
        return keccak256(abi.encode(digest, liquidity, last0, last1));
    }

    function _tickHash(bytes32 digest, int24 tick) private view returns (bytes32) {
        (uint128 gross, int128 net, uint256 f0, uint256 f1) = manager.getTickInfo(key.toId(), tick);
        int16 word = int16((tick / key.tickSpacing) >> 8);
        return keccak256(abi.encode(digest, gross, net, f0, f1, manager.getTickBitmap(key.toId(), word)));
    }

    function _principal(uint160 price, uint128 liquidity, bool up) private view returns (Amounts memory a) {
        uint160 p = price < sqrtLower ? sqrtLower : (price > sqrtUpper ? sqrtUpper : price);
        if (p < sqrtUpper) {
            uint256 first = up
                ? FullMath.mulDivRoundingUp(uint256(liquidity) << 96, sqrtUpper - p, sqrtUpper)
                : FullMath.mulDiv(uint256(liquidity) << 96, sqrtUpper - p, sqrtUpper);
            a.a0 = first / p;
            if (up && first % p != 0) ++a.a0;
        }
        if (p > sqrtLower) a.a1 = up
            ? FullMath.mulDivRoundingUp(liquidity, p - sqrtLower, uint256(1) << 96)
            : FullMath.mulDiv(liquidity, p - sqrtLower, uint256(1) << 96);
    }

    function _pairQuote(uint256 supply, Amounts memory r, uint256 a0, uint256 a1) private pure returns (uint256) {
        require(r.a0 != 0 || r.a1 != 0, "positive incumbent reserves");
        if (r.a0 == 0) return FullMath.mulDiv(a1, supply, r.a1);
        if (r.a1 == 0) return FullMath.mulDiv(a0, supply, r.a0);
        return _productLE(a0, r.a1, a1, r.a0)
            ? FullMath.mulDiv(a0, supply, r.a0) : FullMath.mulDiv(a1, supply, r.a1);
    }

    function _accepted(uint256 supply, EntryControl memory e, uint256 a0, uint256 a1) private pure {
        if (e.reserve.a0 == 0) require(e.used.a0 == 0 && e.used.a1 == a1, "one-sided accepted1");
        else if (e.reserve.a1 == 0) require(e.used.a1 == 0 && e.used.a0 == a0, "one-sided accepted0");
        else {
            require(e.used.a0 == FullMath.mulDivRoundingUp(e.quote, e.reserve.a0, supply), "accepted0 ceiling");
            require(e.used.a1 == FullMath.mulDivRoundingUp(e.quote, e.reserve.a1, supply), "accepted1 ceiling");
        }
        require(e.used.a0 <= a0 && e.used.a1 <= a1, "unused maxima stay caller-owned");
    }

    function _credit(uint256 supply, Amounts memory r, Amounts memory c, uint256 cap) private pure returns (uint256 q) {
        require(supply != 0 && (r.a0 != 0 || r.a1 != 0), "credit domain");
        q = cap;
        // First compare wide products; divide only if a representable quotient is
        // below the current cap. An irrelevant overflowing quotient cannot reject.
        if (r.a0 != 0 && !_productLE(q, r.a0, supply, c.a0)) q = FullMath.mulDiv(supply, c.a0, r.a0);
        if (r.a1 != 0 && !_productLE(q, r.a1, supply, c.a1)) q = FullMath.mulDiv(supply, c.a1, r.a1);
    }

    function _nonDilution(uint256 supply, EntryControl memory e, bool paired) private pure {
        Amounts memory c = paired ? _plus(e.growth, e.residual) : e.growth;
        require(e.reserve.a0 == 0 || _productLE(e.minted, e.reserve.a0, supply, c.a0), "q*R0 <= S*C0");
        require(e.reserve.a1 == 0 || _productLE(e.minted, e.reserve.a1, supply, c.a1), "q*R1 <= S*C1");
    }

    function _productLE(uint256 a, uint256 b, uint256 c, uint256 d) private pure returns (bool) {
        (uint256 hi0, uint256 lo0) = _wide(a, b);
        (uint256 hi1, uint256 lo1) = _wide(c, d);
        return hi0 < hi1 || (hi0 == hi1 && lo0 <= lo1);
    }

    function _wide(uint256 a, uint256 b) private pure returns (uint256 hi, uint256 lo) {
        assembly ("memory-safe") {
            let mm := mulmod(a, b, not(0))
            lo := mul(a, b)
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    function _sqrt(uint256 n) private pure returns (uint256 result) {
        if (n == 0) return 0;
        result = n;
        uint256 candidate = n / 2 + 1;
        while (candidate < result) {
            result = candidate;
            candidate = (n / candidate + candidate) / 2;
        }
    }

    function _fund(address holder, uint256 a0, uint256 a1) private {
        if (a0 != 0) require(token0.mint(holder, a0), "underlying capital0");
        if (a1 != 0) require(token1.mint(holder, a1), "underlying capital1");
        vm.startPrank(holder);
        require(token0.approve(address(vault), type(uint256).max), "underlying approval0");
        require(token1.approve(address(vault), type(uint256).max), "underlying approval1");
        vm.stopPrank();
    }

    function _active(uint256 seed) private view returns (address) {
        for (uint256 i; i < holders.length; ++i) {
            address holder = holders[(seed % holders.length + i) % holders.length];
            if (ghostHolderShares[holder] != 0) return holder;
        }
        revert("no live holder");
    }

    function _mintGhost(address holder, uint256 amount) private {
        ghostHolderShares[holder] += amount;
        ghostSupply += amount;
    }

    function _capital(uint256 seed) private pure returns (uint256) { return 1e6 + seed % (1e16 - 1e6 + 1); }
    function _plus(Amounts memory a, Amounts memory b) private pure returns (Amounts memory) { return Amounts(a.a0 + b.a0, a.a1 + b.a1); }
    function _minus(Amounts memory a, Amounts memory b) private pure returns (Amounts memory) { return Amounts(a.a0 - b.a0, a.a1 - b.a1); }
    function _equal(Amounts memory a, Amounts memory b) private pure returns (bool) { return a.a0 == b.a0 && a.a1 == b.a1; }
    function _signed(Amounts memory a) private pure returns (SignedAmounts memory) {
        require(a.a0 <= uint256(type(int256).max) && a.a1 <= uint256(type(int256).max), "signed observation range");
        return SignedAmounts(int256(a.a0), int256(a.a1));
    }
    function _positive(SignedAmounts memory a) private pure returns (Amounts memory) {
        require(a.a0 >= 0 && a.a1 >= 0, "negative ownership category");
        return Amounts(uint256(a.a0), uint256(a.a1));
    }
    function _apply(Amounts memory a, SignedAmounts memory b) private pure returns (Amounts memory) { return _positive(_addSigned(_signed(a), b)); }
    function _addSigned(SignedAmounts memory a, SignedAmounts memory b) private pure returns (SignedAmounts memory) { return SignedAmounts(a.a0 + b.a0, a.a1 + b.a1); }
    function _subSigned(SignedAmounts memory a, SignedAmounts memory b) private pure returns (SignedAmounts memory) { return SignedAmounts(a.a0 - b.a0, a.a1 - b.a1); }
}
// end::Handler_UniswapV4PairTokenStandardExchangeVault[]

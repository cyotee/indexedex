// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {
    PoolKey, ModifyLiquidityParams, SwapParams, IPoolManager
} from "../../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";

interface ICallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

interface ITokenCalls {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @dev Mutating calls only. STATICCALL observations belong in Foundry's access/debug trace.
contract TraceRecorder {
    struct Entry {
        bytes32 kind;
        address target;
        address caller;
        uint256 value;
        bytes data;
        uint256 depth;
    }

    Entry[] internal entries;
    uint256 public depth;

    function record(bytes32 kind, address caller, uint256 value, bytes calldata data) external {
        entries.push(Entry(kind, msg.sender, caller, value, data, depth));
    }

    function enter() external { ++depth; }
    function exitDepth() external { --depth; }
    function clear() external { delete entries; }
    function length() external view returns (uint256) { return entries.length; }
    function entryAt(uint256 index) external view returns (Entry memory) { return entries[index]; }
    function count(bytes32 kind) external view returns (uint256 result) {
        for (uint256 i; i < entries.length; ++i) if (entries[i].kind == kind) ++result;
    }
}

contract ScriptedERC20 {
    enum ReturnMode {
        True, Empty, False, Malformed, OneByte, TrueExtra,
        FeeOnTransfer, NoMovement, BalanceDecrease, RevertCall, Callback
    }

    error TokenFailure();
    TraceRecorder public immutable trace;
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) public allowance;
    ReturnMode public transferMode;
    ReturnMode public transferFromMode;
    ReturnMode public approveMode;
    ReturnMode public cleanupApproveMode;
    bool public separateCleanup;
    uint256 public feeBps = 1000;
    address public callbackTarget;
    bytes public callbackData;
    bool public callbackMustSucceed = true;
    bytes public callbackResult;

    constructor(TraceRecorder recorder) { trace = recorder; }
    function balanceOf(address who) external view returns (uint256) { return balances[who]; }
    function mint(address who, uint256 amount) external { balances[who] += amount; }
    function setBalance(address who, uint256 amount) external { balances[who] = amount; }
    function setFeeBps(uint256 bps) external { feeBps = bps; }
    function setTransferMode(ReturnMode mode) external { transferMode = mode; }
    function setTransferFromMode(ReturnMode mode) external { transferFromMode = mode; }
    function setApproveMode(ReturnMode mode) external { approveMode = mode; }
    function setCleanupApproveMode(ReturnMode mode) external {
        separateCleanup = true;
        cleanupApproveMode = mode;
    }
    function setCallback(address target, bytes calldata data, bool mustSucceed) external {
        callbackTarget = target;
        callbackData = data;
        callbackMustSucceed = mustSucceed;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        trace.record("approve", msg.sender, 0, msg.data);
        ReturnMode mode = amount == 0 && separateCleanup ? cleanupApproveMode : approveMode;
        allowance[msg.sender][spender] = amount;
        return _respond(mode);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        trace.record("transfer", msg.sender, 0, msg.data);
        _move(msg.sender, to, amount, transferMode);
        return _respond(transferMode);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        trace.record("transferFrom", msg.sender, 0, msg.data);
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _move(from, to, amount, transferFromMode);
        return _respond(transferFromMode);
    }

    function _move(address from, address to, uint256 amount, ReturnMode mode) internal {
        if (mode == ReturnMode.NoMovement) return;
        if (mode == ReturnMode.BalanceDecrease) {
            balances[to] -= amount;
            return;
        }
        balances[from] -= amount;
        balances[to] += mode == ReturnMode.FeeOnTransfer ? amount - amount * feeBps / 10000 : amount;
    }

    function _respond(ReturnMode mode) internal returns (bool) {
        if (mode == ReturnMode.RevertCall) revert TokenFailure();
        if (mode == ReturnMode.Callback) {
            (bool ok, bytes memory result) = callbackTarget.call(callbackData);
            callbackResult = result;
            if (callbackMustSucceed && !ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        }
        if (mode == ReturnMode.Empty) assembly ("memory-safe") { return(0, 0) }
        if (mode == ReturnMode.Malformed) assembly ("memory-safe") { mstore(0, 2) return(0, 32) }
        if (mode == ReturnMode.OneByte) assembly ("memory-safe") { mstore(0, 1) return(31, 1) }
        if (mode == ReturnMode.TrueExtra) assembly ("memory-safe") {
            mstore(0, 1) mstore(32, 0x1234) return(0, 64)
        }
        return mode != ReturnMode.False;
    }
}

contract ScriptedFactory {
    error FactoryFailure(bytes4 getter);
    address internal feeManagerValue;
    uint16 internal protocolFeeValue;
    uint16 internal zapBpsValue;
    int24 internal tickMoveValue;
    mapping(bytes4 => bool) public failures;

    function configure(address recipient, uint16 rate, uint16 cap, int24 movement) external {
        feeManagerValue = recipient;
        protocolFeeValue = rate;
        zapBpsValue = cap;
        tickMoveValue = movement;
    }
    function setFailure(bytes4 getter, bool fail) external { failures[getter] = fail; }
    function _check() internal view { if (failures[msg.sig]) revert FactoryFailure(msg.sig); }
    function feeManager() external view returns (address) { _check(); return feeManagerValue; }
    function protocolFeeBps() external view returns (uint16) { _check(); return protocolFeeValue; }
    function maxZapBps() external view returns (uint16) { _check(); return zapBpsValue; }
    function maxZapTickMove() external view returns (int24) { _check(); return tickMoveValue; }
    function initialize(address instance, address manager, PoolKey calldata key) external {
        (bool ok, bytes memory reason) = instance.call(
            abi.encodeWithSignature(
                "initialize(address,(address,address,uint24,int24,address),string,string)",
                manager, key, "Pair baseline", "PAIR"
            )
        );
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
    }
}

contract ScriptedFeeManager {
    enum Mode { Pull, NoPull, RevertCustom, RevertEmpty, RevertPanic }
    error NotifyFailure();
    TraceRecorder public immutable trace;
    Mode public mode;
    uint256 public notifications;
    constructor(TraceRecorder recorder) { trace = recorder; }
    function setMode(Mode value) external { mode = value; }
    function notify(address token, uint256 amount, bytes32) external payable {
        trace.record("notify", msg.sender, msg.value, msg.data);
        ++notifications;
        if (mode == Mode.RevertCustom) revert NotifyFailure();
        if (mode == Mode.RevertEmpty) assembly ("memory-safe") { revert(0, 0) }
        if (mode == Mode.RevertPanic) assert(false);
        if (token != address(0) && mode == Mode.Pull) {
            require(ITokenCalls(token).transferFrom(msg.sender, address(this), amount));
        }
    }
}

contract ScriptedPoolManager is IPoolManager {
    error ManagerFailure(bytes4 method);
    struct ModifyResult { int256 callerDelta; int256 feesAccrued; }
    struct SwapResult { int256 delta; uint160 price; int24 tick; }
    TraceRecorder public immutable trace;
    mapping(bytes32 => bytes32) public words;
    mapping(bytes4 => bool) public failures;
    ModifyResult[] internal modifications;
    SwapResult[] internal swaps;
    uint256 public modifyCursor;
    uint256 public swapCursor;
    uint256 public paidAmount;
    uint256[] public unlockSupply;
    bool public updatePosition = true;
    address public duringUnlockTarget;
    bytes public duringUnlockData;
    bytes public duringUnlockResult;
    bool public duringUnlockSuccess;

    constructor(TraceRecorder recorder) { trace = recorder; }
    receive() external payable { }
    function pack(int128 delta0, int128 delta1) public pure returns (int256) {
        return int256((uint256(uint128(delta0)) << 128) | uint256(uint128(delta1)));
    }
    function base(bytes32 id) public pure returns (bytes32) { return keccak256(abi.encode(id, bytes32(uint256(6)))); }
    function positionSlot(bytes32 id, address owner, int24 lower, int24 upper) public pure returns (bytes32) {
        bytes32 positionKey = keccak256(abi.encodePacked(owner, lower, upper, bytes32(0)));
        return keccak256(abi.encode(positionKey, bytes32(uint256(base(id)) + 6)));
    }
    function setWord(bytes32 slot, bytes32 value) external { words[slot] = value; }
    function setSlot0(bytes32 id, uint160 price, int24 tick) public {
        words[base(id)] = bytes32(uint256(price) | (uint256(uint24(tick)) << 160));
    }
    function setActiveLiquidity(bytes32 id, uint128 value) external {
        words[bytes32(uint256(base(id)) + 3)] = bytes32(uint256(value));
    }
    function setPositionForPool(bytes32 id, address owner, int24 lower, int24 upper, uint128 value) public {
        words[positionSlot(id, owner, lower, upper)] = bytes32(uint256(value));
    }
    function setPosition(address owner, int24 lower, int24 upper, uint128 value) external {
        // Single-pool convenience uses the most recently configured pool.
        setPositionForPool(configuredPool, owner, lower, upper, value);
    }
    bytes32 public configuredPool;
    function configurePool(bytes32 id, uint160 price, int24 tick) external {
        configuredPool = id;
        setSlot0(id, price, tick);
    }
    function setUpdatePosition(bool enabled) external { updatePosition = enabled; }
    function setPaidAmount(uint256 amount) external { paidAmount = amount; }
    function setFailure(bytes4 method, bool fail) external { failures[method] = fail; }
    function queueModify(int256 callerDelta, int256 feesAccrued) external {
        modifications.push(ModifyResult(callerDelta, feesAccrued));
    }
    function queueSwap(int256 delta, uint160 afterPrice, int24 afterTick) external {
        swaps.push(SwapResult(delta, afterPrice, afterTick));
    }
    function setDuringUnlock(address target, bytes calldata data) external {
        duringUnlockTarget = target;
        duringUnlockData = data;
    }
    function _check() internal view { if (failures[msg.sig]) revert ManagerFailure(msg.sig); }
    function extsload(bytes32 slot) external view returns (bytes32) { _check(); return words[slot]; }
    function callback(address instance, bytes calldata data) external returns (bytes memory) {
        return ICallback(instance).unlockCallback(data);
    }
    function unlock(bytes calldata data) external returns (bytes memory result) {
        _check();
        trace.record("unlock", msg.sender, 0, msg.data);
        (bool readSupply, bytes memory supplyData) = msg.sender.staticcall(abi.encodeWithSignature("totalSupply()"));
        if (readSupply && supplyData.length == 32) unlockSupply.push(abi.decode(supplyData, (uint256)));
        trace.enter();
        if (duringUnlockTarget != address(0)) {
            (duringUnlockSuccess, duringUnlockResult) = duringUnlockTarget.call(duringUnlockData);
        }
        result = ICallback(msg.sender).unlockCallback(data);
        trace.exitDepth();
    }
    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata)
        external returns (int256 callerDelta, int256 feesAccrued)
    {
        _check();
        trace.record("modify", msg.sender, 0, msg.data);
        if (updatePosition) {
            bytes32 slot = positionSlot(
                keccak256(abi.encode(key)), msg.sender, params.tickLower, params.tickUpper
            );
            uint128 old = uint128(uint256(words[slot]));
            words[slot] = bytes32(uint256(uint128(uint256(int256(uint256(old)) + params.liquidityDelta))));
        }
        if (modifyCursor < modifications.length) {
            ModifyResult memory result = modifications[modifyCursor++];
            return (result.callerDelta, result.feesAccrued);
        }
    }
    function swap(PoolKey calldata key, SwapParams calldata, bytes calldata) external returns (int256 delta) {
        _check();
        trace.record("swap", msg.sender, 0, msg.data);
        if (swapCursor < swaps.length) {
            SwapResult memory result = swaps[swapCursor++];
            if (result.price != 0) setSlot0(keccak256(abi.encode(key)), result.price, result.tick);
            return result.delta;
        }
    }
    function sync(address) external { _check(); trace.record("sync", msg.sender, 0, msg.data); }
    function settle() external payable returns (uint256) {
        _check(); trace.record("settle", msg.sender, msg.value, msg.data); return paidAmount;
    }
    function take(address currency, address to, uint256 amount) external {
        _check();
        trace.record("take", msg.sender, 0, msg.data);
        if (currency == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            require(ok);
        } else {
            require(ITokenCalls(currency).transfer(to, amount));
        }
    }
}

contract NativeRecipient {
    TraceRecorder public immutable trace;
    bytes32 public receiveKind = "payout";
    uint256 public receivedCalls;
    uint256 public receivedValue;
    bool public reject;
    constructor(TraceRecorder recorder) { trace = recorder; }
    function setReject(bool value) external { reject = value; }
    function setReceiveKind(bytes32 kind) external { receiveKind = kind; }
    receive() external payable {
        require(!reject, "recipient rejected");
        ++receivedCalls;
        receivedValue += msg.value;
        trace.record(receiveKind, msg.sender, msg.value, bytes(""));
    }
    function execute(address target, bytes calldata data) external payable returns (bytes memory result) {
        (bool ok, bytes memory returned) = target.call{value: msg.value}(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        return returned;
    }
}

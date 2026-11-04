// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PairToken} from "../../../../../contracts/pairtoken-baseline/PairToken.sol";
import {PoolKey} from "../../../../../contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol";
import {
    TraceRecorder, ScriptedERC20, ScriptedFactory, ScriptedFeeManager, ScriptedPoolManager, NativeRecipient
} from "./ScriptedDependencies.sol";

abstract contract PairTokenTestBase is Test {
    uint160 internal constant Q96 = 79228162514264337593543950336;
    PairToken internal pair;
    ScriptedPoolManager internal manager;
    ScriptedFactory internal factory;
    ScriptedFeeManager internal feeManager;
    ScriptedERC20 internal currency0;
    ScriptedERC20 internal currency1;
    TraceRecorder internal trace;
    PoolKey internal key;

    receive() external payable { }

    function setUp() public virtual { _deploy(false); }

    function _deploy(bool native0) internal {
        trace = new TraceRecorder();
        manager = new ScriptedPoolManager(trace);
        factory = new ScriptedFactory();
        feeManager = new ScriptedFeeManager(trace);
        currency0 = new ScriptedERC20(trace);
        currency1 = new ScriptedERC20(trace);
        pair = new PairToken();
        key = PoolKey(native0 ? address(0) : address(currency0), address(currency1), 3000, 60, address(0));
        factory.configure(address(feeManager), 0, 10000, 100);
        factory.initialize(address(pair), address(manager), key);
        manager.configurePool(pair.poolId(), Q96, 0);
        manager.setActiveLiquidity(pair.poolId(), 1000000);
        vm.deal(address(manager), 1e30);
        vm.deal(address(this), 1e30);
        currency0.mint(address(manager), 1e30);
        currency1.mint(address(manager), 1e30);
        currency0.mint(address(this), 1e30);
        currency1.mint(address(this), 1e30);
        currency0.approve(address(pair), type(uint256).max);
        currency1.approve(address(pair), type(uint256).max);
        trace.clear();
    }

    /// @dev The instance is always real and shares are obtained through public entry only.
    function _bootstrap(uint256 amount) internal returns (uint256) {
        uint256 result = pair.deposit{value: key.currency0 == address(0) ? amount : 0}(
            amount, amount, 0, address(this)
        );
        trace.clear();
        return result;
    }

    function _position(uint128 value) internal {
        manager.setPosition(address(pair), pair.tickLower(), pair.tickUpper(), value);
    }

    function _idle(uint256 amount0, uint256 amount1) internal {
        if (key.currency0 == address(0)) vm.deal(address(pair), amount0);
        else currency0.setBalance(address(pair), amount0);
        currency1.setBalance(address(pair), amount1);
    }

    function _callback(uint8 operation, bytes memory payload) internal returns (bytes memory) {
        return manager.callback(address(pair), abi.encode(operation, payload));
    }

    function _delta(int128 amount0, int128 amount1) internal pure returns (int256) {
        return int256((uint256(uint128(amount0)) << 128) | uint256(uint128(amount1)));
    }
}

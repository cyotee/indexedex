// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";

library UniswapV4PoolKeyAwareRepo {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant STORAGE_SLOT = keccak256("indexedex.protocols.dexes.uniswap.v4.pool.key.aware");

    struct Storage {
        PoolKey poolKey;
        PoolId poolId;
    }

    function _layout(bytes32 slot_) internal pure returns (Storage storage layout) {
        assembly {
            layout.slot := slot_
        }
    }

    function _layout() internal pure returns (Storage storage layout) {
        return _layout(STORAGE_SLOT);
    }

    function _initialize(Storage storage layout, PoolKey memory poolKey_) internal {
        layout.poolKey = poolKey_;
        layout.poolId = poolKey_.toId();
    }

    function _initialize(PoolKey memory poolKey_) internal {
        _initialize(_layout(), poolKey_);
    }

    function _poolKey(Storage storage layout) internal view returns (PoolKey memory poolKey_) {
        return layout.poolKey;
    }

    function _poolKey() internal view returns (PoolKey memory poolKey_) {
        return _poolKey(_layout());
    }

    function _poolId(Storage storage layout) internal view returns (PoolId poolId_) {
        return layout.poolId;
    }

    function _poolId() internal view returns (PoolId poolId_) {
        return _poolId(_layout());
    }

    function _currency0(Storage storage layout) internal view returns (Currency currency0_) {
        return layout.poolKey.currency0;
    }

    function _currency0() internal view returns (Currency currency0_) {
        return _currency0(_layout());
    }

    function _currency1(Storage storage layout) internal view returns (Currency currency1_) {
        return layout.poolKey.currency1;
    }

    function _currency1() internal view returns (Currency currency1_) {
        return _currency1(_layout());
    }

    function _fee(Storage storage layout) internal view returns (uint24 fee_) {
        return layout.poolKey.fee;
    }

    function _fee() internal view returns (uint24 fee_) {
        return _fee(_layout());
    }

    function _tickSpacing(Storage storage layout) internal view returns (int24 tickSpacing_) {
        return layout.poolKey.tickSpacing;
    }

    function _tickSpacing() internal view returns (int24 tickSpacing_) {
        return _tickSpacing(_layout());
    }

    function _hooks(Storage storage layout) internal view returns (IHooks hooks_) {
        return layout.poolKey.hooks;
    }

    function _hooks() internal view returns (IHooks hooks_) {
        return _hooks(_layout());
    }
}
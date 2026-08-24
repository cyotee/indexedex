// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolId} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

interface IUniswapV4MultiPoolTwapOracle {
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        int24 prevTick;
        bool initialized;
    }

    error ZeroPoolManager();
    error PoolManagerMismatch();
    error InvalidSecondsAgo();
    error CardinalityNextTooLow();
    error PoolKeyMismatch();
    error TargetPredatesOldestObservation(uint32 oldest, uint32 target);

    event ObservationWritten(PoolId id, int24 tick, uint32 timestamp, uint16 index, uint16 cardinality);
    event CardinalityNextIncreased(PoolId id, uint16 oldCardinalityNext, uint16 newCardinalityNext);

    function poolManager() external view returns (address);

    function MAX_ABS_TICK_MOVE() external pure returns (int24);

    function update(PoolKey calldata key) external returns (bool written);

    function update(PoolKey[] calldata keys) external returns (bool[] memory written);

    function increaseCardinalityNext(PoolId id, uint16 next) external;

    function observe(PoolId id, uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives);

    function consult(PoolId id, uint32 secondsAgo) external view returns (int24 arithmeticMeanTick);

    function getPoolKey(PoolId id) external view returns (PoolKey memory);

    function getState(PoolId id)
        external
        view
        returns (uint16 index, uint16 cardinality, uint16 cardinalityNext, int24 prevTick, uint32 lastTimestamp);

    function getObservation(PoolId id, uint16 index) external view returns (Observation memory);

    function writeAge(PoolId id) external view returns (uint256);
}

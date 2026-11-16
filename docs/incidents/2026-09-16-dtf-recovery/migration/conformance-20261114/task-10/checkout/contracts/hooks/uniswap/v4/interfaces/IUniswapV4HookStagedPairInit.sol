// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/**
 * @title IUniswapV4HookStagedPairInit
 * @notice Shared bootstrap door ABI for V4 hook families (S58 / S59).
 * @dev Unmatched on the proxy after finalizeInitialization. Do not add these
 *      views to the family product hook interface.
 */
interface IUniswapV4HookStagedPairInit {
    error InitializationAlreadyFinalized();
    error ProductDoorsNotLive();

    event PairPoolDeployed(
        address indexed hook,
        address indexed currency0,
        address indexed currency1,
        bytes32 poolId
    );
    event InitializationFinalized(address indexed hook);

    function deployPair(address tokenA, address tokenB) external returns (PoolKey memory key);
    function finalizeInitialization() external returns (bool);
    function isPairPoolLive(address tokenA, address tokenB) external view returns (bool);
    function pairPoolKey(address tokenA, address tokenB) external view returns (PoolKey memory);
    function isInitializationFinalized() external view returns (bool);
}

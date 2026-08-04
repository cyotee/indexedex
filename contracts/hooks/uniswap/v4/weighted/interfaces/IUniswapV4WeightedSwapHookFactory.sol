// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/**
 * @title IUniswapV4WeightedSwapHookFactory
 * @notice Permissionless factory: CREATE3 mine/deploy hook + all binom(n,2) pair doors.
 * @dev feeOracle is factory-immutable; all hooks from a factory share it.
 */
interface IUniswapV4WeightedSwapHookFactory {
    event HookDeployed(
        address indexed deployer,
        address indexed hook,
        address poolManager,
        address feeOracle,
        uint8 numTokens
    );

    event PairPoolsEnsured(address indexed hook, uint8 createdCount, uint8 alreadyLiveCount);

    function poolManager() external view returns (IPoolManager);
    function feeOracle() external view returns (IVaultFeeOracleQuery);
    function create3Factory() external view returns (ICreate3FactoryProxy);

    function deployWithMineNonce(
        address[] calldata tokens,
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external returns (address hook, PoolKey[] memory poolKeys);

    function ensurePairPools(address hook)
        external
        returns (PoolKey[] memory poolKeys, uint8 createdCount);

    function pairPoolKeys(address hook) external view returns (PoolKey[] memory);

    function isDeployedByFactory(address hook) external view returns (bool);

    function predictHookAddress(
        address[] calldata tokens,
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external view returns (address);
}

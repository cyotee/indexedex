// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

/**
 * @title IUniswapV4QuadStableSwapHookFactory
 * @notice Permissionless factory: CREATE3 mine/deploy hook + initialize all six pair doors.
 */
interface IUniswapV4QuadStableSwapHookFactory {
    event HookDeployed(
        address indexed deployer,
        address indexed hook,
        address poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp
    );

    event PairPoolsEnsured(address indexed hook, uint8 createdCount, uint8 alreadyLiveCount);

    function poolManager() external view returns (IPoolManager);
    function create3Factory() external view returns (ICreate3FactoryProxy);

    function deploy(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace
    ) external returns (address hook, PoolKey[6] memory poolKeys);

    function deployWithMineNonce(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external returns (address hook, PoolKey[6] memory poolKeys);

    function ensurePairPools(address hook)
        external
        returns (PoolKey[6] memory poolKeys, uint8 createdCount);

    function pairPoolKeys(address hook) external view returns (PoolKey[6] memory);

    function isDeployedByFactory(address hook) external view returns (bool);

    function predictHookAddress(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external view returns (address);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title IUniswapV4OrbitalSwapHookFactory
 * @notice Permissionless CREATE3 factory: deploy orbital hook + init three pair pools (PRD §5.2).
 */
interface IUniswapV4OrbitalSwapHookFactory {
    event HookDeployed(
        address indexed sender,
        address indexed hook,
        bytes32 salt,
        bytes32 effectiveSalt,
        address feeOracle,
        address token0,
        address token1,
        address token2
    );

    event PoolsInitialized(
        address indexed hook, bytes32 poolId01, bytes32 poolId12, bytes32 poolId02
    );

    error InvalidHookSalt();
    error SaltOccupied();
    error ZeroAddress();
    error SameToken();
    error IndexOutOfBounds();

    function HOOK_FLAGS() external view returns (uint160);
    function poolManager() external view returns (IPoolManager);

    function predictHookAddress(bytes32 salt, address deployer) external view returns (address);

    function isDeployedByFactory(address hook) external view returns (bool);

    function hooksOfBinding(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) external view returns (address[] memory hooks);

    function hooksOfBindingCount(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) external view returns (uint256);

    /// @notice 0-based external index (Q59 / D96)
    function hooksOfBindingAt(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2,
        uint256 index
    ) external view returns (address hook);

    function deploy(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2,
        bytes32 salt,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    )
        external
        returns (
            address hook,
            PoolKey memory poolKey01,
            PoolKey memory poolKey12,
            PoolKey memory poolKey02
        );
}

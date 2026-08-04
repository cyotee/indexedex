// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4WeightedSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_FactoryService.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    IUniswapV4WeightedSwapHookFactory
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHookFactory.sol";

/**
 * @title UniswapV4WeightedSwapHookFactory
 * @notice Permissionless factory: deployWithMineNonce + initialize all binom(n,2) doors.
 * @dev Immutables: create3Factory, poolManager, feeOracle. Never pulls tokens / mints LP.
 */
contract UniswapV4WeightedSwapHookFactory is IUniswapV4WeightedSwapHookFactory {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error NotFactoryHook();
    error InvalidTokenOrder();
    error InvalidWeight();
    error InvalidN();
    error ZeroAddress();

    IPoolManager public immutable override poolManager;
    ICreate3FactoryProxy public immutable override create3Factory;
    IVaultFeeOracleQuery public immutable override feeOracle;

    mapping(address => bool) internal _isDeployedByFactory;

    constructor(
        ICreate3FactoryProxy create3Factory_,
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_
    ) {
        if (
            address(create3Factory_) == address(0) || address(poolManager_) == address(0)
                || address(feeOracle_) == address(0)
        ) {
            revert ZeroAddress();
        }
        create3Factory = create3Factory_;
        poolManager = poolManager_;
        feeOracle = feeOracle_;
    }

    function isDeployedByFactory(address hook) external view override returns (bool) {
        return _isDeployedByFactory[hook];
    }

    function deployWithMineNonce(
        address[] calldata tokens,
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external override returns (address hook, PoolKey[] memory poolKeys) {
        _validateBinding(tokens, normalizedWeights, rateProviders);
        uint8 n = uint8(tokens.length);
        bool newlyDeployed;
        (hook, newlyDeployed) = _deploy(tokens, normalizedWeights, rateProviders, saltNamespace, mineNonce);
        _isDeployedByFactory[hook] = true;
        (poolKeys,,) = _ensurePairs(hook);
        if (newlyDeployed) {
            _emitDeployed(hook, n);
        }
    }

    function _deploy(
        address[] calldata tokens,
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) private returns (address hook, bool newlyDeployed) {
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = poolManager;
        p.feeOracle = feeOracle;
        p.tokens = tokens;
        p.weights = normalizedWeights;
        p.rateProviders = rateProviders;
        p.saltNamespace = saltNamespace;
        return FactoryService.deployHookParamsWithNonce(p, mineNonce);
    }

    function _emitDeployed(address hook, uint8 n) private {
        emit HookDeployed(msg.sender, hook, address(poolManager), address(feeOracle), n);
    }

    function ensurePairPools(address hook)
        external
        override
        returns (PoolKey[] memory poolKeys, uint8 createdCount)
    {
        if (!_isDeployedByFactory[hook]) revert NotFactoryHook();
        uint8 already;
        (poolKeys, createdCount, already) = _ensurePairs(hook);
        emit PairPoolsEnsured(hook, createdCount, already);
    }

    function pairPoolKeys(address hook) external view override returns (PoolKey[] memory) {
        return _computeKeys(hook);
    }

    function predictHookAddress(
        address[] calldata tokens,
        uint256[] calldata normalizedWeights,
        address[] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) external view override returns (address) {
        bytes32 salt = FactoryService.hookSalt(
            bytes(saltNamespace).length == 0
                ? FactoryService.DEFAULT_SALT_NAMESPACE
                : saltNamespace,
            address(poolManager),
            address(feeOracle),
            tokens,
            normalizedWeights,
            rateProviders,
            mineNonce
        );
        return HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt));
    }

    /* ---------------------------------------------------------------------- */
    /*                              internal                                  */
    /* ---------------------------------------------------------------------- */

    function _validateBinding(
        address[] calldata tokens,
        uint256[] calldata weights,
        address[] calldata rateProviders
    ) internal pure {
        uint256 n = tokens.length;
        if (n < Math.MIN_N || n > Math.MAX_N) revert InvalidN();
        if (weights.length != n || rateProviders.length != n) revert InvalidN();
        uint256 sum;
        for (uint256 i; i < n; ++i) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (i > 0 && !(tokens[i - 1] < tokens[i])) revert InvalidTokenOrder();
            if (weights[i] < Math.MIN_WEIGHT) revert InvalidWeight();
            sum += weights[i];
        }
        if (sum != Math.WAD) revert InvalidWeight();
    }

    function _computeKeys(address hook) internal view returns (PoolKey[] memory keys) {
        IUniswapV4WeightedSwapHook h = IUniswapV4WeightedSwapHook(hook);
        address[] memory toks = h.tokens();
        uint256 n = toks.length;
        uint256 pairCount = (n * (n - 1)) / 2;
        keys = new PoolKey[](pairCount);
        uint256 k;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                keys[k] = PoolKey({
                    currency0: Currency.wrap(toks[i]),
                    currency1: Currency.wrap(toks[j]),
                    fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
                    tickSpacing: int24(int256(Math.TICK_SPACING)),
                    hooks: IHooks(hook)
                });
                ++k;
            }
        }
    }

    function _ensurePairs(address hook)
        internal
        returns (PoolKey[] memory keys, uint8 created, uint8 already)
    {
        keys = _computeKeys(hook);
        uint160 sqrtPrice = TickMath.getSqrtPriceAtTick(0);
        for (uint256 i; i < keys.length; ++i) {
            PoolId id = keys[i].toId();
            (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(id);
            if (sqrtPriceX96 == 0) {
                poolManager.initialize(keys[i], sqrtPrice);
                ++created;
            } else {
                ++already;
            }
        }
    }
}

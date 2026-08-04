// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {CREATE3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/external/solmate/utils/CREATE3.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    AddressSet,
    AddressSetRepo
} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    IUniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookFactory.sol";
import {
    UniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook.sol";

/**
 * @title UniswapV4OrbitalSwapHookFactory
 * @notice Permissionless CREATE3 deploy of orbital hooks + three-pair pool init (PRD §5.2).
 * @dev deployer = factory; effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender)).
 */
contract UniswapV4OrbitalSwapHookFactory is IUniswapV4OrbitalSwapHookFactory {
    using AddressSetRepo for AddressSet;
    using PoolIdLibrary for PoolKey;
    using LPFeeLibrary for uint24;

    IPoolManager public immutable override poolManager;

    mapping(address => bool) private _isDeployedByFactory;
    mapping(bytes32 => AddressSet) private _hooksByBinding;

    constructor(IPoolManager poolManager_) {
        if (address(poolManager_) == address(0)) revert ZeroAddress();
        poolManager = poolManager_;
    }

    function HOOK_FLAGS() public pure override returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    function predictHookAddress(bytes32 salt, address deployer)
        public
        view
        override
        returns (address)
    {
        bytes32 effectiveSalt = keccak256(abi.encodePacked(salt, deployer));
        return CREATE3.getDeployed(effectiveSalt, address(this));
    }

    function isDeployedByFactory(address hook) external view override returns (bool) {
        return _isDeployedByFactory[hook];
    }

    function hooksOfBinding(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) external view override returns (address[] memory) {
        return _hooksByBinding[_bindingKey(feeOracle, token0, token1, token2)]._asArray();
    }

    function hooksOfBindingCount(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) external view override returns (uint256) {
        return _hooksByBinding[_bindingKey(feeOracle, token0, token1, token2)]._length();
    }

    function hooksOfBindingAt(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2,
        uint256 index
    ) external view override returns (address) {
        AddressSet storage set = _hooksByBinding[_bindingKey(feeOracle, token0, token1, token2)];
        if (index >= set._length()) revert IndexOutOfBounds();
        return set.values[index];
    }

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
        override
        returns (
            address hook,
            PoolKey memory poolKey01,
            PoolKey memory poolKey12,
            PoolKey memory poolKey02
        )
    {
        _validateBinding(feeOracle, token0, token1, token2);
        hook = _deployOrReuse(feeOracle, token0, token1, token2, salt);
        (poolKey01, poolKey12, poolKey02) =
            _initThreePools(hook, token0, token1, token2, tickSpacing, sqrtPriceX96);
    }

    function _validateBinding(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) internal pure {
        if (address(feeOracle) == address(0) || token0 == address(0) || token1 == address(0)
                || token2 == address(0)) {
            revert ZeroAddress();
        }
        if (token0 == token1 || token1 == token2 || token0 == token2) revert SameToken();
    }

    function _deployOrReuse(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2,
        bytes32 salt
    ) internal returns (address hook) {
        bytes32 effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender));
        address predicted = CREATE3.getDeployed(effectiveSalt, address(this));
        if (uint160(predicted) & Hooks.ALL_HOOK_MASK != HOOK_FLAGS()) revert InvalidHookSalt();

        if (predicted.code.length == 0) {
            hook = CREATE3.deploy(
                effectiveSalt,
                abi.encodePacked(
                    type(UniswapV4OrbitalSwapHook).creationCode,
                    abi.encode(poolManager, feeOracle, token0, token1, token2)
                ),
                0
            );
            _isDeployedByFactory[hook] = true;
            _hooksByBinding[_bindingKey(feeOracle, token0, token1, token2)]._add(hook);
            emit HookDeployed(
                msg.sender, hook, salt, effectiveSalt, address(feeOracle), token0, token1, token2
            );
        } else {
            if (!_isExpectedHook(predicted, feeOracle, token0, token1, token2)) {
                revert SaltOccupied();
            }
            hook = predicted;
        }
    }

    function _initThreePools(
        address hook,
        address token0,
        address token1,
        address token2,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    )
        internal
        returns (PoolKey memory poolKey01, PoolKey memory poolKey12, PoolKey memory poolKey02)
    {
        int24 spacing = tickSpacing == 0 ? int24(60) : tickSpacing;
        uint160 price = sqrtPriceX96 == 0 ? TickMath.getSqrtPriceAtTick(0) : sqrtPriceX96;
        IHooks h = IHooks(hook);

        poolKey01 = _pairKey(token0, token1, spacing, h);
        poolKey12 = _pairKey(token1, token2, spacing, h);
        poolKey02 = _pairKey(token0, token2, spacing, h);

        _initIfNeeded(poolKey01, price);
        _initIfNeeded(poolKey12, price);
        _initIfNeeded(poolKey02, price);

        emit PoolsInitialized(
            hook,
            PoolId.unwrap(poolKey01.toId()),
            PoolId.unwrap(poolKey12.toId()),
            PoolId.unwrap(poolKey02.toId())
        );
    }

    function _bindingKey(
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(feeOracle, token0, token1, token2));
    }

    function _isExpectedHook(
        address predicted,
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) internal view returns (bool) {
        IUniswapV4OrbitalSwapHook h = IUniswapV4OrbitalSwapHook(predicted);
        try h.poolManager() returns (IPoolManager pm) {
            if (address(pm) != address(poolManager)) return false;
        } catch {
            return false;
        }
        try h.feeOracle() returns (IVaultFeeOracleQuery fo) {
            if (address(fo) != address(feeOracle)) return false;
        } catch {
            return false;
        }
        try h.token0() returns (address t0) {
            if (t0 != token0) return false;
        } catch {
            return false;
        }
        try h.token1() returns (address t1) {
            if (t1 != token1) return false;
        } catch {
            return false;
        }
        try h.token2() returns (address t2) {
            if (t2 != token2) return false;
        } catch {
            return false;
        }
        return _isDeployedByFactory[predicted];
    }

    function _pairKey(address a, address b, int24 spacing, IHooks hooks)
        internal
        pure
        returns (PoolKey memory key)
    {
        (address c0, address c1) = a < b ? (a, b) : (b, a);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: spacing,
            hooks: hooks
        });
    }

    function _initIfNeeded(PoolKey memory key, uint160 sqrtPriceX96) internal {
        PoolId id = key.toId();
        // If already initialized, initialize reverts — catch and skip (Q54)
        try poolManager.initialize(key, sqrtPriceX96) {}
        catch {
            // already initialized or other failure — leave existing alone
            id;
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {CREATE3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/external/solmate/utils/CREATE3.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookFactory.sol";
import {
    IUniswapV4OrbitalSwapHookFactory
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookFactory.sol";

/**
 * @title UniswapV4OrbitalSwapHook_FactoryService
 * @notice Off-chain salt mine helpers + factory self-deploy (PRD §5.2.1).
 * @dev Instances always go through factory.deploy — never ecosystem create3Factory for hooks.
 */
library UniswapV4OrbitalSwapHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    string internal constant DEFAULT_SALT_NAMESPACE = "uv4-orbital-swap-hook-";
    uint256 internal constant MAX_LOOP = 160_444;

    error HookMineExhausted();
    error ZeroAddress();

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    /// @dev Mine userSalt so CREATE3.getDeployed(keccak256(userSalt, deployer), factory) has flags.
    function mineSalt(address factory, address deployer, uint160 flags)
        internal
        view
        returns (bytes32 userSalt, address predicted)
    {
        if (factory == address(0) || deployer == address(0)) revert ZeroAddress();
        flags = flags & Hooks.ALL_HOOK_MASK;
        for (uint256 i; i < MAX_LOOP; i++) {
            userSalt = bytes32(i);
            bytes32 effectiveSalt = keccak256(abi.encodePacked(userSalt, deployer));
            predicted = CREATE3.getDeployed(effectiveSalt, factory);
            if (uint160(predicted) & Hooks.ALL_HOOK_MASK == flags && predicted.code.length == 0) {
                return (userSalt, predicted);
            }
        }
        revert HookMineExhausted();
    }

    function mineSalt(address factory, address deployer)
        internal
        view
        returns (bytes32 userSalt, address predicted)
    {
        return mineSalt(factory, deployer, requiredFlags());
    }

    /// @dev Recommended unique preimage then mine (D83 + Q53).
    function mineSaltForBinding(
        address factory,
        address deployer,
        string memory namespace,
        IVaultFeeOracleQuery feeOracle,
        address token0,
        address token1,
        address token2
    ) internal view returns (bytes32 userSalt, address predicted) {
        if (bytes(namespace).length == 0) {
            namespace = DEFAULT_SALT_NAMESPACE;
        }
        uint160 flags = requiredFlags();
        for (uint256 mineNonce; mineNonce < MAX_LOOP; mineNonce++) {
            userSalt = abi.encode(namespace, feeOracle, token0, token1, token2, mineNonce)._hash();
            bytes32 effectiveSalt = keccak256(abi.encodePacked(userSalt, deployer));
            predicted = CREATE3.getDeployed(effectiveSalt, factory);
            if (uint160(predicted) & Hooks.ALL_HOOK_MASK == flags && predicted.code.length == 0) {
                return (userSalt, predicted);
            }
        }
        revert HookMineExhausted();
    }

    /// @dev Deploy the factory once per chain (plain CREATE).
    function deployFactory(IPoolManager poolManager) internal returns (address factory) {
        if (address(poolManager) == address(0)) revert ZeroAddress();
        factory = address(new UniswapV4OrbitalSwapHookFactory(poolManager));
    }

    function isExpectedHook(
        address predicted,
        address poolManager,
        address feeOracle,
        address token0,
        address token1,
        address token2
    ) internal view returns (bool) {
        if (predicted.code.length == 0) return false;
        try IUniswapV4OrbitalSwapHookLike(predicted).poolManager() returns (address pm) {
            if (pm != poolManager) return false;
        } catch {
            return false;
        }
        try IUniswapV4OrbitalSwapHookLike(predicted).feeOracle() returns (address fo) {
            if (fo != feeOracle) return false;
        } catch {
            return false;
        }
        try IUniswapV4OrbitalSwapHookLike(predicted).token0() returns (address t0) {
            if (t0 != token0) return false;
        } catch {
            return false;
        }
        try IUniswapV4OrbitalSwapHookLike(predicted).token1() returns (address t1) {
            if (t1 != token1) return false;
        } catch {
            return false;
        }
        try IUniswapV4OrbitalSwapHookLike(predicted).token2() returns (address t2) {
            if (t2 != token2) return false;
        } catch {
            return false;
        }
        return true;
    }
}

interface IUniswapV4OrbitalSwapHookLike {
    function poolManager() external view returns (address);
    function feeOracle() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function token2() external view returns (address);
}

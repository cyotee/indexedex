// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService
 * @notice Binding-aware CREATE3 mine + deploy for dual SE buffer CP hook.
 * @dev isExpectedHook is factory/internal only (D80) — not on hook ABI.
 */
library UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    string internal constant DEFAULT_SALT_NAMESPACE = "uv4-dual-se-buffer-constant-product-hook-";

    error HookMineExhausted();
    error HookDeployCollision(address occupied);
    error ZeroAddress();

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    /// @dev Salt: namespace + poolManager + feeOracle + sorted legs + mineNonce (C28). No Permit2.
    function hookSalt(
        string memory namespace,
        address poolManager,
        address feeOracle,
        address se0,
        address token0,
        address se1,
        address token1,
        uint256 mineNonce
    ) internal pure returns (bytes32) {
        if (bytes(namespace).length == 0) {
            namespace = DEFAULT_SALT_NAMESPACE;
        }
        (address seLo, address tLo, address seHi, address tHi) =
            token0 < token1 ? (se0, token0, se1, token1) : (se1, token1, se0, token0);
        return abi.encodePacked(namespace, poolManager, feeOracle, seLo, tLo, seHi, tHi, mineNonce)
            ._hash();
    }

    /// @dev Factory / deploy-idempotency only — not required on hook public ABI (D80).
    function isExpectedHook(
        address predicted,
        address poolManager,
        address feeOracle,
        address se0,
        address token0,
        address se1,
        address token1
    ) internal view returns (bool) {
        if (predicted.code.length == 0) return false;
        IUniswapV4DualStandardExchangeBufferConstantProductHook h =
            IUniswapV4DualStandardExchangeBufferConstantProductHook(predicted);
        try h.poolManager() returns (address pm) {
            if (pm != poolManager) return false;
        } catch {
            return false;
        }
        try h.feeOracle() returns (address fo) {
            if (fo != feeOracle) return false;
        } catch {
            return false;
        }
        address gotSe0;
        address gotSe1;
        address gotT0;
        address gotT1;
        try h.standardExchange0() returns (address s0) {
            gotSe0 = s0;
        } catch {
            return false;
        }
        try h.standardExchange1() returns (address s1) {
            gotSe1 = s1;
        } catch {
            return false;
        }
        try h.token0() returns (address t0) {
            gotT0 = t0;
        } catch {
            return false;
        }
        try h.token1() returns (address t1) {
            gotT1 = t1;
        } catch {
            return false;
        }
        bool sameOrder = gotSe0 == se0 && gotT0 == token0 && gotSe1 == se1 && gotT1 == token1;
        bool swapped = gotSe0 == se1 && gotT0 == token1 && gotSe1 == se0 && gotT1 == token0;
        return sameOrder || swapped;
    }

    function deployHook(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        IVaultFeeOracleQuery feeOracle,
        address se0,
        address token0,
        address se1,
        address token1
    ) internal returns (address hook) {
        return deployHook(create3Factory, poolManager, feeOracle, se0, token0, se1, token1, "");
    }

    function deployHook(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        IVaultFeeOracleQuery feeOracle,
        address se0,
        address token0,
        address se1,
        address token1,
        string memory saltNamespace
    ) internal returns (address hook) {
        _requireNonZeroDeployArgs(create3Factory, poolManager, feeOracle, se0, token0, se1, token1);
        if (bytes(saltNamespace).length == 0) {
            saltNamespace = DEFAULT_SALT_NAMESPACE;
        }
        bytes memory creationCode =
            type(UniswapV4DualStandardExchangeBufferConstantProductHook).creationCode;
        bytes memory ctorArgs = abi.encode(poolManager, feeOracle, se0, token0, se1, token1);
        return _mineAndDeploy(
            create3Factory,
            saltNamespace,
            address(poolManager),
            address(feeOracle),
            se0,
            token0,
            se1,
            token1,
            creationCode,
            ctorArgs
        );
    }

    function _requireNonZeroDeployArgs(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        IVaultFeeOracleQuery feeOracle,
        address se0,
        address token0,
        address se1,
        address token1
    ) private pure {
        if (
            address(create3Factory) == address(0) || address(poolManager) == address(0)
                || address(feeOracle) == address(0) || se0 == address(0) || token0 == address(0)
                || se1 == address(0) || token1 == address(0)
        ) {
            revert ZeroAddress();
        }
    }

    function _mineAndDeploy(
        ICreate3FactoryProxy create3Factory,
        string memory namespace,
        address poolManager,
        address feeOracle,
        address se0,
        address token0,
        address se1,
        address token1,
        bytes memory creationCode,
        bytes memory ctorArgs
    ) private returns (address hook) {
        uint160 flags = requiredFlags();
        for (uint256 mineNonce; mineNonce < HookMinerCreate3.MAX_LOOP; ++mineNonce) {
            bytes32 salt =
                hookSalt(namespace, poolManager, feeOracle, se0, token0, se1, token1, mineNonce);
            address predicted =
                HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt));
            if (uint160(predicted) & HookMinerCreate3.FLAG_MASK != flags) continue;

            if (predicted.code.length == 0) {
                hook = ICreate3Factory(address(create3Factory)).create3WithArgs(
                    creationCode, ctorArgs, salt
                );
                if (hook != predicted || predicted.code.length == 0) {
                    revert HookDeployCollision(hook);
                }
                return hook;
            }

            if (isExpectedHook(predicted, poolManager, feeOracle, se0, token0, se1, token1)) {
                return predicted;
            }
            revert HookDeployCollision(predicted);
        }
        revert HookMineExhausted();
    }
}

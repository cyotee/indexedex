// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {UniswapV4SingleStandardExchangeBufferPricingHook} from
    "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferPricingHook.sol";
import {IUniswapV4SingleStandardExchangeBufferPricingHook} from
    "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferPricingHook.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService
 * @notice Binding-aware CREATE3 mine + deploy on existing create3Factory (D20/D32/D37).
 * @dev Do not use bare HookMinerCreate3.find / findWithPrefix for product deploys.
 */
library UniswapV4SingleStandardExchangeBufferPricingHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    string internal constant DEFAULT_SALT_NAMESPACE = "uv4-single-se-buffer-pricing-hook-";

    error HookMineExhausted();
    error HookDeployCollision(address occupied);
    error ZeroAddress();

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
    }

    function hookSalt(
        string memory namespace,
        address poolManager,
        address standardExchange,
        address underlying,
        uint256 mineNonce
    ) internal pure returns (bytes32) {
        if (bytes(namespace).length == 0) {
            namespace = DEFAULT_SALT_NAMESPACE;
        }
        return abi.encodePacked(namespace, poolManager, standardExchange, underlying, mineNonce)._hash();
    }

    function isExpectedHook(
        address predicted,
        address poolManager,
        address standardExchange,
        address underlying
    ) internal view returns (bool) {
        if (predicted.code.length == 0) return false;
        try IUniswapV4SingleStandardExchangeBufferPricingHook(predicted).poolManager() returns (IPoolManager pm) {
            if (address(pm) != poolManager) return false;
        } catch {
            return false;
        }
        try IUniswapV4SingleStandardExchangeBufferPricingHook(predicted).standardExchange() returns (address se) {
            if (se != standardExchange) return false;
        } catch {
            return false;
        }
        try IUniswapV4SingleStandardExchangeBufferPricingHook(predicted).underlying() returns (address u) {
            if (u != underlying) return false;
        } catch {
            return false;
        }
        return true;
    }

    function deployHook(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        address standardExchange,
        address underlying
    ) internal returns (address hook) {
        return deployHook(create3Factory, poolManager, standardExchange, underlying, "");
    }

    function deployHook(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        address standardExchange,
        address underlying,
        string memory saltNamespace
    ) internal returns (address hook) {
        if (
            address(create3Factory) == address(0) || address(poolManager) == address(0)
                || standardExchange == address(0) || underlying == address(0)
        ) {
            revert ZeroAddress();
        }

        string memory namespace =
            bytes(saltNamespace).length == 0 ? DEFAULT_SALT_NAMESPACE : saltNamespace;
        uint160 flags = requiredFlags();
        bytes memory creationCode = type(UniswapV4SingleStandardExchangeBufferPricingHook).creationCode;
        bytes memory ctorArgs = abi.encode(poolManager, standardExchange, underlying);

        for (uint256 mineNonce; mineNonce < HookMinerCreate3.MAX_LOOP; mineNonce++) {
            bytes32 salt =
                hookSalt(namespace, address(poolManager), standardExchange, underlying, mineNonce);
            address predicted =
                HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt));

            if (uint160(predicted) & HookMinerCreate3.FLAG_MASK != flags) {
                continue;
            }

            if (predicted.code.length == 0) {
                // Deploy via existing create3Factory (onlyOwnerOrOperator on factory).
                // Ctor validation (e.g. underlying ∈ vaultTokens) reverts the whole call if invalid.
                hook = ICreate3Factory(address(create3Factory)).create3WithArgs(
                    creationCode, ctorArgs, salt
                );
                // Predicted uses HookMinerCreate3.computeAddress(deployer=create3Factory).
                // Crane Creation.create3 uses the same Solmate CREATE3 deployer=factory.
                if (hook != predicted || predicted.code.length == 0) {
                    revert HookDeployCollision(hook);
                }
                return hook;
            }

            // Occupied at first flag-matching salt for this (namespace, binding)
            if (isExpectedHook(predicted, address(poolManager), standardExchange, underlying)) {
                return predicted;
            }
            revert HookDeployCollision(predicted);
        }

        revert HookMineExhausted();
    }
}

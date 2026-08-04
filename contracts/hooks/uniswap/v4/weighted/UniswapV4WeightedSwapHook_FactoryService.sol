// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";
import {
    UniswapV4WeightedSwapHookDeployer as Deployer
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookDeployer.sol";

/**
 * @title UniswapV4WeightedSwapHook_FactoryService
 * @notice Binding-aware CREATE3 salt + deployWithMineNonce (library / factory+tests only).
 * @dev O1 pin: deployer = address(create3Factory); salt via BetterEfficientHashLib._hash().
 *      Not on public hook ABI.
 */
library UniswapV4WeightedSwapHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    string internal constant DEFAULT_SALT_NAMESPACE = "uv4-weighted-swap-hook-";

    error HookMineExhausted();
    error HookDeployCollision(address occupied);
    error InvalidMineNonce();
    error ZeroAddress();

    struct DeployParams {
        ICreate3FactoryProxy create3Factory;
        IPoolManager poolManager;
        IVaultFeeOracleQuery feeOracle;
        address[] tokens;
        uint256[] weights;
        address[] rateProviders;
        string saltNamespace;
    }

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
        );
    }

    function hookSalt(
        string memory namespace,
        address poolManager,
        address feeOracle,
        address[] memory tokens,
        uint256[] memory weights,
        address[] memory rateProviders,
        uint256 mineNonce
    ) internal pure returns (bytes32) {
        if (bytes(namespace).length == 0) {
            namespace = DEFAULT_SALT_NAMESPACE;
        }
        uint8 n = uint8(tokens.length);
        return abi.encodePacked(
            namespace, poolManager, feeOracle, n, tokens, weights, rateProviders, mineNonce
        )._hash();
    }

    function _saltFor(DeployParams memory p, uint256 mineNonce) private pure returns (bytes32) {
        string memory namespace =
            bytes(p.saltNamespace).length == 0 ? DEFAULT_SALT_NAMESPACE : p.saltNamespace;
        return hookSalt(
            namespace,
            address(p.poolManager),
            address(p.feeOracle),
            p.tokens,
            p.weights,
            p.rateProviders,
            mineNonce
        );
    }

    function _ctorArgs(DeployParams memory p) private pure returns (bytes memory) {
        return abi.encode(p.poolManager, p.feeOracle, p.tokens, p.weights, p.rateProviders);
    }

    function isExpectedHook(
        address predicted,
        address poolManager,
        address feeOracle,
        address[] memory tokens,
        uint256[] memory weights,
        address[] memory rateProviders
    ) internal view returns (bool) {
        if (predicted.code.length == 0) return false;
        IUniswapV4WeightedSwapHook h = IUniswapV4WeightedSwapHook(predicted);
        try h.poolManager() returns (IPoolManager pm) {
            if (address(pm) != poolManager) return false;
        } catch {
            return false;
        }
        try h.feeOracle() returns (IVaultFeeOracleQuery fo) {
            if (address(fo) != feeOracle) return false;
        } catch {
            return false;
        }
        try h.numTokens() returns (uint8 n) {
            if (n != tokens.length) return false;
        } catch {
            return false;
        }
        try h.tokens() returns (address[] memory t) {
            if (t.length != tokens.length) return false;
            for (uint256 i; i < t.length; ++i) {
                if (t[i] != tokens[i]) return false;
            }
        } catch {
            return false;
        }
        try h.getNormalizedWeights() returns (uint256[] memory w) {
            if (w.length != weights.length) return false;
            for (uint256 i; i < w.length; ++i) {
                if (w[i] != weights[i]) return false;
            }
        } catch {
            return false;
        }
        // rate providers checked per-index
        for (uint256 i; i < rateProviders.length; ++i) {
            try h.rateProvider(i) returns (address rp) {
                if (rp != rateProviders[i]) return false;
            } catch {
                return false;
            }
        }
        return true;
    }

    function _isExpected(DeployParams memory p, address predicted) private view returns (bool) {
        return isExpectedHook(
            predicted,
            address(p.poolManager),
            address(p.feeOracle),
            p.tokens,
            p.weights,
            p.rateProviders
        );
    }

    /// @dev public so creationCode lives in linked library bytecode (keeps Factory under size limit).
    function deployHookParamsWithNonce(DeployParams memory p, uint256 mineNonce)
        public
        returns (address hook, bool newlyDeployed)
    {
        return _deployWithNonce(p, mineNonce);
    }

    function _deployWithNonce(DeployParams memory p, uint256 mineNonce)
        private
        returns (address hook, bool newlyDeployed)
    {
        if (
            address(p.create3Factory) == address(0) || address(p.poolManager) == address(0)
                || address(p.feeOracle) == address(0)
        ) {
            revert ZeroAddress();
        }
        for (uint256 i; i < p.tokens.length; ++i) {
            if (p.tokens[i] == address(0)) revert ZeroAddress();
        }

        uint160 flags = requiredFlags();
        bytes32 salt = _saltFor(p, mineNonce);
        address predicted = HookMinerCreate3.computeAddress(address(p.create3Factory), uint256(salt));
        if (uint160(predicted) & HookMinerCreate3.FLAG_MASK != flags) {
            revert InvalidMineNonce();
        }

        if (predicted.code.length == 0) {
            hook = Deployer.create3Hook(address(p.create3Factory), _ctorArgs(p), salt);
            if (hook != predicted || predicted.code.length == 0) {
                revert HookDeployCollision(hook);
            }
            return (hook, true);
        }

        if (_isExpected(p, predicted)) {
            return (predicted, false);
        }
        revert HookDeployCollision(predicted);
    }

    /// @dev Off-chain mine helper for tests: loop until flags match.
    function mineNonceFor(DeployParams memory p) public view returns (uint256 mineNonce, address predicted) {
        uint160 flags = requiredFlags();
        for (mineNonce = 0; mineNonce < HookMinerCreate3.MAX_LOOP; mineNonce++) {
            bytes32 salt = _saltFor(p, mineNonce);
            predicted = HookMinerCreate3.computeAddress(address(p.create3Factory), uint256(salt));
            if (uint160(predicted) & HookMinerCreate3.FLAG_MASK == flags) {
                return (mineNonce, predicted);
            }
        }
        revert HookMineExhausted();
    }
}

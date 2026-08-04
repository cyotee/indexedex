// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ICreate3Factory} from "@crane/contracts/factories/create3/ICreate3Factory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHookDeployer as Deployer
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookDeployer.sol";

/**
 * @title UniswapV4QuadStableSwapHook_FactoryService
 * @notice Binding-aware CREATE3 mine + deploy (library / factory+tests only).
 * @dev Not on public hook ABI. Pattern-copy from single SE buffer FactoryService.
 *      DeployParams packs args to avoid stack-too-deep without via_ir.
 */
library UniswapV4QuadStableSwapHook_FactoryService {
    using BetterEfficientHashLib for bytes;

    string internal constant DEFAULT_SALT_NAMESPACE = "uv4-quad-stable-swap-hook-";

    error HookMineExhausted();
    error HookDeployCollision(address occupied);
    error InvalidMineNonce();
    error ZeroAddress();

    struct DeployParams {
        ICreate3FactoryProxy create3Factory;
        IPoolManager poolManager;
        address token0;
        address token1;
        address token2;
        address token3;
        uint24 lpFeePips;
        uint256 baseAmp;
        address[4] rateProviders;
        string saltNamespace;
    }

    function requiredFlags() internal pure returns (uint160) {
        return uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
        );
    }

    function rateProviderFingerprint(address[4] memory providers) internal pure returns (bytes32) {
        return abi.encodePacked(providers[0], providers[1], providers[2], providers[3])._hash();
    }

    function hookSalt(
        string memory namespace,
        address poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        bytes32 rateFp,
        uint256 mineNonce
    ) internal pure returns (bytes32) {
        if (bytes(namespace).length == 0) {
            namespace = DEFAULT_SALT_NAMESPACE;
        }
        return abi.encodePacked(
            namespace, poolManager, token0, token1, token2, token3, lpFeePips, baseAmp, rateFp, mineNonce
        )._hash();
    }

    function _saltFor(DeployParams memory p, uint256 mineNonce) private pure returns (bytes32) {
        string memory namespace =
            bytes(p.saltNamespace).length == 0 ? DEFAULT_SALT_NAMESPACE : p.saltNamespace;
        return hookSalt(
            namespace,
            address(p.poolManager),
            p.token0,
            p.token1,
            p.token2,
            p.token3,
            p.lpFeePips,
            p.baseAmp,
            rateProviderFingerprint(p.rateProviders),
            mineNonce
        );
    }

    function _ctorArgs(DeployParams memory p) private pure returns (bytes memory) {
        return abi.encode(
            p.poolManager,
            p.token0,
            p.token1,
            p.token2,
            p.token3,
            p.lpFeePips,
            p.baseAmp,
            p.rateProviders
        );
    }

    function isExpectedHook(
        address predicted,
        address poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] memory rateProviders
    ) internal view returns (bool) {
        if (predicted.code.length == 0) return false;
        IUniswapV4QuadStableSwapHook h = IUniswapV4QuadStableSwapHook(predicted);
        try h.poolManager() returns (IPoolManager pm) {
            if (address(pm) != poolManager) return false;
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
        try h.token3() returns (address t3) {
            if (t3 != token3) return false;
        } catch {
            return false;
        }
        try h.lpFeePips() returns (uint24 fee) {
            if (fee != lpFeePips) return false;
        } catch {
            return false;
        }
        try h.baseAmp() returns (uint256 amp) {
            if (amp != baseAmp) return false;
        } catch {
            return false;
        }
        try h.rateProviders() returns (address[4] memory pr) {
            if (
                pr[0] != rateProviders[0] || pr[1] != rateProviders[1] || pr[2] != rateProviders[2]
                    || pr[3] != rateProviders[3]
            ) return false;
        } catch {
            return false;
        }
        return true;
    }

    function _isExpected(DeployParams memory p, address predicted) private view returns (bool) {
        return isExpectedHook(
            predicted,
            address(p.poolManager),
            p.token0,
            p.token1,
            p.token2,
            p.token3,
            p.lpFeePips,
            p.baseAmp,
            p.rateProviders
        );
    }

    /// @dev `public` so creationCode lives in linked library bytecode (keeps Factory under size limit).
    function deployHook(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] memory rateProviders,
        string memory saltNamespace
    ) public returns (address hook, bool newlyDeployed) {
        return deployHookParams(
            DeployParams(
                create3Factory,
                poolManager,
                token0,
                token1,
                token2,
                token3,
                lpFeePips,
                baseAmp,
                rateProviders,
                saltNamespace
            )
        );
    }

    function deployHookParams(DeployParams memory p) public returns (address hook, bool newlyDeployed) {
        return _deployMine(p);
    }

    function _deployMine(DeployParams memory p) private returns (address hook, bool newlyDeployed) {
        if (
            address(p.create3Factory) == address(0) || address(p.poolManager) == address(0)
                || p.token0 == address(0) || p.token1 == address(0) || p.token2 == address(0)
                || p.token3 == address(0)
        ) {
            revert ZeroAddress();
        }

        uint160 flags = requiredFlags();
        bytes memory ctorArgs = _ctorArgs(p);

        for (uint256 mineNonce; mineNonce < HookMinerCreate3.MAX_LOOP; mineNonce++) {
            bytes32 salt = _saltFor(p, mineNonce);
            address predicted =
                HookMinerCreate3.computeAddress(address(p.create3Factory), uint256(salt));

            if (uint160(predicted) & HookMinerCreate3.FLAG_MASK != flags) {
                continue;
            }

            if (predicted.code.length == 0) {
                hook = Deployer.create3Hook(address(p.create3Factory), ctorArgs, salt);
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

        revert HookMineExhausted();
    }

    /// @dev `public` so creationCode lives in linked library bytecode (keeps Factory under size limit).
    function deployHookWithMineNonce(
        ICreate3FactoryProxy create3Factory,
        IPoolManager poolManager,
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] memory rateProviders,
        string memory saltNamespace,
        uint256 mineNonce
    ) public returns (address hook, bool newlyDeployed) {
        return deployHookParamsWithNonce(
            DeployParams(
                create3Factory,
                poolManager,
                token0,
                token1,
                token2,
                token3,
                lpFeePips,
                baseAmp,
                rateProviders,
                saltNamespace
            ),
            mineNonce
        );
    }

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
                || p.token0 == address(0) || p.token1 == address(0) || p.token2 == address(0)
                || p.token3 == address(0)
        ) {
            revert ZeroAddress();
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
}

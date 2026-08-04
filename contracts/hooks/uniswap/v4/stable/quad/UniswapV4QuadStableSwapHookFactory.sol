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
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {
    UniswapV4QuadStableSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHook_FactoryService.sol";
import {
    UniswapV4QuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHookMath.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";
import {
    IUniswapV4QuadStableSwapHookFactory
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHookFactory.sol";

/**
 * @title UniswapV4QuadStableSwapHookFactory
 * @notice Permissionless factory: mine/deploy hook + initialize all six pair doors.
 * @dev Immutable poolManager = canonical V4 PM (D67). Never pulls tokens / mints LP.
 */
contract UniswapV4QuadStableSwapHookFactory is IUniswapV4QuadStableSwapHookFactory {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error NotFactoryHook();
    error InvalidTokenOrder();
    error ZeroAddress();

    IPoolManager public immutable override poolManager;
    ICreate3FactoryProxy public immutable override create3Factory;

    mapping(address => bool) internal _isDeployedByFactory;

    constructor(ICreate3FactoryProxy create3Factory_, IPoolManager poolManager_) {
        if (address(create3Factory_) == address(0) || address(poolManager_) == address(0)) {
            revert ZeroAddress();
        }
        create3Factory = create3Factory_;
        poolManager = poolManager_;
    }

    function isDeployedByFactory(address hook) external view override returns (bool) {
        return _isDeployedByFactory[hook];
    }

    function deploy(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace
    ) external override returns (address hook, PoolKey[6] memory poolKeys) {
        _requireSorted(token0, token1, token2, token3);
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = poolManager;
        p.token0 = token0;
        p.token1 = token1;
        p.token2 = token2;
        p.token3 = token3;
        p.lpFeePips = lpFeePips;
        p.baseAmp = baseAmp;
        p.rateProviders = rateProviders;
        p.saltNamespace = saltNamespace;
        bool newlyDeployed;
        (hook, newlyDeployed) = FactoryService.deployHookParams(p);
        poolKeys = _finalizeDeploy(hook, newlyDeployed, lpFeePips, baseAmp);
    }

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
    ) external override returns (address hook, PoolKey[6] memory poolKeys) {
        _requireSorted(token0, token1, token2, token3);
        FactoryService.DeployParams memory p;
        p.create3Factory = create3Factory;
        p.poolManager = poolManager;
        p.token0 = token0;
        p.token1 = token1;
        p.token2 = token2;
        p.token3 = token3;
        p.lpFeePips = lpFeePips;
        p.baseAmp = baseAmp;
        p.rateProviders = rateProviders;
        p.saltNamespace = saltNamespace;
        bool newlyDeployed;
        (hook, newlyDeployed) = FactoryService.deployHookParamsWithNonce(p, mineNonce);
        poolKeys = _finalizeDeploy(hook, newlyDeployed, lpFeePips, baseAmp);
    }

    function _finalizeDeploy(address hook, bool newlyDeployed, uint24 lpFeePips, uint256 baseAmp)
        private
        returns (PoolKey[6] memory poolKeys)
    {
        _isDeployedByFactory[hook] = true;
        IUniswapV4QuadStableSwapHook h = IUniswapV4QuadStableSwapHook(hook);
        (poolKeys,,) = _ensurePairs(hook, h.token0(), h.token1(), h.token2(), h.token3(), lpFeePips);
        if (newlyDeployed) {
            _emitDeployed(hook, h.token0(), h.token1(), h.token2(), h.token3(), lpFeePips, baseAmp);
        }
    }

    function _emitDeployed(
        address hook,
        address t0,
        address t1,
        address t2,
        address t3,
        uint24 fee,
        uint256 amp
    ) private {
        emit HookDeployed(msg.sender, hook, address(poolManager), t0, t1, t2, t3, fee, amp);
    }

    function ensurePairPools(address hook)
        external
        override
        returns (PoolKey[6] memory poolKeys, uint8 createdCount)
    {
        if (!_isDeployedByFactory[hook]) revert NotFactoryHook();
        IUniswapV4QuadStableSwapHook h = IUniswapV4QuadStableSwapHook(hook);
        uint8 already;
        (poolKeys, createdCount, already) = _ensurePairs(
            hook, h.token0(), h.token1(), h.token2(), h.token3(), h.lpFeePips()
        );
        emit PairPoolsEnsured(hook, createdCount, already);
    }

    function pairPoolKeys(address hook) external view override returns (PoolKey[6] memory keys) {
        IUniswapV4QuadStableSwapHook h = IUniswapV4QuadStableSwapHook(hook);
        return _computeKeys(hook, h.token0(), h.token1(), h.token2(), h.token3(), h.lpFeePips());
    }

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
    ) external view override returns (address) {
        return _predict(
            token0, token1, token2, token3, lpFeePips, baseAmp, rateProviders, saltNamespace, mineNonce
        );
    }

    function _predict(
        address token0,
        address token1,
        address token2,
        address token3,
        uint24 lpFeePips,
        uint256 baseAmp,
        address[4] calldata rateProviders,
        string calldata saltNamespace,
        uint256 mineNonce
    ) private view returns (address) {
        bytes32 salt = FactoryService.hookSalt(
            bytes(saltNamespace).length == 0
                ? FactoryService.DEFAULT_SALT_NAMESPACE
                : saltNamespace,
            address(poolManager),
            token0,
            token1,
            token2,
            token3,
            lpFeePips,
            baseAmp,
            FactoryService.rateProviderFingerprint(rateProviders),
            mineNonce
        );
        return HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt));
    }

    /* ---------------------------------------------------------------------- */
    /*                              internal                                  */
    /* ---------------------------------------------------------------------- */

    function _requireSorted(address t0, address t1, address t2, address t3) internal pure {
        if (!(t0 < t1 && t1 < t2 && t2 < t3)) revert InvalidTokenOrder();
        if (t0 == address(0)) revert ZeroAddress();
    }

    function _computeKeys(
        address hook,
        address t0,
        address t1,
        address t2,
        address t3,
        uint24 fee
    ) internal pure returns (PoolKey[6] memory keys) {
        // pairs: (0,1)(0,2)(0,3)(1,2)(1,3)(2,3) — already address-sorted by binding order
        keys[0] = _key(hook, t0, t1, fee);
        keys[1] = _key(hook, t0, t2, fee);
        keys[2] = _key(hook, t0, t3, fee);
        keys[3] = _key(hook, t1, t2, fee);
        keys[4] = _key(hook, t1, t3, fee);
        keys[5] = _key(hook, t2, t3, fee);
    }

    function _key(address hook, address a, address b, uint24 fee)
        internal
        pure
        returns (PoolKey memory)
    {
        return PoolKey({
            currency0: Currency.wrap(a),
            currency1: Currency.wrap(b),
            fee: fee,
            tickSpacing: int24(int256(Math.TICK_SPACING)),
            hooks: IHooks(hook)
        });
    }

    function _ensurePairs(
        address hook,
        address t0,
        address t1,
        address t2,
        address t3,
        uint24 fee
    ) internal returns (PoolKey[6] memory keys, uint8 created, uint8 already) {
        keys = _computeKeys(hook, t0, t1, t2, t3, fee);
        uint160 sqrtPrice = TickMath.getSqrtPriceAtTick(0);
        for (uint256 i; i < 6; ++i) {
            PoolId id = keys[i].toId();
            (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(id);
            if (sqrtPriceX96 == 0) {
                poolManager.initialize(keys[i], sqrtPrice);
                ++created;
            } else {
                ++already;
            }
        }
        emit PairPoolsEnsured(hook, created, already);
    }
}

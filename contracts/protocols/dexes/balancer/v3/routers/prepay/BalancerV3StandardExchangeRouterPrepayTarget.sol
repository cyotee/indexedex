// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    InitializeHookParams,
    AddLiquidityHookParams,
    RemoveLiquidityHookParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";
import {
    AddLiquidityKind,
    RemoveLiquidityKind
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {SenderGuard} from "@crane/contracts/external/balancer/v3/vault/contracts/SenderGuard.sol";
import {
    BalancerV3StandardExchangeBatchRouterCommon
} from "contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterCommon.sol";
import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";

contract BalancerV3StandardExchangeRouterPrepayTarget is
    SenderGuard,
    BalancerV3StandardExchangeBatchRouterCommon,
    IBalancerV3StandardExchangeRouterPrepay
{
    function _isPrepaid() internal pure override returns (bool) {
        return true;
    }

    modifier onlyUnlockedOrSEToken() {
        _onlyUnlockedOrSEToken();
        _;
    }

    function _onlyUnlockedOrSEToken() internal view {
        // Desired behavior:
        // - If the Balancer V3 vault is unlocked, no other caller can concurrently use it, so prepay operations are
        //   safe to run (this is the common `vault.unlock(...)` callback context).
        // - If the vault is locked, we only allow the current StandardExchange token (set by the router swap facets)
        //   to call prepay, minimizing risk of arbitrary external callers invoking vault unlock flows.

        if (BalancerV3VaultAwareRepo._balancerV3Vault().isUnlocked()) {
            return;
        }

        IStandardExchangeProxy current = currentStandardExchange();

        // If a StandardExchange swap is in-flight, only the in-flight token may call.
        if (address(current) != address(0)) {
            if (address(msg.sender) != address(current)) {
                revert NotCurrentStandardExchangeToken(address(msg.sender), address(current));
            }
            return;
        }

        // Otherwise (no in-flight token), only allow contract callers.
        // This supports trusted vault→router interactions (e.g., seigniorage flows) while still rejecting EOAs.
        if (msg.sender.code.length == 0) {
            revert NotCurrentStandardExchangeToken(address(msg.sender), address(0));
        }
    }

    function isPrepaid() public pure returns (bool) {
        return true;
    }

    function currentStandardExchange() public view returns (IStandardExchangeProxy) {
        return BalancerV3StandardExchangeRouterRepo._currentStandardExchangeToken();
    }

    function prepayInitialize(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external saveSender(msg.sender) onlyUnlockedOrSEToken returns (uint256 bptAmountOut) {
        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeRouterPrepayHooks.prepayInitializeHook,
                        InitializeHookParams({
                            sender: msg.sender,
                            pool: pool,
                            tokens: tokens,
                            exactAmountsIn: exactAmountsIn,
                            minBptAmountOut: minBptAmountOut,
                            wethIsEth: false,
                            userData: userData
                        })
                    )
                ),
            (uint256)
        );
    }

    function prepayAddLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external saveSender(msg.sender) onlyUnlockedOrSEToken returns (uint256 bptAmountOut) {
        (, bptAmountOut,) = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeRouterPrepayHooks.prepayAddLiquidityHook,
                        AddLiquidityHookParams({
                            sender: msg.sender,
                            pool: pool,
                            maxAmountsIn: exactAmountsIn,
                            minBptAmountOut: minBptAmountOut,
                            kind: AddLiquidityKind.UNBALANCED,
                            wethIsEth: false,
                            userData: userData
                        })
                    )
                ),
            (uint256[], uint256, bytes)
        );
    }

    function prepayRemoveLiquidityProportional(
        address pool,
        uint256 exactBptAmountIn,
        uint256[] memory minAmountsOut,
        // bool wethIsEth,
        bytes memory userData
    ) external saveSender(msg.sender) onlyUnlockedOrSEToken returns (uint256[] memory amountsOut) {
        (, amountsOut,) = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeRouterPrepayHooks.prepayRemoveLiquidityHook,
                        RemoveLiquidityHookParams({
                            sender: msg.sender,
                            pool: pool,
                            minAmountsOut: minAmountsOut,
                            maxBptAmountIn: exactBptAmountIn,
                            kind: RemoveLiquidityKind.PROPORTIONAL,
                            wethIsEth: false,
                            userData: userData
                        })
                    )
                ),
            (uint256, uint256[], bytes)
        );
    }

    function prepayRemoveLiquiditySingleTokenExactIn(
        address pool,
        uint256 exactBptAmountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external saveSender(msg.sender) onlyUnlockedOrSEToken returns (uint256 amountOut) {
        (uint256[] memory minAmountsOut, uint256 tokenIndex) =
            _getSingleInputArrayAndTokenIndex(pool, tokenOut, minAmountOut);

        (, uint256[] memory amountsOut,) = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeRouterPrepayHooks.prepayRemoveLiquidityHook,
                        RemoveLiquidityHookParams({
                            sender: msg.sender,
                            pool: pool,
                            minAmountsOut: minAmountsOut,
                            maxBptAmountIn: exactBptAmountIn,
                            kind: RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN,
                            wethIsEth: false,
                            userData: userData
                        })
                    )
                ),
            (uint256, uint256[], bytes)
        );

        return amountsOut[tokenIndex];
    }
}

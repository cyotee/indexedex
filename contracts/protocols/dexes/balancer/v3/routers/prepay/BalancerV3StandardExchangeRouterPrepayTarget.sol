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

    modifier onlyPrepayAuthorized() {
        BalancerV3StandardExchangeRouterRepo._onlyPrepayAuthorized(msg.sender);
        _;
    }

    function isPrepaid() public pure returns (bool) {
        return true;
    }

    function currentStandardExchange() public view returns (IStandardExchangeProxy) {
        return BalancerV3StandardExchangeRouterRepo._currentStandardExchangeToken();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Prepay session auth API                          */
    /* ---------------------------------------------------------------------- */

    /// @inheritdoc IBalancerV3StandardExchangeRouterPrepay
    function passPrepayAuth(address next) external returns (bool) {
        return BalancerV3StandardExchangeRouterRepo._passPrepayAuth(msg.sender, next);
    }

    /// @inheritdoc IBalancerV3StandardExchangeRouterPrepay
    function restorePrepayAuth() external returns (bool) {
        return BalancerV3StandardExchangeRouterRepo._restorePrepayAuth(msg.sender);
    }

    /// @inheritdoc IBalancerV3StandardExchangeRouterPrepay
    function prepaySessionActive() external view returns (bool) {
        return BalancerV3StandardExchangeRouterRepo._prepaySessionActive();
    }

    /// @inheritdoc IBalancerV3StandardExchangeRouterPrepay
    function prepayAuthTop() external view returns (address) {
        return BalancerV3StandardExchangeRouterRepo._prepayAuthTop();
    }

    /// @inheritdoc IBalancerV3StandardExchangeRouterPrepay
    function prepayAuthDepth() external view returns (uint256) {
        return BalancerV3StandardExchangeRouterRepo._prepayAuthDepth();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Prepay liquidity                            */
    /* ---------------------------------------------------------------------- */

    function prepayInitialize(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        // bool wethIsEth,
        bytes memory userData
    ) external saveSender(msg.sender) onlyPrepayAuthorized returns (uint256 bptAmountOut) {
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
    ) external saveSender(msg.sender) onlyPrepayAuthorized returns (uint256 bptAmountOut) {
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
    ) external saveSender(msg.sender) onlyPrepayAuthorized returns (uint256[] memory amountsOut) {
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
    ) external saveSender(msg.sender) onlyPrepayAuthorized returns (uint256 amountOut) {
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

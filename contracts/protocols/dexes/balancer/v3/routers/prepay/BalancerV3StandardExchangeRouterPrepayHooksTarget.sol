// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    InitializeHookParams,
    AddLiquidityHookParams,
    RemoveLiquidityHookParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/RouterTypes.sol";
import {
    AddLiquidityParams,
    RemoveLiquidityParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
import {
    BalancerV3VaultGuardModifiers
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultGuardModifiers.sol";
import {
    BalancerV3StandardExchangeRouterCommon
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol";

contract BalancerV3StandardExchangeRouterPrepayHooksTarget is
    BalancerV3VaultGuardModifiers,
    BalancerV3StandardExchangeRouterCommon,
    IBalancerV3StandardExchangeRouterPrepayHooks
{
    function prepayInitializeHook(InitializeHookParams calldata params)
        external
        onlyBalancerV3Vault
        returns (uint256 bptAmountOut)
    {
        return _initializeHook(params);
    }

    function _initializeHook(InitializeHookParams calldata params) internal returns (uint256 bptAmountOut) {
        IVault balV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        bptAmountOut = balV3Vault.initialize(
            params.pool, params.sender, params.tokens, params.exactAmountsIn, params.minBptAmountOut, params.userData
        );

        for (uint256 i = 0; i < params.tokens.length; ++i) {
            // _takeTokenIn(params.sender, params.tokens[i], params.exactAmountsIn[i], params.wethIsEth);
            balV3Vault.settle(params.tokens[i], params.exactAmountsIn[i]);
        }
    }

    /**
     * @notice Hook for adding liquidity.
     * @dev Can only be called by the Vault.
     * @param params Add liquidity parameters (see IRouter for struct definition)
     * @return amountsIn Actual amounts in required for the join
     * @return bptAmountOut BPT amount minted in exchange for the input tokens
     * @return returnData Arbitrary data with encoded response from the pool
     */
    function prepayAddLiquidityHook(AddLiquidityHookParams calldata params)
        external
        onlyBalancerV3Vault
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData)
    {
        return _interruptToAddLiquidityHook(params);
    }

    /**
     * @notice Internal logic for adding liquidity hook.
     * @dev This is factored out to allow easier overriding in subclasses.
     */
    function _interruptToAddLiquidityHook(AddLiquidityHookParams calldata params)
        internal
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData)
    {
        IVault vault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        (amountsIn, bptAmountOut, returnData) = vault_.addLiquidity(
            AddLiquidityParams({
                pool: params.pool,
                to: params.sender,
                maxAmountsIn: params.maxAmountsIn,
                minBptAmountOut: params.minBptAmountOut,
                kind: params.kind,
                userData: params.userData
            })
        );

        // maxAmountsIn length is checked against tokens length at the Vault.
        IERC20[] memory tokens = vault_.getPoolTokens(params.pool);

        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amountIn = amountsIn[i];

            if (amountIn == 0) {
                continue;
            }

            // if (_isPrepaid() == false || (params.wethIsEth && address(token) == address(_weth()))) {
            //     _takeTokenIn(params.sender, token, amountIn, params.wethIsEth);
            // } else {
            //     // `amountInHint` represents the amount supposedly paid upfront by the sender.
            //     uint256 amountInHint = params.maxAmountsIn[i];

            //     uint256 tokenInCredit = vault_.settle(token, amountInHint);
            //     if (tokenInCredit < amountInHint) {
            //         revert InsufficientPayment(token);
            //     }

            //     _sendTokenOut(params.sender, token, tokenInCredit - amountIn, false);
            // }
            // `amountInHint` represents the amount supposedly paid upfront by the sender.
            uint256 amountInHint = params.maxAmountsIn[i];

            uint256 tokenInCredit = vault_.settle(token, amountInHint);
            if (tokenInCredit < amountInHint) {
                revert InsufficientPayment(token);
            }
            uint256 refundAmt = tokenInCredit - amountIn;
            if (refundAmt > 0) {
                _sendTokenOut(params.sender, token, refundAmt, false);
            }
        }

        // Send remaining ETH to the user.
        // _returnEth(params.sender);
    }

    /**
     * @notice Hook for removing liquidity.
     * @dev Can only be called by the Vault.
     * @param params Remove liquidity parameters (see IRouter for struct definition)
     * @return bptAmountIn BPT amount burned for the output tokens
     * @return amountsOut Actual token amounts transferred in exchange for the BPT
     * @return returnData Arbitrary (optional) data with an encoded response from the pool
     */
    function prepayRemoveLiquidityHook(RemoveLiquidityHookParams calldata params)
        external
        onlyBalancerV3Vault
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData)
    {
        return _removeLiquidityHook(params);
    }

    function _removeLiquidityHook(RemoveLiquidityHookParams calldata params)
        internal
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData)
    {
        IVault vault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        (bptAmountIn, amountsOut, returnData) = vault_.removeLiquidity(
            RemoveLiquidityParams({
                pool: params.pool,
                from: params.sender,
                maxBptAmountIn: params.maxBptAmountIn,
                minAmountsOut: params.minAmountsOut,
                kind: params.kind,
                userData: params.userData
            })
        );

        // minAmountsOut length is checked against tokens length at the Vault.
        IERC20[] memory tokens = vault_.getPoolTokens(params.pool);

        for (uint256 i = 0; i < tokens.length; ++i) {
            _sendTokenOut(params.sender, tokens[i], amountsOut[i], params.wethIsEth);
        }

        // _returnEth(params.sender);
    }
}

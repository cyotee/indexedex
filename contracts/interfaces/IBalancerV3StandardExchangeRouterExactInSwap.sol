// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                Open Zeppelin                               */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

/* -------------------------------------------------------------------------- */
/*                                  Permit2                                   */
/* -------------------------------------------------------------------------- */

import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";

/**
 * @title IBalancerV3StandardExchangeRouterExactInSwap - Exact in swap operations with optional Standard Exchange Vault intermediation.
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Part of a set of interfaces for a Balancer V3 Custom Router.
 * @notice Consolidates proxy functions by common of executing a swap based on the user providing exact payment amount.
 */
interface IBalancerV3StandardExchangeRouterExactInSwap is BalancerV3StandardExchangeRouterTypes {

    /**
     * @notice Executes a single token exact in swap with optional Standard Exchange Vault intermediation.
     * @param pool The address for the target to process the swap.
     *.       If set to a Balancer V3 pool address, the Router will swap through that pool after optional ETH wrapping
     *.         and/or Standard Exchange Vault 'tokenIn' intermediation,
     *.         and before optional Standard Exchange Vault 'tokenOut' intermediation and/or WETH unwrapping.
     *.       If set to a Standard Exchange Vault, the Router will swap through the Standard Exchange Vault to the underlying protocol.
     *.       If set to WETH9, the Router will wrap or unwrap ETH based on how 'tokenIn', and/or 'tokenOut', and 'wethIsETH' is set.
     *        For a ETH wrap or unwrap this is the WETH address used by Balancer V3.
     * @param tokenIn The address of the token the caller wants to pay in exchange for 'tokenOut'.
     *.       If set to WETH and 'wethIsEth' is set to true, the Router will deposit msg.value into WETH9 before swap or Standard Exchange intermediation.
     * @param tokenInVault The optional address for a Standard Exchange Vault through which the Router should process 'tokenIn'.
     *.       If set to address(0), no intermediation for 'tokenIn'.
     *.       If set to the same address as 'pool' and 'tokenOutVault', Router will swap 'tokenIn' for 'tokenOut' through the Standard Exchange Vault.
     *.       If set to a different address from 'pool', Router will exchange 'tokenIn' for 'tokenInVault' before swapping through 'pool'.
     *.       There is no scenario where 'tokenInVault' would be the same as 'tokenIn'.
     *.       There is no scenario where 'tokenInVault' would be the same as 'tokenOutVault' and NOT also be the same as 'pool'.
     * @param tokenOut The address of the token the caller expects to receive for their payment of 'tokenIn'.
     *.       If set to the same address as 'tokenInVault' the Router will deposit 'tokenIn' into 'tokenInVault' and send the minted vault shares to the user.
     *.       If set to WETH9 and 'wethIsETH' is set to true, the Router will withdraw WETH9 into ETH and send the ETH to the user after swap or Standard Exchange intermediation.
     * @param tokenOutVault The optional address for a Standard Exchange Vault through which the Router should process 'tokenOut'.
     *.       If set to address(0), no intermediation for 'tokenOut'.
     *.       If set to the same address as 'pool' and 'tokenInVault', Router will swap 'tokenIn' for 'tokenOut' through the Standard Exchange Vault.
     *.       If set to a different address from 'pool', Router will exchange 'tokenOut' for 'tokenOutVault' after swapping through 'pool'.
     *.       There is no scenario where 'tokenOutVault' would be the same as 'tokenOut'.
     *.       There is no scenario where 'tokenOutVault' would be the same as 'tokenInVault' and NOT also be the same as 'pool'.
     * @param exactAmountIn The exact amount of 'tokenIn' the caller wants to pay.
     * @param minAmountOut The minimum amount of 'tokenOut' the caller expects to receive.
     * @param deadline The Unix timestamp deadline by which the transaction must be included to effect the change.
     * @param wethIsEth If set to true, the Router will wrap or unwrap ETH based on how 'tokenIn', and/or 'tokenOut', and 'wethIsETH' is set.
     */
    function swapSingleTokenExactIn(
        address pool,
        OZIERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        OZIERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256);

    function swapSingleTokenExactInWithPermit(
        StandardExchangeSwapSingleTokenHookParams memory swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external payable returns (uint256);

    function swapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        external
        returns (uint256);

}

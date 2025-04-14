// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {

    // AddLiquidityKind,
    // AddLiquidityParams,
    // RemoveLiquidityKind,
    // RemoveLiquidityParams,
    SwapKind,
    VaultSwapParams
} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {SafeCast} from "@crane/contracts/utils/SafeCast.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    BalancerV3VaultGuardModifiers
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultGuardModifiers.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {
    BalancerV3StandardExchangeRouterCommon
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol";
import {SenderGuard} from "@crane/contracts/external/balancer/v3/vault/contracts/SenderGuard.sol";

// abstract
contract BalancerV3StandardExchangeRouterExactOutQueryTarget is
    ReentrancyLockModifiers,
    SenderGuard,
    BalancerV3VaultGuardModifiers,
    BalancerV3StandardExchangeRouterTypes,
    BalancerV3StandardExchangeRouterCommon,
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
{
    using BetterAddress for address payable;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IWETH;
    using SafeCast for *;

    /**
     * @notice Query the amount of tokens that would be required for a given exact output amount.
     * @param pool Address of the liquidity pool
     * @param tokenIn Token to be swapped from
     * @param tokenInVault Standard Exchange vault for tokenIn, address(0) if no vault
     * @param tokenOut Token to be swapped to
     * @param tokenOutVault Standard Exchange vault for tokenOut, address(0) if no vault
     * @param exactAmountOut Exact amount of tokenOut to receive
     * @param sender Address of the sender (for access control)
     * @param userData Additional (optional) data sent with the query
     * @return amountIn Amount of tokenIn that would be required
     */
    function querySwapSingleTokenExactOut(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        address sender,
        bytes calldata userData
    ) external returns (uint256 amountIn) {
        IWETH _weth = WETHAwareRepo._weth();
        bool wethIsEth = address(tokenIn) == address(_weth) && address(tokenOut) == address(_weth)
            && pool == address(_weth) && address(tokenInVault) == address(0) && address(tokenOutVault) == address(0);

        // For now, delegate to the Balancer V3 Vault's query functionality
        // This is a simplified implementation - in a full implementation,
        // we would need to handle vault interactions properly
        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .quote(
                    abi.encodeCall(
                        BalancerV3StandardExchangeRouterExactOutQueryTarget.querySwapSingleTokenExactOutHook,
                        StandardExchangeSwapSingleTokenHookParams({
                            sender: sender,
                            kind: SwapKind.EXACT_OUT,
                            pool: pool,
                            tokenIn: IERC20(address(tokenIn)),
                            tokenInVault: tokenInVault,
                            tokenOut: IERC20(address(tokenOut)),
                            tokenOutVault: tokenOutVault,
                            amountGiven: exactAmountOut,
                            // limit: type(uint256).max,
                            // limit: type(uint112).max,
                            limit: _MAX_AMOUNT,
                            deadline: type(uint256).max,
                            wethIsEth: wethIsEth,
                            userData: userData
                        })
                    )
                ),
            (uint256)
        );
    }

    /**
     * @notice Hook called by the Balancer V3 Vault during quote() to simulate exact-out swaps.
     * @dev SECURITY: Must be restricted to Vault-only via onlyBalancerV3Vault.
     * This function calls _balVault.swap() which mutates transient accounting state.
     * Without access control, a direct external call or a reentrancy from a malicious
     * strategy vault callback (during IVault.unlock) could execute uncontrolled deltas
     * in Balancer's transient accounting, leading to DoS or delta manipulation.
     * @param params The swap parameters forwarded from querySwapSingleTokenExactOut.
     * @return amountCalculated The calculated input amount for the simulated swap.
     */
    function querySwapSingleTokenExactOutHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        external
        onlyBalancerV3Vault
        returns (uint256 amountCalculated)
    {
        // Deliberately simplistic implementation to facilitate testing.
        // Includes very restrictive conditionals to clearly define "routes".

        // Load the Balancer V3 Vault once to save gas.
        IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();

        // Special-case: wrap ETH -> WETH "as a swap" quote.
        // When tokenIn == tokenOut == WETH and wethIsEth == true, input is 1:1.
        IWETH _weth = WETHAwareRepo._weth();
        if (params.wethIsEth && params.pool == address(_weth) && params.tokenIn == _weth && params.tokenOut == _weth) {
            return params.amountGiven;
        }

        /* ------------------------------------------------------------------ */
        /*                            Balancer Swap                           */
        /* ------------------------------------------------------------------ */

        if ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) == address(0))) {
            // Query Balancer V3 Vault directly
            uint256 amountIn;
            uint256 amountOut;

            // For query facets, call swap normally to get the quoted amount
            // This is safe because we're in a query context
            (amountCalculated, amountIn, amountOut) = _balVault.swap(
                VaultSwapParams({
                    kind: params.kind,
                    pool: params.pool,
                    tokenIn: params.tokenIn,
                    tokenOut: params.tokenOut,
                    amountGivenRaw: params.amountGiven,
                    limitRaw: params.limit,
                    userData: params.userData
                })
            );

            return amountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                       Vault Pass-Through Swap                      */
        /* ------------------------------------------------------------------ */

        if (
            (address(params.pool) == address(params.tokenInVault))
                && (address(params.pool) == address(params.tokenOutVault))
                && (address(params.tokenIn) != address(params.tokenInVault))
                && (address(params.tokenOut) != address(params.tokenOutVault))
        ) {
            // For pass-through swaps, query the vault's previewExchangeOut function
            // This will give us the expected input amount for the underlying protocol swap
            uint256 estimatedAmountIn = params.tokenInVault
                .previewExchangeOut(
                    IERC20(address(params.tokenIn)), IERC20(address(params.tokenOut)), params.amountGiven
                );
            return estimatedAmountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                       Strategy Vault Deposit                       */
        /* ------------------------------------------------------------------ */

        if (
            (address(params.pool) == address(params.tokenInVault))
                && ((address(params.tokenIn) != address(params.tokenInVault))
                    && (address(params.tokenOut) == address(params.tokenInVault)))
        ) {
            // For query facets, call the vault's previewExchangeOut function
            // This will give us the expected input amount for the deposit
            uint256 estimatedAmountIn = params.tokenInVault
                .previewExchangeOut(
                    IERC20(address(params.tokenIn)), IERC20(address(params.tokenInVault)), params.amountGiven
                );
            return estimatedAmountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                      Strategy Vault Withdrawal                     */
        /* ------------------------------------------------------------------ */

        if (
            (address(params.pool) == address(params.tokenOutVault))
                && ((address(params.tokenIn) == address(params.tokenOutVault))
                    && (address(params.tokenOut) != address(params.tokenOutVault)))
        ) {
            // For query facets, call the vault's previewExchangeOut function
            // This will give us the expected input amount for the withdrawal
            uint256 estimatedAmountIn = params.tokenOutVault
                .previewExchangeOut(
                    IERC20(address(params.tokenOutVault)), IERC20(address(params.tokenOut)), params.amountGiven
                );
            return estimatedAmountIn;
        }

        /* ------------------------------------------------------------------ */
        /*                  Strategy Vault Deposit then Swap                  */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) == address(0)))
        ) {
            // EXACT_OUT limit is maximum amount in.
            // Convert provided limit to equivalent amount of strategy vault.
            uint256 convertedLimit = params.tokenInVault
                .previewExchangeIn(IERC20(address(params.tokenIn)), params.limit, IERC20(address(params.tokenInVault)));

            // Processing a wrap/swap
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // swapParams.tokenIn = IERC20(address(params.tokenIn));
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            // swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            swapParams.tokenOut = IERC20(address(params.tokenOut));
            swapParams.amountGivenRaw = params.amountGiven;
            swapParams.limitRaw = convertedLimit;
            swapParams.userData = params.userData;

            // For query facets, call swap normally to get the quoted amount
            // This is safe because we're in a query context
            (, uint256 swapAmountIn,) = _balVault.swap(swapParams);

            // swapAmoutIn ia amount of Strategy vault to pay in.
            // Convert swapAmountIn to equivalent amount of tokenIn.
            uint256 convertedAmountIn = params.tokenInVault
                .previewExchangeOut(IERC20(address(params.tokenIn)), IERC20(address(params.tokenInVault)), swapAmountIn);

            // Return the amount of tokenIn needed.
            return convertedAmountIn;
        }

        /* ------------------------------------------------------------------ */
        /*   Strategy Vault Deposit and Swap and Strategy Vault Withdrawal    */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            // Processing a wrap/swap/unwrap
            // Convert provided limit to equivalent amount of strategy vault in
            uint256 convertedLimit = params.tokenInVault
                .previewExchangeIn(IERC20(address(params.tokenIn)), params.limit, IERC20(address(params.tokenInVault)));
            // User provided amountGiven is how much they wish to receive AFTER unwrap
            // Calculate how many vault tokens would need to be redeemed to get that amount out
            uint256 convertedAmountOut = params.tokenOutVault
                .previewExchangeOut(
                    IERC20(address(params.tokenOutVault)), IERC20(address(params.tokenOut)), params.amountGiven
                );
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            swapParams.amountGivenRaw = convertedAmountOut;
            swapParams.limitRaw = convertedLimit;
            swapParams.userData = params.userData;

            (, uint256 swapAmountIn,) = _balVault.swap(swapParams);

            // Calculate how much needs to be deposited to get the required swapAmountIn of strategy Vault
            amountCalculated = params.tokenInVault
                .previewExchangeOut(IERC20(address(params.tokenIn)), IERC20(address(params.tokenInVault)), swapAmountIn);
            // Return the amount of tokenIn needed.
            return amountCalculated;
        }

        /* ------------------------------------------------------------------ */
        /*                  Swap and Strategy Vault Withdrawal                */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            // Processing a swap/unwrap
            uint256 convertedAmountOut = params.tokenOutVault
                .previewExchangeOut(
                    IERC20(address(params.tokenOutVault)), IERC20(address(params.tokenOut)), params.amountGiven
                );
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            swapParams.tokenIn = IERC20(address(params.tokenIn));
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            swapParams.amountGivenRaw = convertedAmountOut;
            swapParams.limitRaw = params.limit;
            swapParams.userData = params.userData;

            (, uint256 swapAmountIn,) = _balVault.swap(swapParams);

            // Return the amount of tokenIn needed.
            return swapAmountIn;
        }

        revert InvalidRoute(
            address(params.tokenIn),
            address(params.tokenInVault),
            address(params.tokenOut),
            address(params.tokenOutVault)
        );
    }

    // function _swapHook(StandardExchangeSwapSingleTokenHookParams calldata params)
    //     internal
    //     returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut)
    // {
    //     // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
    //     // solhint-disable-next-line not-rely-on-time
    //     if (block.timestamp > params.deadline) {
    //         revert SwapDeadline();
    //     }

    //     // For query facets, call swap normally to get the quoted amount
    //     // This is safe because we're in a query context
    //     (amountCalculated, amountIn, amountOut) = BalancerV3VaultAwareRepo._balancerV3Vault()
    //         .swap(
    //             VaultSwapParams({
    //                 kind: params.kind,
    //                 pool: params.pool,
    //                 tokenIn: params.tokenIn,
    //                 tokenOut: params.tokenOut,
    //                 amountGivenRaw: params.amountGiven,
    //                 limitRaw: params.limit,
    //                 userData: params.userData
    //             })
    //         );
    // }
}

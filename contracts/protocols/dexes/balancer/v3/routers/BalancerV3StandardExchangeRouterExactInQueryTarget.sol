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
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
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
contract BalancerV3StandardExchangeRouterExactInQueryTarget is
    ReentrancyLockModifiers,
    SenderGuard,
    BalancerV3VaultGuardModifiers,
    BalancerV3StandardExchangeRouterTypes,
    BalancerV3StandardExchangeRouterCommon,
    IBalancerV3StandardExchangeRouterExactInSwapQuery
{
    using BetterAddress for address payable;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IWETH;
    using SafeCast for *;

    /**
     * @notice Query the amount of tokens that would be received for a given exact input amount.
     * @param pool Address of the liquidity pool
     * @param tokenIn Token to be swapped from
     * @param tokenInVault Standard Exchange vault for tokenIn, address(0) if no vault
     * @param tokenOut Token to be swapped to
     * @param tokenOutVault Standard Exchange vault for tokenOut, address(0) if no vault
     * @param exactAmountIn Exact amount of tokenIn to swap
     * @param sender Address of the sender (for access control)
     * @param userData Additional (optional) data sent with the query
     * @return amountOut Amount of tokenOut that would be received
     */
    function querySwapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        address sender,
        bytes calldata userData
    ) external returns (uint256 amountOut) {
        IWETH _weth = WETHAwareRepo._weth();
        bool wethIsEth = address(tokenIn) == address(_weth) && address(tokenOut) == address(_weth)
            && pool == address(_weth) && address(tokenInVault) == address(0) && address(tokenOutVault) == address(0);

        amountOut = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .quote(
                    abi.encodeCall(
                        BalancerV3StandardExchangeRouterExactInQueryTarget.querySwapSingleTokenExactInHook,
                        StandardExchangeSwapSingleTokenHookParams({
                            sender: sender,
                            kind: SwapKind.EXACT_IN,
                            pool: pool,
                            tokenIn: IERC20(address(tokenIn)),
                            tokenInVault: tokenInVault,
                            tokenOut: IERC20(address(tokenOut)),
                            tokenOutVault: tokenOutVault,
                            amountGiven: exactAmountIn,
                            limit: 0,
                            deadline: type(uint256).max,
                            wethIsEth: wethIsEth,
                            userData: userData
                        })
                    )
                ),
            (uint256)
        );

        // console.log("[Query Main] BALANCER_V3_VAULT.quote returned amountOut:", amountOut);
        // console.log("[Query Main] Returning amountOut:", amountOut);

        return amountOut;
    }

    /**
     * @notice Hook called by the Balancer V3 Vault during quote() to simulate exact-in swaps.
     * @dev SECURITY: Must be restricted to Vault-only via onlyBalancerV3Vault.
     * This function calls _balVault.swap() which mutates transient accounting state.
     * Without access control, a direct external call or a reentrancy from a malicious
     * strategy vault callback (during IVault.unlock) could execute uncontrolled deltas
     * in Balancer's transient accounting, leading to DoS or delta manipulation.
     * @param params The swap parameters forwarded from querySwapSingleTokenExactIn.
     * @return amountCalculated The calculated output amount for the simulated swap.
     */
    function querySwapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        external
        onlyBalancerV3Vault
        returns (uint256 amountCalculated)
    {
        // Deliberately simplistic implementation to facilitate testing.
        // Includes very restrictive conditionals to clearly define "routes".

        // Load the Balancer V3 Vault once to save gas.
        IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();

        // Special-case: wrap ETH -> WETH "as a swap" quote.
        // When tokenIn == tokenOut == WETH and wethIsEth == true, output is 1:1.
        IWETH _weth = WETHAwareRepo._weth();
        if (params.wethIsEth && params.pool == address(_weth) && params.tokenIn == _weth && params.tokenOut == _weth) {
            return params.amountGiven;
        }

        /* ------------------------------------------------------------------ */
        /*                            Balancer Swap                           */
        /* ------------------------------------------------------------------ */

        if ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) == address(0))) {
            // console.log("[Query Hook] BRANCH 1: Balancer Swap - Direct pool swap without vault involvement");

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

            return amountOut;
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
            amountCalculated = params.tokenInVault
                .previewExchangeIn(
                    IERC20(address(params.tokenIn)), params.amountGiven, IERC20(address(params.tokenOut))
                );

            return amountCalculated;
        }

        /* ------------------------------------------------------------------ */
        /*                       Strategy Vault Deposit                       */
        /* ------------------------------------------------------------------ */

        if (
            (address(params.pool) == address(params.tokenInVault))
                && ((address(params.tokenIn) != address(params.tokenInVault))
                    && (address(params.tokenOut) == address(params.tokenInVault)))
        ) {
            amountCalculated = params.tokenInVault
                .previewExchangeIn(
                    IERC20(address(params.tokenIn)), params.amountGiven, IERC20(address(params.tokenInVault))
                );

            return amountCalculated;
        }

        /* ------------------------------------------------------------------ */
        /*                      Strategy Vault Withdrawal                     */
        /* ------------------------------------------------------------------ */

        if (
            (address(params.pool) == address(params.tokenOutVault))
                && ((address(params.tokenIn) == address(params.tokenOutVault))
                    && (address(params.tokenOut) != address(params.tokenOutVault)))
        ) {
            amountCalculated = params.tokenOutVault
                .previewExchangeIn(
                    IERC20(address(params.tokenOutVault)), params.amountGiven, IERC20(address(params.tokenOut))
                );

            return amountCalculated;
        }

        /* ------------------------------------------------------------------ */
        /*                  Strategy Vault Deposit + Balancer Swap                  */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) == address(0)))
        ) {
            // Convert base token to vault shares (preview deposit)
            uint256 sharesIn = params.tokenInVault
                .previewExchangeIn(
                    IERC20(address(params.tokenIn)), params.amountGiven, IERC20(address(params.tokenInVault))
                );

            // Swap vault shares to base token out via Balancer pool
            uint256 amountIn;
            uint256 amountOut;
            (amountCalculated, amountIn, amountOut) = _balVault.swap(
                VaultSwapParams({
                    kind: params.kind,
                    pool: params.pool,
                    tokenIn: IERC20(address(params.tokenInVault)),
                    tokenOut: params.tokenOut,
                    amountGivenRaw: sharesIn,
                    limitRaw: params.limit,
                    userData: params.userData
                })
            );
            return amountOut;
        }

        /* ------------------------------------------------------------------ */
        /*   Strategy Vault Deposit and Swap and Strategy Vault Withdrawal    */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            // Convert base token to tokenInVault shares
            uint256 sharesIn = params.tokenInVault
                .previewExchangeIn(
                    IERC20(address(params.tokenIn)), params.amountGiven, IERC20(address(params.tokenInVault))
                );

            // For query flows, params.limit is commonly zero.
            // Avoid calling previewExchangeOut(..., 0) which may revert for some vaults.
            uint256 convertedLimit = params.limit == 0
                ? 0
                : params.tokenOutVault.previewExchangeOut(
                    IERC20(address(params.tokenOutVault)), IERC20(address(params.tokenOut)), params.limit
                );

            // Swap tokenInVault shares -> tokenOutVault shares
            uint256 amountIn;
            uint256 sharesOut;
            (amountCalculated, amountIn, sharesOut) = _balVault.swap(
                VaultSwapParams({
                    kind: params.kind,
                    pool: params.pool,
                    tokenIn: IERC20(address(params.tokenInVault)),
                    tokenOut: IERC20(address(params.tokenOutVault)),
                    amountGivenRaw: sharesIn,
                    limitRaw: convertedLimit,
                    userData: params.userData
                })
            );

            // Convert tokenOutVault shares -> base tokenOut
            uint256 finalAmountOut = params.tokenOutVault
                .previewExchangeIn(IERC20(address(params.tokenOutVault)), sharesOut, IERC20(address(params.tokenOut)));
            return finalAmountOut;
        }

        /* ------------------------------------------------------------------ */
        /*                  Swap and Strategy Vault Withdrawal                */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            // For query flows, params.limit is commonly zero.
            // Avoid calling previewExchangeOut(..., 0) which may revert for some vaults.
            uint256 convertedLimit = params.limit == 0
                ? 0
                : params.tokenOutVault.previewExchangeOut(
                    IERC20(address(params.tokenOutVault)), IERC20(address(params.tokenOut)), params.limit
                );

            // Swap base token → tokenOutVault shares in Balancer
            uint256 amountIn;
            uint256 sharesOut;
            (amountCalculated, amountIn, sharesOut) = _balVault.swap(
                VaultSwapParams({
                    kind: params.kind,
                    pool: params.pool,
                    tokenIn: params.tokenIn,
                    tokenOut: IERC20(address(params.tokenOutVault)),
                    amountGivenRaw: params.amountGiven,
                    limitRaw: convertedLimit,
                    userData: params.userData
                })
            );

            // Convert shares to base token via vault preview
            uint256 finalAmountOut = params.tokenOutVault
                .previewExchangeIn(IERC20(address(params.tokenOutVault)), sharesOut, IERC20(address(params.tokenOut)));
            return finalAmountOut;
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

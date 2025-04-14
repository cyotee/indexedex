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
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

contract BalancerV3StandardExchangeRouterExactOutSwapTarget is
    ReentrancyLockModifiers,
    SenderGuard,
    BalancerV3VaultGuardModifiers,
    BalancerV3StandardExchangeRouterTypes,
    BalancerV3StandardExchangeRouterCommon,
    IBalancerV3StandardExchangeRouterExactOutSwap
{
    using BetterAddress for address payable;
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IWETH;
    using SafeCast for *;

    // string public constant WITNESS_TYPE_STRING =
    //     "Witness witness)"
    //     "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
    //     "TokenPermissions(address token,uint256 amount)";

    // bytes32 public constant WITNESS_TYPEHASH = keccak256(
    //     "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
    // );

    // struct SwapParams {
    //     address pool;
    //     IERC20 tokenIn;
    //     IStandardExchangeProxy tokenInVault;
    //     IERC20 tokenOut;
    //     IStandardExchangeProxy tokenOutVault;
    //     uint256 exactAmountOut;
    //     uint256 maxAmountIn;
    //     uint256 deadline;
    //     bool wethIsEth;
    //     bytes userData;
    // }

    /**
     * @notice Executes a swap operation specifying an exact output token amount.
     * @dev Set pool to the same as tokenInVault to deposit without a swap.
     * @dev Set pool to the same as tokenOutVault to withdraw without a swap.
     * @param pool Address of the liquidity pool, if same as strategy vaults will only wrap/unwrap.
     * @param tokenIn Token to be swapped from
     * @param tokenInVault Standard Exchange vault for the input token, address(0) indicates no vault.
     * @param tokenOut Token to be swapped to
     * @param tokenOutVault Standard Exchange vault for the output token, address(0) indicates no vault.
     * @param exactAmountOut Exact amount of output tokens to receive
     * @param maxAmountIn Maximum amount of input tokens to send
     * @param deadline Deadline for the swap, after which it will revert
     * @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
     * @param userData Additional (optional) data sent with the swap request
     * @return amountIn Calculated amount of input tokens to be sent in exchange for the given output tokens
     */
    function swapSingleTokenExactOut(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountOut,
        uint256 maxAmountIn,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) public payable saveSender(msg.sender) returns (uint256 amountIn) {
        StandardExchangeSwapSingleTokenHookParams memory params;
        params.sender = msg.sender;
        params.kind = SwapKind.EXACT_OUT;
        params.pool = pool;
        params.tokenIn = IERC20(address(tokenIn));
        params.tokenInVault = tokenInVault;
        params.tokenOut = IERC20(address(tokenOut));
        params.tokenOutVault = tokenOutVault;
        params.amountGiven = exactAmountOut;
        params.limit = maxAmountIn;
        params.deadline = deadline;
        params.wethIsEth = wethIsEth;
        params.userData = userData;
        return _callExactOutHook(params);
    }

    function _callExactOutHook(
        StandardExchangeSwapSingleTokenHookParams memory params
    ) internal returns (uint256 amountIn) {
        amountIn = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        // IStandardExchangeRouter.swapSingleTokenHook,
                        IBalancerV3StandardExchangeRouterExactOutSwap.swapSingleTokenExactOutHook,
                        params
                    )
                ),
            (uint256)
        );

        return amountIn;
    }

    /**
     * @notice Executes a swap with Permit2 signature-based token transfer.
     * @dev Allows gasless swaps without pre-approval. User signs a permit that authorizes Permit2 to pull tokens.
     * @param permit Permit2 permit data signed by the user
     * @param signature EIP-712 signature authorizing Permit2 to transfer tokens
     * @return amountIn Calculated amount of input tokens sent
     */
    function swapSingleTokenExactOutWithPermit(
        StandardExchangeSwapSingleTokenHookParams memory swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) public payable saveSender(msg.sender) returns (uint256 amountIn) {
        _permitTransferIn(swapParams, permit, signature);
        _setHasPermitPulledTokenIn(true);
        amountIn = _callExactOutHook(swapParams);
        _setHasPermitPulledTokenIn(false);
        return amountIn;
    }

    function _permitTransferIn(
        StandardExchangeSwapSingleTokenHookParams memory swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) internal {
        bytes32 witness = _witnessFromSwapParams(swapParams);

        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(this),
            requestedAmount: swapParams.limit
        });

        Permit2AwareRepo._permit2().permitWitnessTransferFrom(
            permit,
            transferDetails,
            swapParams.sender,
            witness,
            _WITNESS_TYPE_STRING,
            signature
        );
    }

    function _witnessFromSwapParams(
        StandardExchangeSwapSingleTokenHookParams memory swapParams
    ) internal pure returns (bytes32 witness) {
        return abi.encode(
            _WITNESS_TYPEHASH,
            swapParams.sender,
            swapParams.pool,
            swapParams.tokenIn,
            swapParams.tokenInVault,
            swapParams.tokenOut,
            swapParams.tokenOutVault,
            swapParams.amountGiven,
            swapParams.limit,
            swapParams.deadline,
            swapParams.wethIsEth,
            keccak256(swapParams.userData)
        )._hash();
    }

    function _transferTokenIn(
        address sender,
        address recipient,
        IERC20 tokenIn,
        uint256 amount
    ) internal {
        if (amount == 0) return;

        if (_hasPermitPulledTokenIn()) {
            tokenIn.safeTransfer(recipient, amount);
            return;
        }

        Permit2AwareRepo._permit2().transferFrom(sender, recipient, amount.toUint160(), address(tokenIn));
    }

    function swapSingleTokenExactOutHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        public
        onlyBalancerV3Vault
        returns (uint256 amountCalculated)
    {
        // return swapSingleTokenHook(params);
        if (block.timestamp > params.deadline) {
            revert SwapDeadline();
        }
        emit SwapHookParamsDebug(
            params.sender,
            uint8(params.kind),
            params.pool,
            address(params.tokenIn),
            address(params.tokenOut),
            address(params.tokenInVault),
            address(params.tokenOutVault),
            params.amountGiven,
            params.limit,
            params.wethIsEth
        );
        // Deliberately simplistic implementation to facilitate testing.
        // Includes very restrictive conditionals to clearly define "routes".

        IWETH _weth = WETHAwareRepo._weth();
        /* ------------------------------------------------------------------ */
        /*                            Balancer Swap                           */
        /* ------------------------------------------------------------------ */

        if ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) == address(0))) {
            // Special-case: pure ETH<->WETH wrap/unwrap "as a swap" for exact-out mode.
            // Triggered ONLY when selecting the WETH sentinel pool.
            // For wrap/unwrap, amountIn == amountOut (1:1).
            if (
                params.wethIsEth && params.pool == address(_weth) && address(params.tokenIn) == address(_weth)
                    && address(params.tokenOut) == address(_weth)
            ) {
                uint256 amountToReceive = params.amountGiven;
                uint256 amountToPay = amountToReceive;

                if (amountToPay > params.limit) {
                    revert LimitExceeded(params.limit, amountToPay);
                }

                if (address(this).balance >= amountToPay) {
                    // Wrap ETH -> WETH
                    _weth.deposit{value: amountToPay}();
                    _weth.safeTransfer(params.sender, amountToReceive);
                    _returnEth(params.sender);
                    emit WethSentinelDebug(params.sender, uint8(params.kind), amountToPay, params.limit, true, false);
                    return amountToPay;
                }

                // Unwrap WETH -> ETH
                // In withPermit flows, permitWitnessTransferFrom already transferred tokenIn to this contract.
                if (!_hasPermitPulledTokenIn()) {
                    Permit2AwareRepo._permit2()
                        .transferFrom(params.sender, address(this), amountToPay.toUint160(), address(_weth));
                }
                _weth.withdraw(amountToReceive);
                payable(params.sender).sendValue(amountToReceive);
                emit WethSentinelDebug(params.sender, uint8(params.kind), amountToPay, params.limit, false, true);
                return amountToPay;
            }

            uint256 amountIn;
            uint256 amountOut;
            (amountCalculated, amountIn, amountOut) = _swapHook(params);

            // Transfer tokens to the Balancer vault and settle
            // _takeTokenIn handles both ETH wrapping and Permit2 transfers
            _takeTokenIn(params.sender, params.tokenIn, amountIn, params.wethIsEth);

            bool wethIsEthOut = params.wethIsEth && address(params.tokenOut) == address(_weth)
                && address(params.tokenIn) != address(_weth);
            _sendTokenOut(params.sender, params.tokenOut, amountOut, wethIsEthOut);
            if (address(params.tokenIn) == address(_weth)) {
                // Return the rest of ETH to sender
                _returnEth(params.sender);
            }

            return amountCalculated;
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
            // amountGiven is desired amount out.
            // Calculate the needed amount in to get the desired amount out.
            uint256 estimatedAmountIn = params.tokenInVault
                .previewExchangeOut(
                    IERC20(address(params.tokenIn)), IERC20(address(params.tokenOut)), params.amountGiven
                );
            // if (estimatedAmountIn > params.limit) {
            //     revert LimitExceeded(params.limit, estimatedAmountIn);
            // }
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                _weth.deposit{value: estimatedAmountIn}();
                _weth.safeTransfer(address(params.tokenInVault), estimatedAmountIn);
            } else {
                _transferTokenIn(params.sender, address(params.tokenInVault), params.tokenIn, estimatedAmountIn);
            }
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
                amountCalculated = params.tokenInVault
                    .exchangeOut(
                        IERC20(address(params.tokenIn)),
                        estimatedAmountIn,
                        IERC20(address(params.tokenOut)),
                        params.amountGiven,
                        address(this),
                        true,
                        // uint256 deadline
                        params.deadline
                    );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
                _weth.withdraw(params.amountGiven);
                payable(params.sender).sendValue(params.amountGiven);
            } else {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
                amountCalculated = params.tokenInVault
                    .exchangeOut(
                        IERC20(address(params.tokenIn)),
                        estimatedAmountIn,
                        IERC20(address(params.tokenOut)),
                        params.amountGiven,
                        params.sender,
                        true,
                        // uint256 deadline
                        params.deadline
                    );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
            }
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
            uint256 estimatedAmountIn = params.tokenInVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault)),
                    // uint256 amountOut
                    params.amountGiven
                );
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                _weth.deposit{value: estimatedAmountIn}();
                _weth.safeTransfer(address(params.tokenInVault), estimatedAmountIn);
            } else {
                _transferTokenIn(params.sender, address(params.tokenInVault), params.tokenIn, estimatedAmountIn);
                // console.log("Router: Permit2.transferFrom completed");
            }
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            amountCalculated = params.tokenInVault
                .exchangeOut(
                    IERC20(address(params.tokenIn)),
                    estimatedAmountIn,
                    IERC20(address(params.tokenInVault)),
                    params.amountGiven,
                    params.sender,
                    true,
                    // uint256 deadline
                    params.deadline
                );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));
            if (amountCalculated > params.limit) {
                revert LimitExceeded(params.limit, amountCalculated);
            }
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
            uint256 estimatedAmountIn = params.tokenOutVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenOutVault)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenOut)),
                    // uint256 amountOut
                    params.amountGiven
                );
            _transferTokenIn(params.sender, address(params.tokenOutVault), params.tokenIn, estimatedAmountIn);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = params.tokenOutVault
                    .exchangeOut(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 maxAmountIn,
                        estimatedAmountIn,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 amountOut,
                        params.amountGiven,
                        // address recipient,
                        address(this),
                        // bool pretransferred
                        true,
                        // uint256 deadline
                        params.deadline
                    );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
                if (amountCalculated > params.limit) {
                    revert LimitExceeded(params.limit, amountCalculated);
                }
                _weth.withdraw(params.amountGiven);
                payable(params.sender).sendValue(params.amountGiven);
                return amountCalculated;
            } else {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = params.tokenOutVault
                    .exchangeOut(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 maxAmountIn,
                        params.limit,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 amountOut,
                        params.amountGiven,
                        // address recipient,
                        params.sender,
                        // bool pretransferred
                        true,
                        // uint256 deadline
                        params.deadline
                    );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
                if (amountCalculated > params.limit) {
                    revert LimitExceeded(params.limit, amountCalculated);
                }
                return amountCalculated;
            }
        }

        /* ------------------------------------------------------------------ */
        /*                  Strategy Vault Deposit then Swap                  */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) == address(0)))
        ) {
            IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();
            uint256 convertedLimit = params.tokenInVault
                .previewExchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // uint256 amountIn
                    params.limit,
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault))
                );
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // tokenIn becomes tokenInVault
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            swapParams.tokenOut = IERC20(address(params.tokenOut));
            swapParams.amountGivenRaw = params.amountGiven;
            swapParams.limitRaw = convertedLimit;
            swapParams.userData = params.userData;
            (uint256 swapAmountCalculated, uint256 swapAmountIn, uint256 swapAmountOut) = _balVault.swap(swapParams);
            uint256 userPaymentAmt = params.tokenInVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault)),
                    // uint256 amountOut
                    swapAmountIn
                );
            // Check if ETH is being wrapped to WETH.
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for _weth.
                _weth.deposit{value: userPaymentAmt}();
                // Transfer _weth to tokenInVault.
                _weth.safeTransfer(address(params.tokenInVault), userPaymentAmt);
            } else {
                // If not wrapping ETH to _weth, transfer tokenIn to tokenInVault.
                _transferTokenIn(
                    params.sender,
                    address(params.tokenInVault),
                    params.tokenIn,
                    userPaymentAmt
                );
            }
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            // uint256 actualAmountIn = params.tokenInVault
            //     .exchangeOut(
            //         // IERC20 tokenIn,
            //         IERC20(address(params.tokenIn)),
            //         // uint256 maxAmountIn,
            //         params.limit,
            //         // IERC20 tokenOut,
            //         IERC20(address(params.tokenInVault)),
            //         // uint256 amountOut,
            //         swapAmountIn,
            //         // address recipient,
            //         address(_balVault),
            //         // bool pretransferred
            //         true,
            //         // uint256 deadline
            //         params.deadline
            //     );
            uint256 actualAmountIn = _exchangeOutFromVault(
                // StandardExchangeSwapSingleTokenHookParams calldata params,
                params,
                // uint256 amount,
                swapAmountIn,
                // uint256 limit,
                userPaymentAmt,
                // address recipient
                address(_balVault)
            );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));
            // Revert if actual amountIn exceeds limit.
            if (actualAmountIn > params.limit) {
                revert LimitExceeded(params.limit, actualAmountIn);
            }
            // Settle tokenIn in strategy Vault.
            _balVault.settle(IERC20(address(params.tokenInVault)), actualAmountIn);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                // Send tokenOut to strategy vault for unwrapping.
                _balVault.sendTo(IERC20(address(params.tokenOut)), address(this), swapAmountOut);
                // Unwrap _weth to ETH and send to sender.
                _weth.withdraw(swapAmountOut);
                // Send ETH to user.
                payable(params.sender).sendValue(swapAmountOut);
                return swapAmountCalculated;
            } else {
                _balVault.sendTo(IERC20(address(params.tokenOut)), address(params.sender), swapAmountOut);
                return swapAmountCalculated;
            }
        }

        /* ------------------------------------------------------------------ */
        /*   Strategy Vault Deposit and Swap and Strategy Vault Withdrawal    */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();

            /* --------------------- Amounts conversion --------------------- */

            // Convert provided limit to equivalent amount of strategy vault in.
            uint256 convertedLimit = params.tokenInVault
                .previewExchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // uint256 amountIn
                    params.limit,
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault))
                );
            // Calculate how much tokenOutVault is needed to receive the amountGiven of tokenOut.
            uint256 convertedAmountOut = params.tokenOutVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenOutVault)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenOut)),
                    // uint256 amountOut
                    params.amountGiven
                );

            /* ------------------------ Balancer Swap ----------------------- */

            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // tokenIn becomes tokenInVault
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            // tokenOut becomes tokenOutVault
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            // amountGivenRaw becomes convertedAmountOut.
            swapParams.amountGivenRaw = convertedAmountOut;
            // limitRaw becomes convertedLimit.
            swapParams.limitRaw = convertedLimit;
            swapParams.userData = params.userData;
            (
                // uint256 swapAmountCalculated,
                ,
                uint256 swapAmountIn,
                uint256 swapAmountOut
            ) = _balVault.swap(swapParams);

            /* --------------------- Payment Processing --------------------- */

            // Calculate how much needs to be deposited to get the required swapAmountIn of strategy Vault.
            uint256 userPaymentAmt = params.tokenInVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault)),
                    // uint256 amountOut
                    swapAmountIn
                );
            // Check if ETH is being wrapped to _weth.
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for _weth.
                _weth.deposit{value: userPaymentAmt}();
                // Transfer _weth to tokenInVault.
                _weth.safeTransfer(address(params.tokenInVault), userPaymentAmt);
            } else {
                // If not wrapping ETH to _weth, transfer tokenIn to tokenInVault.
                _transferTokenIn(
                    params.sender,
                    address(params.tokenInVault),
                    params.tokenIn,
                    userPaymentAmt
                );
            }
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            // amountCalculated = params.tokenInVault
            //     .exchangeOut(
            //         // IERC20 tokenIn,
            //         IERC20(address(params.tokenIn)),
            //         // uint256 maxAmountIn,
            //         params.limit,
            //         // IERC20 tokenOut,
            //         IERC20(address(params.tokenInVault)),
            //         // uint256 amountOut,
            //         swapAmountIn,
            //         // address recipient,
            //         address(_balVault),
            //         // bool pretransferred
            //         true,
            //         // uint256 deadline
            //         params.deadline
            //     );
            amountCalculated = _exchangeOutFromVault(
                // StandardExchangeSwapSingleTokenHookParams calldata params,
                params,
                // uint256 amount,
                swapAmountIn,
                // uint256 limit,
                params.limit,
                // address recipient
                address(_balVault)
            );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));
            // Revert if actual amountIn exceeds limit.
            // if (actualAmountIn > params.limit) {
            //     revert LimitExceeded(params.limit, actualAmountIn);
            // }
            // Settle tokenIn in strategy Vault.
            _balVault.settle(IERC20(address(params.tokenInVault)), swapAmountIn);
            /* ------------------------------ ! ----------------------------- */
            _balVault.sendTo(IERC20(address(params.tokenOutVault)), address(this), swapAmountOut);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                // // Send tokenOut to strategy vault for unwrapping.
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // amountCalculated = params.tokenOutVault
                //     .exchangeOut(
                //         // IERC20 tokenIn,
                //         IERC20(address(params.tokenOutVault)),
                //         // uint256 maxAmountIn,
                //         params.limit,
                //         // IERC20 tokenOut,
                //         IERC20(address(params.tokenOut)),
                //         // uint256 amountOut,
                //         params.amountGiven,
                //         // address recipient,
                //         address(this),
                //         // bool pretransferred
                //         true,
                //         // uint256 deadline
                //         params.deadline
                //     );
                amountCalculated = _exchangeOutFromVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    params.amountGiven,
                    // uint256 limit,
                    params.limit,
                    // address recipient
                    address(this)
                );
                // console.log("Router: vault.exchangeOut completed");
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );

                // Revert if actual amountIn exceeds limit.
                // if (amountCalculated > params.limit) {
                //     revert LimitExceeded(params.limit, amountCalculated);
                // }
                // Unwrap _weth to ETH and send to sender.
                _weth.withdraw(params.amountGiven);
                // Send ETH to user.
                payable(params.sender).sendValue(params.amountGiven);
                // return amountCalculated;
            } else {
                // _balVault.sendTo(IERC20(address(params.tokenOut)), address(params.sender), swapAmountOut);

                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // amountCalculated = params.tokenOutVault
                //     .exchangeOut(
                //         // IERC20 tokenIn,
                //         IERC20(address(params.tokenOutVault)),
                //         // uint256 maxAmountIn,
                //         params.limit,
                //         // IERC20 tokenOut,
                //         IERC20(address(params.tokenOut)),
                //         // uint256 amountOut,
                //         params.amountGiven,
                //         // address recipient,
                //         params.sender,
                //         // bool pretransferred
                //         true,
                //         // uint256 deadline
                //         params.deadline
                //     );
                amountCalculated = _exchangeOutFromVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    params.amountGiven,
                    // uint256 limit,
                    params.limit,
                    // address recipient
                    params.sender
                );

                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );

                // Revert if actual amountIn exceeds limit.
                // if (amountCalculated > params.limit) {
                //     revert LimitExceeded(params.limit, amountCalculated);
                // }
                // return amountCalculated;
            }
            // _procStrategyVaultWithdrawal(params, swapAmountOut);
            return amountCalculated;
        }

        /* ------------------------------------------------------------------ */
        /*                 Swap and Strategy Vault Withdrawal                 */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            // return _proceSwapAndStratVaultWithdrawal(params);
            // return _proceExactOutSwapAndStratVaultWithdraw(params);
            IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();
            uint256 convertedAmountOut = params.tokenOutVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenOutVault)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenOut)),
                    // uint256 amountOut
                    params.amountGiven
                );
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // tokenIn becomes tokenInVault
            swapParams.tokenIn = IERC20(address(params.tokenIn));
            // tokenOut becomes tokenOutVault
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            // convertedAmountOut becomes amountGivenRaw.
            swapParams.amountGivenRaw = convertedAmountOut;
            // convertedLimit becomes limitRaw.
            swapParams.limitRaw = params.limit;
            swapParams.userData = params.userData;
            (uint256 swapAmountCalculated, uint256 swapAmountIn, uint256 swapAmountOut) = _balVault.swap(swapParams);
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for _weth.
                _weth.deposit{value: swapAmountIn}();
                // Transfer _weth to tokenInVault.
                _weth.safeTransfer(address(_balVault), swapAmountIn);
            } else {
                _transferTokenIn(
                    params.sender,
                    address(_balVault),
                    params.tokenIn,
                    swapAmountIn
                );
            }
            _balVault.settle(IERC20(address(params.tokenIn)), swapAmountIn);
            _balVault.sendTo(IERC20(address(params.tokenOutVault)), address(this), swapAmountOut);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                // // Send tokenOut to strategy vault for unwrapping.
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // amountCalculated = params.tokenOutVault
                //     .exchangeOut(
                //         // IERC20 tokenIn,
                //         IERC20(address(params.tokenOutVault)),
                //         // uint256 maxAmountIn,
                //         params.limit,
                //         // IERC20 tokenOut,
                //         IERC20(address(params.tokenOut)),
                //         // uint256 amountOut,
                //         params.amountGiven,
                //         // address recipient,
                //         address(this),
                //         // bool pretransferred
                //         true,
                //         // uint256 deadline
                //         params.deadline
                //     );
                amountCalculated = _exchangeOutFromVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    params.amountGiven,
                    // uint256 limit,
                    params.limit,
                    // address recipient
                    address(this)
                );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );

                // Revert if actual amountIn exceeds limit.
                // if (amountCalculated > params.limit) {
                //     revert LimitExceeded(params.limit, amountCalculated);
                // }
                // Unwrap _weth to ETH and send to sender.
                _weth.withdraw(swapAmountOut);
                // Send ETH to user.
                payable(params.sender).sendValue(swapAmountOut);
                return swapAmountCalculated;
            } else {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // amountCalculated = params.tokenOutVault
                //     .exchangeOut(
                //         // IERC20 tokenIn,
                //         IERC20(address(params.tokenIn)),
                //         // uint256 maxAmountIn,
                //         params.limit,
                //         // IERC20 tokenOut,
                //         IERC20(address(params.tokenOut)),
                //         // uint256 amountOut,
                //         params.amountGiven,
                //         // address recipient,
                //         params.sender,
                //         // bool pretransferred
                //         true,
                //         // uint256 deadline
                //         params.deadline
                //     );
                amountCalculated = _exchangeOutFromVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    params.amountGiven,
                    // uint256 limit,
                    params.limit,
                    // address recipient
                    params.sender
                );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );

                // Revert if actual amountIn exceeds limit.
                if (amountCalculated > params.limit) {
                    revert LimitExceeded(params.limit, amountCalculated);
                }
                return swapAmountCalculated;
            }
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
    //     // // console.log("Router: _swapHook - entering function");
    //     // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
    //     // solhint-disable-next-line not-rely-on-time
    //     if (block.timestamp > params.deadline) {
    //         revert SwapDeadline();
    //     }

    //     // // console.log("Router: About to call Balancer V3 Vault.swap");
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

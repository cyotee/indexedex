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
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

contract BalancerV3StandardExchangeRouterExactInSwapTarget is
    ReentrancyLockModifiers,
    SenderGuard,
    BalancerV3VaultGuardModifiers,
    BalancerV3StandardExchangeRouterTypes,
    BalancerV3StandardExchangeRouterCommon,
    IBalancerV3StandardExchangeRouterExactInSwap
{
    using BetterAddress for address payable;
    using BetterEfficientHashLib for bytes;
    using BetterSafeERC20 for IERC20;
    using BetterSafeERC20 for IWETH;
    using SafeCast for *;

    /**
     * @notice Executes a swap operation specifying an exact input token amount.
     * @dev Will call Balancer V3 so this proxy can be called using swapSingleTokenExactInHook.
     * @dev Set pool to the same as tokenInVault to deposit without a swap.
     * @dev Set pool to the same as tokenOutVault to withdraw without a swap.
     * @param pool Address of the liquidity pool
     * @param tokenIn Token to be swapped from
     * @param tokenInVault Standard Exchange vault for which to deposit the input token, address(0) indicates no vault.
     * @param tokenOut Token to be swapped to
     * @param tokenOutVault Standard Exchange vault from which to withdraw the output token, address(0) indicates no vault.
     * @param exactAmountIn Exact amounts of input tokens to send
     * @param minAmountOut Minimum amount of tokens to be received
     * @param deadline Deadline for the swap, after which it will revert
     * @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
     * @param userData Additional (optional) data sent with the swap request
     * @return amountOut Calculated amount of output tokens to be received in exchange for the given input tokens
     */
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) public payable saveSender(msg.sender) returns (uint256 amountOut) {
        // Need to assign variables discretely to avoid stack too deep error.
        StandardExchangeSwapSingleTokenHookParams memory params;
        params.sender = msg.sender;
        params.kind = SwapKind.EXACT_IN;
        params.pool = pool;
        params.tokenIn = IERC20(address(tokenIn));
        params.tokenInVault = tokenInVault;
        params.tokenOut = IERC20(address(tokenOut));
        params.tokenOutVault = tokenOutVault;
        params.amountGiven = exactAmountIn;
        params.limit = minAmountOut;
        params.deadline = deadline;
        params.wethIsEth = wethIsEth;
        params.userData = userData;

        return _callExactInHook(params);
    }

    function _callExactInHook(
        StandardExchangeSwapSingleTokenHookParams memory params
    ) internal returns (uint256 amountOut) {
        // Call Vault callback to unlock for swap.
        amountOut = abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        // IStandardExchangeRouter.swapSingleTokenHook,
                        IBalancerV3StandardExchangeRouterExactInSwap.swapSingleTokenExactInHook,
                        params
                    )
                ),
            (uint256)
        );

        if (address(params.tokenIn) == address(WETHAwareRepo._weth())) {
            // console.log("Router: About to call _returnEth for WETH remainder");
            // Return the rest of ETH to sender
            _returnEth(params.sender);
            // console.log("Router: _returnEth completed");
        }
        return amountOut;
    }

    /**
     * @notice Executes a swap with Permit2 signature-based token transfer.
     * @dev Allows gasless swaps without pre-approval. User signs a permit that authorizes Permit2 to pull tokens.
     * @param permit Permit2 permit data signed by the user
     * @param signature EIP-712 signature authorizing Permit2 to transfer tokens
     * @return amountOut Calculated amount of output tokens to be received
     */
    function swapSingleTokenExactInWithPermit(
        StandardExchangeSwapSingleTokenHookParams memory swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) public payable saveSender(msg.sender) returns (uint256 amountOut) {
        _permitTransferIn(swapParams, permit, signature);
        _setHasPermitPulledTokenIn(true);
        amountOut = _callExactInHook(swapParams);
        _setHasPermitPulledTokenIn(false);
        return amountOut;
    }

    function _permitTransferIn(
        StandardExchangeSwapSingleTokenHookParams memory swapParams,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) internal {
        bytes32 witness = _witnessFromSwapParams(swapParams);

        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(this),
            requestedAmount: swapParams.amountGiven
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

    /**
     * @notice Hook for swaps.
     * @dev Can only be called by the Vault. Also handles native ETH.
     * @param params Swap parameters (see IRouter for struct definition)
     * @return amountCalculated Token amount calculated by the pool math (e.g., amountOut for an exact in swap)
     */
    function swapSingleTokenExactInHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        public
        lock
        onlyBalancerV3Vault
        returns (uint256 amountCalculated)
    {
        return _swapSingleTokenHook(params);
    }

    function _swapSingleTokenHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        internal
        returns (uint256 amountCalculated)
    {
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

        // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > params.deadline) {
            revert SwapDeadline();
        }

        IWETH _weth = WETHAwareRepo._weth();
        /* ------------------------------------------------------------------ */
        /*                            Balancer Swap                           */
        /* ------------------------------------------------------------------ */

        if ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) == address(0))) {
            // Special-case: pure ETH<->WETH wrap/unwrap "as a swap".
            // This is ONLY triggered when the caller selects the WETH sentinel pool.
            //
            // - Wrap:  sender pays native ETH (held on this contract) and receives WETH.
            // - Unwrap: sender pays WETH and receives native ETH.
            //
            // The frontend models ETH as WETH + `wethIsEth=true`, so tokenIn==tokenOut==WETH.
            if (
                params.wethIsEth && params.pool == address(_weth) && address(params.tokenIn) == address(_weth)
                    && address(params.tokenOut) == address(_weth)
            ) {
                uint256 amount = params.amountGiven;

                // Respect slippage/minAmountOut semantics: for wrap/unwrap, output is 1:1.
                if (params.limit > amount) {
                    revert MinAmountOutNotMet(params.limit, amount);
                }

                if (address(this).balance >= amount) {
                    // Wrap ETH -> WETH
                    _weth.deposit{value: amount}();
                    _weth.safeTransfer(params.sender, amount);
                    emit WethSentinelDebug(params.sender, uint8(params.kind), amount, params.limit, true, false);
                    return amount;
                }

                // Unwrap WETH -> ETH
                // In withPermit flows, permitWitnessTransferFrom already transferred tokenIn to this contract.
                if (!_hasPermitPulledTokenIn()) {
                    Permit2AwareRepo._permit2()
                        .transferFrom(params.sender, address(this), amount.toUint160(), address(_weth));
                }
                _weth.withdraw(amount);
                payable(params.sender).sendValue(amount);
                emit WethSentinelDebug(params.sender, uint8(params.kind), amount, params.limit, false, true);
                return amount;
            }

            uint256 amountIn;
            uint256 amountOut;
            (amountCalculated, amountIn, amountOut) = _swapHook(params);

            // Transfer tokens to the Balancer vault and settle
            // _takeTokenIn handles both ETH wrapping and Permit2 transfers
            _takeTokenIn(params.sender, params.tokenIn, amountIn, params.wethIsEth);

            // If the caller is using ETH on the input side (tokenIn == WETH with wethIsEth=true),
            // do NOT force-unwap WETH on the output side unless the output side is explicitly ETH.
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
            // For pass-through swaps, the vault acts as the pool
            // We need to transfer tokens to the vault and let it handle the underlying protocol swap

            // Handle ETH/WETH wrapping if needed
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for WETH
                _weth.deposit{value: params.amountGiven}();
                // Transfer WETH to vault
                _weth.safeTransfer(address(params.tokenInVault), params.amountGiven);
            } else {
                // Transfer tokenIn to vault (supports withPermit pre-pulled tokenIn)
                _transferTokenIn(params.sender, address(params.tokenInVault), params.tokenIn, params.amountGiven);
            }

            // For pass-through swaps, we call the vault's exchangeIn function
            // This will perform the swap through the vault's underlying protocol (e.g., Uniswap V2)
            // The vault will handle the actual swap and return the swapped tokens
            // If user wants unwrapping, recipient is address(this) so we can unwrap WETH to ETH
            address recipient = params.sender;
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                recipient = address(this);
            }
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            amountCalculated = params.tokenInVault
                .exchangeIn(
                    IERC20(address(params.tokenIn)),
                    params.amountGiven,
                    IERC20(address(params.tokenOut)),
                    params.limit,
                    recipient,
                    true,
                    // uint256 deadline
                    params.deadline
                );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));

            // Check if token out is WETH and needs to be unwrapped to ETH.
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                _weth.withdraw(amountCalculated);
                payable(params.sender).sendValue(amountCalculated);
            }

            /* -------------------------------------------------------------------------- */
            /*                                      !                                     */
            /* -------------------------------------------------------------------------- */

            // Verify minimum amount out
            if (amountCalculated < params.limit) {
                revert MinAmountOutNotMet(params.limit, amountCalculated);
            }

            // console.log("Router: _procVaultPassThroughSwap - exiting function");
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
            // IVault _balVault = _balV3Vault();
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for WETH.
                _weth.deposit{value: params.amountGiven}();
                // Transfer WETH to tokenInVault.
                _weth.safeTransfer(address(params.tokenInVault), params.amountGiven);
                // console.log("Router: WETH.safeTransfer completed");
            } else {
                // If not wrapping ETH to WETH, transfer tokenIn to tokenInVault.
                _transferTokenIn(params.sender, address(params.tokenInVault), params.tokenIn, params.amountGiven);
            }

            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            // console.log("Router: About to call vault.exchangeIn for deposit");
            amountCalculated = params.tokenInVault
                .exchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // uint256 amountIn,
                    params.amountGiven,
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenOut)),
                    // uint256 minAmountOut,
                    params.limit,
                    // address recipient,
                    params.sender,
                    // bool pretransferred
                    true,
                    // uint256 deadline
                    params.deadline
                );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));

            // Revert if vault shares out does not meet limit.
            if (amountCalculated < params.limit) {
                revert MinAmountOutNotMet(params.limit, amountCalculated);
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
            _transferTokenIn(params.sender, address(params.tokenOutVault), params.tokenIn, params.amountGiven);

            // Check if token out is WETH and needs to be unwrapped to ETH.
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                // For EXACT_IN, use exchangeIn because amountGiven is for amount in.
                // For EXACT_IN, limit is minAmountOut.
                // Set self as recipient so WETH can be unwrapped.
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = params.tokenOutVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 amountIn,
                        params.amountGiven,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 minAmountOut,
                        params.limit,
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

                // Revert if withdrawn amount does not meet limit.
                if (amountCalculated < params.limit) {
                    revert MinAmountOutNotMet(params.limit, amountCalculated);
                }
                _weth.withdraw(amountCalculated);

                // Send ETH to user.
                payable(params.sender).sendValue(amountCalculated);

                // Return the withdrawn amount of token.
                return amountCalculated;
            } else {
                // For EXACT_IN, use exchangeIn because amountGiven is for amount in.
                // For EXACT_IN, limit is minAmountOut.
                // Set sender as recipient.
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = params.tokenOutVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 amountIn,
                        params.amountGiven,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 minAmountOut,
                        params.limit,
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

                // Revert if withdrawn amount does not meet limit.
                if (amountCalculated < params.limit) {
                    revert MinAmountOutNotMet(params.limit, amountCalculated);
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
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for WETH.
                _weth.deposit{value: params.amountGiven}();
                // Transfer WETH to tokenInVault.
                _weth.safeTransfer(address(params.tokenInVault), params.amountGiven);
            } else {
                // If not wrapping ETH to WETH, transfer tokenIn to tokenInVault.
                _transferTokenIn(
                    params.sender,
                    address(params.tokenInVault),
                    params.tokenIn,
                    params.amountGiven
                );
            }
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenInVault);
            uint256 actualVaultShares = params.tokenInVault
                .exchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // uint256 amountIn,
                    params.amountGiven,
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault)),
                    // uint256 minAmountOut,
                    // FIXME adjust to accurate limit
                    0,
                    // address recipient,
                    address(_balVault),
                    // bool pretransferred
                    true,
                    // uint256 deadline
                    params.deadline
                );
            BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));
            /* -------------------------------- ! ------------------------------- */
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // tokenIn becomes tokenInVault
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            // tokenOut becomes tokenOutVault
            swapParams.tokenOut = IERC20(address(params.tokenOut));
            // convertedAmountIn becomes amountGivenRaw.
            swapParams.amountGivenRaw = actualVaultShares;
            // convertedLimit becomes limitRaw.
            swapParams.limitRaw = params.limit;
            swapParams.userData = params.userData;
            // console.log("Router: About to call Balancer V3 Vault.swap");
            (
                uint256 swapAmountCalculated,, // uint256 swapAmountIn,
                // ,
                uint256 swapAmountOut
            ) = _balVault.swap(swapParams);
            _balVault.settle(IERC20(address(params.tokenInVault)), actualVaultShares);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                _balVault.sendTo(IERC20(address(params.tokenOut)), address(this), swapAmountOut);
                _weth.withdraw(swapAmountOut);
                payable(params.sender).sendValue(swapAmountOut);
                return swapAmountCalculated;
            } else {
                _balVault.sendTo(IERC20(address(params.tokenOut)), address(params.sender), swapAmountOut);
                return swapAmountCalculated;
            }
        }

        /* -------------------------------------------------------------------------- */
        /*        Strategy Vault Deposit and Swap and Strategy Vault Withdrawal       */
        /* -------------------------------------------------------------------------- */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) != address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();
            // Processing a wrap/swap/unwrapp of a provided amountIn.
            // Vault swap must be defined as tokenInVault -> tokenOutVault.
            // amountGiven is denominated as tokenIn.
            // Calculate equivalent tokenInVault amount for amountGiven of tokenIn.
            uint256 convertedAmountIn = params.tokenInVault
                .previewExchangeIn(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenIn)),
                    // uint256 amountIn
                    params.amountGiven,
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenInVault))
                );
            // Provided limit is minimum amout out.
            // This is denominated in tokenOut.
            // Calculate the equivalent tokenOutVault amount for the provided limit.
            uint256 convertedLimit = params.tokenOutVault
                .previewExchangeOut(
                    // IERC20 tokenIn,
                    IERC20(address(params.tokenOutVault)),
                    // IERC20 tokenOut,
                    IERC20(address(params.tokenOut)),
                    // uint256 amountOut
                    params.limit
                );
            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            // tokenIn becomes tokenInVault
            swapParams.tokenIn = IERC20(address(params.tokenInVault));
            // tokenOut becomes tokenOutVault
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            // convertedAmountIn becomes amountGivenRaw.
            swapParams.amountGivenRaw = convertedAmountIn;
            // convertedLimit becomes limitRaw.
            swapParams.limitRaw = convertedLimit;
            swapParams.userData = params.userData;
            // Call swap for pool, setting amountGiven to required amount of strategy vault tokens.
            // Set tokenIn to tokenInVault to reflect wrapping.
            // Set tokenOut to tokenOutVault to reflect unwrapping.
            // swapAmountIn is amount of tokenInVault owed to Balancer V3 Vault.
            // swapAmountOut is amount of tokenOutVault owed by Balancer V3 Vault.
            // swapAmountCalculated is amount of tokenOutVault owed by Balancer V3 Vault.
            (
                // uint256 swapAmountCalculated,
                ,
                uint256 swapAmountIn,
                uint256 swapAmountOut
            ) = _balVault.swap(swapParams);
            // Process wrapping of tokenIn to tokenInVault and deposit in Balancer V3 Vault.
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for WETH.
                _weth.deposit{value: params.amountGiven}();
                // Transfer WETH to tokenInVault.
                _weth.safeTransfer(address(params.tokenInVault), params.amountGiven);
            } else {
                // If not wrapping ETH to WETH, transfer tokenIn to tokenInVault.
                _transferTokenIn(
                    params.sender,
                    address(params.tokenInVault),
                    params.tokenIn,
                    params.amountGiven
                );
            }
            _exchangeOutFromVault(
                // StandardExchangeSwapSingleTokenHookParams calldata params,
                params,
                // uint256 amount,
                swapAmountIn,
                // uint256 limit,
                params.amountGiven,
                // address recipient
                address(_balVault)
            );
            _balVault.settle(IERC20(address(params.tokenInVault)), swapAmountIn);
            _balVault.sendTo(IERC20(address(params.tokenOutVault)), address(params.tokenOutVault), swapAmountOut);

            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = _exchangeInToVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    swapAmountOut,
                    // uint256 minAmountOut,
                    swapAmountOut,
                    // address recipient
                    address(this)
                );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
                // Unwrap WETH to ETH and send to sender.
                _weth.withdraw(amountCalculated);
                // Send ETH to user.
                payable(params.sender).sendValue(amountCalculated);
                return amountCalculated;
            } else {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // Unwrap tokenOut from pool, sending tokenOut to user.
                // FIX: Pass params.limit (user's minAmountOut in tokenOut) instead of convertedLimit
                // The vault's exchangeIn will check if the final tokenOut >= minAmountOut
                amountCalculated = _exchangeInToVault(
                    // StandardExchangeSwapSingleTokenHookParams calldata params,
                    params,
                    // uint256 amount,
                    swapAmountOut,
                    // uint256 minAmountOut,
                    params.limit,
                    // address recipient
                    params.sender
                );
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                    IStandardExchangeProxy(address(0))
                );
                return amountCalculated;
            }
        }

        /* ------------------------------------------------------------------ */
        /*                 Swap and Strategy Vault Withdrawal                 */
        /* ------------------------------------------------------------------ */

        if (
            ((address(params.pool) != address(params.tokenInVault))
                    && (address(params.pool) != address(params.tokenOutVault)))
                && ((address(params.tokenInVault) == address(0)) && (address(params.tokenOutVault) != address(0)))
        ) {
            IVault _balVault = BalancerV3VaultAwareRepo._balancerV3Vault();

            VaultSwapParams memory swapParams;
            swapParams.kind = params.kind;
            swapParams.pool = params.pool;
            swapParams.tokenIn = IERC20(address(params.tokenIn));
            // tokenOut becomes tokenOutVault
            swapParams.tokenOut = IERC20(address(params.tokenOutVault));
            swapParams.amountGivenRaw = params.amountGiven;
            // For exact-in swap+withdraw routes, enforce slippage on final tokenOut only.
            // Applying an intermediate converted limit here can prematurely revert with SwapLimit
            // when preview conversion drifts from realized execution.
            swapParams.limitRaw = 0;
            swapParams.userData = params.userData;
            (
                // uint256 swapAmountCalculated,
                ,
                uint256 swapAmountIn,
                uint256 swapAmountOut
            ) = _balVault.swap(swapParams);
            if (params.wethIsEth && address(params.tokenIn) == address(_weth)) {
                // Deposit ETH for WETH.
                _weth.deposit{value: swapAmountIn}();
                // Transfer WETH to tokenInVault.
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
            // Send tokenOut to strategy vault for unwrapping.
            _balVault.sendTo(IERC20(address(params.tokenOutVault)), address(params.tokenOutVault), swapAmountOut);
            // _balVault.settle(IERC20(address(params.tokenOutVault)), 0);
            if (params.wethIsEth && address(params.tokenOut) == address(_weth)) {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                amountCalculated = params.tokenOutVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 amountIn,
                        swapAmountOut,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 minAmountOut,
                        params.limit,
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
                // Unwrap WETH to ETH and send to sender.
                _weth.withdraw(amountCalculated);
                // Send ETH to user.
                payable(params.sender).sendValue(amountCalculated);
                return amountCalculated;
            } else {
                BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(params.tokenOutVault);
                // Unwrap tokenOut from pool, sending tokenOut to user.
                // FIX: Pass params.limit (user's minAmountOut in tokenOut) instead of convertedLimit
                amountCalculated = params.tokenOutVault
                    .exchangeIn(
                        // IERC20 tokenIn,
                        IERC20(address(params.tokenOutVault)),
                        // uint256 amountIn,
                        swapAmountOut,
                        // IERC20 tokenOut,
                        IERC20(address(params.tokenOut)),
                        // uint256 minAmountOut,
                        params.limit,
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
                return amountCalculated;
            }
        }

        revert InvalidRoute(
            address(params.tokenIn),
            address(params.tokenInVault),
            address(params.tokenOut),
            address(params.tokenOutVault)
        );
    }

    // function _exchangeInToVault(
    //     // StandardExchangeSwapSingleTokenHookParams calldata params,
    //     StandardExchangeSwapSingleTokenHookParams calldata params,
    //     // uint256 amount,
    //     uint256 amount,
    //     // uint256 limit,
    //     uint256 limit,
    //     // address recipient
    //     address recipient
    // ) internal returns (uint256 amountOut) {
    //     return params.tokenInVault
    //         .exchangeOut(
    //             // IERC20 tokenIn,
    //             IERC20(address(params.tokenIn)),
    //             // uint256 maxAmountIn,
    //             params.amountGiven,
    //             // IERC20 tokenOut,
    //             IERC20(address(params.tokenInVault)),
    //             // uint256 amountOut,
    //             swapAmountIn,
    //             // address recipient,
    //             address(_balVault),
    //             // bool pretransferred
    //             true,
    //             // uint256 deadline
    //             params.deadline
    //         );
    // }

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

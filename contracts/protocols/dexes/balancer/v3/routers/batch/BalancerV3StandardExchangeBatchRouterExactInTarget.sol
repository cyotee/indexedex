// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    AddLiquidityKind,
    AddLiquidityParams,
    BufferWrapOrUnwrapParams,
    RemoveLiquidityKind,
    RemoveLiquidityParams,
    SwapKind,
    WrappingDirection,
    VaultSwapParams
} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC4626} from '@crane/contracts/interfaces/IERC4626.sol';
import {ISignatureTransfer} from '@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol';
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol';
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
import {
    EVMCallModeHelpers
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/EVMCallModeHelpers.sol';
import {Permit2AwareRepo} from '@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol';
import {
    BalancerV3VaultAwareRepo
} from '@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol';
import {
    BalancerV3StandardExchangeRouterRepo
} from 'contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol';
import {
    TransientEnumerableSet
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/openzeppelin/TransientEnumerableSet.sol';
import {
    TransientStorageHelpers,
    AddressToUintMappingSlot
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/TransientStorageHelpers.sol';
import {SafeCast} from '@crane/contracts/utils/SafeCast.sol';
import {
    BalancerV3StandardExchangeBatchRouterCommon
} from 'contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterCommon.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {
    BalancerV3VaultGuardModifiers
} from '@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultGuardModifiers.sol';
import {SenderGuard} from '@crane/contracts/external/balancer/v3/vault/contracts/SenderGuard.sol';

contract BalancerV3StandardExchangeBatchRouterExactInTarget is
    BalancerV3StandardExchangeBatchRouterCommon,
    ReentrancyLockModifiers,
    BalancerV3VaultGuardModifiers,
    SenderGuard,
    IBalancerV3StandardExchangeBatchRouterExactIn
{
    using SafeCast for *;
    using TransientEnumerableSet for TransientEnumerableSet.AddressSet;
    using TransientStorageHelpers for *;

    /* -------------------------------------------------------------------------- */
    /*                                    Swaps                                   */
    /* -------------------------------------------------------------------------- */

    function swapExactIn(
        SESwapPathExactAmountIn[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        public
        payable
        saveSender(msg.sender)
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        return _swapExactIn(msg.sender, paths, deadline, wethIsEth, userData);
    }

    function _swapExactIn(
        address sender,
        SESwapPathExactAmountIn[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) internal returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut) {
        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeBatchRouterExactIn.swapExactInHook,
                        SESwapExactInHookParams({
                            sender: sender,
                            paths: paths,
                            deadline: deadline,
                            wethIsEth: wethIsEth,
                            userData: userData
                        })
                    )
                ),
            (uint256[], address[], uint256[])
        );
    }

    function swapExactInWithPermit(
        SESwapPathExactAmountIn[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    )
        external
        payable
        saveSender(msg.sender)
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        // Validate array lengths
        if (permits.length != paths.length || signatures.length != paths.length) {
            revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathLengthMismatch(
                paths.length, permits.length, signatures.length
            );
        }

        // Pull tokens via Permit2, then keep batch mode active across settlement.
        _executeBatchPermitIn(paths, permits, signatures);
        _setBatchPermitMode(true);

        (pathAmountsOut, tokensOut, amountsOut) = _swapExactIn(msg.sender, paths, deadline, wethIsEth, userData);
        _setBatchPermitMode(false);
    }

    function _executeBatchPermitIn(
        SESwapPathExactAmountIn[] memory paths,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    ) internal {
        ISignatureTransfer p = ISignatureTransfer(address(Permit2AwareRepo._permit2()));
        for (uint256 i = 0; i < paths.length; ++i) {
            if (permits[i].permitted.token != address(paths[i].tokenIn)) {
                revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathTokenMismatch(
                    i, address(paths[i].tokenIn), permits[i].permitted.token
                );
            }
            if (permits[i].permitted.amount < paths[i].exactAmountIn) {
                revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathAmountInsufficient(
                    i, paths[i].exactAmountIn, permits[i].permitted.amount
                );
            }
            ISignatureTransfer.SignatureTransferDetails memory td = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: paths[i].exactAmountIn
            });
            p.permitTransferFrom(permits[i], td, msg.sender, signatures[i]);
        }
    }

    function swapExactInHook(SESwapExactInHookParams calldata params)
        external
        lock
        onlyBalancerV3Vault
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        (pathAmountsOut, tokensOut, amountsOut) = _swapExactInHook(params);

        _settlePaths(params.sender, params.wethIsEth);
    }

    function _swapExactInHook(SESwapExactInHookParams calldata params)
        internal
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > params.deadline) {
            revert SwapDeadline();
        }

        pathAmountsOut = _computePathAmountsOut(params);

        // The hook writes current swap token and token amounts out.
        // We copy that information to memory to return it before it is deleted during settlement.
        tokensOut = _currentSwapTokensOut().values();
        amountsOut = new uint256[](tokensOut.length);
        for (uint256 i = 0; i < tokensOut.length; ++i) {
            amountsOut[i] = _currentSwapTokenOutAmounts().tGet(tokensOut[i]) + _settledTokenAmounts().tGet(tokensOut[i]);
            _settledTokenAmounts().tSet(tokensOut[i], 0);
        }
    }

    function _computePathAmountsOut(SESwapExactInHookParams calldata params)
        internal
        returns (uint256[] memory pathAmountsOut)
    {
        pathAmountsOut = new uint256[](params.paths.length);

        // Pre-collect all prepaid token-in amounts up front.
        // This avoids order-dependent interactions with `vault.settle(token, hint)`, whose hint-based crediting can
        // otherwise absorb unrelated balance increases for the same token.
        for (uint256 i = 0; i < params.paths.length; ++i) {
            SESwapPathExactAmountIn memory path = params.paths[i];
            uint256 amountIn = path.exactAmountIn;

            if (path.steps[0].isBuffer) {
                _takeTokenIn(params.sender, path.tokenIn, amountIn, params.wethIsEth);
            } else if (!path.steps[0].isStrategyVault) {
                _currentSwapTokensIn().add(address(path.tokenIn));
                _currentSwapTokenInAmounts().tAdd(address(path.tokenIn), amountIn);
            }
        }

        for (uint256 i = 0; i < params.paths.length; ++i) {
            SESwapPathExactAmountIn memory path = params.paths[i];

            // These two variables shall be updated at the end of each step to be used as inputs of the next one.
            // The initial values are the given token and amount in for the current path.
            // uint256 stepExactAmountIn = path.exactAmountIn;
            // IERC20 stepTokenIn = path.tokenIn;
            SESwapStepLocals memory stepLocals;
            // stepLocals.stepTokenIn = path.tokenIn;
            stepLocals.stepAmountIn = path.exactAmountIn;

            for (uint256 j = 0; j < path.steps.length; ++j) {
                // SwapStepLocals memory stepLocals;
                stepLocals.isLastStep = (j == path.steps.length - 1);
                stepLocals.isFirstStep = (j == 0);
                uint256 minAmountOut = stepLocals.isLastStep ? path.minAmountOut : 0;
                SESwapPathStep memory step = path.steps[j];

                if (step.isStrategyVault) {
                    uint256 amountOut;

                    // Always execute the real Standard Exchange operation (including token movements) so that
                    // Standard Exchange Vault callbacks run during `vault.quote(...)`.
                    if (stepLocals.isFirstStep) {
                        if (params.sender == address(this)) {
                            // Query mode: no external token pull. Provide input tokens from the Balancer Vault.
                            BalancerV3VaultAwareRepo._balancerV3Vault()
                                .sendTo(IERC20(path.tokenIn), address(step.pool), stepLocals.stepAmountIn);
                            BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(path.tokenIn), 0);
                        } else {
                            // Execution mode: pull tokens from the user into the Strategy Vault.
                            _transferToRecipient(
                                params.sender,
                                address(step.pool),
                                path.tokenIn,
                                stepLocals.stepAmountIn,
                                params.wethIsEth
                            );
                        }
                    } else {
                        // Balancer Vault → vault → Balancer Vault (middle step)
                        BalancerV3VaultAwareRepo._balancerV3Vault()
                            .sendTo(IERC20(path.tokenIn), address(step.pool), stepLocals.stepAmountIn);
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(path.tokenIn), 0);
                    }

                    BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                        IStandardExchangeProxy(address(step.pool))
                    );
                    amountOut = _exchangeInToVault(
                        params,
                        stepLocals,
                        step,
                        path,
                        minAmountOut,
                        address(BalancerV3VaultAwareRepo._balancerV3Vault())
                    );

                    BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                        IStandardExchangeProxy(address(0))
                    );

                    // The Strategy Vault output increases the Vault's balance for `step.tokenOut`.
                    // Settle immediately so the credit is available for subsequent steps / final sendTo.
                    // If the same token is also used as a prepaid input token (possibly by other paths), include that
                    // pending amount in the settle hint to avoid it being absorbed into reserves.
                    uint256 settleHint = amountOut;
                    uint256 pendingPrepaid = _currentSwapTokenInAmounts().tGet(address(step.tokenOut));
                    if (pendingPrepaid > 0) {
                        settleHint += pendingPrepaid;
                        _currentSwapTokenInAmounts().tSet(address(step.tokenOut), 0);
                        // `_settlePaths` iterates the set later; removing avoids a follow-up settle(0) that could
                        // absorb unrelated dust.
                        _currentSwapTokensIn().remove(address(step.tokenOut));
                    }
                    BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(step.tokenOut), settleHint);

                    emit StrategyVaultExchangeIn(
                        step.pool, path.tokenIn, step.tokenOut, stepLocals.stepAmountIn, amountOut
                    );

                    if (amountOut < minAmountOut) {
                        revert StrategyVaultSwapFailed(step.pool, amountOut, minAmountOut);
                    }
                    if (stepLocals.isLastStep) {
                        pathAmountsOut[i] = amountOut;
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _currentSwapTokenOutAmounts().tAdd(address(step.tokenOut), amountOut);
                    } else {
                        stepLocals.stepAmountIn = amountOut;
                        path.tokenIn = step.tokenOut;
                    }
                } else if (step.isBuffer) {
                    (,, uint256 amountOut) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .erc4626BufferWrapOrUnwrap(
                            BufferWrapOrUnwrapParams({
                                kind: SwapKind.EXACT_IN,
                                direction: step.pool == address(path.tokenIn)
                                    ? WrappingDirection.UNWRAP
                                    : WrappingDirection.WRAP,
                                wrappedToken: IERC4626(step.pool),
                                amountGivenRaw: stepLocals.stepAmountIn,
                                limitRaw: minAmountOut
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // The amount out for the last step of the path should be recorded for the return value, and the
                        // amount for the token should be sent back to the sender later on.
                        pathAmountsOut[i] = amountOut;
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _currentSwapTokenOutAmounts().tAdd(address(step.tokenOut), amountOut);
                    } else {
                        // Input for the next step is output of current step.
                        stepLocals.stepAmountIn = amountOut;
                        // The token in for the next step is the token out of the current step.
                        path.tokenIn = step.tokenOut;
                    }
                } else if (address(path.tokenIn) == step.pool) {
                    // Token in is BPT: remove liquidity - Single token exact in

                    // Remove liquidity is not transient when it comes to BPT, meaning the caller needs to have the
                    // required amount when performing the operation. These tokens might be the output of a previous
                    // step, in which case the user will have a BPT credit.

                    if (stepLocals.isFirstStep) {
                        if (stepLocals.stepAmountIn > 0 && params.sender != address(this)) {
                            // If this is the first step, the sender must have the tokens. Therefore, we can transfer
                            // them to the Router, which acts as an intermediary. If the sender is the Router, we just
                            // skip this step (useful for queries).
                            //
                            // This saves one permit(1) approval for the BPT to the Router; if we burned tokens
                            // directly from the sender we would need their approval.
                            Permit2AwareRepo._permit2()
                                .transferFrom(
                                    params.sender,
                                    address(this),
                                    stepLocals.stepAmountIn.toUint160(),
                                    address(path.tokenIn)
                                );
                        }

                        // BPT is burned instantly, so we don't need to send it back later.
                        if (_currentSwapTokenInAmounts().tGet(address(path.tokenIn)) > 0) {
                            _currentSwapTokenInAmounts().tSub(address(path.tokenIn), stepLocals.stepAmountIn);
                        }
                    } else {
                        // // console.log('In _computePathAmountsOut: stepLocals.isFirstStep = false');
                        // // console.log('In _computePathAmountsOut: Sending token from Balancer Vault to Router.');
                        // If this is an intermediate step, we don't expect the sender to have BPT to burn.
                        // Then, we flashloan tokens here (which should in practice just use existing credit).
                        BalancerV3VaultAwareRepo._balancerV3Vault()
                            .sendTo(IERC20(step.pool), address(this), stepLocals.stepAmountIn);
                    }

                    // minAmountOut cannot be 0 in this case, as that would send an array of 0s to the Vault, which
                    // wouldn't know which token to use.
                    (uint256[] memory amountsOut, uint256 tokenIndex) = _getSingleInputArrayAndTokenIndex(
                        step.pool, step.tokenOut, minAmountOut == 0 ? 1 : minAmountOut
                    );

                    // Router is always an intermediary in this case. The Vault will burn tokens from the Router, so
                    // Router is both owner and spender (which doesn't need approval).
                    // Reusing `amountsOut` as input argument and function output to prevent stack too deep error.
                    (, amountsOut,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .removeLiquidity(
                            RemoveLiquidityParams({
                                pool: step.pool,
                                from: address(this),
                                maxBptAmountIn: stepLocals.stepAmountIn,
                                minAmountsOut: amountsOut,
                                kind: RemoveLiquidityKind.SINGLE_TOKEN_EXACT_IN,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // The amount out for the last step of the path should be recorded for the return value, and the
                        // amount for the token should be sent back to the sender later on.
                        pathAmountsOut[i] = amountsOut[tokenIndex];
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _currentSwapTokenOutAmounts().tAdd(address(step.tokenOut), amountsOut[tokenIndex]);
                    } else {
                        // Input for the next step is output of current step.
                        stepLocals.stepAmountIn = amountsOut[tokenIndex];
                        // The token in for the next step is the token out of the current step.
                        path.tokenIn = step.tokenOut;
                    }
                } else if (address(step.tokenOut) == step.pool) {
                    // Token out is BPT: add liquidity - Single token exact in (unbalanced).
                    (uint256[] memory exactAmountsIn,) =
                        _getSingleInputArrayAndTokenIndex(step.pool, path.tokenIn, stepLocals.stepAmountIn);

                    (, uint256 bptAmountOut,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .addLiquidity(
                            AddLiquidityParams({
                                pool: step.pool,
                                to: stepLocals.isLastStep
                                    ? params.sender
                                    : address(BalancerV3VaultAwareRepo._balancerV3Vault()),
                                maxAmountsIn: exactAmountsIn,
                                minBptAmountOut: minAmountOut,
                                kind: AddLiquidityKind.UNBALANCED,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // The amount out for the last step of the path should be recorded for the return value.
                        // We do not need to register the amount out in _currentSwapTokenOutAmounts since the BPT
                        // is minted directly to the sender, so this step can be considered settled at this point.

                        pathAmountsOut[i] = bptAmountOut;
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _settledTokenAmounts().tAdd(address(step.tokenOut), bptAmountOut);
                    } else {
                        // Input for the next step is output of current step.
                        stepLocals.stepAmountIn = bptAmountOut;
                        // The token in for the next step is the token out of the current step.
                        path.tokenIn = step.tokenOut;
                        // If this is an intermediate step, BPT is minted to the Vault so we just get the credit.
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(step.pool), bptAmountOut);
                    }
                } else {
                    // No BPT involved in the operation: regular swap exact in.
                    (,, uint256 amountOut) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .swap(
                            VaultSwapParams({
                                kind: SwapKind.EXACT_IN,
                                pool: step.pool,
                                tokenIn: path.tokenIn,
                                tokenOut: step.tokenOut,
                                amountGivenRaw: stepLocals.stepAmountIn,
                                limitRaw: minAmountOut,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // The amount out for the last step of the path should be recorded for the return value, and the
                        // amount for the token should be sent back to the sender later on.
                        pathAmountsOut[i] = amountOut;
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _currentSwapTokenOutAmounts().tAdd(address(step.tokenOut), amountOut);
                    } else {
                        // Input for the next step is output of current step.
                        stepLocals.stepAmountIn = amountOut;
                        // The token in for the next step is the token out of the current step.
                        path.tokenIn = step.tokenOut;
                    }
                }
            }
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Queries                                */
    /* ---------------------------------------------------------------------- */

    function querySwapExactIn(SESwapPathExactAmountIn[] memory paths, address sender, bytes calldata userData)
        external
        saveSender(sender)
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        for (uint256 i = 0; i < paths.length; ++i) {
            paths[i].minAmountOut = 0;
        }

        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .quote(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeBatchRouterExactIn.querySwapExactInHook,
                        SESwapExactInHookParams({
                            sender: sender,
                            paths: paths,
                            deadline: type(uint256).max,
                            wethIsEth: false,
                            userData: userData
                        })
                    )
                ),
            (uint256[], address[], uint256[])
        );
    }

    function querySwapExactInHook(SESwapExactInHookParams calldata params)
        external
        lock
        onlyBalancerV3Vault
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut)
    {
        (pathAmountsOut, tokensOut, amountsOut) = _swapExactInHook(params);

        // Query functions are simulated executions (e.g., eth_call). They must still satisfy the Vault's
        // transient-accounting invariant, so we settle deltas the same way as in execution.
        _settlePaths(params.sender, params.wethIsEth);
    }
}

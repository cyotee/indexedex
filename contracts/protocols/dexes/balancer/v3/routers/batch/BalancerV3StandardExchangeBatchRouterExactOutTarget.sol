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
    IBalancerV3StandardExchangeBatchRouterExactOut
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol';
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IStandardExchangeProxy} from 'contracts/interfaces/proxies/IStandardExchangeProxy.sol';
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
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {
    BalancerV3StandardExchangeBatchRouterCommon
} from 'contracts/protocols/dexes/balancer/v3/routers/batch/BalancerV3StandardExchangeBatchRouterCommon.sol';
import {ReentrancyLockModifiers} from '@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol';
import {
    BalancerV3VaultGuardModifiers
} from '@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultGuardModifiers.sol';
import {SenderGuard} from '@crane/contracts/external/balancer/v3/vault/contracts/SenderGuard.sol';

contract BalancerV3StandardExchangeBatchRouterExactOutTarget is
    BalancerV3StandardExchangeBatchRouterCommon,
    ReentrancyLockModifiers,
    BalancerV3VaultGuardModifiers,
    SenderGuard,
    IBalancerV3StandardExchangeBatchRouterExactOut
{
    using BetterSafeERC20 for IERC20;
    using SafeCast for *;
    using TransientEnumerableSet for TransientEnumerableSet.AddressSet;
    using TransientStorageHelpers for *;

    struct SwapStepLocals {
        bool isFirstStep;
        bool isLastStep;
    }

    struct DistinctTokenBalance {
        IERC20 token;
        uint256 balanceBefore;
    }

    function swapExactOut(
        SESwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        public
        payable
        saveSender(msg.sender)
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        return _swapExactOut(msg.sender, paths, deadline, wethIsEth, userData);
    }

    function _swapExactOut(
        address sender,
        SESwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes memory userData
    ) internal returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn) {
        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .unlock(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeBatchRouterExactOut.swapExactOutHook,
                        SESwapExactOutHookParams({
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

    function swapExactOutWithPermit(
        SESwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    )
        external
        payable
        saveSender(msg.sender)
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        return _swapExactOutWithPermit(msg.sender, paths, deadline, wethIsEth, userData, permits, signatures);
    }

    function _swapExactOutWithPermit(
        address sender,
        SESwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    )
        internal
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        DistinctTokenBalance[] memory trackedBalances = _prepareSwapExactOutWithPermit(paths, permits, signatures);

        _setBatchPermitMode(true);
        (pathAmountsIn, tokensIn, amountsIn) = _swapExactOut(sender, paths, deadline, wethIsEth, userData);
        _setBatchPermitMode(false);

        _refundUnusedPermitBalances(sender, trackedBalances);
    }

    function _prepareSwapExactOutWithPermit(
        SESwapPathExactAmountOut[] memory paths,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    ) internal returns (DistinctTokenBalance[] memory trackedBalances) {
        trackedBalances = _trackDistinctTokenInBalances(paths);

        if (permits.length != paths.length || signatures.length != paths.length) {
            revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathLengthMismatch(
                paths.length, permits.length, signatures.length
            );
        }

        _pullBatchPermitTokens(paths, permits, signatures);
    }

    function _trackDistinctTokenInBalances(SESwapPathExactAmountOut[] memory paths)
        internal
        view
        returns (DistinctTokenBalance[] memory trackedBalances)
    {
        trackedBalances = new DistinctTokenBalance[](paths.length);

        uint256 trackedCount = 0;
        for (uint256 i = 0; i < paths.length; ++i) {
            IERC20 tokenIn = paths[i].tokenIn;
            bool seen = false;

            for (uint256 j = 0; j < trackedCount; ++j) {
                if (address(trackedBalances[j].token) == address(tokenIn)) {
                    seen = true;
                    break;
                }
            }

            if (!seen) {
                trackedBalances[trackedCount] = DistinctTokenBalance({
                    token: tokenIn,
                    balanceBefore: tokenIn.balanceOf(address(this))
                });
                ++trackedCount;
            }
        }
    }

    function _refundUnusedPermitBalances(address sender, DistinctTokenBalance[] memory trackedBalances) internal {
        for (uint256 i = 0; i < trackedBalances.length; ++i) {
            IERC20 token = trackedBalances[i].token;
            if (address(token) == address(0)) {
                break;
            }

            uint256 currentBalance = token.balanceOf(address(this));
            if (currentBalance > trackedBalances[i].balanceBefore) {
                token.safeTransfer(sender, currentBalance - trackedBalances[i].balanceBefore);
            }
        }
    }

    function _pullBatchPermitTokens(
        SESwapPathExactAmountOut[] memory paths,
        ISignatureTransfer.PermitTransferFrom[] calldata permits,
        bytes[] calldata signatures
    ) internal {
        ISignatureTransfer permit2 = ISignatureTransfer(address(Permit2AwareRepo._permit2()));

        for (uint256 i = 0; i < paths.length; ++i) {
            if (permits[i].permitted.token != address(paths[i].tokenIn)) {
                revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathTokenMismatch(
                    i, address(paths[i].tokenIn), permits[i].permitted.token
                );
            }
            if (permits[i].permitted.amount < paths[i].maxAmountIn) {
                revert IBalancerV3StandardExchangeBatchRouterTypes.PermitPathAmountInsufficient(
                    i, paths[i].maxAmountIn, permits[i].permitted.amount
                );
            }

            ISignatureTransfer.SignatureTransferDetails memory td = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: paths[i].maxAmountIn
            });

            permit2.permitTransferFrom(permits[i], td, msg.sender, signatures[i]);
        }
    }

    function swapExactOutHook(SESwapExactOutHookParams calldata params)
        external
        lock
        onlyBalancerV3Vault
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        (pathAmountsIn, tokensIn, amountsIn) = _swapExactOutHook(params);

        _settlePaths(params.sender, params.wethIsEth);
    }

    function _swapExactOutHook(SESwapExactOutHookParams calldata params)
        internal
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > params.deadline) {
            revert SwapDeadline();
        }

        pathAmountsIn = _computePathAmountsIn(params);

        // The hook writes current swap token and token amounts in.
        // We copy that information to memory to return it before it is deleted during settlement.
        tokensIn = _currentSwapTokensIn().values(); // Copy transient storage to memory
        amountsIn = new uint256[](tokensIn.length);
        for (uint256 i = 0; i < tokensIn.length; ++i) {
            amountsIn[i] = _currentSwapTokenInAmounts().tGet(tokensIn[i]) + _settledTokenAmounts().tGet(tokensIn[i]);
            _settledTokenAmounts().tSet(tokensIn[i], 0);
        }
    }

    /**
     * @dev Executes every swap path in the given input parameters.
     * Computes inputs for the path, and aggregates them by token and amounts as well in transient storage.
     */
    function _computePathAmountsIn(SESwapExactOutHookParams calldata params)
        internal
        returns (uint256[] memory pathAmountsIn)
    {
        pathAmountsIn = new uint256[](params.paths.length);

        for (uint256 i = 0; i < params.paths.length; ++i) {
            SESwapPathExactAmountOut memory path = params.paths[i];
            // This variable shall be updated at the end of each step to be used as input of the next one.
            // The first value corresponds to the given amount out for the current path.
            // uint256 stepExactAmountOut = path.exactAmountOut;

            // Paths may (or may not) share the same token in. To minimize token transfers, we store the addresses in
            // a set with unique addresses that can be iterated later on.
            //
            // For example, if all paths share the same token in, the set will end up with only one entry.
            // Since the path is 'given out', the output of the operation specified by the last step in each path will
            // be added to calculate the amounts in for each token.
            //
            // Note: If the last step is a strategy vault, _currentSwapTokensIn is not updated here because
            // tokens go directly from sender to vault. The isLastStep block below handles settlement tracking.
            _currentSwapTokensIn().add(address(path.tokenIn));

            // Backwards iteration: the exact amount out applies to the last step, so we cannot iterate from first to
            // last. The calculated input of step (j) is the exact amount out for step (j - 1).
            for (int256 j = int256(path.steps.length - 1); j >= 0; --j) {
                SESwapPathStep memory step = path.steps[uint256(j)];
                SwapStepLocals memory stepLocals;
                stepLocals.isLastStep = (j == 0);
                stepLocals.isFirstStep = (uint256(j) == path.steps.length - 1);

                // These two variables are set at the beginning of the iteration and are used as inputs for
                // the operation described by the step.
                uint256 stepMaxAmountIn;
                IERC20 stepTokenIn;

                if (stepLocals.isFirstStep) {
                    // The first step in the iteration is the last one in the given array of steps, and it
                    // specifies the output token for the step as well as the exact amount out for that token.
                    // Output amounts are stored to send them later on.
                    // For strategy vaults, the output is sent directly to the user, so don't track it here.
                    if (!step.isStrategyVault) {
                        _currentSwapTokensOut().add(address(step.tokenOut));
                        _currentSwapTokenOutAmounts().tAdd(address(step.tokenOut), path.exactAmountOut);
                    }
                }

                if (stepLocals.isLastStep) {
                    // In backwards order, the last step is the first one in the given path.
                    // The given token in and max amount in apply for this step.
                    stepMaxAmountIn = path.maxAmountIn;
                    stepTokenIn = path.tokenIn;
                } else {
                    // For every other intermediate step, no maximum input applies.
                    // The input token for this step is the output token of the previous given step.
                    // We use uint128 to prevent Vault's internal scaling from overflowing.
                    stepMaxAmountIn = _MAX_AMOUNT;
                    stepTokenIn = path.steps[uint256(j - 1)].tokenOut;
                }

                if (step.isStrategyVault) {
                    uint256 amountIn;

                    // Always execute the real Standard Exchange operation (including token movements) so that
                    // Standard Exchange Vault callbacks run during `vault.quote(...)`.
                    if (stepLocals.isLastStep) {
                        // Last step (first in forward order): Strategy vault expects the input tokens to be
                        // transferred to it when `pretransferred=true`.
                        // In batch permit mode the router already holds the pre-pulled first-token balance.
                        // Otherwise, pull from the sender as before.
                        if (_isPrepaid()) {
                            stepTokenIn.safeTransfer(address(step.pool), stepMaxAmountIn);
                        } else {
                            _transferToRecipient(
                                params.sender, address(step.pool), stepTokenIn, stepMaxAmountIn, params.wethIsEth
                            );
                        }
                    } else {
                        // Middle / first step in backwards iteration: tokens come from the Balancer Vault
                        BalancerV3VaultAwareRepo._balancerV3Vault()
                            .sendTo(IERC20(stepTokenIn), address(step.pool), stepMaxAmountIn);
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(stepTokenIn), 0);
                    }

                    BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                        IStandardExchangeProxy(address(step.pool))
                    );
                    amountIn = IStandardExchangeOut(step.pool)
                        .exchangeOut(
                            stepTokenIn,
                            stepMaxAmountIn,
                            step.tokenOut,
                            path.exactAmountOut,
                            stepLocals.isFirstStep
                                ? params.sender
                                : address(BalancerV3VaultAwareRepo._balancerV3Vault()),
                            stepLocals.isLastStep,
                            type(uint256).max
                        );
                    BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(
                        IStandardExchangeProxy(address(0))
                    );

                    // In `pretransferred=true` mode, Standard Exchange vaults refund unused `tokenIn` back to
                    // `msg.sender` (this router). Forward that refund into the Balancer Vault so it can be returned
                    // to the user via the normal batch settlement path.
                    if (stepLocals.isLastStep && amountIn < stepMaxAmountIn) {
                        uint256 refundAmount = stepMaxAmountIn - amountIn;
                        IERC20(stepTokenIn)
                            .safeTransfer(address(BalancerV3VaultAwareRepo._balancerV3Vault()), refundAmount);
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(stepTokenIn), refundAmount);
                    }

                    // If the Strategy Vault outputs to the Balancer Vault (i.e., not the final forward step), settle
                    // the output token so its credit is available for subsequent operations.
                    if (!stepLocals.isFirstStep) {
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(step.tokenOut), path.exactAmountOut);
                    }

                    emit StrategyVaultExchangeOut(step.pool, stepTokenIn, step.tokenOut, amountIn, path.exactAmountOut);

                    if (amountIn > stepMaxAmountIn) {
                        revert StrategyVaultMaxAmountExceeded(step.pool, amountIn, stepMaxAmountIn);
                    }
                    if (stepLocals.isLastStep) {
                        pathAmountsIn[i] = amountIn;
                        _currentSwapTokensOut().add(address(stepTokenIn));
                        _currentSwapTokenOutAmounts().tAdd(address(stepTokenIn), stepMaxAmountIn - amountIn);
                        _settledTokenAmounts().tAdd(address(path.tokenIn), amountIn);
                        // Remove from _currentSwapTokensIn since tokens went directly to strategy vault (not through
                        // Balancer Vault). The Balancer Vault doesn't need to settle these tokens.
                        _currentSwapTokensIn().remove(address(stepTokenIn));
                    } else {
                        path.exactAmountOut = amountIn;
                    }
                } else if (step.isBuffer) {
                    if (stepLocals.isLastStep) {
                        _takeTokenIn(params.sender, path.tokenIn, path.maxAmountIn, params.wethIsEth);
                    }

                    (, uint256 amountIn,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .erc4626BufferWrapOrUnwrap(
                            BufferWrapOrUnwrapParams({
                                kind: SwapKind.EXACT_OUT,
                                direction: step.pool == address(stepTokenIn)
                                    ? WrappingDirection.UNWRAP
                                    : WrappingDirection.WRAP,
                                wrappedToken: IERC4626(step.pool),
                                amountGivenRaw: path.exactAmountOut,
                                limitRaw: stepMaxAmountIn
                            })
                        );

                    if (stepLocals.isLastStep) {
                        pathAmountsIn[i] = amountIn;
                        // Since the token was taken in advance, returns to the user what is left from the
                        // wrap/unwrap operation.
                        _currentSwapTokensOut().add(address(stepTokenIn));
                        _currentSwapTokenOutAmounts().tAdd(address(stepTokenIn), path.maxAmountIn - amountIn);
                        // `settledTokenAmounts` is used to return the `amountsIn` at the end of the operation, which
                        // is only amountIn. The difference between maxAmountIn and amountIn will be paid during
                        // settle.
                        _settledTokenAmounts().tAdd(address(path.tokenIn), amountIn);
                    } else {
                        path.exactAmountOut = amountIn;
                    }
                } else if (address(stepTokenIn) == step.pool) {
                    // Token in is BPT: remove liquidity - Single token exact out

                    // Remove liquidity is not transient when it comes to BPT, meaning the caller needs to have the
                    // required amount when performing the operation. In this case, the BPT amount needed for the
                    // operation is not known in advance, so we take a flashloan for all the available reserves.
                    //
                    // The last step is the one that defines the inputs for this path. The caller should have enough
                    // BPT to burn already if that's the case, so we just skip this step if so.
                    if (stepLocals.isLastStep == false) {
                        stepMaxAmountIn = BalancerV3VaultAwareRepo._balancerV3Vault().getReservesOf(stepTokenIn);
                        BalancerV3VaultAwareRepo._balancerV3Vault()
                            .sendTo(IERC20(step.pool), address(this), stepMaxAmountIn);
                    } else if (params.sender != address(this)) {
                        // The last step being executed is the first step in the swap path, meaning that it's the one
                        // that defines the inputs of the path.
                        //
                        // In that case, the sender must have the tokens. Therefore, we can transfer them
                        // to the Router, which acts as an intermediary. If the sender is the Router, we just skip this
                        // step (useful for queries).
                        Permit2AwareRepo._permit2()
                            .transferFrom(
                                params.sender, address(this), stepMaxAmountIn.toUint160(), address(stepTokenIn)
                            );
                    }

                    (uint256[] memory exactAmountsOut,) =
                        _getSingleInputArrayAndTokenIndex(step.pool, step.tokenOut, path.exactAmountOut);

                    // Router is always an intermediary in this case. The Vault will burn tokens from the Router, so
                    // Router is both owner and spender (which doesn't need approval).
                    (uint256 bptAmountIn,,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .removeLiquidity(
                            RemoveLiquidityParams({
                                pool: step.pool,
                                from: address(this),
                                maxBptAmountIn: stepMaxAmountIn,
                                minAmountsOut: exactAmountsOut,
                                kind: RemoveLiquidityKind.SINGLE_TOKEN_EXACT_OUT,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // BPT is burned instantly, so we don't need to send it to the Vault during settlement.
                        pathAmountsIn[i] = bptAmountIn;
                        _settledTokenAmounts().tAdd(address(stepTokenIn), bptAmountIn);

                        // Refund unused portion of BPT to the user.alias
                        if (bptAmountIn < stepMaxAmountIn && params.sender != address(this)) {
                            stepTokenIn.safeTransfer(address(params.sender), stepMaxAmountIn - bptAmountIn);
                        }
                    } else {
                        // Output for the step (j - 1) is the input of step (j).
                        path.exactAmountOut = bptAmountIn;
                        // Refund unused portion of BPT flashloan to the Vault.
                        if (bptAmountIn < stepMaxAmountIn) {
                            uint256 refundAmount = stepMaxAmountIn - bptAmountIn;
                            stepTokenIn.safeTransfer(address(BalancerV3VaultAwareRepo._balancerV3Vault()), refundAmount);
                            BalancerV3VaultAwareRepo._balancerV3Vault().settle(stepTokenIn, refundAmount);
                        }
                    }
                } else if (address(step.tokenOut) == step.pool) {
                    // Token out is BPT: add liquidity - Single token exact out.
                    (uint256[] memory stepAmountsIn, uint256 tokenIndex) =
                        _getSingleInputArrayAndTokenIndex(step.pool, stepTokenIn, stepMaxAmountIn);

                    // Reusing `amountsIn` as input argument and function output to prevent stack too deep error.
                    (stepAmountsIn,,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .addLiquidity(
                            AddLiquidityParams({
                                pool: step.pool,
                                to: stepLocals.isFirstStep
                                    ? params.sender
                                    : address(BalancerV3VaultAwareRepo._balancerV3Vault()),
                                maxAmountsIn: stepAmountsIn,
                                minBptAmountOut: path.exactAmountOut,
                                kind: AddLiquidityKind.SINGLE_TOKEN_EXACT_OUT,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        // The amount out for the last step of the path should be recorded for the return value.
                        pathAmountsIn[i] = stepAmountsIn[tokenIndex];
                        _currentSwapTokenInAmounts().tAdd(address(stepTokenIn), stepAmountsIn[tokenIndex]);
                    } else {
                        path.exactAmountOut = stepAmountsIn[tokenIndex];
                    }

                    // The first step executed determines the outputs for the path, since this is given out.
                    if (stepLocals.isFirstStep) {
                        // Instead of sending tokens back to the Vault, we can just discount it from whatever
                        // the Vault owes the sender to make one less transfer.
                        _currentSwapTokenOutAmounts().tSub(address(step.tokenOut), path.exactAmountOut);
                    } else {
                        // If it's not the first step, BPT is minted to the Vault so we just get the credit.
                        BalancerV3VaultAwareRepo._balancerV3Vault().settle(IERC20(step.pool), path.exactAmountOut);
                    }
                } else {
                    // No BPT involved in the operation: regular swap exact out.
                    (, uint256 amountIn,) = BalancerV3VaultAwareRepo._balancerV3Vault()
                        .swap(
                            VaultSwapParams({
                                kind: SwapKind.EXACT_OUT,
                                pool: step.pool,
                                tokenIn: stepTokenIn,
                                tokenOut: step.tokenOut,
                                amountGivenRaw: path.exactAmountOut,
                                limitRaw: stepMaxAmountIn,
                                userData: params.userData
                            })
                        );

                    if (stepLocals.isLastStep) {
                        pathAmountsIn[i] = amountIn;
                        _currentSwapTokenInAmounts().tAdd(address(stepTokenIn), amountIn);
                    } else {
                        path.exactAmountOut = amountIn;
                    }
                }
            }
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                 Queries                                */
    /* ---------------------------------------------------------------------- */

    function querySwapExactOut(SESwapPathExactAmountOut[] memory paths, address sender, bytes calldata userData)
        external
        saveSender(sender)
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        return abi.decode(
            BalancerV3VaultAwareRepo._balancerV3Vault()
                .quote(
                    abi.encodeCall(
                        IBalancerV3StandardExchangeBatchRouterExactOut.querySwapExactOutHook,
                        SESwapExactOutHookParams({
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

    function querySwapExactOutHook(SESwapExactOutHookParams calldata params)
        external
        lock
        onlyBalancerV3Vault
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn)
    {
        (pathAmountsIn, tokensIn, amountsIn) = _swapExactOutHook(params);

        // Query functions are simulated executions (e.g., eth_call). They must still satisfy the Vault's
        // transient-accounting invariant, so we settle deltas the same way as in execution.
        _settlePaths(params.sender, params.wethIsEth);
    }
}

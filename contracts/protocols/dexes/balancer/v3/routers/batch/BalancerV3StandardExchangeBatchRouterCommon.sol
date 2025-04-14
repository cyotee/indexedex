// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IWETH} from '@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IVault} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol';
import {BetterSafeERC20} from '@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol';
import {
    TransientEnumerableSet
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/openzeppelin/TransientEnumerableSet.sol';
import {
    TransientStorageHelpers,
    AddressToUintMappingSlot,
    StorageSlotExtension
} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/TransientStorageHelpers.sol';
import {SafeCast} from '@crane/contracts/utils/SafeCast.sol';
import {
    BalancerV3VaultAwareRepo
} from '@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol';
import {WETHAwareRepo} from '@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol';
import {Permit2AwareRepo} from '@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol';
import {
    BalancerV3StandardExchangeRouterCommon
} from 'contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterCommon.sol';
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol';
import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from 'contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol';

abstract contract BalancerV3StandardExchangeBatchRouterCommon is BalancerV3StandardExchangeRouterCommon {
    using SafeCast for *;
    using TransientEnumerableSet for TransientEnumerableSet.AddressSet;
    using TransientStorageHelpers for *;
    using BetterSafeERC20 for IERC20;
    using StorageSlotExtension for *;

    bytes32 private immutable _CURRENT_SWAP_TOKEN_IN_SLOT = _calculateBatchRouterStorageSlot('currentSwapTokensIn');
    bytes32 private immutable _CURRENT_SWAP_TOKEN_IN_AMOUNTS_SLOT =
        _calculateBatchRouterStorageSlot('currentSwapTokenInAmounts');
    bytes32 private immutable _CURRENT_SWAP_TOKEN_OUT_SLOT = _calculateBatchRouterStorageSlot('currentSwapTokensOut');
    bytes32 private immutable _CURRENT_SWAP_TOKEN_OUT_AMOUNTS_SLOT =
        _calculateBatchRouterStorageSlot('currentSwapTokenOutAmounts');
    bytes32 private immutable _SETTLED_TOKEN_AMOUNTS_SLOT = _calculateBatchRouterStorageSlot('settledTokenAmounts');
    bytes32 private immutable _BATCH_PERMIT_MODE_SLOT = _calculateBatchRouterStorageSlot('batchPermitMode');

    function _calculateBatchRouterStorageSlot(string memory key) internal pure returns (bytes32) {
        return TransientStorageHelpers.calculateSlot(type(BalancerV3StandardExchangeBatchRouterCommon).name, key);
    }

    // We use transient storage to track tokens and amounts flowing in and out of a batch swap.
    // Set of input tokens involved in a batch swap.
    function _currentSwapTokensIn() internal view returns (TransientEnumerableSet.AddressSet storage enumerableSet) {
        bytes32 slot = _CURRENT_SWAP_TOKEN_IN_SLOT;
        assembly ('memory-safe') {
            enumerableSet.slot := slot
        }
    }

    // token in -> amount: tracks token in amounts within a batch swap.
    function _currentSwapTokenInAmounts() internal view returns (AddressToUintMappingSlot slot) {
        return AddressToUintMappingSlot.wrap(_CURRENT_SWAP_TOKEN_IN_AMOUNTS_SLOT);
    }

    function _currentSwapTokensOut() internal view returns (TransientEnumerableSet.AddressSet storage enumerableSet) {
        bytes32 slot = _CURRENT_SWAP_TOKEN_OUT_SLOT;
        assembly ('memory-safe') {
            enumerableSet.slot := slot
        }
    }

    // token out -> amount: tracks token out amounts within a batch swap.
    function _currentSwapTokenOutAmounts() internal view returns (AddressToUintMappingSlot slot) {
        return AddressToUintMappingSlot.wrap(_CURRENT_SWAP_TOKEN_OUT_AMOUNTS_SLOT);
    }

    // token -> amount that is part of the current input / output amounts, but is settled preemptively.
    // This situation happens whenever there is BPT involved in the operation, which is minted and burned instantly.
    // Since those amounts are not tracked in the inputs / outputs to settle, we need to track them elsewhere
    // to return the correct total amounts in and out for each token involved in the operation.
    function _settledTokenAmounts() internal view returns (AddressToUintMappingSlot slot) {
        return AddressToUintMappingSlot.wrap(_SETTLED_TOKEN_AMOUNTS_SLOT);
    }

    /*******************************************************************************
                                    Settlement
    *******************************************************************************/

    function _batchPermitModeSlot() internal view returns (StorageSlotExtension.BooleanSlotType) {
        return _BATCH_PERMIT_MODE_SLOT.asBoolean();
    }

    function _setBatchPermitMode(bool enabled) internal {
        _batchPermitModeSlot().tstore(enabled);
    }

    function _isPrepaid() internal view virtual returns (bool) {
        return _batchPermitModeSlot().tload();
    }

    /// @notice Settles batch and composite liquidity operations, after credits and debits are computed.
    function _settlePaths(address sender, bool wethIsEth) internal {
        // numTokensIn / Out may be 0 if the inputs and / or outputs are not transient.
        // For example, a swap starting with a 'remove liquidity' step will already have burned the input tokens,
        // in which case there is nothing to settle. Then, since we're iterating backwards below, we need to be able
        // to subtract 1 from these quantities without reverting, which is why we use signed integers.
        int256 numTokensIn = int256(_currentSwapTokensIn().length());
        int256 numTokensOut = int256(_currentSwapTokensOut().length());

        // Iterate backwards, from the last element to 0 (included).
        // Removing the last element from a set is cheaper than removing the first one.
        for (int256 i = int256(numTokensIn - 1); i >= 0; --i) {
            address tokenIn = _currentSwapTokensIn().unchecked_at(uint256(i));
            uint256 amount = _currentSwapTokenInAmounts().tGet(tokenIn);

            _takeOrSettle(sender, wethIsEth, tokenIn, amount);

            // Erases delta, in case more than one batch router operation is called in the same transaction.
            _currentSwapTokenInAmounts().tSet(tokenIn, 0);
            _currentSwapTokensIn().remove(tokenIn);
        }

        for (int256 i = int256(numTokensOut - 1); i >= 0; --i) {
            address tokenOut = _currentSwapTokensOut().unchecked_at(uint256(i));
            _sendTokenOut(sender, IERC20(tokenOut), _currentSwapTokenOutAmounts().tGet(tokenOut), wethIsEth);
            // Erases delta, in case more than one batch router operation is called in the same transaction.
            _currentSwapTokenOutAmounts().tSet(tokenOut, 0);
            _currentSwapTokensOut().remove(tokenOut);
        }

        // Return the rest of ETH to sender.
        _returnEth(sender);
    }

    /**
     * @notice Interpret the parameters and flags to decide whether we need to pull in tokens, or settle directly.
     * @dev This logic is repeated in many places.
     * @param sender The sender from the current operation
     * @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
     * @param token The token being transferred or settled
     * @param amountIn The amount being transferred or settled
     */
    function _takeOrSettle(address sender, bool wethIsEth, address token, uint256 amountIn) internal {
        if (_isPrepaid()) {
            // Batch permit mode: transfer from router's pre-pulled balance to vault
            if (amountIn > 0) {
                IVault _balancerV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
                IERC20(token).safeTransfer(address(_balancerV3Vault), amountIn);
                _balancerV3Vault.settle(IERC20(token), amountIn);
            }
        } else if (wethIsEth && token == address(WETHAwareRepo._weth())) {
            // WETH handling: wrap and settle
            _takeTokenIn(sender, IERC20(token), amountIn, wethIsEth);
        } else {
            // Retrieve tokens from the sender using Permit2
            _takeTokenIn(sender, IERC20(token), amountIn, wethIsEth);
        }
    }

    function _transferToRecipient(address sender, address recipient, IERC20 tokenIn, uint256 amountIn, bool wethIsEth)
        internal
    {
        if (_isPrepaid()) {
            if (amountIn > 0) {
                tokenIn.safeTransfer(recipient, amountIn);
            }
            return;
        }

        IWETH _weth = WETHAwareRepo._weth();
        address weth = address(_weth);
        if (wethIsEth && address(tokenIn) == address(weth)) {
            _weth.deposit{value: amountIn}();
            // _permit2().transferFrom(sender, recipient, amountIn.toUint160(), address(weth));
            _weth.transfer(recipient, amountIn);
        } else {
            if (amountIn > 0) {
                Permit2AwareRepo._permit2().transferFrom(sender, recipient, amountIn.toUint160(), address(tokenIn));
            }
        }
    }

    /**
     * @dev Returns an array with `amountGiven` at `tokenIndex`, and 0 for every other index.
     * The returned array length matches the number of tokens in the pool.
     * Reverts if the given index is greater than or equal to the pool number of tokens.
     */
    function _getSingleInputArrayAndTokenIndex(address pool, IERC20 token, uint256 amountGiven)
        internal
        view
        returns (uint256[] memory amountsGiven, uint256 tokenIndex)
    {
        uint256 numTokens;
        (numTokens, tokenIndex) =
            BalancerV3VaultAwareRepo._balancerV3Vault().getPoolTokenCountAndIndexOfToken(pool, token);
        amountsGiven = new uint256[](numTokens);
        amountsGiven[tokenIndex] = amountGiven;
    }

    function _exchangeInToVault(
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapExactInHookParams calldata params,
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapStepLocals memory stepLocals,
        IBalancerV3StandardExchangeBatchRouterTypes.SESwapPathStep memory step,
        IBalancerV3StandardExchangeBatchRouterExactIn.SESwapPathExactAmountIn memory path,
        // uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountCalculated) {
        return IStandardExchangeIn(step.pool)
            .exchangeIn(
                path.tokenIn,
                stepLocals.stepAmountIn,
                step.tokenOut,
                minAmountOut,
                recipient,
                true,
                // uint256 deadline
                params.deadline
            );
    }
}

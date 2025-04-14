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
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {BetterAddress} from "@crane/contracts/utils/BetterAddress.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {SafeCast} from "@crane/contracts/utils/SafeCast.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    TransientStorageHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/TransientStorageHelpers.sol";
import {
    StorageSlotExtension
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/openzeppelin/StorageSlotExtension.sol";
import {RouterWethLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/RouterWethLib.sol";

abstract contract BalancerV3StandardExchangeRouterCommon is BalancerV3StandardExchangeRouterTypes {
    using BetterAddress for address payable;
    using RouterWethLib for IWETH;
    using BetterSafeERC20 for IERC20;
    using StorageSlotExtension for *;
    using SafeCast for *;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _IS_RETURN_ETH_LOCKED_SLOT =
        TransientStorageHelpers.calculateSlot(type(BalancerV3StandardExchangeRouterCommon).name, "isReturnEthLocked");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private immutable _HAS_PERMIT_PULLED_TOKEN_IN_SLOT =
        TransientStorageHelpers.calculateSlot(type(BalancerV3StandardExchangeRouterCommon).name, "hasPermitPulledTokenIn");

    string internal constant _WITNESS_TYPE_STRING =
        "Witness witness)"
        "TokenPermissions(address token,uint256 amount)"
        "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)";

    bytes32 internal constant _WITNESS_TYPEHASH = keccak256(
        "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
    );

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    event SwapHookParamsDebug(
        address indexed sender,
        uint8 kind,
        address indexed pool,
        address tokenIn,
        address tokenOut,
        address tokenInVault,
        address tokenOutVault,
        uint256 amountGiven,
        uint256 limit,
        bool wethIsEth
    );

    event WethSentinelDebug(
        address indexed sender, uint8 kind, uint256 amountGiven, uint256 limit, bool wrap, bool unwrap
    );

    /// @notice The swap transaction was not validated before the specified deadline timestamp.
    // error SwapDeadline();

    function _isReturnEthLockedSlot() internal view returns (StorageSlotExtension.BooleanSlotType) {
        return _IS_RETURN_ETH_LOCKED_SLOT.asBoolean();
    }

    function _hasPermitPulledTokenInSlot() internal view returns (StorageSlotExtension.BooleanSlotType) {
        return _HAS_PERMIT_PULLED_TOKEN_IN_SLOT.asBoolean();
    }

    function _setHasPermitPulledTokenIn(bool hasPermitPulledTokenIn) internal {
        _hasPermitPulledTokenInSlot().tstore(hasPermitPulledTokenIn);
    }

    function _hasPermitPulledTokenIn() internal view returns (bool) {
        return _hasPermitPulledTokenInSlot().tload();
    }

    function _swapHook(StandardExchangeSwapSingleTokenHookParams calldata params)
        internal
        returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut)
    {
        // // console.log("Router: _swapHook - entering function");
        // The deadline is timestamp-based: it should not be relied upon for sub-minute accuracy.
        // solhint-disable-next-line not-rely-on-time
        // if (block.timestamp > params.deadline) {
        //     revert SwapDeadline();
        // }

        // // console.log("Router: About to call Balancer V3 Vault.swap");
        (amountCalculated, amountIn, amountOut) = BalancerV3VaultAwareRepo._balancerV3Vault()
            .swap(
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
    }

    function _takeTokenIn(address sender, IERC20 tokenIn, uint256 amountIn, bool wethIsEth) internal {
        IWETH _weth = WETHAwareRepo._weth();
        IVault _balancerV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        if (_hasPermitPulledTokenIn()) {
            if (amountIn > 0) {
                tokenIn.safeTransfer(address(_balancerV3Vault), amountIn);
                _balancerV3Vault.settle(tokenIn, amountIn);
            }
            return;
        }

        // If the tokenIn is ETH, then wrap `amountIn` into WETH.
        if (wethIsEth && address(tokenIn) == address(_weth)) {
            _weth.wrapEthAndSettle(_balancerV3Vault, amountIn);
        } else {
            if (amountIn > 0) {
                // Send the tokenIn amount to the Vault.
                Permit2AwareRepo._permit2()
                    .transferFrom(sender, address(_balancerV3Vault), amountIn.toUint160(), address(tokenIn));
                _balancerV3Vault.settle(tokenIn, amountIn);
            }
        }
    }

    function _sendTokenOut(address sender, IERC20 tokenOut, uint256 amountOut, bool wethIsEth) internal {
        if (amountOut == 0) {
            return;
        }
        IWETH _weth = WETHAwareRepo._weth();
        IVault _balancerV3Vault = BalancerV3VaultAwareRepo._balancerV3Vault();
        // If the tokenOut is ETH, then unwrap `amountOut` into ETH.
        if (wethIsEth && address(tokenOut) == address(_weth)) {
            _weth.unwrapWethAndTransferToSender(_balancerV3Vault, sender, amountOut);
        } else {
            // Receive the tokenOut amountOut.
            _balancerV3Vault.sendTo(tokenOut, sender, amountOut);
        }
    }

    /**
     * @dev Returns excess ETH back to the contract caller. Checks for sufficient ETH balance are made right before
     * each deposit, ensuring it will revert with a friendly custom error. If there is any balance remaining when
     * `_returnEth` is called, return it to the sender.
     *
     * Because the caller might not know exactly how much ETH a Vault action will require, they may send extra.
     * Note that this excess value is returned *to the contract caller* (msg.sender). If caller and e.g. swap sender
     * are not the same (because the caller is a relayer for the sender), then it is up to the caller to manage this
     * returned ETH.
     */
    function _returnEth(address sender) internal {
        // It's cheaper to check the balance and return early than checking a transient variable.
        // Moreover, most operations will not have ETH to return.
        uint256 excess = address(this).balance;
        if (excess == 0) {
            return;
        }

        // If the return of ETH is locked, then don't return it,
        // because _returnEth will be called again at the end of the call.
        if (_isReturnEthLockedSlot().tload()) {
            return;
        }

        payable(sender).sendValue(excess);
    }

    function _exchangeInToVault(
        StandardExchangeSwapSingleTokenHookParams calldata params,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) internal returns (uint256 amountCalculated) {
        // Placeholder to avoid compilation errors.
        return params.tokenOutVault
            .exchangeIn(
                // IERC20 tokenIn,
                IERC20(address(params.tokenOutVault)),
                // uint256 amountIn,
                amountIn,
                // IERC20 tokenOut,
                IERC20(address(params.tokenOut)),
                // uint256 minAmountOut,
                minAmountOut,
                // address recipient,
                recipient,
                // bool pretransferred
                true,
                // uint256 deadline
                params.deadline
            );
    }

    function _exchangeOutFromVault(
        StandardExchangeSwapSingleTokenHookParams calldata params,
        uint256 amount,
        uint256 limit,
        address recipient
    ) internal returns (uint256 amountCalculated) {
        // Placeholder to avoid compilation errors.
        return params.tokenInVault
            .exchangeOut(
                // IERC20 tokenIn,
                IERC20(address(params.tokenIn)),
                // uint256 maxAmountIn,
                limit,
                // IERC20 tokenOut,
                IERC20(address(params.tokenInVault)),
                // uint256 amountOut,
                amount,
                // address recipient,
                recipient,
                // bool pretransferred
                true,
                // uint256 deadline
                params.deadline
            );
    }
}

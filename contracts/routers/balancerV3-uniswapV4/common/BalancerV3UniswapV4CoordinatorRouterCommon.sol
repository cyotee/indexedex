// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterRepo
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterRepo.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterCommon
/// @notice Shared constants, validation, funding helpers for Coordinator targets.
abstract contract BalancerV3UniswapV4CoordinatorRouterCommon is ReentrancyLockModifiers, MultiStepOwnableModifiers {
    using SafeERC20 for IERC20;
    using BetterEfficientHashLib for bytes;
    using BalancerV3UniswapV4CoordinatorRouterRepo for *;

    string internal constant _WITNESS_TYPE_STRING =
        "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)";

    bytes32 internal constant _WITNESS_TYPEHASH = keccak256(
        "Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)"
    );

    uint48 internal constant _PERMIT2_EXPIRATION_BUFFER = 1 hours;

    function _permit2() internal view returns (IPermit2) {
        return Permit2AwareRepo._permit2();
    }

    function _weth() internal view returns (IWETH) {
        return WETHAwareRepo._weth();
    }

    function _validateParams(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params) internal view {
        if (block.timestamp > params.deadline) {
            revert IBalancerV3UniswapV4CoordinatorRouter.ExpiredDeadline();
        }
        if (params.recipient == address(0)) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidRecipient();
        }
        if (params.steps.length == 0) {
            revert IBalancerV3UniswapV4CoordinatorRouter.EmptyRoute();
        }
        if (params.steps[params.steps.length - 1].tokenOut != params.tokenOut) {
            revert IBalancerV3UniswapV4CoordinatorRouter.TokenOutMismatch();
        }
        if (params.ethIn && params.tokenIn != address(_weth())) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn();
        }
        if (params.ethOut && params.tokenOut != address(_weth())) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidEthOut();
        }
        uint256 len = params.steps.length;
        for (uint256 i; i < len; ++i) {
            if (!BalancerV3UniswapV4CoordinatorRouterRepo._isRouterAllowed(params.steps[i].router)) {
                revert IBalancerV3UniswapV4CoordinatorRouter.RouterNotAllowed(params.steps[i].router);
            }
        }
    }

    function _stepsHash(IBalancerV3UniswapV4CoordinatorRouter.RouteStep[] calldata steps)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(steps));
    }

    function _witnessHash(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params)
        internal
        pure
        returns (bytes32)
    {
        return abi.encode(
                _WITNESS_TYPEHASH,
                params.recipient,
                params.tokenIn,
                params.amountIn,
                params.tokenOut,
                params.minAmountOut,
                params.deadline,
                params.ethIn,
                params.ethOut,
                keccak256(abi.encode(params.steps))
            )._hash();
    }

    function _approvePermit2Child(address token, address child, uint256 amount) internal {
        // Child pulls via Permit2: need ERC-20 allowance Coordinator→Permit2 + Permit2 allowance→child.
        IERC20(token).forceApprove(address(_permit2()), amount);
        uint48 expiration = uint48(block.timestamp + _PERMIT2_EXPIRATION_BUFFER);
        _permit2().approve(token, child, uint160(amount), expiration);
    }

    function _clearPermit2Child(address token, address child) internal {
        _permit2().approve(token, child, 0, 0);
        IERC20(token).forceApprove(address(_permit2()), 0);
    }

    function _approveErc20Child(address token, address child, uint256 amount) internal {
        IERC20(token).forceApprove(child, amount);
    }

    function _clearErc20Child(address token, address child) internal {
        IERC20(token).forceApprove(child, 0);
    }
}

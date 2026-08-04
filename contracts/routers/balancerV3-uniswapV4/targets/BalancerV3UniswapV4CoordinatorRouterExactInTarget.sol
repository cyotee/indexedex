// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@crane/contracts/utils/SafeERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IBalancerV3UniswapV4CoordinatorRouter
} from "contracts/routers/balancerV3-uniswapV4/interfaces/IBalancerV3UniswapV4CoordinatorRouter.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterCommon
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol";
import {
    BalancerV3UniswapV4CoordinatorRouterRepo
} from "contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterRepo.sol";
import {
    StockBalancerV3RouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol";
import {
    StockBalancerV3BatchRouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3BatchRouterAdapter.sol";
import {IndexedExSERouterAdapter} from "contracts/routers/balancerV3-uniswapV4/adapters/IndexedExSERouterAdapter.sol";
import {
    UniswapV4UniversalRouterAdapter
} from "contracts/routers/balancerV3-uniswapV4/adapters/UniswapV4UniversalRouterAdapter.sol";

/// @title BalancerV3UniswapV4CoordinatorRouterExactInTarget
abstract contract BalancerV3UniswapV4CoordinatorRouterExactInTarget is BalancerV3UniswapV4CoordinatorRouterCommon {
    using SafeERC20 for IERC20;

    struct HopState {
        address currentToken;
        uint256 amountForStep;
        uint256 amountIn;
    }

    function swapExactInWithPermit(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external payable nonReentrant returns (uint256 amountOut) {
        if (params.ethIn) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn();
        _validateParams(params);
        if (permit.permitted.token != params.tokenIn) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidPermitWitness();
        }
        _pullPermit(params, permit, signature);
        amountOut = _executeRoute(params, params.amountIn);
    }

    function swapExactInEth(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        if (!params.ethIn) revert IBalancerV3UniswapV4CoordinatorRouter.InvalidEthIn();
        _validateParams(params);
        if (msg.value < params.amountIn) revert IBalancerV3UniswapV4CoordinatorRouter.InsufficientEth();
        _weth().deposit{value: params.amountIn}();
        if (msg.value > params.amountIn) {
            _refundEth(msg.sender, msg.value - params.amountIn);
        }
        amountOut = _executeRoute(params, params.amountIn);
    }

    function _pullPermit(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params,
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) private {
        uint256 balBefore = IERC20(params.tokenIn).balanceOf(address(this));
        ISignatureTransfer.SignatureTransferDetails memory td =
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: params.amountIn});
        _permit2()
            .permitWitnessTransferFrom(permit, td, msg.sender, _witnessHash(params), _WITNESS_TYPE_STRING, signature);
        uint256 received = IERC20(params.tokenIn).balanceOf(address(this)) - balBefore;
        if (received < params.amountIn) {
            revert IBalancerV3UniswapV4CoordinatorRouter.InvalidAmount(params.tokenIn, params.amountIn, received);
        }
    }

    function _refundEth(address to, uint256 amount) private {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH_REFUND");
    }

    function _executeRoute(IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        HopState memory hop = HopState({currentToken: params.tokenIn, amountForStep: amountIn, amountIn: amountIn});
        uint256 len = params.steps.length;
        for (uint256 i; i < len; ++i) {
            hop.amountForStep = _runStep(params, i, hop.currentToken, hop.amountForStep);
            hop.currentToken = params.steps[i].tokenOut;
        }
        amountOut = hop.amountForStep;
        _payout(params, hop.amountIn, amountOut, len);
    }

    function _runStep(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params,
        uint256 i,
        address currentToken,
        uint256 amountForStep
    ) private returns (uint256 deltaOut) {
        if (amountForStep == 0) revert IBalancerV3UniswapV4CoordinatorRouter.ZeroAmount();
        IBalancerV3UniswapV4CoordinatorRouter.RouteStep calldata step = params.steps[i];
        IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind =
            BalancerV3UniswapV4CoordinatorRouterRepo._routerKind(step.router);

        uint256 balBefore = IERC20(step.tokenOut).balanceOf(address(this));
        _fundChild(kind, step.router, currentToken, amountForStep);
        _dispatchExecute(kind, step.router, amountForStep, params.deadline, step.data);
        _clearChild(kind, step.router, currentToken);
        deltaOut = IERC20(step.tokenOut).balanceOf(address(this)) - balBefore;

        if (step.minAmountOut != 0 && deltaOut < step.minAmountOut) {
            revert IBalancerV3UniswapV4CoordinatorRouter.MinAmountOutNotMet(step.minAmountOut, deltaOut);
        }
        emit IBalancerV3UniswapV4CoordinatorRouter.StepExecuted(i, step.router, step.tokenOut, deltaOut);
    }

    function _payout(
        IBalancerV3UniswapV4CoordinatorRouter.SwapExactInParams calldata params,
        uint256 amountIn,
        uint256 amountOut,
        uint256 stepCount
    ) private {
        if (amountOut < params.minAmountOut) {
            revert IBalancerV3UniswapV4CoordinatorRouter.MinAmountOutNotMet(params.minAmountOut, amountOut);
        }
        if (IERC20(params.tokenOut).balanceOf(address(this)) < amountOut) {
            revert IBalancerV3UniswapV4CoordinatorRouter.MinAmountOutNotMet(amountOut, 0);
        }
        if (params.ethOut) {
            _weth().withdraw(amountOut);
            (bool ok,) = params.recipient.call{value: amountOut}("");
            require(ok, "ETH_SEND");
        } else {
            IERC20(params.tokenOut).safeTransfer(params.recipient, amountOut);
        }
        emit IBalancerV3UniswapV4CoordinatorRouter.RouteExecuted(
            msg.sender, params.recipient, params.tokenIn, params.tokenOut, amountIn, amountOut, stepCount
        );
    }

    function _fundChild(
        IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind,
        address child,
        address token,
        uint256 amount
    ) private {
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter) {
            _approveErc20Child(token, child, amount);
        } else {
            _approvePermit2Child(token, child, amount);
        }
    }

    function _clearChild(IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind, address child, address token) private {
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter) {
            _clearErc20Child(token, child);
        } else {
            _clearPermit2Child(token, child);
        }
    }

    function _dispatchExecute(
        IBalancerV3UniswapV4CoordinatorRouter.AdapterKind kind,
        address router,
        uint256 amountIn,
        uint256 deadline,
        bytes memory data
    ) private {
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3Router) {
            StockBalancerV3RouterAdapter.execute(router, amountIn, deadline, data);
            return;
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.StockBalancerV3BatchRouter) {
            StockBalancerV3BatchRouterAdapter.execute(router, amountIn, deadline, data);
            return;
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.IndexedExSERouter) {
            IndexedExSERouterAdapter.execute(router, amountIn, deadline, data);
            return;
        }
        if (kind == IBalancerV3UniswapV4CoordinatorRouter.AdapterKind.UniswapV4UniversalRouter) {
            UniswapV4UniversalRouterAdapter.execute(router, amountIn, deadline, data);
            return;
        }
        revert IBalancerV3UniswapV4CoordinatorRouter.InvalidRouterKind();
    }

    receive() external payable {}
}

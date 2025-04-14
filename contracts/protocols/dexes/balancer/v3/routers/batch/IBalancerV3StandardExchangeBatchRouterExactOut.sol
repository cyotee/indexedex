// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    IBalancerV3StandardExchangeBatchRouterTypes
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterTypes.sol";

interface IBalancerV3StandardExchangeBatchRouterExactOut is IBalancerV3StandardExchangeBatchRouterTypes {
    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapPathExactAmountOut {
        IERC20 tokenIn;
        // for each step:
        // If tokenIn == pool, use removeLiquidity SINGLE_TOKEN_EXACT_OUT.
        // If tokenOut == pool, use addLiquidity SINGLE_TOKEN_EXACT_OUT.
        SESwapPathStep[] steps;
        uint256 maxAmountIn;
        uint256 exactAmountOut;
    }

    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapExactOutHookParams {
        address sender;
        SESwapPathExactAmountOut[] paths;
        uint256 deadline;
        bool wethIsEth;
        bytes userData;
    }

    event StrategyVaultExchangeOut(
        address indexed vault, IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    function swapExactOut(
        SESwapPathExactAmountOut[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn);

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
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn);

    function swapExactOutHook(SESwapExactOutHookParams calldata params)
        external
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn);

    function querySwapExactOut(SESwapPathExactAmountOut[] memory paths, address sender, bytes calldata userData)
        external
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn);

    function querySwapExactOutHook(SESwapExactOutHookParams calldata params)
        external
        returns (uint256[] memory pathAmountsIn, address[] memory tokensIn, uint256[] memory amountsIn);
}

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

interface IBalancerV3StandardExchangeBatchRouterExactIn is IBalancerV3StandardExchangeBatchRouterTypes {
    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapPathExactAmountIn {
        IERC20 tokenIn;
        SESwapPathStep[] steps;
        uint256 exactAmountIn;
        uint256 minAmountOut;
    }

    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapExactInHookParams {
        address sender;
        SESwapPathExactAmountIn[] paths;
        uint256 deadline;
        bool wethIsEth;
        bytes userData;
    }

    event StrategyVaultExchangeIn(
        address indexed vault, IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    function swapExactIn(
        SESwapPathExactAmountIn[] memory paths,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        external
        payable
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut);

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
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut);

    function swapExactInHook(SESwapExactInHookParams calldata params)
        external
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut);

    function querySwapExactIn(SESwapPathExactAmountIn[] memory paths, address sender, bytes calldata userData)
        external
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut);

    function querySwapExactInHook(SESwapExactInHookParams calldata params)
        external
        returns (uint256[] memory pathAmountsOut, address[] memory tokensOut, uint256[] memory amountsOut);
}

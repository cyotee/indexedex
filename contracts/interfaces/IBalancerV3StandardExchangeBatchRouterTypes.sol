// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface IBalancerV3StandardExchangeBatchRouterTypes {
    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapStepLocals {
        bool isFirstStep;
        bool isLastStep;
        IERC20 stepTokenIn;
        uint256 stepAmountIn;
    }

    /// forge-lint: disable-next-line(pascal-case-struct)
    struct SESwapPathStep {
        address pool;
        IERC20 tokenOut;
        // If true, the "pool" is an ERC4626 Buffer. Used to wrap/unwrap tokens if pool doesn't have enough liquidity.
        bool isBuffer;
        bool isStrategyVault;
    }

    error StrategyVaultSwapFailed(address vault, uint256 amountOut, uint256 minAmountOut);
    error StrategyVaultMaxAmountExceeded(address vault, uint256 amountIn, uint256 maxAmountIn);

    // Batch permit errors
    error PermitPathLengthMismatch(uint256 paths, uint256 permits, uint256 signatures);
    error PermitPathTokenMismatch(uint256 index, address expectedToken, address permitToken);
    error PermitPathAmountInsufficient(uint256 index, uint256 requiredAmount, uint256 permitAmount);

}

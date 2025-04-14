// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20 as OZIERC20} from "@crane/contracts/interfaces/IERC20.sol";

interface ISeigniorageDETFErrors {
    /* ---------------------------------------------------------------------- */
    /*                                 Errors                                 */
    /* ---------------------------------------------------------------------- */

    error NotBondHolder(address holder, address caller);

    error ExpectedBptNotReceived(uint256 expectedBpt, uint256 actualBpt);

    error ActualBptNotReceived(uint256 expectedBpt, uint256 actualBpt);

    error NotNFTVault(address caller);

    error SelfExpectedAmountNotReceived(uint256 expectedAmount, uint256 actualAmount);

    error ReserveExpectedAmountNotReceived(uint256 expectedAmount, uint256 actualAmount);

    error RateTargetAmountNotReceived(uint256 expectedAmount, uint256 actualAmount);

    error PriceAbovePeg(uint256 currentPrice, uint256 pegPrice);

    error PriceBelowPeg(uint256 currentPrice, uint256 pegPrice);

    error TransferAmountNotReceived(uint256 expected, uint256 actual);

    /* ---------------------------------------------------------------------- */
    /*                                 Events                                 */
    /* ---------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------- */
    /*                                Functions                               */
    /* ---------------------------------------------------------------------- */

    // function reserveVaultRateTarget() external view returns (OZIERC20);

    // function underwrite(OZIERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool pretransferred)
    //     external
    //     returns (uint256 tokenId);

    // function redeem(uint256 tokenId, address recipient) external returns (uint256 amountOut);

    // function previewClaimLiquidity(uint256 lpAmount) external view returns (uint256 liquidityOut);

    // function claimLiquidity(uint256 lpAmount, address recipient) external returns (uint256 extractedLiquidity);

    // function withdrawRewards(uint256 tokenId, address recipient) external returns (uint256 rewards);
}

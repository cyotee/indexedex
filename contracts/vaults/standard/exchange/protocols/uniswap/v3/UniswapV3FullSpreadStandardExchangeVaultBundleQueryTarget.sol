// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {UniswapV3FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV3FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo as PoolRepo} from "./UniswapV3FullSpreadStandardExchangeVaultPoolAwareRepo.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "../v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget {
    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn_, address tokenOut_)
        external view returns (uint256 amountOut_, uint256[] memory refunded_)
    {
        if (amountsIn_.length != 2) revert IStandardExchangeBundleIn.AmountsLengthMismatch();
        if (tokenOut_ != address(this)) revert IStandardExchangeBundleIn.ExchangeBundleInForSingleOutNotAvailable();
        Planner.Plan memory plan_ = Planner.planBundleIn(amountsIn_[0], amountsIn_[1]);
        refunded_ = new uint256[](2);
        refunded_[0] = plan_.refund0;
        refunded_[1] = plan_.refund1;
        return (plan_.failed ? 0 : plan_.amountOut, refunded_);
    }

    function previewExchangeBundleOut(address tokenIn_, uint256 amountIn_, address[] calldata tokensOut_)
        external view returns (uint256[] memory amountsOut_, uint256 refunded_)
    {
        if (tokensOut_.length != 2) revert IStandardExchangeBundleOut.TokenAmountsLengthMismatch();
        if (tokensOut_[0] == tokensOut_[1]) revert IStandardExchangeBundleOut.DuplicateOutput();
        address token0_ = PoolRepo._uniswapV3Pool().token0();
        address token1_ = PoolRepo._uniswapV3Pool().token1();
        if (tokenIn_ != address(this) || !((tokensOut_[0] == token0_ && tokensOut_[1] == token1_)
            || (tokensOut_[0] == token1_ && tokensOut_[1] == token0_))) {
            revert IStandardExchangeBundleOut.ExchangeBundleOutNotAvailable();
        }
        Planner.Plan memory plan_ = Planner.planBundleOut(amountIn_);
        amountsOut_ = new uint256[](2);
        if (!plan_.failed) {
            uint256 index0_ = tokensOut_[0] == token0_ ? 0 : 1;
            amountsOut_[index0_] = plan_.out0;
            amountsOut_[1 - index0_] = plan_.out1;
        }
        return (amountsOut_, 0);
    }
}

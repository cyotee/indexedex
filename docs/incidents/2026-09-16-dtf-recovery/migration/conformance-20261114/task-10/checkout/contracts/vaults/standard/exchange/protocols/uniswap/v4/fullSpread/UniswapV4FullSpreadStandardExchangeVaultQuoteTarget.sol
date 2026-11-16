// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {UniswapV4SinglePositionAwareRepo} from "@crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4SinglePositionAwareRepo.sol";
import {UniswapV4FullSpreadStandardExchangeVaultComponentBindings} from "./UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol";
import {UniswapV4FullSpreadStandardExchangeVaultPlanner as Planner} from "./UniswapV4FullSpreadStandardExchangeVaultPlanner.sol";
import {UniswapV4FullSpreadStandardExchangeVaultTypes as Types} from "./UniswapV4FullSpreadStandardExchangeVaultTypes.sol";

contract UniswapV4FullSpreadStandardExchangeVaultQuoteTarget is UniswapV4FullSpreadStandardExchangeVaultComponentBindings {
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded)
    {
        Types.Plan memory plan_ = Planner.planIn(address(tokenIn), amountIn, address(tokenOut));
        if (plan_.kind == Types.Kind.Unsupported || plan_.failed) return (0, 0);
        return (plan_.amountOut, plan_.amountRefunded);
    }

    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded)
    {
        amountsRefunded = new uint256[](amountsIn.length == 2 ? 2 : amountsIn.length);
        if (amountsIn.length != 2 || tokenOut != address(this)) return (0, amountsRefunded);
        Types.Plan memory plan_ = Planner.planBundleIn(amountsIn[0], amountsIn[1]);
        if (plan_.failed) return (0, amountsRefunded);
        amountsRefunded[0] = plan_.refund0;
        amountsRefunded[1] = plan_.refund1;
        return (plan_.amountOut, amountsRefunded);
    }

    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256)
    {
        amountsOut = new uint256[](tokensOut.length);
        (address face0_, address face1_) = _faces();
        bool faces_ = tokensOut.length == 2
            && ((tokensOut[0] == face0_ && tokensOut[1] == face1_) || (tokensOut[0] == face1_ && tokensOut[1] == face0_));
        if (tokenIn != address(this) || !faces_ || tokensOut[0] == tokensOut[1]) return (amountsOut, 0);
        Types.Plan memory plan_ = Planner.planBundleOut(amountIn);
        if (tokensOut[0] == face0_) {
            amountsOut[0] = plan_.out0;
            amountsOut[1] = plan_.out1;
        } else {
            amountsOut[0] = plan_.out1;
            amountsOut[1] = plan_.out0;
        }
        return (amountsOut, 0);
    }

    function _faces() internal view returns (address face0_, address face1_) {
        PoolKey memory key_ = UniswapV4SinglePositionAwareRepo._poolKey();
        address weth_ = address(WETHAwareRepo._weth());
        face0_ = Currency.unwrap(key_.currency0);
        if (face0_ == address(0)) face0_ = weth_;
        face1_ = Currency.unwrap(key_.currency1);
        if (face1_ == address(0)) face1_ = weth_;
    }
}

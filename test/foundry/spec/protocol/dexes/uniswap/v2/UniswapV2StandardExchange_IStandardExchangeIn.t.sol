// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {TestBase_UniswapV2} from "@crane/contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2.sol";
import {
    TestBase_UniswapV2StandardExchange_IStandardExchangeIn
} from "test/foundry/spec/protocol/dexes/uniswap/v2/TestBase_UniswapV2StandardExchange_IStandardExchangeIn.sol";

contract UniswapV2StandardExchange_IStandardExchangeIn is TestBase_UniswapV2StandardExchange_IStandardExchangeIn {
    function sortedReserves(address tokenA_, IUniswapV2Pair pair_)
        internal
        view
        virtual
        override
        returns (uint256 reserveA, uint256 reserveB)
    {
        return TestBase_UniswapV2.sortedReserves(tokenA_, pair_);
    }

    /**
     * @notice Add balanced liquidity to a Uniswap V2 pool for strategy vault testing.
     * @dev Specify either amountADesired or amountBDesired (or both). If one is zero, the function computes the required amount for a balanced deposit using ConstProdUtils.
     * @param tokenA_ Address of token A
     * @param tokenB_ Address of token B
     * @param amountADesired_ Desired amount of token A (set to 0 if basing on token B)
     * @param amountBDesired_ Desired amount of token B (set to 0 if basing on token A)
     * @param recipient_ Address to receive the LP tokens
     * @return amountA Actual amount of token A deposited
     * @return amountB Actual amount of token B deposited
     * @return liquidity Amount of LP tokens minted
     *
     * Example usage:
     * (amountA, amountB, liquidity) = addBalancedUniswapLiquidity(address(tokenA), address(tokenB), 10_000e18, 0, address(this));
     */
    function addBalancedUniswapLiquidity(
        IUniswapV2Pair pair_,
        address tokenA_,
        address tokenB_,
        uint256 amountADesired_,
        uint256 amountBDesired_,
        address recipient_
    ) public virtual override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        return TestBase_UniswapV2.addBalancedUniswapLiquidity(
                pair_, tokenA_, tokenB_, amountADesired_, amountBDesired_, recipient_
            );
    }
}

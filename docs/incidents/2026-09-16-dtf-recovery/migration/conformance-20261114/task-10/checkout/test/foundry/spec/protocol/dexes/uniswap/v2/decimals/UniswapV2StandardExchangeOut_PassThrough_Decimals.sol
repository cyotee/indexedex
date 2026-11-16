// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_Decimals.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title UniswapV2StandardExchangeOut_PassThrough_Decimals
 * @notice previewExchangeOut vs exchangeOut pass-through on combo decimals.
 * @dev After pair sort, token0/token1 may swap pairToken vs other. Amounts are raw units of the token that moved.
 */
abstract contract UniswapV2StandardExchangeOut_PassThrough_Decimals is TestBase_UniswapV2StandardExchange_Decimals {
    function _safeAmountOut(IUniswapV2Pair pair, address tokenIn, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        uint256 reserveOut = tokenIn == token0 ? reserve1 : reserve0;
        return amountOut > reserveOut / 100 ? reserveOut / 100 : amountOut;
    }

    function test_exchangeOut_passthrough_balanced_token0ToToken1() public {
        _test_exchangeOut_passthrough(PoolConfig.Balanced, true);
    }

    function test_exchangeOut_passthrough_balanced_token1ToToken0() public {
        _test_exchangeOut_passthrough(PoolConfig.Balanced, false);
    }

    function test_exchangeOut_passthrough_unbalanced_token0ToToken1() public {
        _test_exchangeOut_passthrough(PoolConfig.Unbalanced, true);
    }

    function test_exchangeOut_passthrough_unbalanced_token1ToToken0() public {
        _test_exchangeOut_passthrough(PoolConfig.Unbalanced, false);
    }

    function test_exchangeOut_passthrough_extreme_token0ToToken1() public {
        _test_exchangeOut_passthrough(PoolConfig.Extreme, true);
    }

    function test_exchangeOut_passthrough_extreme_token1ToToken0() public {
        _test_exchangeOut_passthrough(PoolConfig.Extreme, false);
    }

    function _test_exchangeOut_passthrough(PoolConfig config, bool token0ToToken1) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IUniswapV2Pair pair = _getPool(config);
        MintableERC20Decimals token0 = MintableERC20Decimals(pair.token0());
        MintableERC20Decimals token1 = MintableERC20Decimals(pair.token1());

        MintableERC20Decimals tokenInStub = token0ToToken1 ? token0 : token1;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = token0ToToken1 ? IERC20(address(token1)) : IERC20(address(token0));

        uint256 amountOut = _safeAmountOut(pair, address(tokenInStub), _uToken(address(tokenOut), 10));
        address recipient = makeAddr("recipient");

        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");

        tokenInStub.mint(address(this), expectedAmountIn);
        tokenInStub.approve(address(vault), expectedAmountIn);

        uint256 amountIn = vault.exchangeOut(
            tokenIn, expectedAmountIn, tokenOut, amountOut, recipient, false, _deadline()
        );

        assertEq(amountIn, expectedAmountIn, "AmountIn from execution must match preview");
        assertGe(tokenOut.balanceOf(recipient), amountOut, "Recipient must receive at least amountOut");
    }
}

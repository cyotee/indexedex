// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/**
 * @title UniswapV2StandardExchangeOut_PassThrough_Test
 * @notice Tests for previewExchangeOut vs exchangeOut parity in pass-through ExactOut swaps.
 * @dev Tests that previewExchangeOut returns the exact amountIn needed for exchangeOut
 *      to execute successfully for pass-through swaps (tokenA -> tokenB where both are
 *      pool constituents).
 */
contract UniswapV2StandardExchangeOut_PassThrough_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                            Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    /// @dev Get a safe amountOut that is within pool reserves for the given direction.
    function _safeAmountOut(IUniswapV2Pair pair, ERC20PermitMintableStub tokenIn, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        uint256 reserveOut = address(tokenIn) == token0 ? reserve1 : reserve0;
        // Use 1% of the output reserve to stay well within bounds
        return amountOut > reserveOut / 100 ? reserveOut / 100 : amountOut;
    }

    /* ---------------------------------------------------------------------- */
    /*                   Preview vs Execution (Exact-Out)                       */
    /* ---------------------------------------------------------------------- */

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
        ERC20PermitMintableStub token0 = ERC20PermitMintableStub(pair.token0());
        ERC20PermitMintableStub token1 = ERC20PermitMintableStub(pair.token1());

        ERC20PermitMintableStub tokenInStub = token0ToToken1 ? token0 : token1;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = token0ToToken1 ? IERC20(address(token1)) : IERC20(address(token0));

        uint256 amountOut = _safeAmountOut(pair, tokenInStub, 10e18);
        address recipient = makeAddr("recipient");

        // Preview to get expected amountIn
        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");

        // Mint and approve
        tokenInStub.mint(address(this), expectedAmountIn);
        tokenInStub.approve(address(vault), expectedAmountIn);

        // Execute
        uint256 amountIn = vault.exchangeOut(
            tokenIn,
            expectedAmountIn,
            tokenOut,
            amountOut,
            recipient,
            false, // not pretransferred
            _deadline()
        );

        // Assert preview matches execution
        assertEq(amountIn, expectedAmountIn, "AmountIn from execution must match preview");
        assertGe(tokenOut.balanceOf(recipient), amountOut, "Recipient must receive at least amountOut");
    }
}

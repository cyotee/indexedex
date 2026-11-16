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
 * @title UniswapV2Vault_RouterRefund_Decimals
 * @notice exchangeOut pretransfer/refund on combo decimals. Amounts are raw units of token0/token1 after sort.
 */
abstract contract UniswapV2Vault_RouterRefund_Decimals is TestBase_UniswapV2StandardExchange_Decimals {
    /// @notice token0 → token1 exact-out with pretransferred=true. amountOut is 1 human of token1.
    function test_exchangeOut_withPretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        MintableERC20Decimals token0 = MintableERC20Decimals(pair.token0());
        MintableERC20Decimals token1 = MintableERC20Decimals(pair.token1());

        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));

        uint256 amountOut = _uToken(address(token1), 1);
        address recipient = makeAddr("recipient");

        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");

        token0.mint(address(this), expectedAmountIn);
        token0.transfer(address(vault), expectedAmountIn);

        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn, expectedAmountIn, tokenOut, amountOut, recipient, true, _deadline()
        );

        assertEq(actualAmountIn, expectedAmountIn, "AmountIn must match");
        assertGe(token1.balanceOf(recipient), amountOut, "Recipient must receive amountOut");
    }

    /// @notice exchangeOut with a contract recipient. Refund of excess tokenIn goes to msg.sender.
    function test_exchangeOut_withContractRecipient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        MintableERC20Decimals token0 = MintableERC20Decimals(pair.token0());
        MintableERC20Decimals token1 = MintableERC20Decimals(pair.token1());

        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));

        uint256 amountOut = _uToken(address(token1), 1);
        address contractRecipient = address(new Univ2DecimalsNonReceivingContract());

        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedAmountIn, 0, "Preview must return non-zero amountIn");

        token0.mint(address(this), expectedAmountIn);
        token0.transfer(address(vault), expectedAmountIn);

        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn, expectedAmountIn, tokenOut, amountOut, contractRecipient, true, _deadline()
        );

        assertEq(actualAmountIn, expectedAmountIn, "AmountIn must match");
    }

    /// @notice Refund excess tokenIn (0.1 human of token0) to msg.sender.
    function test_exchangeOut_refundExcess() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        MintableERC20Decimals token0 = MintableERC20Decimals(pair.token0());
        MintableERC20Decimals token1 = MintableERC20Decimals(pair.token1());

        IERC20 tokenIn = IERC20(address(token0));
        IERC20 tokenOut = IERC20(address(token1));

        uint256 amountOut = _uToken(address(token1), 1);
        address recipient = makeAddr("recipient");

        uint256 expectedAmountIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);

        uint256 excessAmount = expectedAmountIn + _from18(address(token0), 1e17);
        token0.mint(address(this), excessAmount);
        token0.transfer(address(vault), excessAmount);

        uint256 actualAmountIn = vault.exchangeOut(
            tokenIn, excessAmount, tokenOut, amountOut, recipient, true, _deadline()
        );

        assertEq(actualAmountIn, expectedAmountIn, "AmountIn should be actual needed");
        assertGe(token0.balanceOf(address(this)), excessAmount - expectedAmountIn, "Should receive refund");
    }
}

/// @dev Distinct name from gold `NonReceivingContract` to avoid compilation clash.
contract Univ2DecimalsNonReceivingContract {}

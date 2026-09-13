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
 * @title UniswapV2StandardExchangeIn_SlippageProtection_Decimals
 * @notice minAmountOut enforcement on combo decimals. Amounts are raw units of the token that moved.
 * @dev After pair sort, token0/token1 may swap pairToken vs other; `_uToken` uses that token's decimals.
 */
abstract contract UniswapV2StandardExchangeIn_SlippageProtection_Decimals is
    TestBase_UniswapV2StandardExchange_Decimals
{
    function test_Route1Swap_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 amountIn = _uToken(token0, 1);
        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route1Swap_slippage_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 amountIn = _uToken(token0, 1);
        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), amountIn, IERC20(token1), preview + 1, makeAddr("recipient"), false, _deadline()
        );
    }

    function test_Route2ZapIn_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        IERC20 lpToken = IERC20(address(pair));

        uint256 amountIn = _uToken(token0, 1);
        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, lpToken);
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(IERC20(token0), amountIn, lpToken, preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route2ZapIn_slippage_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        IERC20 lpToken = IERC20(address(pair));

        uint256 amountIn = _uToken(token0, 1);
        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, lpToken);

        vm.expectRevert();
        vault.exchangeIn(IERC20(token0), amountIn, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    function test_Route3ZapOut_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        address token0 = pair.token0();

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, IERC20(token0));
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(lpToken, lpAmount, IERC20(token0), preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route3ZapOut_slippage_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        address token0 = pair.token0();

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, IERC20(token0));

        vm.expectRevert();
        vault.exchangeIn(lpToken, lpAmount, IERC20(token0), preview + 1, makeAddr("recipient"), false, _deadline());
    }

    function test_Route5VaultWithdrawal_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, lpToken);
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(vaultToken, shares, lpToken, preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route5VaultWithdrawal_slippage_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, lpToken);

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    function test_Route7ZapOutWithdrawal_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        address token0 = pair.token0();

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, IERC20(token0));
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(vaultToken, shares, IERC20(token0), preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route7ZapOutWithdrawal_slippage_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        address token0 = pair.token0();

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, IERC20(token0));

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, IERC20(token0), preview + 1, makeAddr("recipient"), false, _deadline());
    }
}

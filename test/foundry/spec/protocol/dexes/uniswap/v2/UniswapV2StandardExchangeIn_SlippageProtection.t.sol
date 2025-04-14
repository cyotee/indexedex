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
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/**
 * @title UniswapV2StandardExchangeIn_SlippageProtection_Test
 * @notice Tests minAmountOut enforcement across all UniswapV2 exchange-in routes.
 */
contract UniswapV2StandardExchangeIn_SlippageProtection_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                  Route 1: Pass-through Swap (token→token)              */
    /* ---------------------------------------------------------------------- */

    function test_Route1Swap_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 amountIn = 1e18;
        deal(token0, address(this), amountIn);
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

        uint256 amountIn = 1e18;
        deal(token0, address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), amountIn, IERC20(token1), preview + 1, makeAddr("recipient"), false, _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                Route 2: Pass-through ZapIn (token→LP)                  */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        address token0 = pair.token0();
        IERC20 lpToken = IERC20(address(pair));

        uint256 amountIn = 1e18;
        deal(token0, address(this), amountIn);
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

        uint256 amountIn = 1e18;
        deal(token0, address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, lpToken);

        vm.expectRevert();
        vault.exchangeIn(IERC20(token0), amountIn, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*               Route 3: Pass-through ZapOut (LP→token)                  */
    /* ---------------------------------------------------------------------- */

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

    /* ---------------------------------------------------------------------- */
    /*           Route 4: Underlying Pool Vault Deposit (LP→vault)            */
    /* ---------------------------------------------------------------------- */

    // Already tested in UniswapV2StandardExchangeIn_VaultDeposit.t.sol

    /* ---------------------------------------------------------------------- */
    /*         Route 5: Underlying Pool Vault Withdrawal (vault→LP)           */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdrawal_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        // First deposit to get vault shares
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        // Now withdraw with slippage check
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

        // First deposit to get vault shares
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        // Now try to withdraw with impossible minAmountOut
        uint256 preview = vault.previewExchangeIn(vaultToken, shares, lpToken);

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*            Route 6: ZapIn Vault Deposit (token→vault)                  */
    /* ---------------------------------------------------------------------- */

    // Already tested in UniswapV2StandardExchangeIn_VaultDeposit.t.sol (same pattern)

    /* ---------------------------------------------------------------------- */
    /*          Route 7: ZapOut Vault Withdrawal (vault→token)                */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdrawal_slippage_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        address token0 = pair.token0();

        // First deposit LP to get vault shares
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        // Now ZapOut withdraw vault→token with slippage check
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

        // First deposit LP to get vault shares
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        // Now try ZapOut with impossible minAmountOut
        uint256 preview = vault.previewExchangeIn(vaultToken, shares, IERC20(token0));

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, IERC20(token0), preview + 1, makeAddr("recipient"), false, _deadline());
    }
}

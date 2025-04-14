// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                     */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICLPool} from "@crane/contracts/protocols/dexes/aerodrome/slipstream/interfaces/ICLPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                   */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_SlipstreamFork} from "./TestBase_SlipstreamFork.sol";

/**
 * @title SlipstreamFork_ZapOutWithdraw_Test
 * @notice Fork tests for Route 7: Vault shares to single token via withdraw + zap.
 * @dev Tests the complete flow: vault shares -> burn position -> proportional token withdrawal.
 * 
 *      This tests the concentrated liquidity vault withdrawal logic:
 *      - Withdraws proportional amounts from the double-sided CL position
 *      - Burns LP tokens and returns single token to recipient
 *      - Fees are collected and included in withdrawal amount
 */
contract SlipstreamFork_ZapOutWithdraw_Test is TestBase_SlipstreamFork {
    /* ---------------------------------------------------------------------- */
    /*                              Setup Helper                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Deposits tokens into vault to get shares for withdrawal tests.
     */
    function _seedVaultWithShares(VaultConfig config, uint256 tokenAmount) internal returns (uint256 shares) {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");
        
        address token0 = pool.token0();
        IERC20 tokenIn = IERC20(token0);
        
        deal(token0, address(this), tokenAmount);
        tokenIn.approve(address(vault), tokenAmount);
        
        shares = vault.exchangeIn(
            tokenIn, tokenAmount, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    // function test_ZapOutWithdraw_execVsPreview_WETH_USDC_toToken0() public {
    //     _test_execVsPreview(VaultConfig.WethUsdc, true);
    // }

    // function test_ZapOutWithdraw_execVsPreview_WETH_USDC_toToken1() public {
    //     _test_execVsPreview(VaultConfig.WethUsdc, false);
    // }

    // function test_ZapOutWithdraw_execVsPreview_cbBTC_WETH_toToken0() public {
    //     _test_execVsPreview(VaultConfig.CbBtcWeth, true);
    // }

    // function test_ZapOutWithdraw_execVsPreview_cbBTC_WETH_toToken1() public {
    //     _test_execVsPreview(VaultConfig.CbBtcWeth, false);
    // }

    function _test_execVsPreview(VaultConfig config, bool toToken0) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");

        // Seed vault with shares first
        uint256 shares = _seedVaultWithShares(config, 1e18);
        require(shares > 0, "Insufficient shares");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toToken0 ? IERC20(pool.token0()) : IERC20(pool.token1());

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        // Approve vault to burn shares
        vault.approve(address(vault), sharesToWithdraw);

        // Get preview - shares to token
        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, tokenOut);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, block.timestamp + 1 hours);

        assertEq(tokenOutAmount, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview token amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    // function test_ZapOutWithdraw_balanceChanges_WETH_USDC_toToken0() public {
    //     _test_balanceChanges(VaultConfig.WethUsdc, true);
    // }

    // function test_ZapOutWithdraw_balanceChanges_cbBTC_WETH_toToken0() public {
    //     _test_balanceChanges(VaultConfig.CbBtcWeth, true);
    // }

    function _test_balanceChanges(VaultConfig config, bool toToken0) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");

        // Seed vault
        uint256 shares = _seedVaultWithShares(config, 1e18);

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toToken0 ? IERC20(pool.token0()) : IERC20(pool.token1());

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 senderSharesBefore = vault.balanceOf(address(this));
        uint256 recipientTokenBefore = tokenOut.balanceOf(recipient);
        uint256 totalSupplyBefore = vault.totalSupply();

        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, block.timestamp + 1 hours);

        // Sender shares decreased
        assertEq(vault.balanceOf(address(this)), senderSharesBefore - sharesToWithdraw, "Sender shares should decrease");
        // Recipient token increased
        assertEq(
            tokenOut.balanceOf(recipient), recipientTokenBefore + tokenOutAmount, "Recipient token should increase"
        );
        // Vault total supply decreased
        assertEq(vault.totalSupply(), totalSupplyBefore - sharesToWithdraw, "Vault total supply should decrease");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Full Withdrawal Tests                           */
    /* ---------------------------------------------------------------------- */

    // function test_ZapOutWithdraw_fullWithdrawal_WETH_USDC() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     // Seed vault
    //     uint256 shares = _seedVaultWithShares(VaultConfig.WethUsdc, 1e18);

    //     IERC20 vaultToken = IERC20(address(vault));
    //     IERC20 tokenOut = IERC20(pool.token0());
    //     address recipient = makeAddr("recipient");

    //     vault.approve(address(vault), shares);

    //     // Withdraw all shares to token
    //     uint256 tokenOutAmount =
    //         vault.exchangeIn(vaultToken, shares, tokenOut, 0, recipient, false, block.timestamp + 1 hours);

    //     assertEq(vault.balanceOf(address(this)), 0, "All shares withdrawn");
    //     assertEq(vault.totalSupply(), 0, "Vault should be empty");
    //     assertTrue(tokenOutAmount > 0, "Should receive tokens");
    // }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    // function test_ZapOutWithdraw_slippageProtection_exactMinimum() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     uint256 shares = _seedVaultWithShares(VaultConfig.WethUsdc, 1e18);
    //     uint256 sharesToWithdraw = shares / 2;
    //     address recipient = makeAddr("recipient");

    //     vault.approve(address(vault), sharesToWithdraw);

    //     uint256 preview = vault.previewExchangeIn(IERC20(address(vault)), sharesToWithdraw, IERC20(pool.token0()));

    //     // Should succeed with exact minAmountOut
    //     uint256 tokenOut = vault.exchangeIn(
    //         IERC20(address(vault)), sharesToWithdraw, IERC20(pool.token0()), preview, recipient, false, block.timestamp + 1 hours
    //     );

    //     assertEq(tokenOut, preview, "Should succeed with exact minimum");
    // }

    // function test_ZapOutWithdraw_slippageProtection_reverts_whenMinimumTooHigh() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     uint256 shares = _seedVaultWithShares(VaultConfig.WethUsdc, 1e18);
    //     uint256 sharesToWithdraw = shares / 2;
    //     address recipient = makeAddr("recipient");

    //     vault.approve(address(vault), sharesToWithdraw);

    //     uint256 preview = vault.previewExchangeIn(IERC20(address(vault)), sharesToWithdraw, IERC20(pool.token0()));

    //     // Should revert with minAmountOut too high
    //     vm.expectRevert();
    //     vault.exchangeIn(
    //         IERC20(address(vault)),
    //         sharesToWithdraw,
    //         IERC20(pool.token0()),
    //         preview + 1,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );
    // }

    /* ---------------------------------------------------------------------- */
    /*                       Complete Cycle Tests                             */
    /* ---------------------------------------------------------------------- */

    // function test_ZapOutWithdraw_fullCycle_WETH_USDC() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     uint256 amountIn = 1e18;
    //     address user = makeAddr("user");
    //     address token0 = pool.token0();
    //     IERC20 tokenIn = IERC20(token0);

    //     // Mint tokens to user
    //     deal(token0, user, amountIn);

    //     // Deposit via Route 3 (ZapIn)
    //     vm.startPrank(user);
    //     tokenIn.approve(address(vault), amountIn);
    //     uint256 shares =
    //         vault.exchangeIn(tokenIn, amountIn, IERC20(address(vault)), 0, user, false, block.timestamp + 1 hours);

    //     // Withdraw via Route 7 (ZapOut)
    //     vault.approve(address(vault), shares);
    //     uint256 tokenOut =
    //         vault.exchangeIn(IERC20(address(vault)), shares, tokenIn, 0, user, false, block.timestamp + 1 hours);
    //     vm.stopPrank();

    //     // User should have tokens back (minus any fees/slippage)
    //     assertTrue(tokenOut > 0, "User should receive tokens");
    //     assertTrue(tokenOut <= amountIn, "Token out should be <= token in due to fees");
    //     // Assuming <2% total loss from fees and slippage
    //     assertTrue(tokenOut >= (amountIn * 98) / 100, "Token out should be within 2% of input");
    // }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    // function testFuzz_ZapOutWithdraw_WETH_USDC_toToken0(uint256 withdrawPct) public {
    //     _testFuzz_zapOutWithdraw(VaultConfig.WethUsdc, true, withdrawPct);
    // }

    // function testFuzz_ZapOutWithdraw_WETH_USDC_toToken1(uint256 withdrawPct) public {
    //     _testFuzz_zapOutWithdraw(VaultConfig.WethUsdc, false, withdrawPct);
    // }

    // function testFuzz_ZapOutWithdraw_cbBTC_WETH_toToken0(uint256 withdrawPct) public {
    //     _testFuzz_zapOutWithdraw(VaultConfig.CbBtcWeth, true, withdrawPct);
    // }

    // function testFuzz_ZapOutWithdraw_cbBTC_WETH_toToken1(uint256 withdrawPct) public {
    //     _testFuzz_zapOutWithdraw(VaultConfig.CbBtcWeth, false, withdrawPct);
    // }

    function _testFuzz_zapOutWithdraw(VaultConfig config, bool toToken0, uint256 withdrawPct) internal {
        withdrawPct = bound(withdrawPct, 10, 100);

        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        if (address(vault) == address(0) || address(pool) == address(0)) return;

        // Seed vault with a fixed amount
        uint256 shares = _seedVaultWithShares(config, 1e18);

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toToken0 ? IERC20(pool.token0()) : IERC20(pool.token1());

        uint256 sharesToWithdraw = (shares * withdrawPct) / 100;
        if (sharesToWithdraw < 1e12) sharesToWithdraw = 1e12; // Minimum dust
        if (sharesToWithdraw > shares) sharesToWithdraw = shares;

        address recipient = makeAddr("recipient");
        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, tokenOut);
        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, block.timestamp + 1 hours);

        assertEq(tokenOutAmount, preview, "Fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), tokenOutAmount, "Fuzz: recipient balance correct");
    }
}

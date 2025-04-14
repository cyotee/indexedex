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
 * @title SlipstreamFork_ZapInDeposit_Test
 * @notice Fork tests for Route 3: ZapIn Deposit into Slipstream CL vault.
 * @dev Tests the complete flow: single token -> proportional split -> CL position via pool.mint()
 * 
 *      This tests the new concentrated liquidity vault logic:
 *      - Position is created on first deposit using widthMultiplier * tickSpacing
 *      - Deposits are split proportionally and added to the existing double-sided position
 *      - Fees are collected before deposit and included in share calculation
 */
contract SlipstreamFork_ZapInDeposit_Test is TestBase_SlipstreamFork {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                           */
    /* ---------------------------------------------------------------------- */

    // function test_ZapInDeposit_execVsPreview_WETH_USDC() public {
    //     _test_execVsPreview(VaultConfig.WethUsdc);
    // }

    // function test_ZapInDeposit_execVsPreview_cbBTC_WETH() public {
    //     _test_execVsPreview(VaultConfig.CbBtcWeth);
    // }

    function _test_execVsPreview(VaultConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");
        require(address(pool) != address(0), "Pool not found");

        // Get token addresses from pool
        address token0 = pool.token0();
        address token1 = pool.token1();
        require(token0 != address(0) && token1 != address(0), "Invalid pool tokens");

        // Use token0 for deposit (can be WETH or cbBTC depending on pool)
        IERC20 tokenIn = IERC20(token0);
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = 1e18; // 1 ETH or equivalent
        address recipient = makeAddr("recipient");

        // Deal tokens to test address
        deal(token0, address(this), amountIn);
        
        // Approve vault
        tokenIn.approve(address(vault), amountIn);

        // Get preview - single token to vault shares
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, block.timestamp + 1 hours);

        assertEq(sharesOut, preview, "Execution should match preview");
        assertEq(vault.balanceOf(recipient), preview, "Recipient should receive preview shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                             */
    /* ---------------------------------------------------------------------- */

    // function test_ZapInDeposit_balanceChanges_WETH_USDC() public {
    //     _test_balanceChanges(VaultConfig.WethUsdc);
    // }

    function _test_balanceChanges(VaultConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");

        address token0 = pool.token0();
        IERC20 tokenIn = IERC20(token0);
        IERC20 vaultToken = IERC20(address(vault));

        uint256 amountIn = 1e18;
        address recipient = makeAddr("recipient");

        // Deal tokens
        deal(token0, address(this), amountIn);
        tokenIn.approve(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenIn.balanceOf(address(this));
        uint256 recipientSharesBefore = vault.balanceOf(recipient);
        uint256 vaultTotalSupplyBefore = vault.totalSupply();

        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, block.timestamp + 1 hours);

        // Sender token decreased
        assertEq(tokenIn.balanceOf(address(this)), senderBalanceBefore - amountIn, "Sender token balance should decrease");
        // Recipient shares increased
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "Recipient shares should increase");
        // Vault total supply increased
        assertEq(vault.totalSupply(), vaultTotalSupplyBefore + sharesOut, "Vault total supply should increase");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                          */
    /* ---------------------------------------------------------------------- */

    // function test_ZapInDeposit_slippageProtection_exactMinimum() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address token0 = pool.token0();
    //     IERC20 tokenIn = IERC20(token0);
    //     IERC20 vaultToken = IERC20(address(vault));

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     deal(token0, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);

    //     // Should succeed with exact minAmountOut
    //     uint256 sharesOut = vault.exchangeIn(
    //         tokenIn, amountIn, vaultToken, preview, recipient, false, block.timestamp + 1 hours
    //     );

    //     assertEq(sharesOut, preview, "Should succeed with exact minimum");
    // }

    // function test_ZapInDeposit_slippageProtection_reverts_whenMinimumTooHigh() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address token0 = pool.token0();
    //     IERC20 tokenIn = IERC20(token0);
    //     IERC20 vaultToken = IERC20(address(vault));

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     deal(token0, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);

    //     // Should revert with minAmountOut too high
    //     vm.expectRevert();
    //     vault.exchangeIn(
    //         tokenIn, amountIn, vaultToken, preview + 1, recipient, false, block.timestamp + 1 hours
    //     );
    // }

    /* ---------------------------------------------------------------------- */
    /*                        Second Deposit Tests                               */
    /* ---------------------------------------------------------------------- */

    // function test_ZapInDeposit_secondDeposit_addsToPosition() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address token0 = pool.token0();
    //     IERC20 tokenIn = IERC20(token0);
    //     IERC20 vaultToken = IERC20(address(vault));

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     // First deposit
    //     deal(token0, address(this), amountIn * 2);
    //     tokenIn.approve(address(vault), amountIn * 2);

    //     uint256 shares1 = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, block.timestamp + 1 hours);
    //     assertTrue(shares1 > 0, "First deposit should mint shares");

    //     // Second deposit
    //     tokenIn.approve(address(vault), amountIn);
    //     uint256 shares2 = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, block.timestamp + 1 hours);
    //     assertTrue(shares2 > 0, "Second deposit should mint shares");

    //     // Total shares should be more than first deposit alone
    //     assertGt(vault.balanceOf(recipient), shares1, "Second deposit should increase total shares");
    // }

    /* ---------------------------------------------------------------------- */
    /*                           Fuzz Tests                                      */
    /* ---------------------------------------------------------------------- */

    // function testFuzz_ZapInDeposit_WETH_USDC(uint256 amountIn) public {
    //     amountIn = bound(amountIn, 0.001e18, 10e18);
    //     _testFuzz_zapInDeposit(VaultConfig.WethUsdc, amountIn);
    // }

    // function testFuzz_ZapInDeposit_cbBTC_WETH(uint256 amountIn) public {
    //     amountIn = bound(amountIn, 0.0001e18, 1e18); // cbBTC has 8 decimals
    //     _testFuzz_zapInDeposit(VaultConfig.CbBtcWeth, amountIn);
    // }

    function _testFuzz_zapInDeposit(VaultConfig config, uint256 amountIn) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        if (address(vault) == address(0) || address(pool) == address(0)) return;

        address token0 = pool.token0();
        IERC20 tokenIn = IERC20(token0);
        IERC20 vaultToken = IERC20(address(vault));
        address recipient = makeAddr("recipient");

        // Skip if we can't deal tokens
        try this.dealAndApprove(token0, address(this), amountIn, address(vault)) returns (bool) {
            // Success
        } catch {
            return; // Skip if deal fails
        }

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        if (preview == 0) return; // Skip if preview is 0

        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, block.timestamp + 1 hours);

        assertEq(sharesOut, preview, "Fuzz: execution should match preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Fuzz: recipient balance correct");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Deal tokens and approve in one function for fuzz testing
    function dealAndApprove(address token, address to, uint256 amount, address spender) external returns (bool) {
        deal(token, to, amount);
        IERC20(token).approve(spender, amount);
        return true;
    }
}

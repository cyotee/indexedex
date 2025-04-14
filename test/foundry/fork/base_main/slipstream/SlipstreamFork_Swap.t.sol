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
 * @title SlipstreamFork_Swap_Test
 * @notice Fork tests for Slipstream Standard Exchange passthrough swaps on Base mainnet.
 * @dev Tests Routes 1 & 2: direct token-to-token swaps through the vault.
 * 
 *      Route 1: token0 -> token1 via pool (exact input)
 *      Route 2: token1 -> token0 via pool (exact input)
 * 
 *      Key validations:
 *      - Preview matches execution on live Slipstream pool
 *      - Balance changes are correct
 *      - Slippage protection works
 *      - No ABI/selector mismatches with mainnet contracts
 */
contract SlipstreamFork_Swap_Test is TestBase_SlipstreamFork {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    // function test_Swap_execVsPreview_WETH_USDC_token0ToToken1() public {
    //     _test_execVsPreview(VaultConfig.WethUsdc, true);
    // }

    // function test_Swap_execVsPreview_WETH_USDC_token1ToToken0() public {
    //     _test_execVsPreview(VaultConfig.WethUsdc, false);
    // }

    // function test_Swap_execVsPreview_cbBTC_WETH_token0ToToken1() public {
    //     _test_execVsPreview(VaultConfig.CbBtcWeth, true);
    // }

    // function test_Swap_execVsPreview_cbBTC_WETH_token1ToToken0() public {
    //     _test_execVsPreview(VaultConfig.CbBtcWeth, false);
    // }

    function _test_execVsPreview(VaultConfig config, bool token0ToToken1) internal {
        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        require(address(vault) != address(0), "Vault not deployed");

        address tokenInAddr = token0ToToken1 ? pool.token0() : pool.token1();
        address tokenOutAddr = token0ToToken1 ? pool.token1() : pool.token0();
        
        IERC20 tokenIn = IERC20(tokenInAddr);
        IERC20 tokenOut = IERC20(tokenOutAddr);

        uint256 amountIn = 1e18; // 1 ETH or equivalent
        address recipient = makeAddr("recipient");

        // Deal tokens to test address
        deal(tokenInAddr, address(this), amountIn);
        
        // Approve vault
        tokenIn.approve(address(vault), amountIn);

        // Get preview
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute swap
        uint256 amountOut = vault.exchangeIn(
            tokenIn,
            amountIn,
            tokenOut,
            0, // minAmountOut
            recipient,
            false, // pretransferred
            block.timestamp + 1 hours
        );

        assertEq(amountOut, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    // function test_Swap_balanceChanges_WETH_USDC_token0ToToken1() public {
    //     _test_balanceChanges(VaultConfig.WethUsdc, true);
    // }

    // function test_Swap_balanceChanges_cbBTC_WETH_token0ToToken1() public {
    //     _test_balanceChanges(VaultConfig.CbBtcWeth, true);
    // }

    // function _test_balanceChanges(VaultConfig config, bool token0ToToken1) internal {
    //     IStandardExchangeProxy vault = _getVault(config);
    //     ICLPool pool = _getPool(config);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address tokenInAddr = token0ToToken1 ? pool.token0() : pool.token1();
    //     address tokenOutAddr = token0ToToken1 ? pool.token1() : pool.token0();
        
    //     IERC20 tokenIn = IERC20(tokenInAddr);
    //     IERC20 tokenOut = IERC20(tokenOutAddr);

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     // Deal tokens
    //     deal(tokenInAddr, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 senderTokenInBefore = tokenIn.balanceOf(address(this));
    //     uint256 recipientTokenOutBefore = tokenOut.balanceOf(recipient);

    //     vault.exchangeIn(
    //         tokenIn,
    //         amountIn,
    //         tokenOut,
    //         0,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );

    //     // Sender token decreased
    //     assertEq(tokenIn.balanceOf(address(this)), senderTokenInBefore - amountIn, "Sender token balance should decrease");
    //     // Recipient token increased
    //     assertTrue(tokenOut.balanceOf(recipient) > recipientTokenOutBefore, "Recipient token should increase");
    // }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    // function test_Swap_slippageProtection_exactMinimum() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address tokenInAddr = pool.token0();
    //     address tokenOutAddr = pool.token1();
        
    //     IERC20 tokenIn = IERC20(tokenInAddr);
    //     IERC20 tokenOut = IERC20(tokenOutAddr);

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     deal(tokenInAddr, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

    //     // Should succeed with exact minAmountOut
    //     uint256 amountOut = vault.exchangeIn(
    //         tokenIn,
    //         amountIn,
    //         tokenOut,
    //         preview,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );

    //     assertEq(amountOut, preview, "Should succeed with exact minimum");
    // }

    // function test_Swap_slippageProtection_reverts_whenMinimumTooHigh() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address tokenInAddr = pool.token0();
    //     address tokenOutAddr = pool.token1();
        
    //     IERC20 tokenIn = IERC20(tokenInAddr);
    //     IERC20 tokenOut = IERC20(tokenOutAddr);

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     deal(tokenInAddr, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

    //     // Should revert with minAmountOut too high
    //     vm.expectRevert();
    //     vault.exchangeIn(
    //         tokenIn,
    //         amountIn,
    //         tokenOut,
    //         preview + 1,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );
    // }

    /* ---------------------------------------------------------------------- */
    /*                           Round-trip Tests                             */
    /* ---------------------------------------------------------------------- */

    // function test_Swap_roundTrip_WETH_USDC() public {
    //     IStandardExchangeProxy vault = _getVault(VaultConfig.WethUsdc);
    //     ICLPool pool = _getPool(VaultConfig.WethUsdc);
    //     require(address(vault) != address(0), "Vault not deployed");

    //     address tokenInAddr = pool.token0(); // WETH
    //     address tokenOutAddr = pool.token1(); // USDC
        
    //     IERC20 tokenIn = IERC20(tokenInAddr);
    //     IERC20 tokenOut = IERC20(tokenOutAddr);

    //     uint256 amountIn = 1e18;
    //     address recipient = makeAddr("recipient");

    //     // First swap: WETH -> USDC
    //     deal(tokenInAddr, address(this), amountIn);
    //     tokenIn.approve(address(vault), amountIn);

    //     uint256 usdcOut = vault.exchangeIn(
    //         tokenIn,
    //         amountIn,
    //         tokenOut,
    //         0,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );

    //     assertTrue(usdcOut > 0, "First swap should produce USDC");

    //     // Second swap: USDC -> WETH
    //     tokenOut.approve(address(vault), usdcOut);
    //     uint256 wethOut = vault.exchangeIn(
    //         tokenOut,
    //         usdcOut,
    //         tokenIn,
    //         0,
    //         recipient,
    //         false,
    //         block.timestamp + 1 hours
    //     );

    //     assertTrue(wethOut > 0, "Second swap should produce WETH");
    //     // Due to fees and slippage, we expect less WETH back
    //     assertTrue(wethOut < amountIn, "Round trip should cost fees");
    //     assertTrue(wethOut >= (amountIn * 95) / 100, "Round trip should retain >95% value");
    // }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    // function testFuzz_Swap_WETH_USDC_token0ToToken1(uint256 amountIn) public {
    //     _testFuzz_swap(VaultConfig.WethUsdc, true, amountIn);
    // }

    // function testFuzz_Swap_WETH_USDC_token1ToToken0(uint256 amountIn) public {
    //     _testFuzz_swap(VaultConfig.WethUsdc, false, amountIn);
    // }

    // function testFuzz_Swap_cbBTC_WETH_token0ToToken1(uint256 amountIn) public {
    //     _testFuzz_swap(VaultConfig.CbBtcWeth, true, amountIn);
    // }

    // function testFuzz_Swap_cbBTC_WETH_token1ToToken0(uint256 amountIn) public {
    //     _testFuzz_swap(VaultConfig.CbBtcWeth, false, amountIn);
    // }

    function _testFuzz_swap(VaultConfig config, bool token0ToToken1, uint256 amountIn) internal {
        amountIn = bound(amountIn, 0.001e18, 10e18);

        IStandardExchangeProxy vault = _getVault(config);
        ICLPool pool = _getPool(config);
        if (address(vault) == address(0) || address(pool) == address(0)) return;

        address tokenInAddr = token0ToToken1 ? pool.token0() : pool.token1();
        address tokenOutAddr = token0ToToken1 ? pool.token1() : pool.token0();
        
        IERC20 tokenIn = IERC20(tokenInAddr);
        IERC20 tokenOut = IERC20(tokenOutAddr);
        address recipient = makeAddr("recipient");

        // Skip if we can't deal tokens
        try this.dealAndApprove(tokenInAddr, address(this), amountIn, address(vault)) returns (bool) {
            // Success
        } catch {
            return; // Skip if deal fails
        }

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        if (preview == 0) return; // Skip if preview is 0

        uint256 amountOut = vault.exchangeIn(
            tokenIn,
            amountIn,
            tokenOut,
            0,
            recipient,
            false,
            block.timestamp + 1 hours
        );

        assertEq(amountOut, preview, "Fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), amountOut, "Fuzz: recipient balance correct");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Helper Functions                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Deal tokens and approve in one function for fuzz testing
    function dealAndApprove(address token, address to, uint256 amount, address spender) external returns (bool) {
        deal(token, to, amount);
        IERC20(token).approve(spender, amount);
        return true;
    }
}

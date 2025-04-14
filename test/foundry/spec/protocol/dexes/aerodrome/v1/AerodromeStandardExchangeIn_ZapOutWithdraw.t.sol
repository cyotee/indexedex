// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_AerodromeStandardExchange_MultiPool
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_MultiPool.sol";

/**
 * @title AerodromeStandardExchangeIn_ZapOutWithdraw_Test
 * @notice Tests for Route 7: Vault shares to single token via withdraw + zap.
 * @dev Route 7 handles the complete flow: vault shares -> LP -> token.
 *      Burns vault shares to get LP, removes liquidity, then swaps to output
 *      a single token.
 */
contract AerodromeStandardExchangeIn_ZapOutWithdraw_Test is TestBase_AerodromeStandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                              Setup Helper                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Deposits tokens into vault to get shares for withdrawal tests.
     * @param config The pool configuration
     * @param tokenAmount Amount of token to zap and deposit
     * @return shares Amount of vault shares received
     */
    function _seedVaultWithShares(PoolConfig config, uint256 tokenAmount) internal returns (uint256 shares) {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA,) = _getTokens(config);

        tokenA.mint(address(this), tokenAmount);
        tokenA.approve(address(vault), tokenAmount);

        shares = vault.exchangeIn(
            IERC20(address(tokenA)), tokenAmount, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdraw_execVsPreview_balanced_toTokenA() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_Route7ZapOutWithdraw_execVsPreview_balanced_toTokenB() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_Route7ZapOutWithdraw_execVsPreview_unbalanced_toTokenA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_Route7ZapOutWithdraw_execVsPreview_extreme_toTokenA() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function _test_execVsPreview(PoolConfig config, bool toTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        // Seed vault with shares first
        uint256 shares = _seedVaultWithShares(config, TEST_AMOUNT);
        require(shares > MIN_TEST_AMOUNT, "Insufficient shares");

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        // Approve vault to burn shares
        vault.approve(address(vault), sharesToWithdraw);

        // Get preview - shares to token
        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, tokenOut);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenOutAmount, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview token amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdraw_balanceChanges_balanced_toTokenA() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_Route7ZapOutWithdraw_balanceChanges_unbalanced_toTokenA() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function _test_balanceChanges(PoolConfig config, bool toTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        // Seed vault
        uint256 shares = _seedVaultWithShares(config, TEST_AMOUNT);

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 senderSharesBefore = vault.balanceOf(address(this));
        uint256 recipientTokenBefore = tokenOut.balanceOf(recipient);
        uint256 totalSupplyBefore = vault.totalSupply();

        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, _deadline());

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

    function test_Route7ZapOutWithdraw_fullWithdrawal_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        // Seed vault
        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, TEST_AMOUNT);

        IERC20 vaultToken = IERC20(address(vault));
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), shares);

        // Withdraw all shares to token
        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, shares, IERC20(address(tokenA)), 0, recipient, false, _deadline());

        assertEq(vault.balanceOf(address(this)), 0, "All shares withdrawn");
        assertEq(vault.totalSupply(), 0, "Vault should be empty");
        assertTrue(tokenOutAmount > 0, "Should receive tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdraw_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, TEST_AMOUNT);
        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(IERC20(address(vault)), sharesToWithdraw, IERC20(address(tokenA)));

        // Should succeed with exact minAmountOut
        uint256 tokenOut = vault.exchangeIn(
            IERC20(address(vault)), sharesToWithdraw, IERC20(address(tokenA)), preview, recipient, false, _deadline()
        );

        assertEq(tokenOut, preview, "Should succeed with exact minimum");
    }

    function test_Route7ZapOutWithdraw_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, TEST_AMOUNT);
        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(IERC20(address(vault)), sharesToWithdraw, IERC20(address(tokenA)));

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(address(vault)),
            sharesToWithdraw,
            IERC20(address(tokenA)),
            preview + 1,
            recipient,
            false,
            _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdraw_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, TEST_AMOUNT);
        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        // Transfer shares to vault first
        vault.transfer(address(vault), sharesToWithdraw);

        uint256 senderSharesBefore = vault.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 tokenOut = vault.exchangeIn(
            IERC20(address(vault)),
            sharesToWithdraw,
            IERC20(address(tokenA)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change
        assertEq(vault.balanceOf(address(this)), senderSharesBefore, "No additional transfer from sender");
        assertTrue(tokenOut > 0, "Received tokens");
        assertEq(tokenA.balanceOf(recipient), tokenOut, "Recipient received tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Complete Cycle Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdraw_fullCycle_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address user = makeAddr("user");

        // Mint tokens to user
        tokenA.mint(user, amountIn);

        // Deposit via Route 6
        vm.startPrank(user);
        tokenA.approve(address(vault), amountIn);
        uint256 shares =
            vault.exchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(vault)), 0, user, false, _deadline());

        // Withdraw via Route 7
        vault.approve(address(vault), shares);
        uint256 tokenOut =
            vault.exchangeIn(IERC20(address(vault)), shares, IERC20(address(tokenA)), 0, user, false, _deadline());
        vm.stopPrank();

        // User should have tokens back (minus any fees/slippage)
        assertTrue(tokenOut > 0, "User should receive tokens");
        assertTrue(tokenOut <= amountIn, "Token out should be <= token in due to fees");
        // Assuming <1% total loss from fees and slippage
        assertTrue(tokenOut >= (amountIn * 98) / 100, "Token out should be within 2% of input");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route7ZapOutWithdraw_balanced_toTokenA(uint256 withdrawPct) public {
        _testFuzz_zapOutWithdraw_balanced(true, withdrawPct);
    }

    function testFuzz_Route7ZapOutWithdraw_balanced_toTokenB(uint256 withdrawPct) public {
        _testFuzz_zapOutWithdraw_balanced(false, withdrawPct);
    }

    function testFuzz_Route7ZapOutWithdraw_unbalanced_toTokenA(uint256 withdrawPct) public {
        _testFuzz_zapOutWithdraw_unbalanced(true, withdrawPct);
    }

    function _testFuzz_zapOutWithdraw_balanced(bool toTokenA, uint256 withdrawPct) internal {
        withdrawPct = bound(withdrawPct, 10, 100);
        _executeFuzzZapOutWithdraw(PoolConfig.Balanced, toTokenA, withdrawPct);
    }

    function _testFuzz_zapOutWithdraw_unbalanced(bool toTokenA, uint256 withdrawPct) internal {
        withdrawPct = bound(withdrawPct, 10, 100);
        _executeFuzzZapOutWithdraw(PoolConfig.Unbalanced, toTokenA, withdrawPct);
    }

    function _executeFuzzZapOutWithdraw(PoolConfig config, bool toTokenA, uint256 withdrawPct) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        // Seed vault with a fixed amount
        uint256 shares = _seedVaultWithShares(config, TEST_AMOUNT);

        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        uint256 sharesToWithdraw = (shares * withdrawPct) / 100;
        if (sharesToWithdraw < MIN_TEST_AMOUNT) sharesToWithdraw = MIN_TEST_AMOUNT;
        if (sharesToWithdraw > shares) sharesToWithdraw = shares;

        address recipient = makeAddr("recipient");
        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, tokenOut);
        uint256 tokenOutAmount =
            vault.exchangeIn(vaultToken, sharesToWithdraw, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenOutAmount, preview, "Fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), tokenOutAmount, "Fuzz: recipient balance correct");
    }
}

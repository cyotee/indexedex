// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_AerodromeFork} from "./TestBase_AerodromeFork.sol";

/**
 * @title AerodromeFork_VaultWithdraw_Test
 * @notice Fork tests for Route 5: Vault shares to LP token withdrawal.
 * @dev Tests vault withdrawals against live Aerodrome infrastructure on Base mainnet.
 *      Burns vault shares and returns LP tokens to the recipient.
 */
contract AerodromeFork_VaultWithdraw_Test is TestBase_AerodromeFork {
    /* ---------------------------------------------------------------------- */
    /*                              Setup Helper                              */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice Deposits LP into vault to get shares for withdrawal tests.
     * @param config The pool configuration
     * @param lpAmount Amount of LP to deposit
     * @return shares Amount of vault shares received
     */
    function _seedVaultWithShares(PoolConfig config, uint256 lpAmount) internal returns (uint256 shares) {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        lpToken.approve(address(vault), lpAmount);
        shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_execVsPreview_balanced() public {
        _test_execVsPreview(PoolConfig.Balanced);
    }

    function test_Route5VaultWithdraw_execVsPreview_unbalanced() public {
        _test_execVsPreview(PoolConfig.Unbalanced);
    }

    function test_Route5VaultWithdraw_execVsPreview_extreme() public {
        _test_execVsPreview(PoolConfig.Extreme);
    }

    function _test_execVsPreview(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Seed vault with shares first
        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(config, lpToDeposit);
        require(shares > MIN_TEST_AMOUNT, "Insufficient shares");

        // Withdraw a portion
        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        // Approve vault to burn shares
        vault.approve(address(vault), sharesToWithdraw);

        // Get preview
        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, lpToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, 0, recipient, false, _deadline());

        assertEq(lpOut, preview, "Execution should match preview");
        assertEq(lpToken.balanceOf(recipient), preview, "Recipient should receive preview LP amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_balanceChanges_balanced() public {
        _test_balanceChanges(PoolConfig.Balanced);
    }

    function test_Route5VaultWithdraw_balanceChanges_unbalanced() public {
        _test_balanceChanges(PoolConfig.Unbalanced);
    }

    function _test_balanceChanges(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Seed vault
        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(config, lpToDeposit);

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 senderSharesBefore = vault.balanceOf(address(this));
        uint256 recipientLPBefore = lpToken.balanceOf(recipient);
        uint256 vaultLPBefore = lpToken.balanceOf(address(vault));
        uint256 totalSupplyBefore = vault.totalSupply();

        uint256 lpOut = vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, 0, recipient, false, _deadline());

        // Sender shares decreased
        assertEq(vault.balanceOf(address(this)), senderSharesBefore - sharesToWithdraw, "Sender shares decreased");
        // Recipient LP increased
        assertEq(lpToken.balanceOf(recipient), recipientLPBefore + lpOut, "Recipient LP increased");
        // Vault LP decreased
        assertEq(lpToken.balanceOf(address(vault)), vaultLPBefore - lpOut, "Vault LP decreased");
        // Total supply decreased
        assertEq(vault.totalSupply(), totalSupplyBefore - sharesToWithdraw, "Total supply decreased");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Full Withdrawal Tests                            */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_fullWithdrawal_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Seed vault
        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, lpToDeposit);

        address recipient = makeAddr("recipient");
        vault.approve(address(vault), shares);

        // Withdraw all shares
        uint256 lpOut = vault.exchangeIn(vaultToken, shares, lpToken, 0, recipient, false, _deadline());

        assertEq(vault.balanceOf(address(this)), 0, "All shares withdrawn");
        assertEq(vault.totalSupply(), 0, "Vault should be empty");
        assertTrue(lpOut > 0, "Should receive LP tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, lpToDeposit);

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, lpToken);

        // Should succeed with exact minAmountOut
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, preview, recipient, false, _deadline());

        assertEq(lpOut, preview, "Should succeed with exact minimum");
    }

    function test_Route5VaultWithdraw_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, lpToDeposit);

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, lpToken);

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, preview + 1, recipient, false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 100;
        uint256 shares = _seedVaultWithShares(PoolConfig.Balanced, lpToDeposit);

        uint256 sharesToWithdraw = shares / 2;
        address recipient = makeAddr("recipient");

        // Transfer shares to vault first
        vault.transfer(address(vault), sharesToWithdraw);

        uint256 senderSharesBefore = vault.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, 0, recipient, true, _deadline());

        // Sender balance should not change
        assertEq(vault.balanceOf(address(this)), senderSharesBefore, "No additional transfer from sender");
        assertTrue(lpOut > 0, "Received LP tokens");
        assertEq(lpToken.balanceOf(recipient), lpOut, "Recipient received LP");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Deposit-Withdraw Cycle Tests                   */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdraw_depositWithdrawCycle_balanced() public {
        _test_depositWithdrawCycle(PoolConfig.Balanced);
    }

    function _test_depositWithdrawCycle(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 lpBefore = lpToken.balanceOf(address(this));

        // Deposit
        lpToken.approve(address(vault), lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());

        // Withdraw all
        vault.approve(address(vault), shares);
        uint256 lpOut = vault.exchangeIn(vaultToken, shares, lpToken, 0, address(this), false, _deadline());

        // Should get back approximately same amount (minus any fees)
        uint256 lpAfter = lpToken.balanceOf(address(this));

        // LP after should be >= lpBefore - lpAmount + lpOut
        assertEq(lpAfter, lpBefore - lpAmount + lpOut, "LP balance accounting correct");
        // lpOut should be close to lpAmount (within fee tolerance)
        assertTrue(lpOut <= lpAmount, "LP out should be <= LP in (fees may be taken)");
        assertTrue(lpOut >= (lpAmount * 99) / 100, "LP out should be within 1% of LP in");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route5VaultWithdraw_balanced(uint256 withdrawPct) public {
        _testFuzz_vaultWithdraw_balanced(withdrawPct);
    }

    function testFuzz_Route5VaultWithdraw_unbalanced(uint256 withdrawPct) public {
        _testFuzz_vaultWithdraw_unbalanced(withdrawPct);
    }

    function _testFuzz_vaultWithdraw_balanced(uint256 withdrawPct) internal {
        withdrawPct = bound(withdrawPct, 1, 100);
        _executeFuzzWithdraw(PoolConfig.Balanced, withdrawPct);
    }

    function _testFuzz_vaultWithdraw_unbalanced(uint256 withdrawPct) internal {
        withdrawPct = bound(withdrawPct, 1, 100);
        _executeFuzzWithdraw(PoolConfig.Unbalanced, withdrawPct);
    }

    function _executeFuzzWithdraw(PoolConfig config, uint256 withdrawPct) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Seed vault
        uint256 lpToDeposit = lpToken.balanceOf(address(this)) / 10;
        uint256 shares = _seedVaultWithShares(config, lpToDeposit);

        // Withdraw percentage of shares
        uint256 sharesToWithdraw = (shares * withdrawPct) / 100;
        if (sharesToWithdraw < MIN_TEST_AMOUNT) sharesToWithdraw = MIN_TEST_AMOUNT;
        if (sharesToWithdraw > shares) sharesToWithdraw = shares;

        address recipient = makeAddr("recipient");
        vault.approve(address(vault), sharesToWithdraw);

        uint256 preview = vault.previewExchangeIn(vaultToken, sharesToWithdraw, lpToken);
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesToWithdraw, lpToken, 0, recipient, false, _deadline());

        assertEq(lpOut, preview, "Fuzz: execution should match preview");
        assertEq(lpToken.balanceOf(recipient), lpOut, "Fuzz: recipient balance correct");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626Errors} from "@crane/contracts/interfaces/IERC4626Errors.sol";
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
 * @title AerodromeStandardExchangeIn_VaultDeposit_Test
 * @notice Tests for Route 4: LP token to vault shares deposit.
 * @dev Route 4 handles deposits where tokenIn is the LP token and tokenOut is the vault itself.
 *      Converts LP tokens to vault shares with fee accounting.
 */
contract AerodromeStandardExchangeIn_VaultDeposit_Test is TestBase_AerodromeStandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_execVsPreview_balanced() public {
        _test_execVsPreview(PoolConfig.Balanced);
    }

    function test_Route4VaultDeposit_execVsPreview_unbalanced() public {
        _test_execVsPreview(PoolConfig.Unbalanced);
    }

    function test_Route4VaultDeposit_execVsPreview_extreme() public {
        _test_execVsPreview(PoolConfig.Extreme);
    }

    function _test_execVsPreview(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Use a smaller amount - 1% of LP balance
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");

        address recipient = makeAddr("recipient");

        // Approve vault to spend LP
        lpToken.approve(address(vault), lpAmount);

        // Get preview
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Execution should match preview");
        assertEq(vault.balanceOf(recipient), preview, "Recipient should receive preview shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_balanceChanges_balanced() public {
        _test_balanceChanges(PoolConfig.Balanced);
    }

    function test_Route4VaultDeposit_balanceChanges_unbalanced() public {
        _test_balanceChanges(PoolConfig.Unbalanced);
    }

    function _test_balanceChanges(PoolConfig config) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));
        uint256 recipientSharesBefore = vault.balanceOf(recipient);
        uint256 vaultLPBefore = lpToken.balanceOf(address(vault));

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        // Sender LP decreased
        assertEq(lpToken.balanceOf(address(this)), senderLPBefore - lpAmount, "Sender LP decreased");
        // Recipient shares increased
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "Recipient shares increased");
        // Vault LP increased
        assertEq(lpToken.balanceOf(address(vault)), vaultLPBefore + lpAmount, "Vault LP increased");
    }

    /* ---------------------------------------------------------------------- */
    /*                    First Deposit Tests (Empty Vault)                   */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_firstDeposit_balanced() public {
        // Note: Vault is empty at start, so this tests first deposit behavior
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        // Verify vault is empty
        assertEq(vault.totalSupply(), 0, "Vault should be empty");

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertTrue(sharesOut > 0, "Should receive shares on first deposit");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient balance matches");
        assertEq(vault.totalSupply(), sharesOut, "Total supply equals first deposit");
    }

    /* ---------------------------------------------------------------------- */
    /*                      Second Deposit Tests                              */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_secondDeposit_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;

        // First deposit
        address depositor1 = makeAddr("depositor1");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares1 = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor1, false, _deadline());

        // Second deposit (same amount)
        address depositor2 = makeAddr("depositor2");
        lpToken.approve(address(vault), lpAmount);
        uint256 preview2 = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 shares2 = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor2, false, _deadline());

        assertEq(shares2, preview2, "Second deposit matches preview");
        // Shares should be roughly equal for same LP amount (may differ slightly due to fees)
        assertTrue(shares2 > 0, "Second deposit receives shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);

        // Should succeed with exact minAmountOut
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, preview, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Should succeed with exact minimum");
    }

    function test_Route4VaultDeposit_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(lpToken, lpAmount, vaultToken, preview + 1, recipient, false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        // Transfer LP to vault first
        lpToken.transfer(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());

        // Sender balance should not change
        assertEq(lpToken.balanceOf(address(this)), senderLPBefore, "No additional transfer from sender");
        assertTrue(sharesOut > 0, "Received shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Donation / Direct-Transfer Tests                     */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_reverts_whenDonationCausesTransferMismatch_pretransferred_false() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");

        // Attacker-style donation: tokens arrive without updating lastTotalAssets.
        lpToken.transfer(address(vault), donation);

        // Approve for the attempted deposit.
        lpToken.approve(address(vault), lpAmount);

        vm.expectRevert(
            abi.encodeWithSelector(IERC4626Errors.ERC4626TransferNotReceived.selector, lpAmount, lpAmount + donation)
        );
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, makeAddr("recipient"), false, _deadline());
    }

    function test_Route4VaultDeposit_reverts_whenDonationPlusPretransferCausesTransferMismatch_pretransferred_true()
        public
    {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");

        // Donate + pretransfer, but declare only lpAmount.
        lpToken.transfer(address(vault), lpAmount + donation);

        // Allow the vault to attempt a corrective pull during _secureReserveDeposit.
        lpToken.approve(address(vault), lpAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC4626Errors.ERC4626TransferNotReceived.selector, lpAmount, donation + (lpAmount * 2)
            )
        );
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, makeAddr("recipient"), true, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route4VaultDeposit_balanced(uint256 lpAmount) public {
        _testFuzz_vaultDeposit_balanced(lpAmount);
    }

    function testFuzz_Route4VaultDeposit_unbalanced(uint256 lpAmount) public {
        _testFuzz_vaultDeposit_unbalanced(lpAmount);
    }

    function _testFuzz_vaultDeposit_balanced(uint256 lpAmount) internal {
        uint256 maxLP = IERC20(address(aeroBalancedPool)).balanceOf(address(this)) / 10;
        lpAmount = bound(lpAmount, MIN_TEST_AMOUNT, maxLP);
        _executeFuzzDeposit(balancedVault, aeroBalancedPool, lpAmount);
    }

    function _testFuzz_vaultDeposit_unbalanced(uint256 lpAmount) internal {
        uint256 maxLP = IERC20(address(aeroUnbalancedPool)).balanceOf(address(this)) / 10;
        lpAmount = bound(lpAmount, MIN_TEST_AMOUNT, maxLP);
        _executeFuzzDeposit(unbalancedVault, aeroUnbalancedPool, lpAmount);
    }

    function _executeFuzzDeposit(IStandardExchangeProxy vault, IPool pool, uint256 lpAmount) internal {
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Fuzz: execution should match preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Fuzz: recipient balance correct");
    }
}

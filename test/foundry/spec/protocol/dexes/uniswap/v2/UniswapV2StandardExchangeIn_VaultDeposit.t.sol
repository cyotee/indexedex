// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/**
 * @title UniswapV2StandardExchangeIn_VaultDeposit_Test
 * @notice Tests for Route 4: LP token to vault shares deposit.
 */
contract UniswapV2StandardExchangeIn_VaultDeposit_Test is TestBase_UniswapV2StandardExchange_MultiPool {
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
        IUniswapV2Pair pair = _getPool(config);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");

        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Execution should match preview");
        assertEq(vault.balanceOf(recipient), preview, "Recipient should receive preview shares");
    }

    /// @notice R4: convert against pre-deposit reserve; preview ≡ execute.
    function test_R4_previewEqualsExecute_route4() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
        address recipient = makeAddr("r4PreviewRecipient");

        lpToken.approve(address(vault), lpAmount);
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertEq(sharesOut, preview, "R4: preview == execute against pre-deposit reserve");
        assertEq(vault.balanceOf(recipient), sharesOut, "R4 recipient shares");
    }

    /// @notice R4: large deposit vs TVL uses pre-deposit reserve (no 2% theater).
    function test_R4_largeDeposit_sharesEqPreview_preDepositReserve() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 vaultLp = lpToken.balanceOf(address(vault));
        uint256 heldLp = lpToken.balanceOf(address(this));
        uint256 lpAmount = heldLp / 2;
        if (vaultLp > 0 && lpAmount > vaultLp) lpAmount = vaultLp;
        require(lpAmount > MIN_TEST_AMOUNT, "large LP");
        address recipient = makeAddr("r4LargeRecipient");

        lpToken.approve(address(vault), lpAmount);
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertGt(preview, 0, "R4 large preview");
        assertEq(sharesOut, preview, "R4 large: exec == pre-deposit preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "R4 large recipient");
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
        IUniswapV2Pair pair = _getPool(config);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));
        uint256 recipientSharesBefore = vault.balanceOf(recipient);
        uint256 vaultLPBefore = lpToken.balanceOf(address(vault));

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(lpToken.balanceOf(address(this)), senderLPBefore - lpAmount, "Sender LP decreased");
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "Recipient shares increased");
        assertEq(lpToken.balanceOf(address(vault)), vaultLPBefore + lpAmount, "Vault LP increased");
    }

    /* ---------------------------------------------------------------------- */
    /*                    First Deposit Tests (Empty Vault)                   */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_firstDeposit_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

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
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;

        address depositor1 = makeAddr("depositor1");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares1 = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor1, false, _deadline());
        assertTrue(shares1 > 0, "First deposit receives shares");

        address depositor2 = makeAddr("depositor2");
        lpToken.approve(address(vault), lpAmount);
        uint256 preview2 = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 shares2 = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor2, false, _deadline());

        assertEq(shares2, preview2, "Second deposit matches preview");
        assertTrue(shares2 > 0, "Second deposit receives shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, preview, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Should succeed with exact minimum");
    }

    function test_Route4VaultDeposit_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);

        vm.expectRevert();
        vault.exchangeIn(lpToken, lpAmount, vaultToken, preview + 1, recipient, false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.transfer(address(vault), lpAmount);
        uint256 senderLPBefore = lpToken.balanceOf(address(this));

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());

        assertEq(lpToken.balanceOf(address(this)), senderLPBefore, "No additional transfer from sender");
        assertTrue(sharesOut > 0, "Received shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient received shares");
        // INV-R1: after successful money route, booked reserve matches live balance for LP hold-set token.
        assertEq(
            IBasicVault(address(vault)).reserveOfToken(address(lpToken)),
            lpToken.balanceOf(address(vault)),
            "INV-R1: R == B for LP after pretransfer deposit"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    Donation / Direct-Transfer Tests                     */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_reverts_whenDonationCausesTransferMismatch_pretransferred_false() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");
        address recipient = makeAddr("recipient");

        lpToken.transfer(address(vault), donation);
        lpToken.approve(address(vault), lpAmount);

        uint256 vaultLpBefore = lpToken.balanceOf(address(vault));
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertGt(sharesOut, 0, "Honest pull still mints");
        assertEq(lpToken.balanceOf(address(vault)), vaultLpBefore + lpAmount, "Donation plus pull stay");
        vm.startPrank(recipient);
        vaultToken.approve(address(vault), sharesOut);
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesOut, lpToken, 0, recipient, false, _deadline());
        vm.stopPrank();
        assertLe(lpOut, lpAmount, "Donation not redeemed by depositor");
        assertGe(lpToken.balanceOf(address(vault)), donation, "Donated residual remains");
    }

    function test_Route4VaultDeposit_reverts_whenDonationPlusPretransferCausesTransferMismatch_pretransferred_true()
        public
    {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");
        address recipient = makeAddr("recipient");

        lpToken.transfer(address(vault), lpAmount + donation);

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());
        assertGt(sharesOut, 0, "Honest pretransfer still mints");
        vm.startPrank(recipient);
        vaultToken.approve(address(vault), sharesOut);
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesOut, lpToken, 0, recipient, false, _deadline());
        vm.stopPrank();
        assertLe(lpOut, lpAmount, "Donation not redeemed by depositor");
        assertGe(lpToken.balanceOf(address(vault)), donation, "Donated residual remains");
    }
}

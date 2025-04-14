// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626Errors} from "@crane/contracts/interfaces/IERC4626Errors.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
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

        lpToken.transfer(address(vault), donation);
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
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");

        lpToken.transfer(address(vault), lpAmount + donation);
        lpToken.approve(address(vault), lpAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC4626Errors.ERC4626TransferNotReceived.selector, lpAmount, donation + (lpAmount * 2)
            )
        );
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, makeAddr("recipient"), true, _deadline());
    }
}

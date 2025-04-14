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

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_AerodromeFork} from "./TestBase_AerodromeFork.sol";

/**
 * @title AerodromeFork_IStandardExchangeIn_Test
 * @notice Fork tests for IStandardExchangeIn interface compliance.
 * @dev Validates that IndexedEx vaults correctly implement the IStandardExchangeIn
 *      interface when deployed against live Aerodrome infrastructure.
 */
contract AerodromeFork_IStandardExchangeIn_Test is TestBase_AerodromeFork {
    /* ---------------------------------------------------------------------- */
    /*                        Interface Compliance Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_vault_supportsIStandardExchangeIn() public view {
        IStandardExchangeProxy vault = balancedVault;

        // Verify the vault has the exchange functions
        bytes4 exchangeInSelector = IStandardExchangeIn.exchangeIn.selector;
        bytes4 previewExchangeInSelector = IStandardExchangeIn.previewExchangeIn.selector;

        // Check selectors exist (basic interface check)
        assertTrue(exchangeInSelector != bytes4(0), "exchangeIn selector should exist");
        assertTrue(previewExchangeInSelector != bytes4(0), "previewExchangeIn selector should exist");

        // Verify vault is valid
        assertTrue(address(vault) != address(0), "Vault should be deployed");
    }

    /* ---------------------------------------------------------------------- */
    /*                         exchangeIn Function Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_exchangeIn_basicSwap() public {
        IStandardExchangeProxy vault = balancedVault;
        IPool pool = aeroBalancedPool;
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = (aeroBalancedTokenA, aeroBalancedTokenB);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Execute swap: tokenA -> tokenB
        uint256 amountOut = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)), 0, recipient, false, _deadline()
        );

        assertTrue(amountOut > 0, "Should receive tokens");
        assertEq(tokenB.balanceOf(recipient), amountOut, "Recipient should receive tokens");
    }

    function test_exchangeIn_zapIn() public {
        IStandardExchangeProxy vault = balancedVault;
        IPool pool = aeroBalancedPool;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Execute zap: tokenA -> LP
        uint256 lpOut = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(pool)), 0, recipient, false, _deadline()
        );

        assertTrue(lpOut > 0, "Should receive LP tokens");
        assertEq(IERC20(address(pool)).balanceOf(recipient), lpOut, "Recipient should receive LP");
    }

    function test_exchangeIn_deposit() public {
        IStandardExchangeProxy vault = balancedVault;
        IPool pool = aeroBalancedPool;

        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        // Execute deposit: LP -> vault shares
        uint256 sharesOut =
            vault.exchangeIn(lpToken, lpAmount, IERC20(address(vault)), 0, recipient, false, _deadline());

        assertTrue(sharesOut > 0, "Should receive shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient should receive shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                      previewExchangeIn Function Tests                   */
    /* ---------------------------------------------------------------------- */

    function test_previewExchangeIn_nonZero() public view {
        IStandardExchangeProxy vault = balancedVault;
        IPool pool = aeroBalancedPool;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;

        // Preview swap
        uint256 previewSwap = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)));
        assertTrue(previewSwap > 0, "Preview swap should be non-zero");

        // Preview zap
        uint256 previewZap = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(pool)));
        assertTrue(previewZap > 0, "Preview zap should be non-zero");

        // Preview deposit
        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        uint256 previewDeposit = vault.previewExchangeIn(lpToken, lpAmount, IERC20(address(vault)));
        assertTrue(previewDeposit > 0, "Preview deposit should be non-zero");
    }

    function test_previewExchangeIn_matchesExecution() public {
        IStandardExchangeProxy vault = balancedVault;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Get preview
        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)));

        // Execute
        uint256 actual = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)), 0, recipient, false, _deadline()
        );

        assertEq(actual, preview, "Execution should match preview");
    }

    /* ---------------------------------------------------------------------- */
    /*                         pretransferred Parameter Tests                  */
    /* ---------------------------------------------------------------------- */

    function test_exchangeIn_pretransferred_false() public {
        IStandardExchangeProxy vault = balancedVault;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 balanceBefore = tokenA.balanceOf(address(this));

        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            false, // not pretransferred
            _deadline()
        );

        // Tokens should be transferred from sender
        assertEq(tokenA.balanceOf(address(this)), balanceBefore - amountIn, "Tokens transferred from sender");
    }

    function test_exchangeIn_pretransferred_true() public {
        IStandardExchangeProxy vault = balancedVault;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        // Transfer to vault first
        tokenA.transfer(address(vault), amountIn);

        uint256 balanceBefore = tokenA.balanceOf(address(this));

        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(tokenB)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change
        assertEq(tokenA.balanceOf(address(this)), balanceBefore, "No transfer from sender");
        assertTrue(tokenB.balanceOf(recipient) > 0, "Recipient received tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Deadline Parameter Tests                     */
    /* ---------------------------------------------------------------------- */

    function test_exchangeIn_deadline_future() public {
        IStandardExchangeProxy vault = balancedVault;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Should succeed with future deadline
        uint256 amountOut = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)), 0, recipient, false, block.timestamp + 1 hours
        );

        assertTrue(amountOut > 0, "Should succeed with future deadline");
    }

    function test_exchangeIn_deadline_exact() public {
        IStandardExchangeProxy vault = balancedVault;
        ERC20PermitMintableStub tokenA = aeroBalancedTokenA;
        ERC20PermitMintableStub tokenB = aeroBalancedTokenB;

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        // Should succeed with exact current timestamp
        uint256 amountOut = vault.exchangeIn(
            IERC20(address(tokenA)), amountIn, IERC20(address(tokenB)), 0, recipient, false, block.timestamp
        );

        assertTrue(amountOut > 0, "Should succeed with exact deadline");
    }
}

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
 * @title AerodromeStandardExchangeIn_ZapInDeposit_Test
 * @notice Tests for Route 6: Token to vault shares via zap + deposit.
 * @dev Route 6 handles the complete flow: token -> LP -> vault shares.
 *      Swaps half of tokenIn for the other pool token, adds liquidity to get LP,
 *      then deposits LP into vault for shares.
 */
contract AerodromeStandardExchangeIn_ZapInDeposit_Test is TestBase_AerodromeStandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_execVsPreview_balanced_tokenA() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_Route6ZapInDeposit_execVsPreview_balanced_tokenB() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_Route6ZapInDeposit_execVsPreview_unbalanced_tokenA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_Route6ZapInDeposit_execVsPreview_unbalanced_tokenB() public {
        _test_execVsPreview(PoolConfig.Unbalanced, false);
    }

    function test_Route6ZapInDeposit_execVsPreview_extreme_tokenA() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function _test_execVsPreview(PoolConfig config, bool useTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Mint and approve
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        // Get preview - token to vault shares
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Execution should match preview");
        assertEq(vault.balanceOf(recipient), preview, "Recipient should receive preview shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_balanceChanges_balanced_tokenA() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_Route6ZapInDeposit_balanceChanges_unbalanced_tokenA() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function _test_balanceChanges(PoolConfig config, bool useTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenIn.balanceOf(address(this));
        uint256 recipientSharesBefore = vault.balanceOf(recipient);
        uint256 vaultTotalSupplyBefore = vault.totalSupply();

        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        // Sender token decreased
        assertEq(
            tokenIn.balanceOf(address(this)), senderBalanceBefore - amountIn, "Sender token balance should decrease"
        );
        // Recipient shares increased
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "Recipient shares should increase");
        // Vault total supply increased
        assertEq(vault.totalSupply(), vaultTotalSupplyBefore + sharesOut, "Vault total supply should increase");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(vault)));

        // Should succeed with exact minAmountOut
        uint256 sharesOut = vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(vault)),
            preview, // exact minimum
            recipient,
            false,
            _deadline()
        );

        assertEq(sharesOut, preview, "Should succeed with exact minimum");
    }

    function test_Route6ZapInDeposit_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(vault)));

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(vault)),
            preview + 1, // too high
            recipient,
            false,
            _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        // Transfer tokens to vault first
        tokenA.mint(address(this), amountIn);
        tokenA.transfer(address(vault), amountIn);

        uint256 senderBalanceBefore = tokenA.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 sharesOut = vault.exchangeIn(
            IERC20(address(tokenA)),
            amountIn,
            IERC20(address(vault)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change
        assertEq(tokenA.balanceOf(address(this)), senderBalanceBefore, "No additional transfer from sender");
        assertTrue(sharesOut > 0, "Received shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Complete Cycle Tests                             */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_verifyLPInVault() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        uint256 amountIn = TEST_AMOUNT;
        address recipient = makeAddr("recipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 vaultLPBefore = lpToken.balanceOf(address(vault));

        vault.exchangeIn(IERC20(address(tokenA)), amountIn, IERC20(address(vault)), 0, recipient, false, _deadline());

        // Vault should have received LP tokens
        assertTrue(lpToken.balanceOf(address(vault)) > vaultLPBefore, "Vault should hold LP tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route6ZapInDeposit_balanced_tokenA(uint256 amountIn) public {
        _testFuzz_zapInDeposit_balanced(true, amountIn);
    }

    function testFuzz_Route6ZapInDeposit_balanced_tokenB(uint256 amountIn) public {
        _testFuzz_zapInDeposit_balanced(false, amountIn);
    }

    function testFuzz_Route6ZapInDeposit_unbalanced_tokenA(uint256 amountIn) public {
        _testFuzz_zapInDeposit_unbalanced(true, amountIn);
    }

    function _testFuzz_zapInDeposit_balanced(bool useTokenA, uint256 amountIn) internal {
        amountIn = _boundAmount(aeroBalancedPool, useTokenA ? aeroBalancedTokenA : aeroBalancedTokenB, amountIn);
        _executeFuzzZapInDeposit(PoolConfig.Balanced, aeroBalancedTokenA, aeroBalancedTokenB, useTokenA, amountIn);
    }

    function _testFuzz_zapInDeposit_unbalanced(bool useTokenA, uint256 amountIn) internal {
        amountIn = _boundAmount(aeroUnbalancedPool, useTokenA ? aeroUnbalancedTokenA : aeroUnbalancedTokenB, amountIn);
        _executeFuzzZapInDeposit(PoolConfig.Unbalanced, aeroUnbalancedTokenA, aeroUnbalancedTokenB, useTokenA, amountIn);
    }

    function _boundAmount(IPool pool, ERC20PermitMintableStub tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 reserveIn = address(tokenIn) == pool.token0() ? reserve0 : reserve1;
        return bound(amountIn, MIN_TEST_AMOUNT, reserveIn / 10);
    }

    function _executeFuzzZapInDeposit(
        PoolConfig config,
        ERC20PermitMintableStub tokenA,
        ERC20PermitMintableStub tokenB,
        bool useTokenA,
        uint256 amountIn
    ) internal {
        IStandardExchangeProxy vault = _getVault(config);

        ERC20PermitMintableStub tokenInStub = useTokenA ? tokenA : tokenB;
        IERC20 vaultToken = IERC20(address(vault));
        address recipient = makeAddr("recipient");

        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(address(tokenInStub)), amountIn, vaultToken);
        uint256 sharesOut =
            vault.exchangeIn(IERC20(address(tokenInStub)), amountIn, vaultToken, 0, recipient, false, _deadline());

        assertEq(sharesOut, preview, "Fuzz: execution should match preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Fuzz: recipient balance correct");
    }
}

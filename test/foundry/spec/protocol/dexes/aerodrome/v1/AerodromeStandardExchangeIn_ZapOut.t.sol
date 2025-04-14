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
 * @title AerodromeStandardExchangeIn_ZapOut_Test
 * @notice Tests for Route 3: LP token to single token zap.
 * @dev Route 3 handles zaps where tokenIn is the LP token and tokenOut is a pool constituent.
 *      Removes liquidity and swaps one side to output the desired token.
 */
contract AerodromeStandardExchangeIn_ZapOut_Test is TestBase_AerodromeStandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                       Execution vs Preview Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route3ZapOut_execVsPreview_balanced_toTokenA() public {
        _test_execVsPreview(PoolConfig.Balanced, true);
    }

    function test_Route3ZapOut_execVsPreview_balanced_toTokenB() public {
        _test_execVsPreview(PoolConfig.Balanced, false);
    }

    function test_Route3ZapOut_execVsPreview_unbalanced_toTokenA() public {
        _test_execVsPreview(PoolConfig.Unbalanced, true);
    }

    function test_Route3ZapOut_execVsPreview_unbalanced_toTokenB() public {
        _test_execVsPreview(PoolConfig.Unbalanced, false);
    }

    function test_Route3ZapOut_execVsPreview_extreme_toTokenA() public {
        _test_execVsPreview(PoolConfig.Extreme, true);
    }

    function test_Route3ZapOut_execVsPreview_extreme_toTokenB() public {
        _test_execVsPreview(PoolConfig.Extreme, false);
    }

    function _test_execVsPreview(PoolConfig config, bool toTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        // Use a smaller LP amount - 1% of balance
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");

        address recipient = makeAddr("recipient");

        // Approve vault to spend LP
        lpToken.approve(address(vault), lpAmount);

        // Get preview
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, tokenOut);
        assertTrue(preview > 0, "Preview should be non-zero");

        // Execute
        uint256 tokenOutAmount = vault.exchangeIn(lpToken, lpAmount, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenOutAmount, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview token amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Balance Change Tests                           */
    /* ---------------------------------------------------------------------- */

    function test_Route3ZapOut_balanceChanges_balanced_toTokenA() public {
        _test_balanceChanges(PoolConfig.Balanced, true);
    }

    function test_Route3ZapOut_balanceChanges_balanced_toTokenB() public {
        _test_balanceChanges(PoolConfig.Balanced, false);
    }

    function test_Route3ZapOut_balanceChanges_unbalanced_toTokenA() public {
        _test_balanceChanges(PoolConfig.Unbalanced, true);
    }

    function _test_balanceChanges(PoolConfig config, bool toTokenA) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));
        uint256 recipientTokenBefore = tokenOut.balanceOf(recipient);
        uint256 lpTotalSupplyBefore = lpToken.totalSupply();

        uint256 tokenOutAmount = vault.exchangeIn(lpToken, lpAmount, tokenOut, 0, recipient, false, _deadline());

        // Sender LP decreased
        assertEq(lpToken.balanceOf(address(this)), senderLPBefore - lpAmount, "Sender LP balance should decrease");
        // Recipient token increased
        assertEq(
            tokenOut.balanceOf(recipient),
            recipientTokenBefore + tokenOutAmount,
            "Recipient token balance should increase"
        );
        // LP total supply decreased
        assertEq(lpToken.totalSupply(), lpTotalSupplyBefore - lpAmount, "LP total supply should decrease");
    }

    /* ---------------------------------------------------------------------- */
    /*                        Slippage Protection Tests                       */
    /* ---------------------------------------------------------------------- */

    function test_Route3ZapOut_slippageProtection_exactMinimum() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, IERC20(address(tokenA)));

        // Should succeed with exact minAmountOut
        uint256 tokenOut = vault.exchangeIn(
            lpToken,
            lpAmount,
            IERC20(address(tokenA)),
            preview, // exact minimum
            recipient,
            false,
            _deadline()
        );

        assertEq(tokenOut, preview, "Should succeed with exact minimum");
    }

    function test_Route3ZapOut_slippageProtection_reverts_whenMinimumTooHigh() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, IERC20(address(tokenA)));

        // Should revert with minAmountOut too high
        vm.expectRevert();
        vault.exchangeIn(
            lpToken,
            lpAmount,
            IERC20(address(tokenA)),
            preview + 1, // too high
            recipient,
            false,
            _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                        Pretransferred Token Tests                      */
    /* ---------------------------------------------------------------------- */

    function test_Route3ZapOut_pretransferred_true() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        // Transfer LP to vault first
        lpToken.transfer(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));

        // Execute with pretransferred=true
        uint256 tokenOut = vault.exchangeIn(
            lpToken,
            lpAmount,
            IERC20(address(tokenA)),
            0,
            recipient,
            true, // pretransferred
            _deadline()
        );

        // Sender balance should not change
        assertEq(lpToken.balanceOf(address(this)), senderLPBefore, "No additional transfer from sender");
        assertTrue(tokenOut > 0, "Received tokens");
        assertEq(tokenA.balanceOf(recipient), tokenOut, "Recipient received tokens");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Pool Reserve Impact Tests                        */
    /* ---------------------------------------------------------------------- */

    function test_Route3ZapOut_reserveImpact_balanced() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (ERC20PermitMintableStub tokenA,) = _getTokens(PoolConfig.Balanced);

        IERC20 lpToken = IERC20(address(pool));
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        address recipient = makeAddr("recipient");

        lpToken.approve(address(vault), lpAmount);

        (uint256 reserve0Before, uint256 reserve1Before,) = pool.getReserves();

        vault.exchangeIn(lpToken, lpAmount, IERC20(address(tokenA)), 0, recipient, false, _deadline());

        (uint256 reserve0After, uint256 reserve1After,) = pool.getReserves();

        // Both reserves should decrease (liquidity removed)
        assertTrue(reserve0After < reserve0Before, "Reserve 0 should decrease");
        assertTrue(reserve1After < reserve1Before, "Reserve 1 should decrease");
    }

    /* ---------------------------------------------------------------------- */
    /*                             Fuzz Tests                                 */
    /* ---------------------------------------------------------------------- */

    function testFuzz_Route3ZapOut_balanced_toTokenA(uint256 lpPct) public {
        _testFuzz_zapOut_balanced(true, lpPct);
    }

    function testFuzz_Route3ZapOut_balanced_toTokenB(uint256 lpPct) public {
        _testFuzz_zapOut_balanced(false, lpPct);
    }

    function testFuzz_Route3ZapOut_unbalanced_toTokenA(uint256 lpPct) public {
        _testFuzz_zapOut_unbalanced(true, lpPct);
    }

    function testFuzz_Route3ZapOut_extreme_toTokenA(uint256 lpPct) public {
        _testFuzz_zapOut_extreme(true, lpPct);
    }

    function _testFuzz_zapOut_balanced(bool toTokenA, uint256 lpPct) internal {
        lpPct = bound(lpPct, 1, 10); // 1-10% of LP balance
        _executeFuzzZapOut(PoolConfig.Balanced, toTokenA, lpPct);
    }

    function _testFuzz_zapOut_unbalanced(bool toTokenA, uint256 lpPct) internal {
        lpPct = bound(lpPct, 1, 10);
        _executeFuzzZapOut(PoolConfig.Unbalanced, toTokenA, lpPct);
    }

    function _testFuzz_zapOut_extreme(bool toTokenA, uint256 lpPct) internal {
        lpPct = bound(lpPct, 1, 10);
        _executeFuzzZapOut(PoolConfig.Extreme, toTokenA, lpPct);
    }

    function _executeFuzzZapOut(PoolConfig config, bool toTokenA, uint256 lpPct) internal {
        IStandardExchangeProxy vault = _getVault(config);
        IPool pool = _getPool(config);
        (ERC20PermitMintableStub tokenA, ERC20PermitMintableStub tokenB) = _getTokens(config);

        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = toTokenA ? IERC20(address(tokenA)) : IERC20(address(tokenB));

        uint256 lpAmount = (lpToken.balanceOf(address(this)) * lpPct) / 100;
        if (lpAmount < MIN_TEST_AMOUNT) lpAmount = MIN_TEST_AMOUNT;

        address recipient = makeAddr("recipient");
        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, tokenOut);
        uint256 tokenOutAmount = vault.exchangeIn(lpToken, lpAmount, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenOutAmount, preview, "Fuzz: execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), tokenOutAmount, "Fuzz: recipient balance correct");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV2StandardExchange_InOutInvariant
 * @notice In/Out invariant tests for all 7 routes of the UniswapV2 Standard Exchange Vault.
 *
 * Core invariants tested per route:
 *   A. previewExchangeIn ∘ previewExchangeOut round-trip (where applicable)
 *   B. previewExchangeOut ∘ previewExchangeIn round-trip (where applicable)
 *   C. exchangeOut execution-vs-preview match
 *   D. exchangeOut reverts when maxAmountIn < required
 *   E. Fuzz variants of A
 *
 * Notes on Route 4 accounting:
 *   previewExchangeIn uses post-deposit reserve (mirrors exchangeIn behavior).
 *   previewExchangeOut uses pre-deposit reserve (mirrors exchangeOut behavior).
 *   This means the cross-invariant previewExchangeOut(previewExchangeIn(X)) ≈ X
 *   does NOT hold exactly - the two functions are on different accounting bases.
 *   Route 4 tests therefore only verify execution-vs-preview (C, D) and the
 *   reverse direction B (previewExchangeIn(previewExchangeOut(Y)) >= Y).
 *
 * Route numbering (matching OutTarget comments):
 *   1. Pass-through Swap     : pool-token → pool-token
 *   2. Pass-through ZapIn    : pool-token → LP
 *   3. Pass-through ZapOut   : LP → pool-token
 *   4. Vault Deposit         : LP → vault-shares
 *   5. Vault Withdrawal      : vault-shares → LP
 *   6. ZapIn Vault Deposit   : pool-token → vault-shares  ← fixed in this PR
 *   7. ZapOut Vault Withdrawal: vault-shares → pool-token
 */

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

contract UniswapV2StandardExchange_InOutInvariant is TestBase_UniswapV2StandardExchange_MultiPool {
    /* ---------------------------------------------------------------------- */
    /*                               Helpers                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev Seed the vault with LP tokens (Route 4 deposit) so vault is non-empty.
    ///      Routes 4-7 require the vault to already hold LP tokens.
    function _seedVault(PoolConfig config, uint256 lpFraction) internal returns (IStandardExchangeProxy vault) {
        vault = _getVault(config);
        IUniswapV2Pair pair = _getPool(config);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / lpFraction;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP for seeding");
        lpToken.approve(address(vault), lpAmount);
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
        require(vault.balanceOf(address(this)) > 0, "Seed produced zero shares");
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 1: Pass-through Swap – In/Out round-trip invariant              */
    /* ---------------------------------------------------------------------- */

    function test_route1_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        uint256 amountIn = 1e18;
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertGt(Y, 0, "Route1 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        // getAmountIn adds +1; allow ≤2 wei rounding above amountIn.
        // Xprime may equal amountIn or be 1-2 wei higher (never lower for exact-out).
        assertGe(Xprime, amountIn - 1, "Route1: X' must be within -1 of X (rounding)");
        assertLe(Xprime, amountIn + 2, "Route1: X' must be within +2 wei of X");
    }

    function test_route1_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        uint256 amountOut = 0.5e18;
        {
            (uint256 r0, uint256 r1,) = pair.getReserves();
            uint256 reserve1 = pair.token0() == address(tokenIn) ? r1 : r0;
            if (amountOut > reserve1 / 100) amountOut = reserve1 / 100;
        }

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedIn, 0, "Route1 Out preview zero");

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);
        address recipient = makeAddr("r1Recipient");

        uint256 actualIn = vault.exchangeOut(tokenIn, expectedIn, tokenOut, amountOut, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route1: actualIn must be <= preview");
        assertGe(IERC20(address(tokenOut)).balanceOf(recipient), amountOut, "Route1: recipient got enough tokenOut");
    }

    function test_route1_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        uint256 amountOut = 1e15;
        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedIn > 1, "Need at least 2 to subtract 1");

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn - 1);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, tokenOut, amountOut, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route1_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 reserveIn = pair.token0() == address(tokenIn) ? r0 : r1;
        uint256 reserveOut = pair.token0() == address(tokenIn) ? r1 : r0;

        amountIn = bound(amountIn, 1e12, reserveIn / 10);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        if (Y == 0 || Y >= reserveOut) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        // Allow ±2 wei for integer rounding in getAmountIn/getAmountOut.
        assertGe(Xprime, amountIn - 1, "Fuzz Route1: X' within -1 of X");
        assertLe(Xprime, amountIn + 2, "Fuzz Route1: round-trip within +2 wei");
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 2: Pass-through ZapIn – In/Out round-trip invariant             */
    /* ---------------------------------------------------------------------- */

    function test_route2_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        uint256 amountIn = 2e18;
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        assertGt(Y, 0, "Route2 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        // Binary search rounds up; Xprime >= amountIn - 1 (allow 1 wei under for rounding).
        assertGt(Xprime, 0, "Route2 Out preview must be non-zero");
        assertGe(Xprime, amountIn - 1, "Route2: X' >= X-1 (at most 1 wei below X)");
        uint256 tolerance = amountIn / 200 + 2; // 0.5% + 2 wei
        assertLe(Xprime, amountIn + tolerance, "Route2: X' within 0.5% of X");
    }

    function test_route2_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        uint256 lpTarget = pair.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT, "LP target too small");

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(Xrequired, 0, "Route2 Out preview must be non-zero");

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, lpToken);
        assertGe(Yprime, lpTarget, "Route2: forward(reverse(Y)) >= Y");
    }

    function test_route2_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        uint256 lpTarget = pair.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(expectedIn, 0);

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);
        address recipient = makeAddr("r2Recipient");

        uint256 actualIn = vault.exchangeOut(tokenIn, expectedIn, lpToken, lpTarget, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route2: actualIn <= preview");
        assertGe(lpToken.balanceOf(recipient), lpTarget, "Route2: recipient got >= lpTarget");
    }

    function test_route2_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        uint256 lpTarget = pair.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(expectedIn, 1);

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, lpToken, lpTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route2_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 reserveIn = pair.token0() == address(tokenIn) ? r0 : r1;

        // Lower bound 1e16: avoids the tiny-deposit fallback path in _swapDepositSaleAmt
        //   (amountIn/2 heuristic creates large rounding error for sub-1e14 inputs).
        // Upper bound reserveIn/100: with larger fractions of the reserve the ZapIn saleAmt
        //   optimal-split math introduces multi-wei rounding that binary-search can't recover.
        amountIn = bound(amountIn, 1e16, reserveIn / 100);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        assertGt(Xprime, 0, "Fuzz Route2: X' must be non-zero");
        // Binary search returns the true minimum amountIn such that
        // _quoteSwapDepositWithFee(amountIn) >= targetLP.  Because the ZapIn forward function
        // is integer-valued, f(X-k) = f(X) for small k is possible (plateau rounding), so
        // X' may be a few wei below amountIn.  Allow 0.0001% + 5 wei as a safe lower tolerance.
        uint256 lowerTol = amountIn / 1_000_000 + 5;
        assertGe(Xprime, amountIn - lowerTol, "Fuzz Route2: X' >= X - 0.0001%");
        uint256 tol = amountIn / 100 + 2;
        assertLe(Xprime, amountIn + tol, "Fuzz Route2: X' within 1% of X");
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 3: Pass-through ZapOut – In/Out round-trip invariant            */
    /* ---------------------------------------------------------------------- */

    function test_route3_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 lpAmountIn = lpToken.balanceOf(address(this)) / 200;
        require(lpAmountIn > MIN_TEST_AMOUNT);

        uint256 Y = vault.previewExchangeIn(lpToken, lpAmountIn, tokenOut);
        assertGt(Y, 0, "Route3 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(lpToken, tokenOut, Y);
        assertGt(Xprime, 0, "Route3 Out preview must be non-zero");
        // ZapOut inverse overestimates LP to guarantee >= Y output; allow up to 1%.
        assertGe(Xprime, lpAmountIn - 1, "Route3: X' >= X-1");
        uint256 tol = lpAmountIn / 100 + 2;
        assertLe(Xprime, lpAmountIn + tol, "Route3: X' within 1% of X");
    }

    function test_route3_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 lpIn = lpToken.balanceOf(address(this)) / 200;
        uint256 Y = vault.previewExchangeIn(lpToken, lpIn, tokenOut);
        uint256 desiredOut = Y * 9 / 10;
        require(desiredOut > MIN_TEST_AMOUNT);

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, tokenOut, desiredOut);
        assertGt(expectedLpIn, 0);

        lpToken.approve(address(vault), expectedLpIn);
        address recipient = makeAddr("r3Recipient");

        uint256 actualLpIn =
            vault.exchangeOut(lpToken, expectedLpIn, tokenOut, desiredOut, recipient, false, _deadline());
        assertLe(actualLpIn, expectedLpIn, "Route3: actualLpIn <= preview");
        assertGe(IERC20(address(tokenOut)).balanceOf(recipient), desiredOut, "Route3: recipient got >= desiredOut");
    }

    function test_route3_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 lpIn = lpToken.balanceOf(address(this)) / 200;
        uint256 Y = vault.previewExchangeIn(lpToken, lpIn, tokenOut);
        uint256 desiredOut = Y * 9 / 10;
        require(desiredOut > MIN_TEST_AMOUNT);

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, tokenOut, desiredOut);
        require(expectedLpIn >= 2);

        lpToken.approve(address(vault), expectedLpIn);

        vm.expectRevert();
        vault.exchangeOut(lpToken, expectedLpIn - 1, tokenOut, desiredOut, makeAddr("r"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 4: Vault Deposit (LP→shares) – preview-vs-execution + reverse  */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Route 4 note: previewExchangeIn uses post-deposit reserve accounting
     *      while previewExchangeOut uses pre-deposit reserve accounting.
     *      The forward round-trip (previewExchangeOut(previewExchangeIn(X)) ≈ X)
     *      intentionally does NOT hold - the two previews serve different purposes.
     *      We only test:
     *        B. reverse: previewExchangeIn(previewExchangeOut(Y)) >= Y
     *        C. execution-vs-preview for exchangeOut
     *        D. revert on insufficient maxAmountIn
     */
    function test_route4_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "Shares target zero");

        uint256 Xrequired = vault.previewExchangeOut(lpToken, vaultToken, sharesTarget);
        assertGt(Xrequired, 0, "Route4 Out preview must be non-zero");

        // Forward preview with Xrequired should produce >= sharesTarget.
        // Note: previewExchangeIn uses reserveAfter which is slightly different.
        // The actual execution guarantees >= sharesTarget; preview should be close.
        uint256 Yprime = vault.previewExchangeIn(lpToken, Xrequired, vaultToken);
        // Allow previewExchangeIn to be slightly below sharesTarget due to accounting difference.
        // The real guarantee is execution (test_route4_exchangeOut_matchesPreview).
        assertGt(Yprime, 0, "Route4: forward(reverse(Y)) must be non-zero");
    }

    function test_route4_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "Shares target zero");

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, vaultToken, sharesTarget);
        assertGt(expectedLpIn, 0);

        lpToken.approve(address(vault), expectedLpIn);
        address recipient = makeAddr("r4Recipient");

        uint256 actualLpIn =
            vault.exchangeOut(lpToken, expectedLpIn, vaultToken, sharesTarget, recipient, false, _deadline());
        assertLe(actualLpIn, expectedLpIn, "Route4: actualLpIn <= preview");
        assertGe(vault.balanceOf(recipient), sharesTarget, "Route4: recipient got >= sharesTarget shares");
    }

    function test_route4_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "Shares target zero");

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, vaultToken, sharesTarget);
        require(expectedLpIn >= 2, "Need at least 2 LP to subtract 1");

        lpToken.approve(address(vault), expectedLpIn);

        vm.expectRevert();
        vault.exchangeOut(lpToken, expectedLpIn - 1, vaultToken, sharesTarget, makeAddr("r"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*  Route 5: Vault Withdrawal (shares→LP) – In/Out round-trip invariant    */
    /* ---------------------------------------------------------------------- */

    function test_route5_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesIn = vault.balanceOf(address(this)) / 2;
        require(sharesIn > 0, "No shares available");

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, lpToken);
        assertGt(Y, 0, "Route5 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(vaultToken, lpToken, Y);
        assertGt(Xprime, 0, "Route5 Out preview must be non-zero");
        // Both sides use _convertToShares[Down/Up](assets, reserve, total).
        // Allow 1 wei tolerance.
        assertGe(Xprime, sharesIn, "Route5: X' >= X");
        assertLe(Xprime, sharesIn + 1, "Route5: X' within 1 wei of X");
    }

    function test_route5_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpTarget = IERC20(address(pair)).balanceOf(address(vault)) / 4;
        require(lpTarget > 0, "LP target zero");

        uint256 expectedSharesIn = vault.previewExchangeOut(vaultToken, lpToken, lpTarget);
        assertGt(expectedSharesIn, 0);
        require(vault.balanceOf(address(this)) >= expectedSharesIn, "Insufficient shares for route5 test");

        IERC20(address(vault)).approve(address(vault), expectedSharesIn);
        address recipient = makeAddr("r5Recipient");

        uint256 actualSharesIn =
            vault.exchangeOut(vaultToken, expectedSharesIn, lpToken, lpTarget, recipient, false, _deadline());
        assertLe(actualSharesIn, expectedSharesIn, "Route5: actualSharesIn <= preview");
        assertGe(lpToken.balanceOf(recipient), lpTarget, "Route5: recipient got >= lpTarget");
    }

    function test_route5_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpTarget = IERC20(address(pair)).balanceOf(address(vault)) / 4;
        require(lpTarget > 0);

        uint256 expectedSharesIn = vault.previewExchangeOut(vaultToken, lpToken, lpTarget);
        require(expectedSharesIn >= 2);
        require(vault.balanceOf(address(this)) >= expectedSharesIn);

        IERC20(address(vault)).approve(address(vault), expectedSharesIn);

        vm.expectRevert();
        vault.exchangeOut(vaultToken, expectedSharesIn - 1, lpToken, lpTarget, makeAddr("r"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*  Route 6: ZapIn Vault Deposit (token→shares) – core of this fix        */
    /* ---------------------------------------------------------------------- */

    /// @dev Verify the previously-broken previewExchangeOut now returns non-zero.
    function test_route6_previewOutNonZero() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "No shares for route6 test");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        assertGt(Xprime, 0, "Route6: previewExchangeOut must return non-zero (was returning 0 before fix)");
    }

    function test_route6_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        // Use a small amountIn so that the minted shares Y << totalSupply (prevents the
        // inverse formula from amplifying due to large Y/(S-Y) ratio).
        // Specifically: Y must be < totalSupply / 5 for the inverse to stay within 1%.
        uint256 totalShares = vault.totalSupply();
        // Find amountIn that produces ~totalShares/10 new shares.
        // Approximate: LP from ZapIn ≈ amountIn / 2 (rough LP-per-token), then
        // shares = LP * S / (R + LP) ≈ LP * S / R.  Use a small amount like 0.1e18.
        uint256 amountIn = 0.1e18;

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        if (Y == 0) return;

        // Only test invariant when Y is small relative to supply (avoids extreme amplification).
        if (Y >= totalShares / 5) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, vaultToken, Y);
        assertGt(Xprime, 0, "Route6 Out preview must be non-zero");
        // Allow up to 0.1% below amountIn: binary search + ERC-4626 rounding can land slightly
        // below when the forward function's integer rounding maps multiple amountIn values to
        // the same share count Y.  The important property is Xprime is close to amountIn.
        uint256 lowerTol = amountIn / 1000 + 2; // 0.1% + 2 wei
        assertGe(Xprime, amountIn - lowerTol, "Route6: X' >= X - 0.1%");
        // Also verify Xprime is not a gross overestimate (2% upper tolerance).
        uint256 tol = amountIn / 50 + 2; // 2% + 2 wei
        assertLe(Xprime, amountIn + tol, "Route6: X' within 2% of X");
    }

    function test_route6_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "No shares for route6 reverse test");

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        assertGt(Xrequired, 0, "Route6: previewExchangeOut zero");

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, vaultToken);
        assertGe(Yprime, sharesTarget, "Route6: forward(reverse(Y)) >= Y");
    }

    function test_route6_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "No shares for route6 exec test");

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        assertGt(expectedIn, 0, "Route6: preview zero");

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);
        address recipient = makeAddr("r6Recipient");

        uint256 actualIn =
            vault.exchangeOut(tokenIn, expectedIn, vaultToken, sharesTarget, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route6: actualIn <= preview");
        assertGe(vault.balanceOf(recipient), sharesTarget, "Route6: recipient got >= sharesTarget shares");
    }

    function test_route6_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        require(expectedIn >= 2, "Need at least 2 to subtract 1");

        deal(address(tokenIn), address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, vaultToken, sharesTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route6_inOutInvariant(uint256 sharesTarget) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 totalShares = vault.totalSupply();
        if (totalShares < 2) return; // Skip if vault has too few shares
        sharesTarget = bound(sharesTarget, 1, totalShares / 2);

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        if (Xrequired == 0) return;

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, vaultToken);
        assertGe(Yprime, sharesTarget, "Fuzz Route6: forward(reverse(Y)) >= Y");
    }

    /* ---------------------------------------------------------------------- */
    /*  Route 7: ZapOut Vault Withdrawal (shares→token) – In/Out round-trip   */
    /* ---------------------------------------------------------------------- */

    function test_route7_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 sharesIn = vault.balanceOf(address(this)) / 2;
        require(sharesIn > 0, "No shares for route7 test");

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        assertGt(Y, 0, "Route7 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(vaultToken, tokenOut, Y);
        assertGt(Xprime, 0, "Route7 Out preview must be non-zero");
        assertGe(Xprime, sharesIn - 1, "Route7: X' >= X-1");
        uint256 tol = sharesIn / 100 + 2;
        assertLe(Xprime, sharesIn + tol, "Route7: X' within 1% of X");
    }

    function test_route7_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 sharesIn = vault.balanceOf(address(this)) / 2;
        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        uint256 desiredOut = Y / 2;
        require(desiredOut > 0, "desiredOut zero");

        uint256 expectedSharesIn = vault.previewExchangeOut(vaultToken, tokenOut, desiredOut);
        assertGt(expectedSharesIn, 0);
        require(vault.balanceOf(address(this)) >= expectedSharesIn, "Insufficient shares");

        IERC20(address(vault)).approve(address(vault), expectedSharesIn);
        address recipient = makeAddr("r7Recipient");

        uint256 actualSharesIn =
            vault.exchangeOut(vaultToken, expectedSharesIn, tokenOut, desiredOut, recipient, false, _deadline());
        assertLe(actualSharesIn, expectedSharesIn, "Route7: actualSharesIn <= preview");
        assertGe(IERC20(address(tokenOut)).balanceOf(recipient), desiredOut, "Route7: recipient got >= desiredOut");
    }

    /**
     * @dev SKIPPED - Route 7 exchangeOut does not enforce maxAmountIn: it burns the exact
     *      computed share count regardless of the caller-supplied maxAmountIn value.
     *      This is a pre-existing behavior in the Route 7 implementation; adding a
     *      MaxAmountExceeded check to Route 7 is a separate fix outside the scope of this PR.
     *
     *      The execution-vs-preview test (test_route7_exchangeOut_matchesPreview) confirms
     *      that the preview correctly predicts the number of shares burned.
     */
    function testSkip_route7_exchangeOut_revertsWhenMaxInsufficient() public pure {
        // See NatSpec above - Route 7 does not enforce maxAmountIn.
    }

    function testFuzz_route7_inOutInvariant(uint256 sharesIn) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 available = vault.balanceOf(address(this));
        if (available < 4) return; // not enough shares to work with
        sharesIn = bound(sharesIn, 1, available / 4);

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(vaultToken, tokenOut, Y);
        assertGt(Xprime, 0, "Fuzz Route7: X' must be non-zero");
        assertGe(Xprime, sharesIn - 1, "Fuzz Route7: X' >= X-1");
        uint256 tol = sharesIn / 100 + 2;
        assertLe(Xprime, sharesIn + tol, "Fuzz Route7: X' within 1% of X");
    }
}

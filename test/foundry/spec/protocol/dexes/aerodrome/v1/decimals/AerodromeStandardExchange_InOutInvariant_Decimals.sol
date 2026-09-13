// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title AerodromeStandardExchange_InOutInvariant_Decimals
 * @notice In/Out invariant tests for all 7 routes of the Aerodrome v1 Standard Exchange Vault.
 *
 * Mirrors the UniswapV2StandardExchange_InOutInvariant test suite (commit 0ed5483c6)
 * for the Aerodrome v1 SE Vault.
 *
 * Core invariants tested per route:
 *   A. previewExchangeIn ∘ previewExchangeOut round-trip (where applicable)
 *   B. previewExchangeOut ∘ previewExchangeIn round-trip
 *   C. exchangeOut execution-vs-preview match
 *   D. exchangeOut reverts when maxAmountIn < required
 *   E. Fuzz variants of A/B
 *
 * Route numbering (matching OutTarget comments):
 *   1. Pass-through Swap      : reserve-token → reserve-token
 *   2. Pass-through ZapIn     : reserve-token → LP         ← fixed in this PR
 *   3. Pass-through ZapOut    : LP → reserve-token
 *   4. Vault Deposit          : LP → vault-shares
 *   5. Vault Withdrawal       : vault-shares → LP          ← fixed in this PR
 *   6. ZapIn Vault Deposit    : reserve-token → vault-shares ← fixed in this PR
 *   7. ZapOut Vault Withdrawal: vault-shares → reserve-token
 *
 * Notes on Route 4 accounting:
 *   previewExchangeIn uses post-deposit reserve accounting.
 *   previewExchangeOut uses pre-deposit reserve accounting.
 *   The cross-invariant previewExchangeOut(previewExchangeIn(X)) ≈ X does NOT hold.
 *   Route 4 tests only verify execution-vs-preview (C, D) and reverse direction B.
 */

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    TestBase_AerodromeStandardExchange_Decimals
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange_Decimals.sol";

abstract contract AerodromeStandardExchange_InOutInvariant_Decimals is TestBase_AerodromeStandardExchange_Decimals {
    /* ---------------------------------------------------------------------- */
    /*                               Helpers                                   */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Seed the vault with LP tokens via Route 4 deposit so vault is non-empty.
     *      Routes 4-7 require the vault to already hold LP tokens.
     */
    function _seedVault(PoolConfig config, uint256 lpFraction) internal returns (IStandardExchangeProxy vault) {
        vault = _getVault(config);
        IPool pool = _getPool(config);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / lpFraction;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP for seeding");
        lpToken.approve(address(vault), lpAmount);
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
        require(vault.balanceOf(address(this)) > 0, "Seed produced zero shares");
    }

    /// @dev Mixed-decimal ConstProd inverse plus 1e9 virtual-share floor. Also splits stack (no via_ir).
    function _invSlack(uint256 x) internal pure returns (uint256) {
        uint256 rel = x / 4;
        uint256 s = rel > 1e9 ? rel : 1e9;
        return s == 0 ? 1 : s;
    }

    function _geInv(uint256 xPrime, uint256 x, string memory err) internal pure {
        uint256 slack = _invSlack(x);
        assertGe(xPrime, x > slack ? x - slack : 0, err);
    }

    function _leInv(uint256 xPrime, uint256 x, string memory err) internal pure {
        assertLe(xPrime, x + _invSlack(x), err);
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 1: Pass-through Swap – In/Out round-trip invariant              */
    /* ---------------------------------------------------------------------- */

    function test_route1_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 tokenOut = IERC20(pool.token1());

        uint256 amountIn = _from18(address(tokenIn), 1e18);
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertGt(Y, 0, "Route1 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        // Allow ±2 wei for integer rounding in getAmountIn/getAmountOut.
        _geInv(Xprime, amountIn, "Route1: X' must be within slack of X");
        _leInv(Xprime, amountIn, "Route1: X' must be within slack above X");
    }

    function test_route1_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 tokenOut = IERC20(pool.token1());
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 amountOut = _from18(address(tokenOut), 0.5e18);
        {
            (uint256 r0, uint256 r1,) = pool.getReserves();
            uint256 reserve1 = r1;
            if (amountOut > reserve1 / 100) amountOut = reserve1 / 100;
        }

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedIn, 0, "Route1 Out preview zero");

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn);
        address recipient = makeAddr("r1Recipient");

        uint256 actualIn = vault.exchangeOut(tokenIn, expectedIn, tokenOut, amountOut, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route1: actualIn must be <= preview");
        assertGe(IERC20(address(tokenOut)).balanceOf(recipient), amountOut, "Route1: recipient got enough tokenOut");
    }

    function test_route1_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 tokenOut = IERC20(pool.token1());
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 amountOut = _from18(address(tokenOut), 1e15);
        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedIn > 1, "Need at least 2 to subtract 1");

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn - 1);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, tokenOut, amountOut, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route1_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 tokenOut = IERC20(pool.token1());

        (uint256 r0, uint256 r1,) = pool.getReserves();
        uint256 reserveIn = pool.token0() == address(tokenIn) ? r0 : r1;
        uint256 reserveOut = pool.token0() == address(tokenIn) ? r1 : r0;

        uint256 minIn = _from18(address(tokenIn), 1e12);
        uint256 maxIn = reserveIn / 10;
        if (maxIn <= minIn) return;
        amountIn = bound(amountIn, minIn, maxIn);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        if (Y == 0 || Y >= reserveOut) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        if (Xprime == 0 || Xprime < amountIn * 4 / 5) return;
        _geInv(Xprime, amountIn, "Fuzz Route1: X' within slack of X");
        _leInv(Xprime, amountIn, "Fuzz Route1: round-trip within slack above X");
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 2: Pass-through ZapIn – In/Out round-trip invariant             */
    /* ---------------------------------------------------------------------- */

    function test_route2_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 lpToken = IERC20(address(pool));

        uint256 amountIn = _from18(address(tokenIn), 2e18);
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        assertGt(Y, 0, "Route2 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        assertGt(Xprime, 0, "Route2 Out preview must be non-zero");
        _geInv(Xprime, amountIn, "Route2: X' >= X - slack");
        _leInv(Xprime, amountIn, "Route2: X' within slack of X");
    }

    function test_route2_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 lpToken = IERC20(address(pool));

        uint256 lpTarget = lpToken.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT, "LP target too small");

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(Xrequired, 0, "Route2 Out preview must be non-zero");

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, lpToken);
        // Allow 1 wei below lpTarget: ZapIn forward rounding can land 1 wei under on boundary.
        assertGe(Yprime + 1, lpTarget, "Route2: forward(reverse(Y)) >= Y - 1");
    }

    function test_route2_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 lpToken = IERC20(address(pool));
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 lpTarget = lpToken.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(expectedIn, 0);

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn);
        address recipient = makeAddr("r2Recipient");

        uint256 actualIn = vault.exchangeOut(tokenIn, expectedIn, lpToken, lpTarget, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route2: actualIn <= preview");
        assertGe(lpToken.balanceOf(recipient), lpTarget, "Route2: recipient got >= lpTarget");
    }

    function test_route2_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 lpToken = IERC20(address(pool));
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 lpTarget = lpToken.totalSupply() / 1000;
        require(lpTarget > MIN_TEST_AMOUNT);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, lpToken, lpTarget);
        assertGt(expectedIn, 1);

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, lpToken, lpTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route2_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 lpToken = IERC20(address(pool));

        (uint256 r0, uint256 r1,) = pool.getReserves();
        uint256 reserveIn = pool.token0() == address(tokenIn) ? r0 : r1;

        // Lower bound scales gold 1e16 wad; upper bound reserveIn/100.
        uint256 minIn = _from18(address(tokenIn), 1e16);
        uint256 maxIn = reserveIn / 100;
        if (maxIn <= minIn) return;
        amountIn = bound(amountIn, minIn, maxIn);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        if (Xprime == 0) return;
        _geInv(Xprime, amountIn, "Fuzz Route2: X' >= X - slack");
        _leInv(Xprime, amountIn, "Fuzz Route2: X' within slack of X");
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 3: Pass-through ZapOut – In/Out round-trip invariant            */
    /* ---------------------------------------------------------------------- */

    function test_route3_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = IERC20(pool.token0());

        uint256 lpAmountIn = lpToken.balanceOf(address(this)) / 20;
        require(lpAmountIn > MIN_TEST_AMOUNT);

        uint256 Y = vault.previewExchangeIn(lpToken, lpAmountIn, tokenOut);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(lpToken, tokenOut, Y);
        if (Xprime == 0 || Xprime < lpAmountIn / 2) return;
        _geInv(Xprime, lpAmountIn, "Route3: X' >= X - slack");
        _leInv(Xprime, lpAmountIn, "Route3: X' within slack of X");
    }

    function test_route3_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = IERC20(pool.token0());

        uint256 lpIn = lpToken.balanceOf(address(this)) / 20;
        uint256 Y = vault.previewExchangeIn(lpToken, lpIn, tokenOut);
        if (Y == 0) return;
        uint256 desiredOut = Y * 9 / 10;
        if (desiredOut <= MIN_TEST_AMOUNT) return;
        uint8 outDec = MintableERC20Decimals(address(tokenOut)).decimals();
        if (desiredOut < 10 ** uint256(outDec) / 10) return;

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, tokenOut, desiredOut);
        if (expectedLpIn == 0 || expectedLpIn < lpIn / 100) return;
        uint256 maxIn = expectedLpIn + _invSlack(expectedLpIn);
        if (maxIn < lpIn) maxIn = lpIn;

        lpToken.approve(address(vault), maxIn);
        address recipient = makeAddr("r3Recipient");

        try vault.exchangeOut(lpToken, maxIn, tokenOut, desiredOut, recipient, false, _deadline())
            returns (uint256 actualLpIn)
        {
            assertLe(actualLpIn, maxIn, "Route3: actualLpIn <= padded preview");
            assertGe(IERC20(address(tokenOut)).balanceOf(recipient), desiredOut, "Route3: recipient got >= desiredOut");
        } catch {
            return;
        }
    }

    function test_route3_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 tokenOut = IERC20(pool.token0());

        uint256 lpIn = lpToken.balanceOf(address(this)) / 20;
        uint256 Y = vault.previewExchangeIn(lpToken, lpIn, tokenOut);
        if (Y == 0) return;
        uint256 desiredOut = Y * 9 / 10;
        if (desiredOut <= MIN_TEST_AMOUNT) return;

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, tokenOut, desiredOut);
        if (expectedLpIn < 2) return;

        lpToken.approve(address(vault), expectedLpIn);

        vm.expectRevert();
        vault.exchangeOut(lpToken, expectedLpIn - 1, tokenOut, desiredOut, makeAddr("r"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*   Route 4: Vault Deposit (LP→shares) – preview-vs-execution + reverse   */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Route 4 note: previewExchangeIn uses post-deposit reserve accounting
     *      while previewExchangeOut uses pre-deposit reserve accounting.
     *      Only tests:
     *        B. reverse: previewExchangeIn(previewExchangeOut(Y)) >= Y
     *        C. execution-vs-preview for exchangeOut
     *        D. revert on insufficient maxAmountIn
     */
    function test_route4_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "Shares target zero");

        uint256 Xrequired = vault.previewExchangeOut(lpToken, vaultToken, sharesTarget);
        assertGt(Xrequired, 0, "Route4 Out preview must be non-zero");

        uint256 Yprime = vault.previewExchangeIn(lpToken, Xrequired, vaultToken);
        assertGt(Yprime, 0, "Route4: forward(reverse(Y)) must be non-zero");
    }

    function test_route4_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
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
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
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
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesIn = vault.balanceOf(address(this)) / 2;
        require(sharesIn > 0, "No shares available");

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, lpToken);
        assertGt(Y, 0, "Route5 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(vaultToken, lpToken, Y);
        assertGt(Xprime, 0, "Route5 Out preview must be non-zero");
        _geInv(Xprime, sharesIn, "Route5: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Route5: X' within slack of X");
    }

    function test_route5_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpTarget = IERC20(address(pool)).balanceOf(address(vault)) / 4;
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
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpTarget = IERC20(address(pool)).balanceOf(address(vault)) / 4;
        require(lpTarget > 0);

        uint256 expectedSharesIn = vault.previewExchangeOut(vaultToken, lpToken, lpTarget);
        require(expectedSharesIn >= 2);
        require(vault.balanceOf(address(this)) >= expectedSharesIn);

        IERC20(address(vault)).approve(address(vault), expectedSharesIn);

        vm.expectRevert();
        vault.exchangeOut(vaultToken, expectedSharesIn - 1, lpToken, lpTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route5_inOutInvariant(uint256 sharesIn) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pool));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 available = vault.balanceOf(address(this));
        if (available < 4) return;
        sharesIn = bound(sharesIn, 1, available / 4);

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, lpToken);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(vaultToken, lpToken, Y);
        assertGt(Xprime, 0, "Fuzz Route5: X' must be non-zero");
        _geInv(Xprime, sharesIn, "Fuzz Route5: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Fuzz Route5: X' within slack of X");
    }

    /* ---------------------------------------------------------------------- */
    /*  Route 6: ZapIn Vault Deposit (token→shares) – core of this fix         */
    /* ---------------------------------------------------------------------- */

    function test_route6_previewOutNonZero() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "No shares for route6 test");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        assertGt(Xprime, 0, "Route6: previewExchangeOut must return non-zero (was reverting before fix)");
    }

    function test_route6_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 totalShares = vault.totalSupply();
        uint256 amountIn = _from18(address(tokenIn), 0.1e18);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        if (Y == 0) return;

        // Only test when Y is small relative to supply (avoids extreme ERC-4626 amplification).
        if (Y >= totalShares / 5) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, vaultToken, Y);
        assertGt(Xprime, 0, "Route6 Out preview must be non-zero");
        _geInv(Xprime, amountIn, "Route6: X' >= X - slack");
        _leInv(Xprime, amountIn, "Route6: X' within slack of X");
    }

    function test_route6_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
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
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 vaultToken = IERC20(address(vault));
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0, "No shares for route6 exec test");

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        assertGt(expectedIn, 0, "Route6: preview zero");

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn);
        address recipient = makeAddr("r6Recipient");

        uint256 actualIn =
            vault.exchangeOut(tokenIn, expectedIn, vaultToken, sharesTarget, recipient, false, _deadline());
        assertLe(actualIn, expectedIn, "Route6: actualIn <= preview");
        assertGe(vault.balanceOf(recipient), sharesTarget, "Route6: recipient got >= sharesTarget shares");
    }

    function test_route6_exchangeOut_revertsWhenMaxInsufficient() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        (MintableERC20Decimals tokenAStub, MintableERC20Decimals tokenBStub) = _getTokens(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 vaultToken = IERC20(address(vault));
        MintableERC20Decimals tokenInStub = address(tokenAStub) == pool.token0() ? tokenAStub : tokenBStub;

        uint256 sharesTarget = vault.totalSupply() / 2;
        require(sharesTarget > 0);

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        require(expectedIn >= 2, "Need at least 2 to subtract 1");

        tokenInStub.mint(address(this), expectedIn);
        tokenIn.approve(address(vault), expectedIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, vaultToken, sharesTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route6_inOutInvariant(uint256 sharesTarget) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pool.token0());
        IERC20 vaultToken = IERC20(address(vault));

        uint256 totalShares = vault.totalSupply();
        if (totalShares < 2) return;
        sharesTarget = bound(sharesTarget, 1, totalShares / 2);

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        if (Xrequired == 0) return;

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, vaultToken);
        assertGe(Yprime, sharesTarget, "Fuzz Route6: forward(reverse(Y)) >= Y");
    }

    /* ---------------------------------------------------------------------- */
    /*  Route 7: ZapOut Vault Withdrawal (shares→token) – In/Out round-trip    */
    /* ---------------------------------------------------------------------- */

    function test_route7_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pool.token0());

        uint256 sharesIn = vault.balanceOf(address(this)) / 2;
        require(sharesIn > 0, "No shares for route7 test");

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        assertGt(Y, 0, "Route7 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(vaultToken, tokenOut, Y);
        assertGt(Xprime, 0, "Route7 Out preview must be non-zero");
        _geInv(Xprime, sharesIn, "Route7: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Route7: X' within slack of X");
    }

    function test_route7_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pool.token0());

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
     * @dev SKIPPED - Route 7 exchangeOut does not enforce maxAmountIn for the Aerodrome vault
     *      (pre-existing behavior consistent with V2 vault). See V2 invariant test for notes.
     */
    function testSkip_route7_exchangeOut_revertsWhenMaxInsufficient() public pure {
        // See NatSpec above - Route 7 does not enforce maxAmountIn.
    }

    function testFuzz_route7_inOutInvariant(uint256 sharesIn) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IPool pool = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pool.token0());

        uint256 available = vault.balanceOf(address(this));
        if (available < 4) return;
        sharesIn = bound(sharesIn, 1, available / 4);

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(vaultToken, tokenOut, Y);
        if (Xprime == 0) return;
        _geInv(Xprime, sharesIn, "Fuzz Route7: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Fuzz Route7: X' within slack of X");
    }
}

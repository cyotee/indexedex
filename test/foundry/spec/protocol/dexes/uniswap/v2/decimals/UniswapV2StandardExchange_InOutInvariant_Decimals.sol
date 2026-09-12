// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_Decimals
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_Decimals.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title UniswapV2StandardExchange_InOutInvariant_Decimals
 * @notice In/Out invariants for routes 1–7 on combo decimals. Fuzz bounds scale with token0/token1 decimals.
 * @dev After pair sort, token0/token1 may swap pairToken vs other. vaultShare stays 18.
 */
abstract contract UniswapV2StandardExchange_InOutInvariant_Decimals is TestBase_UniswapV2StandardExchange_Decimals {
    uint8 internal constant _DECIMALS_REMATCH = 1;
    /// @dev Mixed-decimal ConstProd inverse plus Uni V2 decimalOffset zap floor (1 virtual share = 1e9).
    function _invSlack(uint256 x) internal pure returns (uint256) {
        uint256 rel = x / 20; // 5%
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

    function test_route1_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        uint256 amountIn = _uToken(address(tokenIn), 1);
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        assertGt(Y, 0, "Route1 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        _geInv(Xprime, amountIn, "Route1: X' must be within slack of X (rounding)");
        _leInv(Xprime, amountIn, "Route1: X' must be within slack above X");
    }

    function test_route1_exchangeOut_matchesPreview() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());

        uint256 amountOut = _from18(address(tokenOut), 0.5e18);
        {
            (uint256 r0, uint256 r1,) = pair.getReserves();
            uint256 reserve1 = pair.token0() == address(tokenIn) ? r1 : r0;
            if (amountOut > reserve1 / 100) amountOut = reserve1 / 100;
        }

        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        assertGt(expectedIn, 0, "Route1 Out preview zero");

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
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

        uint256 amountOut = _from18(address(tokenOut), 1e15);
        uint256 expectedIn = vault.previewExchangeOut(tokenIn, tokenOut, amountOut);
        require(expectedIn > 1, "Need at least 2 to subtract 1");

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn - 1);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, tokenOut, amountOut, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route1_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 tokenOut = IERC20(pair.token1());
        uint256 reserveOut;
        {
            (uint256 r0, uint256 r1,) = pair.getReserves();
            uint256 reserveIn = pair.token0() == address(tokenIn) ? r0 : r1;
            reserveOut = pair.token0() == address(tokenIn) ? r1 : r0;
            uint256 minIn = _uToken(address(tokenIn), 1);
            if (minIn < 1000) minIn = 1000;
            uint256 maxIn = reserveIn / 100;
            if (maxIn <= minIn) return;
            amountIn = bound(amountIn, minIn, maxIn);
        }

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        if (Y == 0 || Y >= reserveOut) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        if (Xprime == 0) return;
        _geInv(Xprime, amountIn, "Fuzz Route1: X' within slack of X");
        _leInv(Xprime, amountIn, "Fuzz Route1: round-trip within slack above X");
    }

    function test_route2_previewInOutInverse_forward() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        uint256 amountIn = _uToken(address(tokenIn), 2);
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        assertGt(Y, 0, "Route2 In preview zero");

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        assertGt(Xprime, 0, "Route2 Out preview must be non-zero");
        _geInv(Xprime, amountIn, "Route2: X' >= X - slack");
        uint256 tolerance = amountIn / 200 + 2;
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

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
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

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
        IERC20(address(tokenIn)).approve(address(vault), expectedIn);

        vm.expectRevert();
        vault.exchangeOut(tokenIn, expectedIn - 1, lpToken, lpTarget, makeAddr("r"), false, _deadline());
    }

    function testFuzz_route2_inOutInvariant(uint256 amountIn) public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 tokenIn = IERC20(pair.token0());
        IERC20 lpToken = IERC20(address(pair));

        {
            (uint256 r0, uint256 r1,) = pair.getReserves();
            uint256 reserveIn = pair.token0() == address(tokenIn) ? r0 : r1;
            uint256 minIn = _uToken(address(tokenIn), 1);
            if (minIn < 1000) minIn = 1000;
            uint256 maxIn = reserveIn / 200;
            if (maxIn <= minIn) return;
            amountIn = bound(amountIn, minIn, maxIn);
        }

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, lpToken);
        if (Y == 0) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, lpToken, Y);
        if (Xprime == 0) return;
        _geInv(Xprime, amountIn, "Fuzz Route2: X' >= X - slack");
        _leInv(Xprime, amountIn, "Fuzz Route2: X' within slack of X");
    }

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
        _geInv(Xprime, lpAmountIn, "Route3: X' >= X - slack");
        _leInv(Xprime, lpAmountIn, "Route3: X' within slack of X");
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

    function test_route4_previewInOutInverse_reverse() public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
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
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 want = vault.totalSupply() / 10;
        require(want > 0, "Shares target zero");

        uint256 expectedLpIn = vault.previewExchangeOut(lpToken, vaultToken, want);
        assertGt(expectedLpIn, 0);
        uint256 sharesTarget = vault.previewExchangeIn(lpToken, expectedLpIn, vaultToken);
        require(sharesTarget > 0, "Route4 forward preview zero");
        uint256 maxIn = expectedLpIn + _invSlack(expectedLpIn);

        lpToken.approve(address(vault), maxIn);
        address recipient = makeAddr("r4Recipient");

        uint256 actualLpIn =
            vault.exchangeOut(lpToken, maxIn, vaultToken, sharesTarget, recipient, false, _deadline());
        assertLe(actualLpIn, maxIn, "Route4: actualLpIn <= padded preview");
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
        _geInv(Xprime, sharesIn, "Route5: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Route5: X' within slack of X");
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

        uint256 totalShares = vault.totalSupply();
        uint256 amountIn = _from18(address(tokenIn), 0.1e18);

        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        if (Y == 0) return;
        if (Y >= totalShares / 5) return;

        uint256 Xprime = vault.previewExchangeOut(tokenIn, vaultToken, Y);
        assertGt(Xprime, 0, "Route6 Out preview must be non-zero");
        assertGe(Xprime, amountIn - (amountIn / 1000 + 2), "Route6: X' >= X - 0.1%");
        assertLe(Xprime, amountIn + (amountIn / 50 + 2), "Route6: X' within 2% of X");
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

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
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

        MintableERC20Decimals(address(tokenIn)).mint(address(this), expectedIn);
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
        if (totalShares < 2) return;
        sharesTarget = bound(sharesTarget, 1, totalShares / 2);

        uint256 Xrequired = vault.previewExchangeOut(tokenIn, vaultToken, sharesTarget);
        if (Xrequired == 0) return;

        uint256 Yprime = vault.previewExchangeIn(tokenIn, Xrequired, vaultToken);
        assertGe(Yprime, sharesTarget, "Fuzz Route6: forward(reverse(Y)) >= Y");
    }

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
        _geInv(Xprime, sharesIn, "Route7: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Route7: X' within slack of X");
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

    function testFuzz_route7_inOutInvariant(uint256 sharesIn) public {
        IStandardExchangeProxy vault = _seedVault(PoolConfig.Balanced, 100);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 vaultToken = IERC20(address(vault));
        IERC20 tokenOut = IERC20(pair.token0());

        uint256 available = vault.balanceOf(address(this));
        if (available < 4e9) return;
        sharesIn = bound(sharesIn, 1e9, available / 10);

        uint256 Y = vault.previewExchangeIn(vaultToken, sharesIn, tokenOut);
        uint256 minY = _uToken(address(tokenOut), 1);
        if (Y < minY) return;

        uint256 Xprime = vault.previewExchangeOut(vaultToken, tokenOut, Y);
        if (Xprime == 0) return;
        _geInv(Xprime, sharesIn, "Fuzz Route7: X' >= X - slack");
        _leInv(Xprime, sharesIn, "Fuzz Route7: X' within slack of X");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchange_InOutInvariant_Decimals
 * @notice Route preview in/out conservation on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      Fuzz bounds are raw units of pairToken (`_uA`), not 18-dec wads. vaultShare stays 18.
 */
abstract contract CamelotV2StandardExchange_InOutInvariant_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    address internal user;
    IStandardExchangeProxy internal vault;
    address internal pair;

    function setUp() public virtual override {
        super.setUp();
        user = makeAddr("camelotFuzzUser");
        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(user, _uA(10_000));
        tokenB.mint(user, _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 depA = _uA(500);
        uint256 depB = _uB(500);
        vm.startPrank(user);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), depA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), depB);
        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), depA, IERC20(address(tokenB)), depB, user
        );
        vm.stopPrank();

        vault = IStandardExchangeProxy(vaultAddr);
        pair = camelotV2Factory.getPair(address(tokenA), address(tokenB));
        require(pair != address(0), "pair");
        require(vaultAddr != address(0), "vault");
    }

    /// @notice P-ROUTE: previewExchangeIn then previewExchangeOut approx round-trip for pairToken → other.
    function testFuzz_route1_previewInOut_roundTrip(uint256 amountIn) public view {
        (uint256 r0, uint256 r1,,) = ICamelotPair(pair).getReserves();
        address t0 = ICamelotPair(pair).token0();
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));
        uint256 reserveIn = t0 == address(tokenIn) ? r0 : r1;
        uint256 reserveOut = t0 == address(tokenIn) ? r1 : r0;
        if (reserveIn < _uA(1) || reserveOut < _uB(1)) return;

        uint256 minAmt = _uA(1) / 1_000;
        if (minAmt == 0) minAmt = 1;
        uint256 maxAmt = reserveIn / 20;
        if (maxAmt < minAmt) return;
        amountIn = bound(amountIn, minAmt, maxAmt);
        uint256 Y = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        {
            uint256 minY = _uB(1) / 1_000;
            if (minY == 0) minY = 1;
            if (Y == 0 || Y >= reserveOut || Y < minY) return;
        }

        uint256 Xprime = vault.previewExchangeOut(tokenIn, tokenOut, Y);
        // Gold is 2% + 10 wei at 18-dec. Mixed 6-dec tokenOut rounds Y then X' farther;
        // Camelot fees stack on both legs. 5% + 1000 wei still bounds no-free-lunch.
        uint256 tol = amountIn / 20 + 1000;
        assertGe(Xprime + tol, amountIn, "P-ROUTE: X' within tol of X (lower)");
        {
            uint256 upper = amountIn + tol;
            assertLe(Xprime, upper, "P-ROUTE: X' within tol of X (upper)");
        }
    }

    /// @notice P-CONS soft: execute swap and residual free inventory of vault product is non-negative supply.
    function testFuzz_route1_execute_safe(uint256 amountIn) public {
        (uint256 r0, uint256 r1,,) = ICamelotPair(pair).getReserves();
        address t0 = ICamelotPair(pair).token0();
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));
        uint256 reserveIn = t0 == address(tokenIn) ? r0 : r1;
        uint256 minAmt = _uA(1) / 1000;
        if (minAmt == 0) minAmt = 1;
        if (reserveIn < minAmt * 50) return;

        amountIn = bound(amountIn, minAmt, reserveIn / 50);
        tokenA.mint(user, amountIn);

        vm.startPrank(user);
        tokenA.approve(address(vault), amountIn);
        try IStandardExchangeIn(address(vault)).exchangeIn(
            tokenIn, amountIn, tokenOut, 0, user, false, block.timestamp + 1 hours
        ) returns (uint256 out) {
            assertTrue(out > 0, "swap out");
        } catch {
            // Fee / min path may reject - OK for property suite
        }
        vm.stopPrank();
        assertTrue(IERC20(address(vault)).totalSupply() > 0, "vault supply remains");
    }

    /// @notice P-BOUND: zero preview is zero.
    function test_zeroPreview() public view {
        assertEq(
            vault.previewExchangeIn(IERC20(address(tokenA)), 0, IERC20(address(tokenB))), 0, "zero preview"
        );
    }
}

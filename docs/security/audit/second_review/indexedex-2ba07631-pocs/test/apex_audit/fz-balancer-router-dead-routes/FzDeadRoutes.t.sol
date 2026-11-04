// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SwapKind, VaultSwapParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {P4BalancerInvariantBase} from "./P4BalancerInvariant.t.sol";
import {IP4SERouter} from "./P4BalancerHandler.sol";

interface IBV3 {
    function unlock(bytes calldata data) external returns (bytes memory);
    function swap(VaultSwapParams memory p) external returns (uint256, uint256, uint256);
    function settle(IERC20 token, uint256 hint) external returns (uint256);
    function sendTo(IERC20 token, address to, uint256 amount) external;
    function getReservesOf(IERC20 token) external view returns (uint256);
    function getTokenDelta(IERC20 token) external view returns (int256);
}

interface ISE {
    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minOut, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256);
}

/// @notice Replicates the SE router route-2 exact-in sequence (and a fixed ordering) inside a Balancer unlock.
contract Route2Replicator {
    error Diag(uint256 sharesDeposited, uint256 reservesAfterSwap, uint256 vaultBalAfterSwap, uint256 credit, int256 sharesDeltaAfterSettle);

    IBV3 immutable bv;
    address immutable pool;
    IERC20 immutable usdc;
    IERC20 immutable sh;
    IERC20 immutable dai;

    constructor(address bv_, address pool_, address usdc_, address sh_, address dai_) {
        bv = IBV3(bv_);
        pool = pool_;
        usdc = IERC20(usdc_);
        sh = IERC20(sh_);
        dai = IERC20(dai_);
    }

    function run(uint256 amt, bool routerOrder) external returns (uint256 out) {
        out = abi.decode(bv.unlock(abi.encodeCall(this.cb, (amt, routerOrder, msg.sender))), (uint256));
    }

    function cb(uint256 amt, bool routerOrder, address to) external returns (uint256) {
        require(msg.sender == address(bv), "only vault");
        usdc.approve(address(sh), amt);
        VaultSwapParams memory p;
        p.kind = SwapKind.EXACT_IN;
        p.pool = pool;
        p.tokenIn = sh;
        p.tokenOut = dai;
        if (routerOrder) {// EXACTLY the SE router order: shares minted straight into the Balancer vault BEFORE swap, settle AFTER.
            uint256 s = ISE(address(sh)).exchangeIn(usdc, amt, sh, 0, address(bv), false, block.timestamp);
            p.amountGivenRaw = s;
            (,, uint256 o) = bv.swap(p);
            uint256 resAfter = bv.getReservesOf(sh);
            uint256 balAfter = sh.balanceOf(address(bv));
            uint256 credit = bv.settle(sh, s);
            revert Diag(s, resAfter, balAfter, credit, bv.getTokenDelta(sh));
            // unreachable
            // bv.sendTo(dai, to, o);
        } else {// FIX ordering: mint shares to self, swap, THEN pay the vault and settle immediately.
            uint256 s = ISE(address(sh)).exchangeIn(usdc, amt, sh, 0, address(this), false, block.timestamp);
            p.amountGivenRaw = s;
            (,, uint256 o) = bv.swap(p);
            sh.transfer(address(bv), s);
            bv.settle(sh, s);
            bv.sendTo(dai, to, o);
            return o;
        }
    }
}


interface ISEOut {
    function exchangeOut(IERC20 tokenIn, uint256 maxIn, IERC20 tokenOut, uint256 amountOut, address recipient, bool pretransferred, uint256 deadline)
        external
        returns (uint256);
    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut) external view returns (uint256);
}

/// @notice Route-2 exact-out sequence (swap, SE exact-out mint into BV3, settle(hint = USDC amountIn)) with diagnostics.
contract Route2OutReplicator {
    error Diag2(uint256 swapAmountIn, uint256 usdcAmountIn, uint256 minted, uint256 resPreSettle, uint256 balPreSettle, uint256 credit, int256 shDelta, int256 daiDelta);

    IBV3 immutable bv;
    address immutable pool;
    IERC20 immutable usdc;
    IERC20 immutable sh;
    IERC20 immutable dai;

    constructor(address bv_, address pool_, address usdc_, address sh_, address dai_) {
        bv = IBV3(bv_);
        pool = pool_;
        usdc = IERC20(usdc_);
        sh = IERC20(sh_);
        dai = IERC20(dai_);
    }

    function run(uint256 out) external {
        bv.unlock(abi.encodeCall(this.cb, (out)));
    }

    function cb(uint256 out) external returns (uint256) {
        VaultSwapParams memory p;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = pool;
        p.tokenIn = sh;
        p.tokenOut = dai;
        p.amountGivenRaw = out;
        p.limitRaw = type(uint256).max;
        (, uint256 sIn,) = bv.swap(p);
        uint256 pay = ISEOut(address(sh)).previewExchangeOut(usdc, sh, sIn);
        usdc.approve(address(sh), pay);
        uint256 b0 = sh.balanceOf(address(bv));
        uint256 used = ISEOut(address(sh)).exchangeOut(usdc, pay, sh, sIn, address(bv), false, block.timestamp);
        uint256 minted = sh.balanceOf(address(bv)) - b0;
        uint256 res = bv.getReservesOf(sh);
        uint256 bal = sh.balanceOf(address(bv));
        uint256 credit = bv.settle(sh, used); // router passes actualAmountIn (tokenIn units) as the hint
        bv.sendTo(dai, address(this), out);
        revert Diag2(sIn, used, minted, res, bal, credit, bv.getTokenDelta(sh), bv.getTokenDelta(dai));
    }
}

contract FzDeadRoutesTest is P4BalancerInvariantBase {
    address internal user;

    function _aggKey() internal pure returns (string memory) {
        return "FZ_DEAD";
    }

    function setUp() public override {
        super.setUp();
        user = makeAddr("routeUser");
        dai.mint(user, 10_000e18);
        usdc.mint(user, 10_000e18);
        vm.startPrank(user);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);
        IERC20(address(usdc)).approve(address(permit2), type(uint256).max);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(dai), seRouterAddr, type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), seRouterAddr, type(uint160).max, type(uint48).max);
        permit2.approve(address(seVault), seRouterAddr, type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    struct Bal {
        uint256 uDai;
        uint256 uUsdc;
        uint256 uSh;
        uint256 rDai;
        uint256 rUsdc;
        uint256 rSh;
        uint256 vSh;
        uint256 vDai;
        uint256 vUsdc;
    }

    function _bal() internal view returns (Bal memory b) {
        b.uDai = dai.balanceOf(user);
        b.uUsdc = usdc.balanceOf(user);
        b.uSh = IERC20(address(seVault)).balanceOf(user);
        b.rDai = dai.balanceOf(seRouterAddr);
        b.rUsdc = usdc.balanceOf(seRouterAddr);
        b.rSh = IERC20(address(seVault)).balanceOf(seRouterAddr);
        b.vSh = IERC20(address(seVault)).balanceOf(address(vault));
        b.vDai = dai.balanceOf(address(vault));
        b.vUsdc = usdc.balanceOf(address(vault));
    }

    function _assertUnchanged(Bal memory a, Bal memory b) internal pure {
        assertEq(a.uDai, b.uDai, "user DAI");
        assertEq(a.uUsdc, b.uUsdc, "user USDC");
        assertEq(a.uSh, b.uSh, "user shares");
        assertEq(a.rDai + a.rUsdc + a.rSh, b.rDai + b.rUsdc + b.rSh, "router residue");
        assertEq(a.vSh, b.vSh, "vault shares");
        assertEq(a.vDai, b.vDai, "vault DAI");
        assertEq(a.vUsdc, b.vUsdc, "vault USDC");
    }

    function _sel(bytes memory r) internal pure returns (bytes4 s) {
        if (r.length >= 4) assembly { s := mload(add(r, 32)) }
    }

    /* ---------------- Route 2 exact-in: BalanceNotSettled ---------------- */

    /// Root cause: hook settle() mid-swap sweeps the router's unsettled pre-sent shares into reserves w/o credit.
    function test_r2in_rootCause_hookSettleAbsorbsPreSentShares() public {
        Route2Replicator rep = new Route2Replicator(address(vault), bufferPool, address(usdc), address(seVault), address(dai));
        usdc.mint(address(rep), 1000e18);
        uint256 res0 = IBV3(address(vault)).getReservesOf(IERC20(address(seVault)));
        try rep.run(50e18, true) {
            fail("router-order unexpectedly succeeded");
        } catch (bytes memory r) {
            assertEq(_sel(r), Route2Replicator.Diag.selector, "expected Diag");
            bytes memory body = new bytes(r.length - 4);
            for (uint256 i; i < body.length; i++) body[i] = r[i + 4];
            (uint256 s, uint256 resAfter, uint256 balAfter, uint256 credit, int256 delta) =
                abi.decode(body, (uint256, uint256, uint256, uint256, int256));
            console2.log("shares pre-sent to BV3 vault     ", s);
            console2.log("BV3 shares reserves before       ", res0);
            console2.log("BV3 shares reserves after swap   ", resAfter);
            console2.log("BV3 shares balance  after swap   ", balAfter);
            console2.log("router settle credit (hint = s)  ", credit);
            console2.logInt(delta);
            // reserves already == balance after the swap => the hook's settle() absorbed the router's shares
            assertEq(resAfter, balAfter, "hook settle synced reserves to balance (pre-sent shares absorbed)");
            assertLt(credit, s, "router gets less credit than the shares it sent");
            assertGt(delta, 0, "shares debt remains -> BalanceNotSettled");
        }
    }

    /// Fix: mint shares to the router, swap, then transfer+settle -> works.
    function test_r2in_fixedOrdering_succeeds() public {
        Route2Replicator rep = new Route2Replicator(address(vault), bufferPool, address(usdc), address(seVault), address(dai));
        usdc.mint(address(rep), 1000e18);
        uint256 d0 = dai.balanceOf(address(this));
        uint256 out = rep.run(50e18, false);
        console2.log("fixed-order route2 exactIn DAI out", out);
        assertGt(out, 0);
        assertEq(dai.balanceOf(address(this)) - d0, out);
    }

    /// Liveness: the real router reverts for every size; nothing is stranded.
    function test_r2in_router_alwaysReverts_noFundsStuck() public {
        uint256[6] memory amts = [uint256(1e16), 1e17, 1e18, 10e18, 50e18, 500e18];
        for (uint256 i; i < amts.length; i++) {
            Bal memory b0 = _bal();
            vm.prank(user);
            (bool ok, bytes memory r) = seRouterAddr.call(
                abi.encodeCall(
                    IP4SERouter.swapSingleTokenExactIn,
                    (bufferPool, address(usdc), address(seVault), address(dai), address(0), amts[i], 0, block.timestamp + 1 hours, false, "")
                )
            );
            console2.log("r2 exactIn amt", amts[i], ok);
            console2.logBytes4(_sel(r));
            assertFalse(ok, "route2 exactIn should be dead");
            assertEq(_sel(r), bytes4(keccak256("BalanceNotSettled()")), "BalanceNotSettled");
            _assertUnchanged(b0, _bal());
        }
    }

    /* ---------------- Route 3 exact-out: FailedCall ---------------- */

    function test_r3out_router_alwaysReverts_noFundsStuck() public {
        uint256[5] memory outs = [uint256(1e16), 1e18, 10e18, 20e18, 100e18];
        for (uint256 i; i < outs.length; i++) {
            Bal memory b0 = _bal();
            vm.prank(user);
            (bool ok, bytes memory r) = seRouterAddr.call(
                abi.encodeCall(
                    IP4SERouter.swapSingleTokenExactOut,
                    (bufferPool, address(dai), address(0), address(usdc), address(seVault), outs[i], 5000e18, block.timestamp + 1 hours, false, "")
                )
            );
            console2.log("r3 exactOut out", outs[i], ok);
            console2.logBytes4(_sel(r));
            assertFalse(ok, "route3 exactOut should be dead");
            assertEq(_sel(r), bytes4(keccak256("FailedCall()")), "FailedCall");
            _assertUnchanged(b0, _bal());
        }
    }

    /// Root cause: _exchangeOutFromVault always targets params.tokenInVault, which is address(0) on route 3.
    /// A high-level call to a codeless address reverts with empty data; the diamond fallback wraps it as FailedCall.
    function test_r3out_rootCause_callToTokenInVaultZero() public {
        (bool ok, bytes memory r) = address(this).call(abi.encodeCall(this.ext_callZero, ()));
        console2.log("call to IStandardExchange(address(0)).exchangeOut ok?", ok, r.length);
        assertFalse(ok);
        assertEq(r.length, 0, "empty revert data -> wrapped as FailedCall by diamond proxy");
    }

    function ext_callZero() external {ISE(address(0)).exchangeIn(IERC20(address(dai)), 1, IERC20(address(usdc)), 0, address(this), true, block.timestamp);
    }

    /* ---------------- Route 2 exact-out: intermittent ---------------- */

    function test_r2out_sweep() public {
        uint256[8] memory outs = [uint256(1e16), 1e17, 1e18, 10e18, 50e18, 100e18, 200e18, 300e18];
        for (uint256 t; t < 2; t++) {
            for (uint256 i; i < outs.length; i++) {
                uint256 snap = vm.snapshotState();
                uint256 maxIn = 5000e18;
                if (t == 1) {
                    vm.prank(address(0), address(0));
                    try IP4SERouter(seRouterAddr).querySwapSingleTokenExactOut(
                        bufferPool, address(usdc), address(seVault), address(dai), address(0), outs[i], user, ""
                    ) returns (uint256 q) {
                        vm.revertToState(snap);
                        snap = vm.snapshotState();
                        maxIn = q + q / 200 + 1;
                    } catch (bytes memory qr) {
                        vm.revertToState(snap);
                        snap = vm.snapshotState();
                        console2.log("  query reverted for out", outs[i]);
                        console2.logBytes(qr);
                    }
                }
                Bal memory b0 = _bal();
                vm.prank(user);
                (bool ok, bytes memory r) = seRouterAddr.call(
                    abi.encodeCall(
                        IP4SERouter.swapSingleTokenExactOut,
                        (bufferPool, address(usdc), address(seVault), address(dai), address(0), outs[i], maxIn, block.timestamp + 1 hours, false, "")
                    )
                );
                Bal memory b1 = _bal();
                console2.log(t == 1 ? "r2 exactOut TIGHT out/maxIn/ok" : "r2 exactOut LOOSE out/maxIn/ok", outs[i], maxIn, ok);
                if (!ok) {
                    console2.logBytes(r);
                    _assertUnchanged(b0, b1);
                } else {
                    console2.log("   spent USDC / got DAI", b0.uUsdc - b1.uUsdc, b1.uDai - b0.uDai);
                    console2.log("   router residue usdc/sh", b1.rUsdc, b1.rSh);
                    console2.log("   BV3 vault shares delta(+)", b1.vSh >= b0.vSh ? b1.vSh - b0.vSh : 0);
                    console2.log("   BV3 vault shares delta(-)", b1.vSh < b0.vSh ? b0.vSh - b1.vSh : 0);
                }
                vm.revertToState(snap);
            }
        }
    }

    /// Drive the P4 handler through pseudo-random state and attempt route-2 exact-out often; failures are logged.
    function test_r2out_randomStates() public {
        uint256 att;
        for (uint256 i; i < 160; i++) {
            uint256 sd = uint256(keccak256(abi.encode(i, "fz")));
            uint256 k = sd % 9;
            uint256 a1 = uint256(keccak256(abi.encode(sd, 1)));
            uint256 a2 = uint256(keccak256(abi.encode(sd, 2)));
            if (k <= 2) {
                att++;
                try h.h_seSwapExactOut(a1, 2, a2, (sd >> 8) % 2 == 0) {} catch {}
            } else if (k == 3) {
                try h.h_aeroMarket(a1, a2) {} catch {}
            } else if (k == 4) {
                try h.h_mockSwapExactIn(a1, a2 % 2, a2) {} catch {}
            } else if (k == 5) {
                try h.h_donate(a1, a2, a1 >> 3) {} catch {}
            } else if (k == 6) {
                try h.h_warp(a2) {} catch {}
            } else if (k == 7) {
                try h.a_aeroMovePersistent(a2) {} catch {}
            } else {
                try h.h_seSwapExactIn(a1, a2 % 2, a2) {} catch {}
            }
        }
        console2.log("r2 exactOut attempts / ok / fails", h.seOutAtt(2), h.seOutOk(2), h.r2OutFails());
    }

    struct D2 {
        uint256 sIn;
        uint256 usdcIn;
        uint256 minted;
        uint256 res;
        uint256 bal;
        uint256 credit;
        int256 shDelta;
        int256 daiDelta;
    }

    function _decodeDiag2(bytes memory r) internal pure returns (D2 memory d) {
        bytes memory body = new bytes(r.length - 4);
        for (uint256 i; i < body.length; i++) body[i] = r[i + 4];
        d = abi.decode(body, (D2));
    }

    function _diagAt(uint256 out) internal {
        Route2OutReplicator rep = new Route2OutReplicator(address(vault), bufferPool, address(usdc), address(seVault), address(dai));
        usdc.mint(address(rep), 100_000e18);
        try rep.run(out) {
            console2.log("  replicator unexpectedly returned");
        } catch (bytes memory r) {
            if (_sel(r) == Route2OutReplicator.Diag2.selector) {
                D2 memory d = _decodeDiag2(r);
                console2.log("  DIAG2 swapAmountIn(sh) / usdcIn / minted", d.sIn, d.usdcIn, d.minted);
                console2.log("  DIAG2 resPreSettle / balPreSettle / credit", d.res, d.bal, d.credit);
                console2.log("  DIAG2 shDelta / daiDelta");
                console2.logInt(d.shDelta);
                console2.logInt(d.daiDelta);
            } else {
                console2.log("  replicator reverted (other)");
                console2.logBytes(r);
            }
        }
        // route 1 (direct shares -> DAI exact-out) by the real router in the same state
        uint256 snap = vm.snapshotState();
        address u1 = makeAddr("r1user");
        vm.startPrank(u1);
        usdc.mint(u1, 100_000e18);
        IERC20(address(usdc)).approve(address(seVault), type(uint256).max);ISE(address(seVault)).exchangeIn(IERC20(address(usdc)), 5_000e18, IERC20(address(seVault)), 0, u1, false, block.timestamp);
        IERC20(address(seVault)).approve(address(permit2), type(uint256).max);
        permit2.approve(address(seVault), seRouterAddr, type(uint160).max, type(uint48).max);
        (bool ok1, bytes memory r1) = seRouterAddr.call(
            abi.encodeCall(
                IP4SERouter.swapSingleTokenExactOut,
                (bufferPool, address(seVault), address(0), address(dai), address(0), out, type(uint256).max, block.timestamp + 1 hours, false, "")
            )
        );
        vm.stopPrank();
        console2.log("  route1 (direct shares->DAI exactOut) same out ok?", ok1);
        if (!ok1) console2.logBytes(r1);
        vm.revertToState(snap);
        // real router route 2 exact-out with ample limit, fresh funded user
        snap = vm.snapshotState();
        usdc.mint(user, 100_000e18);
        vm.prank(user);
        (bool ok2, bytes memory r2) = seRouterAddr.call(
            abi.encodeCall(
                IP4SERouter.swapSingleTokenExactOut,
                (bufferPool, address(usdc), address(seVault), address(dai), address(0), out, 50_000e18, block.timestamp + 1 hours, false, "")
            )
        );
        console2.log("  real router route2 exactOut ample-limit ok?", ok2);
        if (!ok2) console2.logBytes(r2);
        vm.revertToState(snap);
    }

    function test_r2out_diagFailingStates() public {
        uint256 diags;
        for (uint256 i; i < 160 && diags < 3; i++) {
            uint256 sd = uint256(keccak256(abi.encode(i, "fz")));
            uint256 k = sd % 9;
            uint256 a1 = uint256(keccak256(abi.encode(sd, 1)));
            uint256 a2 = uint256(keccak256(abi.encode(sd, 2)));
            if (k <= 2) {
                uint256 f0 = h.r2OutFails();
                uint256 snap = vm.snapshotState();
                try h.h_seSwapExactOut(a1, 2, a2, (sd >> 8) % 2 == 0) {} catch {}
                if (h.r2OutFails() > f0 && h.lastR2Err() == bytes4(keccak256("BalanceNotSettled()"))) {
                    uint256 out = h.lastR2Out();
                    vm.revertToState(snap);
                    diags++;
                    console2.log("=== BNS state at step", i, "out", out);
                    _diagAt(out);
                    // re-apply the handler call so the state sequence continues identically
                    try h.h_seSwapExactOut(a1, 2, a2, (sd >> 8) % 2 == 0) {} catch {}
                }
            } else if (k == 3) {
                try h.h_aeroMarket(a1, a2) {} catch {}
            } else if (k == 4) {
                try h.h_mockSwapExactIn(a1, a2 % 2, a2) {} catch {}
            } else if (k == 5) {
                try h.h_donate(a1, a2, a1 >> 3) {} catch {}
            } else if (k == 6) {
                try h.h_warp(a2) {} catch {}
            } else if (k == 7) {
                try h.a_aeroMovePersistent(a2) {} catch {}
            } else {
                try h.h_seSwapExactIn(a1, a2 % 2, a2) {} catch {}
            }
        }
        assertGt(diags, 0, "no BNS state reached");
    }
}

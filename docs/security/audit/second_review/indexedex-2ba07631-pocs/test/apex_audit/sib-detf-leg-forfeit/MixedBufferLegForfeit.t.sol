// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MixedBufferMultiVaultStableDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf.sol";

/// sib-detf-leg-forfeit / MixedBuffer: primary burn (gate open) sizes LP pro-rata of all protocol LP,
/// exits proportionally, pays only the selected leg (buffer OR one share leg) and re-joins every other
/// non-DETF leg into protocol LP. Honest-user loss; forfeit accrues to remaining holders.
interface IVaultTokensLF { function getPoolTokens(address rpool) external view returns (address[] memory); }

contract SibLegForfeit_MixedBuffer_Test is TestBase_MixedBufferMultiVaultStableDetf {
    address internal holder2;
    address internal rpool;

    function setUp() public override {
        super.setUp();
        holder2 = makeAddr("sib_holder2");
        // Burn gate open by config (same convention as r3-H3SP-1 ComposedStable): mint 1e30 > burn 1e29.
        _useDetf(_deployDetfN(1, 1e30, 1e29));
        _bootstrapDefault(detf, bob);
        rpool = detfInfo.reservePool();
        // honest buyers acquire DETF through the normal exchangeIn route (reserve swap; mint gate closed)
        _mintDetfFromBuffer(detf, alice, 200e18);
        _mintDetfFromBuffer(detf, holder2, 200e18);
    }

    function _idx(address tok_) internal view returns (uint256) {
        address[] memory toks_ = IVaultTokensLF(address(vault)).getPoolTokens(rpool);
        for (uint256 i; i < toks_.length; ++i) if (toks_[i] == tok_) return i;
        revert("idx");
    }

    function _protocolLp() internal view returns (uint256) {
        return IERC20(rpool).balanceOf(detf) + IERC20(rpool).balanceOf(detfInfo.bondNftVault());
    }

    function _burn(address who_, uint256 amt_, IERC20 out_) internal returns (uint256 got_) {
        vm.startPrank(who_);
        IERC20(detf).approve(detf, amt_);got_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amt_, out_, 0, who_, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    struct M { uint256 d; uint256 lpOut; uint256 sliceOutRaw; uint256 sliceOutLive; uint256 sliceOtherLive;
        uint256 recv; uint256 h2Base; uint256 h2After; uint256 sAfter; uint256 lp0; uint256 lp1; }

    function _run(IERC20 out_, IERC20 other_, string memory tag_) internal {
        M memory m;
        assertTrue(detfInfo.isBurningAllowed(), "primary burn open");
        m.d = IERC20(detf).balanceOf(alice) / 2;
        uint256 h_ = IERC20(detf).balanceOf(holder2);
        uint256 snap_ = vm.snapshotState();
        // baseline: holder2 redeems everything to out_ without alice's redemption
        m.h2Base = _burn(holder2, h_, out_);
        vm.revertToState(snap_);

        // expected proportional slice of alice's LP
        m.lp0 = _protocolLp();
        m.lpOut = m.d * m.lp0 / IERC20(detf).totalSupply();
        (,, uint256[] memory raw_, uint256[] memory live_) = IVault(address(vault)).getPoolTokenInfo(rpool);
        uint256 bptS_ = IERC20(rpool).totalSupply();
        uint256 io_ = _idx(address(out_));
        uint256 ix_ = _idx(address(other_));
        m.sliceOutRaw = m.lpOut * raw_[io_] / bptS_;
        m.sliceOutLive = m.lpOut * live_[io_] / bptS_;
        m.sliceOtherLive = m.lpOut * live_[ix_] / bptS_;

        m.recv = _burn(alice, m.d, out_);
        m.lp1 = _protocolLp();
        m.sAfter = IERC20(detf).totalSupply();
        m.h2After = _burn(holder2, h_, out_);

        console2.log(tag_);
        console2.log("  alice DETF burned          ", m.d);
        console2.log("  lpOut (pro-rata of all LP) ", m.lpOut);
        console2.log("  slice selected leg raw     ", m.sliceOutRaw);
        console2.log("  received                   ", m.recv);
        console2.log("  slice selected leg live18  ", m.sliceOutLive);
        console2.log("  slice forfeited leg live18 ", m.sliceOtherLive);
        uint256 lossBps_ = m.sliceOtherLive * 1e4 / (m.sliceOtherLive + m.sliceOutLive);
        console2.log("  alice loss bps of backing  ", lossBps_);
        console2.log("  protocol LP before/after   ", m.lp0, m.lp1);
        console2.log("  LP/DETF before x1e18       ", m.lp0 * 1e18 / (m.sAfter + m.d));
        console2.log("  LP/DETF after  x1e18       ", m.lp1 * 1e18 / m.sAfter);
        uint256 lpGain_ = m.lp1 - m.lp0 * m.sAfter / (m.sAfter + m.d);
        console2.log("  remaining-holder LP gain   ", lpGain_);
        console2.log("  LP gain / lpOut bps        ", lpGain_ * 1e4 / m.lpOut);
        console2.log("  holder2 redeem base/after  ", m.h2Base, m.h2After);
        console2.log("  holder2 gain               ", m.h2After - m.h2Base);

        assertApproxEqRel(m.recv, m.sliceOutRaw, 1e15, "paid exactly the selected leg of the proportional slice");
        assertGt(lossBps_, 1000, "user forfeits >10% of non-DETF backing");
        assertGt(m.lp1 * 1e18 / m.sAfter, m.lp0 * 1e18 / (m.sAfter + m.d), "forfeit re-joined: LP per DETF rises");
        assertGe(m.h2After, m.h2Base, "remaining holder never worse off");
    }

    function test_mb_burnToBuffer_forfeitsShareLeg() public {
        _run(IERC20(detfInfo.bufferToken()), IERC20(detfInfo.vaultShares()[0]), "MixedBuffer N=1 burn -> buffer");
    }

    function test_mb_burnToShare_forfeitsBufferLeg() public {
        _run(IERC20(detfInfo.vaultShares()[0]), IERC20(detfInfo.bufferToken()), "MixedBuffer N=1 burn -> share0");
    }
}

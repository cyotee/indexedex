// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";
import {
    TestBase_MultiVaultWeightedDetf
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";

interface IVaultTokensMvwLF { function getPoolTokens(address p) external view returns (address[] memory); }

/// sib-detf-leg-forfeit / MultiVaultWeighted (N=2 and N=3): primary burn pays only shares_[leg] of a proportional
/// exit sized pro-rata of all protocol LP; all other share legs are re-joined to protocol LP.
contract SibLegForfeit_Mvw_Test is TestBase_MultiVaultWeightedDetf {
    address internal holder2;
    address internal inst;
    address internal rpool;

    function _setup(uint8 n_) internal {
        holder2 = makeAddr("sib_holder2");
        inst = _deployDetfN(n_, 1e30, 1e29, true);
        _goLiveViaBptBond(inst, bob, 1_000e18);
        rpool = IMultiVaultWeightedDetfInfo(inst).reservePool();
        // honest buyers acquire DETF through exchangeIn (mint gate closed -> reserve swap)
        _mintOnLeg(inst, 0, alice, 100e18);
        _mintOnLeg(inst, 0, holder2, 100e18);
    }

    function _idx(address tok_) internal view returns (uint256) {
        address[] memory toks_ = IVaultTokensMvwLF(address(vault)).getPoolTokens(rpool);
        for (uint256 i; i < toks_.length; ++i) if (toks_[i] == tok_) return i;
        revert("idx");
    }

    function _protocolLp() internal view returns (uint256) {
        return IERC20(rpool).balanceOf(inst) + IERC20(rpool).balanceOf(IMultiVaultWeightedDetfInfo(inst).bondNftVault());
    }

    function _burn(address who_, uint256 amt_, IERC20 out_) internal returns (uint256 got_) {
        vm.startPrank(who_);
        IERC20(inst).approve(inst, amt_);got_ = IStandardExchangeIn(inst).exchangeIn(IERC20(inst), amt_, out_, 0, who_, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    struct M { uint256 d; uint256 lpOut; uint256 sliceOutRaw; uint256 valOut; uint256 valOther; uint256 recv;
        uint256 lp0; uint256 lp1; uint256 sAfter; uint256 h2Base; uint256 h2After; }

    function _value(uint256 lpOut_, uint256 leg_) internal view returns (uint256 sliceOutRaw_, uint256 valOut_, uint256 valOther_) {
        address[] memory shares_ = IMultiVaultWeightedDetfInfo(inst).vaultShares();
        (,, uint256[] memory raw_, uint256[] memory live_) = IVault(address(vault)).getPoolTokenInfo(rpool);
        uint256 io_ = _idx(shares_[leg_]);
        sliceOutRaw_ = lpOut_ * raw_[io_] / IERC20(rpool).totalSupply();
        valOut_ = lpOut_ * live_[io_] / IERC20(rpool).totalSupply();
        for (uint256 i; i < shares_.length; ++i) {
            if (i == leg_) continue;
            valOther_ += _otherVal(lpOut_, live_, io_, _idx(shares_[i]), i, leg_);
        }
    }

    /// weighted spot: price(i in out) = (live_out / w_out) / (live_i / w_i)
    function _otherVal(uint256 lpOut_, uint256[] memory live_, uint256 io_, uint256 ii_, uint256 i_, uint256 leg_)
        internal view returns (uint256)
    {
        (, uint256[] memory w_) = IMultiVaultWeightedDetfInfo(inst).weights();
        uint256 sliceLive_ = lpOut_ * live_[ii_] / IERC20(rpool).totalSupply();
        return sliceLive_ * (live_[io_] * w_[i_]) / (live_[ii_] * w_[leg_]);
    }

    function _run(uint8 n_, uint256 leg_) internal {
        _setup(n_);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(inst);
        assertTrue(info_.isBurningAllowed(), "primary burn open");
        address[] memory shares_ = info_.vaultShares();
        M memory m;
        m.d = IERC20(inst).balanceOf(alice) / 2;
        uint256 h_ = IERC20(inst).balanceOf(holder2);
        IERC20 out_ = IERC20(shares_[leg_]);
        uint256 snap_ = vm.snapshotState();
        m.h2Base = _burn(holder2, h_, out_);
        vm.revertToState(snap_);

        m.lp0 = _protocolLp();
        m.lpOut = m.d * m.lp0 / IERC20(inst).totalSupply();
        (m.sliceOutRaw, m.valOut, m.valOther) = _value(m.lpOut, leg_);

        m.recv = _burn(alice, m.d, out_);
        m.lp1 = _protocolLp();
        m.sAfter = IERC20(inst).totalSupply();
        m.h2After = _burn(holder2, h_, out_);

        uint256 lossBps_ = m.valOther * 1e4 / (m.valOther + m.valOut);
        uint256 lpGain_ = m.lp1 - m.lp0 * m.sAfter / (m.sAfter + m.d);
        console2.log("MVW N / out leg            ", n_, leg_);
        console2.log("  alice DETF burned          ", m.d);
        console2.log("  lpOut                      ", m.lpOut);
        console2.log("  slice selected leg raw     ", m.sliceOutRaw);
        console2.log("  received                   ", m.recv);
        console2.log("  fair non-DETF value (out)  ", m.valOut + m.valOther);
        console2.log("  forfeited value (out units)", m.valOther);
        console2.log("  alice loss bps of backing  ", lossBps_);
        console2.log("  remaining-holder LP gain   ", lpGain_);
        console2.log("  LP gain / lpOut bps        ", lpGain_ * 1e4 / m.lpOut);
        console2.log("  holder2 redeem base/after  ", m.h2Base, m.h2After);

        assertApproxEqRel(m.recv, m.sliceOutRaw, 1e15, "paid exactly the selected leg of the proportional slice");
        assertGt(lossBps_, 1000, "user forfeits >10% of non-DETF backing");
        assertGt(lpGain_, 0, "forfeit re-joined into protocol LP");
        assertGe(m.h2After, m.h2Base, "remaining holder never worse off");
    }

    function test_mvw_N2_burnToLeg0() public { _run(2, 0); }
    function test_mvw_N2_burnToLeg1() public { _run(2, 1); }
    function test_mvw_N3_burnToLeg0() public { _run(3, 0); }
}

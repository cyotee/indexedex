// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {FundedBalancerEpochAssertions} from "contracts/test/bases/FundedBalancerEpochAssertions.sol";
import {TestBase_SingleStandardExchangeDETF} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";

interface IDETFSYView {
    function getTokensIn() external view returns (address[] memory);
    function exchangeRate() external view returns (uint256);
}

/// Unprivileged attacker contract (has bytecode so it passes pretransfer EOA gates).
contract GxAttacker {
    function donatePre(address nft, IERC20 token, uint256 amount) external returns (uint256) {
        return IDetfNftReserveDonation(nft).donate(token, amount, 0, true, block.timestamp);
    }

    function redeemInternal(address sy, uint256 shares, address out) external returns (uint256) {
        return IStandardizedYield(sy).redeem(address(this), shares, out, 0, true);
    }
}

/// Integrating contract that stages SY at the wrapper in one tx and consumes it in another (non-atomic).
contract StagedIntegrator {
    function stage(IERC20 sy, uint256 shares) external { sy.transfer(address(sy), shares); }
}

contract GxDetfSyBondTest is TestBase_SingleStandardExchangeDETF, FundedBalancerEpochAssertions {
    address internal constant BONDER = address(0xB0D1);
    address internal constant DONOR = address(0xD0D0);
    address internal constant STAKER = address(0x51A1);
    address internal constant SYU1 = address(0x5101);
    address internal constant SYU2 = address(0x5102);
    address internal constant SYU3 = address(0x5103);
    address internal constant SYU4 = address(0x5104);
    address internal constant ATTACKER_EOA = address(0xA77A);

    function _staking() internal view returns (IStakedDETF) { return IStakedDETF(detfInfo.rebasingClaimToken()); }
    function _nft() internal view returns (IDetfBondNFT) { return IDetfBondNFT(detfInfo.bondNftVault()); }
    function _ssy() internal view returns (IStandardizedYield) { return IStandardizedYield(detfInfo.stakingSY()); }
    function _rsy() internal view returns (IStandardizedYield) { return IStandardizedYield(detfInfo.rawSY()); }

    function _live() internal {
        _bootstrapViaFirstBond(BONDER, 1_000 ether);
        uint256 d_ = _fundSeShares(DONOR, 50_000 ether);
        _donateEpochCapital(_nft(), seShare, d_, DONOR);
    }

    function _buyDetf(address who, uint256 lp) internal returns (uint256 out) {
        uint256 sh = _fundSeShares(who, lp);
        vm.startPrank(who);
        seShare.approve(detf, sh);out = detfExchangeIn.exchangeIn(seShare, sh, IERC20(detf), 0, who, false, block.timestamp);
        vm.stopPrank();
    }

    function _stakeDirect(address who, uint256 amt) internal {
        IStakedDETF s = _staking();
        vm.startPrank(who);
        IERC20(detf).approve(address(s), amt);s.exchangeIn(IERC20(detf), amt, IERC20(address(s)), amt, who, false, block.timestamp);
        vm.stopPrank();
    }

    function _syDeposit(IStandardizedYield sy, address who, uint256 lp) internal returns (uint256 shares, uint256 seIn) {
        seIn = _fundSeShares(who, lp);
        vm.startPrank(who);
        seShare.approve(address(sy), seIn);
        shares = sy.deposit(who, address(seShare), seIn, 0);
        vm.stopPrank();
    }

    function _syRedeem(IStandardizedYield sy, address who, uint256 shares) internal returns (uint256 out) {
        vm.prank(who);
        out = sy.redeem(who, shares, address(seShare), 0, false);
    }

    function _epoch() internal returns (uint256 minted) {
        vm.warp(block.timestamp + 8 hours + 1);
        minted = detfInfo.synchronizeRewards();
    }

    /// SY wrapper accounting invariant: held gons >= backing + dust, re-derived from public state.
    function _syNative(address who) internal view returns (uint256) {
        uint256 sh = _ssy().balanceOf(who);
        uint256 k = _staking().stakingState().gonsPerUnit;
        return sh * StakingMath._syExchangeRate(k) / 1e18;
    }

    function _assertStakingSolvent(string memory tag) internal view {
        IStakedDETF s = _staking();
        assertGe(IERC20(detf).balanceOf(address(s)), s.stakingState().accountedBacking, string.concat(tag, ": staking backing"));
        assertGe(s.totalSupply() + 1, 0);
        // SY claims on sDETF can never exceed SY's sDETF balance.
        uint256 syClaims = _ssy().totalSupply() * StakingMath._syExchangeRate(s.stakingState().gonsPerUnit) / 1e18;
        assertLe(syClaims, s.balanceOf(address(_ssy())), string.concat(tag, ": SY over-claims sDETF"));
    }

    function test_00_tokens() public {
        _live();
        address[] memory t = IDETFSYView(address(_ssy())).getTokensIn();
        for (uint256 i; i < t.length; ++i) console2.log("SY tokenIn", t[i]);
        console2.log("seShare", address(seShare), "detf", detf);
        console2.log("minting allowed", detfInfo.isMintingAllowed());
    }

    /// A: staking-SY units track a direct sDETF staker across funded rebases (value conservation of reward accounting).
    function test_A_stakingSyTracksDirectStakerAcrossRebases() public {
        _live();
        uint256 x = _buyDetf(STAKER, 100 ether);
        _stakeDirect(STAKER, x);
        (uint256 sh,) = _syDeposit(_ssy(), SYU1, 100 ether);
        uint256 st0 = _staking().balanceOf(STAKER);
        uint256 sy0 = _syNative(SYU1);
        uint256 totalMinted;
        for (uint256 i; i < 4; ++i) { totalMinted += _epoch(); _assertStakingSolvent("A-epoch"); }
        uint256 st1 = _staking().balanceOf(STAKER);
        uint256 sy1 = _syNative(SYU1);
        console2.log("minted", totalMinted);
        console2.log("staker before/after", st0, st1);
        console2.log("sy native before/after", sy0, sy1);
        assertGt(totalMinted, 0, "rewards funded");
        assertGt(st1, st0, "staker grew");
        // growth ratios equal to within rounding (SY gets exactly the direct-staker growth, never more)
        assertApproxEqRel(sy1 * 1e18 / sy0, st1 * 1e18 / st0, 1e12, "SY growth == direct growth");
        assertLe(sy1 * st0, st1 * sy0 + st0 * 2, "SY never out-grows direct staker");
        uint256 out = _syRedeem(_ssy(), SYU1, sh);
        assertGt(out, 0);
        assertEq(_ssy().totalSupply(), 0);
        _assertStakingSolvent("A-end");
    }

    /// B: many SY holders entering between rebases (non-round gonsPerUnit) all exit in reverse order; no DoS, no over-claim.
    function test_B_stakingSyMultiUserExitLiveness() public {
        _live();
        address[4] memory us = [SYU1, SYU2, SYU3, SYU4];
        uint256[4] memory sh;
        uint256[4] memory lps = [uint256(13 ether + 7), 1 ether + 1, 77 ether + 3, 3 ether + 11];
        for (uint256 i; i < 4; ++i) {
            (sh[i],) = _syDeposit(_ssy(), us[i], lps[i]);
            _epoch();
            _assertStakingSolvent("B-in");
        }
        // partial redeem then full exits in reverse order
        _syRedeem(_ssy(), us[2], sh[2] / 3);
        sh[2] -= sh[2] / 3;
        for (uint256 j; j < 4; ++j) {
            uint256 i = 3 - j;
            _syRedeem(_ssy(), us[i], sh[i]);
            _assertStakingSolvent("B-out");
            if (j == 1) _epoch();
        }
        assertEq(_ssy().totalSupply(), 0, "all SY retired");
        uint256 left = _staking().gonsOf(address(_ssy()));
        console2.log("SY residual gons", left, "k", _staking().stakingState().gonsPerUnit);
        assertLt(left / _staking().stakingState().gonsPerUnit, 4, "only sub-unit dust remains");
    }

    /// C: unsolicited sDETF/DETF gifts to the wrappers cannot DoS honest exits nor be claimed by a new depositor.
    function _flowC(bool gift) internal returns (uint256 rate, uint256 out1, uint256 out2) {
        _live();
        IStandardizedYield ssy = _ssy();
        IStandardizedYield rsy = _rsy();
        IStakedDETF stk = _staking();
        (uint256 sh1,) = _syDeposit(ssy, SYU1, 10 ether);
        uint256 g = _buyDetf(ATTACKER_EOA, 5 ether);
        _stakeDirect(ATTACKER_EOA, g / 2);
        if (gift) {
            vm.startPrank(ATTACKER_EOA);
            IERC20(address(stk)).transfer(address(ssy), stk.balanceOf(ATTACKER_EOA));
            IERC20(detf).transfer(address(rsy), IERC20(detf).balanceOf(ATTACKER_EOA));
            vm.stopPrank();
        }
        _epoch();
        (uint256 sh2,) = _syDeposit(ssy, SYU2, 10 ether);
        (uint256 rsh,) = _syDeposit(rsy, SYU3, 10 ether);
        rate = IDETFSYView(address(ssy)).exchangeRate();
        out1 = _syRedeem(ssy, SYU1, sh1);
        out2 = _syRedeem(ssy, SYU2, sh2);
        _syRedeem(rsy, SYU3, rsh);
        assertEq(ssy.totalSupply(), 0);
        assertEq(rsy.totalSupply(), 0);
        _assertStakingSolvent("C-end");
    }

    function test_C_giftsDoNotBreakOrInflateWrappers() public {
        uint256 snap = vm.snapshotState();
        (uint256 r0, uint256 a0, uint256 b0) = _flowC(false);
        vm.revertToState(snap);
        (uint256 r1, uint256 a1, uint256 b1) = _flowC(true);
        console2.log("rate ctrl/gift", r0, r1);
        console2.log("out1 ctrl/gift", a0, a1);
        console2.log("out2 ctrl/gift", b0, b1);
        assertEq(r1, r0, "gift does not move SY rate");
        assertEq(a1, a0, "holder 1 unaffected by gift");
        assertEq(b1, b0, "later depositor cannot claim gift");
    }

    /// D: known class sy-redeem-internalbalance-unattributed on DETFSY: shares staged at the wrapper by a
    ///    non-atomic integrator are redeemable by anyone; DETFSY has no EOA pretransfer gate.
    function test_D_rawSyInternalBalanceStagedSweep() public {
        _live();
        StagedIntegrator victim = new StagedIntegrator();
        IStandardizedYield rsy = _rsy();
        (uint256 sh,) = _syDeposit(rsy, SYU1, 10 ether);
        vm.prank(SYU1);
        IERC20(address(rsy)).transfer(address(victim), sh);
        victim.stage(IERC20(address(rsy)), sh); // tx 1 (victim)
        // tx 2: attacker EOA, zero capital
        uint256 a0 = seShare.balanceOf(ATTACKER_EOA);
        vm.prank(ATTACKER_EOA);
        uint256 out = rsy.redeem(ATTACKER_EOA, sh, address(seShare), 0, true);
        console2.log("EOA swept seShare", out);
        assertEq(seShare.balanceOf(ATTACKER_EOA) - a0, out);
        assertGt(out, 0, "staged shares swept by EOA (no EOA gate on DETFSY)");
        // control: atomic integrator path is safe
        (uint256 sh2,) = _syDeposit(rsy, SYU2, 10 ether);
        AtomicPretransferCaller atomic = new AtomicPretransferCaller();
        vm.prank(SYU2);
        IERC20(address(rsy)).approve(address(atomic), sh2);
        bytes memory r = atomic.consumePretransfer(IERC20(address(rsy)), SYU2, address(rsy), sh2,
            abi.encodeCall(IStandardizedYield.redeem, (SYU2, sh2, address(seShare), 0, true)));
        assertGt(abi.decode(r, (uint256)), 0);
    }

    /// E: bond NFT donate(pretransferred=true) books credit = whole balance (booked 0). Stranded tokens can be
    ///    pushed into the reserve by anyone, but the caller receives nothing; protected assets stay protected.
    function test_E_bondDonatePretransferredNoCallerValue() public {
        _live();
        IDetfBondNFT nft = _nft();
        GxAttacker atk = new GxAttacker();
        IERC20 lp = IERC20(detfInfo.reservePool());
        console2.log("nft seShare pre-existing", seShare.balanceOf(address(nft)));
        uint256 pre = seShare.balanceOf(address(nft));
        uint256 stranded = _fundSeShares(SYU1, 5 ether);
        vm.prank(SYU1);
        seShare.transfer(address(nft), stranded);

        // over-declare reverts
        vm.expectRevert();
        atk.donatePre(address(nft), seShare, pre + stranded + 1);
        // EOA cannot use pretransfer
        vm.prank(ATTACKER_EOA);
        vm.expectRevert();
        IDetfNftReserveDonation(address(nft)).donate(seShare, stranded, 0, true, block.timestamp);

        uint256 lpNft0 = lp.balanceOf(address(nft));
        uint256 lpAtk0 = lp.balanceOf(address(atk));
        uint256 out = atk.donatePre(address(nft), seShare, stranded);
        assertGt(out, 0);
        assertEq(lp.balanceOf(address(atk)), lpAtk0, "attacker gets no LP");
        assertEq(seShare.balanceOf(address(atk)), 0);
        assertEq(IERC20(detf).balanceOf(address(atk)), 0);
        assertEq(_staking().balanceOf(address(atk)), 0);
        assertGe(lp.balanceOf(address(nft)), lpNft0 + out, "LP stays in bond custody");

        // sDETF (escrowed bond principal) can never be donated, pretransferred or not
        IStakedDETF stk = _staking();
        uint256 esc = stk.balanceOf(address(nft));
        assertGt(esc, 0);
        vm.expectRevert();
        atk.donatePre(address(nft), IERC20(address(stk)), esc);
        // LP pretransfer is rejected
        vm.expectRevert();
        atk.donatePre(address(nft), lp, 1);
        // stranded raw DETF at the bond NFT: pushing it is also caller-neutral (or reverts)
        uint256 dd = _buyDetf(SYU2, 2 ether);
        vm.prank(SYU2);
        IERC20(detf).transfer(address(nft), dd);
        try atk.donatePre(address(nft), IERC20(detf), dd) returns (uint256 o2) {
            console2.log("raw DETF stranded donated, lp", o2);
        } catch { console2.log("raw DETF pretransfer donate reverts"); }
        assertEq(lp.balanceOf(address(atk)), 0);
        assertEq(IERC20(detf).balanceOf(address(atk)), 0);
        // bond holder can still fully claim after the donations
        vm.warp(block.timestamp + DEFAULT_MAX_LOCK + 1);
        vm.prank(BONDER);
        (uint256 p, uint256 rw) = nft.claimBond(3, BONDER);
        console2.log("bond claim principal/rewards", p, rw);
        assertGt(p, 0);
    }

    /// F: JIT stake around an epoch boundary (no vesting/cooldown). Quantify capture vs an always-on staker.
    function test_F_jitStakeAroundEpoch() public {
        _live();
        uint256 x = _buyDetf(STAKER, 100 ether);
        _stakeDirect(STAKER, x);
        uint256 y = _buyDetf(ATTACKER_EOA, 100 ether);
        vm.warp(block.timestamp + 8 hours - 5);
        detfInfo.synchronizeRewards();
        _stakeDirect(ATTACKER_EOA, y);
        vm.warp(block.timestamp + 10);
        uint256 minted = detfInfo.synchronizeRewards();
        IStakedDETF stk = _staking();
        uint256 aBal = stk.balanceOf(ATTACKER_EOA);
        vm.prank(ATTACKER_EOA);stk.exchangeIn(IERC20(address(stk)), aBal, IERC20(detf), 0, ATTACKER_EOA, false, block.timestamp);
        console2.log("epoch minted", minted);
        console2.log("staker principal/bal", x, _staking().balanceOf(STAKER));
        console2.log("jit principal/out", y, aBal);
        console2.log("DETF supply", IERC20(detf).totalSupply());
        _assertStakingSolvent("F");
    }
}

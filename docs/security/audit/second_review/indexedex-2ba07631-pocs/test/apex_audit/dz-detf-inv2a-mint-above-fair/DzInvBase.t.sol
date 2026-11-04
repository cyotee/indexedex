// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DzHandler} from "./DzHandler.sol";

interface IERC4626Like { function convertToAssets(uint256) external view returns (uint256); }
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @notice Stateful invariant harness: CP (single SE buffer) Uniswap V4 DETF core (mint / burn / bond / seigniorage
/// expansion / staking / bond NFT), deployment fee config (dexSwapFee 3e14, seigniorage 5%).
contract DzInvBase is TestBase_UniswapV4Detf {
    DzHandler internal h;
    uint256 internal firstId;
    function _statsPath() internal pure virtual returns (string memory) { return "test/apex_audit/dz-detf-inv2a-mint-above-fair/stats.txt"; }

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(reserveHook, 3e14);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(5e16);
        vm.stopPrank();

        (firstId,) = _firstBond(2_000 ether);
        uint256[] memory ids = new uint256[](14);
        vm.startPrank(detfUser);
        for (uint256 i; i < 14; ++i) {
            (ids[i],) = detfInfo.bond(IERC20(address(pairToken)), 300 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        }
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        IDETFFundedRewards(detf).synchronizeRewards();
        vm.startPrank(detfUser);
        nft.claimBond{gas: 30_000_000}(firstId, detfUser);
        for (uint256 i; i < 14; ++i) nft.claimBond{gas: 30_000_000}(ids[i], detfUser);
        IStakedDETF st = IStakedDETF(detfInfo.rebasingClaimToken());st.exchangeIn(IERC20(address(st)), st.balanceOf(detfUser), IERC20(detf), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();

        h = new DzHandler(detf, reserveHook, address(pairToken), se, address(pairProtocolVault), address(pm), firstId);

        // distribute liquid DETF
        uint256 d = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).transfer(h.arb(), d * 45 / 100);
        IERC20(detf).transfer(address(h), d * 15 / 100);
        IERC20(detf).transfer(h.carol(), d * 15 / 100);
        IERC20(detf).transfer(h.alice(), d * 10 / 100);
        IERC20(detf).transfer(h.bob(), d * 5 / 100);
        IERC20(detf).transfer(h.dave(), d * 10 / 100);
        vm.stopPrank();

        // approvals for honest actors
        address[5] memory actors = [h.alice(), h.bob(), h.carol(), h.dave(), h.arb()];
        for (uint256 i; i < actors.length; ++i) {
            pairToken.mint(actors[i], 1_000_000 ether);
            vm.startPrank(actors[i]);
            pairToken.approve(detf, type(uint256).max);
            pairToken.approve(reserveHook, type(uint256).max);
            IERC20(detf).approve(detf, type(uint256).max);
            IERC20(detf).approve(reserveHook, type(uint256).max);
            vm.stopPrank();
            address st_ = detfInfo.rebasingClaimToken();
            address bn_ = detfInfo.bondNftVault();
            vm.startPrank(actors[i]);
            IERC20(detf).approve(st_, type(uint256).max);
            pairToken.approve(bn_, type(uint256).max);
            vm.stopPrank();
        }
        // dave: passive staker
        {
            address dave = h.dave();
            uint256 dd = IERC20(detf).balanceOf(dave);
            address st_ = detfInfo.rebasingClaimToken();
            vm.prank(dave);IStandardExchangeIn(st_).exchangeIn(IERC20(detf), dd, IERC20(st_), 0, dave, false, block.timestamp + 1 hours);
        }
        // adversary capital: pair + SE shares
        pairToken.mint(address(h), 3_000 ether);
        vm.startPrank(address(h));
        pairToken.approve(se, type(uint256).max);try IStandardExchangeIn(se).exchangeIn(IERC20(address(pairToken)), 500 ether, IERC20(se), 0, address(h), false, block.timestamp + 1 hours) {}
        catch { console2.log("adversary SE share acquisition failed"); }
        vm.stopPrank();
        h.init();

        targetContract(address(h));
        bytes4[] memory sels = new bytes4[](23);
        sels[0] = DzHandler.h_mint.selector;
        sels[1] = DzHandler.h_burn.selector;
        sels[2] = DzHandler.h_bond.selector;
        sels[3] = DzHandler.h_claim.selector;
        sels[4] = DzHandler.h_stake.selector;
        sels[5] = DzHandler.h_unstake.selector;
        sels[6] = DzHandler.h_roundTrip.selector;
        sels[7] = DzHandler.h_marketMove.selector;
        sels[8] = DzHandler.h_yield.selector;
        sels[9] = DzHandler.h_warp.selector;
        sels[10] = DzHandler.a_swap.selector;
        sels[11] = DzHandler.a_swapOut.selector;
        sels[12] = DzHandler.a_burn.selector;
        sels[13] = DzHandler.a_mint.selector;
        sels[14] = DzHandler.a_donate.selector;
        sels[15] = DzHandler.a_pretransfer.selector;
        sels[16] = DzHandler.a_pretransferClaim.selector;
        sels[17] = DzHandler.a_sweep.selector;
        sels[18] = DzHandler.a_sync.selector;
        sels[19] = DzHandler.a_pmSwapOp.selector;
        sels[20] = DzHandler.a_syncManip.selector;
        sels[21] = DzHandler.a_bondNftDonate.selector;
        sels[22] = DzHandler.h_donate.selector;
        targetSelector(FuzzSelector({addr: address(h), selectors: sels}));
    }

    // ======================================================================== invariants

    /// INV-1 no adversary profit: fair-valued (pFair) adversary holdings never exceed a buy-and-hold of its initial
    /// holdings (dust tolerance 0.001 pair). Covers mint/redeem round trips by the adversary, pretransfer over-claims,
    /// donation/sweep/unlock games, and burns at manipulated states.
    function _invAdvProfit() internal view {
        assertLe(h.ghost_maxAdvProfit(), int256(1e15), "INV-1 adversary extracted value");
        assertLe(h.advProfit(), int256(1e15), "INV-1 adversary extracted value (now)");
    }

    /// INV-2 fair issuance: mint output and bond principal valued at pFair never exceed paid value (x bond multiplier).
    function _invFairIssuance() internal view {
        assertEq(h.ghost_mintViol(), 0, "INV-2a mint issued above fair price");
        assertEq(h.ghost_bondViol(), 0, "INV-2b bond principal above fair valuation");
    }

    /// INV-3 honest mint -> burn round trip never profitable.
    function _invRoundTrip() internal view {
        assertEq(h.ghost_roundTripViol(), 0, "INV-3 round trip profitable");
        assertEq(h.ghost_overclaimAccepted(), 0, "INV-3b pretransfer over-claim (declared > paid) accepted");
    }

    /// INV-4 no value leak to non-participants: no adversary action lowers arb-normalized redemption backing per DETF.
    function _invNoLeak() internal view {
        assertEq(h.ghost_leakViol(), 0, "INV-4 adversary action reduced protocol fair equity (value leak from holders)");
    }

    /// INV-5 seigniorage expansion is not inflatable by spot manipulation (vs. realization at the normalized state).
    function _invExpansion() internal view {
        if (h.assertExpansion()) assertEq(h.ghost_expViol(), 0, "INV-5 expansion realized above fair-state expansion");
    }

    /// INV-6 supply obligations are backed: staking holds DETF for every sDETF; the bond NFT holds sDETF for every
    /// open position's remaining principal + rewards; reserve LP is only protocol-held.
    function _invObligations() internal view {
        address staking = detfInfo.rebasingClaimToken();
        assertGe(IERC20(detf).balanceOf(staking) + 1, IERC20(staking).totalSupply(), "INV-6a sDETF under-backed");
        address nft = detfInfo.bondNftVault();
        uint256 owed;
        uint256 n = h.bobIdsLength();
        for (uint256 i; i < n; ++i) owed += _owed(nft, h.bobIds(i));
        assertGe(IERC20(staking).balanceOf(nft) + n + 1, owed, "INV-6b bond NFT under-backed");
        assertEq(IERC20(reserveHook).balanceOf(address(h)), 0, "INV-6c adversary holds reserve LP");
        assertEq(IERC20(reserveHook).balanceOf(h.alice()), 0, "INV-6c alice holds reserve LP");
        assertEq(IERC20(reserveHook).balanceOf(h.arb()), 0, "INV-6c arb holds reserve LP");
    }

    function _owed(address nft, uint256 id) internal view returns (uint256) {
        try IDetfBondNFT(nft).previewClaim(id) returns (DETFFundedStakingMath.BondClaim memory c) {
            return c.principalRemaining + c.rewardsDue;
        } catch {
            return 0;
        }
    }

    function checkCore() public {
        _invAdvProfit();
        _invFairIssuance();
        _invRoundTrip();
        _invNoLeak();
        _invExpansion();
        _invObligations();
        _invLiveness();
    }

    /// INV-7 liveness: a passive holder can always redeem 1% of their DETF.
    function _invLiveness() internal {
        address carol = h.carol();
        uint256 amt = IERC20(detf).balanceOf(carol) / 100;
        if (amt == 0) return;
        uint256 snap = vm.snapshotState();
        vm.prank(carol);
        (bool ok, bytes memory ret) = detf.call(
            abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(detf), amt, IERC20(address(pairToken)), 0, carol, false, block.timestamp + 1 hours))
        );
        vm.revertToState(snap);
        if (!ok) console2.logBytes(ret);
        assertTrue(ok, "INV-7 passive holder redemption reverted");
    }

    function afterInvariant() public {
        string memory line = string.concat("run t=", vm.toString(block.timestamp));
        uint256 tc;
        uint256 to;
        for (uint256 i; i < 23; ++i) {
            uint256 c = h.calls(i);
            uint256 o = h.oks(i);
            tc += c;
            to += o;
            line = string.concat(line, " ", h.nameOf(i), "=", vm.toString(o), "/", vm.toString(c));
        }
        line = string.concat(line, " TOTAL=", vm.toString(to), "/", vm.toString(tc));
        line = string.concat(line, " maxAdvProfit=", vm.toString(h.ghost_maxAdvProfit()), " maxLeakWei=", vm.toString(h.ghost_maxLeakPpb()));
        line = string.concat(line, " expTotal=", vm.toString(h.ghost_expansionTotal()), " expShortfall=", vm.toString(h.ghost_expShortfall()));
        line = string.concat(line, " arbFail=", vm.toString(h.ghost_arbFail()), " arbShort=", vm.toString(h.ghost_arbShort()));
        line = string.concat(line, " arbRevert=", vm.toString(h.ghost_arbRevert()), " arbNoConv=", vm.toString(h.ghost_arbNoConverge()));
        line = string.concat(line, " mintGate=", vm.toString(h.ghost_mintGate()), " mintSwap=", vm.toString(h.ghost_mintSwap()));
        line = string.concat(line, " burnGate=", vm.toString(h.ghost_burnGate()), " burnSwap=", vm.toString(h.ghost_burnSwap()));
        line = string.concat(line, " bonds=", vm.toString(h.bobIdsLength()), " pFair=", vm.toString(h.pFair()));
        line = string.concat(line, " overclaimAttempts=", vm.toString(h.ghost_overclaimAttempts()), " overclaimAccepted=", vm.toString(h.ghost_overclaimAccepted()), " overclaimSelfFunded=", vm.toString(h.ghost_overclaimSelfFunded()));
        line = string.concat(line, " mintViol=", vm.toString(h.ghost_mintViol()), " bondViol=", vm.toString(h.ghost_bondViol()), " leakViol=", vm.toString(h.ghost_leakViol()));
        line = string.concat(line, " residAllow=", vm.toString(h.ghost_residualAllowanceUsed()), " maxResidAllow=", vm.toString(h.ghost_maxResidualAllowance()), " rtResidCapture=", vm.toString(h.ghost_roundTripResidualCapture()));
        line = string.concat(line, " unlockMint=", vm.toString(h.ghost_unlockMintOk()), "/", vm.toString(h.ghost_unlockMintAttempts()), " expViol=", vm.toString(h.ghost_expViol()));
        line = string.concat(line, " potTotal=", vm.toString(h.ghost_potTotal()), " potExcess=", vm.toString(h.ghost_potExcess()));
        vm.writeLine(_statsPath(), line);
        console2.log(line);
    }

    // ======================================================================== validation helpers / sanity

    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    function x_invariant_medium_core() public {
        checkCore();
    }

    function test_setup_sane() public view {
        (uint256 x, uint256 y) = h.reserves();
        console2.log("pool pair / DETF", x, y);
        console2.log("pFair (pair wei per DETF)", h.pFair());
        console2.log("quote 1 DETF -> pair", ExchangeInAmount.previewOut(IStandardExchangeIn(reserveHook), IERC20(detf), 1e9, IERC20(address(pairToken))));
        console2.log("quote 1 pair -> DETF", ExchangeInAmount.previewOut(IStandardExchangeIn(reserveHook), IERC20(address(pairToken)), 1 ether, IERC20(detf)));
        console2.log("supply", IERC20(detf).totalSupply());
        console2.log("protocolLp / lpSupply", h.protocolLp(), IERC20(reserveHook).totalSupply());
        console2.log("synthetic", detfInfo.syntheticPrice());
        console2.log("mint gate / burn gate", detfInfo.isMintingAllowed(IERC20(address(pairToken))), detfInfo.isBurningAllowed(IERC20(address(pairToken))));
        console2.log("adv pair / se / detf", h.advPair0(), h.advSe0(), h.advDetf0());
        console2.log("arb DETF", IERC20(detf).balanceOf(h.arb()));
        (int256 eq, uint256 sl) = h.equity(0);
        console2.log("protocol equity (pair wei) / slack");
        console2.logInt(eq);
        console2.log(sl);
        console2.log("redemption backing per DETF", h.redemptionBacking());
        assertGt(h.advDetf0(), 0);
        assertEq(h.advProfit(), 0);
    }

    /// SANITY: with the bond quarantine lifted, the known CP bond-spot finding (detf-bond-spot-valuation) is caught by
    /// INV-2b (adversary dumps DETF, honest bond executes at the manipulated composition). Same sequence quarantined: clean.
    function test_sanity_bondSpot_caughtWhenUnquarantined() public {
        uint256 snap = vm.snapshotState();
        h.setQuarantine(false);
        (, uint256 y) = h.reserves();
        uint256 dump = y / 4;
        uint256 bal = IERC20(detf).balanceOf(address(h));
        h.a_swap(1, dump < bal ? dump : bal);
        h.h_bond(50 ether, 180 days);
        console2.log("UNQUARANTINED bond viol / excess bps", h.ghost_bondViol(), h.ghost_maxBondExcessBps());
        assertGt(h.ghost_bondViol(), 0, "INV-2b must catch the known bond-spot bug when unquarantined");
        vm.expectRevert();
        this.checkFairIssuance();
        vm.revertToState(snap);

        h.a_swap(1, dump < bal ? dump : bal);
        h.h_bond(50 ether, 180 days);
        console2.log("QUARANTINED bond viol", h.ghost_bondViol(), h.bobIdsLength());
        assertEq(h.bobIdsLength(), 1, "quarantined bond executed");
        assertEq(h.ghost_bondViol(), 0, "quarantined sequence clean");
    }

    /// SANITY: un-quarantined spot mint after a DETF dump (detf-spot-mint root cause on CP) is caught by INV-2a.
    function test_sanity_spotMint_caughtWhenUnquarantined() public {
        uint256 snap = vm.snapshotState();
        h.setQuarantine(false);
        (, uint256 y) = h.reserves();
        uint256 dump = y / 4;
        uint256 bal = IERC20(detf).balanceOf(address(h));
        h.a_swap(1, dump < bal ? dump : bal);
        h.h_mint(20 ether);
        console2.log("UNQUARANTINED mint viol / excess bps", h.ghost_mintViol(), h.ghost_maxMintExcessBps());
        assertGt(h.ghost_mintViol(), 0, "INV-2a must catch spot-priced mint when unquarantined");
        vm.revertToState(snap);
        h.a_swap(1, dump < bal ? dump : bal);
        h.h_mint(20 ether);
        assertEq(h.ghost_mintViol(), 0, "quarantined sequence clean");
    }

    /// probe: DETF-routed stake (DETF -> sDETF through the DETF diamond) for an EOA holder
    function test_probe_stakeViaDetf() public {
        address alice = h.alice();
        address st = detfInfo.rebasingClaimToken();
        uint256 amt = IERC20(detf).balanceOf(alice) / 10;
        // (a) raw self-pull as the diamond would do it
        uint256 snap = vm.snapshotState();
        vm.prank(detf);
        bool okRaw = IERC20(detf).transferFrom(alice, detf, amt);
        console2.log("raw transferFrom(alice->detf) by detf ok", okRaw);
        vm.revertToState(snap);
        // (b) DETF-routed stake, EOA, false flag
        vm.prank(alice);
        (bool okStake, bytes memory ret) = detf.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(detf), amt, IERC20(st), 0, alice, false, block.timestamp + 1 hours)));
        console2.log("DETF-routed stake ok", okStake);
        if (!okStake) console2.logBytes(ret);
        // (c) DETF-routed mint+stake (pair -> sDETF)
        vm.prank(alice);
        (bool okMintStake, bytes memory ret2) = detf.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(pairToken)), 1 ether, IERC20(st), 0, alice, false, block.timestamp + 1 hours)));
        console2.log("DETF-routed mint+stake ok", okMintStake);
        if (!okMintStake) console2.logBytes(ret2);
        // (d) direct staking contract
        vm.prank(alice);
        (bool okDirect,) = st.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(detf), amt, IERC20(st), 0, alice, false, block.timestamp + 1 hours)));
        console2.log("direct staking stake ok", okDirect);
    }

    function _dbg(bytes memory c) internal {
        vm.prank(address(h));
        (bool ok, bytes memory ret) = address(h).call(c);
        console2.log("ok", ok);
        if (!ok) console2.logBytes(ret);
    }

    function test_debug_failures() public {
        _dbg(abi.encodeCall(DzHandler.i_pmSwapOp, (true, 10e9, 0, 0, false)));
        _dbg(abi.encodeCall(DzHandler.i_pmSwapOp, (false, 10 ether, 0, 0, false)));
        _dbg(abi.encodeCall(DzHandler.i_donate, (0, 12345)));
        _dbg(abi.encodeCall(DzHandler.i_donate, (1, 12345)));
        _dbg(abi.encodeCall(DzHandler.i_donate, (0, 1e16)));
        _dbg(abi.encodeCall(DzHandler.i_bondNftDonate, (0, 12345)));
        _dbg(abi.encodeCall(DzHandler.i_pretransferClaim, (0, 12345, 0, 0)));
        _dbg(abi.encodeCall(DzHandler.i_pretransferClaim, (1, 1 ether, 0, 0)));
        _dbg(abi.encodeCall(DzHandler.i_pretransferClaim, (0, 1 ether, 0, 2)));
        _dbg(abi.encodeCall(DzHandler.i_pretransferClaim, (0, 1 ether, 0, 3)));
        _dbg(abi.encodeCall(DzHandler.i_pretransferClaim, (0, 1e9, 0, 1)));
        _dbg(abi.encodeCall(DzHandler.i_burnAdv, (1, 0)));
        _dbg(abi.encodeCall(DzHandler.i_swap, (3, 1e9)));
    }

    /// probe H10 (detf-stale-reserve-and-logic): booked SE-share reserve vs actual SE-share balance on the diamond.
    function test_probe_seShareBook() public {
        (bool ok, bytes memory r) = detf.staticcall(abi.encodeWithSignature("reserveOfToken(address)", se));
        uint256 rSe = ok ? abi.decode(r, (uint256)) : type(uint256).max;
        console2.log("R(se) booked / balanceOf(se, detf)", rSe, IERC20(se).balanceOf(detf));
        (ok, r) = detf.staticcall(abi.encodeWithSignature("reserveOfToken(address)", address(pairToken)));
        console2.log("R(pair) booked / balanceOf(pair, detf)", ok ? abi.decode(r, (uint256)) : 0, pairToken.balanceOf(detf));
        // integrator pays 1 SE share-unit worth and claims it with the pretransfer flag
        vm.startPrank(address(h));
        IERC20(se).transfer(detf, 1 ether);
        (bool okMint, bytes memory ret) = detf.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(se), 1 ether, IERC20(detf), 0, address(h), true, block.timestamp + 1 hours)));
        vm.stopPrank();
        console2.log("pretransferred SE-share mint ok", okMint);
        if (!okMint) console2.logBytes(ret);
    }

    /// regression of medium-run break #1 (harness artifact: buy-and-hold baseline ignored that the adversary had
    /// converted pair->DETF at fair value before an exogenous +20% market move). Fixed by mark-to-market baseline.
    function test_regress_break1_mintThenMarketMove() public {
        h.a_pretransferClaim(5e16, 40374141596472776359637019369342536991830805956132596986522135158710243844986, 1963318088, 204);
        h.h_marketMove(2000, true);
        console2.log("advProfit after mint+move");
        console2.logInt(h.advProfit());
        checkCore();
    }

    /// regression of medium-run break #2 (harness artifact: redemption-leg metric valued loose SE residual at par
    /// but the post-sweep single-sided join at ~half, ignoring the protocol DETF leg). Fixed by NAV/circulating metric.
    function test_regress_break2_pretransferThenBondNftDonate() public {
        h.a_pretransfer(89937199, 15772, 75962412145502755164668036543994774951358764275531821157030353897536674699931);
        h.a_bondNftDonate(1820717940, 500000000000000000);
        console2.log("leakViol / maxLeakPpb", h.ghost_leakViol(), h.ghost_maxLeakPpb());
        checkCore();
    }

    /// H5 / detf-expansion-spot quantified (only meaningful when synthetic > mintThreshold, i.e. the Rich variant):
    /// expansion realized right after a same-tx spot pump vs at the fair state, after `gap` of unsynced epochs.
    /// Also reports the adversary's pump+unwind cost at pFair (upper bound on attacker gain = excess if it owned all sDETF).
    function test_H5_expansionSpot_quantified() public {
        if (!detfInfo.isMintingAllowed(IERC20(address(pairToken)))) return;
        pairToken.mint(address(h), 10_000 ether);
        uint256[3] memory gaps = [uint256(8 hours), 3 days, 10 days];
        uint256[4] memory pumps = [uint256(100 ether), 500 ether, 1500 ether, 4000 ether];
        for (uint256 g; g < 3; ++g) {
            for (uint256 j; j < 4; ++j) {
                uint256 snap = vm.snapshotState();
                _h5Case(gaps[g], pumps[j]);
                vm.revertToState(snap);
            }
        }
    }

    function _h5Case(uint256 gap, uint256 pump) internal {
        vm.warp(block.timestamp + gap);
        uint256 s0 = vm.snapshotState();
        vm.recordLogs();
        IDETFFundedRewards(detf).synchronizeRewards();
        uint256 eFair = _expLogs();
        vm.revertToState(s0);
        int256 v0 = int256(h.advValue());
        vm.startPrank(address(h));(uint256 got,) = IStandardExchangeIn(reserveHook).exchangeIn(IERC20(address(pairToken)), pump, IERC20(detf), 0, address(h), false, block.timestamp);
        console2.log("gap(s) / pump(pair) / synthetic after pump", gap, pump / 1e18, detfInfo.syntheticPrice());
        vm.recordLogs();
        IDETFFundedRewards(detf).synchronizeRewards();
        uint256 eAct = _expLogs();IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), got, IERC20(address(pairToken)), 0, address(h), false, block.timestamp);
        vm.stopPrank();
        console2.log("  expansion fair / pumped (DETF wei) / supply", eFair, eAct, IERC20(detf).totalSupply());
        console2.log("  excess minted to stakers (pair wei, at pFair):");
        console2.logInt((int256(eAct) - int256(eFair)) * int256(h.pFair()) / 1e9);
        console2.log("  adversary pump+unwind cost (pair wei, at pFair):");
        console2.logInt(v0 - int256(h.advValue()));
    }

    function _expLogs() internal returns (uint256 e) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 t = keccak256("NaturalSupplyExpanded(uint256,uint256,uint256)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == detf && logs[i].topics.length > 0 && logs[i].topics[0] == t) {
                (uint256 amt,,) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                e += amt;
            }
        }
    }

    /// regression of medium-run break #3 (harness artifact: NAV/circulating metric valued protocol-held DETF as an
    /// asset, so the sweep's single-sided join of pretransferred DETF looked dilutive). Fixed by fair-equity metric.
    function test_regress_break3_pretransferDetfThenSweep() public {
        h.a_pretransfer(906505541, 256588408, 20323089151171879626785167661285591046046314175000282389928788656956827);
        h.a_sweep();
        console2.log("leakViol / maxLeakWei", h.ghost_leakViol(), h.ghost_maxLeakPpb());
        checkCore();
    }

    function _lpLog(string memory tag) internal {
        (bool ok, bytes memory r) = reserveHook.staticcall(abi.encodeWithSignature("dexSwapFeeAndFeeTo()"));
        address feeTo = ok ? abi.decode(r, (address)) : address(0);
        (int256 eq,) = h.equity(0);
        console2.log(tag);
        console2.log("  lpSupply / protocolLp / feeTo LP", IERC20(reserveHook).totalSupply(), h.protocolLp(), IERC20(reserveHook).balanceOf(feeTo));
        (uint256 x, uint256 y) = h.reserves();
        console2.log("  pool x / y / supply", x, y, IERC20(detf).totalSupply());
        console2.logInt(eq);
    }

    function _eqLog(string memory tag) internal {
        _lpLog(tag);
        (int256 eq, uint256 sl) = h.equity(0);
        eq;
        console2.log("  slack", sl);
        console2.log("  loose pair / se / detf on diamond", pairToken.balanceOf(detf), IERC20(se).balanceOf(detf), IERC20(detf).balanceOf(detf));
        console2.log("  PM pair / PM detf / PM se", pairToken.balanceOf(address(pm)), IERC20(detf).balanceOf(address(pm)), IERC20(se).balanceOf(address(pm)));
        console2.log("  hook pair / hook se / hook detf", pairToken.balanceOf(reserveHook), IERC20(se).balanceOf(reserveHook), IERC20(detf).balanceOf(reserveHook));
        console2.log("  adv profit / leakViol / maxLeak", uint256(h.advProfit() < 0 ? -h.advProfit() : h.advProfit()), h.ghost_leakViol(), h.ghost_maxLeakPpb());
        console2.log("  adv profit sign negative?", h.advProfit() < 0);
    }

    /// medium-run break R1 (Rich): pretransfer SE shares to the diamond, then PoolManager-path DETF dump + in-unlock sweepDust
    function test_debug_breakR1() public {
        _eqLog("R1 start");
        h.a_pretransfer(1239286259321928555293972945469763, 78126578316, 832187818364323471703106568438787106205015259200757543908786851487656);
        _eqLog("R1 after pretransfer");
        h.a_pmSwapOp(false, 1671031077830221482215774513191508725783093157659839182104831911656308819877, 62760428, 1060349667992683116822, false);
        _eqLog("R1 after pm dump + in-unlock sweep");
    }

    /// medium-run break B1 (base): adversary mint, burn, big pair pretransfer, small burn (sweep joins residual)
    function test_debug_breakB1() public {
        _eqLog("B1 start");
        h.a_mint(1800, 7500);
        _eqLog("B1 after mint");
        h.a_burn(115792089237316195423570985008687907853269984665640564039457584007913129639932, 67868191704986);
        _eqLog("B1 after burn1");
        h.a_pretransfer(953495055, 200000000000000000000000, 340282366920938463463374607431768211455);
        _eqLog("B1 after pretransfer");
        h.a_burn(120, 38);
        _eqLog("B1 after burn2");
    }

    function test_debug_seSpread() public {
        IStandardExchangeIn s_ = IStandardExchangeIn(se);
        console2.log("SE pair->shares (100 pair)", ExchangeInAmount.previewOut(IStandardExchangeIn(address(s_)), IERC20(address(pairToken)), 100 ether, IERC20(se)));
        console2.log("SE shares->pair (100 shares)", ExchangeInAmount.previewOut(IStandardExchangeIn(address(s_)), IERC20(se), 100 ether, IERC20(address(pairToken))));
        console2.log("pv convertToAssets(1e18)", IERC4626Like(address(pairProtocolVault)).convertToAssets(1e18));
        console2.log("SE totalSupply / pv shares held by SE", IERC20(se).totalSupply(), IERC20(address(pairProtocolVault)).balanceOf(se));
        console2.log("hook SE shares / previewExit pair", IERC20(se).balanceOf(reserveHook));
        (uint256 x,) = h.reserves();
        console2.log("pool x", x);
        // round trip through the hook: buy 500 pair worth of DETF then sell all back (adversary)
        int256 v0 = int256(h.advValue());
        (int256 e0,) = h.equity(0);
        vm.startPrank(address(h));(uint256 got,) = IStandardExchangeIn(reserveHook).exchangeIn(IERC20(address(pairToken)), 500 ether, IERC20(detf), 0, address(h), false, block.timestamp);IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), got, IERC20(address(pairToken)), 0, address(h), false, block.timestamp);
        vm.stopPrank();
        (int256 e1,) = h.equity(0);
        console2.log("hook round trip 500 pair: adversary loss / protocol equity delta (pair wei)");
        console2.logInt(v0 - int256(h.advValue()));
        console2.logInt(e1 - e0);
        (x,) = h.reserves();
        console2.log("pool x after / hook SE shares", x, IERC20(se).balanceOf(reserveHook));
    }

    /// break-class B1/R1 quantified (variant of the confirmed bond-spot root cause: protocol-owned single-sided joins
    /// at the live composition with minLp=0). Honest donor calls DETF.donate(pair, D) (DETF hardcodes minLpOut=0);
    /// attacker sandwiches: buy DETF with B pair -> donation joins into the pair-heavy pool -> sell DETF back.
    function test_donateSandwich_quantified() public {
        uint256[3] memory ds = [uint256(100 ether), 500 ether, 2000 ether];
        uint256[3] memory bs = [uint256(500 ether), 2000 ether, 6000 ether];
        pairToken.mint(address(h), 20_000 ether);
        address donor = h.alice();
        address bnft = detfInfo.bondNftVault();
        vm.prank(donor);
        pairToken.approve(bnft, type(uint256).max);
        for (uint256 i; i < 3; ++i) {
            for (uint256 j; j < 3; ++j) {
                uint256 snap = vm.snapshotState();
                int256 v0 = int256(h.advValue());
                vm.startPrank(address(h));(uint256 got,) = IStandardExchangeIn(reserveHook).exchangeIn(IERC20(address(pairToken)), bs[j], IERC20(detf), 0, address(h), false, block.timestamp);
                vm.stopPrank();
                vm.prank(donor);
                detfInfo.donate(IERC20(address(pairToken)), ds[i], false);
                vm.startPrank(address(h));IStandardExchangeIn(reserveHook).exchangeIn(IERC20(detf), got, IERC20(address(pairToken)), 0, address(h), false, block.timestamp);
                vm.stopPrank();
                int256 pnl = int256(h.advValue()) - v0;
                console2.log("donation / pump (pair)", ds[i] / 1e18, bs[j] / 1e18);
                console2.log("  attacker PnL at pFair (pair wei):");
                console2.logInt(pnl);
                if (i == 1 && j == 1) assertGt(pnl, 0, "donation sandwich profitable");
                vm.revertToState(snap);
            }
        }
    }

    function test_debug_break3() public {
        address st = detfInfo.rebasingClaimToken();
        _eqLog("B3 start");
        console2.log("  staking DETF bal / sDETF supply", IERC20(detf).balanceOf(st), IERC20(st).totalSupply());
        h.a_pretransfer(906505541, 256588408, 20323089151171879626785167661285591046046314175000282389928788656956827);
        _eqLog("B3 after pretransfer");
        console2.log("  staking DETF bal / sDETF supply", IERC20(detf).balanceOf(st), IERC20(st).totalSupply());
        h.a_sweep();
        _eqLog("B3 after sweep");
        console2.log("  staking DETF bal / sDETF supply", IERC20(detf).balanceOf(st), IERC20(st).totalSupply());
        console2.log("  bondNft DETF / LP", IERC20(detf).balanceOf(detfInfo.bondNftVault()), IERC20(reserveHook).balanceOf(detfInfo.bondNftVault()));
    }

    function test_debug_break2_equity() public {
        _lpLog("start");
        h.a_pretransfer(89937199, 15772, 75962412145502755164668036543994774951358764275531821157030353897536674699931);
        _lpLog("after pretransfer");
        h.a_bondNftDonate(1820717940, 500000000000000000);
        _lpLog("after bondNft donate");
    }

    /// regressions of medium-run breaks #4/#5 (residual joined at a same-action manipulated composition = the NEW
    /// donate/residual-sandwich class; now quarantined by allowing loss of at most the residual itself).
    function test_regress_break4_residualSandwichClass() public {
        uint256 snap = vm.snapshotState();
        h.a_pretransfer(20000000000000000000000, 6277101735386680763835789423207666416102355444464034512896, 12288216333838614132587757273427820444310601312935055493890535030410061932956);
        h.a_pmSwapOp(false, 2560383779, 1735, 744, true);
        console2.log("b4 leakViol / maxLeakWei", h.ghost_leakViol(), h.ghost_maxLeakPpb());
        checkCore();
        vm.revertToState(snap);
        h.a_pretransfer(204, 16458, 75337702283278225029460344614249132448607160563425943285732138573525588665312);
        h.a_syncManip(1084285407428000548955354626284195364883736702092, 8600, 60864726522021774670838722750147275786243904004440044236723846204378778771625);
        console2.log("b5 leakViol / maxLeakWei", h.ghost_leakViol(), h.ghost_maxLeakPpb());
        checkCore();
    }

    /// regression of medium-run break #6: over-claim funded by the adversary's OWN earlier unbooked pretransfer to the
    /// bond NFT (booked = 0 => credit = whole balance; APEX-003/004 credit model). Not theft; counted as self-funded.
    function test_regress_break6_selfFundedOverclaim() public {
        h.a_pretransfer(2203783743214361379280364404976033751, 206822946849475765262765553928129862122591614541644079015436079754, 1778147553);
        h.a_pretransferClaim(65103052097912851142975640610843965667333251401062100709921432875709966743168, 200000000000000000, 605, 281474976710655);
        console2.log("overclaim attempts / accepted / selfFunded", h.ghost_overclaimAttempts(), h.ghost_overclaimAccepted(), h.ghost_overclaimSelfFunded());
        checkCore();
    }

    /// regression of medium-run break #7 (Rich): honest mint->burn round trip gains after the adversary left a large
    /// loose pair residual on the diamond; the mint's sweep joins it single-sided and the burn sells into the moved
    /// price = residual-sandwich class (quarantined: gains bounded by the residual's value).
    function test_regress_break7_roundTripResidual() public {
        h.h_burn(80000000000);
        h.a_donate(8600, 48879);
        h.h_mint(19632);
        h.h_mint(10000000000);
        h.h_bond(14480, 466461);
        h.a_swapOut(4297155939710864687488021505921374547, 93411064650449916515241999016210686890306467970895465670);
        h.a_pretransfer(29041600353751597804407, 115792089237316195423570985008687907853269984665640564039457584007913129639932, 198036788162233677024292958762628686108668962);
        h.h_roundTrip(65536);
        console2.log("roundTrip viol / residual-capture", h.ghost_roundTripViol(), h.ghost_roundTripResidualCapture());
        checkCore();
    }

    function checkFairIssuance() external view { _invFairIssuance(); }

    /// SANITY (audit): INV-4 is not vacuous after removing the static residual slack: an un-quarantined adversary mint
    /// after a DETF dump (confirmed detf-spot-mint root cause) must register as a protocol fair-equity drop; the same
    /// mint at fair price (quarantined) must not.
    function test_sanity_leak_caughtWhenUnquarantined() public {
        uint256 snap = vm.snapshotState();
        h.setQuarantine(false);
        (, uint256 y) = h.reserves();
        uint256 bal = IERC20(detf).balanceOf(address(h));
        h.a_swap(1, y / 4 < bal ? y / 4 : bal);
        h.a_mint(400 ether, 0);
        console2.log("UNQUARANTINED dump+mint: mintViol / leakViol / maxLeakWei", h.ghost_mintViol(), h.ghost_leakViol(), h.ghost_maxLeakPpb());
        // gate-closed regime (base): the mint is a pool swap along the curve, protocol equity is unaffected by design
        // (the dump's counterparty is the adversary itself); the protocol-equity drop exists only on the issuance path.
        if (h.ghost_mintGate() > 0) assertGt(h.ghost_leakViol(), 0, "INV-4 must catch the spot-mint equity drop when unquarantined");
        else assertEq(h.ghost_leakViol(), 0, "swap-mint fallback is equity-neutral");
        vm.revertToState(snap);
        h.a_swap(1, y / 4 < bal ? y / 4 : bal);
        h.a_mint(400 ether, 0);
        console2.log("QUARANTINED dump+mint: oks / leakViol", h.oks(13), h.ghost_leakViol());
        assertEq(h.oks(13), 1, "quarantined mint executed");
        assertEq(h.ghost_leakViol(), 0, "quarantined mint at fair: no leak");
    }

    /// one-shot smoke of every selector so the short validation run proves each path is executable.
    function test_smoke_allSelectors() public {
        h.h_mint(10 ether);
        h.h_burn(1000);
        h.h_bond(20 ether, 60 days);
        h.h_stake(5000);
        h.h_unstake(5000);
        h.h_roundTrip(5 ether);
        h.h_marketMove(300, true);
        h.h_yield(5 ether);
        h.h_warp(9 hours);
        h.a_swap(0, 50 ether);
        h.a_swap(1, 30e9);
        h.a_swap(2, 10 ether);
        h.a_swap(3, 10e9);
        h.a_swapOut(0, 5e9);
        h.a_burn(500, 0);
        h.a_burn(500, 1);
        h.a_mint(10 ether, 0);
        h.a_mint(10 ether, 1);
        h.a_donate(0, 1 ether);
        h.a_donate(1, 1 ether);
        h.a_bondNftDonate(0, 1 ether);
        h.a_pretransfer(0, 0, 1000);
        h.a_pretransfer(2, 0, 3);
        h.a_sweep();
        h.a_pretransferClaim(0, 5 ether, 0, 0);
        h.a_pretransferClaim(0, 5e9, 0, 1);
        h.a_pretransferClaim(0, 1 ether, 0, 2);
        h.a_pretransferClaim(0, 1 ether, 1, 0); // over-claim attempt (extra > 0) must fail
        h.a_sync();
        h.a_pmSwapOp(true, 10e9, 0, 0, false);
        h.a_pmSwapOp(false, 10 ether, 1, 1000, true);
        h.a_pmSwapOp(false, 10 ether, 5, 5 ether, true); // in-unlock mint at ~fair (quarantine: arb + 1ppm swap)
        console2.log("unlock mint ok / attempts", h.ghost_unlockMintOk(), h.ghost_unlockMintAttempts());
        h.h_warp(9 hours);
        h.a_syncManip(9 hours, 0, 200 ether);
        h.h_warp(31 days);
        h.h_claim(0);
        for (uint256 i; i < 23; ++i) console2.log(h.nameOf(i), h.oks(i), h.calls(i));
        console2.log("maxAdvProfit");
        console2.logInt(h.ghost_maxAdvProfit());
        console2.log("leakViol / maxLeakPpb", h.ghost_leakViol(), h.ghost_maxLeakPpb());
        console2.log("expViol / maxExpExcess / expTotal", h.ghost_expViol(), h.ghost_maxExpExcess(), h.ghost_expansionTotal());
        console2.log("arbFail", h.ghost_arbFail());
        console2.log("lastViolation", h.lastViolation());
        checkCore();
    }
}

/// @notice "Rich launch" variant: opening price 2.5x the creation rate, so synthetic > mintThreshold (1.05) at start:
/// proportional seigniorage mint, natural expansion and gate-closed swap-burn are the default regime, and market moves
/// down reach the burn-gate-open regime. Same handler, invariants and quarantine.
contract DzInvRichBase is DzInvBase {
    function _defaultDetfArgs() internal view virtual override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        uint256[] memory opening_ = new uint256[](1);
        opening_[0] = 2.5e18;
        args.openingPairPerDetfWad = opening_;
    }

    function _statsPath() internal pure override returns (string memory) { return "test/apex_audit/dz-detf-inv2a-mint-above-fair/stats_rich.txt"; }

    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    function x_invariant_medium_rich() public {
        checkCore();
    }
}

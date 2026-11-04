// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {P4BalancerInvariantBase} from "./P4BalancerInvariant.t.sol";
import {P4Adversary, IP4RP, IP4AeroPool} from "./P4BalancerHandler.sol";

interface IP4BufView {
    function virtualTTA() external view returns (uint256);
    function hookSharesDelta() external view returns (int256);
    function ttaIndex() external view returns (uint256);
}

/// @notice Replay of the shrunk 15-call sequence that broke I7 in the medium run (seed 0xcc1cae02...).
contract P4MediumReplayTest is P4BalancerInvariantBase {
    function _aggKey() internal pure returns (string memory) {
        return "P4B_REPLAY";
    }

    function _advLog(string memory tag) internal view {
        address A = address(h.adv());
        (uint256 r0, uint256 r1,) = IP4AeroPool(address(aeroDaiUsdcPool)).getReserves();
        console2.log(tag);
        console2.log("  adv DAI / USDC", dai.balanceOf(A), usdc.balanceOf(A));
        console2.log("  adv shares / BPT", shares.balanceOf(A), IVault(address(vault)).balanceOf(bufferPool, A));
        console2.log("  rate / fsv", IP4RP(address(seRateProvider)).getRate(), h.fairShareValue());
        console2.log("  aero reserves", r0, r1);
        (,, uint256[] memory raw,) = IVault(address(vault)).getPoolTokenInfo(bufferPool);
        console2.log("  pool raw0/raw1", raw[0], raw[1]);
    }

    function test_replay_mediumI7() public {
        h.h_mockSwapExactIn(2048, 2000000000000000, 998631);
        h.h_donate(25000000000000000000, 25252635464160622100917991260232646306916028971414078037834420486105808243660, 1351);
        h.a_program([uint256(7410), 2058, 1787, 72927835838580457451036447568599381231880883716264991065619414311975978750272, 5163, 19595], [uint256(95), 48, 8390, 35, 1000000, 200], 6173);
        h.h_addProportional(160444, 31536000);
        h.h_aeroArb();
        h.h_mockSwapExactOut(8623, 7, 28536991995719124932180538634723007412464688663785172509077370007285862287836, false);
        h.a_aeroMovePersistent(86400);
        h.h_mockSwapExactIn(2048, 14403, 3152);
        h.h_addUnbalanced(2075244939090433373912069182131322302266118341402, 4704148658744844309221318817161990237728438, 1775602127518254661574661496564215841871607863380908124309949995010018127, 640852406364982565679603621465975323977);
        h.a_program([uint256(7252), 4374744929232521547966616057786, 30, 1084, 3825118854, 100955363631837194547921977150806537276593425653659657794847042039017390830519], [uint256(5100281943573904488), 5491473367361187986832609241631837230097710544299144715359218046187896884395, 7800, 20000, 83901560124972290768797569360196514592445152421815881679378259191277672838609, 20000], 100000000);
        h.h_addUnbalanced(18147, 472, 90000, 581918204);
        h.h_mockSwapExactIn(12689664, 24055, 7447);
        h.h_aeroMarket(0, 3661646523513433570104910091776243694015185976615736558);
        h.a_program([uint256(999999000000000000000), 183, 20000000000000000000000, 472, 3591781490628849072602, 41], [uint256(792067761839585587453268865966828378113048155285), 36, 2405100362, 2066330577, 521206142628048982433596363557203828, 10491], 9169);
        console2.log("profitViolations before final program", h.profitViolations());
        _advLog("BEFORE final program");
        h.a_program([uint256(130164747375472038138021877495339667817706609197703973662550699110855221), 0, 100987593723064020327649310, 115792089237316195423570985008687907853269984665640564039457584007913129639934, 423915645079844373410697757578317200512843800656632497621505284181073094, 2], [uint256(5397143796741551202011330267076258020629715909969), 115792089237316195423570985008687907853269984665640564039457584007913129639933, 106700614200246143, 293433840752728989117713990834669271, 176490268390091523473220477005, 172763421589721697919010603048003210147], 116185649332931825921);
        _advLog("AFTER final program");
        h.logSummary();
    }

    function _aliceVal() internal returns (uint256 vFair, uint256 vRate) {
        uint256 bal = IERC20(bufferPool).balanceOf(alice);
        uint256 snap = vm.snapshotState();
        uint256 t0 = dai.balanceOf(alice);
        uint256 s0 = shares.balanceOf(alice);
        removeLiquidityProportional(alice, bal, 0, 0);
        uint256 dt = dai.balanceOf(alice) - t0;
        uint256 ds = shares.balanceOf(alice) - s0;
        vm.revertToState(snap);
        vFair = dt + ds * h.fairShareValue() / 1e18;
        vRate = dt + ds * IP4RP(address(seRateProvider)).getRate() / 1e18;
    }

    function _runI5(P4Adversary.Op[] memory ops, string memory tag) internal {
        uint256 snap = vm.snapshotState();
        (uint256 f0, uint256 r0v) = _aliceVal();
        uint256 rate0 = IP4RP(address(seRateProvider)).getRate();
        int256 pnl = h.runProgramExt(ops);
        (uint256 f1, uint256 r1v) = _aliceVal();
        console2.log(tag);
        console2.log("  adversary PnL");
        console2.logInt(pnl);
        console2.log("  rate before/after", rate0, IP4RP(address(seRateProvider)).getRate());
        console2.log("  alice fair value before/after", f0, f1);
        console2.log("  alice rate value before/after", r0v, r1v);
        console2.log("  I5 violations / last", h.invDropViolations(), h.lastInvDrop());
        vm.revertToState(snap);
    }

    function test_replay_mediumI5() public {
        P4Adversary.Op[] memory ops = new P4Adversary.Op[](3);
        ops[0] = P4Adversary.Op(4, 1378060764504005562171575027906451072286064825905302285773251539630);
        ops[1] = P4Adversary.Op(1, 23220472999049450395879);
        ops[2] = P4Adversary.Op(13, 2439037181390208231516294383091);
        _runI5(ops, "full program (4,1,13)");
        P4Adversary.Op[] memory ops2 = new P4Adversary.Op[](1);
        ops2[0] = P4Adversary.Op(1, 23220472999049450395879);
        _runI5(ops2, "swap only (1) - no aero move");
        P4Adversary.Op[] memory ops3 = new P4Adversary.Op[](2);
        ops3[0] = P4Adversary.Op(13, 2439037181390208231516294383091);
        ops3[1] = P4Adversary.Op(1, 23220472999049450395879);
        _runI5(ops3, "aero move first then swap (13,1)");
    }

    function test_replay_medium4_I7() public {
        h.a_program([uint256(19522), 14, 6088170, 317942684, 822333294739597949471917823180105001410001, 1684], [uint256(3957201384), 13262, 1461501637330902918203684832716283019655932542975, 2190332811, 16253, 61801706835762437534477659934411257576615823318580767164318962242937750038061], 200000000000000000000);
        h.h_seSwapExactOut(17936, 0, 2, false);
        h.a_program([uint256(16394), 10000, 39, 469473, 11170, 1136], [uint256(20), 20000000000000000000, 281474976710655, 12256, 281474976710655, 3600], 34830048261968031257614025);
        h.h_aeroArb();
        h.a_program([uint256(1690608931732191128337938014270141280244393), 57807678018466194938818653788036917434, 41415179561316310554353381740626559722057267684209841288045423188, 62369644052657872140555322, 4451211155, 36153488641605093852], [uint256(219), 620453555300905476348767459429665015044334, 224391891913521994876518, 160401173606978290387710061304560131195875464782922637064285003791075, 17670635660271497149160346317005401943449512901121456606128, 115792089237316195423570985008687907853269984665640564039457584007913129639935], 8979244653584469095309997735807496147642114097226421944280);
        h.h_mockSwapExactOut(1461501637330902918203684832716283019655932542975, 10530, 1000000000000, false);
        h.h_mockSwapExactIn(10000000000000000, 1000000000000000, 6);
        h.h_addUnbalanced(3166037882687178102874957588857333568697677265101047924978421668867880389040, 115792089237316195423570985008687907853269984665640564039457584007913129639934, 637158721752468770657526950307021829470490967501, 14241788022255886478692447233361303481140454855365289);
        h.h_donate(112336214698132698943098920761410988499977, 115792089237316195423570985008687907853269984665640564039457584007913129639933, 2310175522324719708369181167147684526235813619456);
        h.a_program([uint256(5853215707564369985798707), 20730011937700632341400090623864515, 479125212662592114492421234, 170888962879323607788547883581482123437086720365888464, 2860704388451668075574464052238744321843164412391870440507166, 929915611], [uint256(397269080), 21203321738312677183442607392792408873204144413705748676, 1, 78214364029342159547715782528243962090120, 115792089237316195423570985008687907853269984665640564039457584007913129639935, 120768555304992], 9582189749988978501416665282379209206855883488269682221541225328016806857023);
        h.h_mockSwapExactIn(50, 604800, 64297665218010114168093689776486711162871634548905735406709217792380176022341);
        h.h_mockSwapExactOut(7, 9591932135745647919901757715705820556955925198756582344792433003558549105532, 499, false);
        (,, uint256[] memory raw,) = IVault(address(vault)).getPoolTokenInfo(bufferPool);
        console2.log("pre-final pool liveTTA(idx?) raw0/raw1", raw[0], raw[1]);
        console2.log("virtualTTA / h", IP4BufView(bufferPool).virtualTTA());
        console2.logInt(IP4BufView(bufferPool).hookSharesDelta());
        console2.log("ttaIndex", IP4BufView(bufferPool).ttaIndex());
        (uint256 f0, uint256 r0v) = _aliceVal();
        _advLog("BEFORE final program");
        h.a_program([uint256(26936274090631830599635342949572324802754052044182745667049241084097588082394), 5000000000000000000, 18834, 500000000000000000000, 1003, 8359], [uint256(10000000000000000000), 99990000000000000000, 16, 19103, 686100936602255901738356276852555358882189777908, 14], 32);
        _advLog("AFTER final program");
        (uint256 f1, uint256 r1v) = _aliceVal();
        console2.log("alice fair before/after", f0, f1);
        console2.log("alice rate-valued before/after", r0v, r1v);
        console2.log("profitViolations / last", h.profitViolations(), h.lastProfitViolation());
    }
}

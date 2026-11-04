// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DzInvBase} from "./DzInvBase.t.sol";

/// Replay of the deep-fuzz INV-2a break (detf.log, DetfInvariantTest, shrunk 7 calls) on the same harness,
/// instrumented to show what the final pretransferred mint actually paid vs. what INV-2a charged it with.
contract DzInv2aReplay is DzInvBase {
    bytes32 constant TRANSFER = keccak256("Transfer(address,address,uint256)");

    function _prefix() internal {
        h.h_marketMove(14993, true);
        h.a_pretransfer(11343872967557445712496745348822310946306922816360982565532551169865851923, 1790080350115765827123282554619, 741625833555350293679383493886534133458771356965589002);
        h.a_burn(895, 25252635464160622100917991260232646306916028971414078037834420486105808243661);
        h.a_mint(47968427805066121049381083698257911714407544535517030129577633, 307678875990765756652354955205431890743);
        h.a_donate(3643047537, 35137130659416757679582910009376400481201124194952101350107516583401859182741);
        h.a_pretransfer(700, 15548, 144163205315256026820386714424);
    }

    uint256 constant T_SEL = 2100111235;
    uint256 constant T_AMT = 47209176527818215804562777146582682539327512192606865335393252809108751384597;
    uint256 constant T_EXTRA = 792067761839585587453268865966828378113048155285;
    uint256 constant T_OP = 10872134393090328687412772423127818259620112249767228261881256877562063195928;

    function _log(string memory tag) internal view {
        console2.log(tag);
        console2.log("  pFair / mid", h.pFair(), h.mid());
        console2.log("  SE on DETF diamond (unbooked candidate)", IERC20(se).balanceOf(detf));
        console2.log("  advGifts[detf][se]", h.advGifts(detf, se));
        console2.log("  adv SE / DETF", IERC20(se).balanceOf(address(h)), IERC20(detf).balanceOf(address(h)));
        console2.log("  mintViol / maxMintExcessBps", h.ghost_mintViol(), h.ghost_maxMintExcessBps());
        console2.log("  leakViol / overclaimAccepted / overclaimSelfFunded", h.ghost_leakViol(), h.ghost_overclaimAccepted(), h.ghost_overclaimSelfFunded());
        console2.log("  advProfit (pair wei, signed)");
        console2.logInt(h.advProfit());
    }

    function test_replay_full() public {
        _prefix();
        _log("== after 6-call prefix");
        uint256 seAdv0 = IERC20(se).balanceOf(address(h));
        uint256 d0 = IERC20(detf).balanceOf(address(h));
        int256 prof0 = h.advProfit();
        uint256 seDiamond0 = IERC20(se).balanceOf(detf);
        h.a_pretransferClaim(T_SEL, T_AMT, T_EXTRA, T_OP);
        uint256 amtPaid = bound(T_AMT, 1e12, seAdv0 / 4); // handler: amtSeed%4 != 0 branch
        console2.log("  advProfit delta of final action (pair wei, signed)");
        console2.logInt(h.advProfit() - prof0);
        console2.log("  SE on diamond before/after", seDiamond0, IERC20(se).balanceOf(detf));
        uint256 extra = bound(T_EXTRA, 1, amtPaid);
        uint256 out = IERC20(detf).balanceOf(address(h)) - d0;
        console2.log("== final a_pretransferClaim(op=0 mint, tok=SE, overclaim)");
        console2.log("  SE transferred in this action (amt)", amtPaid);
        console2.log("  extra claimed beyond amt", extra);
        console2.log("  declared amountIn = amt+extra", amtPaid + extra);
        console2.log("  adv SE spent net", seAdv0 - IERC20(se).balanceOf(address(h)));
        console2.log("  DETF out", out);
        console2.log("  ratio (amt+extra)/amt x1e4", (amtPaid + extra) * 1e4 / amtPaid);
        _log("== after final call");
        checkCore();
    }

    /// Control: same final step with the over-claim removed (extraSeed even => extra = 0).
    function test_replay_noOverclaim() public {
        _prefix();
        h.a_pretransferClaim(T_SEL, T_AMT, T_EXTRA - 1, T_OP);
        _log("== after final call, extra=0");
        checkCore();
    }

    /// Control: skip the earlier self-gift of SE to the DETF diamond (prefix call 6).
    function test_replay_noSelfGift() public {
        h.h_marketMove(14993, true);
        h.a_pretransfer(11343872967557445712496745348822310946306922816360982565532551169865851923, 1790080350115765827123282554619, 741625833555350293679383493886534133458771356965589002);
        h.a_burn(895, 25252635464160622100917991260232646306916028971414078037834420486105808243661);
        h.a_mint(47968427805066121049381083698257911714407544535517030129577633, 307678875990765756652354955205431890743);
        h.a_donate(3643047537, 35137130659416757679582910009376400481201124194952101350107516583401859182741);
        _log("== before final, no self-gift");
        h.a_pretransferClaim(T_SEL, T_AMT, T_EXTRA, T_OP);
        _log("== after final call, no self-gift");
        checkCore();
    }
}

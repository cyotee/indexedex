// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ChainDetfAttacker, ChainDetfLender} from "./ChainDetfSystem.t.sol";
import {AdjRealCapitalTest, AdjZeroFeeWhale} from "./AdjRealCapital.t.sol";

/// @notice Independent checker: same production-parameter whale runs as AdjRealCapitalTest, but reports the whale's
/// inventory loss under BOTH valuations (spot liquidation, and backing per circulating DETF) so the verdict's
/// sensitivity to the valuation choice is explicit.
contract AdjCheckerBackingTest is AdjRealCapitalTest {
    function ext_both(ChainDetfAttacker.Cfg memory c, uint256 inv) external returns (int256 real, int256 netSpot, int256 netBack) {
        require(msg.sender == address(this));
        uint256 bpdB = _backingPerCircDetf();
        (real,, netSpot) = this.ext_whale("CHK X2 whale composite", c);
        uint256 bpdA = _backingPerCircDetf();
        netBack = real + (int256(bpdA) - int256(bpdB)) * int256(inv) / 1e9;
        console2.log("  CHK backing/1e9 circ DETF before/after", bpdB, bpdA);
    }

    function test_chk_prodWhale_bothValuations() public {
        _setupHonest();
        _prodFees();
        s0 = _spotDetfIn(IERC20(address(pair0)));
        s1 = _spotDetfIn(IERC20(address(pair1)));
        uint256 lend = IERC20(detf).balanceOf(address(lender));
        uint256 poolD = _reserveOf(detf);
        whale = new AdjZeroFeeWhale(IERC20(detf));
        vm.prank(address(lender)); IERC20(detf).transfer(address(whale), lend);
        lender = ChainDetfLender(address(whale));
        uint256[5] memory bps = [uint256(550), 1000, 2500, 5000, 0];
        for (uint256 i; i < 5; ++i) {
            uint256 d = bps[i] == 0 ? lend : poolD * bps[i] / 10_000;
            if (d > lend) d = lend;
            ChainDetfAttacker.Cfg memory c = _cfg(d, 0, 300 ether, 1000 ether);
            c.bondChunks = 2; c.chunks = 3; c.dumpLeg0 = true; c.bondFirst = true;
            uint256 snap = vm.snapshotState();
            try this.ext_both(c, d) returns (int256 a, int256 ns, int256 nb) {
                console2.log("CHK ROW inventory bps of pool DETF", d * 10_000 / poolD);
                console2.log("CHK ROW realized / whale-net(spot liquidation) / whale-net(backing):");
                console2.logInt(a); console2.logInt(ns); console2.logInt(nb);
            } catch (bytes memory e) { console2.log("CHK ROW REVERTED bps", bps[i]); console2.logBytes(e); }
            vm.revertToState(snap);
        }
    }
}

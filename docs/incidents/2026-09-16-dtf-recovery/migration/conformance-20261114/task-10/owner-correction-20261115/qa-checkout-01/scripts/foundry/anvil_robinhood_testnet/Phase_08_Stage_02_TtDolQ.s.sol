// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ProtocolDetfInstanceLib} from "./ProtocolDetfInstanceLib.sol";

/// @title Phase_08_Stage_02_TtDolQ
/// @notice USD quad TTDOL-Q. Premine before broadcast.
/// @dev Skip key: `TTDOL-Q`.
contract Phase_08_Stage_02_TtDolQ is LaunchStageBase {
    function run() external {
        _start("Phase 08 Stage 02: TTDOL-Q");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_08_02, _skipKeys("TTDOL-Q"))) {
            s.ttDolQ = _loadAddr(FILE_08_02, "TTDOL-Q");
            _exportTtDolQ(s);
            _logAddress("TTDOL-Q:", s.ttDolQ);
            _logComplete("Phase 08 Stage 02 (cached)");
            return;
        }
        _prepDolQ();
        uint256 nonce;
        if (!_hasCode(s.ttDolQ)) {
            console2.log("08-02 premine quad hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = ProtocolDetfInstanceLib.premineDolQ(s);
            console2.log("08-02 premined nonce", nonce);
        }
        _broadcast();
        if (_hasCode(s.ttDolQ)) {
            ProtocolDetfInstanceLib.enrichDolQ(s, owner);
        } else {
            ProtocolDetfInstanceLib.deployDolQ(s, owner, nonce);
        }
        vm.stopBroadcast();
        _exportTtDolQ(s);
        _logAddress("TTDOL-Q:", s.ttDolQ);
        _logComplete("Phase 08 Stage 02");
    }

    function _prepDolQ() private {
        _requireDiamondFactory(s);
        _requireHookFactory(s);
        _requireManager(s);
        _requireCoreTokens(s);
        _requireUsdSes(s);
        s.uniV4DetfPkg = _loadAddr(FILE_06_07, "uniV4DetfPkg");
        s.curveQuadHookPkg = _loadAddr(FILE_06_06, "curveQuadHookPkg");
        require(_hasCode(s.uniV4DetfPkg), "run Phase 06 Stage 07 first");
        require(_hasCode(s.curveQuadHookPkg), "run Phase 06 Stage 06 first");
        s.ttDolQ = _loadAddr(FILE_08_02, "TTDOL-Q");
    }
}

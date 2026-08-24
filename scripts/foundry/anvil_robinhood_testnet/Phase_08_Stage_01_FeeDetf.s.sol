// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {LaunchStageBase} from "./LaunchStageBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {ProtocolDetfInstanceLib} from "./ProtocolDetfInstanceLib.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";

/// @title Phase_08_Stage_01_FeeDetf
/// @notice Fee DETF DTF-DETF / claim DTF-CLAIM. Premine before broadcast.
/// @dev Skip key: `DTF-DETF`.
contract Phase_08_Stage_01_FeeDetf is LaunchStageBase {
    function run() external {
        _start("Phase 08 Stage 01: DTF-DETF");
        RobinhoodCanonicalLib.requireCanonicalPins();
        if (_shouldSkipStage(FILE_08_01, _skipKeys("DTF-DETF"))) {
            s.dtfDetf = _loadAddr(FILE_08_01, "DTF-DETF");
            s.dtfClaim = _loadAddr(FILE_08_01, "DTF-CLAIM");
            if (!_hasCode(s.dtfClaim) && _hasCode(s.dtfDetf)) {
                s.dtfClaim = address(IDetf(s.dtfDetf).rebasingClaimToken());
            }
            _exportFeeDetf(s);
            _logAddress("DTF-DETF:", s.dtfDetf);
            _logComplete("Phase 08 Stage 01 (cached)");
            return;
        }
        _prepFeeDetf();
        uint256 nonce;
        if (!_hasCode(s.dtfDetf)) {
            console2.log("08-01 premine CP hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = ProtocolDetfInstanceLib.premineDtfDetf(s);
            console2.log("08-01 premined nonce", nonce);
        }
        _broadcast();
        if (_hasCode(s.dtfDetf)) {
            ProtocolDetfInstanceLib.enrichDtfDetf(s, owner);
        } else {
            ProtocolDetfInstanceLib.deployDtfDetf(s, owner, nonce);
        }
        vm.stopBroadcast();
        _exportFeeDetf(s);
        _logAddress("DTF-DETF:", s.dtfDetf);
        _logAddress("DTF-CLAIM:", s.dtfClaim);
        _logComplete("Phase 08 Stage 01");
    }

    function _prepFeeDetf() private {
        _requireDiamondFactory(s);
        _requireHookFactory(s);
        _requireManager(s);
        _requireCoreTokens(s);
        _requireDtfWethSe(s);
        s.cpDetfPkg = _loadAddr(FILE_06_07, "cpDetfPkg");
        s.cpHookPkg = _loadAddr(FILE_06_03, "cpHookPkg");
        require(_hasCode(s.cpDetfPkg), "run Phase 06 Stage 07 first");
        require(_hasCode(s.cpHookPkg), "run Phase 06 Stage 03 first");
        s.dtfDetf = _loadAddr(FILE_08_01, "DTF-DETF");
        s.dtfClaim = _loadAddr(FILE_08_01, "DTF-CLAIM");
    }
}

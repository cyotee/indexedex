// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice DTF-DETF: required first DETF (pair TTWETH, SE DTF/TTWETH). Claim token is DTF-CLAIM.
contract Script_06_Ttchir is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06t: DTF-DETF deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.dtfDetf)) {
            console2.log("06t premine CP hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineDtfDetf(s);
            console2.log("06t premined nonce", nonce);
        }
        _broadcast();
        if (_hasCode(s.dtfDetf)) {
            Stage_06_LeafDETFs.enrichDtfDetf(s, owner);
        } else {
            Stage_06_LeafDETFs.deployDtfDetf(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("DTF-DETF", s.dtfDetf);
        _logAddress("DTF-CLAIM:", s.dtfClaim);
    }
}

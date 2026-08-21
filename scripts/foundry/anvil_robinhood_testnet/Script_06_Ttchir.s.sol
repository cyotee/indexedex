// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTCHIR: required first DETF (pair TTWETH, SE TTRICH/TTWETH). Claim token is TTRICHIR.
contract Script_06_Ttchir is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06t: TTCHIR deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.ttChir)) {
            console2.log("06t premine CP hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineChir(s);
            console2.log("06t premined nonce", nonce);
        }
        _broadcast();
        if (_hasCode(s.ttChir)) {
            Stage_06_LeafDETFs.enrichChir(s, owner);
        } else {
            Stage_06_LeafDETFs.deployChir(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("TTCHIR", s.ttChir);
        _logAddress("TTRICHIR:", s.ttRichir);
    }
}

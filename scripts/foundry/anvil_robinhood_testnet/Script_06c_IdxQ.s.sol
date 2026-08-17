// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTIDX-Q: deployVault + first-bond + one sized D47 deposit per leg.
contract Script_06c_IdxQ is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06c: TTIDX-Q deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.ttIdxQ)) {
            console2.log("06c premine quad hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineIdxQ(s);
            console2.log("06c premined nonce", nonce);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttIdxQ)) {
            Stage_06_LeafDETFs.enrichIdxQ(s, owner);
        } else {
            Stage_06_LeafDETFs.deployIdxQ(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("TTIDX-Q", s.ttIdxQ);
    }
}

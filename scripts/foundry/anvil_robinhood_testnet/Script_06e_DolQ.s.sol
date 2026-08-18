// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTDOL-Q: deployVault (bootstrap hook only) + door/finalize/wire + first-bond + one sized D47 deposit per leg.
contract Script_06e_DolQ is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06e: TTDOL-Q deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.ttDolQ)) {
            console2.log("06e premine quad hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineDolQ(s);
            console2.log("06e premined nonce", nonce);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttDolQ)) {
            Stage_06_LeafDETFs.enrichDolQ(s, owner);
        } else {
            Stage_06_LeafDETFs.deployDolQ(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("TTDOL-Q", s.ttDolQ);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTNVDA-SMH-O: deployVault (bootstrap hook only) + door/finalize/wire + first-bond + one sized D47 deposit per leg.
contract Script_06b_NvdaSmhO is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06b: TTNVDA-SMH-O deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.ttNvdaSmhO)) {
            console2.log("06b premine orbital hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineNvdaSmhO(s);
            console2.log("06b premined nonce", nonce);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttNvdaSmhO)) {
            Stage_06_LeafDETFs.enrichNvdaSmhO(s, owner);
        } else {
            Stage_06_LeafDETFs.deployNvdaSmhO(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("TTNVDA-SMH-O", s.ttNvdaSmhO);
    }
}

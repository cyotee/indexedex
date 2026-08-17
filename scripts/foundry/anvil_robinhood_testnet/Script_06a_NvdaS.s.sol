// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Stage_06_LeafDETFs} from "./Stage_06_LeafDETFs.sol";
import {Script_06_LeafBase} from "./Script_06_LeafBase.sol";

/// @notice TTNVDA-S: deployVault + first-bond + one sized D47 deposit.
contract Script_06a_NvdaS is Script_06_LeafBase {
    function run() external {
        _prepLeaves();
        _logHeader("Group 06a: TTNVDA-S deploy + first-bond + D47");
        uint256 nonce;
        if (!_hasCode(s.ttNvdaS)) {
            console2.log("06a premine CP hook nonce (off-chain, not a broadcast tx)");
            (, nonce) = Stage_06_LeafDETFs.premineNvdaS(s);
            console2.log("06a premined nonce", nonce);
        }
        vm.startBroadcast();
        if (_hasCode(s.ttNvdaS)) {
            Stage_06_LeafDETFs.enrichNvdaS(s, owner);
        } else {
            Stage_06_LeafDETFs.deployNvdaS(s, owner, nonce);
        }
        vm.stopBroadcast();
        _done("TTNVDA-S", s.ttNvdaS);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase as AnvilDeploymentBase} from "../../anvil_base_main/DeploymentBase.sol";

contract DeploymentBase is AnvilDeploymentBase {
    function _localOutDir() internal view returns (string memory) {
        try vm.envString("OUT_DIR_OVERRIDE") returns (string memory value) {
            if (bytes(value).length > 0) {
                return value;
            }
        } catch {}

        revert("OUT_DIR_OVERRIDE must be set");
    }
}
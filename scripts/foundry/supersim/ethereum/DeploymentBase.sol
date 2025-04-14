// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {DeploymentBase as SuperSimDeploymentBase} from "../DeploymentBase.sol";

abstract contract DeploymentBase is SuperSimDeploymentBase {
    function _localOutDir() internal view returns (string memory) {
        return _ethereumOutDir();
    }

    function _chainRole() internal pure returns (string memory) {
        return "ethereum";
    }
}

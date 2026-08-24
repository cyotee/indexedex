// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_03_Stage_01_CommonFacets as CommonFacetsLib} from "./Phase_03_Stage_01_CommonFacets.sol";

/// @title Phase_03_Stage_01_CommonFacets
/// @notice Skip keys: `erc20Facet`, `multiAssetBasicVaultFacet`, `diamondCutFacet`.
contract Phase_03_Stage_01_CommonFacets is LaunchStageBase {
    function run() external {
        _start("Phase 03 Stage 01: Common facets");
        if (_shouldSkipStage(FILE_03_01, _skipKeys("erc20Facet", "multiAssetBasicVaultFacet", "diamondCutFacet"))) {
            _requireCommonFacets(s);
        } else {
            _requireCreate3(s);
            _broadcast();
            CommonFacetsLib.execute(s);
            vm.stopBroadcast();
        }
        _exportCommonFacets(s);
        _logAddress("erc20Facet:", address(s.erc20Facet));
        _logComplete("Phase 03 Stage 01");
    }
}

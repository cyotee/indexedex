// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_10_RebasingAwareERC4626Pkg as RebasingAwarePkgLib} from
    "./Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol";

/// @title Phase_06_Stage_10_RebasingAwareERC4626Pkg
/// @notice Deploys the wrapper package and facet independently of optional TokenStaking.
contract Phase_06_Stage_10_RebasingAwareERC4626Pkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 10: Rebasing-aware ERC4626 pkg");
        _requireDiamondFactory(s);
        _requireCommonFacets(s);
        _requireManager(s);
        string[] memory skipKeys = new string[](6);
        skipKeys[0] = "rebasingAwareErc4626Pkg";
        skipKeys[1] = "rebasingAwareErc4626Facet";
        skipKeys[2] = "rebasingAwareSeFacet";
        skipKeys[3] = "rebasingAwareSyFacet";
        skipKeys[4] = "rebasingAwareMetadataFacet";
        skipKeys[5] = "rebasingAwareQuoteFacet";
        bool current;
        if (_shouldSkipStage(FILE_06_10, skipKeys)) {
            _loadRebasingAwareERC4626Pkg(s);
            current = RebasingAwarePkgLib.isCurrent(s);
        }
        if (!current) {
            _broadcast();
            RebasingAwarePkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportRebasingAwareERC4626Pkg(s);
        _logAddress("rebasingAwareErc4626Facet:", address(s.rebasingAwareErc4626Facet));
        _logAddress("rebasingAwareSeFacet:", address(s.rebasingAwareSeFacet));
        _logAddress("rebasingAwareSyFacet:", address(s.rebasingAwareSyFacet));
        _logAddress("rebasingAwareMetadataFacet:", address(s.rebasingAwareMetadataFacet));
        _logAddress("rebasingAwareQuoteFacet:", address(s.rebasingAwareQuoteFacet));
        _logAddress("rebasingAwareErc4626Pkg:", s.rebasingAwareErc4626Pkg);
        _logComplete("Phase 06 Stage 10");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {Phase_06_Stage_08_TokenStakingPkg as TokenStakingPkgLib} from
    "./Phase_06_Stage_08_TokenStakingPkg.sol";

/// @title Phase_06_Stage_08_TokenStakingPkg
/// @notice Skip key: `tokenStakingPkg`. CREATE3 facets + DFPkgs. No instance.
contract Phase_06_Stage_08_TokenStakingPkg is LaunchStageBase {
    function run() external {
        _start("Phase 06 Stage 08: TokenStaking pkg");
        if (_shouldSkipStage(FILE_06_08, _skipKeys("tokenStakingPkg"))) {
            _requireDiamondFactory(s);
            _loadTokenStakingPkg(s);
        } else {
            _requireDiamondFactory(s);
            _requireCommonFacets(s);
            _broadcast();
            TokenStakingPkgLib.execute(s);
            vm.stopBroadcast();
        }
        _exportTokenStakingPkg(s);
        _logAddress("tokenStakingFacet:", address(s.tokenStakingFacet));
        _logAddress("rebasingAwareErc4626Pkg:", s.rebasingAwareErc4626Pkg);
        _logAddress("tokenStakingPkg:", s.tokenStakingPkg);
        _logComplete("Phase 06 Stage 08");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {Phase_06_Stage_10_RebasingAwareERC4626Pkg} from "./Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {TokenStaking_Component_FactoryService} from
    "contracts/protocols/staking/token/TokenStaking_Component_FactoryService.sol";

/// @title Phase_06_Stage_08_TokenStakingPkg
/// @notice TokenStaking facet + rebasing-aware ERC-4626 DFPkg + TokenStaking DFPkg via CREATE3.
library Phase_06_Stage_08_TokenStakingPkg {
    using TokenStaking_Component_FactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
        address permit2_ = RobinhoodCanonicalLib.permit2();
        require(permit2_.code.length > 0, "Phase 06-08: Permit2 pin");
        Phase_06_Stage_10_RebasingAwareERC4626Pkg.execute(s);
        s.tokenStakingFacet = s.create3Factory.deployTokenStakingFacet();
        s.tokenStakingPkg = address(
            TokenStaking_Component_FactoryService.deployTokenStakingDFPkg(
                s.create3Factory,
                ITokenStakingDFPkg.PkgInit({
                    tokenStakingFacet: s.tokenStakingFacet,
                    multiStepOwnableFacet: s.multiStepOwnableFacet,
                    claimVaultPkg: IRebasingAwareERC4626DFPkg(s.rebasingAwareErc4626Pkg),
                    permit2: IPermit2(permit2_)
                })
            )
        );
    }
}

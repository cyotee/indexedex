// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";

/// @title Phase_08_Stage_01_TokenStakingDtf
/// @notice $DTF TokenStaking instance via diamondPackageFactory. Does not notify rewards.
library Phase_08_Stage_01_TokenStakingDtf {
    uint256 internal constant REWARDS_DURATION = 7 days;
    uint256 internal constant OWNERSHIP_BUFFER = 2 days;

    function execute(LaunchState storage s, address owner_) internal {
        address dtf_ = RobinhoodCanonicalLib.dtf();
        require(dtf_.code.length > 0, "Phase 08-01: $DTF has no code");
        require(owner_ != address(0), "Phase 08-01: owner");
        require(s.tokenStakingPkg.code.length > 0, "Phase 08-01: tokenStakingPkg");
        s.tokenStaking = address(
            ITokenStakingDFPkg(s.tokenStakingPkg).deployStaking(
                s.diamondPackageFactory,
                ITokenStakingDFPkg.PkgArgs({
                    stakingToken: IERC20(dtf_),
                    rewardsDuration: REWARDS_DURATION,
                    owner: owner_,
                    ownershipBufferPeriod: OWNERSHIP_BUFFER,
                    optionalSalt: bytes32(0)
                })
            )
        );
    }
}

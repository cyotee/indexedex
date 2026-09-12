// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/DETFSYDFPkg.sol";
import {DETFChildSYRepo} from "contracts/vaults/detf/common/sy/DETFChildSYRepo.sol";

/// @title DETFSYDeploymentLib
/// @notice Parent-package post-deployment wiring through the registered wrapper package.
library DETFSYDeploymentLib {
    event StandardizedYieldWired(address indexed rawSY, address indexed stakingSY);

    function _deploy(IDETFSYDFPkg pkg_, IStakedDETF staking_, address[] memory in_, address[] memory out_) internal {
        IDETFSYDFPkg.PkgArgs memory args_ = IDETFSYDFPkg.PkgArgs({
            detf: IERC20(address(this)), staking: staking_, isStaking: false,
            name: string.concat("SY ", ERC20Repo._name()), symbol: string.concat("SY-", ERC20Repo._symbol()),
            tokensIn: in_, tokensOut: out_
        });
        address raw_ = pkg_.deployVault(args_);
        args_.isStaking = true;
        args_.name = string.concat("SY Staked ", ERC20Repo._name());
        args_.symbol = string.concat("SY-s", ERC20Repo._symbol());
        address staked_ = pkg_.deployVault(args_);
        DETFChildSYRepo._initialize(raw_, staked_);
        emit StandardizedYieldWired(raw_, staked_);
    }
}

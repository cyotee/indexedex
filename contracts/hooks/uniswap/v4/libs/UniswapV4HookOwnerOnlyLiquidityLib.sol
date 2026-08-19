// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";

/// @title UniswapV4HookOwnerOnlyLiquidityLib
/// @notice D9: when `ownerOnlyLiquidity` is set, only the MultiStepOwnable owner may add/remove LP.
/// @dev Native V4 `modifyLiquidity` stays banned on product hooks independently of this flag.
library UniswapV4HookOwnerOnlyLiquidityLib {
    function enforce(bool ownerOnlyLiquidity) internal view {
        if (ownerOnlyLiquidity) {
            MultiStepOwnableRepo._onlyOwner();
        }
    }
}

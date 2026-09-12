// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldContextRepo} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";

/// @notice Immutable liquidity policy exposed by DETF reserve hooks.
interface IUniswapV4HookLiquidityPolicy {
    function ownerOnlyLiquidity() external view returns (bool);
}

/// @title UniswapV4HookOwnerOnlyLiquidityLib
/// @notice D9: when `ownerOnlyLiquidity` is set, only the owner may add LP; the current fee collector may also redeem LP.
/// @dev Native V4 `modifyLiquidity` stays banned on product hooks independently of this flag.
library UniswapV4HookOwnerOnlyLiquidityLib {
    /// @dev Callers pass the live oracle feeTo, never a deployment-time recipient snapshot.
    function enforceRemoval(bool restricted, address feeRecipient) internal view {
        if (!restricted) return;
        address actor = msg.sender;
        if (actor == address(this)) {
            address initiator = NativeStandardYieldContextRepo._initiator();
            if (initiator != address(0)) actor = initiator;
        }
        if (actor != feeRecipient && actor != MultiStepOwnableRepo._owner()) {
            revert IMultiStepOwnable.NotOwner(actor);
        }
    }

    function enforce(bool ownerOnlyLiquidity) internal view {
        if (ownerOnlyLiquidity) {
            MultiStepOwnableRepo._onlyOwner();
        }
    }
}

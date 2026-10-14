// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUnbalancedLiquidityInvariantRatioBounds} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IUnbalancedLiquidityInvariantRatioBounds.sol";
import {BalancerV3PoolRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3PoolRepo.sol";

/// @dev Capture the installed implementation's bounds once during package initialization.
/// Both constant bounds facets and repo-backed bounds execute in the initialized pool context.
/// Native quotes can then read the existing fields without routing through the diamond.
library BalancerV3NativePoolBounds {
    function initialize(IFacet facet_) internal {
        uint256 minimum_ = _read(facet_, IUnbalancedLiquidityInvariantRatioBounds.getMinimumInvariantRatio.selector);
        uint256 maximum_ = _read(facet_, IUnbalancedLiquidityInvariantRatioBounds.getMaximumInvariantRatio.selector);
        BalancerV3PoolRepo.Storage storage layout_ = BalancerV3PoolRepo._layoutStruct();
        layout_.minimumInvariantRatio = minimum_;
        layout_.maximumInvariantRatio = maximum_;
    }

    function _read(IFacet facet_, bytes4 selector_) private returns (uint256) {
        (bool success_, bytes memory result_) = address(facet_).delegatecall(abi.encodeWithSelector(selector_));
        if (!success_) {
            assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        }
        return abi.decode(result_, (uint256));
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4DetfMigrationAllocation as Allocation} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationClaimVaultAllocationTarget} from "./UniswapV4DetfMigrationClaimVaultAllocationTarget.sol";

/// @notice Sole direct-share configuration selector; removed with every other loader at activation.
contract UniswapV4DetfMigrationClaimVaultAllocationFacet is UniswapV4DetfMigrationClaimVaultAllocationTarget, IFacet {
    function facetName() public pure returns (string memory) { return "UniswapV4DetfMigrationClaimVaultAllocationFacet"; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) { return new bytes4[](0); }
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](1);
        funcs_[0] = Allocation.configureClaimVaultEntitlements.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4DetfMigrationRecovery as Recovery} from "./interfaces/IUniswapV4DetfMigrationRecovery.sol";
import {UniswapV4DetfMigrationRecoveryTarget} from "./UniswapV4DetfMigrationRecoveryTarget.sol";

/// @notice Persistent finite recovery surface; no removable administration selectors.
contract UniswapV4DetfMigrationRecoveryFacet is UniswapV4DetfMigrationRecoveryTarget, IFacet {
    function facetName() public pure returns (string memory) { return "UniswapV4DetfMigrationRecoveryFacet"; }
    function facetInterfaces() public pure returns (bytes4[] memory ids_) {
        ids_ = new bytes4[](1);
        ids_[0] = type(Recovery).interfaceId;
    }
    function facetFuncs() public pure returns (bytes4[] memory funcs_) {
        funcs_ = new bytes4[](4);
        funcs_[0] = Recovery.recoverMigrationNfts.selector;
        funcs_[1] = Recovery.migrationRecoveryInventory.selector;
        funcs_[2] = Recovery.migrationRecoveryGons.selector;
        funcs_[3] = Recovery.migrationNftRecovery.selector;
    }
    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}

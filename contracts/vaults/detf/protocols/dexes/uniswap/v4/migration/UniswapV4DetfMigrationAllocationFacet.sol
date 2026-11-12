// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IUniswapV4DetfMigration as Migration, IUniswapV4DetfMigrationAllocation as Allocation} from "./interfaces/IUniswapV4DetfMigration.sol";
import {UniswapV4DetfMigrationAllocationTarget} from "./UniswapV4DetfMigrationAllocationTarget.sol";
contract UniswapV4DetfMigrationAllocationFacet is UniswapV4DetfMigrationAllocationTarget, IFacet {
function facetName() public pure returns(string memory) { return "UniswapV4DetfMigrationAllocationFacet"; }
function facetInterfaces() public pure returns(bytes4[] memory ids_) { ids_ = new bytes4[](1); ids_[0] = type(Allocation).interfaceId; }
function facetFuncs() public pure returns(bytes4[] memory funcs_) {
bytes4[] memory all_ = _administrationSelectors();
funcs_ = new bytes4[](8);
for (uint256 i_; i_ < funcs_.length; ++i_) funcs_[i_] = all_[i_];
}
function facetMetadata() external pure returns(string memory,bytes4[] memory,bytes4[] memory) { return (facetName(),facetInterfaces(),facetFuncs()); }
}

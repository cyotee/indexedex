// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {UniswapV3FullSpreadStandardExchangeVaultReserveTarget} from "./UniswapV3FullSpreadStandardExchangeVaultReserveTarget.sol";

contract UniswapV3FullSpreadStandardExchangeVaultReserveFacet is UniswapV3FullSpreadStandardExchangeVaultReserveTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultReserveFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IBasicVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](3);
        selectors_[0] = IBasicVault.reserves.selector;
        selectors_[1] = IBasicVault.reserveOfToken.selector;
        selectors_[2] = UniswapV3FullSpreadStandardExchangeVaultReserveTarget.canOpenBoundPoolOps.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}

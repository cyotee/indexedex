// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget} from "./UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet is UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget, IFacet {
    function facetName() public pure returns (string memory) {
        return type(UniswapV3FullSpreadStandardExchangeVaultMaintenanceFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces_) {
        interfaces_ = new bytes4[](1);
        interfaces_[0] = type(IVault).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory selectors_) {
        selectors_ = new bytes4[](4);
        selectors_[0] = IVault.donate.selector;
        selectors_[1] = IVault.compound.selector;
        selectors_[2] = IVault.setOperator.selector;
        selectors_[3] = IVault.setOperatorFor.selector;
    }

    function facetMetadata() external pure returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVautlFeeOracleQueryAware} from "contracts/interfaces/IVautlFeeOracleQueryAware.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";

contract VaultFeeOralceQueryAwareFacet is IVautlFeeOracleQueryAware, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */
    function facetName() public pure returns (string memory name) {
        return type(VaultFeeOralceQueryAwareFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVautlFeeOracleQueryAware).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IVautlFeeOracleQueryAware.vaultFeeOracleQuery.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function vaultFeeOracleQuery() external view returns (IVaultFeeOracleQuery) {
        return VaultFeeOracleQueryAwareRepo._feeOracle();
    }
}

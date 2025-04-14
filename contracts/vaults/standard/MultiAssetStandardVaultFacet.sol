// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
// import {BetterIERC20 as IERC20} from "contracts/crane/interfaces/BetterIERC20.sol";
// import {Create3AwareContract} from "contracts/crane/factories/create2/aware/Create3AwareContract.sol";
// import {ICreate3Aware} from "contracts/crane/interfaces/ICreate3Aware.sol";
// import { IERC5115 } from "contracts/crane/interfaces/IERC5115.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";

contract MultiAssetStandardVaultFacet is IStandardVault, IFacet {
    function facetName() public pure returns (string memory name) {
        return type(MultiAssetStandardVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IStandardVault).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](4);
        funcs[0] = IStandardVault.vaultFeeTypeIds.selector;
        funcs[1] = IStandardVault.contentsId.selector;
        funcs[2] = IStandardVault.vaultTypes.selector;
        funcs[3] = IStandardVault.vaultConfig.selector;
        return funcs;
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

    function vaultFeeTypeIds() public view returns (bytes32 vaultFeeTypeIds_) {
        return StandardVaultRepo._vaultFeeTypeIds();
    }

    function contentsId() external view returns (bytes32 contentsId_) {
        return StandardVaultRepo._contentsId();
    }

    function vaultTypes() public view returns (bytes4[] memory vaultTypes_) {
        return StandardVaultRepo._vaultTypes();
    }

    function vaultConfig() public view returns (VaultConfig memory vaultConfig_) {
        StandardVaultRepo.Storage storage layout = StandardVaultRepo._layout();
        vaultConfig_ = IStandardVault.VaultConfig({
            vaultFeeTypeIds: StandardVaultRepo._vaultFeeTypeIds(layout),
            contentsId: StandardVaultRepo._contentsId(layout),
            vaultTypes: StandardVaultRepo._vaultTypes(layout),
            tokens: MultiAssetBasicVaultRepo._vaultTokens()
        });
    }
}

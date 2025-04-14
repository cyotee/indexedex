// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
// import {Create3AwareContract} from "@crane/contracts/factories/create2/aware/Create3AwareContract.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";
import {VaultRegistryVaultPackageRepo} from "contracts/registries/vault/VaultRegistryVaultPackageRepo.sol";
import {VaultRegistryVaultRepo} from "contracts/registries/vault/VaultRegistryVaultRepo.sol";
import {BondTerms, VaultFeeType} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";

contract VaultFeeOracleQueryFacet is IVaultFeeOracleQuery, IFacet {
    using AddressSetRepo for AddressSet;

    function facetName() public pure returns (string memory name) {
        return type(VaultFeeOracleQueryFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IVaultFeeOracleQuery).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](21);
        funcs[0] = IVaultFeeOracleQuery.feeTo.selector;
        funcs[1] = IVaultFeeOracleQuery.usageFeeVaultTypeIds.selector;
        funcs[2] = IVaultFeeOracleQuery.defaultUsageFee.selector;
        funcs[3] = IVaultFeeOracleQuery.defaultUsageFeeOfTypeId.selector;
        funcs[4] = IVaultFeeOracleQuery.usageFeeOfVault.selector;
        funcs[5] = IVaultFeeOracleQuery.usageFeeAndFeeToOfVault.selector;
        funcs[6] = IVaultFeeOracleQuery.dexSwapFeeVaultTypeIds.selector;
        funcs[7] = IVaultFeeOracleQuery.defaultDexSwapFee.selector;
        funcs[8] = IVaultFeeOracleQuery.defaultDexSwapFeeOfTypeId.selector;
        funcs[9] = IVaultFeeOracleQuery.dexSwapFeeOfVault.selector;
        funcs[10] = IVaultFeeOracleQuery.dexSwapFeeAndFeeToOfVault.selector;
        funcs[11] = IVaultFeeOracleQuery.bondVaultTypesIds.selector;
        funcs[12] = IVaultFeeOracleQuery.defaultBondTerms.selector;
        funcs[13] = IVaultFeeOracleQuery.defaultBondTermsOfVaultTypeId.selector;
        funcs[14] = IVaultFeeOracleQuery.bondTermsOfVault.selector;
        funcs[15] = IVaultFeeOracleQuery.bondTermsAndFeeToOfVault.selector;
        funcs[16] = IVaultFeeOracleQuery.seigniorageVaultTypeIds.selector;
        funcs[17] = IVaultFeeOracleQuery.defaultSeigniorageIncentivePercentage.selector;
        funcs[18] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfTypeId.selector;
        funcs[19] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault.selector;
        funcs[20] = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVaultAndFeeTo.selector;
        return funcs;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function feeTo() public view returns (IFeeCollectorProxy) {
        return VaultFeeOracleRepo._feeTo();
    }

    /* ---------------------------------------------------------------------- */
    /*                               Usage Terms                              */
    /* ---------------------------------------------------------------------- */

    function usageFeeVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultUsageFeeTypeIds();
    }

    function defaultUsageFee() public view returns (uint256 defaultFee_) {
        return VaultFeeOracleRepo._defaultVaultUsageFee();
    }

    function defaultUsageFeeOfTypeId(bytes4 vaultFeeTypeId) public view returns (uint256 defaultFee_) {
        return VaultFeeOracleRepo._defaultUsageFeeOfTypeId(vaultFeeTypeId);
    }

    function usageFeeOfVault(address vault) public view returns (uint256 usageFee_) {
        VaultFeeOracleRepo.Storage storage feeOracle = VaultFeeOracleRepo._layout();
        usageFee_ = VaultFeeOracleRepo._usageFeeOfVault(feeOracle, vault);
        if (usageFee_ == 0) {
            usageFee_ = VaultFeeOracleRepo._defaultUsageFeeOfTypeId(
                feeOracle, VaultRegistryVaultRepo._usageFeeIdOfVault(vault)
            );
            if (usageFee_ == 0) {
                usageFee_ = defaultUsageFee();
            }
        }
        return usageFee_;
    }

    function usageFeeAndFeeToOfVault(address vault)
        external
        view
        returns (IFeeCollectorProxy feeTo_, uint256 usageFee_)
    {
        feeTo_ = feeTo();
        usageFee_ = usageFeeOfVault(vault);
        return (feeTo_, usageFee_);
    }

    /* ---------------------------------------------------------------------- */
    /*                                DEX Terms                               */
    /* ---------------------------------------------------------------------- */

    /* ----------------------------- Swap Terms ----------------------------- */

    function dexSwapFeeVaultTypeIds() external view returns (bytes4[] memory vaultTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultDexFeeTypeIds();
    }

    function defaultDexSwapFee() public view returns (uint256 swapFee_) {
        return VaultFeeOracleRepo._defaultDexSwapFee();
    }

    function defaultDexSwapFeeOfTypeId(bytes4 vaultFeeTypeId) public view returns (uint256 swapFee_) {
        return VaultFeeOracleRepo._defaultDexSwapFeeOfTypeId(vaultFeeTypeId);
    }

    function dexSwapFeeOfVault(address vault) public view returns (uint256 swapFee_) {
        VaultFeeOracleRepo.Storage storage feeOracle = VaultFeeOracleRepo._layout();
        swapFee_ = VaultFeeOracleRepo._dexSwapFeeOfVault(feeOracle, vault);
        if (swapFee_ == 0) {
            swapFee_ = VaultFeeOracleRepo._defaultDexSwapFeeOfTypeId(
                feeOracle, VaultRegistryVaultRepo._dexFeeIdOfVault(vault)
            );
            if (swapFee_ == 0) {
                swapFee_ = defaultDexSwapFee();
            }
        }
        return swapFee_;
    }

    function dexSwapFeeAndFeeToOfVault(address vault)
        external
        view
        returns (IFeeCollectorProxy feeTo_, uint256 swapFee_)
    {
        feeTo_ = feeTo();
        swapFee_ = dexSwapFeeOfVault(vault);
        return (feeTo_, swapFee_);
    }

    /* ---------------------------------------------------------------------- */
    /*                               Bond Terms                               */
    /* ---------------------------------------------------------------------- */

    function bondVaultTypesIds() external view returns (bytes4[] memory vaultTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultBondFeeTypeIds();
    }

    function defaultBondTerms() public view returns (BondTerms memory bondTerms_) {
        return VaultFeeOracleRepo._defaultBondTerms();
    }

    function defaultBondTermsOfVaultTypeId(bytes4 vaultFeeTypeId) public view returns (BondTerms memory bondTerms_) {
        return VaultFeeOracleRepo._defaultBondTermsOfVaultTypeId(vaultFeeTypeId);
    }

    function bondTermsOfVault(address vault) public view returns (BondTerms memory bondTerms_) {
        bondTerms_ = VaultFeeOracleRepo._bondTermsOfVault(vault);
        if (bondTerms_.minLockDuration == 0) {
            bondTerms_ = defaultBondTermsOfVaultTypeId(VaultRegistryVaultRepo._bondFeeIdOfVault(vault));
            if (bondTerms_.minLockDuration == 0) {
                bondTerms_ = defaultBondTerms();
            }
        }
        return bondTerms_;
    }

    function bondTermsAndFeeToOfVault(address vault)
        external
        view
        returns (IFeeCollectorProxy feeTo_, BondTerms memory bondTerms_)
    {
        feeTo_ = feeTo();
        bondTerms_ = bondTermsOfVault(vault);
        return (feeTo_, bondTerms_);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Seigniorage Terms                             */
    /* -------------------------------------------------------------------------- */

    function seigniorageVaultTypeIds() public view returns (bytes4[] memory vaultTypeIds_) {
        return VaultRegistryVaultPackageRepo._vaultSeigniorageTypeIds();
    }

    function defaultSeigniorageIncentivePercentage() public view returns (uint256 percentage) {
        return VaultFeeOracleRepo._defaultSeigniorageIncentivePercentage();
    }

    function seigniorageIncentivePercentageOfTypeId(bytes4 vaultTypeId) public view returns (uint256 percentage) {
        return VaultFeeOracleRepo._defaultSeigniorageIncentivePercentageOfTypeId(vaultTypeId);
    }

    function seigniorageIncentivePercentageOfVault(address vault) public view returns (uint256 percentage) {
        percentage = VaultFeeOracleRepo._seigniorageIncentivePercentageOfVault(vault);
        if (percentage == 0) {
            percentage =
                seigniorageIncentivePercentageOfTypeId(VaultRegistryVaultRepo._seigniorageIncentiveIdOfVault(vault));
            if (percentage == 0) {
                percentage = defaultSeigniorageIncentivePercentage();
            }
        }
        return percentage;
    }

    function seigniorageIncentivePercentageOfVaultAndFeeTo(address vault)
        public
        view
        returns (IFeeCollectorProxy feeTo_, uint256 percentage)
    {
        feeTo_ = feeTo();
        percentage = seigniorageIncentivePercentageOfVault(vault);
    }
}

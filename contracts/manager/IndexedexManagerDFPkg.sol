// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {Create3FactoryAwareRepo} from "@crane/contracts/factories/create3/Create3FactoryAwareRepo.sol";
import {DiamondPackageFactoryAwareRepo} from "@crane/contracts/factories/diamondPkg/DiamondPackageFactoryAwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    DEFAULT_VAULT_USAGE_FEE,
    DEFAULT_BOND_MIN_TERM,
    DEFAULT_BOND_MAX_TERM,
    DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
    DEFAULT_BOND_MAX_BONUS_PERCENTAGE,
    DEFAULT_DEX_FEE,
    DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
} from "contracts/constants/Indexedex_CONSTANTS.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {IVaultRegistryVaultPackageManager} from "contracts/interfaces/IVaultRegistryVaultPackageManager.sol";
import {IVaultRegistryVaultManager} from "contracts/interfaces/IVaultRegistryVaultManager.sol";
import {VaultFeeOracleRepo} from "contracts/oracles/fee/VaultFeeOracleRepo.sol";

interface IIndexedexManagerDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet diamondCutFacet;
        IFacet multiStepOwnableFacet;
        IFacet vaultFeeQueryFacet;
        IFacet vaultFeeManagerFacet;
        IFacet operableFacet;
        IFacet vaultRegistryDeploymentFacet;
        IFacet vaultRegistryVaultManagerFacet;
        IFacet vaultRegistryVaultPackageManagerFacet;
        IFacet vaultRegistryVaultPackageQueryFacet;
        IFacet vaultRegistryVaultQueryFacet;
    }

    struct PkgArgs {
        address owner;
        IFeeCollectorProxy feeTo;
        ICreate3FactoryProxy create3Factory;
        IDiamondPackageCallBackFactory diamondPackageFactory;
    }
}

contract IndexedexManagerDFPkg is IIndexedexManagerDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable DIAMOND_CUT_FACET;
    IFacet immutable MULTI_STEP_OWNABLE_FACET;
    IFacet immutable VAULT_FEE_QUERY_FACET;
    IFacet immutable VAULT_FEE_MANAGER_FACET;
    IFacet immutable OPERABLE_FACET;
    IFacet immutable VAULT_REGISTRY_DEPLOYMENT_FACET;
    IFacet immutable VAULT_REGISTRY_VAULT_MANAGER_FACET;
    IFacet immutable VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET;
    IFacet immutable VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET;
    IFacet immutable VAULT_REGISTRY_VAULT_QUERY_FACET;

    constructor(PkgInit memory pkgInitArgs) {
        DIAMOND_CUT_FACET = pkgInitArgs.diamondCutFacet;
        MULTI_STEP_OWNABLE_FACET = pkgInitArgs.multiStepOwnableFacet;
        VAULT_FEE_QUERY_FACET = pkgInitArgs.vaultFeeQueryFacet;
        VAULT_FEE_MANAGER_FACET = pkgInitArgs.vaultFeeManagerFacet;
        OPERABLE_FACET = pkgInitArgs.operableFacet;
        VAULT_REGISTRY_DEPLOYMENT_FACET = pkgInitArgs.vaultRegistryDeploymentFacet;
        VAULT_REGISTRY_VAULT_MANAGER_FACET = pkgInitArgs.vaultRegistryVaultManagerFacet;
        VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET = pkgInitArgs.vaultRegistryVaultPackageManagerFacet;
        VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET = pkgInitArgs.vaultRegistryVaultPackageQueryFacet;
        VAULT_REGISTRY_VAULT_QUERY_FACET = pkgInitArgs.vaultRegistryVaultQueryFacet;
    }

    function packageName() public pure returns (string memory name_) {
        return type(IndexedexManagerDFPkg).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](10);
        interfaces[0] = type(IDiamondCut).interfaceId;
        interfaces[1] = type(IMultiStepOwnable).interfaceId;
        // Order must match facetAddresses() ordering
        interfaces[2] = type(IVaultFeeOracleQuery).interfaceId; // VAULT_FEE_QUERY_FACET
        interfaces[3] = type(IVaultFeeOracleManager).interfaceId; // VAULT_FEE_MANAGER_FACET
        interfaces[4] = type(IOperable).interfaceId; // OPERABLE_FACET
        interfaces[5] = type(IVaultRegistryDeployment).interfaceId;
        interfaces[6] = type(IVaultRegistryVaultManager).interfaceId;
        interfaces[7] = type(IVaultRegistryVaultPackageManager).interfaceId;
        interfaces[8] = type(IVaultRegistryVaultPackageQuery).interfaceId;
        interfaces[9] = type(IVaultRegistryVaultQuery).interfaceId;
        return interfaces;
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](10);
        facetAddresses_[0] = address(DIAMOND_CUT_FACET);
        facetAddresses_[1] = address(MULTI_STEP_OWNABLE_FACET);
        facetAddresses_[2] = address(VAULT_FEE_QUERY_FACET);
        facetAddresses_[3] = address(VAULT_FEE_MANAGER_FACET);
        facetAddresses_[4] = address(OPERABLE_FACET);
        facetAddresses_[5] = address(VAULT_REGISTRY_DEPLOYMENT_FACET);
        facetAddresses_[6] = address(VAULT_REGISTRY_VAULT_MANAGER_FACET);
        facetAddresses_[7] = address(VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET);
        facetAddresses_[8] = address(VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET);
        facetAddresses_[9] = address(VAULT_REGISTRY_VAULT_QUERY_FACET);
    }

    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](10);

        facetCuts_[0] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(DIAMOND_CUT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: DIAMOND_CUT_FACET.facetFuncs()
        });

        facetCuts_[1] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(MULTI_STEP_OWNABLE_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: MULTI_STEP_OWNABLE_FACET.facetFuncs()
        });

        facetCuts_[2] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(OPERABLE_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: OPERABLE_FACET.facetFuncs()
        });

        facetCuts_[3] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_FEE_QUERY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_FEE_QUERY_FACET.facetFuncs()
        });

        facetCuts_[4] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_FEE_MANAGER_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_FEE_MANAGER_FACET.facetFuncs()
        });

        facetCuts_[5] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_REGISTRY_DEPLOYMENT_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_REGISTRY_DEPLOYMENT_FACET.facetFuncs()
        });

        facetCuts_[6] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_REGISTRY_VAULT_MANAGER_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_REGISTRY_VAULT_MANAGER_FACET.facetFuncs()
        });

        facetCuts_[7] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_REGISTRY_VAULT_PACKAGE_MANAGER_FACET.facetFuncs()
        });

        facetCuts_[8] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_REGISTRY_VAULT_PACKAGE_QUERY_FACET.facetFuncs()
        });

        facetCuts_[9] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(VAULT_REGISTRY_VAULT_QUERY_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: VAULT_REGISTRY_VAULT_QUERY_FACET.facetFuncs()
        });
    }

    function diamondConfig() public view returns (DiamondConfig memory config) {
        return IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    function updatePkg(
        address, // expectedProxy,
        bytes memory // pkgArgs
    )
        public
        virtual
        returns (bool)
    {
        return true;
    }

    function initAccount(bytes memory initArgs) public {
        (PkgArgs memory decodedArgs) = abi.decode(initArgs, (PkgArgs));
        MultiStepOwnableRepo._initialize(decodedArgs.owner, 3 days);
        Create3FactoryAwareRepo._initialize(decodedArgs.create3Factory);
        DiamondPackageFactoryAwareRepo._initialize(decodedArgs.diamondPackageFactory);
        VaultFeeOracleRepo.Storage storage feeLayout = VaultFeeOracleRepo._layout();
        VaultFeeOracleRepo._setFeeTo(feeLayout, decodedArgs.feeTo);
        VaultFeeOracleRepo._setDefaultVaultUsageFee(feeLayout, DEFAULT_VAULT_USAGE_FEE);
        VaultFeeOracleRepo._setDefaultBondTerms(
            feeLayout,
            BondTerms({
                minLockDuration: DEFAULT_BOND_MIN_TERM,
                maxLockDuration: DEFAULT_BOND_MAX_TERM,
                minBonusPercentage: DEFAULT_BOND_MIN_BONUS_PERCENTAGE,
                maxBonusPercentage: DEFAULT_BOND_MAX_BONUS_PERCENTAGE
            })
        );
        VaultFeeOracleRepo._setDefaultDexSwapFee(feeLayout, DEFAULT_DEX_FEE);
        VaultFeeOracleRepo._setDefaultSeigniorageIncentivePercentage(
            feeLayout, DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE
        );
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}

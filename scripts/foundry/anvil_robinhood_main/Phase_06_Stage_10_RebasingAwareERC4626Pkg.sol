// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";

/// @title Phase_06_Stage_10_RebasingAwareERC4626Pkg
/// @notice Enhanced rebasing-aware ERC4626 facets and registered package. No instance.
library Phase_06_Stage_10_RebasingAwareERC4626Pkg {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    /// @notice Code at a saved address is insufficient: require this build and these constructor dependencies.
    function isCurrent(LaunchState storage s) internal returns (bool) {
        if (!_matches(s, s.rebasingAwareErc4626Facet, "RebasingAwareERC4626Facet",
            ArtifactCreationCode.creationCode("RebasingAwareERC4626Facet.sol:RebasingAwareERC4626Facet"))) return false;
        if (!_matches(s, s.rebasingAwareSeFacet, "RebasingAwareStandardExchangeFacet",
            ArtifactCreationCode.creationCode("RebasingAwareStandardExchangeFacet.sol:RebasingAwareStandardExchangeFacet"))) return false;
        if (!_matches(s, s.rebasingAwareSyFacet, "RebasingAwareStandardYieldFacet",
            ArtifactCreationCode.creationCode("RebasingAwareStandardYieldFacet.sol:RebasingAwareStandardYieldFacet"))) return false;
        if (!_matches(s, s.rebasingAwareMetadataFacet, "RebasingAwareVaultMetadataFacet",
            ArtifactCreationCode.creationCode("RebasingAwareVaultMetadataFacet.sol:RebasingAwareVaultMetadataFacet"))) return false;
        if (!_matches(s, s.rebasingAwareQuoteFacet, "RebasingAwareStandardExchangeQuoteFacet",
            ArtifactCreationCode.creationCode("RebasingAwareStandardExchangeQuoteFacet.sol:RebasingAwareStandardExchangeQuoteFacet"))) return false;
        bytes memory code = ArtifactCreationCode.creationCode("RebasingAwareERC4626DFPkg.sol:RebasingAwareERC4626DFPkg");
        bytes memory args = abi.encode(_pkgInit(s));
        bytes32 salt = RebasingAwareERC4626_Component_FactoryService.releaseSalt("RebasingAwareERC4626DFPkg", code, args);
        if (s.rebasingAwareErc4626Pkg != Creation._create3AddressFromOf(address(s.create3Factory), salt)
            || s.rebasingAwareErc4626Pkg.code.length == 0) return false;
        if (s.rebasingAwareConstructorFingerprint != keccak256(args)
            || s.rebasingAwareImplFingerprint != _implementationFingerprint(s)) return false;
        if (keccak256(bytes(s.rebasingAwareReleaseId)) != keccak256("indexedex.rebasing-aware-erc4626.sy-se.v1")) return false;
        return IVaultRegistryVaultPackageQuery(address(s.indexedexManager)).isPackage(s.rebasingAwareErc4626Pkg);
    }

    function _matches(LaunchState storage s, IFacet facet, string memory name, bytes memory code)
        private view returns (bool)
    {
        bytes32 salt = RebasingAwareERC4626_Component_FactoryService.releaseSalt(name, code, "");
        return address(facet).code.length > 0
            && address(facet) == Creation._create3AddressFromOf(address(s.create3Factory), salt);
    }

    function execute(LaunchState storage s) internal {
        require(address(s.indexedexManager).code.length > 0, "Phase 06-10: indexedexManager");
        require(address(s.erc20Facet).code.length > 0, "Phase 06-10: erc20Facet");
        s.rebasingAwareErc4626Facet = s.create3Factory.deployRebasingAwareERC4626Facet();
        s.rebasingAwareSeFacet = s.create3Factory.deployRebasingAwareStandardExchangeFacet();
        s.rebasingAwareSyFacet = s.create3Factory.deployRebasingAwareStandardYieldFacet();
        s.rebasingAwareMetadataFacet = s.create3Factory.deployRebasingAwareVaultMetadataFacet();
        s.rebasingAwareQuoteFacet = s.create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        IRebasingAwareERC4626DFPkg.PkgInit memory pkgInit = _pkgInit(s);
        s.rebasingAwareErc4626Pkg = address(
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
                s.indexedexManager, pkgInit
            )
        );
        s.rebasingAwareReleaseId = IRebasingAwareERC4626DFPkg(s.rebasingAwareErc4626Pkg).releaseIdentifier();
        s.rebasingAwareConstructorFingerprint = keccak256(abi.encode(pkgInit));
        s.rebasingAwareImplFingerprint = _implementationFingerprint(s);
    }

    function _pkgInit(LaunchState storage s) private view returns (IRebasingAwareERC4626DFPkg.PkgInit memory) {
        return IRebasingAwareERC4626DFPkg.PkgInit({
            erc20Facet: s.erc20Facet,
            rebasingAwareErc4626Facet: s.rebasingAwareErc4626Facet,
            diamondFactory: s.diamondPackageFactory,
            standardExchangeFacet: s.rebasingAwareSeFacet,
            standardYieldFacet: s.rebasingAwareSyFacet,
            vaultMetadataFacet: s.rebasingAwareMetadataFacet,
            transitionQuoteFacet: s.rebasingAwareQuoteFacet,
            vaultRegistry: IVaultRegistryDeployment(address(s.indexedexManager))
        });
    }

    function _implementationFingerprint(LaunchState storage s) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                address(s.rebasingAwareErc4626Facet),
                address(s.rebasingAwareSeFacet),
                address(s.rebasingAwareSyFacet),
                address(s.rebasingAwareMetadataFacet),
                address(s.rebasingAwareQuoteFacet),
                s.rebasingAwareErc4626Pkg
            )
        );
    }
}

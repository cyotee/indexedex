// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchState} from "./LaunchState.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";

/// @title Phase_06_Stage_10_RebasingAwareERC4626Pkg
/// @notice Enhanced rebasing-aware ERC4626 facets and registered package. No instance.
library Phase_06_Stage_10_RebasingAwareERC4626Pkg {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    function execute(LaunchState storage s) internal {
        require(address(s.indexedexManager).code.length > 0, "Phase 06-10: indexedexManager");
        require(address(s.erc20Facet).code.length > 0, "Phase 06-10: erc20Facet");
        s.rebasingAwareErc4626Facet = s.create3Factory.deployRebasingAwareERC4626Facet();
        s.rebasingAwareSeFacet = s.create3Factory.deployRebasingAwareStandardExchangeFacet();
        s.rebasingAwareSyFacet = s.create3Factory.deployRebasingAwareStandardYieldFacet();
        s.rebasingAwareMetadataFacet = s.create3Factory.deployRebasingAwareVaultMetadataFacet();
        s.rebasingAwareQuoteFacet = s.create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        IRebasingAwareERC4626DFPkg.PkgInit memory pkgInit = IRebasingAwareERC4626DFPkg.PkgInit({
            erc20Facet: s.erc20Facet,
            rebasingAwareErc4626Facet: s.rebasingAwareErc4626Facet,
            diamondFactory: s.diamondPackageFactory,
            standardExchangeFacet: s.rebasingAwareSeFacet,
            standardYieldFacet: s.rebasingAwareSyFacet,
            vaultMetadataFacet: s.rebasingAwareMetadataFacet,
            transitionQuoteFacet: s.rebasingAwareQuoteFacet,
            vaultRegistry: IVaultRegistryDeployment(address(s.indexedexManager))
        });
        s.rebasingAwareErc4626Pkg = address(
            RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
                s.indexedexManager, pkgInit
            )
        );
        s.rebasingAwareReleaseId = IRebasingAwareERC4626DFPkg(s.rebasingAwareErc4626Pkg).releaseIdentifier();
        s.rebasingAwareConstructorFingerprint = keccak256(abi.encode(pkgInit));
        s.rebasingAwareImplFingerprint = keccak256(
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

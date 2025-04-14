// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {Vm as FoundryVM} from "forge-std/Vm.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {FeeCollectorManagerFacet} from "contracts/fee/collector/FeeCollectorManagerFacet.sol";
import {FeeCollectorSingleTokenPushFacet} from "contracts/fee/collector/FeeCollectorSingleTokenPushFacet.sol";
import {IFeeCollectorDFPkg, FeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";

// tag::FeeCollectorFactoryService[]
/**
 * @title FeeCollectorFactoryService - Library for deploying Fee Collector components and instances.
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Deployments done using CREATE3.
 * @notice Deployed addresses will be consistent across chains for the same Create3 factory.
 */
library FeeCollectorFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    FoundryVM constant HEVM = FoundryVM(VM_ADDRESS);

    // tag::deployFeeCollectorManagerFacet(address)[]
    /**
     * @notice Deploys the FeeCollectorManagerFacet.
     * @param factory The Create3Factory to use for deployment.
     * @return facet The deployed FeeCollectorManagerFacet.
     */
    function deployFeeCollectorManagerFacet(ICreate3FactoryProxy factory)
        internal
        returns (IFacet facet)
    {
        facet = factory.deployFacet(
            type(FeeCollectorManagerFacet).creationCode, abi.encode(type(FeeCollectorManagerFacet).name)._hash()
        );
        HEVM.label(address(facet), type(FeeCollectorManagerFacet).name);
    }

    // end::deployFeeCollectorManagerFacet(address)[]

    // tag::deployFeeCollectorSingleTokenPushFacet(address)[]
    /**
     * @notice Deploys the FeeCollectorSingleTokenPushFacet.
     * @param factory The Create3Factory to use for deployment.
     * @return facet The deployed FeeCollectorSingleTokenPushFacet.
     */
    function deployFeeCollectorSingleTokenPushFacet(ICreate3FactoryProxy factory)
        internal
        returns (IFacet facet)
    {
        facet = factory.deployFacet(
            type(FeeCollectorSingleTokenPushFacet).creationCode,
            abi.encode(type(FeeCollectorSingleTokenPushFacet).name)._hash()
        );
        HEVM.label(address(facet), type(FeeCollectorSingleTokenPushFacet).name);
    }

    // end::deployFeeCollectorSingleTokenPushFacet(address)[]

    // tag::deployFeeCollectorDFPkg(address_address_address_address_address)[]
    /**
     * @notice Deploys the FeeCollectorDFPkg.
     * @param factory The Create3Factory to use for deployment.
     * @param diamondCutFacet The DiamondCut facet to include in the package.
     * @param multiStepOwnableFacet The MultiStepOwnable facet to include in the package.
     * @param feeCollectorSingleTokenPushFacet The FeeCollectorSingleTokenPush facet to include in the package.
     * @param feeCollectorManagerFacet The FeeCollectorManager facet to include in the package.
     * @return dfpkg The deployed FeeCollectorDFPkg.
     */
    function deployFeeCollectorDFPkg(
        ICreate3FactoryProxy factory,
        IFacet diamondCutFacet,
        IFacet multiStepOwnableFacet,
        IFacet feeCollectorSingleTokenPushFacet,
        IFacet feeCollectorManagerFacet
    ) internal returns (IFeeCollectorDFPkg dfpkg) {
        IFeeCollectorDFPkg.PkgInit memory pkgInitArgs = IFeeCollectorDFPkg.PkgInit({
            diamondCutFacet: diamondCutFacet,
            multiStepOwnableFacet: multiStepOwnableFacet,
            feeCollectorSingleTokenPushFacet: feeCollectorSingleTokenPushFacet,
            feeCollectorManagerFacet: feeCollectorManagerFacet
        });

        dfpkg = IFeeCollectorDFPkg(
            address(
                factory.deployPackageWithArgs(
                    type(FeeCollectorDFPkg).creationCode,
                    abi.encode(pkgInitArgs),
                    abi.encode(type(FeeCollectorDFPkg).name, pkgInitArgs)._hash()
                )
            )
        );
        HEVM.label(address(dfpkg), type(FeeCollectorDFPkg).name);
    }

    // end::deployFeeCollectorDFPkg(address_address_address_address_address)[]

    // tag::deployFeeCollector(address_address_address)[]
    /**
     * @notice Deploys a FeeCollectorProxy diamond using the provided DFPkg.
     * @param diamondFactory The DiamondPackageCallBackFactory to use for deployment.
     * @param feeCollectorDFPkg The FeeCollectorDFPkg to use for deployment.
     * @param owner The owner of the deployed FeeCollectorProxy.
     */
    function deployFeeCollector(
        IDiamondPackageCallBackFactory diamondFactory,
        IFeeCollectorDFPkg feeCollectorDFPkg,
        address owner
    ) internal returns (IFeeCollectorProxy feeCollector) {
        IFeeCollectorDFPkg.PkgArgs memory pkgArgs = IFeeCollectorDFPkg.PkgArgs({owner: owner});

        feeCollector = IFeeCollectorProxy(diamondFactory.deploy(feeCollectorDFPkg, abi.encode(pkgArgs)));
        HEVM.label(address(feeCollector), "FeeCollectorProxy");
    }
    // end::deployFeeCollector(address_address_address)[]
}
// end::FeeCollectorFactoryService[]

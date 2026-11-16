// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {LaunchState} from "./LaunchState.sol";

import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {ICreate3Factory} from "@crane/contracts/interfaces/ICreate3Factory.sol";
import {IDiamondFactoryPackageRegistry} from "@crane/contracts/registries/package/IDiamondFactoryPackageRegistry.sol";
import {ICallTargetRegistryQuery} from "@crane/contracts/interfaces/ICallTargetRegistryQuery.sol";
import {ICallTargetRegistryManagement} from "@crane/contracts/interfaces/ICallTargetRegistryManagement.sol";
import {Create3Factory} from "@crane/contracts/factories/create3/Create3Factory.sol";
import {ICREATE3DFPkg} from "@crane/contracts/factories/create3/Create3FactoryDFPkg.sol";
import {ICallTargetRegistryDFPkg} from "@crane/contracts/registries/target/CallTargetRegistryDFPkg.sol";
import {IBountyBoardDFPkg} from "@crane/contracts/bounties/BountyBoardDFPkg.sol";
import {IBountyCommon} from "@crane/contracts/bounties/common/IBountyCommon.sol";
import {ISingleFinalBounty} from "@crane/contracts/bounties/single/ISingleFinalBounty.sol";
import {IMilestoneBounty} from "@crane/contracts/bounties/milestone/IMilestoneBounty.sol";
import {IContestBounty} from "@crane/contracts/bounties/contest/IContestBounty.sol";
import {IContinuousBounty} from "@crane/contracts/bounties/continuous/IContinuousBounty.sol";
import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";

/// @title Phase_02_Stage_02_DiamondPackageFactory
/// @notice Diamond Package Factory via CREATE3, plus remaining InitDevService.initEnv DFPkgs.
library Phase_02_Stage_02_DiamondPackageFactory {
    Vm internal constant vm = Vm(VM_ADDRESS);

    bytes32 internal constant CREATE3_FACTORY_PACKAGE_SALT = keccak256(abi.encode("Create3FactoryDFPkg"));
    bytes32 internal constant CALL_TARGET_REGISTRY_PACKAGE_SALT =
        keccak256(abi.encode("CallTargetRegistryDFPkg"));
    bytes32 internal constant BOUNTY_BOARD_PACKAGE_SALT = keccak256(abi.encode("BountyBoardDFPkg"));

    function execute(LaunchState storage s) internal {
        ICreate3FactoryProxy factory = s.create3Factory;
        IDiamondPackageCallBackFactory diamondFactory = InitDevService.initDiamondFactory(factory);
        s.diamondPackageFactory = diamondFactory;

        IDiamondFactoryPackage create3DFPkg_ = IDiamondFactoryPackage(
            factory.deployCanonicalPackageWithArgs(
                ArtifactCreationCode.creationCode(s.create3Factory, "Create3FactoryDFPkg.sol:Create3FactoryDFPkg"),
                abi.encode(
                    ICREATE3DFPkg.PkgInit({
                        diamondCutFacet: IFacetRegistry(address(factory)).canonicalFacet(type(IDiamondCut).interfaceId),
                        multiStepOwnableFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IMultiStepOwnable).interfaceId),
                        operableFacet: IFacetRegistry(address(factory)).canonicalFacet(type(IOperable).interfaceId),
                        create3FactoryFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ICreate3Factory).interfaceId),
                        facetRegistryFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IFacetRegistry).interfaceId),
                        packageRegistryFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IDiamondFactoryPackageRegistry).interfaceId),
                        callTargetRegistryQueryFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ICallTargetRegistryQuery).interfaceId),
                        callTargetRegistryManagementFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ICallTargetRegistryManagement).interfaceId),
                        diamondFactory: diamondFactory
                    })
                ),
                CREATE3_FACTORY_PACKAGE_SALT,
                type(ICREATE3DFPkg).interfaceId
            )
        );
        vm.label(address(create3DFPkg_), "Create3FactoryDFPkg");
        Create3Factory(payable(address(factory))).initFactory();

        IDiamondFactoryPackage callTargetRegistryDFPkg_ = IDiamondFactoryPackage(
            factory.deployCanonicalPackageWithArgs(
                ArtifactCreationCode.creationCode(s.create3Factory, "CallTargetRegistryDFPkg.sol:CallTargetRegistryDFPkg"),
                abi.encode(
                    ICallTargetRegistryDFPkg.PkgInit({
                        diamondCutFacet: IFacetRegistry(address(factory)).canonicalFacet(type(IDiamondCut).interfaceId),
                        multiStepOwnableFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IMultiStepOwnable).interfaceId),
                        callTargetRegistryQueryFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ICallTargetRegistryQuery).interfaceId),
                        callTargetRegistryManagementFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ICallTargetRegistryManagement).interfaceId),
                        diamondFactory: diamondFactory
                    })
                ),
                CALL_TARGET_REGISTRY_PACKAGE_SALT,
                type(ICallTargetRegistryDFPkg).interfaceId
            )
        );
        vm.label(address(callTargetRegistryDFPkg_), "CallTargetRegistryDFPkg");

        IDiamondFactoryPackage bountyBoardDFPkg_ = IDiamondFactoryPackage(
            factory.deployCanonicalPackageWithArgs(
                ArtifactCreationCode.creationCode(s.create3Factory, "BountyBoardDFPkg.sol:BountyBoardDFPkg"),
                abi.encode(
                    IBountyBoardDFPkg.PkgInit({
                        diamondCutFacet: IFacetRegistry(address(factory)).canonicalFacet(type(IDiamondCut).interfaceId),
                        multiStepOwnableFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IMultiStepOwnable).interfaceId),
                        bountyCommonFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IBountyCommon).interfaceId),
                        singleFinalBountyFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(ISingleFinalBounty).interfaceId),
                        milestoneBountyFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IMilestoneBounty).interfaceId),
                        contestBountyFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IContestBounty).interfaceId),
                        continuousBountyFacet: IFacetRegistry(address(factory))
                            .canonicalFacet(type(IContinuousBounty).interfaceId),
                        diamondFactory: diamondFactory
                    })
                ),
                BOUNTY_BOARD_PACKAGE_SALT,
                type(IBountyBoardDFPkg).interfaceId
            )
        );
        vm.label(address(bountyBoardDFPkg_), "BountyBoardDFPkg");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";

// tag::IFeeCollectorDFPkg[]
/**
 * @title IFeeCollectorDFPkg - Package initialziation and argument structs.
 * @author cyotee doge <not_cyotee@proton.me>
 */
interface IFeeCollectorDFPkg is IDiamondFactoryPackage {
    struct PkgInit {
        IFacet diamondCutFacet;
        IFacet multiStepOwnableFacet;
        IFacet feeCollectorSingleTokenPushFacet;
        IFacet feeCollectorManagerFacet;
    }

    struct PkgArgs {
        address owner;
    }
}

// end::IFeeCollectorDFPkg[]

// tag::FeeCollectorDFPkg[]
/**
 * @title FeeCollectorDFPkg - Diamond Factory Package for Fee Collector contracts.
 * @author cyotee doge <not_cyotee@proton.me>
 */
contract FeeCollectorDFPkg is IFeeCollectorDFPkg {
    using BetterEfficientHashLib for bytes;

    IFacet immutable DIAMOND_CUT_FACET;
    IFacet immutable MULTI_STEP_OWNABLE_FACET;
    IFacet immutable FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET;
    IFacet immutable FEE_COLLECTOR_MANAGER_FACET;

    constructor(PkgInit memory pkgInitArgs) {
        DIAMOND_CUT_FACET = pkgInitArgs.diamondCutFacet;
        MULTI_STEP_OWNABLE_FACET = pkgInitArgs.multiStepOwnableFacet;
        FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET = pkgInitArgs.feeCollectorSingleTokenPushFacet;
        FEE_COLLECTOR_MANAGER_FACET = pkgInitArgs.feeCollectorManagerFacet;
    }

    // tag::packageName()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function packageName() public pure returns (string memory name_) {
        return type(FeeCollectorDFPkg).name;
    }

    // end::packageName()[]

    // tag::facetInterfaces()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](4);
        interfaces[0] = type(IDiamondCut).interfaceId;
        interfaces[1] = type(IMultiStepOwnable).interfaceId;
        interfaces[2] = type(IFeeCollectorSingleTokenPush).interfaceId;
        interfaces[3] = type(IFeeCollectorManager).interfaceId;
        return interfaces;
    }

    // tag::facetInterfaces()[]

    // tag::facetAddresses()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](4);
        facetAddresses_[0] = address(DIAMOND_CUT_FACET);
        facetAddresses_[1] = address(MULTI_STEP_OWNABLE_FACET);
        facetAddresses_[2] = address(FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET);
        facetAddresses_[3] = address(FEE_COLLECTOR_MANAGER_FACET);
    }

    // end::facetAddresses()[]

    // tag::packageMetadata()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function packageMetadata()
        public
        view
        returns (string memory name_, bytes4[] memory interfaces, address[] memory facets)
    {
        name_ = packageName();
        interfaces = facetInterfaces();
        facets = facetAddresses();
    }

    // end::packageMetadata()[

    // tag::facetCuts()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function facetCuts() public view returns (IDiamond.FacetCut[] memory facetCuts_) {
        facetCuts_ = new IDiamond.FacetCut[](4);

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
            facetAddress: address(FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: FEE_COLLECTOR_SINGLE_TOKEN_PUSH_FACET.facetFuncs()
        });

        facetCuts_[3] = IDiamond.FacetCut({
            // address facetAddress;
            facetAddress: address(FEE_COLLECTOR_MANAGER_FACET),
            // FacetCutAction action;
            action: IDiamond.FacetCutAction.Add,
            // bytes4[] functionSelectors;
            functionSelectors: FEE_COLLECTOR_MANAGER_FACET.facetFuncs()
        });
    }

    // end::facetCuts()[]

    // tag::diamondConfig()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function diamondConfig() public view returns (DiamondConfig memory config) {
        return IDiamondFactoryPackage.DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    // end::diamondConfig()[]

    // tag::calcSalt()[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) {
        return abi.encode(pkgArgs)._hash();
    }

    // end::calcSalt()[]

    // tag::processArgs(bytes)[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }

    // end::processArgs(bytes)[]

    // tag::updatePkg(addreess,bytes)[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
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

    // end::updatePkg(addreess,bytes)[]

    // tag::initAccount(bytes)[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function initAccount(bytes memory initArgs) public {
        (PkgArgs memory decodedArgs) = abi.decode(initArgs, (PkgArgs));
        MultiStepOwnableRepo._initialize(decodedArgs.owner, 3 days);
    }

    // end::initAccount(bytes)[]

    // tag::postDeploy(address)[]
    /**
     * @inheritdoc IDiamondFactoryPackage
     */
    function postDeploy(address) public pure returns (bool) {
        return true;
    }
    // end::postDeploy(address)[]
}
// end::FeeCollectorDFPkg[]

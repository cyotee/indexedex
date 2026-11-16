// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";

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

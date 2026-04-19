// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {BaseProtocolDETFExchangeInFacet} from "contracts/vaults/protocol/BaseProtocolDETFExchangeInFacet.sol";
import {BaseProtocolDETFExchangeInQueryFacet} from "contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryFacet.sol";
import {BaseProtocolDETFExchangeOutFacet} from "contracts/vaults/protocol/BaseProtocolDETFExchangeOutFacet.sol";
import {BaseProtocolDETFBondingFacet} from "contracts/vaults/protocol/BaseProtocolDETFBondingFacet.sol";
import {BaseProtocolDETFBridgeFacet} from "contracts/vaults/protocol/BaseProtocolDETFBridgeFacet.sol";
import {BaseProtocolDETFBondingQueryFacet} from "contracts/vaults/protocol/BaseProtocolDETFBondingQueryFacet.sol";
import {BaseProtocolDETFRichirRedeemFacet} from "contracts/vaults/protocol/BaseProtocolDETFRichirRedeemFacet.sol";
import {ProtocolNFTVaultFacet} from "contracts/vaults/protocol/ProtocolNFTVaultFacet.sol";
import {RICHIRFacet} from "contracts/vaults/protocol/RICHIRFacet.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";

/**
 * @title BaseProtocolDETF_Facet_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Protocol DETF facets via CREATE3.
 * @dev Separated from package deployment to avoid stack-too-deep.
 */
library BaseProtocolDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBaseProtocolDETFExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFExchangeInFacet).creationCode, abi.encode(type(BaseProtocolDETFExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFExchangeInFacet).name);
    }

    function deployBaseProtocolDETFExchangeInQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFExchangeInQueryFacet).creationCode,
            abi.encode(type(BaseProtocolDETFExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFExchangeInQueryFacet).name);
    }

    function deployBaseProtocolDETFExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFExchangeOutFacet).creationCode, abi.encode(type(BaseProtocolDETFExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFExchangeOutFacet).name);
    }

    function deployBaseProtocolDETFBondingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFBondingFacet).creationCode, abi.encode(type(BaseProtocolDETFBondingFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFBondingFacet).name);
    }

    function deployBaseProtocolDETFBridgeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFBridgeFacet).creationCode, abi.encode(type(BaseProtocolDETFBridgeFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFBridgeFacet).name);
    }

    function deployBaseProtocolDETFBondingQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFBondingQueryFacet).creationCode,
            abi.encode(type(BaseProtocolDETFBondingQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFBondingQueryFacet).name);
    }

    function deployBaseProtocolDETFRichirRedeemFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseProtocolDETFRichirRedeemFacet).creationCode,
            abi.encode(type(BaseProtocolDETFRichirRedeemFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseProtocolDETFRichirRedeemFacet).name);
    }

    function deployProtocolNFTVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ProtocolNFTVaultFacet).creationCode, abi.encode(type(ProtocolNFTVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ProtocolNFTVaultFacet).name);
    }

    function deployRICHIRFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(RICHIRFacet).creationCode, abi.encode(type(RICHIRFacet).name)._hash());
        vm.label(address(instance), type(RICHIRFacet).name);
    }

    function deployERC4626BasedBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626BasedBasicVaultFacet).creationCode, abi.encode(type(ERC4626BasedBasicVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626BasedBasicVaultFacet).name);
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626StandardVaultFacet).creationCode, abi.encode(type(ERC4626StandardVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626StandardVaultFacet).name);
    }
}

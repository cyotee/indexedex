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

import {BaseDualSelfCommonDETFExchangeInFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeInFacet.sol";
import {BaseDualSelfCommonDETFExchangeInQueryFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeInQueryFacet.sol";
import {BaseDualSelfCommonDETFExchangeOutFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFExchangeOutFacet.sol";
import {BaseDualSelfCommonDETFBondingFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBondingFacet.sol";
import {BaseDualSelfCommonDETFBridgeFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBridgeFacet.sol";
import {BaseDualSelfCommonDETFBondingQueryFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFBondingQueryFacet.sol";
import {BaseDualSelfCommonDETFRichirRedeemFacet} from "contracts/vaults/protocol/BaseDualSelfCommonDETFRichirRedeemFacet.sol";
import {ProtocolNFTVaultFacet} from "contracts/vaults/protocol/ProtocolNFTVaultFacet.sol";
import {RICHIRFacet} from "contracts/vaults/protocol/RICHIRFacet.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";

/**
 * @title BaseDualSelfCommonDETF_Facet_FactoryService
 * @author cyotee doge <not_cyotee@proton.me>
 * @notice Factory service for deploying Protocol DETF facets via CREATE3.
 * @dev Separated from package deployment to avoid stack-too-deep.
 */
library BaseDualSelfCommonDETF_Facet_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    /* ---------------------------------------------------------------------- */
    /*                              Facet Deployment                          */
    /* ---------------------------------------------------------------------- */

    function deployBaseDualSelfCommonDETFExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFExchangeInFacet).creationCode, abi.encode(type(BaseDualSelfCommonDETFExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFExchangeInFacet).name);
    }

    function deployBaseDualSelfCommonDETFExchangeInQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFExchangeInQueryFacet).creationCode,
            abi.encode(type(BaseDualSelfCommonDETFExchangeInQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFExchangeInQueryFacet).name);
    }

    function deployBaseDualSelfCommonDETFExchangeOutFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFExchangeOutFacet).creationCode, abi.encode(type(BaseDualSelfCommonDETFExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFExchangeOutFacet).name);
    }

    function deployBaseDualSelfCommonDETFBondingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFBondingFacet).creationCode, abi.encode(type(BaseDualSelfCommonDETFBondingFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFBondingFacet).name);
    }

    function deployBaseDualSelfCommonDETFBridgeFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFBridgeFacet).creationCode, abi.encode(type(BaseDualSelfCommonDETFBridgeFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFBridgeFacet).name);
    }

    function deployBaseDualSelfCommonDETFBondingQueryFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFBondingQueryFacet).creationCode,
            abi.encode(type(BaseDualSelfCommonDETFBondingQueryFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFBondingQueryFacet).name);
    }

    function deployBaseDualSelfCommonDETFRichirRedeemFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(BaseDualSelfCommonDETFRichirRedeemFacet).creationCode,
            abi.encode(type(BaseDualSelfCommonDETFRichirRedeemFacet).name)._hash()
        );
        vm.label(address(instance), type(BaseDualSelfCommonDETFRichirRedeemFacet).name);
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

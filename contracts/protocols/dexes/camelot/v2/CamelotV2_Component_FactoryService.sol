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
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICamelotV2Router} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotV2Router.sol";
import {ICamelotFactory} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    CamelotV2StandardExchangeInFacet
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeInFacet.sol";
import {
    CamelotV2StandardExchangeOutFacet
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutFacet.sol";
import {
    ICamelotV2StandardExchangeDFPkg,
    CamelotV2StandardExchangeDFPkg
} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";

library CamelotV2_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployCamelotV2StandardExchangeInFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(CamelotV2StandardExchangeInFacet).creationCode,
            abi.encode(type(CamelotV2StandardExchangeInFacet).name)._hash()
        );
        vm.label(address(instance), type(CamelotV2StandardExchangeInFacet).name);
    }

    function deployCamelotV2StandardExchangeOutFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(CamelotV2StandardExchangeOutFacet).creationCode,
            abi.encode(type(CamelotV2StandardExchangeOutFacet).name)._hash()
        );
        vm.label(address(instance), type(CamelotV2StandardExchangeOutFacet).name);
    }

    function deployCamelotV2StandardExchangeDFPkg(
        IVaultRegistryDeployment vaultRegistry,
        ICamelotV2StandardExchangeDFPkg.PkgInit memory pkgInit
    ) internal returns (ICamelotV2StandardExchangeDFPkg instance) {
        instance = ICamelotV2StandardExchangeDFPkg(
            address(
                vaultRegistry.deployPkg(
                    type(CamelotV2StandardExchangeDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(CamelotV2StandardExchangeDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(CamelotV2StandardExchangeDFPkg).name);
    }
}

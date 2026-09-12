// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

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

import {ICamelotV2StandardExchangeDFPkg} from "contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol";

library CamelotV2_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function _deployFacet(ICreate3FactoryProxy factory_, string memory name_) private returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode(string.concat(name_, ".sol:", name_));
        instance = factory_.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode(name_)._hash(), code, ""));
        vm.label(address(instance), name_);
    }

    function deployCamelotV2StandardExchangeInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeInFacet");
    }

    function deployCamelotV2StandardExchangeOutFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeOutFacet");
    }

    function deployCamelotV2StandardExchangeQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeQueryFacet");
    }

    function deployCamelotV2StandardExchangeDFPkg(
        IVaultRegistryDeployment registry_, ICamelotV2StandardExchangeDFPkg.PkgInit memory init_
    ) internal returns (ICamelotV2StandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("CamelotV2StandardExchangeDFPkg.sol:CamelotV2StandardExchangeDFPkg");
        bytes memory args = abi.encode(init_);
        instance = ICamelotV2StandardExchangeDFPkg(address(registry_.deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("CamelotV2StandardExchangeDFPkg")._hash(), code, args)
        )));
        vm.label(address(instance), "CamelotV2StandardExchangeDFPkg");
    }
}

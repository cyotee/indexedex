// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";

library TokenStaking_Component_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployTokenStakingFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("TokenStakingFacet.sol:TokenStakingFacet"),
            abi.encode("TokenStakingFacet")._hash()
        );
        vm.label(address(instance), "TokenStakingFacet");
    }

    function deployRebasingAwareERC4626Facet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        return RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626Facet(create3Factory);
    }

    function deployRebasingAwareERC4626DFPkg(
        IIndexedexManagerProxy indexedexManager,
        IRebasingAwareERC4626DFPkg.PkgInit memory pkgInit
    ) internal returns (IRebasingAwareERC4626DFPkg instance) {
        return RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(
            indexedexManager, pkgInit
        );
    }

    function deployTokenStakingDFPkg(ICreate3FactoryProxy create3Factory, ITokenStakingDFPkg.PkgInit memory pkgInit)
        internal
        returns (ITokenStakingDFPkg instance)
    {
        instance = ITokenStakingDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode("TokenStakingDFPkg.sol:TokenStakingDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("TokenStakingDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "TokenStakingDFPkg");
    }
}

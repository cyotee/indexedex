// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
// Explicit dependencies keep factory-loaded bytecode available in focused builds.
import {UniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

library UniswapV4Detf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4DetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4DetfDFPkg instance_) {
        bytes memory initCode_ = ArtifactCreationCode.creationCode("UniswapV4DetfDFPkg.sol:UniswapV4DetfDFPkg");
        bytes memory initArgs_ = abi.encode(pkgInit_);
        instance_ = IUniswapV4DetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    initCode_,
                    initArgs_,
                    ArtifactCreationCode.releaseSalt(abi.encode("UniswapV4DetfDFPkg")._hash(), initCode_, initArgs_)
                )
            )
        );
        vm.label(address(instance_), "UniswapV4DetfDFPkg");
    }
}

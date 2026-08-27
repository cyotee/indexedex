// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";

library UniswapV4Detf_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4DetfDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4DetfDFPkg instance_) {
        instance_ = IUniswapV4DetfDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4DetfDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4DetfDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4DetfDFPkg).name);
    }
}

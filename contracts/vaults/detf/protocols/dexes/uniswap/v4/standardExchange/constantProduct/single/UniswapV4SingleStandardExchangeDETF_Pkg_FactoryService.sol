// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETDFPkg.sol";

library UniswapV4SingleStandardExchangeDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4SingleStandardExchangeDETDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4SingleStandardExchangeDETDFPkg instance_) {
        instance_ = IUniswapV4SingleStandardExchangeDETDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4SingleStandardExchangeDETDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4SingleStandardExchangeDETDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4SingleStandardExchangeDETDFPkg).name);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETDFPkg.sol";

library UniswapV4StandardExchangeOrbitalDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeOrbitalDETDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeOrbitalDETDFPkg instance_) {
        instance_ = IUniswapV4StandardExchangeOrbitalDETDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4StandardExchangeOrbitalDETDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4StandardExchangeOrbitalDETDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4StandardExchangeOrbitalDETDFPkg).name);
    }
}

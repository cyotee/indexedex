// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETDFPkg.sol";

library UniswapV4StandardExchangeWeightedDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeWeightedDETDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeWeightedDETDFPkg instance_) {
        instance_ = IUniswapV4StandardExchangeWeightedDETDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4StandardExchangeWeightedDETDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4StandardExchangeWeightedDETDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4StandardExchangeWeightedDETDFPkg).name);
    }
}

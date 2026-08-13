// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol";

library UniswapV4StandardExchangeCurveQuadStableDETF_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4StandardExchangeCurveQuadStableDETDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg instance_) {
        instance_ = IUniswapV4StandardExchangeCurveQuadStableDETDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4StandardExchangeCurveQuadStableDETDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4StandardExchangeCurveQuadStableDETDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4StandardExchangeCurveQuadStableDETDFPkg).name);
    }
}

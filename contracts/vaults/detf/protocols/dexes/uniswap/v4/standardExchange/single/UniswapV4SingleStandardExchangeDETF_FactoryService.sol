// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    UniswapV4SingleStandardExchangeDETFFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFFacet.sol";
import {
    IUniswapV4SingleStandardExchangeDETFDFPkg,
    UniswapV4SingleStandardExchangeDETFDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeDETFDFPkg.sol";

library UniswapV4SingleStandardExchangeDETF_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4SingleStandardExchangeDETFFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4SingleStandardExchangeDETFFacet).creationCode,
            abi.encode(type(UniswapV4SingleStandardExchangeDETFFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4SingleStandardExchangeDETFFacet).name);
    }

    function deployUniswapV4SingleStandardExchangeDETFDFPkg(
        IVaultRegistryDeployment vaultRegistry_,
        IUniswapV4SingleStandardExchangeDETFDFPkg.PkgInit memory pkgInit_
    ) internal returns (IUniswapV4SingleStandardExchangeDETFDFPkg instance_) {
        instance_ = IUniswapV4SingleStandardExchangeDETFDFPkg(
            address(
                vaultRegistry_.deployPkg(
                    type(UniswapV4SingleStandardExchangeDETFDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(UniswapV4SingleStandardExchangeDETFDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(UniswapV4SingleStandardExchangeDETFDFPkg).name);
    }
}

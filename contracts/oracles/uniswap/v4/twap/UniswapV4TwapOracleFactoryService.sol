// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniswapV4MultiPoolTwapOracleFacet
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleFacet.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4TwapAdapterFactory
} from "contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol";

library UniswapV4TwapOracleFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4MultiPoolTwapOracleFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniswapV4MultiPoolTwapOracleFacet).creationCode,
            abi.encode(type(UniswapV4MultiPoolTwapOracleFacet).name)._hash()
        );
        vm.label(address(instance), type(UniswapV4MultiPoolTwapOracleFacet).name);
    }

    function deployUniswapV4MultiPoolTwapOracleDFPkg(
        ICreate3FactoryProxy create3Factory,
        IFacet twapOracleFacet,
        IDiamondPackageCallBackFactory diamondFactory
    ) internal returns (IUniswapV4MultiPoolTwapOracleDFPkg instance) {
        IUniswapV4MultiPoolTwapOracleDFPkg.PkgInit memory pkgInit = IUniswapV4MultiPoolTwapOracleDFPkg.PkgInit({
            twapOracleFacet: twapOracleFacet, diamondFactory: diamondFactory
        });
        instance = IUniswapV4MultiPoolTwapOracleDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(UniswapV4MultiPoolTwapOracleDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniswapV4MultiPoolTwapOracleDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniswapV4MultiPoolTwapOracleDFPkg).name);
    }

    function deployUniswapV4TwapAdapterFactory(ICreate3FactoryProxy create3Factory)
        internal
        returns (UniswapV4TwapAdapterFactory instance)
    {
        instance = UniswapV4TwapAdapterFactory(
            create3Factory.create3(
                type(UniswapV4TwapAdapterFactory).creationCode,
                abi.encode(type(UniswapV4TwapAdapterFactory).name)._hash()
            )
        );
        vm.label(address(instance), type(UniswapV4TwapAdapterFactory).name);
    }
}

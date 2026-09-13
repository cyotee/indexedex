// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IUniswapV4MultiPoolTwapOracleDFPkg} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {IUniswapV4TwapAdapterFactory} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4TwapAdapterFactory.sol";

library UniswapV4TwapOracleFactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniswapV4MultiPoolTwapOracleFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("UniswapV4MultiPoolTwapOracleFacet.sol:UniswapV4MultiPoolTwapOracleFacet"),
            abi.encode("UniswapV4MultiPoolTwapOracleFacet")._hash()
        );
        vm.label(address(instance), "UniswapV4MultiPoolTwapOracleFacet");
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
                    ArtifactCreationCode.creationCode("UniswapV4MultiPoolTwapOracleDFPkg.sol:UniswapV4MultiPoolTwapOracleDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("UniswapV4MultiPoolTwapOracleDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "UniswapV4MultiPoolTwapOracleDFPkg");
    }

    function deployUniswapV4TwapAdapterFactory(ICreate3FactoryProxy create3Factory)
        internal
        returns (IUniswapV4TwapAdapterFactory instance)
    {
        instance = IUniswapV4TwapAdapterFactory(
            create3Factory.create3(
                ArtifactCreationCode.creationCode("UniswapV4TwapAdapterFactory.sol:UniswapV4TwapAdapterFactory"),
                abi.encode("UniswapV4TwapAdapterFactory")._hash()
            )
        );
        vm.label(address(instance), "UniswapV4TwapAdapterFactory");
    }
}

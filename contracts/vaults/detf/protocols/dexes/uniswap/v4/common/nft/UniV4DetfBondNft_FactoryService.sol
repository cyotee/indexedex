// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniV4DetfBondNftFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftFacet.sol";
import {
    IUniV4DetfBondNftDFPkg,
    UniV4DetfBondNftDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/UniV4DetfBondNftDFPkg.sol";

library UniV4DetfBondNft_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniV4DetfBondNftFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(UniV4DetfBondNftFacet).creationCode, abi.encode(type(UniV4DetfBondNftFacet).name)._hash()
        );
        vm.label(address(instance), type(UniV4DetfBondNftFacet).name);
    }

    function deployUniV4DetfBondNftDFPkg(
        ICreate3FactoryProxy create3Factory,
        IUniV4DetfBondNftDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniV4DetfBondNftDFPkg instance) {
        instance = IUniV4DetfBondNftDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(UniV4DetfBondNftDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniV4DetfBondNftDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniV4DetfBondNftDFPkg).name);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {
    UniV4DetfRebasingClaimFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimFacet.sol";
import {
    IUniV4DetfRebasingClaimDFPkg,
    UniV4DetfRebasingClaimDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol";

/// @notice Pure Crane factory helpers for rebasing claim facet + DFPkg (not vault registry).
library UniV4DetfRebasingClaim_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployUniV4DetfRebasingClaimFacet(ICreate3FactoryProxy create3Factory)
        internal
        returns (IFacet instance)
    {
        instance = create3Factory.deployFacet(
            type(UniV4DetfRebasingClaimFacet).creationCode,
            abi.encode(type(UniV4DetfRebasingClaimFacet).name)._hash()
        );
        vm.label(address(instance), type(UniV4DetfRebasingClaimFacet).name);
    }

    function deployUniV4DetfRebasingClaimDFPkg(
        ICreate3FactoryProxy create3Factory,
        IUniV4DetfRebasingClaimDFPkg.PkgInit memory pkgInit
    ) internal returns (IUniV4DetfRebasingClaimDFPkg instance) {
        instance = IUniV4DetfRebasingClaimDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(UniV4DetfRebasingClaimDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(UniV4DetfRebasingClaimDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(UniV4DetfRebasingClaimDFPkg).name);
    }
}

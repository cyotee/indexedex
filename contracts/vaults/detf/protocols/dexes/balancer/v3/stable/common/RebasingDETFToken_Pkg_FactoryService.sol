// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {VM_ADDRESS} from '@crane/contracts/constants/FoundryConstants.sol';
import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {BetterEfficientHashLib} from '@crane/contracts/utils/BetterEfficientHashLib.sol';

import {
    IRebasingDETFTokenDFPkg,
    RebasingDETFTokenDFPkg
} from 'contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenDFPkg.sol';

library RebasingDETFToken_Pkg_FactoryService {
    using BetterEfficientHashLib for bytes;

    Vm constant vm = Vm(VM_ADDRESS);

    function deployRebasingDETFTokenDFPkg(
        ICreate3FactoryProxy create3Factory,
        IRebasingDETFTokenDFPkg.PkgInit memory pkgInit_
    ) internal returns (IRebasingDETFTokenDFPkg instance_) {
        instance_ = IRebasingDETFTokenDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(RebasingDETFTokenDFPkg).creationCode,
                    abi.encode(pkgInit_),
                    abi.encode(type(RebasingDETFTokenDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance_), type(RebasingDETFTokenDFPkg).name);
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import {Vm} from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20Facet} from "@crane/contracts/tokens/ERC20/ERC20Facet.sol";
import {ERC2612Facet} from "@crane/contracts/tokens/ERC2612/ERC2612Facet.sol";
import {ERC4626Facet} from "@crane/contracts/tokens/ERC4626/ERC4626Facet.sol";
import {ERC5267Facet} from "@crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol";
import {IERC4626PermitDFPkg, ERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";
import {ERC4626BasedBasicVaultFacet} from "contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol";
import {ERC4626StandardVaultFacet} from "contracts/vaults/standard/ERC4626StandardVaultFacet.sol";
import {MultiAssetBasicVaultFacet} from "contracts/vaults/basic/MultiAssetBasicVaultFacet.sol";
import {MultiAssetStandardVaultFacet} from "contracts/vaults/standard/MultiAssetStandardVaultFacet.sol";

library VaultComponentFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC20Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(type(ERC20Facet).creationCode, abi.encode(type(ERC20Facet).name)._hash());
        vm.label(address(instance), type(ERC20Facet).name);
    }

    function deployERC2612Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(ERC2612Facet).creationCode, abi.encode(type(ERC2612Facet).name)._hash());
        vm.label(address(instance), type(ERC2612Facet).name);
    }

    function deployERCC5267Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(ERC5267Facet).creationCode, abi.encode(type(ERC5267Facet).name)._hash());
        vm.label(address(instance), type(ERC5267Facet).name);
    }

    function deployERC4626Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(ERC4626Facet).creationCode, abi.encode(type(ERC4626Facet).name)._hash());
        vm.label(address(instance), type(ERC4626Facet).name);
    }

    function deployERC4626PermitDFPkg(ICreate3FactoryProxy create3Factory, IERC4626PermitDFPkg.PkgInit memory pkgInit)
        internal
        returns (IERC4626PermitDFPkg instance)
    {
        instance = IERC4626PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC4626PermitDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ERC4626PermitDFPkg).name)._hash()
                )
            )
        );
        vm.label(address(instance), type(ERC4626PermitDFPkg).name);
    }

    function deployERC4626PermitDFPkg(
        ICreate3FactoryProxy create3Factory,
        IFacet erc20Facet,
        IFacet erc5267Facet,
        IFacet erc2612Facet,
        IFacet erc4626Facet
    ) internal returns (IERC4626PermitDFPkg instance) {
        IERC4626PermitDFPkg.PkgInit memory pkgInit = IERC4626PermitDFPkg.PkgInit({
            erc20Facet: erc20Facet, erc5267Facet: erc5267Facet, erc2612Facet: erc2612Facet, erc4626Facet: erc4626Facet
        });
        return deployERC4626PermitDFPkg(create3Factory, pkgInit);
    }

    function deployERC4626BasedBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(ERC4626BasedBasicVaultFacet).creationCode, abi.encode(type(ERC4626BasedBasicVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(ERC4626BasedBasicVaultFacet).name);
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(ERC4626StandardVaultFacet).creationCode, abi.encode(type(ERC4626StandardVaultFacet).name)._hash());
        vm.label(address(instance), type(ERC4626StandardVaultFacet).name);
    }

    function deployMultiAssetBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(type(MultiAssetBasicVaultFacet).creationCode, abi.encode(type(MultiAssetBasicVaultFacet).name)._hash());
        vm.label(address(instance), type(MultiAssetBasicVaultFacet).name);
    }

    function deployMultiAssetStandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            type(MultiAssetStandardVaultFacet).creationCode,
            abi.encode(type(MultiAssetStandardVaultFacet).name)._hash()
        );
        vm.label(address(instance), type(MultiAssetStandardVaultFacet).name);
    }
}

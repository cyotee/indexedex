// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

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

import {IERC4626PermitDFPkg} from "@crane/contracts/tokens/ERC4626/ERC4626PermitDFPkg.sol";

library VaultComponentFactoryService {
    using BetterEfficientHashLib for bytes;

    /// forge-lint: disable-next-line(screaming-snake-case-const)
    Vm constant vm = Vm(VM_ADDRESS);

    function deployERC20Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(ArtifactCreationCode.creationCode("ERC20Facet.sol:ERC20Facet"), abi.encode("ERC20Facet")._hash());
        vm.label(address(instance), "ERC20Facet");
    }

    function deployERC2612Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(ArtifactCreationCode.creationCode("ERC2612Facet.sol:ERC2612Facet"), abi.encode("ERC2612Facet")._hash());
        vm.label(address(instance), "ERC2612Facet");
    }

    function deployERC5267Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(ArtifactCreationCode.creationCode("ERC5267Facet.sol:ERC5267Facet"), abi.encode("ERC5267Facet")._hash());
        vm.label(address(instance), "ERC5267Facet");
    }

    function deployERC4626Facet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(ArtifactCreationCode.creationCode("ERC4626Facet.sol:ERC4626Facet"), abi.encode("ERC4626Facet")._hash());
        vm.label(address(instance), "ERC4626Facet");
    }

    function deployERC4626PermitDFPkg(ICreate3FactoryProxy create3Factory, IERC4626PermitDFPkg.PkgInit memory pkgInit)
        internal
        returns (IERC4626PermitDFPkg instance)
    {
        instance = IERC4626PermitDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode("ERC4626PermitDFPkg.sol:ERC4626PermitDFPkg"),
                    abi.encode(pkgInit),
                    abi.encode("ERC4626PermitDFPkg")._hash()
                )
            )
        );
        vm.label(address(instance), "ERC4626PermitDFPkg");
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
            ArtifactCreationCode.creationCode("ERC4626BasedBasicVaultFacet.sol:ERC4626BasedBasicVaultFacet"), abi.encode("ERC4626BasedBasicVaultFacet")._hash()
        );
        vm.label(address(instance), "ERC4626BasedBasicVaultFacet");
    }

    function deployERC4626StandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(ArtifactCreationCode.creationCode("ERC4626StandardVaultFacet.sol:ERC4626StandardVaultFacet"), abi.encode("ERC4626StandardVaultFacet")._hash());
        vm.label(address(instance), "ERC4626StandardVaultFacet");
    }

    function deployMultiAssetBasicVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance =
            create3Factory.deployFacet(ArtifactCreationCode.creationCode("MultiAssetBasicVaultFacet.sol:MultiAssetBasicVaultFacet"), abi.encode("MultiAssetBasicVaultFacet")._hash());
        vm.label(address(instance), "MultiAssetBasicVaultFacet");
    }

    function deployMultiAssetStandardVaultFacet(ICreate3FactoryProxy create3Factory) internal returns (IFacet instance) {
        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("MultiAssetStandardVaultFacet.sol:MultiAssetStandardVaultFacet"),
            abi.encode("MultiAssetStandardVaultFacet")._hash()
        );
        vm.label(address(instance), "MultiAssetStandardVaultFacet");
    }
}

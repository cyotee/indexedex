// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IUniswapV4DetfMigrationDFPkg} from "./interfaces/IUniswapV4DetfMigrationDFPkg.sol";
import {IUniswapV4DetfMigrationRewardTokenDFPkg} from "./sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";

/// @notice Registered parent/bond packages and the generic immutable local RT package.
library UniswapV4DetfMigration_Pkg_FactoryService {
    Vm internal constant vm = Vm(VM_ADDRESS);

    function deployParent(IVaultRegistryDeployment registry_, IUniswapV4DetfMigrationDFPkg.PkgInit memory init_)
        internal returns (IUniswapV4DetfMigrationDFPkg)
    {
        return IUniswapV4DetfMigrationDFPkg(_registered(registry_, "UniswapV4DetfMigrationDFPkg", abi.encode(init_)));
    }

    function deployBond(IVaultRegistryDeployment registry_, IDETFNFTVaultDFPkg.PkgInit memory init_)
        internal returns (IDETFNFTVaultDFPkg)
    {
        return IDETFNFTVaultDFPkg(_registered(registry_, "UniswapV4DetfMigrationBondNFTVaultDFPkg", abi.encode(init_)));
    }

    function deployRewardToken(
        ICreate3FactoryProxy factory_, IUniswapV4DetfMigrationRewardTokenDFPkg.PkgInit memory init_
    ) internal returns (IUniswapV4DetfMigrationRewardTokenDFPkg package_) {
        string memory name_ = "UniswapV4DetfMigrationRewardTokenDFPkg";
        package_ = IUniswapV4DetfMigrationRewardTokenDFPkg(address(factory_.deployPackageWithArgs(
            ArtifactCreationCode.creationCode(factory_, string.concat(name_, ".sol:", name_)), abi.encode(init_),
            ArtifactCreationCode.releaseSalt(keccak256(abi.encode(name_)))
        )));
        vm.label(address(package_), name_);
    }

    function _registered(IVaultRegistryDeployment registry_, string memory name_, bytes memory init_)
        private returns (address package_)
    {
        package_ = address(registry_.deployPkg(
            ArtifactCreationCode.creationCode(string.concat(name_, ".sol:", name_)), init_,
            ArtifactCreationCode.releaseSalt(keccak256(abi.encode(name_)))
        ));
        vm.label(package_, name_);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IDETFSYDFPkg} from "contracts/vaults/detf/common/sy/IDETFSYDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";
import {IUniswapV4DetfMigrationDFPkg} from "../interfaces/IUniswapV4DetfMigrationDFPkg.sol";

/// @notice Package-only immutable construction records for pre-parent Migration SYs.
interface IUniswapV4DetfMigrationSYDFPkg is IDETFSYDFPkg {
    struct MigrationPkgInit {
        IDETFSYDFPkg.PkgInit baseInit;
        IDiamondPackageCallBackFactory diamondFactory;
    }

    struct Preparation {
        address parentPackage;
        bytes32 constructionId;
        address parent;
        address bond;
        address bondPackage;
        bytes32 bondArgsHash;
        address receipt;
        address rawSy;
        address stakingSy;
        bytes32 rawArgsHash;
        bytes32 stakingArgsHash;
        bool completed;
    }

    error InvalidSyConstruction();
    error SyPreparationBusy();

    function diamondFactory() external view returns (IDiamondPackageCallBackFactory);
    function prepare(IUniswapV4DetfMigrationDFPkg.PkgArgs memory args_)
        external returns (Preparation memory);
    function preparation(bytes32 constructionId_) external view returns (Preparation memory);
    function construction(address parentPackage_, IUniswapV4DetfMigrationDFPkg.PkgArgs memory args_)
        external view returns (IUniswapV4DetfMigrationDFPkg.SyConstruction memory);
    function authorizedChild(bytes32 argsHash_) external view returns (address);
    function validateChild(address child_, IDETFSYDFPkg.PkgArgs memory args_) external view;
    /// @notice Validate exact registered bond reuse before or after final reserved-role wiring.
    function validateBond(address bond_, address package_, IDETFNFTVaultDFPkg.PkgArgs memory args_,
        bool reserved_, address creator_) external view;
}

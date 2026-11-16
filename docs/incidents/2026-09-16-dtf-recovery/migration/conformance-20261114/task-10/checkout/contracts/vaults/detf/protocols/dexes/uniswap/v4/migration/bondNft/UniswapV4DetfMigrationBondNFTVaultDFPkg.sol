// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "./IUniswapV4DetfMigrationBondNFTVault.sol";

/// @notice Registered Migration bond package using unchanged common arguments and real custody initialization.
/// @dev PkgInit selects Migration lifecycle and metadata facets, plus the canonical ERC721 facet.
contract UniswapV4DetfMigrationBondNFTVaultDFPkg is DETFNFTVaultDFPkg {
    constructor(PkgInit memory init_) DETFNFTVaultDFPkg(init_) {}

    /// @inheritdoc DETFNFTVaultDFPkg
    function packageName() public pure override returns (string memory) {
        return type(UniswapV4DetfMigrationBondNFTVaultDFPkg).name;
    }

    /// @inheritdoc DETFNFTVaultDFPkg
    function facetInterfaces() public pure override returns (bytes4[] memory ids_) {
        bytes4[] memory common_ = super.facetInterfaces();
        ids_ = new bytes4[](common_.length + 2);
        for (uint256 i_; i_ < common_.length; ++i_) ids_[i_] = common_[i_];
        ids_[common_.length] = type(IUniswapV4DetfMigrationBondNFTVault).interfaceId;
        ids_[common_.length + 1] = type(IUniswapV4DetfMigrationAccounting).interfaceId;
    }
}

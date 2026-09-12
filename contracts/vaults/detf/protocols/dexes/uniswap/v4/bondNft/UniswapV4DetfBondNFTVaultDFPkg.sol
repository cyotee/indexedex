// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DETFNFTVaultDFPkg, IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";

/// @notice V4 factory schema uses the common funded bond package.
interface IUniswapV4DetfBondNFTVaultDFPkg is IDETFNFTVaultDFPkg {}

/// @notice V4 deployment binding; accounting and selector cuts are shared across families.
contract UniswapV4DetfBondNFTVaultDFPkg is DETFNFTVaultDFPkg {
    constructor(PkgInit memory init_) DETFNFTVaultDFPkg(init_) {}

    /// @inheritdoc DETFNFTVaultDFPkg
    function packageName() public pure override returns (string memory) {
        return type(UniswapV4DetfBondNFTVaultDFPkg).name;
    }
}

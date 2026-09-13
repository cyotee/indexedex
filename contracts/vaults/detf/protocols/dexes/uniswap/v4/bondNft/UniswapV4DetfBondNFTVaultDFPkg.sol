// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/IUniswapV4DetfBondNFTVaultDFPkg.sol";

import {DETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/IDETFNFTVaultDFPkg.sol";



/// @notice V4 deployment binding; accounting and selector cuts are shared across families.
contract UniswapV4DetfBondNFTVaultDFPkg is DETFNFTVaultDFPkg {
    constructor(PkgInit memory init_) DETFNFTVaultDFPkg(init_) {}

    /// @inheritdoc DETFNFTVaultDFPkg
    function packageName() public pure override returns (string memory) {
        return type(UniswapV4DetfBondNFTVaultDFPkg).name;
    }
}

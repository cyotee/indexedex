// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DETFNFTVaultFacet} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultFacet.sol";

/// @notice V4 package binding to the common funded bond lifecycle.
contract UniswapV4DetfBondNFTVaultFacet is DETFNFTVaultFacet {
    /// @inheritdoc DETFNFTVaultFacet
    function facetName() public pure override returns (string memory) {
        return type(UniswapV4DetfBondNFTVaultFacet).name;
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4DetfExchangeFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeFacet.sol";
import {UniswapV4DetfBondFacet} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfBondFacet.sol";
import {
    UniswapV4DetfMaintenanceFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfMaintenanceFacet.sol";
import {
    UniswapV4DetfClaimFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfClaimFacet.sol";
import {
    UniswapV4DetfQueryFacet
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryFacet.sol";
import {UniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol";

/// @notice Production source root for artifact-loaded universal DETF implementations.
/// @dev Like CraneFactoryArtifactSeed, never import from FactoryServices, TestBases, or scripts.
library UniswapV4DetfFactoryArtifactSeed {
    function artifactNames() internal pure returns (string memory) {
        return string.concat(
            type(UniswapV4DetfExchangeFacet).name,
            type(UniswapV4DetfBondFacet).name,
            type(UniswapV4DetfMaintenanceFacet).name,
            type(UniswapV4DetfClaimFacet).name,
            type(UniswapV4DetfQueryFacet).name,
            type(UniswapV4DetfDFPkg).name
        );
    }
}

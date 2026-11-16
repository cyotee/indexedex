// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultTypes[]
/// @notice Policy-independent geometry and principal observations for the three managed slots.
library UniswapV4UpperLowerWingsStandardExchangeVaultTypes {
    enum Slot {
        Core,
        Upper,
        Lower
    }
    enum Composition {
        NoPrincipal,
        Token0Only,
        Token1Only,
        Mixed
    }

    /// @dev Unavailable wings have zeroed bounds and must not be submitted to PoolManager.
    struct Range {
        int24 lower;
        int24 upper;
        bool available;
    }

    struct Geometry {
        Range core;
        Range upper;
        Range lower;
    }

    struct Principal {
        uint256 amount0;
        uint256 amount1;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultTypes[]

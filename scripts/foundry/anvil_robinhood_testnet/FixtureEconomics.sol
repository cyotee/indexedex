// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

/// @title FixtureEconomics
/// @notice Locked numeric constants for the 46630 launch-group scripts (PRD §2 / plan §4).
library FixtureEconomics {
    string internal constant SALT_NS = "RhTestnet";

    uint256 internal constant MIN_LOCK = 86400;
    uint256 internal constant MAX_LOCK = 180 days;
    uint256 internal constant DEFAULT_MIN_LOCK = MIN_LOCK;
    uint256 internal constant DEFAULT_MAX_LOCK = MAX_LOCK;

    uint256 internal constant USAGE_FEE = 5e16;
    uint256 internal constant DEX_SWAP_FEE = 3e14;
    uint256 internal constant SEIGNIORAGE = 5e16; // 5% product default
    uint256 internal constant V4_LIQUID_RESERVE = 0.2e18;
    uint256 internal constant DEFAULT_V4_LIQUID_RESERVE_PCT = V4_LIQUID_RESERVE;

    uint256 internal constant CLAIM_WIDTH_MULTIPLIER = 1;

    uint256 internal constant CREATION_PAIR_PER_DETF = 1e18;
    /// @dev First-bond pair per DETF. N17 starts 1.1e18. Hermetic N10: CP Single mint-opens at 2.2e18
    ///      after a real `bond` (Quad mint-opens at 1.1e18). Shared 46630 fixture uses the CP WAD.
    ///      Not a D47 impersonation target.
    uint256 internal constant OPENING_PAIR_PER_DETF = 2.2e18;
    uint256 internal constant MINT_THRESHOLD = 1.05e18;
    uint256 internal constant BURN_THRESHOLD = 0.95e18;
    uint256 internal constant EXPANSION_EPOCH = 0;
    uint256 internal constant EXPANSION_R = 0;
    uint256 internal constant EXPANSION_CATCHUP = 0;
    uint256 internal constant BASE_AMP = 100;
    /// @dev Morpho Blue LLTV enabled on rehearsal Morpho (80%).
    uint256 internal constant MORPHO_LLTV = 0.8e18;
    uint8 internal constant ORBITAL_DETF_BINDING = 2;
    uint256 internal constant DETF_WEIGHT = 0.2e18;
    // Mint-open plus a little room (Policy mint is 1.05e18). 10.5e18 is a 15x fd
    // add these SE-buffered hooks cannot zap; gold TestBases only drive S > 1.05.
    uint256 internal constant RICH_TARGET = 1.1e18;

    uint256 internal constant FACADE_MAX_MINT = 10_000_000e18;
    uint256 internal constant FACADE_MIN_INTERVAL = 0;
    uint256 internal constant PREMINT = 1e12 ether;

    uint24 internal constant POOL_FEE = 3000;
    int24 internal constant POOL_TICK_SPACING = 60;

    uint256 internal constant TT_TT_SEED = 1e9 ether;
    uint256 internal constant WETH_POOL_SEED = 100 ether;
    uint256 internal constant LEAF_FIRST_BOND = 10 ether;
    uint256 internal constant TTDOL_FIRST_BOND = 10 ether;
    uint256 internal constant DTF_DETF_FIRST_BOND = 10 ether;
    uint256 internal constant INVENTORY_STARTER = 100_000 ether;
    uint256 internal constant SWAP_MIN_OUT = 1;

    uint256 internal constant W_TTNVDA = 184000000000000000;
    uint256 internal constant W_TTMSFT = 160000000000000000;
    uint256 internal constant W_TTAAPL = 144000000000000000;
    uint256 internal constant W_TTGOOGL = 96000000000000000;
    uint256 internal constant W_TTAMZN = 96000000000000000;
    uint256 internal constant W_TTMETA = 72000000000000000;
    uint256 internal constant W_TTTSLA = 48000000000000000;
    uint256 internal constant W_NEST_LEG = 200000000000000000;

    function poolSqrtPrice() internal pure returns (uint160) {
        return TickMath.getSqrtPriceAtTick(0);
    }
}

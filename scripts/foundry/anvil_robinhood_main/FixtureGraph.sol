// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title FixtureGraph
/// @notice TT0–TT7 roles, pool edges, weights for Anvil Robinhood Uni V4 DETF demos.
library FixtureGraph {
    uint8 internal constant TOKEN_COUNT = 8;
    uint256 internal constant MINT_AMOUNT = 1_000_000_000_000e18; // 1e12 whole units @ 18 decimals
    uint256 internal constant EQUAL_WEIGHT_N8 = 0.125e18; // 1/8; sum = 1e18
    uint24 internal constant V3_FEE = 3000;
    uint24 internal constant V3_SE_WIDTH_MULTIPLIER = 10;
    uint24 internal constant V4_SE_WIDTH_MULTIPLIER = 60;
    uint24 internal constant V4_POOL_FEE = 3000;
    int24 internal constant V4_TICK_SPACING = 60;
    /// @dev 1:1 sqrtPriceX96
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    /// @dev Launch-rich expansion rate (from DETF TestBase helpers).
    uint256 internal constant LAUNCH_RICH_R = 4.4e18;
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF = 1e18;
    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;

    function tokenName(uint8 i) internal pure returns (string memory) {
        if (i == 0) return "Test Token 0";
        if (i == 1) return "Test Token 1";
        if (i == 2) return "Test Token 2";
        if (i == 3) return "Test Token 3";
        if (i == 4) return "Test Token 4";
        if (i == 5) return "Test Token 5";
        if (i == 6) return "Test Token 6";
        return "Test Token 7";
    }

    function tokenSymbol(uint8 i) internal pure returns (string memory) {
        if (i == 0) return "TT0";
        if (i == 1) return "TT1";
        if (i == 2) return "TT2";
        if (i == 3) return "TT3";
        if (i == 4) return "TT4";
        if (i == 5) return "TT5";
        if (i == 6) return "TT6";
        return "TT7";
    }

    function tokenSalt(uint8 i) internal pure returns (bytes32) {
        if (i == 0) return keccak256("AnvilRobinhoodTT0");
        if (i == 1) return keccak256("AnvilRobinhoodTT1");
        if (i == 2) return keccak256("AnvilRobinhoodTT2");
        if (i == 3) return keccak256("AnvilRobinhoodTT3");
        if (i == 4) return keccak256("AnvilRobinhoodTT4");
        if (i == 5) return keccak256("AnvilRobinhoodTT5");
        if (i == 6) return keccak256("AnvilRobinhoodTT6");
        return keccak256("AnvilRobinhoodTT7");
    }

    /// @notice Chain path edges TT0-TT1 … TT6-TT7 plus star extras from TT0 (unique pairs).
    /// @dev Returns parallel arrays of left/right indices into TT0…TT7.
    function v3PoolEdges() internal pure returns (uint8[] memory left, uint8[] memory right) {
        // 7 chain + 6 star (TT0-TT2..TT0-TT7; TT0-TT1 already in chain) = 13
        left = new uint8[](13);
        right = new uint8[](13);
        uint256 k;
        for (uint8 i = 0; i < 7; ++i) {
            left[k] = i;
            right[k] = i + 1;
            unchecked {
                ++k;
            }
        }
        // star: TT0-TT2 … TT0-TT7
        for (uint8 j = 2; j < 8; ++j) {
            left[k] = 0;
            right[k] = j;
            unchecked {
                ++k;
            }
        }
    }

    function equalWeightsN8() internal pure returns (uint256[] memory w) {
        w = new uint256[](8);
        for (uint256 i; i < 8; ++i) {
            w[i] = EQUAL_WEIGHT_N8;
        }
    }
}

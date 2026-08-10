// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

/// @title FixtureEconomics
/// @notice Env-overridable fixture constants for the fee-DETF Anvil launch path.
library FixtureEconomics {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev 10 WETH per 1 CHIR at empty-book join (1e18 scale).
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF_WAD = 10e18;
    /// @dev Launch-rich expansion rate (~1y walk narrative).
    uint256 internal constant DEFAULT_EXPANSION_CLOSURE_RATE_PER_YEAR_WAD = 4.4e18;
    uint256 internal constant DEFAULT_LARGE_RICH_BUY_WETH = 50 ether;
    /// @dev First bond size; keep viable vs MINIMUM_LIQUIDITY on empty SE + hook (env override).
    uint256 internal constant DEFAULT_FIRST_BOND_WETH = 1 ether;
    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint24 internal constant V3_SE_WIDTH_MULTIPLIER = 10;

    string internal constant CHIR_NAME = "IndexedEx Fee DETF";
    string internal constant CHIR_SYMBOL = "CHIR";
    string internal constant RICH_NAME = "RICH";
    string internal constant RICH_SYMBOL = "RICH";

    address internal constant PONS_FACTORY = 0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB;
    address internal constant PONS_LOCKER = 0x736D76699C26D0d966744cAe304C000d471f7F35;
    /// @dev pons V3 SwapRouter02 pin (dexConfig.swapRouter).
    address internal constant PONS_V3_SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;

    function creationPairPerDetfWad() internal view returns (uint256) {
        try vm.envUint("CREATION_PAIR_PER_DETF_WAD") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_CREATION_PAIR_PER_DETF_WAD;
    }

    function expansionClosureRatePerYearWad() internal view returns (uint256) {
        try vm.envUint("EXPANSION_CLOSURE_RATE_PER_YEAR_WAD") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_EXPANSION_CLOSURE_RATE_PER_YEAR_WAD;
    }

    function largeRichBuyWeth() internal view returns (uint256) {
        try vm.envUint("LARGE_RICH_BUY_WETH") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_LARGE_RICH_BUY_WETH;
    }

    function firstBondWeth() internal view returns (uint256) {
        try vm.envUint("FIRST_BOND_WETH") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_FIRST_BOND_WETH;
    }

    function v3SeWidthMultiplier() internal view returns (uint24) {
        try vm.envUint("UNI_V3_SE_WIDTH_MULTIPLIER") returns (uint256 v) {
            if (v > 0 && v <= type(uint24).max) return uint24(v);
        } catch {}
        return V3_SE_WIDTH_MULTIPLIER;
    }
}

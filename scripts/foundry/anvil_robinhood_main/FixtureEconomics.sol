// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

/// @title FixtureEconomics
/// @notice Env-overridable fixture constants for the fee-DETF Anvil launch path.
/// @dev Synthetic S = (fdPair / supply) / creationRate is a *ratio*. Absolute WETH needed for
///      target S scales with first-bond size (supply). Keep first bond minimal so S≈10 fits in
///      a ~1–2 WETH launch budget (bond + pair-only seed).
library FixtureEconomics {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev 10 WETH per 1 CHIR at empty-book join (1e18 scale). Peg units, not launch capital.
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF_WAD = 10e18;
    /// @dev Launch-rich expansion rate (~1y walk narrative).
    uint256 internal constant DEFAULT_EXPANSION_CLOSURE_RATE_PER_YEAR_WAD = 4.4e18;
    uint256 internal constant DEFAULT_LARGE_RICH_BUY_WETH = 50 ether;

    /// @dev Minimal viable first bond (empty reserve + hook MINIMUM_LIQUIDITY=1000).
    ///      Capital for S≈10 scales roughly with this; keep small.
    uint256 internal constant DEFAULT_FIRST_BOND_WETH = 0.1 ether;
    /// @dev Soft total WETH budget for first bond + launch-rich seed (greenfield launch).
    uint256 internal constant DEFAULT_LAUNCH_BUDGET_WETH = 2 ether;
    /// @dev After first bond, deposit pair-only until synthetic exceeds this (WAD).
    ///      Launch-rich narrative: S ~10e18 (10x peg) for expansion runway past mint gate (1.05e18).
    uint256 internal constant DEFAULT_LAUNCH_RICH_TARGET_SYNTHETIC_WAD = 10e18;
    /// @dev Fine seed steps after the estimated bulk deposit (avoid multi-ether overshoot).
    uint256 internal constant DEFAULT_LAUNCH_RICH_SEED_STEP_WETH = 0.01 ether;
    /// @dev Hard cap on pair-only seed alone (also clamped by launch budget − first bond).
    uint256 internal constant DEFAULT_LAUNCH_RICH_SEED_MAX_WETH = 1.9 ether;

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

    /// @dev Total WETH intent for bond + seed. Seed is clamped to budget − firstBond when possible.
    function launchBudgetWeth() internal view returns (uint256) {
        try vm.envUint("LAUNCH_BUDGET_WETH") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_LAUNCH_BUDGET_WETH;
    }

    function launchRichTargetSyntheticWad() internal view returns (uint256) {
        try vm.envUint("LAUNCH_RICH_TARGET_SYNTHETIC_WAD") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_LAUNCH_RICH_TARGET_SYNTHETIC_WAD;
    }

    function launchRichSeedStepWeth() internal view returns (uint256) {
        try vm.envUint("LAUNCH_RICH_SEED_STEP_WETH") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_LAUNCH_RICH_SEED_STEP_WETH;
    }

    function launchRichSeedMaxWeth() internal view returns (uint256) {
        try vm.envUint("LAUNCH_RICH_SEED_MAX_WETH") returns (uint256 v) {
            if (v > 0) return v;
        } catch {}
        return DEFAULT_LAUNCH_RICH_SEED_MAX_WETH;
    }

    function v3SeWidthMultiplier() internal view returns (uint24) {
        try vm.envUint("UNI_V3_SE_WIDTH_MULTIPLIER") returns (uint256 v) {
            if (v > 0 && v <= type(uint24).max) return uint24(v);
        } catch {}
        return V3_SE_WIDTH_MULTIPLIER;
    }
}

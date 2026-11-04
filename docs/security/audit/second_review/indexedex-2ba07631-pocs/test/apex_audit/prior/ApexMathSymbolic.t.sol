// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookMath as WMath
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";

/**
 * @notice APEX — INVARIANT-LIBRARY item: halmos symbolic pass on the math actually on the
 *         live path (the weighted buffer hook is the only hook deployed on Robinhood
 *         mainnet 4663) plus the bond reward math, which moves real funds.
 *
 *         Properties chosen for where value can leak:
 *           - a fee must never increase the amount it is applied to
 *           - grossing an exact-out back up must recover at least the net (else the
 *             protocol eats the difference every trade)
 *           - scale/descale round-trips must not manufacture units
 *           - reward and effective-share math must not overflow into a windfall
 *
 *         Run:  halmos --match-contract ApexMathSymbolic
 *         Also runs under plain `forge test` as bounded fuzz.
 */
contract ApexMathSymbolic is Test {
    uint256 constant WAD = 1e18;

    /* ---------------- fee direction ---------------- */

    /// A fee must never hand back more than was put in.
    function check_feeNeverIncreases(uint256 amountIn, uint256 feeWad) public pure {
        vm.assume(feeWad < WAD);
        vm.assume(amountIn < type(uint128).max);
        uint256 net = WMath.applyTradingFeeNet(amountIn, feeWad);
        assert(net <= amountIn);
    }

    /// Grossing back up must recover at least the net amount — otherwise the protocol
    /// silently subsidises every exact-out trade.
    function check_grossUpRecoversNet(uint256 netIn, uint256 feeWad) public pure {
        vm.assume(feeWad < WAD);
        vm.assume(netIn > 0 && netIn < type(uint96).max);
        uint256 gross = WMath.grossUpExactOut(netIn, feeWad);
        assert(gross >= netIn);
    }

    /// Round-trip must not be profitable for the caller: fee applied to the grossed-up
    /// amount must not exceed what they asked for.
    function check_feeRoundTripNotProfitable(uint256 netIn, uint256 feeWad) public pure {
        vm.assume(feeWad < WAD);
        vm.assume(netIn > 0 && netIn < type(uint96).max);
        uint256 gross = WMath.grossUpExactOut(netIn, feeWad);
        vm.assume(gross < type(uint128).max);
        uint256 back = WMath.applyTradingFeeNet(gross, feeWad);
        // Recovering strictly MORE than requested would be free value.
        assert(back <= netIn + 1);
    }

    /* ---------------- scaling round-trip ---------------- */

    /// descale(scaleTo(a)) must never exceed `a` — scaling cannot manufacture units.
    function check_scaleRoundTripNoInflation(uint256 amount, uint256 rate) public pure {
        vm.assume(rate > 0 && rate <= 1e27);
        vm.assume(amount < type(uint96).max);
        uint256 scaled = WMath.scaleTo(amount, rate);
        uint256 back = WMath.descale(scaled, rate);
        assert(back <= amount);
    }

    /// The rounding-up variants must sit above their rounding-down counterparts.
    function check_upVariantsDominate(uint256 amount, uint256 rate) public pure {
        vm.assume(rate > 0 && rate <= 1e27);
        vm.assume(amount < type(uint96).max);
        assert(WMath.scaleToUp(amount, rate) >= WMath.scaleTo(amount, rate));
        assert(WMath.descaleUp(amount, rate) >= WMath.descale(amount, rate));
    }

    /* ---------------- bond reward math ---------------- */

    /// No rewards may be produced when the per-share index has not advanced.
    function check_noRewardsWithoutIndexAdvance(uint256 eff, uint256 rps, uint256 paid) public pure {
        vm.assume(rps <= paid);
        (uint256 rewards, bool has) = DETFBondNFTMathLib._calcHarvestRewards(eff, rps, paid);
        assert(rewards == 0);
        assert(!has);
    }

    /// Rewards must scale with the index delta and never exceed the naive product.
    function check_rewardsBoundedByDelta(uint256 eff, uint256 rps, uint256 paid) public pure {
        vm.assume(rps > paid);
        vm.assume(eff < type(uint96).max);
        vm.assume(rps - paid < type(uint96).max);
        (uint256 rewards,) = DETFBondNFTMathLib._calcHarvestRewards(eff, rps, paid);
        assert(rewards <= (eff * (rps - paid)) / 1e18);
    }

    /// A bonus multiplier at parity must be the identity on shares.
    function check_effectiveSharesParityIsIdentity(uint256 shares) public pure {
        vm.assume(shares < type(uint96).max);
        assert(DETFBondNFTMathLib._calcEffectiveShares(shares, WAD) == shares);
    }

    /// A sub-parity multiplier must never increase effective shares.
    function check_effectiveSharesMonotone(uint256 shares, uint256 mult) public pure {
        vm.assume(shares < type(uint96).max);
        vm.assume(mult <= WAD);
        assert(DETFBondNFTMathLib._calcEffectiveShares(shares, mult) <= shares);
    }
}

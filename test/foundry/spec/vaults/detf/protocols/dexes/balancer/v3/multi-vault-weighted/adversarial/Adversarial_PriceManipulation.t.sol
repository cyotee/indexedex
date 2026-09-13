// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_MultiVaultWeightedDetf_Adversarial
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfInfo.sol";

/// @notice B1 flash-style skew arb bound; B3 threshold gate coupling under rate moves.
/// @dev Deferred P2: B2 (reserve sandwich - user minOut + no protocol NFT drain; external pool risk),
///      B4 (cross-leg rate desync N=2), B5 (MaxInRatio/min-balance grief - clean revert only).
contract Adversarial_PriceManipulation_Test is TestBase_MultiVaultWeightedDetf_Adversarial {
    /// @notice B1: when mint AND burn are both open (open thresholds), underlying skew can extract
    ///      seigniorage as vault-share PnL. That is intentional product surface - not a free drain of
    ///      bonded principal. Hard invariants: victim DETF balance, residual inventory, claim authority.
    function test_B1_skewMintReverseBurn_seigniorageBounds() public {
        address instance_ = _deployOpenModeDetfN(1);
        (uint256 aliceTokenId_, uint256 aliceBpt_) = _goLiveViaBptBond(instance_, alice, 2_000e18);
        assertTrue(aliceTokenId_ > 0 && aliceBpt_ > 0, "alice bond principal");

        // Victim holds free DETF from a prior mint (seigniorage dilution target)
        uint256 victimOut_ = _mintOnLeg(instance_, 0, victim, 50e18);
        uint256 victimBal_ = IERC20(instance_).balanceOf(victim);
        assertEq(victimBal_, victimOut_, "victim detf");

        address pool_ = IMultiVaultWeightedDetfInfo(instance_).reservePool();
        address custody_ = IMultiVaultWeightedDetfInfo(instance_).bondNftVault();
        uint256 bptBefore_ = IERC20(pool_).balanceOf(custody_);
        assertGt(bptBefore_, 0, "funded protocol reserve");

        dai.mint(attacker, 500_000e18);
        usdc.mint(attacker, 500_000e18);

        uint256 sharesIn_ = _fundSeSharesLeg(0, attacker, 80e18);

        // Skew → mint → reverse → burn (atomic flash-style sequence)
        _swapUnderlying(address(dai), address(usdc), 50_000e18, attacker);

        vm.startPrank(attacker);
        seShares[0].approve(instance_, sharesIn_);
        uint256 detfOut_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShares[0], sharesIn_, IERC20(instance_), 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertTrue(detfOut_ > 0, "minted after skew");

        _swapUnderlying(address(usdc), address(dai), 50_000e18, attacker);

        vm.startPrank(attacker);
        IERC20(instance_).approve(instance_, detfOut_);
        uint256 sharesBack_ = IStandardExchangeIn(instance_)
            .exchangeIn(IERC20(instance_), detfOut_, seShares[0], 0, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();

        // Hard safety: victim token balance unchanged (no rebalance theft of balances)
        assertEq(IERC20(instance_).balanceOf(victim), victimBal_, "B1: victim DETF balance intact");
        // Hard safety: attacker cannot pull BPT without claim
        assertEq(IERC20(pool_).balanceOf(attacker), 0, "B1: attacker holds no free BPT");
        // The NFT holds protocol-owned LP; purchased bonds hold funded staking.
        assertGt(IERC20(pool_).balanceOf(custody_), 0, "B1: protocol reserve remains funded");
        // Seigniorage bound: share profit (if any) is finite and sub-linear in size of attack vs bootstrap.
        // Documented intentional risk when both gates open - not unbounded drain of aliceBpt_ principal.
        if (sharesBack_ > sharesIn_) {
            uint256 profit_ = sharesBack_ - sharesIn_;
            emit log_named_uint("B1_intentional_seigniorage_share_profit", profit_);
            // Profit must remain a small fraction of bootstrap principal scale (not full drain)
            assertLt(profit_, aliceBpt_ / 10, "B1: seigniorage profit bounded vs bond principal scale");
            assertLt(profit_, sharesIn_ / 2, "B1: profit < 50% of attack size");
        }
        // Residual free inventory clean
        _assertNoFreeInventoryStrict(instance_);
        // bpt may move with join/exit; never invent claim authority
        emit log_named_uint("bpt_before", bptBefore_);
        emit log_named_uint("bpt_after", IERC20(pool_).balanceOf(custody_));
    }

    /// @notice B1b: under default thresholds, deadband often blocks free mint↔burn cycle after mild skew.
    function test_B1b_defaultThresholds_cannotMintAndBurnSameRegime() public {
        address instance_ = _openLiveN1DefaultThresholds();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);

        // Mild skew
        dai.mint(attacker, 100_000e18);
        _swapUnderlying(address(dai), address(usdc), 20_000e18, attacker);

        bool mintOk_ = info_.isMintingAllowed();
        bool burnOk_ = info_.isBurningAllowed();
        // Deadband: both cannot be true simultaneously with default 1.05 / 0.95
        assertFalse(mintOk_ && burnOk_, "B1b: mint and burn mutually exclusive under default thresholds");
    }

    /// @notice D39: a closed primary gate routes the payment through the funded reserve.
    function test_B3_closedPrimaryMint_executesReserveSwapWithoutIssuance() public {
        address instance_ = _openLiveN1DefaultThresholds();
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        uint256 synth_ = info_.syntheticPrice();
        assertEq(info_.isMintingAllowed(), synth_ > info_.mintThreshold(), "primary mint coupling");
        assertEq(info_.isBurningAllowed(), synth_ < info_.burnThreshold(), "primary burn coupling");
        assertFalse(info_.isMintingAllowed(), "primary mint closed");
        uint256 shares_ = _fundSeSharesLeg(0, attacker, 20e18);
        uint256 quote_ = IStandardExchangeIn(instance_).previewExchangeIn(seShares[0], shares_, IERC20(instance_));
        assertGt(quote_, 0, "funded fallback quote");
        uint256 supply_ = IERC20(instance_).totalSupply();
        vm.startPrank(attacker);
        seShares[0].approve(instance_, shares_);
        uint256 received_ = IStandardExchangeIn(instance_)
            .exchangeIn(seShares[0], shares_, IERC20(instance_), quote_, attacker, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(received_, quote_, "reserve swap matches preview");
        assertEq(IERC20(instance_).balanceOf(attacker), received_, "existing DETF delivered");
        assertEq(IERC20(instance_).totalSupply(), supply_, "closed primary mint creates no supply");
        _assertNoFreeInventoryStrict(instance_);
    }

    /// @dev External entry so try/catch works from same contract context.
    function _externalMint(address instance_, address user, uint256 lp) external {
        _mintOnLeg(instance_, 0, user, lp);
    }
}

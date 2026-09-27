// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_RocketPoolRETHStandardExchange} from
    "contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol";
import {FailingRocketDepositPool} from "contracts/test/stubs/APEXDependencyFailureStubs.sol";
import {HermeticRocketStorage} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";

/// @notice APEX R14 / D39 / D42 on the production Rocket Pool SE proxy: sub-minimum booking,
///         reserve-first sweep bounded by capacity, still-failing deposit propagation.
contract RocketPoolRETHStandardExchange_APEX_R14_Test is TestBase_RocketPoolRETHStandardExchange {
    function _wethToSe(uint256 amount, address who) internal returns (uint256 shares) {
        _dealWeth(who, amount);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, amount);
        shares = seIn.exchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(seVault), 0, who, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _setTarget(uint256 pct) internal {
        // A per-vault override of 0 falls back to the default; set the default itself.
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(pct);
    }

    /// @dev D39: caller input below `getMinimumDeposit()` is fully booked, mints on the full input,
    ///      makes no `deposit` call and matches `previewExchangeIn`.
    function test_APEX_D39_subMinimumInput_bookedAndMintedWithoutDeposit() public {
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(1 ether);
        uint256 amount = 0.5 ether;
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), amount, IERC20(seVault));
        uint256 rethBefore = hermeticReth.balanceOf(seVault);
        uint256 shares = _wethToSe(amount, address(this));
        assertEq(shares, preview, "preview equals execution");
        assertGt(shares, 0);
        assertEq(hermeticReth.balanceOf(seVault), rethBefore, "no deposit below the minimum");
        assertEq(rocketPoolSe.liquidReserveEth(), amount, "whole input booked as sleeve");
    }

    /// @dev D39/D42: a sleeve-eligible booked excess below the minimum is left untouched by a later
    ///      investing operation, and is swept only once the eligible stake reaches the minimum.
    function test_APEX_D39_bookedExcessBelowMinimum_skippedThenSweptWhenEligible() public {
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(1 ether);
        _wethToSe(0.6 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 0.6 ether, "sub-minimum booked");
        // Second sub-minimum caller: booked 0.6 stays (sweep below minimum is skipped, no revert),
        // and the caller's own 0.3 is booked too; total booked 0.9 > 0 but each stake < minimum.
        _wethToSe(0.3 ether, address(0xA11CE));
        assertEq(rocketPoolSe.liquidReserveEth(), 0.9 ether, "sweep skipped below minimum, no revert");
        assertEq(hermeticReth.balanceOf(seVault), 0, "no deposit made");
        // Lower the minimum: the next investing operation sweeps the booked 0.9 then stakes the caller.
        hermeticSettings.setMinimumDeposit(0.01 ether);
        _wethToSe(0.5 ether, address(0xB0B));
        assertEq(rocketPoolSe.liquidReserveEth(), 0, "booked excess swept and caller staked");
        assertGt(hermeticReth.balanceOf(seVault), 0, "rETH received");
    }

    /// @dev R14 / D31: 80 booked, capacity 100, caller 50 at target 0 → sweep 80, invest 20 of
    ///      the caller's, book the other 30; shares are issued for the caller's 50 only.
    function test_APEX_R14_reserveFirst_80booked_100capacity_50caller_target0() public {
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(0.01 ether);
        // Book 80 while the pool is closed (capacity 0 books everything).
        hermeticPool.setMaxDepositAmount(0);
        uint256 firstShares = _wethToSe(80 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 80 ether, "80 booked while closed");
        assertEq(hermeticReth.balanceOf(seVault), 0);
        // Reopen with exactly 100 of capacity.
        hermeticPool.setMaxDepositAmount(100 ether);
        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 50 ether, IERC20(seVault));
        uint256 callerShares = _wethToSe(50 ether, address(0xCA11));
        assertEq(callerShares, preview, "preview equals execution across the sweep");
        assertEq(hermeticPool.getMaximumDepositAmount(), 0, "capacity fully consumed: 80 + 20");
        assertEq(rocketPoolSe.liquidReserveEth(), 30 ether, "only the caller's uninvested 30 stays booked");
        assertGt(hermeticReth.balanceOf(seVault), 0);
        // Shares: first depositor keeps its 80-backed shares, second gets shares for 50 at 1:1 value.
        assertEq(IERC20(seVault).balanceOf(address(this)), firstShares);
        assertEq(IERC20(seVault).balanceOf(address(0xCA11)), callerShares);
    }

    /// @dev D30/D34: after both prechecks pass, a `deposit` that still reverts propagates the pool's
    ///      original revert bytes and leaves shares, reserves and WETH unchanged.
    function test_APEX_D34_stillFailingDeposit_revertsWithPoolBytes_fullRollback() public {
        _setTarget(0);
        hermeticSettings.setMinimumDeposit(0.01 ether);
        // The pool is bound at deploy: deploy a second production SE through the same package,
        // bound to a pool whose published capacity is open but whose `deposit` rejects.
        FailingRocketDepositPool failing = new FailingRocketDepositPool();
        HermeticRocketStorage failingRegistry = new HermeticRocketStorage(address(hermeticReth), address(failing));
        failingRegistry.register("rocketDAOProtocolSettingsDeposit", address(hermeticSettings));
        vm.prank(owner);
        address failingSe = rocketPoolSeDFPkg.deployVault(
            address(hermeticReth), address(hermeticWeth), address(failing), address(failingRegistry)
        );
        uint256 amount = 5 ether;
        _dealWeth(address(this), amount);
        hermeticWeth.approve(failingSe, amount);
        uint256 supplyBefore = IERC20(failingSe).totalSupply();
        vm.expectRevert(
            abi.encodeWithSelector(FailingRocketDepositPool.DependencyRejected.selector, amount, failing.TAG())
        );
        IStandardExchangeIn(failingSe).exchangeIn(
            IERC20(address(hermeticWeth)), amount, IERC20(failingSe), 0, address(this), false, block.timestamp + 1 hours
        );
        assertEq(IERC20(failingSe).totalSupply(), supplyBefore, "no shares survive");
        assertEq(hermeticWeth.balanceOf(failingSe), 0, "no reserve change survives");
        assertEq(hermeticWeth.balanceOf(address(this)), amount, "WETH not pulled");
    }

    /* ------------------------------------------------------------------ */
    /*                    R14.4 — locked-arithmetic + target extremes     */
    /* ------------------------------------------------------------------ */

    function _setVaultTarget(uint256 pct) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setLiquidReservePercentageOfVault(seVault, pct);
    }

    /// @dev Zero BOTH usage-fee levels for exact NAV/entitlement math (mirrors
    ///      TestBase_AaveV3StataStandardExchange_Decimals._setTestUsageFee).
    function _zeroUsageFees() internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seVault, 0);
        vm.stopPrank();
    }

    function _wethToSeExactOut(uint256 sharesOut, address who) internal returns (uint256 usedWeth) {
        uint256 need = seOut.previewExchangeOut(IERC20(address(hermeticWeth)), IERC20(seVault), sharesOut);
        _dealWeth(who, need);
        vm.startPrank(who);
        hermeticWeth.approve(seVault, need);
        usedWeth = seOut.exchangeOut(
            IERC20(address(hermeticWeth)), need, IERC20(seVault), sharesOut, who, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev R14.4: locked-arithmetic sweep. A 400-WETH wrap at the 20% default self-produces the
    ///      fixture (80 liquid / 320 staked). With finite capacity 100, a later 50-WETH wrap sweeps
    ///      only the 40 previously-booked excess toward target (never the caller's own 50); capacity
    ///      is consumed by exactly 40, and the first holder's entitlement is unchanged.
    ///
    ///      _bestEffortStakeOverageTowardTarget's second pass stakes `liquid - target`, but the first
    ///      pass — bounded by `bookedReserve(WETH)` — is why the just-pulled WETH is not swept here:
    ///      after the sweep of the booked excess, `liquid <= target` and the pass returns.
    ///
    ///      RED (vulnerable version): a sweep sized off raw `liquidReserveEth()` (or one ignoring the
    ///      `min(eligible, bookedReserve(WETH))` bound) would have staked part of the in-flight caller's
    ///      50, consuming more than 40 of capacity and shifting locked/NAV — caught by the exact
    ///      capacity-remaining (60) and sleeve (90) assertions below.
    function test_APEX_R14_4_lockedArithmetic_sweepsOnlyBookedExcess_notCallerInput() public {
        _zeroUsageFees();
        // Default target is 20%; capacity open; minimum small.
        hermeticSettings.setMinimumDeposit(0.01 ether);

        // Self-produce the 80/320 fixture with a single 400 wrap at the 20% default.
        uint256 firstShares = _wethToSe(400 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 80 ether, "20% sleeve: 80 liquid");
        assertEq(rocketPoolSe.lockedReserveEth(), 320 ether, "80% staked: 320 locked (1:1 rETH)");
        assertEq(rocketPoolSe.totalReserveEth(), 400 ether, "NAV 400");
        uint256 firstEntitlementBefore =
            seIn.previewExchangeIn(IERC20(seVault), firstShares, IERC20(address(hermeticWeth)));

        // Finite capacity 100 for the sweep.
        hermeticPool.setMaxDepositAmount(100 ether);

        uint256 preview = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 50 ether, IERC20(seVault));
        uint256 callerShares = _wethToSe(50 ether, address(0xCA11));
        assertEq(callerShares, preview, "preview equals execution across the sweep");

        // Only the previously-booked excess (40) was swept; the caller's 50 stayed liquid.
        assertEq(rocketPoolSe.liquidReserveEth(), 90 ether, "80 - 40 swept + 50 caller = 90 liquid");
        assertEq(rocketPoolSe.lockedReserveEth(), 360 ether, "320 + 40 swept = 360 locked");
        assertEq(rocketPoolSe.totalReserveEth(), 450 ether, "NAV 450");
        assertEq(hermeticPool.getMaximumDepositAmount(), 60 ether, "capacity consumed exactly 40");

        // Share offset is 3, so relate the caller's shares to value, not to a hand-computed literal.
        assertApproxEqRel(
            seIn.previewExchangeIn(IERC20(seVault), callerShares, IERC20(address(hermeticWeth))),
            50 ether, 0.0001e18, "caller's shares are worth ~its own 50 WETH input"
        );
        // No entitlement transfer to the first holder from the sweep.
        assertApproxEqAbs(
            seIn.previewExchangeIn(IERC20(seVault), firstShares, IERC20(address(hermeticWeth))),
            firstEntitlementBefore, 1e6, "first holder's entitlement unchanged by the sweep"
        );
    }

    /// @dev R14.4: target 0 invests everything on BOTH the exact-in and exact-out sleeve routes.
    ///      RED: a route that booked instead of staking the overage at a zero target would leave
    ///      liquid > 0 — caught by the liquid==0 assertions.
    function test_APEX_R14_4_targetZero_investsEverything_bothRoutes() public {
        _zeroUsageFees();
        _setTarget(0); // global default (a per-vault 0 falls back to the 20% default)
        hermeticSettings.setMinimumDeposit(0.01 ether);

        // Exact-in wrap: whole input staked.
        _wethToSe(100 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 0, "exact-in at target 0 stakes everything");
        assertGt(hermeticReth.balanceOf(seVault), 0, "rETH received");

        // Exact-out wrap: the pulled input is also fully staked back to target 0.
        _wethToSeExactOut(20_000 ether, address(0xB0B));
        assertEq(rocketPoolSe.liquidReserveEth(), 0, "exact-out at target 0 stakes everything");
    }

    /// @dev R14.4: target 100% invests nothing on the sleeve (WETH→SE), but the hard WETH→rETH route
    ///      still stakes regardless of target.
    ///      RED: a hard-stake path gated on the sleeve target would have returned zero rETH here.
    function test_APEX_R14_4_targetFull_sleeveKeepsAll_hardStakeStillWorks() public {
        _zeroUsageFees();
        _setVaultTarget(1e18); // per-vault 100%
        hermeticSettings.setMinimumDeposit(0.01 ether);

        _wethToSe(100 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 100 ether, "100% target: sleeve keeps the whole input");
        assertEq(hermeticReth.balanceOf(seVault), 0, "best-effort staked nothing at a 100% target");

        // Hard WETH -> rETH still stakes and pays rETH to the recipient.
        uint256 quote = seIn.previewExchangeIn(IERC20(address(hermeticWeth)), 10 ether, IERC20(address(hermeticReth)));
        assertGt(quote, 0, "hard-stake quote");
        _dealWeth(address(0xCA11), 10 ether);
        vm.startPrank(address(0xCA11));
        hermeticWeth.approve(seVault, 10 ether);
        uint256 out = seIn.exchangeIn(
            IERC20(address(hermeticWeth)), 10 ether, IERC20(address(hermeticReth)), 0, address(0xCA11), false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out, quote, "hard-stake preview equals execution");
        assertEq(hermeticReth.balanceOf(address(0xCA11)), out, "recipient received the hard-staked rETH");
        assertGt(out, 0, "hard stake produced rETH at a 100% sleeve target");
    }

    /// @dev R14.4: reopen-to-20%-then-sweep bridge. Booked under a 100% target, the excess is swept
    ///      to the 20% band by the next investing operation once the target is lowered.
    function test_APEX_R14_4_reopenTo20Percent_sweepsBookedExcess() public {
        _zeroUsageFees();
        hermeticSettings.setMinimumDeposit(0.01 ether);

        // Book the whole input as sleeve under a 100% target.
        _setVaultTarget(1e18);
        _wethToSe(100 ether, address(this));
        assertEq(rocketPoolSe.liquidReserveEth(), 100 ether, "booked whole input at 100%");
        assertEq(hermeticReth.balanceOf(seVault), 0, "nothing staked at 100%");

        // Lower to 20%; the next investing operation sweeps the booked excess toward the band.
        _setVaultTarget(0.2e18);
        _wethToSe(10 ether, address(0xB0B));
        assertEq(rocketPoolSe.liquidReserveEth(), 22 ether, "swept to the 20% band (0.2 * 110)");
        assertEq(rocketPoolSe.lockedReserveEth(), 88 ether, "88 swept into rETH");
        assertEq(rocketPoolSe.totalReserveEth(), 110 ether, "NAV preserved across the sweep");
        assertApproxEqAbs(rocketPoolSe.actualLiquidReservePercentage(), 0.2e18, 1e12, "actual liquid ~ 20%");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TestBase_UniswapV4UpperLowerWingsStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/test/bases/TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {WingsHandler} from "./WingsHandler.sol";

/// @notice Stateful invariant harness for the UpperLowerWings vault pair. See WingsHandler for the quarantine list.
contract WingsInvariantTest is TestBase_UniswapV4UpperLowerWingsStandardExchangeVault {
    using StateLibrary for IPoolManager;

    WingsHandler internal handler;
    Actor internal externalLp;

    function setUp() public virtual override {
        super.setUp();
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        externalLp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pool, address(this)), keccak256("Apex.p4.extLp")));
        token0.mint(address(externalLp), 1e25); token1.mint(address(externalLp), 1e25);
        externalLp.modify(key, -887220, 887220, int256(uint256(1e18)), bytes32(0)); // baseline external depth (fixed)
        handler = new WingsHandler(pool, key, token0, token1, wings0, wings1);
        handler.seed(1e17);
        require(handler.isClean(), "seed not clean");

        bytes4[] memory s = new bytes4[](15);
        s[0] = WingsHandler.h_deposit.selector;
        s[1] = WingsHandler.h_redeem.selector;
        s[2] = WingsHandler.h_depositExactShares.selector;
        s[3] = WingsHandler.h_redeemExactAssets.selector;
        s[4] = WingsHandler.h_syDeposit.selector;
        s[5] = WingsHandler.h_syRedeem.selector;
        s[6] = WingsHandler.h_routerPushedDeposit.selector;
        s[7] = WingsHandler.k_rebalance.selector;
        s[8] = WingsHandler.warp.selector;
        s[9] = WingsHandler.a_swapRoundTrip.selector;
        s[10] = WingsHandler.a_swapRebalanceRestore.selector;
        s[11] = WingsHandler.a_rebalanceBackrun.selector;
        s[12] = WingsHandler.a_jitSwapRebalanceRestore.selector;
        s[13] = WingsHandler.a_inUnlockView.selector;
        s[14] = WingsHandler.a_donate.selector;
        handler.registerSelectors(s);
        targetSelector(FuzzSelector(address(handler), s));
        targetContract(address(handler));
    }

    /// Single campaign checking every invariant (one function => one campaign, so cost is not multiplied).
    /// forge-config: audit.invariant.show-metrics = true
    /// forge-config: audit.invariant.runs = 64
    /// forge-config: audit.invariant.depth = 50
    function invariant_wings() public view {
        // (0) any handler-recorded violation: liveness, honest no-free-value / NAV dilution, in-unlock depth monotonicity
        assertEq(handler.violations(), 0, handler.firstViolation());
        // (1) clean state between calls (adversary actions are atomic)
        assertTrue(handler.isClean(), "non-clean state between calls");
        for (uint8 vi; vi < 2; ++vi) {
            // (2) valuation bounded: target-total <= V <= target-total + opposing@spot, decomposition matches inventory
            (uint8 code, uint256 x, uint256 y) = handler.valuationCheck(vi);
            if (code != 2) assertEq(code, 0, string.concat("valuation code ", vm.toString(code), " ", vm.toString(x), " ", vm.toString(y)));
            // (3) inventory conservation: balances == booked + donations; shares fully attributed; positions match manager
            (bool ok, string memory why) = handler.conservationCheck(vi);
            assertTrue(ok, why);
        }
        // (4) no free value for the non-holder adversary beyond losses the vault itself accepted on its rebalances
        int256 pnl = handler.advPnL();
        assertLe(pnl, int256(handler.advTolerance()), "adversary extracted value");
    }

    function afterInvariant() public {
        handler.logStats();
        string memory line = handler.statsLine();
        vm.writeLine("apex_p4_wings_stats.txt", line);
        (uint256 ta, uint256 ts) = handler.totals();
        // non-vacuity: most bounded calls must actually execute end-to-end
        if (ta >= 8) assertGe(ts * 100, ta * 60, "vacuous run: <60% of handler calls succeeded");
        // per-selector non-vacuity: no single family may be silently dead (a 0% selector could hide under the aggregate)
        (uint256 pct, bytes4 worst) = handler.worstSelector(6);
        assertGe(pct, 30, string.concat("vacuous selector ", vm.toString(abi.encodePacked(worst))));
    }

    // ------------------------------------------------------------------------------------------------------
    // Sanity: the no-free-value predicate DOES catch the known wings-spot-nav bug when un-quarantined.
    // ------------------------------------------------------------------------------------------------------
    function test_sanity_invariantCatchesKnownSpotNav() public {
        assertLe(handler.advPnL(), int256(handler.advTolerance()), "pre: predicate holds");
        handler.UNSAFE_jitDepositRedeemInUnlock(3e16, 1e22);
        int256 pnl = handler.advPnL();
        console2.log("UNSAFE spot-nav JIT adversary PnL (raw @p0)"); console2.logInt(pnl);
        console2.log("tolerance", handler.advTolerance());
        assertTrue(handler.isClean(), "price untouched / JIT removed");
        assertGt(pnl, int256(handler.advTolerance()), "invariant (4) must flag the known spot-nav extraction");
    }

    /// Sanity 2: valuation/conservation predicates hold on the seeded state and a scripted mixed sequence.
    function test_scriptedSequence() public {
        handler.h_deposit(0, 0, 1e16);
        handler.h_deposit(1, 1, 2e16);
        handler.a_swapRebalanceRestore(0, false, 2e17, 2);
        handler.a_inUnlockView(0, 1e19, true, 3e17);
        handler.a_jitSwapRebalanceRestore(1, 1 + (5 << 8), 1e18, true, 1e17 + 1);
        handler.h_redeem(0, 0, 5000);
        handler.h_redeemExactAssets(1, 1, 3000);
        handler.h_syDeposit(2, 0, 3e15);
        handler.h_syRedeem(2, 0, 10_000);
        handler.h_depositExactShares(2, 1, 1e15);
        handler.h_routerPushedDeposit(0, 1, 1e15);
        handler.a_donate(0, false, 1e12);
        handler.k_rebalance(0);
        handler.a_rebalanceBackrun(1);
        handler.logStats();
        invariant_wings();
    }
}

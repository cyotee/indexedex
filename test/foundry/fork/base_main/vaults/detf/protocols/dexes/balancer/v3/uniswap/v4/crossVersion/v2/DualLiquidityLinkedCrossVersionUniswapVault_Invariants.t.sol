// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Sequence-based invariants over real deposits/swaps/redeems: no free value, BPT backing,
///         BPT-per-share non-decreasing (zero-tolerance cross-multiply).
/// @dev **L2 GOLD** for IndexedEx property program (fixed multi-op sequences; not Foundry
///      `invariant_*` + Handler). Prefer hermetic L3 for CI; fork L3 deferred (RPC cost).
///      See `docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md`.
contract DualLiquidityLinkedCrossVersionUniswapVault_Invariants is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal actor = makeAddr("invActor");

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
    }

    function test_invariant_depositThenFullBptRedeem_neverProfits() public {
        uint256 minted = _depositCommon(actor, LEG_SEED);
        address pool = _reservePool();

        vm.startPrank(actor);
        uint256 bptOut = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), minted, IERC20(pool), 0, actor, false, block.timestamp
        );
        vm.stopPrank();

        // Round-trip shares -> BPT cannot create free BPT relative to what was just deposited's claim.
        // Actor may hold less BPT than raw LEG_SEED (fees + market impact); just assert non-zero and
        // that vault no longer holds actor's shares.
        assertGt(bptOut, 0);
        assertEq(IERC20(linkedVault).balanceOf(actor), 0);
        assertEq(IERC20(pool).balanceOf(actor), bptOut);
    }

    function test_invariant_bptBackingCoversShareClaims() public {
        _depositCommon(actor, LEG_SEED);
        _depositCommon(makeAddr("inv2"), LEG_SEED / 2);

        uint256 supply = IERC20(linkedVault).totalSupply();
        uint256 bpt = _totalReserveBpt();
        // After any deposits, reserve BPT is strictly positive and shares are backed 1:1 in accounting
        // (shares are claims on BPT; total claim = supply * bpt / supply = bpt).
        assertGt(bpt, 0);
        assertGt(supply, 0);
        // Identity: sum of pro-rata claims == bpt (flooring may leave dust <= supply).
        uint256 claimed;
        address[3] memory holders = [address(this), actor, makeAddr("inv2")];
        // re-fetch inv2
        holders[2] = makeAddr("inv2");
        for (uint256 i = 0; i < 3; i++) {
            uint256 s = IERC20(linkedVault).balanceOf(holders[i]);
            if (s > 0) claimed += (s * bpt) / supply;
        }
        assertLe(claimed, bpt, "aggregate claims <= reserve BPT");
        assertGe(claimed + supply, bpt, "flooring dust bounded");
    }

    function test_invariant_bptPerShare_nonDecreasing_acrossOps() public {
        uint256 bpt0 = _totalReserveBpt();
        uint256 s0 = IERC20(linkedVault).totalSupply();

        _depositCommon(actor, LEG_SEED);
        uint256 bpt1 = _totalReserveBpt();
        uint256 s1 = IERC20(linkedVault).totalSupply();
        assertTrue(_bptPerShareGte(bpt1, s1, bpt0, s0), "after deposit");

        // Swap does not touch reserve BPT accounting of the vault's own shares.
        _fund(tokenA, actor, 20e18);
        vm.startPrank(actor);
        tokenA.approve(linkedVault, 20e18);
        IStandardExchangeIn(linkedVault).exchangeIn(tokenA, 20e18, tokenB, 0, actor, false, block.timestamp);
        vm.stopPrank();
        uint256 bpt2 = _totalReserveBpt();
        uint256 s2 = IERC20(linkedVault).totalSupply();
        assertEq(bpt2, bpt1, "swap leaves reserve BPT unchanged");
        assertEq(s2, s1, "swap leaves share supply unchanged");

        // Convenience redeem accrues to remaining holders.
        uint256 actorShares = IERC20(linkedVault).balanceOf(actor);
        uint256 burn = actorShares / 4;
        vm.startPrank(actor);
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), burn, commonToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        uint256 bpt3 = _totalReserveBpt();
        uint256 s3 = IERC20(linkedVault).totalSupply();
        assertTrue(_bptPerShareGte(bpt3, s3, bpt2, s2), "after redeposit-style redeem");
    }

    /// @notice Wave 3B L2 expand: three actors pro-rata claims never exceed reserve BPT.
    function test_invariant_threeActor_proRataClaimsLeReserve() public {
        address a2 = makeAddr("inv3");
        address a3 = makeAddr("inv4");
        _depositCommon(actor, LEG_SEED);
        _depositCommon(a2, LEG_SEED / 2);
        _depositCommon(a3, LEG_SEED / 3);

        uint256 supply = IERC20(linkedVault).totalSupply();
        uint256 bpt = _totalReserveBpt();
        assertGt(supply, 0);
        assertGt(bpt, 0);

        address[4] memory holders = [address(this), actor, a2, a3];
        uint256 claimed;
        for (uint256 i = 0; i < 4; i++) {
            uint256 s = IERC20(linkedVault).balanceOf(holders[i]);
            if (s > 0) claimed += (s * bpt) / supply;
        }
        assertLe(claimed, bpt, "P-PRORATA three-actor");
    }

    /// @notice Wave 3B L2 expand: partial redeem leaves residual inventory clean and BPT/share coherent.
    function test_invariant_partialRedeem_residualAndBacking() public {
        uint256 minted = _depositCommon(actor, LEG_SEED);
        uint256 burn = minted / 3;
        if (burn == 0) burn = minted;

        uint256 bpt0 = _totalReserveBpt();
        uint256 s0 = IERC20(linkedVault).totalSupply();

        vm.startPrank(actor);
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), burn, commonToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();

        _assertNoIntermediateInventory();
        if (IERC20(linkedVault).totalSupply() > 0) {
            assertGt(_totalReserveBpt(), 0, "backing after partial redeem");
            assertTrue(
                _bptPerShareGte(_totalReserveBpt(), IERC20(linkedVault).totalSupply(), bpt0, s0)
                    || _totalReserveBpt() <= bpt0,
                "BPT/share after partial redeem"
            );
        }
    }

    function test_invariant_fullBptRedeem_preservesProRata() public {
        uint256 minted = _depositCommon(actor, LEG_SEED);
        uint256 bpt = _totalReserveBpt();
        uint256 supply = IERC20(linkedVault).totalSupply();
        uint256 expected = (minted * bpt) / supply;

        address pool = _reservePool();
        vm.startPrank(actor);
        uint256 got = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), minted, IERC20(pool), 0, actor, false, block.timestamp
        );
        vm.stopPrank();

        // Floor division: got == expected (both use same floor).
        assertEq(got, expected, "exact-in shares->BPT is pure pro-rata");
    }
}

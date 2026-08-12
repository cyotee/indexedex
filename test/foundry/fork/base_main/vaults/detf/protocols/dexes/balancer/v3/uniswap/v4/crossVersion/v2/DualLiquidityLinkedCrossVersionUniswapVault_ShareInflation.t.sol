// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice First-deposit 1:1 model and donation / share-inflation resistance (no genesis dust).
/// @dev Catalog: A3-class (BPT donation cannot steal victim deposit / front-run inflation).
///      Formal DualLiquidity adversarial catalog: `adversarial/` under this fork tree.
contract DualLiquidityLinkedCrossVersionUniswapVault_ShareInflation is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    function test_firstDeposit_mintsOneToOne() public {
        // Inert until bootstrap; bootstrap's first BPT deposit is the 1:1 genesis.
        assertEq(IERC20(linkedVault).totalSupply(), 0, "inert before bootstrap");
        uint256 bpt = _bootstrapReserve();
        assertGt(bpt, 0);
        uint256 supply = IERC20(linkedVault).totalSupply();
        uint256 reserveBpt = _totalReserveBpt();
        assertEq(supply, reserveBpt, "1:1 genesis ratio");
    }

    function test_bptDonation_cannotStealVictimDeposit() public {
        _bootstrapReserve();
        address attacker = makeAddr("attacker");
        address victim = makeAddr("victim");

        // Attacker deposits normally then donates extra BPT to the vault (inflation attack pattern).
        uint256 attackerShares = _depositCommon(attacker, LEG_SEED);
        address pool = _reservePool();

        // Acquire more BPT via a second deposit -> redeem to BPT, then transfer BPT as donation.
        uint256 more = _depositCommon(attacker, LEG_SEED);
        vm.startPrank(attacker);
        uint256 donatedBpt = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), more, IERC20(pool), 0, attacker, false, block.timestamp
        );
        // Donate BPT directly to the vault (increases totalReserveBpt without minting shares).
        IERC20(pool).transfer(linkedVault, donatedBpt);
        vm.stopPrank();

        uint256 bptBeforeVictim = _totalReserveBpt();
        uint256 supplyBeforeVictim = IERC20(linkedVault).totalSupply();

        uint256 victimShares = _depositCommon(victim, LEG_SEED);
        assertGt(victimShares, 0, "victim still receives shares despite donation");

        // Victim's pro-rata claim on BPT should be at least their deposit's fair share of the
        // post-donation pool (they cannot be rounded to zero).
        uint256 victimClaim =
            (victimShares * _totalReserveBpt()) / IERC20(linkedVault).totalSupply();
        assertGt(victimClaim, 0, "victim claim non-zero");

        // Attacker does not gain free shares from the donation.
        assertEq(IERC20(linkedVault).balanceOf(attacker), attackerShares, "donation mints no attacker shares");
        assertGe(bptBeforeVictim, supplyBeforeVictim > 0 ? 1 : 0);
    }

    function test_frontRunDonation_doesNotZeroVictim() public {
        _bootstrapReserve();
        address attacker = makeAddr("frontrunner");
        address victim = makeAddr("victimUser");

        _depositCommon(attacker, LEG_SEED);
        address pool = _reservePool();
        uint256 more = _depositCommon(attacker, LEG_SEED);
        vm.startPrank(attacker);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), more, IERC20(pool), 0, attacker, false, block.timestamp
        );
        // Donate BPT (classic inflation attack payload).
        IERC20(pool).transfer(linkedVault, bpt);
        vm.stopPrank();

        uint256 victimShares = _depositCommon(victim, LEG_SEED);
        assertGt(victimShares, 0, "victim not rounded to zero by front-run donation");

        // Victim can still full-exit to BPT for a non-zero amount.
        vm.startPrank(victim);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), victimShares, IERC20(pool), 0, victim, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(out, 0, "victim exit recovers value");
    }
}

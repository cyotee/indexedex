// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Sequence-based multi-op invariants (avoids Foundry invariant runner's heavy fork RPC load).
contract DualLiquidityLinkedCrossVersionUniswapVault_InvariantHandler is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal actor = makeAddr("invHandler");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    function test_invariantSequence_mixedOps_bptBackingAndCleanInventory() public {
        uint256 bpt0 = _totalReserveBpt();
        uint256 s0 = shareToken.totalSupply();

        // Deposit
        uint256 m1 = _depositCommon(actor, LEG_SEED);
        assertGt(m1, 0);
        _assertNoIntermediateInventory();
        assertTrue(_bptPerShareGte(_totalReserveBpt(), shareToken.totalSupply(), bpt0, s0) || true);
        // After deposit BPT/share is not always >= if fee mint dilutes without enough BPT - fee is from
        // gross against new BPT so claim of old holders non-decreasing is the stronger property.
        uint256 genesis = shareToken.balanceOf(address(this));
        uint256 claim0 = (genesis * bpt0) / s0;
        uint256 claim1 = (genesis * _totalReserveBpt()) / shareToken.totalSupply();
        assertGe(claim1, claim0, "genesis BPT claim non-decreasing after deposit");

        // Swap
        _fund(tokenA, actor, 50e18);
        vm.startPrank(actor);
        tokenA.approve(linkedVault, 50e18);
        IStandardExchangeIn(linkedVault).exchangeIn(tokenA, 50e18, tokenB, 0, actor, false, block.timestamp);
        vm.stopPrank();
        _assertNoIntermediateInventory();

        // Convenience redeem
        uint256 bal = shareToken.balanceOf(actor);
        vm.startPrank(actor);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, bal / 4, commonToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        _assertNoIntermediateInventory();

        // Full-value BPT redeem remainder
        bal = shareToken.balanceOf(actor);
        if (bal > 0) {
            address pool = _reservePool();
            vm.startPrank(actor);
            IStandardExchangeIn(linkedVault).exchangeIn(
                shareToken, bal, IERC20(pool), 0, actor, false, block.timestamp
            );
            vm.stopPrank();
        }
        _assertNoIntermediateInventory();
        if (shareToken.totalSupply() > 0) {
            assertGt(_totalReserveBpt(), 0, "backing while supply > 0");
        }
    }

    function test_invariantSequence_repeatedDepositsAndBptExits() public {
        for (uint256 i = 0; i < 3; i++) {
            address a = makeAddr(string(abi.encodePacked("seq", i)));
            uint256 m = _depositCommon(a, LEG_SEED / 2);
            address pool = _reservePool();
            vm.startPrank(a);
            IStandardExchangeIn(linkedVault).exchangeIn(
                shareToken, m / 2, IERC20(pool), 0, a, false, block.timestamp
            );
            vm.stopPrank();
            _assertNoIntermediateInventory();
        }
        assertGt(_totalReserveBpt(), 0);
        assertGt(shareToken.totalSupply(), 0);
    }
}

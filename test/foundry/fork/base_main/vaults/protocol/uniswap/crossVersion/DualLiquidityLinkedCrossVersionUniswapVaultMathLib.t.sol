// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    DualLiquidityLinkedCrossVersionUniswapVaultMathLib
} from "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultMathLib.sol";

contract DualLiquidityLinkedCrossVersionUniswapVaultMathLibTest is Test {
    function test_sharesForBpt_proportional() public pure {
        // 100 BPT into a reserve of 1000 BPT backing 2000 shares -> 200 shares
        assertEq(DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt(100e18, 2000e18, 1000e18), 200e18);
    }

    function test_bptForShares_proportional() public pure {
        assertEq(DualLiquidityLinkedCrossVersionUniswapVaultMathLib._bptForShares(200e18, 2000e18, 1000e18), 100e18);
    }

    function test_sharesForBpt_roundsDown() public pure {
        assertEq(DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt(1, 3, 2), 1); // 1*3/2 = 1.5 -> 1
    }

    function test_bptForShares_roundsDown() public pure {
        assertEq(DualLiquidityLinkedCrossVersionUniswapVaultMathLib._bptForShares(1, 3, 2), 0); // 1*2/3 = 0.66 -> 0
    }

    function testFuzz_roundTrip_neverProfits(uint128 bptIn, uint128 totalShares, uint128 totalBpt) public pure {
        vm.assume(totalShares > 0 && totalBpt > 0 && bptIn > 0);
        uint256 shares = DualLiquidityLinkedCrossVersionUniswapVaultMathLib._sharesForBpt(bptIn, totalShares, totalBpt);
        uint256 back = DualLiquidityLinkedCrossVersionUniswapVaultMathLib._bptForShares(shares, totalShares, totalBpt);
        assertLe(back, bptIn); // depositor can never round-trip into free BPT
    }
}

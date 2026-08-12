// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Usage-fee share inflation on deposit routes: fee slice mints to feeTo(); depositor pays;
///         existing holders are not diluted (their share of BPT rises or stays when fee is taken from gross).
contract DualLiquidityLinkedCrossVersionUniswapVault_Fees is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal depositor = makeAddr("feeDepositor");
    uint256 internal constant FEE_WAD = 5e16; // 5%

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        _setUsageFee(FEE_WAD);
    }

    function test_deposit_mintsFeeSharesToFeeTo() public {
        address feeTo = _feeTo();
        uint256 feeBefore = IERC20(linkedVault).balanceOf(feeTo);
        uint256 depBefore = IERC20(linkedVault).balanceOf(depositor);

        uint256 minted = _depositCommon(depositor, LEG_SEED);
        uint256 feeAfter = IERC20(linkedVault).balanceOf(feeTo);

        assertGt(minted, 0, "user received shares");
        assertEq(IERC20(linkedVault).balanceOf(depositor), depBefore + minted, "user balance");
        assertGt(feeAfter, feeBefore, "feeTo accrued fee shares");

        // fee / (user + fee) ~ FEE_WAD on the gross of this deposit (allow rounding).
        uint256 feeDelta = feeAfter - feeBefore;
        uint256 gross = minted + feeDelta;
        uint256 expectedFee = Math.mulDiv(gross, FEE_WAD, 1e18);
        assertEq(feeDelta, expectedFee, "fee split matches DETFUsageFeeLib");
    }

    function test_deposit_existingHoldersNotDiluted() public {
        // Genesis holder = address(this) after bootstrap.
        uint256 genesisShares = IERC20(linkedVault).balanceOf(address(this));
        uint256 bptBefore = _totalReserveBpt();
        uint256 supplyBefore = IERC20(linkedVault).totalSupply();

        _depositCommon(depositor, LEG_SEED);

        uint256 bptAfter = _totalReserveBpt();
        uint256 supplyAfter = IERC20(linkedVault).totalSupply();

        // Genesis still holds the same absolute shares; BPT/share for them is non-decreasing
        // (new BPT entered; fee mint dilutes less than full gross would).
        assertEq(IERC20(linkedVault).balanceOf(address(this)), genesisShares, "no share burn of holders");
        assertTrue(
            _bptPerShareGte(bptAfter, supplyAfter, bptBefore, supplyBefore)
                || bptAfter * supplyBefore >= bptBefore * supplyAfter,
            "reserve backing per share does not worsen vs pre-deposit"
        );
        // Stronger: genesis claim on BPT (pro-rata) should not fall after a fee-paying deposit.
        // pro-rata BPT claim = shares * totalBpt / totalSupply
        uint256 claimBefore = Math.mulDiv(genesisShares, bptBefore, supplyBefore);
        uint256 claimAfter = Math.mulDiv(genesisShares, bptAfter, supplyAfter);
        assertGe(claimAfter, claimBefore, "existing holder BPT claim non-decreasing");
    }

    function test_swap_doesNotMintSharesOrFee() public {
        address feeTo = _feeTo();
        uint256 feeBefore = IERC20(linkedVault).balanceOf(feeTo);
        uint256 supplyBefore = IERC20(linkedVault).totalSupply();

        _fund(tokenA, depositor, 50e18);
        vm.startPrank(depositor);
        tokenA.approve(linkedVault, 50e18);
        IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, 50e18, tokenB, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(IERC20(linkedVault).totalSupply(), supplyBefore, "swap does not mint shares");
        assertEq(IERC20(linkedVault).balanceOf(feeTo), feeBefore, "swap does not mint fee shares");
    }
}

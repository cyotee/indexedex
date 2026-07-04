// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Heavy market skew / imbalance: vault routes still complete and leave no residual inventory.
contract DualLiquidityLinkedCrossVersionUniswapVault_RateExtremes is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal actor = makeAddr("extremeActor");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    function test_rateExtremes_heavySkewA_thenDepositCommon() public {
        // Moderate skew - extreme single-sided V4 pressure can hit leg SPL floors mid-route.
        _skewMarketTowardTokenA(25_000e18);
        uint256 minted = _depositCommon(actor, LEG_SEED);
        assertGt(minted, 0);
        _assertNoIntermediateInventory();
    }

    function test_rateExtremes_heavySkewB_thenDepositTokenA() public {
        _skewMarketTowardTokenB(25_000e18);
        _fund(tokenA, actor, LEG_SEED);
        vm.startPrank(actor);
        tokenA.approve(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, LEG_SEED, shareToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted, 0);
        _assertNoIntermediateInventory();
    }

    function test_rateExtremes_oscillatingSwaps_thenRedeem() public {
        // Push markets back and forth, then redeem.
        for (uint256 i = 0; i < 3; i++) {
            _skewMarketTowardTokenA(20_000e18);
            _skewMarketTowardTokenB(20_000e18);
        }
        uint256 minted = _depositCommon(actor, LEG_SEED);
        address pool = _reservePool();
        vm.startPrank(actor);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 2, IERC20(pool), 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(bpt, 0);
        _assertNoIntermediateInventory();
    }

    function test_rateExtremes_largeDepositAfterSkew_previewMatches() public {
        _skewMarketTowardTokenA(100_000e18);
        _skewMarketTowardTokenB(50_000e18);
        uint256 amount = 5_000e18;
        _fund(commonToken, actor, amount);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, amount, shareToken);
        vm.startPrank(actor);
        commonToken.approve(linkedVault, amount);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, shareToken, 0, actor, false, block.timestamp
        );
        vm.stopPrank();
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop deposit after skew preview ~ execution");
        _assertNoIntermediateInventory();
    }
}

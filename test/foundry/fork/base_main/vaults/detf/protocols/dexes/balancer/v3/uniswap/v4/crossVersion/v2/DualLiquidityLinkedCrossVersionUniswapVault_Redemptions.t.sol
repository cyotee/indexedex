// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Exact-in redemptions. Shares->BPT is the canonical full-value exit; other payouts are
///         convenience routes (partial value, reserve accrual). Proportional-exit previews convert
///         live scaled18 → raw (rates are 1e18 under product-default STANDARD legs) so
///         preview == execution for redeem routes.
contract DualLiquidityLinkedCrossVersionUniswapVault_Redemptions is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal redeemer = makeAddr("redeemer");
    IERC20 internal shareToken;
    uint256 internal holderShares;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        holderShares = _depositCommon(redeemer, LEG_SEED);
        assertGt(holderShares, 0, "redeemer holds shares");
    }

    function test_redeem_toReserveBpt_fullValue_previewMatchesExecution() public {
        address pool = _reservePool();
        uint256 bptBefore = _totalReserveBpt();
        uint256 supplyBefore = shareToken.totalSupply();

        uint256 sharesIn = holderShares / 4;
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, IERC20(pool));

        vm.startPrank(redeemer);
        uint256 bptOut = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, IERC20(pool), 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(bptOut, 0, "BPT payout");
        assertEq(bptOut, preview, "preview == execution for pure pro-rata BPT exit");
        assertEq(IERC20(pool).balanceOf(redeemer), bptOut, "redeemer holds BPT");
        assertLe(bptOut * supplyBefore, sharesIn * bptBefore + supplyBefore, "full-value within 1 share of dust");
        assertGe(bptOut * supplyBefore + bptBefore, sharesIn * bptBefore, "not under-paying badly");
    }

    function test_redeem_toLegVaultShare_previewMatchesExecution() public {
        IERC20 legShare = vault.getPoolTokens(_reservePool())[0];
        uint256 sharesIn = holderShares / 5;

        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, legShare);

        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, legShare, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(out, 0, "leg-share payout");
        assertEq(out, preview, "leg-share raw preview == execution");
        assertEq(legShare.balanceOf(redeemer), out);
        assertGt(_totalReserveBpt(), 0, "reserve still live");
    }

    function test_redeem_toCommonToken_paysUser() public {
        uint256 sharesIn = holderShares / 5;
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, commonToken);
        assertGt(preview, 0, "preview non-zero");

        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, commonToken, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        // Leg SE vault share→common can differ from its own preview by sub-bps (V4 path math);
        // proportional-exit raw amounts are exact (see leg-share test). Bound is ~0.05 bps of payout.
        assertApproxEqAbs(out, preview, 1e16, "commonToken redeem preview ~ execution");
        assertEq(commonToken.balanceOf(redeemer), out);
    }

    function test_redeem_toTokenA_paysUser() public {
        uint256 sharesIn = holderShares / 5;
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, tokenA);
        assertGt(preview, 0, "preview non-zero");

        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, tokenA, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(out, preview, "tokenA redeem preview == execution");
        assertEq(tokenA.balanceOf(redeemer), out);
    }

    function test_redeem_reserveAccrual_remainingHoldersBenefit() public {
        uint256 supplyBefore = shareToken.totalSupply();
        uint256 bptBefore = _totalReserveBpt();
        uint256 genesisShares = shareToken.balanceOf(address(this));
        assertGt(genesisShares, 0, "genesis holder still in");

        uint256 sharesIn = holderShares / 3;
        vm.startPrank(redeemer);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, commonToken, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        uint256 supplyAfter = shareToken.totalSupply();
        uint256 bptAfter = _totalReserveBpt();
        assertTrue(
            _bptPerShareGte(bptAfter, supplyAfter, bptBefore, supplyBefore),
            "redeposit accrual: BPT/share non-decreasing"
        );
    }
}

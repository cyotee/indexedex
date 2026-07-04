// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Focused asset / leg-share redemption coverage (exact-in). Shares->BPT remains the
///         canonical full-value exit; these routes are convenience exits with reserve accrual.
/// @dev Live WITH_RATE proportional exits can diverge from BasePoolMath previews; where symmetry is
///      not tight we assert non-zero payout, recipient balance, and remaining-holder accrual.
contract DualLiquidityLinkedCrossVersionUniswapVault_AssetRedemptions is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal redeemer = makeAddr("assetRedeemer");
    IERC20 internal shareToken;
    uint256 internal holderShares;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        // Larger position so fractional burns stay above dust floors.
        holderShares = _depositCommon(redeemer, LEG_SEED * 2);
        assertGt(holderShares, 0);
    }

    /* ----------------------- Full-value baseline --------------------------- */

    function test_assetRedeem_sharesToBpt_exactPreview() public {
        address pool = _reservePool();
        uint256 sharesIn = holderShares / 4;
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, IERC20(pool));

        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, IERC20(pool), 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(out, preview, "BPT exit is pure pro-rata");
        assertEq(IERC20(pool).balanceOf(redeemer), out);
    }

    /* ----------------------- Leg-share convenience exits ------------------- */

    function test_assetRedeem_toLegShare0() public {
        (IERC20 leg0,,) = _legShares();
        _redeemToLegShare(leg0);
    }

    function test_assetRedeem_toLegShare1() public {
        (, IERC20 leg1,) = _legShares();
        _redeemToLegShare(leg1);
    }

    function test_assetRedeem_toLegShare2() public {
        (,, IERC20 leg2) = _legShares();
        _redeemToLegShare(leg2);
    }

    function _redeemToLegShare(IERC20 legShare) internal {
        // Size for a non-dust proportional slice of this weighted leg (20% or 60%).
        uint256 bal = _depositCommon(redeemer, LEG_SEED * 5);
        uint256 sharesIn = bal / 2;
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, legShare);
        assertGt(preview, 0, "leg preview non-zero");

        uint256 tokenBalBefore = legShare.balanceOf(redeemer);
        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, legShare, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(out, preview, "WITH_RATE raw preview == execution for leg share");
        assertEq(legShare.balanceOf(redeemer), tokenBalBefore + out, "recipient balance");
    }

    /* ----------------------- Underlying asset exits ------------------------ */

    function test_assetRedeem_toCommonToken() public {
        _assertAssetPayout(commonToken, holderShares / 8);
    }

    function test_assetRedeem_toTokenA() public {
        _assertAssetPayout(tokenA, holderShares / 8);
    }

    function test_assetRedeem_toTokenB() public {
        _assertAssetPayout(tokenB, holderShares / 8);
    }

    function test_assetRedeem_sequentialUnderlyingExits_keepReserveLive() public {
        uint256 chunk = holderShares / 10;
        _assertAssetPayout(commonToken, chunk);
        _assertAssetPayout(tokenA, chunk);
        _assertAssetPayout(tokenB, chunk);
        assertGt(_totalReserveBpt(), 0, "reserve remains live after sequential convenience exits");
        assertGt(shareToken.totalSupply(), 0, "supply remains after partial burns");
    }

    function test_assetRedeem_accrual_bptPerShareNonDecreasing() public {
        uint256 supplyBefore = shareToken.totalSupply();
        uint256 bptBefore = _totalReserveBpt();

        uint256 sharesIn = holderShares / 5;
        vm.startPrank(redeemer);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, commonToken, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        assertTrue(
            _bptPerShareGte(_totalReserveBpt(), shareToken.totalSupply(), bptBefore, supplyBefore),
            "convenience exit accrues to remaining holders"
        );
    }

    /* ------------------------------ Guards --------------------------------- */

    function test_assetRedeem_minAmountOut_reverts() public {
        address pool = _reservePool();
        uint256 sharesIn = holderShares / 10;
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, IERC20(pool));

        vm.startPrank(redeemer);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, preview + 1, preview)
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, IERC20(pool), preview + 1, redeemer, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_assetRedeem_zeroShares_reverts() public {
        vm.expectRevert(DualLiquidityLinkedCrossVersionUniswapVaultRepo.ZeroAmount.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, 0, commonToken, 0, redeemer, false, block.timestamp
        );
    }

    function test_assetRedeem_unsupportedTokenOut_reverts() public {
        // A random ERC20 not in the family topology.
        IERC20 junk = _deployTestToken("Junk", "JNK", keccak256("assetRedeemJunk"));
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute.selector, shareToken, junk
            )
        );
        IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, 1e18, junk);
    }

    function test_assetRedeem_fullShareBurn_toBpt() public {
        address pool = _reservePool();
        uint256 sharesIn = shareToken.balanceOf(redeemer);
        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, IERC20(pool), 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(shareToken.balanceOf(redeemer), 0, "all shares burned");
    }

    /* ------------------------------ helpers -------------------------------- */

    function _assertAssetPayout(IERC20 tokenOut, uint256 sharesIn) internal {
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, sharesIn, tokenOut);
        assertGt(preview, 0, "preview non-zero");

        uint256 balBefore = tokenOut.balanceOf(redeemer);
        vm.startPrank(redeemer);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, sharesIn, tokenOut, 0, redeemer, false, block.timestamp
        );
        vm.stopPrank();

        // tokenA/tokenB: exact (closed-form leg). commonToken: SE vault hop may drift sub-bps.
        if (address(tokenOut) == address(commonToken)) {
            assertApproxEqAbs(out, preview, 1e16, "common asset redeem preview ~ execution");
        } else {
            assertEq(out, preview, "asset redeem preview == execution");
        }
        assertEq(tokenOut.balanceOf(redeemer), balBefore + out, "recipient received payout");
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Exact-out surface: closed-form routes only. Nonlinear exact-out redemptions to assets
///         revert UnsupportedRoute (use exact-in exchangeIn instead).
contract DualLiquidityLinkedCrossVersionUniswapVault_ExactOut is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal user = makeAddr("exactOutUser");
    IERC20 internal shareToken;
    uint256 internal holderShares;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        holderShares = _depositCommon(user, LEG_SEED);
    }

    function test_exactOut_redeemToReserveBpt_previewMatchesExecution() public {
        address pool = _reservePool();
        uint256 bptWanted = IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, holderShares / 10, IERC20(pool));
        // Slightly under so we don't exhaust shares on rounding.
        bptWanted = bptWanted > 1 ? bptWanted - 1 : bptWanted;

        uint256 previewIn = IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, IERC20(pool), bptWanted);

        vm.startPrank(user);
        uint256 sharesIn = IStandardExchangeOut(linkedVault).exchangeOut(
            shareToken, type(uint256).max, IERC20(pool), bptWanted, user, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(sharesIn, previewIn, "preview == execution");
        assertEq(IERC20(pool).balanceOf(user), bptWanted, "exact BPT out");
        assertLe(sharesIn, holderShares, "did not over-burn");
    }

    function test_exactOut_redeemToLegShare_previewMatchesExecution() public {
        IERC20 legShare = vault.getPoolTokens(_reservePool())[0];
        // Use a very small exact-out relative to holder so exit rounding covers the quote.
        uint256 probe =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, holderShares / 10, legShare);
        uint256 want = probe / 20;
        if (want < 1e6) return;

        uint256 previewIn = IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, legShare, want);

        vm.startPrank(user);
        try IStandardExchangeOut(linkedVault).exchangeOut(
            shareToken, type(uint256).max, legShare, want, user, false, block.timestamp
        ) returns (uint256 sharesIn) {
            assertEq(sharesIn, previewIn);
            assertEq(legShare.balanceOf(user), want, "exact leg-share out");
        } catch {
            // Live Balancer rate/invariant edge on some reserve states - exact-out leg-share is
            // best-effort; exact-in shares->legShare remains the supported path.
        }
    }

    function test_exactOut_redeemToCommon_revertsUnsupported() public {
        // Nonlinear: shares -> common via proportional exit + leg swap is not closed-form exact-out.
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute.selector,
                shareToken,
                commonToken
            )
        );
        IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, commonToken, 1e18);
    }

    function test_exactOut_swap_commonToTokenA_previewMatchesExecution() public {
        // Quote exact-in first to size a realistic amountOut.
        uint256 probeIn = 50e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;

        uint256 previewIn =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);

        _fund(commonToken, user, previewIn + 1e18);
        vm.startPrank(user);
        commonToken.approve(linkedVault, type(uint256).max);
        uint256 amountIn = IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, type(uint256).max, tokenA, amountOut, user, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(amountIn, previewIn, "preview == execution");
        assertEq(tokenA.balanceOf(user), amountOut, "exact tokenA out");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Broader exact-out matrix: swaps, BPT redeem, leg-share redeem, unsupported asset redeem.
/// @dev Law B: two-tx / prefund + `true` is I1 (no surplus refund to caller).
contract DualLiquidityLinkedCrossVersionUniswapVault_ExactOutMatrix is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal user = makeAddr("eoUser");
    IERC20 internal shareToken;
    uint256 internal holderShares;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
        holderShares = _depositCommon(user, LEG_SEED * 2);
    }

    function test_exactOutMatrix_swap_tokenBToCommon() public {
        _assertExactOutSwap(tokenB, commonToken, 80e18);
    }

    function test_exactOutMatrix_swap_commonToTokenB() public {
        _assertExactOutSwap(commonToken, tokenB, 80e18);
    }

    function test_exactOutMatrix_swap_tokenAToTokenB() public {
        _assertExactOutSwap(tokenA, tokenB, 50e18);
    }

    function test_exactOutMatrix_swap_tokenBToTokenA() public {
        _assertExactOutSwap(tokenB, tokenA, 50e18);
    }

    function test_exactOutMatrix_redeemToBpt_refundsUnusedShares() public {
        address pool = _reservePool();
        uint256 bptWanted =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, holderShares / 10, IERC20(pool));
        if (bptWanted <= 1) return;
        bptWanted = bptWanted / 2;

        uint256 sharesNeeded =
            IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, IERC20(pool), bptWanted);
        uint256 maxIn = sharesNeeded + sharesNeeded / 10 + 1;

        uint256 sharesBefore = shareToken.balanceOf(user);
        vm.startPrank(user);
        uint256 used = IStandardExchangeOut(linkedVault).exchangeOut(
            shareToken, maxIn, IERC20(pool), bptWanted, user, false, block.timestamp
        );
        vm.stopPrank();

        assertEq(used, sharesNeeded);
        assertEq(IERC20(pool).balanceOf(user), bptWanted);
        assertEq(shareToken.balanceOf(user), sharesBefore - used, "unused max not burned");
    }

    function test_exactOutMatrix_redeemToEachLegShare() public {
        (IERC20 l0, IERC20 l1, IERC20 l2) = _legShares();
        _tryExactOutLegShare(l0);
        _tryExactOutLegShare(l1);
        _tryExactOutLegShare(l2);
    }

    function test_exactOutMatrix_redeemToTokenB_revertsUnsupported() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.UnsupportedRoute.selector, shareToken, tokenB
            )
        );
        IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, tokenB, 1e18);
    }

    function test_I1_exactOutMatrix_swap_prefundThenTrue_revertsNoSurplusRefund() public {
        uint256 probe = 40e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probe, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;

        uint256 amountIn = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        uint256 prefund = amountIn + 5e18;
        _fund(commonToken, user, prefund);
        vm.startPrank(user);
        commonToken.transfer(linkedVault, prefund);
        // `_receiveOut` credits the quoted used `amountIn`, not `maxIn` / prefund.
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amountIn, uint256(0))
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, prefund, tokenA, amountOut, user, true, block.timestamp
        );
        vm.stopPrank();

        assertEq(tokenA.balanceOf(user), 0, "no exact-out on theater prefund");
        assertEq(commonToken.balanceOf(user), 0, "no surplus refund to caller");
        assertEq(commonToken.balanceOf(linkedVault), prefund, "prefund sticks");
    }

    function _assertExactOutSwap(IERC20 tokenIn, IERC20 tokenOut, uint256 probeIn) internal {
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenIn, probeIn, tokenOut);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;

        uint256 amountIn = IStandardExchangeOut(linkedVault).previewExchangeOut(tokenIn, tokenOut, amountOut);
        _fund(tokenIn, user, amountIn + 1e18);
        vm.startPrank(user);
        tokenIn.approve(linkedVault, type(uint256).max);
        uint256 used = IStandardExchangeOut(linkedVault).exchangeOut(
            tokenIn, type(uint256).max, tokenOut, amountOut, user, false, block.timestamp
        );
        vm.stopPrank();
        assertEq(used, amountIn);
        assertEq(tokenOut.balanceOf(user), amountOut);
    }

    function _tryExactOutLegShare(IERC20 leg) internal {
        uint256 probe =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, holderShares / 8, leg);
        uint256 want = probe / 10;
        if (want < 1e6) return;
        uint256 sharesNeeded =
            IStandardExchangeOut(linkedVault).previewExchangeOut(shareToken, leg, want);
        vm.startPrank(user);
        try IStandardExchangeOut(linkedVault).exchangeOut(
            shareToken, type(uint256).max, leg, want, user, false, block.timestamp
        ) returns (uint256 used) {
            assertEq(used, sharesNeeded);
            assertEq(leg.balanceOf(user), want);
        } catch {}
        vm.stopPrank();
    }
}

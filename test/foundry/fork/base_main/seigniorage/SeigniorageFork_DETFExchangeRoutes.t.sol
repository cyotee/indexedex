// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// Crane IERC20 imported below

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_SeigniorageDETF_Fork} from "test/foundry/fork/base_main/seigniorage/TestBase_SeigniorageDETF_Fork.sol";

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ISeigniorageDETFUnderwriting} from "contracts/vaults/seigniorage/SeigniorageDETFUnderwritingTarget.sol";

contract SeigniorageFork_DETFExchangeRoutes is TestBase_SeigniorageDETF_Fork {
    function setUp() public override {
        super.setUp();

        // Ensure pool exists with some initial liquidity.
        IERC20 reserveAsset = _reserveAsset();
        uint256 assetIn = _mintReserveAssetTo(alice, UNDERWRITE_AMOUNT);

        vm.startPrank(alice);
        reserveAsset.approve(address(detf), assetIn);
        detf.underwrite(reserveAsset, assetIn, LOCK_DURATION, alice, false);
        vm.stopPrank();
    }

    function testFork_ExchangeIn_RevertsWhenBelowPeg() public {
        // Step 1: Acquire reserve vault shares.
        uint256 shares = _mintReserveVaultSharesTo(alice, UNDERWRITE_AMOUNT);
        assertGt(shares, 0, "No reserve vault shares");

        // Step 2: Push above peg by buying RBT with reserve vault shares.
        _approvePermit2ToSeRouter(alice, address(_reserveVaultShares()));
        vm.startPrank(alice);
        _swapExactInChunked(
            reservePoolAddress, _reserveVaultShares(), _noVault(), IERC20(address(detf)), _noVault(), shares / 2, 0, 8
        );
        vm.stopPrank();

        // Step 3: Mint additional RBT via the reserve->RBT exchange route (requires above peg).
        vm.startPrank(alice);
        _reserveVaultShares().approve(address(detf), type(uint256).max);
        IStandardExchangeIn(address(detf))
            .exchangeIn(
                IERC20(address(_reserveVaultShares())),
                shares / 4,
                IERC20(address(detf)),
                0,
                alice,
                false,
                block.timestamp + 1 hours
            );
        vm.stopPrank();

        // Step 4: Dump all RBT into the pool to drain reserves and drive price below peg.
        uint256 rbtBal = IERC20(address(detf)).balanceOf(alice);
        assertGt(rbtBal, 0, "No RBT to dump");

        _approvePermit2ToSeRouter(alice, address(detf));
        vm.startPrank(alice);
        _swapExactInChunked(
            reservePoolAddress, IERC20(address(detf)), _noVault(), _reserveVaultShares(), _noVault(), rbtBal, 0, 20
        );

        IERC20 srbt = detf.seigniorageToken();

        // Step 5: If we didn't cross the peg yet, keep dumping in small chunks until we do.
        // (Balancer weighted pools enforce MaxInRatio, so we prefer many small swaps.)
        uint256 dumpTries = 0;
        while (!_previewRbtToSrbtReverts(srbt) && dumpTries < 25) {
            dumpTries++;

            // Top-up RBT so we can continue pushing price down.
            // Note: using `deal` is test-only; the objective is to exercise the live Balancer/Aerodrome path.
            uint256 topUp = 250e18;
            deal(address(detf), alice, IERC20(address(detf)).balanceOf(alice) + topUp);

            _swapExactInChunked(
                reservePoolAddress, IERC20(address(detf)), _noVault(), _reserveVaultShares(), _noVault(), topUp, 0, 50
            );
        }

        assertTrue(_previewRbtToSrbtReverts(srbt), "Failed to drive below peg");

        // Below peg (or at peg), RBT -> sRBT preview should revert.
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).previewExchangeIn(IERC20(address(detf)), 1e18, srbt);
        vm.stopPrank();
    }

    function _previewRbtToSrbtReverts(IERC20 srbt) internal view returns (bool) {
        try IStandardExchangeIn(address(detf)).previewExchangeIn(IERC20(address(detf)), 1e18, srbt) returns (uint256) {
            return false;
        } catch {
            return true;
        }
    }

    function _swapExactInChunked(
        address pool,
        IERC20 tokenIn,
        IStandardExchangeProxy tokenInVault,
        IERC20 tokenOut,
        IStandardExchangeProxy tokenOutVault,
        uint256 amountInTotal,
        uint256 minAmountOut,
        uint256 chunks
    ) internal {
        require(chunks > 0, "chunks=0");

        uint256 remaining = amountInTotal;
        uint256 chunkSize = (amountInTotal + chunks - 1) / chunks;

        while (remaining > 0) {
            uint256 amountIn = remaining < chunkSize ? remaining : chunkSize;
            remaining -= amountIn;

            _swapExactIn(pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amountIn, minAmountOut);
        }
    }

    function testFork_ExchangeIn_SucceedsWhenAbovePeg() public {
        // Mint reserve vault shares to alice and buy RBT to push price above peg.
        uint256 shares = _mintReserveVaultSharesTo(alice, UNDERWRITE_AMOUNT);
        assertGt(shares, 0, "No reserve vault shares");

        // Push price above peg by buying RBT with reserve vault shares.
        _approvePermit2ToSeRouter(alice, address(_reserveVaultShares()));
        vm.startPrank(alice);
        _swapExactIn(
            reservePoolAddress, _reserveVaultShares(), _noVault(), IERC20(address(detf)), _noVault(), shares / 4, 0
        );
        vm.stopPrank();

        uint256 rbtBal = IERC20(address(detf)).balanceOf(alice);
        assertGt(rbtBal, 0, "No RBT after buy");

        vm.startPrank(alice);
        IERC20(address(detf)).approve(address(detf), type(uint256).max);

        uint256 previewOut =
            IStandardExchangeIn(address(detf)).previewExchangeIn(IERC20(address(detf)), 1e18, detf.seigniorageToken());
        assertGt(previewOut, 0, "Preview out is 0");

        uint256 out = IStandardExchangeIn(address(detf))
            .exchangeIn(
                IERC20(address(detf)), 1e18, detf.seigniorageToken(), 0, alice, false, block.timestamp + 1 hours
            );
        assertEq(out, previewOut, "Exchange out mismatch");
        vm.stopPrank();
    }

    function _mintReserveVaultSharesTo(address user, uint256 tokenAmount) internal returns (uint256 sharesOut) {
        uint256 liquidity = _mintReserveAssetTo(user, tokenAmount);
        require(liquidity > 0, "No LP minted");

        vm.startPrank(user);
        _reserveAsset().approve(address(daiUsdcVault), type(uint256).max);
        sharesOut = daiUsdcVault.deposit(liquidity, user);
        vm.stopPrank();
    }
}

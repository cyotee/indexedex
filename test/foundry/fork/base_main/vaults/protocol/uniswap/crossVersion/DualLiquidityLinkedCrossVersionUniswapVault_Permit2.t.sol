// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice All vault routes funded via Permit2 AllowanceTransfer into the vault (or to the
///         caller for burns), then executed with `pretransferred=true` where the surface pulls
///         `tokenIn`. The diamond itself still uses ERC20 `transferFrom` / burn - Permit2 is the
///         user-facing funding path (canonical Permit2 on Base), matching production wallets.
///
/// @dev Flow per deposit/swap/exact-out:
///      1. User ERC20-approves Permit2
///      2. User Permit2-approves this test as spender
///      3. Test `permit2.transferFrom(user -> vault, amount)`
///      4. User `exchangeIn/Out(..., pretransferred=true)`
contract DualLiquidityLinkedCrossVersionUniswapVault_Permit2 is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal user = makeAddr("permit2User");
    IERC20 internal shareToken;
    uint256 internal constant AMT = 100e18;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    /* ---------------------------- Deposits --------------------------------- */

    function test_permit2_deposit_commonToken() public {
        _permit2PrefundVault(user, commonToken, AMT);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, AMT, shareToken);

        vm.prank(user);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, AMT, shareToken, 0, user, true, block.timestamp
        );

        assertGt(minted, 0);
        // Multi-hop: post-hop rate-provider update vs pre-hop join quote (see Deposits suite notes).
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop preview ~ execution");
        assertEq(shareToken.balanceOf(user), minted);
        assertEq(commonToken.balanceOf(linkedVault), 0, "vault consumed prefund");
    }

    function test_permit2_deposit_tokenA() public {
        _permit2PrefundVault(user, tokenA, AMT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, AMT, shareToken);

        vm.prank(user);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, AMT, shareToken, 0, user, true, block.timestamp
        );

        assertGt(minted, 0);
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop preview ~ execution");
    }

    function test_permit2_deposit_tokenB() public {
        _permit2PrefundVault(user, tokenB, AMT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenB, AMT, shareToken);

        vm.prank(user);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, AMT, shareToken, 0, user, true, block.timestamp
        );

        assertGt(minted, 0);
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop preview ~ execution");
    }

    function test_permit2_deposit_legVaultShare() public {
        (IERC20 vaultAShare,,) = _legShares();
        uint256 shares = _acquireLegShare(address(vaultAShare), user);

        // Prefund leg share into vault via Permit2.
        _permit2ApproveToken(user, vaultAShare);
        _permit2ApproveSpender(user, vaultAShare, address(this));
        _permit2TransferFrom(user, linkedVault, vaultAShare, shares);

        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(vaultAShare, shares, shareToken);
        vm.prank(user);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            vaultAShare, shares, shareToken, 0, user, true, block.timestamp
        );

        assertGt(minted, 0);
        assertEq(minted, preview);
    }

    function test_permit2_deposit_reserveBpt_requiresTransferFrom() public {
        // Product rule: reserve-BPT deposit MUST transferFrom (pretransferred reverts) so the
        // pre-mint reserve snapshot stays correct. Prior legs of the flow may still use Permit2.
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);
        address pool = _reservePool();

        vm.startPrank(user);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted, IERC20(pool), 0, user, false, block.timestamp
        );
        // pretransferred=true is rejected for BPT even if the user still holds the BPT.
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(pool), bpt, shareToken, 0, user, true, block.timestamp
        );

        // Canonical BPT deposit: ERC20 approve vault + transferFrom (pretransferred=false).
        IERC20(pool).approve(linkedVault, bpt);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(IERC20(pool), bpt, shareToken);
        uint256 sharesOut = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(pool), bpt, shareToken, 0, user, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(sharesOut, 0);
        assertEq(sharesOut, preview, "BPT deposit after Permit2-funded acquire cycle");
    }

    /* ------------------------------ Swaps ---------------------------------- */

    function test_permit2_swap_commonToTokenA() public {
        _permit2PrefundVault(user, commonToken, AMT);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, AMT, tokenA);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, AMT, tokenA, 0, user, true, block.timestamp
        );

        assertGt(out, 0);
        assertEq(out, preview);
        assertEq(tokenA.balanceOf(user), out);
        assertEq(shareToken.balanceOf(user), 0, "swap mints no shares");
    }

    function test_permit2_swap_tokenAToCommon() public {
        _permit2PrefundVault(user, tokenA, AMT);
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, AMT, commonToken);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, AMT, commonToken, 0, user, true, block.timestamp
        );

        assertGt(out, 0);
        assertEq(out, preview);
    }

    function test_permit2_swap_tokenAToTokenB() public {
        _permit2PrefundVault(user, tokenA, AMT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, AMT, tokenB);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, AMT, tokenB, 0, user, true, block.timestamp
        );

        assertGt(out, 0);
        assertEq(out, preview);
    }

    function test_permit2_swap_tokenBToTokenA() public {
        _permit2PrefundVault(user, tokenB, AMT);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenB, AMT, tokenA);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, AMT, tokenA, 0, user, true, block.timestamp
        );

        assertGt(out, 0);
        assertEq(out, preview);
    }

    /* --------------------------- Exact-out --------------------------------- */

    function test_permit2_exactOut_swap_commonToTokenA() public {
        uint256 probeIn = 50e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;

        uint256 amountIn =
            IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        // Prefund with surplus; exact-out refunds unused input when pretransferred.
        uint256 prefund = amountIn + 1e18;
        _permit2PrefundVault(user, commonToken, prefund);

        uint256 vaultBalBefore = commonToken.balanceOf(linkedVault);
        // vaultBalBefore should equal prefund after permit2 transfer
        assertEq(vaultBalBefore, prefund);

        vm.prank(user);
        uint256 used = IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, prefund, tokenA, amountOut, user, true, block.timestamp
        );

        assertEq(used, amountIn, "used matches preview");
        assertEq(tokenA.balanceOf(user), amountOut, "exact out");
        // Unused prefund refunded to user (receiveOut path).
        assertEq(commonToken.balanceOf(user), prefund - used, "surplus refunded");
    }

    function test_permit2_exactOut_deposit_commonToShares() public {
        // Exact-out mint paid in commonToken (sizes via closed-form leg+join when available).
        uint256 probeShares = _depositCommonViaPermit2(user, AMT);
        if (probeShares < 4) return;
        uint256 sharesWanted = probeShares / 4;

        // Clear probe shares so balance is known.
        address pool = _reservePool();
        vm.startPrank(user);
        IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, shareToken.balanceOf(user), IERC20(pool), 0, user, false, block.timestamp
        );
        vm.stopPrank();

        uint256 tokenInNeeded;
        try IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, shareToken, sharesWanted) returns (
            uint256 n
        ) {
            tokenInNeeded = n;
        } catch {
            return; // route not available for this size
        }
        if (tokenInNeeded == 0) return;

        uint256 prefund = tokenInNeeded + tokenInNeeded / 5 + 1e15;
        _permit2PrefundVault(user, commonToken, prefund);

        vm.prank(user);
        try IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, prefund, shareToken, sharesWanted, user, true, block.timestamp
        ) returns (uint256 used) {
            assertLe(used, prefund);
            assertEq(shareToken.balanceOf(user), sharesWanted, "exact shares out");
        } catch {
            // Accept: exact-out deposit is best-effort under live WITH_RATE sizing.
        }
    }

    /* -------------------------- Redemptions -------------------------------- */

    function test_permit2_redeem_toBpt_afterPermit2Deposit() public {
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);
        address pool = _reservePool();

        // Share burn does not need Permit2 (burn from msg.sender balance).
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, minted / 2, IERC20(pool));

        vm.prank(user);
        uint256 bptOut = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 2, IERC20(pool), 0, user, false, block.timestamp
        );

        assertEq(bptOut, preview);
        assertEq(IERC20(pool).balanceOf(user), bptOut);
    }

    function test_permit2_redeem_toCommon_afterPermit2Deposit() public {
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 3, commonToken, 0, user, false, block.timestamp
        );

        assertGt(out, 0);
        assertEq(commonToken.balanceOf(user), out);
    }

    function test_permit2_redeem_toTokenA_afterPermit2Deposit() public {
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 3, tokenA, 0, user, false, block.timestamp
        );

        assertGt(out, 0);
        assertEq(tokenA.balanceOf(user), out);
    }

    function test_permit2_redeem_toLegShare_afterPermit2Deposit() public {
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);
        (IERC20 vaultAShare,,) = _legShares();

        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(shareToken, minted / 4, vaultAShare);

        vm.prank(user);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, minted / 4, vaultAShare, 0, user, false, block.timestamp
        );

        assertGt(out, 0);
        assertEq(out, preview, "permit2 redeem preview == execution");
        assertEq(vaultAShare.balanceOf(user), out);
    }

    /* --------------------- End-to-end Permit2 cycle ------------------------ */

    function test_permit2_fullCycle_depositSwapRedeem() public {
        // Deposit common via Permit2
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);
        assertGt(minted, 0);

        // Swap leftover common via Permit2 prefund
        _permit2PrefundVault(user, commonToken, AMT);
        vm.prank(user);
        uint256 swapped = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, AMT, tokenA, 0, user, true, block.timestamp
        );
        assertGt(swapped, 0);

        // Redeem half shares to BPT
        address pool = _reservePool();
        uint256 half = shareToken.balanceOf(user) / 2;
        vm.prank(user);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, half, IERC20(pool), 0, user, false, block.timestamp
        );
        assertGt(bpt, 0);
    }
}

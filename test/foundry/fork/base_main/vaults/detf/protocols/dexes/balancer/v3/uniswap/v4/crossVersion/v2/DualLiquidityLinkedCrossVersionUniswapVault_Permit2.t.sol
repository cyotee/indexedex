// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Permit2 funding vs DualLiquidity same-tx receive (law **B**).
/// @dev Prefund into the diamond then `pretransferred=true` **reverts** `TransferDeltaInsufficient`.
///      Happy redeem paths after an honest `!pretransferred` pull still run. Surplus is **not**
///      refunded to the caller (`held − amountIn` theft class is closed).
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

    function test_I1_permit2_deposit_commonToken_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, commonToken, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, AMT, shareToken, 0, user, true, block.timestamp
        );
        assertEq(shareToken.balanceOf(user), 0, "Permit2-true must not mint");
        assertEq(commonToken.balanceOf(linkedVault), AMT, "prefund sticks");
    }

    function test_I1_permit2_deposit_tokenA_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, tokenA, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(tokenA, AMT, shareToken, 0, user, true, block.timestamp);
        assertEq(shareToken.balanceOf(user), 0);
    }

    function test_I1_permit2_deposit_tokenB_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, tokenB, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(tokenB, AMT, shareToken, 0, user, true, block.timestamp);
        assertEq(shareToken.balanceOf(user), 0);
    }

    function test_I1_permit2_deposit_legVaultShare_prefundThenTrue_reverts() public {
        (IERC20 vaultAShare,,) = _legShares();
        uint256 shares = _acquireLegShare(address(vaultAShare), user);

        _permit2ApproveToken(user, vaultAShare);
        _permit2ApproveSpender(user, vaultAShare, address(this));
        _permit2TransferFrom(user, linkedVault, vaultAShare, shares);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            vaultAShare, shares, shareToken, 0, user, true, block.timestamp
        );
        assertEq(shareToken.balanceOf(user), 0);
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

    function test_I1_permit2_swap_commonToTokenA_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, commonToken, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(commonToken, AMT, tokenA, 0, user, true, block.timestamp);
        assertEq(tokenA.balanceOf(user), 0);
    }

    function test_I1_permit2_swap_tokenAToCommon_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, tokenA, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(tokenA, AMT, commonToken, 0, user, true, block.timestamp);
    }

    function test_I1_permit2_swap_tokenAToTokenB_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, tokenA, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(tokenA, AMT, tokenB, 0, user, true, block.timestamp);
    }

    function test_I1_permit2_swap_tokenBToTokenA_prefundThenTrue_reverts() public {
        _permit2PrefundVault(user, tokenB, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(tokenB, AMT, tokenA, 0, user, true, block.timestamp);
    }

    /* --------------------------- Exact-out --------------------------------- */

    function test_I1_permit2_exactOut_swap_prefundThenTrue_revertsNoSurplusRefund() public {
        uint256 probeIn = 50e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) return;

        uint256 amountIn = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        uint256 prefund = amountIn + 1e18;
        _permit2PrefundVault(user, commonToken, prefund);
        assertEq(commonToken.balanceOf(linkedVault), prefund);

        uint256 userBefore = commonToken.balanceOf(user);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, amountIn, uint256(0))
        );
        IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, prefund, tokenA, amountOut, user, true, block.timestamp
        );
        assertEq(tokenA.balanceOf(user), 0, "no exact-out on theater prefund");
        assertEq(commonToken.balanceOf(user), userBefore, "no surplus refund to caller");
        assertEq(commonToken.balanceOf(linkedVault), prefund, "prefund not refunded");
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
        uint256 minted = _depositCommonViaPermit2(user, LEG_SEED);
        assertGt(minted, 0);

        // Law B: prefund + true is I1, not a happy swap.
        _permit2PrefundVault(user, commonToken, AMT);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, AMT, uint256(0))
        );
        IStandardExchangeIn(linkedVault).exchangeIn(commonToken, AMT, tokenA, 0, user, true, block.timestamp);

        address pool = _reservePool();
        uint256 half = shareToken.balanceOf(user) / 2;
        vm.prank(user);
        uint256 bpt = IStandardExchangeIn(linkedVault).exchangeIn(
            shareToken, half, IERC20(pool), 0, user, false, block.timestamp
        );
        assertGt(bpt, 0);
    }
}

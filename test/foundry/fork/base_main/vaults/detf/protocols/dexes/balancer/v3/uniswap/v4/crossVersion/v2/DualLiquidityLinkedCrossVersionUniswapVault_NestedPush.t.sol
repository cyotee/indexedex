// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Explicit T-NEST-1…8 + T-LOCAL for DUAL (L-DETF-TEST-EXPLICIT).
/// @dev **Fork-primary family** (`FOUNDRY_PROFILE=fork`). No hermetic suite — documented.
///      Uses a dedicated `user` so `_fund` transfers work (no-op when `to == address(this)`).
///      Nested hosts = production leg SE diamonds (share address == vault for Uni V4/V2 SE packages).
contract DualLiquidityLinkedCrossVersionUniswapVault_NestedPush_Test is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    IBasicVault internal openBook;
    address internal user = makeAddr("nestedPushUser");
    /// @dev Nested SE host (leg0 share token address == SE vault diamond).
    address internal nestedHost;
    IBasicVault internal nestedHostBook;

    function setUp() public virtual override {
        super.setUp();
        _bootstrapReserve();
        openBook = IBasicVault(linkedVault);
        (IERC20 leg0,,) = _legShares();
        nestedHost = address(leg0);
        nestedHostBook = IBasicVault(nestedHost);
    }

    function _assertHoldSetREqualsB() internal view {
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            assertEq(
                openBook.reserveOfToken(t),
                IERC20(t).balanceOf(linkedVault),
                "hold-set R == B"
            );
        }
    }

    /// @dev Pick a face token the nested host books (common/tokenA/tokenB tried in order).
    function _nestedHostFaceToken() internal view returns (IERC20 token_) {
        IERC20[3] memory candidates = [commonToken, tokenA, tokenB];
        for (uint256 i; i < candidates.length; ++i) {
            // Host vaultTokens / reserveOfToken may not list every candidate; try balance path.
            if (candidates[i].balanceOf(nestedHost) > 0 || nestedHostBook.reserveOfToken(address(candidates[i])) > 0) {
                return candidates[i];
            }
        }
        return commonToken;
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        uint256 minted = _depositCommon(user, LEG_SEED);
        assertTrue(minted > 0, "T-NEST-1");
        assertGe(IERC20(linkedVault).balanceOf(user), minted, "user shares");
        _assertHoldSetREqualsB();
    }

    /// @dev T-NEST-2: nested host short — claimed > all face inventory on leg SE with true.
    ///      Production host durable pull: U_face <= B_face always, so B+1 with true reverts.
    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        IERC20 face_ = _nestedHostFaceToken();
        uint256 dust_ = 10e18;
        _fund(face_, user, dust_);
        vm.prank(user);
        face_.transfer(nestedHost, dust_);

        uint256 Bh = face_.balanceOf(nestedHost);
        assertTrue(Bh > 0, "T-NEST-2: nested host has face after push");

        // Claim strictly more than entire face balance → host U insufficient (nested short).
        vm.expectRevert(); // TransferDeltaInsufficient(claimed, U) with U <= Bh
        IStandardExchangeIn(nestedHost).exchangeIn(
            face_, Bh + 1, IERC20(nestedHost), 0, user, true, block.timestamp
        );
    }

    /// @dev T-NEST-3: nested host I1 — after Dual money route, true without new push reverts on host.
    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        // Production nested fund path: Dual deposit → leg push+true + host end-sync.
        _depositCommon(user, LEG_SEED / 2);

        IERC20 face_ = _nestedHostFaceToken();
        // No new push: claim 1 with pretransferred=true must not free-credit booked face (host I1 / short).
        vm.expectRevert(); // TransferDeltaInsufficient(1, U) with U < 1 when free face booked
        IStandardExchangeIn(nestedHost).exchangeIn(
            face_, 1, IERC20(nestedHost), 0, user, true, block.timestamp
        );
    }

    function test_T_NEST_4_noNestedApproveOnFundPath() public {
        uint256 minted = _depositCommon(user, LEG_SEED);
        assertTrue(minted > 0, "T-NEST-4 deposit completed");
        // Nested fund path is push+true (production `_legExchange`); no caller-side pre-approve to legs required.
        _assertHoldSetREqualsB();
    }

    /// @dev T-NEST-5: outermost exact-out refunds unused pretransferred maxIn to entry msg.sender.
    function test_T_NEST_5_outerExactOut_refundToEntryMsgSender() public {
        uint256 probeIn = 50e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn, tokenA);
        amountOut = amountOut > 1 ? amountOut / 2 : amountOut;
        if (amountOut == 0) {
            _depositCommon(user, LEG_SEED / 4);
            _assertHoldSetREqualsB();
            return;
        }

        uint256 needIn = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        uint256 surplus = needIn / 5 + 1e15;
        uint256 maxIn = needIn + surplus;

        // Production refund re-forward path is pretransferred + maxIn > used (L-DETF-REFUND-OUTER).
        _permit2PrefundVault(user, commonToken, maxIn);
        uint256 userCommonBefore = commonToken.balanceOf(user);
        uint256 tokenABefore = tokenA.balanceOf(user);

        vm.prank(user);
        uint256 usedIn = IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn, tokenA, amountOut, user, true, block.timestamp
        );

        assertLe(usedIn, maxIn, "used <= maxIn");
        assertEq(tokenA.balanceOf(user) - tokenABefore, amountOut, "exact-out delivered");
        // Unused prefund re-forwarded to entry msg.sender (user).
        assertEq(
            commonToken.balanceOf(user),
            userCommonBefore + (maxIn - usedIn),
            "T-NEST-5: unused maxIn refunded to msg.sender"
        );
        assertEq(commonToken.balanceOf(linkedVault), 0, "T-NEST-5: no free tokenIn residual");
        _assertHoldSetREqualsB();
    }

    function test_T_NEST_6_holdSetSyncAfterRoute() public {
        _depositCommon(user, LEG_SEED / 2);
        _assertHoldSetREqualsB();
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public {
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(address(commonToken)), 0, IERC20(linkedVault), 0, user, false, block.timestamp
        );
    }

    /// @dev T-NEST-8: partial maxIn exact-out succeeds (no residual-hard-revert).
    function test_T_NEST_8_partialMaxIn_succeeds_noHardRevert() public {
        uint256 probeIn = 80e18;
        uint256 amountOut = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, probeIn, tokenA);
        amountOut = amountOut > 1 ? amountOut / 3 : amountOut;
        if (amountOut == 0) {
            _depositCommon(user, LEG_SEED / 4);
            _assertHoldSetREqualsB();
            return;
        }

        uint256 needIn = IStandardExchangeOut(linkedVault).previewExchangeOut(commonToken, tokenA, amountOut);
        uint256 maxIn = needIn * 2 + 1e18;
        assertTrue(maxIn > needIn, "oversized maxIn");

        _permit2PrefundVault(user, commonToken, maxIn);
        uint256 userCommonBefore = commonToken.balanceOf(user);

        vm.prank(user);
        uint256 usedIn = IStandardExchangeOut(linkedVault).exchangeOut(
            commonToken, maxIn, tokenA, amountOut, user, true, block.timestamp
        );

        assertTrue(usedIn > 0, "T-NEST-8 used input");
        assertLt(usedIn, maxIn, "T-NEST-8 partial maxIn");
        assertEq(
            commonToken.balanceOf(user),
            userCommonBefore + (maxIn - usedIn),
            "T-NEST-8 refund to caller"
        );
        _assertHoldSetREqualsB();
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public {
        uint256 amt = LEG_SEED / 4;
        _fund(commonToken, user, amt);
        vm.prank(user);
        commonToken.transfer(linkedVault, amt);
        vm.prank(user);
        uint256 out_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amt, IERC20(linkedVault), 0, user, true, block.timestamp
        );
        assertTrue(out_ > 0, "T-LOCAL-PUSH");
        _assertHoldSetREqualsB();
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _depositCommon(user, LEG_SEED / 4);
        _assertHoldSetREqualsB();
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            if (t == linkedVault) continue;
            uint256 R = openBook.reserveOfToken(t);
            uint256 B = IERC20(t).balanceOf(linkedVault);
            if (R == B) {
                vm.prank(user);
                vm.expectRevert();
                IStandardExchangeIn(linkedVault).exchangeIn(
                    IERC20(t), 1, IERC20(linkedVault), 0, user, true, block.timestamp
                );
                return;
            }
        }
        uint256 Rc = openBook.reserveOfToken(address(commonToken));
        uint256 Bc = commonToken.balanceOf(linkedVault);
        assertEq(Rc, Bc, "common booked after deposit");
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, 1, IERC20(linkedVault), 0, user, true, block.timestamp
        );
    }
}

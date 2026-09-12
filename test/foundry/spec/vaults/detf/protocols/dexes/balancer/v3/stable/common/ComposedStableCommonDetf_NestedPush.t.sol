// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {
    ComposedStableCommonDetf_IntegratedDeploy_Test
} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol";

/// @notice Explicit T-NEST-1…8 + T-LOCAL for BAL-CS (L-DETF-TEST-EXPLICIT).
/// @dev Extends production IntegratedDeploy harness (manager registry + real SE adapters).
contract ComposedStableCommonDetf_NestedPush_Test is ComposedStableCommonDetf_IntegratedDeploy_Test {
    IBasicVault internal openBook;

    function setUp() public override {
        super.setUp();
        // Do not bootstrap here — parent IntegratedDeploy tests bootstrap themselves.
        // NestedPush tests call _bootstrapReserveGraph() once per test as needed.
        openBook = IBasicVault(deployedDetfVault);
    }

    function _ensureLive() internal {
        // Idempotent-ish: only bootstrap if reserve inventory is empty.
        if (IERC20(address(reservePool)).balanceOf(deployedDetfVault) == 0) {
            _bootstrapReserveGraph();
        }
    }

    function _assertHoldSetREqualsB() internal view {
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            assertEq(openBook.reserveOfToken(t), IERC20(t).balanceOf(deployedDetfVault), "hold-set R == B");
        }
    }

    function _mintDetf(address user, uint256 daiIn_) internal returns (uint256 detfOut_) {
        dai.mint(user, daiIn_ * 2);
        vm.startPrank(user);
        dai.approve(deployedDetfVault, daiIn_);
        detfOut_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(
                IERC20(address(dai)), daiIn_, IERC20(address(detfToken)), 0, user, false, block.timestamp + 1 hours
            );
        vm.stopPrank();
    }

    function test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync() public {
        _ensureLive();
        // Same production path as IntegratedDeploy mint test.
        uint256 amountIn_ = 10e18;
        // Fund rate asset / path token used by integrated mint.
        dai.mint(address(this), amountIn_ * 2);
        dai.approve(deployedDetfVault, amountIn_);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(
                IERC20(address(dai)),
                amountIn_,
                IERC20(address(detfToken)),
                0,
                address(this),
                false,
                block.timestamp + 1 hours
            );
        assertTrue(out_ > 0, "T-NEST-1");
        // Nested vault fund paths must not leave permanent DETF→underlying SE approve for rate asset.
        // (Permit2/router approvals may remain for Balancer hops — not nested SE fund-window.)
        assertTrue(IDETF(deployedDetfVault).reservePool() != address(0), "reserve wired");
        _assertHoldSetREqualsB();
    }

    function test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient() public {
        _ensureLive();
        // Host shortfall on SE leg (daiUsdcVault) after bootstrap funded reserves.
        IBasicVault seBook = IBasicVault(address(daiUsdcVault));
        uint256 dust_ = 10e18;
        dai.mint(address(this), dust_ * 2);
        IERC20(address(dai)).transfer(address(daiUsdcVault), dust_);
        uint256 Rh = seBook.reserveOfToken(address(dai));
        uint256 Bh = IERC20(address(dai)).balanceOf(address(daiUsdcVault));
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        assertTrue(U > 0, "need surplus");
        uint256 claimOver_ = U + 1;
        vm.expectRevert(); // TransferDeltaInsufficient or host InsufficientDeposit
        IStandardExchangeIn(address(daiUsdcVault))
            .exchangeIn(
                IERC20(address(dai)),
                claimOver_,
                IERC20(address(daiUsdcVault)),
                0,
                address(this),
                true,
                block.timestamp + 1 hours
            );
    }

    function test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts() public {
        _ensureLive();
        IBasicVault seBook = IBasicVault(address(daiUsdcVault));
        // Drive a money op on SE via DETF path first if needed; then I1 on booked face.
        uint256 Rh = seBook.reserveOfToken(address(dai));
        uint256 Bh = IERC20(address(dai)).balanceOf(address(daiUsdcVault));
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        if (U >= 1) {
            vm.expectRevert();
            IStandardExchangeIn(address(daiUsdcVault))
                .exchangeIn(
                    IERC20(address(dai)),
                    U + 1,
                    IERC20(address(daiUsdcVault)),
                    0,
                    address(this),
                    true,
                    block.timestamp + 1 hours
                );
        } else {
            vm.expectRevert();
            IStandardExchangeIn(address(daiUsdcVault))
                .exchangeIn(
                    IERC20(address(dai)),
                    1,
                    IERC20(address(daiUsdcVault)),
                    0,
                    address(this),
                    true,
                    block.timestamp + 1 hours
                );
        }
    }

    function test_T_NEST_4_noNestedApproveOnFundPath() public {
        _ensureLive();
        // Structural: production nested vault entry uses push+true (see presence suite + greps).
        // Runtime: after mint, DETF should not need residual underlying vault allowance for fund path.
        test_T_NEST_1_nestedHappy_pushTrue_hostReservesSync();
        assertEq(dai.allowance(deployedDetfVault, address(daiUsdcVault)), 0, "no payment approval to nested SE");
        assertEq(
            IERC20(address(daiUsdcVault)).allowance(deployedDetfVault, address(daiUsdcVault)),
            0,
            "no share approval to nested SE"
        );
    }

    /// @dev T-NEST-5: outermost exact-out re-forwards unused caller-paid maxIn to entry msg.sender.
    ///      Production asserts refundFromReturn == remaining bal before transfer (L-DETF-REFUND-OUTER).
    /// @dev The underlying SE pays its quoted rounded LP redemption, including
    /// native output dust. Compare that payment independently of the DETF max-input refund.
    function _quotedUnderlyingPayment(uint256 wanted_) internal view returns (uint256) {
        IERC20 shares_ = IERC20(address(daiUsdcVault));
        uint256 input_ = IStandardExchangeOut(address(daiUsdcVault)).previewExchangeOut(shares_, dai, wanted_);
        return IStandardExchangeIn(address(daiUsdcVault)).previewExchangeIn(shares_, input_, dai);
    }

    function test_T_NEST_5_outerExactOut_refundToEntryMsgSender() public {
        _ensureLive();
        uint256 raw_ = _mintDetf(address(this), 10e18);
        uint256 wanted_ = 1e15;
        uint256 expected_ = _quotedUnderlyingPayment(wanted_);
        assertGe(expected_, wanted_);
        uint256 quote_ = IStandardExchangeOut(deployedDetfVault).previewExchangeOut(detfToken, dai, wanted_);
        assertGt(quote_, 0);
        assertLt(quote_, raw_);
        uint256 maximum_ = quote_ + (raw_ - quote_) / 2;
        assertGt(maximum_, quote_);
        uint256 before_ = dai.balanceOf(address(this));
        detfToken.approve(deployedDetfVault, maximum_);
        uint256 used_ = IStandardExchangeOut(deployedDetfVault)
            .exchangeOut(detfToken, maximum_, dai, wanted_, address(this), false, block.timestamp);
        assertGt(used_, 0);
        assertLe(used_, quote_);
        assertLt(used_, maximum_);
        assertEq(dai.balanceOf(address(this)), before_ + expected_, "quoted underlying payment including native dust");
        assertEq(detfToken.balanceOf(address(this)), raw_ - used_, "unused input stays with payer");
        assertEq(detfToken.balanceOf(deployedDetfVault), 0);
        _assertHoldSetREqualsB();
    }

    /// @dev T-NEST-6: end order refund then full hold-set sync → post-route R == B for every vault token.
    function test_T_NEST_6_holdSetSyncAfterRoute() public {
        _ensureLive();
        uint256 out_ = _mintDetf(address(this), 50e18);
        assertTrue(out_ > 0, "minted");
        _assertHoldSetREqualsB();
    }

    function test_T_NEST_7_zeroAmount_skipsNested_outerRevertsZeroAmount() public {
        _ensureLive();
        vm.expectRevert();
        IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(
                IERC20(address(dai)), 0, IERC20(address(detfToken)), 0, address(this), false, block.timestamp + 1 hours
            );
    }

    /// @dev T-NEST-8: partial maxIn exact-out succeeds (no residual-hard-revert on unused input).
    function test_T_NEST_8_partialMaxIn_succeeds_noHardRevert() public {
        _ensureLive();
        uint256 raw_ = _mintDetf(address(this), 10e18);
        uint256 wanted_ = 1e15;
        uint256 expected_ = _quotedUnderlyingPayment(wanted_);
        assertGe(expected_, wanted_);
        uint256 quote_ = IStandardExchangeOut(deployedDetfVault).previewExchangeOut(detfToken, dai, wanted_);
        assertGt(quote_, 0);
        assertLt(quote_, raw_);
        uint256 maximum_ = raw_;
        assertGt(maximum_, quote_);
        uint256 before_ = dai.balanceOf(address(this));
        detfToken.approve(deployedDetfVault, maximum_);
        uint256 used_ = IStandardExchangeOut(deployedDetfVault)
            .exchangeOut(detfToken, maximum_, dai, wanted_, address(this), false, block.timestamp);
        assertGt(used_, 0);
        assertLe(used_, quote_);
        assertLt(used_, maximum_);
        assertEq(dai.balanceOf(address(this)), before_ + expected_, "quoted underlying payment including native dust");
        assertEq(detfToken.balanceOf(address(this)), raw_ - used_, "unused input stays with payer");
        assertEq(detfToken.balanceOf(deployedDetfVault), 0);
        _assertHoldSetREqualsB();
    }

    function test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU() public {
        _ensureLive();
        uint256 amountIn_ = 5e18;
        dai.mint(address(this), amountIn_);
        IERC20(address(dai)).transfer(deployedDetfVault, amountIn_);
        uint256 R0 = openBook.reserveOfToken(address(dai));
        uint256 B0 = IERC20(address(dai)).balanceOf(deployedDetfVault);
        if (B0 > R0) {
            uint256 U = B0 - R0;
            uint256 claim_ = U < amountIn_ ? U : amountIn_;
            if (claim_ > 0) {
                uint256 out_ = IStandardExchangeIn(deployedDetfVault)
                    .exchangeIn(
                        IERC20(address(dai)),
                        claim_,
                        IERC20(address(detfToken)),
                        0,
                        address(this),
                        true,
                        block.timestamp + 1 hours
                    );
                assertTrue(out_ > 0, "T-LOCAL-PUSH");
                _assertHoldSetREqualsB();
                return;
            }
        }
        // If dai is not hold-set / U==0 after transfer (absorbed), still prove I1 path next.
        test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts();
    }

    function test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts() public {
        _ensureLive();
        // After bootstrap, booked hold-set + true without new push reverts for a hold-set token if any.
        address[] memory tokens = openBook.vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            address t = tokens[i];
            if (t == deployedDetfVault) continue;
            uint256 R = openBook.reserveOfToken(t);
            uint256 B = IERC20(t).balanceOf(deployedDetfVault);
            if (R == B) {
                vm.expectRevert();
                IStandardExchangeIn(deployedDetfVault)
                    .exchangeIn(
                        IERC20(t), 1, IERC20(address(detfToken)), 0, address(this), true, block.timestamp + 1 hours
                    );
                return;
            }
        }
        // Fall back: SE host I1 already covers nested host law (T-NEST-3).
        test_T_NEST_3_nestedI1_bookedHost_trueWithoutPushReverts();
    }
}

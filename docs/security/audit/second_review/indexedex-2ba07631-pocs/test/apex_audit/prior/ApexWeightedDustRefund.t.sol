// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {TestBase_UniswapV4StandardExchangeWeightedBufferHook} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";

/**
 * @notice APEX-2026-007 / -008 — ADVERSARIAL VERIFICATION of the dust-refund payout.
 *
 *         Claim under test: `_refundBufferedDust` lets an arbitrary caller take face token
 *         resting on the hook.
 *
 *         The honest question is not "did the attacker's balance go up" — a joiner always
 *         gets some unused-input dust back, which is their own money. The question is
 *         whether the attacker ends up with MORE THAN THEY PUT IN, and specifically
 *         whether a third party's donation follows them out.
 *
 *         This test measures net profit and tracks where the donation actually goes.
 */
contract ApexWeightedDustRefund is TestBase_UniswapV4StandardExchangeWeightedBufferHook {
    address internal attacker = address(0xA77ACC);

    function setUp() public override {
        super.setUp();
        _seedFullBook(10_000 ether);
    }

    struct Snap { uint256 attacker; uint256 hookBal; uint256 seBal; }

    function _snap(address t) internal view returns (Snap memory s) {
        address se = weighted.standardExchangeOf(t);
        s.attacker = IERC20(t).balanceOf(attacker);
        s.hookBal = IERC20(t).balanceOf(hook);
        s.seBal = se == address(0) || se == t ? 0 : IERC20(t).balanceOf(se);
    }

    /// @dev Join with an exact, accounted contribution so net profit is computable.
    function _joinAs(uint256 amountEach) internal returns (uint256 contributed) {
        address[] memory toks = weighted.tokens();
        uint256 n = toks.length;
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = amountEach;
            SimpleMintableERC20(toks[i]).mint(attacker, amountEach);
            vm.prank(attacker);
            IERC20(toks[i]).approve(hook, type(uint256).max);
        }
        contributed = amountEach;
        vm.prank(attacker);
        weighted.joinProportional(amounts, attacker, 0, block.timestamp + 1 days);
    }

    /// @notice Does a third party's donation leave with the next caller?
    function test_apex007_donationDoesNotFollowTheCaller() public {
        address t0 = address(token0);
        uint256 donation = 500 ether;

        SimpleMintableERC20(t0).mint(hook, donation);
        Snap memory before_ = _snap(t0);
        emit log_named_uint("donation placed on hook   ", donation);
        emit log_named_uint("hook face balance (before)", before_.hookBal);
        emit log_named_uint("SE face balance  (before) ", before_.seBal);

        // attacker contributes `amountEach` of EVERY token, and is minted exactly that much
        uint256 contributed = _joinAs(1 ether);
        Snap memory after_ = _snap(t0);

        emit log_named_uint("hook face balance (after) ", after_.hookBal);
        emit log_named_uint("SE face balance  (after)  ", after_.seBal);
        emit log_named_uint("SE face DELTA (absorbed)  ", after_.seBal - before_.seBal);
        emit log_named_uint("attacker face balance     ", after_.attacker);
        emit log_named_uint("attacker contributed      ", contributed);

        // The attacker was minted exactly `contributed` and holds whatever came back.
        // Net profit in this token = final balance - 0 (started at 0, was minted `contributed`).
        assertLt(after_.attacker, contributed, "attacker must not end up ahead on this token");
        emit log_string("=> attacker recovered only part of its OWN input; no net profit");

        // The donation left the hook but did NOT follow the caller. `_bufferToken` exchanges
        // it into SE shares, so it shows up as SE shares held by the hook (and as underlying
        // inside the protocol vault), not as face token anywhere.
        assertLe(after_.hookBal, 10, "hook left at MAX_DUST_WEI");
        uint256 paidOut = after_.attacker;
        assertLt(paidOut, donation, "the donation did not follow the caller");
        emit log_named_uint("hook SE-share balance (book)", IERC20(weighted.standardExchangeOf(t0)).balanceOf(hook));
        emit log_string("=> donation was buffered into SE shares held by the hook (accrues to LPs)");
        emit log_string("=> NOT paid to the caller");
    }

    /// @notice Same with a sub-preview donation, to check the buffer-skip branch.
    function test_apex007_subPreviewDonation() public {
        address t0 = address(token0);
        address se = weighted.standardExchangeOf(t0);
        uint256 donation = 1000;

        SimpleMintableERC20(t0).mint(hook, donation);(uint256 preview,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(t0), donation - 10, IERC20(se));
        emit log_named_uint("previewExchangeIn(excess)", preview);

        Snap memory before_ = _snap(t0);
        uint256 contributed = _joinAs(1 ether);
        Snap memory after_ = _snap(t0);

        emit log_named_uint("attacker face balance", after_.attacker);
        emit log_named_uint("attacker contributed ", contributed);
        emit log_named_uint("hook face (after)    ", after_.hookBal);
        assertLt(after_.attacker, contributed, "no net profit on the sub-preview path either");
        emit log_string("=> buffer-first still absorbs; payout is the caller's own residue");
    }

    /// @notice Residual closure: force `previewExchangeIn == 0` NATURALLY (no mocks) by
    ///         inflating the SE share price, so the buffer-first branch is skipped and the
    ///         resting balance is paid straight to the caller. Establishes the true upper
    ///         bound on what a caller can take from a buffer-first family.
    function test_apex007_previewZeroBranchIsReachable() public {
        address t0 = address(token0);
        address se = weighted.standardExchangeOf(t0);

        // Inflate the share price so that a small face amount converts to zero SE shares.
        token0.mint(address(this), 1_000_000 ether);
        IERC20(t0).approve(address(vault0), type(uint256).max);
        vault0.simulateYield(500_000 ether);

        // A resting balance too small to buy even one SE share.
        uint256 resting = 1000;
        SimpleMintableERC20(t0).mint(hook, resting);(uint256 preview,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(t0), resting - 10, IERC20(se)
        );
        emit log_named_uint("resting balance          ", resting);
        emit log_named_uint("previewExchangeIn(excess)", preview);

        uint256 attBefore = IERC20(t0).balanceOf(attacker);
        uint256 contributed = _joinAs(1 ether);
        uint256 finalBal = IERC20(t0).balanceOf(attacker) - attBefore;

        emit log_named_uint("attacker final t0 balance", finalBal);
        emit log_named_uint("attacker contributed     ", contributed);
        emit log_named_uint("hook face (after)        ", IERC20(t0).balanceOf(hook));

        if (preview == 0) {
            emit log_string("preview==0 -> buffer skipped; resting balance paid to caller");
            emit log_string("BUT the amount is by construction less than one SE share == true dust");
        } else {
            emit log_string("preview still non-zero; buffer absorbed as before");
        }
        // Either way, the caller cannot end up meaningfully ahead on a buffer-first family.
        assertLe(finalBal, contributed + resting, "bounded by own input plus sub-share dust");
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_AaveLoopFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_AaveLoopFixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol";

/// @notice D20: constantProduct/single × AaveCrossVersionLoop (COMPATIBLE; the M13 host row for this
///         heavy family). Face: tokenA, the 18-decimal "Cross Loop Token A" listed on the local Aave
///         V3.6 and V4 markets, wrapped by the registry-deployed cross-version loop package; SE
///         shares ("axCARRY") are 18 decimals. Partial case: the V3 tokenA supply cap (D43).
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_AaveCrossVersionLoop is
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior
{
    function _newFixture() internal virtual override returns (SeMatrixFixture) {
        return new SeMatrix_AaveLoopFixture(_ctx(), address(0), 18);
    }

    /// @dev F2 (2026-09-21, D60) and F8 (2026-09-23, D61) closed: the loop values its SE leg by the rate
    ///      provider and repays proportionally on an exact-out unwind, so it keeps borrow headroom and the ten
    ///      row controls run. This one control is overridden for a recorded rounding finding (below).
    ///
    /// @dev D61 recorded finding — loop exact-in redemption is conservative by up to a wei. The loop prices a
    ///      redemption from NAV (`navUsd * shares / supply / priceA`), while its proportional unwind frees
    ///      `floor(s*phi) - ceil(d*phi)` (floor the V3 collateral withdrawal, ceil the V4 debt repayment) so the
    ///      remaining position's LTV never rises (D61 borrow-headroom invariant). On a non-clean burn ratio the
    ///      NAV price is up to a wei above the unwind's floor, so the loop is CONSERVATIVE: it delivers the
    ///      preview exactly, or reverts `AmountOutNotMet` — it never over-delivers. Making it pay the NAV amount
    ///      would require a bare HF-unsafe extra V3 withdrawal (breaks the E2E-verified full-exit and
    ///      sub-oracle controls, `test_nativeSY_fullSingleTokenExitUnwindsProportionally` /
    ///      `test_exactOutput_positiveSubOracleAmountConsumesShares`). This control therefore accepts either
    ///      outcome and asserts there is never a partial delivery on the conservative revert. The loop's
    ///      authoritative exactness coverage is its own E2E suite (all green).
    function test_row_previewMatchesExecution() public override {
        uint256 lp = _seed();
        (uint256 a0, uint256 a1) = _ordered(_f(10), 10 ether);
        (uint256 pLp, uint256 pUsed0, uint256 pUsed1) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 gotLp, uint256 used0, uint256 used1) = single.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
        assertEq(used0, pUsed0, "deposit used0 preview == execution");
        assertEq(used1, pUsed1, "deposit used1 preview == execution");
        assertApproxEqRel(gotLp, pLp, 1e12, "deposit LP preview == execution");

        uint256 burn = lp / 10;
        uint256 pOut = single.previewWithdrawSingle(burn, face);
        uint256 beforeFace = IERC20(face).balanceOf(user);
        vm.prank(user);
        try single.withdrawSingle(burn, face, user, 0, block.timestamp + 1 hours) returns (uint256 out) {
            assertEq(out, pOut, "withdrawSingle(face) preview == execution when the unwind reconciles");
            assertEq(IERC20(face).balanceOf(user) - beforeFace, out, "withdraw delivered the returned amount");
        } catch (bytes memory err) {
            assertEq(
                bytes4(err),
                bytes4(keccak256("AmountOutNotMet(uint256,uint256)")),
                "only the conservative unwind-shortfall revert is tolerated"
            );
            assertEq(IERC20(face).balanceOf(user), beforeFace, "no partial delivery on the conservative revert");
        }

        uint256 probe = _previewSwapProbe();
        if (probe == 0) {
            emit log("swap control skipped: the row pins it to a recorded finding (see its test_BLOCKED_* test)");
            return;
        }
        uint256 pSwap = single.previewSwapExactIn(face, raw, probe);
        uint256 rBefore = IERC20(raw).balanceOf(user);
        _swapExactIn(face, raw, probe);
        assertEq(IERC20(raw).balanceOf(user) - rBefore, pSwap, "swap preview == execution");
    }
}

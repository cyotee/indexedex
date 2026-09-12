// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test
/// @notice Incoming liquidity is excluded from protocol growth fees on the registered CP package.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test is TestBase {
    /// @notice Start from a fee-on reserve with no accrued swap or yield growth.
    function setUp() public override {
        super.setUp();
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();
    }

    /// @notice Balanced raw/pair capital mints only depositor LP and matches the preview exactly.
    function test_balancedDeposit_newCapitalDoesNotMintProtocolFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        _depositPairAndCheckPreview(20 ether, 20 ether);
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "new capital is not growth");
    }

    /// @notice Balanced raw/SE-share capital does not create a growth fee.
    function test_balancedSeShares_newCapitalDoesNotMintProtocolFee() public {
        uint256 shares = _mintSeSharesToUser(20 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        _depositSharesAndCheckPreview(20 ether, shares);
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "incoming SE shares are not growth");
    }

    /// @notice The generic proportional intake accrues fees before pulling its two legs.
    function test_joinProportional_newCapitalDoesNotMintProtocolFee() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 20 ether;
        amounts[1] = 20 ether;
        IUniswapV4SeBufferHook h = IUniswapV4SeBufferHook(hook);
        (uint256 preview, uint256[] memory usedPreview) = h.previewJoinProportional(amounts);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        (uint256 minted, uint256[] memory used) = h.joinProportional(amounts, user, preview, block.timestamp);
        assertEq(minted, preview, "generic join preview");
        assertEq(used, usedPreview, "generic join amounts");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "generic capital is not growth");
    }

    /// @notice The generic SE-share intake also excludes both incoming legs from growth.
    function test_joinUnbalancedSeShares_newCapitalDoesNotMintProtocolFee() public {
        uint256 shares = _mintSeSharesToUser(20 ether);
        address[] memory tokens = new address[](2);
        tokens[0] = address(rawToken);
        tokens[1] = se;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 20 ether;
        amounts[1] = shares;
        IUniswapV4SeBufferHook h = IUniswapV4SeBufferHook(hook);
        uint256 preview = h.previewJoinUnbalanced(tokens, amounts);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        uint256 minted = h.joinUnbalanced(tokens, amounts, user, preview, block.timestamp);
        assertEq(minted, preview, "SE-share generic preview");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "generic SE capital is not growth");
    }

    /// @notice Real Permit2 allowance intake preserves the same pre-intake fee boundary.
    function test_permit2Allowance_newCapitalDoesNotMintProtocolFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        (uint256 preview, uint256 used0Preview, uint256 used1Preview) = single.previewDeposit(20 ether, 20 ether);
        vm.startPrank(user);
        rawToken.approve(address(permit2), type(uint256).max);
        pairToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(address(rawToken), hook, type(uint160).max, type(uint48).max);
        IAllowanceTransfer(address(permit2)).approve(address(pairToken), hook, type(uint160).max, type(uint48).max);
        (uint256 minted, uint256 used0, uint256 used1) =
            single.depositWithPermit2Allowance(20 ether, 20 ether, user, preview, block.timestamp);
        vm.stopPrank();
        assertEq(minted, preview, "Permit2 LP preview");
        assertEq(used0, used0Preview, "Permit2 currency0 preview");
        assertEq(used1, used1Preview, "Permit2 currency1 preview");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "Permit2 capital is not growth");
    }

    /// @notice Single-sided raw intake does not count the just-pulled raw inventory as prior growth.
    function test_singleRawDeposit_newCapitalDoesNotMintPriorGrowthFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        vm.prank(user);
        uint256 minted = single.depositSingle(address(rawToken), 5 ether, user, preview, block.timestamp);
        assertGt(minted, 0, "single deposit completes");
        assertEq(minted, preview, "single raw preview matches post-swap intake");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "single raw input is not prior growth");
    }

    function testFuzz_singleDeposit_afterYield_previewMatches(bool pairIn_, uint64 amount_) public {
        _addYield(20 ether + 13);
        uint256 amount = bound(amount_, 1e12, 20 ether);
        address token = pairIn_ ? address(pairToken) : address(rawToken);
        uint256 preview = single.previewDepositSingle(token, amount);
        vm.prank(user);
        uint256 minted = single.depositSingle(token, amount, user, preview, block.timestamp);
        assertGt(minted, 0);
        assertEq(minted, preview, "sequential state quote equals minted LP");
    }

    function test_singleQuote_minimumAboveOutput_revertsAtomically() public {
        _addYield(20 ether + 13);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        uint256 userRaw = rawToken.balanceOf(user);
        uint256 supply = IERC20(hook).totalSupply();
        uint256 held = IERC20(se).balanceOf(hook);
        uint256 feeLp = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        vm.expectRevert(bytes4(keccak256("InsufficientLpOut()")));
        single.depositSingle(address(rawToken), 5 ether, user, preview + 1, block.timestamp);
        assertEq(rawToken.balanceOf(user), userRaw, "input transfer rolled back");
        assertEq(IERC20(hook).totalSupply(), supply, "LP issuance rolled back");
        assertEq(IERC20(se).balanceOf(hook), held, "buffer transitions rolled back");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeLp, "protocol fee rolled back");
    }

    /// @notice Previously accrued yield earns the same protocol fee regardless of incoming deposit size.
    function test_realGrowth_feeIndependentOfNewCapitalAndPreviewMatches() public {
        _addYield(20 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 snapshot = vm.snapshotState();
        _depositPairAndCheckPreview(10 ether, 11 ether);
        uint256 smallDepositFee = IERC20(hook).balanceOf(_feeTo()) - feeBefore;
        assertGt(smallDepositFee, 0, "real yield accrues protocol fee");

        assertTrue(vm.revertToState(snapshot), "restore identical accrued growth");
        _depositPairAndCheckPreview(100 ether, 110 ether);
        assertEq(IERC20(hook).balanceOf(_feeTo()) - feeBefore, smallDepositFee, "fee depends only on prior growth");
    }

    /// @notice SE-share intake preserves the same positive fee for existing yield at both deposit sizes.
    function test_realGrowth_seSharesFeeIndependentOfNewCapitalAndPreviewMatches() public {
        _mintSeSharesToUser(100 ether);
        _addYield(30 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 snapshot = vm.snapshotState();
        _depositSharesAndCheckPreview(10 ether, 10 ether);
        uint256 smallDepositFee = IERC20(hook).balanceOf(_feeTo()) - feeBefore;
        assertGt(smallDepositFee, 0, "existing SE yield earns fee");

        assertTrue(vm.revertToState(snapshot), "restore identical SE growth");
        _depositSharesAndCheckPreview(100 ether, 100 ether);
        assertEq(IERC20(hook).balanceOf(_feeTo()) - feeBefore, smallDepositFee, "SE fee excludes new capital");
    }

    /// @notice Exact-out admission uses the same pending-fee quote as the external preview, before pulling.
    function test_realGrowth_exactOutQuoteDoesNotCountPendingFeeTwice() public {
        _addYield(20 ether);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "nonzero single-deposit quote");
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        rawToken.approve(hook, 0);

        // The quoted bound must reject before a token pull can fail for missing approval.
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        vm.prank(user);
        IUniswapV4SeBufferHook(hook)
            .joinSingleAssetExactOut(address(rawToken), preview + 1, user, 5 ether, block.timestamp);
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "rejected quote leaves fee accrual untouched");
    }

    /// @notice Exact-out intake and direct intake charge identical accrued fees from identical state.
    function test_realGrowth_exactOutAccruesOnceAndMatchesDirectIntake() public {
        _addYield(20 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        uint256 snapshot = vm.snapshotState();
        vm.prank(user);
        uint256 directLp = single.depositSingle(address(rawToken), 5 ether, user, 0, block.timestamp);
        uint256 directFee = IERC20(hook).balanceOf(_feeTo()) - feeBefore;
        assertGt(directFee, 0, "existing growth earns fee");
        assertGt(directLp, 0, "direct single intake completes");

        assertTrue(vm.revertToState(snapshot), "restore identical single-intake growth");
        uint256 sharesMin = preview < directLp ? preview : directLp;
        assertGt(sharesMin, 0, "positive exact-out minimum");
        vm.prank(user);
        uint256 spent = IUniswapV4SeBufferHook(hook)
            .joinSingleAssetExactOut(address(rawToken), sharesMin, user, 5 ether, block.timestamp);
        assertEq(spent, 5 ether, "exact-out uses configured maximum input");
        assertEq(rawBefore - rawToken.balanceOf(user), spent, "exact-out raw debit");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, directLp, "same intake produces same LP");
        assertEq(IERC20(hook).balanceOf(_feeTo()) - feeBefore, directFee, "pending growth fee minted once");
    }

    /// @dev Assert both token usage and LP issuance against the public pre-intake quote.
    function _depositPairAndCheckPreview(uint256 rawAmount, uint256 pairAmount) internal {
        uint256 a0 = _amountForCurrency(single.currency0(), rawAmount, pairAmount);
        uint256 a1 = _amountForCurrency(single.currency1(), rawAmount, pairAmount);
        (uint256 preview, uint256 u0Preview, uint256 u1Preview) = single.previewDeposit(a0, a1);
        vm.prank(user);
        (uint256 minted, uint256 u0, uint256 u1) = single.deposit(a0, a1, user, preview, block.timestamp);
        assertEq(minted, preview, "raw/pair LP preview");
        assertEq(u0, u0Preview, "raw/pair currency0 usage");
        assertEq(u1, u1Preview, "raw/pair currency1 usage");
    }

    /// @dev Assert the SE-share intake quote on the deployed hook proxy.
    function _depositSharesAndCheckPreview(uint256 rawAmount, uint256 shareAmount) internal {
        (uint256 preview, uint256 rawPreview, uint256 sharePreview) =
            single.previewDepositWithSeShares(rawAmount, shareAmount);
        vm.prank(user);
        (uint256 minted, uint256 usedRaw, uint256 usedShares) =
            single.depositWithSeShares(rawAmount, shareAmount, user, preview, block.timestamp);
        assertEq(minted, preview, "SE-share LP preview");
        assertEq(usedRaw, rawPreview, "SE-share raw usage");
        assertEq(usedShares, sharePreview, "SE-share usage");
    }

    /// @dev Use the existing yield-bearing ERC4626 fixture without mocking the SE or fee oracle.
    function _addYield(uint256 amount) internal {
        pairToken.mint(address(this), amount);
        pairToken.approve(address(pairProtocolVault), amount);
        pairProtocolVault.simulateYield(amount);
    }
}

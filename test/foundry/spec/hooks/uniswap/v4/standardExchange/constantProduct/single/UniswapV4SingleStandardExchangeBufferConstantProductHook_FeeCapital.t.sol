// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test
/// @notice New backed gross LP is split exactly; rate growth never issues LP by itself.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_FeeCapital_Test is TestBase {
    /// @notice Start from a fee-on reserve with no accrued swap or yield growth.
    function setUp() public override {
        super.setUp();
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();
    }

    /// @notice Balanced raw/pair capital pays the exact fee from backed gross and matches its preview.
    function test_balancedDeposit_newCapitalMintsExactProtocolFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 net = _depositPairAndCheckPreview(20 ether, 20 ether);
        _assertFeeSplit(feeBefore, supplyBefore, net);
    }

    /// @notice Balanced raw/SE-share capital pays the same backed-gross mint fee.
    function test_balancedSeShares_newCapitalMintsExactProtocolFee() public {
        uint256 shares = _mintSeSharesToUser(20 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 net = _depositSharesAndCheckPreview(20 ether, shares);
        _assertFeeSplit(feeBefore, supplyBefore, net);
    }

    /// @notice The generic proportional intake splits only its accepted backed gross.
    function test_joinProportional_newCapitalMintsExactProtocolFee() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 20 ether;
        amounts[1] = 20 ether;
        IUniswapV4SeBufferHook h = IUniswapV4SeBufferHook(hook);
        (uint256 preview, uint256[] memory usedPreview) = h.previewJoinProportional(amounts);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        vm.prank(user);
        (uint256 minted, uint256[] memory used) = h.joinProportional(amounts, user, preview, block.timestamp);
        assertEq(minted, preview, "generic join preview");
        assertEq(used, usedPreview, "generic join amounts");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    /// @notice The generic SE-share intake splits backed LP between depositor and treasury.
    function test_joinUnbalancedSeShares_newCapitalMintsExactProtocolFee() public {
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
        uint256 supplyBefore = IERC20(hook).totalSupply();
        vm.prank(user);
        uint256 minted = h.joinUnbalanced(tokens, amounts, user, preview, block.timestamp);
        assertEq(minted, preview, "SE-share generic preview");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    /// @notice Real Permit2 allowance intake pays the same exact backed-mint fee.
    function test_permit2Allowance_newCapitalMintsExactProtocolFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
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
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    /// @notice Paid single-leg preparation splits the accepted gross LP exactly.
    function test_singleRawDeposit_newCapitalMintsExactProtocolFee() public {
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "paid raw preparation produces backed LP");
        vm.prank(user);
        uint256 minted = single.depositSingle(address(rawToken), 5 ether, user, preview, block.timestamp);
        assertEq(minted, preview, "single raw preview");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, minted, "recipient net LP");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    function testFuzz_singleDeposit_afterYield_previewMatches(bool pairIn_, uint64 amount_) public {
        _addYield(20 ether + 13);
        uint256 amount = bound(amount_, 1e12, 20 ether);
        address token = pairIn_ ? address(pairToken) : address(rawToken);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 preview = single.previewDepositSingle(token, amount);
        assertGt(preview, 0, "post-yield paid preparation remains available");
        vm.prank(user);
        uint256 minted = single.depositSingle(token, amount, user, preview, block.timestamp);
        assertEq(minted, preview, "post-yield single preview");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, minted, "post-yield recipient net");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
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

    /// @notice After yield, the exact mint fee scales with new backed capital.
    function test_realGrowth_feeScalesWithNewCapitalAndPreviewMatches() public {
        _addYield(20 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 snapshot = vm.snapshotState();
        _depositPairAndCheckPreview(10 ether, 11 ether);
        uint256 smallDepositFee = IERC20(hook).balanceOf(_feeTo()) - feeBefore;
        assertGt(smallDepositFee, 0, "new backed LP pays mint fee");

        assertTrue(vm.revertToState(snapshot), "restore identical accrued growth");
        _depositPairAndCheckPreview(100 ether, 110 ether);
        assertGt(IERC20(hook).balanceOf(_feeTo()) - feeBefore, smallDepositFee, "larger backed mint pays larger fee");
    }

    /// @notice After yield, a larger share-funded contribution pays a larger exact mint fee.
    function test_realGrowth_seSharesFeeScalesWithNewCapitalAndPreviewMatches() public {
        _mintSeSharesToUser(100 ether);
        _addYield(30 ether);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 snapshot = vm.snapshotState();
        _depositSharesAndCheckPreview(10 ether, 10 ether);
        uint256 smallDepositFee = IERC20(hook).balanceOf(_feeTo()) - feeBefore;
        assertGt(smallDepositFee, 0, "new share-backed LP pays mint fee");

        assertTrue(vm.revertToState(snapshot), "restore identical SE growth");
        _depositSharesAndCheckPreview(100 ether, 100 ether);
        assertGt(IERC20(hook).balanceOf(_feeTo()) - feeBefore, smallDepositFee, "larger SE-backed mint pays larger fee");
    }

    /// @notice An infeasible exact-net bound rejects before attempting any token pull.
    function test_realGrowth_exactOutQuoteDoesNotCountPendingFeeTwice() public {
        _addYield(20 ether);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "feasible exact-in net quote");
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        rawToken.approve(hook, 0);

        // The quoted bound must reject before a token pull can fail for missing approval.
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        vm.prank(user);
        IUniswapV4SeBufferHook(hook)
            .joinSingleAssetExactOut(address(rawToken), preview + 1, user, 5 ether, block.timestamp);
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "rejected bound issues no fee LP");
    }

    function test_exactNet_fullFee_rejectsBeforeFunding() public {
        _enableProtocolFee(1e18);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 rawBefore = rawToken.balanceOf(user);
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        vm.prank(user);
        rawToken.approve(hook, 0);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        vm.prank(user);
        IUniswapV4SeBufferHook(hook).joinSingleAssetExactOut(address(rawToken), 1, user, 5 ether, block.timestamp);
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "impossible positive net mints nothing");
        assertEq(rawToken.balanceOf(user), rawBefore, "impossible positive net pulls nothing");
        assertEq(IERC20(hook).balanceOf(_feeTo()), feeBefore, "no fee on rejected input");
    }

    /// @notice Exact-net pays one mint fee and rejects an insufficient input budget atomically.
    function test_realGrowth_exactOutPaidPreparation_matchesNetAndBudget() public {
        _addYield(20 ether);
        bytes32 before_ = _strictJoinState(user);
        uint256 preview = single.previewDepositSingle(address(rawToken), 5 ether);
        assertGt(preview, 0, "paid preparation quote");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        IUniswapV4SeBufferHook(hook)
            .joinSingleAssetExactOut(address(rawToken), preview + 1, user, 5 ether, block.timestamp);
        assertEq(_strictJoinState(user), before_, "infeasible budget restores entire basket");
        uint256 target = preview / 2;
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 lpBefore = IERC20(hook).balanceOf(user);
        uint256 rawBefore = rawToken.balanceOf(user);
        vm.prank(user);
        uint256 spent = single.joinSingleAssetExactOut(address(rawToken), target, user, 5 ether, block.timestamp);
        assertGt(spent, 0, "exact-net execution pays input");
        assertLe(spent, 5 ether, "exact-net respects input budget");
        assertEq(rawBefore - rawToken.balanceOf(user), spent, "returned spend includes caller refund");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, target, "exact requested net LP");
        _assertFeeSplit(feeBefore, supplyBefore, target);
    }

    /// @dev Assert both token usage and LP issuance against the public pre-intake quote.
    function _depositPairAndCheckPreview(uint256 rawAmount, uint256 pairAmount) internal returns (uint256 minted) {
        uint256 a0 = _amountForCurrency(single.currency0(), rawAmount, pairAmount);
        uint256 a1 = _amountForCurrency(single.currency1(), rawAmount, pairAmount);
        (uint256 preview, uint256 u0Preview, uint256 u1Preview) = single.previewDeposit(a0, a1);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 u0;
        uint256 u1;
        vm.prank(user);
        (minted, u0, u1) = single.deposit(a0, a1, user, preview, block.timestamp);
        assertEq(minted, preview, "raw/pair LP preview");
        assertEq(u0, u0Preview, "raw/pair currency0 usage");
        assertEq(u1, u1Preview, "raw/pair currency1 usage");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    /// @dev Assert the SE-share intake quote on the deployed hook proxy.
    function _depositSharesAndCheckPreview(uint256 rawAmount, uint256 shareAmount) internal returns (uint256 minted) {
        (uint256 preview, uint256 rawPreview, uint256 sharePreview) =
            single.previewDepositWithSeShares(rawAmount, shareAmount);
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 feeBefore = IERC20(hook).balanceOf(_feeTo());
        uint256 usedRaw;
        uint256 usedShares;
        vm.prank(user);
        (minted, usedRaw, usedShares) =
            single.depositWithSeShares(rawAmount, shareAmount, user, preview, block.timestamp);
        assertEq(minted, preview, "SE-share LP preview");
        assertEq(usedRaw, rawPreview, "SE-share raw usage");
        assertEq(usedShares, sharePreview, "SE-share usage");
        _assertFeeSplit(feeBefore, supplyBefore, minted);
    }

    function _assertFeeSplit(uint256 feeBefore, uint256 supplyBefore, uint256 net) internal view {
        uint256 gross = IERC20(hook).totalSupply() - supplyBefore;
        uint256 fee = gross * 0.05e18 / 1e18;
        assertGt(gross, 0, "positive backed mint");
        assertEq(IERC20(hook).balanceOf(_feeTo()) - feeBefore, fee, "exact mint fee");
        assertEq(net, gross - fee, "fee plus net equals gross");
    }

    /// @dev Use the existing yield-bearing ERC4626 fixture without mocking the SE or fee oracle.
    function _addYield(uint256 amount) internal {
        pairToken.mint(address(this), amount);
        pairToken.approve(address(pairProtocolVault), amount);
        pairProtocolVault.simulateYield(amount);
    }
}

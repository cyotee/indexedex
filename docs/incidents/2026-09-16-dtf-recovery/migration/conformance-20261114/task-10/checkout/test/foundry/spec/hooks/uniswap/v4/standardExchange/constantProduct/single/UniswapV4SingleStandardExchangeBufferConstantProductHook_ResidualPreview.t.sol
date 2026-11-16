// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
// tag::UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test[]
/// @title Residual preview through the installed production hook facets
/// @notice Ambient pair transfers are never swept into the pool or paid to an incoming caller.
/// @dev Parent operations convert only caller-owned input or the independently allocated exit
/// claim. Even an ambient amount whose quote would overflow cannot affect those operations.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test is TestBase {
    uint256 internal seededLocal;
    struct Balances {
        uint256 hookPair;
        uint256 excess;
        uint256 hookSe;
        uint256 hookRaw;
        uint256 userPair;
        uint256 userSe;
        uint256 userRaw;
        uint256 userLp;
        uint256 lpSupply;
        address feeTo;
        uint256 feePair;
        uint256 localBook;
        uint256 feeLp;
    }

    /// @notice Deploy the unchanged registry-bound hook and ERC-4626 SE, then fund both share entries.
    function setUp() public override {
        super.setUp();
        _seedLiveLiquidity();
        seededLocal = pairToken.balanceOf(hook);
        _mintSeSharesToUser(20 ether);
    }

    /// @notice A zero-quoted ambient donation stays unbooked while caller-funded LP is minted.
    function test_residualPreview_deposit_zeroRetainsExcess() public {
        _prepareZeroQuote();
        Balances memory before_ = _balances();
        (uint256 lpExpected, uint256 rawExpected, uint256 seExpected) =
            single.previewDepositWithSeShares(10 ether, 10 ether);
        assertGt(lpExpected, 0, "positive parent minimum");
        _expectNoSweepQuote(before_.excess);

        vm.prank(user);
        (uint256 lp, uint256 usedRaw, uint256 usedSe) =
            single.depositWithSeShares(10 ether, 10 ether, user, lpExpected, block.timestamp);

        assertEq(lp, lpExpected, "parent LP minimum and preview");
        assertEq(usedRaw, rawExpected, "parent raw input");
        assertEq(usedSe, seExpected, "parent SE input");
        assertEq(IERC20(hook).balanceOf(user), before_.userLp + lp, "LP received");
        assertEq(rawToken.balanceOf(user), before_.userRaw - usedRaw, "raw paid");
        assertEq(rawToken.balanceOf(hook), before_.hookRaw + usedRaw, "raw intake");
        assertEq(IERC20(se).balanceOf(user), before_.userSe - usedSe, "SE paid");
        uint256 gross = IERC20(hook).totalSupply() - before_.lpSupply;
        assertEq(IERC20(se).balanceOf(hook) - before_.hookSe, _ceil(gross, before_.hookSe, before_.lpSupply), "ceil share intake");
        _assertResidualRetained(before_, _ceil(gross, before_.localBook, before_.lpSupply), false);
    }

    /// @notice A zero-quoted ambient donation stays unbooked while the allocated basket is paid.
    function test_residualPreview_withdraw_zeroRetainsExcess() public {
        _prepareZeroQuote();
        Balances memory before_ = _balances();
        (uint256 rawExpected, uint256 seExpected) = single.previewWithdrawSeShares(10 ether);
        assertGt(rawExpected, 0, "positive parent raw minimum");
        assertGt(seExpected, 0, "positive parent SE minimum");
        _expectNoSweepQuote(before_.excess);

        vm.prank(user);
        (uint256 rawOut, uint256 seOut) =
            single.withdrawSeShares(10 ether, user, rawExpected, seExpected, block.timestamp);

        assertEq(rawOut, rawExpected, "parent raw minimum and preview");
        assertEq(seOut, seExpected, "parent SE minimum and preview");
        assertEq(IERC20(hook).balanceOf(user), before_.userLp - 10 ether, "LP burned");
        assertEq(rawToken.balanceOf(user), before_.userRaw + rawOut, "raw payout");
        assertEq(rawToken.balanceOf(hook), before_.hookRaw - rawOut, "raw debit");
        assertEq(IERC20(se).balanceOf(user), before_.userSe + seOut, "SE payout");
        assertEq(IERC20(se).balanceOf(hook), before_.hookSe - 10 ether * before_.hookSe / before_.lpSupply, "only allocated SE debit");
        _assertResidualRetained(before_, 10 ether * before_.localBook / before_.lpSupply, true);
    }

    /// @notice An overflowing ambient quote is not evaluated by a caller-funded join.
    function test_residualPreview_deposit_quoteRevertNotSwept() public {
        _prepareRevertingQuote();
        Balances memory before_ = _balances();
        (uint256 lpExpected,,) = single.previewDepositWithSeShares(10 ether, 10 ether);
        assertGt(lpExpected, 0, "parent quote succeeds");
        _expectNoSweepQuote(before_.excess);

        vm.prank(user);
        (uint256 minted,,) = single.depositWithSeShares(10 ether, 10 ether, user, lpExpected, block.timestamp);

        assertEq(minted, lpExpected, "ambient quote cannot block valid join");
        uint256 gross = IERC20(hook).totalSupply() - before_.lpSupply;
        _assertResidualRetained(before_, _ceil(gross, before_.localBook, before_.lpSupply), false);
    }

    /// @notice An overflowing ambient quote is not evaluated by a proportional exit.
    function test_residualPreview_withdraw_quoteRevertNotSwept() public {
        _prepareRevertingQuote();
        Balances memory before_ = _balances();
        (uint256 rawExpected, uint256 seExpected) = single.previewWithdrawSeShares(10 ether);
        assertGt(rawExpected, 0, "parent raw quote succeeds");
        assertGt(seExpected, 0, "parent SE quote succeeds");
        _expectNoSweepQuote(before_.excess);

        vm.prank(user);
        (uint256 rawOut, uint256 seOut) = single.withdrawSeShares(10 ether, user, rawExpected, seExpected, block.timestamp);

        assertEq(rawOut, rawExpected, "raw payout unaffected by ambient quote");
        assertEq(seOut, seExpected, "share payout unaffected by ambient quote");
        _assertResidualRetained(before_, 10 ether * before_.localBook / before_.lpSupply, true);
    }

    function test_residualPreview_failedMinimum_rollsBackWithAmbientInventory() public {
        _prepareRevertingQuote();
        Balances memory before_ = _balances();
        (uint256 lpExpected,,) = single.previewDepositWithSeShares(10 ether, 10 ether);
        vm.expectRevert(abi.encodeWithSignature("InsufficientLpOut()"));
        vm.prank(user);
        single.depositWithSeShares(10 ether, 10 ether, user, lpExpected + 1, block.timestamp);
        _assertRolledBack(before_);
        (uint256 rawExpected, uint256 seExpected) = single.previewWithdrawSeShares(10 ether);
        vm.expectRevert(abi.encodeWithSignature("InsufficientTokenOut()"));
        vm.prank(user);
        single.withdrawSeShares(10 ether, user, rawExpected + 1, seExpected, block.timestamp);
        _assertRolledBack(before_);
    }

    /// @notice Making the library quote internal does not expose a preview selector on the hook.
    function test_residualPreview_hasNoHookSelector() public view {
        assertEq(
            IDiamondLoupe(hook).facetAddress(bytes4(keccak256("previewResidualBuffer(uint256)"))),
            address(0),
            "no preview facet selector"
        );
    }

    /// @dev Accrue yield through the bound receipt's supported transition, without minting shares.
    function _prepareZeroQuote() private {
        uint256 supplyBefore = pairProtocolVault.totalSupply();
        uint256 assetsBefore = pairProtocolVault.totalAssets();
        pairToken.mint(address(this), assetsBefore);
        pairToken.approve(address(pairProtocolVault), assetsBefore);
        pairProtocolVault.simulateYield(assetsBefore);
        assertEq(pairProtocolVault.totalSupply(), supplyBefore, "yield mints no receipt shares");
        assertEq(pairProtocolVault.totalAssets(), assetsBefore * 2, "yield increases assets");
        _donatePair(1);
        uint256 excess = 1;
        assertGt(excess, 0, "nonzero sweep excess");
        vm.prank(hook);
        assertEq(ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(address(pairToken)), excess, IERC20(se)),
            0,
            "bound SE quotes the sweep excess to zero"
        );
    }

    /// @dev The existing receipt computes (assets * supply) / totalAssets with checked arithmetic.
    /// The smallest overflowing input is reachable by donating minted pair tokens to the hook.
    /// Parent operations may change receipt supply, but never quote the ambient amount.
    function _prepareRevertingQuote() private {
        uint256 excess = type(uint256).max / pairProtocolVault.totalSupply() + 1;
        _donatePair(excess);
        vm.expectRevert(_overflowPanic());
        vm.prank(hook);ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(address(pairToken)), excess, IERC20(se));
    }

    function _donatePair(uint256 amount) private {
        assertGt(pairToken.balanceOf(hook), 0, "genesis has booked local backing");
        pairToken.mint(user, amount);
        vm.prank(user);
        pairToken.transfer(hook, amount);
    }

    /// @dev No parent operation may evaluate a quote for the unbooked ambient amount.
    function _expectNoSweepQuote(uint256 excess) private {
        vm.expectCall(
            se,
            abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(pairToken)), excess, IERC20(se))),
            uint64(0)
        );
        vm.expectCall(
            address(pairProtocolVault), abi.encodeWithSignature("convertToShares(uint256)", excess), uint64(0)
        );
    }

    function _balances() private view returns (Balances memory b) {
        b.hookPair = pairToken.balanceOf(hook);
        b.localBook = seededLocal;
        b.excess = b.hookPair - b.localBook;
        b.hookSe = IERC20(se).balanceOf(hook);
        b.hookRaw = rawToken.balanceOf(hook);
        b.userPair = pairToken.balanceOf(user);
        b.userSe = IERC20(se).balanceOf(user);
        b.userRaw = rawToken.balanceOf(user);
        b.userLp = IERC20(hook).balanceOf(user);
        b.lpSupply = IERC20(hook).totalSupply();
        b.feeTo = _feeTo(); // Actual hook fee oracle result, including address(0).
        b.feePair = pairToken.balanceOf(b.feeTo);
        b.feeLp = IERC20(hook).balanceOf(b.feeTo);
    }

    function _assertResidualUnchanged(Balances memory b) private view {
        assertEq(pairToken.balanceOf(hook), b.hookPair, "pair retained in hook");
        assertEq(pairToken.balanceOf(user), b.userPair, "no dust payout to caller");
        assertEq(pairToken.balanceOf(b.feeTo), b.feePair, "no dust payout to fee recipient");
    }

    function _assertResidualRetained(Balances memory b, uint256 localChange, bool exit_) private view {
        assertEq(pairToken.balanceOf(hook), exit_ ? b.hookPair - localChange : b.hookPair + localChange,
            "only the operation's native local allocation moves");
        if (exit_) assertEq(pairToken.balanceOf(user), b.userPair, "share exit pays no ambient pair");
        else assertGe(pairToken.balanceOf(user), b.userPair, "caller may receive only its unused conversion proceeds");
        assertEq(pairToken.balanceOf(b.feeTo), b.feePair, "ambient pair not paid as fee");
    }

    function _ceil(uint256 mint_, uint256 component_, uint256 supply_) private pure returns (uint256) {
        uint256 product_ = mint_ * component_;
        return product_ / supply_ + (product_ % supply_ == 0 ? 0 : 1);
    }

    function _assertRolledBack(Balances memory b) private view {
        _assertResidualUnchanged(b);
        assertEq(IERC20(se).balanceOf(hook), b.hookSe, "hook SE rolled back");
        assertEq(rawToken.balanceOf(hook), b.hookRaw, "hook raw rolled back");
        assertEq(IERC20(se).balanceOf(user), b.userSe, "caller SE rolled back");
        assertEq(rawToken.balanceOf(user), b.userRaw, "caller raw rolled back");
        assertEq(IERC20(hook).balanceOf(user), b.userLp, "caller LP rolled back");
        assertEq(IERC20(hook).totalSupply(), b.lpSupply, "LP supply rolled back");
        assertEq(IERC20(hook).balanceOf(b.feeTo), b.feeLp, "protocol LP rolled back");
    }

    function _overflowPanic() private pure returns (bytes memory) {
        return abi.encodeWithSignature("Panic(uint256)", uint256(0x11));
    }
}
// end::UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test[]

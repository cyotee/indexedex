// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";

// tag::UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test[]
/// @title Residual preview through the installed production hook facets
/// @notice REQ-02: zero quotes retain dust; quote failures roll back the parent operation.
/// @dev depositWithSeShares reaches DepositCommon._refundPairDust; withdrawSeShares reaches
/// WithdrawalLib.refundPairDust. Neither entry moves pair tokens before the sweep, so the
/// pre-call pair balance minus Repo.MAX_DUST_WEI is exactly the sweep's quoted excess.
/// The monolithic Target._refundPairDust is not installed by this TestBase, and the
/// SeTarget._refundPairDust copy has no caller. Both remain unreached; no entry is added.
/// Revert witnesses use the bound receipt's existing checked convertToShares multiplication,
/// with a real pair-token donation. No receipt code, balanceOf behavior, or vault is replaced.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test is TestBase {
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
    }

    /// @notice Deploy the unchanged registry-bound hook and ERC-4626 SE, then fund both share entries.
    function setUp() public override {
        super.setUp();
        _seedLiveLiquidity();
        _mintSeSharesToUser(20 ether);
    }

    /// @notice DepositCommon leaves a zero-quoted excess local while minting the previewed LP.
    function test_residualPreview_deposit_zeroRetainsExcess() public {
        _prepareZeroQuote();
        Balances memory before_ = _balances();
        (uint256 lpExpected, uint256 rawExpected, uint256 seExpected) =
            single.previewDepositWithSeShares(10 ether, 10 ether);
        assertGt(lpExpected, 0, "positive parent minimum");
        _expectSweepQuote(before_.excess);

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
        assertEq(IERC20(se).balanceOf(hook), before_.hookSe + usedSe, "only parent SE intake");
        _assertResidualUnchanged(before_);
    }

    /// @notice WithdrawalLib leaves a zero-quoted excess local while paying the previewed basket.
    function test_residualPreview_withdraw_zeroRetainsExcess() public {
        _prepareZeroQuote();
        Balances memory before_ = _balances();
        (uint256 rawExpected, uint256 seExpected) = single.previewWithdrawSeShares(10 ether);
        assertGt(rawExpected, 0, "positive parent raw minimum");
        assertGt(seExpected, 0, "positive parent SE minimum");
        _expectSweepQuote(before_.excess);

        vm.prank(user);
        (uint256 rawOut, uint256 seOut) =
            single.withdrawSeShares(10 ether, user, rawExpected, seExpected, block.timestamp);

        assertEq(rawOut, rawExpected, "parent raw minimum and preview");
        assertEq(seOut, seExpected, "parent SE minimum and preview");
        assertEq(IERC20(hook).balanceOf(user), before_.userLp - 10 ether, "LP burned");
        assertEq(rawToken.balanceOf(user), before_.userRaw + rawOut, "raw payout");
        assertEq(rawToken.balanceOf(hook), before_.hookRaw - rawOut, "raw debit");
        assertEq(IERC20(se).balanceOf(user), before_.userSe + seOut, "SE payout");
        assertEq(IERC20(se).balanceOf(hook), before_.hookSe - seOut, "only parent SE debit");
        _assertResidualUnchanged(before_);
    }

    /// @notice DepositCommon propagates the exact quote panic and rolls back token pulls and LP minting.
    function test_residualPreview_deposit_quoteRevertRollsBack() public {
        _prepareRevertingQuote();
        Balances memory before_ = _balances();
        (uint256 lpExpected,,) = single.previewDepositWithSeShares(10 ether, 10 ether);
        assertGt(lpExpected, 0, "parent quote succeeds");
        _expectSweepQuote(before_.excess);

        vm.expectRevert(_overflowPanic());
        vm.prank(user);
        single.depositWithSeShares(10 ether, 10 ether, user, lpExpected, block.timestamp);

        _assertRolledBack(before_);
    }

    /// @notice WithdrawalLib propagates the exact quote panic and rolls back payouts and LP burning.
    function test_residualPreview_withdraw_quoteRevertRollsBack() public {
        _prepareRevertingQuote();
        Balances memory before_ = _balances();
        (uint256 rawExpected, uint256 seExpected) = single.previewWithdrawSeShares(10 ether);
        assertGt(rawExpected, 0, "parent raw quote succeeds");
        assertGt(seExpected, 0, "parent SE quote succeeds");
        _expectSweepQuote(before_.excess);

        vm.expectRevert(_overflowPanic());
        vm.prank(user);
        single.withdrawSeShares(10 ether, user, rawExpected, seExpected, block.timestamp);

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
        _donatePair(Repo.MAX_DUST_WEI + 1);
        uint256 excess = pairToken.balanceOf(hook) - Repo.MAX_DUST_WEI;
        assertGt(excess, 0, "nonzero sweep excess");
        vm.prank(hook);
        assertEq(
            IStandardExchangeIn(se).previewExchangeIn(IERC20(address(pairToken)), excess, IERC20(se)),
            0,
            "bound SE quotes the sweep excess to zero"
        );
    }

    /// @dev The existing receipt computes (assets * supply) / totalAssets with checked arithmetic.
    /// The smallest overflowing input is reachable by donating minted pair tokens to the hook.
    /// Share-only parent operations leave this amount and the receipt supply unchanged.
    function _prepareRevertingQuote() private {
        uint256 excess = type(uint256).max / pairProtocolVault.totalSupply() + 1;
        _donatePair(Repo.MAX_DUST_WEI + excess);
        assertEq(pairToken.balanceOf(hook) - Repo.MAX_DUST_WEI, excess, "exact overflowing sweep excess");
        vm.expectRevert(_overflowPanic());
        vm.prank(hook);
        IStandardExchangeIn(se).previewExchangeIn(IERC20(address(pairToken)), excess, IERC20(se));
    }

    function _donatePair(uint256 amount) private {
        assertEq(pairToken.balanceOf(hook), 0, "share setup leaves no free pair");
        pairToken.mint(user, amount);
        vm.prank(user);
        pairToken.transfer(hook, amount);
    }

    /// @dev Exact call counts prove the parent reaches this quote, including in the revert cases.
    function _expectSweepQuote(uint256 excess) private {
        vm.expectCall(
            se,
            abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(pairToken)), excess, IERC20(se))),
            uint64(1)
        );
        vm.expectCall(
            address(pairProtocolVault), abi.encodeWithSignature("convertToShares(uint256)", excess), uint64(1)
        );
    }

    function _balances() private view returns (Balances memory b) {
        b.hookPair = pairToken.balanceOf(hook);
        b.excess = b.hookPair - Repo.MAX_DUST_WEI;
        b.hookSe = IERC20(se).balanceOf(hook);
        b.hookRaw = rawToken.balanceOf(hook);
        b.userPair = pairToken.balanceOf(user);
        b.userSe = IERC20(se).balanceOf(user);
        b.userRaw = rawToken.balanceOf(user);
        b.userLp = IERC20(hook).balanceOf(user);
        b.lpSupply = IERC20(hook).totalSupply();
        b.feeTo = _feeTo(); // Actual hook fee oracle result, including address(0).
        b.feePair = pairToken.balanceOf(b.feeTo);
    }

    function _assertResidualUnchanged(Balances memory b) private view {
        assertEq(pairToken.balanceOf(hook), b.hookPair, "pair retained in hook");
        assertEq(pairToken.balanceOf(hook) - Repo.MAX_DUST_WEI, b.excess, "same excess retained");
        assertEq(pairToken.balanceOf(user), b.userPair, "no dust payout to caller");
        assertEq(pairToken.balanceOf(b.feeTo), b.feePair, "no dust payout to fee recipient");
    }

    function _assertRolledBack(Balances memory b) private view {
        _assertResidualUnchanged(b);
        assertEq(IERC20(se).balanceOf(hook), b.hookSe, "hook SE rolled back");
        assertEq(rawToken.balanceOf(hook), b.hookRaw, "hook raw rolled back");
        assertEq(IERC20(se).balanceOf(user), b.userSe, "caller SE rolled back");
        assertEq(rawToken.balanceOf(user), b.userRaw, "caller raw rolled back");
        assertEq(IERC20(hook).balanceOf(user), b.userLp, "caller LP rolled back");
        assertEq(IERC20(hook).totalSupply(), b.lpSupply, "LP supply rolled back");
    }

    function _overflowPanic() private pure returns (bytes memory) {
        return abi.encodeWithSignature("Panic(uint256)", uint256(0x11));
    }
}
// end::UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview_Test[]

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial} from "./TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol";

/// @notice APEX matrix finding F6 diagnostic (owner-approved 2026-09-21). Measures, on the FullSpread V4
///         vault alone (no hook), how far the share-to-token zap-out executes from its own preview under
///         four states: fresh after a single-token deposit, after market trades that accrue fees and move
///         the price, with a 20% liquid sleeve, and for the exact-out route. Diagnostic only: it records
///         signed basis-point deltas and asserts nothing about them beyond a positive delivery, so the
///         numbers can be read from the log before a fix side is chosen.
contract UniswapV4FullSpreadStandardExchangeVault_F6Diagnostic is TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial {
    IStandardExchangeIn internal seIn_;
    IStandardExchangeOut internal seOut_;

    function test_F6_diagnostic_zapOutPreviewVersusExecution() public {
        seIn_ = IStandardExchangeIn(address(subject));
        seOut_ = IStandardExchangeOut(address(subject));
        _seedMarket();
        _fund(asset0, address(this), 1_500 ether);
        _fund(asset1, address(this), 1_000 ether);
        // The FullSpread vault's first mint is the dual-token join; a single-token zap-in on an idle vault is 0.
        uint256 shares = _join(1_000 ether, 1_000 ether, address(this));
        uint256 burn = shares / 10;
        _report("fresh after dual-token first mint", burn);
        asset0.approve(address(subject), 500 ether);
        seIn_.exchangeIn(asset0, 500 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp);
        _report("after a single-token zap-in deposit", burn);
        _trade(true, 100 ether);
        _trade(false, 100 ether);
        _report("after market trades (fees accrued, price moved)", burn);
        _configureSleeve(0.2e18);
        _rebalance();
        _report("with 20% liquid sleeve after rebalance", burn);
    }

    /// @notice APEX F6 fix gate (owner ruling 2026-09-21): exact-out zap-out preview and execution match
    ///         exactly. The SE spends exactly the previewed shares and delivers exactly the requested amount;
    ///         any zap-out surplus stays in the vault. Exact-in equality is asserted as the control.
    ///         Red before the fix (execution delivered requested + 99 bps), green after.
    function test_F6_exactOut_previewAndExecutionMatchExactly() public {
        seIn_ = IStandardExchangeIn(address(subject));
        seOut_ = IStandardExchangeOut(address(subject));
        _seedMarket();
        _fund(asset0, address(this), 1_500 ether);
        _fund(asset1, address(this), 1_000 ether);
        uint256 shares = _join(1_000 ether, 1_000 ether, address(this));
        _assertExactRoutes(shares / 10);
        asset0.approve(address(subject), 500 ether);
        seIn_.exchangeIn(asset0, 500 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp);
        _assertExactRoutes(shares / 10);
        _trade(true, 100 ether);
        _trade(false, 100 ether);
        _assertExactRoutes(shares / 10);
        _configureSleeve(0.2e18);
        _rebalance();
        _assertExactRoutes(shares / 10);
    }

    function _assertExactRoutes(uint256 burn) internal {
        _assertExactIn(asset0, burn);
        _assertExactIn(asset1, burn);
        _assertExactOut(asset0, 10 ether);
        _assertExactOut(asset1, 10 ether);
    }

    function _assertExactIn(IERC20 tokenOut, uint256 burn) internal {
        uint256 snap = vm.snapshotState();
        uint256 preview = seIn_.previewExchangeIn(IERC20(address(subject)), burn, tokenOut);
        subject.approve(address(subject), burn);
        uint256 before = tokenOut.balanceOf(address(this));
        uint256 got = seIn_.exchangeIn(IERC20(address(subject)), burn, tokenOut, 0, address(this), false, block.timestamp);
        assertEq(got, preview, "F6: exact-in delivery equals preview to the wei");
        assertEq(tokenOut.balanceOf(address(this)) - before, got, "F6: exact-in returned amount is the delivered amount");
        vm.revertToState(snap);
    }

    function _assertExactOut(IERC20 tokenOut, uint256 want) internal {
        uint256 snap = vm.snapshotState();
        uint256 previewShares = seOut_.previewExchangeOut(IERC20(address(subject)), tokenOut, want);
        assertGt(previewShares, 0, "F6: exact-out route is quoted");
        subject.approve(address(subject), previewShares * 2);
        uint256 before = tokenOut.balanceOf(address(this));
        uint256 vaultBefore = tokenOut.balanceOf(address(subject));
        uint256 sharesBefore = subject.balanceOf(address(this));
        uint256 spent = seOut_.exchangeOut(IERC20(address(subject)), previewShares * 2, tokenOut, want, address(this), false, block.timestamp);
        assertEq(spent, previewShares, "F6: exact-out returns the previewed shares");
        assertEq(sharesBefore - subject.balanceOf(address(this)), previewShares, "F6: exact-out burns exactly the previewed shares");
        assertEq(tokenOut.balanceOf(address(this)) - before, want, "F6: exact-out delivers exactly the requested amount");
        assertGe(tokenOut.balanceOf(address(subject)), vaultBefore > want ? vaultBefore - want : 0, "F6: any zap-out surplus stays in the vault");
        vm.revertToState(snap);
    }

    function _report(string memory label, uint256 burn) internal {
        emit log(string.concat("--- F6 ", _family(), ": ", label));
        _reportExactIn(asset0, burn, "exact-in se->asset0");
        _reportExactIn(asset1, burn, "exact-in se->asset1");
        _reportExactOut(asset0, "exact-out se->asset0");
        _reportExactOut(asset1, "exact-out se->asset1");
    }

    function _reportExactIn(IERC20 tokenOut, uint256 burn, string memory route) internal {
        uint256 snap = vm.snapshotState();
        uint256 preview = seIn_.previewExchangeIn(IERC20(address(subject)), burn, tokenOut);
        subject.approve(address(subject), burn);
        uint256 before = tokenOut.balanceOf(address(this));
        uint256 got = seIn_.exchangeIn(IERC20(address(subject)), burn, tokenOut, 0, address(this), false, block.timestamp);
        assertGt(got, 0, "zap-out delivers");
        assertEq(tokenOut.balanceOf(address(this)) - before, got, "returned amount is the delivered amount");
        vm.revertToState(snap);
        _logDelta(route, preview, got);
    }

    function _reportExactOut(IERC20 tokenOut, string memory route) internal {
        uint256 snap = vm.snapshotState();
        uint256 want = 10 ether;
        uint256 previewShares = seOut_.previewExchangeOut(IERC20(address(subject)), tokenOut, want);
        if (previewShares == 0) {
            vm.revertToState(snap);
            emit log(string.concat("    ", route, ": exact-out route not quoted (0)"));
            return;
        }
        subject.approve(address(subject), previewShares * 2);
        uint256 before = tokenOut.balanceOf(address(this));
        uint256 sharesBefore = subject.balanceOf(address(this));
        seOut_.exchangeOut(IERC20(address(subject)), previewShares * 2, tokenOut, want, address(this), false, block.timestamp);
        uint256 spent = sharesBefore - subject.balanceOf(address(this));
        uint256 delivered = tokenOut.balanceOf(address(this)) - before;
        vm.revertToState(snap);
        _logDelta(string.concat(route, " shares spent vs previewed"), previewShares, spent);
        _logDelta(string.concat(route, " delivered vs requested"), want, delivered);
    }

    /// @dev Signed basis points of (actual - preview) / preview.
    function _logDelta(string memory route, uint256 preview, uint256 actual) internal {
        int256 bps = preview == 0 ? int256(0) : (int256(actual) - int256(preview)) * 10_000 / int256(preview);
        emit log_named_uint(string.concat("    ", route, " preview"), preview);
        emit log_named_uint(string.concat("    ", route, " actual"), actual);
        emit log_named_int(string.concat("    ", route, " delta bps"), bps);
    }
}

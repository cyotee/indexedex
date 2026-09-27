// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareOracle} from
    "test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareOracle.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

contract RebasingAwareERC4626_StandardExchange is TestBase_RebasingAwareERC4626 {
    function _se() internal view returns (IStandardExchangeIn) {
        return IStandardExchangeIn(address(vault));
    }

    function _seOut() internal view returns (IStandardExchangeOut) {
        return IStandardExchangeOut(address(vault));
    }

    function test_API04_assetToShareExactIn() public {
        uint256 assets = 40e18;
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.sharesForDeposit(assets, 0, 0, V);
        vm.prank(alice);
        uint256 out = _se().exchangeIn(
            IERC20(address(asset)), assets, IERC20(address(vault)), expected, alice, false, block.timestamp
        );
        assertEq(out, expected);
        assertEq(IERC20(address(vault)).balanceOf(alice), expected);
    }

    function test_API04_shareToAssetExactIn() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(80e18, alice);
        uint256 A = vault.totalAssets();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.assetsForRedeem(shares / 2, A, S, V);
        vm.prank(alice);
        uint256 out = _se().exchangeIn(
            IERC20(address(vault)),
            shares / 2,
            IERC20(address(asset)),
            expected,
            alice,
            false,
            block.timestamp
        );
        assertEq(out, expected);
    }

    function test_API04_assetToShareExactOut() public {
        uint256 shares = 7e18;
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expectedIn = RebasingAwareOracle.assetsForMint(shares, 0, 0, V);
        vm.prank(alice);
        uint256 inAmt = _seOut().exchangeOut(
            IERC20(address(asset)),
            expectedIn,
            IERC20(address(vault)),
            shares,
            alice,
            false,
            block.timestamp
        );
        assertEq(inAmt, expectedIn);
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
    }

    function test_API04_shareToAssetExactOut() public {
        vm.prank(alice);
        vault.deposit(90e18, alice);
        uint256 A = vault.totalAssets();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 assetsOut = 4e18;
        uint256 expectedShares = RebasingAwareOracle.sharesForWithdraw(assetsOut, A, S, V);
        vm.prank(alice);
        uint256 burned = _seOut().exchangeOut(
            IERC20(address(vault)),
            expectedShares,
            IERC20(address(asset)),
            assetsOut,
            alice,
            false,
            block.timestamp
        );
        assertEq(burned, expectedShares);
    }

    function test_API07_assetPretransferReverts() public {
        vm.prank(alice);
        asset.transfer(address(vault), 10e18);
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        _se().exchangeIn(
            IERC20(address(asset)), 10e18, IERC20(address(vault)), 0, alice, true, block.timestamp
        );
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        _seOut().exchangeOut(
            IERC20(address(asset)), 10e18, IERC20(address(vault)), 1, alice, true, block.timestamp
        );
    }

    function test_API07_sharePretransferBurnsBAndRefundsPB() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(50e18, alice);
        uint256 burnAmt = shares / 4;
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares / 2);
        uint256 P = IERC20(address(vault)).balanceOf(address(vault));
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _se().exchangeIn(
            IERC20(address(vault)), burnAmt, IERC20(address(asset)), 0, bob, true, block.timestamp
        );
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        _se().exchangeIn(
            IERC20(address(vault)), burnAmt, IERC20(address(asset)), 0, bob, true, block.timestamp
        );
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), P - burnAmt);
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), 0);
    }

    function test_API04_invalidRouteReverts() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStandardExchangeErrors.InvalidRoute.selector, address(asset), address(asset)
            )
        );
        _se().exchangeIn(
            IERC20(address(asset)), 1e18, IERC20(address(asset)), 0, alice, false, block.timestamp
        );
    }

    function test_API04_expiredDeadlineReverts() public {
        // R2.4: pin the typed selector — `RebasingAwareERC4626Common.requireDeadline` reverts
        // `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)` (0x24bf66c5).
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, block.timestamp - 1, block.timestamp)
        );
        _se().exchangeIn(
            IERC20(address(asset)), 1e18, IERC20(address(vault)), 0, alice, false, block.timestamp - 1
        );
    }

    function test_previewZeroInvalidRouteReturnsZero() public {
        assertEq(_se().previewExchangeIn(IERC20(address(asset)), 0, IERC20(address(0))), 0);
    }

    function test_sameSnapshotSeMatchesErc4626() public {
        uint256 snap = vm.snapshotState();
        vm.prank(alice);
        uint256 seShares = _se().exchangeIn(
            IERC20(address(asset)), 11e18, IERC20(address(vault)), 0, alice, false, block.timestamp
        );
        vm.revertToState(snap);
        vm.prank(alice);
        uint256 ercShares = vault.deposit(11e18, alice);
        assertEq(seShares, ercShares);
    }

    function test_F08_deadlineEqualSucceeds_minAtEquality() public {
        uint256 assets = 3e18;
        uint256 preview =
            _se().previewExchangeIn(IERC20(address(asset)), assets, IERC20(address(vault)));
        vm.prank(alice);
        uint256 out = _se().exchangeIn(
            IERC20(address(asset)), assets, IERC20(address(vault)), preview, alice, false, block.timestamp
        );
        assertEq(out, preview);
        vm.prank(alice);
        vm.expectPartialRevert(bytes4(keccak256("MinAmountNotMet(uint256,uint256)")));
        _se().exchangeIn(
            IERC20(address(asset)),
            1e18,
            IERC20(address(vault)),
            preview + 1,
            alice,
            false,
            block.timestamp
        );
    }

    function test_F08_exactOutMaxAtEquality() public {
        uint256 shares = 2e18;
        uint256 need =
            _seOut().previewExchangeOut(IERC20(address(asset)), IERC20(address(vault)), shares);
        vm.prank(alice);
        uint256 paid = _seOut().exchangeOut(
            IERC20(address(asset)), need, IERC20(address(vault)), shares, alice, false, block.timestamp
        );
        assertEq(paid, need);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("MaxAmountExceeded(uint256,uint256)", need - 1, need));
        _seOut().exchangeOut(
            IERC20(address(asset)),
            need - 1,
            IERC20(address(vault)),
            shares,
            alice,
            false,
            block.timestamp
        );
    }

    function test_API07_sharePretransferExactOutBurnsBRefundsPB() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(60e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares / 2);
        uint256 P = IERC20(address(vault)).balanceOf(address(vault));
        uint256 A = vault.totalAssets();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 assetsOut = 3e18;
        uint256 B = RebasingAwareOracle.sharesForWithdraw(assetsOut, A, S, V);
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _seOut().exchangeOut(
            IERC20(address(vault)),
            P,
            IERC20(address(asset)),
            assetsOut,
            bob,
            true,
            block.timestamp
        );
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        uint256 burned = _seOut().exchangeOut(
            IERC20(address(vault)),
            P,
            IERC20(address(asset)),
            assetsOut,
            bob,
            true,
            block.timestamp
        );
        assertEq(burned, B);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), P - B);
        assertEq(asset.balanceOf(bob), 1_000_000e18 + assetsOut);
    }

    function test_APEX003_eoaSharePretransferRejected() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(20e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares);
        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _se().exchangeIn(
            IERC20(address(vault)), 1e11, IERC20(address(asset)), 0, attacker, true, block.timestamp
        );
    }

    function test_APEX003_contractExactInBurnsRequestedOnly() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(50e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares);
        uint256 resting = IERC20(address(vault)).balanceOf(address(vault));
        uint256 burnAmt = resting / 10;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (IERC20(address(vault)), burnAmt, IERC20(address(asset)), 0, address(caller), true, block.timestamp)
        );
        uint256 assetsOut = abi.decode(caller.execute(address(vault), data), (uint256));
        assertGt(assetsOut, 0);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), resting - burnAmt);
        assertEq(IERC20(address(vault)).balanceOf(address(caller)), 0);
    }

    /// @notice R5.2 (2026-09-23): the exact-in share pretransfer shortfall reverts with the exact
    ///         `TransferDeltaInsufficient(amountIn, selfShareBalance)` from a contract caller.
    function test_APEX003_contractExactInShortfall_revertsExactArgs() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(50e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares);
        uint256 resting = IERC20(address(vault)).balanceOf(address(vault));
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, resting + 1, resting)
        );
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)), resting + 1, IERC20(address(asset)), 0, address(caller), true, block.timestamp
        );
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), resting, "resting shares untouched");
    }

    function test_previewPositiveInvalidRouteReverts() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidRoute(address,address)", address(asset), address(asset)));
        _se().previewExchangeIn(IERC20(address(asset)), 1e18, IERC20(address(asset)));
    }

    function test_zeroPreviewAllSeOverloads() public view {
        assertEq(_se().previewExchangeIn(IERC20(address(asset)), 0, IERC20(address(vault))), 0);
        assertEq(_seOut().previewExchangeOut(IERC20(address(asset)), IERC20(address(vault)), 0), 0);
        assertEq(_se().previewExchangeIn(IERC20(address(vault)), 0, IERC20(address(asset))), 0);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareOracle} from
    "test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareOracle.sol";
import {
    IStandardExchangeTransitionQuote
} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

contract RebasingAwareERC4626_Fuzz is TestBase_RebasingAwareERC4626 {
    function testFuzz_FUZZ01_depositMatchesOracle(uint96 assets) public {
        assets = uint96(bound(assets, 1, 1_000e18));
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.sharesForDeposit(assets, 0, 0, V);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, expected);
    }

    function testFuzz_FUZZ01_previewMatchesDeposit(uint96 assets) public {
        assets = uint96(bound(assets, 1, 1_000e18));
        uint256 preview = vault.previewDeposit(assets);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, preview);
    }

    function testFuzz_FUZZ01_crossInterfaceSameSnapshot(uint96 assets) public {
        assets = uint96(bound(assets, 1, 500e18));
        uint256 snap = vm.snapshotState();
        vm.prank(alice);
        uint256 erc = vault.deposit(assets, alice);
        vm.revertToState(snap);
        vm.prank(alice);
        uint256 se = IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(asset)), assets, IERC20(address(vault)), 0, alice, false, block.timestamp
        );
        vm.revertToState(snap);
        vm.prank(alice);
        uint256 sy = IStandardizedYield(address(vault)).deposit(alice, address(asset), assets, 0);
        assertEq(erc, se);
        assertEq(se, sy);
    }

    function testFuzz_FUZZ02_exactOutMinimals(uint96 shares) public {
        shares = uint96(bound(shares, 1e10, 50e18));
        uint256 need = IStandardExchangeOut(address(vault)).previewExchangeOut(
            IERC20(address(asset)), IERC20(address(vault)), shares
        );
        vm.assume(need > 1 && need < 1_000e18);
        uint256 snap = vm.snapshotState();
        vm.prank(alice);
        vm.expectRevert();
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(asset)),
            need - 1,
            IERC20(address(vault)),
            shares,
            alice,
            false,
            block.timestamp
        );
        vm.revertToState(snap);
        vm.prank(alice);
        uint256 paid = IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(asset)),
            need,
            IERC20(address(vault)),
            shares,
            alice,
            false,
            block.timestamp
        );
        assertEq(paid, need);
    }

    function testFuzz_FUZZ03_closedCycleNoProfit(uint96 assets) public {
        assets = uint96(bound(assets, 1e18, 200e18));
        uint256 before = asset.balanceOf(alice);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        vm.prank(alice);
        vault.redeem(shares, alice, alice);
        assertLe(asset.balanceOf(alice), before);
    }

    function testFuzz_FUZZ04_donationDoesNotMintShares(uint96 donation) public {
        donation = uint96(bound(donation, 1, 100e18));
        uint256 supply = IERC20(address(vault)).totalSupply();
        asset.mint(address(vault), donation);
        assertEq(IERC20(address(vault)).totalSupply(), supply);
    }

    function testFuzz_FUZZ06_allowanceOwnerRedeem(uint96 assets) public {
        assets = uint96(bound(assets, 1e18, 50e18));
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        vm.prank(alice);
        IERC20(address(vault)).approve(bob, shares / 2);
        vm.prank(bob);
        uint256 out = vault.redeem(shares / 2, bob, alice);
        assertGt(out, 0);
        assertEq(IERC20(address(vault)).allowance(alice, bob), 0);
    }

    function testFuzz_FUZZ09_assetPretransferAlwaysReverts(uint96 amount, bool exactOut) public {
        amount = uint96(bound(amount, 1, 50e18));
        vm.prank(alice);
        asset.transfer(address(vault), amount);
        uint256 supply = IERC20(address(vault)).totalSupply();
        if (exactOut) {
            vm.prank(alice);
            vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
            IStandardExchangeOut(address(vault)).exchangeOut(
                IERC20(address(asset)), amount, IERC20(address(vault)), 1, alice, true, block.timestamp
            );
        } else {
            vm.prank(alice);
            vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
            IStandardExchangeIn(address(vault)).exchangeIn(
                IERC20(address(asset)), amount, IERC20(address(vault)), 0, alice, true, block.timestamp
            );
        }
        assertEq(IERC20(address(vault)).totalSupply(), supply);
    }

    function testFuzz_FUZZ10_sharePretransferRefundConservation(uint96 assets) public {
        assets = uint96(bound(assets, 10e18, 80e18));
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        uint256 prepaid = shares / 2;
        vm.assume(prepaid > 0);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), prepaid);
        uint256 P = IERC20(address(vault)).balanceOf(address(vault));
        uint256 burnAmt = prepaid / 3;
        vm.assume(burnAmt > 0);
        uint256 aliceBefore = IERC20(address(vault)).balanceOf(alice);
        vm.prank(alice);
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)), burnAmt, IERC20(address(asset)), 0, bob, true, block.timestamp
        );
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
        assertEq(IERC20(address(vault)).balanceOf(alice), aliceBefore + (P - burnAmt));
    }

    function testFuzz_FUZZ11_quoteDepositMatchesExecution(uint96 assets) public {
        assets = uint96(bound(assets, 1e18, 40e18));
        IStandardExchangeTransitionQuote q = IStandardExchangeTransitionQuote(address(vault));
        (bytes memory state,) = q.quoteState(address(asset), alice);
        (bytes memory next, uint256 inAmt, uint256 outAmt,) = q.quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, assets
        );
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        assertEq(shares, outAmt);
        assertEq(inAmt, assets);
        (bytes memory live,) = q.quoteState(address(asset), alice);
        assertEq(keccak256(live), keccak256(next));
    }

    function testFuzz_FUZZ13_zeroAmountAlwaysReverts(uint8 route) public {
        route = uint8(bound(route, 0, 3));
        vm.startPrank(alice);
        if (route == 0) {
            vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
            vault.deposit(0, alice);
        } else if (route == 1) {
            vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
            vault.mint(0, alice);
        } else if (route == 2) {
            vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
            IStandardExchangeIn(address(vault)).exchangeIn(
                IERC20(address(asset)), 0, IERC20(address(vault)), 0, alice, false, block.timestamp
            );
        } else {
            vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
            IStandardizedYield(address(vault)).deposit(alice, address(asset), 0, 0);
        }
        vm.stopPrank();
        assertEq(vault.previewDeposit(0), 0);
    }

    function testFuzz_redeemDoesNotExceedBacking(uint96 assets) public {
        assets = uint96(bound(assets, 1, 500e18));
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        uint256 before = vault.totalAssets();
        vm.prank(alice);
        uint256 out = vault.redeem(shares, alice, alice);
        assertLe(out, before);
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {
    TestBase_RebasingAwareERC4626
} from "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";

/// @notice Independent integer accounting over changed backing, all money routes and public shares.
contract RebasingAwareERC4626_ReleaseFuzz is TestBase_RebasingAwareERC4626 {
    uint256 private constant V = 1e10;

    function testFuzz_FUZZ04_attackerPaysDonationCost(uint32 entrySeed, uint96 donationSeed, uint96 victimSeed) public {
        uint256 entry = bound(entrySeed, 1, 1e6);
        uint256 donation = bound(donationSeed, 1, 100e18);
        uint256 victim = bound(victimSeed, 1e15, 10e18);
        uint256 attackerBefore = asset.balanceOf(attacker);
        vm.startPrank(attacker);
        uint256 attackerShares = vault.deposit(entry, attacker);
        asset.transfer(address(vault), donation);
        vm.stopPrank();
        uint256 roundingBound = _ceil(entry + donation + 1, attackerShares + V) + 1;
        uint256 expectedShares = victim * (attackerShares + V) / (entry + donation + 1);
        vm.prank(alice);
        uint256 victimShares = vault.deposit(victim, alice);
        assertEq(victimShares, expectedShares);
        vm.prank(attacker);
        vault.redeem(attackerShares, attacker, attacker);
        assertLe(asset.balanceOf(attacker), attackerBefore, "donation attack extracted victim assets");
        vm.prank(alice);
        uint256 recovered = vault.redeem(victimShares, alice, alice);
        assertGe(recovered + roundingBound, victim, "victim loss exceeds two conversion floors");
    }

    function testFuzz_FUZZ01_allRoutesAtChangedBacking(uint96 backingSeed, uint96 amountSeed) public {
        uint256 backing = bound(backingSeed, 1e18, 200e18);
        uint256 amount = bound(amountSeed, 1e10, 1e17);
        _book(backing);
        uint256 supply = vault.totalSupply();
        uint256 snap = vm.snapshotState();
        for (uint256 route; route < 10; ++route) {
            uint256 input = (route == 1 || route == 3 || route == 5 || route == 7 || route == 9) ? amount * V : amount;
            uint256 expected = route == 1 || route == 3
                ? _ceil(input * (backing + 1), supply + V)
                : route == 6 || route == 8
                    ? _ceil(input * (supply + V), backing + 1)
                    : route >= 5 ? input * (backing + 1) / (supply + V) : input * (supply + V) / (backing + 1);
            vm.prank(alice);
            assertEq(_route(route, input), expected);
            uint256 assetsMoved = route == 1 || route == 3 || route == 5 || route == 7 || route == 9 ? expected : input;
            uint256 sharesMoved = assetsMoved == input
                && (route == 0 || route == 2 || route == 4 || route == 6 || route == 8)
                ? expected
                : input;
            assertEq(vault.totalAssets(), route < 5 ? backing + assetsMoved : backing - assetsMoved);
            assertEq(vault.totalSupply(), route < 5 ? supply + sharesMoved : supply - sharesMoved);
            assertTrue(vm.revertToState(snap));
        }
    }

    function testFuzz_FUZZ05_decimalsAndQuantizedRate(uint8 decimalsSeed, uint8 offsetSeed, uint96 backingSeed) public {
        uint8 offset = uint8(bound(offsetSeed, 10, 18));
        uint8 decimals_ = uint8(bound(decimalsSeed, 0, 77 - offset));
        ERC20PermitMintableStub token = new ERC20PermitMintableStub("Rate asset", "RA", decimals_, owner, 0);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(token)), offset, bytes32(0));
        assertEq(IERC20Metadata(address(wrapped)).decimals(), decimals_ + offset);
        token.mint(alice, 1e18);
        vm.startPrank(alice);
        token.approve(address(wrapped), type(uint256).max);
        wrapped.deposit(1e18, alice);
        vm.stopPrank();
        uint256 backing = bound(backingSeed, 1, 1_000e18);
        if (backing < 1e18) token.burn(address(wrapped), 1e18 - backing);
        else token.mint(address(wrapped), backing - 1e18);
        uint256 denominator = wrapped.totalSupply() + 10 ** uint256(offset);
        uint256 numerator = 1e18 * (backing + 1);
        uint256 expected = numerator / denominator;
        if (expected == 0) {
            vm.expectRevert(IRebasingAwareERC4626.SYExchangeRateUnderflow.selector);
            IStandardizedYield(address(wrapped)).exchangeRate();
        } else {
            uint256 rate = IStandardizedYield(address(wrapped)).exchangeRate();
            assertEq(rate, expected);
            assertLt(numerator - rate * denominator, denominator);
        }
    }

    function testFuzz_FUZZ07_limitsFailAtomically(uint96 backingSeed, uint96 amountSeed, bool exactOut) public {
        uint256 backing = bound(backingSeed, 1e18, 200e18);
        uint256 amount = bound(amountSeed, 1e10, 1e17);
        _book(backing);
        uint256 supply = vault.totalSupply();
        uint256 payer = asset.balanceOf(alice);
        uint256 held = vault.balanceOf(alice);
        if (exactOut) {
            uint256 required = _ceil(amount * V * (backing + 1), supply + V);
            vm.expectRevert(
                abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, required - 1, required)
            );
            vm.prank(alice);
            IStandardExchangeOut(address(vault))
                .exchangeOut(
                    IERC20(address(asset)),
                    required - 1,
                    IERC20(address(vault)),
                    amount * V,
                    bob,
                    false,
                    block.timestamp
                );
        } else {
            uint256 expected = amount * (supply + V) / (backing + 1);
            vm.expectRevert(
                abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, expected + 1, expected)
            );
            vm.prank(alice);
            IStandardExchangeIn(address(vault))
                .exchangeIn(
                    IERC20(address(asset)), amount, IERC20(address(vault)), expected + 1, bob, false, block.timestamp
                );
        }
        assertEq(vault.totalAssets(), backing);
        assertEq(vault.totalSupply(), supply);
        assertEq(asset.balanceOf(alice), payer);
        assertEq(vault.balanceOf(alice), held);
        vm.prank(alice);
        assertGt(vault.deposit(amount, alice), 0, "failed operation left a lock");
    }

    function testFuzz_FUZZ08_twoHolderLossRecoveryAndFullExit(uint96 recoverySeed) public {
        _book(100e18);
        vm.prank(bob);
        vault.deposit(100e18, bob);
        uint256 supply = vault.totalSupply();
        asset.burn(address(vault), 200e18);
        vm.expectRevert(IRebasingAwareERC4626.ZeroReserveWithOutstandingShares.selector);
        vm.prank(alice);
        vault.mint(1, alice);
        uint256 recovery = bound(recoverySeed, 1e18, 500e18);
        asset.mint(address(vault), recovery);
        uint256 firstShares = vault.balanceOf(alice);
        uint256 firstAssets = firstShares * (recovery + 1) / (supply + V);
        vm.prank(alice);
        assertEq(vault.redeem(firstShares, alice, alice), firstAssets);
        uint256 secondShares = vault.balanceOf(bob);
        uint256 secondAssets = secondShares * (recovery - firstAssets + 1) / (supply - firstShares + V);
        vm.prank(bob);
        assertEq(vault.redeem(secondShares, bob, bob), secondAssets);
        assertEq(vault.totalSupply(), 0);
        uint256 residual = recovery - firstAssets - secondAssets;
        assertEq(vault.totalAssets(), residual);
        vm.prank(alice);
        assertEq(vault.deposit(1e18, alice), 1e18 * V / (residual + 1));
    }

    function testFuzz_FUZZ10_FUZZ12_exactOutPublicBudget(uint96 budgetSeed, uint96 outSeed, bool otherReceiver) public {
        _book(150e18);
        uint256 payout = bound(outSeed, 1e10, 1e18);
        uint256 required = _ceil(payout * (vault.totalSupply() + V), 150e18 + 1);
        uint256 budget = bound(budgetSeed, required, vault.balanceOf(alice));
        address receiver = otherReceiver ? bob : alice;
        vm.prank(alice);
        vault.transfer(address(vault), budget);
        uint256 supply = vault.totalSupply();
        uint256 callerShares = vault.balanceOf(alice);
        uint256 receiverAssets = asset.balanceOf(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, required - 1, required)
        );
        vm.prank(alice);
        IStandardExchangeOut(address(vault))
            .exchangeOut(
                IERC20(address(vault)), required - 1, IERC20(address(asset)), payout, receiver, true, block.timestamp
            );
        assertEq(vault.balanceOf(address(vault)), budget);
        assertEq(vault.totalAssets(), 150e18);
        vm.prank(alice);
        uint256 burned = IStandardExchangeOut(address(vault))
            .exchangeOut(
                IERC20(address(vault)), required, IERC20(address(asset)), payout, receiver, true, block.timestamp
            );
        assertEq(burned, required);
        assertEq(vault.balanceOf(alice) - callerShares + burned, budget);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply - required);
        assertEq(asset.balanceOf(receiver), receiverAssets + payout);
        assertEq(vault.totalAssets(), 150e18 - payout);
    }

    function testFuzz_FUZZ13_allTenZeroRoutes(uint8 routeSeed, uint96 backingSeed) public {
        _book(bound(backingSeed, 1e18, 200e18));
        uint256 backing = vault.totalAssets();
        uint256 supply = vault.totalSupply();
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vm.prank(alice);
        _route(routeSeed % 10, 0);
        assertEq(vault.totalAssets(), backing);
        assertEq(vault.totalSupply(), supply);
        assertEq(vault.previewDeposit(0), 0);
        assertEq(vault.previewMint(0), 0);
        assertEq(vault.previewWithdraw(0), 0);
        assertEq(vault.previewRedeem(0), 0);
        assertEq(IStandardizedYield(address(vault)).previewDeposit(address(asset), 0), 0);
        assertEq(IStandardizedYield(address(vault)).previewRedeem(address(asset), 0), 0);
        assertEq(
            IStandardExchangeIn(address(vault)).previewExchangeIn(IERC20(address(asset)), 0, IERC20(address(vault))), 0
        );
        assertEq(
            IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(vault)), IERC20(address(asset)), 0),
            0
        );
    }

    function _book(uint256 backing) private {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        if (backing < 100e18) asset.burn(address(vault), 100e18 - backing);
        else asset.mint(address(vault), backing - 100e18);
    }

    function _ceil(uint256 numerator, uint256 denominator) private pure returns (uint256) {
        return numerator / denominator + (numerator % denominator == 0 ? 0 : 1);
    }

    function _route(uint256 route, uint256 amount) private returns (uint256) {
        IERC20 a = IERC20(address(asset));
        IERC20 s = IERC20(address(vault));
        if (route == 0) return vault.deposit(amount, alice);
        if (route == 1) return vault.mint(amount, alice);
        if (route == 2) {
            return IStandardExchangeIn(address(vault)).exchangeIn(a, amount, s, 0, alice, false, block.timestamp);
        }
        if (route == 3) {
            return IStandardExchangeOut(address(vault))
                .exchangeOut(a, type(uint256).max, s, amount, alice, false, block.timestamp);
        }
        if (route == 4) return IStandardizedYield(address(vault)).deposit(alice, address(asset), amount, 0);
        if (route == 5) return vault.redeem(amount, alice, alice);
        if (route == 6) return vault.withdraw(amount, alice, alice);
        if (route == 7) {
            return IStandardExchangeIn(address(vault)).exchangeIn(s, amount, a, 0, alice, false, block.timestamp);
        }
        if (route == 8) {
            return IStandardExchangeOut(address(vault))
                .exchangeOut(s, type(uint256).max, a, amount, alice, false, block.timestamp);
        }
        return IStandardizedYield(address(vault)).redeem(alice, amount, address(asset), 0, false);
    }
}

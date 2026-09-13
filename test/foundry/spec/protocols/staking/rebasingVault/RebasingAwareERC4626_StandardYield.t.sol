// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingAwareOracle} from
    "test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareOracle.sol";

contract RebasingAwareERC4626_StandardYield is TestBase_RebasingAwareERC4626 {
    function _sy() internal view returns (IStandardizedYield) {
        return IStandardizedYield(address(vault));
    }

    function test_API08_discovery() public view {
        assertEq(_sy().yieldToken(), address(asset));
        (IStandardizedYield.AssetType kind, address assetAddr, uint8 decs) = _sy().assetInfo();
        assertEq(uint8(kind), uint8(IStandardizedYield.AssetType.TOKEN));
        assertEq(assetAddr, address(asset));
        assertEq(decs, 18);
        address[] memory tokensIn = _sy().getTokensIn();
        address[] memory tokensOut = _sy().getTokensOut();
        assertEq(tokensIn.length, 1);
        assertEq(tokensOut.length, 1);
        assertEq(tokensIn[0], address(asset));
        assertEq(tokensOut[0], address(asset));
        assertTrue(_sy().isValidTokenIn(address(asset)));
        assertTrue(_sy().isValidTokenOut(address(asset)));
        assertFalse(_sy().isValidTokenIn(address(vault)));
    }

    function test_API13_emptyRewards() public {
        assertEq(_sy().getRewardTokens().length, 0);
        assertEq(_sy().accruedRewards(alice).length, 0);
        assertEq(_sy().rewardIndexesStored().length, 0);
        assertEq(_sy().rewardIndexesCurrent().length, 0);
        uint256[] memory claimed = _sy().claimRewards(alice);
        assertEq(claimed.length, 0);
        assertEq(asset.balanceOf(alice), 1_000_000e18);
    }

    function test_API09_syDepositRedeem() public {
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        uint256 expected = RebasingAwareOracle.sharesForDeposit(20e18, 0, 0, V);
        vm.prank(alice);
        uint256 shares = _sy().deposit(alice, address(asset), 20e18, expected);
        assertEq(shares, expected);
        vm.prank(alice);
        uint256 assets = _sy().redeem(alice, shares, address(asset), 0, false);
        assertGt(assets, 0);
    }

    function test_API12_internalBurnExactNoRefund() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(30e18, alice);
        uint256 prepaid = shares / 2;
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), prepaid);
        uint256 burnAmt = prepaid / 2;
        uint256 leftover = prepaid - burnAmt;
        vm.prank(bob);
        _sy().redeem(bob, burnAmt, address(asset), 0, true);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), leftover);
    }

    function test_API09_nativeValueReverts() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.NativeValueNotSupported.selector);
        _sy().deposit{value: 1}(alice, address(asset), 1e18, 0);
    }

    function test_API11_exchangeRateMatchesOracle() public {
        vm.prank(alice);
        vault.deposit(50e18, alice);
        uint256 A = vault.totalAssets();
        uint256 S = IERC20(address(vault)).totalSupply();
        uint256 V = _virtualShares(DEFAULT_OFFSET);
        assertEq(_sy().exchangeRate(), RebasingAwareOracle.wadRate(A, S, V));
    }

    function test_zeroPreview() public view {
        assertEq(_sy().previewDeposit(address(asset), 0), 0);
        assertEq(_sy().previewRedeem(address(asset), 0), 0);
        assertEq(_sy().previewDeposit(address(vault), 0), 0);
    }

    function test_API08_allSixteenSelectorsCallableOnProxy() public {
        IStandardizedYield sy = _sy();
        assertEq(sy.yieldToken(), address(asset));
        sy.assetInfo();
        sy.getTokensIn();
        sy.getTokensOut();
        assertTrue(sy.isValidTokenIn(address(asset)));
        assertTrue(sy.isValidTokenOut(address(asset)));
        assertEq(sy.previewDeposit(address(asset), 0), 0);
        assertEq(sy.previewRedeem(address(asset), 0), 0);
        assertEq(sy.getRewardTokens().length, 0);
        assertEq(sy.accruedRewards(alice).length, 0);
        assertEq(sy.rewardIndexesStored().length, 0);
        assertEq(sy.rewardIndexesCurrent().length, 0);
        assertEq(sy.claimRewards(alice).length, 0);
        uint256 rate = sy.exchangeRate();
        assertGt(rate, 0);
        vm.prank(alice);
        uint256 shares = sy.deposit(alice, address(asset), 1e18, 0);
        vm.prank(alice);
        sy.redeem(alice, shares / 2, address(asset), 0, false);
    }

    function test_API09_positiveInvalidTokenReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        _sy().deposit(alice, address(vault), 1e18, 0);
        vm.expectRevert();
        _sy().previewDeposit(address(vault), 1e18);
    }
}

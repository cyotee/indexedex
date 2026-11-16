// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {UnderConsumeERC4626} from "contracts/test/stubs/UnderConsumeERC4626.sol";
import {ShortRedeemERC4626} from "contracts/test/stubs/ShortRedeemERC4626.sol";
import {CappedPausableERC4626} from "contracts/test/stubs/CappedPausableERC4626.sol";

contract APEX_D46_CapacityFixtures is Test {
    MintableERC20Decimals internal asset;
    address internal payer;
    address internal receiver;

    function setUp() public {
        asset = new MintableERC20Decimals("Asset", "AST", 18);
        payer = makeAddr("payer");
        receiver = makeAddr("receiver");
    }

    function test_APEX_D46_underConsumeLeavesDust() public {
        UnderConsumeERC4626 vault = new UnderConsumeERC4626(asset);
        vault.setLeaveDust(5);
        asset.mint(payer, 100);
        vm.prank(payer);
        asset.approve(address(vault), 100);
        vm.prank(payer);
        uint256 shares = vault.deposit(100, receiver);
        assertEq(shares, 95);
        assertEq(asset.balanceOf(payer), 5);
        assertEq(asset.balanceOf(address(vault)), 95);
        assertEq(vault.totalAssetsStored(), 95);
        assertEq(vault.balanceOf(receiver), 95);
        assertEq(vault.maxDeposit(address(this)), type(uint256).max);
    }

    function test_APEX_D46_cappedMintCapExceeded() public {
        CappedPausableERC4626 vault = new CappedPausableERC4626(asset);
        asset.mint(payer, 1000);
        vm.startPrank(payer);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(100, payer);
        vm.stopPrank();
        asset.mint(address(this), 100);
        asset.approve(address(vault), 100);
        vault.simulateYield(100);
        assertEq(vault.totalAssets(), 200);
        assertEq(vault.totalSupply(), 100);
        vault.setDepositCap(250);
        assertEq(vault.maxDeposit(payer), 50);
        assertEq(vault.maxMint(payer), 25);
        uint256 preview = vault.previewMint(26);
        assertEq(preview, 52);
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(CappedPausableERC4626.DepositCapExceeded.selector, 52, 50));
        vault.mint(26, receiver);
        assertEq(vault.totalSupply(), 100);
        assertEq(asset.balanceOf(payer), 900);
        vm.prank(payer);
        uint256 assets = vault.mint(25, receiver);
        assertEq(assets, 50);
        assertEq(vault.maxDeposit(payer), 0);
    }

    function test_APEX_D46_cappedPauseAndUncapped() public {
        CappedPausableERC4626 vault = new CappedPausableERC4626(asset);
        asset.mint(payer, 10);
        vm.prank(payer);
        asset.approve(address(vault), 10);
        vault.setPaused(true);
        assertEq(vault.maxDeposit(payer), 0);
        assertEq(vault.maxMint(payer), 0);
        vm.prank(payer);
        vm.expectRevert(CappedPausableERC4626.DepositsPaused.selector);
        vault.deposit(1, receiver);
        vault.setPaused(false);
        assertEq(vault.maxDeposit(payer), type(uint256).max);
        vm.prank(payer);
        vault.deposit(1, receiver);
        assertEq(vault.balanceOf(receiver), 1);
        ShortRedeemERC4626 shortVault = new ShortRedeemERC4626(asset);
        assertEq(shortVault.maxRedeem(receiver), 0);
        SimpleYieldERC4626 baseVault = new SimpleYieldERC4626(asset);
        assertEq(baseVault.maxWithdraw(payer), 0);
    }
}

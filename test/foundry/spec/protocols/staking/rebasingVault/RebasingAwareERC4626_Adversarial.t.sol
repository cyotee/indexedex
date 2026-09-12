// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

import {TestBase_RebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/TestBase_RebasingAwareERC4626.sol";
import {IRebasingAwareERC4626} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {ReentrantERC20Harness} from "contracts/test/stubs/ReentrantERC20Harness.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

contract RebasingAwareERC4626_Adversarial is TestBase_RebasingAwareERC4626 {
    function test_ADV_firstDepositorDonationInflationOffset() public {
        asset.mint(address(vault), 1e18);
        vm.prank(alice);
        uint256 shares = vault.deposit(1e18, alice);
        assertGt(shares, 0);
        vm.prank(bob);
        uint256 bobShares = vault.deposit(1e18, bob);
        assertGt(bobShares, 0);
        vm.prank(alice);
        uint256 aliceOut = vault.redeem(shares, alice, alice);
        vm.prank(bob);
        uint256 bobOut = vault.redeem(bobShares, bob, bob);
        assertLe(aliceOut + bobOut, 2e18 + 1e18);
    }

    function test_ADV_cannotBurnOtherHolderViaInternalSy() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10e18, alice);
        vm.prank(bob);
        vm.expectRevert();
        IStandardizedYield(address(vault)).redeem(bob, shares, address(asset), 0, true);
        assertEq(IERC20(address(vault)).balanceOf(alice), shares);
    }

    function test_ADV_assetPretransferDoesNotMint() public {
        uint256 beforeShares = IERC20(address(vault)).totalSupply();
        vm.prank(attacker);
        asset.transfer(address(vault), 25e18);
        vm.prank(attacker);
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(asset)), 25e18, IERC20(address(vault)), 0, attacker, true, block.timestamp
        );
        assertEq(IERC20(address(vault)).totalSupply(), beforeShares);
        assertEq(IERC20(address(vault)).balanceOf(attacker), 0);
    }

    function test_ADV_publicSharesArePublic() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(20e18, alice);
        vm.prank(alice);
        IERC20(address(vault)).transfer(address(vault), shares);
        vm.prank(attacker);
        uint256 out = IStandardizedYield(address(vault)).redeem(attacker, shares, address(asset), 0, true);
        assertGt(out, 0);
        assertEq(IERC20(address(vault)).balanceOf(address(vault)), 0);
    }

    function test_ADV_crossVaultIsolation() public {
        IERC4626 vault2 = pkg.deployVault(IERC20Metadata(address(asset)), 10, bytes32(uint256(99)));
        vm.prank(alice);
        vault.deposit(10e18, alice);
        vm.prank(bob);
        asset.approve(address(vault2), type(uint256).max);
        vm.prank(bob);
        vault2.deposit(10e18, bob);
        assertEq(IERC20(address(vault)).balanceOf(bob), 0);
        assertEq(IERC20(address(vault2)).balanceOf(alice), 0);
    }

    function test_ADV_disableDoesNotBlockExit() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(6e18, alice);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setPackageDisabled(address(pkg), true);
        vm.prank(alice);
        uint256 out = vault.redeem(shares, alice, alice);
        assertGt(out, 0);
    }

    function test_ADV02_insufficientSharePretransferReverts() public {
        vm.prank(alice);
        vault.deposit(10e18, alice);
        vm.prank(alice);
        vm.expectRevert();
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)), 1e18, IERC20(address(asset)), 0, alice, true, block.timestamp
        );
    }

    function test_ADV03_reentrancyDuringDepositReverts() public {
        ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(123)));
        tok.mint(alice, 100e18);
        tok.setReenter(
            address(wrapped),
            abi.encodeWithSelector(IERC4626.deposit.selector, uint256(1e18), alice)
        );
        vm.startPrank(alice);
        tok.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(10e18, alice);
        vm.stopPrank();
    }

    function test_ADV07_invalidReceiverReverts() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(5e18, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRebasingAwareERC4626.InvalidReceiver.selector, address(0)));
        vault.redeem(shares / 2, address(0), alice);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IRebasingAwareERC4626.InvalidReceiver.selector, address(vault))
        );
        vault.redeem(shares / 2, address(vault), alice);
    }

    function test_ADV08_taxedOutboundFailsClosed() public {
        TaxedERC20Harness taxed = new TaxedERC20Harness("Tax", "TAX", 18, 100);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(taxed)), 10, bytes32(uint256(44)));
        taxed.mint(alice, 100e18);
        vm.startPrank(alice);
        taxed.approve(address(wrapped), type(uint256).max);
        vm.expectRevert();
        wrapped.deposit(10e18, alice);
        vm.stopPrank();
    }

    function test_ADV09_unauthorizedDiamondCutReverts() public {
        (bool ok,) = address(vault).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)",
                new bytes(0),
                address(0),
                ""
            )
        );
        assertFalse(ok);
    }

    function test_ADV16_zeroPayoutBurnReverts() public {
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        vault.withdraw(0, alice, alice);
        vm.prank(alice);
        vm.expectRevert(IRebasingAwareERC4626.ZeroOperationAmount.selector);
        IStandardizedYield(address(vault)).redeem(alice, 0, address(asset), 0, false);
    }
}

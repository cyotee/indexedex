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
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {TaxedERC20Harness} from "contracts/test/stubs/TaxedERC20Harness.sol";
import {ReentrantERC20Harness} from "contracts/test/stubs/ReentrantERC20Harness.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";

contract RebasingAwareERC4626_Adversarial is TestBase_RebasingAwareERC4626 {
    bool internal nestedAttempted;
    bytes internal nestedReason;

    /// @dev Called from the token pull. A wrong nested error fails this assertion inside the
    ///      reverted frame; the vault then reports the pull as TransferFromFailed.
    function observeNestedDeposit(address wrapped, address receiver) external {
        (bool ok, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)));
        assertFalse(ok, "nested deposit must be rejected");
        assertEq(reason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked");
        revert IReentrancyLock.IsLocked();
    }

    function recordNestedDeposit(address wrapped, address receiver) external {
        (, bytes memory reason) = wrapped.call(abi.encodeCall(IERC4626.deposit, (uint256(1e18), receiver)));
        nestedAttempted = true;
        nestedReason = reason;
    }

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
        uint256 aliceShares = IERC20(address(vault)).balanceOf(alice);
        uint256 reserveBefore = IBasicVault(address(vault)).reserveOfToken(address(asset));
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares, 0));
        IStandardizedYield(address(vault)).redeem(address(caller), shares, address(asset), 0, true);
        assertEq(IERC20(address(vault)).balanceOf(alice), aliceShares, "other holder shares unchanged");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(asset)), reserveBefore, "rejected claim books nothing");
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
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(attacker, shares, address(asset), 0, true);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        uint256 out = IStandardizedYield(address(vault)).redeem(address(caller), shares, address(asset), 0, true);
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
        // The EOA-rejection path is covered by test_ADV_publicSharesArePublic. This test validates the
        // named condition: a permitted (contract) pretransfer caller that claims more shares than it
        // actually pretransferred. With nothing pretransferred, the vault's self-balance credit is 0, so
        // the share-input redeem reverts TransferDeltaInsufficient(claimed, delivered), NOT the EOA gate.
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1e18), uint256(0)));
        IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)), 1e18, IERC20(address(asset)), 0, address(caller), true, block.timestamp
        );
    }

    function test_ADV03_reentrancyDuringDepositReverts() public {
        ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(123)));
        tok.mint(alice, 100e18);
        tok.setReenter(address(this), abi.encodeCall(this.observeNestedDeposit, (address(wrapped), alice)));
        tok.setBubbleRevert(true);
        uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
        uint256 aliceShares = IERC20(address(wrapped)).balanceOf(alice);
        uint256 vaultAssets = tok.balanceOf(address(wrapped));
        uint256 reserveBefore = IBasicVault(address(wrapped)).reserveOfToken(address(tok));
        vm.startPrank(alice);
        tok.approve(address(wrapped), type(uint256).max);
        vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
        wrapped.deposit(10e18, alice);
        vm.stopPrank();
        assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore, "nested guard mints nothing");
        assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceShares, "nested guard credits no shares");
        assertEq(tok.balanceOf(address(wrapped)), vaultAssets, "nested guard takes no assets");
        assertEq(IBasicVault(address(wrapped)).reserveOfToken(address(tok)), reserveBefore, "nested guard books nothing");
    }

    function test_ADV03_nestedDepositIsLocked_outerDepositCompletes() public {
        ReentrantERC20Harness tok = new ReentrantERC20Harness("R", "R", 18);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(tok)), 10, bytes32(uint256(123)));
        tok.mint(alice, 100e18);
        tok.setReenter(address(this), abi.encodeCall(this.recordNestedDeposit, (address(wrapped), alice)));
        tok.setBubbleRevert(true);
        nestedAttempted = false;
        delete nestedReason;
        uint256 depositAssets = 10e18;
        uint256 expectedShares = wrapped.previewDeposit(depositAssets);
        uint256 supplyBefore = IERC20(address(wrapped)).totalSupply();
        uint256 aliceSharesBefore = IERC20(address(wrapped)).balanceOf(alice);
        uint256 aliceAssetsBefore = tok.balanceOf(alice);
        uint256 vaultAssetsBefore = tok.balanceOf(address(wrapped));
        assertGt(expectedShares, 0, "previewed shares");
        vm.startPrank(alice);
        tok.approve(address(wrapped), type(uint256).max);
        uint256 minted = wrapped.deposit(depositAssets, alice);
        vm.stopPrank();
        assertGt(minted, 0, "outer deposit finished");
        assertEq(minted, expectedShares, "outer deposit matches preview");
        assertEq(IERC20(address(wrapped)).balanceOf(alice), aliceSharesBefore + minted, "recipient shares are the outer mint");
        assertEq(IERC20(address(wrapped)).totalSupply(), supplyBefore + minted, "supply grew by the outer mint");
        assertEq(tok.balanceOf(alice), aliceAssetsBefore - depositAssets, "caller paid the outer assets");
        assertEq(tok.balanceOf(address(wrapped)), vaultAssetsBefore + depositAssets, "vault received the outer assets");
        assertTrue(nestedAttempted, "nested deposit was attempted");
        assertEq(nestedReason, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "nested guard is IsLocked");
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
        TaxedERC20Harness taxed = new TaxedERC20Harness("Tax", "TAX", 18, 0);
        IERC4626 wrapped = pkg.deployVault(IERC20Metadata(address(taxed)), 10, bytes32(uint256(44)));
        taxed.mint(alice, 100e18);
        vm.startPrank(alice);
        taxed.approve(address(wrapped), type(uint256).max);
        wrapped.deposit(10e18, alice);
        vm.stopPrank();
        taxed.setTaxBps(100);
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        uint256 snap = vm.snapshotState();
        for (uint256 route; route < 5; ++route) {
            vm.prank(alice);
            wrapped.transfer(address(wrapped), 2e28);
            vm.expectRevert(abi.encodeWithSelector(
                IRebasingAwareERC4626.AssetSupplyChangedDuringTransfer.selector, 100e18, 100e18 - 1e16));
            if (route == 0) {
                vm.prank(alice);
                wrapped.redeem(1e28, bob, alice);
            } else if (route == 1) {
                vm.prank(alice);
                wrapped.withdraw(1e18, bob, alice);
            } else if (route == 2) {
                vm.prank(address(caller));
                IStandardExchangeIn(address(wrapped)).exchangeIn(
                    IERC20(address(wrapped)), 1e28, IERC20(address(taxed)), 0, bob, true, block.timestamp);
            } else if (route == 3) {
                vm.prank(address(caller));
                IStandardExchangeOut(address(wrapped)).exchangeOut(
                    IERC20(address(wrapped)), 2e28, IERC20(address(taxed)), 1e18, bob, true, block.timestamp);
            } else {
                vm.prank(address(caller));
                IStandardizedYield(address(wrapped)).redeem(bob, 1e28, address(taxed), 0, true);
            }
            assertEq(wrapped.totalSupply(), 1e29);
            assertEq(wrapped.balanceOf(alice), 8e28);
            assertEq(wrapped.balanceOf(address(wrapped)), 2e28, "failed payout consumed public shares/refund");
            assertEq(taxed.balanceOf(address(wrapped)), 10e18);
            assertEq(taxed.balanceOf(bob), 0);
            assertTrue(vm.revertToState(snap));
        }
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

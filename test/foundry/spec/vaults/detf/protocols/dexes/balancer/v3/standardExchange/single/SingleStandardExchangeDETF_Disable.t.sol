// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

/**
 * @notice SingleStandardExchange DETF respects registry kill-switch by address and package.
 * @dev Uses an open-mint DETF (mintThreshold=1) so post-bootstrap exchangeIn is a real success path
 *      (same pattern as SingleStandardExchangeDETF_Mint_Test).
 */
contract SingleStandardExchangeDETF_Disable_Test is TestBase_SingleStandardExchangeDETF {
    IVaultRegistryDisableQuery internal disableQuery;
    IVaultRegistryDisableManager internal disableManager;

    address internal openDetf;
    ISingleStandardExchangeDETFInfo internal openInfo;
    ISingleStandardExchangeDETFBonding internal openBonding;
    IStandardExchangeIn internal openExchangeIn;

    function setUp() public virtual override {
        super.setUp();
        disableQuery = IVaultRegistryDisableQuery(address(indexedexManager));
        disableManager = IVaultRegistryDisableManager(address(indexedexManager));

        openDetf = _deployOpenMintDetf();
        openInfo = ISingleStandardExchangeDETFInfo(openDetf);
        openBonding = ISingleStandardExchangeDETFBonding(openDetf);
        openExchangeIn = IStandardExchangeIn(openDetf);

        // Bootstrap reserve so subsequent mints are a live mutation path.
        _bootstrapOpen(alice, 1_000e18);
        assertTrue(openInfo.isReserveLive(), "reserve live after first bond");
        assertTrue(openInfo.isMintingAllowed(), "minting allowed with open threshold");
    }

    function _deployOpenMintDetf() internal returns (address detf_) {
        detf_ = _deployOpenModeDetf("Disable Open Mint DETF", "dOmDETF");
    }

    function _bootstrapOpen(address bonder, uint256 lpAmount) internal {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        require(seShares_ > 0, "bootstrap needs SE shares");
        vm.startPrank(bonder);
        seShare.approve(openDetf, seShares_);
        openBonding.bond(seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function _mintAfterFund(address user, uint256 lpAmount) internal returns (uint256 out_) {
        uint256 seShares_ = _fundSeShares(user, lpAmount);
        require(seShares_ > 0, "need funded SE shares");
        vm.startPrank(user);
        seShare.approve(openDetf, seShares_);
        out_ = openExchangeIn.exchangeIn(
            seShare, seShares_, IERC20(openDetf), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Address disable / re-enable                    */
    /* ---------------------------------------------------------------------- */

    function test_disableByVaultAddress_blocksExchangeIn() public {
        vm.prank(owner);
        disableManager.setVaultAddressDisabled(openDetf, true);
        assertTrue(disableQuery.isDisabled(openDetf));

        uint256 seShares_ = _fundSeShares(bob, 200e18);
        require(seShares_ > 0, "fund bob");

        // Previews remain callable while disabled.
        openExchangeIn.previewExchangeIn(seShare, seShares_, IERC20(openDetf));

        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, openDetf));
        openExchangeIn.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_reenableVaultAddress_allowsExchangeIn() public {
        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(openDetf, true);
        assertTrue(disableQuery.isDisabled(openDetf));
        disableManager.setVaultAddressDisabled(openDetf, false);
        vm.stopPrank();
        assertFalse(disableQuery.isDisabled(openDetf));

        uint256 out_ = _mintAfterFund(bob, 200e18);
        assertTrue(out_ > 0, "minted DETF after vault address re-enable");
        assertTrue(IERC20(openDetf).balanceOf(bob) >= out_, "bob received DETF");
    }

    /* ---------------------------------------------------------------------- */
    /*                         Package disable / re-enable                    */
    /* ---------------------------------------------------------------------- */

    function test_disableByPackage_blocksExchangeIn() public {
        address pkg = disableQuery.packageOfVault(openDetf);
        assertEq(pkg, address(singleStandardExchangeDetfPkg), "open detf package");

        vm.prank(owner);
        disableManager.setPackageDisabled(pkg, true);
        assertTrue(disableQuery.isDisabled(openDetf));
        assertFalse(disableQuery.isVaultAddressDisabled(openDetf), "package path only");

        uint256 seShares_ = _fundSeShares(bob, 200e18);
        require(seShares_ > 0, "fund bob");

        vm.startPrank(bob);
        seShare.approve(openDetf, seShares_);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, openDetf));
        openExchangeIn.exchangeIn(seShare, seShares_, IERC20(openDetf), 0, bob, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    function test_reenablePackage_allowsExchangeIn() public {
        address pkg = disableQuery.packageOfVault(openDetf);

        vm.startPrank(owner);
        disableManager.setPackageDisabled(pkg, true);
        assertTrue(disableQuery.isDisabled(openDetf));
        disableManager.setPackageDisabled(pkg, false);
        vm.stopPrank();
        assertFalse(disableQuery.isDisabled(openDetf));

        uint256 out_ = _mintAfterFund(bob, 200e18);
        assertTrue(out_ > 0, "minted DETF after package re-enable");
        assertTrue(IERC20(openDetf).balanceOf(bob) >= out_, "bob received DETF");
    }

    function test_disableDetfPackage_doesNotDisableLegSeVault() public {
        address detfPkg = disableQuery.packageOfVault(openDetf);
        address sePkg = disableQuery.packageOfVault(address(seVault));

        vm.prank(owner);
        disableManager.setPackageDisabled(detfPkg, true);

        assertTrue(disableQuery.isDisabled(openDetf));
        if (sePkg != address(0)) {
            assertFalse(disableQuery.isDisabled(address(seVault)), "leg SE package still active");
        }
    }
}

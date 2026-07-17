// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice DualLiquidityLinked respects registry kill-switch by vault address and package.
contract DualLiquidityLinkedCrossVersionUniswapVault_Disable is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal caller = makeAddr("disableCaller");
    IVaultRegistryDisableQuery internal disableQuery;
    IVaultRegistryDisableManager internal disableManager;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        disableQuery = IVaultRegistryDisableQuery(address(indexedexManager));
        disableManager = IVaultRegistryDisableManager(address(indexedexManager));
    }

    function test_disableByVaultAddress_blocksExchangeIn() public {
        assertFalse(disableQuery.isDisabled(linkedVault));

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(linkedVault, true);
        assertTrue(disableQuery.isDisabled(linkedVault));

        uint256 amount = 100e18;
        _fund(commonToken, caller, amount);
        // Previews remain available while disabled
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, amount, IERC20(linkedVault));
        assertTrue(preview > 0 || preview == 0); // call must not revert

        vm.startPrank(caller);
        commonToken.approve(linkedVault, amount);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, linkedVault));
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, IERC20(linkedVault), 0, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_reenableVaultAddress_allowsExchangeIn() public {
        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(linkedVault, true);
        disableManager.setVaultAddressDisabled(linkedVault, false);
        vm.stopPrank();

        uint256 minted = _depositCommon(caller, LEG_SEED);
        assertTrue(minted > 0);
    }

    function test_disableByPackage_blocksExchangeIn() public {
        address pkg = address(linkedVaultPkg);
        assertEq(disableQuery.packageOfVault(linkedVault), pkg);

        vm.prank(owner);
        disableManager.setPackageDisabled(pkg, true);
        assertTrue(disableQuery.isDisabled(linkedVault));
        assertFalse(disableQuery.isVaultAddressDisabled(linkedVault));

        uint256 amount = 50e18;
        _fund(commonToken, caller, amount);
        vm.startPrank(caller);
        commonToken.approve(linkedVault, amount);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, linkedVault));
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, IERC20(linkedVault), 0, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    function test_reenablePackage_allowsExchangeIn() public {
        address pkg = address(linkedVaultPkg);
        vm.startPrank(owner);
        disableManager.setPackageDisabled(pkg, true);
        disableManager.setPackageDisabled(pkg, false);
        vm.stopPrank();

        uint256 minted = _depositCommon(caller, LEG_SEED);
        assertTrue(minted > 0);
    }

    function test_disableByPackage_blocksExchangeOutPath() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        address pkg = address(linkedVaultPkg);

        vm.prank(owner);
        disableManager.setPackageDisabled(pkg, true);

        vm.startPrank(caller);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, linkedVault));
        IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), minted / 4, commonToken, 0, caller, false, block.timestamp
        );
        vm.stopPrank();
    }
}

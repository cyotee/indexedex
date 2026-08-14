// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

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

    /// @notice CROPS: inbound mint stays disable-gated after `setVaultAddressDisabled(true)`.
    function test_CROPS_disabled_still_blocks_inbound_mint() public {
        vm.prank(owner);
        disableManager.setVaultAddressDisabled(linkedVault, true);

        uint256 amount = 100e18;
        _fund(commonToken, caller, amount);
        vm.startPrank(caller);
        commonToken.approve(linkedVault, amount);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, linkedVault));
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, amount, IERC20(linkedVault), 0, caller, false, block.timestamp
        );
        vm.stopPrank();
    }

    /// @notice CROPS: share redeem (user exit) still works after address disable.
    ///         DualLiquidity has no bond NFT / `redeemClaim`; exit is share burn.
    function test_CROPS_disabled_still_allows_redeem() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        address pool = _reservePool();

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(linkedVault, true);
        assertTrue(disableQuery.isDisabled(linkedVault));

        uint256 half = minted / 2;
        uint256 preview =
            IStandardExchangeIn(linkedVault).previewExchangeIn(IERC20(linkedVault), half, IERC20(pool));
        vm.prank(caller);
        uint256 out = IStandardExchangeIn(linkedVault).exchangeIn(
            IERC20(linkedVault), half, IERC20(pool), 0, caller, false, block.timestamp
        );
        assertGt(out, 0, "CROPS: redeem after disable");
        assertEq(out, preview, "CROPS: preview == redeem after disable");
        assertEq(IERC20(pool).balanceOf(caller), out);
    }

    /// @notice CROPS: exact-out share redeem still works after address disable.
    function test_CROPS_disabled_still_allows_exchangeOut_redeem() public {
        uint256 minted = _depositCommon(caller, LEG_SEED);
        address pool = _reservePool();
        uint256 wantBpt = IStandardExchangeIn(linkedVault).previewExchangeIn(
            IERC20(linkedVault), minted / 4, IERC20(pool)
        );
        require(wantBpt > 0, "CROPS: need redeemable BPT");

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(linkedVault, true);

        vm.prank(caller);
        uint256 used = IStandardExchangeOut(linkedVault).exchangeOut(
            IERC20(linkedVault), minted, IERC20(pool), wantBpt, caller, false, block.timestamp
        );
        assertGt(used, 0, "CROPS: exchangeOut redeem after disable");
        assertLe(used, minted);
        assertEq(IERC20(pool).balanceOf(caller), wantBpt);
    }
}

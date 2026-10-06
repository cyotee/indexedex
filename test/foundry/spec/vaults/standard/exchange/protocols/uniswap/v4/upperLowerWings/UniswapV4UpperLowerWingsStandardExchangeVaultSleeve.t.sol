// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultAccounting as Accounting
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultSleeveTest[]
/// @notice The real production manager/fee oracle controls the Wings helper's sleeve value.
/// @dev Tests the internal helper in this contract's context; a Wings package has not yet been deployed.
contract UniswapV4UpperLowerWingsStandardExchangeVaultSleeveTest is IndexedexTest {
    /// @notice An unset effective oracle percentage is zero; Wings must not silently substitute twenty percent.
    function test_zeroOraclePercentageHasNoWingsDefault() public {
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0);
        assertEq(indexedexManager.liquidReservePercentageOfVault(address(this)), 0);
        assertEq(Accounting.liquidTarget(indexedexManager, 120e18), 0);
    }

    /// @notice Zero/rundown oracle allocation still preserves one native unit until the last share burns.
    function test_positiveValueFloorAndFinalRelease() public {
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0);
        assertEq(Accounting.requiredLiquid(indexedexManager, 100, 1), 1);
        assertEq(Accounting.requiredLiquid(indexedexManager, 100, 0), 0);
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        assertEq(Accounting.requiredLiquid(indexedexManager, 5, 100), 1);
        assertEq(Accounting.requiredLiquid(indexedexManager, 120, 100), 20);
    }

    /// @notice Global and instance changes use the oracle's own precedence, including clearing an override.
    function test_effectiveOraclePercentageAndUpdates() public {
        vm.startPrank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        vm.stopPrank();
        assertEq(Accounting.liquidTarget(indexedexManager, 120e18), 20e18);
        vm.prank(owner);
        indexedexManager.setLiquidReservePercentageOfVault(address(this), 0.5e18);
        assertEq(Accounting.liquidTarget(indexedexManager, 120e18), 40e18);
        vm.prank(owner);
        indexedexManager.setLiquidReservePercentageOfVault(address(this), 0);
        assertEq(Accounting.liquidTarget(indexedexManager, 120e18), 20e18);
    }

    /// @notice Even a positive percentage can round the local sleeve to zero for small native-unit balances.
    function test_positivePercentageCanRoundToZero() public {
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        assertEq(Accounting.liquidTarget(indexedexManager, 5), 0);
        assertEq(Accounting.liquidTarget(indexedexManager, 6), 1);
    }

    /// @notice Full-width balances use full-precision arithmetic rather than overflow-prone multiplication.
    function test_fullWidthTargetInventory() public {
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(1e18);
        assertEq(Accounting.liquidTarget(indexedexManager, type(uint256).max), type(uint256).max / 2);
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(0.2e18);
        assertEq(Accounting.liquidTarget(indexedexManager, type(uint256).max), type(uint256).max / 6);
    }

    /// @notice The local target is exactly the floor solution to F=p*D with F+D=total target principal.
    function testFuzz_sleeveRatio(uint128 inventory_, uint64 percentageSeed_) public {
        uint256 percentage = uint256(percentageSeed_) % (1e18 + 1);
        vm.prank(owner);
        indexedexManager.setDefaultLiquidReservePercentage(percentage);
        uint256 local = Accounting.liquidTarget(indexedexManager, inventory_);
        uint256 numerator = uint256(inventory_) * percentage;
        assertLe(local * (1e18 + percentage), numerator);
        assertLt(numerator, (local + 1) * (1e18 + percentage));
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultSleeveTest[]

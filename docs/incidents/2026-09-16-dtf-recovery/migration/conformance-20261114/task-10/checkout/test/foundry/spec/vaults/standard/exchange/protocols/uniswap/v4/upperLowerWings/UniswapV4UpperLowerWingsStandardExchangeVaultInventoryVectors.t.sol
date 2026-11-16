// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {
    UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultInventoryVectorsTest[]
/// @notice Full-width expected principal from independent Python arbitrary-precision rationals.
contract UniswapV4UpperLowerWingsStandardExchangeVaultInventoryVectorsTest is Test {
    /// @notice Protocol extremes and maximum uint128 liquidity match exact floor and ceil references.
    function test_arbitraryPrecisionPrincipalVectors() public view {
        string memory source = vm.readFile(
            "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/reference/UniswapV4UpperLowerWingsStandardExchangeVaultInventoryVectors.json"
        );
        uint256[] memory values = vm.parseJsonUintArray(source, ".values");
        assertEq(values.length, 144);
        for (uint256 i; i < values.length; i += 6) {
            Types.Principal memory floor =
                Inventory.principal(uint160(values[i]), -887272, 887272, uint128(values[i + 1]), false);
            Types.Principal memory ceil =
                Inventory.principal(uint160(values[i]), -887272, 887272, uint128(values[i + 1]), true);
            assertEq(floor.amount0, values[i + 2]);
            assertEq(floor.amount1, values[i + 3]);
            assertEq(ceil.amount0, values[i + 4]);
            assertEq(ceil.amount1, values[i + 5]);
        }
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultInventoryVectorsTest[]

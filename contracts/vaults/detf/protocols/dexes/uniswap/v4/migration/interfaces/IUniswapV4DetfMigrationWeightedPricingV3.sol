// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from "./IUniswapV4DetfMigrationWeightedPricing.sol";

/// @notice Permanent normalized pricing read, separate from the legacy migration interface id.
interface IUniswapV4DetfMigrationWeightedPricingV3 {
    /// @notice Return current or normalized legacy operands, retaining the stored version and id.
    function migrationWeightedPricingV3() external view returns (Pricing.BookV3 memory);
}

/// @notice Removable owner administration for version-three manual books.
interface IUniswapV4DetfMigrationWeightedPricingAllocationV3 {
    function setMigrationWeightedPricingV3(Pricing.InputsV3 calldata next_) external returns (bytes32 bookId_);
}

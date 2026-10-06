// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";

// tag::UniswapV4UpperLowerWingsStandardExchangeVaultAccounting[]
/// @notice Oracle-sourced target sleeve arithmetic, independent of position placement.
/// @dev Native target units denominate initial shares; no permanent sink or separate residual claims.
library UniswapV4UpperLowerWingsStandardExchangeVaultAccounting {
    uint256 internal constant ONE_WAD = 1e18;
    error InvalidLiquidReservePercentage(uint256 percentage);

    error ZeroIssue();
    error InvalidAccountingState();

    /// @notice Issue at the post-harvest pre-entry rate; subsequent placement costs belong to vault reserves.
    function issue(uint256 supply_, uint256 value_, uint256 credit_) internal pure returns (uint256 shares_) {
        if (credit_ == 0) revert ZeroIssue();
        if (supply_ != 0 && value_ == 0) revert InvalidAccountingState();
        shares_ = supply_ == 0 ? credit_ : FullMath.mulDiv(supply_, credit_, value_);
        if (shares_ == 0) revert ZeroIssue();
    }
    function entitlement(uint256 supply_, uint256 value_, uint256 shares_) internal pure returns (uint256) {
        if (supply_ == 0 || shares_ > supply_) revert InvalidAccountingState();
        return FullMath.mulDiv(shares_, value_, supply_);
    }
    function inputForShares(uint256 supply_, uint256 value_, uint256 shares_) internal pure returns (uint256) {
        if (shares_ == 0 || (supply_ != 0 && value_ == 0)) revert InvalidAccountingState();
        return supply_ == 0 ? shares_ : FullMath.mulDivRoundingUp(shares_, value_, supply_);
    }
    function sharesForAssets(uint256 supply_, uint256 value_, uint256 assets_) internal pure returns (uint256) {
        if (supply_ == 0 || value_ == 0 || assets_ > value_) revert InvalidAccountingState();
        return FullMath.mulDivRoundingUp(supply_, assets_, value_);
    }

    /// @notice Target local inventory for the oracle's effective local/deployed target-token ratio.
    /// @param oracle_ Configured Vault Fee Oracle; it resolves vault, type and global defaults.
    /// @param targetInventory_ Owned local plus deployed target principal, excluding pending caller credit/liabilities.
    /// @dev Runs in the vault's context. Uncollected fees are not local cover. Opposing inventory is not the denominator.
    function liquidTarget(IVaultFeeOracleQuery oracle_, uint256 targetInventory_) internal view returns (uint256) {
        uint256 percentage = oracle_.liquidReservePercentageOfVault(address(this));
        if (percentage > ONE_WAD) revert InvalidLiquidReservePercentage(percentage);
        return FullMath.mulDiv(targetInventory_, percentage, ONE_WAD + percentage);
    }
    /// @notice Oracle sleeve with the positive-value floor while any shares remain.
    function requiredLiquid(IVaultFeeOracleQuery oracle_, uint256 targetInventory_, uint256 remainingShares_)
        internal view returns (uint256 liquid_)
    {
        liquid_ = liquidTarget(oracle_, targetInventory_);
        if (remainingShares_ != 0 && liquid_ == 0) liquid_ = 1;
    }
}
// end::UniswapV4UpperLowerWingsStandardExchangeVaultAccounting[]

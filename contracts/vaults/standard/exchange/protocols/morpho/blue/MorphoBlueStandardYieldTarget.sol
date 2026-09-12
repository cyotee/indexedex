// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";

/// @notice Native Morpho market shares use the existing accrued loan-asset entitlement.
abstract contract MorphoBlueStandardYieldTarget is NativeStandardYieldTarget {
    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](1); tokens_[0] = IERC4626(address(this)).asset();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    /// @dev Morpho supply shares are ledger entries, with no separate ERC-20 yield token.
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        address asset_ = IERC4626(address(this)).asset();
        return (IStandardizedYield.AssetType.TOKEN, asset_, IERC20Metadata(asset_).decimals());
    }
    function exchangeRate() external view override returns (uint256) {
        return IERC4626(address(this)).convertToAssets(1e18);
    }
}

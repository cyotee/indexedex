// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {ERC4626StandardExchangeCommon} from "./ERC4626StandardExchangeCommon.sol";

/// @notice SY for the existing SE share token backed by an external ERC-4626 vault.
abstract contract ERC4626StandardYieldTarget is NativeStandardYieldTarget, ERC4626StandardExchangeCommon {
    function getTokensIn() public view override returns (address[] memory tokens_) {
        IERC4626 vault_ = protocolVault();
        tokens_ = new address[](2);
        tokens_[0] = address(vault_);
        tokens_[1] = vault_.asset();
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return address(protocolVault()); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        address asset_ = protocolVault().asset();
        return (IStandardizedYield.AssetType.TOKEN, asset_, IERC20Metadata(asset_).decimals());
    }

    /// @dev Proportional accounting assets per raw SE share, scaled by 1e18. convertToAssets
    ///      excludes transaction slippage/exit fees; previewRedeem continues to quote those.
    function exchangeRate() external view override returns (uint256) {
        IERC4626 vault_ = protocolVault();
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return vault_.convertToAssets(1e18);
        uint256 held_ = IERC20(address(vault_)).balanceOf(address(this));
        return Math.mulDiv(vault_.convertToAssets(held_), 1e18, supply_);
    }
}

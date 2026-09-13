// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ConstProdReserveVaultRepo} from "contracts/vaults/ConstProdReserveVaultRepo.sol";
import {NativeStandardYieldTarget} from "./NativeStandardYieldTarget.sol";

/// @notice Native SY metadata for existing Uni V2, Camelot V2 and Aerodrome LP-backed SE shares.
/// @dev Accounting remains in actual LP units. Existing compound operations realize any
///      separately accrued pool fees into that reserve; this adapter creates no second reward.
abstract contract ConstantProductStandardYieldTarget is NativeStandardYieldTarget {
    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](3);
        tokens_[0] = address(ERC4626Repo._reserveAsset());
        tokens_[1] = ConstProdReserveVaultRepo._token0();
        tokens_[2] = ConstProdReserveVaultRepo._token1();
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return address(ERC4626Repo._reserveAsset()); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        address asset_ = address(ERC4626Repo._reserveAsset());
        return (IStandardizedYield.AssetType.TOKEN, asset_, IERC20Metadata(asset_).decimals());
    }

    function exchangeRate() external view override returns (uint256) {
        return IERC4626(address(this)).convertToAssets(1e18);
    }
}

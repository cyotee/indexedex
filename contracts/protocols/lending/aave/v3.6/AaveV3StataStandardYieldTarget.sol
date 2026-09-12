// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";

/// @notice SY at the existing Stata SE address; protocol rewards retain their existing fee-recipient forwarding.
abstract contract AaveV3StataStandardYieldTarget is NativeStandardYieldTarget {
    function _yieldVault() internal view returns (IStataTokenV2) { return IStataTokenV2(address(ERC4626Repo._reserveAsset())); }
    function getTokensIn() public view override returns (address[] memory tokens_) {
        IStataTokenV2 stata_ = _yieldVault();
        tokens_ = new address[](3); tokens_[0] = address(stata_); tokens_[1] = stata_.asset(); tokens_[2] = stata_.aToken();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return address(_yieldVault()); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        address asset_ = _yieldVault().asset();
        return (IStandardizedYield.AssetType.TOKEN, asset_, IERC20Metadata(asset_).decimals());
    }
    function exchangeRate() external view override returns (uint256) {
        IStataTokenV2 stata_ = _yieldVault();
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return stata_.convertToAssets(1e18);
        return Math.mulDiv(stata_.convertToAssets(IERC20(address(stata_)).balanceOf(address(this))), 1e18, supply_);
    }
}

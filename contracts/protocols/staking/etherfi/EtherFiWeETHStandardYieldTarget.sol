// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {EtherFiWeETHStandardExchangeCommon} from "./EtherFiWeETHStandardExchangeCommon.sol";

/// @notice Native SY adapter preserving this SE's ETH reserve entitlement and liquid sleeve.
abstract contract EtherFiWeETHStandardYieldTarget is NativeStandardYieldTarget, EtherFiWeETHStandardExchangeCommon {
    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](3);
        tokens_[0] = weth();
        tokens_[1] = eETH();
        tokens_[2] = weETH();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return weETH(); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.TOKEN, weth(), IERC20Metadata(weth()).decimals());
    }

    /// @dev Reuses proportional reserve conversion, including the existing virtual share units.
    function exchangeRate() external view override returns (uint256) {
        return _previewRedeemSharesToEth(1e18);
    }
}

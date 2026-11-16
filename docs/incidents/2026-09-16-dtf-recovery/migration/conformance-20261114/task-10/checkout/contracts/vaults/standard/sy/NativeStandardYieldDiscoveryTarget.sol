// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";

abstract contract NativeStandardYieldValidation {
    function isValidTokenIn(address token_) public view virtual returns (bool);
    function isValidTokenOut(address token_) public view virtual returns (bool);
}

/// @notice Read-only discovery shared by native SY query adapters.
abstract contract NativeStandardYieldDiscoveryTarget is NativeStandardYieldValidation {
    function getTokensIn() public view virtual returns (address[] memory);
    function getTokensOut() public view virtual returns (address[] memory);
    function yieldToken() external view virtual returns (address);
    function assetInfo() external view virtual returns (IStandardizedYield.AssetType, address, uint8);
    function exchangeRate() external view virtual returns (uint256);

    function isValidTokenIn(address token_) public view virtual override returns (bool) { return _contains(getTokensIn(), token_); }
    function isValidTokenOut(address token_) public view virtual override returns (bool) { return _contains(getTokensOut(), token_); }

    function _contains(address[] memory tokens_, address token_) internal pure returns (bool) {
        for (uint256 i_; i_ < tokens_.length; ++i_) if (tokens_[i_] == token_) return true;
        return false;
    }

    function getRewardTokens() external view virtual returns (address[] memory) { return new address[](0); }
    function accruedRewards(address) external view virtual returns (uint256[] memory) { return new uint256[](0); }
    function rewardIndexesStored() external view virtual returns (uint256[] memory) { return new uint256[](0); }
}

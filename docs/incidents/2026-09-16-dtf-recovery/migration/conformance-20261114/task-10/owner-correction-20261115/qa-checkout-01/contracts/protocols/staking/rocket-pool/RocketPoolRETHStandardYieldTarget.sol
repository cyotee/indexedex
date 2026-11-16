// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {RocketPoolRETHStandardExchangeInExecutionBase} from "./RocketPoolRETHStandardExchangeInTarget.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {RocketPoolRETHStandardExchangeCommon} from "./RocketPoolRETHStandardExchangeCommon.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/// @notice Native SY adapter preserving this SE's ETH reserve entitlement and liquid sleeve.
abstract contract RocketPoolRETHStandardYieldTarget is NativeStandardYieldTarget, RocketPoolRETHStandardExchangeInExecutionBase {
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256 amount_)
    {
        amount_ = _quoteExactIn(address(this), shares_, tokenOut_);
        if (amount_ < minimum_) revert Slippage();
        ERC20Repo._burn(address(this), shares_);
        _payAsset(tokenOut_, amount_, receiver_);
        _syncAllExpectedHoldReserves();
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](2);
        tokens_[0] = weth();
        tokens_[1] = rETH();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return rETH(); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.TOKEN, weth(), IERC20Metadata(weth()).decimals());
    }

    /// @dev Reuses proportional reserve conversion, including the existing virtual share units.
    function exchangeRate() external view override returns (uint256) {
        return _previewRedeemSharesToEth(1e18);
    }
}

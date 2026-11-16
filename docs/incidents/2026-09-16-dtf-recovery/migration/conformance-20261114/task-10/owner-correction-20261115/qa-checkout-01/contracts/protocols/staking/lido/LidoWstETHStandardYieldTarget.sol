// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {LidoWstETHStandardExchangeInExecutionBase} from "./LidoWstETHStandardExchangeInTarget.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {LidoWstETHStandardExchangeCommon} from "./LidoWstETHStandardExchangeCommon.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

/// @notice Native SY adapter preserving this SE's ETH reserve entitlement and liquid sleeve.
abstract contract LidoWstETHStandardYieldTarget is NativeStandardYieldTarget, LidoWstETHStandardExchangeInExecutionBase {
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256 amount_)
    {
        uint256 wrappedOut_;
        if (tokenOut_ == stETH()) wrappedOut_ = _wstEthFromStEth(_previewRedeemSharesToEth(shares_));
        else amount_ = _quoteExactIn(address(this), shares_, tokenOut_);
        ERC20Repo._burn(address(this), shares_);
        amount_ = tokenOut_ == stETH() ? _unwrapAndPaySt(wrappedOut_, receiver_) : _payAsset(tokenOut_, amount_, receiver_);
        if (amount_ < minimum_) revert Slippage();
        _syncAllExpectedHoldReserves();
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](3);
        tokens_[0] = weth();
        tokens_[1] = stETH();
        tokens_[2] = wstETH();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return wstETH(); }

    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.TOKEN, weth(), IERC20Metadata(weth()).decimals());
    }

    /// @dev Reuses proportional reserve conversion, including the existing virtual share units.
    function exchangeRate() external view override returns (uint256) {
        return _previewRedeemSharesToEth(1e18);
    }
}

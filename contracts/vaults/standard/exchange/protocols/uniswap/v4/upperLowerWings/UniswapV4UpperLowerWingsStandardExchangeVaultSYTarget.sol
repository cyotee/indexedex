// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase} from "./UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

/// @notice Native SY uses the existing vault share and its installed standard money routes.
contract UniswapV4UpperLowerWingsStandardExchangeVaultSYTarget is NativeStandardYieldTarget, UniswapV4UpperLowerWingsStandardExchangeVaultInExecutionBase {
    function _redeemVaultHeld(address receiver_, uint256 shares_, address, uint256 minimum_)
        internal override returns (uint256 amount_)
    {
        Money.begin(block.timestamp);
        amount_ = Money.redeem(shares_, minimum_, receiver_, true);
        Money.end();
    }

    function getTokensIn() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](1); tokens_[0] = address(Money.target());
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external view override returns (address) { return address(this); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.TOKEN, address(Money.target()), ERC20Repo._decimals());
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 1e18;
        return FullMath.mulDiv(_liquidationValue().value, 1e18, supply);
    }
}

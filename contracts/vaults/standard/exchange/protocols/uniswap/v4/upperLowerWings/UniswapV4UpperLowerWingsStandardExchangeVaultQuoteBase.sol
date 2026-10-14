// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as IWings} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {NativeStandardYieldQuoteBase} from "contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

abstract contract UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase is NativeStandardYieldQuoteBase {
    function _liquidationValue() internal view returns (Quote.Result memory) {
        Repo.Storage storage state = Repo._layout();
        if (!state.initialized) revert IWings.NotInitialized();
        if (state.busy) revert IWings.ReentrantOperation();
        return Quote.quote(Common.quoteRequest());
    }

    function _previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal view override returns (uint256)
    {
        return Money.preview(_route(tokenIn_, tokenOut_), amountIn_);
    }

    function _route(IERC20 tokenIn_, IERC20 tokenOut_) internal view returns (bool deposit_) {
        address target = address(Money.target());
        if (address(tokenIn_) == target && address(tokenOut_) == address(this)) return true;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == target) return false;
        revert IStandardExchangeErrors.InvalidRoute(address(tokenIn_), address(tokenOut_));
    }
}

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IUniswapV4FullSpreadPonsFamilyHookInExecutionBinding as ExitBinding} from "./interfaces/IUniswapV4FullSpreadPonsFamilyHookComponentBindings.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "./UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV4FullSpreadPonsFamilyHookOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutBase.sol";

contract UniswapV4FullSpreadPonsFamilyHookOutMultiQueryTarget is UniswapV4FullSpreadPonsFamilyHookOutBase, NativeStandardYieldTarget {
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant operationScope returns (uint256 amount_)
    {
        // Native SY has already authorized the held-share debit. Keep its lock
        // and operation scope here, sharing the installed immutable exact-input delegate.
        address delegate_ = ExitBinding(address(this)).UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
        (bool ok_, bytes memory result_) = delegate_.delegatecall(abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", tokenOut_, shares_, minimum_, receiver_
        ));
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        amount_ = abi.decode(result_, (uint256));
        _pokeBoundPoolTwap();
    }


    function getTokensIn() public view override returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = _token0();
        tokens[1] = _token1();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        // V4 pools have bytes32 identifiers. The host is a liquidity identifier, not an ERC-20.
        // The complete PoolKey remains available on the existing pool metadata surface.
        return (IStandardizedYield.AssetType.LIQUIDITY, address(_poolManager()), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 1e18;
        (uint256 reserve0, uint256 reserve1) = _totalVaultReserves();
        return Math.mulDiv(FixedPointMathLib.mulSqrt(reserve0, reserve1), 1e18, supply);
    }


    function previewExchangeOutOneToMany(IERC20 tokenIn, address[] calldata tokensOut, uint256[] calldata amountsOut)
        external view returns (uint256 shares)
    {
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut))
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        (shares,) = _dualExitPlan(_snapshot(0, 0), amountsOut[0], amountsOut[1]);
    }
}

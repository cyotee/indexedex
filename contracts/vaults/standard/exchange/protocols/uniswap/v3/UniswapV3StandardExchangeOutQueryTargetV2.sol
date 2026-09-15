// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3StandardExchangeOutBaseV2
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3StandardExchangeOutBaseV2.sol";

abstract contract UniswapV3StandardExchangeOutQueryTargetV2 is UniswapV3StandardExchangeOutBaseV2, NativeStandardYieldTarget {
    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256)
    {
        if (address(in_) == address(this) && !internal_) {
            // SY redemption spends the caller's own native shares without a self-approval.
            ERC20Repo._transfer(msg.sender, address(this), amount_);
            internal_ = true;
        }
        return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
    }
    function getTokensIn() public view override returns (address[] memory tokens) {
        tokens = new address[](2); tokens[0] = _token0(); tokens[1] = _token1();
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(_pool()), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 1e18;
        (uint256 reserve0, uint256 reserve1) = _totalVaultReservesForShareMath();
        return Math.mulDiv(FixedPointMathLib.mulSqrt(reserve0, reserve1), 1e18, supply);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            if (!canOpenBoundPoolOps()) {
                revert UniswapV3Exchange_BoundPoolInteractionBlocked();
            }
            return _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            return _previewZapOutWithdrawal(address(tokenOut), amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}

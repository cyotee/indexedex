// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {NativeStandardYieldPreviewTarget as NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    UniswapV4StandardExchangeOutBase
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol";

contract UniswapV4StandardExchangeOutMultiQueryTarget is UniswapV4StandardExchangeOutBase, NativeStandardYieldTarget {
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


    function previewExchangeOutOneToMany(
        IERC20 tokenIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (uint256 amountIn) {
        if (address(tokenIn) != address(this) || !_isDualPoolCurrencies(tokensOut) || !_dualAmountsPositive(amountsOut))
        {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }

        uint256 amount0 = amountsOut[0];
        uint256 amount1 = amountsOut[1];
        uint256 totalShares = IERC20(address(this)).totalSupply();
        (uint256 total0, uint256 total1) = _totalVaultReserves();
        (uint256 s0, uint256 s1) = _dualExitShareBurns(amount0, amount1, total0, total1, totalShares);
        if (s0 != s1) {
            revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        return s0;
    }
}

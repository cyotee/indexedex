// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol";

/// @dev Read the constructor binding on the installed implementation, not a new vault selector.
interface IUniswapV3FullSpreadInExecutionBinding {
    function UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE() external view returns (address);
}

abstract contract UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget is UniswapV3FullSpreadStandardExchangeVaultOutBase, NativeStandardYieldTarget {
    function _redeemVaultHeld(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_)
        internal override nonReentrant returns (uint256)
    {
        address facet_ = IDiamondLoupe(address(this)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address delegate_ = IUniswapV3FullSpreadInExecutionBinding(facet_)
            .UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE();
        (bool ok_, bytes memory result_) = delegate_.delegatecall(abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", tokenOut_, shares_, minimum_, receiver_
        ));
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        return abi.decode(result_, (uint256));
    }

    /// @dev Ordinary share redemption moves the caller's own shares without an allowance,
    /// then delegatecalls the existing exit. It does not use an external self-call.
    function _standardRoute(IERC20 in_, uint256 amount_, IERC20 out_, uint256 minimum_, address receiver_, bool internal_)
        internal override returns (uint256 received_)
    {
        if (address(in_) != address(this) || internal_) {
            return super._standardRoute(in_, amount_, out_, minimum_, receiver_, internal_);
        }
        ERC20Repo._transfer(msg.sender, address(this), amount_);
        bytes memory data_ = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (in_, amount_, out_, minimum_, receiver_, true, block.timestamp)
        );
        (bool ok_, bytes memory result_) = address(this).delegatecall(data_);
        if (!ok_) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
        received_ = abi.decode(result_, (uint256));
        if (received_ < minimum_) revert SYMinimumNotMet(minimum_, received_);
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

        // D64: exact-out mint. A pair token in, exactly `amountOut` SE shares out.
        if (address(tokenOut) == address(this) && (address(tokenIn) == token0 || address(tokenIn) == token1)) {
            return _amountInForZapMint(address(tokenIn), amountOut);
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }
}

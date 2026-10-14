// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInBase} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";

abstract contract UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBase is UniswapV4FullSpreadHooklessStandardExchangeVaultInBase, StandardExchangeInExecutionBase {
    function _exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minAmountOut, address recipient, bool pretransferred, uint256 deadline)
        internal override nonReentrant exchangeInOperationScope returns (uint256 amountOut)
    {
        _requireExchangeInput(tokenIn, deadline);
        address token0 = _token0();
        address token1 = _token1();
        if ((address(tokenIn) == token0 || address(tokenIn) == token1) && address(tokenOut) == address(this)) {
            if (amountIn == 0) revert UniswapV4Exchange_ZeroAmount();
            if (ERC20Repo._totalSupply() == 0) revert IStandardExchangeErrors.InvalidRoute(address(tokenIn), address(this));
            uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, pretransferred);
            _requireExactDelivery(amountIn, actualIn);
            amountOut = _executeInputDeposit(address(tokenIn), actualIn, minAmountOut, recipient);
            _pokeBoundPoolTwap();
            return amountOut;
        }
        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            uint256 actualIn = _secureShareDelivery(amountIn, pretransferred);
            _requireExactDelivery(amountIn, actualIn);
            amountOut = _executeInputRedeem(address(tokenOut), actualIn, minAmountOut, recipient);
            _pokeBoundPoolTwap();
            return amountOut;
        }
        revert IStandardExchangeIn.ExchangeInNotAvailable();
    }
    function _isExchangeSwap(IERC20 in_, IERC20 out_) internal view returns (bool) {
        address token0 = _token0();
        address token1 = _token1();
        return (address(in_) == token0 && address(out_) == token1) || (address(in_) == token1 && address(out_) == token0);
    }
    function _exchangeSwapIn(IERC20 tokenIn, uint256 amountIn, uint256 minimum, address recipient, bool prepaid, uint256 deadline)
        internal nonReentrant exchangeInOperationScope returns (uint256 amountOut)
    {
        _requireExchangeInput(tokenIn, deadline);
        _requireCanOpenPoolManagerUnlock();
        if (amountIn == 0) revert UniswapV4Exchange_ZeroAmount();
        uint256 actualIn = _secureTokenTransfer(tokenIn, amountIn, prepaid);
        _requireExactDelivery(amountIn, actualIn);
        amountOut = _executeDirectSwapIn(address(tokenIn), actualIn, recipient);
        if (amountOut < minimum) revert UniswapV4ExchangeIn_SlippageExceeded();
        _pokeBoundPoolTwap();
    }
    function _requireExchangeInput(IERC20 tokenIn, uint256 deadline) private view {
        if (address(tokenIn) != address(this)) _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeIn_DeadlineExceeded();
    }
    function _executeInputDeposit(address tokenIn, uint256 amountIn, uint256 minimum, address recipient) internal virtual returns (uint256);
    function _executeInputRedeem(address tokenOut, uint256 shares, uint256 minimum, address recipient) internal virtual returns (uint256);
}

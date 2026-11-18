// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Address} from "@crane/contracts/utils/Address.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from "./UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IVault} from "./interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";

contract UniswapV3FullSpreadStandardExchangeVaultInTarget is
    UniswapV3FullSpreadStandardExchangeVaultCommon, ReentrancyLockModifiers
{
    using Address for address;
    address public immutable UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE;

    constructor(address executionDelegate_) {
        UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE = executionDelegate_;
    }

    function exchangeIn(
        IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minimum_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external nonReentrant returns (uint256 amountOut_, uint256 refunded_) {
        _deadline(deadline_);
        address input_ = address(tokenIn_);
        address output_ = address(tokenOut_);
        bool inputUnderlying_ = input_ == _token0() || input_ == _token1();
        bool outputUnderlying_ = output_ == _token0() || output_ == _token1();
        if (!(input_ == address(this) && outputUnderlying_)) _requireNotDisabled();
        if (input_ == output_ || !(inputUnderlying_ || input_ == address(this))
            || !(outputUnderlying_ || output_ == address(this))) {
            revert IStandardExchangeIn.ExchangeInNotAvailable();
        }
        if (amountIn_ == 0) revert IVault.EmptyExchange();
        _recipient(recipient_);
        if (pretransferred_) LocalCreditLib.requirePretransferCaller(msg.sender);
        bytes memory result_ = UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeExchangeIn(address,uint256,address,uint256,address,bool)",
                input_, amountIn_, output_, minimum_, recipient_, pretransferred_
            )
        );
        return abi.decode(result_, (uint256, uint256));
    }
}

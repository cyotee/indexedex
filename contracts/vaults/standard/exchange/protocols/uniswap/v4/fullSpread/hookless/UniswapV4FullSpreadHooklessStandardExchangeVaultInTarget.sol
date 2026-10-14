// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBase} from "./UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBase.sol";
import {StandardExchangeInExecutionBase} from "contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    UniswapV4FullSpreadHooklessStandardExchangeVaultInBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol";

interface IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport {
    function importPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut);
}


abstract contract UniswapV4FullSpreadHooklessStandardExchangeVaultInDelegateExecutionBase is UniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBase {
    using Address for address;

    address public immutable UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        if (executionDelegate.code.length == 0) revert AccountingMismatch();
        UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE = executionDelegate;
    }



    function _executeInputDeposit(address tokenIn, uint256 amountIn, uint256 minSharesOut, address recipient)
        internal
        override
        returns (uint256 sharesOut)
    {
        bytes memory result = UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapInDeposit(address,uint256,uint256,address)", tokenIn, amountIn, minSharesOut, recipient
            )
        );
        return abi.decode(result, (uint256));
    }

    function _executeInputRedeem(
        address tokenOut,
        uint256 sharesBurned,
        uint256 minAmountOut,
        address recipient
    ) internal override returns (uint256 amountOut) {
        bytes memory result =
            UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE.functionDelegateCall(
                abi.encodeWithSignature(
                    "executeZapOutExactIn(address,uint256,uint256,address)",
                    tokenOut,
                    sharesBurned,
                    minAmountOut,
                    recipient
                )
            );
        return abi.decode(result, (uint256));
    }
}

contract UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget is UniswapV4FullSpreadHooklessStandardExchangeVaultInDelegateExecutionBase {
    constructor(address executionDelegate) UniswapV4FullSpreadHooklessStandardExchangeVaultInDelegateExecutionBase(executionDelegate) {}
    function unlockCallback(bytes calldata data) external returns (bytes memory) { return _unlockCallback(data); }
    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 minimum, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256)
    {
        if (_isExchangeSwap(tokenIn, tokenOut)) return _exchangeSwapIn(tokenIn, amountIn, minimum, recipient, prepaid, deadline);
        return _exchangeIn(tokenIn, amountIn, tokenOut, minimum, recipient, prepaid, deadline);
    }
}

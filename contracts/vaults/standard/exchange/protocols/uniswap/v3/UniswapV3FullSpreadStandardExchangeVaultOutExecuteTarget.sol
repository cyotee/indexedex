// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV3FullSpreadStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutBase.sol";

abstract contract UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget is UniswapV3FullSpreadStandardExchangeVaultOutBase {
    using Address for address;

    address immutable UNISWAP_V3_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        UNISWAP_V3_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE = executionDelegate;
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        if (address(tokenIn) != address(this)) _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV3ExchangeOut_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            amountIn = _executeQuotedSwapOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred);
            _rebalanceLiquidReserveBestEffort();
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            amountIn = _delegateExecuteZapOutWithdrawal(
                address(tokenOut), maxAmountIn, amountOut, recipient, pretransferred
            );
            _rebalanceLiquidReserveBestEffort();
            return amountIn;
        }

        // D64: exact-out mint. Pull the closed-form pair input, book it, mint exactly `amountOut` shares.
        // Delegated to the CREATE3 execution delegate (mirrors the zap-out withdrawal) so the OutFacet
        // runtime stays under EIP-170; the closed-form math lives only in the delegate and the query facet.
        if (address(tokenOut) == address(this) && (address(tokenIn) == token0 || address(tokenIn) == token1)) {
            amountIn = _delegateExecuteZapInMintExactOut(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
            _rebalanceLiquidReserveBestEffort();
            return amountIn;
        }

        revert IStandardExchangeOut.ExchangeOutNotAvailable();
    }

    function _executeQuotedSwapOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        _requireCanOpenBoundPoolOps();
        uint256 quotedIn = _quoteSwapOut(address(tokenIn), address(tokenOut), amountOut);
        if (quotedIn > maxAmountIn) revert UniswapV3ExchangeOut_InsufficientInput();
        uint256 inboundBefore = tokenIn.balanceOf(address(this));
        uint256 pullAmount = quotedIn;
        if (pretransferred) {
            uint256 credit = _pretransferCredit(tokenIn, maxAmountIn);
            if (quotedIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(quotedIn, credit);
            pullAmount = credit;
        }
        uint256 providedAmountIn = _secureTokenTransfer(tokenIn, pullAmount, pretransferred);
        if (pretransferred) inboundBefore -= providedAmountIn;
        _requireDelivered(quotedIn, providedAmountIn);
        amountIn = _swapExactOut(address(tokenIn), address(tokenOut), amountOut, maxAmountIn, recipient);
        _requireDelivered(amountIn, providedAmountIn);
        if (pretransferred) {
            _refundThisCallUnusedInbound(tokenIn, inboundBefore, providedAmountIn, amountIn);
        }
        _syncVaultReserves();
    }

    /// @dev D64 exact-out mint, delegated to the CREATE3 execution delegate so the OutFacet runtime
    /// stays under EIP-170. The delegate computes the closed-form input, pulls it, books it and mints
    /// exactly `sharesOut`; preview equals execution because both read the owed-inclusive reserve basis.
    function _delegateExecuteZapInMintExactOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        uint256 sharesOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        bytes memory result = UNISWAP_V3_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapInMintExactOut(address,uint256,uint256,address,bool)",
                address(tokenIn),
                maxAmountIn,
                sharesOut,
                recipient,
                pretransferred
            )
        );
        return abi.decode(result, (uint256));
    }

    function _refundThisCallUnusedInbound(
        IERC20 tokenIn,
        uint256 inboundBefore,
        uint256 providedAmountIn,
        uint256 amountIn
    ) internal {
        uint256 unusedInbound =
            tokenIn.balanceOf(address(this)) > inboundBefore ? tokenIn.balanceOf(address(this)) - inboundBefore : 0;
        uint256 leftover = providedAmountIn > amountIn ? providedAmountIn - amountIn : 0;
        uint256 refund = leftover < unusedInbound ? leftover : unusedInbound;
        if (refund > 0) {
            _transferCurrency(address(tokenIn), msg.sender, refund);
        }
    }

    function _delegateExecuteZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 sharesBurned) {
        bytes memory result = UNISWAP_V3_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.functionDelegateCall(
            abi.encodeWithSignature(
                "executeZapOutWithdrawal(address,uint256,uint256,address,bool)",
                tokenOut,
                maxSharesToBurn,
                minAmountOut,
                recipient,
                pretransferred
            )
        );
        return abi.decode(result, (uint256));
    }
}

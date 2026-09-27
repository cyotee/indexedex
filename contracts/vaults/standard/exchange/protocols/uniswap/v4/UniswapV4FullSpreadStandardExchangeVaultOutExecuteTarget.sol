// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Address} from "@crane/contracts/utils/Address.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {
    UniswapV4FullSpreadStandardExchangeVaultOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutBase.sol";

/// @dev Direct swap + rebalance on Facet; heavy zap-out via CREATE3 OutExecutionDelegate (Option 2b).
abstract contract UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget is UniswapV4FullSpreadStandardExchangeVaultOutBase {
    using Address for address;

    address immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE = executionDelegate;
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
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            _requireCanOpenPoolManagerUnlock();
            // Reuse the installed query facet so the execute facet does not embed a second quoter.
            uint256 estimatedAmountIn = IStandardExchangeOut(address(this)).previewExchangeOut(tokenIn, tokenOut, amountOut);
            if (estimatedAmountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();

            uint256 inboundBefore = tokenIn.balanceOf(address(this));
            uint256 pullAmount = estimatedAmountIn;
            if (pretransferred) {
                uint256 credit = _pretransferCredit(tokenIn, maxAmountIn);
                if (estimatedAmountIn > credit) {
                    revert ISecurePullErrors.TransferDeltaInsufficient(estimatedAmountIn, credit);
                }
                pullAmount = credit;
            }
            uint256 providedAmountIn = _secureTokenTransfer(tokenIn, pullAmount, pretransferred);
            if (pretransferred) inboundBefore -= providedAmountIn;
            _requireDelivered(estimatedAmountIn, providedAmountIn);
            uint256 actualOut;
            (amountIn, actualOut) = _executeDirectSwapOut(address(tokenIn), amountOut, recipient);
            if (amountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();
            _requireDelivered(amountIn, providedAmountIn);
            if (actualOut < amountOut) revert UniswapV4ExchangeOut_SlippageExceeded();

            if (pretransferred) {
                _refundExcess(tokenIn, inboundBefore, providedAmountIn, amountIn);
            }
            _syncVaultReserves();
            _rebalanceLiquidReserveBestEffort();
            _pokeBoundPoolTwap();
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            amountIn = _delegateExecuteZapOutWithdrawal(
                address(tokenOut), maxAmountIn, amountOut, recipient, pretransferred
            );
            _rebalanceLiquidReserveBestEffort();
            _pokeBoundPoolTwap();
            return amountIn;
        }

        // D64: exact-out mint. Pull the closed-form pair input, book it, mint exactly `amountOut` shares.
        if (address(tokenOut) == address(this) && (address(tokenIn) == token0 || address(tokenIn) == token1)) {
            amountIn = _executeZapInMintExactOut(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
            _rebalanceLiquidReserveBestEffort();
            _pokeBoundPoolTwap();
            return amountIn;
        }

        revert ExchangeOutNotAvailable();
    }

    /// @dev D64 exact-out mint. `amountIn` is the closed-form minimal pair input for `sharesOut`
    /// (total-reserve basis, so it equals `previewExchangeOut`). The full input is booked by
    /// `_syncVaultReserves`; any rounding surplus over the exact backing stays for existing holders
    /// (D6, NAV never decreases). Mirrors the deposit path's collect / sleeve semantics.
    function _executeZapInMintExactOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        uint256 sharesOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 amountIn) {
        if (sharesOut == 0) revert UniswapV4Exchange_ZeroAmount();
        uint256 credit = pretransferred ? _pretransferCredit(tokenIn, maxAmountIn) : 0;
        amountIn = _amountInForZapMint(address(tokenIn), sharesOut, credit);
        if (amountIn > maxAmountIn) revert UniswapV4ExchangeOut_InsufficientInput();

        uint256 inboundBefore = tokenIn.balanceOf(address(this));
        uint256 pullAmount = amountIn;
        if (pretransferred) {
            if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);
            pullAmount = credit;
        }
        uint256 providedAmountIn = _secureTokenTransfer(tokenIn, pullAmount, pretransferred);
        if (pretransferred) inboundBefore -= providedAmountIn;
        _requireDelivered(amountIn, providedAmountIn);
        if (pretransferred) {
            _refundExcess(tokenIn, inboundBefore, providedAmountIn, amountIn);
        }

        _collectManagedFeesIfIdle();
        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();
    }

    function _executeDirectSwapOut(address tokenIn, uint256 amountOut, address recipient)
        internal
        returns (uint256 actualIn, uint256 actualOut)
    {
        bool zeroForOne = tokenIn == _token0();
        address outputToken = zeroForOne ? _token1() : _token0();
        uint256 inputBalanceBefore = IERC20(tokenIn).balanceOf(address(this));
        uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

        _executeUnlock(
            OperationParams({
                op: Operation.SwapExactOut,
                zeroForOne: zeroForOne,
                amountSpecified: amountOut,
                tickLower: 0,
                tickUpper: 0,
                liquidity: 0,
                salt: bytes32(0)
            })
        );

        actualIn = inputBalanceBefore - IERC20(tokenIn).balanceOf(address(this));
        actualOut = IERC20(outputToken).balanceOf(address(this)) - balanceBefore;
        _transferCurrency(outputToken, recipient, actualOut);
    }

    function _delegateExecuteZapOutWithdrawal(
        address tokenOut,
        uint256 maxSharesToBurn,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 sharesBurned) {
        bytes memory result = UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE.functionDelegateCall(
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

    function _refundExcess(IERC20 token, uint256 inboundBefore, uint256 providedAmount, uint256 usedAmount) internal {
        uint256 balance = token.balanceOf(address(this));
        uint256 unusedInbound = balance > inboundBefore ? balance - inboundBefore : 0;
        uint256 leftover = providedAmount > usedAmount ? providedAmount - usedAmount : 0;
        uint256 refund = leftover < unusedInbound ? leftover : unusedInbound;
        if (refund != 0) _transferCurrency(address(token), msg.sender, refund);
    }
}

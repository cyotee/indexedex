// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes as Types} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol";
import {UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath as Inventory} from "../hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol";
import {UniswapV4FullSpreadPonsFamilyHookTransitionPlanner as Planner} from "./UniswapV4FullSpreadPonsFamilyHookTransitionPlanner.sol";
import {UniswapV4FullSpreadPonsFamilyHookQuoteService as Quotes} from "./UniswapV4FullSpreadPonsFamilyHookQuoteService.sol";


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
    UniswapV4FullSpreadPonsFamilyHookOutBase
} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutBase.sol";

/// @dev Direct swap + rebalance on Facet; heavy zap-out via CREATE3 OutExecutionDelegate (Option 2b).
abstract contract UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget is UniswapV4FullSpreadPonsFamilyHookOutBase {
    using Address for address;

    address public immutable UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE;

    constructor(address executionDelegate) {
        if (executionDelegate.code.length == 0) revert AccountingMismatch();
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
    ) external nonReentrant operationScope returns (uint256 amountIn) {
        if (address(tokenIn) != address(this)) _requireNotDisabled();
        if (deadline < block.timestamp) revert UniswapV4ExchangeOut_DeadlineExceeded();

        address token0 = _token0();
        address token1 = _token1();

        if (
            (address(tokenIn) == token0 && address(tokenOut) == token1)
                || (address(tokenIn) == token1 && address(tokenOut) == token0)
        ) {
            amountIn = _executeDirectOut(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
            _pokeBoundPoolTwap();
            return amountIn;
        }

        if (address(tokenIn) == address(this) && (address(tokenOut) == token0 || address(tokenOut) == token1)) {
            amountIn = _delegateExecuteZapOutWithdrawal(
                address(tokenOut), maxAmountIn, amountOut, recipient, pretransferred
            );
            _pokeBoundPoolTwap();
            return amountIn;
        }

        // D64: exact-out mint. Pull the closed-form pair input, book it, mint exactly `amountOut` shares.
        if (address(tokenOut) == address(this) && (address(tokenIn) == token0 || address(tokenIn) == token1)) {
            amountIn = _executeZapInMintExactOut(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
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
        // The prepaid branch checked amountIn <= credit above; pull requires exact delivery.
        if (pretransferred) {
            _refundExcess(tokenIn, inboundBefore, providedAmountIn, amountIn);
        }

        // F1 is admitted only inside the enclosing manager session; collection is unavailable.
        ERC20Repo._mint(recipient, sharesOut);
        _syncVaultReserves();
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
        if (usedAmount > providedAmount) revert AccountingMismatch();
        uint256 refund = providedAmount - usedAmount;
        if (token.balanceOf(address(this)) < inboundBefore + refund) revert AccountingMismatch();
        if (refund != 0) _transferCurrency(address(token), msg.sender, refund);
    }

    struct DirectOutFrame {
        Types.Plan plan;
        uint256 credit;
        uint256 inboundBefore;
        uint256 provided;
        bool zeroForOne;
    }

    function _executeDirectOut(IERC20 tokenIn, uint256 maximum, uint256 amountOut, address recipient, bool prepaid)
        internal returns (uint256 used)
    {
        if (amountOut == 0) revert UniswapV4Exchange_ZeroAmount();
        DirectOutFrame memory frame;
        frame.zeroForOne = address(tokenIn) == _token0();
        frame.credit = prepaid ? _pretransferCredit(tokenIn, maximum) : 0;
        frame.plan = _directOutPlan(_snapshot(frame.zeroForOne ? frame.credit : 0, frame.zeroForOne ? 0 : frame.credit), frame.zeroForOne, amountOut);
        used = frame.plan.swap.amountIn;
        if (used > maximum) revert UniswapV4ExchangeOut_InsufficientInput();
        if (prepaid && used > frame.credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, frame.credit);
        frame.inboundBefore = tokenIn.balanceOf(address(this));
        frame.provided = _secureTokenTransfer(tokenIn, prepaid ? frame.credit : used, prepaid);
        if (prepaid) frame.inboundBefore -= frame.provided;
        // Prepaid credit was bounded above; a pull delivers exactly used or reverts.
        _commitExecutionPlan(keccak256(abi.encode(frame.plan)),
            frame.zeroForOne ? frame.provided - used : amountOut,
            frame.zeroForOne ? amountOut : frame.provided - used);
        _collectManagedFeesIfIdle();
        _executePlannedSwap(frame.plan.swap, true, 0);
        _transferCurrency(frame.zeroForOne ? _token1() : _token0(), recipient, amountOut);
        if (prepaid) _refundExcess(tokenIn, frame.inboundBefore, frame.provided, used);
        _commitExecutionPlan(keccak256(abi.encode(frame.plan)), 0, 0);
        _collectManagedFeesIfIdle();
        _executePlacement(frame.plan.placement);
        _verifyState(frame.plan.placement.afterState);
        _syncVaultReserves();
    }
}

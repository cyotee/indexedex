// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

/**
 * @title ERC4626StandardExchangeOutTarget
 * @notice Exact-out routes for ERC-4626 SE: wrap (tokenOut=SE), protocolVault→SE, and exits.
 *
 * @dev Exact-out law (D38/D50/D66/D69/D71/D74):
 *      calculate amountIn, consume only that, refund refundable surplus;
 *      unrefundable residual ≤ MAX_DUST_WEI → feeTo when non-zero, skip if feeTo==0;
 *      delivered out < amountOut → Slippage (not dust).
 *      Non-burn tokenIn: durable reserve-delta `_securePull` (no free-mint on booked reserve).
 *      Every money route end-syncs expected-hold reserves after refunds.
 */
contract ERC4626StandardExchangeOutTarget is
    ERC4626StandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    using SafeERC20 for IERC20;

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        if (address(tokenIn) == underlying && address(tokenOut) == address(this)) {
            return _previewUnderlyingInForSeOut(amountOut);
        }
        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            return _previewVaultInForSeOut(amountOut);
        }
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            return _previewSharesForVaultOut(amountOut);
        }
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            return _previewSeInForUnderlyingOut(amountOut);
        }

        revert UnsupportedRoute();
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
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        _requireNonZero(maxAmountIn);

        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        // Wrap exact-out: underlying → SE
        if (address(tokenIn) == underlying && address(tokenOut) == address(this)) {
            amountIn = _previewUnderlyingInForSeOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            _pullExactOutInput(tokenIn, amountIn, maxAmountIn, pretransferred);

            // Backing before this caller's credit (unbooked underlying is not in the backing).
            uint256 backingBefore = _receiptBacking();
            // D22/D31: precheck capacity, sweep booked reserve first, invest what fits, and
            // value the full credited input at the receipt's accounting rate.
            _investCreditedUnderlying(amountIn);
            uint256 sharesFromDelta = _convertVaultDeltaToShares(vault.convertToShares(amountIn), backingBefore);
            if (sharesFromDelta < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        // protocolVault → SE exact-out — amountIn vault tokens stay as SE reserve
        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            return _receiptForExactShares(tokenIn, maxAmountIn, amountOut, recipient, pretransferred);
        }

        // SE → protocolVault exact-out — burn only amountIn (self-burn when pretransferred).
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            amountIn = _previewSharesForVaultOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            uint256 held = IERC20(address(vault)).balanceOf(address(this));
            if (amountOut > held) revert InsufficientReceiptInventory(amountOut, held);
            _burnExactOutShares(amountIn, maxAmountIn, pretransferred);
            IERC20(address(vault)).safeTransfer(recipient, amountOut);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        // Unwrap exact-out: SE → underlying — burn only amountIn; local cash pays first (R14.15).
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            amountIn = _previewSeInForUnderlyingOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            _burnExactOutShares(amountIn, maxAmountIn, pretransferred);
            _payUnderlyingLocalFirst(vault, amountOut, recipient);
            _syncAllExpectedHoldReserves();
            return amountIn;
        }

        revert UnsupportedRoute();
    }

    function _receiptForExactShares(
        IERC20 receipt,
        uint256 maximum,
        uint256 shares,
        address recipient,
        bool pretransferred
    ) internal returns (uint256 required) {
        uint256 prepaid = pretransferred ? _prepaidCredit(receipt, maximum) : 0;
        // Full backing before this caller's credit: prepaid receipts already sit in the held
        // balance; a pulled receipt arrives after this snapshot.
        uint256 totalBefore = _receiptBacking() - prepaid;
        required = _vaultInForSeOut(shares, totalBefore);
        if (required > maximum) revert Slippage();
        uint256 received = _securePull(receipt, required, pretransferred);
        if (received != required) revert InsufficientDeposit(required, received);
        if (_convertVaultDeltaToShares(required, totalBefore) < shares) revert Slippage();
        _mintWithUsageFee(recipient, shares);
        // Only the caller's unused credited payment is refundable.
        if (prepaid > required) receipt.safeTransfer(msg.sender, prepaid - required);
        _syncAllExpectedHoldReserves();
    }
}

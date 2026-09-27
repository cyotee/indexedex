// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC4626StandardExchangeQuoteTarget} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol";

/**
 * @title ERC4626StandardExchangeInTarget
 * @notice Exact-in routes: underlying ↔ protocolVault ↔ SE shares (incl. SE → underlying unwrap).
 * @dev Mint routes apply dilution usage fee (D40). Exit / unwrap: no usage fee (D42).
 *      Non-burn tokenIn paths use durable reserve-delta `_securePull` (L-DETF-HOST-UPGRADE).
 *      Every money route end-syncs expected-hold reserves after refunds.
 */
contract ERC4626StandardExchangeInTarget is
    ERC4626StandardExchangeQuoteTarget,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using SafeERC20 for IERC20;
    using ERC4626Service for IERC4626;

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        // Identity share→share: DETF custom mint tables probe `previewExchangeIn(se, 1, se)`.
        if (address(tokenIn) == address(this) && address(tokenOut) == address(this)) {
            return amountIn;
        }

        // Mint SE
        if (address(tokenOut) == address(this)) {
            if (address(tokenIn) == address(vault)) {
                return _convertVaultDeltaToShares(amountIn, _receiptBacking());
            }
            if (address(tokenIn) == underlying) {
                uint256 receiptEquiv = vault.convertToShares(amountIn);
                return _convertVaultDeltaToShares(receiptEquiv, _receiptBacking());
            }
        }

        // Underlying ↔ protocol vault pass-through
        if (address(tokenIn) == underlying && address(tokenOut) == address(vault)) {
            return vault.previewDeposit(amountIn);
        }
        if (address(tokenIn) == address(vault) && address(tokenOut) == underlying) {
            return vault.previewRedeem(amountIn);
        }

        // Unwrap exact-in: SE → underlying (no exit fee)
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            return _previewUnderlyingOutForSeIn(amountIn);
        }

        // SE → protocol vault exact-in
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            return _previewRedeemShares(amountIn);
        }

        revert UnsupportedRoute();
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        // underlying → protocolVault
        if (address(tokenIn) == underlying && address(tokenOut) == address(vault)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            tokenIn.forceApprove(address(vault), actualIn);
            amountOut = vault.deposit(actualIn, recipient);
            if (amountOut < minAmountOut) revert Slippage();
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        // Wrap exact-in: underlying → SE (dilution fee). Mint on full credited input;
        // under-consumed remainder is booked locally (D22).
        if (address(tokenIn) == underlying && address(tokenOut) == address(this)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 backingBefore = _receiptBacking();
            _investCreditedUnderlying(actualIn);
            uint256 receiptEquiv = vault.convertToShares(actualIn);
            amountOut = _convertVaultDeltaToShares(receiptEquiv, backingBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        // protocolVault → SE (dilution fee) — durable U credit (no free-mint on booked reserve)
        // amountIn vault tokens **stay** as SE reserve; never refund absolute vault balance.
        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            // The credited receipt (prepaid or pulled) is already in the held balance. Exclude
            // only this payment; booked local underlying stays in the backing (R14.14).
            uint256 totalBefore = _receiptBacking() - actualIn;
            amountOut = _convertVaultDeltaToShares(actualIn, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // Pull overshoot already refunded in _securePull; reserve retained.
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        // protocolVault → underlying — redeem only actualIn; remaining vault tokens are reserve
        if (address(tokenIn) == address(vault) && address(tokenOut) == underlying) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            amountOut = vault.redeem(actualIn, recipient, address(this));
            if (amountOut < minAmountOut) revert Slippage();
            // Do not refund vault-token reserve
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        // Unwrap exact-in: SE → underlying (no exit fee) — burn SE shares (self-burn path).
        // Nested DETF push+true leaves shares on this diamond; burn from address(this).
        // !pretransferred burns from msg.sender (standard ERC20 burn-from-holder).
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            // Entitlement in receipt units of the full backing; local cash pays first (R14.15).
            amountOut = _previewUnderlyingOutForSeIn(amountIn);
            if (amountOut < minAmountOut) revert Slippage();
            _burnSeShares(msg.sender, amountIn, pretransferred);
            _payUnderlyingLocalFirst(vault, amountOut, recipient);
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        // SE → protocolVault exact-in — burn SE shares (self-burn path; same pretransfer law).
        // Receipt output needs actual receipts; local cash never substitutes for it (R14.15).
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            amountOut = _previewRedeemShares(amountIn);
            if (amountOut < minAmountOut) revert Slippage();
            uint256 held = IERC20(address(vault)).balanceOf(address(this));
            if (amountOut > held) revert InsufficientReceiptInventory(amountOut, held);
            _burnSeShares(msg.sender, amountIn, pretransferred);
            IERC20(address(vault)).safeTransfer(recipient, amountOut);
            _syncAllExpectedHoldReserves();
            return amountOut;
        }

        revert UnsupportedRoute();
    }
}

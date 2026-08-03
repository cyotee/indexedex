// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

/**
 * @title ERC4626StandardExchangeInTarget
 * @notice Exact-in routes: underlying ↔ protocolVault ↔ SE shares (incl. SE → underlying unwrap).
 * @dev Mint routes apply dilution usage fee (D40). Exit / unwrap: no usage fee (D42).
 *      Non-burn tokenIn paths use Rocket-style `_securePull` balance-delta only.
 */
contract ERC4626StandardExchangeInTarget is
    ERC4626StandardExchangeCommon,
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

        // Mint SE
        if (address(tokenOut) == address(this)) {
            if (address(tokenIn) == address(vault)) {
                uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
                return _convertVaultDeltaToShares(amountIn, totalBefore);
            }
            if (address(tokenIn) == underlying) {
                uint256 vaultDelta = vault.previewDeposit(amountIn);
                uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
                return _convertVaultDeltaToShares(vaultDelta, totalBefore);
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
            // Only idle underlying cash (not protocol-vault reserve)
            _refundOrAbsorbAbove(tokenIn, msg.sender, 0);
            return amountOut;
        }

        // Wrap exact-in: underlying → SE (dilution fee)
        if (address(tokenIn) == underlying && address(tokenOut) == address(this)) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            tokenIn.forceApprove(address(vault), actualIn);
            uint256 vaultDelta = vault.deposit(actualIn, address(this));
            amountOut = _convertVaultDeltaToShares(vaultDelta, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // Idle underlying leftover after deposit (e.g. under-consume dust) only
            _refundOrAbsorbAbove(tokenIn, msg.sender, 0);
            return amountOut;
        }

        // protocolVault → SE (dilution fee) — balance-delta only (no free-mint on reserve)
        // amountIn vault tokens **stay** as SE reserve; never refund absolute vault balance.
        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            // totalBefore is vault inventory *before* this user's deposit delta
            amountOut = _convertVaultDeltaToShares(actualIn, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // Pull overshoot already refunded in _securePull; reserve retained.
            return amountOut;
        }

        // protocolVault → underlying — redeem only actualIn; remaining vault tokens are reserve
        if (address(tokenIn) == address(vault) && address(tokenOut) == underlying) {
            uint256 actualIn = _securePull(tokenIn, amountIn, pretransferred);
            amountOut = vault.redeem(actualIn, recipient, address(this));
            if (amountOut < minAmountOut) revert Slippage();
            // Do not refund vault-token reserve
            return amountOut;
        }

        // Unwrap exact-in: SE → underlying (no exit fee) — burn SE, no tokenIn pull
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            uint256 vaultOut = _previewRedeemShares(amountIn);
            ERC20Repo._burn(msg.sender, amountIn);
            amountOut = vault.redeem(vaultOut, recipient, address(this));
            if (amountOut < minAmountOut) revert Slippage();
            return amountOut;
        }

        // SE → protocolVault exact-in — burn SE
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            amountOut = _previewRedeemShares(amountIn);
            if (amountOut < minAmountOut) revert Slippage();
            ERC20Repo._burn(msg.sender, amountIn);
            IERC20(address(vault)).safeTransfer(recipient, amountOut);
            return amountOut;
        }

        revert UnsupportedRoute();
    }
}

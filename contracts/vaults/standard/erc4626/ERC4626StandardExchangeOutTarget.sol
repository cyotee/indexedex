// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC4626StandardExchangeCommon} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol";

/**
 * @title ERC4626StandardExchangeOutTarget
 * @notice Exact-out routes for ERC-4626 SE: wrap (tokenOut=SE), protocolVault→SE, and exits.
 *
 * @dev Exact-out law (D38/D50/D66/D69/D71/D74):
 *      calculate amountIn, consume only that, refund refundable surplus;
 *      unrefundable residual ≤ MAX_DUST_WEI → feeTo when non-zero, skip if feeTo==0;
 *      delivered out < amountOut → Slippage (not dust).
 *      Non-burn tokenIn: Rocket `_securePull` balance-delta only (no free-mint on reserve).
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

            // Balance-delta pull only (Rocket peer). Prefer !pretransferred+transferFrom.
            // pretransferred=true requires a same-tx delta ≥ amountIn (not absolute reserve).
            _securePull(tokenIn, amountIn, pretransferred);

            // Vault-token inventory before deposit (underlying pull does not change it).
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            tokenIn.forceApprove(address(vault), amountIn);
            uint256 vaultDelta = vault.deposit(amountIn, address(this));
            uint256 sharesFromDelta = _convertVaultDeltaToShares(vaultDelta, totalBefore);
            if (sharesFromDelta < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);

            // Idle underlying leftover after deposit only (not protocol-vault reserve)
            _refundOrAbsorbAbove(tokenIn, msg.sender, 0);
            return amountIn;
        }

        // protocolVault → SE exact-out — amountIn vault tokens stay as SE reserve
        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            amountIn = _previewVaultInForSeOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();

            // Snapshot reserve *before* user deposit delta (free-mint safe).
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            _securePull(tokenIn, amountIn, pretransferred);

            uint256 sharesFromDelta = _convertVaultDeltaToShares(amountIn, totalBefore);
            if (sharesFromDelta < amountOut) revert Slippage();
            _mintWithUsageFee(recipient, amountOut);
            // Pull overshoot already refunded in _securePull; never refund absolute reserve.
            return amountIn;
        }

        // SE → protocolVault exact-out — burn only amountIn
        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            amountIn = _previewSharesForVaultOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            ERC20Repo._burn(msg.sender, amountIn);
            IERC20(address(vault)).safeTransfer(recipient, amountOut);
            return amountIn;
        }

        // Unwrap exact-out: SE → underlying — burn only amountIn; Slippage if short
        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            amountIn = _previewSeInForUnderlyingOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();

            uint256 vaultOut = _previewRedeemShares(amountIn);
            ERC20Repo._burn(msg.sender, amountIn);
            uint256 underlyingOut = vault.redeem(vaultOut, recipient, address(this));
            if (underlyingOut < amountOut) revert Slippage();
            return amountIn;
        }

        revert UnsupportedRoute();
    }
}

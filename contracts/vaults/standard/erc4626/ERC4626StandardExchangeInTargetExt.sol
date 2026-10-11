// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {
    ERC4626StandardExchangeQuoteTarget
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol";

/// @dev Preview selector only. `exchangeIn` stays on `ERC4626StandardExchangeInTarget`.
contract ERC4626StandardExchangeInTargetExt is ERC4626StandardExchangeQuoteTarget {
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
}

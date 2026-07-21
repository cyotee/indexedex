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
 * @notice Routes: underlying ↔ protocolVault ↔ SE shares.
 */
contract ERC4626StandardExchangeInTarget is
    ERC4626StandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using SafeERC20 for IERC20;
    using ERC4626Service for IERC4626;

    error DeadlineExpired();
    error Slippage();
    error UnsupportedRoute();

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

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

        if (address(tokenIn) == underlying && address(tokenOut) == address(vault)) {
            return vault.previewDeposit(amountIn);
        }
        if (address(tokenIn) == address(vault) && address(tokenOut) == underlying) {
            return vault.previewRedeem(amountIn);
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
    ) external returns (uint256 amountOut) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        if (!pretransferred && amountIn > 0) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        }

        if (address(tokenIn) == underlying && address(tokenOut) == address(vault)) {
            tokenIn.forceApprove(address(vault), amountIn);
            amountOut = vault.deposit(amountIn, recipient);
            if (amountOut < minAmountOut) revert Slippage();
            return amountOut;
        }

        if (address(tokenIn) == underlying && address(tokenOut) == address(this)) {
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this));
            tokenIn.forceApprove(address(vault), amountIn);
            uint256 vaultDelta = vault.deposit(amountIn, address(this));
            amountOut = _convertVaultDeltaToShares(vaultDelta, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            ERC20Repo._mint(recipient, amountOut);
            return amountOut;
        }

        if (address(tokenIn) == address(vault) && address(tokenOut) == address(this)) {
            uint256 totalBefore = IERC20(address(vault)).balanceOf(address(this)) - amountIn;
            // vault tokens already on this contract if pretransferred; else pulled above
            amountOut = _convertVaultDeltaToShares(amountIn, totalBefore);
            if (amountOut < minAmountOut) revert Slippage();
            ERC20Repo._mint(recipient, amountOut);
            return amountOut;
        }

        if (address(tokenIn) == address(vault) && address(tokenOut) == underlying) {
            amountOut = vault.redeem(amountIn, recipient, address(this));
            if (amountOut < minAmountOut) revert Slippage();
            return amountOut;
        }

        revert UnsupportedRoute();
    }
}

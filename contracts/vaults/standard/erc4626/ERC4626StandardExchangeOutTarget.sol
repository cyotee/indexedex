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
 * @notice Exit routes: SE shares → protocolVault or underlying.
 */
contract ERC4626StandardExchangeOutTarget is
    ERC4626StandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeOut
{
    using SafeERC20 for IERC20;

    error DeadlineExpired();
    error Slippage();
    error UnsupportedRoute();

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        if (address(tokenIn) == address(this) && address(tokenOut) == address(vault)) {
            // amountOut is vault tokens desired; SE shares needed ≈ amountOut (when 1:1-ish)
            uint256 supply = ERC20Repo._totalSupply();
            uint256 vaultBal = IERC20(address(vault)).balanceOf(address(this));
            if (supply == 0 || vaultBal == 0) return amountOut;
            return (amountOut * supply + vaultBal - 1) / vaultBal;
        }

        if (address(tokenIn) == address(this) && address(tokenOut) == underlying) {
            // approximate SE shares needed for amountOut underlying
            uint256 vaultNeeded = vault.previewWithdraw(amountOut);
            uint256 supply = ERC20Repo._totalSupply();
            uint256 vaultBal = IERC20(address(vault)).balanceOf(address(this));
            if (supply == 0 || vaultBal == 0) return vaultNeeded;
            return (vaultNeeded * supply + vaultBal - 1) / vaultBal;
        }

        revert UnsupportedRoute();
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool, /* pretransferred */
        uint256 deadline
    ) external returns (uint256 amountIn) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (address(tokenIn) != address(this)) revert UnsupportedRoute();

        IERC4626 vault = protocolVault();
        address underlying = vault.asset();

        if (address(tokenOut) == address(vault)) {
            amountIn = _previewSharesForVaultOut(amountOut);
            if (amountIn > maxAmountIn) revert Slippage();
            ERC20Repo._burn(msg.sender, amountIn);
            IERC20(address(vault)).safeTransfer(recipient, amountOut);
            return amountIn;
        }

        if (address(tokenOut) == underlying) {
            // Burn SE for proportional vault tokens then redeem to underlying
            uint256 vaultBal = IERC20(address(vault)).balanceOf(address(this));
            uint256 supply = ERC20Repo._totalSupply();
            // Use maxAmountIn SE shares as the spend
            amountIn = maxAmountIn;
            uint256 vaultOut = supply == 0 ? 0 : (amountIn * vaultBal) / supply;
            ERC20Repo._burn(msg.sender, amountIn);
            uint256 underlyingOut = vault.redeem(vaultOut, recipient, address(this));
            if (underlyingOut < amountOut) revert Slippage();
            return amountIn;
        }

        revert UnsupportedRoute();
    }

    function _previewSharesForVaultOut(uint256 vaultAmountOut) internal view returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
        if (supply == 0 || vaultBal == 0) return vaultAmountOut;
        return (vaultAmountOut * supply + vaultBal - 1) / vaultBal;
    }
}

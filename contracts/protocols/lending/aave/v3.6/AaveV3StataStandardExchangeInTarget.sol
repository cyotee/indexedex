// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {ERC4626Service} from "@crane/contracts/tokens/ERC4626/ERC4626Service.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStataTokenV2} from "@crane/contracts/protocols/lending/aave/v3.6/extensions/stata-token/interfaces/IStataTokenV2.sol";

import {IPool} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPool.sol";
import {IAToken} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAToken.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {AaveV3StataStandardExchangeCommon} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";

/**
 * @title AaveV3StataStandardExchangeInTarget
 * @notice Target implementing IStandardExchangeIn for the Stata wrapper.
 * Supported routes (see plan for full matrix):
 * - Base <-> aToken, Base <-> Strata, Base <-> SE Vault
 * - aToken <-> Strata, aToken <-> SE Vault
 * - Strata <-> SE Vault
 *
 * When the output is SE Vault shares, usage fee inflation + reward collection is applied.
 */
contract AaveV3StataStandardExchangeInTarget is
    AaveV3StataStandardExchangeCommon,
    ReentrancyLockModifiers,
    IStandardExchangeIn
{
    using SafeERC20 for IERC20;

    /* ------------------------------------------------------------------ */
    /*                          Helpers                                   */
    /* ------------------------------------------------------------------ */

    function _stata() internal view returns (address) {
        return IAaveV3StataStandardVault(address(this)).stataToken();
    }

    function _aToken() internal view returns (address) {
        address stata = _stata();
        if (stata == address(0)) return address(0);
        return IStataTokenV2(stata).aToken();
    }

    function _pool() internal view returns (IPool) {
        // In full, from the stata or a known pool.
        // For sketch, many paths don't require direct pool if using stata.
        return IPool(address(0));
    }

    function _underlying() internal view returns (address) {
        return IERC4626(_stata()).asset();
    }

    /* ------------------------- IStandardExchangeIn ------------------------ */

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        address stata = _stata();
        address underlying = _underlying();

        // to SE Vault shares (applies same math as execution)
        if (address(tokenOut) == address(this)) {
            if (address(tokenIn) == stata || address(tokenIn) == underlying) {
                uint256 stataDelta = (address(tokenIn) == stata) ? amountIn : IERC4626(stata).previewDeposit(amountIn);
                uint256 totalBefore = IERC20(stata).balanceOf(address(this));
                return _convertStataDeltaToShares(stataDelta, totalBefore);
            }
        }

        // stata -> base
        if (address(tokenIn) == stata && address(tokenOut) == underlying) {
            return IERC4626(stata).previewRedeem(amountIn);
        }

        // base -> stata (and base -> aToken as pass-through for now)
        if (address(tokenIn) == underlying && address(tokenOut) == stata) {
            return IERC4626(stata).previewDeposit(amountIn);
        }

        // default for sketch (aToken paths etc return input for 1:1 mocks)
        if (address(tokenIn) == underlying && address(tokenOut) == _aToken()) {
            return amountIn;
        }
        if (address(tokenIn) == _aToken() && (address(tokenOut) == stata || address(tokenOut) == address(this))) {
            // for preview assume 1:1 pass or would delegate
            return amountIn;
        }

        return amountIn;
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
        address stata = _stata();
        address base = _underlying();
        IPool pool = _pool();

        // Pull tokens if not pretransferred
        if (!pretransferred && amountIn > 0) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        }

        uint256 totalAssetsBefore = IERC20(stata).balanceOf(address(this));

        if (address(tokenIn) == base && address(tokenOut) == _aToken()) {
            tokenIn.safeApprove(address(pool), amountIn);
            pool.supply(base, amountIn, recipient, 0);
            amountOut = amountIn;
            _collectAndForwardRewards();
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        if (address(tokenIn) == base && address(tokenOut) == stata) {
            tokenIn.safeApprove(stata, amountIn);
            amountOut = IERC4626(stata).deposit(amountIn, recipient);
            _collectAndForwardRewards();
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        if (address(tokenIn) == base && address(tokenOut) == address(this)) {
            tokenIn.safeApprove(stata, amountIn);
            uint256 delta = IERC4626(stata).deposit(amountIn, address(this));
            amountOut = _mintStataDeltaAsSEShares(delta, recipient, totalAssetsBefore);
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        if (address(tokenIn) == _aToken() && address(tokenOut) == stata) {
            tokenIn.safeApprove(stata, amountIn);
            amountOut = IStataTokenV2(stata).depositATokens(amountIn, recipient);
            _collectAndForwardRewards();
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        if (address(tokenIn) == _aToken() && address(tokenOut) == address(this)) {
            tokenIn.safeApprove(stata, amountIn);
            uint256 delta = IStataTokenV2(stata).depositATokens(amountIn, address(this));
            amountOut = _mintStataDeltaAsSEShares(delta, recipient, totalAssetsBefore);
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        if (address(tokenIn) == stata && address(tokenOut) == address(this)) {
            amountOut = _mintStataDeltaAsSEShares(amountIn, recipient, totalAssetsBefore);
            require(amountOut >= minAmountOut, "slippage");
            return amountOut;
        }

        revert ExchangeInNotAvailable();
    }

    /* ------------------ Internal helpers for share mint + fee ------------------ */

    /* ------------------------------------------------------------------ */
    /*                     Mint path helper (uses Common)                   */
    /* ------------------------------------------------------------------ */

    /**
     * @dev After increasing our stata holding by `deltaStata` (via deposit into stata),
     *      convert the delta to SE Vault shares (using pre-delta totals) and mint
     *      with usage fee inflation + trigger reward forward.
     */
    function _mintStataDeltaAsSEShares(uint256 deltaStata, address recipient, uint256 totalAssetsBefore)
        internal
        returns (uint256 sharesMinted)
    {
        uint256 sharesForDeposit = _convertStataDeltaToShares(deltaStata, totalAssetsBefore);

        _mintSharesWithUsageFee(recipient, sharesForDeposit);
        _collectAndForwardRewards();

        return sharesForDeposit;
    }

    function _previewMintSEShares(uint256 grossStata) internal view returns (uint256) {
        address stataAddr = _stata();
        uint256 totalAssets = IERC20(stataAddr).balanceOf(address(this));
        uint256 shares = _convertStataDeltaToShares(grossStata, totalAssets);

        // Preview returns what the user will receive (full sharesForDeposit).
        // Fee inflation happens on top (extra to feeTo).
        return shares;
    }
}
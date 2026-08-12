// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";

/**
 * @title ERC4626StandardExchangeCommon
 * @notice Shared helpers for generic ERC-4626 SE in/out routes.
 *
 * @dev Unrefundable multi-leg residual dust is bounded by `MAX_DUST_WEI` (10).
 *      When residual ≤ MAX_DUST_WEI cannot be refunded on-path without a second transfer,
 *      absorb to oracle `feeTo` only if `feeTo != address(0)`; skip absorb when `feeTo == 0`
 *      (Rocket Pool fee-mint peer). Residual > MAX_DUST_WEI is not silent absorb.
 *      Under-delivery of amountOut is Slippage, not dust.
 *
 * @dev Token-in pull is durable reserve-delta (BasicVault peer / L-DETF-HOST-UPGRADE):
 *      `U = B - R`; `pretransferred=true` credits claimed iff `claimed <= U`.
 *      Nested DETF push+true requires this (observed in-call delta is always 0 after external push).
 */
abstract contract ERC4626StandardExchangeCommon is IERC4626StandardExchange {
    using SafeERC20 for IERC20;

    /// @notice Max unrefundable multi-leg residual absorbed to feeTo (wei). PRD D50/D55.
    uint256 internal constant MAX_DUST_WEI = 10;

    error ZeroAmount();
    error Slippage();
    error UnsupportedRoute();
    error DeadlineExpired();
    error InsufficientDeposit(uint256 required, uint256 actual);

    function protocolVault() public view virtual returns (IERC4626) {
        return IERC4626(address(ERC4626Repo._reserveAsset()));
    }

    function _underlying() internal view returns (address) {
        return protocolVault().asset();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    /// @dev Convert protocol-vault token delta into SE shares (first depositor 1:1).
    function _convertVaultDeltaToShares(uint256 vaultDelta, uint256 totalVaultBefore)
        internal
        view
        returns (uint256 shares)
    {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || totalVaultBefore == 0) {
            return vaultDelta;
        }
        return (vaultDelta * supply) / totalVaultBefore;
    }

    /// @dev Invert: SE shares needed for a vault-token amount out (ceil).
    function _previewSharesForVaultOut(uint256 vaultAmountOut) internal view returns (uint256) {
        uint256 supply = ERC20Repo._totalSupply();
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
        if (supply == 0 || vaultBal == 0) return vaultAmountOut;
        return (vaultAmountOut * supply + vaultBal - 1) / vaultBal;
    }

    /// @dev Pro-rata protocol vault tokens for burning `seShares` SE.
    function _previewRedeemShares(uint256 seShares) internal view returns (uint256 vaultTokensOut) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 0;
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
        return (seShares * vaultBal) / supply;
    }

    /// @dev SE shares in for exact underlying out (true exact-out).
    function _previewSeInForUnderlyingOut(uint256 underlyingOut) internal view returns (uint256 seIn) {
        IERC4626 vault = protocolVault();
        uint256 vaultNeeded = vault.previewWithdraw(underlyingOut);
        return _previewSharesForVaultOut(vaultNeeded);
    }

    /// @dev Underlying in required to mint exact user SE shares (wrap exact-out).
    ///      Fee is dilution mint (extra supply); does not increase amountIn.
    function _previewUnderlyingInForSeOut(uint256 seOut) internal view returns (uint256 underlyingIn) {
        IERC4626 vault = protocolVault();
        uint256 supply = ERC20Repo._totalSupply();
        uint256 vaultBal = IERC20(address(vault)).balanceOf(address(this));
        uint256 vaultDelta;
        if (supply == 0 || vaultBal == 0) {
            vaultDelta = seOut;
        } else {
            vaultDelta = (seOut * vaultBal + supply - 1) / supply;
        }
        return vault.previewMint(vaultDelta);
    }

    /// @dev Protocol vault tokens in for exact user SE shares (protocolVault → SE exact-out).
    function _previewVaultInForSeOut(uint256 seOut) internal view returns (uint256 vaultIn) {
        uint256 supply = ERC20Repo._totalSupply();
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
        if (supply == 0 || vaultBal == 0) {
            return seOut;
        }
        return (seOut * vaultBal + supply - 1) / supply;
    }

    /// @dev Underlying out for exact SE in (unwrap exact-in).
    function _previewUnderlyingOutForSeIn(uint256 seIn) internal view returns (uint256 underlyingOut) {
        uint256 vaultOut = _previewRedeemShares(seIn);
        if (vaultOut == 0) return 0;
        return protocolVault().previewRedeem(vaultOut);
    }

    /**
     * @dev Dilution usage fee on share-minting routes only (D40/D40a/D57).
     *      User receives full `userShares`; fee expands supply to feeTo when non-zero.
     *      Skips when feePct==0, feeTo==0, or feeShares==0 (Rocket Pool peer / D71).
     */
    function _mintWithUsageFee(address recipient, uint256 userShares) internal {
        ERC20Repo._mint(recipient, userShares);
        uint256 feePct = VaultFeeOracleQueryAwareRepo._feeOracle().usageFeeOfVault(address(this));
        if (feePct == 0) return;
        uint256 feeShares = BetterMath._percentageOfWAD(userShares, feePct);
        if (feeShares == 0) return;
        address feeTo_ = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo_ == address(0)) return;
        ERC20Repo._mint(feeTo_, feeShares);
    }

    /**
     * @dev Absorb unrefundable residual ≤ MAX_DUST_WEI to oracle feeTo when non-zero.
     *      Skip when feeTo==0 (D71). Residual > MAX_DUST_WEI must not call this.
     */
    function _absorbDustToFeeTo(IERC20 token, uint256 amount) internal {
        if (amount == 0 || amount > MAX_DUST_WEI) return;
        address feeTo_ = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo_ == address(0)) return;
        token.safeTransfer(feeTo_, amount);
    }

    /**
     * @dev Durable reserve-delta secure pull (BasicVault peer).
     *      - `R = reserveOfToken` (booked at last money-route sync)
     *      - `B = balanceOf(this)`
     *      - `U = B - R` (unbooked surplus)
     *      - `!pretransferred`: transferFrom; credit **pull delta only** (FoT-safe; no prior U).
     *        Pull overshoot is refunded immediately (D38).
     *      - `pretransferred`: no in-call transfer; credit `claimed` iff `claimed <= U`, else
     *        `TransferDeltaInsufficient(claimed, U)`. I1 when `R == B` (U=0).
     *      Unclaimed surplus (`U - claimed`) is **not** refunded here — absorbed into `R` at
     *      end-route `_syncAllExpectedHoldReserves()`.
     */
    function _securePull(IERC20 token, uint256 amountIn, bool pretransferred)
        internal
        returns (uint256 actualIn)
    {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token));
        uint256 B0 = token.balanceOf(address(this));

        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amountIn);
            uint256 delta = token.balanceOf(address(this)) - B0;
            if (delta == 0) {
                revert InsufficientDeposit(amountIn, 0);
            }
            // FoT / under-pull
            if (delta < amountIn) {
                return delta;
            }
            // Pull overshoot: refund immediately to caller (D38)
            if (delta > amountIn) {
                _refundExcess(token, msg.sender, delta - amountIn);
            }
            return amountIn;
        }

        // pretransferred == true — durable reserve baseline
        uint256 U = B0 - R;
        if (amountIn > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, U);
        }
        return amountIn;
    }

    /// @dev Full expected-hold sync after money routes (L-RSRV-SYNC-FULL / L-DETF-END-ORDER).
    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    /**
     * @dev Refund/absorb only balance **above** `keepBalance`.
     *      NEVER call with keepBalance=0 on protocol-vault tokens that back SE shares —
     *      that would drain reserve inventory to `to`.
     *      Intended for idle **underlying cash** leftover after deposit/consume.
     *      Pull overshoot is already refunded inside `_securePull`.
     */
    function _refundOrAbsorbAbove(IERC20 token, address to, uint256 keepBalance) internal {
        uint256 bal = token.balanceOf(address(this));
        if (bal <= keepBalance) return;
        uint256 leftover = bal - keepBalance;
        if (leftover > MAX_DUST_WEI) {
            _refundExcess(token, to, leftover);
        } else {
            _absorbDustToFeeTo(token, leftover);
        }
    }

    function _refundExcess(IERC20 token, address to, uint256 excess) internal {
        if (excess == 0) return;
        token.safeTransfer(to, excess);
    }

    /**
     * @dev Burn SE shares for unwrap / SE→protocolVault routes (L-DETF-SHARE / BasicVault peer).
     *      - `pretransferred=true`: shares were pushed onto this diamond; burn `address(this)`.
     *        Refund leftover free shares on diamond to `owner` (exact-out partial maxIn).
     *      - `pretransferred=false`: burn from `owner` (msg.sender holder).
     */
    function _burnSeShares(address owner, uint256 burnAmount, bool pretransferred) internal {
        if (pretransferred) {
            ERC20Repo._burn(address(this), burnAmount);
            uint256 leftover = IERC20(address(this)).balanceOf(address(this));
            if (leftover > 0) {
                IERC20(address(this)).safeTransfer(owner, leftover);
            }
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
    }
}

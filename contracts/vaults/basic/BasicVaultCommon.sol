// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

// tag::BasicVaultCommon[]
/**
 * @title BasicVaultCommon - Behavior common to call vaults.
 * @author cyotee doge <not_cyotee@proton.me>
 * @dev Reserve-delta pretransfer: `pretransferred=true` credits `claimed` only when
 *      `claimed <= U` where `U = balanceOf - reserveOfToken` (durable last-accounted snapshot).
 *      Unclaimed push surplus is absorbed into `R` at end-of-op full-set sync (not refunded).
 *      Exact-out refunds (`_refundExcess`) only when `maxAmount > usedAmount` with pretransfer.
 *      Every money route must call `_syncAllExpectedHoldReserves()` after refunds.
 */
contract BasicVaultCommon is ISecurePullErrors {
    using BetterSafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*  Reserve helpers (MultiAssetBasicVaultRepo durable book)               */
    /* ---------------------------------------------------------------------- */

    /// @notice Booked reserve snapshot for `token` (last end-of-op sync).
    function _bookedReserve(IERC20 token) internal view returns (uint256) {
        return MultiAssetBasicVaultRepo._reserveOfToken(address(token));
    }

    /// @notice Unbooked surplus `U = balanceOf - reserveOfToken` (checked math; no underflow product error).
    function _unbookedSurplus(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this)) - MultiAssetBasicVaultRepo._reserveOfToken(address(token));
    }

    /// @notice Set booked reserve of one token to its live balance.
    function _syncReserveToBalance(IERC20 token) internal {
        MultiAssetBasicVaultRepo._updateReserve(token, token.balanceOf(address(this)));
    }

    /// @notice Full expected-hold sync: for each `_vaultTokens` entry, `R := balanceOf`.
    /// @dev Call at end of every successful money route, after `_refundExcess`.
    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    // tag::_secureTokenTransfer(address_uint256_bool)[]
    /**
     * @notice Securely pulls or credits tokens into the vault using reserve-delta accounting.
     * @dev Definitions:
     *      - `R = reserveOfToken` (booked snapshot from last money-route sync)
     *      - `B = balanceOf(vault)`
     *      - `U = B - R` (unbooked surplus)
     *
     *      - `!pretransferred`: pulls via ERC20 allowance or Permit2, returns the actual
     *        inbound pull delta only (FoT-safe; does **not** add prior unbooked `U`).
     *      - `pretransferred`: no in-call transfer. Credits exactly `claimed` iff
     *        `claimed <= U`; otherwise reverts `TransferDeltaInsufficient(claimed, U)`.
     *        Absolute free credit of booked inventory is forbidden (I1 when `R == B`).
     *        Unclaimed surplus (`U - claimed`) is **not** refunded here; it is absorbed
     *        into `R` when the route ends with `_syncAllExpectedHoldReserves()`.
     * @param tokenIn The token to transfer into the vault.
     * @param amountTokenToDeposit Claimed amount to pull / credit.
     * @param pretransferred When true, no transfer is performed in this call; credit requires
     *        `claimed <= unbooked surplus` relative to durable reserve.
     * @return actualIn Credited amount: claimed when pretransferred and surplus-sufficient;
     *         otherwise the observed inbound pull delta.
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
        internal
        virtual
        returns (uint256 actualIn)
    {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 B0 = tokenIn.balanceOf(address(this));

        if (!pretransferred) {
            if (tokenIn.allowance(msg.sender, address(this)) < amountTokenToDeposit) {
                Permit2AwareRepo._permit2()
                    .transferFrom(msg.sender, address(this), uint160(amountTokenToDeposit), address(tokenIn));
            } else {
                tokenIn.safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);
            }
            uint256 B1 = tokenIn.balanceOf(address(this));
            // FoT-safe: return pull delta only — do NOT add prior unbooked U
            return B1 - B0;
        }

        // pretransferred == true — durable reserve baseline
        uint256 U = B0 - R;
        if (amountTokenToDeposit > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amountTokenToDeposit, U);
        }
        return amountTokenToDeposit;
    }

    /**
     * @notice Refunds this-call unused inbound tokens after an exact-out consume.
     * @dev E6 law: refund `min(maxAmount_ - usedAmount_, unused U)` only, where
     *      `U = balanceOf(this) - reserveOfToken` (unbooked surplus). Never pays booked `R`.
     *      If `U == 0`, refund is 0. Gate remains `pretransferred_ && maxAmount_ > usedAmount_`.
     *      Does **not** refund unclaimed push surplus beyond this-call unused inbound;
     *      leftover surplus is absorbed into booked reserve at end-of-op full-set sync.
     *      Call **before** `_syncAllExpectedHoldReserves()`.
     * @param token_ The token to refund.
     * @param maxAmount_ The maximum amount that was pretransferred / credited.
     * @param usedAmount_ The amount that was actually consumed by the operation.
     * @param pretransferred_ Whether tokens were pretransferred.
     * @param recipient_ The address to receive the refund (typically msg.sender / the router).
     */
    function _refundExcess(
        IERC20 token_,
        uint256 maxAmount_,
        uint256 usedAmount_,
        bool pretransferred_,
        address recipient_
    ) internal {
        if (pretransferred_ && maxAmount_ > usedAmount_) {
            uint256 unusedU = _unbookedSurplus(token_);
            uint256 claimedUnused = maxAmount_ - usedAmount_;
            uint256 refund = claimedUnused < unusedU ? claimedUnused : unusedU;
            if (refund > 0) {
                token_.safeTransfer(recipient_, refund);
            }
        }
    }

    /**
     * @notice Burns vault shares (`vaultShare` / `address(this)`) for a pretransfer or pull path.
     * @dev E6 law: when `preTransferred`, burn `burnAmount` from `address(this)` only.
     *      Do **not** sweep leftover `balanceOf(this)` to `owner`. Honest extra / donated
     *      self-shares stay on the vault (absorb), matching token-side unclaimed push surplus.
     *      If `burnAmount` exceeds self-balance, ERC20 burn reverts.
     *      When `!preTransferred`, burn `burnAmount` from `owner`.
     * @param owner Share holder to burn from when `!preTransferred`.
     * @param burnAmount Shares to burn.
     * @param preTransferred When true, burn from `address(this)` (already-held self-shares).
     */
    function _secureSelfBurn(address owner, uint256 burnAmount, bool preTransferred) internal {
        if (preTransferred) {
            ERC20Repo._burn(address(this), burnAmount);
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
    }
}
// end::BasicVaultCommon[]

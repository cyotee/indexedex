// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

// tag::BasicVaultCommon[]
/**
 * @title BasicVaultCommon - Behavior common to call vaults.
 * @author cyotee doge <not_cyotee@proton.me>
 */
contract BasicVaultCommon is ISecurePullErrors {
    using BetterSafeERC20 for IERC20;

    // tag::_secureTokenTransfer(address_uint256_bool)[]
    /**
     * @notice Securely pulls tokens into the vault using balance-delta accounting.
     * @dev Measures `observedDelta = balanceAfter - balanceBefore` over the pull window.
     *      - `!pretransferred`: pulls via ERC20 allowance or Permit2, then returns the
     *        actual inbound delta (fee-on-transfer safe; may be less than claimed).
     *      - `pretransferred`: performs no in-call transfer. Credits exactly `claimed` only
     *        when `claimed <= observedDelta`; otherwise reverts
     *        `TransferDeltaInsufficient(claimed, observedDelta)`. Absolute `balanceOf >= claimed`
     *        without a positive in-window delta is forbidden (blocks free inventory credit / I1).
     *        Surplus delta is not credited (donations must not lock honest deposits; no exact-delta grief).
     * @param tokenIn The token to transfer into the vault.
     * @param amountTokenToDeposit Claimed amount to pull / credit.
     * @param pretransferred When true, no transfer is performed in this call; credit requires
     *        a non-short observed delta in the pull window.
     * @return actualIn Credited amount: claimed when pretransferred and delta-sufficient;
     *         otherwise the observed inbound delta.
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
        internal
        virtual
        returns (uint256 actualIn)
    {
        uint256 balBefore = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            if (tokenIn.allowance(msg.sender, address(this)) < amountTokenToDeposit) {
                Permit2AwareRepo._permit2()
                    .transferFrom(msg.sender, address(this), uint160(amountTokenToDeposit), address(tokenIn));
            } else {
                tokenIn.safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);
            }
        }
        uint256 observedDelta = tokenIn.balanceOf(address(this)) - balBefore;
        if (pretransferred) {
            if (amountTokenToDeposit > observedDelta) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amountTokenToDeposit, observedDelta);
            }
            // Credit exactly claimed; surplus delta is not credited (no exact-delta grief)
            return amountTokenToDeposit;
        }
        // !pretransferred: FoT-safe — return actual inbound delta (may be < amount)
        return observedDelta;
    }

    /**
     * @notice Refunds excess pretransferred tokens back to the caller.
     * @dev Only refunds when pretransferred is true and maxAmount exceeds the amount actually used.
     * @param token_ The token to refund.
     * @param maxAmount_ The maximum amount that was pretransferred.
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
            uint256 refund = maxAmount_ - usedAmount_;
            token_.safeTransfer(recipient_, refund);
        }
    }

    function _secureSelfBurn(address owner, uint256 burnAmount, bool preTransferred) internal {
        if (preTransferred) {
            ERC20Repo._burn(address(this), burnAmount);

            // If excess shares were pretransferred to this vault, refund them back to the owner.
            // This keeps `exchangeOut(..., pretransferred=true)` semantics consistent: only `burnAmount` is consumed.
            uint256 leftoverShares = IERC20(address(this)).balanceOf(address(this));
            if (leftoverShares > 0) {
                IERC20(address(this)).safeTransfer(owner, leftoverShares);
            }
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
    }
}
// end::BasicVaultCommon[]

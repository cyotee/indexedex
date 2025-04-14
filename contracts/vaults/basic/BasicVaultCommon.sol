// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

// tag::BasicVaultCommon[]
/**
 * @title BasicVaultCommon - Behavior common to call vaults.
 * @author cyotee doge <not_cyotee@proton.me>
 */
contract BasicVaultCommon {
    using BetterSafeERC20 for IERC20;

    // tag::_secureTokenTransfer(address_uint256_bool)[]
    /**
     * @notice Securely transfers tokens into the vault, handling pretransfers and fee-on-transfer tokens.
     * @dev Uses balance-delta accounting to return only the amount received in this call,
     *      not the vault's entire held balance. This prevents over-crediting when the vault
     *      holds pre-existing dust or reserve balances.
     * @param tokenIn The token to transfer into the vault.
     * @param amountTokenToDeposit The amount of the token to transfer into the vault.
     * @param pretransferred Boolean indicating if the tokens have already been transferred to the vault.
     * @return actualIn The actual amount of tokens received by the vault (delta, not absolute balance).
     */
    function _secureTokenTransfer(IERC20 tokenIn, uint256 amountTokenToDeposit, bool pretransferred)
        internal
        virtual
        returns (uint256 actualIn)
    {
        if (pretransferred) {
            require(
                tokenIn.balanceOf(address(this)) >= amountTokenToDeposit,
                "BasicVaultCommon: insufficient pretransferred balance"
            );
            return amountTokenToDeposit;
        }

        uint256 balBefore = tokenIn.balanceOf(address(this));

        if (tokenIn.allowance(msg.sender, address(this)) < amountTokenToDeposit) {
            Permit2AwareRepo._permit2()
                .transferFrom(msg.sender, address(this), uint160(amountTokenToDeposit), address(tokenIn));
        } else {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);
        }

        actualIn = tokenIn.balanceOf(address(this)) - balBefore;
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

// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";
import {
    ReceiptBackedERC4626AccountingLib
} from "contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol";

/**
 * @title ERC4626StandardExchangeCommon
 * @notice Shared helpers for generic ERC-4626 SE in/out routes.
 *
 * @dev APEX 2026-09-17 (D6/D15/D22/D31/R14): every residual, dust included, is retained as
 *      booked local reserve for holders; nothing is paid to the fee recipient and exact-input
 *      routes never refund. Under-consumed underlying (capacity or pause) is booked and swept
 *      into the protocol vault by a later investing operation. Under-delivery of amountOut is Slippage.
 *
 * @dev Token-in pull is durable reserve-delta (BasicVault peer / L-DETF-HOST-UPGRADE):
 *      `U = B - R`; `pretransferred=true` is contract-only (D9) and credits exactly `claimed`
 *      iff `claimed <= U`; excess stays uncredited (D28). Exact-out credits `min(U, maxAmountIn)`
 *      and refunds only `credit - used` (D15).
 */
abstract contract ERC4626StandardExchangeCommon is IERC4626StandardExchange {
    using SafeERC20 for IERC20;

    /// @notice Historical dust boundary retained for tests only; no production path pays residual to feeTo (APEX D6).
    uint256 internal constant MAX_DUST_WEI = 10;

    error ZeroAmount();
    error Slippage();
    error UnsupportedRoute();
    error DeadlineExpired();
    error InsufficientDeposit(uint256 required, uint256 actual);
    /// @notice A receipt-denominated payout exceeded the protocol-vault receipts actually held (R14.15).
    error InsufficientReceiptInventory(uint256 required, uint256 held);

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

    /// @dev Generic receipt backing. Expected-hold extras are Stata-only and contribute zero here.
    function _receiptBacking() internal view returns (uint256) {
        return ReceiptBackedERC4626AccountingLib.backingReceiptUnits(protocolVault(), address(this), false);
    }

    /// @dev Spendable booked local underlying: the booked reserve, capped by the held balance.
    ///      Unbooked balance is a pending pretransfer credit and is never spent on a payout.
    function _localUnderlying() internal view returns (uint256) {
        IERC20 underlying = IERC20(_underlying());
        uint256 booked = MultiAssetBasicVaultRepo._reserveOfToken(address(underlying));
        uint256 bal = underlying.balanceOf(address(this));
        return booked < bal ? booked : bal;
    }

    /// @dev R14.15: pay `due` underlying from booked local cash first and withdraw only the
    ///      shortfall from the protocol vault. The vault's own exceeded-max error propagates.
    function _payUnderlyingLocalFirst(IERC4626 vault, uint256 due, address recipient) internal {
        IERC20 underlying = IERC20(_underlying());
        uint256 local = _localUnderlying();
        uint256 fromLocal = due < local ? due : local;
        uint256 shortfall = due - fromLocal;
        if (shortfall > 0) {
            uint256 before_ = underlying.balanceOf(recipient);
            vault.withdraw(shortfall, recipient, address(this));
            if (underlying.balanceOf(recipient) - before_ < shortfall) revert Slippage();
        }
        if (fromLocal > 0) underlying.safeTransfer(recipient, fromLocal);
    }

    /// @dev Convert protocol-vault token delta into SE shares (first depositor 1:1).
    function _convertVaultDeltaToShares(uint256 vaultDelta, uint256 totalVaultBefore)
        internal
        view
        returns (uint256 shares)
    {
        return ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits(
            vaultDelta, totalVaultBefore, ERC20Repo._totalSupply()
        );
    }

    /// @dev Invest previously booked local underlying first, then this caller's credited input.
    function _investCreditedUnderlying(uint256 actualIn) internal {
        IERC4626 vault = protocolVault();
        IERC20 underlying = IERC20(_underlying());
        uint256 capacity = vault.maxDeposit(address(this));
        uint256 booked = MultiAssetBasicVaultRepo._reserveOfToken(address(underlying));
        uint256 sweep = booked < capacity ? booked : capacity;
        if (sweep > 0) {
            underlying.forceApprove(address(vault), sweep);
            vault.deposit(sweep, address(this));
            capacity = vault.maxDeposit(address(this));
        }
        uint256 invest = actualIn < capacity ? actualIn : capacity;
        if (invest > 0) {
            underlying.forceApprove(address(vault), invest);
            vault.deposit(invest, address(this));
        }
    }

    /// @dev Invert: SE shares needed for a receipt-unit amount out (ceil), priced on the full
    ///      local-plus-receipt backing (R14.12/R14.14).
    function _previewSharesForVaultOut(uint256 vaultAmountOut) internal view returns (uint256) {
        return ReceiptBackedERC4626AccountingLib.sharesForWithdraw(
            vaultAmountOut, _receiptBacking(), ERC20Repo._totalSupply()
        );
    }

    /// @dev Pro-rata receipt-unit entitlement for burning `seShares` SE, priced on the full backing.
    function _previewRedeemShares(uint256 seShares) internal view returns (uint256 vaultTokensOut) {
        return ReceiptBackedERC4626AccountingLib.receiptUnitsFromShares(
            seShares, _receiptBacking(), ERC20Repo._totalSupply()
        );
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
        uint256 vaultDelta = ReceiptBackedERC4626AccountingLib.receiptUnitsForMint(
            seOut, _receiptBacking(), ERC20Repo._totalSupply()
        );
        return vault.previewMint(vaultDelta);
    }

    /// @dev Protocol vault tokens in for exact user SE shares (protocolVault → SE exact-out).
    function _previewVaultInForSeOut(uint256 seOut) internal view returns (uint256 vaultIn) {
        return _vaultInForSeOut(seOut, _receiptBacking());
    }

    /// @param backingBefore Receipt-denominated backing before this caller's credit.
    function _vaultInForSeOut(uint256 seOut, uint256 backingBefore) internal view returns (uint256 vaultIn) {
        return ReceiptBackedERC4626AccountingLib.receiptUnitsForMint(seOut, backingBefore, ERC20Repo._totalSupply());
    }

    /// @dev Credit at most the caller's maximum from unbooked payment. Booked
    /// reserve and unclaimed surplus remain backing throughout exact-output minting.
    function _prepaidCredit(IERC20 token, uint256 maximum) internal view returns (uint256) {
        return LocalCreditLib.budget(
            LocalCreditLib.available(
                token.balanceOf(address(this)),
                MultiAssetBasicVaultRepo._reserveOfToken(address(token))
            ),
            maximum
        );
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
     * @dev Durable reserve-delta secure pull (BasicVault peer).
     *      - `R = reserveOfToken` (booked at last money-route sync)
     *      - `B = balanceOf(this)`
     *      - `U = B - R` (unbooked surplus)
     *      - `!pretransferred`: transferFrom; the pull delta must equal the requested amount.
     *        There is no immediate overshoot refund. Push sufficiency is `claimed <= U`, not
     *        equality of the entire surplus.
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
            if (delta != amountIn) {
                revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, delta);
            }
            return amountIn;
        }

        LocalCreditLib.requirePretransferCaller(msg.sender);
        uint256 U = LocalCreditLib.available(B0, R);
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

    function _refundExcess(IERC20 token, address to, uint256 excess) internal {
        if (excess == 0) return;
        token.safeTransfer(to, excess);
    }

    function _refundCreditMinusUsed(IERC20 token, uint256 credit, uint256 used) internal {
        if (credit > used) {
            token.safeTransfer(msg.sender, credit - used);
        }
    }

    function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred) internal {
        uint256 credit;
        if (pretransferred) {
            credit = _prepaidCredit(token, maxAmountIn);
            if (used > credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, credit);
        }
        _securePull(token, used, pretransferred);
        if (pretransferred) _refundCreditMinusUsed(token, credit, used);
    }

    function _burnExactOutShares(uint256 used, uint256 maxAmountIn, bool pretransferred) internal {
        uint256 credit;
        if (pretransferred) {
            credit = _prepaidCredit(IERC20(address(this)), maxAmountIn);
            if (used > credit) revert ISecurePullErrors.TransferDeltaInsufficient(used, credit);
        }
        _burnSeShares(msg.sender, used, pretransferred);
        if (pretransferred) _refundCreditMinusUsed(IERC20(address(this)), credit, used);
    }

    /**
     * @dev Burn SE shares for unwrap / SE→protocolVault routes (L-DETF-SHARE / BasicVault peer).
     *      - `pretransferred=true`: shares were pushed onto this diamond; burn precisely
     *        `burnAmount` from `address(this)`. No leftover self-share sweep or refund to owner.
     *      - `pretransferred=false`: burn precisely `burnAmount` from `owner` (msg.sender holder).
     */
    function _burnSeShares(address owner, uint256 burnAmount, bool pretransferred) internal {
        if (pretransferred) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            uint256 selfBal = IERC20(address(this)).balanceOf(address(this));
            if (burnAmount > selfBal) {
                revert ISecurePullErrors.TransferDeltaInsufficient(burnAmount, selfBal);
            }
            ERC20Repo._burn(address(this), burnAmount);
        } else {
            ERC20Repo._burn(owner, burnAmount);
        }
    }
}

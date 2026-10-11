# Grok — is `maxRedeem` calculating the right share cap?

Reviewer: Grok. Targeted follow-up. No peer answers were read. No code was edited. Context7 did not return an ERC-4626 `maxRedeem` page for this query. The conclusion below is from the current functions, not from an external library quote.

## 1. Is the current formula correct?

**No.**

`maxWithdraw` (`ReceiptBackedERC4626Target.sol:67-71`) is `min(convertToAssets(owner balance), held receipt balance)`. `convertToAssets` is `receiptUnitsFromShares` (`ReceiptBackedERC4626AccountingLib.sol:63-69`): `floor(shares * backing / supply)`.

`maxRedeem` (`ReceiptBackedERC4626Target.sol:74-80`) then does `min(owner balance, convertToShares(that asset cap))`, except it returns 0 when the asset cap is 0 (`:77`). `convertToShares` is `sharesFromReceiptUnits` (`AccountingLib.sol:54-60`): `floor(assets * supply / backing)`.

That is not the inverse of what `redeem` pays. `previewRedeem` (`Target.sol:101-102`) is the same floor as `convertToAssets`. `redeem` (`:162-168`) rejects `shares > maxRedeem(owner)` and then transfers `previewRedeem(shares)` of the receipt token.

Two consequences follow from those lines alone:

- If `previewRedeem(balance) <= held receipts`, the receipt transfer for the full balance would fit. `maxRedeem` still returns `floor(floor(balance * backing / supply) * supply / backing)`, which is less than or equal to the balance and can be strictly less. A deliverable full redeem is then rejected at `:163-164`.
- If the owner's floor entitlement is above held receipts, `floor(heldReceipts * supply / backing)` is a share count whose payout does not exceed held receipts, but it is not the largest such count. Any larger share count with the same floored payout is still payable and is still rejected.
- If the floored entitlement is 0, `:77` returns 0 even when `previewRedeem(balance)` is 0 and a zero receipt transfer would not exceed holdings.

The formula is a conservative lower bound. It is not the maximum share amount `redeem` can pay from held receipts.

## 2. Invariant `maxRedeem` must satisfy

For the owner's balance `b`, held receipt-token balance `r`, and the same backing and supply that `previewRedeem` uses:

- `maxRedeem(owner) <= b`.
- `previewRedeem(maxRedeem(owner)) <= r`.
- `redeem(maxRedeem(owner))` must be able to transfer that preview amount of the receipt token. It must not revert only because the cap is tighter than the receipt balance. Allowance and receiver checks are separate.
- It must be the largest share amount with both properties. If `previewRedeem(s) <= r` and `s <= b`, then `maxRedeem(owner) >= s`.
- In particular, if `previewRedeem(b) <= r`, then `maxRedeem(owner) = b`.
- The bound is held receipt tokens (`Target.sol:70` and the transfer at `:168`), not total backing. Backing includes booked underlying (`AccountingLib.sol:41-51`). Those units are not what `redeem` transfers.

`withdraw` uses `sharesForWithdraw`, which rounds up (`AccountingLib.sol:72-78`). That inverse belongs to `maxWithdraw` / `withdraw`. It must not be reused as `maxRedeem`.

## 3. Is the coordinator's proposed rule the right replacement?

**Yes.** No different calculation is required.

The proposed rule is the invariant in section 2, stated as a procedure:

- If the receipts owed by the owner's full balance are held, return the full balance.
- Otherwise return the largest share amount whose owed receipts do not exceed held receipts.
- Never pay more receipts than the vault holds.

"Owed receipts" must mean `previewRedeem`, the floor `redeem` actually transfers. It must not mean a round-up, and it must not mean `convertToShares(maxWithdraw)`.

A closed form that matches the invariant, when supply and backing are nonzero, is: return the balance when `previewRedeem(balance) <= held receipts`; otherwise return `min(balance, floor(((held receipts + 1) * supply - 1) / backing))`. That is the largest integer `s` with `floor(s * backing / supply) <= held receipts`. When backing is zero, `previewRedeem` is zero, so the rule returns the full balance. The current early return of 0 does not.

This is not an owner-optional rounding preference. Any other share cap either rejects a redeem whose preview fits in held receipts, or allows a preview that the receipt transfer cannot pay.

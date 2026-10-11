# Receipt-backed maxRedeem — Astra

## 1. Is the current formula correct?

**No—not as the calculation of the maximum deliverable share redemption.** It is a conservative cap in the ordinary positive-backing/positive-supply domain, but it needlessly excludes deliverable shares.

`ReceiptBackedERC4626Target.sol:67–71` first converts the owner's shares into receipt units and caps the result by held receipts. Lines **74–80** then convert that already-rounded result back to shares. Both conversions round down: `ReceiptBackedERC4626AccountingLib.sol:54–60` and **63–69**. A floor conversion followed by its floor inverse is not an identity and is not the maximum inverse of the payout function.

Consequently, the cap can be smaller than the owner's balance even when that balance's actual receipt payout is fully payable. This is an executable restriction, not just a conservative informational quote: `ReceiptBackedERC4626Target.sol:162–166` rejects redemptions above that cap before computing their payout. The defect is unnecessary rejection, not evidence that the current cap ordinarily pays more receipts than are held.

## 2. Required invariant

For one unchanged accounting state, define:

- `O`: owner's share balance;
- `H`: actual receipt-token inventory available for payout;
- `P(s)`: `previewRedeem(s)`;
- `M`: `maxRedeem(owner)`.

The receipt-liquidity limit should satisfy:

1. **Ownership and payout safety:** `0 <= M <= O`, and any admitted redemption must have `P(s) <= H`.
2. **Executable consistency:** for valid positive shares within the limit, an authorized caller with a valid receiver must not fail solely because the calculated limit understates receipt liquidity. On success, `redeem(s)` burns `s` and pays `P(s)` from the same pre-settlement state. This does not promise success despite token transfer restrictions or other independent failures.
3. **Maximality:** absent another explicit redemption restriction, `M` is the largest owner-held share amount satisfying the receipt-payout inequality—not the floor conversion of `maxWithdraw` back into shares. If `M < O`, the next share amount must exceed receipt liquidity or violate another explicitly approved restriction.

These relationships follow the actual settlement path: `previewRedeem` delegates to `convertToAssets` at **101–102**, the accounting library floors the receipt payout at **63–69**, and `redeem` uses that preview, burns the shares, and transfers the receipts at **166–168**.

## 3. Is the coordinator's proposed replacement right?

**Yes, for the receipt-liquidity calculation.** Returning the full balance when its actual rounded payout is deliverable, and otherwise selecting the largest share amount whose rounded payout fits held receipts, correctly expresses the inverse problem. No different financial valuation is required. Preserve total backing for pricing and actual held receipts for liquidity; they are different quantities.

The implementation must invert the **rounded payout inequality**. Merely switching the second floor to a ceiling, or substituting `previewWithdraw`, does not generally find its largest satisfying share amount: `sharesForWithdraw` at `ReceiptBackedERC4626AccountingLib.sol:72–78` answers the different question of shares charged for an exact receipt withdrawal. Arithmetic must also avoid intermediate overflow and explicitly handle zero backing/supply rather than blindly divide.

**One policy boundary needs to remain explicit:** current `maxRedeem` returns zero when `capAssets == 0` (**Target:77**). The proposal's literal “largest amount whose owed receipts do not exceed inventory” can admit positive shares whose rounded payout is zero. `redeem` checks nonzero **shares** at **160**, but contains no separate nonzero-asset-output check at **166–168**. Thus applying the proposal without qualification can change the current zero-payout behavior, including at zero receipt inventory.

If preserving the existing zero-payout restriction is intended, retain that restriction consistently in the limit/settlement policy, and apply maximality to otherwise eligible, positive-payout redemptions. If zero-payout burns are intentionally allowed, the proposal's unqualified inequality is the correct liquidity rule, but that behavior change should be explicit. Neither choice justifies the existing double-floor restriction on positive, fully deliverable redemptions.

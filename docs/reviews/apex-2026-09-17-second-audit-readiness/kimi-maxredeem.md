# Kimi K3 — ReceiptBackedERC4626Target.maxRedeem formula analysis

Sources read in current tree: `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`
(full; cited lines 43–55, 62–81, 133–169) and
`contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol` (full; cited lines
54–88). Rounding directions from the library: `sharesFromReceiptUnits` floors (line 60),
`receiptUnitsFromShares` floors (line 69), `sharesForWithdraw` ceils (line 78),
`receiptUnitsForMint` ceils (line 87).

## 1. Is the current formula correct? **No.**

Current chain (`ReceiptBackedERC4626Target.sol`):

- `maxWithdraw(owner)` (67–72) = `min(convertToAssets(bal), heldReceipts)`, where
  `convertToAssets` (50–55) is `receiptUnitsFromShares` — a floor.
- `maxRedeem(owner)` (74–81) = `min(convertToShares(maxWithdraw(owner)), bal)`, where
  `convertToShares` (43–48) is `sharesFromReceiptUnits` — a second floor.
- `redeem` (153–169) enforces that cap (162–165) and pays `previewRedeem(shares)` =
  `convertToAssets(shares)` in held receipts (166–168).

Two distinct defects, both from composing floor ∘ floor instead of inverting the payout
function:

**(a) Full-balance case.** When held receipts cover the owner's whole entitlement,
`maxWithdraw = floor(bal*B/S)` and `maxRedeem = floor(floor(bal*B/S) * S/B) ≤ bal`. The
round trip loses whenever `bal*B/S` is non-integral. The loss is **not bounded at one
share**: when a share is worth many receipt units (B/S large), each lost receipt unit in
the inner floor costs roughly S/B shares in the outer floor. Example shape (B=100, S=3,
bal=2): entitlement floors to 66 receipts; converting 66 back yields 1 share; `redeem(2)`
would pay `previewRedeem(2) = 66` receipts, which are held, yet the cap rejects it. A
deliverable full redemption is rejected.

**(b) Liquidity-limited case.** When `heldReceipts R` is the binding constraint, the cap
is `floor(R*S/B)` (via `sharesFromReceiptUnits`, line 60). But the payout of `s` shares
is `previewRedeem(s) = floor(s*B/S)`, so the true largest redeemable share count is the
largest `s` with `floor(s*B/S) ≤ R`, i.e. `s < (R+1)*S/B`. The formula's `floor(R*S/B)`
is strictly below that bound whenever the inequality has slack. Example shape (B=3, S=2,
R=4): the formula yields 2; the true maximum is 3, since `floor(3*3/2) = 4 ≤ 4`. So even
in the regime the cap exists for, it undercounts redeemable shares.

The formula is **safe in one direction** — it never authorizes a payout above held
receipts (`floor(floor(R*S/B)*B/S) ≤ R`). The defect is over-rejection: unnecessary
`ERC4626ExceededMaxRedeem` reverts (163–165) and stranded shares, consistent with the
Low-severity liveness classification in my cross-review agreement with Astra-04. The
terminal `min(..., bal)` at line 80 does not repair case (a) because the computed cap is
already below `bal`.

## 2. The invariant `maxRedeem` must satisfy

`maxRedeem(owner)` must equal the largest `s ≤ balanceOf(owner)` such that
`previewRedeem(s) ≤ heldReceipts`, where `heldReceipts` is the vault's actual balance of
the receipt asset (the token `redeem` transfers at line 168). Equivalently, three
conjuncts relative to the current code:

1. **Completeness:** if `previewRedeem(balanceOf(owner)) ≤ heldReceipts`, then
   `maxRedeem(owner) == balanceOf(owner)` — a fully deliverable balance is never capped.
2. **Soundness:** `previewRedeem(maxRedeem(owner)) ≤ heldReceipts` — `redeem` at the cap
   can never promise more receipts than the vault holds, so the transfer at line 168
   cannot fail for lack of inventory.
3. **Maximality:** no `s` with `maxRedeem(owner) < s ≤ balanceOf(owner)` satisfies
   `previewRedeem(s) ≤ heldReceipts` — the cap rejects only redemptions that genuinely
   exceed deliverable receipts.

Two consistency requirements follow from the surrounding code: the cap must be computed
against the **same** `previewRedeem`/`convertToAssets` floor used by `redeem` (lines
101–103, 166), not a different rounding path; and the asset-side pair
(`maxWithdraw` at 67–72 with `withdraw` at 133–151) must stay coherent — it currently is,
because `withdraw` pays exactly `assets` and `previewWithdraw` ceils (AccountingLib line
78), so no change is needed there. Edge cases the invariant must cover: `supply == 0`
(balance is 0, cap 0); `backing == 0` with `supply > 0` (owed receipts are 0, so the full
balance is trivially within inventory).

## 3. Is the coordinator's proposed rule the right replacement?

**Yes — the proposed rule is exactly the invariant of section 2, and it is the correct
replacement semantically.** "If the receipts owed by the owner's full balance are held,
return the full balance" is conjunct 1; "otherwise return the largest share amount whose
owed receipts do not exceed held receipts" is conjuncts 2 and 3; "never pay more receipts
than the vault holds" is the soundness property the current formula already has and must
keep.

One implementation caveat, stated as the invariant rather than a recipe: the "largest
share amount whose owed receipts do not exceed held receipts" must be computed as the
**exact inverse of the `previewRedeem` floor** — the largest `s` satisfying
`floor(s*B/S) ≤ R` (equivalently `s < (R+1)*S/B`) — and **not** by reusing
`sharesFromReceiptUnits(R, B, S)` = `floor(R*S/B)`, which is the undercounting step in
today's formula (defect b). Reusing the deposit-side helper would reintroduce the same
rounding loss the rule is meant to remove. The full-balance branch should be a direct
comparison of `previewRedeem(bal)` against held receipts, not the current
floor-then-floor round trip.

Acceptance tests should pin, for both dispatched families (generic ERC-4626 SE and Stata,
per D45): a non-integral-ratio full-balance redeem that is deliverable and must succeed;
a redeem above actual receipt inventory that must still revert
`ERC4626ExceededMaxRedeem`; and the boundary where `previewRedeem(s) == R` exactly, in
both the share-heavy and receipt-heavy ratio regimes, since defect (b) lives there.

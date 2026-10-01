# Grok original — pre-maturity wrapper principal reinvestment

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| PRD | **v0.25** §§10, 12.2–12.4, H01–H03; tracker v0.25 NN-02 |
| Scope | Do **not** reopen: holder isolation, R41 no-bonus, atomic installment funding, excess-as-same-NFT-principal (prior), purchase-epoch storage. |

---

## 1. Accepted this round (process)

**Dedicated reinvestment of already-funded wrapper principal is allowed while the original native note is still maturing.**

Prerequisites (keep):

- Some native vest was **already** atomically collected → Keep-YT → mint/stake as **this NFT’s** principal.
- Burn **only requested actual funded principal** (incentive-free owned-reserve quote, `quoteInput = actualDetfIn`, R41).
- Output is a **NEW bond** with **that destination type’s typical lock** (Pendle-cliff fresh bond, next-epoch elected, etc.). **Do not invent numeric durations.**
- **Old native note, old wrapping NFT, old holder stay.** No native transfer/cancel/second intended `deposit` on that holder.
- Remainder of funded principal, **early funded rewards**, and **future** native installments stay on the **old** tokenId.
- Fully matured **and emptied** NFT is claimed/retired **separately** (H03 path).
- **Purchase-epoch-passed** stays **distinct** from **full-collection epoch**. User: lock-by-type eligibility **later**; do not silently settle C05.

Prior: excess native proceeds **credit same NFT principal**; store **purchase epoch** from exposed NetNet **processed** counter; **unlock epoch `0` = assigned Pendle maturity sentinel**, **not** “pending” or “fully collected.”

---

## 2. Contradiction with v0.25 (must correct)

v0.25 **conflates two operations** under one gate:

| Text | Conflict |
| --- | --- |
| §10 row: wrapper principal claim/**reinvestment** gated by **full intended-note collection + next processed epoch** | User now allows **reinvestment before** full native collection |
| §10.615–617; O03; tracker §2: native maturity **alone** insufficient; **full collection + next epoch** for release | Mixes **wallet/principal withdrawal & retirement** with **dedicated reinvest** |
| §12.4:849: principal claim/reinvestment **after full collection and next epoch**; “later eligible principal reinvestment follows R41” | R41 is right **mechanics**; **eligibility** must **not** require full collection |
| H02: wait until registered note `claimed == payout` **then** later epoch | That wait belongs to **final principal withdrawal / empty retirement**, **not** to pre-maturity reinvest |
| C08/§12.3:823: blocked native `redeem` **also locks already-funded principal** | True for **final drain**; **false** for burning **already-staked** principal into a **new** bond while the note still vests |

**Correction (do not reopen isolation):** split **A** vs **B**.

- **A — Pre-maturity dedicated reinvestment (SELECTED now):** needs **actual funded principal > 0** on the old NFT (from prior successful installments). Does **not** require `claimed == payout` on the native note. Does **not** consume future vest. Does **not** move the holder.
- **B — Final principal withdrawal / retirement:** still needs **full intended-note collection** (H02) **plus** whatever remaining funded principal is left; then empty NFT can retire. Blocked `redeem` can still strand **uncollected native** and **un-reinvested** leftover principal.

**PurchaseEpoch vs fullCollectionEpoch vs unlock:** three fields.

| Field | Meaning | `0` means |
| --- | --- | --- |
| `purchaseEpoch` | NetNet **processed** counter at intended native purchase | **never** “unlocked”; 0 only if counter was 0 |
| `fullCollectionEpoch` | Processed epoch **after** intended note `claimed == payout` **and** last installment contributed | **not yet fully collected** |
| `unlockEpoch` | Destination-bond / Pendle cliff sentinel | **`0` = assigned Pendle maturity** (user), **not** pending/full-collected |

**Purchase-epoch-passed** (e.g. installment/reinvest after purchase epoch) **≠** `fullCollectionEpoch` set. Do not overload `0`.

---

## 3. Spec (preserve selected process)

- **tokenId:** **old** keeps holder + remaining principal/rewards/future NET. **New** bond = **new tokenId** (typical lock of **requested destination type**). User said NEW bond; do not reuse old holder for a second **native** purchase (H03).
- **Partial vs all current principal:** either **requested amount** or all **currently funded** principal; **future** native proceeds **always** remain old.
- **Rewards:** claimable on **old** under existing early-reward rules; reinvest **does not** seize unclaimed rewards unless separately claimed.
- **Backing:** debit **only this position’s** internal shares / held DETF (R41/§10.2); floor rounding; **actual** `balanceOf`/shares, **not** projected unminted expansion.
- **Quote:** discovery-supported output asset only; owned-reserve burn; **no** contraction bonus on nested steps.
- **Atomic:** fail → restore old principal/claims, no new bond, native note untouched.
- **H01:** excess already **same-NFT principal** (prior); reinvest burns that principal like any other funded amount. Late gifts after reinvest still **old** holder/NFT.

---

## 4. Remaining lock questions (not numeric defaults)

1. **Destination lock table later** (user): Pendle-cliff vs next-epoch vs wrapper-B. Don’t pick hours.
2. May **A** run **before** purchase-epoch-passed if installments already funded? User: keep that check **distinct** — **do not drop it** unless they say so.
3. After **A** empties current principal but native **still vesting**, old NFT is **not** retired (future proceeds). Retirement only when **B** (matured + emptied).
4. C05: new bond’s duration vs oracle min — still OPEN.

---

## 5. Proposed PRD wording

§10 wrapper row: **two gates** — (A) funded-principal **reinvest** while native matures, R41, **new** bond; (B) **withdraw/retire** after **fullCollectionEpoch** + rules in H02.

§12.4: “Do **not** require full native collection for (A). Do **not** treat (A) as completing H02.” Three epoch fields as table above.

H03: old tokenId **persists** until B; new bond **new** tokenId; no second intended native buy on old holder.

---

## Limits

No implementation. Confidence **high** that v0.25 over-gated (A) with (B); **none** on lock numbers. C08 residual scan **unchanged**.

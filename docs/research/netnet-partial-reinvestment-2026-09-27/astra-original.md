# Astra — partial wrapped-bond reinvestment ORIGINAL

2026-09-27. Independent bounded pass; prior session retained, no new-round peer artifacts read. Routing label `openai/gpt-6-astra`, not provider attestation. Current PRD inspected: v0.25.

## Accepted process: two positions, not a native-note rollover

**Reinvest already-funded DETF principal while the original native bond is still maturing.** The original native note, holder and wrapping NFT remain intact. Only the requested amount of principal previously collected, contributed, minted and staked is consumed. The incentive-free owned-reserve burn realizes a supported asset, which purchases a **new destination bond** with its own normal type-specific lock.

The old tokenId retains unreinvested principal, its remaining funded rewards and future native-note proceeds. Later native installments—including attributable excess now selected for same-NFT principal credit—continue funding that old tokenId. The destination bond has a separate identity/new tokenId where its bond interface uses NFTs. Reinvesting all current principal is **not** closure of the still-maturing old native position. No transfer/cancel of the native note, second intended purchase on the old holder, purchaser-based rights or automatic old-NFT retirement is selected.

## Exact current text needing reconciliation

The latest instruction supersedes v0.25's blanket **full-collection prerequisite for reinvestment**, not every withdrawal/lock rule:

- PRD `25`, R19 at `165`, §10 row `610`, §12.2 `797`, and §12.4 `849` tie claim **and reinvestment** to full collection plus another processed epoch. Split the two operations; that prerequisite must not bar the newly selected pre-maturity dedicated reinvestment.
- §10.1 `623,626` and §10.2 `648` say preserve existing lock eligibility and use the income-reinvestment release rule. Add the explicit wrapped-principal reinvestment exception and **destination-type lock**; do not let generic wording silently reintroduce full collection or impose one universal next-epoch destination lock.
- H01 `857` and tracker `86` still ask whether excess funds the same NFT: that destination is now answered. Keep only late-excess timing/donation classification issues not yet resolved.
- H03 `859` and tracker `88` retain replacement-identity ambiguity. Record **old position retained/new bond created**; retirement and late-gift terminal handling remain distinct.
- Reconcile R/O/A cross-references, especially O03 `885`, A08 `932`, and tracker `31,81,96`. They must distinguish final principal withdrawal/retirement from this principal-to-new-bond operation.

These are contradictions with the **new instruction**, not evidence v0.25 was internally inconsistent when written. Existing authorization, funding, settlement and user-limit checks survive.

## Separate epoch meanings

Keep three semantic fields—not necessarily a prescribed storage layout:

| Field | Meaning |
| --- | --- |
| `purchaseEpoch` | Processed NetNet counter recorded for the old purchase; its purchase-epoch-passed check is independent of completion. |
| `fullCollectionEpoch` | Checkpoint for successful full collection/contribution of the **intended** native note; separate completion-validity state is required. |
| `unlockEpoch` | Type-specific epoch release field; **0 means assigned Pendle maturity**, not “unlocked,” “pending,” or “fully collected.” |

`lib/crane/contracts/protocols/pol/net/src/interfaces/IStaking.sol:27–35` exposes `epoch().number`; `src/Staking.sol:134–150` increments it upon processing. Use that configured counter, not elapsed-time arithmetic. Do not alias purchase and completion markers or infer missing completion from `unlockEpoch==0`.

The user retains the purchase-epoch check but defers lock-by-type review. Specify its exact snapshot/evaluation ordering and the destination-type lock table later; do not claim purchase-epoch passage alone settles every eligibility condition. Full native collection is explicitly **not necessary for this reinvestment**.

## Accounting and acceptance obligations

At one settled snapshot let `P` be the old position's remaining actually funded principal and `q` the requested principal input. Enforce `q <= P`; pool/staking balances belonging to other positions, uncollected native NET and projected rewards cannot fund q.

Retire only the old position's corresponding staking shares/backing and burn actual q. Apply `quoteInput=q` at every peg regime, with no contraction bonus. Route realized assets internally into a discovery-supported destination bond accepting that asset; discovery on only one leg is insufficient. Preserve normal bond calculations/fees and enforce end-to-end limits. The newly funded principal need not equal q.

For P=100 and q=40, old principal becomes 60; its remaining rewards and future receipts stay old. For q=100, current principal becomes zero, **not native completion**. Specify native-unit share rounding and position-local dust so debits cannot eat others' backing or silently consume old rewards. Early funded reward claims remain separately available. Failure anywhere restores old shares/principal/backing, burn, reserve changes, markers and new-bond issuance atomically.

## Proposed wording — UNAPPROVED drafting

> Dedicated wrapped-native-bond reinvestment may operate before native maturity/full collection using only requested already-contributed, minted and staked principal. Preserve the purchase-epoch check and other applicable checks independently of final-release/completion rules; lock-by-type details remain separately reviewed. Burn actual requested principal with no contraction incentive, realize a supported reinvestment asset and fund a new bond under that destination type's normal lock. Retain the original tokenId, holder, native note, remaining principal/rewards and future proceeds; zero current principal alone does not retire them. Keep purchase, full-collection and unlock-epoch meanings distinct, with unlock epoch zero reserved for assigned Pendle maturity. The entire conversion reverts on failure.

No process re-approval is needed. Remaining checkpoints are exact epoch/check ordering, type-specific locks/final withdrawal conditions, and terminal late-gift/retirement treatment—not whether pre-maturity reinvestment exists. High confidence in this reconciliation; no rounding implementation or execution proof claimed. Current CLAUDE and canonical Crane architecture/NetNet plus local adversarial guidance read directly. No external API claims required lookup. No shell/RPC/tests/browser/code/config/delegation or read failures; only this report written.

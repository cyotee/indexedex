# Grok original — NN-02 external-note custody / claim liveness

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| Scope | **NN-02 / C08 / A09 only.** No NN-03+ solutions. No PRD edit. |
| Reads | PRD §§12, 14 C08, A09/A30; tracker NN-02; `CLAUDE.md`; local `indexedex-adversarial-testing` header. |
| Failed reads | `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol`, `.../interfaces/IBondDepository.sol`, `.../Constants.sol` → `RC_UNAVAILABLE`. **Not retried.** Interface below is **PRD-documented**, not this-pass source verification. |
| Context7 | Unused (local ABI analysis; no new external library claim). |
| NN-01 | Tracker: Pendle factory/router constants added; **LIVE checks still open.** Does not close vest 2d vs 5d or depository bytecode. |

**UNAPPROVED** wording at the end is a proposal only.

---

## 1. Plain English

NetNet primary bonds are **notes on an address**, not NFTs. Anyone can `deposit(..., to)` and attach a note to **any** `to`. The only documented redeem is **“pay everything currently vested across all notes of `msg.sender`.”** There is **no** per-note redeem, transfer, or callback.

This family wants an NFT to **exclusively** own those notes and, in one transaction, redeem vested NET → Keep-YT → mint/stake. So the NFT (or its escrow) **is** `to` / `msg.sender` for native redeem.

The grief: an attacker (or the user’s own history) can make that address’s note list arbitrarily long. Redeem then does work **proportional to list length**, including notes that already paid out or pay zero this call, if the implementation walks the whole array (PRD §12.3; tracker: include third-party appends **and** fully claimed history). Happy-path harvests do not prove a bound (A09).

Two different statements:

| Kind | Meaning |
| --- | --- |
| **Gas-unbounded** | No wrapper-enforced cap on how many notes `redeem` must visit. |
| **Economically costly** | Each unsolicited note still requires a real `deposit` (USDG or LP, `maxPriceWad`). Cost may deter spam; it is **not** a gas bound until min size × loop gas is measured against the chain limit. |

C08: if no bounded design exists on the **actual** ABI without scope/upstream change, **return to the owner** before planning the route as executable. Labeling “escrow” is not a solution (C08, tracker:81).

---

## 2. What is already selected (do not reopen)

- External purchase from DETF-out / eligible contraction is a **product route** (R12/R44).
- NFT exclusive control; **not** notes deposited to the user’s wallet (PRD:788).
- Atomic collect → Keep-YT → mint/stake; failed harvest leaves NET **unclaimed in the depository** (PRD:773, 806).
- NFT transferable as **wrapper control**, not a native note transfer (PRD:804).
- No invented upstream selector (PRD:811).

---

## 3. Wrapper-only options vs the documented ABI

Evaluated **without inventing** `redeem(noteId)`, prune, `onDeposit` callback, or batch-subset APIs.

| Idea | Bounds `redeem` against third-party `deposit(..., escrow)`? |
| --- | --- |
| **Per-note / per-NFT escrow** | Isolates **which** list is long. Attacker still appends to **that** `to`. PRD:810 already: separate escrows do **not** inherently prevent this. |
| **CREATE2 precomputed `to`** | Same list once the address is known. Front-running the predicted address can **pre-load** notes before first wrap. Worse, not better. |
| **Wrapper-side cap** on *our* deposits | Stops honest over-buying. Does **not** stop `deposit(..., escrow)` from others. Tracker: not a solution by itself. |
| **Frequent claims** | Shrinks vested **amounts**, not array **length**, if claimed notes stay in the walk. |
| **User “gifting” notes away** | No transfer selector. Only `deposit` to another `to` (the attack) or full `redeem` (the expensive walk). |
| **Hypothetical batching layer** | Wrapper cannot add missing per-note/batch redeem (PRD:810). Calling `redeem(escrow)` once still scans **all** notes of that sender. |
| **Min payout / epoch capacity** | May raise attacker **USDG/LP** cost (quantified **if** LIVE min/cap known). Does not cap iterations. NN-01 has not verified deployed vest/min. |

**Can any wrapper-only design actually bound work without upstream changes?**

On the **PRD-stated** ABI: **no enforceable gas bound.** Exclusive NFT custody **requires** a durable `to` that anyone can append to; the only redeem is all-notes-of-sender. That is **incompatibility of selected custody + atomic harvest with this interface**, not a theorem that no DeFi wrapper can ever work.

Not proven here (source unread): whether deployed code **prunes** fully paid notes, skips cheaply, or has a hidden per-note path. If LIVE bytecode **differs**, NN-01 must record it; then this analysis is revised. Until then, plan as **full-array walk, append-only**.

**Quantified feasibility (conditional, not a close):** if each dust note still needs a full bond payment at NAV floor (mechanism docs), spam costs real USDG/LP. Without `Constants`/LIVE min amount and gas-per-iteration, **do not** treat “bonds cost money” as C08 closure.

---

## 4. Conditional designs (not owner picks)

1. **Keep the route, document residual grief (needs owner).** Spec: redeem is O(n) including claimed/zero; unsolicited notes allowed by upstream; harvest reverts if native `redeem` OOGs; no partial native payout (atomic rule). Publish attacker-cost model after LIVE min deposit + loop gas. **Does not “prove a bound”** (A09); it **accepts** unbounded n with explicit failure.

2. **Descope external-bond wrapper** until upstream offers per-note/paginated redeem or a reject callback. Rest of family proceeds. Matches C08 “return to owner before planning that feature as executable.”

3. **If NN-01 LIVE shows prune-on-full-claim or per-note redeem:** rewrite this item; those would be **source** changes relative to the PRD snapshot, not wrapper invention.

Do **not** ship CREATE2-per-note as if it closed C08.

Vest 2d vs 5d is **NN-01 LIVE**, not an NN-02 bound.

---

## 5. Narrow checkpoint

Ask **one** question:

> Given the documented ABI (`deposit` to arbitrary `to`; `redeem` = all notes of sender; no per-note API), no wrapper-only design **enforces** a gas bound on unsolicited + historical notes. **(A)** Descope the external-note route until upstream ABI or LIVE code shows a bound, or **(B)** keep the route and accept O(n) redeem / OOG harvest as specified residual risk, with LIVE min-deposit economics recorded later?  
> Not asked: family re-approval, inventing `redeem(noteId)`, or closing NN-01.

---

## 6. UNAPPROVED PRD clause (optional)

*Not operative.*

> **C08 / NN-02 (draft).** Native notes are address-indexed. `deposit(..., to)` may append to any `to`. Documented `redeem` walks all notes of `msg.sender`; the wrapper cannot add per-note, prune, or reject callbacks. Per-escrow CREATE2, local caps, frequent claims, and batching **do not** by themselves bound third-party appends plus claimed history. Exclusive NFT custody therefore has **no wrapper-enforced gas bound** on this ABI. Specification authors shall not invent upstream selectors. Until LIVE depository bytecode shows a tighter walk/prune, the owner must either **descope** this route or **explicitly accept** O(n) redeem and harvest OOG as residual, without treating that acceptance as a proven bound (A09).

---

## 7. Limits

Crane depository/interface/Constants unread this pass. Confidence **high** on PRD ABI vs wrapper-only bound; **none** on deployed loop/prune/min size. Constants edit ≠ NN-01 LIVE close.

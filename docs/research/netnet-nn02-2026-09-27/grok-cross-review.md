# Grok NN-02 cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi originals. No peer cross-reviews. |
| Date | 2026-09-27 |

Grok original did **not** read Crane depository files (`RC_UNAVAILABLE`). Peer line numbers are untrusted; they **agree** with each other and with PRD §12 on the ABI shape.

---

## Source-consistent facts (three-peer overlap)

- `deposit(..., to)` appends to `notes[to]`; no consent, cap, or callback.
- `redeem` / `pendingFor` walk **all** notes of `msg.sender`. Zero-claimable entries are skipped **after a visit**; **length is not pruned or reset**.
- Epoch cap is **payout value**, not note count. `amount != 0` can still yield **zero payout** (floor). Vest 2d code vs 5d prose is NN-01 LIVE.
- No per-note / range / transfer selector in the inspected ABI. Do **not** invent one.

`noteCount` and `notes(account,i)` / returned `noteId` (Astra, Kimi) can bound **wrapper bookkeeping** of *our* purchases. That does **not** bound or split the upstream scan, and does **not** solve unsolicited **provenance**.

---

## Challenged proposals

**Does `redeem(to)` sweep “excess” or shrink the array?**  
No. Peers: `to` is payout **recipient**; notes scanned are always `msg.sender`’s. MiniMax `redeem(to=feeSink)` on “excess” would pay **all currently claimable** of the wrapper (including **authorized** notes) to the sink, or still walk the full list. MiniMax “MAX_REDEEM_NOTES … **resets on sweep**” has **no source**. Reject.

**Must the NFT contract itself be `to`?**  
No. Notes are keyed by **address**. A **NFT-controlled escrow** can be `to` (Astra isolation; Kimi CREATE3). MiniMax (A) “singleton depository ⇒ cannot precompute escrows” is **false**. PRD requires exclusive **control**, not that `address(nft)` equals the note owner. Escrows **contain** grief per position; they do **not** stop appends to **that** `to` (PRD:810). CREATE2 **prediction** enables **pre-load** (Astra, Kimi, Grok).

**Nonzero gifts ⇒ irrational attacker?**  
No. Nonzero notes **donate NET** (Kimi) but still **lengthen** every future scan. Dust/zero-payout notes can be **cheap** (Astra: positive payment, zero mint). Mixing both is rational if the goal is DOS, not theft. “Attack costs money” is **not** C08 closure (Astra, Grok).

**Cadence / caps / frequent claims guarantee completion?**  
No. They shape **when** scans happen. Terminal `redeem` is still O(n) including claimed history. Local purchase caps do not bind third-party appends (tracker:81). Inactivity or delayed final claim can still hit an OOG wall (Astra).

**Are gas, slot counts, N\* established?**  
**No.** Kimi: “few hundred warm gas,” “3 slots,” analytic N\*. MiniMax: “few hundred thousand gas.” **Unmeasured.** Do not treat as evidence. Measurement is NN-18 **after** a design, not a bound today.

**Unsolicited proceeds = `feeTo()` sweep?**  
**Not owner-selected.** MiniMax P1/G/§12.4 invents gift→`feeTo` and never-reinvest-gifts. That can **steal** mixed legitimate vest if `redeem` is all-or-nothing, and **conflates** fee routing (§13) with note attribution. Astra: aggregate NET may include other maturities; do **not** auto-grant the registered note’s release or mint new NFT rights from arbitrary gifts. Provenance remains **unspecified**.

**Invented upstream / automatic close**  
MiniMax P4 `redeemNote` / `redeemUpTo` — record as **unavailable**, not a plan step. MiniMax checkpoint + Grok original **A/B binary** (descope vs accept O(n)) **forces risk/scope without investigation**. **Withdraw Grok binary.** Astra’s order is right: **quantify residual first; NN-02 stays OPEN**; owner only after a written envelope **or** explicit deferral — not auto-descope, not auto-accept.

---

## What to keep

- Exclusive NFT **control** + atomic harvest; no raw-NET escape.
- Per-position **controlled** escrow as **containment**, not a bound.
- Own-note **index recording** for accounting/views (Kimi/Astra). Do **not** infer collection liveness or gift provenance from it.
- Distinguish **gas-unbounded scan** vs **costly spam**. Economic model needs LIVE min payment + measured loop gas — **not done**.
- Constants edit ≠ NN-01 LIVE ≠ depository bytecode.

---

## Genuine dissent

| Item | Split | Grok |
| --- | --- | --- |
| Close via owner “economic attestation” + sweep | MiniMax yes | **No** — attestation ≠ bound (A09); sweep ABI-inconsistent |
| Close via N\* + cadence + residual accept | Kimi candidate | Residual **may** be asked **after** measurement; not established now |
| Quantify then ask | Astra | **Adopt** |
| Wrapper-only gas bound | All: no enforceable cap | Hold |

---

## Recommended checkpoint (not a decision)

> Do **not** descope or accept residual yet. Direct the specification author to: (1) custody = NFT-controlled escrow vs NFT-as-`to` (control, not extra product NFT); (2) own-note index bookkeeping **without** claiming redeem is bounded; (3) **attribution rule for unsolicited NET** as a **later owner question** if gifts can mix with authorized vest — **not** `feeTo` by default; (4) measure/derive redeem gas vs n **before** any N\* or “safe spam cost.” Keep NN-02 OPEN. Invent no selector.

**UNAPPROVED (narrow):** Closure needs an **enforceable** workload bound **or** an owner disposition **after** quantified residual (including zero-payout and claimed history). Escrow, caps, cadence, gift-as-donation, and bookkeeping are not that bound. `redeem` does not prune or selectively sweep. Source ≠ deployed.

Confidence: **high** on no-prune / no-selective-redeem if peer source reads hold; **none** on N\*, gas, or LIVE bytecode. Grok original over-forced the binary — corrected here.

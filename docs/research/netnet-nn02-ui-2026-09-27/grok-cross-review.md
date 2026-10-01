# Grok NN-02 UI cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Extra fetch | `https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi` (2026-09-27) |
| Date | 2026-09-27 |

---

## What Sourcify actually is

This turn’s ABI fetch: `creationMatch`/`runtimeMatch` **`exact_match`**, `verifiedAt` **2026-07-16T20:34:17Z**, `matchId` **42442631**. Writes: **`redeem(address to)`** only. Reads: `notes(address,uint256)`, `noteCount`, `pendingFor`. Events: `BondCreated`, `BondRedeemed(depositor, noteId, payout)`. **No** `redeemNote` / range / batch.

That is a **verification-service record** from July 16, not:

- a 2026-09-27 **self-measured** runtime codehash,
- a **diff** of that compilation vs today’s Crane tree (VENDOR dump **2026-08-28**; files can have been edited),
- proof the **app** calls `redeem`.

Kimi: “local source ≡ deployed” and “code cannot have changed (no proxy).” **Too strong.** Exact-match attests *that* compile vs *then* bytecode. It does **not** freeze the chain forever or certify the **current** worktree. Astra is right: attestation ≠ own block-pinned measurement; no full bytecode diff.

**NN-01 increment:** record BondDepository as **Sourcify exact_match ABI, 2026-07-16**, plus vendor/PRD 2-day **compilation** evidence (Astra/Kimi Constants in that record). **Not** “all LIVE checks closed.” Vesting **on-chain now** still wants an observation if NN-01 requires current state, not July metadata.

---

## ABI ≠ frontend handler

Grok original: bundle not decoded. Astra: fragments `Ae("rwaDesk")`, `TooManyNotes` / “Redeem some first”, `PayoutBelowMinimum` “0.01 NET”, `Ae("assetBondDesk")` — **other desks**, **not** in BondDepository ABI. Astra **refuses** `redeem(connectedWallet)` inference.

Kimi: bundle has `0xff32a969`, `noteCount`, `pendingFor`, `"redeem"` strings, **no** `redeemNote`; therefore UI **must** write `redeem`. **Reject.** ABI completeness of **one** contract does not prove the Claim button’s `to`/`data`. Could be RWA/PackDesk, a helper, or multicall. **Handler remains unextracted.** `BondRedeemed.noteId` is **log display**, not a selective write.

MiniMax did not obtain Sourcify ABI; Blockscout HTML only.

---

## Superstore / RWA pagination vs selected depository

Docs: PackDesk “**paginated redeem**” + “same plumbing as RWA”; RWA ledger “alongside standard bonds.”

**Do not import into PkgArgs BondDepository.** MiniMax: no `paginated` in vendored Solidity. Astra: mixed ledger may hit **another** target. Pagination may be real on **desks**, UI-only, or unverified. **NN-02 for this family stays the standard depository.** Desk pagination, if real, is a **separate** product — still not audited here (MiniMax: no desk source in tree).

Genesis `claim()` scalars; Inverse swap; TURBO ERC-1155: **not** this array (all three peers). Correct Grok’s “all NetNet bonds” overbreadth (already corrected in Grok UI original).

---

## Rejected assertions

| Claim | Why |
| --- | --- |
| Typical **1–2 notes** (MiniMax) | Unmeasured. |
| Gifts harmless / ignore dust (Kimi retail) | Nonzero still grows **n**; dust/zero-payout still visits. Wrapper **cannot** ignore if harvest is mandatory. |
| `pendingFor` unlimited / **free** (MiniMax R3) | Off-chain `eth_call` is not a **tx** bound; nodes can still fail huge views. Not a liveness proof. |
| Exact UI call without extraction (Kimi) | See ABI≠handler. |
| Immutable never-changes (Kimi) | No proxy ≠ eternal; no current hash check. |
| “Few hundred thousand gas” (MiniMax) | Unmeasured. |

---

## Users vs wrapper (risk, not outage)

**No observed outage.** Ordinary EOAs **share the same `redeem` walk** if they use BondDepository; **n** unmeasured. Wrapper adds **atomic Keep-YT budget**, **durable/predictable `to`**, **must claim**. Concentration is a **design risk**, not a reported incident.

---

## Remaining UI gap

**No exact handler found.** Need readable claim-button encoding (target, `redeem(to)` vs desk page). Until then: **assume no selective BondDepository write**; **do not** assume the SPA’s Claim is that write.

NN-02 **stays OPEN** (quantify / provenance). NN-01 may **add** Sourcify ABI + 2-day **compilation** row, not close LIVE.

Confidence: **high** Sourcify ABI has only aggregate `redeem`; **medium** vendor matches that behavior; **low** on app calldata; **none** on typical n, gas, or outage.

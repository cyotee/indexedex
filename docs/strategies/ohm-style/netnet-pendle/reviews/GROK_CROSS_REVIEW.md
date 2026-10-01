# Grok — cross-review of Astra/MiniMax initial-PRD reviews

- Reviewer: Grok (`xai/grok-4.6`)
- Inputs: Astra and MiniMax **original saved** first-pass reviews (untrusted). Initial PRD not edited.
- Date: 2026-09-21

**Verdict:** Keep **(a) reviewable consolidated draft**. **Not (b) frozen.** Grok first-pass stands. Unauthorized.

## Tax / exemption
**Reject MiniMax #1** (“both FoT carve-out **and** NetNet whitelist required”). User **accepts tax**; design **does not depend** on exemption (`INITIAL` §8). Policy revision (O01) is **IndexedEx law**, **not** a NetNet whitelist gate. **Accept MiniMax #2 as optional:** third-party V2 LP remains taxed; DETF SE uses **live per-hop** getters.

## Epoch
**Reject MiniMax #3** (keep D50 **plus** a second clock). **NET `epoch()` sync is selected** (`R08`, §9). Do **not** re-anchor silently **or** dual-clock. **Accept Astra #4 optional:** testable markers; queued `distribute` vs `nextReward()`.

## External note → common backing / NFT
**Accept Astra #1 (must):** before reentry, notes/pending NET = **exclusive NFT**; after **actual** DETF contribution, strategy assets = **common backing**; NFT exclusive on **locked DETF/sDETF**—**not** both exclude assets **and** issue common DETF, **not** a second liability on the same DETF.

**Accept Astra #2 (must-spec, not owner freeze):** one snapshot per composed tx; settle claims before ownership change; unsolicited notes **not** next depositor.

**Accept Astra #3 / MiniMax #4:** O08 **product** (NFT transfer, fail policy) vs **engineering** (aggregate `redeem`, no magic wrapper). Keep `:192` strong.

## Other
**Accept Grok prior musts:** NET/USDG pair vs sNET **route** ban; bond-only **OPEN**; lock **release OPEN**; hook **OPEN**; O01 before code.

**Optional only:** MiniMax #5–9 (transition-quote **candidate**, not proven required surface; route/rollover lists already in §5/§11). **Reject** inventing extra owner IDs.

**Owner:** O01 FoT; O03 locks; O02 primary/bond-only; O04 hook; O05 expansion **on NET sync**. **Engineering:** tax Zap; facades; note liveness; roll atomicity.

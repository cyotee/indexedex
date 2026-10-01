# Kimi K3 — ORIGINAL: L1 finite B/U principal representation — NetNet/Pendle production patterns and candidate algorithm

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Plan v0.2 §9/L1 only. Actively sought the reusable production solution rather than defending prior counterexamples. Research only; no execution/delegation; no current-round peers. |
| Sources (direct reads, 2026-09-27) | `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol` (full, 138 lines); `.../src/perp/WrappedStakedNET.sol` (full, 122 lines — **corrected path, confirmed**); `Staking.sol:120–160`; plan v0.2 §9 (:404–431) and L1 row (:75); PRD v0.30 §10.2; Pendle SY docs (fetched earlier this session); Pendle SY template tree listing. |

## 1. How NetNet actually solves it — three distinct mechanisms, exact promises

### 1a. StakedNET (explicit rebasing gons, pre-minted inventory)

`StakedNET.sol`: TOTAL_GONS fixed at `2^256 − (2^256 mod 5e18)` (:25–27); `gonsPerFragment = TOTAL_GONS / _totalSupply` (:40, recomputed only on rebase :97); `balanceOf = _gonBalances[account] / gonsPerFragment` (:58–60).

- **Issuance/debit:** stake/unstake/transfer move gons by **exact integer multiplication** — `gons = value * gonsPerFragment` (:129), never a division at transfer time, so there is **zero per-transfer rounding**. Overflow is impossible by construction: transferred amount ≤ `_totalSupply` (inventory-bounded) and `supply × gonsPerFragment = TOTAL_GONS < 2^256`.
- **Rebase (reward):** `rebaseAmount = profit * _totalSupply / circulating` (:93), supply grows, `gonsPerFragment` decreases (:97) — every balance grows pro-rata with **one floor per epoch** (≤ 1 native unit aggregate, conservative). No per-holder loop, no index refresh; balances derive live from gons ÷ divisor.
- **Peg conservation / full exit:** a pre-minted full inventory is assigned to Staking at wire with a pinned 1.0 index (:45–49); staking moves NET in and inventory fragments out 1:1, so stake/unstake is exactly 1:1 with no mint-on-deposit arithmetic at all. Full exit burns `value × gonsPerFragment` gons — exact.
- **Zero-stake / queue:** rebase with no circulating stake is a no-op that retains the queue (:86–90 with `Staking.sol:138–144`).

### 1b. WrappedStakedNET (static SY-style conversion)

`WrappedStakedNET.sol`: fixed 18-decimal shares; `ws = sNet × 1e18 / index` (:79–81), `sNet = ws × index / 1e18` (:83–86). Wrap/unwrap each floor once (:50, :66) — loss < 1 ws-unit, far below one native 9-dec unit; shares are then exact integers. This is the gOHM/ERC-4626-style static face over a rebasing underlying.

### 1c. Pendle side

The configured external SY-sNET (0x5d446a…, API attestation this session) uses Pendle's **scaled18 decimals-wrapper pattern** over rebasing sNET (API: accounting asset `NET-scaled18`, underlying `sNET-scaled18`, both 18-dec; docs describe Scaled18 SYs and `refStrictlyEqual=false` for rebasing yield tokens, accessed 2026-09-27). Its exact conversion implementation is **not in the vendor tree** — recorded as an NN-10/G1 evidence limit, not assumed.

## 2. The algebraic identity that resolves L1

The selected B/U model `balance = floor(B·s/U)` **is** the gons algebra with a fixed giant denominator: set `U = TOTAL_GONS` (constant) and let the rate be a scalar `r = TOTAL_GONS / B` (or its stored equivalent updated only at funding events). Then `balance = g / r = floor(B·g/TOTAL_GONS)` — identical to B/U, no model change, no "gons substitution": the L1 prohibition was against substituting the *indexed/inventory accounting* for the selected live-B/U behavior, and this changes no explicit right. The prior drafts failed only because they computed proportional shares against a **share counter** (`s = floor(x·U/B)`), which is not how either production system issues ownership. Both production systems issue/debit by **exact multiplication against a rate anchored to backing**, and scale balances by moving the rate's divisor — never by recomputing per-holder shares.

## 3. Candidate algorithm (poststate math, all branches)

State: gon inventory assigned to the staking child at initialization (Candidate A — StakedNET-shaped); constant `TOTAL_GONS`; fragment supply `F` with `gonsPerUnit = TOTAL_GONS / F` (scalar, not a per-holder index); per-account gons `g(a)`; per-position native principal `P`.

**Bootstrap (U0):** wire at family initialization: `F := F0` (pinned bootstrap scale, cf. StakedNET's `INITIAL_FRAGMENTS`), inventory gons held by the child, `gonsPerUnit := TOTAL_GONS / F0`. No depositor is ever gifted backing: first stake moves `x` DETF in and `x·gonsPerUnit` gons out of inventory — exact multiply, zero rounding (:129 pattern).

**Stake x:** pull x DETF into custody (measured delta); transfer `x·gonsPerUnit` gons from inventory to the staker. Exact 1:1 native principal; `P += x` for funded positions.

**Unstake x:** burn/return `x·gonsPerUnit` gons to inventory; pay exactly x. Full exit returns the position's last whole native unit; sub-unit dust cannot exist because transfers are exact multiplications (:127–137 pattern).

**Reward funding Δ (expansion mint into custody):** `rebaseAmount = floor(Δ·F/circulating)` (one floor, ≤1 native unit aggregate); `F += rebaseAmount`; `gonsPerUnit = TOTAL_GONS / F` decreases; every balance grows pro-rata — no loop, no refresh, ordinary holders' gons unchanged. This is the exact NetNet promise (:91–99).

**Standing recipients (new-reward-only, additive, no ownership of pre-existing principal):** on funding Δ, after the rebase: mint/transfer from inventory to recipients `floor(f·Δ·gonsPerUnit/1e18)` and `floor(c·Δ·gonsPerUnit/1e18)` gons (recipient value = f·Δ, c·Δ at the new rate, exact at gon scale). Ordinary aggregate captures the rebase increase; recipients capture only their configured share of the new Δ. Independent floors; sub-native dust remains in inventory (conservative, single bucket). When `circulating == 0`, rebase is a no-op retaining the queue (:86–90) and recipient issuance proceeds against inventory.

**Partial rebond q ≤ P:** burn `q·gonsPerUnit` gons from the position (exact multiply); `P −= q`. Residual rewards `(g − q·gonsPerUnit)/gonsPerUnit − (P−q) ≥` prior rewards — the B=10/U=6/s=3/P=4/rewards=1 counterexample resolves exactly: burn 4 units' gons, remaining value = 1 = the reward, retained.

**Reward-only claim c ≤ rewards:** burn `c·gonsPerUnit` gons; `P` unchanged; pay c.

**Overflow:** identical to NetNet's invariant — every gon-denominated write is `amount × gonsPerUnit ≤ F × gonsPerUnit = TOTAL_GONS < 2^256` because debits never exceed the position's fragment claim (revert on insufficient gons, :131).

## 4. Distinguishing the four models (per the prompt)

- **Live custody B/U shares** (selected): balances derive from live custody with no index refresh. Candidate A/B above implement exactly this — the scalar rate is shared, single, and updated only at funding events.
- **Explicitly rebased gons/index** (StakedNET): the production proof that exact 1:1 native principal and no-loop reward distribution coexist; we reuse its arithmetic conventions, not its product behavior (no parallel rebasing-underlying claim).
- **Static SY conversion** (wsNET / Scaled18 SY): fixed-share faces for venues that need static balances; available for the family's SY-compat surfaces if a static face is ever required — not required for the staking child itself.
- **Fixed bond principal** (`P`): stored natively outside the share math, so share rounding can never shave locked principal; invariant `value ≥ P` holds exactly under exact-multiply debit.

## 5. Reachability/precision summary (answers L1's exact demand)

The L1 counterexamples assumed issuance by proportional division against a share counter. Under the production issuance convention (exact multiply against the backing-anchored rate, divisor-scaled rewards), the failing states are unreachable **by construction**: deposit never dilutes old holders (their gons and the rate are untouched by a stake), never confiscates newcomers (exact 1:1), and never shaves principal (debits are exact multiplications; P is native). Aggregate rounding is exactly one floor per reward event (≤1 native unit, conservative, inventory-held), matching the production system's documented behavior. This is not "scale alone fixes it": the load-bearing changes are (i) exact-multiply issuance against a backing-anchored rate and (ii) divisor-scaled rewards, both directly evidenced in `StakedNET.sol:83–99,127–137`.

## 6. Evidence limits

- The custom family's bootstrap inventory scale `F0` and its backing-at-wire arrangement are design choices that must be specified with the first-bond flow (G4); NetNet's own wire used a pre-funded genesis inventory — the analog here is the reserve-activating first bond, which must therefore fund the staking child's inventory coherently (specification work, not an economic change).
- The external SY-sNET conversion implementation is not in the vendor tree; §1c is API/docs attestation only (NN-10/G1).
- Recipient weight source remains the oracle (`IVaultFeeOracleQuery.sol:120–148`); configured values unread (G1).
- No execution; all code citations are direct reads dated 2026-09-27. The corrected wsNET path (`src/perp/WrappedStakedNET.sol`) was used; no read of the incorrect path was attempted.

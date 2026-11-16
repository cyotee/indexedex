# Product Requirements Document (PRD)

## Title

**MixedLegWeightedBufferPool** — mixed unpaired + buffered-pair weighted pool (Balancer V3)

## Status

**LOCKED (product requirements) — reconciled 2026-07-19**

- Behavioral reference: multi-pair buffer + single SE buffer (same hook / virtual / SE I/O for **pair** legs only).
- Package path: `contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/`
- Parallel product forever with multi-pair and single-pair buffer (do not replace them).
- Implementation exists and matches locked decisions below (including optional unpaired rate providers).

**Created:** 2026-07-19  
**Requirements locked:** 2026-07-19 (user multi-choice reconciliation)

---

## Living progress log

| Date | Note |
|------|------|
| 2026-07-20 | Gap suite: validation reverts, unpaired WITH_RATE, LP remove proportional, U0P4 + U4P2 T=8 smoke. **69 green tests**. |
| 2026-07-19 | MultiPair-parity test suite: adversarial P0, U0P2/U2P2 cross-config, comparative vs WeightedPool, invariant/unbalanced/donation. |
| 2026-07-19 | Locked product decisions via multi-choice. Optional unpaired rate providers **confirmed**. Implementation matches all 12 locked items. |
| 2026-07-19 | Initial production surface + TestBase before formal lock (process miss). Requirements review recovered without undoing code. |

---

## Locked product decisions (source of truth)

| # | Decision | Match MultiPair? |
|---|----------|------------------|
| 1 | **Separate parallel product forever** (`mixedLegBuffer`); MultiPair stays | Parallel-forever stance |
| 2 | Allow **`P=0` and `U=0`** as long as `2 ≤ U+2P ≤ 8` | MultiPair = `U=0` special case |
| 3 | Token count **`2 ≤ T ≤ 8`** (`T = U + 2P`) | Same Balancer bound |
| 4 | **Full swap graph** — any pool token ↔ any other | MultiPair O2/L18 |
| 5 | **Proportional + unbalanced LP** + donation/CUSTOM hook tools | MultiPair O6/L19 |
| 6 | Unpaired AMM balance = **physical** Vault `balancesLiveScaled18` only | N/A (no unpaired in MultiPair) |
| 7 | Pair buffer accounting **identical** to MultiPair / single SE buffer | Exact |
| 8 | **Fixed deploy-time weights** sum `1e18`, min ~`1e16`; **pool-wide static** swap fee | Exact |
| 9 | **Pair:** default SE RP if `address(0)`, optional override. **Unpaired:** optional RP — `address(0)` ⇒ STANDARD, non-zero ⇒ WITH_RATE | Pair exact; unpaired is extension |
| 10 | Hook facet **on pool diamond**; **separate** MixedLeg HookFacet/storage (behavior reuse, not MultiPair contract) | On-pool L5 match |
| 11 | Init: **all legs non-zero** seed; buffer seed → `virtualBuffer[i]`; share + unpaired physical | Buffer→virtual L25 match |
| 12 | **All token addresses unique** after sort; unpaired ≠ any buffer or share | Uniqueness + Balancer + explicit rule |

---

## Purpose

Expose a **Balancer V3 weighted market** over **up to 8 tokens** that may be:

1. **Unpaired tokens** — ordinary pool legs; math balance = Vault `balancesLiveScaled18` (physical); optional rate provider.
2. **Buffered pairs** — `(bufferToken, vaultShare)` with Standard Exchange pre-seat / reconcile (same as multi-pair).

Primary goals:

1. **Same buffer accounting** on pair legs as multi-pair / single SE buffer.
2. **Unpaired legs** participate in full weighted graph without SE I/O.
3. **No duplicate tokens** — unpaired must not equal any pair buffer or share (Balancer forbids duplicates).
4. **Composable** — Crane diamond, vault-registry DFPkg, production-first tests.

---

## Product shape

### Constraints

| Rule | Value |
|------|--------|
| Token count `T` | `T = U + 2P` with **`2 ≤ T ≤ 8`** |
| Unpaired count `U` | `0 … 8` |
| Pair count `P` | `0 … 4` |
| Uniqueness | All token addresses distinct after sort (unpaired ⊄ pair buffers ∪ pair shares) |
| Weights | Fixed deploy-time; length `T`; sum `1e18`; each ≥ min weight (`1e16`) |

### Token kinds

| Kind | Balancer role | Math balance | SE I/O |
|------|---------------|--------------|--------|
| **Unpaired** | `STANDARD` if RP `address(0)`; **`WITH_RATE` if optional RP set** | `balancesLiveScaled18[i]` | None |
| **Buffer** | `STANDARD` | `virtualBuffer[p]` | Pre-seat out / reconcile in |
| **Share** | `WITH_RATE` (+ SE RP) | derived via `hookShareDelta` | Used in pre-seat redeem / deposit |

### Behavior locked (same as multi-pair for pairs)

- Hook facet **on pool proxy** (`hooksContract == pool`); separate MixedLeg HookFacet (own storage).
- Init: unpaired seed non-zero physical; buffer seed → `virtualBuffer`; share seed non-zero.
- Full weighted graph (any token ↔ any other).
- Proportional + unbalanced LP; virtuals scale on pair legs only.
- CUSTOM LP passthrough + `NotHookCaller`.
- Eventual-zero physical buffer at rest for pair buffer legs.
- Rate providers: **unpaired optional** (`0` ⇒ STANDARD); **pair** default SE RP when `address(0)`.

### Naming

| Use | Name |
|-----|------|
| Product | `MixedLegWeightedBufferPool` |
| Unpaired | `unpairedToken` / `unpairedRateProvider` |
| Pair | `bufferToken` / `standardExchangeVault` / `shareToken` / `pairRateProvider` |
| Virtual | `virtualBuffer[p]` / `hookShareDelta[p]` |

**Do not** reuse multi-pair HookFacet (separate storage slot / repo). Pattern reuse is fine; storage is not shared.

---

## Equivalence

- **Pair legs:** same AMM + buffer identity thesis as multi-pair under frozen SE underlyings.
- **Unpaired-only (`P=0`):** behaves as a normal weighted pool with physical balances (no buffer hooks fire for SE); optional RPs allowed.
- **Pairs-only (`U=0`):** behavioral twin of multi-pair for that `P` (separate package).

---

## Testing expectations

1. Production DFPkg path via manager vault registry; CREATE3 facets via FactoryService.
2. Gold TestBase on `TestBase_StandardExchangeBufferPool` stack.
3. Happy path: U=2 P=1 mixed; U=0 P=1 pair-only; U=2 P=0 unpaired-only; uniqueness; CUSTOM; graph swaps; proportional LP.
4. **MultiPair-parity suites:**
   - Adversarial P0: D1/D2, F3, A3, E1/E2, E3/E4, E7, C1
   - Cross-config: U=0 P=2 full graph; U=2 P=2 unpaired↔pair
   - Comparative: frozen SE underlyings vs real WeightedPool (buffer↔shares, unpaired routes)
   - Invariant smokes: virtual non-negative sequence; unbalanced LP grows virtual; donation no free BPT
5. Optional unpaired WITH_RATE allowed by pkg; hermetic defaults pass `address(0)`.
6. No mocks of SUT pool / pkg / manager.

---

## Implementation status

**Matches locked requirements.** Production surface + MultiPair-comparable hermetic suite + gap fill (**69 tests green**).

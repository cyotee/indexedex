# Fuzz & invariant coverage — gap report

**Date:** 2026-07-16  
**Scope:** IndexedEx first-party Foundry tests under `test/` and `contracts/` (excludes vendored `lib/crane` product ports unless cited as patterns).  
**Companion:** [ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md](./ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md) (catalog-driven abuse suites).  
**Gold standards (in-repo):**

| Kind | Path | Role |
|------|------|------|
| **Foundry `invariant_*` + Handler** | `test/.../standardExchange/StandardExchangeBufferPool.invariant.t.sol` + `Handler_StandardExchangeBufferPool.sol` | Only production SUT with real multi-call invariant runner |
| **Sequence “invariant” tests** | `test/foundry/fork/.../DualLiquidityLinkedCrossVersionUniswapVault_Invariants.t.sol` (+ `_InvariantHandler.t.sol`) | Fixed multi-op sequences; intentionally avoids fork RPC load of Foundry invariant engine |
| **Property fuzz (SE)** | `AerodromeStandardExchange_Fuzz.t.sol`, `*_InOutInvariant.t.sol`, router/Aave fuzz | Bounded `testFuzz_*` on routes / math / fees |
| **Crane reference (not IndexedEx product)** | `lib/crane/.../CamelotV2_invariant.t.sol`, `TestBase_ERC4626` / `TestBase_ERC20` handlers | Protocol-port and token stub patterns to port, not substitute for DETF/SE product coverage |

This report inventories **where property fuzz and stateful invariants are missing or weak**, relative to what the adversarial program already covers with fixed abuse scenarios. Adversarial ≠ fuzz: fixed scenarios catch known attack shapes; fuzz/invariants catch **state-space and multi-call failures** that catalogs do not enumerate.

---

## Executive summary

| Metric (IndexedEx `test/` + relevant `contracts/`, ~2026-07-16) | Count / status |
|----------------------------------------------------------------|----------------|
| `function testFuzz_*` (approx., includes ~10 Slipstream **commented** stubs) | **~117** definitions; **~107** active |
| Foundry `function invariant_*` | **8** — **all** in Standard Exchange Buffer Pool |
| Foundry `targetContract` product handlers | **1** — BufferPool only |
| Sequence-style `test_invariant_*` | **4** (+ 1 multi-op sequence file) — DualLiquidity only |
| DETF product family (`test/.../vaults/detf/**`) | **0** fuzz, **0** Foundry invariant, **0** sequence invariant |
| Camelot Standard Exchange (IndexedEx path) | **0** `testFuzz_*` |
| Slipstream fork fuzz | **All commented out** (~10 stubs) |

| Maturity | Product families |
|----------|------------------|
| **Full Foundry invariant + Handler** | Standard Exchange Buffer Pool only |
| **Strong `testFuzz_*` (routes / math / fees)** | Aerodrome SE (dominant share); Uni V2 SE in/out; Aave Stata SE; Balancer SE router; VaultFeeOracle bounds/dilution; DualLiquidity math pure fuzz |
| **Sequence invariants (not Foundry runner)** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Thin / pure / stub fuzz** | Seigniorage (bonus multiplier only); RebasingClaimToken (pure math stub); BufferPool common weights view fuzz |
| **Critical gap** | **All DETFs** (MultiVaultWeighted, Single SE, ComposedStable, SingleVault, Seigniorage product paths); **Camelot SE**; **SE multi-call invariants** (except BufferPool); **Slipstream** (commented) |

**Highest ROI fills (P0):**

1. **MultiVaultWeightedDetf** Foundry Handler + `invariant_*` (or high-depth sequence pack) — adversarial gold already exists; property layer missing.  
2. **SingleStandardExchangeDETF** property fuzz + mint/bond/redeem conservation — mirrors MultiVault.  
3. **Aerodrome (or shared SE) Handler invariants** for routes already fuzzed one-at-a-time — close residual / inventory / share conservation under random call order.  
4. **ComposedStable + DualLiquidity** upgrade DualLiquidity sequences → optional Foundry invariant on hermetic path; ComposedStable has neither.  
5. **Camelot SE parity** — port Aerodrome `_InOutInvariant` / fuzz pattern (Camelot protocol-port invariants live under Crane, not IndexedEx SE vaults).

---

## Methodology

### What counts as coverage

| Level | Foundry form | What it proves |
|-------|--------------|----------------|
| **L0 Example** | `test_*` fixed inputs | Known happy / edge cases |
| **L1 Property fuzz** | `testFuzz_*` with `bound` / assumptions | Input-space properties for one (or few) call(s) |
| **L2 Sequence invariant** | Hand-written multi-op `test_invariant_*` | Order-sensitive properties on fixed choreography |
| **L3 Stateful invariant** | `invariant_*` + Handler + `targetContract` / `targetSelector` | Random call sequences; ghost-tracked conservation |

Adversarial suites (catalog A–H) sit mostly at **L0–L1 abuse examples**. They do **not** replace L2/L3 for multi-user interleaving, residual dust accumulation, or “any order of mint/bond/redeem/donate.”

### Classification legend

| Symbol | Meaning |
|--------|---------|
| **F** | Full for that level (meaningful Handler or dense fuzz) |
| **P** | Partial (some `testFuzz_*` or sequences; missing multi-call or product surfaces) |
| **G** | Gap (none or pure-stub only) |
| **C** | Commented / disabled |
| **N** | Not applicable |

### Inventory commands (reproducible)

```bash
# Active-ish fuzz count (IndexedEx tree)
rg "function testFuzz_" test contracts --glob '*.sol' | wc -l

# Foundry invariants (product)
rg "function invariant_" test contracts --glob '*.sol'

# Sequence-named invariants
rg "function test_invariant_" test --glob '*.sol'

# Handlers
rg "targetContract\(" test --glob '*.sol'
```

---

## Coverage matrix (level × product)

| Product / surface | L1 `testFuzz_*` | L2 sequence | L3 Foundry Handler | Notes |
|-------------------|-----------------|-------------|--------------------|-------|
| **SE Buffer Pool** | P (weights view) | — | **F** (8 invariants) | **Gold** |
| **Aerodrome SE** | **F** (~40+ hermetic + fork) | G | G | Route fuzz + InOutInvariant; no Handler |
| **Uniswap V2 SE** | P (InOutInvariant routes) | G | G | Weaker than Aerodrome route matrix |
| **Camelot SE (IndexedEx)** | **G** | G | G | Protocol-port invariants only in Crane |
| **Aave Stata SE** | P (route/fee hermetic + fork) | G | G | Solid L1; no multi-call |
| **Balancer SE router** | P (direct/vault deposit/withdraw/pass-through + fork) | G | G | |
| **Slipstream SE / fork** | **C** | G | G | Fuzz stubs commented |
| **DualLiquidity linked vault** | P (math pure) | **P/F** (4 + sequence file) | G | Explicitly avoids Foundry invariant on fork |
| **MultiVaultWeightedDetf** | **G** | G | G | Adversarial F; property **G** |
| **SingleStandardExchangeDETF** | **G** | G | G | Same |
| **ComposedStableCommonDetf** | **G** | G | G | Same |
| **SingleVaultDetf** | **G** | G | G | Same |
| **Seigniorage DETF / NFT** | P (bonus multiplier ×2) | G | G | No bond/redeem/conservation fuzz |
| **RebasingClaimToken** | P (pure conversion stub) | G | G | Labeled stub risk |
| **VaultFeeOracle** | P (bounds, dilution, bond terms) | G | G | Config/math only |
| **BasicVault / generic vault** | G | G | G | Optional defer with adversarial |

\* “Aerodrome ~40+” counts hermetic route/fuzz + fork route mirrors; see inventory section.

---

## Quantitative inventory (IndexedEx)

### L1 — `testFuzz_*` concentration

Rough active distribution (path keyword match; overlapping paths possible):

| Area | ~Count | Character |
|------|--------|-----------|
| Aerodrome SE (spec + fork) | ~60+ | Route amounts, zap, deposit/withdraw, proportional math, in/out refund |
| Aave Stata SE (spec + fork + eth) | ~13 | Base↔SE↔Stata routes, fee, preview |
| Balancer SE router + fork | ~14 | Exact in/out, vault deposit/withdraw, pass-through |
| Uni V2 SE InOutInvariant | ~4 | Route conservation-style |
| VaultFeeOracle | ~7 | WAD bounds, dilution, bond terms |
| Slipstream | ~10 **commented** | Disabled |
| DualLiquidity math | 1 | Pure round-trip never profits |
| Seigniorage | ~2 | Lock duration → bonus |
| SE Out refund / BufferPool common | ~2 | Refund surplus; weight normalize |
| DETF composed / multi / single | **0** | — |
| Camelot SE IndexedEx | **0** | — |

**Skew:** Fuzz investment is **Standard Exchange route-centric (Aerodrome-led)**. Value-layer products (DETFs) that compose those SE vaults have almost no property layer.

### L3 — Foundry `invariant_*` (complete list)

All eight live in one contract:

`test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool.invariant.t.sol`

| ID (spec §8.3) | Function | Property theme |
|----------------|----------|----------------|
| I-1 | `invariant_virtualTTABounded` | Virtual accounting bound |
| I-2 | `invariant_bptSupplyPositive` | BPT supply > 0 |
| I-3 | `invariant_virtualTTAPositive` | Virtual TTA > 0 |
| I-4 | `invariant_actualTTABounded` | Actual TTA bound |
| I-5 | `invariant_noFreeValue` | No free value (ghost) |
| I-6 | `invariant_ghostCountersMonotonic` | Ghost counters |
| I-7 | `invariant_hookSharesDeltaBounded` | Hook share delta |
| I-8 | `invariant_actualSharesPositive` | Actual shares > 0 |

**Config:** `runs = 50`, `depth = 20` (CI-friendly).  
**Handler ops:** `swap_TTA_in`, `swap_shares_in`, `lp_add`, `lp_remove`, `lp_add_unbalanced`.

### L2 — DualLiquidity sequences

| File | Style |
|------|--------|
| `.../DualLiquidityLinkedCrossVersionUniswapVault_Invariants.t.sol` | Fixed multi-step: deposit→redeem never profits; BPT backing; BPT/share non-decreasing; pro-rata redeem |
| `.../DualLiquidityLinkedCrossVersionUniswapVault_InvariantHandler.t.sol` | Named sequence of deposit/swap/redeem with inventory + genesis claim checks — **not** Foundry `targetContract` |

Comment in Handler file: *avoids Foundry invariant runner's heavy fork RPC load* — a real constraint for fork golds; hermetic DETF/SE should prefer L3.

---

## Product-by-product gaps

### 1. Standard Exchange Buffer Pool — **L3 baseline complete**

| Item | Detail |
|------|--------|
| Status | **IMPLEMENTED** — Handler + 8 invariants |
| Residual gaps | Optional: more actors, donation/ghost free-share attacks interleaved with swaps; raise `runs`/`depth` in nightly profile; L1 only thin |

No blocking gap for this family. **Use as template** for DETF/SE Handlers.

---

### 2. MultiVaultWeightedDetf — **critical property gap**

| Item | Detail |
|------|--------|
| Production | `contracts/vaults/detf/...` multi-vault weighted package |
| Adversarial | **Full P0/P1** under `.../multi-vault-weighted/adversarial/` |
| Fuzz / invariant | **None** |

**Why this matters:** Adversarial proves specific attacks fail once. Invariants must hold after **random interleaving** of mint, bond, redeem, claim, residual-cleanup, and (if in-scope) donate/skew ops across multiple actors.

**Recommended L3 properties (map to adversarial themes):**

| Invariant theme | Related catalog | Assertion sketch |
|-----------------|-----------------|------------------|
| No free DETF / claim from donation | A1–A3 | Ghost: Σ user claims ≤ reserve; donate does not increase attacker claim without mint |
| Conservation after successful mint/redeem | E1, H2 | Actor asset + vault residual consistent; failed ops leave no stuck intermediate |
| Bond/claim authority | D2–D6 | Ghost onlyOwner NFT/claim balances; no double redeem |
| Rate / threshold non-exploit under bounds | B1, B3 | After any sequence with bounded external prices, gates still coherent |
| Residual inventory clean | H3, E residual | After handler “cleanup” or successful user ops, diamond intermediate balances ≈ 0 (or dust bound) |
| Reentrancy not required in invariant path | C* | Prefer lock-safe handlers; adversarial remains for C |

**Recommended suite path:**

```text
test/foundry/spec/vaults/detf/composed/multi-vault-weighted/invariant/
  Handler_MultiVaultWeightedDetf.sol
  MultiVaultWeightedDetf.invariant.t.sol
```

Reuse `TestBase` from adversarial/matrix; production deploy only. Prefer **hermetic** SE underlyings so L3 is CI-cheap.

**L1 starter pack (if L3 blocked):** `testFuzz_mint_burn_conservation`, `testFuzz_bond_redeem_proRata`, `testFuzz_multiActor_noFreeMint` with `bound` amounts.

---

### 3. SingleStandardExchangeDETF — **critical property gap**

| Item | Detail |
|------|--------|
| Status | Adversarial P0/P1 implemented; **0** fuzz/invariant |
| Closest existing | SE route fuzz on underlyings — does not exercise DETF mint/bond/claim |

**Priority properties:** mint/burn share conservation; bond NFT lifecycle; claim redeem no free BPT; residual after failed route; multi-actor share pro-rata.

**Path:** `.../standardExchange/single/invariant/` mirroring MultiVault.

---

### 4. ComposedStableCommonDetf — **critical property gap**

| Item | Detail |
|------|--------|
| Status | Adversarial P0; multi-leg reserve; **0** property layer |
| Unique risk | Nested composition + rebasing claim — L2/L3 more valuable than single-leg |

**Priority:** multi-leg mint/redeem conservation; claim redeem atomicity under random order; outer composition inventory clean.

---

### 5. DualLiquidityLinkedCrossVersionUniswapVault — **L2 partial; L3 gap**

| Item | Detail |
|------|--------|
| L1 | Math pure `testFuzz_roundTrip_neverProfits` |
| L2 | Strong sequence invariants + mixed-ops sequence |
| L3 | Intentionally skipped on fork (RPC cost) |

**Gap fill options:**

1. Hermetic dual-leg TestBase + Foundry Handler (preferred for CI).  
2. Nightly fork profile: low `runs`/`depth` L3.  
3. Expand L2 sequences (more actors, fee edge, residual after partial redeem) without Foundry engine.

---

### 6. Aerodrome Standard Exchange — **L1 strong; L2/L3 gap**

| Item | Detail |
|------|--------|
| Strength | Richest `testFuzz_*` surface; `_InOutInvariant` per-route; dedicated `_Fuzz.t.sol` for proportional deposit math |
| Gap | No random multi-route Handler; no residual/inventory invariant across route switches |

**ROI:** One `Handler_AerodromeStandardExchange` targeting swap / zap / vault deposit / vault withdraw / zap-out-withdraw with:

- `invariant_noStuckInventory` (tokens held by vault diamond ≈ expected)  
- `invariant_shareSupply_matchesAccounting`  
- `invariant_preview_vs_execute_bound` (if cheap enough)

Template: BufferPool Handler + existing InOutInvariant assertions as post-call checks.

---

### 7. Uniswap V2 SE — **L1 partial**

Has `_InOutInvariant` route fuzz; thinner route matrix than Aerodrome. Port remaining Aerodrome route fuzz + shared Handler pattern.

---

### 8. Camelot Standard Exchange (IndexedEx) — **L1 gap**

| Item | Detail |
|------|--------|
| IndexedEx SE | **0** `testFuzz_*` |
| Crane | Strong Camelot V2 protocol-port fuzz + `CamelotV2_invariant.t.sol` |

**Do not confuse** protocol-port K-invariants with **Standard Exchange vault** route conservation. Port Aerodrome SE fuzz/InOut patterns via Camelot TestBase.

---

### 9. Aave Stata SE — **L1 partial; L3 gap**

Hermetic + fork preview/route/fee fuzz. Missing multi-call Handler (supply/withdraw/fee path interleaving; index accrual if modeled).

---

### 10. Balancer SE router — **L1 partial; L3 gap**

Direct swap + vault deposit/withdraw/pass-through fuzz (spec + fork). No Handler for mixed router modes / Permit2 optional later.

---

### 11. Slipstream — **L1 disabled**

All fork `testFuzz_*` commented. Re-enable or replace with hermetic Slipstream SE fuzz once TestBase stability allows. Treat as **C → G** until green.

---

### 12. Seigniorage — **L1 thin**

Only bonus-multiplier scaling fuzz (spec + fork). Missing: mint/bond lock math under random durations **and** amounts; redeem/claim conservation; incentive fee extraction monotonicity (oracle side has some dilution fuzz).

---

### 13. RebasingClaimToken / protocol NFT stubs — **stub risk**

`testFuzz_conversion_roundTrip` is **pure** math, not production diamond. Align with adversarial report: labeled stub; real redeem fuzz only when production claim token path is the SUT.

---

### 14. VaultFeeOracle — **L1 partial (config)**

Bounds + dilution + bond terms round-trip. No multi-call “oracle state machine” invariant (optional; lower risk than vault funds).

---

## Cross-cutting gaps

### A. Terminology debt: “invariant” in names

Many `testFuzz_*_inOutInvariant` and `test_invariant_*` are **not** Foundry stateful invariants. Document in suite headers:

- **Property fuzz** — single-call / few-call  
- **Sequence invariant** — fixed multi-op  
- **Stateful invariant** — `invariant_*` + Handler  

Avoid inflating maturity metrics by name alone.

### B. DETF vs SE skew

Adversarial program closed **catalog** gaps on DETFs. Fuzz/invariant program is inverted: **SE routes dense, DETF empty**. Highest systemic risk sits at DETF composition of SE underlyings — exactly where L3 is missing.

### C. Fork vs hermetic

DualLiquidity correctly avoided L3 on fork. Prefer:

| Environment | Preferred level |
|-------------|-----------------|
| Hermetic TestBase | L3 Handler (CI) |
| Fork gold | L1 + L2; optional nightly L3 |

### D. Ghost accounting underused outside BufferPool

BufferPool ghosts (no free value, monotonic counters) are the pattern DETF Handlers should copy for mint/burn/claim ledgers.

### E. Production-first constraint

Handlers must call **real** facets/vaults via existing TestBases (`IndexedexTest` → protocol TestBase → product TestBase). Do not reintroduce `MockStandardExchange` as SUT. Test doubles only as controllable ERC20s / reentrancy tokens **outside** SUT (see `contracts/test/adversarial/`).

### F. Crane vs IndexedEx

Crane has rich L3 for ERC20/ERC4626 stubs, Camelot ports, set repos, Liquity ports. That **does not** count as IndexedEx product coverage. Port **patterns**, not credit.

---

## Recommended fill order (roadmap)

| Priority | Work | Level | Est. effort | Depends on |
|----------|------|-------|-------------|------------|
| **P0** | MultiVaultWeightedDetf Handler + core `invariant_*` (no free value, residual, claim ledger) | L3 | M–L | Existing MultiVault TestBase |
| **P0** | Single SE DETF L1 conservation pack + thin L3 if MultiVault pattern works | L1→L3 | M | MultiVault Handler pattern |
| **P0** | Aerodrome SE Handler: inventory + share conservation across routes | L3 | M | BufferPool Handler pattern |
| **P1** | ComposedStable L2 sequences + L3 hermetic | L2–L3 | L | Multi-leg TestBase |
| **P1** | Camelot SE L1 InOutInvariant parity with Aerodrome | L1 | M | Camelot SE TestBase |
| **P1** | DualLiquidity expand L2; optional hermetic L3 | L2–L3 | M | DualLiquidity TestBase |
| **P1** | Aave Stata + Balancer router thin Handlers | L3 | M | Existing fuzz bases |
| **P2** | Re-enable Slipstream fuzz or hermetic replace | L1 | M | Stability |
| **P2** | Seigniorage mint/redeem conservation fuzz | L1 | S–M | Seigniorage TestBase |
| **P2** | Nightly profile: higher BufferPool + DETF `runs`/`depth` | config | S | P0 suites |
| **P3** | Fee oracle state machine; BasicVault | L1–L3 | S | Optional |

---

## Acceptance criteria (when a product is “covered”)

A product family is **property-complete** when:

1. **L1:** At least one meaningful `testFuzz_*` per primary user flow (mint/deposit, redeem/withdraw, swap/route if applicable) with realistic `bound`s.  
2. **L2 or L3:** Either multi-op sequences **or** Foundry Handler covering ≥3 mutating entrypoints and ≥2 actors (where multi-user is in threat model).  
3. **L3 (funds-holding products):** At least one `invariant_noFreeValue` / conservation ghost and one residual/inventory clean assertion.  
4. **CI:** Hermetic L3 with documented `runs`/`depth`; fork L3 only in optional profile.  
5. **No double-counting:** Adversarial suite alone does not satisfy (2)–(3).

**Current status vs criteria:**

| Family | Meets? |
|--------|--------|
| BufferPool | **Yes** (L3 + thin L1) |
| Aerodrome SE | **Partial** (L1 only) |
| DualLiquidity | **Partial** (L2; weak L1; no L3) |
| All DETFs | **No** |
| Camelot SE | **No** |
| Slipstream | **No** (disabled) |

---

## Relationship to adversarial coverage

| Program | Strength | Blind spot |
|---------|----------|------------|
| **Adversarial (catalog A–H)** | Known attack shapes; reentrancy; authority; donation once | Call ordering; multi-actor interleaving; “any amount” residual dust |
| **Fuzz L1** | Input ranges; rounding; fee math | Multi-call state machines |
| **Invariant L3** | State machines; ghosts | May miss intentional attack setups unless Handler exposes donate/reenter hooks |

**Together:** Adversarial P0 + L3 conservation is the pre-audit bar for DETF gold products. Today MultiVault has adversarial only; BufferPool has L3 only (and is not a DETF).

---

## Appendix A — Key file index

### Gold / near-gold

| File | Role |
|------|------|
| `.../StandardExchangeBufferPool.invariant.t.sol` | L3 suite |
| `.../Handler_StandardExchangeBufferPool.sol` | Handler |
| `.../DualLiquidity..._Invariants.t.sol` | L2 sequences |
| `.../DualLiquidity..._InvariantHandler.t.sol` | L2 multi-op sequence |
| `.../AerodromeStandardExchange_Fuzz.t.sol` | L1 math/deposit |
| `.../AerodromeStandardExchange_InOutInvariant.t.sol` | L1 route conservation |
| `.../UniswapV2StandardExchange_InOutInvariant.t.sol` | L1 Uni V2 |
| `.../AaveV3StataStandardExchange*.t.sol` | L1 Aave |
| `.../BalancerV3StandardExchangeRouter_*.t.sol` | L1 router |
| `.../VaultFeeOracle_*.t.sol` | L1 oracle |

### Explicit gaps (expected empty)

| Path | Expectation today |
|------|-------------------|
| `test/foundry/spec/vaults/detf/**` | No `testFuzz_*` / `invariant_*` |
| Camelot under `test/foundry/spec/protocol/dexes/camelot` (if present) | No SE route fuzz parity |
| Slipstream fork `testFuzz_*` | Commented |

### Crane patterns to copy (not credit)

| Path | Pattern |
|------|---------|
| `lib/crane/contracts/tokens/ERC4626/TestBase_ERC4626.sol` | Handler + share sum invariants |
| `lib/crane/test/.../CamelotV2_invariant.t.sol` | Protocol K invariants |
| `lib/crane/contracts/tokens/ERC20/TestBase_ERC20.sol` | Classic balance-sum Handler |

---

## Appendix B — Suggested first MultiVault Handler surface

Minimal selector set for P0 L3:

```text
handler.mintWithRateAsset(uint256 amountSeed, uint8 actorIdx)
handler.redeemShares(uint256 shareSeed, uint8 actorIdx)
handler.bond(uint256 amountSeed, uint8 actorIdx)          // if always available post-bootstrap
handler.redeemClaim / sell path(uint8 actorIdx)         // authority-sensitive; may revert often
handler.warp(uint256 dtSeed)                            // time for locks if needed
handler.donateSharesOrBpt(uint256 amountSeed)           // optional for A-class ghost checks
```

Ghosts:

- `ghost_mintedAssets[actor]`, `ghost_redeemedAssets[actor]`  
- `ghost_claimsOutstanding`  
- `ghost_donateAmount`  
- After every call: residual inventory ≤ dust bound; `Σ convertible claims ≤ reserve BPT (+ fee policy)`

Config (start): `runs = 32`, `depth = 12` hermetic; raise in nightly.

---

## Appendix C — Change log

| Date | Note |
|------|------|
| 2026-07-16 | Initial inventory: ~117 `testFuzz_*`, 8 Foundry `invariant_*` (BufferPool only), DualLiquidity L2, DETF property gap, Camelot SE / Slipstream gaps. Companion to adversarial gap report post Waves 0–3. |
| 2026-07-16 | **Gaps filled (Waves 0–3):** MultiVault + Single SE L1+L3 Handlers; Aerodrome SE L3; Camelot L1 InOut; ComposedStable L2 sequences; DualLiquidity L2 expand; Seigniorage amount fuzz; SingleVault L1; shared `InvariantAssertLib`. Remaining optional: Wave 4 (Aave/Balancer Handlers, Slipstream re-enable, nightly depth). |

---

*End of report. Implementation plan: [`docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md`](./FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md) (**IMPLEMENTED** Waves 0–3 mandatory; Wave 4 optional deferred).*

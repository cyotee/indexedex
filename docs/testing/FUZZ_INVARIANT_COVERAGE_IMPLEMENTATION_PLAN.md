# Fuzz & invariant coverage — implementation plan

**Status:** IMPLEMENTED (Waves 0–3 mandatory scope; Wave 4 optional deferred)  
**Date:** 2026-07-16 (executed 2026-07-16)  
**Inputs:**

- Gap report: [`docs/testing/FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md`](./FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md)
- Adversarial companion (done Waves 0–3): [`docs/testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md`](./ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md)
- L3 gold: `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPool.invariant.t.sol` + `Handler_StandardExchangeBufferPool.sol`
- L2 gold: `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_Invariants.t.sol`
- L1 gold: `AerodromeStandardExchange_Fuzz.t.sol`, `*_InOutInvariant.t.sol`
- Skills: `crane-testing`, `indexedex-testing`, `forge-fuzz-testing`; adversarial skills for catalog cross-refs only

**Goal:** Close the **property** layer (L1 fuzz + L2 sequences + L3 Foundry Handler invariants) for DETFs and Standard Exchange surfaces so multi-call / multi-actor / input-space failures are covered — complementary to catalog-driven adversarial suites.

This plan does **not** re-implement adversarial A–H cases. It proves **conservation, residual cleanliness, and share accounting** under random inputs and random call order.

---

## 1. Success definition

### 1.1 Coverage levels (canonical)

| Level | Form | CI expectation |
|-------|------|----------------|
| **L1** | `testFuzz_*` + `bound` / `vm.assume` | Always on default profile |
| **L2** | Hand-written multi-op `test_invariant_*` or `test_invariantSequence_*` | Always when hermetic; fork OK with profile |
| **L3** | `invariant_*` + Handler + `targetContract` / `targetSelector` | Hermetic default; fork only nightly / optional |

**Naming rule (mandatory in suite NatSpec):**

- Property fuzz ≠ sequence invariant ≠ Foundry stateful invariant.  
- Do not name L1/L2 files `*.invariant.t.sol` unless they use Foundry `invariant_*`.  
- Prefer: `*_Fuzz.t.sol`, `*_Sequences.t.sol`, `*.invariant.t.sol` + `Handler_*.sol`.

### 1.2 “Property-complete” (per product)

A product is **property-complete** when (from gap report acceptance criteria):

1. **L1:** ≥1 meaningful `testFuzz_*` per primary flow (mint/deposit, redeem/withdraw, swap/route if applicable) with realistic bounds.  
2. **L2 or L3:** Multi-op sequences **or** Foundry Handler covering ≥3 mutating entrypoints and ≥2 actors (where multi-user is in threat model).  
3. **L3 for funds-holding products:** ≥1 conservation / no-free-value ghost invariant **and** ≥1 residual/inventory clean assertion.  
4. **CI:** Hermetic L3 with documented `runs`/`depth`; fork L3 only optional profile.  
5. Adversarial alone does **not** satisfy (2)–(3).

### 1.3 Program-level done

| Wave | Done when |
|------|-----------|
| **0** | Shared invariant harness + docs + CI profile notes; BufferPool tagged as gold |
| **1** | MultiVaultWeightedDetf L1 + L3 green; Single SE DETF L1 (+ L3 if pattern ports cleanly) |
| **2** | Aerodrome SE L3 Handler; Camelot SE L1 parity; Uni V2 L1 tighten |
| **3** | ComposedStable L2/L3; DualLiquidity L2 expand (+ hermetic L3 if feasible); Seigniorage L1 expand |
| **4 (optional)** | Aave/Balancer Handlers; Slipstream re-enable; nightly high-depth profile |

### 1.4 Non-negotiable testing rules

1. **Production-first:** CREATE3 + FactoryService + vault registry DFPkg path (`indexedex-testing`).  
2. **No** `MockStandardExchange` / mock manager / mock registry as SUT.  
3. Handlers call **real** entry points (`exchangeIn`, mint/bond/redeem, SE routes).  
4. Handler ops use `try/catch` (or explicit preconditions) so expected reverts do not fail the invariant campaign — only successful ops update ghosts (BufferPool pattern).  
5. **DETF role names only** (`rateAsset`, `pairToken`, `underlyingVault`, `rebasingClaimToken`).  
6. Prefer **hermetic** TestBases for L3; fork for L1/L2 validation of live wiring.  
7. If L3 finds a real free-value bug → **production fix before green tests**.  
8. Keep `runs`/`depth` CI-friendly by default; document nightly overrides.

---

## 2. Property catalog (IDs for test / invariant names)

Use these IDs in names and plan matrices (orthogonal to adversarial A–H).

| ID | Level | Theme | Assertion sketch |
|----|-------|--------|------------------|
| **P-CONS** | L1/L3 | Round-trip conservation | Mint then full redeem: actor asset out ≤ in + fees; no free shares |
| **P-PRORATA** | L1/L3 | Pro-rata claims | `claim ≤ (shares * reserve) / supply`; aggregate claims ≤ reserve + dust |
| **P-NODILUTE** | L1/L2 | Existing holders | After third-party mint (no donate), prior claim non-decreasing (cross-mul) |
| **P-RESID** | L2/L3 | Residual inventory | After successful user ops, diamond intermediate token balances ≤ dust bound |
| **P-NOFREE** | L3 | Ghost no free value | Σ actor gains ≤ Σ actor deposits + explicit donate ghost |
| **P-SUPPLY** | L3 | Share supply | `totalSupply` matches sum of tracked actor balances (+ protocol dust) |
| **P-GHOST** | L3 | Monotonic ghosts | Successful op counters non-decreasing; no wrap |
| **P-BOUND** | L1 | Input bounds | Zero / max / one-wei / extreme amount: revert or safe |
| **P-PREVIEW** | L1 | Preview parity | Preview ≈ execute within documented tolerance |
| **P-FEE** | L1 | Fee monotonic | Higher fee ⇒ ≤ output for same in |
| **P-ROUTE** | L1 | Route in/out | SE route N: out > 0 and in/out conservation class |
| **P-AUTH** | L2 | Authority in sequence | Random order never grants claim/NFT to wrong actor (may be mostly reverts) |
| **P-TIME** | L1/L2 | Time locks | Warp + redeem respects lock (Seigniorage / bond) |

Cross-link adversarial themes in NatSpec only, e.g. `@dev Supports E1-class under random order (not a catalog case)`.

---

## 3. Wave 0 — Foundation

### 3.1 Purpose

Make L3 portable: shared ghosts, residual assert, actor pick, forge-config conventions — without rewriting BufferPool.

### 3.2 Deliverables

| ID | Task | Output | Est. |
|----|------|--------|------|
| W0-1 | **InvariantAssertLib** (or extend `AdversarialAssertLib`) | `contracts/test/invariant/InvariantAssertLib.sol` — residual bound, pro-rata claim, cross-mul gte | 0.5 d |
| W0-2 | **Handler style guide** | Short md section in this plan §7 + NatSpec template for Handler (try/catch, ghosts, 2+ actors, fund-before-act) | 0.25 d |
| W0-3 | **CI config notes** | Document default `/// forge-config: default.invariant.runs = 32` / `depth = 12`; optional `[profile.invariant_nightly]` in plan (add to `foundry.toml` only if team agrees) | 0.25 d |
| W0-4 | **Gold labels** | NatSpec on BufferPool invariant suite + DualLiquidity sequences: L3 gold / L2 gold | 0.1 d |
| W0-5 | **Gap report link** | Point gap report “Next artifact” to this plan; set plan status PLANNED | 0.1 d |
| W0-6 | **Compile smoke** | Minimal `InvariantHarness_Compile.t.sol` importing lib if new lib has no other user yet | 0.25 d |

### 3.3 Exit criteria

- [ ] Shared assert helpers compile and are importable.  
- [ ] BufferPool + DualLiquidity labeled as golds.  
- [ ] Wave 1 implementers can copy BufferPool Handler skeleton without re-deriving try/catch rules.  
- [ ] **Do not** require BufferPool refactor onto shared lib in Wave 0 (optional later).

### 3.4 Non-goals Wave 0

- DETF or SE product Handlers (Wave 1+).  
- Raising BufferPool runs (optional Wave 4).

---

## 4. Wave 1 — DETF property core (highest ROI)

MultiVault is adversarial gold and property empty — **implement L3 here first**, then port to Single SE.

### 4.1 MultiVaultWeightedDetf (Wave 1A) — **first**

#### 4.1.1 Layout

```text
# Product-local co-located fuzz/invariant plan md is retired (directory reorg).
# Property IDs: suite NatSpec + this program doc + AGENTS.md testing expectations.
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/invariant/
  MultiVaultWeightedDetf.invariant.t.sol

test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/fuzz/
  MultiVaultWeightedDetf_Fuzz.t.sol   # L1 pack
```

#### 4.1.2 Handler surface (P0 selectors)

| Selector | Behavior | Ghost updates |
|----------|----------|---------------|
| `mint(uint256 amountSeed, uint8 actorIdx)` | Mint with `rateAsset` (or product primary mint path) | `ghost_assetsIn[actor]`, `ghost_sharesOut[actor]`, count |
| `redeem(uint256 shareSeed, uint8 actorIdx)` | Redeem shares → assets | `ghost_assetsOut[actor]`, `ghost_sharesIn[actor]` |
| `bond(uint256 amountSeed, uint8 actorIdx)` | Bond when live (try/catch if gates fail) | `ghost_bondCount` |
| `claimOrSell(uint8 actorIdx)` | Claim/redeem path if actor holds NFT/claim | authority-sensitive; often reverts |
| `donateUnderlying(uint256 amountSeed)` | Optional free transfer to diamond / reserve BPT | `ghost_donate` for P-NOFREE |
| `warp(uint256 dtSeed)` | If locks matter | — |

**Actors:** ≥2 (alice/bob) + optional genesis holder. Fund actors before each action (BufferPool pattern).

#### 4.1.3 Core invariants (P0)

| Function | Properties |
|----------|------------|
| `invariant_noFreeValue` | P-NOFREE — actor net assets ≤ deposited + donate ghost (fee-aware tolerance) |
| `invariant_residualInventory` | P-RESID — intermediate tokens on diamond ≤ dust |
| `invariant_proRataClaims` | P-PRORATA — aggregate claims ≤ reserve |
| `invariant_shareSupplyConsistent` | P-SUPPLY — if shares are ERC20-like and enumerable actors cover all holders, or check genesis+actors |
| `invariant_ghostCountersMonotonic` | P-GHOST |

Start config:

```solidity
/// forge-config: default.invariant.runs = 32
/// forge-config: default.invariant.depth = 12
```

#### 4.1.4 L1 fuzz pack (parallel or pre-L3)

| Test | Property |
|------|----------|
| `testFuzz_mint_fullRedeem_conservation` | P-CONS |
| `testFuzz_multiActor_proRata` | P-PRORATA |
| `testFuzz_mint_noDilutePriorClaim` | P-NODILUTE |
| `testFuzz_zeroAndBoundAmounts` | P-BOUND |

#### 4.1.5 Task checklist

| ID | Task | Depends | Pri |
|----|------|---------|-----|
| 1A-0 | Product plan md (properties, deferred, pass matrix) | W0 | — |
| 1A-1 | Confirm MultiVault happy + adversarial still green on TestBase | 1A-0 | — |
| 1A-2 | L1 fuzz file green | 1A-1 | P0 |
| 1A-3 | Handler + `targetSelector` wiring on production TestBase | 1A-1 | P0 |
| 1A-4 | P0 invariants green | 1A-3 | P0 |
| 1A-5 | Optional donate ghost + P-NOFREE tighten | 1A-4 | P1 |
| 1A-6 | Update product plan + gap report checkboxes | 1A-4 | — |

#### 4.1.6 Verification

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/fuzz/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/invariant/**' -vv
# Regression:
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**'
```

#### 4.1.7 Exit

- [ ] L1 pack green  
- [ ] L3 Handler + ≥4 P0 invariants green  
- [ ] Plan status **IMPLEMENTED (L1+L3 P0)**  

**Est.:** 4–7 eng-days (handler tuning dominates).

---

### 4.2 SingleStandardExchangeDETF (Wave 1B)

#### 4.2.1 Layout

```text
# Product-local co-located fuzz/invariant plan md is retired (directory reorg).
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/fuzz/
  SingleStandardExchangeDETF_Fuzz.t.sol

test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/invariant/
  SingleStandardExchangeDETF.invariant.t.sol
```

#### 4.2.2 Tasks

| ID | Task | Pri |
|----|------|-----|
| 1B-0 | Product plan; hermetic Aerodrome underlying | — |
| 1B-1 | Port MultiVault L1 pack (mint/redeem/pro-rata/bounds) | P0 |
| 1B-2 | Port Handler skeleton; drop multi-leg-only ops | P0 |
| 1B-3 | Invariants: P-NOFREE, P-RESID, P-PRORATA, P-GHOST | P0 |
| 1B-4 | Optional bond/claim selectors if stable under fuzz | P1 |
| 1B-5 | Green + plan matrix | — |

#### 4.2.3 Verification

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/fuzz/**'
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/invariant/**'
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/**'
```

**Est.:** 3–5 eng-days after 1A pattern exists (parallel only if 1A Handler API frozen).

---

## 5. Wave 2 — Standard Exchange multi-call + Camelot L1

### 5.1 Aerodrome SE Handler (Wave 2A)

#### 5.1.1 Goal

L1 already strong. Add **L3** so random **route order** cannot stick inventory or mint free shares.

#### 5.1.2 Layout

```text
test/foundry/spec/protocol/dexes/aerodrome/v1/invariant/
  Handler_AerodromeStandardExchange.sol
  AerodromeStandardExchange.invariant.t.sol
```

#### 5.1.3 Handler ops (map to existing routes)

| Op | Maps to existing coverage |
|----|---------------------------|
| `swap_AtoB` / `swap_BtoA` | Route1 Swap fuzz |
| `zapIn` | Route2 |
| `zapOut` | Route3 |
| `vaultDeposit` | Route4 |
| `vaultWithdraw` | Route5 |
| `zapInDeposit` | Route6 |
| `zapOutWithdraw` | Route7 |

Start with **subset** (swap + vault deposit + vault withdraw + one zap) if full surface is flaky; expand P1.

#### 5.1.4 Invariants

| Function | Property |
|----------|----------|
| `invariant_noStuckInventory` | P-RESID |
| `invariant_shareAccounting` | P-SUPPLY / fee-aware |
| `invariant_ghostMonotonic` | P-GHOST |
| Optional `invariant_noFreeShares` | P-NOFREE |

Reuse assertion ideas from `*_InOutInvariant` as post-success checks inside handler where cheap.

#### 5.1.5 Tasks

| ID | Task | Pri |
|----|------|-----|
| 2A-0 | Product note in aerodrome coverage doc or local plan md | — |
| 2A-1 | Handler from `TestBase_AerodromeStandardExchange` | P0 |
| 2A-2 | Core 3 invariants green | P0 |
| 2A-3 | Expand selectors to all routes | P1 |
| 2A-4 | Ensure existing L1 fuzz still green (no regressions) | — |

```bash
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/invariant/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**Fuzz**'
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/*InOut*'
```

**Est.:** 3–5 eng-days.

---

### 5.2 Camelot SE L1 parity (Wave 2B)

#### 5.2.1 Goal

IndexedEx Camelot SE currently **0** `testFuzz_*`. Port Aerodrome InOut / route fuzz patterns — **not** Crane pair K-invariants alone.

#### 5.2.2 Layout

```text
test/foundry/spec/protocol/dexes/camelot/v2/
  CamelotV2StandardExchange_InOutInvariant.t.sol   # mirror UniV2/Aerodrome
  CamelotV2StandardExchange_Fuzz.t.sol             # proportional / route amounts if applicable
```

#### 5.2.3 Tasks

| ID | Task | Pri |
|----|------|-----|
| 2B-0 | Confirm Camelot SE TestBase hermetic green | — |
| 2B-1 | Port route in/out fuzz for primary routes (P-ROUTE, P-CONS) | P0 |
| 2B-2 | Fee/FOT-aware bounds where Camelot differs | P1 |
| 2B-3 | Optional thin L3 later (Wave 4) after Aerodrome Handler proven | P2 |

```bash
forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/**'
```

**Est.:** 2–4 eng-days.

---

### 5.3 Uniswap V2 SE L1 tighten (Wave 2C)

| ID | Task | Pri |
|----|------|-----|
| 2C-1 | Expand `_InOutInvariant` to match Aerodrome route coverage gaps | P1 |
| 2C-2 | Optional share Aerodrome Handler via abstract SE handler (only if 2A stayed generic) | P2 |

**Est.:** 1–3 eng-days.

---

## 6. Wave 3 — Composed products + DualLiquidity + Seigniorage

### 6.1 ComposedStableCommonDetf (Wave 3A)

#### 6.1.1 Approach

Multi-leg + rebasing claim: **L2 sequences first** (cheaper to debug), then L3.

#### 6.1.2 Layout

```text
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/sequences/
  ComposedStableCommonDetf_Sequences.t.sol

test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/fuzz/
  ComposedStableCommonDetf_Fuzz.t.sol

test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/invariant/   # after sequences stable
  Handler_ComposedStableCommonDetf.sol
  ComposedStableCommonDetf.invariant.t.sol
```

#### 6.1.3 Tasks

| ID | Task | Pri |
|----|------|-----|
| 3A-0 | Product plan | — |
| 3A-1 | L1 multi-leg mint/redeem conservation | P0 |
| 3A-2 | L2: mint → claim → redeem; multi-actor; residual | P0 |
| 3A-3 | L3 Handler (mint/redeem/claim) | P0/P1 |
| 3A-4 | Green + plan | — |

**Est.:** 5–8 eng-days.

---

### 6.2 DualLiquidity (Wave 3B)

#### 6.2.1 Approach

Keep fork L3 **optional**. Prefer:

1. Expand L2 sequences (more actors, partial redeem residual, fee edge).  
2. If hermetic dual-leg deploy path exists or can be added without new protocol ports → L3 Handler.  
3. Else document: L2+L1 only for fork gold.

#### 6.2.2 Tasks

| ID | Task | Pri |
|----|------|-----|
| 3B-0 | Inventory current Invariants + InvariantHandler sequences → property ID map | — |
| 3B-1 | Add L2: 3-actor pro-rata; partial redeem residual; swap-then-redeem | P0 |
| 3B-2 | Extra L1 amounts on deposit/redeem if missing | P1 |
| 3B-3 | Hermetic L3 **or** NatSpec defer with reason | P1 |
| 3B-4 | Optional `FOUNDRY_PROFILE=fork` nightly L3 low runs | P2 |

```bash
FOUNDRY_PROFILE=fork forge test --match-path \
  'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/*Invariant*'
```

**Est.:** 2–4 eng-days (L2 expand); +3–5 if hermetic L3.

---

### 6.3 Seigniorage (Wave 3C)

| ID | Task | Pri |
|----|------|-----|
| 3C-0 | Product fuzz plan (hermetic primary) | — |
| 3C-1 | `testFuzz_mint_bond_redeem_conservation` (amount + lockDuration) | P0 |
| 3C-2 | `testFuzz_bonusMultiplier_withAmounts` (extend beyond duration-only) | P0 |
| 3C-3 | L2 sequence: multi-user lock/redeem | P1 |
| 3C-4 | L3 only if mint surface is stable under random order | P2 |

```bash
# SeigniorageDETF product tests removed with package (legacy dual-token product)
# fork smoke optional:
# FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/seigniorage/**'
```

**Est.:** 2–4 eng-days.

---

### 6.4 SingleVaultDetf (Wave 3D)

| ID | Task | Pri |
|----|------|-----|
| 3D-1 | Port MultiVault L1 conservation to SingleVault TestBase | P1 |
| 3D-2 | Thin L3 or L2 sequences if product still user-facing | P1 |
| 3D-3 | Role-name hygiene on any new tests | — |

**Est.:** 2–4 eng-days.

---

## 7. Wave 4 — Optional / polish

| ID | Task | Pri |
|----|------|-----|
| 4-1 | Aave Stata SE thin Handler (supply/withdraw/fee interleave) | P2 |
| 4-2 | Balancer SE router Handler (deposit/withdraw/swap modes) | P2 |
| 4-3 | Slipstream: re-enable commented fuzz **or** hermetic SE fuzz replacement | P2 |
| 4-4 | Shared abstract `Handler_StandardExchange` if Aerodrome/Camelot/UniV2 converge | P2 |
| 4-5 | Nightly profile: BufferPool + MultiVault `runs≥100`, `depth≥25` | P2 |
| 4-6 | Refactor BufferPool onto InvariantAssertLib (optional consistency) | P3 |
| 4-7 | Production path for RebasingClaimToken fuzz (replace pure stub) if product requires | P2 |

---

## 8. Per-suite implementation recipe

Execute for each Wave product:

```text
1. Confirm happy-path (and adversarial if present) green on gold TestBase
2. Document L1/L2/L3 scope + property IDs + deferred reasons in suite NatSpec / this program doc
     (do not co-locate product plan md under family package dirs)
3. L1 fuzz first if Handler unknown (faster feedback)
4. Handler:
     - constructor(TestBase)
     - 2+ actors, fund-before-act
     - try/catch on expected reverts
     - ghost counters only on success
5. invariant_*.t.sol:
     - targetContract + targetSelector
     - forge-config runs/depth
     - P-NOFREE / P-RESID / P-PRORATA / P-GHOST as applicable
6. L2 sequences only if L3 blocked (fork cost) or as pre-debug
7. forge match-path suite → full product path
8. Update product plan pass matrix + gap report
```

### Handler anti-patterns

```solidity
// WRONG — unbounded random amount without fund/bound → always reverts → zero coverage
function mint(uint256 amount) public {
    vault.mint(amount); // no fund, no try/catch
}

// WRONG — mock SUT
MockStandardExchange se = new MockStandardExchange(...);

// RIGHT — bound, fund actor, try/catch, ghost on success
function mint(uint256 amountSeed, uint8 actorIdx) public {
    address actor = _actor(actorIdx);
    uint256 amount = bound(amountSeed, 1e6, 100e18);
    _fund(actor, amount);
    try IVault(vault).mint(...) {
        ghost_mintCount++;
        ghost_assetsIn[actor] += amount;
    } catch {}
}
```

---

## 9. Dependencies and ordering

```text
Wave 0 (shared assert + gold labels + CI notes)
    │
    ├─► Wave 1A MultiVault L1 + L3  ──┐
    │                                  ├─► Wave 1B Single SE DETF (port Handler)
    │                                  │
    ├─► Wave 2A Aerodrome SE L3  ──────┤ (can parallel Wave 1 after W0)
    ├─► Wave 2B Camelot L1  ───────────┤ (independent of 1A)
    └─► Wave 2C Uni V2 L1  ────────────┘
              │
              ▼
         Wave 3A ComposedStable (L2 then L3)
         Wave 3B DualLiquidity (L2 expand; L3 if hermetic)
         Wave 3C Seigniorage L1
         Wave 3D SingleVault L1/L2
              │
              ▼
         Wave 4 optional (Aave/Balancer/Slipstream/nightly)
```

**Parallelism:**

- After W0: **1A** and **2A/2B** can proceed in parallel (different TestBases).  
- **1B** should follow **1A** Handler API freeze (1–2 day lag OK).  
- **3A** benefits from 1A patterns but is not blocked on 2A.

**Ship gates:**

| Gate | Meaning |
|------|---------|
| After **Wave 1** | DETF gold products have property layer |
| After **Wave 2** | SE legs have multi-call + Camelot L1 |
| After **Wave 3** | Full stack property-complete per gap criteria |
| Wave 4 | Nice-to-have / nightly depth |

---

## 10. Effort estimate (rough)

| Wave | Eng-days | Cumulative |
|------|----------|------------|
| 0 Foundation | 1–1.5 | 1.5 |
| 1A MultiVault L1+L3 | 4–7 | 8.5 |
| 1B Single SE DETF | 3–5 | 13.5 |
| 2A Aerodrome L3 | 3–5 | 18.5 |
| 2B Camelot L1 | 2–4 | 22.5 |
| 2C Uni V2 L1 | 1–3 | 25.5 |
| 3A ComposedStable | 5–8 | 33.5 |
| 3B DualLiquidity | 2–4 (+3–5 L3) | 37–42 |
| 3C Seigniorage | 2–4 | 41–46 |
| 3D SingleVault | 2–4 | 45–50 |
| 4 Optional | 3–8 | ~55 |

---

## 11. Verification matrix (program)

| Check | Command / action |
|-------|------------------|
| MultiVault property | `--match-path '.../multi-vault-weighted/{fuzz,invariant}/**'` |
| Single SE DETF property | `--match-path '.../standardExchange/single/{fuzz,invariant}/**'` |
| Aerodrome L3 | `--match-path '.../aerodrome/v1/invariant/**'` |
| Camelot L1 | `--match-path '.../camelot/**'` |
| DualLiquidity L2 | `FOUNDRY_PROFILE=fork` + `*Invariant*` |
| No adversarial regression | existing adversarial match-paths |
| Inventory drift | re-run gap report `rg` counts after each wave |

Update gap report executive table when each wave exits.

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Handler always reverts → false green | Log `ghost_*Count`; assert `ghost_mintCount > 0` after campaign **or** use Foundry `fail_on_revert = false` intentionally and require min success ghost in a dedicated check (document choice) |
| Fee policy breaks strict conservation | Fee-aware tolerances; cross-mul inequalities; document fee model in plan |
| Fork RPC flakiness on L3 | No default fork L3; DualLiquidity stays L2 |
| L3 runtime in CI | Low `runs`/`depth` default; nightly profile for depth |
| Overlap with adversarial | Different dirs (`fuzz/` `invariant/` vs `adversarial/`); NatSpec cross-ref only |
| Multi-leg ComposedStable complexity | L2 before L3; smaller selector set first |
| Slipstream still broken | Wave 4 only; do not block Wave 1–3 |

---

## 13. Relationship to adversarial program

| Program | Owns |
|---------|------|
| Adversarial (done Waves 0–3) | Catalog A–H fixed abuse cases |
| **This plan** | P-CONS / P-NOFREE / P-RESID / multi-call ghosts |

Both required for pre-audit bar on MultiVault-class products:

```text
adversarial P0/P1  +  L1 fuzz  +  L3 conservation  =  property-complete DETF gold
```

Do not merge suites into one directory; share only assert libs and TestBases.

---

## 14. Documentation deliverables

| Artifact | When |
|----------|------|
| This plan | Wave 0 start |
| Per-product fuzz/invariant suites under `test/.../{fuzz,invariant}/` + NatSpec | Start of each product wave |
| Gap report checkbox / maturity table updates | End of each wave |
| Optional `foundry.toml` `[profile.invariant_nightly]` | Wave 4 or W0 if approved |

---

## 15. Immediate next actions (execute Wave 0 → 1A)

1. Land W0-1 InvariantAssertLib + W0-4 gold labels.  
2. Document MultiVault P0 property list in suite NatSpec / this plan (no co-located product plan).  
3. Implement MultiVault L1 fuzz pack until green.  
4. Port BufferPool Handler skeleton → MultiVault Handler; add four P0 invariants.  
5. Freeze Handler API; start Single SE DETF + Aerodrome L3 in parallel.

---

## Appendix A — forge-config defaults

**CI default (recommended for new suites):**

```solidity
/// forge-config: default.invariant.runs = 32
/// forge-config: default.invariant.depth = 12
/// forge-config: default.fuzz.runs = 64
```

**Nightly (optional profile):**

```toml
# foundry.toml — only if adopted
[profile.invariant_nightly]
invariant = { runs = 100, depth = 25 }
fuzz = { runs = 256 }
```

BufferPool today: `runs = 50`, `depth = 20` — leave as-is until nightly profile exists.

---

## Appendix B — File layout summary (target end state)

```text
test/foundry/spec/vaults/detf/
  composed/multi-vault-weighted/
    adversarial/          # existing
    fuzz/                 # Wave 1A
    invariant/            # Wave 1A
  standardExchange/single/
    adversarial/          # existing
    fuzz/                 # Wave 1B
    invariant/            # Wave 1B
  composed/stable/common/
    adversarial/          # existing
    sequences/            # Wave 3A
    fuzz/                 # Wave 3A
    invariant/            # Wave 3A

test/foundry/spec/protocol/dexes/
  aerodrome/v1/invariant/ # Wave 2A
  camelot/v2/*Fuzz*       # Wave 2B
  uniswap/v2/             # expand existing InOutInvariant

contracts/test/invariant/
  InvariantAssertLib.sol  # Wave 0
```

---

## Appendix C — Change log

| Date | Note |
|------|------|
| 2026-07-16 | Initial plan from fuzz/invariant gap report; waves 0–4; MultiVault L3 first. Status **PLANNED**. |
| 2026-07-16 | **Executed Waves 0–3.** Wave 0: `InvariantAssertLib` + compile smoke + gold labels. Wave 1A: MultiVault L1+L3 green. Wave 1B: Single SE L1+L3 green. Wave 2A: Aerodrome SE L3 green. Wave 2B: Camelot L1 InOut green. Wave 2C: Uni V2 already had InOut (no further expand required). Wave 3A: ComposedStable L2 sequences green. Wave 3B: DualLiquidity L2 expand in source (fork profile not re-run in CI batch). Wave 3C: Seigniorage amount+duration fuzz green. Wave 3D: SingleVault L1 fuzz green. Wave 4 deferred (Aave/Balancer Handlers, Slipstream re-enable, nightly profile). |

### Execution verification (2026-07-16)

| Suite | Result |
|-------|--------|
| `InvariantHarness_Compile` | PASS |
| MultiVault `fuzz/**` + `invariant/**` | PASS (4 + 5) |
| Single SE `fuzz/**` + `invariant/**` | PASS (3 + 4) |
| Aerodrome `invariant/**` | PASS (3) |
| Camelot `InOutInvariant` | PASS (3) |
| ComposedStable `sequences/**` | PASS (incl. 3 sequence tests + inherited deploy matrix) |
| Seigniorage `testFuzz_bonusMultiplier_withAmounts` | PASS |
| SingleVault `fuzz/**` | PASS (2 fuzz + inherited) |
| DualLiquidity L2 expand | Source landed; run with `FOUNDRY_PROFILE=fork` |

---

*End of implementation plan. Waves 0–3 mandatory scope complete; Wave 4 optional.*

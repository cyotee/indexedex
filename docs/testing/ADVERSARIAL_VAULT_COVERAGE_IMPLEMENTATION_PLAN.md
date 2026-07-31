# Adversarial vault coverage — implementation plan

**Status:** IMPLEMENTED (Waves 0–3 mandatory scope)  
**Date:** 2026-07-15 (executed 2026-07-16)  
**Inputs:**

- Gap report: [`docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md`](./ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md)
- Gold suite: `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/`
- Gold law: `AGENTS.md` DETF expectations + `docs/detf/` (co-located family `*_ADVERSARIAL_TEST_PLAN.md` retired in directory reorg — do not restore under package dirs)
- Skills: `crane-adversarial-testing`, `indexedex-adversarial-testing`

**Goal:** Bring peer vault / DETF / SE families to a MultiVault-comparable **P0 (and target P1)** adversarial bar using production-first Foundry tests — not mocks of the SUT.

---

## 1. Success definition

### 1.1 “Adversarially tested” (per product)

A product is **adversarially tested** when:

1. An `adversarial/` suite exists under its test tree (spec or fork as appropriate).
2. Every **P0** catalog ID applicable to that product has a real test driving production entry points, **or** is explicitly deferred with NatSpec reason.
3. Target **P1** IDs are implemented or deferred with reason.
4. `forge test --match-path '<product>/adversarial/**'` exits 0.
5. Full product match-path (happy + adversarial) exits 0.
6. Product-local plan/checklist updated (status + pass matrix).

### 1.2 Program-level done

| Wave | Done when |
|------|-----------|
| 0 | Hygiene + shared harness landed; stubs flagged |
| 1 | Single SE DETF + ComposedStable adversarial P0 green |
| 2 | DualLiquidity catalog suite + SE shared harness P0 green |
| 3 | SingleVaultDetf + Seigniorage P0 green (or deferred with product decision) |
| Optional | MultiVault remaining P2; BasicVault if still user-facing |

### 1.3 Non-negotiable testing rules

1. **Production-first:** CREATE3 + FactoryService + registry DFPkg path (`indexedex-testing`).
2. **No** `MockStandardExchange` / mock manager / mock registry as SUT or leg.
3. Allowed harnesses only: hostile ERC20, attacker EOAs, mintable underlyings, multicall bots.
4. Drive real entry points (`exchangeIn`, `bond`, `redeemClaim`, SE deposit/withdraw, etc.).
5. Exploit **blocked** or **documented intentional economic risk** with hard safety invariants.
6. Real profitable unbounded exploit → **production fix before green tests**.
7. DETF **role names only** (`rateAsset`, `pairToken`, `underlyingVault`, `rebasingClaimToken`) — no brand reintroduction on new surfaces.

---

## 2. Catalog (canonical IDs)

Use these IDs in test names: `test_<ID>_<slug>()`. Full definitions: Crane skill `references/attack-catalog-template.md` and MultiVault adversarial plan.

| Pri | IDs (DETF-class) | Theme |
|-----|------------------|--------|
| **P0** | A1, A3, B1*, B3*, C1–C3, D2, D3, D6, E1, E5, F2–F3, H2, H3 | Donation free-mint / free principal, reentrancy, claim authority, residual, access, atomic fail |
| **P1** | A2, D4, D5, E4, F1, F4, G1 | Donate product token, lock clamp, non-dilution, immutability, nested |
| **P2** | A4–A5, B2, B4–B5, C4–C5, D7, E2–E3, G2–G3, H1 | Dust grief, sandwich, cross-leg desync, gas N-max, peer extras |

\* B1/B3 **N/A** for pure SE vaults without synthetic thresholds; substitute deposit/withdraw conservation and route guards.

**SE-class P0 subset:** A1, C (deposit/withdraw path), E1, E5, H3, F (no free cut if unowned).

---

## 3. Shared foundation (Wave 0)

### 3.1 Purpose

Avoid copy-paste thrash across families; keep MultiVault as behavior gold, extract only stable harness bits.

### 3.2 Deliverables

| ID | Task | Output | Est. |
|----|------|--------|------|
| W0-1 | Shared hostile ERC20 + reentry target | `contracts/test/adversarial/HostileReentrantShare.sol`, `DetfReentryTarget.sol` (or under `contracts/vaults/test/adversarial/`) | 0.5 d |
| W0-2 | Shared residual helper pattern | NatSpec snippet / optional `AdversarialAssertLib` with `_assertNoFreeInventory(instance, shareTokens[])` | 0.5 d |
| W0-3 | Tag existing partial security tests | NatSpec `@dev BASE-C` / `A3-class` on Single SE reentrancy, DualLiquidity ShareInflation, etc. | 0.5 d |
| W0-4 | Stub hygiene | Header on `DETFNFTVault.t.sol` + `RebasingClaimTokenRedemption.t.sol`: **not production-path coverage**; open follow-up task W3-stub | 0.25 d |
| W0-5 | Program checklist in gap report | Link this plan from gap report “Revision history” | 0.1 d |

### 3.3 Exit criteria

- [ ] Shared harness compiles in isolation (imported by a smoke test or MultiVault optional refactor — **do not break MultiVault**).
- [ ] Stub files explicitly labeled.
- [ ] No requirement to refactor MultiVault onto shared harness in Wave 0 (optional later).

### 3.4 Non-goals Wave 0

- Implementing peer adversarial suites (Wave 1+).
- Replacing MultiVault adversarial files wholesale.

---

## 4. Wave 1 — Peer DETF ports

### 4.1 SingleStandardExchangeDETF (Wave 1A) — **first**

#### 4.1.1 Layout

```text
# Product-local co-located plan md is retired; track IDs in suite NatSpec + this program doc.
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/
  TestBase_SingleStandardExchangeDETF_Adversarial.sol
  Adversarial_SingleSE_P0.t.sol     # consolidated P0 suite (guards, access, reentrancy, donation, bond/claim, economic)
  # optional split files if re-partitioned later:
  # Adversarial_Guards.t.sol, Adversarial_Access.t.sol, …
```

#### 4.1.2 Task checklist

| ID | Task | Depends | Pri |
|----|------|---------|-----|
| 1A-0 | Write product adversarial plan md (copy MultiVault structure; list applicable IDs) | W0 | — |
| 1A-1 | `TestBase_*_Adversarial`: extend `TestBase_SingleStandardExchangeDETF`; attacker/victim; hostile share deploy path; `_openLive`; residual helpers | 1A-0 | — |
| 1A-2 | Guards/Access: E5, H3, F1–F4 (dedupe with existing Guards via NatSpec, not duplicate flaky cases) | 1A-1 | P0/P1 |
| 1A-3 | BondClaim: D2, D3, D6 (+ D4/D5 P1) | 1A-1 | P0 |
| 1A-4 | Reentrancy: C1 init/first-bond, C2 redeem, C3 mint→bond (C3 may already exist — assert or import, expand C1/C2) | 1A-1 | P0 |
| 1A-5 | Donation: A1, A3 (+ A2 P1) | 1A-1 | P0 |
| 1A-6 | Economic + Price: E1, E4; B1 seigniorage bounds; B3 gates | 1A-1 | P0 |
| 1A-7 | Griefing H2 claim atomicity | 1A-1 | P0 |
| 1A-8 | Nested G1 (P1) if stack allows | 1A-1 | P1 |
| 1A-9 | Green: adversarial path + full single SE path | 1A-2…1A-8 | — |
| 1A-10 | Update plan pass matrix + deferred NatSpec | 1A-9 | — |

#### 4.1.3 Verification

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**'
# Optional fork matrix smoke (if touched wiring):
# forge test --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**'
```

#### 4.1.4 Exit

- [ ] All applicable P0 green  
- [ ] P1 implemented or deferred with reason  
- [ ] Plan status **IMPLEMENTED (P0/P1)**  

**Est.:** 4–6 eng-days (hermetic Aerodrome SE first).

---

### 4.2 ComposedStableCommonDetf (Wave 1B)

#### 4.2.1 Layout

```text
# Product-local co-located plan md is retired; track IDs in suite NatSpec + this program doc.
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/
  Adversarial_ComposedStable_P0.t.sol
```

#### 4.2.2 Task checklist

| ID | Task | Pri | Notes |
|----|------|-----|-------|
| 1B-0 | Product plan md | — | Multi-leg + rebasing claim specific threats |
| 1B-1 | Adversarial TestBase from `TestBase_ComposedStableCommonDetf` | — | |
| 1B-2 | Reuse / extend claim-token “no burn on failed exit” as H2 baseline; add DETF-level H2 | P0 | Existing RebasingDETFTokenBehavior is partial |
| 1B-3 | D2–D6 bond/claim authority on production graph | P0 | |
| 1B-4 | A1–A3 donation | P0 | |
| 1B-5 | C1–C3 reentrancy (hostile share as leg if product accepts; else hostile rateAsset carefully) | P0 | |
| 1B-6 | E1 multi-leg residual free inventory | P0 | |
| 1B-7 | F access | P0/P1 | |
| 1B-8 | B route/rate grief (P1); defer B5 MaxInRatio with reason if only clean-revert | P1 | |
| 1B-9 | Green paths + plan matrix | — | |

#### 4.2.3 Verification

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**'
```

**Est.:** 5–7 eng-days (multi-leg complexity).

---

## 5. Wave 2 — Protocol vaults + SE surface

### 5.1 DualLiquidityLinkedCrossVersionUniswapVault (Wave 2A)

#### 5.1.1 Approach

Fork-first (gold TestBase is fork). **Do not invent hermetic dual-liquidity if ports incomplete.** Catalog-ize existing security files; fill true gaps only.

#### 5.1.2 Layout

```text
test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/adversarial/
  TestBase_DualLiquidity_Adversarial.sol   # thin wrapper over existing TestBase
  Adversarial_Catalog.t.sol                # or split by category
  # Prefer: NatSpec map existing ShareInflation / Reentrancy / Residual tests → IDs
  # Add only missing P0 cases as new files
```

#### 5.1.3 Tasks

| ID | Task | Pri |
|----|------|-----|
| 2A-0 | Inventory existing tests → ID map in product plan md | — |
| 2A-1 | Tag ShareInflation = A3-class; Reentrancy = C; Residual = E/H | — |
| 2A-2 | Fill missing: H3 failed deposit residual, C cross-entry if incomplete, F access gaps | P0 |
| 2A-3 | P1: minOut sandwich / best-route bounds documentation | P1 |
| 2A-4 | Green fork adversarial + existing dual-liquidity suite | — |

#### 5.1.4 Verification

```bash
forge test --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/adversarial/**'
# Full dual-liquidity suite (RPC-dependent):
forge test --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/**'
```

**Est.:** 3–5 eng-days (+ RPC flakiness buffer).

---

### 5.2 Shared Standard Exchange adversarial harness (Wave 2B)

#### 5.2.1 Goal

One harness, N protocol TestBases (Aerodrome hermetic first, Camelot second, Uni V2 third; Uni V4 / Aave Stata when stable).

#### 5.2.2 Layout

```text
test/foundry/spec/vaults/standard-exchange/adversarial/   # or under protocols/dexes/_shared/
  TestBase_StandardExchange_Adversarial.sol               # abstract: virtual vault + share
  Adversarial_SE_Donation.t.sol
  Adversarial_SE_Reentrancy.t.sol
  Adversarial_SE_Residual.t.sol
  Adversarial_SE_Guards.t.sol
  instances/
    AerodromeSE_Adversarial.t.sol    # inherits + wires TestBase_Aerodrome...
    CamelotSE_Adversarial.t.sol
    # UniV2 / UniV4 / Aave later
```

#### 5.2.3 SE P0 cases

| ID | Case |
|----|------|
| A1 | Transfer underlyings/LP to vault without deposit credit |
| C | Hostile token on deposit/withdraw/swap callback path → IsLocked |
| E1 | Deposit→withdraw conservation (fee-aware) |
| E5 | Zero / deadline |
| H3 | Failed minOut / slippage leaves no free inventory |
| F | Instance not freely diamondCut (if applicable) |

#### 5.2.4 Tasks

| ID | Task |
|----|------|
| 2B-0 | Abstract TestBase + SE plan md |
| 2B-1 | Aerodrome instance green |
| 2B-2 | Camelot instance green |
| 2B-3 | Document Uni V4 / Aave as Wave 2B-extend (defer OK) |
| 2B-4 | Ensure existing `*_ReentrancyGuard` tests NatSpec-linked, not deleted |

**Est.:** 4–6 eng-days for Aerodrome+Camelot.

---

## 6. Wave 3 — Secondary products + stub replacement

### 6.1 SingleVaultDetf (`composed/single`) (Wave 3A)

| ID | Task | Pri |
|----|------|-----|
| 3A-0 | Product plan; **role-name cleanup** on any new/edited tests | — |
| 3A-1 | Adversarial TestBase (production path only) | — |
| 3A-2 | C1–C3 reentrancy (none today) | P0 |
| 3A-3 | A free-transfer abuse vs intentional `donate()` (document distinction) | P0 |
| 3A-4 | D claim/NFT authority; H2/H3 | P0 |
| 3A-5 | Bridge grief (replay / non-relayer already partial) P1 expansion | P1 |
| 3A-6 | Green + plan matrix | — |

**Est.:** 4–6 eng-days.

### 6.2 Seigniorage DETF (Wave 3B)

| ID | Task | Pri |
|----|------|-----|
| 3B-0 | Product plan (spec + fork) | — |
| 3B-1 | Port D/C/H/E5; leverage existing peg gates + dust/FOT | P0 |
| 3B-2 | onlyOwner NFT already partial — complete F matrix | P0/P1 |
| 3B-3 | Green hermetic first; fork smoke if required | — |

**Est.:** 3–5 eng-days.

### 6.3 Protocol claim/NFT stubs (Wave 3-stub)

| ID | Task |
|----|------|
| 3S-1 | Replace pure placeholders in `DETFNFTVault.t.sol` with production DFPkg deploy + real calls **or** delete and rely on DETF-integrated D-class tests only (document decision) |
| 3S-2 | Same for `RebasingClaimTokenRedemption.t.sol` — prefer real claim token via DetfPkgFactoryService |

**Est.:** 2–4 eng-days if full replace; 0.5 d if explicit deprecation.

### 6.4 BasicVault (Wave 3C — optional)

Only if BasicVault remains a direct user deposit surface outside SE packaging.

| ID | Task |
|----|------|
| 3C-1 | Minimal adversarial: A1, C, E1, H3 on production BasicVault facet package | P1/P2 |

**Default:** **defer** with reason in program checklist unless product prioritizes.

### 6.5 MultiVault P2 (Wave 3D — optional)

| ID | Task |
|----|------|
| 3D-1 | Implement or reaffirm deferrals for A4–A5, B2/B4–B5, C4–C5, D7, E2–E3, G2–G3, H1 | P2 |

Non-blocking for peer ports.

---

## 7. Per-suite implementation recipe (every product)

Execute in this order for each wave item:

```
1. Confirm happy-path green on gold TestBase
2. Map P0 list + deferred IDs in suite NatSpec / this program doc (do not co-locate product plan under family package)
3. TestBase_*_Adversarial (live helpers, attacker, residual)
4. P0 files: Guards/Access → BondClaim/Authority → Reentrancy → Donation → Economic/Price → Griefing
5. P1 files or NatSpec defer
6. forge adversarial path → full product path
7. Update plan status + pass matrix; update gap report checkboxes
```

Copy structure and assertion style from MultiVault adversarial, not happy-path only tests.

---

## 8. Dependencies and ordering

```text
Wave 0 (shared harness + hygiene)
    │
    ├─► Wave 1A Single SE DETF  ──┐
    │                              ├─► (optional) G1 nested uses both
    └─► Wave 1B ComposedStable  ──┘
              │
              ▼
         Wave 2A DualLiquidity (fork; independent of 1B)
         Wave 2B SE shared (independent; can parallel 2A)
              │
              ▼
         Wave 3A SingleVaultDetf
         Wave 3B Seigniorage
         Wave 3-stub claim/NFT
         Wave 3C BasicVault (optional)
         Wave 3D MultiVault P2 (optional)
```

**Parallelism:** 1A and 1B can proceed in parallel after W0. 2A (fork) and 2B (hermetic SE) are independent. Wave 3 after Wave 1 preferred (shared patterns mature).

---

## 9. Effort estimate (rough)

| Wave | Eng-days | Cumulative |
|------|----------|------------|
| 0 Foundation | 1.5–2 | 2 |
| 1A Single SE | 4–6 | 8 |
| 1B ComposedStable | 5–7 | 15 |
| 2A DualLiquidity | 3–5 | 20 |
| 2B SE shared (2 protocols) | 4–6 | 26 |
| 3A SingleVault | 4–6 | 32 |
| 3B Seigniorage | 3–5 | 37 |
| 3-stub | 0.5–4 | 41 |
| Optional 3C/3D | 2–5 | ~45 |

Ship gates can stop after **Wave 1** for “peer DETFs adversarially tested,” or after **Wave 2** for “vault stack + SE legs.”

---

## 10. Acceptance criteria (program)

### Wave 0

- [ ] Shared harness files exist and compile  
- [ ] Stub suites labeled  
- [ ] Gap report links this plan  

### Wave 1 complete

- [ ] Single SE DETF adversarial P0 green + full single path green  
- [ ] ComposedStable adversarial P0 green + full stable path green  
- [ ] Both product plans **IMPLEMENTED (P0/P1)** or P1 deferred documented  

### Wave 2 complete

- [ ] DualLiquidity catalog + missing P0 green (fork)  
- [ ] ≥2 SE protocols on shared harness green  

### Wave 3 complete (if in scope)

- [ ] SingleVaultDetf and/or Seigniorage P0 green per product decision  
- [ ] Stub replace/deprecation decision executed  

### Global

- [ ] MultiVault path remains green (no regressions)  
- [ ] No Mock SE SUT introduced  
- [ ] Role naming respected on new DETF tests  

---

## 11. Risk register

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in multi-leg setups | Struct helpers; N=1/N=2 attack paths (MultiVault lesson) |
| Fork RPC flakiness (DualLiquidity) | Pin block; retry policy; hermetic when possible |
| Seigniorage / SingleVault naming debt | Role names only on new files; fix brands only when editing |
| Shared harness breaks MultiVault | Wave 0 optional adopt; MultiVault freeze unless deliberate refactor |
| Claim path differs per DETF | Map D2 to actual API (`redeemClaim` vs `redeemPosition` vs underwrite) in product plan before coding |
| Intentional seigniorage “profit” (B1) | Document bounds + hard safety invariants (MultiVault B1 pattern) |
| Scope creep P2 | Explicit defer NatSpec; do not block wave exit |

---

## 12. Verification commands (summary)

```bash
# Gold — must stay green throughout
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**'

# Wave 1
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/**'
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/**'

# Wave 2
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/adversarial/**'
forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**'

# Program sweep (when multiple exist)
forge test --match-path '**/adversarial/**'
```

Capture logs under session scratch when running under a goal harness.

---

## 13. Documentation touchpoints

| Doc | Update when |
|-----|-------------|
| This plan | Checkbox / status per wave |
| Gap report | Mark families Full/Partial as waves complete |
| Product adversarial suite under `test/.../adversarial/` + NatSpec | Per product exit |
| `AGENTS.md` | Only if new skill paths or mandatory reading changes (already points to adversarial skills) |

---

## 14. Task checklist (master)

### Wave 0

- [x] W0-1 Shared HostileReentrantShare + ReentryTarget (`contracts/test/adversarial/`)  
- [x] W0-2 Residual assert helper pattern (`AdversarialAssertLib`)  
- [x] W0-3 Tag partial security tests with catalog IDs  
- [x] W0-4 Label protocol claim/NFT stub suites (stub-not-production-path NatSpec)  
- [x] W0-5 Cross-link gap report ↔ this plan  

### Wave 1A — Single SE DETF

- [x] 1A-0 Product adversarial plan  
- [x] 1A-1 Adversarial TestBase  
- [x] 1A-2 Guards + Access  
- [x] 1A-3 BondClaim D2–D5 (D6 N/A no claim token)  
- [x] 1A-4 Reentrancy C1–C3  
- [x] 1A-5 Donation A1–A3  
- [x] 1A-6 Economic + Price E1/E4/B1/B3  
- [x] 1A-7 Griefing H3 (H2 claim N/A → sellPosition)  
- [x] 1A-8 Nested G1 deferred (ComposedStable matrix)  
- [x] 1A-9 Forge green (20/20 adversarial)  
- [x] 1A-10 Pass matrix  

### Wave 1B — ComposedStable

- [x] 1B-0…1B-9 P0 suite on IntegratedDeploy production graph (17 green; C deferred P2)  

### Wave 2A — DualLiquidity

- [x] 2A-0…2A-4 Catalog map + adversarial fill; run with `FOUNDRY_PROFILE=fork`  

### Wave 2B — SE shared

- [x] 2B-0…2B-4 Aerodrome + Camelot adversarial P0 (9 green)  

### Wave 3

- [x] 3A SingleVaultDetf P0 (adversarial/ suite green; C deferred P2)  
- [x] 3B Seigniorage P0 (adversarial/ suite green; C deferred P2)  
- [x] 3S Stub suites labeled stub-not-production-path (DETFNFTVault + RebasingClaimToken)  
- [x] 3C BasicVault optional — deferred (not user-facing deposit surface this cycle)  
- [x] 3D MultiVault P2 optional — deferred (P0/P1 already complete)  

### Program exit

- [x] MultiVault regression 72/72 green  
- [x] No MockStandardExchange SUT  
- [x] Scratch forge logs under implementer scratch dir  

---

## 15. Revision history

| Date | Change |
|------|--------|
| 2026-07-15 | Initial program plan from gap report + MultiVault gold + adversarial skills |
| 2026-07-16 | Executed Waves 0–3; fixed fork BufferPool deployPool arity for FOUNDRY_PROFILE=fork compile |

---

## See also

- [`ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md`](./ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md)
- `lib/crane/.claude/skills/crane-adversarial-testing/`
- `.claude/skills/indexedex-adversarial-testing/`
- MultiVault adversarial suite (implementation reference)

# Adversarial vault coverage — gap report

**Date:** 2026-07-15  
**Scope:** IndexedEx vault / DETF / Standard Exchange surfaces vs production-first adversarial methodology (`crane-adversarial-testing` + `indexedex-adversarial-testing`).  
**Gold standard:** `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/` (P0/P1 green; plan: `MultiVaultWeightedDetf_ADVERSARIAL_TEST_PLAN.md`).

This report inventories **where formal adversarial suites are missing**, what **baseline** abuse coverage already exists (happy-path-adjacent or partial), and a **recommended port order**. It is not a claim that other products have zero security tests — only that they lack a catalog-driven adversarial program comparable to MultiVaultWeightedDetf.

---

## Executive summary

| Maturity | Product families |
|----------|------------------|
| **Full adversarial suite (P0/P1)** | MultiVaultWeightedDetf; SingleStandardExchangeDETF; ComposedStableCommonDetf (P0; C P2 deferred) |
| **Adversarial P0 + catalog** | DualLiquidity (catalog + fill; `FOUNDRY_PROFILE=fork`); SE Aerodrome+Camelot shared adversarial; SingleVaultDetf P0; Seigniorage P0 |
| **Stub labeled / optional deferred** | Protocol DETFNFTVault + RebasingClaimToken pure stubs (labeled); BasicVault optional defer; MultiVault P2 optional |
| **Dedicated `adversarial/`** | MultiVault, Single SE, ComposedStable, DualLiquidity (fork), SE shared, SingleVault, Seigniorage |

**Highest ROI ports (P0 next):**

1. **SingleStandardExchangeDETF** — closest architecture to MultiVault; matrix already green; MultiVault plan Phase 6 peer #1.  
2. **ComposedStableCommonDetf** (+ rebasing claim token) — multi-leg reserve, claim redeem, nested composition.  
3. **DualLiquidityLinkedCrossVersionUniswapVault** — strong fork security slices; needs catalog consolidation + missing P0 IDs.  
4. **Standard Exchange vaults** (shared SE surface) — cross-protocol residual, donation, route abuse.  
5. **SingleVaultDetf / SeigniorageDETF** — product-specific bond/redeem/bridge surfaces.

---

## Methodology used for this report

For each product family:

1. Locate production package + TestBase.  
2. List existing `test/foundry/spec/**` and `test/foundry/fork/**` coverage.  
3. Map against catalog IDs (A donation, B manip, C reentrancy, D authority/claim, E accounting, F access, G composition, H grief).  
4. Classify: **Full** / **Partial** / **Gap** / **N/A** / **Stub risk**.  
5. Recommend suite path + priority.

Reference catalog: `lib/crane/.claude/skills/crane-adversarial-testing/references/attack-catalog-template.md`.

---

## Coverage matrix (catalog × product)

Legend: **F** = full formal adversarial suite · **P** = partial baseline · **G** = gap (needs adversarial work) · **N** = not applicable · **S** = stub/pure placeholder risk

| ID / theme | MultiVault | Single SE DETF | ComposedStable | SingleVaultDetf | DualLiquidity | SE vaults* | Seigniorage | BasicVault | Protocol claim/NFT |
|------------|------------|----------------|----------------|-----------------|---------------|------------|-------------|------------|--------------------|
| A1–A3 Donation | **F** | **G** | **G** | **P**† | **P**‡ | **G** | **P**§ | **G** | **G** |
| B1/B3 Price/threshold manip | **F** | **P** (gates only) | **G** | **P** (mint gate) | **P** (rate extremes) | **G** | **P** (peg gates) | N | N |
| C1–C3 Reentrancy | **F** | **P** (C mint+bond only) | **G** | **G** | **P** (reentrancy files) | **P** (some guards) | **G** | **G** | **G** |
| D2–D6 Claim/bond authority | **F** | **G** (bonding exists; no D2 suite) | **P** (redeem path exists) | **P** (sell/redeem happy) | N | N | **P** (NFT onlyOwner) | N | **S**/G |
| E1/E5 Residual + zero/deadline | **F** | **P** (E5 guards; residual burn) | **P** (exchange happy) | **P** | **P** (residual file) | **P** | **P** | **G** | **S** |
| F Access / immutability | **F** | **G** | **G** | **G** | **P** (immutability) | **G** | **P** | **G** | **S**/G |
| G Nested composition | **F** | **P** (stable matrix) | **G** as outer SUT | **G** | N | N | N | N | N |
| H2–H3 Atomic fail / residual | **F** | **G** | **P** (claim fail no burn) | **G** | **P** | **G** | **G** | **G** | **S** |
| Formal `adversarial/` dir | **Yes** | No | No | No | No | No | No | No | No |

\* SE vaults = Aerodrome / Camelot / Uni V2 / Uni V4 / Aave Stata Standard Exchange packages.  
† SingleVault has intentional `donate()` API tests (product feature), not adversarial free-transfer donation.  
‡ DualLiquidity has `ShareInflation` (BPT donation / front-run).  
§ Seigniorage has dust / fee-on-transfer secure transfer tests.

---

## Product-by-product gaps

### 1. MultiVaultWeightedDetf — **baseline complete (P0/P1)**

| Item | Detail |
|------|--------|
| Path | `test/.../multi-vault-weighted/adversarial/` |
| Status | **IMPLEMENTED** — ~30 adversarial + happy matrix green |
| Remaining | MultiVault **P2 only** (A4–A5, B2/B4–B5, C4–C5, D7, E2–E3, G2–G3, H1); optional peer ports **are this report** |

No blocking gap for this family.

---

### 2. SingleStandardExchangeDETF — **highest-priority port**

| Item | Detail |
|------|--------|
| Production | `contracts/vaults/detf/standardExchange/single/` |
| TestBase | `TestBase_SingleStandardExchangeDETF.sol` |
| Existing specs | Deploy, Mint, Burn, Bonding, Guards, Info, Requirements, Reentrancy, ComposedStable matrix; fork matrices DualLiquidity / Uni V4 |
| Plan callout | MultiVault adversarial plan Phase 6: port A1–A3, B1, C*, D2-class, E1, E4, F* |

**Already partial:**

- **C (partial):** `SingleStandardExchangeDETF_Reentrancy.t.sol` — mint nested + mint→bond → `IsLocked` (BASE-R1/R2 class).  
- **E5 / routes:** Guards zero amount, deadline, unsupported route.  
- **E residual:** Requirements burn cleans residual; non-dilution on mint.  
- **B gates:** Bonding/info threshold after bootstrap; Requirements synthetic mint gate.  
- **G partial:** ComposedStable outer matrix; fork DualLiquidity/Uni V4 as underlying SE.

**Critical gaps (formal adversarial missing):**

| Priority | IDs | Gap |
|----------|-----|-----|
| P0 | A1, A3 | Direct transfer vault shares / BPT to diamond without free mint or free principal redeem |
| P0 | D2, D3, D6 | redeemClaim / sellNFT authority (no free BPT; double redeem; over-claim) — if claim path wired |
| P0 | C1, C2 | Reenter `initializeReserve`/first-bond and redeem/claim (beyond mint/bond only) |
| P0 | E1, H2, H3 | Round-trip conservation; failed redeem atomicity; failed mint residual |
| P0 | F2–F3 | Bond NFT + claim onlyOwner |
| P1 | A2, B1, B3, E4, F1, F4 | Donate DETF; skew arb bounds; threshold coupling; non-dilution; no cut; immutable weights |

**Recommended suite path:**

```text
test/foundry/spec/vaults/detf/standardExchange/single/adversarial/
  TestBase_SingleStandardExchangeDETF_Adversarial.sol
  Adversarial_*.t.sol  # mirror MultiVault layout
```

Reuse MultiVault harness patterns; underlying SE via existing matrix providers (Aerodrome hermetic first).

---

### 3. ComposedStableCommonDetf (+ RebasingDETFToken) — **high priority**

| Item | Detail |
|------|--------|
| Production | `contracts/vaults/detf/composed/stable/common/` |
| TestBase | `TestBase_ComposedStableCommonDetf.sol` (+ Components) |
| Existing | Deploy, exchangeIn/burn, bonding facet, integrated deploy (bond→sell→redeem), rebasing token behavior/pricing |

**Already partial:**

- **H2-class on claim token:** `RebasingDETFTokenBehavior` — exchangeIn/Out reverts when claim liquidity fails **without burning shares**.  
- Happy bond / sellNFT / redeem on integrated deploy.  
- Pricing synthetic helpers.

**Critical gaps:**

| Priority | Theme | Gap |
|----------|-------|-----|
| P0 | A / D | Donation of legs or BPT; redeem without claim; double redeem; over-claim |
| P0 | C | Hostile reentrancy on multi-leg join / mint / bond / redeem |
| P0 | E / H | Multi-leg residual free inventory; failed path atomicity on DETF diamond (not only claim token) |
| P1 | B | Stable-pool / multi-leg rate desync; route selection grief (“most liquid”) |
| P1 | G | As outer DETF with nested SE DETF legs — reverse of Single SE matrix |
| P1 | F | onlyOwner / immutability on bond NFT vault + claim |

**Note:** Multi-leg + stable topology has more grief surface (B5 MaxInRatio, dust legs) than single-leg SE DETF — budget extra H/B cases.

---

### 4. SingleVaultDetf (`composed/single`) — **medium–high; naming debt**

| Item | Detail |
|------|--------|
| Production | `contracts/vaults/detf/composed/single/` |
| Existing | Mint/donate/capture seigniorage, sellNFT/redeemPosition, auction bond, bridge transport, facet declaration |

**Already partial:**

- Product **donate** API (WETH → protocol NFT shares; DETF donate burns supply).  
- Mint gate when not allowed; fee split destinations.  
- Bridge: non-relayer receive reverts.  
- Auction bootstrap path.

**Critical gaps:**

| Priority | Theme | Gap |
|----------|-------|-----|
| P0 | C | No reentrancy suite at all |
| P0 | A adversarial | Direct transfer abuse distinct from intentional `donate()` |
| P0 | D | Free principal / double redeem / onlyOwner NFT+claim |
| P0 | H | Failed redeem/mint residual + atomicity |
| P1 | B | Threshold + seigniorage capture abuse |
| P1 | Bridge | Replay / wrong chain / partial bridge grief (beyond non-relayer) |

**Risk:** Some tests still use brand-oriented names (`mintWithWeth`, RICH/RICHIR paths). Adversarial ports must use **role names** (`rateAsset`, etc.) per `AGENTS.md` — fix naming when touching those files.

---

### 5. DualLiquidityLinkedCrossVersionUniswapVault — **partial security; needs catalog suite**

| Item | Detail |
|------|--------|
| Production | `contracts/vaults/protocol/uniswap/crossVersion/` |
| Mode | Primarily **Base fork** gold TestBase |
| Existing security-ish | ShareInflation (donation), Reentrancy, ReentrancyRedeem, Residual, Guards, Immutability, RateExtremes, Invariants/handler, Fees |

**Already strong partial:**

- **A-class:** BPT donation cannot steal victim deposit; front-run donation.  
- **C-class:** reentrancy + redeem reentrancy files.  
- **E/H residual:** dedicated residual tests.  
- **F:** immutability.  
- **B:** rate extremes.

**Gaps vs formal adversarial program:**

| Priority | Gap |
|----------|-----|
| P0 | Consolidate into `adversarial/` with ID tags; ensure C cross-entry matrix complete |
| P0 | Failed-path residual / minOut grief (H3) if not already exact |
| P1 | Explicit access (F2-style) for any onlyOwner inventory policies |
| P1 | Sandwich / best-route abuse with minOut bounds |
| P2 | Full MEV reconstruction (non-goal unless required) |

**Recommended:** Add `test/foundry/fork/.../adversarial/` **or** hermetic port if protocol ports allow — prefer extending existing fork TestBase without mocking SUT.

---

### 6. Standard Exchange vault packages (protocol legs)

Families with substantial happy-path specs: Aerodrome V1, Camelot V2, Uniswap V2/V4, Aave V3 Stata, Balancer SE router / buffer pools.

| Item | Detail |
|------|--------|
| Partial | Aerodrome + Camelot **ReentrancyGuard** tests; Uni V2 slippage; Balancer router query-hook abuse / deadline / prepay lock |
| Gap | No product-level `adversarial/` catalog across SE packages |

**Shared SE P0 port set (one harness, N protocol TestBases):**

| ID | Case |
|----|------|
| A1 | Donate underlyings / LP to vault diamond without deposit credit |
| C | Hostile token reentrancy on deposit/withdraw/swap paths |
| E1 | Deposit→withdraw conservation (net of fees) |
| E5 / H3 | Zero/deadline/minOut fail leaves no free inventory |
| F | No unauthorized diamondCut / owner on instances if unowned |

Do **not** mock SE SUT; use gold protocol TestBases.

---

### 7. Seigniorage DETF + Seigniorage NFT vault

| Item | Detail |
|------|--------|
| Spec | Exchange routes, integration underwrite/redeem, NFT lock, token transfer dust/FOT |
| Fork | Base seigniorage integration / routes / NFT |

**Partial:** peg gates, onlyOwner lock, dust inflation on secure transfer, deadline/invalid route.

**Gaps:** formal C suite; A free-transfer donation; H2 atomicity on underwrite/redeem fail; F immutability/cut; economic B skew if rate-target pool exists.

Priority: **after** Single SE + ComposedStable unless Seigniorage is next ship gate.

---

### 8. BasicVault / multi-asset basic facets

| Item | Detail |
|------|--------|
| Spec | Token transfer + Permit2 |
| Fork | Base/Eth Permit2 transfer |

**Gap:** nearly all adversarial catalog IDs for a general vault (donation, reentrancy, residual, access). Lower product priority if BasicVault is infrastructure-only under SE/DETF — still needed if user-facing deposits hit BasicVault paths directly.

---

### 9. Protocol DETFNFTVault + RebasingClaimToken (unit suite risk)

| Files | Concern |
|-------|---------|
| `test/foundry/spec/vaults/protocol/DETFNFTVault.t.sol` | Many tests marked `public pure` / placeholder style |
| `test/foundry/spec/vaults/protocol/RebasingClaimTokenRedemption.t.sol` | Same pattern — not driving production deploy path |

**Gap type: S (stub risk)** — these do **not** count as adversarial or production-first coverage for claim/NFT authority (D2-class). Real D2/D6/H2 coverage today lives on **integrated DETF** tests (MultiVault adversarial; ComposedStable claim token behavior).

**Action:** Either (a) replace stubs with production DFPkg-deployed NFT/claim tests, or (b) document as non-coverage and rely on DETF-integrated adversarial only. Prefer (a) for reusable authority surfaces.

---

## Priority roadmap (suggested implementation order)

### Wave 0 — Hygiene (1–2 days)

- [ ] Tag existing partial security tests with catalog IDs in NatSpec (Single SE reentrancy = BASE-C; DualLiquidity ShareInflation = A3-class, etc.).  
- [ ] Flag protocol `DETFNFTVault` / `RebasingClaimToken` pure suites as stubs in file header or replace.

### Wave 1 — Peer DETF ports (1–2 weeks)

| Order | Product | Deliverable |
|-------|---------|-------------|
| 1 | SingleStandardExchangeDETF | Full `adversarial/` P0 + plan md |
| 2 | ComposedStableCommonDetf | Full `adversarial/` P0 (claim + multi-leg focus) |
| 3 | MultiVault P2 (optional) | Close deferred MultiVault IDs if still needed |

### Wave 2 — Protocol vaults (1–2 weeks)

| Order | Product | Deliverable |
|-------|---------|-------------|
| 1 | DualLiquidity | Catalog suite on fork TestBase; fill missing P0 |
| 2 | SE shared adversarial | Parameterized harness × Aerodrome + Camelot (+ Uni V2 if capacity) |
| 3 | SingleVaultDetf | Adversarial + role-name cleanup on touched tests |

### Wave 3 — Secondary

| Product | Notes |
|---------|-------|
| Seigniorage DETF | Port D/C/H after SE/DETF waves |
| BasicVault | Only if direct user deposit surface ships |
| Uni V4 SE / Aave Stata | Fold into SE shared harness |
| MultiVault remaining P2 | Non-blocking |

---

## Shared work products (do once, reuse)

1. **Adversarial plan template** — already in `crane-adversarial-testing/references/attack-catalog-template.md`.  
2. **Hostile share + reentry target** — copy MultiVault `AdvRecordingReentrantShare` / `AdvReentryTarget` into a shared `contracts/test/adversarial/` or per-family TestBase (avoid cross-package hard deps if circular).  
3. **`_assertNoFreeInventory` / residual** helpers — pattern from MultiVault TestBase.  
4. **Checklist** — `indexedex-adversarial-testing/references/detf-adversarial-checklist.md`.  
5. **Acceptance bar per product:**  
   - P0 IDs green under `adversarial/**`  
   - Full product match-path still green  
   - Deferred IDs NatSpec documented  

---

## Out of scope for adversarial expansion (unless product prioritizes)

- Frontend / Permit2 UI signing (covered separately).  
- Binary-search exact-out on DETFs that intentionally `InvalidRoute`.  
- Exhaustive Base-fork MEV reconstruction.  
- Peer ports outside vault tree (oracles, fee collector alone) — only when they hold user funds with mint/burn.

---

## File index (existing anchors)

| Family | Gold TestBase / suite anchor |
|--------|------------------------------|
| MultiVault | `TestBase_MultiVaultWeightedDetf` + `adversarial/*` |
| Single SE DETF | `TestBase_SingleStandardExchangeDETF` |
| ComposedStable | `TestBase_ComposedStableCommonDetf` |
| DualLiquidity | `TestBase_DualLiquidityLinkedCrossVersionUniswapVault` (fork) |
| Aerodrome SE | `TestBase_AerodromeStandardExchange` |
| Camelot SE | `TestBase_CamelotV2StandardExchange` |
| Aave Stata SE | `TestBase_AaveV3StataStandardExchange` |
| Skills | `crane-adversarial-testing`, `indexedex-adversarial-testing` |

---

## Implementation plan

Execute ports per:

**[`ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md`](./ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md)**

(Wave 0 shared harness → Wave 1 Single SE + ComposedStable → Wave 2 DualLiquidity + SE → Wave 3 secondary.)

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-15 | Initial gap report from repo inventory vs MultiVault adversarial gold standard |
| 2026-07-15 | Linked implementation plan for filling gaps |

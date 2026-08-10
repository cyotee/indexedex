# Struct + Audit Readiness Review — AGGREGATE

- **Date:** 2026-08-08
- **Mode:** pilot
- **PRD:** docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_PRD.md (v0.2+)
- **Orchestrator:** Grok Build (IndexedEx workspace)
- **Areas scheduled / complete / partial / failed:** 3 scheduled · 3 COMPLETE · 0 partial · 0 failed
- **Execute plan:** docs/STRUCT_CONSOLIDATION_AND_AUDIT_READINESS_EXECUTE_PLAN.md

## 1. Program metadata

| Area ID | Status | Report path | Structs inventoried | Notes |
|---------|--------|-------------|--------------------:|-------|
| A-hooks-v4 | COMPLETE | `docs/reviews/2026-08-08_struct-audit_A-hooks-v4.md` | 62 | SE Orbital stack-hot; known HANDOFF compile risk |
| A-detf-univ4 | COMPLETE | `docs/reviews/2026-08-08_struct-audit_A-detf-univ4.md` | 52 | Orbital / weighted / CP-single / legacy single + common claim/nft |
| A-detf-core | COMPLETE | `docs/reviews/2026-08-08_struct-audit_A-detf-core.md` | 14 | Bond NFT harvest/redeem + claim token + expansion libs |
| **Total (union)** | — | — | **128** | No overlapping path allowlists |

## 2. Global inventory stats

### Totals

| Kind (approx) | Count | Notes |
|---------------|------:|-------|
| API (`PkgInit` / `PkgArgs` / deploy) | ~40 | Mostly per-package interface pairs |
| Storage (`Layout` / `Storage` / mapping values) | ~25 | Diamond / repo slots |
| Stack-relief / execution-context | ~45 | Hot-path Targets + Math libs |
| Result / residual | ~18 | MintSplit, residuals, harvest result |
| **All** | **128** | Pilot allowlists only |

### Top 15 files by struct density (rg counts)

| Rank | File | Structs |
|-----:|------|--------:|
| 1 | `contracts/hooks/.../orbital/UniswapV4StandardExchangeOrbitalBufferHookTarget.sol` | 9 |
| 2 | `contracts/hooks/.../orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol` | 7 |
| 3 | `contracts/vaults/detf/.../orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol` | 4 |
| 4 | `contracts/vaults/detf/.../common/rebasing/UniV4DetfRebasingClaimCommon.sol` | 4 |
| 5 | `contracts/vaults/detf/.../weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol` | 3 |
| 6 | `contracts/vaults/detf/.../single/UniswapV4SingleStandardExchangeDETFDFPkg.sol` | 3 |
| 7 | `contracts/vaults/detf/.../orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol` | 3 |
| 8 | `contracts/vaults/detf/.../orbital/UniswapV4StandardExchangeOrbitalDETFBurnPreviewLib.sol` | 3 |
| 9 | `contracts/vaults/detf/.../constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol` | 3 |
| 10 | `contracts/vaults/detf/common/bondNft/DETFNFTVaultService.sol` | 3 |
| 11 | `contracts/hooks/.../dual/UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol` | 3 |
| 12 | Orbital / weighted / CP DETF interfaces + DFPkgs (PkgInit/PkgArgs) | 2 each |
| 13 | Hook package interfaces (×11 families) | 2 each (Pkg*) |
| 14 | Bond NFT / claim DFPkg + Repos | 2 each |
| 15 | Hook factory (`DeployCtx`, `InitArgs`, flags Storage) | 1–2 each |

### Kind distribution notes

- **Highest stack-relief density:** SE Orbital buffer hook Target/Math (HANDOFF history).
- **Highest family clone density:** `MintSplit` ×4, `PolicyInit` ×3, `DeployConfig` ×4 under Uni V4 DETF; `HarvestParams` clones into balancer family (out of pilot scope but cited by A-detf-core).
- **API compliance:** Pilot areas generally keep `PkgInit`/`PkgArgs` on interfaces (compliant).

## 3. Cross-area duplicates

| Struct pattern | Areas | Files (examples) | Collapse class | Notes |
|----------------|-------|------------------|----------------|-------|
| `MintSplit` (4×`uint256`) | A-detf-univ4 (×4 families); potential A-detf-core landing zone | orbital/weighted/CP/legacy Commons | **C3** share under `detf/common` | Top shared-library win; no hooks involvement |
| `PairLegRating` + dead `pairNotionalWad` | A-detf-univ4 only (orbital+weighted) | `*DETFCommon.sol` | **C5** drop field + optional C3 share | Cross-family inside area |
| `PolicyInit` (6 fields) | A-detf-univ4 ×3 Repos | orbital/weighted/CP Repos | **C3** optional `DETFPolicyInit` in common | Coordinate with A-detf-core |
| `HarvestParams` / `HarvestResult` / `RedeemParams` | A-detf-core canonical; **OOS** ComposedStable clone | `DETFNFTVaultService.sol` vs balancer family service | **C3** delete family copies after common lands | Cross-area with future A-detf-balancer |
| `AccrualInput` name collision | A-detf-core only | continuous vs epoch libs | **Do not merge** (different formulas) | Rename for clarity only |
| `PkgInit` / `PkgArgs` templates | All three areas | every DFPkg/package interface | **Do not** force one ABI type | Document template; product-specific |
| `Storage` / `Layout` packing theme | All three | Repos with lone `bool`/`uint8` | **C6** per layout + tests | Shared *technique*, not shared type |
| `OperationParams` (NFT vs claim) | A-detf-univ4 common | nft vs rebasing Common | Name collision only — do not merge | Clarity rename |
| `SphereLegsWad` Math vs Target | A-hooks-v4 only | Orbital Math + Target | **C3** within hooks | Related to DETF burn sphere math (different packages) |
| `DepositFlexibleVars` dual vs orbital | A-hooks-v4 only | dual 2-leg vs orbital 3-leg | **Do not force one type** | Arity differs |
| Research ↔ production mirrors | n/a this pilot | — | — | Full mode `A-research` only |

**Orchestrator decision:** Shared landing zone for `MintSplit` + harvest service types is **`contracts/vaults/detf/common/**`** (A-detf-core owns types; family areas delete clones). Hook stack-relief types stay in hooks packages.

## 4. Priority backlog (Top 25)

Scoring (PRD §8):

```text
score = 3*gas_hot + 2*audit_sev + 2*dupe + 1*clarity - 3*break_pen - 2*stack_pen
```

Weights: gas_hot 0–3; audit Nit0/Low1/Med2/High3/Blocker4; dupe 0–3; clarity 0–2; break 0–2; stack 0–2.

| Rank | Score | ID | Area | Title | Gas | Audit sev | Break? | Next step |
|-----:|------:|----|------|-------|-----|-----------|--------|-----------|
| 1 | 17 | A-A-detf-core-003 | A-detf-core | `pretransferred=true` skips balance proof on claim token | n/a | High | No | Balance-delta gate + hermetic abuse test |
| 2 | 16 | A-A-detf-core-001 | A-detf-core | `detfNFTSold` never gated (`DETFNFTSold` dead) | n/a | High | No | Gate `addToDETFNFT` + negative tests |
| 3 | 16 | A-A-detf-core-002 | A-detf-core | Claim redeem pre-funded `rateAsset` only vs NatSpec BPT unwind | n/a | High | Maybe docs/ABI | Product decision + solvency tests |
| 4 | 15 | A-A-detf-univ4-001 | A-detf-univ4 | CP-single burn skips usage fee (peers take fee) | n/a | High | No | Port `_takeBurnUsageFee` + fee tests |
| 5 | 14 | A-A-hooks-v4-001 | A-hooks-v4 | Stack-too-deep CI / default `forge build` history (HANDOFF) | n/a | Blocker | No | Confirm `forge build`; helper splits only if red |
| 6 | 13 | S-A-detf-univ4-010 / 005 | A-detf-univ4 | **C3** shared `MintSplit` (4 family clones) | + bytecode | Med clarity | No | Land type in `detf/common`; replace clones |
| 7 | 12 | S-A-detf-univ4-011 / 001 | A-detf-univ4 | Drop dead `PairLegRating.pairNotionalWad` | + hot mint/bond | — | No | Delete field + assignments; snapshot mint |
| 8 | 12 | S-A-detf-core-012 | A-detf-core | Canonical harvest service types; delete ComposedStable clones | + bytecode | Med | No | After common shrink; coordinate balancer area |
| 9 | 11 | S-A-detf-core-001/002/004 | A-detf-core | Shrink dead Harvest/Redeem members | + harvest path | — | No | Remove unused fields; compile gate |
| 10 | 11 | A-A-detf-univ4-003 | A-detf-univ4 | CP `claimRewards` catch may return unpaid pending | n/a | Med | No | Revert or return 0 only |
| 11 | 11 | A-A-detf-univ4-002 | A-detf-univ4 | `claimRewards` non-holder soft-returns 0 | n/a | Med | Semantics | Prefer custom error |
| 12 | 11 | A-A-detf-univ4-004 | A-detf-univ4 | Orbital SE passthrough preview returns 0 | n/a | Med | No | Wire preview to SE preview path |
| 13 | 10 | S-A-hooks-v4-010 | A-hooks-v4 | **C3** unify `SphereLegsWad` Math↔Target | + bytecode | Med | No | After compile gate; re-verify stack |
| 14 | 10 | S-A-hooks-v4-001 | A-hooks-v4 | Drop unused orbital `WithdrawFlexibleVars.a0–a2` | + | — | No | Trim struct |
| 15 | 10 | S-A-hooks-v4-002 / A-A-hooks-v4-002 | A-hooks-v4 | Thread or drop discarded `feeWad` on swap execute | + | Med economic | No | Single-source fee into preview |
| 16 | 10 | A-A-detf-core-004 | A-detf-core | `reallocateDetfNftRewards` missing `nonReentrant` | n/a | Med | No | Add same lock as claim |
| 17 | 10 | A-A-detf-core-005/006 | A-detf-core | Facet omits live Target selectors | n/a | Med | Facet ABI | Add selectors or remove dead entrypoints |
| 18 | 9 | S-A-detf-univ4-012 / 002 | A-detf-univ4 | Drop write-only `MintSplit.grossDetf` | + | — | No | 3-field MintSplit with C3 |
| 19 | 9 | S-A-detf-core-016/017 | A-detf-core | **C5** inline harvest/redeem (drop params structs if stack-safe) | + | — | No | Try compile; measure gas |
| 20 | 8 | A-A-detf-univ4-005 | A-detf-univ4 | Intermediate hook legs `minOut=0` | n/a | Med | No | Document outer-minOut policy; tests |
| 21 | 8 | A-A-hooks-v4-003 | A-hooks-v4 | Single SE buffer Layout lacks reentrancy field | n/a | Med | Maybe storage | Confirm hooks-only; add lock if external API |
| 22 | 8 | A-A-detf-univ4-008 | A-detf-univ4 | Dual product trees (legacy single vs CP single) | n/a | Med process | No | Archive or rename legacy tree |
| 23 | 7 | S-A-hooks-v4-017 | A-hooks-v4 | **C6** SE Orbital Layout packing | + SLOAD | — | **Yes storage** | Pre-launch layout tests only |
| 24 | 7 | S-A-detf-univ4-015 | A-detf-univ4 | **C6** orbital DETF Storage packing | + SLOAD | — | **Yes storage** | Same test gate |
| 25 | 7 | S-A-detf-core-018 | A-detf-core | **C6** pack `decimalOffset` + `detfNFTSold` | + cold | — | **Yes storage** | Same test gate |

**Explicitly not Top 25 (keep / anti-collapse):**

- Orbital hook `SwapLiveCtx` + `SphereLegsWad` on quote path (stack history) — S-A-hooks-v4-019
- DETF `PostRemoveBook` / `MappedLegs` / `SphereWad` BurnPreviewLib — S-A-detf-univ4-019
- All public `PkgInit`/`PkgArgs` product-specific ABI types

## 5. Merged findings (Blocker / High first)

### Blockers

| ID | Area | Title | Evidence |
|----|------|-------|----------|
| A-A-hooks-v4-001 | A-hooks-v4 | Default `forge build` / CI may still fail stack-too-deep on SE Orbital buffer Target | HANDOFF cites Target ~740; current Target `:666-767` has stack-relief — **verify compile** |

### High

| ID | Area | Title | Evidence |
|----|------|-------|----------|
| A-A-detf-core-001 | A-detf-core | `detfNFTSold` unenforced | `DETFNFTVaultTarget.sol:312-319`, `addToDETFNFT:253-261` |
| A-A-detf-core-002 | A-detf-core | Claim redeem funding model vs NatSpec | `RebasingClaimTokenTarget._executeRedeem:494-516` |
| A-A-detf-core-003 | A-detf-core | `pretransferred` without balance proof | `_secureTokenTransfer:518-531` |
| A-A-detf-univ4-001 | A-detf-univ4 | CP-single burn omits usage fee | CP `ExchangeOutTarget.sol:50-63` vs orbital/weighted peers |

### Medium (summary counts + links)

| Area | Medium count (approx) | Report |
|------|----------------------:|--------|
| A-hooks-v4 | ~8 (fee dual-source, reentrancy parity, zap preview, test gaps, …) | area file §7 |
| A-detf-univ4 | ~10 (claimRewards soft-fail, preview asymmetry, minOut=0 legs, dual trees, …) | area file §7 |
| A-detf-core | ~6 (realloc reentrancy, facet gaps, rate calc, brand naming, test gaps) | area file §7 |

### Low / Nit

| Area | Low+Nit (approx) |
|------|-----------------:|
| A-hooks-v4 | ~8 |
| A-detf-univ4 | ~6 |
| A-detf-core | ~8 |

## 6. Conflicts & resolutions

| Topic | Area A said | Area B said | Orchestrator decision |
|-------|-------------|-------------|------------------------|
| Shared `MintSplit` home | A-detf-univ4: land in `detf/common` | A-detf-core: no MintSplit defined yet; factory/common is natural home | **Implement under `contracts/vaults/detf/common/core/` (or similar) first; families import** |
| Harvest params collapse vs keep | A-detf-core: C5 remove or shrink | (balancer OOS clones want share) | **Shrink dead members first; C3 share service types; C5 remove only after compile+gas** |
| Sphere / burn stack structs | A-hooks-v4: do not collapse quote relief | A-detf-univ4: do not collapse BurnPreviewLib | **Agreed — both stack-critical; keep** |
| Storage packing urgency | All areas propose C6 | — | **Score lower until audit High/struct dead-fields land; always layout tests** |
| via_ir | All areas forbid | HANDOFF historically mentioned package profiles | **Never recommend via_ir; stack = structs/helpers/scopes only** |
| Blocker severity of HANDOFF | A-hooks marks Blocker (compile unknown) | — | **Keep Blocker until default `forge build` confirmed green in implementation phase** |

## 7. Gas measurement shortlist (implementation phase)

| ID | Hermetic command | Optional fork | Notes |
|----|------------------|---------------|-------|
| Baseline compile | `forge build` (default profile) | — | Gate for stack-too-deep (A-A-hooks-v4-001) |
| Hooks orbital swap/zap/flex | `forge test --match-path 'contracts/hooks/uniswap/v4/standardExchange/orbital/*' --gas-report` | only if TestBase needs live PM | S-hooks dead members / fee thread |
| Hooks dual CP | `forge test --match-path 'contracts/hooks/uniswap/v4/standardExchange/dual/*' --gas-report` | — | Flexible vars comparison |
| Orbital DETF mint/burn/bond | `forge snapshot --match-contract TestBase_UniswapV4StandardExchangeOrbitalDETF` (adjust name) | fork if hermetic cannot fund SE | After pairNotional/MintSplit edits |
| CP-single burn fee | `forge test --match-path '**/constantProduct/single/**' --match-test 'test_.*[Bb]urn' --gas-report` | — | A-A-detf-univ4-001 regression |
| Bond NFT harvest/redeem | `forge snapshot --match-path 'test/foundry/spec/vaults/detf/common/**'` | — | HarvestParams shrink / C5 |
| Claim pretransfer abuse | hermetic negative test (new) | — | A-A-detf-core-003 |
| Storage packing (later) | package lifecycle suite + layout tests | — | C6 items ranks 23–25 |

**Rule:** no invented gas %; high-severity gas claims need hermetic snapshot deltas in implementation phase.

## 8. Audit readiness scorecard

| Area | Scorecard | Rationale |
|------|-----------|-----------|
| A-hooks-v4 | **BLOCKED** | Historical default-profile stack-too-deep on SE Orbital Target may still block CI/audit of the tree until compile is confirmed green. Struct hygiene otherwise solid; PM gates and reentrancy on main SE products look intentional. |
| A-detf-univ4 | **NEEDS_WORK** | Compiles as product surface but High fee asymmetry on CP burn, claimRewards semantics, and preview/execute gaps must close before external audit. Dual legacy tree raises navigation risk. |
| A-detf-core | **NEEDS_WORK** | Multiple High findings on sold-flag invariant, claim solvency/doc mismatch, and pretransfer trust model. Facet selector gaps undermine diamond API completeness. |

**Pilot overall:** **NEEDS_WORK** (one potential Blocker compile + several High economic/access items). Not external-audit READY.

## 9. Recommended follow-on artifacts

1. **Implementation plan** (new doc, separate authorization) covering:
   - Wave A: audit High/Blocker (compile gate, sold flag, pretransfer, CP burn fee, claim redeem product law)
   - Wave B: dead-member + C3 MintSplit / harvest share (no storage/ABI)
   - Wave C: C6 packing + facet ABI completeness
2. **Adversarial gap pointers** → `indexedex-adversarial-testing` / `crane-adversarial-testing`:
   - Claim `pretransferred` drain
   - SE buffer reenter under lock
   - CP vs orbital fee parity burn
   - Protocol NFT sold then add LP
3. **Full mode re-run** after Wave A/B merges: add A-detf-balancer, A-se-vaults, A-routers, A-manager-fee-oracle, A-interfaces-types, A-protocols, A-research.
4. **Re-run pilot** after large orbital DETF/hook merges.

## 10. Out of scope / deferred debt

- Full monorepo areas not in pilot (balancer DETF, SE vaults, routers, manager/fee/oracle, interfaces, protocols, research)
- Implementing any struct collapse or storage packing
- `via_ir` / IR package profiles
- Frontend, `lib/**` vendor law, product economics changes
- Full `forge test` monorepo suite in this review pass
- Machine-readable `inventory.json` appendix (optional PRD §7.6 — deferred)

## 11. Acceptance criteria checklist

| # | Criterion | Status |
|---|-----------|--------|
| AC1 | Every scheduled area has COMPLETE or justified PARTIAL/FAILED report on disk | **PASS** — 3× COMPLETE |
| AC2 | Aggregate report exists with Top 25 backlog + scorecard | **PASS** — this file §§4, 8 |
| AC3 | Every collapse proposal includes gas dir, stack risk, ABI/storage break, confidence | **PASS** — area §4 tables |
| AC4 | Every Blocker/High audit finding has path:line evidence and a verification idea | **PASS** — area §7 + aggregate §5 |
| AC5 | Do-not-collapse lists exist for each area | **PASS** — area §5 |
| AC6 | No recommendation requires `via_ir` | **PASS** — only forbid mentions |
| AC7 | No product code changed in this program | **PASS** — report-only under `docs/reviews/` |
| AC8 | Cross-area duplicates section lists shared opportunities (or none) | **PASS** — §3 |

---

**Definition of done (execute plan §9):** D1–D5 satisfied for pilot mode.

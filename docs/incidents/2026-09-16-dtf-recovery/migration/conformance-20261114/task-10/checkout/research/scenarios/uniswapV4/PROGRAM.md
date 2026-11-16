# Uni V4 Hooks + DETF Performance Research Program

**Purpose:** Hermetic, reconstructable performance research for IndexedEx Uniswap V4 **hooks** and **true DETFs** that use those hooks as reserve hosts — same methodology as Uni V2 SE / Single SE DETF / DualLiquidity campaigns.

| Field | Value |
|-------|--------|
| **Created** | 2026-08-06 |
| **Status** | **ACTIVE** — Phase 0 complete; Phase 1: Orbital H0–H2 **PASS**; Uni V4 CP DETF D0–D1 **PASS** |
| **Methodology** | [`research/RESEARCH_PLAYBOOK.md`](../../RESEARCH_PLAYBOOK.md) |
| **Prior DETF gold** | [`research/scenarios/detf/singleSe/`](../detf/singleSe/) (Balancer Single SE — **do not re-run**) |
| **Prior SE rails** | [`research/scenarios/uniswapV2Se/rateProviderCompare/`](../uniswapV2Se/rateProviderCompare/) (cite only) |
| **Maturity matrix** | [`MATURITY.md`](./MATURITY.md) |

**Conflict rule:** Product PRDs under `contracts/**` win on behavior. Chart conventions in `research/README.md` win on framing. This program wins on campaign scope / work order / maturity gates.

---

## 1. Why this program exists

| Prior work | Proved | Does **not** cover |
|------------|--------|---------------------|
| Uni V2 SE Mode A / rateProviderCompare | SE re-mark; R+/R− residual; fee as arb threshold | V4 custom curves / hooks |
| Balancer Single SE DETF D0–D9 | Inert→live, Policy/Open, expansion, compound | Uni V4 reserve host + hook LP principal |
| DualLiquidity research | Nested multi-SE share book | True DETF synthetic gates on V4 hooks |

New products under research:

| Layer | Paths (user scope) |
|-------|---------------------|
| **AMM hooks** | `contracts/hooks/uniswap/v4/{orbital,stable/quad,weighted}` |
| **SE buffer hooks** | `…/standardExchange/{constantProduct/single,orbital}` (+ weighted buffer when TestBase-ready) |
| **True DETFs** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{constantProduct/single,orbital,weighted}` |

---

## 2. Research ladder (do not skip tiers)

Work **down** the ladder. A product may be blocked at Tier 0 if code/TestBase is incomplete — see [`MATURITY.md`](./MATURITY.md).

| Tier | Question | Products |
|------|----------|----------|
| **H0** Smoke deploy | Package deploys via production path; telemetry writes | All hooks with TestBase |
| **H1** Mode A demand | Market buys one leg through hook pair doors; LP book mark | Orbital, Quad, Weighted, SE-CP, SE-Orbital |
| **H2** Preview honesty | Closed-form preview == execution on swaps / LP | Same |
| **H3** Fee / inventory attribution | Fee P&L vs price/inventory P&L (split panels) | Same |
| **S1** SE buffer composition | SE share leg re-marks effective reserve under SE yield / wrap | SE-CP, SE-Orbital, SE-Weighted |
| **D0–D9** DETF lifecycle | Mirror Single SE DETF campaign (inert, first bond, gates, expansion, compound) | Uni V4 CP DETF, Orbital DETF; Weighted DETF when coded |
| **F** Fork validation | Same JSONL schema on Base / Eth / Robinhood | After hermetic stories lock |

---

## 3. Campaign index

### Hooks (AMM / buffer)

| Campaign id | Product | Scenario dir | Ready? |
|-------------|---------|--------------|--------|
| `uniswapV4/hooks/orbital` | Orbital Swap Hook (3-asset sphere) | [`hooks/orbital/`](./hooks/orbital/) | **Yes** — TestBase + hermetic suite |
| `uniswapV4/hooks/quadStable` | Quad Stable Swap Hook | [`hooks/quadStable/`](./hooks/quadStable/) | **Yes** |
| `uniswapV4/hooks/weighted` | Weighted Swap Hook | [`hooks/weighted/`](./hooks/weighted/) | **Yes** (monomorph factory) |
| `uniswapV4/hooks/seConstantProductSingle` | Single SE Buffer CP Hook | [`hooks/seConstantProductSingle/`](./hooks/seConstantProductSingle/) | **Yes** |
| `uniswapV4/hooks/seOrbital` | SE Orbital Buffer Hook | [`hooks/seOrbital/`](./hooks/seOrbital/) | **Yes** |
| `uniswapV4/hooks/seWeighted` | SE Weighted Buffer Hook | [`hooks/seWeighted/`](./hooks/seWeighted/) | **Partial** — code + TestBase under `test/…`; no contracts/ TestBase co-locate |

### DETFs (true DETF families)

| Campaign id | Product | Scenario dir | Ready? |
|-------------|---------|--------------|--------|
| `uniswapV4/detf/standardExchangeCpSingle` | Uni V4 Single SE CP Buffer DETF | [`detf/standardExchangeCpSingle/`](./detf/standardExchangeCpSingle/) | **Yes** — full suite (deploy/firstBond/mintBurn/…) |
| `uniswapV4/detf/standardExchangeOrbital` | Uni V4 SE Orbital DETF | [`detf/standardExchangeOrbital/`](./detf/standardExchangeOrbital/) | **Yes** — suite present |
| `uniswapV4/detf/standardExchangeWeighted` | Uni V4 SE Weighted DETF | [`detf/standardExchangeWeighted/`](./detf/standardExchangeWeighted/) | **No** — PRD/plan only |

---

## 4. Layout contract

```text
research/
  scenarios/uniswapV4/
    PROGRAM.md                 # this file
    MATURITY.md
    hooks/<product>/
      *_Research_PRD.md
      *_IMPLEMENTATION_AND_TEST_PLAN.md
      FINDINGS.md              # after runs
      AGENT_RESEARCH_REPORT.md # after campaign lock
    detf/<product>/
      same pattern
  out/uniswapV4/
    hooks/<product>/<runId>/{meta.json,series.jsonl,NOTES.md,*.png}
    detf/<product>/<runId>/...
  run_uniswap_v4_research.sh   # portfolio runner (smoke / per-campaign)
  plots/plot_uniswap_v4_*.py

scripts/foundry/research/uniswapV4/
  hooks/<product>/ResearchFixture_*.sol + Script_*.s.sol
  detf/<product>/ResearchFixture_*.sol + Script_D*.s.sol
```

**Rules:** narrative + code tracked; `out/` generated (gitignored). Production-first: CREATE3 + registry / hook factory — **no mock SUT**.

---

## 5. Foundry profiles (locked for research)

Narrow product profiles exist in `foundry.toml`. Research scripts import gold TestBases and production packages; runners **must** set the profile that successfully compiles that product suite:

| Product | Typical profile |
|---------|-----------------|
| Orbital AMM hook | `orbital` |
| Quad stable | `quad_stable` |
| Weighted AMM hook | `default` (or dedicated if added) |
| SE CP single buffer | `single_se_buffer_cp_hook` |
| SE orbital buffer | `se_orbital_buffer_hook` (`via_ir=true`) |
| SE weighted buffer | `se_weighted_buffer_hook` (`via_ir=true`) |
| Uni V4 CP DETF | `uv4_single_se_cp_detf` |
| Uni V4 Orbital DETF | `se_orbital_detf` (`via_ir=true`) |

If a narrow profile **skips** `scripts/**`, research either:
1. Uses `forge script` path that still compiles via import graph, or  
2. Extends profile `fs_permissions` / drop skip for research paths, or  
3. Places thin Script under the profile’s `test/` tree as a research-only file (last resort).

Document the working command in each campaign’s PRD Progress section.

---

## 6. Scenario families

### Hooks — Mode H (market demand)

| ID | Story | Drive |
|----|-------|-------|
| **H0** | Smoke deploy + seed liquidity | No demand; sample reserves / LP supply |
| **H1a** | Market buys tokenᵢ with tokenⱼ | Exact-in swaps on pair door (i,j) for N steps |
| **H1b** | Opposite demand | Mirror of H1a |
| **H2** | Preview == execution | One-step swap + LP add/remove |
| **H3** | LP book P&L | Full exit LP → tokens → numeraire mark |

### SE buffer hooks — Mode S

| ID | Story |
|----|-------|
| **S0** | Hook live; SE bound; dual-leg deposit |
| **S1** | SE yield / rate move re-marks effective reserves (where product has rates) |
| **S2** | SE In/Out route through hook surface |

### DETFs — Mode D (mirror Single SE Phase 3)

| ID | Maps to Single SE | Story |
|----|-------------------|-------|
| **D0** | D0 | Inert deploy; mint blocked |
| **D1** | D1 | First bond → live |
| **D2** | D2 | Policy deadband / post-bond gate state |
| **D3** | D3 | Mint allowed + preview==exec |
| **D4** | D4 | Burn gate |
| **D5** | D5 | Open twin control |
| **D6** | D6 | Capital seigniorage dilution |
| **D7** | D7 | Bond vs free mint books |
| **D8** | D8 | Natural expansion (Policy only) |
| **D9** | D9 | Protocol compound |

Family deltas (creation rate, dual-capital first bond, mature-only sell→claim, epoch expansion) come from **co-located product PRDs** — research must not invent Balancer-only mechanics on V4 hosts.

---

## 7. Metrics dictionary (V4 extensions)

Reuse SE/DETF names where applicable. Add:

| Name | Definition |
|------|------------|
| `hookLpSupply` | IERC20 totalSupply of hook diamond LP |
| `reserve_i` / `effectiveReserve_i` | Raw or SE-composed reserve leg i |
| `radius` / `lSquared` | Orbital sphere state (when product exposes) |
| `mid_ij` | Pair mid for door (i,j) — product-defined (sphere / weighted / CP) |
| `midIndex_ij` | mid_t / mid_0 |
| `previewOut` / `execOut` | Closed-form honesty |
| `syntheticPrice` | DETF synthetic (1e18 peg narrative) |
| `isReserveLive` / `isMintingAllowed` / `isBurningAllowed` | DETF gates |
| `lpBookExitNumeraire` | Full removeLiquidity mark in research numeraire |

**Numeraire default (hermetic):** mark all tokens at **1:1** mintable units unless a scenario pins a relative spot (document in meta). Do **not** invent off-chain USD oracles.

---

## 8. Work order (agents)

### Phase 0 — Portfolio (this session baseline)

1. PROGRAM + MATURITY authored.  
2. Campaign PRD stubs + implementation plans for each ready product.  
3. README + SCENARIO_LOG index rows.

### Phase 1 — Hook smoke + Mode A (priority order)

1. **Orbital AMM** H0 + H1a/H1b  
2. **SE CP single** H0 + S0 + H1  
3. **Quad stable** H0 + H1  
4. **Weighted AMM** H0 + H1  
5. **SE Orbital** H0 + S0 + H1  
6. **SE Weighted** when fixture bootstrap is stable  

### Phase 2 — DETF lifecycle (after reserve host H0 green)

1. **Uni V4 CP Single DETF** D0–D1 smoke → full D0–D9  
2. **Orbital DETF** D0–D1 smoke → full D0–D9  
3. **Weighted DETF** blocked until package code lands  

### Phase 3 — Plots + FINDINGS

PNG packs + FINDINGS.md + AGENT_RESEARCH_REPORT per campaign.  
No marketing APY. Cite production paths only.

### Phase 4 — Fork (later)

Same schema on Base / Eth / Robinhood forks already used by product DoD.

---

## 9. Success criteria (portfolio)

- [ ] Every **ready** product has campaign PRD + plan  
- [ ] Every ready product has at least **H0** (hooks) or **D0** (DETFs) green with `series.jsonl` + NOTES  
- [ ] DETF CP + Orbital: D0–D1 green before claiming full D-matrix  
- [ ] In-development products (Weighted DETF) documented as **blocked**, not skipped silently  
- [ ] SCENARIO_LOG rows for completed runs  
- [ ] One-command runners documented per campaign  

---

## 10. Non-goals

- Re-running Balancer Single SE DETF D0–D9 or Uni V2 rateProviderCompare matrices  
- Mainnet APY / Monte Carlo yield  
- Mocking hooks, DETFs, manager, registry, or SE under test  
- Treating DualLiquidity as a true DETF  
- Product brand names in research surfaces (`rateAsset`, `pairToken`, `vaultShare`, `detfToken`, …)

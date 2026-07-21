# Agent Research Report — DualLiquidity Linked Cross-Version Vault

**Audience:** agents and humans who must **reuse** DualLiquidity research without re-running Base-fork scripts.  
**Status:** Mode A + Mode B complete (2026-07-21).  
**Do not re-run** full fork matrices unless parameters change (wall-clock: multi-minute bootstrap each run).

| Doc | Path |
|-----|------|
| This report | `research/scenarios/dualLiquidityLinkedCrossVersion/AGENT_RESEARCH_REPORT.md` |
| Findings | [`FINDINGS.md`](./FINDINGS.md) |
| PRD / plan | [`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md), [`DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Prior SE rates theory | `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` |
| Artifacts | `research/out/dualLiquidityLinkedCrossVersion/` |

**Reproduce (when needed):**

```bash
FOUNDRY_PROFILE=default ./research/run_dual_liquidity_research.sh
# Requires foundry.toml base_mainnet_alchemy + ALCHEMY_KEY
```

---

## 1. One-paragraph answer

DualLiquidity composes two Uni V4 SE legs + one Uni V2 pair SE into a **0.3% fee** Balancer weighted reserve and mints simple vault shares against BPT. With **`useRateProviders: true`**, nested mid×rate residual on the vaultA lens stays **≈ 0** under modest V4 common→tokenA demand. With **product default `false`**, residual **grows** (small at modest volume). Mode B commonToken deposits show **exact** preview==execution when rates off, and **≤ few-wei** when rates on. Canonical full-value exit mark is **shares → reserve BPT**. Fee-threshold arb on the reserve was **not** exercised at this volume (R− residual ≪ 0.3%).

---

## 2. SUT and API

| Item | Value |
|------|--------|
| Package | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` |
| Rates flag | `PkgArgs.useRateProviders` (homogeneous three legs) |
| Default | **false** (STANDARD) |
| Research fixture | `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol` |
| Residual | `residualA = midIndexA * rateIndexA / 1e18 - 1` with `midA = live[pair]/live[vaultA]` |

---

## 3. Results table

| Run | residualA end | Mode B preview |
|-----|---------------|----------------|
| rates_off Mode A | ~**+1.86e-4** | n/a |
| rates_on Mode A | **~0** (−1 wei) | n/a |
| rates_off Mode B deposit | n/a | **exact** |
| rates_on Mode B deposit | n/a | **few-wei** |

Artifacts:

```text
research/out/dualLiquidityLinkedCrossVersion/
  rates_off/{modeA_legDemand,modeB_depositCommon,smoke}/
  rates_on/{modeA_legDemand,modeB_depositCommon}/
  compare/{modeA_legDemand,modeB_depositCommon}/
```

---

## 4. What to cite for marketing / product docs

| Claim | Cite |
|-------|------|
| Nested V4+V2 under one share | Topology + Mode B share mint series |
| Default without rates | meta `useRateProviders: false` |
| Rates re-mark nested mids | Mode A rates_on residual ≈ 0 |
| Rates off allows lag | Mode A rates_off residual growth |
| Deposit previews trustworthy | Mode B preview/exec fields |
| Fee is arb filter | Uni V2 SE agent report + DualLiquidity residual ≪ 0.3% at modest volume |

**Do not claim:** mainnet APY; Mode C fills on DualLiquidity at this tier; residual formula is unique fair numeraire for all three legs (v1 locks vaultA lens only).

---

## 5. Open questions / next campaign

**Normative next research:** DualLiquidity **v2** — linked volume + share-book (primary VP), not Mode C.

| Doc | Path |
|-----|------|
| v2 PRD | [`DualLiquidity_Research_v2_PRD.md`](./DualLiquidity_Research_v2_PRD.md) |
| v2 plan | [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md) |

Still open from v1 (stretch only):

- Larger Mode A volume until R− residual ≳ 0.3% for Mode C fills on DualLiquidity.  
- Multi-leg residual (vaultB, pair) charts.  
- Stress R+ Mode C behavior (Uni V2 SE showed stress fills even with rates).

---

*Prefer updating this file over spawning parallel narratives when new tiers complete.*

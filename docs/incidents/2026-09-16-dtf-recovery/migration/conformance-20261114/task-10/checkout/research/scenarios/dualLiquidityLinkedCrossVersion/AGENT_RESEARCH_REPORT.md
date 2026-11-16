# Agent Research Report — DualLiquidity Linked Cross-Version Vault

**Audience:** agents and humans who must **reuse** DualLiquidity research without re-running Base-fork scripts.  
**Status:** **v1 + v2 complete** (2026-07-21).  
**Do not re-run** full fork matrices unless parameters change (wall-clock: multi-minute bootstrap each run).

| Doc | Path |
|-----|------|
| This report | `research/scenarios/dualLiquidityLinkedCrossVersion/AGENT_RESEARCH_REPORT.md` |
| v1 findings (rates residual + preview) | [`FINDINGS.md`](./FINDINGS.md) |
| **v2 findings (volume + share book + narrative)** | [`FINDINGS_v2.md`](./FINDINGS_v2.md) |
| v1 PRD / plan | [`DualLiquidity_Research_PRD.md`](./DualLiquidity_Research_PRD.md), [`DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_IMPLEMENTATION_AND_TEST_PLAN.md) |
| v2 PRD / plan | [`DualLiquidity_Research_v2_PRD.md`](./DualLiquidity_Research_v2_PRD.md), [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md) |
| Marketing roll-up | [`../../MARKETING_AND_PERFORMANCE_FINDINGS.md`](../../MARKETING_AND_PERFORMANCE_FINDINGS.md) |
| Prior SE rates / fee-threshold theory | `research/scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md` |
| Artifacts | `research/out/dualLiquidityLinkedCrossVersion/` (v1) and `.../v2/` (v2) |

**Reproduce (when needed):**

```bash
FOUNDRY_PROFILE=default ./research/run_dual_liquidity_research.sh      # v1 R+/R− residual + preview
FOUNDRY_PROFILE=default ./research/run_dual_liquidity_research_v2.sh   # v2 volume + share book (rates-off)
# Requires foundry.toml base_mainnet_alchemy + ALCHEMY_KEY
```

---

## 1. One-paragraph answer

DualLiquidity composes two Uni V4 SE legs + one Uni V2 pair SE into a **0.3% fee** Balancer weighted reserve and mints simple vault shares against BPT. **Primary product story (v2):** deposits via the product surface put capital into **nested SE share inventory and reserve BPT** (measurable volume attribution) — composition/routing under one share, not synthetic DETF seigniorage. **Rates (v1):** with `useRateProviders: true`, nested mid×rate residual ≈ 0 under modest leg demand; product default `false` allows residual growth (still ≪ 0.3% fee at modest size). Mode B previews match execution (exact off / few-wei on). **Extension:** holders of DualLiquidity sit behind **Standard Exchange shares in the reserve**, so they structurally benefit from SE re-mark traffic and, when residual clears fees, **arb-induced volume on those SE legs** (proven on Uni SE research; DualLiquidity Mode C not required for the claim). Lead marketing with **linked liquidity + deposit→nested volume**; rates and arb are supporting depth.

---

## 2. SUT and API

| Item | Value |
|------|--------|
| Package | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg` |
| Rates flag | `PkgArgs.useRateProviders` (homogeneous three legs) |
| Default | **false** (STANDARD) |
| Research fixture | `scripts/foundry/research/dualLiquidityLinkedCrossVersion/ResearchFixture_DualLiquidity.sol` |
| Residual (v1) | `residualA = midIndexA * rateIndexA / 1e18 - 1` with `midA = live[pair]/live[vaultA]` |
| Volume attribution (v2) | `attributionModel = reserve_live_plus_alice_shares` (reserve live SE balances + alice shares + diamond BPT) |

---

## 3. Results tables

### 3.1 v1 — residual + preview

| Run | residualA end | Mode B preview |
|-----|---------------|----------------|
| rates_off Mode A | ~**+1.86e-4** | n/a |
| rates_on Mode A | **~0** (−1 wei) | n/a |
| rates_off Mode B deposit | n/a | **exact** |
| rates_on Mode B deposit | n/a | **few-wei** |

Artifacts: `research/out/dualLiquidityLinkedCrossVersion/{rates_off,rates_on,compare}/`

### 3.2 v2 — volume + share book (rates-off)

| Route | Nested volume signal | Notes |
|-------|----------------------|-------|
| deposit_common | BPT + **pair** SE live | Pair funnel |
| deposit_tokenA | BPT + **vaultA** (+ pair over path) | Multi-surface hero |
| deposit_tokenB | BPT + **vaultB** (+ pair over path) | **Peer of tokenA** (nested min fix) |
| deposit_pairShare | BPT + pair SE | Direct SE join |
| deposit_vaultAShare | BPT + vaultA SE | Direct SE join |
| swap_tokenA_tokenB | execOut ≫ 0; reserve live Δ = 0 | Off-reserve volume driver |
| Mode A leg demand | share→BPT mark **flat**; residual ~1.86e-4 | Uni-only does not reprice BPT claim |

Artifacts: `research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/`  
Detail + step cites: [`FINDINGS_v2.md`](./FINDINGS_v2.md)

---

## 4. What to cite for marketing / product docs

| Claim | Cite |
|-------|------|
| Nested V4+V2 under one share | Topology + v2 volume_by_leg deposits |
| Deposits fund nested SE legs + reserve BPT | FINDINGS_v2 Mode B series / `volume_by_leg.png` |
| Routes hit different legs (not equal spray) | common→pair; tokenA→vaultA; tokenB→vaultB |
| Both linked tokens mint DualLiquidity shares | deposit_tokenA + deposit_tokenB peer series |
| Default without rates | meta `useRateProviders: false` |
| Opt-in rates re-mark nested mids | v1 Mode A rates_on residual ≈ 0 |
| Rates off allows lag | v1 Mode A rates_off residual growth |
| Deposit previews trustworthy | v1 Mode B preview/exec |
| Fee is arb **filter** (not free lunch) | Uni V2 SE rateProviderCompare + DualLiquidity residual ≪ 0.3% modest |
| **SE-in-reserve benefits from re-mark / fee-gated arb volume** | Chain: Uni SE residual+arb research + DualLiquidity holds SE shares (v2 inventory) — **not** DualLiquidity Mode C fills |
| Holder BPT mark trackable | v2 Mode A share_book_pnl; grows with deposits (Mode B) |

**Do not claim:** mainnet APY; DualLiquidity Mode C fills at this tier; residual formula is unique fair numeraire for all three legs; equal flow to all SE legs every trade; Uni-only Mode A moves share→BPT mark; DualLiquidity is primarily an arb product.

---

## 5. Marketing narrative spine (locked for agents)

1. **Standard Exchange** re-marks with underlying markets; nested Balancer mids fair with rates; lag ≠ arb below fees.  
2. **DualLiquidity** = one share over **linked Uni V4 + V2 SE liquidity**; deposits **fund nested SEs and BPT** (v2).  
3. Because the reserve holds **SE shares**, DualLiquidity holders are positioned to benefit from **SE ecosystem volume**, including rebalancing / **arb-induced flow when residual clears fees** on those legs (SE research).  
4. Product lead is **composition + volume into nested markets**; rates and arb are **supporting technical** claims.  
5. Previews match execution on closed-form deposits.

---

## 6. Open questions (stretch only)

- DualLiquidity Mode C when residual approaches ~0.3%.  
- Multi-leg residual charts as first-class marketing panels.  
- Optional `deposit_vaultBShare` research twin.  
- Multi-protocol SE legs (Aero/Camelot) as DualLiquidity substitutes — separate campaign.

## 7. Production note (tokenB gap closed)

Nested `_swapThrough` no longer floors intermediate SE hops on exact preview (was causing `UniswapV4ExchangeIn_SlippageExceeded` on tokenB→shares). Outer DualLiquidity `minAmountOut` + actual-BPT share mint unchanged. See FINDINGS_v2 “Production fix”.

---

*Prefer updating this file and FINDINGS_v2 over spawning parallel narratives when new tiers complete.*

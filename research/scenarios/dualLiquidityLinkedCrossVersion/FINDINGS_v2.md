# DualLiquidity Research v2 — Findings

**Status:** Complete (rates-off hero matrix + tokenB deposit gap closed).  
**PRD:** [`DualLiquidity_Research_v2_PRD.md`](./DualLiquidity_Research_v2_PRD.md)  
**Plan:** [`DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md`](./DualLiquidity_Research_v2_IMPLEMENTATION_AND_TEST_PLAN.md)  
**Reproduce:** `./research/run_dual_liquidity_research_v2.sh` (Base fork; `FOUNDRY_PROFILE=default`)

## Addendum (v2.1) — tokenB deposit gap closed

**When:** 2026-07-21 (same research day as v2 matrix).  
**What was missing:** `deposit_tokenB` (research role **tokenB** = hermetic test ERC-20 **Token B / TKB**, the vaultB-side linked asset — not a mainnet brand) was attempted in the original Mode B P0 matrix and **reverted** with `UniswapV4ExchangeIn_SlippageExceeded` on nested Uni V4 hops, so only an init row existed and the path was marked deferred.

**Root cause:** DualLiquidity nested deposit hops passed **exact** `previewExchangeIn` as the leg SE `minOut`. V4 share mints can undershoot that preview by rounding.

**Fix (production):** `_swapThrough` in `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` uses **`minOut = 0`** for intermediate nested SE hops. User-facing DualLiquidity `minAmountOut` on minted shares and actual-BPT share minting are unchanged.

**Verification:**

| Check | Result |
|-------|--------|
| Fork Deposits suite | `test_depositLinkedTokenB_*` green (`FOUNDRY_PROFILE=fork`) |
| Research series | `v2/rates_off/modeB_depositTokenB/` — **13 lines** (init + 12 steps) at full `TRADE_SIZE` |
| Nested volume | step 1: `dLiveVaultB` and `dBalDiamondBpt` both non-zero (peer of tokenA → vaultA) |
| Hero graph | `modeB_depositTokenB/volume_by_leg.png` |

**Marketing takeaway:** both linked tokens (**tokenA and tokenB**) can mint DualLiquidity shares and fund the corresponding nested SE books. Detail below in Mode B table, production-fix section, and marketing claims. Agent handoff: [`AGENT_RESEARCH_REPORT.md`](./AGENT_RESEARCH_REPORT.md) §3.2 / §7.

---

## Attribution model (locked)

```text
attributionModel = reserve_live_plus_alice_shares
liveVaultA/B/pair = Balancer reserve live balance of each SE share token
balDiamondBpt     = reserve BPT held by DualLiquidity diamond
balAliceShares    = alice DualLiquidity ERC-20 balance
d*                = step delta vs previous sample
```

Meta on every v2 run: `researchVersion: 2`, `useRateProviders: false`.

## Artifact root

```text
research/out/dualLiquidityLinkedCrossVersion/v2/rates_off/
  smoke/
  modeB_depositCommon/
  modeB_depositTokenA/
  modeB_depositTokenB/          # full 12-step series (product nested-min fix)
  modeB_depositPairShare/       # P1
  modeB_depositVaultAShare/     # P1
  modeB_swapTokenATokenB/       # P1 volume driver
  modeA_legDemand/
```

Hero graphs:

| Chart | Path |
|-------|------|
| Volume (common deposit) | `v2/rates_off/modeB_depositCommon/volume_by_leg.png` |
| Volume (tokenA → multi-leg) | `v2/rates_off/modeB_depositTokenA/volume_by_leg.png` |
| Volume (tokenB → multi-leg) | `v2/rates_off/modeB_depositTokenB/volume_by_leg.png` |
| Volume (vaultA share join) | `v2/rates_off/modeB_depositVaultAShare/volume_by_leg.png` |
| Share book Mode A | `v2/rates_off/modeA_legDemand/share_book_pnl.png` |

## Mode B results (rates-off)

| Route | Steps | sum dBalDiamondBpt | sum dLiveVaultA | sum dLiveVaultB | sum dLivePairVault | Notes |
|-------|-------|--------------------|-----------------|-----------------|--------------------|-------|
| **deposit_common** | 12+init | **+7.27e13** | 0 | 0 | **+3.42e9** | Pair leg + BPT; V4 legs frozen |
| **deposit_tokenA** | 12+init | **+9.14e13** | **+1.98e21** | 0 | **+2.29e9** | vaultA + pair + BPT |
| **deposit_tokenB** | 12+init | **+8.85e13** | 0 | **+1.92e21** | **+2.21e9** | **Closed gap:** vaultB + pair + BPT (peer of tokenA) |
| **deposit_pairShare** (P1) | 12+init | **+7.28e13** | 0 | 0 | **+3.42e9** | Direct pair SE join |
| **deposit_vaultAShare** (P1) | 12+init | **+5.34e13** | **+5.90e21** | 0 | 0 | Direct vaultA SE join |
| **swap_tokenA_tokenB** (P1) | 12+init | 0 | 0 | 0 | 0 | Swap does **not** change reserve live inventory; execOut ≫ 0 (leg volume off reserve books) |

### Cited step (H2 smoking gun)

`modeB_depositTokenA` **step 1** (`route=deposit_tokenA`):

| Field | Value |
|-------|-------|
| `dBalDiamondBpt` | `9543548531784` |
| `dLiveVaultA` | `497699730991656872440` |
| `dLivePairVault` | `0` (this step; cumulative pair Δ still non-zero over run) |
| `previewOut` / `execOut` | equal (preview gap 0) |

`modeB_depositCommon` **step 1**:

| Field | Value |
|-------|-------|
| `dBalDiamondBpt` | `7205449530800` |
| `dLivePairVault` | `288138108` |
| `dLiveVaultA` / `dLiveVaultB` | `0` |

`modeB_depositTokenB` **step 1** (`route=deposit_tokenB`):

| Field | Value |
|-------|-------|
| `dBalDiamondBpt` | `9213479059013` |
| `dLiveVaultB` | `477706861886609739986` |
| `dLiveVaultA` | `0` |
| `previewOut` / `execOut` | `9204278778449` / `9204265579954` (few-wei gap) |

**H2 aggregate:** BPT Δ and SE-leg Δ both non-zero across matrix → **PASS** (both vaultA and vaultB deposit paths proven).

### Production fix (tokenB gap root cause)

Nested deposit hops used **exact `previewExchangeIn` as leg `minOut`**. Uni V4 share mints can undershoot preview by rounding → `UniswapV4ExchangeIn_SlippageExceeded` on the tokenB linked path (and other multi-hop deposits under stress).

**Fix:** `_swapThrough` passes **`minOut = 0`** for intermediate nested SE hops. End-user slippage remains on DualLiquidity `exchangeIn` share `minAmountOut`; share mint still uses **actual** BPT (`_mintSharesForActualBpt`). File: `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol`. Tests: `test_depositLinkedTokenB_*` in `DualLiquidityLinkedCrossVersionUniswapVault_Deposits.t.sol`.

## Mode A results (rates-off share book)

| Metric | Result |
|--------|--------|
| Steps | 12 + init |
| `markFullExit` / `portfolioExitBpt` | Flat at bootstrap book (`50353710728921`) |
| `pnlNorm` | `0` entire path |
| residualA end | `186397266046056` (~1.86e-4 fraction) — matches v1 residual order |

**Interpretation:** Under **leg Uni demand only**, DualLiquidity **shares → reserve BPT** full-exit mark is invariant (pro-rata BPT claim does not reprice from SE rate lag). Series + plot still deliver the share-book panel; do **not** claim Mode A moves holder BPT mark without product deposits. Residual fairness remains a v1 cite.

## Hypotheses

| ID | Claim | Verdict |
|----|--------|---------|
| **H1** | Mode B routes create measurable nested activity beyond “shares exist” | **Supported** (BPT + SE live on deposit_* routes) |
| **H2** | BPT + ≥1 SE leg non-zero (aggregate) | **Supported** |
| **H3** | Share full-exit mark plotable under Mode A | **Supported** (series + PNG; mark flat under Uni-only — documented) |
| **H4** | Rates-off sufficient for hero charts | **Supported** (no rates-on runs required) |

## Deferred / notes

1. ~~**deposit_tokenB** deferred~~ — **closed** (nested min fix + full series; vaultB + BPT).  
2. **swap_tokenA_tokenB** — fills successfully; reserve live attribution stays 0 by design (no join). Treat as off-reserve volume driver, not H2 evidence.  
3. **deposit_vaultBShare** — optional twin of vaultAShare not required once tokenB deposit proves vaultB live inventory.  
4. v1 trees under `rates_off|rates_on|compare` **unchanged** (cksum isolation verified).

## Narrative synthesis (what v2 told us)

v2 was **not** about residual fairness (v1) or DualLiquidity-as-arb-product. It asked: when users take **product routes**, does capital appear in **nested SE books** and the **reserve**?

**Answer:** Yes on deposit paths. DualLiquidity is a **composition / routing** surface over linked Uni V4 + V2 Standard Exchange legs under one share.

### Bridge to SE arb volume (marketing chain)

1. **Uni V2 SE research** showed underlying demand re-marks SE rates; nested Balancer mids lag without rates; **arb fills only when residual clears fees** (fee as presentation threshold).  
2. **SE shares in a Balancer reserve** (including DualLiquidity’s weighted reserve) are the natural home for that mid×rate residual and closer flow when edge exists.  
3. **v2 DualLiquidity deposits** put **more SE share inventory into that reserve** (and grow BPT). Holders therefore sit **behind** the same SE books that attract **re-mark traffic and, when residual ≳ fees, arb-induced volume**.  
4. DualLiquidity itself is **not** sold as an arb engine: product default is rates-off; residual at modest size is still ≪ 0.3% reserve fee; Mode C was not required. The benefit is **structural**: nested SE exposure + product volume into legs, **plus** optional capture of SE ecosystem rebalancing / arb flow when markets are live.

**Lead claim:** one share over linked multi-version Uni liquidity, with deposits that fund nested SEs.  
**Supporting claim:** those SE legs participate in the broader Standard Exchange re-mark / fee-gated arb volume story (cite Uni SE rateProviderCompare for arb threshold; cite v2 for capital into legs).

### What not to overclaim

| Overclaim | Honest line |
|-----------|-------------|
| Equal volume into both V4 markets every deposit | Routes are **asymmetric** by design; common→pair; tokenA→vaultA; tokenB→vaultB |
| DualLiquidity Mode C arb proven | Residual still modest; Mode C stretch only |
| Rates required for the product | Rates-off is default and sufficient for volume VP |
| Uni-only Mode A moves share→BPT mark | Mark is **flat** under Uni demand alone (v2 Mode A) |

## Marketing claims unlocked (v2)

| Claim | Evidence |
|-------|----------|
| Depositing into DualLiquidity funds nested SE / reserve composition | Mode B volume_by_leg + series d* fields |
| Multiple deposit routes hit different legs | common→pair; tokenA→vaultA; **tokenB→vaultB**; SE-share joins |
| **Both linked tokens (A and B) can mint DualLiquidity shares** | deposit_tokenA + deposit_tokenB peer series |
| Product swap routes execute (linked token↔token) | swap series execOut |
| Holder BPT mark trackable | Mode A share_book_pnl (+ Mode B mark grows with deposits) |
| Holders benefit from SE legs in reserve (incl. re-mark / fee-gated arb volume on those SEs) | v2 inventory into SE shares + Uni SE residual/arb research chain (not DualLiquidity Mode C) |

**Do not claim:** equal flow to all three SE legs every single route; Mode A Uni demand alone changes share→BPT mark; DualLiquidity is primarily an arb product.

## Review order

1. `modeB_depositTokenA/volume_by_leg.png`  
2. `modeB_depositTokenB/volume_by_leg.png`  
3. `modeB_depositCommon/volume_by_leg.png`  
4. `modeB_depositVaultAShare/volume_by_leg.png`  
5. `modeA_legDemand/share_book_pnl.png`  
6. This file + series.jsonl for step-level cites  
7. Uni SE fee-threshold: `rateProviderCompare/AGENT_RESEARCH_REPORT.md`  

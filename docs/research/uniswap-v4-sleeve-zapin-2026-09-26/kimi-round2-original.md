# Kimi K3 — Round 2 independent original: proportional zap-in under owner directives

**Date:** 2026-09-26. Research only; no code/tests/delegation. Prior files preserved. Context: moderator PRD `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` read; no round-2 peer artifacts accessed. External API claims rely on round-1 Context7 citations (`/uniswap/v4-core`, `/uniswap/v4-periphery`, 2026-09-26); no new external claims made.

**Owner directives (verbatim, paraphrased only where noted):** (1) fix the existing route — RESOLVED (G1: modify idle single-token `exchangeIn`, selector preserved); (2) swap only current-call inputs — RESOLVED (G2); (3) sleeve = **20% of owned deployed reserve** — interpreted literally as `F_i = p·D_i` on vault-owned deployed principal; (4) proposed flow: **swap amountIn to proportional split → allocate/deploy-or-hold per fee-oracle sleeve → mint last** as proportional allocation of deployed + sleeve.

## 1. Directive 3: `F_i = p·D_i` — semantics, fixed point, endpoints, blast radius

Definitions: `D_i` = vault-owned deployed principal of token `i` (position amounts from liquidity only — current `_positionAmounts`, `Common.sol:461-478`, excludes uncollected fees); `F_i` = free balance incl. collected/uncollected fees (current `_freeBalancesForShareMath`, `Common.sol:626-631`); `T_i = F_i + D_i` (whole owned book, D9/D58).

**Fixed point (owner-requested derivation):** steady state requires `F = p·D` with `T = F + D`:
`F* = p(T − F*)` ⇒ **`F* = p/(1+p) · T`**. Compute the target **once from the call-start snapshot** `F*_i = p·D_i(snapshot)`; placement then executes to a fixed number and never chases a moving denominator. At `p = 0.20e18`: `F* = T/6 ≈ 16.67%` of total (matches the moderator PRD §4 arithmetic: "20% of deployed ⇒ 16⅔% of total").

**Endpoints:** `p = 0` ⇒ `F* = 0` (fully deployed). Oracle stored-0 = unset/fallthrough (D8) is unchanged; a *resolved* 0 yields zero sleeve — blocked amount-out then always reverts (the known §9 "0% liquid" risk; the 20% type default still guards it). `p = 1` ⇒ `F* = T/2`: the maximum expressible sleeve is now **half the book**. Under the old denominator, `p = 1` meant fully-free vault (local-buffer PRD §9). The knob's range compresses from `F/T ∈ [0,1]` to `[0, 1/2]` — a genuine semantic change, not a reparameterization.

**Fee component treatment (recommended):** uncollected fees count as **sleeve** (`F`), never as deployed principal (`D`). They are earned-but-unheld; current code already treats them as free for share math and moves them to free on collect (`Common.sol:648-667`). Consequence: fee accrual does not raise `F*` until collected *and deployed*; collecting fees refills the sleeve first — consistent with D58 count-once. **Owner confirm.**

**Blast radius:** `liquidReservePercentage` is a shared oracle knob (vault → type → global cascade; staking-SE sleeves are the behavioral peer, local-buffer PRD §0). Options: (a) V4-SE-local reinterpretation of the same value as "fraction of deployed principal" (documented in NatSpec/views) — minimal change, type-specific meaning; (b) global denominator change — silently alters staking SEs, out of scope; (c) new oracle field — rejected by D5. **Recommend (a)**, plus updating the reporting view `actualLiquidReservePercentage` (`LiquidReserveTarget.sol:69-83`, currently free/total) or it misreports policy. **Critical consequence:** the D7 20% default was sized as nested-cover headroom on TOTAL; under `p·D` it yields 16.7%-of-total cover. To preserve the original blocked-operation cover, the type default would need to be **0.25e18 of deployed** (= 20% of total). **Remaining owner choice O1.**

**Deadband:** keep `max(floor, 5% of targetFree)` (D22) applied to the new smaller target; absolute floor unchanged. The moderator PRD §2 (line 28) directly confirmed the existing test helper's 25%/50%-of-total slack — new tests must assert the strict per-token deadband, resolving my round-1 unverified note.

## 2. Directive 4: swap → allocate/rebalance → mint-last. Verdict: sound, and it dissolves the "issuance blocker"

**Core finding (this round's headline): once the caller's post-swap basket is aligned to the incumbent whole-book ratio, the EXISTING dual min-ratio branch is exact proportional issuance.** `Common.sol:700-704`: `shares = min(a0·S/T0, a1·S/T1)`. If `a0/T0 = a1/T1` both terms are equal → the caller receives exactly a pro-rata claim on the enlarged book, incumbents are neither diluted nor gifted, no new NAV, no new formula. The round-1 "approval-blocking issuance equation" shrinks to: **align the basket to `(T0:T1)` from a call-start snapshot, then reuse the existing branch.** This answers "proportional to post-swap LP ratio vs whole owned book": use the LP/CL ratio only for the *placement* step (how much can deploy), and the **whole owned book ratio** for the *composition/issuance* step (what the caller is credited). When the sleeve is skewed these differ; directive 4's decoupling (mint proportional to deployed+sleeve regardless of placement) is exactly what makes placement leftovers issuance-neutral — D32 residue becomes harmless dust, not an injustice.

**Recommended algorithm (idle single-token `exchangeIn`):**
1. Fee-collect if idle (existing `_collectManagedFeesIfIdle`, `Common.sol:648-667`) → fees land in `F`, counted once.
2. **Snapshot** `S`, `T_pre = (F+D)` at call start (pre-pull). This is the incumbent attribution base; donations already on the diamond belong to incumbents (D29) and are inside `T_pre`.
3. Pull `amountIn` (existing secure transfer / pretransferred measured-delta law).
4. Solve swap size `x`: post-swap basket `a_j = amountIn − x`, `a_k = out(x)` must satisfy `a_j/T_j = a_k/T_k`. `out(x)` is monotone; use the existing quoter with bounded interpolation — precedent exists at `Common.sol:182-200` (`_inventorySharesIn`, ≤8 probes + bisection). Bound with user `minCounterOut`/finite price limit (not the MIN/MAX tick limits at `Common.sol:669-670`); no TWAP mandate (moderator §7 agrees).
5. Execute swap + placement (add/remove only — D28 intact; a sleeve *deficit* may remove liquidity, which returns both tokens and never swaps) toward snapshot targets `F*_i = p·D_i(snapshot)`, within deadband, inside one unlock; atomic revert on bound/slippage/settlement failure (moderator ZR-4).
6. **Mint last:** `shares = _sharesOutForDeposit(a_j, a_k, S, T_pre_j, T_pre_k)` — the existing dual branch; enforce `minSharesOut`. Placement before mint is share-neutral because issuance reads only `T_pre` and the basket.

**Caller-basket vs incumbent attribution:** back out exactly the caller's net deltas: `T_pre_j = post_j − (amountIn − x)`, `T_pre_k = post_k − out` (extends the existing back-out pattern, `InBase.sol:287-290`). Fees earned *during* the caller's swap accrue on incumbent L (position L at snapshot; caller not yet deployed) → incumbents keep them; recommend the call-start snapshot (conservative, simple) — alternative post-swap snapshot shares recycled self-LP fee with the caller. **Owner choice O3.** Self-LP fee recycle and the caller-swap price effect on the vault's own full-range position are genuine but bounded market effects on incumbents; quantify in ZA-7, don't pretend they are zero (moderator §6.6).

**Donation/pretransfer:** measured-delta pulls + call-start snapshot + inside-unlock callback authentication (`Common.sol:996-999`). A hostile hook transferring tokens to the diamond mid-callback cannot enter `T_pre` (snapshot predates it) and cannot join the caller basket (basket = swap-measured deltas); residual lands in free → incumbents, caught by `_syncVaultReserves` — same as today's D29 surface. ZA-10 must prove this.

## 3. Numerical examples (fee/impact ignored, π = 1 token1/token0 for illustration)

**E1 — skewed book, abundant-token deposit (the reported bug).** Book `T=(160,100)`, `S` supply. Caller deposits 10 token0.
- Today: invariant-growth single-side = `S·(√(170·100)−√(160·100))/√(16000)` = `S·(130.38−126.49)/126.49` = **0.0308·S**, and ~8 of the 10 strand in the sleeve forever.
- Directive 4: solve `(10−x)/160 = x/100` → `x = 3.846`; basket `(6.154, 3.846)`; shares = `6.154·S/160` = **0.0385·S**; both tokens deployable above `F*`. Caller gains more shares *and* the deposit becomes productive; incumbents hold an unchanged fractional claim on a proportionally enlarged book.

**E2 — skewed book, scarce-token deposit.** `T=(100,140)`, deposit 10 token0 (book-short side).
- No-swap invariant: `S·(√(110·140)−√(100·140))/118.32` = **0.0489·S** (deposit improves balance; CP rewards it), but excess token1 remains stranded.
- Directive 4: `x = 10·140/(140+100) = 5.833`; basket `(4.167, 5.833)`; shares = `4.167·S/100` = **0.04167·S** — fewer shares than no-swap, minus swap fee. **Trade-off to disclose:** always-compose sacrifices the CP balancing reward on scarce-side deposits in exchange for deployability. Alternative (owner choice **O4**): skip composition when the raw deposit already improves the book ratio, accept the stranded-counter-token residue. I recommend **always-compose** for predictable deployability and uniform previews, but this is a genuine economics choice, not a blocker.

**E3 — sleeve target.** `T=(100,100)`, `p=0.2`: old target `(20,20)`; new `F*=(16.67,16.67)` (i.e., `p·D` at steady state `D=(83.33,83.33)`). Blocked-cover per token drops 16.7% — see O1.

## 4. Preserved law

Dual bootstrap (D59: one-sided activation still reverts, `Common.sol:693-695`), full-range imports (D57; moderator-resolved), native/WETH face + PoolKey order + wrap/unwrap settlement (`Common.sol:411-425, 1096-1118`), blocked sleeve path (D2/D4/D18; mints with existing blocked-route economics, no swap/unlock), public `rebalanceLiquidReserve` add/remove-only (backlog not repaired — G2). Multi D45/D47 untouched.

## 5. Remaining owner choices (concrete)

- **O1:** type default under new denominator: keep `0.20e18` (=16.7% of total cover) or raise to `0.25e18` of deployed (=20% of total, preserves D7's nested-cover rationale). Recommend 0.25e18.
- **O2:** confirm uncollected fees = sleeve (recommended), excluded from `D`.
- **O3:** attribution snapshot at call start (recommended; incumbents keep swap-time self-LP fees) vs post-swap (caller shares recycle).
- **O4:** always-compose (recommended) vs skip-composition when deposit already improves book ratio (E2).
- **O5:** bound exposure: user `minCounterOut` + `minSharesOut` + finite price limit (recommended); no oracle mandate.
- **O6:** V4-local NatSpec/view reinterpretation of `liquidReservePercentage` as "of deployed principal" (recommended) — global oracle change stays out of scope.

## 6. Confidence and gaps

High: fixed-point algebra, existing-branch sufficiency once basket-aligned (`Common.sol:700-704` read directly), endpoint/blast-radius analysis, numerical examples. Medium: solver convergence bounds against manipulated quotes (needs the bounded-probe spec + tests ZA-9/15). Gaps: no tests run; exact upstream port pin still unestablished; E1/E2 ignore fees/impact by construction — implementation spec must redo them with real fills. This report proposes requirements; it authorizes nothing.

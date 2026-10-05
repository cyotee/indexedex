# Kimi K3 original — search-free Hookless SE redesign

**Date:** 2026-10-03. Independent first pass. No peer originals read. Research only; no implementation. No measured gas claims. No consensus claims.

## 0. Where the searches actually are (composition ≠ maintenance)

Two distinct sizing loops exist today, and they are separable:

1. **Caller composition** — `UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner._composition` (`contracts/.../fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108`): binary search over swap input `x ∈ [0, credit]`, `MAX_REFINEMENTS = 32` (:23), each probe a full forward swap simulation (`_compositionCandidate` :110–156 → `Quotes._tryForward`, `UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:67–71`), bounded at 64 core steps per simulation (`docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:251`). This is a **user-operation** search and is the real target.
2. **Holder repair** — `_maintenance` (:168–214): 2 directions × 2 funding domains × ≤16 probes (impl plan :253). This is **maintenance**, separately callable (`rebalanceLiquidReserve`), already permitted bounded-solver work (`PRD §6.4`, `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:238`). Removing it from the deposit path does **not** remove composition sizing; the prompt is correct to force the distinction.

Why composition resists closed form: the required basket ratio is `B′₀(x)/B′₁(x)`, the **post-swap** incumbent book. `B′` depends on `x` through position repricing (`_afterSwap` :158–166), own-LP fee accrual at the traversed price, and placement rounding; `out(x)` is a step function across tick-bitmap boundaries. A self-referential ratio against a path-dependent, discontinuous function has no general arithmetic inverse. Prior DER inverse candidates were reviewed and **not adopted** (impl plan :150, :356 — including my own earlier proposals; I do not re-litigate them here).

Exits are already search-free in exact-in: F6 removes `floor(l·shares/S)` and converts the **entire** opposing entitlement forward (impl plan :131–135); only exact-**output** inversion was rejected. So the redesign scope narrows to: **the single-token deposit composition**.

## 1. Ranked recommendation

**Rank 1 — Proportional dual core + refund, conversion moved out of the vault (sketches 1+4 merged).**
Deposits become dual-token proportional joins against the **pre-placement, pre-any-swap** incumbent book; excess leg refunded exactly. In-kind proportional exits stay (already search-free). Blocked single-token exits stay (linear CP valuation against local cover — closed form, not a search). On-chain single-token→shares composition is **removed** (idle `exchangeIn(token→shares)` becomes `InvalidRoute`; blocked F1 linear mint stays). Single-token UX is provided by the caller or by Orbital executing **one ordinary exact-in swap of a caller-chosen size** plus the dual join. Maintenance keeps its bounded solver as a separate permissionless call, never interleaved in user ops.

**Rank 2 — Rank 1 plus a narrow-domain closed-form zap (sketch 3)** as a later optimization: single-token zap only when the swap provably stays in one core step, book is already proportional within 1 bp, placement rounding stencil is unchanged, and fee accrual is exactly accounted; fallback to Rank 1 otherwise. Fragile domain checks; do not gate the redesign on it.

**Rank 3 — Spot/TWAP NAV single-token mint (sketch 2): reject as primary.** Ratio-matching (not value-matching) is what currently blocks same-transaction price-manipulation of the mint. A NAV mint against the same pool the vault LPs in is manipulable within one transaction; TWAP adds oracle dependence and stale-price arbitrage. Charm's "range orders can only be manipulated higher" comment covers its **proportional dual** deposit, not single-sided NAV — it does not rescue this option.

## 2. What changes, per design

### Rank 1 (recommended)

- **Stays:** full-range position; fungible shares; `B = D + F + E` counted once; F0 dual activation with `MINIMUM_LIQUIDITY` dead sink; pretransfer law; full booking; live-oracle sleeve target `targetFree = floor(T·p/(1e18+p))` with deadband; blocked-state sleeve-only ops with actual-cover checks; direct PoolManager; 25/10/1 bp protections; separate bounded maintenance; Pons family separation.
- **User sees:** single-token idle deposit reverts `InvalidRoute`. Dual deposit takes `(a0max, a1max)`, consumes `C_i ≤ a_i`, refunds `a_i − C_i` exactly. Dual/single exits unchanged. Depositor slippage protection is per-leg `minShares` + the structural ceil (never `minOut = 0`).
- **Goes away:** caller-composition swap, 50 bp composition-impact bound (vacuous for deposits), `AlignmentNotAchievable` path, post-swap-ratio targeting (D5), incumbent-repricing-during-deposit attribution.

### Rank 2 adds: a restricted zap route with explicit domain certificate; user sees single-token deposits succeed only inside the certified domain, else `InvalidRoute`.

### Rank 3 would change issuance to value-based mint — rejected; it trades away manipulation resistance and the 1 bp alignment guarantee's current meaning.

## 3. Exact equations and domains (Rank 1)

State: incumbent `B_i = D_i + F_i + E_i` (caller credit excluded, E collected once via fee-growth checkpoints), supply `S`, position liquidity `l`.

**Dual deposit (idle or blocked), positive two-leg book.** Given declared max legs `(a₀, a₁)`:

```
m   = min( floor(S·a₀/B₀), floor(S·a₁/B₁) )        ; revert if m == 0
C_i = ceil(m·B_i/S)                                ; consumed, rounds against depositor
r_i = a_i − C_i ≥ 0                                ; exact refund
B_i′ = B_i + C_i ;  S′ = S + m
```

Conservation / non-dilution: `B_i′/S′ ≥ B_i/S ⟺ C_i/m ≥ B_i/S`, true since `C_i ≥ m·B_i/S`. Incumbents can only gain rounding dust; the depositor's per-leg loss is `< 1` unit, so the 1 bp alignment bound holds whenever `m·B_i/S ≥ 10⁴` units; below that, **revert** (no silent relaxation — bounds changes are owner decisions). Placement after mint uses the existing closed-form stencil: `budget_i = T_i − target_i`, `l* = getLiquidityForAmounts(q, a, b, budget₀, budget₁)` evaluated at `l*` and `l*−1` only (impl plan §3:162–166; v4-core `LiquidityAmounts`, Context7 `/uniswap/v4-core`, accessed 2026-10-03) — no adaptive loop, unchanged from today.

**Empty domain (`S = 0`):** F0 dual activation unchanged; `raw = mulSqrt(a₀,a₁)`, shares `= raw − MINIMUM_LIQUIDITY` to the caller, minimum to `0xdEaD`. Single-token activation stays invalid.

**One-sided book (`B₁ = 0`, price at range extreme):** require `a₁` fully refunded (`C₁ = 0`), `m = floor(S·a₀/B₀)`; never mint against a donated opposite leg (mirrors impl plan :127's linear-rule condition). Symmetric for `B₀ = 0`.

**Blocked (already-unlocked) domain:** no placement, no swap; deposit books `C_i` into `F`; withdrawal pays `floor(m·F_i/S)` per requested currency from actual local cover, reverting atomically on shortfall (PRD §4:111–115). Blocked single-token exit keeps the existing linear CP valuation — closed form.

**In-kind exit (idle):** burn `m`, remove `l_m = floor(l·m/S)`, collect fees once, pay each leg's measured pro-rata; rounding residual stays booked (retain-and-sweep-later). Single-token idle exit swaps the **whole** opposing entitlement forward (fixed size — no discovery).

**Fees:** `E_i += floor(ΔfeeGrowthInside_i · l / 2¹²⁸)` projected once; collection moves `E→F`; neither collection nor placement creates backing.

**Orbital-callable interface (no router-with-search):** (a) view returning `(B₀, B₁, S, l, sqrtPrice)` — one staticcall; (b) `exchangeInManyToOne([a₀max, a₁max], minShares, recipient, …)` with exact refund — already the R7 surface; (c) Orbital's own buffer/pair swap with caller-supplied or default `x` (e.g. half-by-value at current price), refund absorbing error. Orbital already composes nested SE legs via `quoteTransition` and `exchangeIn` (`UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:43,65,92,378`; `UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol:91,143,215,256`); it is itself an AMM and can source the conversion leg autonomously. Residual from refund is ordinary Orbital buffer inventory.

## 4. Sleeve policy and blocked cover

Adopt **placement-reserved sleeve + separate maintenance restore**: placement reserves `target_i` per token from the live oracle `p` (both tokens may miss target simultaneously after joins; deadband governs when maintenance acts). Maintenance is a separate permissionless call with the existing 25 bp bound, 1 bp proportionality metric, placement-first preference, and truthful no-op. Not adopted: continuous interleaved rebalancing (that is what made user ops searchable); purely accidental residual sleeve (violates "useful sleeve"). Blocked operations pay only from actual local cover — unchanged law, no unlimited-withdrawal promise.

## 5. Orbital / SY / Pons consequences

- **Invalid after redesign:** nested single-token `exchangeIn(token→SE shares)` and its `quoteTransition(DepositExactIn)` previews — the 11-`quoteTransition`, ~547-`extsload` pattern (historical, unverified trace; not a fresh measurement).
- **Replacement (search-free, autonomous):** Orbital reads `(B,S)` once, does one own swap, calls dual join; per-leg `minShares`/slippage parameters it can compute arithmetically. SY `deposit`/`redeem` map to the same dual join / in-kind exit (R9 equivalence preserved). Native SY `NativeStandardYieldTarget.sol:20–77` semantics unchanged.
- **Pons:** D22 separation stands; the same amendment applies to the Pons family implementation in parallel (its F4 hook charge `h(n)` applies to Orbital's own swaps, not to any vault composition, which no longer exists). Do not merge families. Pons needs its own owner sign-off on dropping single-token composition.
- **Remaining outer searches (named):** (i) the caller's/Orbital's choice of external swap size `x` — an economic input, not a discovery loop; refund makes any `x` safe; (ii) maintenance's bounded solver — retained by design, separate call; (iii) blocked exact-share mint inverse — linear, closed form.

## 6. D1–D31 amendments (Rank 1)

- **Amend:** D1 (single-token `exchangeIn` composition removed; owner approval required — this is the named trade-off); D2 (composition-swap funding rule vacuous for deposits; keep for maintenance); D4 (order becomes fund → allocate → mint); D5 (post-swap whole-book targeting repealed — no caller swap); D7 (excess **refunded**, not retained; if the owner prefers retain-and-credit, that is Rank 3 territory and needs explicit approval); D17–D19/§6.4 (composition exact-output/interleaving questions become moot; route matrix shrinks: R3 idle dual-only, R4 `InvalidRoute`); D20 (50 bp composition bound vacuous; 25/10/1 bp unchanged, still fixed constants per D25).
- **Unchanged:** D3 (sleeve), D6 (proportional issuance — now the only path), D8–D16, D21–D31 (families, manager/hook bindings, removal gate, preview==execution — now easier to satisfy).

## 7. Risks

- **Manipulation/donation:** min-formula + ceil-consumed + exact refund is donation-safe; unsolicited transfers remain donor risk under existing pretransfer law. Deposits no longer reprice incumbents at all (risk *shrinks*); maintenance swaps still reprice, bounded, accruing to the book.
- **Fee ownership:** unchanged single-count discipline; placement rounding charged as today (caller-attributable only for its required placement).
- **Rounding:** per-leg `< 1` unit depositor cost; tiny deposits revert rather than silently breach 1 bp.
- **Residual/free-ride:** refunds must settle before final booking sync (D16).
- **UX/liquidity regression:** single-token entry now costs the user an external swap; Orbital preserves it for nested flows. This is the honest price of removing the search.
- **Charm/Arrakis/Gamma as precedent:** Charm `AlphaVault` verified primary (`deposit` proportional via `_calcSharesAndAmounts`; separate strategy-only `rebalance(int256 swapAmount,…)`) — note its rebalance takes a **manager-supplied swapAmount**, which the prompt correctly forbids copying into an Orbital-unpopulatable interface; we keep our own bounded solver instead. Charm is a V3 vault *configurable* to wide ranges, not inherently full-range. Arrakis/Gamma/Range not re-verified this round — leads only.

## 8. Acceptance and benchmark plan (for a later agent; not executed)

1. Route matrix update: R3 idle single-token → `InvalidRoute`; dual join preview == execution bitwise (D30); refund exactness; Orbital nested deposit end-to-end on `TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` / `V4FundedBindings.t.sol` fixtures (both exist).
2. Invariants: `B_i/S` non-decreasing across deposits; fees counted once; full booking after refunds; blocked cover shortfall reverts atomically; one-sided and near-`MIN_TICK`/`MAX_TICK` domains; empty-book activation.
3. Adversarial: same-tx price manipulation attempts against the join (expected: no extraction vs. old composition baseline); donation/re-credit negatives.
4. **Later** measurement (no claims now): matched-state gas of old `_composition` planner vs. dual join, and nested Orbital `planDeposit` against the 31M SY / 32M chain caps. Measure first; report; only then claim any win.

## 9. Evidence, confidence, gaps

- Local: TransitionPlanner.sol:23,73–108,168–214; QuoteService.sol:67–71,113–131; PRD `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:28–57` (D-table), `:132–159` (sleeve), `:108–115` (blocked), `:238`; impl plan `:129,135,148,150,162–166,251–257,356`; Orbital ExitQuoteLib.sol:43–378, DepositCore.sol:91–256; Crane `UniswapV4ZapQuoter.sol:145–186` (confirmed binary search — discussed, no gas assertion).
- External: Charm `AlphaVault.sol` (github.com/charmfinance/alpha-vaults-contracts, `main`, pragma 0.7.6, accessed 2026-10-03); Context7 `/uniswap/v4-core` `LiquidityAmounts`/`SqrtPriceMath` docs (upstream `main`, not version-pinned, accessed 2026-10-03).
- **Confidence:** high on where the searches live and on the conservation math; medium on Orbital's willingness to absorb the conversion leg (needs owner/product sign-off); the 19.97M gas trace remains unverified historical.
- **Gaps:** no fresh gas measurement (by instruction); Arrakis/Gamma/Range primaries not read this round; Rank 2's domain certificate not derived; Pons-family parallel amendment not specified in detail.

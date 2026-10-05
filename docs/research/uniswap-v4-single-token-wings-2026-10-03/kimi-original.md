# Kimi K3 original — mandatory scalar routes with one-sided wings

**Date:** 2026-10-03. Independent first pass for the wings question. Retained session history acknowledged; no peer artifacts (prior or current) read this round. Research only; no implementation; no consensus or measured-gas claims.

## 0. The controlling decomposition: placement ≠ valuation

The binary search in today's design (`TransitionPlanner._composition`, `.../fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108`) exists to satisfy one rule: mint shares only when the caller's basket matches the incumbent whole-book ratio. A wing — a one-sided out-of-range position — changes **where deposited assets sit**, not **how many shares a single-token deposit deserves**. Pricing arbitrary token A against an existing A+B book requires an ownership-admission rule, and no placement geometry supplies one. So every search-free scalar design is a pair: (admission rule, placement rule). The human's wing proposal is adopted here as the placement layer; the admission rule is the real decision, and it is an owner-level economic choice, not an engineering detail.

On "only removing binary search": integer square roots and fixed-stencil position math are deterministic arithmetic with constant iteration counts, not probe sequences discovering an economic amount. Bounded iteration over a fixed position set (≤5 positions below) and tick traversal of an already-sized swap are likewise not sizing searches. Under that clarification, search-free scalar routes are achievable. If the policy instead demanded "no derived sizing at all," even the exact-share inverse would be suspect — that reading is not adopted.

## 1. Ranked designs

**Rank 1 — Internal invariant admission (existing blocked CP model extended to idle) + wing/core placement + permissionless consolidation.** The vault already contains a search-free scalar admission rule, used today only while blocked: `_sharesForDeposit`'s single-sided branch, `_amountInForShares`, `_singleExit` (`contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:37,78,98,113`, verified this session). Extend it to idle; deposits place into wings; exits fund from sleeve → wing removal → core removal cascade (§3). No swap, no probe, no oracle on any ordinary call or quote. Cost: holders internalize the deposit/withdraw imbalance; the internal price `B1/B0` diverges from the pool between maintenance events, creating an arbitrage the book pays. Mitigations: explicit spread charge λ on scalar routes (new owner-approved fee), frequent permissionless consolidation, and a new internal-divergence bound (§5). This is the only candidate that keeps scalar SE/SY routes synchronous, fungible, autonomous, and oracle-free.

**Rank 2 — Wing placement + independent TWAP/oracle admission.** Mint `m = floor(S·v(C)/V(B))` with `v` from a TWAP or external oracle. Search-free, but imports staleness arbitrage, availability and governance dependencies, and denomination questions; spot-price variants are manipulable within one transaction. TWAP admission is not impossible — it is a priced risk the owner must buy knowingly. Rank below Rank 1 because it adds an oracle where the internal model needs none.

**Rank 3 — Restricted analytic conversion (single-candidate reject-policy zap).** Evaluate one candidate swap size exactly and revert outside its certified domain. Search-free by definition; liveness unproven (a nearby passing integer may exist when the candidate fails). An optional optimization layered on Rank 1, never the backbone.

**Rank 4 — Epochs / separately owned pending deposits.** Breaks synchronous fungibility and SY/ERC-4626-style composability; the question forbids async receipt tokens as a substitute. Rejected as primary.

## 2. Wing mechanics (fair analysis of the human sketch)

**Orientation (source-exact).** Per v4-core `LiquidityAmounts.getAmountsForLiquidity` (Context7 `/uniswap/v4-core`, `test/utils/LiquidityAmounts.sol`, accessed 2026-10-03): `q ≤ sqrtA` ⇒ position holds token0 only; `q ≥ sqrtB` ⇒ token1 only. So a **token0 wing** is a band `[a,b]` fully *below* the current tick; a **token1 wing** fully *above*. Out-of-range wing principal is a price-independent exact token amount — this kills any valuation circularity in backing inputs (the double-sided core still reprices with `q`, as today).

**Range-order behavior.** An out-of-range one-sided position is a fee-earning limit order (Uniswap Labs, "Introducing Uniswap v3," 2021-03-23, https://blog.uniswap.org/uniswap-v3, accessed 2026-10-03): crossing the band converts the token along a smooth curve; full execution prices at the geometric mean of the bounds; and — the documented caveat — a crossed position **converts back** if price reverses while liquidity stays. Vault-owned wings keep both conversions' fees in the book; reversal costs the book the round-trip conversion but no fee loss. Consolidation timing therefore trades fee capture against reversal exposure.

**Bounds, salts, aggregation.** V4 positions key on `(owner, tickLower, tickUpper, salt)`. Policy: at most one *active* wing per side plus one *crossed* wing per side awaiting consolidation — hard cap **5 positions** (1 core + 2 active + 2 crossed). Bands are tickSpacing-aligned windows at deterministic offsets from the anchor tick; salts derive from band index, so successive deposits into the same side aggregate into one position via ordinary liquidity increase. State queries iterate a fixed ≤5-element set: explicit constant gas bound.

**Mint amounts and rounding.** Wing liquidity `l_w = getLiquidityForAmount0(sqrtA, sqrtB, budget0)` (round down; token1 symmetric). Settlement debts round up, removal proceeds round down (existing CC discipline, impl plan `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:162–166`). Wing fees accrue via per-position `feeGrowthInside` checkpoints and count once in `E`.

**While already unlocked (blocked):** no `modifyLiquidity`; caller funds book to sleeve `F` exactly as today's F1/F2 (`PRD §4`, `UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:108–115`). No nested unlock; no unlimited blocked withdrawals.

**Consolidation.** Trigger: active wing fully crossed (`q ≥ b` for a token0 wing) or crossed-wing age/threshold policy. Steps: remove wing fully → proceeds `(x0, x1)` (rounded down at settlement); compute core add `l_add = getLiquidityForAmounts(q, coreA, coreB, x0 + budget0, x1 + budget1)` against sleeve-reserved budgets; add; **residual leg is retained and booked** (existing residual law) or routed to the opposite side's active wing. An in-range wing does *not* hold the core's required ratio — consolidation must not assume it; the residual is structural, not an error. Consolidation mints no shares; rounding costs accrue to the book (holders), matching current repair law. If the residual cannot deploy, it waits in `F` — nothing forces deployment. Keeper failure is safe: wings remain in backing `D` and remain removable for exits; only fee optimization degrades.

## 3. Exact admission, exit, and funding equations

Book `B_i = D_i + F_i + E_i` with wings inside `D`; caller credit excluded; fees counted once; `S > 0`. (Empty/one-sided: F0 dual activation with dead-sink minimum stays; single-token into empty book reverts; one-sided book uses the existing linear branch on the positive leg only, rejecting donations to the empty leg.)

**Scalar deposit of `c` in token_in (idle or blocked), internal invariant admission:**
```
K = ceil( sqrt(B_in * B_other) )
A = floor( sqrt((B_in + c) * B_other) )
m = A > K ? floor( S * (A - K) / K ) : 0      ; revert if m == 0
```
**Exact-share inverse (closed form):** `A_req = K + ceil(m*K/S)`; `c_req = ceil(A_req² / B_other) − B_in`. These are the existing integer branches, not new math.

**Scalar exit of `r` shares in token_out:**
```
u = floor(B_out * r / S);  v = floor(B_other * r / S)
y = u + (v == 0 ? 0 : floor((B_out - u) * v / B_other))
```
**Funding cascade for `y` (idle):** (1) sleeve `F_out`; (2) shortfall `s` → remove from the token_out wing: `l_rm = getLiquidityForAmount0(sqrtA, sqrtB, s)` rounded **up**, with a fixed +1-liquidity-unit stencil (two candidates, not a loop); (3) residual shortfall → core removal sized by the closed-form liquidity-for-amount inverse at current `q`, round up, settle, verify; the core's other-token proceeds stay booked in `F`. Final cover still short ⇒ atomic revert. Blocked: step (1) only. Exact-output share exits stay `InvalidRoute` beyond the linear one-sided branch — the two-leg inverse is bisection (`StandardExchangeConstantProduct.sol:113–128`) and is not adopted. **Exact-input scalar routes are preserved; exact-output inverses keep today's domains.** That distinction is explicit per the question.

**Conservation.** Mint: `B′ = B + c·e_in`, `S′ = S + m`. Exit: `B′ = B − y·e_out`, `S′ = S − r`. Placement/consolidation move `F ↔ D` only. At fixed external state, conservative rounding gives `B′₀B′₁/(S′)² ≥ B₀B₁/S²` for these scalar ops and proportional joins: no costless fixed-state round trip. **This is not cross-state economic safety** — divergence between the internal ratio and the pool price is exactly where holders pay. I do not claim the fixed-state inequality proves more.

## 4. Orbital / SY surfaces and outer searches

Search-free autonomous calls under Rank 1: `exchangeIn(token→shares)` and its preview/`quoteTransition(DepositExactIn)` become the closed-form mint above (idle and blocked); `exchangeIn(shares→token)` becomes the funded exit; `exchangeOut(token→shares)` is `_amountInForShares`; SY `deposit`/`redeem` remain aliases (R9 equivalence). Minima/maxima stay meaningful: `minShares`/`minOut` against deterministic previews; preview == execution at identical state.

Outer searches, dispositioned:
- `_faceForClaim` (`OrbitalBufferHookExitQuoteLib.sol:347–373`) and `_invertBufferForEffective` (`OrbitalBufferHookClaimLib.sol:250–273`): **eliminable** — replace with one `_amountInForShares` evaluation plus rate projection. This is an **explicit Orbital product change**, not a Hookless side effect. Note the source detail the question flags: their `while (low < high)` loops continue past the 8 interpolation probes via plain bisection (`ExitQuoteLib.sol:357–370`, `ClaimLib.sol:265–273`), so worst-case iterations are logarithmic in the amount domain, not 8.
- `zapSplitWad` (`UniswapV4StandardExchangeOrbitalBufferHookMath.sol:270,317`, loop `:336` bounded at 64): sphere-residual balancing, Orbital-internal; **retained with disclosure** or deferred to an Orbital round. With closed-form SE legs each probe is constant-cost, but I do **not** claim end-to-end search freedom while it remains.
- Idle redemption quotes currently append `_maintenance` (`InQueryTarget.sol:150,184–186`): removed from user/quote paths in all ranks.

## 5. Protections, fees, and what changes economically

No user-path swap exists under Rank 1, so D20's 50 bp composition-impact bound becomes **vacuous**, not relaxed. Retained with unchanged meanings: 25 bp on external maintenance swaps, 10 bp execution shortfall on any executed external swap, 1 bp alignment for basket joins. **New, requiring explicit owner approval:** (a) a spread/imbalance charge λ bp against scalar-route admission to compensate holders for internalized imbalance; (b) an internal-divergence trigger `|B1/B0 − pool-implied ratio|` beyond which scalar routes throttle to basket-only until consolidation — a new metric, not a silent migration of the 50 bp meaning. Sleeve policy unchanged: live `p`, `target = floor(T·p/(1e18+p))`, deadband; wings count as deployed principal.

## 6. D1–D31 amendments (Rank 1)

Amend: **D1** (route kept, composition swap removed); **D2** (caller-swap funding vacuous); **D4** (credit → invariant mint → wing placement); **D5** (post-swap ratio targeting repealed — no swap; replaced by invariant-growth admission); **D6** (the single-sided invariant branch becomes the *sanctioned* scalar path — currently forbidden as a silent substitute; this is the central owner approval); **D7** (full credit including wing-placed portion); **D17–D19** (interleaving moot for scalar routes; exact-output domains unchanged); **D20/D25** (new λ and divergence bound added as fixed constants; existing values untouched); **D21** (maintenance target expands to wing lifecycle: anchor bands, consolidate crossed wings, placement-first, then ≤1 bounded swap). Unchanged: D3, D8–D16, D22–D24, D26–D31 (families, bindings, removal gate, preview parity). Orbital held-rate addendum and B6 flexible-share law unchanged; rate providers never valued via trade-sized quotes. DETF/SY: aliases preserved; no law change beyond the H route semantics. Pons orchestration/fees untouched absent explicit approval.

## 7. Risks and attacks

- **Divergence arbitrage:** primary cost. Depositor buys the cheap internal leg; holders fund convergence. Mitigated by λ, divergence trigger, consolidation cadence; magnitude unquantified — gate below.
- **Donation:** source-agnostic surplus still movable into `B`, shifting `B1/B0` — same class as today, now with admission-price impact; dust-griefing bounded by deadbands/minimums and the 5-position cap (outsiders cannot add to vault-salted wings).
- **Wing reversal:** crossed wing re-converts on price reversal (documented range-order behavior); consolidation policy must price this trade-off.
- **Consolidation sandwiching:** maintenance swaps remain 25 bp-bounded; consolidation itself is swap-free.
- **Rounding:** ceil-side against callers on mint, floors against exits; per-leg <1-unit effects; tiny deposits revert.
- **Keeper failure:** safe degradation, never lockup — wings stay in `D` and removable.

## 8. Later acceptance / benchmark plan (not executed)

Integer reference vs implementation over exhaustive small domains; preview == execution bitwise; wing lifecycle suites (place, partial/full cross, reversal, consolidation with residual, cap enforcement, dust); blocked cover atomicity; Orbital end-to-end asserting zero probe-loop iterations on `_faceForClaim`/`_invertBufferForEffective` after the named Orbital change; divergence-arb quantification matrix (simulated price paths, λ calibration evidence); then — later, pinned states — gas/quote-count measurement against the 31M/32M caps. No numbers predicted here.

## 9. Evidence, confidence, gaps

Local (read directly, this session or pass 1): `TransitionPlanner.sol:23,73–108,168–214`; `QuoteService.sol:113–141`; `StandardExchangeConstantProduct.sol:37,78,98,113`; `InQueryTarget.sol:82,150,184–186`; Orbital `ExitQuoteLib.sol:347–373`, `ClaimLib.sol:250–273`, `OrbitalBufferHookMath.sol:270,317,336`; PRD `:28–57,108–115,132–159,238`; impl plan `:162–166,251–257`; fixture `TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:40–53` (distinct opposite tokens per nested SE). External: Context7 `/uniswap/v4-core` `LiquidityAmounts` (accessed 2026-10-03, upstream `main` unpinned); Uniswap Labs v3 announcement, range orders (accessed 2026-10-03); Charm `AlphaVault.sol` (accessed 2026-10-03 — base + single-sided bid/ask order precedent; manager-driven, not autonomous). Compiler baseline: Solidity 0.8.35, runs 1, no via-IR (PRD §15:532). **Confidence:** high on source mechanics and equation provenance; medium on Rank 1's economic acceptability pending the divergence-arb quantification; low on consolidation cadence calibration. **Gaps:** no λ calibration evidence; no crossing-frequency data for target pools; V4 pool manager multi-position salt semantics assumed from v4-core position keying (Context7) — worth a dedicated verification task; no gas measurements by instruction. Missing ordinary files: none this round.

# Wings clarifications — Kimi K3 original (independent pass)

**Author:** Kimi K3. **Date:** 2026-10-05. No peer artifacts read. Research only. PRD read: `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (v0.1). Formula evidence: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`. Nothing below claims any formula is safe; existing code is evidence of mechanism, not of economics.

## 1. Settled clarifications mapped (not reopened)

- **Local reserve tracking = custody only.** `R_i` = tokens locally held by the vault, never deployed principal. Matches PRD §4 (`:65`: "durable local custody snapshot, not economic backing") and C1 (`:106`: external price moves must not manufacture credit).
- **Sleeve % is of vault-owned deployed reserves, not pool reserves.** `F_i = p·D_i`, `D_i = Σ_j D_ij` over the vault's own three positions. Post-placement check: `targetFree_i = floor(T_i·p/(1e18+p))`, `T_i = F_i + D_i` (PRD S1 `:164-169`; zap PRD precedent `:32,:143`). Numeric meaning: at `p = 0.20e18`, **F is 1/6 ≈ 16.67% of T, not 20%** of total; `p = 1e18` targets F = D (half of T). `E` (uncollected fees) is excluded from the target base until collected (S1 `:171`) but included in mint/exit backing `B = F + ΣD + ΣE`.

## 2. Precise economic semantics

- **R (custody snapshot):** what delivery/credit checks may touch. Funding and refunds come from R only.
- **F (spendable local):** R minus this-call credit/liabilities; the sleeve; the *only* payout capacity while blocked.
- **D (deployed principal):** exact finite-range math per position at current state; re-ratios with pool price without any vault action.
- **E (uncollected own fees):** counts in backing once; E→F exactly once on collection.
- **B (backing):** the valuation book for mint/burn. **Key structural fact:** B's token ratio is *not* the pool price, because F (≈1/6 of T) does not re-ratio with the pool while D does. This decoupling drives §5.

## 3. No-swap single-sided issuance — the mechanism already exists as evidence

`StandardExchangeConstantProduct._sharesForDeposit:37-65` implements single-token mint without any swap:

- Both legs offered → min-ratio (`:52-56`). **Min-ratio zero:** `C_1 = 0 ⇒ m = min(S·C_0/B_0, 0) = 0` — scalar entry is impossible under B2 alone; a conversion rule is mandatory, which is exactly PRD B3 (`:143`).
- Single-token, both reserves positive → **invariant-growth mint** (`:58-64`): `K = ceil(sqrt(r0·r1))` (denominator rounded up, `:59-61`), `K' = floor(sqrt((r0+c)·r1))`, `m = floor(S·(K'−K)/K)`; `K' ≤ K ⇒ 0` (`:63`).
- One-sided book → linear branch `mulDiv(c, S, r)` (`:50-51`).
- Exact-out inverse `_amountInForShares:78-96`; redemption `_singleExit:98-111` (proportional burn, then other-entitlement converted through the remaining book); exit inverse `_sharesForSingleExit:113-129` (bisection, ceil).

**Proof (invariant-per-share preservation, real arithmetic).** Mint `m = S·(K'−K)/K`. New supply `S' = S·K'/K`. GM-per-share after = `K'/S' = K/S` = before, exactly. The deposit grows the invariant; the mint equals the relative growth; incumbents' geometric-mean backing per share is untouched. **So yes: share accounting can preserve invariant-per-share value for single-sided deposits with no balancing swap** — the zap's composition swap is performed *virtually* against the vault's own CP-valued book.

**Corollary (small-deposit fairness).** For `c << r0`, `m ≈ S·c/(2·r0)`; valued at the internal marginal price `r1/r0`, the mint is worth `≈ c·r1/r0` — full marginal value; the depositor's cost appears only at second order (`≈ c²/8r0²` relative), i.e. the impact a real swap would have charged, accruing to incumbents.

## 4. What is preserved vs not (four distinct notions)

| Notion | Preserved? | Why |
|---|---|---|
| Invariant (GM) per share | **Yes, exactly** (modulo floor rounding against the joiner) | §3 proof |
| Market value per share (external numeraire) | Only insofar as B's ratio equals market price | mint prices the virtual conversion at B's internal ratio, not at an oracle |
| Underlying quantities per share | **No — by design** | per-share deposited-token entitlement rises, other-token falls; every single-sided entry re-flavors all shares |
| Payout capacity | **No — separate axis** | a token0-only deposit raises only F_0; blocked token1 payouts are unchanged; quote ≠ capacity (`_inventoryRedeem` comment: values inventory even when sleeve cannot pay) |

## 5. Concrete numerical counterexample — the sleeve-decoupling window

Book `r0 = r1 = 1,000,000`, `S = 1000`, 1:1 market. Attacker moves the **pool** to `r0 = 4,000,000 / r1 = 250,000` (k unchanged 1e12) — but suppose the vault holds a 1/6 sleeve that does **not** re-ratio: vault B becomes e.g. `(3.4e6, 4.17e5)`-style skewed *less* than the pool (D tracks pool, F static), so B's internal price deviates from both the old and the new market. Two directions:

- **Deposit the pool-cheap token (token0, 1,000,000 units):** `K' = sqrt(5e6·2.5e5) ≈ 1,118,034`, `m = 118`. Price reverts; vault book k = 1.25e12 → ≈1,118,034/side; attacker's 10.55% claim ≈ 235,946 value vs 1,000,000 paid plus pool roundtrip cost — **heavy loss**. The internal CP price is unfavorable to the joiner by construction (he buys the other entitlement at average, not marginal).
- **The residual window is the sleeve:** because F doesn't track the pool, B's ratio after a pool move sits between old and new price. An attacker depositing the token that B *undervalues relative to market* extracts ≈ `(price divergence) × (deposit) − (join impact)`, where the divergence is damped by the sleeve fraction (≈1/6 at p=0.2) instead of being zero. With F = 0 the vault's deployed book tracks the pool and the window is pool-arbitrage-bounded; with F large it widens. **No-swap single-sided issuance therefore inherits a manipulation channel sized by sleeve × price move × deposit, not eliminated by invariant-preserving math** (which protects GM-units, not market value). This is the concrete content of OD-2/OD-4 — and it needs an owner-chosen bound (divergence gate, deposit caps, or accepted risk), not a formula relabeling.

## 6. Rounding, fees, zero-sided, redemption consistency

- **Rounding favors incumbents:** K ceil, K' floor, mint floor (`:59-64`); exact-out input ceil, surplus retained (`:69-77`); exit inverse ceil shares (`:118-128`).
- **Dust domain:** `K' ≤ K ⇒ m = 0` — sub-threshold single-token deposits mint nothing (revert via min-shares), an *unnamed* economic rejection; depositing into an **empty same-side reserve** reverts arithmetically in the forward path (K=0 denominator at `:60-64`) while the inverse names it (`InsufficientBacking`, `:85`). PRD B4's "named domain rejection" requirement should cover both.
- **Full-drain guard:** `_singleExit` reverts when `shares == supply && reserveOther != 0` (`:102`) — 100% single-token exit of a two-token book is impossible.
- **Fees:** the conversion is **fee-free** (`:8` "Fee-free settlement"). A zap route would have paid trading fees; fee neutrality between zap and no-swap paths is an owner choice, not derivable from the code.
- **Roundtrip consistency (numbers):** r0=r1=1e6, S=1000, deposit 10,000 token0 → m = 4 shares (K' floor 1,004,987). Immediate single-token exit of those 4: entitlementOut 4,023 + conversion 4,007 = **8,030 < 10,000**. Join+exit impacts both accrue to incumbents; no profitable passive cycle. Remaining holders' per-share total rises (redeemer paid impact).
- **E in pricing:** mint/exit over B includes accrued uncollected fees — joiners can't skim E; but E is excluded from the *sleeve target* base until collected (S1), so heavy accrual leaves F structurally under target until a collection event.

## 7. Answers to the user's question (condensed)

Yes — invariant-per-share value can be preserved without any balancing swap, and production code already embodies the rule (`_sharesForDeposit` single-token branch). The honest limits: (1) preservation is in GM/invariant units, with market-value fairness holding only when the book ratio ≈ market price; (2) the sleeve decouples the book ratio from the pool, opening a bounded but real manipulation window (§5); (3) quantities per share intentionally change composition; (4) payout capacity is a separate constraint that no issuance rule can relax.

## 8. Actionable owner questions (settled definitions not reopened)

1. **Conversion base.** Should the no-swap join/exit conversion price over the whole book B (current `_singleExit`/`_sharesForDeposit` behavior, sleeve included — wider window) or over deployed D only with F admitted/paid separately (tighter tracking, more accounting)? This single choice sizes the §5 window; please pick.
2. **Divergence bound.** Is a spot-vs-reference (TWAP) divergence gate on single-sided mints/exits wanted, and if so which units/window/band — or is the sleeve-damped window accepted as-is? (PRD OD-4; council's 25 bp / 100 bp / 30 min figures remain uncalibrated — a decision is needed, not a default.)
3. **Fee neutrality.** Fee-free internal conversion (status quo, `:8`) or charge the trading fee a zap would have paid, to keep zap and no-swap routes economically aligned?
4. **Dust/empty-side domains.** Confirm named rejections (not arithmetic accidents) for: single-token deposit minting 0, deposit into an empty same-side reserve, and define a product minimum single-token deposit if any.

## 9. Missing evidence / honest scope

No execution, no fork measurement, no peer review yet; `_linearExitPlan` (hookless blocked-entry sizing) not read this pass; the §5 extraction bound is analytical, not simulated; existing formulas are treated as mechanism evidence only — no claim that any of them is safe, and no historical code or council agreement is cited as proof.

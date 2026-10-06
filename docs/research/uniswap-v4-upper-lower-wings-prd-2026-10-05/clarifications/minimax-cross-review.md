# MiniMax M3 — clarifications cross-review

- **Inputs read in full:** `clarifications/astra-original.md`, `clarifications/grok-original.md`, `clarifications/kimi-original.md` (untrusted attributed proposals). **No** peer cross-reviews read. Original preserved at `clarifications/minimax-original.md`. **No** PRD edits; **no** shell/tests/code/config.
- **Method:** peer proposals verified against primary code and PRD text. Four counterexamples cross-checked arithmetically. The user's specific concerns (virtual vs AMM, sleeve-only manipulation bound, concentrated `D` not tracking market, fixed-mark vs token quantity) addressed.

## 1. Verifications and corrections

### 1.1 Counterexample arithmetic — all four peers consistent

- My path-B example (B0=B1=100, S=100, C0=100, C1=0, 1:1 price): m = 41 ✓.
- Grok's "token0-only ratio" example (B0=B1=100, S=100, C0=20): m = floor(100·20/100) = 20 ✓. Geometric m = floor(100·(sqrt(12000)-100)/100) = 9 ✓. Min-ratio m = 0 ✓.
- Kimi's r0=r1=1e6, S=1000, C0=10000: K = ceil(sqrt(1e12)) = 1e6, K' = floor(sqrt(1.01e12)) = 1,004,987, m = floor(1000·4987/1e6) = 4 ✓. (Kimi's 4,023+4,007=8,030 roundtrip is approximate; I did not read `_singleExit` internals this pass to verify the conversion leg.)
- Astra's P0=2/P1=1, deposit 125 token1: sqrt(100·225) = 150, m = 100·(150-100)/100 = 50 ✓. Incumbent value 300 → 100/150·(200+225) = 283.33 (loss 16.67 in market) ✓. Entrant claim 141.67 vs deposit 125 = gain 16.67 ✓.

### 1.2 Correction to my own original (arithmetic)

My `minimax-original.md` said the path-B depositor takes a "**net loss of 41.84**" at 1:1 prices. That number is the **B0-only delta** (100·20/141 transferred from depositor's B0 claim to incumbents' B0 share), not the depositor's total-value loss. At 1:1 prices, the depositor's claim is 41·(200+100)/141 ≈ 87.24; loss = 100-87.24 = **12.76**, not 41.84. The 41.84 = 12.76 × (P0/(P0-P1)) at P0=P1=1 only holds in B0 isolation. The transfer magnitude is **price-metric-dependent** and equals the slippage of the implicit virtual swap the invariant-mint performs against the vault's own CP book. I should have written "12.76 at 1:1 prices; 54.6 at P0=2/P1=1" and framed it as virtual-swap slippage. **Corrected framing:** the invariant-mint is a virtual swap from B1 to B0 at the internal CP rate; the depositor is implicitly selling the other entitlement; the transfer to incumbents is the slippage.

### 1.3 Concentrated D vs full-range D (user-flagged)

The user is right that my counterexample assumed a **full-range center** whose D re-ratios smoothly with pool price. The historical 10/90 wings split (`UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:74`) puts 90% of each token in a **one-sided wing**. A one-sided wing's D is fixed when out of range (binary: full single token, or zero when in range). It does not track the pool smoothly. So:

- For a wings vault, **B's price movement is not a clean CP curve** even ignoring F. Wings introduce step changes in D when price crosses a wing boundary.
- My counterexample's "value transfer = virtual-swap slippage" framing is only strictly correct for a full-range center. With wings, the transfer is the slippage **plus** a discrete inventory-shift component at every wing boundary.
- Kimi's §5 ("sleeve-decoupling window") generalizes: F's static nature creates a bounded manipulation channel; **wings add a second bounded channel** at every boundary. PRD §7.3 must address both.

### 1.4 Sleeve-only manipulation bound

Per Kimi §5 (verified arithmetically): when F doesn't re-ratio and the pool moves, B's internal price sits between old and new market. A depositor who buys the under-valued token (by B's lagging internal price) extracts `≈ (price divergence) × (deposit) − (join impact)`. The window is sized by `(sleeve fraction) × (price move) × (deposit)`, not eliminated by invariant-preserving math (which protects GM units, not market value). **Grok's claim that this is a real bound, not a relabeled formula, is supported.** The PRD needs an owner-chosen guard (divergence gate / deposit cap / accepted risk), not a different mint rule.

### 1.5 Virtual pricing vs actual AMM execution

All four peers agree the invariant-mint is a **virtual composition** against the vault's own CP book, not against the AMM. It is therefore **not a "typical zap-in/balancing swap"** under the owner's clarification, because no AMM or external liquidity is touched. Astra's "PRD §7.3 should no longer present composition as an equally pending entry choice" is **too strong**: the owner said "no typical zap-in/balancing swap," not "no virtual/internal pricing." The invariant mint is a different category and remains a candidate. **I will not declare it owner-prohibited.**

### 1.6 Custody R vs ownership B

All four agree: `R` (custody snapshot) is `IERC20(token).balanceOf(address(this))`; `F` is spendable part of R; `B = F + D + E` is backing; `D` is finite-range math per position at current state; `E` is uncollected fees, count-once on collection. **Fixed-mark value neutrality is a property of `B/S` only when B's ratio equals external price; it is not a property of `R`, `F`, or token quantities.** Sufficient local cover (`F_i ≥ required_payout`) is a separate gate from ownership valuation (`B_i/S × shares_burned`).

### 1.7 PRD §8.1 vs §8.1 parameters

The owner confirmed the **`F = pD` and `targetFree = T·p/(1+p)` formula** in their clarification. The **parameters** (`p = 0.20e18` default, `RELATIVE_TOL_WAD = 0.05e18`, `ABSOLUTE_FLOOR_i = 10^max(0,decimals-6)`) remain separate decisions. Astra's "§8.1 convention now confirmed in principle" is right on the formula, **too strong on the constants**.

## 2. Few clear human questions

1. **"No typical zap" scope.** Does it forbid (a) only AMM/external-pool swaps, or (b) any pricing operation that re-flavors the new depositor's claim to include the other entitlement, including virtual composition against B? The invariant-mint is a virtual composition; the TWAP-valued mint is a virtual pricing; a fee-charging internal AMM stub is a hybrid. Q1 picks the entry family.
2. **Sleeve-decoupling + wings-boundary manipulation window.** With F static and wing boundaries discrete, an attacker can exploit price divergence at the window's open end. Is a **divergence gate** (TWAP vs spot) required for single-sided mints and exits, and what window/units/band? PRD OD-4 still open.
3. **Sleeve base / default / deadband parameters.** Formula confirmed; `p = 0.20e18` default, 5% relative tolerance, `ABSOLUTE_FLOOR_i = 10^max(0,decimals-6)` are not yet owner-ratified. Please name values, or default to local buffer D7/D22.
4. **Value-transfer acknowledgment.** Path-B (and any non-zero-mint path under Q1) **always** transfers value from new depositor to incumbents — magnitude equals the implicit virtual-swap slippage, price-metric-dependent. Is this an accepted product feature (Balancer-style), or do we need revert+refund for one-sided deposits (Grok's policy) or a TWAP-anchored mint (Astra's V-based option)?
5. **Sleeve replenishment under wings geometry.** With 90% of capital in one-sided wings and D28 (no rebalance swap) preserved, the per-token sleeve target may be unreachable for long periods. Is a **rebalance swap exception** for this product needed, or is "best-effort per token with possibly thin sleeve" accepted as policy?

## 3. Honest scope

- No claim that any economic formula is safe. Four counterexamples exhibit the math; none are executed security tests.
- No restoration of `35f47b51`; historical 10/90 split cited from primary PRD text only.
- No claim that 1.28M gas figure is wings evidence.
- No consumer impact analysis (Weighted, Orbital, Pons, FullSpread, Aperture) in this pass.
- No PRD edit, no shell, no tests, no code, no config, no instruction edit.

Original preserved. PRD unchanged. Saved to `clarifications/minimax-cross-review.md`.
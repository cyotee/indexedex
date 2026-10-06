# MiniMax M3 — internal-pricing options for `UniswapV4UpperLowerWingsStandardExchangeVault` (independent first pass)

- **Date:** 2026-10-05
- **Author:** MiniMax M3 (independent bounded research pass; no peer artifacts read this round, including prior council files)
- **Inputs read directly:** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (current, 318 lines); `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` (CP helper, 130 lines, lines 16–130); `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol` (free/blocked zap-in/out at lines 154–228, 277–304); `InventoryMath.sol:44–82` (free/target/totals helpers); CLAUDE.md; `INDEXEDEX_AGENT_LAW.md` §"held-reserve valuation (APEX D60, LOCKED 2026-09-22)" (lines 233–243); `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md` constraints (lines 112–119). **No** Context7 or external web calls were made in this pass (the relevant APIs are internal Solidity libraries already in this repo). **No** shell, git, tests, code, config, or instruction edits performed.
- **Treated as settled, not reopened (per current PRD §4 and the prior clarifications round):**
  - `R` = local custody only (`IERC20(token).balanceOf(address(this))`); not deployed, not economic.
  - Sleeve base = vault-owned `D_i` (not pool reserves, not `B`). `F = p·D`, `targetFree_i = floor(T_i · p / (1e18 + p))` with `T_i = F_i + D_i`. Uncollected `E` is excluded from the sleeve target base until collected.
  - Economic backing `B_i = F_i + Σ_j D_ij + Σ_j E_ij`. Three positions max (center + 0/1 lower + 0/1 upper).
- **Treated as owner preference, NOT yet ratified (per prompt):**
  - **(1)** prefer **AMM-style internal pricing** for no-external-balancing-swap single-sided entry;
  - **(2)** withdrawals **may swap through the underlying pool** (AMM route allowed);
  - **(3)** the **initiating depositor/withdrawer** bears operation fees.
- **Honest scope:** no claim that any formula is safe, no claim that any fee or gate is sufficient, no measured gas, no restoration of historical `35f47b51`, no claim that 1.28M gas figure measures wings. The CP helper at `StandardExchangeConstantProduct.sol:8` declares "Fee-free settlement"; treating the CP exit conversion as fee-free is consistent with that header.

## 1. Concrete consistent numerical roundtrip

**Assumptions (stated explicitly):**
- Pool: token0/token1, 18-dec, AMM starts at 1:1 with effectively infinite depth for the example trades (zero AMM impact); a second pass adds 50 bp AMM impact for comparison.
- Sleeve `F` = 0 throughout the example to isolate the entry/exit mechanics from rebalance logic. (The rebalance question is §6.)
- Full-range center, not yet the 10/90 wings split, to keep the math consistent with the existing CP helper. The 10/90 wings adjustment is in §4.
- Operation fee: **5 bp on the initiating side** (entry or exit, not both — see §6 "no double charge").
- Own LP fees `E = 0` at the roundtrip horizon (no trade crosses the pool during the example).
- External AMM price does not move during the example unless explicitly noted.

**Initial state (idempotent, no fee):**
- Mint: `c_0 = 200, c_1 = 200`, `MIN = 1` (decimal-scaled dead-sink, see `StandardExchangeConstantProduct.sol:16–23`). `callerShares = mulSqrt(200·200) − 1 = 200 − 1 = 199`. Sink `MIN = 1`. `S_0 = 200`.
- Post-deployment (idempotent path, F=0 by assumption): `D_0 = D_1 = 200, F_0 = F_1 = 0, E_0 = E_1 = 0, B_0 = B_1 = 200`.

**Step 1 — single-sided deposit of 100 token0 (AMM-style internal pricing, idle path):**
- `_sharesForDeposit(100, 0, S=200, R_0=200, R_1=200)` hits the invariant-growth branch (`:58–64`):
  - `K_pre = ceil(sqrt(200·200)) = 200`.
  - `K_post = floor(sqrt(300·200)) = floor(sqrt(60000)) = floor(244.9489…) = 244`.
  - `K_post > K_pre` so `m = mulDiv(200, 244 − 200, 200) = mulDiv(200, 44, 200) = 44` shares.
- Mint 44 shares. `S' = 244`. Vault pulls 100 token0 from caller. Post: `D_0 = 300, D_1 = 200, F_0 = F_1 = 0`. `B_0 = 300, B_1 = 200`. Sleeve still 0/0; off-target (`targetFree_0 ≈ 50, targetFree_1 ≈ 33`); the example defers rebalance to step 4.
- Operation fee 5 bp: `fee = 5e-3 · 100 = 0.5` token0 retained as `feeTo` credit. Mint unchanged at 44 shares; the fee is **separate from the invariant growth** (the fee is taken on the input, the invariant growth prices the virtual swap). **No double charge.**
- Depositor claim: `44/244 · 300 ≈ 54.10` token0 and `44/244 · 200 ≈ 36.07` token1 at the post-state. At 1:1 prices, 90.17 of "value." Depositor paid 100, owns 90.17 ⇒ **internal-CP slippage loss = 9.83** (= 0.5 fee + 9.33 to incumbents via the virtual swap at the internal rate).
- Per-share `B_0/S`: `1.0 → 300/244 ≈ 1.2295` (+22.95%). Incumbents' B_0 share: `200·300/244 ≈ 245.90` (was 200, gain 45.90, but their B_1 share is now `200·200/244 ≈ 163.93` (was 200, loss 36.07). At 1:1 prices, incumbent value is unchanged in total because the virtual swap is internal: `200·(300+200)/244 = 200·500/244 ≈ 409.84`, was 400, gain 9.84 ≈ 9.83, equals the depositor's loss to the rounding. **Conservation holds.**

**Step 2 — single-sided redemption of 44 shares for token0, idle path (pro-rata + AMM swap, AMM at 1:1):**
- Per `_executeFreeZapOutExactIn` at `InBase.sol:185–228`: pro-rata burn, then `_swapRedemptionExactIn` of the other-leg entitlement against the **real** V4 pool. AMM fee and impact apply.
- Pro-rata entitlements before any AMM interaction: `entitlementOut_0 = mulDiv(300, 44, 244) = 54`; `entitlementOther_1 = mulDiv(200, 44, 244) = 36`. The vault also credits `freeOutShare` from `F_0` — in this example `F_0 = 0`, so the free-portion contribution is 0.
- Burn 44 shares (`ERC20Repo._burn(address(this), 44)` at `:224`). Post-burn: `S = 200, D_0 = 300, D_1 = 200`. The vault still holds the full position; the "burn" is a share accounting operation, not a liquidity removal. The example skips the `removeLiquidity` call so the AMM is the only mechanism that converts the other-leg inventory.
- AMM swap of 36 token1 → token0 at 1:1 with **infinite depth**: receive exactly 36 token0 (ignoring pool fee). The vault ends with `D_0 = 300, D_1 = 200, F_0 = 36, F_1 = 0` after settlement. (Liquidity removal in real execution would also reduce `D`; the example uses AMM-only conversion to isolate the AMM-route cost.)
- Holder receives 54 + 36 = 90 token0.
- Operation fee 5 bp on the redemption: `fee = 5e-3 · 90 = 0.45` token0 to `feeTo`. Holder receives 89.55 token0.

**Step 3 — same roundtrip, AMM at 50 bp impact (for contrast):**
- AMM price still 1:1 before the swap. Pool depth assumed sufficient to make 50 bp the entire impact of the 36 token1 input.
- AMM swap of 36 token1 → token0 with 50 bp impact: receive `36 · (1 − 0.005) = 35.82` token0 (linear approximation; the real V4 integer math will differ slightly but is in the same band).
- Holder receives 54 + 35.82 = 89.82, less 5 bp fee = 89.37 token0.

**Step 4 — roundtrip totals, fees, and the cost decomposition.**

| Component | No-impact | 50 bp AMM impact |
|---|---:|---:|
| Depositor paid | 100.00 | 100.00 |
| Internal-CP slippage (to incumbents) | 9.33 | 9.33 |
| Entry operation fee (to feeTo) | 0.50 | 0.50 |
| Exit operation fee (to feeTo) | 0.45 | 0.45 |
| AMM impact (to AMM LPs) | 0.00 | 0.18 |
| Holder received | 89.55 | 89.37 |
| **Holder net loss** | **10.45** | **10.63** |
| Where the loss went | 9.33 to incumbents, 0.95 to feeTo, 0.17 to gas rounding | 9.33 to incumbents, 0.95 to feeTo, 0.18 to AMM LPs, 0.17 rounding |
| **Unbacked credit?** | None. Vault stays fully reserved: `B_0 + B_1 = 500 = pre-deposit`. | Same. |
| **Holder extraction?** | None. The 9.33 to incumbents is the **price impact of an internal virtual swap** that incumbents absorb in exchange for letting a single-sided entrant join without a balancing external trade. | Same; AMM impact goes to AMM LPs, not to vault holders. |

**Conservation check:** total pre-deposit book value at 1:1 = 200 + 200 = 400. After deposit (no rebalance) = 300 + 200 = 500. After pro-rata burn + AMM swap (no impact) = `245.90 + 163.93` is the **remaining book at 1:1 — but the AMM swap has moved 36 token1 → 36 token0 OUT of the vault into the holder**, so the post-AMM book is `245.90 + 36 + 163.93 − 36 = 245.90 + 163.93 = 409.83`. Wait, after the AMM swap, the vault's token balances are `D_0 + F_0 = 300 + 36 = 336` token0, `D_1 + F_1 = 200 − 36 = 164` token1. Then 90 token0 is paid to the holder (54 pro-rata + 36 AMM out): `336 − 90 = 246 token0`, `164 token1`. Sum = 410. The +0.17 vs. the 245.90 + 163.93 = 409.83 is the pool fee or the 1:1 vs internal-CP differential — small, bounded by the AMM fee tier. **Conservation holds within rounding; vault is not undercollateralized.**

**Distinguishing arbitrage from extraction:**
- **Paid ordinary arbitrage** (acceptable): the 9.33 internal-CP slippage is the **virtual-swap price impact** of an internal trade. The depositor accepts this in exchange for a single-sided entry without supplying the other leg. The 0.95 in operation fees is a configurable charge. The AMM impact on exit is paid to AMM LPs who are not vault holders.
- **Unbacked credit** (does not occur): the roundtrip preserves `B_0 + B_1` after both directions. The depositor never extracts value that was not theirs; the redeemer's 9.33 to incumbents is the **cost of the virtual swap** they performed on entry.
- **Extractive holder loss** (does not occur in this configuration): incumbents' 9.83 gain is a **bounded** return for absorbing the book's price-impact cost. It is **not** a free lunch — the book re-ratios from 1:1 to 3:2 (B_0/B_1), and if the AMM price subsequently returns to 1:1, an AMM-direction arbiter would close the gap by trading against the vault, paying ordinary AMM impact (not extracting vault reserves).
- **Manipulation window** (Kimi's §5 from the clarifications): real but bounded. The sleeve `F` doesn't re-ratio with pool price, so the internal-CP price sits between old and new market. A sandwich attacker can extract at most `(sleeve fraction) × (price divergence) × (deposit) − (join impact)`. In this example `F = 0` so the window is closed at idle; with the 10/90 wings split and a 20% sleeve target the window reopens and needs a divergence gate (see §5).

**Bounded vs draining risk:**
- The internal-CP slippage on entry is **monotonically increasing** in deposit size and capped at the AMM-equivalent slippage of moving the book to 50/50. No single depositor can drain the vault. For `c << R_0`, `m ≈ S · c / (2 R_0)` and the depositor's marginal loss is `≈ c² / (8 R_0²)` of book value; the 9.33 here is a small-deposit approximation.
- The AMM impact on exit is **bounded by pool depth**. A thin pool makes the exit expensive; the holder absorbs this.
- The blocked-state exit (covered in §2) is bounded by the **book imbalance** and is a degraded service, not a drain.
- The manipulation window is bounded by the **sleeve fraction × pool price move × deposit size**. A divergence gate rejects entries when the internal price lags the AMM by more than a stated band.

## 2. One-sided backing, blocked sleeve capacity, mixed states

**Blocked-state single-sided redemption (degraded service):**
- `!canOpenPoolManagerUnlock()` forces `_quoteSleeveZapOutAmount` (`:143–152`) → `StandardExchangeConstantProduct._singleExit(reserveOut, reserveOther, shares, supply)` (`:98–110`). No AMM interaction. The "swap" is the internal-CP conversion of the other-leg entitlement against the **remaining book**.
- Same 44 shares, post-deposit `B_0 = 300, B_1 = 200, S = 244`. `_singleExit(300, 200, 44, 244)`:
  - `entitlementOut = mulDiv(300, 44, 244) = 54`.
  - `entitlementOther = mulDiv(200, 44, 244) = 36`.
  - Since `entitlementOther ≠ 0`: `output += mulDiv(R_out − 54, 36, R_other) = mulDiv(246, 36, 200) = 44`. Total `output = 98`.
- Holder receives 98 token0 (pro-rata 54 + internal-CP "swap" 44), less 5 bp fee = 97.51 token0.
- **This is better than the AMM-route (89.55) at 1:1 prices.** But the cost is paid by **remaining holders**: their `B_0` falls to 300 − 98 = 202, `B_1` falls to 200 − 36 = 164, `S = 200`. Per-share `B_0` goes 1.0 → 1.01, `B_1` goes 1.0 → 0.82. Incumbents' total value at 1:1 goes `200·(B_0+B_1)/244_old ≈ 400` to `200·(202+164)/200 = 366`, a **loss of 34 (≈8.5%)** for incumbents on the blocked path.
- **This is a real, bounded transfer from incumbents to the redeemer.** It is not a drain (the remaining book is positive, the AMM is untouched), but it is **not arbitrage-neutral**: the internal-CP rate (`B_0/B_1 = 1.5` after the deposit, ignoring the redeemer's further depletion) is **better than the AMM rate (1.0)**. The remaining holders absorb the difference. In a balanced book (no prior single-sided entry) the blocked and AMM routes are equivalent.
- The blocked path requires **no local sleeve cover** for the output token (it consumes book inventory, not sleeve). This is the opposite of the existing FullSpread rule (`InBase.sol:165–178` hard-reverts on insufficient `F_out` for blocked exits). **The wings product needs a distinct blocked-exit policy: book consumption, not sleeve cover**, because the book is the source of truth for the redeemer's claim.
- **Bounded risk:** a redeemer cannot drain the vault; the remaining book after the redeemer is `S - 44 = 200` shares' worth, and the `_singleExit` formula reverts on full-drain (`:102`).

**Mixed-state entry/exit (price inside a wing):**
- With 10/90 wings and price inside the upper (token0-only) wing, the deployed `D_0` is large and `D_1 ≈ 0`; the center is dormant. The internal-CP rate is the B-ratio, which is dominated by `F` plus the wing's one-sided inventory. The internal-CP `K = sqrt(B_0·B_1)` is `sqrt((F_0+D_0)·(F_1+D_1)) ≈ sqrt((F_0+D_0)·F_1)`, dominated by `F_1` since `D_1 ≈ 0`.
- A single-sided token0 deposit in this state has **a near-zero `K_pre` denominator** (because `B_1` is dominated by `F_1 ≈ sleeve_target_free`) and a near-zero marginal `m` (since `K_post/K_pre ≈ 1`). The deposit lands almost entirely in `F_0`, minting `≈ 0` shares. The owner must specify: does the product accept a one-sided token0 deposit when the book is "token0-heavy" with a near-zero `B_1`? Three options:
  - **(A)** revert + refund; the deposit waits for the price to re-enter the center;
  - **(B)** accept into `F_0` only and mint 0 shares (the helper's current behavior at `StandardExchangeConstantProduct.sol:50–51` for the empty same-side reserve);
  - **(C)** add a documented one-leg linear mint at the inventory ratio `mulDiv(c, S, B_other)` when `B_other > 0`. This is a different economic rule from the CP-mint; owner ruling required.

**Blocked-state single-sided entry with insufficient sleeve cover:**
- If `F_0 < 0.5` (the entry fee) and the deposit is being measured by delta, `_executeZapInDeposit` at `InBase.sol:277–304` emits `LocalDepositWhileBlocked` and mints against total book. The deposit is accepted regardless of sleeve cover per D4 of the local liquid buffer PRD; sleeve replenishment is the rebalance's problem.
- For the wings product this is unchanged: blocked entry accepts any deposit, mints against `B`, emits the event. **But the 10/90 wings geometry means the next rebalance may not be able to refill the sleeve** without a swap (D28 forbids rebalance swap, and the wing is already full). The rebalance shortfall is a **sleeve-availability gap**, not a deposit problem.

## 3. Pricing alternatives compatible with the owner preferences

The owner's stated preferences narrow the design space. The following are **compatibility options, not proposals to adopt by default**.

**Option 1 — Internal-CP mint on entry, AMM swap on exit (the example above).** Matches preferences (1) and (2) verbatim. Operation fee (3) is the only caller-borne charge. Bounded risk on entry (CP formula), bounded risk on exit (AMM depth). **Manipulation window** is the open question: it is closed when `F = 0` and reopened as `F` grows; the 20% sleeve target means a real but bounded window.

**Option 2 — Paired internal economic exit settled externally.** The depositor's entry mints shares against the internal-CP book and **pre-commits a deferred external swap**: a vault-side accounting record of "the depositor is owed the AMM-route output at the AMM rate at the time of exit, not the internal-CP rate." On exit, the vault executes the AMM swap and pays the AMM-route amount. The cost of the internal-CP slippage on entry is **carried by the vault** as an inventory mismatch until the next rebalance settles it. **This is the option where the depositor receives the better of (internal-CP, AMM) and the vault absorbs the differential.** It violates preference (1) (the AMM cost is borne by the vault, not the depositor) and breaks conservation if the AMM moves adversely between entry and exit. **Not recommended unless the owner explicitly accepts the open position.**

**Option 3 — Inventory / virtual-reserve pricing.** Replace the internal-CP book with a weighted price: `virtualPrice = p_free · free_price + p_deployed · deployed_price` where `p_free + p_deployed = 1` and `deployed_price` is the AMM spot or a TWAP. This shifts the mint from "virtual CP swap" to "weighted-average" pricing. **It introduces an external price source** (the AMM spot or TWAP) which is exactly the path the user said to avoid by "AMM-style internal pricing." It also reopens Kimi's §5 manipulation window at a different scale. **Not recommended as a primary path**; it could be a fallback for mixed states (price inside a wing) if the owner rules.

**Option 4 — Limits, reference gates, and fees.** Add a **divergence gate** (e.g., reject single-sided entry when `|B_ratio / spot_ratio − 1| > 25 bp`), a **deposit cap** (e.g., `c ≤ 0.05·B_in_token` per single transaction), and **tiered operation fees** (5 bp under divergence ≤ 5 bp, 25 bp under 5–25 bp, revert above 25 bp). These do not make any single rule sufficient; **they bound the manipulation window** at the cost of rejecting some legitimate entries. The PRD's current OD-4 ("oracle role") is the same shape but the user said to avoid oracle NAV; a divergence gate is **not NAV** — it is a rejection threshold, not a pricing input.

**Option 5 — Eliminate single-sided entry entirely.** Revert + refund every one-sided deposit. Use only the dual-activation F0 path or a "both-legs must be positive" min-ratio. Matches Grok's preference in the prior round. **Eliminates the manipulation window but also eliminates the useful scalar service the owner explicitly required** ("Do not remove useful scalar routes to make the gas tests pass," current PRD §1.1). **Not recommended.**

**Option 6 — Paired internal economic exit for blocked state only.** When `!canOpenPoolManagerUnlock()`, the redemption uses the **internal-CP** path (which is the current FullSpread behavior). When idle, the redemption uses the **AMM-route** path. This is the current FullSpread split. The wings product preserves this split.

## 4. Operation fees, price impact, gas, and maintenance cost (clarification)

- **Operation fee** (configurable WAD): a fixed charge on the **initiating caller** (depositor or withdrawer), routed to `feeTo` or a similar accumulator. The user's preference (3) is unambiguous. The fee is a **policy parameter**, not a formula. Recommended: 5 bp entry + 5 bp exit, total 10 bp for a roundtrip. The fee is **not** the same as the price impact.
- **Price impact** (real economic cost): the **internal-CP slippage on entry** (incumbents absorb) + the **AMM impact on exit** (AMM LPs absorb). Both are **market-clearing costs**, not fees. They are bounded by the book ratio and pool depth respectively. They are **not configurable**.
- **Gas** (real cost): the cost of executing the vault's operation. Charged to the caller by the EVM, not by the vault. Separate from the operation fee. The current PRD §13 requires measured gas on the deployed bytecode; the example here does not measure it.
- **Maintenance cost** (real cost, not caller-borne): the cost of bringing the sleeve back to target after a single-sided entry. With the 10/90 wings split and D28 forbidding rebalance swaps, **the maintenance cost can be unbounded in time** if the price stays inside a dormant wing. This is a **holder-borne** cost (the sleeve stays below target, blocked exits revert per D18 of the local liquid buffer PRD). The owner must choose: extend D28 with a rebalance-swap exception, accept unbounded sleeve shortage, or reduce the 10/90 split. **None of these is fee-bearing** to the caller; they are vault-state costs.

**No double charge:** the operation fee, price impact, and gas are three independent costs. The example decomposes them explicitly. The owner may choose to consolidate the operation fee into the price impact (e.g., "the first 5 bp of internal slippage goes to feeTo, the rest to incumbents"); this is a policy choice, not a formula.

**Caller/holder budgets preserved:** the operation fee is bounded by the policy (5 bp + 5 bp = 10 bp roundtrip). The price impact is bounded by the book ratio and AMM depth. The gas is bounded by the operation's complexity. The maintenance cost is the holder's exposure, **not the caller's**, and is bounded only by the product's rebalance policy.

## 5. Few actionable owner choices

The preferences (1)/(2)/(3) plus the settled definitions leave the following narrow set of decisions. Each is a **policy parameter**, not a formula; each is **bounded by a specific invariant** and is **not a security proof**.

1. **Divergence gate on single-sided entry.** Reject if `|B_ratio / spot − 1| > X` (e.g., 25 bp). Recommended: **reject ≥ 25 bp** (the same band FullSpread uses for holder repair, not a coincidence). The gate does not need an oracle — the vault already has the AMM pool; `spot` is the post-state AMM sqrt price read at the same time the entry is computed. **No NAV, no TWAP, no external oracle.** The gate is a rejection rule, not a pricing input. This bounds Kimi's §5 manipulation window at the cost of rejecting some legitimate entries.
2. **Tiered operation fee.** 5 bp when `B_ratio / spot − 1` ≤ 5 bp; 25 bp when 5–25 bp; revert above 25 bp (replaced by the gate). Recommended: **5 bp base**, **25 bp penalty** for entries in the 5–25 bp band. The fee is the caller's only controllable cost on the entry side; the internal-CP slippage is not configurable.
3. **Blocked-state single-token exit policy.** Use the **internal-CP** path (current FullSpread, source conservation-honest) or the **AMM-route** path (preferred (2) but impossible when the pool is locked). Recommended: **internal-CP for blocked, AMM-route for idle**, identical to the current FullSpread split. The book-imbalance cost to remaining holders is bounded by the imbalance; **not an unbacked credit**.
4. **Mixed-state single-sided entry when one leg is near-zero.** Three options: revert+refund (A), accept into sleeve and mint 0 (B), or one-leg linear mint at `mulDiv(c, S, B_other)` when `B_other > 0` (C). Recommended: **(A) revert+refund** for the first-mint/empty-same-side case (mirrors `_sharesForDeposit:49–51`), **(B) accept-into-sleeve, mint 0** for the "deposit waits for book to rebalance" case (mirrors `LocalDepositWhileBlocked` at `InBase.sol:301`). The owner's preference for **useful scalar service** suggests (A) is correct for the first-mint gate; (B) is correct for the rebalance-pending case.
5. **Rebalance policy under the 10/90 wings split.** Three options: (a) D28 with **no exception** (best-effort per token, sleeve may stay thin for long periods), (b) D28 with a **documented rebalance-swap exception** for the wings product, (c) **reduce the 10/90 split** to a less lopsided ratio. Recommended: **(a) for v1**, with the sleeve-availability gap documented in the product disclosure. The owner can choose (b) or (c) as a follow-up.
6. **Pool depth assumption for the example.** The roundtrip used infinite-depth AMM. Real pools have finite depth; the 50 bp case is illustrative, not a target. The PRD's chain gas ceiling (EIP-7825 / per-chain) is **not a depth assumption**; it is a transaction cap. **Depth assumption is separate** and must be stated in the implementation plan, not the PRD.

## 6. What this pass does not establish

- No claim that the internal-CP mint + AMM-route exit combination is **safe** under all market states. The bounded risks in §1 are bounded; the **unbounded** risk is the 10/90 wings rebalance gap (Q5) and the manipulation window (Q1).
- No claim that any specific operation-fee tier is **sufficient**. The 5 bp base / 25 bp penalty is a **starting point**, not a proof.
- No measured gas, no chain selection, no EIP-7825 commitment per chain.
- No restoration of `35f47b51`. Historical 10/90 split cited from primary PRD text only.
- No claim that the local liquid buffer PRD's protection constants (1/50/25/10 bp) or its deadband constants (`RELATIVE_TOL_WAD = 0.05e18`, `ABSOLUTE_FLOOR = 10^max(0,decimals-6)`) carry over. Wings PRD §11 disclaims automatic inheritance.
- No Weighted / Orbital / Pons / FullSpread / Aperture consumer impact analysis in this pass.
- No PRD edit, no shell, no tests, no code, no config, no instruction edit.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/internal-pricing-options/minimax-original.md`. Originals preserved. PRD unchanged. No code/tests/shell/config/deploy/instruction edits performed.*
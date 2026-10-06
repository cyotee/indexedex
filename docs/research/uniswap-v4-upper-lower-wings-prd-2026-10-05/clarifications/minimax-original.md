# MiniMax M3 — clarifications on the wings PRD (independent first pass)

- **Date:** 2026-10-05
- **Inputs read directly:** `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (current, 318 lines); `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` (the local liquid buffer, sleeve/`F=pD`/targetFree convention); `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` §5–6 (sleeve policy, proportional issuance). Skill files: `CLAUDE.md`, `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`, `.claude/skills/indexedex-testing/SKILL.md`, `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md` (catalogs). No peer originals or cross-reviews read this round.
- **Treated as clarified, not open votes:** (1) local reserve tracking = **only** tokens locally held by the vault (`R = F = IERC20(token).balanceOf(address(this))` for each pool currency), **not** deployed reserves; (2) sleeve percentage is of **vault-owned deployed reserves**, not underlying pool reserves, so the base is `D_i` and the formula is `F_i = p * D_i` with `targetFree_i = floor(T_i * p / (1e18 + p))`, `T_i = F_i + D_i`; (3) no-typical-zap intent: a single-token entry/exit must not require a balancing swap on the AMM.
- **No** shell, git, tests, config, contract edits, or other writes performed.
- **Honest scope:** no claim that any economic formula is consensus-safe; no measurement of historical code; no claim that this analysis constitutes a security proof.

## 1. Council questions on the current PRD (specific, actionable)

The current PRD at `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` already locks most surface decisions. The remaining questions are **only** the economic ones the owner explicitly flagged.

| # | Question | Why it matters |
|---|---|---|
| Q1 | Under the **no-typical-zap** intent, does the owner accept a **one-sided subsidy from the new depositor to incumbents** on every single-sided deposit and withdrawal? (See counterexample §2.) Without a swap there is no economically fair way to credit a one-sided contribution; the PRD's "Direct local inventory pricing" path B in §7.B3 implies this subsidy. | The PRD §7.B3 names path B as a candidate but does not say the new depositor pays the imbalance. Q1 forces an explicit acknowledgment. |
| Q2 | Is the **payout-capacity floor** (local sleeve `F_0 + F_1`) the **only** redemption guarantee the owner will accept while interaction is blocked, or does the owner also accept a **delayed withdrawal queue** that pays when the position is in range? | A queue changes the security model and the gas profile of `exitSingleAssetExactOut`. Local buffer PRD §1.3, D18 currently hard-reverts on insufficient local cover. |
| Q3 | For the **sleeve replenishment** during rebalance, does the owner accept **best-effort per-token** under the existing D28 "no swap as rebalance tool" rule, or does the owner want a **rebalance swap** route on this new product? The 10/90 wings split can leave one side structurally under-supplied at certain ticks. | D28 of the local buffer PRD forbids rebalance swaps; with a 10/90 split the "best-effort" can stall for long periods. |
| Q4 | Are the **protection constants 1/50/25/10 bp** of FullSpread inherited verbatim, or are they **recalibrated** for the three-wing product where spot moves sharply with concentrated capital? | The wings PRD §11 last paragraph already says no FullSpread constant is automatically wings law. Q4 makes the call. |
| Q5 | Is the **chain gas ceiling** for acceptance **EIP-7825 (16,777,216 per tx)** on every target chain, or per-chain (Ethereum 30M block, Base 60M, RH 4663 per chain)? | The PRD §13 already names EIP-7825 as the spec but does not select a binding number. |
| Q6 | Does the owner want a **payout-capacity floor** (minimum `F_i` that an idle single-token exit must always be able to satisfy regardless of sleeve target) as a separate invariant from `F = p * D`? | A floor is a different economic commitment than a target. |
| Q7 | Are the historical **10% center / 90% per wing** numbers (`activeLiquidityBps = 1000`, per `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:74`) a **restoration** commitment, or a **starting point** the owner can change in v1? | Restoration is a stronger claim than starting point. |

Questions to **avoid re-opening** (settled in the current PRD): identity, path, kind, deploy, immutability, no `new` SUT, no `MockStandardExchange`, no `via_ir`, no scaled stale reserve, no fee waiver, no NAV, no in-kind recovery, no public `diamondCut`, blocked state sleeve-only, full-range center, three-position cap, decimal-scaled dead-sink minimum, no `widthMultiplier` arithmetic unless explicit `h` approved.

## 2. Concrete counterexample: single-sided deposit under three rules

Definitions (per the current wings PRD §4 and local buffer PRD §0): `F_i` = spendable local ERC-20 of token `i`; `D_i` = owned position principal at current state; `E_i` = uncollected own LP fees; `B_i = F_i + D_i + E_i` = economic backing; `S` = share supply.

**Setup (numerical, 18-dec, no fees, no donation, sleeve target irrelevant for the issuance math):**

- Initial dual mint: `c_0 = 100, c_1 = 100`. `MIN = 1` (decimal-scaled default, `d = 18 → MIN = 10^(18-3) = 1e15` here simplified to 1 for the example). Caller shares = `floor(sqrt(100 × 100)) - 1 = 100 - 1 = 99`; dead-sink MIN = 1; `S_0 = 100`.
- Post-mint: `F_0 = F_1 = 0` (sleeve empty for clarity; the math is the same with any non-zero sleeve, see §3); `D_0 = D_1 = 100` (one full-range center, all 100 of each side at the mint price for simplicity). `E_0 = E_1 = 0`. `B_0 = B_1 = 100`. `S = 100`.
- **One-sided deposit:** `C_0 = 100, C_1 = 0`. The caller does not provide any token1.

### 2.1 Path A — Proportional composition (zap-in with a swap)

The current FullSpread path. The caller swaps some of their token0 into token1 against the AMM to make their contribution proportional to the post-swap book; then mints under `m = min_i floor(S × C_i / B_i)` on the post-swap whole book.

- Suppose the AMM price is 1:1 with negligible impact. Caller swaps 50 token0 for 50 token1; their net contribution is `C_0' = 50 + 50 = 100, C_1' = 0 + 50 = 50` is wrong; actually `C_0' = 100 - 50 = 50` and `C_1' = 50`. (The math: caller puts 100 token0; swaps 50 → 50; ends with 50 token0 + 50 token1.)
- Post-swap: `B_0 = 100 + 50 = 150, B_1 = 100 + 50 = 150`. `S = 100`.
- `m = min(floor(100 × 50 / 150), floor(100 × 50 / 150)) = min(33, 33) = 33`.
- Existing holders own `100/133 ≈ 75.2%` of the book; new owns `33/133 ≈ 24.8%`. Each share is worth `B_0/S = 150/133 ≈ 1.128`.
- Existing holders per-share value went `1.0 → 1.128` (+12.8%); new depositor per-share value at deposit time = 1.128. Their input was 100 (token0-side equivalent at the 1:1 swap); pro-rata they own 24.8% of 300 = 74.4 of post-state. They paid 100 (50 token0 + 50 token1); they own 74.4 → **net loss of 25.6** (paid in swap slippage + roundtrip spread, which is **not a subsidy** — it is paid to the AMM LP, not to vault holders).

### 2.2 Path B — Direct local-inventory pricing (no swap, CP-mint on partial B)

This is the PRD §7.B3 "Direct local inventory pricing" path. Standard constant-product one-sided mint formula on the **whole post-deposit book**:

`m = floor( ( sqrt((B_0 + C_0) × (B_1 + C_1)) - sqrt(B_0 × B_1)) × S / sqrt(B_0 × B_1) )`.

- `B_0 + C_0 = 200, B_1 + C_1 = 100`. `sqrt(200 × 100) = sqrt(20000) ≈ 141.421`. `sqrt(100 × 100) = 100`. `S = 100, sqrt(K_pre) = 100`.
- `m = floor( (141.421 - 100) × 100 / 100 ) = floor(41.421) = 41` shares.
- Total shares `S' = 141`. New owns `41/141 ≈ 29.1%`. Existing owns `100/141 ≈ 70.9%`.
- Per-share value: `B_0'/S' = 200/141 ≈ 1.418`. `B_1'/S' = 100/141 ≈ 0.709`.
- **Existing holders per-share value went `1.0 → 1.418` (+41.8%)** with **zero contribution**.
- **New depositor paid 100 token0 and now owns 41 shares × 1.418 ≈ 58.16 of post-state B_0**. **Net loss of 41.84** in post-state B_0 equivalent.

**The 41.84 is transferred from the new depositor to the existing holders** as a one-sided subsidy. This is the standard Balancer / CP one-sided-mint property. It is **not** a hidden fee; it is the entire point of path B.

### 2.3 Path C — Proportional issuance at the "implicit" pre-state ratio (no swap, force proportional mint)

Hypothetical: mint `m = min_i floor(S × C_i / B_i)` directly, without the swap. With `C_1 = 0`:

- `m = min(floor(100 × 100 / 100), floor(100 × 0 / 100)) = min(100, 0) = 0` shares.
- **The new depositor mints zero shares for 100 token0.** This is the well-known "min-ratio zero" failure of proportional issuance against a two-leg book with one leg missing. It is not a usable rule.

### 2.4 Roundtrip symmetry check (Path B)

If the new depositor redeems all 41 shares at the **post-deposit** state (`B_0 = 200, B_1 = 100, S = 141`):

- Pro-rata exit: `floor(41 × 200 / 141) = 58` token0; `floor(41 × 100 / 141) = 29` token1.
- They receive **(58 token0, 29 token1)** for a deposit of 100 token0.
- If they immediately swap 29 token1 → token0 at 1:1, they end with 87 token0 → **net loss of 13 token0** plus 0.84 inventory-mismatch rounding plus the swap fee. (The 41.84 from the deposit is not fully recovered because the incumbent holdings grew by the spot walk the swap implied; if no AMM spot walk, the swap is 1:1 and they recover 87, not 58+29 = 87. The "loss on roundtrip" is 100 - 87 = 13, not 41.84, because the book value moved while they held shares.)

If they redeem immediately **at the same state** without a swap: they receive 58 token0; the 29 token1 stays in the vault and is **abandoned**.

### 2.5 What "preservation of value" can mean

| Definition | Path A (zap-in) | Path B (no-swap CP-mint) | Path C (no-swap min-ratio) |
|---|---|---|---|
| **Per-share backing `B_i/S` for incumbents** | Grows **proportionally** to their ownership fraction of the new contribution. Existing: 1.0 → 1.128 (+12.8%). New: 1.0 → 1.128. | Incumbents gain **disproportionately**: 1.0 → 1.418 (+41.8%) without contributing. New loses 41.84 of deposit value. | New mints 0; incumbents unchanged. |
| **Invariant `K = B_0 × B_1`** | Doubles via the AMM swap (caller pays the slippage). | Doubles via path B's accounting. The growth is real in `K`; it is the share-mint factor `sqrt(K_new/K_pre) - 1 = 41.4%`. New depositor mints only 41/(100+41) = 29% of the new K instead of a fair 50%. | Unchanged. |
| **Market value of LP token** | Marked by post-state `B_i / S`. Same for both sides. | Marked by post-state `B_i / S`. **Same per-share B_i**, but a 41.8% transfer from new to existing is hidden inside the mint equation. | Unchanged. |
| **Underlying quantities on hand** | Pro-rata: 33 shares × 150/133 ≈ 37.2 of each side. | Pro-rata: 41 shares × 200/141 ≈ 58 token0, 41 shares × 100/141 ≈ 29 token1. | None. |
| **Payout capacity in local sleeve `F_i`** | Depends on `F_i` at exit. A blocked single-token exit pays at most `F_token0`; shortfall hard-reverts (local buffer D18). | Same. The new depositor's 58 token0 is **not in `F_0` unless rebalanced**; it is in `D_0` (deployed). |

## 3. Sleeve implications under the owner clarifications

Per owner clarification, the sleeve base is `D_i` (vault-owned deployed) **not** the underlying pool's total liquidity. This matches the local buffer PRD §5 formula and the wings PRD §8. Restating for the counterexample:

- After the deposit of 100 token0, `B_0 = 200, D_0` rises to 200 only if the deposit was deployed (path A swap returns the swap out, the deposit was already in `D_0` pre-deposit for path A and B if the vault is full-range centered at 1:1 with all 100/100 deployed). If `D_0 = 200, D_1 = 100` and `F_0 = F_1 = 0`, then `targetFree_0 = floor((0 + 200) × 0.20e18 / (1e18 + 0.20e18)) ≈ 33.33` and `targetFree_1 = floor((0 + 100) × 0.20e18 / 1.20e18) ≈ 16.66`. The deadband is `5% of target ≈ 1.66` for token0, so a rebalance is required.
- The local reserve (R) view returns `F_i = 0` for both tokens at this state. Payout capacity in the blocked-state single-token exit is **zero** for both tokens. Any blocked exit reverts (local buffer D18) until a free-path rebalance fills the sleeve.
- The fee-on operation mints protocol LP from the rated book growth `sqrt(K_new) - sqrt(K_pre)` on the **pre-intake** K vs the post-deposit K. Path B's 41.4% K growth is real economic growth; existing holders' 41.8% per-share bump is partly a fee-on mint (if a fee-to is configured) and partly the one-sided-mint subsidy.

## 4. Cross-rule consistency check

- **D28 of local buffer PRD** ("no swap as rebalance tool") and the **10/90 wings split** are in tension: at certain ticks, the 90% token0 wing is dormant and `D_0` may not move toward target via a `modifyLiquidity` add (the wing is already full). Best-effort per token means the sleeve may stay thin. The 10/90 ratio is preserved; the 20% sleeve target is not always reachable.
- **No nested unlock** (PRD §8.S3 + local buffer D2) means that after a single-sided deposit (path B, no swap), if the AMM spot has moved into a wing, the rebalance that would top up the sleeve cannot run while blocked. The sleeve may stay below target for many blocks. This is a known design constraint, not a defect, but it interacts with the **payout-capacity question Q6** above.
- **Donation / pre-existing sleeve**: the example assumed `F_0 = F_1 = 0` for clarity. A non-zero sleeve scales the math: the path B subsidy magnitude shrinks proportionally to `F_i / B_i` because `B_i` includes `F_i`. The owner-confirmed meaning of "local reserve = tokens locally held by vault" applies to the `F_i` term only.

## 5. Few actionable owner questions (consolidated)

The seven questions in §1 are the only open items I would raise. Specifically Q1 (acknowledge the one-sided subsidy or reject path B), Q3 (rebalance swap exception for wings) and Q6 (separate payout-capacity floor) are blocking for v1 issuance and redemption.

## 6. What this pass does not establish

- No claim that path A, path B, or any other path is **safe**. The counterexample only exhibits the math; it does not argue economic soundness, sandwich resistance, or end-to-end audit.
- No measured gas, no chain selection, no Calldata/instrinsic breakdown, no commitment on EIP-7825 adoption per chain.
- No restoration of commit `35f47b51`. The historical PRD text is the only source cited for the 10/90 split and `activeLiquidityBps = 1000`.
- No claim that the existing local buffer PRD's protection constants (1/50/25/10 bp) or its deadband constants (`RELATIVE_TOL_WAD = 0.05e18`, `ABSOLUTE_FLOOR = 10^max(0,decimals-6)`) carry over to this product. Wings PRD §11 explicitly disclaims automatic inheritance.
- No statement on Weighted, Orbital, Pons, FullSpread, or Aperture consumer impact; that is a separate round.

---

*Saved to `docs/research/uniswap-v4-upper-lower-wings-prd-2026-10-05/clarifications/minimax-original.md`. Originals preserved. PRD unchanged. No code/tests/shell/config/deploy/instruction edits performed.*
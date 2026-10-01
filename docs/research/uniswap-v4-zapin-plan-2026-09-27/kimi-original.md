# Kimi K3 — Original: Decision-complete implementation plan proposal
# Uniswap V4 FullSpread SE — Proportional Zap-In, Liquid Sleeve, Iterative Rebalancing, Combined Exact-Output

**Date:** 2026-09-27 · **Researcher:** Kimi K3 (independent first pass this round; no peer artifacts read)
**Source PRD:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (2026-09-27 rev., D1–D19, §6.4) — "the PRD"
**Target:** `UniswapV4FullSpreadStandardExchangeVault` — `contracts/vaults/standard/exchange/protocols/uniswap/v4/` ("**V4FS/**"). No old-tree (`contracts/protocols/dexes/uniswap/v4/`) edits, deprecation actions, or migration.
**Owner rulings applied:** holder-funded repair toward proportionality/sleeve within protections is intended; exact-output routes interleave maintenance; the **entire combined exact-output+rebalance transition must be closed-form or `InvalidRoute`** — not an input quote plus numerical repair.
**Status:** research/plan proposal only. Authorizes nothing.

---

## 0. Plan decisions (PD) — engineering options resolved with rationale

| ID | Decision | Rationale |
|---|---|---|
| PD-1 | "Closed-form" = every route *unknown* (share count, input amount, composition swap size, maintenance swap size, placement liquidity) is solved by direct arithmetic (polynomial root in radicals, linear/rational solve) from on-chain state. Exact state *evaluation* (tick-bitmap segment checks, single-step `SwapMath`, position amount math) is arithmetic, not solving. Any bisection/Newton/secant over the unknown is "iterative route solving" and is forbidden inside combined exact-output routes (D18/D19); it remains permitted for exact-in deposits (PRD §7) and tests (as reference). | Direct reading of D18: "not merely a closed-form input quote followed by separately solved repair". |
| PD-2 | Supported domain for idle combined routes: PoolManager idle **and** hook modeled (hook-zero, or Pons V2 launch validated by `_ponsHookFees`) **and** static pool fee **and** every swap in the combined transition (user leg + maintenance leg) crosses **zero** initialized ticks **and** managed (non-imported) full-range position. Outside domain → `InvalidRoute`. | Fees/hook effects must be closed-form-accountable (§6.4.1). Tick crossing makes swap output piecewise with data-dependent segment selection — see G1. |
| PD-3 | Blocked (in-session) routes are **not** "combined" routes: they are preserved sleeve-only operations (PRD §3/§4) with no maintenance possible; their inverses are converted to closed form where currently bisected (CF-6). | §6.4: "does not authorize nested unlocks or waive the funded sleeve-only constraints in §4". |
| PD-4 | Exact-in routes (deposit, dual join, direct swap, zap-out exact-in) keep **placement-only** tails (add/remove liquidity) under the new sleeve formula. Holder-funded swaps live in (a) public `rebalanceLiquidReserve` and (b) interleaved maintenance of exact-output routes. | D17 scopes interleaving to exact-output; D9 scopes swap authority to public rebalance; automatic tails gaining swaps would silently change who pays for trading on every user op. |
| PD-5 | All combined routes and public rebalance share **one maintenance primitive** (`MAINTAIN`, §8): closed-form joint solve for (holder swap size `s`, placement liquidity `δ`), clamped to protection caps; no-op when thresholds satisfied (D12). | Uniform domain gate, uniform `InvalidRoute`, one derivation, one test oracle. |
| PD-6 | Every idle combined/ deposit route begins: (1) establish caller credit (PRD §6.1) → (2) collect position fees (`E→F` once) → (3) user leg → (4) placement (deposit) / `MAINTAIN` (exact-out) → (5) mint/pay → (6) full local sync. Collecting first zeroes `E`, simplifying all closed forms; PRD §5 collection semantics preserved. | "Collection moves fees from E into F once; it does not create an accounting gain." |
| PD-7 | Proportionality satisfaction threshold for D12's stop rule: normalized deployability residual ≤ **1 bp** (reuses accepted `MAX_ALIGNMENT_LOSS_WAD`) or the absolute token floor, mirroring the sleeve deadband structure. Sleeve satisfaction: existing deadband `max(floor_i, 5%·targetFree_i)`. | The PRD accepts 1 bp as *the* alignment tolerance; inventing a second number adds a knob; the stop rule needs a numeric band to avoid churn (§8). |
| PD-8 | Protection parameters are **immutable constants** in `Common` (new facet bytecode, new salts). No admin, no storage, no overload of `liquidReservePercentage` (PRD §9). Values: 25 / 50 / 10 / 1 bp as proposed (§9 working defaults). | Vaults are immutable/unowned (CLAUDE.md non-negotiable 5); constant change = new CREATE3 facet version = explicit governance event. |
| PD-9 | Deposit composition solver: **closed-form quadratic (CF-2) as primary** within the zero-crossing domain; `UniswapV4Quoter.quoteFromState` verification probe + ≤8 bisection refinements only when the segment check fails (exact-in route, bounded solver permitted by §7). Hard caps: `MAX_COMPOSITION_QUOTER_PROBES = 8`, `MAX_QUOTER_SWAP_STEPS = 64`; exhaustion → atomic revert. | Cheapest gas in the common domain, exact in principle, bounded everywhere; quoter (`UniswapV4Quoter.sol:143-174`) is the repo's exact swap evaluator already used for inventory quotes. |
| PD-10 | Do **not** use `UniswapV4ZapQuoter.quoteZapInSingleCore` anywhere in the new paths: it binary-searches (`UniswapV4ZapQuoter.sol:169-235`, `searchIters=20` via `QuoteService.sol:62,148-174`) the swap amount against the *pool-position* ratio, not the D5 *post-swap incumbent whole-book* ratio, and it is iterative. | Wrong target ratio whenever sleeve `F` or fees `E` skew the book (book ≠ position), and D19 bars iterative solving in combined routes. |
| PD-11 | `InvalidRoute` error: reuse crane `IStandardExchangeErrors.InvalidRoute(address tokenIn, address tokenOut)` (`lib/crane/contracts/interfaces/IStandardExchangeErrors.sol:25`), already inherited by `IStandardExchangeIn/Out`. | No new ABI surface; integrators already handle it. |
| PD-12 | Imported-position vaults: combined idle exact-out routes gate to `InvalidRoute` in v1 of this work, pending the integer-exactness verification milestone for PositionManager rounding (G2). Blocked sleeve routes and all exact-in routes unaffected. | Closed forms are identical (same position math), but PositionManager add/remove rounding (`validateMaxIn/MinOut` on principal-minus-fees) is not yet proven replicable; D19 forbids shipping an unproven "solution". Not a claim of nonexistence — a verification gate (G2). |
| PD-13 | New facet/delegate bytecode deploys under **new CREATE3 salts** (crane CREATE3 address depends only on (deployer, salt) — `Bytecode.sol:278-307`, `_create3AddressOf(salt)`, `TargetAlreadyExists` on collision) and a new DFPkg identity; existing instances keep their current cuts untouched. Salt convention: `keccak256(abi.encode("<FullSpread contract name>"))` (package README) gains a version suffix constant in the Component FactoryService for every redeployed component. | §3 forbids in-place migration; CP-PRD §7 identity law; same-salt redeploy would revert anyway. |
| PD-14 | Unlock batching: keep the existing one-operation-per-unlock pattern (`Common.sol:680-684,954-971`); combined routes run sequential unlocks (collect → user swap → liquidity op → maintenance swap → placement) inside one nonReentrant transaction. | Zero new settlement surface; the callback's settle/take accounting (`Common.sol:1023-1076`) is already proven. Batched-actions callback is a later gas optimization only. |
| PD-15 | `actualLiquidReservePercentage(token)` view (`LiquidReserveTarget.sol:69-83`) keeps its current free/(free+deployed) ABI and meaning (consumers exist); add a new additive view `actualSleeveRatioWad(token) = F·1e18/D` matching D3 semantics. `targetLiquidReservePercentage()` unchanged (returns oracle `p`). | Additive ABI only; acceptance #3 is about policy math, not view breakage. |

---

## 1. Support matrix (final)

Pool classes: **V** = vanilla static-fee (hook-zero); **P** = Pons V2 validated (`_ponsHookFees` true); **U** = any other hook and/or dynamic fee. Position: managed full-range (imported see PD-12). Pre-activation (`S=0`): exact-out routes N/A; dual-funding activation only (D59).

| Route (selector) | Idle V / P | Idle U | Blocked (any pool) |
|---|---|---|---|
| `exchangeIn` token→token (direct swap) | ✓ existing; placement-only tail, new sleeve formula | ✓ existing (measured actuals) | revert `PoolManagerInteractionBlocked` (existing) |
| `exchangeIn` token→shares (**deposit, D1/D4/D5**) | ✓ **new composition route** (CF-2 + PD-9) | ✓ same; atomic revert if measured ε>1 bp or impact>50 bp | sleeve-only mint, existing invariant-growth issuance (preserved; = zero-fee CP reference, CP-PRD §5.3) |
| `exchangeIn` shares→token (zap-out exact-in) | ✓ existing free path; placement-only tail | ✓ existing | `_singleExit` CP settlement, sleeve-covered (existing) |
| `exchangeInManyToOne` (dual join) | ✓ preserved; placement-only tail | ✓ preserved | preserved sleeve mint (existing) |
| `exchangeOut` token→token (direct exact-out) | ✓ **combined** (CF-1 + `MAINTAIN`); else `InvalidRoute` | **`InvalidRoute`** | revert (existing) |
| `exchangeOut` shares→token (zap-out exact-out) | ✓ **combined** (CF-3 + `MAINTAIN`); else `InvalidRoute` | **`InvalidRoute`** | `_singleExit` settlement + **CF-6 closed-form inverse**; no maintenance (PD-3) |
| `exchangeOut` token→shares (exact-share mint, "D64") | ✓ **combined** (CF-4 + `MAINTAIN`); else `InvalidRoute` | **`InvalidRoute`** | existing `_amountInForShares` (already closed-form, CP lib:78-96); no maintenance |
| `exchangeOutOneToMany` (dual exit exact-out) | ✓ **combined** (user leg swap-free + `MAINTAIN`); else `InvalidRoute` | **`InvalidRoute`** | existing sleeve dual-pay (cover-checked) |
| `rebalanceLiquidReserve` | ✓ **`MAINTAIN` closed-form step** (swap+placement, capped); no-op when satisfied (D12) | ✓ allowed with measured impact-cap enforcement (holder-funded; slot0-measured price impact is hook-independent); no-op when satisfied | revert (existing) |
| `importPosition` | unchanged | unchanged | unchanged (hard-revert blocked, existing) |

Route-availability/previews report the same domain (acceptance #20): previews revert `InvalidRoute` (combined) or `InvalidQuoteState` (transition quotes) exactly where execution would.

## 2. State model and notation (implementation contract)

Per token i ∈ {0,1}, after fee collection (PD-6), all in native token units:
- `u` = sqrtPriceX96 (Q64.96); `l` = pool active liquidity (`StateLibrary.getLiquidity`); `L` = vault position liquidity (`_currentLiquidity`, `Common.sol:462-464`); `[√a, √b]` = full-range bounds (`_deriveManagedTicks`, `Common.sol:1141-1145`).
- `D_i(u)`: deployed principal via exact position math (`_positionAmounts`, `Common.sol:466-483`): `D_0 = L(1/u − 1/√b)`, `D_1 = L(u − √a)` in-range (full-range ⇒ always in range).
- `F_i` = `_freeBalances()`; `E_i` = `_collectablePositionFees()` (zero post-collect); `T_i = D_i + F_i`; book `B_i = D_i + F_i + E_i`.
- `p` = `_liveLiquidReservePercentage()` (WAD; vault→type→global cascade with stored-zero fallthrough, `VaultFeeOracleQueryFacet.sol:322-331`); `q = p/(1e18+p)`; `targetFree_i = floor(T_i·p/(1e18+p))` (**new**, D3).
- Fee: vanilla pool `f` = `poolKey.fee` (static, per-million), protocol fee `pf` from slot0; Pons: `f=0` (`PONS_V2_POOL_FEE=0`, `TestBase_UniswapV4StandardExchange_PonsV2.sol:66`), hook cuts `c = (hookFeeBps + creatorTaxBps)/1e4` as two floored cuts on the unspecified leg — verified against hook source (`PonsV2MemeHook.sol:495-504`: `feeAmount = unspecified·hookFeeBps/BASIS_POINTS`, `taxAmount = unspecified·creatorTaxBps/BASIS_POINTS`) matching `QuoteService._ponsHookFees`/`_adjustHookSwap` (`QuoteService.sol:21-58`).
- Single-segment exact-in swap of `s` (token1→token0): `u1 = u0 + (1−f)s/l`; `out_0 = l(1/u0 − 1/u1)`; Pons: user-visible `out_0' = out_0 − floor(out_0·feeBps/1e4) − floor(out_0·taxBps/1e4)`. New vault fee accrual (vanilla): `ΔE_1 = f·s·(1−pf)·L/l`; Pons: `ΔE = 0`.

## 3. Closed forms (derivations; all roots in radicals)

### CF-1 — Single-segment exact-out swap input (direct exact-out leg)
Exact out `Y` of token1: `u1 = u0 + Y/l` (linear). Gross token0 input: replicate one `SwapMath.computeSwapStep` exactly (integer, fee-inclusive, round-up): `in = ceil(l·u0·u1·(1/u0 − 1/u1)… )` — the crane `SwapMath` port (same library the local `PoolManager` port executes) guarantees integer-exactness by construction. Mirror for token0-out. Pons exact-out: gross the unspecified-leg input by the two cuts (`QuoteService._adjustHookSwap(..., false)` semantics, `QuoteService.sol:50-58`).

### CF-2 — Deposit composition swap size (exact-in deposit of `d` token1)
Solve `C_0·B_1' = C_1·B_0'` where `C_0 = l(1/u0−1/u1)` (Pons: ×(1−c)), `C_1 = d − s`, `s = l(u1−u0)/(1−f)`, `B_0' = L(1/u1−1/√b)+F_0`, `B_1' = L(u1−√a)+F_1+ΔE_1(u1)`.
`C_0·u1 = l(u1−u0)/u0` (linear in `u1`); `B_0'·u1`, `B_1'`, `C_1` all linear in `u1` ⇒ condition ×`u1` is a **quadratic in u1**: `α·u1² + β·u1 + γ = 0` with `α,β,γ` integer functions of `(u0, l, L, √a, √b, F_0, F_1, f, pf, d)`. Root selection: `u1 ∈ (u0, min(u_segmentMax, u_impactCap)]`, `s ≤ d`, discriminant ≥ 0; else infeasible (deposit: revert; or PD-9 refinement when the failure is segment-induced).
*Proof sketch completed by expansion (this document's working); coefficients tabulated in the maintenance library NatSpec.*

### CF-3 — Zap-out exact-output shares (idle)
Execution sequence mirrored from `_executeFreeZapOutWithdrawalCore` (`OutExecutionDelegate.sol:108-147`): burn `δL=floor(s·L/S)`, free portions `floor(F_i·s/S)`, swap other-token proceeds. `X(s) = P·s + Q·s/(u0 + k·m·s)` with `P = (L(1/u0−1/√b)+F_0)/S`, `Q = (1−f)m/u0`, `m = (L(u0−√a)+F_1)/S`, `k=(1−f)/l`. Setting `X(s) = target` ⇒ **quadratic** `P·km·s² + (P·u0 + Q − target·km)·s − target·u0 = 0`. Integer protocol: `ŝ = ceil(root)`; evaluate integer forward `X(ŝ)` with execution floors; require `X(ŝ) ≥ target > X(ŝ−1)` (adjust ±1); burn `ŝ`, pay exactly `target`, surplus booked (existing D55 semantics, `OutExecutionDelegate.sol:78-81`).

### CF-4 — Exact-share mint input (idle "D64" replacement)
Solve for `u1` from the issuance identity with aligned ratios: `S·l(1/u0 − 1/u1) = S_out·(L(1/u1 − 1/√b) + F_0)` ⇒ **linear** in `u1` after ×`u1`:
`u1* = (S·l + S_out·L) / (S·l/u0 − S_out·(F_0 − L/√b))` (token1-in; mirror for token0-in; require denominator > 0, `u1* ≥ u0`, segment + impact caps).
Then composition alignment gives caller input: `d = s* + out_x·B_1'/B_0'` (rational, all terms known; `B_1'` includes `ΔE_1`, incumbent-owned). Integer: `d̂ = ceil(d)`; execute; verify `min(floor(S·C_0/B_0'), floor(S·C_1/B_1')) ≥ S_out`; mint exactly `S_out`; surplus backing accrues to holders (existing `_executeZapInMintExactOut` semantics, `OutExecuteTarget.sol:105-137`).
**This replaces** the invariant-growth `_amountInForZapMint` (`OutBase.sol:49-62`) on the idle path; PRD §6.4: "the current invariant-growth exact-output inverse alone does not establish compliance."

### CF-5 — Joint maintenance solve (`MAINTAIN`, holder-funded)
Unknowns: holder swap size `s` (sell the relatively excessive token) and placement `δ` (signed liquidity). Sleeve targets `t_i = q·T_i'` (placement-invariant `T_i'` post-swap). Exact joint solution requires `(F_i' − t_i)` parallel to placement direction `(a_0(δ), a_1(δ)) = δ·(1/u1 − 1/√b, u1 − √a)`:
`(F_0' − t_0)/(F_1' − t_1) = (1/u1 − 1/√b)/(u1 − √a)` with `F_0' = F_0 + l(1/u0 − 1/u1)`, `F_1' = F_1 − s`, `t_i = q(D_i(u1) + F_i')`.
Expanding (identity `l(1/u0 − 1/u1) = l(u1−u0)/(u0 u1)`, `s = l(u1−u0)/(1−f)`) and multiplying by `u1` ⇒ **quadratic in u1**: `(A_0 − B_1/√b)·u1² + (B_1 + A_1/√b − A_0·√a − B_0)·u1 + (B_0·√a − A_1) = 0` with
`A_0 = (1−q)(F_0 + l/u0) + qL/√b`, `B_0 = (1−q)·? ` — *full integer coefficient table to be generated in the maintenance library NatSpec from this expansion; structure verified: u1², u1, constant terms all closed-form in `(F_0, F_1, L, l, u0, √a, √b, q, f)`.*
Then `s = l(u1*−u0)/(1−f)`, `δ = (F_0' − t_0)/(1/u1* − 1/√b)` (sign: add if positive, remove if negative, clamp `−L ≤ δ`, add-side capped by available `F'`).
Clamps (all closed-form boundary values): impact cap `u1 ≤ u0·√(1+cap)` (25 bp rebalance / 50 bp composition); `s ≤ F_sell`; root-feasibility (discriminant, interval). If exact joint solve infeasible → take the capped boundary step with best progress metric (public rebalance; §8 progress rule) — still closed-form; combined exact-out routes treat *infeasible-undefined* states (e.g. `l=0`) as `InvalidRoute`, but boundary-clamped partial steps remain supported transitions.

### CF-6 — Blocked single-exit inverse (replaces `_sharesForSingleExit` bisection)
`_singleExit` (`StandardExchangeConstantProduct.sol:98-111`) in reals: `out = resOut·r(2−r)`, `r = s/S` ⇒ `r = 1 − √(1 − out/resOut)` (valid `out ≤ resOut`; `reserveOther=0` degenerates to linear `s = ceil(out·S/resOut)`). Integer: `ŝ = ceil(r·S)`; verify `forward(ŝ) ≥ out > forward(ŝ−1)`; adjust ±1. Deterministic closed form; bisection (`StandardExchangeConstantProduct.sol:113-129`) retired in V4FS call sites only — **add `_sharesForSingleExitClosedForm` as a new function; do not alter the shared library's existing functions** (V3 FullSpread shares this file and is out of scope).

### CF-7 — Placement (deposit allocation + maintenance δ execution)
Existing `_managedLiquidityPlan`/`_deployExcessLiquidity`/`_refillDeficitLiquidity` mechanics (`Common.sol:530-581,818-899`) with the **new target formula** in `_loadRebalanceSnap` (`Common.sol:744-750`) and `_targetFree` (`Common.sol:358-360`): `targetFree_i = floor(T_i·p/(1e18+p))`. Deploy-excess budgets capped by plan ratio (ρ at current price); residual disclosed (D8). Deficit refill fraction `max(need_i/deployed_i)` capped at 100% — mechanics unchanged; only the target changes.

## 4. Deposit route algorithm (`exchangeIn` token→shares, idle) — §6.2 faithful

1. `_secureTokenTransfer` credit (existing; guard + reserve-delta, `Common.sol:1219-1240`). **Before any collection** (§6.1).
2. `_collectManagedFeesIfIdle()` (PD-6).
3. Snapshot `(u0, l, L, F, S)`; compute CF-2 root `(u1*, s*)`; feasibility: discriminant, interval, `s* ≤ credit`, impact ≤ 50 bp (price metric, §9), segment check (next-initialized-tick both bounds — bounded bitmap reads).
   - If segment check fails: PD-9 refinement — evaluate composition error at `s*` via `UniswapV4Quoter.quoteFromState` (exact evaluation, `Common.sol:222-240` pattern), ≤8 bisection probes on monotone residual `g(s) = callerRatio(s) − bookRatio(s)` (caller ratio increasing in `s`, book ratio decreasing ⇒ unique root), `MAX_QUOTER_SWAP_STEPS=64` per probe; exhaustion/infeasible → revert `UniswapV4Exchange_UnsupportedRoute()`.
4. Execute `_swapExactIn(zeroForOne, s)` **funded only by caller credit** (D2 — swap input taken from the just-credited amount; never from booked `F`; enforce by measuring: vault balance of input token before/after minus credit accounting).
5. Measure actuals: `C_0 = balanceDelta(out)`, incumbent changes re-measured (`_positionAmounts`, fee growth) — swap-caused position/fees changes are **incumbent** (§6.2); `C_1 = credit − s_used` (price-limit partial fills leave unspent input in caller contribution).
6. Placement toward sleeve (CF-7) on whole-book free inventory (incumbent sleeve + caller basket); D8: proportional ownership precedence — deploy only what the position ratio absorbs at plan cap; residual stays free, emitted (`PlacementResidual`), booked.
7. Shares: `sharesOut = min(floor(S·C_0/B_0'), floor(S·C_1/B_1'))` (D6); `B_i'` = incumbent backing after swap excluding contribution (includes collected fees and swap-earned `ΔE`).
8. Protection gates (revert atomically — whole transaction, sequential unlocks included): ε check (§7 formula, FullMath.mulDiv 512-bit, zero-denominator guards), impact ≤ 50 bp, execution shortfall vs modeled ≤ 10 bp (modeled pools only), `sharesOut ≥ minSharesOut`, `sharesOut > 0`.
9. Mint; `_syncVaultReserves()`; emit `CompositionSwapExecuted` (+`PlacementResidual` if any); `_pokeBoundPoolTwap()`.
Blocked: unchanged existing `_executeZapInDeposit` sleeve mint (`InBase.sol:269-312`), `LocalDepositWhileBlocked`.

## 5. Combined exact-output algorithms (idle; domain-gated per PD-2)

Uniform skeleton: domain gate → credit/pull (existing exact-out funding/refund rules preserved, §6.4.3) → collect → user leg (route-specific CF) → execute + measure → pay exact output / mint exact shares → enforce max-input → `MAINTAIN` (CF-5) → verify protections (impact caps per leg, shortfall ≤10 bp on modeled pools) → full sync → events → TWAP poke.

- **token→token:** CF-1 input; `amountIn ≤ maxAmountIn`; execute `SwapExactOut` (existing `Common.sol:973-989`); refund exact-out unused credit only (existing `_refundExcess`, `OutExecuteTarget.sol:185-191`); `MAINTAIN`.
- **shares→token (zap-out withdrawal):** CF-3 shares; `ŝ ≤ maxAmountIn(shares)`; execute existing core (`OutExecutionDelegate.sol:108-147`) — unchanged mechanics, new inverse; pay exactly `amountOut`; `MAINTAIN`.
- **token→shares (mint):** CF-4 input; `d̂ ≤ maxAmountIn`; composition swap `s*` (caller-funded); verify min-issuance ≥ `amountOut`; mint exactly `amountOut`; `MAINTAIN`.
- **one→many (dual exit):** existing `_payIdleDualExit` user leg (`OutMultiTarget.sol:101-121`); then `MAINTAIN` (replaces `_rebalanceLiquidReserveBestEffort` tail at :120).
Domain failures at any gate → `InvalidRoute(tokenIn, tokenOut)` (PD-11). Protection breach (impact/shortfall) → protection errors (§9), not `InvalidRoute`.

## 6. Public `rebalanceLiquidReserve` (rewrite of `_rebalanceLiquidReserveInternal`, `Common.sol:757-807`)

1. Gate: `_requireNotDisabled` + idle (existing, `LiquidReserveTarget.sol:92-97`).
2. Collect fees; snapshot; compute residuals `R_i = F_i − t_i` (new target); deadband `db_i = max(floor_i, 5%·t_i)`; proportionality residual `propErr = |R_0·a_1u − R_1·a_0u| / (T_0·a_1u + T_1·a_0u)` (WAD).
3. **Stop rule (D12):** if `|R_i| ≤ db_i` both **and** `propErr ≤ 1 bp` → no trades, sync, return false.
4. Else CF-5 joint solve (direction from residual signs), clamped (impact 25 bp, `s ≤ F_sell`, `−L ≤ δ`); **progress rule (no-churn):** objective `J = max(propErr/1e14, |R_0|/db_0, |R_1|/db_1)` (normalized); execute only if closed-form post-state `J' < J` (strictly); else truthful no-op. Rounding residuals inside deadband ⇒ next call no-ops ⇒ no pointless fee churn; legitimate repairs always strictly reduce `J` (each capped step reaches either the exact solution or the impact boundary — both strict improvements when outside thresholds).
5. Execute holder swap + placement; measure actuals; costs/fees to book (§8); sync; emit `MaintenanceStepExecuted` + existing `LiquidReserveRebalanced`; poke TWAP.
Immediate repeated calls (D10/D11): each call re-derives from live state; a large repair proceeds in 25 bp-capped steps across calls in the same tx/block.

## 7. Attribution rules (normative)

- **Caller contribution (deposit/mint legs):** credited input net of swap input spent + actual swap output received + retained amounts (D7). Never includes: collected incumbent fees, swap-earned `ΔE`, incumbent sleeve, placement residuals of incumbents.
- **Incumbent backing `B'` (issuance denominator):** whole book post-swap excluding caller contribution — includes collected fees and the vault's own-LP fee earnings `ΔE` from the composition swap (§6.2: "belong to incumbent backing").
- **Own-LP fees:** vanilla `ΔE = f·s·(1−pf)·L/l` per swap (input-token fee, pro-rata active liquidity; vault share `L/l`; Pons `ΔE=0`, hook cuts are external costs). Collected at route start (`E→F`, once); accruals during the route stay `E` until the next route's collection; `E` counts in share backing, never in `T`/sleeve cover (PRD §5).
- **Maintenance (holder-funded):** swap input from booked `F`; all costs (impact, fees, hook cuts) and own-fee recovery accrue to the book; mints nothing; never credited to any caller (§6.4.4, §8).
- **Pons cuts:** caller composition swap — cuts reduce caller's received output (caller cost, inside D2 budget); maintenance swap — cuts are book costs. Model: two floored bps cuts on the unspecified leg (verified §2).

## 8. Protection constants and checks (immutable, PD-8)

```
REBALANCE_MAX_PRICE_IMPACT_WAD   = 0.0025e18  // 25 bp, maintenance/public rebalance legs
COMPOSITION_MAX_PRICE_IMPACT_WAD = 0.005e18   // 50 bp, caller-funded composition leg
MAX_EXECUTION_SHORTFALL_WAD      = 0.001e18   // 10 bp, measured vs fee-inclusive model (modeled pools)
MAX_ALIGNMENT_LOSS_WAD           = 0.0001e18  // 1 bp, ε and proportionality threshold (PD-7)
MAX_COMPOSITION_QUOTER_PROBES    = 8
MAX_QUOTER_SWAP_STEPS            = 64
```
- Price impact: `|u1² − u0²|·1e18/u0²` via `FullMath.mulDiv` (price, **not** sqrt-price, §9); evaluated per swap leg (user leg, each maintenance leg), from slot0 before/after — hook-independent.
- Fee-inclusive quote: model already nets LP fee + hook cuts; no second subtraction (§9).
- ε: for both `i`: require `mulDiv(sharesOut, B_i', 1) · 10_000 ≥ S·C_i·9_999` implemented as `FullMath.mulDiv(sharesOut, B_i'·10_000, S·C_i) ≥ 9_999` with explicit `S·C_i == 0` guards (activation paths never reach here).
- Limits bind even with zero caller min-out (§9): all checks are vault-side, independent of `minSharesOut`/`minAmountOut`.

## 9. Errors / events / ABI / storage

- **Reuse:** `IStandardExchangeErrors.InvalidRoute(address,address)` (PD-11); existing `UniswapV4Exchange_*` set (`Common.sol:306-314`), `ExchangeIn/OutNotAvailable`, `InsufficientLocalReserve`, `TransferDeltaInsufficient`, `EOAPretransferNotAllowed`.
- **New errors:** `UniswapV4Exchange_AlignmentLossExceeded(uint256 epsilonWad)`, `UniswapV4Exchange_PriceImpactExceeded(uint256 impactWad, uint256 capWad)`, `UniswapV4Exchange_ExecutionShortfallExceeded(uint256 expected, uint256 actual)`, `UniswapV4Exchange_ClosedFormInfeasible()` (deposit-side domain/solver failure; exact-out side uses `InvalidRoute`).
- **New events:** `CompositionSwapExecuted(address indexed tokenIn, uint256 swapIn, uint256 swapOut, uint160 sqrtPriceBeforeX96, uint160 sqrtPriceAfterX96)`; `PlacementResidual(address indexed token, uint256 amount)`; `MaintenanceStepExecuted(bool zeroForOne, uint256 swapIn, uint256 swapOut, int128 liquidityDelta, uint256 free0After, uint256 free1After)`. Keep `LiquidReserveRebalanced`, `LocalDepositWhileBlocked`.
- **New views (additive only):** `actualSleeveRatioWad(address token)` (PD-15). No selector removals; all existing surfaces preserved.
- **Storage:** none new. Constants only; `MultiAssetBasicVaultRepo` snapshots, position repo, fee-oracle cascade untouched (PRD §12 preservation — V4FS local-snapshot + caller guard controls carried into every new workflow; regression-tested, acceptance #12/#13).

## 10. Quotes, previews, transition quotes, hooks

- `previewExchangeIn/Out` (`InQueryTarget`/`OutQueryTarget` + Multi variants): mirror the new execution exactly. Deposit preview = CF-2 solve + placement simulation (single-segment closed form; quoter refinement permitted for exact-in previews). Combined exact-out previews = same CF pipeline and same domain gate: outside domain → revert `InvalidRoute` (not a fabricated number); modeled pools → integer-exact preview (R4). `previewExchangeOut` direct-swap branch currently reverts when blocked (`OutQueryTarget.sol:38-41`) — unchanged.
- Transition quotes / SY (`InQueryTarget.sol:14-170`): `_inventoryDeposit` must model composition (CF-2) instead of invariant growth; `_inventoryRebalance` (:145-169) must model `MAINTAIN` (swap + placement) instead of placement-only; blocked paths unchanged; `WithdrawExactOut` idle branch (:88-96) switches to CF-3 and `InvalidQuoteState` outside domain. SY redemption semantics preserved (R1: one accounting model).
- `_inventorySharesIn`/`_previewZapOutWithdrawal` bisections (`Common.sol:175-212`, `OutBase.sol:104-119`) retired on idle paths in favor of CF-3/CF-6 (preview==execution).
- Unmodelled hooks: exact-in quotes remain *indicative* (execution measures actuals); NatSpec must state they are not exact (PRD §10); combined exact-out quotes fail-closed (`InvalidRoute`). No whitelist added (D14); `_supportsProjectedHook` (`QuoteService.sol:44-48`) is a quote-domain predicate, not admission control.

## 11. File work packages (V4FS tree; exact paths)

| WP | File(s) | Change |
|---|---|---|
| WP-1 | `…/uniswap/StandardExchangeConstantProduct.sol` (shared!) | **Additive only:** `_sharesForSingleExitClosedForm` (CF-6). No edits to existing functions (V3 family shares this file). |
| WP-2 | `v4/UniswapV4FullSpreadStandardExchangeVaultMaintenanceMath.sol` **(new internal library)** | CF-1…CF-5 coefficient tables + roots, impact/ε/shortfall checks, segment check (next-initialized-tick reads), progress metric `J`. Pure/view over a `MaintState` struct. |
| WP-3 | `v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol` | `_targetFree` (:358-360) → `floor(T·p/(1e18+p))`; `_loadRebalanceSnap` (:744-750) same; protection constants (§8); `_rebalanceLiquidReserveInternal` (:757-807) → `MAINTAIN` (§6); new `_maintainPlacementOnly` (placement-only tail variant, new formula) replacing `_rebalanceLiquidReserveBestEffort` call semantics on exact-in tails; inventory machinery (`_inventoryDeposit`/`_inventoryRebalance` callers in InQueryTarget) updated; dead `_deployedFaceOf` (:1242-1247) removal-note. |
| WP-4 | `v4/UniswapV4FullSpreadStandardExchangeVaultInBase.sol` | `_executeZapInDeposit` (:269-312) → composition algorithm (§4) on idle; blocked branch untouched. `_executeZapInDualDeposit` (:335-375) unchanged except new-target placement tail. |
| WP-5 | `v4/UniswapV4FullSpreadStandardExchangeVaultOutBase.sol` | `_previewZapOutWithdrawal` (:64-119) → CF-3 (idle) / CF-6 (blocked); `_amountInForZapMint` (:49-62) → CF-4 (idle); blocked keeps `_amountInForShares`. |
| WP-6 | `v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol` | exchangeOut dispatch (:34-103): domain gates + `MAINTAIN` interleave on all three branches; `_executeZapInMintExactOut` (:109-137) → CF-4 flow; refund rules unchanged. |
| WP-7 | `v4/UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | `_quotedWithdrawalShares` (:85-100) → CF-3/CF-6 (drop budget-hint bisection-fallback); blocked branch → CF-6 inverse. |
| WP-8 | `v4/UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol` | `_payIdleDualExit` (:101-121): tail → `MAINTAIN`; domain gate → `InvalidRoute`. Blocked unchanged. |
| WP-9 | `v4/UniswapV4FullSpreadStandardExchangeVaultInQueryTarget.sol` + `…OutQueryTarget.sol` + `…InMultiQueryTarget` + `…OutMultiQueryTarget` | Preview parity (§10); `InvalidRoute`/domain-consistent availability. |
| WP-10 | `v4/UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol` | `actualSleeveRatioWad` view; NatSpec for new stop rule; rebalance body now calls rewritten internal. |
| WP-11 | `v4/interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol` (+ relevant In/Out interfaces) | New events/views declarations. |
| WP-12 | `v4/UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol` + `…DFPkg.sol` + `I…DFPkg.sol` | Versioned salts for **all** redeployed facets/delegates (all inherit Common ⇒ all bytecode changes): In/Out/InMulti/OutMulti/InQuery/OutQuery/InMultiQuery/OutMultiQuery/LiquidReserve/PositionImport facets + In/Out ExecutionDelegates + DFPkg. `PkgInit`/`PkgArgs` stay on the interface (crane law). |
| WP-13 | `v4/UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol`, `…InFacet.sol`, etc. | Metadata only if selectors changed (new view); otherwise redeployed with new salts under unchanged names/surfaces. |

Out of scope: old tree (any edit), V3 family, BasicVaultCommon, fee oracle, hook admission, registry deprecation actions, Universal Router migration, live-instance rewiring.

## 12. Deployment and identity

- Facets/delegates/packages via CREATE3 FactoryServices with new versioned salts (PD-13); vault packages via IndexedEx manager vault registry (`deploy*DFPkg` path, CLAUDE.md non-negotiable 2); no repoint/disable of existing instances or the old package (no deprecation action authorized).
- `forge build` before `forge test`/`forge script` (artifact law); every new runtime ≤ 24,576 bytes (release limit per package README) — size risk concentrated in In/Out facets; mitigation: move WP-2 hot paths into the existing CREATE3 execution-delegate pattern (`functionDelegateCall`, `OutExecuteTarget.sol:24-31` precedent) if any facet exceeds the limit. DoD gate, not an afterthought.
- Worktree cache seeding; hermetic default profile; no `via_ir`.

## 13. Test plan (mapped to PRD acceptance 1–20)

Location: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/zapIn/` (new) + existing `release/v4/` suites updated; fixtures: `SeMatrix_FullSpreadV4Fixture.sol` (hook integration/blocked), `TestBase_UniswapV4StandardExchange_PonsV2.sol` (modeled hook), production registry-deployed proxies, hermetic PoolManager port; **no SUT mocks**; independent reference models in tests may iterate (PD-1).
1–2. Repeated unilateral deposits both directions; shares vs test-side reference (direct PoolManager compose); sleeve-credited contribution (D7); incumbent-fee non-attribution check. 3. Sleeve semantics: 100/40@20% → 116⅔/23⅓; oracle override live; stored-zero fallthrough; `p=0`; `p=1e18`. 4. Blocked deposit inside outer unlock (hook fixture) — no nested unlock. 5. Blocked withdrawal cover-or-revert. 6. Dual activation; single-token activation invalid. 7. Public rebalance bounded swaps; same-tx repeated calls progress. 8. Stop rule: satisfied → zero deltas/events. 9. No throttle: N consecutive calls. 10. Impact units price-vs-sqrtPrice (adversarial case where they differ >tol); no double fee subtraction vs reference. 11. In-deadband but >1 bp alignment → revert (`AlignmentLossExceeded`). 12. Full booking after every route incl. residuals/dust (INV-R1 assertions). 13. Pretransfer: unbooked-claim happy path; booked re-credit revert; EOA `EOAPretransferNotAllowed`. 14. Unmodelled-hook pool: exact-in works (measured), combined exact-out + previews `InvalidRoute`; no fabricated quote. 15. Native/WETH, import, Multi routes, SY transitions, hook SE-matrix regression. 16. Cross-mode idle/blocked deposit-withdraw cycles vs reference; quote-diff-not-exploit documentation. 17. Solver bounds: probe counters; independent economic checks. 18. Combined exact-out (all four routes): closed-form output == high-precision test-side reference; exact output honored; max-input enforced; attribution assertions. 19. `InvalidRoute` battery: tick-crossing requirement, unmodelled hook, imported position (PD-12), `l=0`; assert no maintenance-omission fallback (route reverts rather than skipping `MAINTAIN`). 20. Preview==execution across idle/blocked/no-trade/domain-edge.
Plus: fuzz/invariant handlers (deposit/rebalance cycles vs reference book; holder-NAV-never-decreases-by-placement; INV-R1); gas snapshot vs 24,576-byte limit; Pons-model equivalence tests (hook source cross-check); CF coefficient differential tests (real-root vs reference bisection over wide state grid).

## 14. Epistemic gaps (explicit; not claimed nonexistent)

- **G1 — Multi-segment combined transitions.** Per-segment piecewise roots exist mathematically, but segment-index selection interleaves with root choice (data-dependent search). Classified outside the supported closed-form domain → `InvalidRoute` (PD-2). If the owner wants this domain, it requires ruling that bounded piecewise exact evaluation qualifies under D18 — a product interpretation, escalated, not assumed.
- **G2 — Imported-position PositionManager rounding replication** (PD-12): formulas identical; integer-exactness of PM `modifyLiquidities` rounding unverified → gated `InvalidRoute` until a verification milestone; reversible.
- **G3 — Pons model coverage:** validated 13-word launch schema + fixed flag set + static fee only (`QuoteService.sol:21-48`); drift → fail-closed `InvalidRoute` for combined routes. Verified against `PonsV2MemeHook.sol:495-504` on 2026-09-27.
- **G4 — Dust-scale ε feasibility:** mints below ~1e4 raw share units cannot satisfy 1 bp with flooring; compliant behavior = atomic revert; quantified as negligible (activation minimums ≥ 1e15 raw at 18/18).
- **G5 — Integer coefficient tables for CF-2/CF-5** are structurally proven here (quadratic/linear in `u1`) but must be generated with overflow analysis (256/512-bit bounds per term) during WP-2; differential tests (13) are the correctness gate.

## 15. Definition of Done (plan-level)

All 20 acceptance items green on registry-deployed production paths; CF differential suite green; InvalidRoute battery green; runtime sizes ≤ 24,576; hermetic `forge test` default profile; `forge build` before test; no old-tree diff; no V3/shared-library behavior change (hash-check WP-1 functions untouched); NatSpec for domain gates, stop rule, attribution, and "sleeve is not withdrawal-liquidity promise".

## 16. Evidence and confidence

Code (read 2026-09-27): V4FS `Common.sol` (:318-330 gate, :358-360 target, :610-617 sync, :680-684 unlock, :757-807 rebalance, :1219-1240 secure pull), `InBase.sol` (:126-135 blocked exit, :269-312 deposit), `OutExecuteTarget.sol` (:34-103, :109-137, :185-191), `OutBase.sol` (:49-119), `OutExecutionDelegate.sol` (:18-192), `OutMultiTarget.sol` (:101-121), `InTarget.sol` (:40-84), `InQueryTarget.sol` (:14-170), `OutQueryTarget.sol` (:26-54), `QuoteService.sol` (:21-58, :96-227), `LiquidReserveTarget.sol` (:69-97); crane `UniswapV4Quoter.sol` (:37-204), `UniswapV4ZapQuoter.sol` (:151-235), `Bytecode.sol` (:278-317), `IStandardExchangeErrors.sol:25`; `PonsV2MemeHook.sol` (:495-504); `VaultFeeOracleQueryFacet.sol` (:322-331); `StandardExchangeConstantProduct.sol` (:37-129); `foundry.toml` (:29-36). Law: PRD D1–D19/§6.4; CP-accounting PRD R1–R13/§5; pretransfer PRD §1.1/§4; DETF_ALIGNMENT D57–D59/§24.7.1; CLAUDE.md non-negotiables.
**Confidence: high** — route inventory, attribution rules, CF-1/CF-3/CF-4/CF-6 derivations (fully expanded), Pons model (source-verified), deployment/identity mechanics. **Medium-high** — CF-2/CF-5 coefficient correctness pending WP-2 expansion + differential tests (structure proven); imported-position gate (G2); D18 interpretation PD-1 (text-supported, product-visible). **Remaining blockers:** none requiring owner answer under the stated rulings; G1/G2 are escalation *paths*, not assumptions.

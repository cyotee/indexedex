# MiniMax M3 — Round 2 independent first pass

**Scope.** Human accepts adding the previously discussed buyback routing (Round 1 originals, MiniMax section, frozen) and now asks for two extensions: (A) finite-capacity **split** routing between InverseBond and the canonical V2 swap, and (B) **NET-funded zap-in** that uses InverseBond to obtain USDG for a proportional LP deposit, instead of/in addition to swapping through the pool. Research only; no PRD/plan/source edits. Prior findings preserved unmodified; this round is independent — no peer artifacts read.

## 1. Toy continuous model (assumption-labelled)

Let `n` = total NET (raw, 9-dec) available for the operation; `P = InverseBond.price()` (WAD USDG per NET) = `backingPerToken × 9850`; `r_pool_µ(s)` = canonical pool marginal USDG-out per NET-in at trade size `s` (V2 with 30-bps fee: `r_pool_µ(s) = 997·y / (1000·x + 997·s)`); `c_WAD = InverseBond.capacityRemaining()` (WAD USDG, raw-equivalent `c_raw = c_WAD / 10^(18−usdgDecimals)`); `f_ib = c_WAD × 1e9 / P` is the NET-equivalent of capacity (`n_ib_max`); `R = x/y` is current pool reserve ratio (NET per USDG).

**Objective A (USDG-out).** Maximize `u_pool(n_pool) + u_ib(n_ib)` s.t. `n_pool + n_ib ≤ n`, `n_ib ≤ n_ib_max`, `u_ib = floor(n_ib·P/1e9) / 10^(18−usdgDecimals)`. Optimum: fill IB first if `r_ib = P/1e9 × 10^(usdgDecimals−18)` exceeds `r_pool_µ(0)`; else fill pool only. If `r_ib > r_pool_µ(0)` and `n_ib_max < n`, exhaust IB then fill pool. If `r_ib > r_pool_µ(n − n_ib_max)`, exhaust IB even at the expense of pool slippage. Continuous conclusion: split is monotone — IB-then-pool when `r_ib` exceeds pool marginal at the boundary; pool-only otherwise.

**Objective B (LP-out via NET-funded zap).** Given `n` NET, sell `n_pool + n_ib` for USDG and deposit `(n − n_pool − n_ib, u_pool + u_ib)` proportionally to the post-pool-trade reserves `(x + n_pool, y − u_pool)`. Proportional constraint:

```text
(n − n_ib − n_pool) / (u_ib + u_pool) = (x + n_pool) / (y − u_pool)
```

With `u_ib = n_ib · P/1e9 · 10^(usdgDecimals−18)` (continuous; rounding below) and `u_pool` from the standard V2 zap formula. Without IB, the canonical optimum in the no-fee continuous limit is `n_pool* = n·x / (n + 2x)` (derivation: solve the proportional constraint plus `u_pool = n_pool·y/x`; matches the standard V2 single-input zap). With IB, treat `u_ib` as a free USDG source priced at `r_ib`:

```text
n_used = (x + n_pool)/(y − u_pool) · (u_ib + u_pool)
n      = n_used + n_ib + n_pool
```

Two equations, three unknowns; the third dimension is the `n_ib` choice. Net effect: every unit of NET sold via IB at rate `r_ib` replaces a unit that would have been sold via pool, but at a different rate. The optimal `n_ib` is monotone in `(r_ib − r_pool_µ)`: IB is used iff `r_ib > r_pool_µ` evaluated at the relevant boundary. Capacity bounds `n_ib ≤ n_ib_max`. The proportional deposit constraint then determines `n_pool` and `n_used`.

**Toy take-away.** Both objectives admit an IB-then-pool monotone split when `r_ib > r_pool_µ(0)`; otherwise the IB leg is dormant. Below-NAV regimes (`r_pool_µ < r_ib ≈ 0.985·backing`) are exactly when the IB leg pays.

## 2. Executable integer algorithm and proof gaps

**Continuous→integer translation.** Three rounding seams:

1. **IB outbound (NET→USDG).** `payoutWad = n_ib·P/1e9` floored; `usdgOutRaw = payoutWad / 10^(18−usdgDecimals)` floored (truncates residual `< USDG_RAW_UNIT`). For USDG-6 (per `ROBINHOOD_MAIN.sol` comment, unverified live `decimals()`): each NET unit can lose up to `(10^12 − 1)` raw-USDG dust. Ownership of this dust is **unspecified** — IB does not credit it back, does not forward it. **Open product decision:** attribute the dust to (a) the SE vault (round-up of vault revenue), (b) the caller via a residual `mintTo(receiver, dust)` route, or (c) leave it stuck. (a) is consistent with the gauge-cumulative-style fee accrual in the hook; (c) is silent revenue; (b) requires an ABI that does not exist.
2. **Pool swap.** Existing `UniswapV2StandardExchangeQuoteTarget._quoteDeposit`/`_quoteWithdraw` already model the 30-bps fee and `_quoteMintPoolFee` for the protocol-fee LP minting (`UniswapV2StandardExchangeQuoteTarget.sol:212–223,225–270`). Reuse the helpers; do not re-derive.
3. **Proportional deposit.** `lpOut = min(n_used·S/x', u_received·S/y')` floored for share token mint (`S` = LP supply). Conservation requires `lpOut` from both legs match; otherwise the smaller binds. **Open proof gap:** under IB-and-pool split, with two distinct USDG-source rounding seams, the equality `lpOut_n = lpOut_u` does not generally hold at integer precision; the conservative move is to mint the **smaller** and credit residual NET/USDG back to the caller (or to the vault's held reserve). The reference SE does not currently expose a residual-credit path on single-sided zaps.

**Two-call vs one-call.** The bounded initial release should call IB **at most once per user operation** (`_checkActive = false` in Round 1 sense). Repeated calls within the same operation raise `P` and lower `c_rem` between calls; previews that assume static `P, c_rem` become stale. The state-snapshot entry must be enforced in the operation's accounting layer (`PositionSnapshot`/`FundingReceipt` analog from Plan §5.3:197–200) and the second call must re-read `P, c_rem` and re-validate, not reuse the snapshot.

**Capacity exhaustion between preview and execution.** Preview returns `Q_pool` as guaranteed minimum (per Round 1 Kimi/Grok consensus). Execution attempts IB at snapshot-bound `n_ib`; on `ExceedsCapacity` (`:78–80`), revert to pool-only within the same tx. **No retry solver, no partial-second-call, no cross-block queuing.** This is consistent with PRD R11 ("insufficient funding/delivery reverts atomically; no silent Universal fallback").

**Tax predicate per hop.** Re-derived from `NET.sol:131–145`: predicate is `taxEnabled && !isTaxExempt[from] && !isTaxExempt[to] && (isTaxedPair[from] || isTaxedPair[to])`. For each hop in the bounded design:

| Hop | Taxed? | Notes |
|---|---|---|
| user → SE | No | SE is not a taxed pair; user is not a pair |
| SE → IB | No | IB is not a taxed pair and not pair-mappable (`NET.sol:188–219`) |
| SE → pair (pool swap) | Yes unless SE exempt | pair is taxed pair; pair never exempt (`NET.sol:231`); 5% if SE not exempt |
| SE → pair (proportional deposit NET leg) | Yes unless SE exempt | same predicate as pool swap |
| IB → user (treasury payout) | No | `treasury.spendUsdg` is plain ERC-20 transfer (`Treasury.sol:135–147`) |

If the SE is **not** a `isTaxExempt` member, two `SE → pair` hops are taxed. IB-routing avoids 5% + 0.3% on the IB-leg amount. If the SE is exempt, IB-routing still avoids 0.3% on the IB-leg. The PRD §4.2:286 ("exemption-aware branch") requires both branches modeled; bounded release must reflect the live `isTaxExempt(SE)` read at operation entry.

**Guard mapping changes.** Plan §5.3:199 `ExecutionLimits` — "No arbitrary external target or arbitrary calldata forwarding." The bounded release uses a typed `InverseBondAdapter` library, not a generic `target.call(data)`. The IB address is a `PkgInit` immutable, validated against `inverseBond.net() == NET` and `inverseBond.treasury() == NETNET_TREASURY` at deploy (per PRD R33 / §4.1:268–275 binding precedent for the canonical pair).

## 3. Operation order (rounded)

1. **Authenticate** caller/operator, route, deadline, pretransfer mode, `RouteLimits`. Reject zero `n` or `minLPOut > type(uint256).max`.
2. **Snapshot** `P, c_WAD, x, y, S_pool, taxEnabled, isTaxExempt(SE), isTaxedPair(pair)`. Read once; do not cache across reentrancy.
3. **Authorize NET receipt** via pretransfer (existing `LocalCreditLib.available`) or `transferFrom`. Measure delta; do not credit pre-existing surplus.
4. **Compute split.** Decide `n_ib_max_eff = min(floor(c_WAD · 1e9 / P), n)` and `r_ib_eff = floor(n_ib · P / 1e9) / n_ib` (WAD per NET, per-unit). If `r_ib_eff > r_pool_µ(0)`, set `n_ib = n_ib_max_eff`, else `n_ib = 0`. For zap-in, then solve the proportional constraint for `n_pool, n_used` with `n_used = n − n_ib − n_pool`.
5. **Pre-transfer checks** on IB: `genesisBond.finalizeTime() != 0` (post-genesis), `oracle.twapNetUsdg()` in-band (Plan §6.5.4 / `InverseBond.sol:73`), live `isTaxExempt(SE)` reading matches assumption, `payoutWad ≤ c_WAD` (re-read at execution), user `minLPOut` (or `minUsdgOut`) compatible with pool-floor quote.
6. **Execute IB first** (`approve(IB, n_ib); swap(n_ib, minOut=0)` for first leg; capture `usdgOutRaw` return).
7. **Fallback gate.** If IB `swap` reverts with `ExceedsCapacity`/`NotActive`/oracle revert/tax mismatch, **revert the whole operation** to pre-step 3 (no half-baked state). This is **stricter** than Kimi's same-tx pool fallback — chosen because (a) PRD R11 atomicity, (b) `SE → IB` is one of two `SE → pair`-class hops and unwinding pool-side accounting after IB already moved treasury reserves is non-trivial. **Open product decision** whether to permit pool fallback vs revert; PRD/owner must specify.
8. **Execute pool-side.** Sell `n_pool` via canonical pool (V2 router or pair-direct per SE design) for `u_pool` USDG. Realize the pool's `_quoteMintPoolFee` (`:212–223`) and apply protocol-fee LP minting to the projected reserves.
9. **Proportional deposit.** Compute `lpOut = min(floor(n_used · S_pool / x_new), floor(u_received · S_pool / y_new))`. Mint `lpOut` to the receiver. Credit residual NET/USDG (`Pair` view) to the receiver (or to vault's tracked `_bookedReserve`).
10. **Refunds.** Authorized pretransfer refund from this operation's credit. `LocalCreditLib.available` snapshot before, refund first, then full expected-set synchronization (`BasicVaultRepo._syncAllExpectedHoldReserves`, Plan §6.3:435–441).
11. **Events.** `SwapRouted(route, n_ib, n_pool, n_used, u_pool, usdgOutRaw, lpOut)`. No quote-only positions reported as minted (Plan §6.1).
12. **Atomicity.** Any required failure (tax, capacity, oracle, route, refund, mint, fee, sync) reverts entire sequence. Failed IB→fallback revert choice is documented per step 7.

## 4. Gross/net deposit ratio

Per pool: `x'/y'` post-trade equals `(x + n_pool) / (y − u_pool)` with V2 fee math. With IB leg adding `u_ib` outside pool reserves:

```text
lpOut = min(floor(n_used · S_pool / (x + n_pool)), floor((u_ib + u_pool) · S_pool / (y − u_pool)))
```

Conservation requires both to match; if they don't, the smaller binds (NET or USDG leg is the binding undersized). Residual NET/USDG is real and must be credited per step 9 above. The bounded design does **not** silently consume residual as fee.

## 5. Marginal vs average-price allocation

`r_pool_µ(s)` is the **marginal** USDG-per-NET at pool size `s` (decreasing in `s`). `r_pool_avg(s) = u_pool(s)/s` (average across the trade). For an exact-output USDG target `U`, the optimal split solves `u_pool(n_pool) + u_ib(n_ib) = U` with `n_ib ≤ n_ib_max` and minimize `n_pool + n_ib`. Because `r_ib` is constant and `r_pool_µ` is decreasing, the optimum concentrates as much as possible in IB until `r_pool_µ(s_at_boundary) = r_ib` (continuous); the remainder fills pool. For an integer solution, project the continuous optimum and round, then forward-replay and check.

## 6. Fees, tax, protocol fee

- **IB fee:** spread only (`1 − 0.015 = 0.985` of backing); no per-call fee. Net USDG-out is `floor(...)/10^(18−usdgDecimals)` truncated.
- **Pool fee:** 30-bps on input (`997/1000`). Modeled in existing `_quoteDeposit`/`_quoteWithdraw`/`_quoteMintPoolFee`.
- **Protocol fee LP minting:** `_quoteMintPoolFee` mints fee LP to `_quoteFeeTo()` if `feeTo() != address(0)`. The SE already accounts for this in `_quoteAssets` (`:192–205`). The bounded zap must mirror the same protocol-fee minting in its projected state so post-deposit `S_pool` includes the projected fee mint.
- **Tax:** per §2 table. SE→pair taxed 5% per hop unless SE exempt. The bounded design must replay tax per hop and verify exemption read at operation entry; no cache.

## 7. State projection & exact-output implications

- **Preview** returns pool-quoted values; IB figure is **upper bound**, not guaranteed. `preview*` is read-only and never writes. The PRD/IStandardExchangeTransitionQuote (`IStandardExchangeTransitionQuote.sol:5–39`) extension must mirror: previews captured here by `quoteState`/`quoteTransition`/`quoteExternalDeposit`/`quoteExternalExchange` remain canonical-pool-only; the bounded IB leg is an execution-only branch with `Q_pool` as the floor.
- **Exact-output USDG variant:** required inverse `RATE = IB` is `n_ib = ceil(usdgOutWad · 1e9 / P)` (minimum-sufficient integer inverse per Plan §6.5.3:481–484). Replay forward, validate against capacity, then add pool side for the residual target. Owner decision: deferred (Round 1).
- **Exact-output LP variant:** derive total NET input for a target LP via Newton's method or fixed-point iteration on the proportional constraint; not closed-form. **Open engineering decision**: implement iterative solver or expose only exact-input LP. PRD R11 atomicity precludes multi-tx search.

## 8. Depletion/fallback with original user limits

- User `minUsdgOut` (USDG-out routes): pool floor quote is the guaranteed minimum; IB improves strictly only. If IB fails, fall back per step 7 choice.
- User `minLPOut` (zap-in): pool-only zap LP is the guaranteed minimum. If IB fails, fallback to pool-only zap may undershoot but never below pool-only.
- `decodeTime` deadline applies per existing pattern.
- `maxTokenIn` (NET cap) bounds `n`. `maxHlpIn` (if reverse direction) bounds redemption separately.

## 9. Buyback-first vs pool-first — treasury NAV/cap effects

- IB-first then pool consumes IB capacity first; treasury's NET supply drops by `n_ib`, USDG liquid drops by `usdgOutRaw`, `backingPerToken` rises slightly, `c_rem` for current epoch drops to zero. Subsequent operations in the same epoch see `c_rem = 0` and skip IB.
- Pool-first then IB leaves `c_rem` partially full; in a multi-block design, a follow-up operation can still hit the bid.
- **Bounded release choice:** **per-operation** IB-then-pool (Round 1 opinion). Multi-block session-level sequencing is **deferred** to a future PRD revision if observed behavior motivates it. State-snapshot at operation entry enforces per-operation isolation.

## 10. Repeated buyback calls and NAV price feedback

- Each `swap` burns NET (supply lower) and pays USDG out of treasury (liquid lower, possibly Morpho unwound).
- `backingPerToken = rfv / totalSupply` rises (RFV rises via raw per-pol from unaffected k; supply falls; net effect positive — NetNet docs §3 confirms accretive).
- IB price for next call: `P' = backing' × 0.985`, slightly higher than `P`.
- `c_rem` for current epoch drops by `payoutWad` of the previous call.
- **Bounded release:** operation-scoped, single IB call. No stateful chain of IB calls within one operation (Round 1 line). Multi-call session design is deferred.

## 11. Taxed NET deposit leg

- User → SE NET hop: untaxed (SE not a taxed pair).
- SE → IB NET hop: untaxed (IB not a taxed pair, IB not pair-mappable).
- SE → pair NET hop (swap + proportional deposit): taxed 5% unless SE exempt.
- Bounded release reads `isTaxExempt(SE)` at operation entry; replays tax per hop. Pre-check live predicate before IB call; if SE not exempt, document the 5%×2 tax drag in previews.

## 12. Custom zap vs DETF NET Keep-YT vs USDG SE input

- DETF NET/sNET input: Keep-YT (Pendle PLP+YT) — PRD §6.1:413, R03. Not the SE.
- DETF USDG input: SE — PRD §6.1:411.
- HLP USDG-leg deposit/withdraw: direct SE-share transfer — PRD §4.4:324–325.
- HLP NET-leg deposit/withdraw: Keep-YT only — PRD R03.
- The custom NET-funded zap proposed here is a **SE-level single-sided LP-deposit operation**, not a DETF NET-input route. It can serve:
  - External NET→LP users (if the SE exposes the route — currently not in PRD §5).
  - Hook HLP operations that need to sell NET for USDG during redemptions (future).
- The custom zap does **not** replace Keep-YT for DETF NET inputs. The two serve different roles and the PRD distinguishes them.

## 13. Reuse and primary sources

**Reuse (existing files, no new code):**
- `UniswapV2StandardExchangeQuoteTarget.sol:31–272` — `quoteState`, `quoteTransition`, `quoteExternalDeposit`, `quoteExternalExchange`, `_quoteDeposit`, `_quoteWithdraw`, `_quoteMintPoolFee`, `_quoteAssets`. Reuse helpers; do not re-derive V2 fee math.
- `UniswapV2StandardExchangeInTarget.sol` / `OutTarget.sol` — exact-in/out swap path; adapt IB-aware branch in the same dispatcher frame.
- `UniswapV2StandardExchangeCommon.sol:1–120` — `LocalCreditLib`, `ConstProdReserveVaultRepo`, `Permit2AwareRepo`, `BasicVaultCommon`. Reuse `_unbookedSurplus`, `_requireNotDisabled`, `_loadIndexSourceReserves`, `_loadStrategyVault`.
- `BasicVaultRepo`, `BasicVaultCommon` (Plan §6.3) — public pretransfer `available(B,R)` and full-set sync.
- `LocalCreditLib.sol:13–20` — `available = max(B−R, 0)`.
- Plan §6.5.4 — tax predicate and gross/net inverse `floor((y−1)·B/(B−t))+1` for input-given-output; forward replay through `g − floor(g·t/D)`.

**Primary sources (Oct 1, 2026 access):**
- `lib/crane/contracts/protocols/pol/net/src/InverseBond.sol:25–141` (verified).
- `lib/crane/contracts/protocols/pol/net/src/interfaces/IInverseBond.sol:16–37`.
- `lib/crane/contracts/protocols/pol/net/src/Treasury.sol:84–147`.
- `lib/crane/contracts/protocols/pol/net/src/Constants.sol:17,42,64,67`.
- `lib/crane/contracts/protocols/pol/net/src/NET.sol:131–145,188–219,231`.
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:459,467,470` (USDG decimals comment unverified live).
- V2 core: Context7 `/uniswap/v2-core` accessed 2026-10-01 (fee formula confirmed).
- Docs: `docs.netnet.capital/treasury`, `docs.netnet.capital/mechanism`, `docs.netnet.capital/FEES.HTM` (referenced; per Round 1, blockscout/Sourcify returned 403/404 for fresh verification on 2026-10-01).

## 14. Product vs engineering choices (open)

- **Revert vs pool-fallback on IB revert:** Round 2 atomic revert (stricter). PRD/owner must specify; PRD R11 atomicity language is currently ambiguous for SE venue routing. **Engineering impact:** revert is simpler; pool-fallback better UX but requires partial rollback handling for IB-side movements. Defer.
- **USDG dust from `usdgOutRaw` truncation:** attribute to vault, caller, or stuck. **Engineering impact:** new `DeclareInversion*` residual accounting or hook minor callback. Defer to Round 1 path.
- **Exact-output USDG variant:** closed-form inversion available; deferred per Round 1.
- **Exact-output LP variant:** iterative solver vs exact-input only. **Engineering impact:** iterative solver adds complexity; exact-input only is conservative. Defer.
- **Multi-block session sequencing of IB calls:** out of scope for bounded release; per-operation isolation enforced.
- **IB address binding validation:** package validates `inverseBond.net() == NET`, `inverseBond.treasury() == NETNET_TREASURY`. **Engineering impact:** two storage reads at deploy; no runtime cost. Adopt.
- **Tax-hop replay at operation entry:** read `isTaxExempt(SE)` once per operation; no cache. Adopt.
- **Custom NET→LP SE seal single-sided deposit route:** out of current PRD §5 user-facing routes; the bounded design is **engineering reference** with no execution authorization. Defer to PRD revision.

## 16. Confidence

- **High:** toy continuous model, monotone IB-then-pool split, IB directionlessness invariant, IB orphan-cadence invariant, tax-hop table, gross/net inverse per Plan §6.5.4.
- **High:** operation order, gross/net deposit ratio formula, fees/tax accounting.
- **Medium:** integer algorithm for the bounded two-leg split; conservation proof (lpOut equality) under two USDG-source rounding seams requires additional analysis — **open proof gap**.
- **Medium:** USDG `decimals()` (constant-pinned but not live-rounded this round).
- **Low:** deployed-code equivalence for InverseBond/Treasury/PairOracle (G1 pending per Plan §2.1).
- **Low:** live `isTaxExempt(SE)` membership (SE not yet deployed; PRD §4.1:270 mentions "may eventually be configured for an exemption" but does not promise).

## 17. Saved path

Written to `docs/research/netnet-buyback-discussion-2026-10-01/round2/minimax-original.md`. No other writes. No shell, no tests, no config, no implementation, no peer or prior-report artifacts read this round. Frozen for cross-review.
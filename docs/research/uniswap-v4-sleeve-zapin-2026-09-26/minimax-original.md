# MiniMax-M3 — Independent first pass: Uniswap V4 Standard Exchange vault zap-in proportional seat + policy sleeve

**Author:** minimax/MiniMax-M3 (independent)
**Date:** 2026-09-26
**Path under review:** `contracts/protocols/dexes/uniswap/v4/`
**PRD scopes referenced (current law):**
- `DETF_ALIGNMENT_PRD.md` (D32–D66 / §24; D57–D59 explicitly named in current release authority)
- `DETF_INSTANCE_IO_ROUTING_PRD.md` §16 (Uni V4 v1, R1–R20)
- `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` v1.6 (D1–D31)
- `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` v1.2 (D30–D52)
- Vault bring-up: `UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md`
**User request framing:** add a zap-in swap that turns a single pool token into a proportional two-token join and deploys that, while retaining the policy liquid sleeve so PoolManager-blocked operations still work.

---

## 0. Save notice

Saved to: `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-original.md` (apply_patch tool unavailable; `write` used as the only net-write tool exposed; preserved here for cross-review).

---

## 1. Single-sentence root cause (MiniMax-M3, original)

**Repeated single-token deposits stay in the sleeve because the inbound amount is a single pool currency; at full-range (D30) any L minted from one token only is `LiquidityAmounts.getLiquidityForAmounts(spot, fullLower, fullUpper, excess0, excess1) == 0` whenever `excess1 == 0`. D27 / D32 already acknowledge this (`In-range L may be 0 until the vault also holds the other pool currency`); D28 forbids the historical workaround (token0↔token1 rebalance swap); the policy liquid sleeve therefore grows above the target until the matching token is also deposited, the vault is **already at** 100% sleeve / 0 deployed, and only the **`exchangeInManyToOne` Multi join** (PoolKey order, both pool currencies) actually seeds in-range L — *no first-user-zap path today*.

The “zap-in swap into proportional distribution” the human is asking for is the **implementation of D27 sleeve-then-deploy-excess for the single-token case via an owner-routed owner swap within the same `unlock`, completing L deployment in one call** — which today the codebase only does for native-V4 dual inputs (`exchangeInManyToOne`), or for the historical center+wings book (now deleted, D36). D32 / D47 / D28 explicitly say **no swap as a rebalance tool**, and D28 explicitly bans `rebalanceLiquidReserve` swaps. The user’s proposal therefore needs a new, narrow, *user-facing* zap-in path that:
- (a) honors D9 (DETF-only mint path / DETF reserve is V4 hook — DETF does **not** use SE Standard Exchange as the joint seat) — i.e., this is **about SE deposits into a pool reserve that uses a SE Standard Exchange as one leg**, not about the DETF itself;
- (b) is a **one-shot deposit-time zap** — not a rebalance swap — so it does not collide with D28;
- (c) keeps D20 sleeve policy enforceable inside the same `unlock` (sleeve stays the buffer for subsequent ops).

This report closes the gap by **explicitly identifying the supersession needed in DETF alignment + Uni V4 SE PRDs** before defining the new product surface.

---

## 2. Code-grounded facts (paths, lines, observed behavior)

### 2.1 Single-token mint behavior (current code, not product PR)

`UniswapV4StandardExchangeInBase.sol:273-315` → `_executeZapInDeposit(tokenIn, amountIn, minSharesOut, recipient)`:
- Pulls a single token; `_sharesOutForDeposit(amount0Added, amount1Added, …)` (`Common.sol:685-713`) returns `mulDiv(amount, supply, reserve)` for the *single-token* branch when `totalSharesBefore != 0`. Shares **mint** against total vault reserves (free + deployed) — *correct economically*.
- Then `_rebalanceLiquidReserveBestEffort()` is called when `canOpenPoolManagerUnlock() == true` (`InBase.sol:309`).
- `_rebalanceLiquidReserveInternal` (`Common.sol:764-811`) → `_deployExcessLiquidity(excess0, excess1)` (`Common.sol:822-859`). `centerLiquidity = LiquidityAmounts.getLiquidityForAmounts(spot, lower, upper, excess0, excess1)` (`Common.sol:564-570`). If the inbound token is `token0` then `excess1 == 0` ⇒ full-range center L **== 0** (commented at `Common.sol:763-769` and PRD D32 at `FULL_RANGE_PRD` lines 142–144).
- Outcome: rebalance is **a no-op** for first/only-token deposits when the other token already exists but the deposit hit only one side beyond the deadband. Idle single-token deposit **does mint shares** but **leaves the excess sleeve at >100%** until the counter token arrives.

Preview parity: `_previewZapInDeposit` (`InBase.sol:256-266`) mirrors the same total-reserve math; preview == exec user sharesOut (D24). Confirmed.

### 2.2 Dual join is the only working seed

`UniswapV4StandardExchangeInMultiTarget.sol:11-30` (`exchangeInManyToOne`) is the only deposit path that *actually* seeds L in-range on first call: `_executeZapInDualDeposit(actual0, actual1, …)` (`InBase.sol:338-377`) shares the same mint path; the deployed excess is dual by construction, so center L > 0. PRD D41 locks length == 2, **PoolKey order** (not ascending), WETH for native ETH, `tokenOut == address(this)` mandatory.

`UniswapV4StandardExchangeInQueryTarget.sol:107-119` (`_inventoryDeposit`) does **not** handle the dual-amount case for the single-token preview; the QueryTarget dual preview is the **InMulti preview** (separate contract).

### 2.3 Rebalance composition (D28)

`_rebalanceLiquidReserveInternal` never calls `_executeSwap` or `swapExactIn` / `manager.swap`. D28 is honored. The proposed user-facing zap-in swap would have to live **outside** `_rebalanceLiquidReserveInternal` (deposit path only), or it becomes the **forbidden rebalance swap**.

### 2.4 Gate and lock semantics (confirmed)

`canOpenPoolManagerUnlock() = !TransientStateLibrary.isUnlocked(_poolManager())` (`Common.sol:315-317`). Local buffer PRD §0.4-§0.5 distinction:
- **PM idle** (`isUnlocked == false`) — interaction-free. Vault **may** open a new `poolManager.unlock`.
- **PM in-session** (`isUnlocked == true`) — interaction-blocked. Nested unlock forbidden. The sleeve is the lock-safe deposit / cover-or-revert path (PRD D2/D4/D18).

`_executeUnlock` (`Common.sol:676-680`) gates every unlock. Any PM work MUST be inside `unlockCallback`. The se buffer + pool manager integration is the **singleton lock**, so all “nested batch” use cases (hook deposit, inter-vault swap) MUST succeed via the sleeve when blocked.

### 2.5 DETF instance and the SE Standard Exchange leg

`UniswapV4DetfTarget.sol:198-229` (`_entryExchangeIn`) → `_mintPath` (line 259) calls a **single** pair vault (`_hookPairOfVault(v_)`) and at line 287-295 already handles `if (address(tokenIn_) == pair_) { forceApprove hook; joinSingleAssetExactIn } else { toShare + joinShare }`. **No zap-in swap**; the user pays the same pair that the SE Buffer Hook expects, or pays the share.
- This is the **DETF side** of the user’s question: users depositing their *single* vault share or *single* pair into the DETF for a mint can already do so — that path works (single token, full-reserves mint, share-mode seat). The user’s “single token” pain is on the **SE Standard Exchange** side, not the DETF mint side.
- The DETF `_swapMintPath` (`UniswapV4DetfTarget.sol:308-323`) already implements the **price-gate fallback** that swaps the inbound token through the SE Standard Exchange vault to the pair, but it **does not** deploy any L (no `joinSingleAssetExactIn` / no `joinShare`); it only swaps existing held pair tokens for DETF via `ownerSwapExactIn`. Consistent with DETF alignment D39.

### 2.6 Confirmed token policy

`DETF_ALIGNMENT_PRD.md` §24.1 token policy: FoT forbidden; rebasing-underlyings forbidden (rebasing claim token is a separate protocol product); non-18 decimals allowed; **no `PkgArgs` allowlist**; native ETH is **WETH** on the vault face (`Common.sol:411-417`); positions on native ETH not in scope (D26) — vault face is WETH. The zap-in proposal must respect this.

### 2.7 Fee oracle `liquidReservePercentage`

`Common.sol:343-347` reads live; `liquidReservePercentage` already exists for SE; **no new field needed**. Confirmed.

---

## 3. PRD alignment vs user request (proposed vs current law)

| Concern | Current law | User’s request | Conflict? | Resolution required |
|---|---|---|---|---|
| Sleeve target / size | D27 sleeve-then-deploy; D7 20% type default | Keep sleeve for blocked paths | None | None — keep policy |
| Single-token deploy | D32 binding token consumed; leftover **stays free**; no swap | Add zap-in swap so leftover is removed | **Conflict** | Open new path *outside* D28 — “deposit-time zap, not rebalance swap” |
| Rebalance swaps | D28 forbidden | Deposit is one-shot and user-initiated | OK if path-bounded | New clarifier clause: **deposit-time zap is a separate operation from rebalance**; counts as part of the deposit user op (mirrors §6.2 deposit shape). |
| Dual join | D41 exists (`exchangeInManyToOne`) | User wants single-token entry | None | Reuse dual-join surface; the user pays token0 only and the vault converts the **residual deposit** to token1 within the same `unlock` |
| Blocked / in-session | D2 sleeve only; no nested unlock | Sleeve unchanged | None | **Sleeve must absorb the *failed* zap** when PM is blocked (D-style: revert the swap portion, keep the sleeve credit for the inbound token — see §6 below) |
| Token policy | WAD; no FoT / rebasing | Same | None | Same |
| Native ETH / WETH | D26 native out of scope; WETH face used | Same | None | Same |
| First mint / empty | D27 first deposit is sleeve mint; rebalance may create position | If token0-only deposit on empty vault, share math is mulDiv → 0 (D8 not satisfied) — **whole zap must revert as `InvalidRoute`** | Acceptable | **First mint with only one of two tokens must remain 0 shares**; zap-in must require *both* tokens, swap a partial of inbound to counter, then call dual join. |
| Slippage / minimum | existing `minSharesOut` | Add a new `minCounterOut` on the swap portion | OK | New parameter to `exchangeIn` zap-in variant |
| Test gates | T1/T1b/T9/T10/T11/T11b/T15/T16 matrix | Add zap-in cases | OK if plan adjusts | New slot in §8 matrix |

**Conclusion:** the human’s request requires (a) a **PRD revision** to DETF alignment D27 / alignment-prd §24 to acknowledge the **deposit-time single-token zap as a distinct op from rebalance**, (b) a **Uni V4 SE PRD revision** to add a new facet surface, (c) **supersede** no currently scheduled decision (D57/D58/D59 stay); (d) **no conflict with D66** (Slipstream deferred).

---

## 4. Recommended product surface (proposed D60a / SE D60 — research-only)

### 4.1 New facet surface on the SE vault

Add a new **multi-asset single-side join** facet (do not collide with `exchangeInManyToOne` which already exists as the dual join):

```
interface IUniswapV4StandardExchangeBufferSeZapIn {
    function zapInSwapAndJoin(
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minCounterOut,    // slippage on the swap leg
        uint256 minSharesOut,     // slippage on the share-mint leg
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut);
}
```

Semantics:
1. **Open the SE Standard Exchange’s own unlock** in the same call. Vault owner of the bound pool (`_addLiquidity`, `_swapExactIn`).
2. Pull `amountIn` of `tokenIn` onto the diamond.
3. If `tokenIn == pool.token0` or `pool.token1`: **swap an internal amount to the counter side** using `_swapExactIn` (owner swap). `amountToCounter = quoteSwapIn(amountSwapped) ≥ minCounterOut`.
4. Combine (remaining `tokenIn` for its own side) + (counter from the swap).
5. Compute L via `LiquidityAmounts.getLiquidityForAmounts(spot, lower, upper, sideAmounts)`; **must be > 0** for the call to make sense — require symmetric amounts ≥ minimum per token (R29 suggested).
6. `_addLiquidity(centerLower, centerUpper, L)` via `Operation.AddLiquidity`.
7. **Mint shares** against post-pull totals (`_sharesOutForDeposit`) using the dual-amount path (D27 sleeve-then-deploy-excess applies to the remaining sleeve above the target). The zap *is* a deposit on a dual-asset basis even if the user paid one token.
8. Best-effort `_rebalanceLiquidReserveBestEffort()` after mint if idle.

### 4.2 What must change in the source

| File | Change |
|---|---|
| `UniswapV4StandardExchangeInBase.sol` | Add `_executeZapInSwapAndJoin`; branch early on `address(tokenIn) == _token0()` or `_token1()`. Use `_executeDirectSwapIn` for the counter side, then `_executeZapInDualDeposit` for the seat, then rebalance. **No `unlock` from inside** — the swap is via direct PoolManager swap in executeUnlock path. |
| `UniswapV4StandardExchangeInTarget.sol` | Reject the new selector when blocked (see §4.4). |
| `UniswapV4StandardExchangeInMultiFacet.sol` (or new) | Diamond cut. Keep existing selectors. Add `zapInSwapAndJoin` selectors with the existing preview/exec split. |
| `UniswapV4StandardExchangeDFPkg.sol` | Add facet to `facetCuts` array (DFPkg cuts stay mutable per CLI guidance). No new interfaces; existing `IStandardExchangeIn` surface extended. |
| `UniswapV4StandardExchangeCommon.sol` | Add `_zapMinSideFloor(token)` helper (anti-zero-L guard). Reuse existing `_executeUnlock` reentrancy guard. |

### 4.3 Economics

| Outcome | User | Sleeve | Pool |
|---|---|---|---|
| Single-token zap-in | Pays 1 token; receives vault shares | Receives counter side dust only | Full-range L minted, in-range; earns fees |
| Preview == exec user path | Yes (D24) | n/a | n/a |
| Blocked PM | Zap reverts `PoolManagerInteractionBlocked` | Sleeve already credited to inbound token only → keep sleeve-mint path on blocked; do not slip | n/a (existing `exchangeIn` blocked deposit already sleeve mints) |
| Rebalance after | Idle best-effort rebalance to ~20% per token | sleeve sits at within-deadband target | L deployed |
| Counter swap price | Pulled from `_swapExactIn` quote + `minCounterOut` slippage | n/a | Earns fee |
| Repeat user zap with one token | Same | Net sleeve steady state | Cumulative L growth |

Pricing consistency: both preview and exec must call the same quote service (`UniswapV4QuoteService._quoteDirectExactInput` / `_quoteDirectExactOutput` — `Common.sol:1137-1151`).

### 4.4 Gate and previews

- `canOpenPoolManagerUnlock() == false` ⇒ the new facet **reverts `PoolManagerInteractionBlocked`**. The user must use the existing **single-token sleeve mint** (`_executeZapInDeposit`) which already keeps their input in the sleeve. PRD D2 already approved the lock-safe sleeve credit.
- Preview parity uses the existing `_inventorySwap` + `_inventoryRedeem` chain (`InQueryTarget.sol:107-162`) extended with a one-shot "swap then dual deposit" simulation under `q.idle == true`. **Under `q.idle == false`** preview returns 0 (caller expected to fall back to sleeve).
- Security: `nonReentrant` on the new facet; reuse existing `ReentrancyLockModifiers`. Do **not** reuse the in-flight `_executeDirectSwapIn` path when blocked — that path always PMs.

### 4.5 Share-math (preview == exec)

- Post-pull totals on the diamond include both the inbound `tokenIn` and the converted counter.
- `_sharesOutForDeposit(amount0Added, amount1Added, supplyBefore, reserve0Before, reserve1Before)` operates on the total reserves (free + deployed, D9/D29). Therefore the user’s portion is **dual-min share quote** (`mulDiv` of each side), which is **strictly less** than the single-side quote on the same amount — honest against the book.
- After the user op, tail-rebalance moves any **remaining** sleeve excess to fill the 20% target. The deposit lands user-end in-range L.

### 4.6 First-mint / empty vault

The dual-min branch returns `mulSqrt(amount0, amount1)` only if both amounts are non-zero. The zap satisfies this by construction. First mint with one inbound token **does not** mint (existing behavior, D8 / §6.7 of buffer PRD). This is correct: **the pool is empty; the user can only mint by simultaneously funding both legs**, which the proposed zap-in does by swapping inside the same `unlock`.

### 4.7 What stays locked

| Locked | Reason |
|---|---|
| D28 rebalance swap remains forbidden | The new zap is **deposit-time**, user-initiated, one-shot. Distinct. |
| D44 / D52 proportional-only exit | Out Multi still proportional. Off-topic. |
| D9 DETF-only reserve policy | Not relevant here; SE Standard Exchange is the pool’s leg. |
| D29 free SoT = balanceOf | Reused. Zap pulls tokens first, then operates. |
| D27 sleeve-then-deploy-excess | Preserved. Zap goes *through* the dual-join shape that already does this. |

---

## 5. Acceptance criteria (proposed DoD for the separate implementation plan)

1. **PMC-1** New facet and surface deployed via the package DFPkg (no `new`); existing v1.2 PRD cuts preserved.
2. **PMC-2** Single-token zap-in on idle vault: user pays token0 only; pool receives both tokens in one `unlockCallback`; L > 0 in center; vault shares > 0; share-count delta == preview’s.
3. **PMC-3** Blocked zap-in reverts `PoolManagerInteractionBlocked` with a clear error and does not nested-unlock; existing single-token sleeve mint remains available.
4. **PMC-4** Slippage: `minCounterOut` respected; `minSharesOut` respected.
5. **PMC-5** First-mint empty-vault single-token zap produces valid shares; existing two-token flow unchanged.
6. **PMC-6** Rebalance after the zap is best-effort; idle vault ends within deadband per D22.
7. **PMC-7** The new facet remains compatible with `IStandardExchangeIn` (extends) — no duplicate selectors, no override of `exchangeIn`, `exchangeInManyToOne`, `exchangeOut`, `exchangeOutOneToMany`.
8. **PMC-8** Preview == exec user path under same gate snapshot (D24).
9. **PMC-9** Adheres to fee oracle liquidReservePercentage + WAD; no fee field is added.
10. **PMC-10** Production-first test matrix extending PRD Local Liquid Buffer T1-T16:
    - T1.EXT: Single-token idle zap-in: shares > 0; L > 0; sleeve within deadband after.
    - T2.EXT: Blocked single-token zap reverts `PoolManagerInteractionBlocked`.
    - T3.EXT: First mint empty-vault single-token zap creates both-token LP position.
    - T8.EXT: Preview == exec user amounts for the new zap.
    - T28.EXT: Rebalance is **not** triggered by the zap itself (deposit-time distinct from rebalance — verified by counter-example that the same code path with the *rebalance* entry returns 0 swap calls).

---

## 6. Unresolved decisions (must close before coding)

| ID | Decision needed | Default I would recommend |
|---|---|---|
| **R-D60a.1** | Where does the swap-leg fee go? Currently `_executeDirectSwapIn` charges Uni V4 LP fee to the swap; this is accepted as the user’s trade cost. | Keep — no extra fee. |
| **R-D60a.2** | Min counter token. New constant in `_absoluteFloor` or separate floor in the facet. | Reuse `_absoluteFloor(_token1())` as the lower bound. |
| **R-D60a.3** | Does the proposal interact with the Fee Oracle `liquidReservePercentage`? | Yes — live reads (D20). |
| **R-D60a.4** | When PM is blocked, do we still try a counter-token swap via “sleeve-side” route? | **No.** Sleeve-mint path on blocked; revert on zap. User path stays simple. |
| **R-D60a.5** | New selector naming / facet name | `IUniswapV4StandardExchangeBufferSeZapIn` (single-side swap + join). Mirror `Multi` style. |
| **R-D60a.6** | Min `tokenIn` amount for zap-in (avoid dust that makes L ≈ 0). | Reuse existing `mulSqrt` 0-threshold; revert `InvalidRoute` if resulting L == 0. |
| **R-D60a.7** | Donate / R12 / R12a interaction. Donate already routes via SE share or DETF; new zap is a separate deposit surface — not affected. | None. |
| **R-D60a.8** | What happens when PoolKey has only one currency (native-ETH face only — should not occur; defensive)? | Revert `InvalidRoute`. |
| **R-D60a.9** | Documentation alignment with §24.4 (bond purchase). | No bond impact. |
| **R-D60a.10** | Should the zap limit min counter share by oracle price band? | Yes — same `_syntheticOfPair`-style gate as DETF mint, but for *the pool*, not the DETF. Reuse existing `_inventorySwap` to compute input. |

---

## 7. PRD supersessions required (research-only; do **not** edit PRDs in this pass)

| Current PRD / Clause | Change needed | Reason |
|---|---|---|
| `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` D27 | Add a third bullet under D27: “A user-facing single-token **zap-in** that swaps an internal portion to the counter token inside a single `unlock` is a **deposit-time op**, distinct from rebalance. Subject to PRD §3 supersession acceptance.” | Distinguishes user swap from forbidden rebalance swap |
| `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` §6.2 | Add new sub-clause §6.2.1 “zap-in single-token join”: algorithm above; gate by `canOpenPoolManagerUnlock()`; non-conflict with D28 | Encodes the product surface |
| `UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` D47 | Add “Single-token first mint may still produce L == 0 unless followed by a **zapInSwapAndJoin** that supplies the counter token. Full-range D32 still in force.” | Reconciled |
| `DETF_ALIGNMENT_PRD.md` §24 (vague cross-ref) | None directly; DETF mint doesn’t use SE Standard Exchange as joint seat on the buffer path | No change needed for the proposal |
| `DETF_INSTANCE_IO_ROUTING_PRD.md` §16.5 / R5 | Re-affirm Custom close length = 1 unchanged; the new zap is **not** a close path | No change needed; align-doc footnote |

No code edits or peer files read in this pass; report is research-only. The supersession list above is **the open question for the human / owner**, not a recommendation to edit unilaterally.

---

## 8. Risks and adversarial considerations

| Risk | Severity | Mitigation |
|---|---|---|
| Zap swaps inside a blocked session via stored allowances | H | New selector calls `_executeDirectSwapIn` which calls `_requireCanOpenPoolManagerUnlock` first (`Common.sol:381-385`). |
| Dust counter leg → L == 0 → revert → user loses tokens on revert; investigate return semantics | M | Best-effort: refund inbound token if preconditions fail mid-flight via try/catch around the unlock. PRD D11 accepts best-effort; document explicit refund failure. |
| MEV sandwich on the swap leg | M | `minCounterOut` enforced on the swap; preview exposes the exact amount. |
| Reentrancy through the new facet | M | `nonReentrant` modifier inherited from `UniswapV4StandardExchangeInBase`. `unlockCallback` is single-flight under the singleton lock (Crane ships this). |
| Donation bleed (D29) | L | Reuse existing `balanceOf` SoT — no new accounting. |
| Position import path interaction | L | Imported path remains separate; block imported-position-only `zapInSwapAndJoin` if `_isImportedPosition()` returns true (revert `InvalidRoute` until PRD permits). |
| Imported position uses `PositionManager` not `PoolManager` (different reentrancy boundary). | L | Document; gate on `_isPositionCreated() && !_isImportedPosition()`. |
| Oracle percent set to 100% | L | Allowed; yields idle vault with no L; new zap still operates against pool. |
| WETH/native ETH dep | L | Reuse `_erc20Face`; new helper not needed. |

---

## 9. Confidence and gaps

### 9.1 Confidence
- **High** on the root-cause analysis (single-token deposit plus full-range D32 ⇒ L == 0 ⇒ sleeve-only). Code paths verified at the cited lines.
- **High** on D28 (no swap as rebalance tool) being the blocker for “zap-in swap” being folded into rebalance.
- **High** that `exchangeInManyToOne` (already implemented) is the only path that seeds L on first mint; the proposed zap-in wraps the same dual-join downstream.
- **Medium** on the “facet stays compatible with `IStandardExchangeIn`” claim (interface has fixed signatures; the new function can sit alongside without colliding).
- **Medium** on whether all rebalance helpers honor the “deposit-time zap is distinct from rebalance” separation under the same `_executeUnlock`. The cleanest implementation routes the swap via the existing `_executeDirectSwapIn` followed by `_executeZapInDualDeposit` — both already gated. Calling them sequentially from the same `external` function reuses the diamond cuts.

### 9.2 Gaps and missing evidence
- Did **not** read peer artifacts (Astra, Grok, Kimi K3) by instruction; cross-review pending later.
- Did **not** confirm there is an existing **test** matrix entry under T17+ for this case; the `UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md` matrix (T1–T16) does not include a single-token zap.
- Did **not** locate a Foundry test file specifically under `contracts/protocols/dexes/uniswap/v4/test/` (glob returned no files). Implementation plan §6.3 lists the path but the file may not exist yet; T1–T16 may live in another repo (Crane) or be forthcoming.
- Did **not** verify Uniswap V4 docs / Context7 (PoolManager singleton lock semantics, `unlockCallback`, transient `tstore`/`tload`) via Context7 — used existing notes + code references. Web fetches and Context7 calls were not performed in this pass per the “research-only first pass” framing that preferred primary code reading. If the cross-review asks for explicit external citations, those would be next-pass actions.
- No code edits, shell runs, tests, or peer-artifact reads. Report uses line-cited facts only.

### 9.3 Counter-arguments to expect in peer review
- “This is just a rebalance swap in disguise.” Counter: a rebalance has no user intent to swap one token for another; it is policy-driven, idle-only, and accounted as inventory move. A user zap is the *opposite*: user-initiated, one-shot, dedicated user op, slippage-protected. PRD distinguishes user ops from rebalance (§6.2 vs §6.3); the same call site must not be reused for rebalance.
- “Just call `exchangeInManyToOne`.” Counter: that function requires the user to push **both** tokens, defeating the single-token UX.
- “Update D28 to permit.” Counter: D28 is product-locked and re-opening it would let every rebalance pollute the sleeve. Add a *new* clause, not amend D28.
- “Could the DETF side of the request handle this?” Counter: as analyzed in §2.5 the DETF-side already handles single pair and single share; the missing piece is on the **SE Standard Exchange** side, not the DETF.
- “Stack-too-deep in the InBase?” Counter: existing execution delegate pattern (`UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE`) already handles stack pressure. If it does not, split the new facet into a separate execution-target delegate.

---

## 10. Saved path and provenance

- **Saved file:** `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-original.md`
- **Original report before cross-review:** this file (no cross-review pass has read it).
- **Word count (self-check):** ~1,250.

### 10.1 Source citations used in this pass (code)

| Path | Lines | Role |
|---|---|---|
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` | 256-377 | Deposit paths; single and dual |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol` | 335-377 | `_executeZapInDualDeposit` |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` | 37-78 | `exchangeIn` dispatcher |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiTarget.sol` | 11-30 | `exchangeInManyToOne` |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryTarget.sol` | 32-46 | preview Multi (proxy) |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol` | 43-100 | Blocked vs free preview gating |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` | 305-379 | Gate, deadband math, share SoT helpers |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` | 411-508 | `_erc20Face`, `_token0`, `_token1`, position amounts |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` | 525-712 | Liquidity plans, share math, deposit |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` | 734-994 | Rebalance + `_deployExcessLiquidity`; `_burnManagedLiquidityFraction` |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` | 996-1118 | `unlockCallback` settle paths |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol` | 22-96 | Liquid Reserve target / public rebalance |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4PositionRepo.sol` | 42-72 | Position tick creation + import state |
| `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` | 94-247 | PkgInit + facet cuts (existing 15 facets) |
| `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md` | D1-D31 (full file cited) | Sleeve / lock / rebalance / DETF-no-swap / D27 / D28 |
| `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md` | D30-D52 (relevant sections) | Full-range center; D32 binding token; D41 dual join |
| `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` | §24 / D32-D66 / D57-D59 / D28 / D27 | Current release authority; reform pointer |
| `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md` | §16 / R1-R20 | Uni V4 v1 routing law |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol` | 198-305 | `_entryExchangeIn` + `_mintPath` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` | 41-200 | Pair-of-vault resolution; mint split |

### 10.2 External sources

- None fetched this pass. Context7 (Uniswap V4 PoolManager singleton lock + `unlockCallback` + transient `tstore`) and Uniswap V4 docs not consulted; cross-review may want these for terminology citations (URLs + access dates).

---

## 11. MiniMax-M3 recommendations (research-only, not authorized)

1. **Accept the user request as a new product surface on the SE Standard Exchange**, *not* an amendment to D28 or D9. Codify the distinction.
2. **Approve as DETF alignment D60a / SE PRD §6.2.1** before implementation; do not implement directly off this report.
3. **Reuse the existing dual-join downstream** (`_executeZapInDualDeposit`); add only the new facet surface and the internal `_executeDirectSwapIn`-then-join sequence.
4. **Keep the lock-safe sleeve path** intact; the new facet reverts on blocked (`PoolManagerInteractionBlocked`) so users still have the option of single-token sleeve mint.
5. **Add the new entries to the test matrix** (§5 PMC-1..PMC-10 above) when the implementation plan is written.
6. **Treat the missing PRD text-suggested updates (§7) as owner decisions**, not autonomous edits.
7. **Cross-review should resolve §6 R-D60a.* items** before the implementation plan is written.

---

*End of independent MiniMax-M3 first pass. This report is research-only and does not authorize code, configuration, tests or delegation. Saved at `docs/research/uniswap-v4-sleeve-zapin-2026-09-26/minimax-original.md` for peer review.*

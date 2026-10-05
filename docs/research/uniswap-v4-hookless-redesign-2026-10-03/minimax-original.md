# MiniMax M3 — Hookless SE search-free redesign original

**Date:** 2026-10-03. **Family:** Uniswap V4 `UniswapV4FullSpreadHooklessStandardExchangeVault` (H). **Scope:** whether ordinary H deposits, redemptions, and quotes can be made search-free while keeping a useful sleeve and remaining composable with Orbital; what changes; what must be amended. **Independent first pass**; no peer originals or replacement originals read; no synthesis, status reports, or replacement memory used.

## 1. Ranked recommendation (refusal context stated)

The Hookless planner's two search loops are explicit in source: `Planner._composition` (`.../fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108`) runs up to 32 binary-search refinements (`MAX_REFINEMENTS = 32` at `:23`) over caller input, and `Planner._maintenance` (`:168–214`) runs up to 16 refinements per direction × two funding domains (`:192`). Both fit the prompt's forbidden class: "probe sequence whose purpose is to discover a swap amount." Public repair is the latter; deposit is the former. They are different operations (D11 §15 + PRD §6.2/§8); we treat them separately below.

Ranked designs, best-first:

1. **Design (1) — Proportional core, separate conversion (one-step closed form).** Adopting this. Search-free for every ordinary deposit/redemption/quote by routing the conversion through `Quotes._exactOutput` (`.../QuoteService.sol:113–141`) plus the existing closed-form `_closedPlacement` (`TransitionPlanner.sol:49–67`) and `_tryTargetLiquidity` (`.../InventoryMath.sol:216–230`). Public repair becomes placement-preferred plus **at most one** holder swap at a deterministic budget; no refinement loop.
2. **Design (3) — Domain-restricted direct sizing.** Same core, but explicitly rejects single-token input outside the one-step closed-form swap domain. Stricter than (1); user-visible reverts grow. Orbital would be impacted because Orbital's input size can be outside domain.
4. **Design (4) — Core vault only, no on-chain single-token.** Most search-free; breaks Orbital because Orbital composes H via `Transition(tokenIn).quoteTransition(..., DepositExactIn, ...)` and an SE-share `ReceiveShares` path (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:170–185, 241–246`).
2. **Design (2) — Single-token valuation (oracle/NAV).** Rejected. It does not eliminate a sizing loop — it moves the loop into an oracle/NAV that an autonomous Orbital call cannot supply, which the prompt explicitly excludes.

## 2. What stays, what the user sees change, which PRD decisions amend

### Behaviors preserved (no amendment)
- Full-range liquidity, fungible vault shares, complete booking (PRD §3, §12). Path: `H/Common.sol:514–524, 1006–1009`.
- Dual-token initial activation, F0 minimum liquidity, dead-sink shares (`Common.sol:344–350`). Path: `StandardExchangeConstantProduct.sol:16–35`.
- Sleeve target = live fee-oracle percentage of owned deployed principal, default 20%, deadband unchanged (PRD §5; `InventoryMath.sol:50–56`). Placement changes the denominator; this is enforced by `_tryTargetLiquidity` (`InventoryMath.sol:216–230`) reading `sleeveWad` from the cached sample.
- "Retain and sweep later" for identified excess (D8; PRD §6.2/§12). The change does not silently substitute the single-sided invariant-growth branch when composed dual-token alignment fails (`Common.sol:268–274`, `InventoryMath.sol:128–165`).
- Fixed execution protections (D20): 25/50/10/1 bps. Path: `Common.sol:980–984`. The PRD states they are fixed constants with no setters. The redesign keeps them; no relaxation requested or required.
- Separate Pons Family V2 implementation tree (D22, D26). The redesign changes H internals only; no Pons merge.
- Hookless admits `poolKey.hooks == address(0)` only (D14; PRD §10).
- Source-agnostic pretransfer law (D15; PRD §11). Path: `Common.sol:900–922, 941–949`.
- Blocked operations do not initiate nested unlock (PRD §4).
- Public repair remains permissionless and immediate; no throttle introduced (D11).
- F3 dual exact-output exit, F1 blocked single-input forward and exact-share inverse, F2 blocked redemption, F4 one-step external exact-output (PRD §6.4; PRD plan §2.1–2.5).

### Behaviors the user sees change
- Single-token deposit no longer returns the search-optimal shares. It returns the shares from one core step (`Quotes._exactOutput`, `:113–141`) plus the closed-form placement candidate. Caller accepts that one core step gives a *bounded* swap (terminal price strictly inside the first core-step target), not the search-wide optimum. If the one-step swap cannot satisfy the 1 bp alignment bound (`Common.sol:984`), the call reverts `AlignmentNotAchievable()`. Public preview and execution produce the same integer amounts (`Common.sol:1116–1118`, `QuoteService.sol:54–65`).
- Single-token redemption becomes: `_linearExitPlan` (closed form, requires opposite backing = 0; `Common.sol:1051–1073, 1076–1083`) **plus** one `_redemptionForward` (`QuoteService.sol:47–62`, bounded traversal ≤ 64 ticks, not a sizing search) **plus** the same closed placement. The general two-leg exact-output redemption already marked `InvalidRoute` (PRD plan §2.3, §4 R6) remains so; the prompt permits this.
- Public `rebalanceLiquidReserve` keeps placement-preferred first (`Planner._safePlacement` → `_place(state, current, ...)` at `InventoryMath.sol:179–203`); if both bands still fail it performs **at most one** holder swap attempt at the deterministic "to-bring-decomposition-target" amount derived from `_compositionSign` and `Inventory._target`, then re-quotes the resulting state. There is no binary-search refinement probe (`Planner._maintenance:181–212` removed/replaced). Each call evaluates current state independently and may be repeated (D11).

### PRD decisions amended (D1–D31)
- **D1**: amend — the existing `exchangeIn` route is preserved but composition internals change (one-step closed form instead of refinement loop). Selectors unchanged.
- **D8**: amend — wording retains "Proportional ownership takes precedence over forced deployment"; the residual rule becomes "single-step residual retained; alignment failure reverts atomically."
- **D11**: amend — public repair is still no-throttle, still placement-preferred, but the search-vs-no-op policy now documents a one-attempt swap rather than a refinement loop.
- **D17, D18, D19, D22**: amend the *engineering specification* (see PRD plan §2.6, §4, §6.3) to reference the one-step closed form instead of the refinement loop. The PRD's *product* text about interleaved rebalance, formula-backed support, route-preservation exception, separate family orchestration is preserved.
- **D25**: unchanged — execution protections remain fixed constants.
- **D28**: unchanged — H → P reuse remains restricted to the three enumerated hook-independent files; the new planner does not introduce H→P dispatcher code.
- All other D1–D31: unchanged.

## 3. Exact equations, conservation, and domain behavior

All asset quantities are raw currency units. Let `S` be the pre-operation share supply, `B_i = F_i + D_i + E_i` (call `B_i` the *complete incumbent backing*; fees counted once, PRD §6.3 plan §2.0). The caller's contribution is `C_i`; prepaid credit is excluded from incumbent reserves (PRD §6.2; `Common.sol:1007–1008`). Caller credit is set before any collection (`Planner._composition:79`; PRD §5 §3 step 1).

**Sleeve policy** (PRD §5; `InventoryMath.sol:50–56`):
```
T_i = D_i + F_i                       // placeable
target_i = floor(T_i * p / (1e18 + p))
deadband_i = max(absoluteFloor_i, target_i / 20)
```
With `p = 0.20e18` and combined inventory 120 → deployed 100, free 20. Placeable changes after placement (do not freeze on pre-placement principal).

**Closed placement** (PRD §6.4; `InventoryMath.sol:216–245`):
```
budget_i = T_i - target_i
L* = min(
  getLiquidityForAmounts(q, a, b, budget_0, 0),
  getLiquidityForAmounts(q, a, b, 0,      budget_1)
)
```
Stencils evaluated at `L*`, `L* - 1`, and current liquidity; first passing with `rho ≤ 1bp` and `sigma = 0` wins. Three candidates, no adaptive loop.

**F0 — Dual-token proportional share** (PRD §6.3; `StandardExchangeConstantProduct.sol:30–65`):
```
mean   = floor((d0 + d1) / 2)
minLiq = mean < 3 ? 1 : 10^(mean - 3)
raw    = floor(sqrt(C0 * C1))                  // mulSqrt
empty-book:
    m = raw - minLiq
    residualSink = max(ceil(B0*m/C0), ceil(B1*m/C1))
live book, both legs:
    m = min(floor(S*C0/B0), floor(S*C1/B1))
```
**Conservation:** post-success, `free_Bi + deployed_Bi + earned_Bi` reconciles to actual `balanceOf(vault)` for both pool tokens and the self-share (`Common.sol:514–524`).

**F1 — Blocked single-input mint** (PRD plan §2.2; `StandardExchangeConstantProduct.sol:78–96`):
```
K      = ceil(sqrt(B_in * B_other))
A      = floor(sqrt((B_in + credit) * B_other))
minted = A > K ? floor(S * (A - K) / K) : 0
inverse:
    A_needed = K + ceil(shares*K / supply)
    amountIn = ceil(A_needed^2 / B_other) - B_in
```
Linear when `B_other == 0`: `forward = floor(credit*S/B_in)`, `inverse = ceil(shares*B_in/S)`. Reverts `InsufficientBacking` for first mint or single-token into empty same-side reserve.

**F2 — Blocked redemption** (PRD plan §2.3; `StandardExchangeConstantProduct.sol:98–111`):
```
u = floor(B_out * shares / S)
v = floor(B_other * shares / S)
output = u + floor((B_out - u) * v / B_other)
```
Pay only with sufficient local output cover; full-supply burn forbidden when positive opposite backing. Exact-output share inverse with two-leg backing is bisection (`_sharesForSingleExit` at `StandardExchangeConstantProduct.sol:113–129`) → `InvalidRoute` for general two-leg exact-output per R6 (PRD plan §2.3, §4).

**F3 — Dual exact-output exit** (PRD plan §2.4; `Common.sol:854–866, 1124–1145`):
```
burn0 = ceil(out0 * S / B0)
burn1 = ceil(out1 * S / B1)
require burn0 == burn1 && burn0 <= supply
pay: require both local covers >= out_i (idle) || request (blocked)
```

**F4 — One-step exact-output external swap** (PRD plan §2.5; `QuoteService.sol:113–141`):
```
zeroForOne: t = s - output / L;      netInput = L * (1/t - 1/s)
oneForZero:  t = L * s / (L - output*s); netInput = L * (t - s)
amountIn = netInput + ceil(netInput * fee / (1e6 - fee))
domain:  one core step, activeLiquidity > 0, total fee < 1e6,
         terminal price strictly inside first core-step target.
```
The replacement composition path uses exactly this one-step quote plus `Math.mulDiv(ownLpFee, 2^128, liquidityAfter)` for own-LP accrual (`QuoteService.sol:134–140`); no tick traversal is performed by the user-facing deposit beyond the bounded forward work in `_tryForwardBounded` (≤64 steps, `:28, :71–111`) which is *not* a sizing search — it executes or quotes an already-sized swap.

**F6 — Linear redemption-plus-conversion** (PRD plan §2.7; `Common.sol:1051–1083`): the linear branch is closed form; non-linear general two-leg inverse is `InvalidRoute`.

**Empty book** (`supply == 0`): only F0 with both `C_i > 0` and `raw > minLiq` produces shares (PRD §6.1; `StandardExchangeConstantProduct.sol:30–35`). Single-token into empty book reverts.

**One-sided book** (`B_i > 0`, `B_j == 0` for `j != i`): F1 linear (`floor(credit*S/B_i)`; inverse `ceil(shares*B_i/S)`); F6 linear inverse when zero opposite leg; placement settles only the active leg (RL invariant at `InventoryMath.sol:84–110, 217–230`); alignment requires the inactive residual to be zero, otherwise revert.

**Already-unlocked (PoolManager in-session)** (PRD §4; `Common.sol:354–358`): idle routes reject `UniswapV4Exchange_PoolManagerInteractionBlocked`. Only F1/F2 (blocked equivalents) plus the per-call local-cover behavior remain; public repair silently no-ops when `!canOpenPoolManagerUnlock()` (`Common.sol:626–632`). No nested unlock permitted.

## 4. Sleeve policy and blocked-cover behavior

Sleeve policy preserved (target = `p%` of owned deployed principal; deadband retained). Blocked-cover behavior preserved. The permit's revenue model (D25 unchanged) is unchanged.

## 5. Orbital and SY consequences

**Orbital composition today** calls H through three surfaces:
- `Transition(tokenIn).quoteTransition(..., DepositExactIn, amountIn)` — the H preview path, which currently calls `Planner._composition` (`Common.sol:265–274`) and runs up to 32 refinements. **Replaced** by the one-step closed-form quote + closed placement: deterministic preview == execution.
- `Transition(tokenIn).quoteTransition(..., ReceiveShares, amountIn)` for SE-share inputs (`OrbitalBufferHookExitQuoteLib.sol:170–185`) — path is the H `_amountInForZapMint` (`OutBase.sol:60–72`), already closed form for the blocked branch and accepted here for the one-step idle branch via the redesigned `_executeZapInDeposit`.

**Outer Orbital searches that remain** (separate problem, flagged not solved here):
- `zapSplitWad` (`.../UniswapV4StandardExchangeOrbitalBufferHookMath.sol:321–364`) does a 64-probe binary search for the residual. With H now one-step closed form, each Orbital probe is O(1); the outer 64-probe loop remains Orbital's, not H's.
- `_faceForClaim` (`OrbitalBufferHookExitQuoteLib.sol:347–374`) is an up-to-8-probe binary search; replaced by a single `_claimIn` call in the new H design (claim is `Transition(leg.se).quoteTransition(..., DepositExactIn, amount)` plus rate; already closed form).
- `_planDeposit → _depositSales → zapSplitWad` (`:241–330`) is the outer Orbital sizing. The prompt's search-free restriction is on H; Orbital-side sphere residual balancing is out of scope unless the owner opens a second round.

**Which current H calls become invalid**: `Planner._composition`'s refinement path (`TransitionPlanner.sol:84–107`). `Planner._maintenance`'s refinement loop (`TransitionPlanner.sol:181–212`). Callers must use the new `Quotes._exactOutput + Planner._closedPlacement + Inventory._targetLiquidity` path.

**Autonomous Orbital-callable search-free alternative**: H exposes `quoteDepositSingle(tokenIn, amountIn) → (sharesOut, priceAfterX96)` and `quoteRedeemSingle(tokenOut, sharesBurned) → (amountOut, priceAfterX96)` whose preview is the deterministic one-step + placement state. Orbital's `Transition.quoteTransition` returns this preview directly; Orbital does not need its own `zapSplitWad` for the H leg, only for its own sphere composition. **Remaining outer search**: Orbital's sphere residual balancing for the non-SE legs (Leg 0 and Leg 2 if they are not H SE shares) — `zapSplitWad` and `_faceForClaim` are still required for those, at least until a separate Orbital-side redesign.

## 6. Manipulation, donation, fee-ownership, rounding, same-pool incumbent-repricing risks

- **Donation**: pretransfer law unchanged (PRD §11; `Common.sol:900–922, 941–949`). Unbooked surplus cannot fabricate caller credit; declared amount > unbooked reverts (`TransferDeltaInsufficient`).
- **Fee ownership**: own LP accrual computed as `floor(lpFeeAmount * 2^128 / activeLiquidity)` (`QuoteService.sol:139`); protocol/Pons fees not booked to E (`QuoteService.sol:136–138`). Order: credit before collection, then E→F once (`Planner._composition:79`; PRD §12).
- **Rounding loss** is attributed to the caller on addition, to the incumbent on removal (`Planner._composition:135–144`); `result_.roundingLoss[i] = beforeTotal - afterTotal` (`InventoryMath.sol:281`).
- **Same-pool incumbent repricing**: swap's effect on incumbent B is recomputed from the simulated `sqrtPriceAfterX96` and own-LP fee growth (`Planner._afterSwap:158–166`); it is not assumed identical to the pre-swap backing. Pool repricing belongs to incumbents, never to the depositor (PRD §6.2).
- **1 bp alignment enforcement** (`Protection._aligned:105–111`): `10000 * shares * B_i >= 9999 * S * C_i`. Exact-wide-arithmetic via `_product` (`:82–86, 102–103`) and `Types.Uint2048` eight-limb checks (`ProtectionMath.sol:8–174`). Wide-arithmetic required; one `mulDiv` is not enough.
- **Hookless invariants**: `_supportsInventoryQuote` requires `poolKey.hooks == address(0)` and not an imported position (`Common.sol:121–123`). Preview for imported positions already reverts `InvalidQuoteState`.
- **Pons-side risks**: out of scope; Pons keeps its own per-pool fee decoding. The change does not introduce any H→P fallback.

## 7. Acceptance and benchmark plan (later implementation, not for this round)

1. **Freeze specification and source revision**; record git SHA of this original plus the current planner/quotes/inventory/protection libraries.
2. **Replace planner**: delete the refinement loop bodies in `_composition` and `_maintenance`; replace with a fixed 2–3 candidate placement stencil + a one-step exact-output swap when applicable. Reuse `Quotes._exactOutput` as-is.
3. **Restore exact-parity suites** (PRD plan §8): `FormulaDomains.t.sol`, `QuoteExecutionParity.t.sol`, `EquivalentInterfaces.t.sol`, `AttributionAndBooking.t.sol`, `ZapAndPlacement.t.sol`, `MaintenanceProgress.t.sol`, `NestedAndConsumer.t.sol`, `Adversarial.t.sol`, `RuntimeAndWork.t.sol`. Each asserts preview == execution at the same integer amount.
4. **Orbital parity**: assert `Transition(tokenIn).quoteTransition(..., DepositExactIn, amount)` returns identical integer shares to execution across all supported token directions, decimal combinations, and the three fee-oracle sleeves (`p = 0, 0.2, 1`, plus live inherited changes).
5. **No gas measurement claim in this round**. Bench work is a separate later round; do not assert a gas improvement.
6. **Audit-submission evidence**: post-readiness, both new families pass applicable acceptance; H reports `executionProtectionBps()` unchanged; Pons reports unchanged.
7. **No `viaIR`**, hermetic profile only, `forge build` then `forge test` (CLAUDE.md §10); no profile or config workaround.

## 8. Evidence — paths, lines, primary URLs, versions, access date, confidence, gaps

| Source | Path:line | Used for |
|---|---|---|
| Composition refinement loop | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108` | Search to remove |
| `MAX_REFINEMENTS = 32` | `:23` | Work bound |
| Maintenance refinement loop | `:168–214` | Holder search to remove |
| Per-direction refinement | `:192` (loop header) | Holder search to remove |
| `_closedPlacement` (no loop) | `:49–67` | Closed-form placement retained |
| One-step `_exactOutput` | `.../UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol:113–141` | Closed-form swap retained |
| `_tryForwardBounded` | `:71–111` | Bounded traversal (≤64 steps), not a sizing search |
| `MAX_CORE_STEPS = 64` | `:28` | Bounded traversal cap |
| Sleeve target/deadband | `.../UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol:50–56` | Sleeve policy |
| Composition-vs-progress | `:84–110` | Rho/sigma definitions |
| `_tryTargetLiquidity` | `:216–245` | Closed-form placement target |
| 25/50/10/1 bps constants | `.../UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:980–984` | Fixed execution protections |
| Single-token deposit path | `:264–304` (`_executeZapInDeposit`) | Caller composition site |
| Pretransfer law | `:900–922, 941–949` | Donor/credit invariants |
| F1/F3/F4/F6 helpers | `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:16–129` | Source-blocked helpers |
| Crane `UniswapV4ZapQuoter` | `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4ZapQuoter.sol:151–231` | Library binary search; not adopted |
| Crane `UniswapV4Quoter` | `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:105–194` | Tick-traversal quoter |
| Crane `UniswapV4Utils` | `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Utils.sol:262–284` | `getLiquidityForAmounts` reference |
| Orbital `planDeposit` | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:241–330` | Outer Orbital sizing (out of scope) |
| Orbital `zapSplitWad` | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol:321–364` | 64-probe binary search; Orbital-side |
| Orbital `_faceForClaim` | `.../UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:347–374` | Up-to-8-probe binary search; Orbital-side |
| PRD | `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` | Owner product authority |
| Plan | `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` | Engineering specification baseline |

Primary upstream (Context7; first-party GitHub sources via Context7 MCP):
- Uniswap v4 Core `SwapMath.computeSwapStep` — `/uniswap/v4-core` (description: "Computes the next price, input amount, output amount, and fee amount for a single swap step ... Exact-in scales input by (MAX_SWAP_FEE - feePips)/MAX_SWAP_FEE; exact-out caps output by amountRemaining and is impossible when feePips equals MAX_SWAP_FEE"). Source: `uniswap/v4-core/_autodocs/api-reference/sqrt-price-math.md`.
- Uniswap v4 Core `LiquidityAmounts.getLiquidityForAmounts` — `/uniswap/v4-core/test/utils/LiquidityAmounts.sol` (closed-form helper).
- Uniswap v4 Core `ProtocolFeeLibrary.calculateSwapFee` — `/uniswap/v4-core/src/libraries/ProtocolFeeLibrary.sol` (assembly: `protocolFee + lpFee − protocolFee·lpFee/1e6`, rounded up).
- Uniswap v4 Periphery `PositionManager.modifyLiquidities` — `/uniswap/v4-periphery` (description: "requires a deadline and performs an unlock ... reverts with ContractLocked if locked").
- Uniswap v4 Periphery `UniversalRouter` `V4SwapRouter` — `/uniswap/v4-periphery/_autodocs/api-reference/PermissionedV4Router.md` (background only; not used by the inspector).

Local compiler baseline: Solidity 0.8.35, optimizer runs 1, `viaIR` disabled (PRD §15; CLAUDE.md §7).

Access date: 2026-10-03 (this round). Compiler/runtime settings are repository baseline, not an independent deployment attestation.

Confidence: **high** in the directly read source formulas, the identification of the two refinement loops as searches, the closed-form of `_closedPlacement`/`_tryTargetLiquidity`/`_exactOutput`, and the F1/F3/F6 inventory. **Medium** in end-to-end integer workflow feasibility after removing the refinement loop, until the acceptance suites in §7 run. **Lower** in autonomous Orbital-callable search-free properties for Orbital's own sphere residual balancing (out of scope for H; flagged as remaining outer search).

**Gaps (missing ordinary files; not retried):**
- `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol` — directory does not exist in this revision; not retried.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol` — directory does not exist in this revision; not retried.

**Not measured**: gas. The PRD/council explicitly directs no fresh measurement in this round.

**No consensus claimed.** This is an independent first-pass original; peer originals, replacement originals, status reports, and synthesis were not read or used. No measured gas improvement is claimed. No evaluated findings asserted as public-source canonical claims.
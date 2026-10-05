# Astra — Aperture OptimalSwap and V4 Hookless feasibility

**2026-10-03. Independent original for this question.** Retained session history acknowledged; no peer artifacts read. Research/source inspection only; no execution, tests, implementation or gas measurements. No consensus claim.

## 1. Answer: three distinct targets

| Target | Answer |
|---|---|
| Pinned Aperture directly executing V4 | **No.** Its calls and custody are V3/NFT-based. No maintained official hookless V4 OptimalSwap executor was verified. |
| An ordinary single V4 hookless position | **Yes in mathematical approach; conditional port.** Walk pool segments, solve the final constant-liquidity segment analytically, execute one sized swap then add liquidity. V4 settlement, fees, rounding and work bounds need implementation/proof. |
| Existing fungible Hookless whole book | **Promising conditional yes, not a ready upstream feature.** I derive below a quadratic in each fixed segment including arbitrary local/prior-fee balances, owned active liquidity, repricing and own LP fee accrual. These additions do not inherently force a higher-degree equation. Integer execution and terminal placement remain unresolved. |
| Orbital/SY autonomous composition | **Idle inner calls can use that approach without backend sizing. Already-unlocked same-manager calls cannot use the swap path under current law.** Existing funded sleeve routes remain necessary; outer claim inversions and sphere sizing are separate problems. |

There are three different loops: binary-search trial sizing; monotone discovery of which segment contains the answer; and traversal to execute/quote an amount already known. Aperture replaces the first with the second plus a root calculation. This question permits investigating that distinction; I impose no new blanket loop ban.

## 2. Pinned source, dependencies and official V4 search

All Aperture file references below use **AP** = `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/`.

Directly read: `src/libraries/OptimalSwap.sol`, `src/base/SwapRouter.sol`, `src/base/Automan.sol`, `src/UniV3Automan.sol`, `src/base/Callback.sol`, `package.json`, `.gitmodules`, `foundry.toml`, `LICENSE`, `test/OptimalSwapRouter.t.sol`, `test/uniswap/UniHandler.sol`, `test/uniswap/UniBase.sol`.

Package version is **2.0.1**. Exact declared math dependency is `@aperture_finance/uni-v3-lib:3.0.3`; [v3.0.3 TickBitmap](https://raw.githubusercontent.com/Aperture-Finance/uni-v3-lib/v3.0.3/src/TickBitmap.sol) and [SwapMath](https://raw.githubusercontent.com/Aperture-Finance/uni-v3-lib/v3.0.3/src/SwapMath.sol) were read. Other dependency declarations include V3 core ^1.0.1, periphery ^1.4.4, OpenZeppelin ^5.0.2 and Solady ^0.0.232. Their exact resolved lockfile versions/package-byte equivalence were not verified. Only forge-std appears in `.gitmodules`.

Pinned Foundry configuration: solc **0.8.26**, Paris, optimizer 4,294,967,295 runs, **via_ir=false**. This is not local IndexedEx's 0.8.35/optimizer-1 baseline. README-era advice is not a substitute for the pinned configuration.

Official public search found [Aperture-Finance/uniswap-v4-hooks](https://github.com/Aperture-Finance/uniswap-v4-hooks), its freshly read proposal-oriented README, an Aperture v4-core fork, Aperture-Lens preliminary V4 PRs, and a V4 backtester. The [Lens README](https://raw.githubusercontent.com/Aperture-Finance/Aperture-Lens/main/README.md) describes ephemeral lenses. None inspected established a current production V4 hookless OptimalSwap port. This is **absence of verified evidence**, not a claim no such code exists anywhere. The hooks proposal is not a zero-hook executor.

## 3. Actual money path and algorithm

### Funding, selected range and execution

For one pool token, call `Automan.mintOptimal` with the other desired amount zero. The **caller supplies the target ticks**, pool tokens/fee tier, recipient, deadline and mint minima. It pulls desired tokens, deducts explicitly supplied service-fee amounts bounded by `feeConfig`, then calls `_optimalSwap`. This fee extraction is separate from the pool swap fee.

With **empty swapData**, `_optimalSwapWithPool` calls `OptimalSwap.getOptimalSwap` on-chain. No backend amount is needed. The library returns **amountIn, predicted amountOut, direction, predicted final sqrt price**—not an encoded full settlement plan. SwapRouter executes the returned input amount via direct V3 `pool.swap`, using V3's positive exact-input sign and global extreme price limits. The authenticated V3 callback verifies the computed pool and pays its debt from Automan custody. Actual output determines the remaining basket; the NFT manager receives approvals and executes mint. `_mint` refunds unused desired amounts.

`increaseLiquidityOptimal` reads the existing NFT's range and pool identity, pulls new funding and follows the same optimizer. That increases a particular NFT; it does not price fungible common-book shares for a new owner. Decrease/collect can target one output token by swapping the known opposing proceeds and checking `tokenOutMin`, with residual refunds. These are reusable scalar realization semantics, not a general exact-output share inverse.

Nonempty swapData selects an allowed external-router path followed by ratio adjustment. This is distinct from the fully on-chain empty-data path. `mintFromTokenIn` is a separate arbitrary-third-token interface with caller allocations to the two pool tokens; it should not be conflated with a unilateral pool-token `mintOptimal`.

The pinned router does **not** enforce our 50 bp terminal impact, 10 bp fee-inclusive shortfall or 1 bp whole-book share-loss rules. Mint minima/deadlines, fee limits and callback authentication do not collectively imply those protections. Its global swap limits cannot simply be copied into the local money path.

### How it discovers the final segment

1. Read current sqrt price/tick, active pool L, fee and spacing; derive endpoint sqrt prices from supplied ticks.
2. `isZeroForOne`: below target range only token0 is needed, above it only token1; inside compare the liquidity obtainable from each caller leg. The excess leg determines direction.
3. `crossTicks` reads the next initialized tick with a **cached bitmap word**. The dependency compresses negative ticks with floor-toward-negative-infinity, not truncation toward zero.
4. Simulate spending up to the remaining input budget toward that boundary. If the boundary cannot be reached, stop. If the resulting caller basket would require the opposite direction, stop **without committing that overshooting step** to the saved segment state.
5. Otherwise commit spent/received amounts and boundary price, apply signed liquidityNet, and advance tick (`next−1` leftward, `next` rightward). Repeat.
6. Solve the terminal segment analytically; handle transitions into the target range and possible all-input conversion outside it; derive integer swap amounts, then execute one swap separately.

The continuous invariant is that saved state reflects a committed swap prefix and the imbalance has not yet reversed; the solution lies in the uncommitted terminal segment or an endpoint/budget case. The prefix moves monotonically in price; it does not repeatedly quote unrelated midpoint amounts.

**New source-level caution:** dependency `nextInitializedTick` scans empty bitmap words until a nonzero masked word and explicitly assumes a next initialized tick exists. It has its own uncapped while-loop, in addition to `crossTicks`' uncapped do/while. Bounding only initialized crossings is insufficient. Moreover, it skips empty-word boundaries whereas core swap execution takes within-one-word steps. Integer fee/input/output rounding can depend on these step partitions. A V4 exact-parity port should walk **core-compatible targets**, cache reads without deleting computational boundaries, and budget both word reads and swap steps.

## 4. Single-position constant-segment algebra, both directions

This section is **continuous algebra**, with raw-unit sqrt price normalized out of Q96. Let current s, selected range endpoints a<b, active pool liquidity L>0, caller holdings x,y and fee fraction f<1; g=1−f.

For token0→token1, final t≤s:

`u=L(1/t−1/s)/g`, `v=L(s−t)`.

Require the resulting basket match position amounts:

`(x−u)/(1/t−1/b)=(y+v)/(t−a)`.

This gives `A_z*t²−B_z*t−C_z=0`, where

```
A_z = x + L/(g*s) − L/b
B_z = a*(x+L/(g*s)) + f*L/g − (y+L*s)/b
C_z = y+L*s − L*a/g
```

For token1→token0, final t≥s:

`u=L(t−s)/g`, `v=L(1/s−1/t)`;

`(x+v)/(1/t−1/b)=(y−u)/(t−a)` gives `A_o*t²−B_o*t−C_o=0`, with

```
A_o = x + L/s − L/(g*b)
B_o = a*(x+L/s) − f*L/g − (y+L*s/g)/b
C_o = y+L*s/g − L*a
```

These match the structure/comments of upstream `solveOptimal*`; each uses a quadratic root analogous to `(B+sqrt(B²+4AC))/(2A)`. They apply to an interior final price in the selected range and one constant-L segment. Root direction, segment/budget limits and degenerate coefficients must be validated, not assumed from a root's existence.

Upstream implements signed quantities in unsigned two's-complement assembly, unchecked products and shifts, intermediate floors, then clamps a computed terminal price that moves in the wrong direction back to the starting price. It also sometimes floors fee gross-up in the final amount calculation, whereas the boundary-step helper uses rounded-up gross input. This is an **analytic sizing implementation with rounding**, not a source-established universal exact-integer optimality theorem.

## 5. Whole-book extension: explicit quadratic including own fees

**Original derivation for this report.** It preserves current ownership semantics rather than switching to NAV/internal CP. Let a segment start at s, external active liquidity L>0 and vault-owned **active** liquidity ℓ≤L. The vault may own multiple positions, but no active set changes inside this segment. Inactive positions have constant amounts; active positions aggregate as

`D0(t)=d0+ℓ/t`, `D1(t)=d1+ℓ*t`.

Thus any sleeve F and earned-before-segment E can be included through starting incumbent totals `B0s,B1s`, excluding caller credit. Define `U0=B0s−ℓ/s`, `U1=B1s−ℓ*s`. These constants can be negative because finite-range offsets are subtracted; B itself must remain nonnegative.

Let f be the live combined fee expressed as a fraction, φ the directional protocol fraction, g=1−f, H=L/g. In the **smooth approximation to core's already-selected fee rate**, own LP fee received per gross input is

`η=(ℓ/L)*(f−φ)`.

Protocol fees and other LP fees never enter incumbent E. Actual core integer splitting is discussed below. Let d be caller input still available at this segment and e the caller's opposite-token proceeds accumulated on prior segments. At the initial segment d=c,e=0. B0s/B1s include all incumbent prefix repricing and prior own fees.

### Token0 input

Incremental gross input `u=H(1/t−1/s)` and output `v=L(s−t)`. Set

```
A = d+H/s;       Y = e+L*s
U = U0−η*H/s;    V = ℓ+η*H;    W = U1
C0 = A−H/t;      C1 = Y−L*t
B0 = U+V/t;      B1 = W+ℓ*t
```

Whole-book alignment `C0*B1−C1*B0=0`, multiplied by t, is

```
(A*ℓ + L*U)*t²
+ (A*W − H*ℓ − Y*U + L*V)*t
− (H*W + Y*V) = 0.
```

### Token1 input

Incremental gross input `u=H(t−s)` and output `v=L(1/s−1/t)`. Set

```
A = d+H*s;       Y = e+L/s
U = U0;          W = U1−η*H*s;   V = ℓ+η*H
C1 = A−H*t;      C0 = Y−L/t
B0 = U+ℓ/t;      B1 = W+V*t
```

Alignment `C1*B0−C0*B1=0`, multiplied by t, becomes

```
− (H*U + Y*V)*t²
+ (A*U − H*ℓ − Y*W + L*V)*t
+ (A*ℓ + L*W) = 0.
```

**Result:** arbitrary F/E constants, finite-range principal offsets and proportionate own LP fee accrual preserve quadratic degree within a fixed segment. There is no need to assume the sleeve is initially proportional or to equate owned ℓ with external L. When ℓ=0, use η=0; a fixed positive incumbent book still yields a quadratic. At f=φ, LP recovery vanishes. If a quadratic term is zero, solve the linear degeneration; if all vanish, classify the actual economic domain instead of dividing by zero.

The scalar comparison is continuously monotone before placement: spending input reduces caller input and increases caller output; incumbent input increases from principal conversion/own fees while incumbent output decreases. Hence `C_in*B_out−C_out*B_in` moves toward/through zero on a funded positive book. This supports a **whole-book boundary walk**, not an instruction to reuse Aperture's position-ratio sign predicate. At every initialized/own boundary, update external L and owned active ℓ separately and reconstruct U0/U1 from the new snapshot. Multiple wings remain piecewise quadratic; they require more boundary/state bookkeeping, not automatically a higher polynomial degree.

### What is not proved

1. Raw integer core transitions are staircases: combined fee pips are rounded, protocol deduction floors, per-step Q128 growth floors, each owned position's fee entitlement floors, price is Q96, principal and payouts round directionally. η*u is not their exact replacement.
2. Prior fee collection affects checkpoint rounding. Freeze caller credit before collection; model the actual collection/checkpoint sequence once. Adding separate rounded fee estimates is not always equivalent to collecting cumulative growth.
3. After the swap, current deposit placement can charge rounding loss to C or B. `HTransitionPlanner.sol:135–143` does this; it is absent from the quadratic and can invalidate alignment.
4. Squaring signed coefficients can need substantially more than 256 bits. No production width/stability proof or universal integer-neighbor bound is supplied here.

A credible first domain is one positive-liquidity **core swap step**, fixed owned-active set, f<1, certified representability, one analytic candidate, and an exact forward/placement check satisfying all protections. Reject failure without probing. This certifies successful calls but does not prove sufficient acceptance coverage. A bounded multi-segment version is the next candidate; it must preserve exact prefix checkpoints and core step boundaries.

## 6. V4 port and concrete autonomous sequence

Local **C**=`lib/crane/contracts/protocols/dexes/uniswap/v4/`; **H** is the full Hookless vault prefix under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`.

Crane `ProtocolFeeLibrary.sol:35–46` computes total fee pips as `protocol+lp−floor(protocol*lp/1e6)`; `utils/UniswapV4Quoter.sol:196–225` reads direction-specific protocol fee and deducts it before own fee growth. This direct source corrects potentially stale audit snippets returned by documentation search. Zero hooks removes custom hook deltas—not these fees, core boundaries or settlement.

V3 exact-input positive becomes V4 **negative** amountSpecified. Read pool state by PoolId/StateLibrary, not a V3 pool address; replace V3 callback pay with authenticated PoolManager unlock/settle/take; use salted owner/tick position identity. `modifyLiquidity` callerDelta already includes fees; never add feesAccrued twice. Track native ETH with its single configured ERC20 face. Existing Crane overlay is one liquidity-change range; wings require corresponding bounded overlay/fee expansion. Quoter `:143–175,233–288` supplies the core-compatible forward machinery, not the missing sizing rule.

**Proposed exact-input operation:**

1. Validate route/manager/hook, deadline, caller credit and minShares. Snapshot supply, complete incumbent D/F/E, liquidity/ticks, fee checkpoints, live sleeve percentage and pool fee state, with credit excluded.
2. Model collection consistently. Read-only walk at most an explicit core-step/bitmap budget (initial candidate: existing 64-step ceiling, to be validated), maintaining caller and incumbent prefix separately; stop at budget, impact boundary or sign bracket. Zero-L gaps require bounded boundary traversal, not division by zero.
3. Solve the segment quadratic once, convert deterministically to a gross integer candidate, then perform one exact core forward verification. Evaluate actual finite-range incumbent principal/fees, caller C and the selected placement. No midpoint/refinement rescue.
4. Compute `m=min(floor(S*C0/B0),floor(S*C1/B1))` after loss attribution; require `10000*m*B_i≥9999*S*C_i`, minShares and positive meaningful output. Enforce 50 bp **price** impact using squared sqrt ratios, not a 50 bp sqrt-price move. Model fees once; enforce 10 bp fee-inclusive execution shortfall.
5. Execute the committed one-swap/liquidity action sequence through current authenticated context, reconcile observed deltas/state, mint, and book all retained sleeve/residual/dust. Exact-in refunds nothing under current law. A same-state modeled preview must equal execution exactly; tolerance is not permission to disagree.

Aperture's refund-all scratch-router pattern cannot be copied into persistent holder custody. Collection/placement do not create caller capital. Tokenwise accounting must reconcile `incumbent-after-swap + caller-after-swap − placementLoss` against final backing; caller-funded swap gross spend and output are distinct from incumbent repricing/fees.

Holder repair remains separate work. Replacing `_composition` does not remove `_maintenance`; changing mandatory interleaving requires explicit plan/PRD reconciliation. Do not append a searched repair and call the complete route analytic.

## 7. Nesting, exact-output and preserved scalar exits

When PoolManager is already unlocked, the current law permits only local sleeve settlement; Aperture cannot open a nested unlock or manufacture spendable opposite currency. Preserve existing blocked F1 exact-input/inverse and F2 covered scalar exits, with complete B valuation and actual F cover. Their internal economics differ from external composition; this report does not silently unify them.

Native SY `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76` delegates scalar SE entry/exit. An autonomous idle `quoteTransition(DepositExactIn,c)` can call the proposed planner using configured pool/range state; no user swap-size parameter is needed. Its state must project the same supply, positions, balances, fees and subsequent rate-provider reads as execution.

A forward analytic deposit is **not** an inverse for token→exact shares. Idle exact-share mint remains unsupported absent a separately derived minimal-input equation, including rounding and placement. General two-leg exact-output scalar redemption also remains unsupported; keep existing source-linear one-legged and one-core-step direct-swap domains. Idle exact-input exit already knows its proportional position removal and opposing entitlement; it can forward-swap that amount without deposit sizing research, with fees on remaining holders' positions attributed correctly. Scalar entry/exit are not replaced by baskets.

Orbital's `_faceForClaim` and `_invertBufferForEffective` still need an input-for-shares inverse at the correct projected rate/state. Eight interpolation attempts do not cap subsequent bisection. `zapSplitWad` is a separate sphere-residual search. Faster/analytic inner forward quotes remove none of these automatically. B6 and the held-rate addendum remain: reserve valuation is raw shares times configured rate, not a trade-sized SE quote. No minOut=0, gas-conditioned valuation or speculative sharesJ/sharesK accounting is proposed.

## 8. Tests, amendments, license and decision

**Read-only upstream test evidence:** pinned `OptimalSwapRouterTest.testFuzz_MintOptimal` compares aggregator-assisted/direct routes with an approximate liquidity tolerance `max(liquidity/1000,1e6)`. `UniBase.assertLittleLeftover` permits each token unit/1000 and ETH 1e12; fuzz amounts are bounded relative to fork pool balances. `UniHandler` includes 1% approximate comparisons, empty-data scalar exits and zero-minimum test calls. UniV3 fixture forks Ethereum block 17,000,000. These are useful asserted scenarios, **not executed results here**, not our 1 bp whole-book guarantee, and not our test/deployment style to copy.

Later gates: independently verify both polynomial expansions/root selection, exact-prefix monotonicity and error bounds; exhaust small integer/decimal domains; test word-boundary rounding, own/external tick crossings, zero L, 100%-fee rejection, f near limits, extreme ticks, signed coefficients/discriminant overflow and tiny m; reconcile cumulative fee collection and terminal placement losses; require useful successes under 1/50/25/10 bp limits and exact SE/SY/transition parity. Benchmark whole nested calls and runtime sizes with current artifacts, not only quadratic arithmetic. No cap raise or measured speedup claim.

**Product changes:** potentially preserve D1–8 ownership/funding and D20/D25 constants; replace the plan's §6.3 refinement algorithm and specify bounded monotone discovery under D27/D30. State whether the final target is no binary trial sizing or strict no-discovery. Any maintenance omission amends D18–19 as needed. Any new inverse needs D17 evidence. Existing F0 dual activation/dead-sink, D15–16 booking/pretransfer, full-range policy and Pons separation remain. Multi-wing expansion requires its own approved range/accounting scope; not necessary for the single-core derivation.

Pinned LICENSE remains a BUSL-1.1 document with **2026-07-01** change date and **GPL-2.0-or-later** change license. That date has passed; review applicability and combined/dependency obligations rather than declaring MIT or a perpetual production ban. Read math dependencies carry GPL-2.0-or-later headers. No source-copy permission is inferred from this research.

**Ranked feasibility:** (1) single-position V4 port is the most mature mechanism; (2) whole-book one-segment analytic candidate plus exact certificate is the strongest local next proof target; (3) bounded whole-book segment walk is promising once integer invariants are closed; (4) complete Orbital optimization remains separate. No current upstream executable is a drop-in V4 whole-book zap.

**Plain English:** Aperture follows the pool's price path until it finds the interval where the correct split must lie, then calculates the split instead of repeatedly guessing it. The same idea can plausibly price our entire book: the continuous equation still reduces to a quadratic. But the executor, integer accounting and nested-manager limits do not disappear. The useful next step is proof and a separately authorized port—not an assertion that today's V3 code already solves V4.

### Evidence/limitations

All accesses **2026-10-03**. Context7 `/uniswap/v4-core` preceded API research. Public AP paths above are commit-pinned; dependency paths are version-tagged, not independently content-hashed. Exact external function names substitute for unavailable raw line numbers. Current CLAUDE, task PRD/plan, catalog, canonical skills, Orbital held-rate/B6 and DETF D53/D57–59 were directly read. No ordinary path failed this turn; previously missing mistaken paths were not retried. No guard or genuine SDK unavailability occurred.

Confidence: high in source flow/dependency behavior; medium-high in the explicitly expanded continuous whole-book quadratics; unresolved in integer completeness, economic/liveness coverage, official V4 successor availability and performance. Stop for human decision; no implementation authorized.

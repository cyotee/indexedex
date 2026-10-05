# Aperture OptimalSwap: how it works and V4 Hookless feasibility

**Date/access date:** 2026-10-03. **Author:** Astra moderator. **Status:** completed bounded research round: four originals and four combined cross-reviews. No implementation, tests, gas measurements, deployment or source-copy authorization.

## 1. Direct answer

**Aperture really does discover an on-chain zap-in swap size without binary-search trial sizing. The inspected implementation executes V3, not V4. Its approach is a credible basis for a V4 Hookless port, and this round establishes a continuous fixed-segment extension for our complete incumbent book.**

| Question | Answer |
|---|---|
| Does it calculate how much of one pool token to swap? | Yes. `mintOptimal` accepts a zero desired amount for the other pool token; empty `swapData` selects autonomous calculation and direct-pool execution. |
| Does it select the investment range? | No. Target ticks are supplied by the caller or read from the existing NFT. |
| Does it execute an existing V4 hookless pool as written? | No. Pinned code uses V3 pool calls/callbacks and NFT-position custody. No maintained official hookless V4 OptimalSwap executor was verified. |
| Can the mathematical process be ported to a V4 hookless position? | Conditionally yes: same concentrated-liquidity structure, different fees, state access, signs and settlement. Exact rounding and bounded work must be specified. |
| Does upstream already price new fungible shares against our entire book? | No. However, an explicit whole-book quadratic is derived below; sleeves and prior fees do not inherently destroy analytic solvability. |
| Does this solve all nested Orbital/SY calls? | No. Idle inner scalar calls can potentially use an adapted planner. Current already-unlocked sleeve-only policy and the outer sizing searches remain separate. |

**Recommendation:** advance an Aperture-inspired **whole-book analytic planner**, first in a certified one-core-step domain, then a bounded segment walk. Preserve current proportional admission and incumbent ownership as the initial target; do not switch to internal CP, remove scalar entry/exit, discard the sleeve or require wings merely because the solver changes. This recommendation is a proof/port-specification direction, not implementation readiness.

## 2. What the algorithm actually does

Pinned repository: [Aperture UniV3 Automan c40aaa98cf49baf454fbb7a8ee6709862e27038e](https://github.com/Aperture-Finance/uniswap-v3-automan/tree/c40aaa98cf49baf454fbb7a8ee6709862e27038e).

### Call flow

1. **Funding and range.** `Automan.mintOptimal` receives the pool identity, selected ticks, desired token amounts, recipient, deadline and liquidity minima. It pulls nonzero inputs and deducts specified service-fee amounts under its configured fee limit. Its own service fee is distinct from the pool swap fee.
2. **Autonomous sizing.** With empty `swapData`, `_optimalSwapWithPool` calls `OptimalSwap.getOptimalSwap` using current pool state. One desired amount may be zero; a backend need not supply the split. Nonempty data selects a separate allowed-router flow.
3. **Direction.** `isZeroForOne` identifies which token is excessive relative to the selected position at current price. Below the range the position needs token0; above it token1; inside it compares the two liquidity capacities.
4. **Segment discovery.** `crossTicks` simulates movement toward successive initialized ticks. It tracks remaining input, accumulated output, sqrt price and active liquidity. It stops if the remaining budget cannot reach the next boundary or the proposed next step would reverse the optimal direction. An overshooting step is not committed to the saved segment start.
5. **Terminal solution.** Within the final constant-liquidity segment, `solveOptimalZeroForOne` or `solveOptimalOneForZero` evaluates a quadratic. Out-of-range/budget cases have additional endpoint/all-input handling; “last tick outside range” does not universally mean all input is consumed without further handling.
6. **Execution.** The math returns `amountIn`, predicted `amountOut`, direction and predicted final sqrt price. It does **not** return a complete V4 action plan. `SwapRouter` executes one sized V3 pool swap; authenticated callbacks pay debts. Automan then mints/increases the NFT and refunds unused amounts.

`increaseLiquidityOptimal` uses the existing NFT's range. It is position-owner automation, not fungible common-book admission. `mintFromTokenIn` is a separate arbitrary-input-token conversion interface; it does not negate the autonomous single-pool-token `mintOptimal` path.

### Plain-English comparison

Current binary sizing asks repeatedly: “What if we swap this amount? Too much? Too little?” Each trial may quote the price path again.

Aperture instead asks: “Does the answer lie before the next liquidity boundary? If not, advance to that boundary. Once the right interval is known, calculate the answer.”

This is **monotone segment discovery plus an analytic solve**, not amount bisection and not a zero-loop universal formula. Execution later traverses the actual sized swap. An exact acceptance check may also traverse the committed path, so do not claim only one traversal total or a measured gas win.

## 3. Why the single-position equation is quadratic

In continuous normalized sqrt-price units, let initial/final prices be s/t, target range [a,b], active liquidity L>0, available caller amounts x/y, fee fraction f<1 and g=1−f.

For token0 input:

```
gross input u = L*(1/t - 1/s)/g
output v = L*(s-t)
caller basket = (x-u, y+v)
```

A liquidity position ending inside the range requires amounts proportional to `(1/t-1/b, t-a)`, so solve:

`(x-u)*(t-a) = (y+v)*(1/t-1/b)`.

This becomes `A*t²-B*t-C=0`, with:

```
A = x + L/(g*s) - L/b
B = a*(x+L/(g*s)) + f*L/g - (y+L*s)/b
C = y+L*s - L*a/g
```

For token1 input, `u=L*(t-s)/g`, `v=L*(1/s-1/t)` and the symmetric coefficients are:

```
A = x + L/s - L/(g*b)
B = a*(x+L/s) - f*L/g - (y+L*s/g)/b
C = y+L*s/g - L*a
```

These explain the pinned code's coefficient structure. Its Q96 implementation includes floors, signed quantities represented in unsigned assembly, unchecked intermediate arithmetic, and clamps. A displayed quadratic root is not proof of universal exact integer optimality, safe extended coefficient widths or valid root direction. Root degeneracies and endpoint domains must be checked explicitly.

## 4. Important new result: the whole-book problem also stays quadratic per segment

The existing local rule matches caller contribution to **post-swap incumbent backing**:

`C_in * B_out = C_out * B_in`, then `m=min(floor(S*C0/B0),floor(S*C1/B1))`.

Here B includes deployed principal, spendable local inventory and own earned uncollected fees, with caller credit excluded. Upstream Aperture does not contain that full ownership model. Nevertheless, it can be expressed analytically within a fixed active-liquidity segment.

### Assumptions and definitions

This section is a **continuous derivation**, not source-exact integer code. No liquidity placement/removal occurs inside the segment; fees and active sets are fixed there.

- L>0: all active pool liquidity.
- l: vault-owned active liquidity; rho=l/L.
- f: combined pool swap-fee fraction; g=1−f.
- phi: directional protocol-fee fraction of gross input.
- a,b: incumbent input/output backing at segment start, including local/prior-fee balances and previous segment changes, excluding caller credit.
- d: caller input remaining; e: caller output accumulated on previous segments.
- u: additional gross input in this segment; v(u): its output.

Both directions have the form:

```
v(u) = beta*u/(L+gamma*u)

token0 -> token1: beta=L*g*s², gamma=g*s
token1 -> token0: beta=L*g/s², gamma=g/s
```

The vault's principal gains `rho*g*u` input currency. Its own LP fee recovery is `rho*(f-phi)*u`, not the protocol fee and not all pool fees. Consequently:

```
alpha = rho*(1-phi)
B_in(u)  = a + alpha*u
B_out(u) = b - rho*v(u)
C_in(u)  = d - u
C_out(u) = e + v(u)
```

These expressions are the smooth approximation to the actual fee/checkpoint floors. In particular, **hookless is not protocol-fee-free**.

Let `P=b*L` and `Q=b*gamma-rho*beta`. Substituting into alignment and multiplying once by the positive denominator yields:

```
A*u² + B*u + C = 0

A = Q + alpha*beta + e*alpha*gamma
B = beta*a - d*Q + P + e*(a*gamma + alpha*L)
C = e*a*L - d*P
```

At the first segment, d=c and e=0. These coefficients include arbitrary sleeves/prior fees through a,b and own LP ownership through rho. Share supply is applied after the basket is aligned; it need not enter the continuous ratio equation.

### Hand-checkable nonzero-sleeve example

Take L=100, l=50, s=1, no fees, a=b=100 and d=10,e=0. The book can comprise 25/25 position principal plus a 75/75 sleeve. The quadratic is:

`100u² + 19500u - 100000 = 0`.

Its physical root is u=5. Output is 100/21. Incumbent backing becomes 102.5 input and 2050/21 output. Both caller/incumbent contribution ratios are 2/41. **The sleeve is nonzero, yet the equation is quadratic.** This is hand algebra, not an executed test.

### Multiple positions and progression

Within a fixed active set, owned principal sums to `D0=k0+l/t` and `D1=k1+l*t`; inactive positions contribute constants. Multiple ranges introduce additional boundaries and checkpoint work, not higher powers inside the segment. Recompute L and owned l separately at relevant boundaries; an own boundary can matter even if aggregate liquidityNet cancels.

For `G(u)=(d-u)B_out-(e+v)B_in`, in a funded positive-book domain:

`G'=-B_out-(d-u)*rho*v'-v'*B_in-(e+v)*alpha < 0`.

This supports finding a continuous root by a progressing sign bracket. It does not establish monotonicity or completeness of the exact **post-placement integer** acceptance predicate.

**Adjudication:** MiniMax's original sleeve→cubic, fees→quartic, wings→quintic and Abel–Ruffini objections were erroneous and withdrawn in review. Cubics/quartics also have general radical formulas, and a special higher-degree expression would not itself prove nonsolvability. The correct issue is discrete arithmetic/segmentation/placement, not a demonstrated algebraic impossibility.

## 5. Integer behavior is the main remaining proof gap

The quadratic can propose a candidate. Our actual operation includes:

- rounded combined fee pips and per-step protocol deductions;
- Q96 price and token-delta rounding;
- Q128 fee-growth floors and each position's checkpoint/final earned-fee floor;
- cumulative collection order, with caller credit fixed before collection;
- signed settlement/representation bounds;
- share flooring;
- terminal placement, whose costs may be charged to caller contribution or incumbent backing.

The current planner explicitly attributes placement loss before final mint at `TransitionPlanner.sol:135–153`. That loss is absent from the smooth equation. A passing continuous root therefore need not yield a passing integer deposit.

Proposed research acceptance procedure: calculate one deterministically rounded candidate, evaluate the **exact** forward transition and placement accounting, then enforce all funding, ownership and protection conditions. Reject if it fails—do not silently reintroduce midpoint refinement. A mathematically proved rounding correction could be part of arithmetic; a root±1 search selecting an economic amount must be described honestly and separately approved if used.

Successful validation proves that candidate is admissible. It does not prove the algorithm finds every feasible nearby amount or supplies useful deposit liveness. Tiny deposits, mixed decimals, active-set boundaries, high fees, zero liquidity, extreme ticks and wide signed coefficient/discriminant arithmetic need independent tests later. Exact-input forward sizing also does not establish an exact-share input inverse.

## 6. Two work loops and exact V4 stepping

The pinned dependency is `@aperture_finance/uni-v3-lib` **3.0.3**. Its `TickBitmap.nextInitializedTick` caches words and scans empty words until a nonzero mask, explicitly assuming a next initialized tick exists. That scan has its own while-loop in addition to `crossTicks`.

A robust port must bound:

1. Core swap steps/segment advancement.
2. Bitmap/storage reads, including empty words.
3. Price/impact domain and global tick endpoints.
4. Zero-liquidity gaps and source representability.

Input depletion alone does not bound empty-liquidity traversal because price may advance without consuming input. A 50 bp price bound is not a reliable tick-count/work bound; initialized distribution and spacing matter.

**Subtle parity issue:** Aperture's initialized-tick scan may skip empty-word boundaries that core execution processes as computational steps. Per-step fee and amount rounding can depend on that partition even when L does not change. A V4 planner should preserve core-compatible within-one-word targets and exact prefix accounting, while caching reads—not delete rounding boundaries. Local Crane's forward quoter is useful verification machinery, not a substitute for deriving the sizing equation.

The structure plausibly avoids repeated full simulations, but the cost of traversal, square roots, wide arithmetic, certification, placement and nesting is unmeasured. Vendor comments about gas are not our performance evidence.

## 7. V4 hookless port map

| Area | Required adaptation |
|---|---|
| State reads | PoolId/StateLibrary/PoolManager reads instead of V3 pool address/call helpers; support supplied transition snapshots faithfully. |
| Exact-input sign | V3 positive amountSpecified becomes **negative** in V4. |
| Delta signs | V4 negative caller delta is debt to manager; positive is receivable. Do not copy V3 output-negation logic unchanged. |
| Fees | Read live directional protocol and LP fees. Local combination is `protocol+lp-floor(protocol*lp/1e6)`. Deduct protocol before own LP growth. |
| Settlement | Authenticated unlock context, settle/take all caller-owned deltas; ERC20 sync **before** payment transfer, then settle. Native currency requires its own correct path. |
| Position identity | Owner/lower/upper/salt. Different ranges need not inherently have different salts, though fixed named slots can be a policy. |
| Custody | Replace V3 NFT manager scratch custody/refunds with persistent vault accounting. Position ownership stays with the actual manager caller. |
| Protections | Do not copy global MIN+1/MAX−1 as sufficient protection. Enforce 50 bp terminal **price** impact, 10 bp fee-inclusive shortfall, existing 1 bp alignment/share loss, meaningful user minima and deadlines. |
| Own fees | `modifyLiquidity` callerDelta already includes fee accrual. Never count its informational fee return twice. |
| Multiple ranges | Expand snapshots/overlays/checkpoints consistently; no conflating pool L with owned l. |

A retrieved Context7 generated documentation snippet incorrectly presented transfer→sync→settle. The moderator checked upstream `test/utils/CurrencySettler.sol`, which explicitly performs **sync→transfer→settle**; source governs this report. This illustrates why fetched docs and council answers are evidence, not unquestioned authority.

### Already unlocked: protocol semantics versus current product law

Calling `unlock` again reverts. However, V4 `swap`/`modifyLiquidity` check the manager's global unlocked state; an appropriately authenticated/settled caller can technically act within an existing session. A read-only sizing call itself does not attempt another unlock.

**Our current product deliberately uses sleeve-only settlement in that state.** Aperture supplies no approved active-session vault adapter. Moving a view before the outer unlock does not solve position ownership, transient liabilities, funding, stale state or reentrancy. Any active-session extension would be separate product/security work, not an automatic consequence of porting math. Do not describe protocol-wide impossibility where the actual boundary is current product law.

## 8. Proposed autonomous idle call sequence

This is a specification sketch, not implemented code:

1. Validate scalar route, hooks==0, manager binding, caller, deadline, credit and minShares. Freeze credit exclusions before internal collection.
2. Snapshot S, full D/F/E, position state, pool fee state, checkpoints, live sleeve percentage and any projected prior transitions.
3. In the allowed work/impact domain, advance a core-compatible prefix while maintaining caller input/output and incumbent principal/fees separately. Use a whole-book sign predicate, not upstream's one-position ratio predicate.
4. Solve the bracketed terminal whole-book quadratic, including linear/degenerate cases and valid-root selection. Produce one integer gross input candidate.
5. Verify the exact forward swap, updated incumbent book, placement and attributed losses. Mint by current proportional formula only if both positive-leg share-loss checks pass:

   `10000*m*B_i >= 9999*S*C_i`.

6. Enforce impact and fee-inclusive execution checks, execute through the authenticated manager context, reconcile observed results, mint and fully synchronize retained local balances.

No caller-provided swap split or backend payload is needed for this proposed idle route. Native SY can keep delegating the scalar SE operation. No minOut=0, gas-dependent fallback or speculative `sharesJ/sharesK` accounting is proposed.

Current exact-in residuals remain retained/booked; Aperture's refund-all scratch-router policy is not imported. F0 dual activation/dead-sink rules remain. Holder maintenance remains a separate sizing problem; leaving a searched maintenance tail inside the call would defeat a claim that the whole user operation is analytic. Any interleaving change requires PRD reconciliation.

## 9. Scope not solved by a forward analytic zap

- **Idle exact-share mint inverse:** not derived merely by solving swap size for a supplied input credit.
- **General two-leg exact-output scalar redemption:** still needs its own supported direct inverse; no numerical inversion is authorized.
- **Scalar exact-input exits:** remain mandatory and can remove predetermined proportional liquidity then swap the known opposing entitlement. Correct post-removal state and own-fee ownership still matter.
- **Blocked calls:** retain existing F1/F2/local-cover domains under current policy. Analytic external conversion does not create cover.
- **Orbital outer `_faceForClaim`, `_invertBufferForEffective`, `zapSplitWad`:** remain separate. Reducing inner forward-quote work may help, but does not remove their inverse/allocation searches.
- **Pons:** remains separately implemented; the Hookless fee derivation is not a Pons fee/dispatch port.

An original's shorthand “Orbital: no” is therefore narrowed: Aperture is not a complete Orbital solution, but an adapted idle inner planner can be autonomously callable. No off-chain size need be introduced just because the original product uses NFTs.

## 10. Cross-review outcome and remaining dissent

| Researcher | Original contribution | Correction/disposition |
|---|---|---|
| Astra | Detailed dependency/money-path trace and whole-book sqrt-price quadratics | Cross-review supplies simpler gross-input coefficients, explicit monotonicity conditions and active-session distinction. |
| Grok replacement | Restricted whole-book input quadratic, V3/V4 sign and ownership cautions | Adds protocol/bitmap caveats; categorical Orbital/wing exclusions narrowed to actual unresolved integration work. |
| MiniMax M3 | Broad execution/port checklist | Withdraws erroneous higher-degree/Abel–Ruffini and scalar-entry conflation. Some settlement/unlock/license statements in original are not adopted. |
| Kimi K3 | Independent quadratic-degree argument and exact-candidate reject-policy framing | Own LP fee coefficient requires gross-up/protocol correction; predicted final price is not upstream's execution limit. License no-port prohibition withdrawn. |

The cross-reviews agree on the continuous quadratic opportunity and lack of an integer proof. Their independent algebra is useful evidence, not a security vote. No complete integer domain/liveness proof, source-exact V4 port or performance measurement was produced. Approximate upstream assertions do not satisfy our bit-exact D30 or 1 bp loss requirement automatically.

The correct own fee term for token0-in expressed through price change is `l*(f-phi)/(1-f)*(1/t-1/s)` in the continuous model. Several Kimi statements omit the gross-up factor; this report uses the corrected alpha form. Similarly, a fixed set of owned ranges raises boundary complexity, not polynomial degree by itself.

## 11. Versions, evidence and license

All accesses **2026-10-03**. External raw files are cited by exact function and pinned revision rather than invented line numbers.

Primary Aperture root: `https://raw.githubusercontent.com/Aperture-Finance/uniswap-v3-automan/c40aaa98cf49baf454fbb7a8ee6709862e27038e/`:

- `src/libraries/OptimalSwap.sol` — `getOptimalSwap`, `crossTicks`, `solveOptimal*`, direction predicate.
- `src/base/SwapRouter.sol` — `_optimalSwapWithPool`, `_poolSwap`, actual global price limit and V3 positive exact-input sign; moderator freshly fetched.
- `src/base/Automan.sol`, `src/base/Callback.sol`, `src/UniV3Automan.sol` — funding/execution/refund/authentication, researcher direct traces.
- `package.json` — package 2.0.1, exact declared `@aperture_finance/uni-v3-lib` 3.0.3; other semver dependencies not lockfile-resolved in this round.
- `foundry.toml` — solc 0.8.26, Paris, optimizer runs 4,294,967,295, via_ir=false; moderator freshly fetched. Not our build settings.
- `test/OptimalSwapRouter.t.sol`, `test/uniswap/UniBase.sol`, `test/uniswap/UniHandler.sol` — read by Astra, not run. Approximate comparisons/leftover tolerances and selected fork-state fuzz domains are not exact whole-book proof.
- `LICENSE` — BUSL-1.1 text with 2026-07-01 change date and GPL-2.0-or-later change license. That date has passed; dependency/version/combined-work obligations still require review. GPL is not a categorical prohibition on porting, nor a permissive-license clearance.

[Version-tagged dependency TickBitmap](https://raw.githubusercontent.com/Aperture-Finance/uni-v3-lib/v3.0.3/src/TickBitmap.sol) was freshly read by moderator: negative-tick compression, cached word reads and uncapped empty-word scan. Its header is GPL-2.0-or-later. Package-byte/tag equivalence and transitive license closure remain unverified.

Context7 `/uniswap/v4-core` preceded API verification. Primary settlement correction: [CurrencySettler.sol](https://raw.githubusercontent.com/Uniswap/v4-core/main/test/utils/CurrencySettler.sol). [PoolManager.sol](https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol) was verified in retained discussion and researcher review; upstream main is not a deployed pin.

Official V4 search found [Aperture hooks proposals](https://github.com/Aperture-Finance/uniswap-v4-hooks), [Aperture v4-core fork](https://github.com/Aperture-Finance/v4-core), [Lens preliminary V4 work](https://github.com/Aperture-Finance/Aperture-Lens/pull/21) and [backtester](https://github.com/Aperture-Finance/UniV4Backtester_ETHSF2024). None inspected verifies an official maintained V4 hookless OptimalSwap executor. Do not turn this coverage limit into a universal absence claim.

Local source directly checked by moderator this round:

- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:35–46` — combined fee.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Utils.sol:41–62` — exact-input sign. Its global target means comments alone do not establish a one-step boundary certificate.
- Same utils `UniswapV4Quoter.sol:143–185,196–225,233–288` — exact forward work cap, live fees, own recovery and within-word crossing.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultTransitionPlanner.sol:73–108,110–165` — current search, ownership predicate, placement loss and mint.

Current law/skills were read directly in retained sessions: CLAUDE, Hookless PRD D1–31 and implementation plan, Orbital B6/held-rate addendum and relevant canonical skills. Local compiler baseline is `foundry.toml:29–36`: 0.8.35, optimizer runs 1, no via-IR. Neither this nor vendor audit/deployment listings attests a current deployed port. No vendor gas statement is adopted as measured evidence.

## 12. Human checkpoint and separate implementation handoff

**Recommended bounded next target:** specify and independently validate the whole-book one-core-step analytic candidate, then define bounded monotone traversal using core-compatible steps. This investigates Aperture's useful mechanism without discarding current ownership protections or mandatory scalar service.

Before implementation readiness, close:

1. Both-direction coefficient/root equivalence, protocol fee, fixed active sets, linear degeneracies and wide-integer bounds.
2. Exact forward/fee/checkpoint and terminal placement-loss accounting, including small-unit failures.
3. Word/step/zero-liquidity/own-boundary termination and impact caps.
4. Nontrivial supported deposits with positive fees, sleeve and own LP recovery; quantify candidate rejection versus feasible integer solutions later with an independent reference.
5. Exact preview/transition/execution/SY parity, funding/authentication/native/residual rules and cross-mode economic cycles.
6. Separately derived exact-output eligibility, outer Orbital effects, source-license review and later nested gas/runtime measurements under unchanged caps.

Owner decisions remain bounded discovery versus strict single-segment rejection, any proved rounding correction/stencil policy, and maintenance interleaving. No change to D5 ownership or D20 protection values is inherently required by the continuous derivation. The current implementation-plan refinement policy and D27/D30 engineering specification would need amendment. D17 inverse support is not automatically widened. Wings are optional separate scope, not necessary for this result.

### Retained researcher record

| Researcher | Session | Original / combined review |
|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md` / `astra-cross-review.md` |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md` / `grok-replacement-cross-review.md` |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | `minimax-original.md` / `minimax-cross-review.md` |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md` / `kimi-cross-review.md` |

Eight synchronous continuation calls completed this round. All originals are preserved. Each review received the other three current originals only, never a prior cross-review. Historical replaced Grok was not resumed. No guard/SDK failure was reported this round.

**Confidence:** high in observed algorithm/port distinctions; strong continuous algebra evidence, not formal verification; unresolved integer completeness, economic/liveness coverage and gas. No contracts/tests/config changed; no shell/tests/deployments/transactions/benchmarks run. Stop at the human checkpoint.

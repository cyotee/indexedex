# Astra — Independent implementation-plan research, original

Date/access date: **2026-09-27**. Target: **NEW FullSpread V4** only. This is the new round's independent original; no peer artifacts were read for this round, and no earlier peer cross-reviews were read. Retained conversation history is not new evidence. Research/Markdown only; no shell, tests, implementation, deployment or delegation.

## 0. Executive determination

The latest PRD resolves the former automatic-maintenance/exact-output questions: holder-funded repair is intended; **the complete exact-output transition, including its maintenance, must be closed-form**. The existing exact-output mint inverse followed by `_rebalanceLiquidReserveBestEffort()` is not compliant merely because its input quote is closed-form.

I select below a concrete architecture, attribution ledger, bounded exact-in/public solver, progress rule, constants, ABI and work packages. I derive useful closed forms for a **single-swap-step constant-fee domain**, including a holder-repair quadratic, instead of declaring exact-output mathematically impossible or blanket-disabling it. However, a real-number quadratic is not a proof of an integer-exact EVM route. Integer candidate certification, supported hook models, and domain coverage are explicit **engineering proof gates before an implementation-ready plan may be frozen**. No implementer is authorized to improvise those answers, remove maintenance, introduce a search into exact-output, or silently remove required routes.

### Source shorthand

- **Z**: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`, updated 2026-09-27, D17–D19/§6.4.
- **U**: `contracts/vaults/standard/exchange/protocols/uniswap/`.
- **F/**: `U/v4/`. Within F, **Common**, **InBase**, **InQuery**, **OutBase**, **OutExecute**, **QuoteService**, etc. abbreviate `UniswapV4FullSpreadStandardExchangeVault<suffix>.sol`.
- **CPMath**: `U/StandardExchangeConstantProduct.sol`.
- **CP law**: `F/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`.
- **CraneV4/**: `lib/crane/contracts/protocols/dexes/uniswap/v4/`.

## 1. Binding authority and verified baseline

Read latest Z and CLAUDE.md; current CP law and DETF alignment §24.7.1; canonical Crane architecture/deployment/testing/adversarial skills directly; local IndexedEx testing/adversarial skills directly. The retained direct reads of pretransfer law and skill catalog also apply. Current Z wins over older no-swap policy and pretransfer provenance language. No original-source edits, deletion, registry deprecation action or migration are authorized. V3 shared math must not acquire V4-specific economics by accident.

Verified NEW target facts:

| Area | Source evidence | Consequence |
|---|---|---|
| Idle single-token issuance | InBase:269–311; Common:689–701; CPMath:37–64 | Currently credits sleeve, invariant-mints, then places; must change idle exact-in path. |
| Blocked issuance | Same branches, no unlock when blocked | Preserve fee-free same-book internal settlement; do not run external composition or repair. |
| Local booking | Common:610–635,1218–1239 | Actual local snapshots and caller guard already exist; retain them. |
| Swap callback | Common:954–1020 | Single-operation unlock payload, global min/max price limits, modifyLiquidity discards separate `feesAccrued`; extend scoped execution accounting. |
| Exact-output dispatch | OutExecute:34–100 | Direct swap, share redemption, exact-share mint all have maintenance tails. Remove separate numerical tails from exact-output. |
| Existing exact-share inverse | OutBase:45–61; CPMath:67–95 | Only inverse of invariant-growth mint, not of new external composition plus maintenance. |
| Exact-output withdrawal inverse | OutBase:64–118; CPMath:113–128 | Uses bisection in relevant branches; not admissible for combined exact-output under D18. |
| Dual exact-output exit | OutMultiTarget:58–120 | Equal ceiled share burns, payout and public-style tail; must project complete maintenance. |
| Ordinary preview | InMultiQueryTarget:11–48; InBase:252–261 | Ordinary `previewExchangeIn` is not on the transition-query target. |
| Transition simulation | InQuery:15–29,61–103,112–168 | Includes supply, holder claims, pool overlays, fees and sleeve allocation. Must be changed with execution. |
| Hook quoting | QuoteService:21–57; Common:103–109 | Pons-like fee decoding exists; unsupported ordinary adjustment silently returns unchanged amount, whereas projected inventory support is restricted. Not a universal exact hook model. |
| Native interface | Common:1054–1075; self-share SY path :1274–1280 | WETH face/native settlement and restricted SY self-call must survive. |
| Deployment | FactoryService:26–56,71–90; I...DFPkg:22–49 | Artifact-loaded CREATE3 delegates/facets, interface-defined PkgInit, PoolKey-only instance args. |

Canonical guidance requires real registered diamonds and target-derived proxy selector tests, not mocks or facet-only calls. Existing FullSpread base: `F/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`. Existing release/remediation tests are under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/`.

## 2. Selected architectural and product interpretations

These are **Astra engineering proposals**, not extra owner decisions.

1. Keep public SE money selectors and PkgArgs unchanged. Replace their internal planning/execution. Add additive diagnostic query selectors; no setter, owner, new oracle field or hook whitelist.
2. One pure/view **transition planner** returns an explicit bounded action plan and expected terminal book. Ordinary previews, transition quotes, availability and execution use it. Execution verifies actual deltas against the plan; it never repairs a bad quote with a different issuance formula.
3. Exact-in deposit: credit → collect incumbent fees → compose caller basket → placement → determine final attributed basket/backing → mint → full sync. No second composition swap funded by holders hidden inside the caller budget.
4. Public maintenance and automatic non-exact-output maintenance may use a bounded solver. Exact-output calls a distinct **closed-form combined planner**; its call graph must not reach bisection, Newton, secant, adaptive root searches, or numerical repair helpers.
5. Exact-output mint: compose caller basket → preliminary placement → mint exact requested shares → holder maintenance → final placement/settlement. Holder repair after mint is borne by all shares then outstanding, including the new recipient. Composition own-LP fees earned before mint belong exclusively to incumbents. Execution is atomic; the recipient obtains no lasting intermediate claim on failure.
6. Exact-output exit: establish the reference entitlement, remove its position fraction, perform necessary user conversion, burn/debit user shares and reserve exact payout → maintain the remaining book → pay exact output and refund only unused credited input → full sync. Pending payout is excluded from repair funding. Direct exact-output swap follows user swap → reserve exact payout → repair holder book → pay/refund/sync.
7. Interleaving means these actions form one precomputed, verified transition. It does not require simultaneous settlement or prohibit a sequential composition of closed formulas. A closed input inverse followed by **numerically** sized repair is expressly prohibited.
8. Blocked state never opens/join-piggybacks an unlock. No executable external maintenance exists in that state; §6.4 explicitly preserves this constraint. Preserve internal sleeve operations, with exact-output restricted to closed-form internally settled branches; do not mislabel blocked inability to trade as failure to include an executable maintenance leg.

### Constants and policy

Compile-time immutable constants: `REPAIR_IMPACT_BPS=25`, `COMPOSITION_IMPACT_BPS=50`, `EXECUTION_SHORTFALL_BPS=10`, `ALIGNMENT_LOSS_BPS=1`; denominators 10,000. No governance surface. Read sleeve `p` live once per transition; verify the same effective value before commitment after any external callback capable of altering dependencies.

Price protection uses `max(Pafter/Pbefore,Pbefore/Pafter)-1`, with `P=sqrtPriceX96² / 2^192`. Compare squared prices by full-width arithmetic; do not apply the percentage directly to sqrt price. Repair cap is across **all repair swaps within that operation**, measured from repair start to terminal, and each action is also checked. Caller-composition leg uses 50 bp; holder leg uses 25 bp. This is not a cumulative cap between calls. For existing ordinary user swaps/exits preserve user min/max protections; do not invent a 50 bp limit on every user trade merely because composition uses it.

Actual spend and received amounts are checked against the fee-inclusive quote for the **actual fill**. Require output at least `ceil(quotedOutput*9990/10000)`, with quoted input/settlement budgets separately enforced. No double subtraction of quoted fees. A partial fill cannot satisfy exact output. Exact-in retains unused credited inventory only if final alignment passes.

## 3. Inventory, attribution and placement

### Four distinct ledgers

Use memory transition state with `supply`, PoolKey/pool state, own liquidity/ticks, booked local snapshots, actual local F, fees E, principal D, caller credit C, pending payouts/refunds, and holder inventory H. Persistent local snapshots remain the existing storage. No persisted alternative NAV book.

- Capture declared pretransfer credit before collection/sync; source-agnostic surplus remains allowed. Pull credits measured delivery under existing no-FoT policy. Refund exact-out unused **credit**, not arbitrary balance surplus; false-flag exact-out pulls only quoted used.
- Exclude user credit and reserved payouts from holder trading budgets, even though all tokens share custody. Exclude unclaimed surplus from caller credit; absorb it into holder backing.
- Prior uncollected fees belong to holders. Collect before operations where available; moving E→F is not gain. Use pool fee-growth accumulation for newly earned fees, then collect or carry E exactly once.
- During caller composition: `C_in = credit - actualGrossSwapInput`, `C_out = actualNetSwapOutput`. Own deployed repricing and own LP fee accrual modify B, not C. Do **not** compute user output by a broad local-balance change spanning collection and liquidity modification.
- Separate `modifyLiquidity` principal, fees and hook deltas. Common:991–1020 currently takes only callerDelta. Use its separately returned fees plus exact before/after position amounts to reconcile. In the neutral-hook modeled domain, marginal add rounding costs are charged to the new contribution; old-position removal/repair costs are holder costs. Unknown liquidity-hook charges cannot be silently assigned: require a modeled attribution or reject that protected transition.
- After mint, holder repair owns all net trading costs and own-position recoveries pro rata over current shares. Never mint shares for public maintenance.

### Placement choice

At fixed sqrt price s and range endpoints a,b (real-number notation), define per-liquidity quantities `d0=1/s-1/b`, `d1=s-a`. For placeable `T=D+F`, desired final liquidity is

`Lstar = min(T0/((1+p)*d0), T1/((1+p)*d1))`.

Use raw-unit exact CL math in implementation, downward-safe liquidity budgeting for addition, upward-safe required token debt and normal core removal rounding. Zero d branches use one-sided math; never divide by zero. No artificial price/NAV normalization. Existing ticks never change.

The integer placement planner computes `targetFree_i=floor(T_i*p/(WAD+p))`, deployable token budgets `T_i-targetFree_i`, then maximum liquidity payable from those budgets with native `LiquidityAmounts`/`SqrtPriceMath`. It validates the exact rounded token debt before executing. Compute a **final position target**, rather than deploy/remove/deploy loops around a moving denominator. Skip placement when both sleeve deviations lie within the existing `max(absoluteFloor,5% targetFree)` band. Residual on the nonbinding token is retained, reported and booked.

This placement is closed algebraic budgeting, not a numerical repair solver. It cannot eliminate token-composition mismatch by itself.

### Shares and flooring

For composed deposits use `m=min(floor(S*C0/B0),floor(S*C1/B1))`, positive S/B/C. Initial dual bootstrap remains its existing geometric-mean/minimum/dead-share policy. Do not route it through the positive-incumbent formula.

Check for each leg:

`10000*m*B_i >= 9999*S*C_i`.

Use full-width product comparison. This includes share flooring and has no absolute-dust escape. For exact requested mint m, size contribution then enforce the same inequalities and `m <= min(floor(S*C_i/B_i))`; surplus beyond 1 bp fails, not an undocumented donation. Placement residual is not a refund.

## 4. Exact-in and public repair solvers

### Selected bounded execution

For mathematically modeled hook-neutral/static-fee pools, use a fee-growth-aware forward simulator based on CraneV4 `UniswapV4Quoter.quoteFromState` (143–193), with own-position overlay and inside-fee tracking. **Always set maxSteps=64**, never existing `0 == unlimited` (quoter:43,172–175). A truncated quote is not a certified full fill.

Deposit candidate objective is `g(x)=C0(x)*B1(x)-C1(x)*B0(x)` using post-swap amounts and own fees. Evaluate endpoints, an analytic one-step seed where valid, then at most **32 bisection refinements** within a sign bracket, plus the two adjacent integer candidates. Choose the passing candidate with largest shares; tie: lower gross swap input. Maintain all exact loss/protection checks. If no candidate passes, revert `AlignmentNotAchievable`; do not relax tolerance. This is bounded best effort, not an assertion of hook-general monotonicity or guaranteed success for every feasible amount.

Public repair first collects fees and tries placement-only. If mismatch remains, evaluate both directions within actual holder input budget and 25 bp terminal bound; select a safe improving candidate. Use the same 32-refinement/64-step bounds. At most **one economic repair swap per call**, followed by one final placement action (a funding removal may precede the swap if required and included in its projected liquidity). A caller may immediately call again. If no safe improving plan exists, emit deferred status, fully book any collected fees, return without trading.

### Explicit progress and stopping metric

Compute liquidity-equivalent totals `v0=T0/d0`, `v1=T1/d1`; compare using cross-products without lossy division. Proportional mismatch `rho=abs(v0-v1)/max(v0,v1)`; threshold **1 bp** (selected engineering constant for maintenance, not the deposit epsilon). When both d are positive this measures compatibility with the **current exact position ratio**, not a historical portfolio ratio.

Sleeve error `sigma=max_i(max(0,abs(F_i-targetFree_i)-deadband_i)/max(T_i,1))`. Zero d/zero totals receive explicit one-sided placement-only handling; do not fake two-sided rho.

Stop swaps when `rho<=1 bp` and `sigma=0`. Evaluate progress after final placement and after all fees/costs:

- Above proportionality threshold: require strictly smaller rho (at least one unit in WAD reporting precision), and do not permit an increase in sigma after final feasible placement.
- Within proportionality threshold: prefer placement-only; allow a swap only if rho stays within threshold and sigma strictly decreases.
- Compare against the **placement-only baseline from the same starting state**, not the deliberately worsened intermediate state after a funding removal.

No fee-generating round trip is accepted merely because an intermediate metric improved. This objective does not promise global convergence, nonloss under external arbitrage or bounded aggregate movement across repeated calls. Fee-inclusive protection does not impose an unapproved fee ceiling.

## 5. Closed-form combined exact-output: derivations and support domain

### 5.1 Domain and precise meaning

Choose a fixed finite formula graph: user leg → exact rounded state evaluation → analytic holder repair → exact rounded state evaluation → placement. No variable-count route root search or simulated trial executions. Arithmetic square-root/division implementations may iterate internally on bits; that is not iterative route solving.

First provable external domain: static known fee; **one actual core swap step for each user/repair swap**, not merely “no initialized tick crossed”; positive active liquidity; known managed full-range position; no callback affecting swap amounts, fees, liquidity accounting or pool state; all action amounts representable. Tick-bitmap inspection establishes that each selected price remains inside the current step. Word boundaries matter because fee rounding occurs per step even without a net-liquidity change.

Use actual fee pips and protocol fee split. Let `g=1-effectiveSwapFee`, and `r` be the continuous own-LP-fee recovery per gross input. For constant active liquidity L and own l, `r=(l/L)*(effectiveSwapFee-directionalProtocolFee)` under the continuous approximation. **Integer execution must use fee-growth floors, not this r approximation.** Static fee 100% cannot support ordinary exact-output swapping.

Mirror all formulas for token1-in using reciprocal sqrt price and swapped token labels; include transformed endpoints. These are derivations, not deployed-version claims.

### 5.2 Closed-form holder repair (nontrivial maintenance)

Assume token0-in holder repair, starting local F0,F1 after collecting prior fees, active L, own l and sqrt price s. Let t be terminal sqrt price and x gross input:

`x=(L/g)*(1/t-1/s)`; `y=L*(s-t)`.

Post-repair complete placeable inventory, after collecting own fees, is:

`T0(t)=A0+H0/t`, `T1(t)=A1+H1*t`, where

```
A0 = F0 - l/b + (1-r)*L/(g*s)
H0 = l - (1-r)*L/g
A1 = F1 + L*s - l*a
H1 = l - L
```

Exact proportionality to the range requires:

`(A0*t+H0)*(t-a) - (A1+H1*t)*(1-t/b) = 0`.

This is a **quadratic in t**, with coefficients:

```
q2 = A0 + H1/b
q1 = H0 - A0*a - H1 + A1/b
q0 = -H0*a - A1
```

Solve its real roots; retain physically valid root(s), with t<s, sufficient input and valid segment. Linear/zero-coefficient degeneracies are explicit algebraic branches. If full repair requires greater price movement, clamp t to the 25 bp boundary or inventory boundary, whichever occurs first, and evaluate the resulting **partial** repair and progress. A closed-form partial repair is allowed; manufacturing a trade when already on-target is not.

Final position liquidity is the §3 placement formula evaluated on T(t). Thus swap plus placement is algebraic. This is meaningful evidence of a nonempty closed-form maintenance domain, not “input quote then numerical repair.”

### 5.3 Caller exact-share mint in one external step

Token0-funded mint of exactly m shares, alpha=m/S. Let incumbent F/E be collected before composition. Its post-swap token1 backing is `B1(t)=F1+l*(t-a)`. The caller receives `C1=L*(s-t)`. Proportionality gives:

```
t = (L*s - alpha*(F1-l*a)) / (L+alpha*l)
x = (L/g)*(1/t-1/s)
B0 = F0 + l*(1/t-1/b) + r*x
C0 = alpha*B0
requiredCallerInput = x + C0
```

Compute preliminary placement, mint m, then evaluate the complete post-mint holder repair quadratic and final placement on that actual projected state. Own LP fees from composition are in B before m is minted. Repair fees after mint accrue to the new combined shareholder set. The entire candidate transition is a composition of rational functions, roots and core rounding rules.

For integer execution select token1 output by rounding the derived caller output upward, then apply one-step exact-output SwapMath to derive actual t/x and incumbent fee growth, then `C0=ceil(m*B0/S)`. Recheck token1 sufficiency and 1 bp on both legs. **Do not loop** if rounding makes this candidate invalid. The exact supported integer predicate must be specified and independently proved (see §5.7).

### 5.4 Exact-output direct pool swap

For token0 input and exact token1 output o, continuous `t=s-o/L`; gross input `x=(L/g)*(1/t-1/s)`. Use one-step exact-output `SwapMath` for exact integer amounts, then add actual own fee accrual/repricing to the holder book, exclude the reserved o payout, solve §5.2 repair from that state and perform final placement. This is a complete combined route, not a skipped maintenance alternative. Directional hook effects are part of the domain, never ignored.

### 5.5 Single-token exact-output redemption

For token0 output o, fraction z of shares burned, pre-route complete backing B0,B1 and own l, removing z*l leaves pool active liquidity `H=L-l*z`. User entitlement is `(z*B0,z*B1)`. Converting token1 entitlement through the remaining pool gives continuous output:

`o = z*B0 + H*g*z*B1 / (s*(s*H+g*z*B1))`.

Therefore solve the quadratic:

`(o-z*B0)*s*(s*L+z*(g*B1-s*l)) - g*z*B1*(L-l*z)=0`.

Choose smallest physical z in (0,1), ceil z*S to user share input, compute the **exact integer forward reference** (rounded liquidity removal, entitlements, swap output and fees). Reserve exact o payout; excess proceeds remain with the residual book under the existing exact-output policy. Then solve the closed-form remaining-holder repair and placement. Own fees generated after the user's liquidity fraction is removed belong to remaining liquidity owners; do not add those fees to the withdrawing user's conversion proceeds.

Again, the integer predicate/rounding proof is not replaced by the continuous root. Existing `_inventorySharesIn` bisection or a 1% buffer cannot remain as a fallback.

### 5.6 Dual exact-output and blocked exact-output cases

- **Dual exit:** retain `ceil(o0*S/B0)==ceil(o1*S/B1)` and burn that amount. Project fee collection, proportional removal, exact payouts and refund reserve. Solve holder repair and placement from the remaining book with §5.2. In the already aligned case this reduces to removal plus algebraic placement with zero repair swap; that is valid combined maintenance, not intentional omission.
- **Blocked exact-share mint:** existing CPMath:78–95 provides the integer invariant inverse. No unlock or external maintenance is available. Preserve it, validate its rounding/credit and synchronize. It is not a fallback for an idle unsupported route.
- **Blocked dual exact-output:** two ceiled share requirements plus actual local cover is closed-form; preserve without nested maintenance.
- **Blocked single-output exit:** continuous reference output is `B_out*(2z-z²)` for two positive book legs. Candidate share input is `S - floor(sqrt(S²*(B_out-o)/B_out))`. However current integer forward CPMath:98–110 floors both entitlements and conversion separately; a naive radical is **not automatically its exact inverse**. A valid candidate domain can certify forward(candidate)>=o and forward(candidate-1)<o with two fixed evaluations, exploiting monotonicity of the forward function. If the candidate fails, that demonstrates this candidate is unsupported, not that no integer closed form exists. One-asset linear branch is simply `ceil(o*S/B_out)` with cover checks.

### 5.7 Integer certification and honest limits — plan-freeze gate

Use exact Q64.96/SqrtPriceMath/SwapMath and fee-growth Q128 arithmetic to evaluate each analytic candidate once. For repair evaluate at most two algebraic roots and their fixed adjacent representable sqrt-price candidates; this is a finite branch set, not adaptive numerical solving. Choose least gross turnover among candidates satisfying funding, impact, progress, terminal accounting and exact output. A root outside the domain is not force-fit by a search.

**Important missing proof:** I have not established that these fixed rounded candidates cover every mathematically feasible single-step exact-output state, nor that rejecting all candidate failures is an acceptable final availability domain for every required consumer. These are genuine engineering evidence gaps. Do not convert them into a claim of mathematical nonexistence or deploy blanket `InvalidRoute` on all exact-output routes.

Selected arithmetic implementation for the proof work: signed rational coefficients, cancel common factors before multiplication; full-width products/quotients and integer square root in a new V4-only math library, with checked overflow. Specify at least 1024-bit intermediate limbs for coefficient evaluation, and explicitly bound the supported raw input/liquidity/price domain with overflow predicates. No unchecked overflow, silently rounded-down discriminant or guessed fixed-point scaling. The bit-width sufficiency and root error bounds must be proved before freezing production arithmetic; if 1024 bits is insufficient for an intended input range, the report must revise the representation rather than let the coder choose it.

**D18 audit:** every exact-output success must carry a formula-branch ID plus a precomputed complete terminal state. Acceptance requires an execution trace with no route solver invoked anywhere in that call graph. Fixed checks verify the formula; they cannot resize repair based on an iterative residual search.

## 6. Proposed support matrix and hooks

| Route/state | Required proposed handling |
|---|---|
| Idle exact-in single-token → shares | Bounded modeled forward solver, caller-funded composition, final 1 bp check; productive placement best effort. |
| Blocked exact-in → shares | Preserve current internally settled constant-product issuance, no PM access. |
| Initial dual/import | Existing actual dual funding/minimum/dead-share/full-range conversion; no single-token bootstrap. |
| Multi exact-in | Existing min-ratio/donation policy, no forced composition; holder maintenance afterward when idle; final full booking. |
| Exact-in share redemption/direct swap | Preserve user reference settlement; holder maintenance is permitted afterward, modeled in transition state. |
| Public repair | Bounded single-step economic repair per call, repeated calls unrestricted. |
| Idle exact-output | Only complete certified formula graph; external single-step domain plus placement-only/no-trade special cases. Otherwise `InvalidRoute`, with the limitation described accurately. |
| Blocked exact-output | Closed-form internal branches above; no external maintenance; unfunded currency cover fails atomically. |
| Native/WETH | Same branches in PoolKey order using WETH face, one wrap/unwrap boundary; no duplicate reserve entry. |

**Hooks:** No deployment whitelist or new administrator. Classify quote capability, not moral trust. Callback-free-for-relevant-actions pools with static fees are a mathematically valid neutral domain even if an initialize-only hook address exists. A callback flag is only a structural condition; arbitrary callbacks with economic effects require a genuine model. Existing Pons-style `launches` decoding is not proof arbitrary code with that ABI obeys the model.

For exact-in/public repair, retain and strengthen the known-model quote path only after independent production-hook tests establish fee directions, fee floors, callback state and actual-fill adjustments. For unmodeled effects, protected zap/public-repair quoting is unavailable rather than returned as vanilla truth; deployment itself is not forbidden. Do not silently strip existing direct-route support while changing the zap.

For exact-output, the two independently floored hook charges in QuoteService:56 are not a linear fee under integer arithmetic; their inversion and maintenance fee allocation need a separate closed-form proof. Dynamic fees and hooks changing liquidity are outside the currently derived external domain. **This report does not establish Pons/existing launch-consumer exact-output coverage**. That is a plan-freeze dependency if those consumers are required by the actual launch matrix; model it or escalate an actual support conflict, not a blanket hook rejection.

## 7. ABI, errors, state and execution safety

Keep all existing SE/SY/PoolKey/fee-oracle interfaces and PkgArgs. Add to the V4 liquid-reserve query interface/facet:

- `executionProtectionBps() -> (uint16 repair,uint16 composition,uint16 shortfall,uint16 alignment)`.
- `previewCombinedExactOut(address tokenIn,address tokenOut,uint256 amountOut) -> (uint256 amountIn,bytes32 branchId,bytes32 planHash)`; unsupported state reverts `InvalidRoute()` consistently with ordinary preview/execute.
- `rebalanceStatus() -> (uint256 proportionalityErrorWad,uint256 sleeveErrorWad,bool canProgress)`; no implication that a price-moving state between calls preserves the answer.

New local errors: `InvalidRoute()`, `AlignmentNotAchievable()`, `PriceImpactExceeded()`, `ExecutionShortfall()`, `TransitionMismatch()`, `OperationBudgetExceeded()`. Preserve existing exact deadline, caller, insufficient credit, min/max and local-cover errors. Unsupported structural/mathematical exact-output domains use `InvalidRoute`, not an arbitrary solver error. State changes between preview and execution may legitimately cause a protection revert.

Events: `ZapComposed(recipient,credit,spent,received,shares,retained0,retained1)`; `MaintenanceApplied(branchId,swapInput,swapOutput,liquidityBefore,liquidityAfter,rhoBefore,rhoAfter)`; `MaintenanceDeferred(reasonCode,rho,sigma)`. Existing rebalance event remains. These report amounts in PoolKey order and native raw units, not an invented NAV.

No persistent percentage/progress/turnover state. Add a transient context repo only for callback authorization and in-flight budget commitments, with a unique namespaced slot; clear it on successful exit (rollback handles revert). Each unlock verifies expected PoolManager, active vault workflow and hashed action payload. Arbitrary third-party unlocks cannot cause the vault callback to spend its inventory. Preserve outer reentrancy protection; use internal delegate execution for multi-actions, never reenter a guarded public method to solve the route. Route simulations never mutate the durable snapshot.

Execute a bounded batch inside one own unlock when idle, settling currency deltas before return. Native settlement retains `sync`, WETH unwrap, native settle and rewrap of taken currency as Common:1054–1075. At the end sync both expected token faces and existing protected self-share custody, after all refunds/payouts/maintenance. No new unbooked residuals.

## 8. Exact file work packages and verification

All following are **planned changes only**. No authorization to execute them is supplied by this research.

### WP0 — freeze proofs/support before dependent production edits

Write mathematical reference vectors for §5: two directions, single core-step boundaries, nonzero protocol/LP fees, own LP 0/partial/all, finite range, integer root/candidate failure cases. Establish a nonempty integer domain for each supported exact-output branch and characterize excluded domains honestly. Resolve existing launch-hook coverage and integer blocked single-exit inverse. Verify artifact identity/dependency pins and actual installed selectors. This is an evidence gate, not “implementer chooses later.” If incomplete, final plan status remains blocked on engineering proof.

### WP1 — V4-local pure planning/math components

Add under F: `UniswapV4FullSpreadTransitionTypes.sol`, `UniswapV4FullSpreadPlacementMath.sol`, `UniswapV4FullSpreadRepairMath.sol`, `UniswapV4FullSpreadClosedFormMath.sol`, `UniswapV4FullSpreadTransitionPlanner.sol`, `UniswapV4FullSpreadExecutionContextRepo.sol`.

Types hold attribution and bounded actions; placement owns new denominator/deadband; repair owns rho/sigma and permitted solver; closed-form library has no dependency on solver; planner selects branches. Do not alter CPMath's shared V3 semantics or Crane's port merely to fit V4 behavior. Reuse their pure primitives.

### WP2 — Common execution/accounting

Edit Common: `_targetFree`, snapshot/planner adaptation, operation payload, callback authorization, price limits, fee-separated liquidity accounting, batch execution, verification and final synchronization. Preserve `_secureTokenTransfer`/`_secureShareDelivery`/existing LocalCreditLib policy; extend tests rather than replacing these with economic totals.

### WP3 — all money routes

Edit InBase, InTarget, InExecutionDelegate; InMultiTarget; OutBase, OutExecuteTarget, OutExecutionDelegate; OutMultiTarget; LiquidReserveTarget; PositionImportTarget. Exact-output dispatch consumes the **combined plan**, with no subsequent `_rebalanceLiquidReserveBestEffort` call. Public and automatic allowed exact-in tails use the bounded repair planner. Import stays actual dual-funded converted full-range and receives final full-set sync.

### WP4 — quote/SY/consumer surface

Edit InMultiQueryTarget (ordinary preview), InQueryTarget (transition simulator), OutQueryTarget, OutMultiQueryTarget, QuoteService, interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol and LiquidReserveFacet selector declarations. Remove unqualified vanilla exactness for unmodeled protected paths. Ordinary and transition previews use identical branch IDs, fees, rounding and maintenance ordering.

Audit NativeStandardYieldTarget callers and existing transition-quote consumers; maintain existing SY selector append wiring. No DETF economics change, migration or new external price policy. A missing supported consumer is a release gate, not permission to quietly remove its advertised route.

### WP5 — package, factories and runtime identity

Edit F/DFPkg, I...DFPkg only if new facet/delegate references are necessary, and F/Component_FactoryService. Use dedicated CREATE3 execution/planner delegates for runtime size rather than enabling via-IR. Keep structs on interface and manager registry deployment. Use source-qualified artifact strings for every touched helper; dependencies and constructor delegates must be current. Existing occupied immutable CREATE3 identities cannot be overwritten; confirm fresh identities/versioned components in the planned manifest before any future deployment. No live rewiring is authorized.

### WP6 — concrete test suites

Extend F/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol. New specs under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v4/`:

1. `UniswapV4FullSpread_ZapComposition.t.sol`: unilateral repetitions, partial fill retained, post-swap B, 1 bp equality/+1 failure including flooring, no input subsidy, bootstrap negatives.
2. `UniswapV4FullSpread_RepairProgress.t.sol`: both directions; p=0/.2/1; absolute/relative band boundaries; placement-only progress; fee collection no-op still syncs; repeated calls same transaction; no reverse churn; no swaps after both thresholds pass.
3. `UniswapV4FullSpread_CombinedExactOut.t.sol`: each supported formula branch has nontrivial successful maintenance cases, exact output, max input, refunds and zero numerical-solver reachability. Cases requiring a tick/word crossing or unsupported hook fail truthful `InvalidRoute`; demonstrate formula domain rather than asserting universal nonexistence.
4. `UniswapV4FullSpread_ClosedFormReference.t.sol`: independent rational/interval reference, exact core rounding forward verifier, coefficient degeneracies/discriminants, integer endpoints; never compare the math library against itself.
5. `UniswapV4FullSpread_Attribution.t.sol`: own LP fees/protocol fees, prior E collection, partial donation/credit, liquidity rounding costs, hook deltas, pending payout exclusion, post-mint maintenance distribution.
6. `UniswapV4FullSpread_QuoteAndConsumers.t.sol`: ordinary preview, transition next-state, native SY, Multi, installed selectors and representative real buffered consumer under outer unlock. Do not claim arbitrary consuming hooks covered by one fixture.
7. `UniswapV4FullSpread_ZapAdversarial.t.sol`: price changes between bookings and claims; contract/EOA/constructor/7702 guard semantics; no booked re-credit; unclaimed surplus absorption; malicious callbacks/reentrancy; exact-in/out/blocked/idle cycles with independent trade-cost accounting; mixed 6/9/18 decimals, low-decimal rounding, native/WETH, residual sink claims.

Maintain existing release/v4, remediation delivery and preserved-source comparison suites. Preserve old source hashes. After separately authorized coding: artifact build before tests, default hermetic plus relevant fork parity, no new profiles/via-IR, runtime size <=24,576 bytes for deployed components. Record gas/work at maximum 32×64 solver effort; these are **proposed work bounds, not proven practical gas limits**. If they exceed target block budget, optimize the selected algorithm without silently weakening loss/protection or route requirements; plan must revise numeric work bounds explicitly before release.

## 9. Remaining blockers, facts versus proposals, confidence

**Owner economics now settled:** holder-funded maintenance, exact-output interleaving, combined closed-form-only, `InvalidRoute` for unsupported combined routes, pretransfer source-agnostic law, direct PoolManager, deployer hook assurance, repeated calls and full booking. Do not ask those again.

**Engineering proof blockers to a truly decision-complete final plan:**

1. Integer candidate completeness/domain and arithmetic bounds for §5.3/§5.5 and blocked dual-floor single exit. This report derives continuous forms and exact certification requirements, not their universal integer correctness.
2. Required production-hook/consumer matrix, especially separately floored Pons fees and any dynamic/caller-sensitive hook. No general exact hook quote mechanism is established by current code.
3. Gas and runtime-size feasibility of proposed bounded work; dependency/deployment identity pins. No tests/shell were available or authorized to establish these.

I recommend resolving these as a bounded pre-implementation proof/specification work package, not letting a coder select numerical fallbacks. If a required hook/route cannot satisfy D18 with an established formula, present its exact conflicting requirements and state domain to the owner. Lack of a proof in this pass is not proof that a closed form does not exist.

**Observed versions:** latest Z has D17–D19 and §6.4; Solidity config previously directly observed at `foundry.toml:29–36`: 0.8.35, optimizer runs 1, via-IR false. Local SwapMath pragma ^0.8.0 and comment “ported for 0.8.30” are not the compiler configuration. Exact dependency commit and deployed code pins remain unverified.

**External evidence:** Context7 first, `/uniswap/v4-core`, for swap/fee APIs; primary source fetched 2026-09-27: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol . Local matching mechanics: CraneV4/libraries/SwapMath.sol:52–105, including per-step floors/ceilings and exact-output sign; quoter:196–225 for protocol fee deduction and own-fee growth. Upstream main is not a deployment pin. No proprietary code was sent externally.

**Confidence:** high on current code inventory, owner requirements, sleeve algebra and the stated continuous single-step derivations; medium on selected solver/progress behavior; explicitly incomplete on universal integer/domain proofs, arbitrary hook coverage and practical gas. No safety, convergence, deployment readiness or successful test claim is inferred from this report.

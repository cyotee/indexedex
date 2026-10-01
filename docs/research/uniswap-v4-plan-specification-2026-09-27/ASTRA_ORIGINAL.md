# Astra — Concrete FullSpread implementation specification, independent original

**Date:** 2026-09-27. **Status:** council-authored engineering proposal for implementation-plan consolidation; not implementation or executed validation. No peer artifacts read in this round. No shell, tests, code/config edits, deployment, deletion or delegation.

## 0. Authority and selected design

The current user assignment controls where it advances the on-disk PRD: accept official Pons documentation plus graduated pools using the current hook as sufficient integration evidence; **remove runtime-bytecode equivalence as an additional gate**. Do not claim equivalence was proved. Use `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` and the canonical manager constant, without a new hook/codehash-selection questionnaire. Deprecate old code-linked PRDs, rather than reconcile them into current law.

Otherwise implement current PRD D1–D26: two separated families, caller-funded exact-in composition, proportional issuance, live sleeve percentage measured against deployed principal, fixed 25/50/10/1 bp, separate 1 bp maintenance mismatch, source-based exact-output eligibility, narrow route-preservation exception, full booking and gated legacy removal. No shared family dispatcher, no migration, no blanket exact-output ban.

**Read evidence:** CLAUDE.md; current task PRD §2/§3.1/§6.4/§8/§9; DETF alignment §24.7.1; canonical Crane architecture/testing and local IndexedEx testing skills directly; current FullSpread money/query/SY interfaces, source math and both complete legacy-directory file listings. Retained direct readings of deployment/salt guidance apply. Current user direction removes the earlier runtime-equivalence gate; it does not remove runtime funding, slippage or callback checks.

### Abbreviations

- **Z** = `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.
- **O** = `contracts/protocols/dexes/uniswap/v4/`.
- **F** = `contracts/vaults/standard/exchange/protocols/uniswap/v4/`.
- **U** = `contracts/vaults/standard/exchange/protocols/uniswap/`.
- **H** = `F/fullSpread/hookless/`; prefix **HP** = `UniswapV4FullSpreadHooklessStandardExchangeVault`.
- **P** = `F/fullSpread/ponsFamilyV2Hook/`; prefix **PP** = `UniswapV4FullSpreadPonsFamilyHook`.
- **CP** = `U/StandardExchangeConstantProduct.sol`.
- **C** = `lib/crane/contracts/protocols/dexes/uniswap/v4/`.
- Current F source suffixes below use prefix `UniswapV4FullSpreadStandardExchangeVault` unless written in full.

## 1. Exact operation definitions, source formulas and rounding

Use raw token units; do not convert assets into an oracle NAV. `S` is outstanding share supply; `B_i=D_i+F_i+E_i` is complete incumbent backing, excluding current caller credit. Deployed quantities are the exact finite-range CL quantities at the actual pool state; use the existing `SqrtPriceMath` rounding rules, not an infinite-range V2 substitute.

### Q0 — Bootstrap and dual input

Preserve CP:16–34 minimum/dead-share behavior: `raw=floor(sqrt(C0*C1))`; minimum is `10^(floor((dec0+dec1)/2)-3)` when mean decimals >=3, otherwise 1. Require actual positive funding in both tokens and raw>minimum. Mint minimum and pre-existing inventory's residual claim to the existing dead sink. No unilateral activation.

For live dual inputs, `m=min(floor(S*C0/B0),floor(S*C1/B1))` (CP:52–56). Multi inputs remain exactly both PoolKey currencies with positive amounts; excess is retained under the existing unbalanced-Multi policy. The composed-single deposit's 1 bp loss condition does not silently outlaw an explicitly unbalanced Multi join.

### Q1 — Blocked single-input issuance and its exact-share inverse

Preserve the integer CP same-book expression (CP:58–64):

```
K = ceil(sqrt(Bin*Bother))
A = floor(sqrt((Bin+c)*Bother))
m = floor(S*(A-K)/K), if A>K; else zero/revert for execution
```

One-backed-leg branches retain CP:49–51 linear math. For exact m, CP:78–95 gives:

```
Aneed = K + ceil(m*K/S)
c = ceil(Aneed*Aneed/Bother) - Bin
```

with its existing positivity/empty-book checks and linear `ceil(m*Bin/S)` when the opposite reserve is zero. Compute with existing full-width math. Exclude prepaid credit from pre-deposit reserves as current OutBase:53–61 does. That exclusion is correct attribution, not credit scaling.

The inverse is adopted **only for the internally settled blocked branch**, not as an idle external-composition substitute. Execute exact m and retain the inverse's rounding surplus, as its current contract specifies. Test the forward quote at c and c-1; no numerical search on exact-output.

### Q2 — Blocked exact-share redemption

Preserve CP:98–110:

```
u = floor(Bout*b/S)
v = floor(Bother*b/S)
out = u + floor((Bout-u)*v/Bother)       // second term zero if v=0
```

Require actual local output-token cover. This is internally settled burn-and-convert, not payout of only one proportional token leg. Reject full-supply burn when its current positive-other-leg domain rejects it; do not invent a final-exit conversion policy.

**Exact-output inverse selection:** for the single-backed-leg branch, `b=ceil(out*S/Bout)` is adopted. For positive backing in both legs, current CP `_sharesForSingleExit` (:113–128) is bisection; it is not adopted as a closed form. This specification does **not** adopt the speculative `UniswapV4FullSpreadClosedFormCandidate.sol` radical or its tests. The two-leg blocked exact-output redemption is `InvalidRoute`; its exact-in redemption remains available under Q2. This is a source-qualified availability decision, not a proof no closed-form inverse could ever exist.

### Q3 — Dual exact-output redemption

Adopt existing `_dualExitShareBurns` semantics:

`b0=ceil(o0*S/B0)`, `b1=ceil(o1*S/B1)`; require `b0==b1`, both outputs positive, b within delivered/max shares. Pay exact requested outputs. Idle route collects fees and removes the pro-rata `floor(l*b/S)` managed liquidity; funded local inventory may supply the remaining owed amounts. A shortage reverts; no supply clamp or short delivery. Blocked route uses local cover for both tokens and never unlocks.

### Q4 — External swaps and Pons fees

Use the current Crane V4 quoter/SwapMath forward semantics, including tick crossing, fee rounding, protocol-fee split and actual fill. Read fee state at the operation snapshot. The source quoter `C/utils/UniswapV4Quoter.sol:143–225` projects state and own LP fee growth; set finite work bounds, never `maxSteps=0` in new economic planning.

Hookless: core swap result is the user result. Pons: use the fixed admitted V2 hook's registered per-pool terms, not global policy. Let `h(n)=floor(n*hookFeeBps/10000)+floor(n*creatorTaxBps/10000)`. For exact input, net received is core output minus h(core output); for exact output, required input is core input plus h(core input). The fee is on the unspecified leg, matching `PonsV2MemeHook.sol:480–524`. Own LP fee recovery is **core LP fees only**, never the Pons charge or protocol fee.

**External exact-output source domain selected:** one core swap step without crossing its target boundary; static/known execution fee; initialized positive liquidity; actual Pons model above; total fee <1e6. Use `SwapMath.computeSwapStep`'s exact-output branch and `SqrtPriceMath.getNextSqrtPriceFromOutput`, not the variable tick-traversal loop as a claimed closed equation. In real-unit notation for token0-in/token1-out, `t=s-o/L`, net core input `L*(1/t-1/s)`; token1-in/token0-out has `t=L*s/(L-o*s)`, input `L*(t-s)`. Implementation uses Q96 helpers, input debt rounded up, output capped exactly, fee `ceil(netInput*f/(1e6-f))`. Determine the first bitmap step boundary and reject requests reaching/crossing it in this exact-output domain. Both initialized ticks and word-step boundaries matter for integer fee behavior.

This does not assert no closed form across multiple steps; it selects a concrete supported formula domain. Other exact-output external domains remain `InvalidRoute` in this plan, with exact-in forward evaluation retained.

### Q5 — Composed idle single-token deposit

For input amount c, simulate candidate gross swap x using Q4. Net caller basket is `(c-x, netSwapOutput)` in direction order. Incumbent B changes by exact own-position repricing and newly earned own LP fees, not by the caller principal. Find x satisfying post-swap min-ratio issuance and the 1 bp bound. Adopt bounded forward solving in §4; preserve exact-in support in both directions when a passing candidate is found. Do not substitute Q1 when idle alignment fails.

**Idle exact-share mint:** the current Q1 inverse is not applicable to Q5 and its holder maintenance. This plan does not pretend it is. Adopt no newly speculative inverse; idle token→exact-shares is `InvalidRoute` in this selected source-based plan. The same direction's exact-in deposit remains supported; D19 is not invoked simply to retain this old inverse. This is a deliberately explicit matrix entry, subject to tests establishing the selected formula domains—not an invitation for the implementer to swap in numerical inversion.

### Q6 — Idle exact-share redemption

Collect prior E; establish the user's pro-rata sleeve entitlement, remove `floor(l*b/S)`, convert its measured opposing removal plus entitled sleeve through Q4, and pay the selected output. Respect actual fill; any residual unused user entitlement remains accounted for under the route's defined retained-residual behavior, never available as new pretransfer credit. Minimum output protects the complete user result. Newly earned fees on the remaining position belong to remaining holders. Model those fees independently rather than adding every local balance increase to user output.

Idle shares→exact-single-token currently uses search in OutBase:64–118 and `_inventorySharesIn`; no applicable general non-search inverse is adopted here. Keep **linear/no-op conversion cases** when there is no opposing inventory and no position conversion: `b=ceil(out*S/Bout)`, with actual funding and placement domain below. Otherwise `InvalidRoute`; Q6 exact-in remains available.

## 2. Closed placement transition and concrete route/state/family matrix

### CPPlace — algebraic maintenance subset, not a universal repair proof

For known post-user-leg state, after collecting fees where idle:

`target_i=floor((D_i+F_i)*p/(WAD+p))`; `budget_i=D_i+F_i-target_i`.

Use `LiquidityAmounts.getLiquidityForAmounts` on both budgets and fixed ticks for the desired final liquidity. Evaluate rounded actual principal debt/removal with SqrtPriceMath. Never spend a reserved user payout/refund. Let `L0` be current own liquidity and `L*` the budgeted liquidity. For addition test `L*` and `max(L*-1,L0)` as a fixed rounding stencil; choose highest affordable. For removal use the direct difference to the target and compute exact rounded proceeds. No adaptive repeat or swap sizing is hidden in this operation.

The **combined CPPlace certificate** is the fully evaluated terminal state of the user formula plus this placement: it passes both normalized composition and sleeve thresholds, or it makes strict final progress under §4 with no remaining required amount/payout omitted. If placement is unnecessary, it is explicitly a no-trade branch with both thresholds passing. A result that needs a holder swap for any useful progress is outside CPPlace. A failed candidate is not silently treated as a successful combined quote.

Q4 single-step exact-output + own-fee update + reserved payout + CPPlace is a fixed finite composition of existing algebraic operations and rounding functions. This report selects that **certified combined domain**, not all vanilla swaps merely because LiquidityAmounts exists. No solver is reachable from the exact-output call graph.

### Matrix

Apply each row independently to token0 and token1. H/P share generic mathematical contracts; P's external swap output/input is transformed by h(n). Blocked internal settlement is unchanged by P's external hook because no hook is called.

| Public selector / route | Idle H | Idle P | Blocked H and P | Maintenance / error selection |
|---|---|---|---|---|
| `exchangeIn(token_i,c,share,...)` | Q5 bounded composition | Q5 with Pons net output | Q1 internally settled | Required composition/placement before mint idle; blocked external maintenance omitted by state constraint. Alignment failure reverts, no Q1 idle fallback. |
| `exchangeIn(share,b,token_i,...)` | Q6 | Q6 with Pons conversion charge | Q2 | Idle user settlement then one bounded holder-repair step. Blocked no unlock. |
| `exchangeIn(token_i,c,token_j,...)` | Q4 forward bounded steps | Q4+h | `InvalidRoute` for blocked external swap | Idle user swap then one bounded holder-repair step. |
| `exchangeOut(token_i,max,token_j,o,...)` | Q4 one-step + CPPlace certificate | Same, gross input includes h(core input) | `InvalidRoute` | Unsupported combined/multi-step domain rejected before funding. Exact-in sibling remains available; no D19 waiver solely to save exact-out. |
| `exchangeOut(token_i,max,share,m,...)` | `InvalidRoute` (no adopted applicable Q5 inverse) | Same | Q1 inverse | Blocked maintenance would otherwise remove both modes; preserve internally settled operations under state rule/D19. No missing inverse invented. |
| `exchangeOut(share,max,token_i,o,...)` | Q6 linear/no-op-conversion case + CPPlace only; otherwise `InvalidRoute` | Same; no hook charge when no external conversion | Linear Q2 inverse only; two-leg inverse `InvalidRoute` | Exact-in withdrawal remains available for all funded Q2/Q6 domains. No bisection fallback. |
| `exchangeInManyToOne([token0,token1],C,share,...)` | Q0 live/activation, placement, holder repair | Same with explicit P family operations | Q0, no unlock | Do not charge single-zap alignment loss to intentional unbalanced Multi input; fully book surplus. |
| `exchangeOutOneToMany(share,max,[token0,token1],O,...)` | Q3 + CPPlace when certificate passes; otherwise Q3 with documented D19 omission | Same | Q3 cover-or-revert | Shares→both-assets has no exact-in public counterpart. Requiring unavailable combined maintenance would eliminate all modes of this specific vector route; preserve its existing algebraic exact-out operation. Do not count inverse-direction Multi join as an alternative. Omission affects holder maintenance only, not required removal/fee settlement. |
| `importPosition(...)` | Actual dual delivery, convert full range, Q0 activation | Same, fixed Pons PoolKey required | Blocked error before import | Not an exact-output route. Retain NFT ownership/auth checks; public repair can follow productive placement. |
| `rebalanceLiquidReserve()` | §4 bounded repair | §4 P model | Interaction-blocked error | Mint/burn no user shares; final book/sync even if only fees collected. |
| Native SY `deposit/redeem` and previews | Exact same applicable `exchangeIn` semantics | Same, P family | Same blocked routes | No alternative formula, fee, share rounding or maintenance path. |

**D19 interpretation selected:** use it for blocked operations (external maintenance forbidden) and the existing exact-out-only vector redemption when unavailable interleaving would otherwise remove that entire vector direction. Do not apply it to idle single-token routes whose exact-in sibling is available with bounded repair. This is the concrete scope chosen for the plan; no runtime caller switch requests a cheaper nonmaintenance variant.

**Zero/unsupported assets:** preserve deadline/authorization checks; zero economic requests return zero in existing views where appropriate and fail money-path zero-amount guards. Nonpool token, reversed Multi ordering, duplicates, single-token Multi or unbalanced dual output is invalid. Unsupported formula/combined-domain requests use existing `IStandardExchangeErrors.InvalidRoute()` before pull, fee collection, share changes or unlock; user max/min/funding violations retain their distinct errors.

**Availability:** token lists describe directional asset support, not a promise for every amount or current funding state. Add per-family read-only `previewRouteStatus(tokenIn,tokenOut,amount,exactOutput)` reporting the selected branch/revert category; ordinary numerical previews and execution use the same evaluator. Do not advertise a numeric quote when that branch is unsupported.

## 3. Accounting sequence adopted for both separated implementations

Each family has its own workflow code; only pure hook-independent arithmetic/custody primitives may be reused.

1. Validate route/family/deadline/disable/caller guards. Determine formula eligibility and maintenance branch from pre-call book; for push quotes subtract available declared/prescribed credit from local totals so prepaid assets are not incumbents. Detect unsupported exact-output before economic actions.
2. Establish credit from existing LocalCreditLib and measured delivery. True exact-in credits declared input only; true exact-out credits capped declared/max availability and refunds credit-used; false exact-out pulls quoted used only. No provenance witness or excess-push rejection. Prior unclaimed surplus belongs to the book, not caller contribution.
3. Snapshot pre-operation S, current actual local F, principal D and fees E, plus caller budgets and pending output/refund liabilities. Quote and execution share this decomposition.
4. Collect existing fees when idle; E→F once. During blocked operations include E in backing, never spend it as local cover. Exclude pending user amounts from holder repair budgets.
5. Execute the selected user operation with actual deltas. For composition, capture only that swap's gross input and net output; independently re-read own D and fee growth. Own-price repricing and LP fee recovery update incumbents, not C. For payout reserve exactly what the route owes before repair.
6. Placement is a custody move, not new contribution. Determine add/remove principal with core math; collection fees remain holder property. Attribute marginal add rounding loss to new C for a deposit; holder removal/repair rounding costs remain in holder book. Check post-placement C/B issuance and alignment, then mint. Unknown/unreconciled discrepancies atomically revert `AccountingMismatch` rather than silently assigning them.
7. Holder maintenance after user share mint/burn belongs to the then-current shareholders. It cannot count as caller spending or mint extra shares. For composed exact-in deposits, do not add a holder-funded composition swap before proving caller alignment; required placement is already inside the mint workflow.
8. Complete refunds/payouts, wrap/unwrap only at native currency boundary, sync all expected held ERC20 faces and protected self-share custody. Re-read live local balances for durable snapshots. End-state equality must hold after success including no-op/fee-only maintenance.

Supply and token bookkeeping use existing FullSpread native units. Reuse CP's dead-share minimum, residual sink policy and existing Native SY context. `NativeStandardYieldTarget.sol:20–77` already routes SY operations/previews through SE; preserve that architectural parity. Do not propagate the baseline SY share-transfer/pretransferred=true path where an EOA would fail the contract-caller guard: perform its internal share move under the existing explicit active SY context and internal self-call with `pretransferred=false`, then burn exactly once. This is a parity correction for an adopted public interface, not a pretransfer-policy change.

## 4. Numerical rules, solver, progress and protection

### Share protection

For composed idle deposits with positive denominators, require both:

`m=min(floor(S*C0/B0),floor(S*C1/B1)) > 0`

`10000*m*B_i >= 9999*S*C_i` for i=0,1.

Use full-width product comparisons. No dust exception. Partial swap fills retain unspent caller tokens only if this condition passes. Tiny inputs may revert. Do not conflate this epsilon with maintenance rho.

### Maintenance metric selected

At actual post-action sqrt price s and fixed range endpoints a,b, per-unit requirements in real notation are `d0=1/s-1/b`, `d1=s-a`. Implementation evaluates their equivalent rational Q96 coefficients using full-width cross-products; it does not materialize rounded one-unit token amounts that may be zero.

For positive d0,d1: `X=T0*d1`, `Y=T1*d0`; `rho=abs(X-Y)/max(X,Y)`. Define rho=0 when X=Y=0. One-sided range boundary uses placement-only on the active leg; an inactive-leg inventory is residual and cannot be declared balanced by dividing by zero.

`target_i=floor(T_i*p/(WAD+p))`; `band_i=max(absoluteFloor_i,floor(target_i*5/100))`; `absoluteFloor_i=10^max(decimals_i-6,0)` preserving the baseline supported metadata behavior. Define `sigma=max_i(max(abs(F_i-target_i)-band_i,0)/max(T_i,1))`.

Stop trading when rho<=1/10000 and sigma=0. Always try CPPlace first. Compare repair candidates against this placement-only baseline, not a deliberately worsened funding-removal intermediate.

Selected progress ordering: lexicographic `(max(rho-1bp,0), sigma)`, with exact rational comparisons (reporting may round to WAD). A repair is useful if this pair strictly decreases after **all** fees and final placement; when starting within the composition band it must stay inside. This allows placement-only reduction of sigma when rho is unchanged; never accepts a trade that only improves an intermediate state. Tie-break: no swap, then lower input turnover, then smaller liquidity modification.

### Bounded exact-in/public solver selected

For composition evaluate caller input x against post-swap incumbent ratio using the family Q4 forward evaluator. Begin endpoints plus a half-input seed, then 32 sign-bracket bisection probes, ending with the two adjacent integer candidates. Choose maximal valid m then lowest gross swap input; if none meets 1 bp, revert alignment error. Bound each simulation to 64 core quote steps. No success claim from a truncated quote.

Public maintenance permits at most one economic holder swap per call, with a funding removal and final CPPlace. Evaluate both token directions using 32 bounded probes each within the 25 bp price boundary and actual holder budget. Select the best strictly improving terminal candidate. If none, no swap and truthful deferred/no-op result; fee collection still books. No cooldown, epoch, campaign or cumulative budget. Repeated immediate calls remain valid.

These work bounds are selected engineering parameters, not observed gas results. Verification may reveal implementation optimization is needed; it cannot silently relax approved loss/impact constraints or expand exact-output into numerical inversion.

### Fixed protections

Every family defines `REBALANCE_IMPACT_BPS=25`, `COMPOSITION_IMPACT_BPS=50`, `EXECUTION_SHORTFALL_BPS=10`, `DEPOSIT_ALIGNMENT_BPS=1`, `REPAIR_COMPOSITION_BPS=1`, no setters. Sleeve p stays live oracle policy, sampled per operation and consistently used by preview/execution.

Compare squared sqrt prices with full-width products so `max(Pafter/Pbefore,Pbefore/Pafter)-1 <= limit/10000`; price is not sqrt price. Each selected composition/repair leg enforces its limit; the complete repair leg includes any funding removal's effect on the actual swap liquidity. Existing user direct-swap/zap-out min/max protection remains; do not automatically impose the composition cap on every independent user trade.

For actual filled input, require net output >= `ceil(feeInclusiveQuotedOutput*9990/10000)`. Include core directional LP/protocol fee and Pons h exactly once. Exact-output primitive must fulfill exact requested output. Do not use a quote for a larger requested fill as the reference for a smaller actual fill. Quote/execute same-state parity remains exact for supported modeled paths; the 10 bp runtime guard is not a license for deterministic quote mismatch.

### Callback and ABI details

Reuse public money selectors. Add family diagnostic `executionProtectionBps`, `previewRouteStatus`, `rebalanceStatus`; expose no mutable adapter. Use a namespaced transient execution context committing active workflow, PoolManager, action plan hash and input/payout budgets. Callback requires configured manager and active matching context, not merely manager address. Keep external reentrancy guards. Direct calls to execution delegates must not access a diamond's custody.

Errors: reuse `InvalidRoute`, existing deadline/min/max/delivery/local-cover guards; add family `AlignmentNotAchievable`, `PriceImpactExceeded`, `ExecutionShortfall`, `AccountingMismatch`, `QuoteWorkLimit`. Events: retained caller basket/residuals, maintenance terminal rho/sigma and applied/deferred status. Events never replace balance/supply assertions.

## 5. Family files and permitted reuse — explicit set

For each prefix HP and PP create the following **separate family files** in its assigned directory (append `.sol`):

```
Common
DFPkg
_Component_FactoryService
InBase
InTarget
InFacet
InExecutionDelegate
InQueryTarget
InQueryFacet
InMultiTarget
InMultiFacet
InMultiQueryTarget
InMultiQueryFacet
OutBase
OutExecuteTarget
OutTarget
OutFacet
OutExecutionDelegate
OutQueryTarget
OutQueryFacet
OutMultiTarget
OutMultiFacet
OutMultiQueryTarget
OutMultiQueryFacet
LiquidReserveTarget
LiquidReserveFacet
PositionImportTarget
PositionImportFacet
PositionRepo
PoolKeyAwareRepo
PoolManagerAwareRepo
QuoteService
TransitionPlanner
ExecutionContextRepo
```

Additionally create `I<prefix>DFPkg.sol`; `interfaces/I<prefix>LiquidReserve.sol`; `test/bases/TestBase_<prefix>.sol`; and per-family decimal bases with suffixes `H6`, `H9`, `P6_R9`, `P6_R18`, `P9_R6`, `P9_R18`, `P18_R6`, `P18_R9` under `test/bases/`. `OutTarget` retains the public inheritance/constructor layout needed by its facet. `InQuery` remains transition simulation; `InMultiQuery` owns the ordinary preview selector, as current source does.

**Hook-independent reuse authored under H and imported by P:**

- `HPInventoryMath.sol`: pure complete-book arithmetic, funding exclusions, proportional/CPPlace coefficients, rho/sigma. No PoolKey hook, external calls or model dispatch.
- `HPProtectionMath.sol`: full-width bps/price/product comparisons only.
- `HPRouteTypes.sol`: enums/memory structs only, with no family dispatcher or dynamic adapter address.

These are genuinely hook-independent helpers, not a hidden Hookless execution delegate. Both family planners, QuoteServices, callback/settlement orchestration, targets and execution delegates remain separately compiled under their correct prefix. P does **not** inherit HPCommon, HPQuoteService, HPTransitionPlanner, HPLiquidReserveTarget or HPPositionImportTarget. Remove Pons parsing entirely from H; P must not use unknown-hook or hookless fallback.

Also reuse unchanged outside the removal roots: U/CP, Crane FullMath/Math/FixedPointMathLib, V4 SqrtPriceMath/LiquidityAmounts/SwapMath/StateLibrary/quoter primitives, generic ERC20/ERC2612/ERC5267 facets, MultiAssetBasicVault/StandardVault infrastructure, NativeStandardYieldTarget/Selectors/Context, LocalCreditLib, registry/factory and fee-oracle infrastructure. Pons reference tree and network constants are retained unchanged. Preserve the existing usage-fee policy ID/default cascade; renaming a Solidity type alone is not a reason to create a new economic fee domain.

Production H constructor binds canonical manager and no hook. Production P constructor binds canonical manager plus `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK`. Validate exact equality centrally before approvals; registered launch/token orientation and expected schema are checked at P initialization. `info[0]` is registration, not version. No runtime-codehash gate is added. Hermetic tests instantiate the actual family implementation with real local protocol fixtures via dedicated test construction bindings; no normal production PkgArgs setter can choose another manager/hook.

CREATE3 production component salts remain hashes of exact actual contract identifiers; no constructor/code hash or arbitrary family suffix salt. HP and PP names naturally distinguish components. Same occupied name returns existing bytecode; assert immutable delegates/dependencies on reuse. Instance salts continue through the package-address-bound DiamondPackageCallBackFactory; no global one-vault-per-pool restriction. Package deployment remains manager/registry controlled. No live action is authorized here.

## 6. Acceptance and interface parity — selected assertions

Use new family suite roots under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/`. For each family require:

1. `AdmissionAndIdentity.t.sol`: correct constant binding, wrong hook/manager/historical hook/same-flags impostor, registration/token order/native face, occupied CREATE3 names, proxy selectors/cuts, independent storage.
2. `FormulaDomains.t.sol`: every matrix cell, zero/one-leg/bootstrap boundaries, fee100% infeasibility, core-step exactout boundary, CP inverse forward(c)>=m and forward(c-1)<m, equal-ceil Multi output rule. Reject searched/inapplicable branches before balance effects.
3. `QuoteExecutionParity.t.sol`: at identical state exact equality of preview returned amount and execution; equality of transition nextState quantities, supply, holder shares, D/F/E, pool price/liquidity and net fees. No relative fudge when the same model predicts deterministic integer results.
4. `EquivalentInterfaces.t.sol`: native SY deposit == SE exact-in deposit; native SY redeem == SE share exact-in withdrawal including internal-balance mode; ordinary preview == corresponding transition/user route; helper/delegate/facet calling paths yield identical asset/supply outcomes. Same in-kind Multi and equivalent reference proportional settlement agree after mandated rounding. Do not require exact-in and exact-out Pons swap fees to be identical merely by reversing their amounts: the actual unspecified-leg rule differs; test each against its correct reference and in-kind interface wrapper.
5. `AttributionAndBooking.t.sol`: pretransfer before fee collection, donations underclaim absorption, caller-only composition, fee collection once, own LP/protocol/hook decomposition, actual local snapshots after every success and no effects after revert, exactout refund caps, no false-pull-max-refund.
6. `ZapAndPlacement.t.sol`: repeated unilateral deposits, net basket retained/deployed entitlement, one-bp floor bound at equality/+1, 6/9/18 units, p=0/.2/1 live fallthrough, placement residuals/dust, initial and imported actual dual funding.
7. `MaintenanceProgress.t.sol`: placement preferred, terminal improvement including costs/own fee recovery, one-step incremental repair, no trade when both bands pass, same-block repeated calls, no fees-from-pointless roundtrips, funded-removal budget correctness.
8. `NestedAndConsumer.t.sol`: real outer unlock and real buffer consumer, funded blocked deposits/redemptions, correct requested-token cover and no nested unlock, current DETF/transition-rate-provider consumers against both admitted integrations.
9. `Adversarial.t.sol`: cross-mode cycles, EOA/contract/constructor/delegated account pretransfer semantics, reentrant hook/token, wrong callback context, unpaid deltas, late min failure rollback, disable inbound versus exits, initial donation/sink shares, price movement between booking and claimed input.
10. `RuntimeAndWork.t.sol`: actual deployed facet/delegate/package runtime <=24,576 bytes, compiler 0.8.35/optimizer1/no via-IR; bounded 32×64 worst-case work recorded. No mocks of manager/registry/vault/facets/fee oracle/PoolManager.

P-specific acceptance includes real registered Pons swaps, both directions and both raw/native faces; separate floor charges; changing global hookFeeBps does not change old launch rates; creator/buyback updates do not alter swapper charge rates; fee sweeps may alter market state and are modeled as external transitions. Core directional protocol fees remain included and may vary between operations.

**Evidence accepted as assigned:** official documentation/current-stack hook and graduated pool usage suffice for integration selection. Tests validate this implementation against the selected model. The handoff explicitly says deployed-runtime equivalence was not independently proved and is not an additional pass/fail gate. No new live RPC proof is required by this specification.

## 7. Exact legacy manifest — inspected file listings

Inspection returned **49 files under O** and **38 files under F**, including one unrelated `.DS_Store` and one unadopted candidate. The new H/P subdirectories are retained even if still empty at this snapshot. The manifest below names every observed file; newly created files are not swept implicitly. Apply dispositions only after the readiness gate.

### 7.1 O — remove these 44 Solidity files after porting required coverage/consumers

Relative to `contracts/protocols/dexes/uniswap/v4/`:

```
IUniswapV4StandardExchangeDFPkg.sol
UniswapV4_Component_FactoryService.sol
UniswapV4PoolKeyAwareRepo.sol
UniswapV4PoolManagerAwareRepo.sol
UniswapV4PositionRepo.sol
UniswapV4QuoteService.sol
UniswapV4StandardExchangeCommon.sol
UniswapV4StandardExchangeDFPkg.sol
UniswapV4StandardExchangeInBase.sol
UniswapV4StandardExchangeInExecutionDelegate.sol
UniswapV4StandardExchangeInFacet.sol
UniswapV4StandardExchangeInMultiFacet.sol
UniswapV4StandardExchangeInMultiQueryFacet.sol
UniswapV4StandardExchangeInMultiQueryTarget.sol
UniswapV4StandardExchangeInMultiTarget.sol
UniswapV4StandardExchangeInQueryFacet.sol
UniswapV4StandardExchangeInQueryTarget.sol
UniswapV4StandardExchangeInTarget.sol
UniswapV4StandardExchangeLiquidReserveFacet.sol
UniswapV4StandardExchangeLiquidReserveTarget.sol
UniswapV4StandardExchangeOutBase.sol
UniswapV4StandardExchangeOutExecuteTarget.sol
UniswapV4StandardExchangeOutExecutionDelegate.sol
UniswapV4StandardExchangeOutFacet.sol
UniswapV4StandardExchangeOutMultiFacet.sol
UniswapV4StandardExchangeOutMultiQueryFacet.sol
UniswapV4StandardExchangeOutMultiQueryTarget.sol
UniswapV4StandardExchangeOutMultiTarget.sol
UniswapV4StandardExchangeOutQueryFacet.sol
UniswapV4StandardExchangeOutQueryTarget.sol
UniswapV4StandardExchangeOutTarget.sol
UniswapV4StandardExchangePositionImportFacet.sol
UniswapV4StandardExchangePositionImportTarget.sol
interfaces/IUniswapV4StandardExchangeLiquidReserve.sol
test/bases/TestBase_UniswapV4StandardExchange.sol
test/bases/TestBase_UniswapV4StandardExchange_Decimals.sol
test/bases/TestBase_UniswapV4StandardExchange_H6.sol
test/bases/TestBase_UniswapV4StandardExchange_H9.sol
test/bases/TestBase_UniswapV4StandardExchange_P6_R9.sol
test/bases/TestBase_UniswapV4StandardExchange_P6_R18.sol
test/bases/TestBase_UniswapV4StandardExchange_P9_R6.sol
test/bases/TestBase_UniswapV4StandardExchange_P9_R18.sol
test/bases/TestBase_UniswapV4StandardExchange_P18_R6.sol
test/bases/TestBase_UniswapV4StandardExchange_P18_R9.sol
```

Disposition: implementation-specific source is replaced by exact family-prefixed counterparts in §5. Test bases' behavior is ported to both applicable family bases, not preserved as a legacy deployed SUT requirement after deletion. The manager/key repos are simple vault dependency stores, not the canonical V4 core; no standalone generic protocol implementation must be moved out of O. A direct contracts search found outside-O dependency on the old FactoryService in `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol:95`: replace with explicit H/P factory selection based on its fixture/route PoolKey, never a new shared execution dispatcher.

### 7.2 O — deprecate and retire these five historical documents

```
UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_PRD.md
UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md
UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md
UNISWAP_V4_STANDARD_EXCHANGE_LOCAL_LIQUID_BUFFER_IMPLEMENTATION_AND_TEST_PLAN.md
UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md
```

Mark DEPRECATED before gate with current Z/family-spec pointers; at removal retire active copies and retain their exact historical text/revision in a dated docs archive/evidence record. Do not reconcile percent-of-total/no-swap/old bootstrap clauses into new product law.

### 7.3 F — remove these 36 Solidity files after replacement readiness

Relative to `contracts/vaults/standard/exchange/protocols/uniswap/v4/`:

```
IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadClosedFormCandidate.sol
UniswapV4FullSpreadStandardExchangeVault_Component_FactoryService.sol
UniswapV4FullSpreadStandardExchangeVaultCommon.sol
UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol
UniswapV4FullSpreadStandardExchangeVaultInBase.sol
UniswapV4FullSpreadStandardExchangeVaultInExecutionDelegate.sol
UniswapV4FullSpreadStandardExchangeVaultInFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInMultiTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultInQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultInTarget.sol
UniswapV4FullSpreadStandardExchangeVaultLiquidReserveFacet.sol
UniswapV4FullSpreadStandardExchangeVaultLiquidReserveTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutBase.sol
UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutExecutionDelegate.sol
UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutMultiTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutQueryFacet.sol
UniswapV4FullSpreadStandardExchangeVaultOutQueryTarget.sol
UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol
UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol
UniswapV4FullSpreadStandardExchangeVaultPoolManagerAwareRepo.sol
UniswapV4FullSpreadStandardExchangeVaultPositionImportFacet.sol
UniswapV4FullSpreadStandardExchangeVaultPositionImportTarget.sol
UniswapV4FullSpreadStandardExchangeVaultPositionRepo.sol
UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol
interfaces/IUniswapV4FullSpreadStandardExchangeVaultLiquidReserve.sol
test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol
```

The candidate file is **unadopted legacy experimental source**, not a repair target or selected equation. Retire it and its candidate-only consumers at the gate without inventing a code fix; preserve any relevant diagnostic observation as historical, not test evidence.

### 7.4 F — deprecate/preserve dispositions

- `UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md`: deprecate as a current V4 law source; archive its historical contents/revision when removing legacy source. Parent V3/shared-remediation docs linking it receive a historical pointer plus a link to still-applicable shared accounting reference, without changing V3 economics.
- `.DS_Store`: unrelated filesystem metadata; **preserve/out of removal scope**, not part of a vault-source deletion operation. Do not parse it as source or make it a document target.
- `fullSpread/hookless/**` and `fullSpread/ponsFamilyV2Hook/**`: **preserve completely**. Never recursively delete F.
- `U/StandardExchangeConstantProduct.sol`, parent README, shared-remediation and V3 companion files are **outside the two removal roots**: preserve. Update active pointers in parent README/shared docs to new families and mark V4 legacy portions deprecated; do not delete shared V3 law/math. Preserve dated source maps/hash evidence without rewriting old hashes as if they described new sources.
- All `lib/crane/contracts/protocols/dexes/uniswap/v4/**`, Pons reference sources and `ROBINHOOD_MAIN.sol`: preserve unchanged by removal.

### 7.5 Reference rehome rules and external consumers

No generic Solidity implementation currently listed inside O/F needs relocation as an unchanged standalone contract: family-specific implementations are replaced and genuinely shared primitives already live outside. Rehome still-needed **behavior** into the corresponding family file, and generic pure math into the three H libraries in §5. Do not leave forwarding imports at the old paths after removal.

Port outside-root `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol` to a P-family test base/consumer of real P fixtures; its old inheritance cannot remain. Source references in `UniswapV4DetfProductionSeDeployLib.sol` use H for hookless and P for the fixed current-stack hook. Existing protocol-tree Pons tests and unsegmented `release/v4`/`remediation` tests retain security assertions in the new family test suites; candidate-only parity tests are archived/retired, not prerequisites. Pure shared CP tests remain on CP and are reused.

Before applying the finite removal list, the implementation phase performs a deterministic reference check over maintained contracts/tests/scripts/interfaces/artifact strings and updates each old type reference to its corresponding H/P family. A test genuinely about old behavior is archived with the old revision, not compiled against deleted symbols. Script/source wiring changes prepare new artifacts only; no broadcast, live registry disablement or deployed-instance retargeting follows. This dependency-closure check is a verification task with fixed disposition rules—not permission to add files to the removal list blindly.

## 8. Phased handoff and final acceptance

**Phase 0 — record this specification:** publish chosen matrix/Q0–Q6/CPPlace, both component sets, accepted Pons evidence and 87-file manifest. Explicitly supersede runtime-equivalence gating and old-PRD reconciliation language under the current human instruction. Do not execute deletion.

**Phase 1 — H implementation:** implement pure math, accounting/state separation, bounded solver, certified source-domain exact-output branches, selectors/SY/quotes and real tests. All eligible Q1/Q3/single-step domains need at least one successful reference case; no green suite produced by rejecting all requests.

**Phase 2 — P implementation:** distinct fee/quote/execution/maintenance files, fixed singleton admission, Pons h(n) semantics, generic reuse only as enumerated. Build both package/factory paths with versioned exact names and unchanged fee policy.

**Phase 3 — parity/consumer/regression closure:** run all listed tests, independence/funding invariants, cross-interface parity and both state modes. Record commands/source/artifact/toolchain and measured maximum work/runtime size. Failure of an adopted formula means correct the implementation or explicitly revise this council specification; it does not authorize silently substituting bisection or changing ownership.

**Phase 4 — audit-submission readiness checkpoint:** both implementations and applicable tests pass; consumer import closure and finite deletion manifest reviewed; artifact identities and preserved-history references recorded. No bytecode-equivalence gate is added. Readiness is not audit completion or a security guarantee.

**Phase 5 — gated removal and final validation:** apply only listed obsolete vault/code/doc dispositions, preserve H/P and outside-root shared infrastructure, refresh required runtime artifacts, rebuild and rerun replacement/consumer suites. Final audit submission points to the post-removal revision and its executed results, never just pre-removal green output.

## 9. Confidence, evidence boundaries and remaining risks

This report **selects** executable domains, equations, ordering, metrics, component/reuse boundaries and exact file dispositions. It does not delegate those choices back as an owner questionnaire. Its restricted exact-output domain is intentional and documented; it is not proof no wider formula can exist. Existing core one-step math + explicit state/funding/placement certificate is the adopted combined algebraic subset; a liquidity helper or one unlock alone would not establish it.

Derivation confidence is high for CP source formulas, Pons's separate floors, one-step core swap equations and share-loss comparisons; medium for complete workflow attribution/placement certificates until independent tests exercise the integer boundaries. The D19 vector-route omission is an explicit interpretive choice in this proposal and must be reviewed in consolidation, not left to a coder. It preserves the existing sole vector-output interface without inventing an exact-in alias or exact-output formula.

Potential measured solver cost, runtime-size pressure and unusual token metadata behavior are test risks, not an invitation to alter fixed policy. No compilation or successful test result is claimed. The unadopted candidate's presence is not validation. No runtime-bytecode equivalence claim is made; that extra gate is removed per current instruction.

Context7 `/uniswap/v4-core` was queried before external API claims about SwapMath. Local authoritative evidence includes `C/libraries/SwapMath.sol:52–105`, `C/libraries/LiquidityAmounts.sol:48–77`, quoter:143–225, CP:16–128, F/InMultiTarget:11–31, F/OutMultiQueryTarget:16–79, and `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–77`. Context7 returned both current API snippets and an older audit excerpt; the current local implementation, not the historical audit fragment, governs fee-boundary details here. Prior directly fetched primary source: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/SwapMath.sol (accessed 2026-09-27). Compiler baseline observed in retained direct reads is 0.8.35, optimizer runs 1, via-IR false. Upstream main and repository source are not deployment-equivalence proofs.

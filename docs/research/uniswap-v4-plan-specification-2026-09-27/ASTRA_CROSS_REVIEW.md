# Astra — Adjudicated implementation specification

**Date:** 2026-09-27. One combined cross-review. Read Grok, MiniMax and Kimi originals completely, including MiniMax's continuation after tool truncation. No peer cross-review read. All originals remain unchanged. No shell, tests, code/config edits, deletion or delegation.

This report supplies a concrete replacement matrix and arithmetic where the originals disagree. It retains my original's explicit family/component and file manifests except for the corrections below. It does not adopt new speculative closed-form candidates by vote. Pons identity evidence remains accepted as instructed; **no runtime-bytecode equivalence gate is reintroduced**.

## 1. Decisions adopted and corrections to my original

1. **Adopt existing source-applicable formulas, not Grok E6 or Kimi DER-1..4.** Their continuous derivations/forward checks do not establish the required integer inverse, and their proposed fallback mechanisms either omit required semantics or numerically solve the route.
2. **Retain bounded solving for exact-in composition and public repair**, with terminal exact checks. A 32-probe budget is not a guarantee of an adjacent-integer bracket or a 1 bp root.
3. **Tighten my original CPPlace certificate:** an exact-output branch is certified only when its entire projected transition, including exact fees, payouts and rounded placement, finishes with **both** maintenance thresholds satisfied. The earlier “or merely makes progress” alternative is withdrawn for this finite algebraic exact-output subset. Public/exact-in repair still permits incremental progress.
4. **Withdraw my original idle-vector D19 shortcut.** An exact-in vector-output selector that never existed cannot be counted as an independently available mode eliminated by maintenance. Keep idle dual exact-output only under the complete certificate below; otherwise `InvalidRoute`. Blocked funded dual output remains supported by the explicit state rule.
5. **Correct error ABI:** reuse `IStandardExchangeErrors.InvalidRoute(address tokenIn,address tokenOut)` from `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol:25`, not `InvalidRoute()` or an invented reason overload. For a structurally valid two-output vector whose formula branch fails, use the share input and first requested output token; richer diagnostics belong in the status query.
6. **Add the source-supported Pons core-LP-fee check:** `PonsV2LaunchFactory.sol:1485–1498` explicitly rejects `config.poolFee != 0`. This is now verified directly; it is not an inference from a fixture. Pons directional **protocol** fee must still be read and applied.

### Paths

**Z**: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md`.
**F**: `contracts/vaults/standard/exchange/protocols/uniswap/v4/`; F source suffixes use `UniswapV4FullSpreadStandardExchangeVault`.
**CP**: parent `StandardExchangeConstantProduct.sol`.
**C**: `lib/crane/contracts/protocols/dexes/uniswap/v4/`.
**O**: `contracts/protocols/dexes/uniswap/v4/`.

## 2. Rejected arithmetic and sequencing, with evidence

### Grok radical inverse is not an integer inverse

CP:98–110 executes:

`Q(b)=u+floor((X-u)*v/Y)`, with `u=floor(X*b/S)`, `v=floor(Y*b/S)`.

The real-valued simplification `X*(2b/S-(b/S)^2)` drops two economically relevant floors. Even a correctly rounded real inverse followed by two checks does not cover its integer inverse.

**Hand-checkable counterexample:** X=Y=100, S=1000, requested output=1. The real inverse is approximately 5.01256 shares, so its ceiling is 6. Q(6)=Q(7)=0 because both entitlements floor to zero. The first sufficient integer input is b=10: Q(10)=1+floor(99/100)=1. No tests were needed or run to establish this arithmetic example.

Grok's E6 fails at its intended two-candidate coverage claim even if its unspecified fixed-point `sqrt_up` were implemented favorably. Using the same E6 for an **idle** external pool conversion is additionally wrong: that route depends on post-removal external liquidity, price, core fee and Pons charge, not the same-book internal curve.

Kimi DER-1's `while forward(s)<out: s++` / downward correction are numerical inverse search. An analytic seed does not exempt that search from D17/D18. Neither algorithm is adopted. General two-leg single-output exact-out remains unsupported under this source selection; CP's forward exact-in route remains available.

### Kimi DER-2..5 do not establish new exact-output eligibility

- DER-2 does not correctly expose the active pool liquidity reduction caused by the vault's pro-rata liquidity burn in its stated coefficients. The actual remaining pool liquidity is a function of shares burned, not a fixed pre-removal coefficient.
- DER-3 solves the output-ratio equation before including the Pons output multiplier and integer cuts, then adjusts proceeds afterward. That does not generally solve the Pons equation it claims to solve.
- DER-4's displayed post-swap inventories omit the separately recovered own-LP fees; its gross-output expression also omits Pons net output. Continuous quadratic structure without those terms is not a complete maintenance quotation.
- DER-5 may motivate a future exact-in seed, but its undeclared coefficients and general monotonicity assertions are not required or adopted. Use actual forward simulation and final protection checks for permitted bounded solving.

These are source/semantic objections, not claims that useful new formulas cannot exist. This plan follows Z:209–214 and does not create a DER-repair workstream.

### Tick walking is not automatically a closed form

`C/utils/UniswapV4Quoter.sol:172–175` loops over state-dependent steps. It is an execution evaluator, not root bisection, but neither “finite” nor “each step is algebraic” establishes the closed-form complete route required here. Adopt the explicit **one-core-step** domain below. Do not relabel `maxSteps=0` as a bounded policy. A future explicit finite-segment formula could be reviewed separately; none is assumed here.

### Correct ordering

Grok's composition → mint → placement ordering violates D4 and Z:171–177. Adopt:

**establish credit → collect prior fees → composition → allocation → attribution/loss check → mint → full final booking.**

The baseline already establishes credit in InTarget:67–70 before InBase:277 collects fees. MiniMax's original does not actually provide a complete collect-versus-credit ordering; I do not invent a quotation assigning it one. Any collect-before-credit interpretation of its fee-first overview is rejected: incoming fees would otherwise enter local unbooked availability before caller credit is fixed.

Prepaid input is excluded from incumbent reserves, as OutBase:53–61 explicitly specifies. That subtraction must not be deleted or defaulted to zero for true pretransfer.

### MiniMax equations and policy errors

- CP `_amountInForShares` is not a generic `numerator/denominator+1` swap inverse. Its actual expression is `ceil((K+ceil(m*K/S))^2/Bother)-Bin`, with K=ceil(sqrt(Bin*Bother)); CP:67–95.
- CP `_singleExit` divides its conversion term by original `reserveOther`, not `reserveOther+entitlementOther`; CP:103–109. It models blocked internal settlement, not idle external conversion.
- Pons charge is **sum of two floors**, not floor of the summed rate. Example: unspecified amount=50, rates=100 and 100 bps: separate cuts are 0+0, combined floor is 1. Preserve the source.
- 2000 bps is **20%**, not 0.2%. Fee ceilings do not fit automatically inside a 10 bp execution-shortfall allowance; the quote includes the intended fees.
- Raw-token `T_i/(T0+T1)` targeting 50/50 is neither decimal-safe nor D21's current-price finite-range composition objective. Do not offer metric variants to the implementer.
- Public swap repair is required by D9; it is not disabled by the exact-output restrictions. The old blanket combined-route prohibition has been superseded.
- No single-token bootstrap is introduced, no Multi leg may silently become zero, and measured execution alone is not proof of preview equality.

## 3. Complete algebraic placement certificate — selected exact-output subset

This replaces my original's looser CPPlace paragraph. The certificate is an explicit finite formula graph, not a call to the public repair solver.

### Inputs and domain

Inputs: PoolKey, slot0, active pool liquidity, own position liquidity l and full-range ticks, local balances, fee-growth checkpoints, share supply, live sleeve p, requested output and caller limits. All are the same snapshot used by preview and execution. Admit only the family's fixed hook/manager model. Core LP/protocol fees and Pons per-launch cuts are modeled; no unknown hooks. Arithmetic, liquidity-delta signed bounds and current tick liquidity caps must be representable and valid.

For the external exact-output primitive, require positive active liquidity, fee<1e6 and a target sqrt price **strictly inside the first core step**, including the current bitmap-word boundary, not merely before the next initialized liquidity change. Compute with `SwapMath.computeSwapStep` exact-output branch (`C/libraries/SwapMath.sol:88–105`): rounded-up input debt, exact requested output, rounded-up core fee. No core-step loop is used to size an exact-output route.

### Fixed graph

1. **Freeze caller credit before collection.** Preview excludes declared/prepaid input from incumbent backing. False-flag exact-out will pull the computed used amount only; true-flag availability is separately validated and unused credit reserved for refund.
2. **Project prior fee collection exactly.** If own l>0, E_i=`floor((growthInside_i-last_i)*l/2^128)` transfers into F_i once and checkpoints update. If l=0, no invalid zero-liquidity poke is manufactured.
3. **Evaluate the source user leg completely:** one-step external exact-output swap, proportional dual output, or the adopted linear share redemption. Include required pro-rata removal if any. Reserve output and refunds and remove their economic claims from the book on which maintenance is planned. Pending payment is never a holder swap/placement budget.
4. **Project new own LP fees exactly.** For a one-step swap, derive core fee amount and its directional protocol deduction, then `deltaGrowth=floor(lpFeeAmount*2^128/activeLiquidity)` and own earned fee from the appropriate current own-liquidity checkpoint. This follows quoter:214–225. Add neither protocol fees nor Pons charge to E. Pons input debt for an external exact-out swap is core input plus its two unspecified-input cuts.
5. **Project fee collection after the user leg** where needed for placement. Let `T_i=D_i(l,q)+F_i+E_i` of the residual holder book, with pending liabilities already excluded; after collection E_i=0 and F includes those fees. Compute `target_i=floor(T_i*p/(1e18+p))`, `budget_i=T_i-target_i`.
6. **Choose final liquidity without search:** `l*=LiquidityAmounts.getLiquidityForAmounts(q,a,b,budget0,budget1)`. Evaluate candidate l*; for an addition also evaluate `max(l*-1,l)` as a fixed safety alternative if the first candidate's exact rounded debt is unaffordable. If the computed target is below l, evaluate that removal target directly. Never repeatedly decrement/increment until feasible. Choose the highest-liquidity candidate that satisfies all certificate predicates. Include the unchanged-l candidate only when final thresholds already pass.
7. **Evaluate actual integer principal settlement**, not merely `D(l*)-D(l)`: for positive delta use the core `SqrtPriceMath` amount deltas rounded up; for negative delta use them rounded down. Update local balances by those debts/credits and set own liquidity to the candidate. Recompute D at q from the resulting position and recompute targets/deadbands from the resulting exact book. `SqrtPriceMath.sol:264–289` shows these signed rounding rules. The chosen Pons hook has no liquidity-return-delta callbacks.
8. **Certificate predicate:** all intermediate settlement budgets and reserved liabilities funded; exact requested user output, maximum input, applicable protections and share equations satisfied; final local balances nonnegative; supply/position/currency deltas reconciled; and **terminal rho<=1 bp and terminal sigma=0** using §5 below. Thresholds are checked after the complete user operation and placement, not merely at entry. Any required rounding costs are attributed as specified, not booked as a gain.
9. The projected terminal state/amounts and the action list are the combined quote. Execute that fixed list and compare actual terminal quantities. Mismatch reverts atomically. No post-quote public repair call, numerical “rescue,” or changed fee formula is permitted.

This is an exact specified finite transition with an explicit supported-state predicate; it does not claim to reach policy from every state. It can be nonempty—for example, a sufficiently small direct swap on a well-funded, initially balanced large vault whose repriced final inventory remains inside both bands requires no holder trade. Algebraic add/remove placement extends that subset. A release test must demonstrate successful nontrivial placement cases, not only empty amounts or universal rejection.

If no candidate passes, the combined certificate is unavailable. Apply the matrix and D19 below; do not call that failure mathematical nonexistence of all possible combined formulas.

## 4. Adjudicated directly adoptable matrix

Abbreviations: **EI**=`exchangeIn`, **EO**=`exchangeOut`, **MI**=`exchangeInManyToOne`, **MO**=`exchangeOutOneToMany`; **CC**=complete certificate above; **BR**=bounded exact-in/public repair; **I**=`InvalidRoute(tokenIn,tokenOut)` before funding. Apply directions symmetrically and independently to both families; P uses the actual two-floor fee transform on external legs.

| Direction/interface | Idle Hookless/Pons | Blocked Hookless/Pons | Maintenance / D19 disposition |
|---|---|---|---|
| EI token_i→token_j | Core exact-input forward evaluation, with P net-output cuts | Interaction-blocked rejection; no invented sleeve direct swap | Idle BR tail; no exact-output formula requirement for this EI route. |
| EO token_i→token_j | One-core-step exact-output equation **and CC**; otherwise I | I | No omitted idle maintenance; EI sibling exists with BR, so D19 does not save a failed EO branch. |
| EI token_i→shares | Caller-funded composition, allocation, min-ratio mint and 1 bp bound | Existing CP invariant-growth/linear branches | Idle deposit order is fixed; blocked external maintenance cannot occur. |
| EO token_i→shares | I: no adopted source inverse of the required external-composition/issuance route | Existing CP `_amountInForShares` within domain | Blocked operation survives without external interleaving under §4/§6.4 state constraints. No idle fallback to the blocked equation. |
| EI shares→token_i | Pro-rata sleeve + rounded position removal + external conversion, P fee on that conversion | Existing integer CP `_singleExit` with local cover | Idle BR after user entitlement; blocked no unlock. |
| EO shares→token_i | Only source-linear/no-op-conversion branch **and CC**; otherwise I | `ceil(out*S/Bout)` when other backing is zero and cover holds; positive two-leg inverse I | Do not adopt radical+checks or bisection. EI remains available; no general idle D19 exemption. |
| MI [token0,token1]→shares | Existing positive dual bootstrap/min-ratio join; placement/BR as applicable | Same dual accounting, local only | No single-token Multi alias; retain intentional dual surplus. |
| MO shares→[token0,token1] | Equal-ceiled-share-burn source equation **and CC**; otherwise I | Same algebraic share requirement, both local covers | **Correction to Astra original:** absence of a vector EI selector is not evidence that interleaving eliminated an available EI mode. No idle-vector D19 exception is asserted. |
| SY deposit/redeem | Exact corresponding EI operation | Exact corresponding EI operation | Same amounts, fees, storage, liabilities and maintenance; no second share model. |
| importPosition / activation | Actual dual funding, approved full-range conversion and sink/minimum policy | Imported unlock-dependent operation rejects | Not an exact-output eligibility shortcut. |
| public rebalance | One bounded useful holder-swap/placement step; immediate repeats allowed | Interaction-blocked rejection | D9/D21 fully implemented, not limited to add/remove. |

### D19 rows, explicitly

- **Blocked funded token→share and share→token/vector routes:** mandatory external maintenance would violate the no-nested-unlock rule and remove funded sleeve functionality. Omit external interleaving under the explicit state-preservation rule; applying D19 yields the same documented result. The operation must still have its own applicable equation, so the missing two-leg exact-output inverse remains I.
- **Idle scalar routes:** EI remains available with bounded repair, so lack of a combined EO quotation cannot trigger the both-modes exception. EO outside CC is I.
- **Idle vector output:** do not invent an EI counterpart or infer both-mode loss merely from its absence. MO outside CC is I in this conservative source-only matrix.

Grok's assessment across “at least one interaction state” is invalid: Z:220 requires the **same** direction/family/state. Its ordinary “no combined form, therefore omit maintenance and support EO anyway” is not the narrow exception. MiniMax's blanket combined-route release disablement is obsolete; Kimi's newly derived branches are not adopted as a route-preservation workaround.

The vector row is a deliberate correction of my earlier overbroad exception—not a hidden coder option. If the owner intended the exception to include sole-exposed-mode interfaces, that would require a targeted clarification of “both modes”; the plan above can be implemented without inventing that interpretation.

## 5. Fixed arithmetic and bounded work

### Share and price checks

Retain full-width comparison `10000*m*B_i >= 9999*S*C_i` for each positive composed contribution leg. Do not use Kimi's dimensionally incomplete `1-mulDiv(...)` expression without its scale, nor multiply S*C unchecked before mulDiv. Do not imply `mulDiv` automatically makes a three-factor product safe.

Impact: `10000*max(q0,q1)^2 <= (10000+limitBps)*min(q0,q1)^2`, for 25 bp repair and 50 bp composition. Use wide products; a 160-bit sqrt squared exceeds uint256. Kimi's absolute relative-to-start difference underprotects one direction compared with the approved reciprocal-max metric. Grok/MiniMax must not apply 50 bp automatically to every ordinary user direct swap; preserve its own min/max unless it is the defined composition leg.

Shortfall: require actual net output >= ceil(fee-inclusive quoted output for actual filled input ×9990/10000), with budget/settlement checks separately enforced. Intended Pons charges are not shortfall and must not be subtracted twice.

### Finite-range progress metric

At sqrt price q strictly inside range (a,b), eliminate the rational per-liquidity denominators using:

`X=T0*(q-a)*q*b`, `Y=T1*(b-q)*Q96^2`.

Then `rho=abs(X-Y)/max(X,Y)`. This is the exact finite-range position-composition mismatch; common positive factors cancel. Use sufficiently wide integer products/comparisons, not amounts from an arbitrary reference liquidity that may round one leg to zero. Both X=Y=0 means empty book; handle range-boundary/one-sided cases explicitly with placement-only accounting and no zero-denominator approval of opposite-token residual.

Sleeve: `target_i=floor(T_i*p/(WAD+p))`, `db_i=max(absoluteFloor_i,floor(target_i/20))`; `sigma=max_i(max(abs(F_i-target_i)-db_i,0)/max(T_i,1))`.

Public progress remains lexicographic `(max(rho-1bp,0),sigma)` after all costs and placement, compared with placement-only baseline. Exact wide comparisons determine eligibility; rounded WAD values are reporting only. Tie/no improvement means no trade. CC uses stricter final `rho<=1bp && sigma=0`.

### Correct work-budget interpretation

Keep **32 bracket refinements**, max **64 core forward steps** per simulation for permitted EI/public planning, and at most one executed holder swap per call. Starting x-domain may be uint256-sized; after 32 bisections its width may still be approximately `initialWidth/2^32`. Therefore:

- Evaluate the final **bracket endpoints**; call them adjacent only when their actual difference is one.
- Return success only when the exact terminal alignment/progress checks pass. Exhaustion with no passing candidate is a clean alignment failure or truthful maintenance defer.
- Do not assert root coverage, monotonicity for arbitrary hooks, universal feasible-deposit success, or a ±1-unit precision guarantee from the iteration count.
- Practical liveness and worst-case gas are acceptance tests on the admitted families. No exact-output branch calls this solver; no unsafe quote truncation is accepted as a fill.

An analytic seed is not necessary for this selected implementation; neither Grok's four Newton steps nor Kimi's eight probes has a demonstrated integer coverage guarantee.

## 6. Accounting and parity rules adopted

Establish funding credit before any collection. For unsupported EO reject before economic effects. Quote and execute use the same source snapshot and caller-credit exclusion. Track separate caller basket, incumbent backing, pending payment/refund and holder inventory. New LP fee growth/repricing during composition belongs to B, not C. Collection is E→F once, not minting value. Deposit allocation precedes mint, including any rounding attribution/check. Finish payouts/refunds/maintenance before durable full-set sync.

Correct preview equality must compare independent execution results, not merely common helper names. Required same-state tests:

1. Every supported cell: ordinary numerical preview equals returned user amount; unsupported preview and execution select the same formula-domain error before funding.
2. Transition quotes equal resulting S, holder shares, F/D/E, pool state and fees for the identical operation sequence.
3. SY deposit/redeem and internal-balance redemption match the equivalent SE EI route in kind, including recipient, funding context and exact share burn. Native SY must not manufacture a public EOA pretransfer bypass.
4. For each adopted inverse, forward(input)>=target and forward(input-1)<target within its exact stated domain; pay exactly requested output and book any prescribed residual.
5. **Do not compare illegal/non-equivalent operations:** Multi requires two positive amounts, so a zero-leg Multi call is not a single-token alias. A dual join is not generally equivalent to two sequential single-token zaps with separate fees/state changes. A direct swap is not automatically equivalent to a deposit/redemption cycle. Test those as economic sequences against their own references, not fabricated equality identities.
6. Pons exact-in taxes output, exact-out taxes input: same-in-kind interface wrappers must agree, but blindly demanding inverse-mode amounts agree ignores the actual fee convention. No unexplained tolerance such as ±1 bp is used to greenwash deterministic differences.
7. Full local booking after success; failed calls preserve balances/supply/position/snapshots atomically. Fees E remain in complete backing; MiniMax's `balance+deployed` postcondition omits uncollected fees when present.

Use the separate family suites and component sets in my original. Preserve shared generic repo slots when reusing existing generic facets: differing directory names do not automatically create different storage slots, and changing those slots would disconnect the shared facet from its data. Per-instance diamond addresses already isolate storage. Family-specific repos may have explicitly chosen family namespaces; no need to fork MultiAssetBasicVaultRepo solely for family separation.

## 7. Manifest counts verified by directory reads

Direct current directory reads, including interfaces and test bases, establish:

| Root | Top-level entries | Actual files including nested legacy bases/interfaces | Disposition |
|---|---:|---:|---|
| O | 40 = 38 files + 2 directories | **49 = 44 Solidity + 5 Markdown** | Retire listed Solidity after porting coverage/consumers; deprecate/archive all five historical docs. |
| F | 39 = 36 files + 3 directories | **38 = 36 Solidity + 1 Markdown + .DS_Store** | Retire the listed legacy Solidity and historical PRD; preserve unrelated .DS_Store outside the vault-removal operation. |
| F/fullSpread | 2 directories | Both new family directories currently empty | Preserve both subtrees; subsequently created replacement files excluded from deletion. |

The exact filenames in my original §7.1–7.4 match these reads and remain the finite adopted manifest. MiniMax's top-level directory counts are not complete file counts and its invented `...Common_Component_FactoryService.sol` is not an observed file. Kimi's “36 old-root Solidity” and “30 unsegmented-prefixed files” counts are incorrect: O has 33 top-level Solidity + 1 interface + 10 bases; F has 32 top-level `UniswapV4FullSpreadStandardExchangeVault*.sol`, its DFPkg interface, the candidate, and the two nested Solidity files.

Do not retain the old liquid-reserve interface path merely to preserve its interface ID: new family declarations with the same required selectors preserve the surface; remove the inventoried old file after imports are ported. Keep the generic usage-fee policy stable without retaining a stale active dependency.

Retire the experimental candidate because it is not adopted, not because a diagnostic supposedly proves it broken. Do not modify it. Deprecate old PRDs tied to removed code; preserve their dated source/provenance. Keep parent shared/V3/Pons/Crane resources and the new subtrees. Before deletion, record readiness; afterward rebuild artifacts and rerun family/consumer suites at the final revision. No deletion occurs in this research pass.

## 8. Directly adoptable handoff and remaining evidence boundary

Adopt the matrix, CC graph, corrected arithmetic/work semantics, separate families/generic reuse and finite manifest above. Implement H first, then separately implement P's fixed-model paths; run common behavioral controls on both. Required tests include the X=Y=100/S=1000 radical counterexample, all source-inverse domain boundaries, one-step word-boundary rejects, successful CC no-trade and nontrivial placement cases, credit-before-collection, Pons separate floors and both directions, terminal maintenance progress, wrapper parity, occupied deployment identities and post-removal consumer closure.

No DER-1..5 implementation phase, no candidate repair, no runtime-bytecode-equivalence gate and no old-PRD reconciliation as current law are adopted. Official Pons documentation/graduated-pool evidence and the maintained constant remain sufficient by owner instruction; that is not a claim of binary equivalence.

**Irreducible evidence gaps:** no tests/build/gas measurements were performed, and the selected finite certificate domain's practical coverage must be validated. The source-only matrix does not prove absence of all possible wider closed forms. If required product traffic is shown to fall outside these explicit domains, present that concrete case for specification revision—not an unadvertised numerical inverse or a general maintenance omission. My withdrawn vector D19 reading is not left as an implementation option.

Confidence is high in the integer counterexample, source-helper classification, ordering correction, fee floors and exact file counts; medium in complete workflow implementation feasibility until the specified tests run. Agreement is not proof of safety or economic soundness.

# Search-free Hookless redesign — final council synthesis

**Date:** 2026-10-03. **Author:** Astra moderator. **Status:** completed bounded research round, awaiting human product decision. Not an amended PRD, implementation authorization, security proof, or benchmark result.

## 1. Answer and recommendation

**Yes for a narrower proportional-basket vault; not established for the complete existing autonomous single-token Orbital/SY behavior.** Full-range deployed liquidity, fungible shares, complete backing, a deliberately reserved local sleeve, basket deposits, and known-share redemptions can coexist without ordinary-operation sizing searches. The price is a real interface/availability change, not simply a cheaper planner.

**Recommended design baseline:** proportional basket core; no holder repair on ordinary execution or quote paths; separate permissionless maintenance with a reserved sleeve; preserve known-share idle single-token redemption using its already-sized opposing entitlement. Preserve current exact-in retain-and-book semantics. Prefer deferred placement for ordinary joins so placement losses do not silently alter their issuance equation. Consider a distinct exact-share basket interface that pulls only its computed requirements; do not retrofit refund behavior into current exact-in selectors without approval.

**Do not adopt this as a drop-in Orbital replacement.** Idle scalar token-to-share composition would become unsupported. Share-denominated flexible Orbital operations are a useful surviving subset, not a replacement for scalar buffering. If unchanged autonomous scalar entry is mandatory, this round has not produced an implementation-ready search-free solution. Keeping the present search remains a valid owner choice: the prompt did not prohibit it.

| Rank | Alternative | Preserves | Explicit trade-off / disposition |
|---|---|---|---|
| 1 | Proportional basket core, separate maintenance | Full range, proportional ownership, complete backing, local cover, known-share exits | Loses general idle scalar entry; current Orbital/SY scalar composition is not preserved. Recommended conditional baseline. |
| 2 | Uniform internal constant-product scalar market plus basket core | Direct scalar mint arithmetic and exact-share input inverse in both manager states | Different economics; proposed scalar exits require local cover even idle; donations, pool repricing, maintenance and in-kind exits expose cross-market risks. Research candidate, not approved economics. |
| 3 | One directly sized external candidate with exact acceptance certificate | Original post-swap proportional issuance on a restricted domain | No complete integer sizing formula or useful liveness domain established. Reject outside domain, no retries. Do not confuse a known-output swap quote with deposit sizing. |
| 4 | Oracle/NAV admission | Arithmetic single-token mint given prices | New oracle/trust/freshness and imbalance-risk policy; same-pool spot valuation is not an acceptable default. No claim that NAV necessarily searches. |

A caller-specified conversion followed by a basket join is an interface possibility, not an autonomous solution unless Orbital can derive the size without discovery, obtain the other assets legally, and account for every residual. A fixed split sacrifices utilization and may fail protection bounds. No general impossibility theorem was proved for broader direct formulas.

## 2. Protocol, attribution, and changes of view

All four active researchers supplied originals and one combined cross-review of the other three active originals. No earlier cross-review was supplied to another researcher. Originals remain immutable. The human authorized replacing the first Grok after its reported attribution guard event; the fresh replacement was explicitly authorized to read the two then-existing originals. Its first pass is therefore **peer-informed**, not independent blind corroboration. Its cross-review timed out once, then completed in the same session after explicit human resubmission authorization.

| Researcher | Initial position | Final cross-review position |
|---|---|---|
| Astra | Conditionally preferred uniform internal CP scalar settlement | Revised to basket core first; internal CP remains conditional. Corrected omitted outer split search and overly broad invariant wording. |
| Grok replacement | Basket core first; challenged old Grok's quadratic | Retains basket-first ranking; corrects current dual-join maintenance and omitted outer split search. |
| MiniMax M3 | Claimed one-step exact-output swap plus placement solved deposits | Explicitly withdraws that claim: known-output inversion does not choose the deposit split. Ranks basket core first. |
| Kimi K3 | Basket core with refunds and an asserted autonomous Orbital converter | Retains basket-first ranking, acknowledges refund-law conflict and missing opposite-token availability; favors pull-exact and retaining certified no-swap placement routes. |

**Agreement is architectural, not unanimous correctness.** Reviews still contain errors; the moderator adjudications below supersede them for this report. Kimi's review describes Astra's original ranking and MiniMax's original sizing claim; it could not see their simultaneous corrections. Those are not their final positions.

### Moderator source adjudications

1. `_exactOutput` receives `params_.amount`, calls one swap step, and requires exactly that output. It supplies no equation choosing that amount for a deposit. MiniMax's original composition proposal is rejected. [HQuote:113–141]
2. `_faceForClaim` does **not** stop at eight probes. Eight caps interpolated guesses; `while (low < high)` continues. `_invertBufferForEffective` similarly has up to 64 expansions, then interpolation followed by continuing bisection—not a 72-probe total bound. Three reviews repeat the incorrect count. [OExit:347–374; OClaim:250–276]
3. `_zapSplitWadPacked` independently searches the residual for up to 64 iterations. Removing Hookless sizing or replacing two scalar inversions does not remove this search. [OMath:321–364]
4. Blocked entitlement uses **whole backing B**, then tests local cover F. Paying `floor(r*F/S)` while burning the whole claim is not a liquidity restriction; it changes ownership and underpays the entitlement. F1/F2 are not generally linear. [CP:49–64,78–110]
5. Placement can reduce represented backing by rounding loss. `B'=B+C` holds for a no-placement local mint, not automatically after placement. Economic backing is not local ERC20 custody. [HInventory:253–292]
6. Calling a two-token liquidity helper twice with one zero budget in each call is not the interior target. Current code takes the minimum of the two **single-leg** capacities. [HInventory:216–244]
7. Refund, scalar SY, and autonomous opposite-token claims are unresolved product changes, not aliases of current behavior. SY accepts one input/output token. The fixture's nested vaults require distinct opposite assets. [SY:20–42,50–76; Fixture:36–55]
8. A fixed two/three-candidate placement stencil is not automatically search-free under this prompt's definition of a sizing probe sequence. The old plan permits it; the new claim needs a proved arithmetic correction or a single deterministic target with validation. Deferred placement avoids this ambiguity on ordinary joins.

## 3. Accounting specification for the recommended baseline

All quantities are native raw units. Let S be pre-operation supply, l owned full-range liquidity, and `B_i=D_i+F_i+E_i`. Exclude current caller credit, refunds and payouts from incumbent F. Fees count once. Fix credit before fee collection; eligible source-agnostic pretransfer credit remains the declared amount within unbooked custody. Absorb other surplus consistently and fully synchronize local balances after success.

### Live basket joins

For credited exact-in basket C, positive S and both B legs:

```
m = min(floor(S*C0/B0), floor(S*C1/B1))
B'_i = B_i + C_i                 // deferred placement, no swap
S' = S + m
```

Thus `S*C_i >= m*B_i`: incumbents are not diluted in either leg. Exact-in refunds nothing; identified excess stays in backing. Intentional unbalanced Multi contributions retain their disclosed existing treatment, not a new promise of 1 bp loss for arbitrary excess.

For a separately specified exact-share basket request m:

```
C_i = ceil(m*B_i/S)
mint exactly m; require C_i <= max_i
```

Pull exactly C; do not pull max and silently introduce a refund. For a protected proportional join enforce the exact existing inequality `10000*m*B_i >= 9999*S*C_i` for each positive leg, in addition to minShares/maxAssets/deadline and actual-delivery checks. Reject where flooring breaches the bound; a blanket 10,000-unit minimum is unnecessary. An owner-approved capped/refundable variant could compute `m=min floor(S*a_i/B_i)`, then refund `a_i-C_i`, but only from credited caller assets. It is **not** current exact-in law.

### Activation and degenerate books

For S=0 preserve dual actual funding, `raw=floor(sqrt(C0*C1))`, decimal-dependent minimum `10^(meanDecimals-3)` when mean>=3, otherwise 1; require raw>minimum. Mint raw−minimum to caller and minimum plus the existing prior-backing residual-sink issuance to the dead sink. Preserve the plan's residual equation `max(ceil(priorB0*m/C0),ceil(priorB1*m/C1))`; do not credit old donations to the activator. [CP:16–34; implementation plan:43–62]

For S>0 and B0=B1=0, reject issuance rather than inventing a ratio. For a genuinely one-backed-leg book, a dedicated supported linear domain uses `m=floor(S*c/B)` and exact-share requirement `ceil(m*B/S)`; reject opposite-leg credit instead of silently donating it through that domain. Current dual-only interfaces need explicit route decisions for this extension. No single-token activation.

### Known-share exits

For a blocked proportional vector entitlement, `y_i=floor(r*B_i/S)` and require `F_i>=y_i` for every paid leg. Burn r and pay y: `B'=B-y`, `S'=S-r`. Earned uncollected E is never cover. Preserve dead-sink/supply limits.

For idle in-kind realization, snapshot prior F/E, collect E once, remove `l_r=floor(l*r/S)`, and pay `floor(r*(F_i+E_i)/S)+actualRemovalProceeds_i`. Explicitly account for removal rounding and retained fractional-position residuals; this realization need not equal the blocked book-floor payout. Its preview must model its own exact integer operation. A single-token idle exit converts the already determined opposing entitlement with one bounded forward quote/execution, not an amount-discovery loop. Do not append holder repair. Preserve disclosed terminal partial-fill residual behavior unless the owner approves full-fill rejection; work-budget exhaustion is not a successful complete quote.

Existing dual exact-output F3 requires equal per-leg ceiling burns, actual payment and cover; retain only source-supported domains. General two-leg scalar exact-output redemption remains unsupported: CP's inverse is bisection, not a closed form. [CP:113–128; implementation plan:81–103,131–135]

### Fees and conservation

`E_i=floor(l*deltaFeeGrowthInside_i/2^128)` uses checkpoint/wrap semantics. Collection transfers E to F once. A swap's protocol fee is not own LP earnings; the growth-per-liquidity amount needs the second multiplication/floor by owned liquidity. Repricing and own-position accrual belong to incumbents when pricing a caller composition.

With gross caller receipts A and explicit refunds R, a no-swap transition reconciles:

`B_after = B_before + A - R - payouts - placement/removalLoss`.

For swaps, add actual signed token settlement, incumbent principal repricing and own earned-fee changes separately, without counting fees twice. No unexplained loss may be retained as an asset. Deferred placement yields the clean local-join equations above; later maintenance costs belong to then-current holders. This timing changes economic cost allocation and needs approval.

## 4. Sleeve and placement

Choose **reserved maintenance placement**, not accidental leftovers. Read live p (WAD), default 20%; after collecting available fees, let `T_i=D_i+F_i` and `target_i=floor(T_i*p/(1e18+p))`. Preserve `max(absoluteFloor_i,target_i/20)` deadband. Target is relative to final deployed principal, not 20% of total or frozen pre-placement D.

For interior sqrt price q and endpoints a,b, Q=2^96, budgets `T-target`:

```
L0 = floor(budget0 * floor(q*b/Q) / (b-q))
L1 = floor(budget1 * Q / (q-a))
Ltarget = min(L0,L1)
```

Use the active token only at range endpoints, with source representability/tick-capacity bounds. Addition debts round up; removal proceeds round down. Recompute D/F, loss, final target and funding after exact settlement. One deterministic target may fail validation; defer rather than discover another ordinary-operation amount. Separate maintenance may retain its approved bounded search.

Both sleeve targets cannot be promised simultaneously for arbitrary inventory. Deferred placement can leave excess idle capital; keeper liveness affects deployment and restored cover. A reserved sleeve is useful but finite: any missing requested-token cover rejects blocked withdrawal atomically. No nested unlock. Removing repair from user paths does not remove separate D9–12/D21 maintenance capability.

## 5. Conditional scalar alternatives

The existing internal market provides actual direct arithmetic for positive two-leg B:

```
K = ceil(sqrt(Bin*Bother))
A = floor(sqrt((Bin+c)*Bother))
m = A>K ? floor(S*(A-K)/K) : 0
Areq = K + ceil(mRequested*K/S)
cRequired = ceil(Areq*Areq/Bother) - Bin

u = floor(Bout*r/S); v = floor(Bother*r/S)
y = u + (v==0 ? 0 : floor((Bout-u)*v/Bother))
```

Respect the helper's positivity/minimum-input, integer width and supply guards; reject zero-output successful funding. One-sided domains use the linear rules. No new fee is proposed for internal settlement. Local mint changes B by +c; exit by −y with actual `Fout>=y`. These are fee-free **internal market** equations, not post-external-swap proportional admission. [CP:58–110]

A proposed uniform version applies these scalar rules both idle and blocked and makes scalar exits local-cover-only. Matching entry/exit formulas does **not** eliminate hedging through in-kind exits, external markets or subsequent maintenance. Frozen-book invariant reasoning is not economic safety. Existing blocked formulas also need cross-state cycle testing; changing idle paths does not make that risk disappear. Do not silently reinterpret 50 bp external pool impact or 1 bp alignment as internal-market protections.

A certified external zap instead needs an actual function x(c,state), exact evaluation of `C=(c-x,Q(x))`, repriced incumbent B(x), fees/losses, and all bounds. One-step swap math alone does not supply x. One candidate followed by rejection could be a valid limited product, but no such useful integer domain was established. Oracle NAV `m=floor(S*(sum p_i*C_i)/(sum p_i*B_i))` is search-free given prices, yet requires a separate oracle and economic policy. It is not adopted.

## 6. Orbital and SY: concrete boundary, not a router promise

The conservative surviving composition surface is **already-held SE shares**: `depositFlexible(amount_i,isSeShare_i,...)` and `withdrawFlexible(...,receiveSeShare_i,...)`, with the relevant flags true, plus state/share receipt and configured rate arithmetic. This does not authorize disabling required pair-token B6 surfaces without an Orbital PRD amendment. [B6 PRD:35–43,48–71]

Under rank 1, idle Hookless `exchangeIn(token,amount,shares,...)`, its scalar deposit previews, and transition `DepositExactIn` lose their composition domain. An explicit basket interface can be called autonomously **only when both required assets are actually available**. The current fixture binds p0/seOther0 and p1/seOther1; Orbital's p0/p1 sphere does not establish custody or a legal conversion route for seOther0/seOther1. [Fixture:36–55]

SY is scalar: its deposit/redeem calls delegate to scalar SE routes. Do not claim a vector join or payout fits the same signature. Narrow discovery, accept an explicitly defined basket/share asset, or supply a separately proved converter. No generic SY adapter rewrite is authorized. [SY:20–76]

Under conditional uniform internal settlement, a candidate replacement for the two buffer inversions is: desired rated-native claim → `sharesForNativeUp` with fixed configured rate/decimals → `quoteInputForExactShares` in the newly supported domain → one matching execution/validation. Exact-input extra minted shares and exact-share execution cannot be modeled as identical silently. This still does not replace `zapSplitWad`. A deterministic outer split/raw-share basket policy needs separate equations, residual ownership, protections, and parity evidence. [OClaim:315–329]

Held-reserve valuation remains shares×configured rate, never trade-sized SE quotes or a gas-dependent fallback. LP operations use raw balances. [Orbital PRD:828–835] Do not adopt speculative `sharesJ/sharesK` accounting. Do not move discovery into a helper or off-chain instruction autonomous Orbital cannot supply.

## 7. PRD amendments required before adoption

Current PRD remains authoritative until the owner chooses. For rank 1:

| Decisions | Required disposition |
|---|---|
| D1–2 | Explicit loss of idle scalar composition; caller-composition funding rule becomes inapplicable there, not a holder-maintenance budget rule. |
| D3 | Keep live denominator/default/deadband; clarify maintenance timing and best-effort cover. |
| D4–5 | Replace composition→allocation→mint with local basket pricing/mint and deferred placement; retain incumbent attribution on other swaps. |
| D6–8 | Keep proportional shares/full contribution/residual booking. Specify any exact-share pull route. Refunds require an explicit alternative, not silent changes. |
| D9–12, D21 | Retain separate public repair, immediate repeated calls, no throttles, progress/stopping rules; remove implicit calls from ordinary operations/quotes. |
| D13–16 | Keep direct manager/admission/pretransfer/full booking; D15's associated no-refund semantics need amendment if refunds are chosen. |
| D17 | Keep applicable-closed-form-only exact-output support; no numerical inversion. |
| D18–19 | Replace mandatory user-path repair/interleaving rules; decide whether proved deterministic no-swap placement survives on particular exact-output routes. |
| D20, D25 | No silent relaxation of 1/50/25/10 bp. State applicability by route; no external composition means its 50 bp check is vacuous, not replaced by an internal bound. Constants stay fixed. |
| D22–24, D26, D28–29, D31 | Preserve family separation, bindings, evidence/removal gates and allowed reuse. No Pons behavior changes by implication. |
| D27, D30 | Replace complete selector/state/consumer matrix and prove identical-state integer parity for each actual operation. |

Rank 2 additionally replaces scalar D5/D6 economics, idle exit availability and any new internal-price/rounding bounds. Rank 3 amends liveness/domain rejection and maintenance timing while preserving proportional issuance where certified. Rank 4 replaces valuation/admission policy and introduces oracle requirements. Corresponding Orbital, SY and DETF obligations must be amended explicitly; Hookless approval alone does not close them.

## 8. Dissent, confidence, and later implementation gates

**Unresolved choices:** deferred placement (moderator/Astra preference) versus retaining certified no-swap placement (Kimi); retain-and-book default (moderator/Grok/Astra) versus pull-exact/new capped funding (Kimi); whether to pursue internal-market economics at all. All final rankings favor basket-first, but that does not establish the full requested composability. MiniMax's statements that outer Orbital searches are out of scope are rejected for the end-to-end claim. Its categorical no-closed-form assertions are not adopted.

High confidence: current search locations, exact-output-vs-sizing distinction, scalar interface limitations, backing/cover separation, refund-law conflict. Medium confidence: architectural feasibility of the narrowed basket design. Unresolved: full integer transition liveness, cross-market economic acceptability, deployed dependency pins and end-to-end gas. No council vote or passing tests proves security.

Later authorized implementation must first freeze owner decisions and current source/dependency revisions, then:

1. Produce a selector×direction×manager-state×consumer matrix including unsupported domains, native/import/one-sided cases, exact-output limits and residual policy.
2. Use independent integer references, exhaustive small cases and real production-path proxies/PoolManager; verify exact preview/execution and SE/SY parity, not two calls to one helper.
3. Assert no sizing probes in every promised ordinary call graph, including dual joins, redemption queries, external-exchange queries and outer Orbital. Tick traversal for an already-sized swap remains permitted.
4. Reconcile custody D/F/E, caller credit, refunds, fee checkpoints and every placement/removal loss. Test donated/unbooked claims, re-credit rejection, mixed decimals, extremes, live-p changes and failed-cover rollback.
5. Exercise deposit→blocked settlement→idle/in-kind exit→maintenance cycles, same-pool manipulation, rate changes, rounding/donation and repeated repair without inventing forbidden throttles. A matched internal curve alone is insufficient.
6. Refresh runtime artifacts before tests under current project law. Replay the funded-binding and nested Univ4Se fixtures; pin comparable states and measure full transaction gas, quote calls, storage reads and runtime size. Respect the stated 31M SY/32M chain constraints; do not conflate them with the much larger general Foundry gas_limit. No cap raises, via-IR/config workaround, minOut=0 or gas-dependent valuation.

**Human checkpoint:** approve the narrower basket-first product and explicit Orbital/SY losses; or retain current scalar behavior/search while commissioning a bounded further research question; or explicitly pursue internal-market/direct-sizing alternatives without treating them as ready to implement. Recommended default: basket-first specification only if the lost scalar routes are acceptable. Otherwise, do not approve a misleading “compatible search-free” implementation plan.

## 9. Evidence, versions, artifacts and handoff

All accesses in this round: **2026-10-03**. Moderator directly read CLAUDE, current Hookless PRD/plan, canonical IndexedEx skills, Orbital B6 and held-rate law, and the critical source sections cited above. Researcher originals/reviews contain further canonical/source reads. Root CLAUDE and current PRDs supersede stale README/skill examples.

Literal citation aliases:

- HQuote/HInventory: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol` and `...InventoryMath.sol`.
- CP: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol`.
- OExit/OClaim/OMath: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol`, `...ClaimLib.sol`, `...Math.sol`.
- SY: `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`.
- Fixture: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol`.
- B6 PRD: `contracts/hooks/uniswap/v4/standardExchange/orbital/UNISWAP_V4_SE_ORBITAL_BUFFER_MIN_SE_AND_B6_REMEDIATION_PRD.md`.
- Orbital PRD: same directory, `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md`.
- Hookless authority: `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:28–58,118–206,240–269,398–450`; implementation plan `UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:43–168,170–214,249–267`.

Local compiler configuration directly verified: `foundry.toml:29–36`, Solidity 0.8.35, optimizer runs 1, via_ir=false. Context7 `/uniswap/v4-core` preceded moderator primary verification: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol (upstream Solidity 0.8.26), `unlock` rejects AlreadyUnlocked and liquidity caller delta includes principal plus fees. Upstream main is not a deployment or local dependency commit pin. The protocol's nested-unlock restriction does not itself prove all cooperation inside an existing unlock is impossible; current sleeve-only product law and unproved integration prevent assuming such a new design.

Researchers inspected https://learn.charm.fi/charm/technical-references/core/alphaprovault and https://github.com/charmfinance/alpha-vaults-contracts (Kimi reports pragma 0.7.6): proportional deposits/separate rebalance and configurable ranges are a precedent only, not a verified full-range-only V4 or autonomous converter. Arrakis/Gamma/Range are not relied upon for the recommendation. No exploit-history claims.

Missing ordinary fixture reads in MiniMax are preserved as its access report; moderator directly read the Univ4Se fixture successfully. A moderator broad glob reported unrelated missing Crane links; no secret search or execution was used to work around it. Astra's accidental `as-cross-review.tmp` is disclosed in its review/status; it was not deleted or moved.

| Active researcher | Session | Original / sole cross-review |
|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md` / `astra-cross-review.md` |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md` / `grok-replacement-cross-review.md` |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | `minimax-original.md` / `minimax-cross-review.md` |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md` / `kimi-cross-review.md` |

Historical replaced Grok `ses_efecf30f9ffeVpfJwKjFmW1UfU` and `grok-original.md` remain provenance only. There were extra calls for the authorized replacement and timeout resubmission; do not describe this interrupted process as exactly eight task invocations. Four active originals and four completed combined reviews now exist.

**Separate implementation handoff:** no contracts/tests/config were edited, and no shell/tests/deployments or gas measurements were run in this research. This report selects a conditional design baseline, not code to execute. Owner decisions and a revised cross-product specification are prerequisites to implementation. Stop here.

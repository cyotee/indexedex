# Mandatory single-token SE routes with managed wings

**Date:** 2026-10-03. **Author:** Astra moderator. **Status:** bounded council research concluded with a partial MiniMax cross-review; product decisions and economic proofs remain open. Not an approved PRD or implementation authorization.

## 1. Executive decision

The human's latest requirement controls: **single-token deposits and single-token withdrawals are essential**, including autonomous buffered-pool use. Basket-only and asynchronous-only replacements are rejected. Full-range-only deployment is relaxed for investigation, not silently changed in current product law.

**The wing proposal is mechanically feasible and worth pursuing.** A single token can be placed in an appropriately out-of-range position using direct arithmetic. A bounded manager can later remove a mixed or fully crossed wing and add feasible liquidity to a common double-sided core. Neither operation intrinsically needs a swap-sizing search.

**Wings do not, by themselves, determine how many fungible shares to mint.** A new depositor acquires ownership of the entire existing book, not only the wing funded by that deposit. Current min-ratio issuance against a positive two-leg incumbent book yields zero shares for a one-leg contribution. We must consciously choose a different scalar admission rule.

### Recommended architecture, independently of the unresolved pricing choice

1. Preserve scalar SE/SY selectors and actual minimum-output/max-input protection.
2. Admit deposits **locally first**, issue fungible shares with a direct chosen pricing rule, and fully book the received token. Do not make admission depend on an available wing slot.
3. Maintain a small fixed inventory: **one core and one wing per token orientation**, with deterministic identities, not one position per depositor. Three active positions is the recommended starting cap, not a measured gas guarantee.
4. Reserve a useful local sleeve against aggregate deployed principal. Place only excess under a separate bounded management operation. If a wing is occupied/mixed or unavailable at a price extreme, retain incoming tokens locally.
5. Consolidate selected mixed or fully crossed wings without forcing a balancing swap. Add what fits the core; retain and book the remainder. A fixed full-usable-range core is the simplest starting choice; a concentrated/recentered core needs additional policy.
6. Preserve scalar withdrawals through an explicit realization policy below. Already-unlocked calls remain actual-local-cover-only under current product law.
7. Treat the remaining outer Orbital allocation search as an explicit product decision. Do not claim full end-to-end search freedom merely because Hookless becomes search-free.

**Pricing recommendation:** advance two alternatives to a specification/economic gate, not production adoption. The source-backed internal constant-product model is the most concrete first proof track when broad pair coverage without a new feed dependency matters. Controlled independent-price admission is a serious comparator where suitable feeds exist, not something to dismiss as mathematically impossible. No feed, spread or divergence calibration was established for either. I do not select one as economically safe by researcher vote.

## 2. What the wing lifecycle actually does

Use Uniswap's canonical price orientation: token1 per token0, with sqrt price q. A position has endpoints a<b.

| Current price relative to position | Position principal | Correct one-sided placement |
|---|---|---|
| q <= a | token0 only | Token0 wing **above** current price |
| a < q < b | both tokens | Unilateral funding cannot be assumed |
| q >= b | token1 only | Token1 wing **below** current price |

This is directly supported by Crane `LiquidityAmounts.sol:67–76` and upstream source. MiniMax and Kimi initially reversed the wing labels; both reported correcting them. Position fees are separate from principal and can include both tokens.

New wings should be strictly separated from current sqrt price, on legal tick-spacing boundaries, with deterministic gap/width. Mathematical floor is required for negative ticks; Solidity signed division truncates toward zero. Validate actual sqrt comparisons and usable endpoints rather than clamping an invalid range into an active one. Gap and width are policy inputs still to choose; neither percentages of tick indices nor a loop over candidate widths is acceptable.

For Q=2^96 and one-token budget c, the existing helpers compute:

```
L0 = floor(c * floor(a*b/Q) / (b-a))
L1 = floor(c * Q / (b-a))
```

Use L0 for an above-price token0 wing and L1 for a below-price token1 wing. Cap by representable signed change, owned/tick capacity and other source bounds; verify exact rounded-up addition debt against the budget. Retain unused funds. No trial-price or swap-sizing loop is needed. The helper's floor can return zero for dust/extreme domains: leave assets local, do not turn that into a failed scalar admission after funding.

As price enters a wing, external swaps progressively change its token mix. On full crossing, principal becomes the other token. **Conversion can reverse before the position is removed.** Out-of-range positions earn no new swap fees; an in-range period can earn fees but is not a profit guarantee. No keeper timing guarantees a completed sale.

### Aggregation and consolidation

- Aggregate same-orientation inflows into the existing wing only while its range remains appropriately one-sided. Fixed slots can change ticks only after prior liquidity and fees are fully settled; no caller-supplied salt proliferation.
- Once mixed, freeze unilateral additions. New deposits still mint and remain in F. This decouples scalar service from keeper timing.
- A permissionless consolidation examines at most two wings, removes selected liquidity, collects each position's fees once, reserves the sleeve, and computes one limiting-leg core addition from both budgets.
- An in-range wing generally has a different ratio from the core. A fully crossed wing is single-sided again. **Neither is guaranteed to fit completely into a double-sided core.** Use opposite local inventory if available; otherwise retain the unmatched currency or later place it in a correctly oriented wing.
- Consolidation preserves aggregate tokens apart from fees and rounding. It does not itself repair arbitrary token imbalance. External trading or separately approved maintenance would be needed for forced ratio repair.
- No new shares or keeper-owned residuals are created. No dust burning. Prevent repeated no-progress remove/add churn by a defined progress rule, not a forbidden cooldown or cumulative turnover cap.

Five slots could permit more immediate placement but do not solve indefinite price movement; they also eventually require local deferral. The proposed 256 per-user positions is rejected as an unsubstantiated nested-gas and dust-DoS design.

## 3. Complete backing and conservation

For token i, `B_i = F_i + sum_j D_ij + sum_j E_ij`, over at most three positions. F is spendable local custody after excluding caller credit and liabilities; D is principal at the actual pool price; E is own earned uncollected fee entitlement. B is **not** the vault's local ERC20 balance.

Per position, `E_ij=floor(l_j*deltaFeeGrowthInside_ij/2^128)` with source checkpoint/wrap semantics. Collection moves E to F once. PoolManager's returned caller delta already includes principal plus fees; its separate fee return must not be counted as an additional cash transfer. Core, wings, native/WETH accounting faces and local snapshots need one reconciled book.

For a local deposit c with deferred placement: `B'=B+c*e_in`, `S'=S+m`. For a funded payout y: `B'=B-y*e_out-loss`, `S'=S-r`, plus any separately recorded swap repricing/fee effects. Placement/removal loss is `before(F+D)-after(F+D)` after excluding transfers and collected fees. A lost unit cannot remain a booked residual. Public later management costs belong to then-current holders. Immediate caller-funded placement would change mint-loss attribution and may destroy a previously direct exact-share inverse; it is not the recommended first version.

Preserve actual dual-token activation, existing F0 minimum/dead-sink and prior-backing residual-sink issuance. No unilateral bootstrap. Preserve eligible source-agnostic pretransfer, exact-in no-refund law, complete final booking and existing contract-caller restrictions. Retained charges proposed below are a disclosed ownership-pricing discount, not an unexplained transfer or unbooked balance.

## 4. Two real scalar pricing alternatives

### A. Internal constant-product admission and settlement

This reuses existing `StandardExchangeConstantProduct.sol:58–110` arithmetic, but extending it to idle state is an explicit economic change. For S>0 and positive Bin/Bother:

```
K = ceil(sqrt(Bin*Bother))
A = floor(sqrt((Bin+c)*Bother))
m = A>K ? floor(S*(A-K)/K) : 0

Areq = K + ceil(mRequested*K/S)
cRequired = ceil(Areq*Areq/Bother) - Bin

u = floor(Bout*r/S)
v = floor(Bother*r/S)
y = u + (v==0 ? 0 : floor((Bout-u)*v/Bother))
```

Apply source positivity, minimum-input, integer-width and full-burn guards. Reject zero successful issuance. One-backed-leg source domains use `floor(S*c/B)` and `ceil(m*B/S)`; entering an empty same-side reserve is not silently supported. Nonzero supply with empty backing rejects. Two-leg scalar exact-output redemption remains unsupported: its source inverse searches.

**Meaning:** the depositor trades economically against the common book without an external swap. The share formula discounts unilateral contributions according to that book's imbalance. The exit internally buys the withdrawing holder's opposite-token entitlement. Both can execute while already unlocked if the actual requested payout is locally funded.

At a frozen book, the conservative floors support an invariant argument. They do not prove safety as LP holdings move, assets are donated, wings cross, management acts, or an external market prices the two tokens differently. Matching internal entry/exit helps define coherent terms but does not eliminate external or in-kind hedging. An oracle-free formula is not an oracle-free economic-risk proof.

If an explicit retained entry spread lambda is selected, a concrete proposal is `n=floor(c*(W-lambda)/W)`, mint F1(B,n), book all c; invert F1 to nRequired then `ceil(nRequired*W/(W-lambda))`. A retained exit spread gamma gives `floor(F2(B,r)*(W-gamma)/W)`. Neither rate is selected. They must be frozen for the operation; an amount-dependent imbalance fee needs its own inverse and could reintroduce search. A divergence gate cannot secretly fall back to basket-only as the product's normal service.

### B. Controlled reference-price admission

Let p_i be prices per raw unit in a common numeraire and `V=sum_i p_i B_i`. With an explicitly approved retained entry charge f_i and W=1e18:

```
n = floor(c*(W-f_i)/W)
m = floor(S*p_in*n/V)
nRequired = ceil(mRequested*V/(S*p_in))
cRequired = ceil(nRequired*W/(W-f_i))
```

This is direct arithmetic and also works with local funding while already unlocked. Under fixed prices, local-only issuance is non-dilutive in the selected valuation. It does not establish realizable market-value safety. Zero/stale/unavailable prices must fail closed for dependent routes. Suitable feeds for the intended pairs, maximum age/confidence, deviation/position exposure gates, fee/spread and rate-provider projection remain unspecified owner policies.

A proposed covered blocked payout is `floor(r*V*(W-g_out)/(S*p_out*W))`, with direct exact-output share inverse `ceil(y*S*p_out*W/(V*(W-g_out)))`. That consciously replaces current F2. Idle payout can instead realize a proportional slice at actual market execution as described below; this is a distinct operation and needs a cross-mode economic analysis, not a false inverse claim.

**Oracle dissent adjudication:** Grok/Kimi warn of cheap admission and pool-priced exit. This is a legitimate risk to test, not a demonstrated universal exploit. At fixed independent token0 price P in token1 units, interior LP marked value is `L*[P*(1/q-1/b)+(q-a)]`; its derivative is `L*(1-P/q^2)` and it has a minimum at q=sqrt(P). Moving spot away from an initially fair price therefore does not mechanically reduce that marked NAV. Actual holdings, stale prices, attacker trading costs, fees and realization must be modeled. Conversely, independent p does not make D(q) constant or magically prove safety. No valuation-envelope design was completed.

### Not adopted

Liquidity shares based solely on wing L, `S*c/(Bin+c)`, same-pool spot-only NAV, epochs/private wing receipts, basket-only service, or an unproved analytic zap presented as an exact solution. A direct analytic candidate with one certificate remains possible research, not a nonexistence theorem or complete blocked-state solution.

## 5. Single-token withdrawal without binary search

There are **two coherent mechanical approaches**, whose pricing and cost allocation must be paired deliberately with the chosen admission rule.

### Proportional realization plus one known-input conversion

Given r shares, collect old fees once, remove `floor(l_j*r/S)` from each position, and combine actual proceeds with `floor(r*(F_i+sum E_ij)/S)` local/earned entitlement. Swap the now-known opposing amount once; quote against the pool after all removals. The swap may traverse bounded ticks, but does not discover an amount. Pay the selected currency, preserve terminal residual policy, and reject truncated work-limit quotes. This supports broader idle realization without asking the caller for another asset.

Current quote overlays model one liquidity change; a three-range removal needs a corresponding bounded multi-range overlay and exact projected fee/state changes. Simply reusing the single-range quoter is not parity evidence. [Quoter:46–50,69–80]

### Internally priced payout, algebraically funded

First compute y using the selected internal rule. Use local output currency, then a fixed-order traversal of at most three positions to remove enough principal of that currency. This is execution of a directly calculated funding plan, not exploratory simulation.

With Q=2^96 and a token-bearing segment u<v, rounded-down proceeds are:

```
R0(l) = floor(l*Q*(v-u)/(u*v))
R1(l) = floor(l*(v-u)/Q)

Lrequired0(z) = ceil(z*u*v/(Q*(v-u)))
Lrequired1(z) = ceil(z*Q/(v-u))
```

For token0 use u=max(q,a), v=b when u<v. For token1 use u=a, v=min(q,b) when u<v. Collect fees once before sizing the remaining shortfall, cap each removal at owned liquidity, settle, retain incidental opposing proceeds and update shortfall. Revert atomically if actual requested currency is still insufficient. Signed settlement limits and exact wide arithmetic are mandatory. This derivation is source-supported mathematics, **not implemented or exhaustively verified**.

An existing floor liquidity-for-budget helper is not this inverse. Its token0 intermediate `floor(u*v/Q)` can be zero near low prices; adding one liquidity unit does not universally fix underfunding. MiniMax's partial review adopted the +1 stencil; that claim is rejected. Grok's one-wing-only funding restriction is a simpler domain but unnecessarily rejects some withdrawals funded by core/mixed positions. Even correct funding incurs removal-rounding losses that must be assigned and included in preview; frozen-book F2 conservation does not silently cover them.

### Already-unlocked state

Price the whole-book entitlement, but pay only actual local F. Wings and uncollected E are not cover. No nested unlock or position operations under the retained sleeve-only product policy. Revert on shortage. Neither design promises every requested token at every size/state; meaningful scalar functionality is mandatory, unlimited liquidity is not.

## 6. Sleeve, protections and management risk

Use aggregate deployed D and live oracle sleeve percentage p: `target_i=floor((D_i+F_i)*p/(W+p))`, default p=0.20W; existing absolute/5%-of-target deadband remains. A target calculation on pre-placement D alone is wrong. Reserve free budgets, compute exact post-debt D/F and recheck final targets including loss. Both token targets may not be attainable at once; new deposits can remain local.

No-swap wing additions do not move spot price, so the old 50 bp composition-impact check is **inapplicable**, not a sandwich defense. Keep the 25 bp bound on actual management swaps and 10 bp fee-inclusive execution-shortfall bound where applicable. The existing 1 bp basket-alignment meaning cannot be transplanted to unilateral NAV/invariant issuance. Any replacement integer-loss bound, reference-price deviation, spread or wing-width limit is an explicit owner decision; no unapproved tuning setter.

Risks requiring quantified analysis: internal/external price divergence; stale feeds; same-pool position repricing; crossing-and-reversal; keeper MEV and prolonged absence; fee-checkpoint timing; dust/salt DoS; repeated no-progress consolidation; one-sided output depletion; incorrect native faces; callbacks and reentrancy. Swap-free consolidation can still change subsequent price exposure and active liquidity at a manipulable state. Correct accounting is not a guarantee of no loss or no exit failure.

## 7. Orbital and SY contract

Keep scalar `exchangeIn(token,c,share,minShares,...)`, `exchangeIn(share,r,token,minOut,...)`, SY aliases and matching transition quotes. No caller supplies an opposite token or an off-chain sizing plan. Transition state must include all active ranges/liquidity/checkpoints, local balances, credit exclusions, supply, any reference observation/charge schedule and manager availability.

The two outer inversions can be replaced **conditionally** by: desired rated claim → decimal-aware ceil share requirement → one direct `quoteInputForExactShares` → matching execution/validation. This assumes the same frozen rate convention and quote state; an amount-dependent/post-deposit target rate needs an additional derivation. Exact-input can mint extra shares and cannot be silently modeled as exact-share execution. Reject zero-mint/zero-rated face fallbacks.

| Search | Disposition |
|---|---|
| Hookless caller composition | Removed from proposed scalar admission; replaced by chosen direct share rule. |
| Hookless user/quote holder repair | Remove from ordinary paths; separate management only. |
| `_faceForClaim` | Direct inverse substitution only after rate/state semantics are proved. Eight interpolation attempts are not a total bound. |
| `_invertBufferForEffective` | Same; expansion plus continuing bisection currently remains. |
| `zapSplitWad` | Still an outer allocation search. Wings and direct admission do not eliminate it. |
| General two-leg CP exact-output exit inverse | Unsupported unless a separate valid direct inverse is supplied; no bisection substitution. |

For complete Orbital search freedom, a new deterministic outer policy is needed or a direct split formula must be proved. Astra proposes two predetermined sales, then a direct proportional join with explicit unused-asset treatment. That is autonomous arithmetic but trades away optimized/full consumption, can cause unnecessary conversion, and has no demonstrated parity/liveness economics. It is an optional product amendment, not an adopted thirds rule. Keeping the outer loop while making inner quotes cheap is a lesser performance objective and must be named honestly.

Preserve configured shares×rate valuation and raw-share B6 LP accounting. Do not use trade-sized SE quotes for held-reserve value or gas-dependent fallback. Pons remains a separately implemented family; this research does not change its fees, range strategy or admission.

## 8. Attributed findings, corrections and dissent

- **Astra:** prefers controlled-reference admission, local-first, three slots, proportional idle realization; derives exact removal funding inverses as an alternative. Explicitly corrected its overly broad oracle-manipulation warning. Feed/economic policy remains unproved.
- **Grok replacement:** prefers internal CP with optional spread; correctly separates placement/valuation and orientation; accepts three slots for deferred placement, favors five for immediate placement. Restricts idle funding to local inventory and a one-sided wing; moderator regards this as an avoidable liveness restriction, not a theorem.
- **MiniMax:** original proposed wing-dependent one-leg issuance, reversed orientation and 256 positions. Partial returned review corrects orientation, adopts three slots and internal CP, but still adopts an unproved +1 funding correction. Its attempted cross-review write was denied; detailed review artifact is absent.
- **Kimi:** favors internal CP with direct funding cascade; corrects orientation, adopts three-slot freeze and local-first minting; downgrades +1 to a test hypothesis. Its claim that internal CP is the only oracle-free synchronous scalar rule is too broad; it is a reviewed source candidate, not a uniqueness proof.

Additional moderator corrections: MiniMax's `m=S*c/(Bin+c)` implies incumbent fraction `(Bin+c)/(Bin+2c)` before integer floors, not Kimi's claimed `Bin/(Bin+c)`. It still omits opposite value and is not an acceptable admission rule; Astra supplies a small-contribution equal-price overissuance counterexample. Also, `10000*m*Bother >= 9999*S*Cother` with Cother=0 is trivially true, not a rejecting check as Grok/Kimi state. The actual min-ratio mint is what becomes zero. Non-dilution in one token or an alignment inequality alone cannot certify scalar valuation.

The opinions do not constitute complete four-way consensus. All original files are preserved; no researcher received another cross-review. Old session history persists, but no peer artifacts were read during this round's first passes. Eight task calls occurred: four resumed originals and four resumed cross-review turns.

## 9. PRD amendments and later acceptance

Current law remains in force until approved. The human authorizes considering wings, not an implementation change.

- **D1–2, D4–6:** preserve scalar selectors, replace caller swap/composition/min-ratio scalar admission with selected pricing/order; preserve attribution of any actual caller-funded swaps. D6 is a substantive ownership decision.
- **D3:** aggregate core+wing principal for the live sleeve target; specify timing/defer behavior.
- **D7–8:** credit and book entire input including disclosed retained charges/residuals; amend full-range-only placement and cost allocation. No implicit exact-in refunds.
- **D9–12, D21:** bounded permissionless lifecycle/consolidation, progress/stopping and no forbidden temporal throttles; swaps, if retained for repair, remain separate and protected.
- **D13–16:** direct manager/admission/pretransfer/booking remain; position storage and source accounting expand without confusing custody and backing.
- **D17–19:** exact-output domain matrix and direct inverse semantics; no numerical inversion; ordinary maintenance interleaving removed or explicitly bounded without sizing discovery.
- **D20/D25:** owner-approved replacement scalar rounding/valuation metrics and any new fixed charges/gates; preserve actual 25/50/10/1 bp meanings where still applicable.
- **D22–24/D26/D28–29/D31:** preserve separate Pons orchestration, bindings, permitted generic reuse and readiness/removal gates. Pons unchanged absent its own decision.
- **D27/D30:** complete route/state/consumer and exact parity specification. Explicitly amend relevant DETF full-range/accounting and SY/rate-provider contracts, not only Hookless source. Orbital direct inverses/outer split require their own product changes while held-rate/B6 principles remain.

Before implementation: decide the admission model and exit realization pair, feed or spread/divergence policy, wing gap/width/core range, three-slot fallback, realization-loss ownership, and Hookless-only versus full Orbital search-free scope.

Later acceptance must independently establish: scalar useful supported domains (not universal rejection), inverse minimality/overflow, exact add/remove debt/proceeds, negative-tick/boundary/extreme orientation, all wing phases/reversal, caps and dust, per-position fee attribution, full custody/book conservation, donation and cross-market cycles with actual trading costs, failed-cover rollback, multi-position state/quote/SY parity, native/import/decimal edge cases and management progress. Use production registry proxies and refreshed runtime artifacts. Replay funded-binding/nested same-manager fixtures; measure total transaction gas, storage reads, forward steps and runtime size on pinned equivalent states under unchanged 31M/32M constraints. No benchmarks were run here; three positions and fewer probes are not proof of a gas win.

## 10. Evidence and process record

Access date **2026-10-03**. Canonical skills/current PRDs were read in retained sessions; moderator directly read canonical V4 liquidity skill and source. Some skill descriptions conflate ERC6909 currency claims with LP positions; this proposal relies on direct PoolManager positions, not that narrative. Current source wins.

Primary sources after Context7 `/uniswap/v4-core`:

- https://github.com/Uniswap/v4-core/blob/main/test/utils/LiquidityAmounts.sol — orientation and amount/liquidity mapping; upstream pragma ^0.8.20, main unpinned.
- https://developers.uniswap.org/docs/get-started/concepts/liquidity-providers/range-orders — freshly fetched: V3/V4 range orders, conversion/reversal and timing limits.
- https://support.uniswap.org/hc/en-us/articles/20980601560717-What-is-a-range-order — primary search result: no out-of-range fee earnings until active.
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — researcher primary verification this round, moderator prior round; caller delta includes fees, nested unlock rejection; pragma 0.8.26, not deployed pin.

Local paths (all relative to repository):

- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:19–44,56–76` (pragma ^0.8.24).
- Same directory `SqrtPriceMath.sol:186–209,237–255,264–289`: exact signed/rounded settlement and removal derivation.
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:16–34,49–128`: activation, CP mint/exit/inverse and searched inverse.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultPositionRepo.sol:9–22,121–135`: current single managed range.
- Same prefix `InventoryMath.sol:216–244,253–292`: liquidity target and explicit losses; `InQueryTarget.sol:22–32` rejects current idle exact-share input (researcher verified).
- `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:46–50,69–80`: current single-change overlay.
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol:347–374`, `...ClaimLib.sol:250–276,315–329`, `...Math.sol:321–364`: outer inversions/rate scaling/split.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–76`: scalar aliases.
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:28–58,118–206,240–269,398–450` and corresponding implementation plan: authority until amended.
- Orbital co-located product PRD:828–835 and B6 remediation PRD:35–43,48–71; fixture `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:36–61`.
- `foundry.toml:29–36`: local compiler 0.8.35, optimizer runs 1, no via-IR. No deployed bytecode/dependency commit attestation.

Charm examples were a researcher lead, not a relied-upon proof of this combined scalar/multi-position design. No fresh gas or exploit execution evidence. Ordinary missing-file reports remain attributed access limitations; moderator has read the canonical liquidity and Univ4Se fixture paths successfully.

### Participation and authoring limitation

| Researcher | Retained session | Current output |
|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md`, `astra-cross-review.md` |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md`, `grok-replacement-cross-review.md` |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | `minimax-original.md`; partial cross-review returned in chat, write denied |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md`, `kimi-cross-review.md` |

MiniMax reported `[RC_POLICY] tool policy validation failed` for writing its assigned review and stopped without retry. The task returned attributed partial findings; no RC_ATTRIBUTION/RC_IDENTITY/RC_HISTORY/RC_COMPACTION/RC_EVIDENCE or genuine SDK RC_UNAVAILABLE was reported by the tool. RC_POLICY is not relabeled as those errors. The moderator did not retry or recreate that blocked file, and continued the separately authorized Kimi review. Directory inspection confirmed no MiniMax review artifact. Consequently this is a moderator synthesis with **partial MiniMax cross-review**, not a claim of four complete written reviews or unanimous consensus.

**Implementation handoff:** no implementation, tests, shell, deployment, transaction or configuration changes were performed. The next authorized work should be a concrete pricing/withdrawal/range-management specification and economic validation plan, not automatic execution. Stop at the human decision checkpoint.

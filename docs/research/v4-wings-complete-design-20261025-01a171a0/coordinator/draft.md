# Coordinator draft: complete V4 Wings design

## Draft identity

- Draft ID: draft-v4-wings-complete-design-20261025-01a171a0-r1
- Path: docs/research/v4-wings-complete-design-20261025-01a171a0/coordinator/draft.md
- Run ID: v4-wings-complete-design-20261025-01a171a0
- Status: pending advisory review; not the final report.
- Fingerprint: not computed. The revision label and preserved bytes identify this draft.
- Sources: all four originals under members/{astra,grok,minimax,kimi}/response.md, the common brief and the coordinator-verified source locators below.
- Original files remain unchanged. This draft will not be edited once sent for feedback; subsequent wording belongs to the final and resolution.

## Participation

- Council kind/result label: full.
- Requested and substantive initial respondents: Astra, Grok, MiniMax and Kimi; all four Native turns settled before synthesis.
- Missing initials: none.
- Coordinator: invoking agent, not an independent vote.
- This is a coordinator-selected synthesis, not a claim that the four members endorse every choice.
- Native routes and task/session identities are recorded in ../RUN.md.

## Question

What complete V4 fee-earning portfolio vault should replace the current Upper Lower Wings accounting, from deposit and full imbalance credit through fees, compounding, actual withdrawals, previews, getRate, gas, and external liquidity use?

## Proposed text

### 1. Recommended product and deliberate tradeoffs

Recommend a **single fungible ERC20 portfolio share**, with:

1. Independent-reference valuation for minting ownership, evaluating each LP range at that reference price itself.
2. Target-only approximate-swap entry, plus an explicit dual-token route. Every retained deposit-funded core/wing increment and idle token receives its full net reference credit.
3. Proportional in-kind withdrawal as the primitive, with an optional strict target-conversion route paying actual proceeds.
4. The user's exact one-whole-share target-exit preview as canonical getRate, not NAV and not a clamped substitute.
5. Swap-free fee compounding, separately bounded range maintenance, and no first-release portfolio-funded swap rebalance.
6. Initial trading of shares as a distinct asset. Rate-based target/share parity integrations require their own safe pricing/settlement design.

This selects the architecture supported most directly by Astra and Grok. MiniMax also prefers independent-reference issuance, but differs materially on how LP principal is valued and on clamping the rate. Kimi prefers a price obtained from the entrant's own executed swap; that remains a live-denominator proposal with an admitted unproved attack and is not selected for release.

The principal cost is **limited pair eligibility**: without a qualified independent price source, do not enable the preferred full-imbalance-credit product. If arbitrary long-tail pairs matter more, choose a separately specified proportional-join/refund product. Do not silently switch the same instance between unrelated ownership rules when an oracle fails.

Full credit means the net reference value of retained assets, not guaranteed reimbursement of gross input or guaranteed exit proceeds.

### 2. Ownership, state, units and fees

- One share balance h out of supply S owns h/S of every shareholder-owned position, both idle balances and all shareholder fees.
- Store three range/liquidity/fee-checkpoint records, two owned idle balances, supply, immutable pool/target/reference/risk configuration, operation/callback guards and bounded-maintenance state.
- Keep entrant credit, unpaid refunds, exit escrow and genuine non-shareholder liabilities separate from the common book.
- Never cache deployed token amounts as permanent reserves: external swaps change composition. Store liquidity/ranges and derive actual principal for execution.
- New deployment uses 18-decimal shares and full-width, high-precision reference accounting; token transfers remain in each token's native decimals. Every adapter/SY metadata conversion must explicitly account for share and target decimals. The existing target-decimal initialization is not silently compatible.
- Recommend no additional first-release vault usage, entry, exit, performance or keeper fees. Pool trading/protocol fees remain real costs. This is a proposed new-family fee policy, not a claim that current surrounding defaults are zero.
- All current holders own ordinary accrued fees in common. There are no permanent section/cohort claims and no private rights transferred separately from ERC20 shares.
- At positive supply, direct and fee-growth donations become old equity, never entrant credit. Authorized pulls are measured independently. At zero supply, pre-existing surplus is excluded from first-minter credit and tracked for an immutable designated recovery recipient; it is not silently appropriated by bootstrap.
- Reject FoT/rebasing underlyings; non-18 token decimals remain supported. Token pauses/blacklists can still prevent transfers; no design promises otherwise.

### 3. Valuation and mint equation

Fix ONE independently validated reference snapshot P for the whole entry operation. For exposition P is whole token1 per whole token0; convert correctly to the raw-unit sqrt price for Q96 liquidity math.

For each existing or newly added range with liquidity L and sqrt bounds a,b:

```text
z = clamp(sqrt(rawPrice(P)), a, b)
x0_ref = L * (1/z - 1/b)
x1_ref = L * (z - a)
```

Use Inventory/SqrtPriceMath-equivalent fixed-point amounts with explicit rounding, not floating arithmetic. Convert x0_ref/x1_ref into a common target-denominated accounting unit using P and the actual decimals. Idle and accrued-fee amounts are already token quantities and are valued directly at P.

```text
N(book;P) =
    reference value of owned idle + accrued fees - real liabilities
  + sum(reference value of each L/range evaluated at P)
```

The reference composition is a valuation basis, not a claim that those token quantities are presently in custody. Actual removal uses live pool composition. In particular, do NOT compute current-spot LP amounts and merely multiply the opposing side by P while claiming spot independence.

After the entrant swap and the final old-fee checkpoint, let:

```text
S = old supply
A = N(old shareholder equity, including entry-earned old LP fees; P)
E = deposit-funded final liquidity increments + retained idle - refunds
C = N(E;P)
m = floor(S * C / A)                  for positive S and A
```

Use an old-equity upper valuation A_hi and contribution lower valuation C_lo under documented integer error intervals:

```text
m = floor(S * C_lo / A_hi)
```

No old position is removed or re-ranged to complete entry. Reference range value is linear in liquidity at fixed bounds/P, so the final book decomposes as old equity plus actual funded increments. Additions whose principal delta is netted against collected old fees require explicit principal/fee separation.

In ideal arithmetic, old holders retain reference value:

```text
S/(S+m) * (A+C) >= A
```

New holders purchase a fraction of old fees through the denominator; those fees are not part of their contribution numerator. Full overage credit is the value of the new wing/idle increments, not a limiting-token minimum and not the gross target input.

Illustration, not runtime evidence:

```text
old supply = 1000; old equity before entry swap = 1000
old LPs earn 2 during entrant swap
entrant input = 100; actual final contributed assets valued at 97
A = 1002; C = 97; minted = 1000 * 97 / 1002, before rounding
```

Credit cannot be fixed from post-swap wallet tokens and then assumed unchanged by a lossy reference-valued LP placement. Either credit final retained liquidity/idle as above, or retain the assets idle. The entrant bears its allocation cost.

### 4. Complete deposit sequence

1. Validate initialization, inbound registry status, recipient, deadline, nonzero inputs, operation lock and manager locked-at-entry. Freeze the reference round, freshness/confidence, live/reference deviation policy and entry-exposure budget.
2. Checkpoint existing equity and collect fees WITHOUT converted-wing closure/recentering. Reconcile unsolicited balances before measuring caller pulls.
3. Pull and measure authenticated caller funds into a segregated entrant tray. No arbitrary public pretransfer surplus claim. A separately authenticated operation-bound pretransfer design, if later required, needs its own proof and nonce accounting.
4. Target-only convenience entry initially swaps 50% of target input; an explicit plan may choose another bounded amount. This is an execution convenience, not a fairness formula. The dual-token route can skip the swap.
5. Spend only entrant credit through the configured hookless pool. Enforce a finite price limit, swap minimum and pre/post live/reference deviation. Default requires full intended consumption; a separately explicit partial-fill plan retains/refunds the unused entrant input.
6. Account ALL fees earned by the old LP during that swap into old equity. Do not approximate them as negligible or count them as input.
7. Add matched amounts to the full-range core using bounded direct amount/liquidity arithmetic. Add token0 overage to an eligible existing upper wing and token1 overage to an eligible existing lower wing. If a wing is mixed, unavailable, at capacity, or unacceptable under the reference cost policy, retain overage as credited idle or refund it under the chosen plan.
8. Do not overwrite a live range slot or reshape old equity during this entry. Record actual funded liquidity increments, principal deltas, fees, residual balances and refunds separately.
9. Settle manager deltas, compute final C and m, enforce user minShares/minimum credit plus protocol rounding-loss guards, and reconcile old equity plus entrant assets with actual custody.
10. Merge accepted assets and mint shares at the ownership cut. Pay only entrant refunds, emit actual contribution components and reference identifiers, then release the guard after final backing checks.

Failure reverts the entire transaction. The same contract-owned callback can carry this ordering inside its authenticated manager unlock; foreign unlock contexts do not get a skip-harvest/cash-payment branch.

### 5. Bootstrap, rounding and donations

- Require a valid reference and a real seed that can fund meaningful core liquidity. Target-only bootstrap uses real external depth; otherwise seed with both tokens. An empty pool cannot supply the missing token for free.
- Initial shares have one-whole-target accounting price per whole share, with a mechanical minimum credited seed of one whole target, plus pair-specific meaningful-liquidity launch criteria. This does not claim one target token alone prevents inflation.
- No permanent dead-share sink/fictional asset is proposed. Use high-precision shares/accounting, minimum minted share atoms and a strict reference-value rounding-loss invariant.
- Draft precision policy: minimum m of 10^12 raw 18-decimal share atoms, plus allowed issuance reference-rounding loss no greater than ceil(C/10^12) plus a documented valuation quantum. Calibrate/verify the quantum, bounds and repeated-attack profitability before deployment. User minShares alone is not the defense.
- Round funding upward and removals/issuance downward where appropriate. Do not use an under-rounded denominator to overmint.
- Direct and fee-growth donations are distinct from caller contributions. Their effect on equity does not waive the rounding guard. No arbitrary caller can recover someone else's tokens under a pretransfer flag.
- Last-share and rebootstrap cases must settle every real asset or defined surplus liability; no ownerless residual is silently inherited as new credit.

### 6. Complete withdrawal sequence

Offer normal strict target redemption and an explicit two-token in-kind redemption. The in-kind route is a liveness primitive, not a silent fallback.

1. Validate holder/allowance, recipient, deadline, nonzero shares, operation lock and manager locked-at-entry. Disabled inbound does not disable exits.
2. Collect all pre-exit fees without compounding/re-ranging, reconcile equity, and fix q/S of EACH position and both idle balances.
3. Burn/reserve shares and remove the assigned equity from the common book within the locked operation before any recipient callback. Public economic views cannot observe a lower supply backed by the old book.
4. Remove floor(q*L_j/S) from each position and floor(q*idle_i/S) from each idle amount. For q=S take ALL equity instead of repeating floors. Use actual removal principal and explicit fee attribution, not a simulated promised payout.
5. In-kind route pays the actual token0/token1 slice under per-token minima, without reference, quote or swap dependence.
6. Strict target route sells ONLY the exit tray's opposing inventory. Remaining vault liquidity is allowed to fill it; the fees it earns belong to remaining shareholders.
7. Pay actual slice target plus actual swap target. Enforce fixed user minTargetOut, finite directional limit, and full opposing consumption. Never top up from remaining holders' cash or sell their opposing inventory.
8. If unsold opposing remains, strict target mode reverts. A separately explicit residual-return route may return both outputs, never silently retain/zero-value that residual.
9. Settle, transfer, reconcile custody and release the guard. Atomic failure restores the burn/removals.

Target-only terminal success cannot be guaranteed after withdrawing the only liquidity that could buy opposing tokens. In-kind terminal redemption provides access to owned assets, subject to actual manager/token operability.

No constant-target-equity test is imposed on remaining LPs: their holdings can change through filling the exiter's sale. Test proportional ownership and attributable trade/fees instead.

### 7. Previews, getRate, projected state and exact-output

One execution model must simulate collection, q/S removal, actual principal, post-removal pool depth, sale fees/ticks, finite limits and residual policy. The current full-book quote removes ALL owned liquidity and cannot simply be divided by supply. A small-slice simulation retains the staying holders' liquidity as possible swap depth.

For target decimals dT, share decimals dS, raw input q, and quoted raw target output T(q):

```text
rate(q) = floor(T(q) * 10^dS * 10^18 / (q * 10^dT))
U = 10^dS
getRate() = rate(U)                 from strict canonical one-share execution
```

No clamp to NAV and no full-book average. Amount-specific previews quote their own amount; generally T(q)/q differs from T(U)/U.

Canonical getRate uses an immutable route/full-consumption policy and finite maximum price movement from the valid pre-exit pool state. A user may impose tighter constraints. The canonical execution quote does not require a healthy independent issuance reference.

If S<U, the whole-share slice does not exist: getRate is unavailable/reverts, including at zero supply. An initial issuance-price query is separate. Do not substitute a smaller trade, cached value, zero price or synthetic par and call it an executable whole-share quote.

Projected quote state includes pool/tick overlays, range liquidities, idle balances, fee checkpoints, supply, reference identity where issuance needs it, and schema/vault binding. Public data is not authority to settle fabricated book values; stateful execution rechecks actual data.

First release supports exact-input plus minima. Arbitrary swap-dependent exact-output surfaces are explicitly unsupported and not advertised. An off-chain solver can select an input and return surplus through a router. A future exact-output route is possible with a separately specified correct inverse/candidate-forward-verification and refund contract; do not call it mathematically impossible or preserve a linear inversion by relabeling it.

SY money paths use the same execution engine. If SY requires an accounting exchange rate, expose it explicitly with correct target metadata and NAV semantics; do not pretend it is the execution-quoted canonical getRate. Eligibility of that SY integration must be validated before enabling it.

### 8. Fees, compounding and range maintenance

All LP fees belong globally to current shareholders. No per-section ownership claims are needed.

- Separate fee collection from inventory mutation.
- Reinvest fee token0 into an eligible upper wing and fee token1 into an eligible lower wing; leave it as owned idle if not safely deployable. Do not swap communal fees merely to eliminate overage.
- Core funding on entry uses only entrant inventory. Separate maintenance may use recovered communal principal under its defined policy.
- Remove the first-release permissionless portfolio-funded bestSwap rebalance. Capturing a pre-call spot alone does not cure front-run displacement (audit 025 R2); a per-call loss allowance can also be repeatedly exhausted.
- No-swap wing replacement uses a fresh independent reference, a reference-derived tick-aligned gap wider than allowed spot deviation, movement trigger and epoch gate. Do not recenter simply because an unprivileged caller presents a displaced live spot.
- Close/collect a wing before replacing its slot. Compare old/new portfolios at the SAME reference. Charge permitted loss to an immutable cumulative epoch budget, not a resettable per-call tolerance; gains do not replenish the spent budget.
- Require non-dust progress and at most one replacement per slot/epoch. No keeper reward in the preferred first release. Common holders bear the permitted maintenance costs; entrant calls cannot force that unrelated cost.

Reference outages stop issuance and maintenance, not in-kind exit. Exact quote availability remains a separate market/work question.

### 9. Price-reference contract and deployment eligibility

Require a pair/chain-specific independent source with explicit direction, scaling, timestamps/rounds, confidence/error bounds, max age, outage/sequencer policy where relevant and cross-feed timestamp skew. A ratio of qualified independent token feeds can qualify; a TWAP label alone does not.

Reject same-pool spot, this vault's exit quote/getRate, the entrant's own self-selected executed swap price, and any circular downstream adapter as the issuance reference. Those are execution observations, not independent prices for unsold communal inventory.

Use one reference snapshot across the entry. Bound before/after spot deviation and cumulative new credit per reference interval/round; withdrawals do not replenish that interval cap. Such caps reduce exposure, not oracle truthfulness.

Stale/zero/inconsistent source: fail issuance and maintenance closed. Never fall back to current pool price. Do not deploy preferred full-credit instances for a pair with no qualified source. The source's actual availability remains an owner/deployer prerequisite, not a supplied fact.

### 10. Gas and quote liveness

- Three-position valuation, contribution accounting, principal calculations and slice arithmetic are bounded by the number of positions.
- Approximate entry sizing needs no stateful iterative root search. A supplied off-chain plan can improve the default 50% convenience split; the contract checks real results.
- Actual swaps and faithful previews can traverse arbitrarily many relevant initialized ticks/words. Three positions and a small quote size do not establish a universal gas bound.
- Do not silently skip small-liquidity ticks while claiming exact parity. Price-distance bounds alone do not bound attacker-created ticks in that distance.
- Use truthful work-limit versus market-liquidity failures. Never publish an incomplete target sale as a successful full quote.
- Deposits without a swap and in-kind exits do not depend on that sale walker. Target-only deposit execution, target redemption and getRate may still fail for work/gas/depth. In-kind access is the escape, not a promise that every view always succeeds.
- Gas figures in old records are not new measurements. Future gates require complete transaction receipts, deployed bytecode size and the actual consumer call graph.

### 11. External liquidity and manager integration

Canonical getRate is a live, size-specified execution quote. It is not a manipulation-resistant mark for unredeemed inventory. Actual-size output settlement does not validate every other rated reserve that fed the pool's price.

Recommended first listing: an ordinary price-discovering pool trading the actual vault ERC20 as a distinct asset, without target/share parity multiplication.

For advanced integrations:

1. An explicitly different NAV provider can expose independent-reference accounting value with freshness/exposure/size constraints. This is not a getRate replacement or a liquidation guarantee.
2. An execution-backed route redeems the relevant actual-size shares before paying target proceeds. It must not use manipulated unredeemed reserve values elsewhere in the trade.
3. The generic StandardExchangeRateProviderFacet currently uses a full-supply preview. A canonical-getRate change does not make that adapter a one-share forwarding adapter. Reject/rewrite the chosen wiring explicitly and test it.
4. Same-manager automatic buffering inside a foreign unlock is ineligible in this first release. Shares can be prepared/redeemed outside the outer unlock or traded as raw inventory. A future authenticated shared-unlock design is separate work.

The two-token LP claim and raw target are not economically identical. External parity/liquidation guarantees cannot be manufactured by assigning an IRateProvider.

### 12. Alternatives and disagreement retained

| Topic | Member positions | Coordinator choice / unresolved point |
| --- | --- | --- |
| LP principal valuation | Astra/Grok evaluate L/ranges at independent reference; MiniMax values live composition at reference | Use reference-evaluated ranges; live-composition marking remains spot-dependent and is not accepted as equivalent. |
| Executed entry price as numeraire | Kimi prefers self-executed average price, admits denominator attack unproved | Not release basis. A real small trade does not independently price the unsold old inventory; testing selected cases is not a general bound. |
| One-share getRate | Astra/Grok/Kimi preserve exact preview; MiniMax clamps to NAV | Preserve exact preview. A clamp changes the requested semantics and may still leave profitable in-band extraction. |
| No-reference pairs | Grok offers unpriced mode in same family; Astra offers separate proportional product; Kimi offers executed price | No silent oracle-outage mode switch. Separate explicit proportional/refund product if desired. |
| Common-reserve swaps | Astra/Grok remove initial swap rebalance; MiniMax keeps independent cap; Kimi keeps pre-call-spot bound | No first-release portfolio-funded swap. |
| Decimal choice | Astra proposes new 18-decimal shares; others keep target decimals | New 18-decimal shares with explicit adapter normalization; existing integrations not presumed compatible. |
| In-kind escape | Astra/Grok recommend explicit route; Kimi optional/off; MiniMax explicit | Required explicit in-kind route; never automatic unexpected output. |
| Fees and placement cut | Astra credits final added L/idle; other originals sometimes mint before placement or omit exact entry-earned fees | Final deposit-funded increments determine credit; all old fees in denominator. |

Oracle-free alternative: after fee collection, require a proportional addition to the actual asset vector (L_core,L_upper,L_lower,idle0,idle1), with rounded-up funding verified on chain. Off-chain solving can size the target zap. Refund unmatched assets; do not treat only total token-ratio matching followed by different range allocation as identical position ownership. This gives up retaining arbitrary imbalance as common shares, but not necessarily the target-only router UX.

Separate range/section claims work when users deliberately own different exposures. Internal ledgers behind one fungible share do not remove valuation. Genuine multiple claims need source-to-destination fee ownership; a fixed-basket wrapper restores proportional-input requirements, and a dynamic wrapper restores valuation.

No single aggregate sqrt(reserve0*reserve1) invariant has been established for heterogeneous ranges and idle/fees. Designing a new internally priced AMM is a separate product, not a demonstrated free solution.

### 13. Security gates and full validation scope

No finding is closed by this report. Static design hypotheses:

| Audit item | Chosen mechanism change | Required evidence |
| --- | --- | --- |
| APEX-012 | No live liquidation mint/target liability; independent range reference; final contribution; strict foreign-unlock rejection | Settled/unsettled JIT and spot round trips with all wallet, LP, debt, fee and remaining-holder effects counted |
| APEX-024 | Fraction of every position; sell only exit escrow; no remaining-cash top-up | Small/majority/terminal withdrawals, sandwiches, no unauthorized whole-book sale |
| APEX-025 | Remove swap rebalance; reference/epoch-budgeted no-swap maintenance | Churn, front-run/backrun, budget and range-replacement tests |
| APEX-026 | No sale walker for in-kind exit/dual-token issuance; truthful quote failures | Real dust ticks/empty words, quote exhaustion versus market limit, in-kind liveness; target quote failure remains possible |
| APEX-040 | High precision, explicit donations, seed/rounding guards, terminal accounting | Fee-growth inflation, one-atom mint, repeated dust/rounding, zero supply/rebootstrap |

Use the real manager, registry deployment, package/facets, price adapter and direct consumers. Build changed production artifacts before tests in a separately authorized implementation task; no SUT mocks. No tests were run here.

Required gates additionally cover: both target orientations/non-18 tokens; final net-contribution components and fees on add/remove; incumbent equity at a fixed reference; no escrow reuse; preview/stateful and projected sequential parity; unsupported exact-output selectors; reference-stale/update/deviation/round-cap attacks; actual LP inventories and debts on attacker unwind; same-manager negative paths and read-only callbacks; quote failure not turned into free zero-priced shares; real raw-share/NAV/execution-backed pool integrations; bootstrap below-one-share availability; registry inbound-disable/exit behavior; proxy selector matrix; full gas receipts and bytecode sizes.

Do not require identical shares for identical gross inputs if JIT genuinely improves the entrant's actual contributed assets. Hold final contribution constant or count the extra assets and provider inventory/cost. Do not demand constant stayer token composition after an intended trade.

### 14. Owner decisions and launch prerequisites

The design recommendation is complete as a machine, but not launch-ready parameterization. Owner/deployer must choose:

- Eligible pair/chain and qualified independent reference implementation, freshness/confidence/decimal policy and update risk.
- Deviation and per-reference cumulative-entry limits; canonical exit movement/work policy.
- Seed size/real liquidity, precision quantums and rounding thresholds validated for token decimals.
- Reference-derived wing gap, movement/epoch trigger and cumulative maintenance-loss budget.
- Immutable zero-supply surplus recipient.
- Acceptance of in-kind fallback, independent share denomination, no initial exact-output or foreign-unlock buffering, no portfolio-funded swap rebalance, and initial consumer eligibility.

Do not silently treat unselected parameters or nonexistent reference sources as implementation details already supplied by the session. Do not launch the preferred product with a same-pool fallback merely to support arbitrary pairs.

## Preserved disagreements

The substantive disagreements are tabulated in section 12. Historical PRDs remain evidence, not a veto on this current recommendation. The coordinator has selected a tradeoff; there is no unanimity claim. All four reviewers will receive this same immutable draft and can challenge any selection.

## Evidence gaps

- No pair-specific external reference, addresses, calibrated budgets, chain eligibility or live deployment inventory verified.
- No project test, PoC rerun, gas receipt or bytecode build.
- Original-read coverage differs: Grok did not read the quote walk body or historical PRDs; coordinator verified the walk/dispatch and direct fee settlement independently.
- Initial MiniMax/Grok/Kimi file creation used their ordinary writer before the patch-only delivery clarification; preserve those originals and disclose this method deviation. Future missing-patch feedback must be inline.
- Only relevant CP/weighted/direct-rate consumers were source-checked sufficiently to establish the valuation risk; no exhaustive implementation review of all integrations.
- Shared live tree, not an atomic revision snapshot.

## Coverage adopted from responses and coordinator checks

| Target | Status | Source/adoption | Gap |
| --- | --- | --- | --- |
| Common brief and user corrections | examined | all originals and coordinator conversation | no final implementation approval |
| APEX-012/024/025/026/040 | examined | all four originals; coordinator checked quoted sections | PoCs not rerun |
| Wings ownership/money/geometry/inventory/fees | examined | Astra full family, other originals, coordinator reads | no new code |
| Slice quote/walk and actual settlement | examined | Astra full quote; coordinator _removeOwned/_sell and PoolManager fee returns | future exact overlay unimplemented |
| Exact-output dispatch | examined | coordinator OutTarget/requiredInput checks and Astra | earlier arbitrary-price claim not adopted |
| Rate adapter | examined | all originals; coordinator direct read | replacement integration unimplemented |
| CP/weighted external rate use | partially examined | Astra/Grok/Kimi; coordinator LegLib | full consumer matrix unreviewed |
| Existing production-first base | examined as source | Astra | no runtime execution |
| Historical product law | partially examined | differing original coverage | superseded explicitly where selected |
| Public protocol docs | supplied via Astra | official flash-accounting fetch in original | no raw PDF/search content presumed usable |

## Limits

Static research, not security proof, audit closure, tested implementation or deployment approval. This draft is the coordinator's selection after four independent originals; the coordinator is not a fifth vote. Advisory review may produce revisions, which will be labeled in the final resolution rather than rewriting this draft.

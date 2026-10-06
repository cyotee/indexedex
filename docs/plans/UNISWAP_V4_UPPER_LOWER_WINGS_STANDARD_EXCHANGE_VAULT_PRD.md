# PRD — UniswapV4UpperLowerWingsStandardExchangeVault

**Date:** 2026-10-05  
**Version:** 0.4 — owner implementation rulings with precedence below  
**Status:** Implementation authorized. Owner policy rulings O1–O6 recorded; accounting, lifecycle and release proofs remain in progress. Not a security certification.  
**Required prefix:** `UniswapV4UpperLowerWingsStandardExchangeVault`  
**Council record:** [Consolidation](../research/uniswap-v4-upper-lower-wings-prd-2026-10-05/CONSOLIDATION.md)

**Implementation plan:** [UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.plan.md](UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.plan.md).

## v0.4 controlling addendum — owner implementation rulings (2026-10-05)

These explicit owner instructions supersede conflicting v0.3/v0.2 text and the execution plan's decision gates. They resolve policy; mathematical and execution verification remains the implementer's responsibility.

- **O1 — Unsellable inventory:** tokens that cannot currently sell are excluded from priced accounting and create no separately reserved recovery claim for existing holders. Keep physical custody/settlement accounting accurate; exclusion from V does not authorize a public sweep. When supply reaches zero, residual inventory is unowned and available as an incentive for subsequent interaction. No incumbent recovery ledger or sink allocation is required. If inventory becomes realizable while shares exist, the normal current-V calculation includes its proceeds.
- **O2 — Positive-value expectation:** the owner expects target-only deposits to ensure realizable value whenever shares are outstanding. Validate this as an invariant across trading, wing conversion, fees, external liquidity changes and sleeve depletion. The owner did not approve a recapitalization mechanism or the assistant's proposed blanket zero-value freeze. A counterexample must be demonstrated concretely rather than treating a hypothetical as an unresolved owner preference.
- **O3 — First depositor:** pre-existing donations/residual assets benefit the first depositor. Do not mint donation shares to a permanent sink. Preserve the possibility of zero total supply; a permanently locked minimum must not defeat the owner-directed residual lifecycle.
- **O4 — Costs:** the vault pays execution costs from reserves. Do not reopen payer attribution or reduce credited caller input by a separate placement-cost surcharge. Account actual reserve expenditure once, retain current fee-oracle integration, and continue to prove entitlement funding and bounded maintenance losses. Transaction gas remains paid by the transaction sender.
- **O5 — Sleeve:** read the effective percentage from `IVaultFeeOracleQuery.liquidReservePercentageOfVault(address(this))`. The oracle resolves instance/type/global defaults. No Wings-specific 20% default or independently selected sleeve percentage. The existing target/deployed-target denominator remains unchanged.
- **O6 — Routes:** immutable PoolKey and target token; only that target token is accepted on deposits and paid on withdrawals. Native ETH wrapping/unwrapping belongs to routers, never the vault. Do not reopen token-route choices or inherit opposing-token/dual-token/direct-swap surfaces. Implement applicable existing PRD/shared route semantics and verify integer exact-output behavior where required by consumers.

- **O7 — Positive-value reserve floor (implementation continuation):** following the real-pool zero-value witness and the proposed invariant enforcement, the owner instructed continued implementation through passing tests. Implementation proceeds with at least one native target-token unit retained locally whenever shares remain outstanding, including after fees and execution costs. This is a minimum reserve floor, not a replacement percentage: the configured oracle percentage still determines the sleeve above that floor. Release the floor on the final redemption. No permanently locked shares or separate recovery ownership is introduced.

## v0.3 controlling addendum — latest owner directions

This addendum supersedes conflicting v0.2 language below, specifically G3 harvest scheduling, V1/V2 complete-liquidation requirements, S2 expense attribution, RV-1/RV-2/RV-4/RV-7, and the corresponding acceptance checklist. The remaining strategy, target-only routes, geometry, withdrawal priority and security requirements stand. Authoring this PRD and its plan does not execute or authorize deployment.

**A1 — Market-limited opposing inventory.** V is current realizable target-token proceeds from hypothetical liquidation of the whole vault after removal of all owned liquidity. Attempt opposing conversion through reachable external liquidity; count actual quoted target proceeds only. An unsellable opposing remainder contributes no assumed sale proceeds but stays fully owned and accounted for. Later actual inventory may enter the appropriate one-sided wing or remain local until placement is possible. No market-capacity-only rejection of valuation is required. This supersedes the earlier all-or-nothing conversion requirement, not the whole-vault valuation basis.

Expose sold input, unsold input, target output and market-limited status. Zero active liquidity at one tick does not establish no reachable liquidity. Computational work exhaustion, overflow and invalid state are **not** evidence that the unexamined inventory cannot sell; reject those calculations explicitly rather than marking them market-limited. Hypothetical quoting does not execute liquidation or create a wing.

**A2 — Ownership when realizable value is zero.** Unsold inventory is not abandoned or transferred to the caller. The share issuance formula remains subject to validation, especially S>0 with V=0 and deposits before recovery of zero-sale opposing inventory. No division-by-zero workaround, reset of supply, confiscation, virtual denominator or automatic recapitalization is authorized. Present the concrete recovery/dilution analysis and obtain approval of its ownership policy before activating those issuance paths. This is an accounting gate, not a reversal of A1.

**A3 — Mandatory interleaved harvest.** Eligible idle vault money operations harvest converted wings first, then price/process the requested operation on the post-harvest state. Authenticate and isolate inbound credit before harvest; do not let collections absorb it into incumbent backing. Previews and transition quotes project exactly the same sequence without writing state. Ordinary harvest uses available paired assets, with no balancing zap; the expensive balancing swap remains in separate rebalance.

For an already-unlocked manager, preserve the owner's sleeve-only behavior: defer position mutation, use the actual current state and reject uncovered target payouts with requested/available amounts. No nested unlock. This explicit manager-state exception reconciles harvest with nested consumer support. Enumerate vault money entrypoints; ordinary ERC20 transfer/approval/permit does not become a maintenance transaction by implication.

**A4 — Rebalance expense.** Vault inventory pays rebalance trading and authorized portfolio-execution costs; its caller pays gas. No keeper reward is implied. Protocol-side loss, slippage and progress bounds remain mandatory; caller permission is not unlimited loss authorization.

**A5 — Implementation readiness.** The owner requested the separate implementation plan. Work on independent foundations can be scoped in that plan, but unresolved accounting, surface and numeric parameters remain explicit dependencies before their production money paths or release. No earlier council record proves this updated design safe. No code, tests, shell, configuration or deployment was performed in this document-authoring task.

## 1. Purpose and authorization

Create a separate Uniswap V4 hookless Standard Exchange vault configured with a PoolKey and one target currency. The vault accepts that target token, issues fungible shares referenced to whole-vault liquidation value in that token, and redeems into that token. It maintains a full-usable-range core and at most one upper and one lower wing, plus a target-token-only local liquidity sleeve.

This is deferred liquidity initialization: an initial single-token deposit can fund a one-sided wing without first solving a balancing swap. Ordinary pool trading can convert wing inventory. Permissionless separate rebalance harvests converted wings, can execute a balancing zap, builds the full-range core and restores the sleeve. Expensive balancing is not a prerequisite for every deposit or withdrawal.

**Revision precedence:** v0.2 supersedes v0.1's finite center, frozen contiguous envelope, 10/90 allocation, dual-token activation and swap-free maintenance proposals. Earlier geometric-invariant pricing discussions are research history, not the selected valuation basis. Whole-vault liquidation value is now the owner-selected basis. Earlier council artifacts remain unchanged and are not approval of this revised design.

The product must support useful single-token entry and withdrawal and composition inside eligible consuming pools and DETFs. The objective is predictable, affordable on-chain service, not merely a cheaper standalone demonstration.

This task authors a PRD only. No implementation plan, contract/test edits, restoration, deployment, migration, config change or instruction-file edit is authorized by this document. The next step after owner satisfaction is a separate implementation plan.

### 1.1 Owner-fixed requirements

- Use the exact prefix above for product-specific Solidity types/files, with normal `I`/`TestBase_` prefixes where appropriate.
- Preserve the current FullSpread Hookless and Pons-family products. This is additive, not their replacement or an upgrade of immutable instances.
- Each instance binds one immutable target token from its immutable hookless PoolKey; another instance may target the other token of the same pool.
- Use a full-range core plus upper/lower wing slots. Slots may be empty; first deposit need not fund the core.
- Shares reference current hypothetical whole-vault liquidation into the target token, accounting for owned liquidity removal, resulting pool changes and applicable fees.
- Accept deposits and pay ordinary redemptions only in the configured target token. No opposing-token deposit or withdrawal route is implied.
- Prefer preserving core liquidity: consume target-token wing, then opposing-token wing with conversion, before core/in-range liquidation, after using available local target tokens.
- Favor sufficiently funded redemption over exact-fit optimization; retained overage belongs to the remaining vault book and is placed in the appropriate one-sided wing subject to sleeve/rounding constraints.
- Place each wing immediately outside the current price at a valid tick boundary, extending to that side's usable protocol limit.
- Recognize a wing as harvest-eligible upon actual conversion, on a subsequent transaction that observes it; no autonomous execution or full-crossing requirement.
- Separate permissionless rebalance may execute the balancing zap and set the sleeve. Do not force that expensive operation into ordinary user routes.
- DETFs may compose eligible SE vaults and bare tokens. FullSpread geometry is not a universal DETF eligibility requirement.
- Include a real local liquidity sleeve and rigorous adversarial, invariant, integration and gas acceptance requirements.
- Do not remove useful scalar routes to make the gas tests pass.

### 1.2 Precedence correction

For this proposed product, the owner's latest direction supersedes an interpretation of DETF alignment D57 that would forbid non-full-range SE strategies. D57's full-range requirement remains descriptive of the existing FullSpread product; it is not a reason to reject this distinct family. No unrelated token, security, registry, deprecated-product or route-eligibility rule is waived.

This scoped correction is recorded here. No existing alignment PRD or instruction file was changed in this authoring round. Future documentation reconciliation must distinguish historical decisions from current product scope rather than erase history.

## 2. Provenance and evidence boundaries

The conversation identified `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` as a historical three-position locator. Its exact source/dependency closure was not independently retrieved in this round. Before implementation planning, obtain an authorized immutable source snapshot and compare its geometry, pricing and lifecycle against this PRD.

The later `92cdf89a^` snapshot restored earlier in the conversation is **center-only full-range**. The approximately 1.28M/1.29M whole-test gas figures belong to that snapshot, not the three-wing strategy. They are neither transaction receipts nor a matched-state comparison with the analytic FullSpread quote.

Direct historical documentation: `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_PRD.md:66–83` records frozen center-plus-wings, `centerWidthMultiplier=2`, `activeLiquidityBps=1000`, token1 in the lower wing and token0 in the upper wing. Lines 98–114 describe its subsequent replacement. This supports historical intent, not historical security or gas performance.

Historical source is a reference, not a trusted implementation baseline. Do not restore known delivery, bootstrap, refund or blocked-exit defects for fidelity. The newly specified full-range-core/target-token design is an explicit alteration, not a claim of byte-for-byte historical restoration. None of the previous gas measurements validates its liquidation quote or execution.

## 3. Product boundaries and identity

**Proposed home:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` with a mirrored hermetic test family. Exact files and execution steps belong in the later plan.

- A registry-deployed vault diamond owns the three positions directly. It is not itself a mined-address Uniswap hook merely because hooks consume its shares.
- Use Crane Facet/Target/Repo, CREATE3/FactoryServices and IndexedEx manager/vault-registry package deployment. `PkgInit` and `PkgArgs` live on interfaces.
- Distinct product ID, package names, CREATE3 salts, storage namespaces and discovery records; no identity collision with legacy or FullSpread deployments.
- Immutable pool and target-token binding; core bounds remain full-range. Wing bounds may change only through the controlled close/settle/reopen lifecycle below. No public arbitrary delegatecall, arbitrary position salt, user-selected swap target or administrative asset withdrawal.
- Registration is not automatic certification of every consumer configuration.
- Preserve existing FullSpread behavior and its separate unresolved gas work. Changes to shared helpers, if later necessary, need explicit impact review and regression coverage.

**Outside the described effort unless separately approved:** NFT import/conversion, keeper rewards, migrations, arbitrary hooked underlying pools, per-user positions, public opposing-token routes and a proportional basket-exit fallback. Native ETH/WETH treatment must be resolved in §15; do not silently advertise it. Wing reopening is in scope, unlike arbitrary recentering of the core.

## 4. Terminology and state model

| Quantity/state | Meaning |
|---|---|
| `token0`, `token1` | Canonical underlying PoolKey currency order; native currency uses an explicitly specified accounting face |
| `target`, `opposing` | Configured user-facing currency and the other pool currency; neither changes after deployment |
| `S` | Live vault-share supply, including permanent minimum/sink shares |
| `V(state)` | Current hypothetical whole-vault liquidation proceeds in target-token units, not a spot-price NAV or partial-holder liquidation quote |
| `F_i` | Actual spendable local inventory belonging to the incumbent book, excluding this operation's credit and liabilities |
| `D_ij` | Owned position `j` principal in token `i`, evaluated with exact finite-range math at the relevant state |
| `E_ij` | Earned, uncollected own-position LP fees in token `i` |
| `B_i` | Economic backing: `F_i + sum_j D_ij + sum_j E_ij` |
| `R_i` | Durable local custody snapshot, not economic backing |
| `C_i` | This operation's actual net contribution in matching native units |
| Idle/interactable | PoolManager is protocol-locked; vault can open its own unlock session |
| Blocked/nested | PoolManager is already unlocked for an outer operation; vault must not nest `unlock` |

PoolManager and vault reentrancy locks are different states. This product deliberately does not join an arbitrary outer session to mutate its positions. That is a product security boundary, not a claim that V4 generally forbids calls during an existing session.

## 5. Geometry and three-position lifecycle

### G1 — Full-range core and nearest-boundary wings

Let `s` be the pool tick spacing, `q` its current sqrt price, and `tMin/tMax` the minimum/maximum usable ticks. The proposed exact interpretation of “just outside” is strict separation from q:

| Slot | Bounds | Principal at creation |
|---|---|---|
| Core | `[tMin, tMax]` | Exact two-token requirement at q |
| Upper | `[u, tMax]`, u the nearest usable aligned tick with sqrtPrice(u) > q | Token0 only |
| Lower | `[tMin, l]`, l the nearest usable aligned tick with sqrtPrice(l) < q | Token1 only |

These wings are outside the **current price**, not outside the full-range core. They overlap the core's tick interval. Their outer edges extend to protocol usable limits; they are not one-spacing-wide positions. At an exact aligned price, strict separation uses the next boundary on the relevant side. Check actual sqrt comparisons and negative-tick mathematical floor, not truncating signed division alone.

No zero-width or out-of-bounds range may be created. If no valid wing exists at a price extreme, retain its inventory locally and expose the capacity condition; do not fake a placement or silently replace it with a swap. Placement arithmetic must cap liquidity to actual budgets and protocol capacity and retain rounding residuals.

### G2 — Desired allocation and lazy activation

The desired book is the full-range core plus a target-token one-sided wing and the configured target sleeve. With only target inventory, the core may remain empty. Both target choices must work symmetrically: target0 prefers upper; target1 prefers lower.

Use already available paired inventory for a budget-backed proportional core addition without a balancing swap. Preserve the target sleeve. Favor allocation leaving a target-token remainder where feasible; do not claim that arbitrary inventory can always achieve that without conversion. If only opposing inventory remains, put eligible opposing excess into its appropriate wing. No fixed 10/90 capital split is inherited.

Ordinary deposit placement must be bounded and must not invoke the expensive zap. If an occupied slot cannot accept fresh unilateral inventory without harvesting/reconfiguration, local retention is preferable to forcing portfolio-wide maintenance into the deposit.

### G3 — Harvest and reopening

A wing becomes harvest-eligible when its principal has actually converted into a nonzero amount of the other token; full crossing is not required. Accrued fees alone are not proof that principal converted. Compare precise principal amounts and actual price/range state, including integer dust and reversals. A pending eligible wing must never be treated as still one-sided for additions.

The next relevant transaction observes eligibility. Removal and consolidation require an available manager session. No autonomous transaction generation is assumed. Permissionless rebalance executes harvesting; the proposed user-path scheduling is to recognize eligibility without forcing general maintenance, with withdrawals removing positions as needed for payout. Whether every eligible idle user transaction must also perform a bounded harvest remains an explicit scheduling decision in §15.

Harvesting settles principal/fees, adds supported paired inventory to the core and assigns residuals to local custody or a newly out-of-range wing. Rebalance may additionally swap under §8. Before changing a wing's bounds, fully close and settle its old position and fee entitlement. At most three funded/unsettled managed positions may exist; no forgotten old liquidity, fee claims or unbounded historical iteration. Use deterministic slot identity and observability for every close/reopen.

Price entry or full crossing is not a guaranteed profitable conversion. Price can reverse before harvest. Fee exposure and inventory consequences must be documented, not advertised as guaranteed yield.

## 6. Custody, delivery and conservation requirements

**C1.** Book local custody separately from `B`. Never derive available inbound credit as stale total backing minus current deployed amounts. External price movements must not manufacture credit.

**C2.** Establish current-call credit before fee collection or synchronization can absorb it. Pull mode measures exact received delta and rejects short delivery. Public push mode applies the shared caller-bytecode restriction; no-transfer, short-transfer and replayed-credit calls fail with precise errors and complete rollback.

**C3.** Exact-input push processes exactly the declared amount and refunds nothing. Excess available unbooked inventory is not automatically this call's input. Exact-output push credit is `min(available, max)` and only unused credited input may be refunded. Exact-output pull transfers quoted used input only, not max-then-refund. Document self-share/SY internal context separately.

**C4.** Match current source-agnostic unbooked-surplus law: authenticated contract callers can supply credit from valid unbooked availability. Do not simultaneously promise original-donor ownership of unsolicited surplus. No caller can claim previously booked inventory. Pre-activation residual allocation and live donations must be specified separately.

**C5.** Fee collection moves `E` into `F` once. Returned PoolManager caller deltas and separately reported fees must not both be counted as cash. Protocol swap fees are not owned LP fees. Position increase/decrease rounding and placement losses are explicitly attributed; no fictional backing remains after loss.

**C6.** Every successful route ends with final local custody synchronization, after payout/refund/wrapping. Collection followed by a no-op rebalance still synchronizes. Transient operation credit and callback state are cleared on completion and restored on failure.

**C7.** Full-precision arithmetic, checked narrowing and signed bounds; mint/output floor, sufficient required input ceil. Supported decimal combinations are tested in native units. FoT and rebasing underlyings remain forbidden; pause/blacklist behavior is accepted with atomic failure.

## 7. Whole-vault liquidation valuation and share accounting

### V1 — Canonical liquidation function

`V(state)` is the net target-token amount obtainable by hypothetical liquidation of the entire owned book at the current state. Define one deterministic simulation used by previews, execution accounting, rates and transition projections:

1. Snapshot incumbent local custody, all three owned positions, earned fees, liabilities and pool state. Exclude the pending caller contribution from pre-entry valuation.
2. Hypothetically collect owned fees and remove all owned liquidity, using exact principal/removal rounding. Update projected active liquidity and tick changes for **all** owned positions, including overlapping core/wing endpoints.
3. Aggregate recovered target and opposing inventory with local inventory, net of actual liabilities.
4. Quote conversion of the entire opposing inventory through the configured pool **after the owned liquidity has been removed**, with current applicable swap fees, protocol fees, tick traversal, price movement and settlement rounding.
5. Add resulting target proceeds and subtract only applicable specified liquidation costs once. Gas expenditure is a separate network cost unless an explicitly approved valuation convention includes it.

Do not retain the vault's own removed liquidity in the simulated swap depth. Do not double-count callerDelta and feesAccrued. Do not replace this calculation with a spot-mark sum, geometric invariant growth, stale cached price or liquidation of only the redeeming holder's fraction.

Simulation is read-only: it does not actually unwind the portfolio. An already-unlocked manager does not by itself make valuation unavailable. Queries during an outer session must use the relevant current/projected pool state without treating another caller's transient deltas as vault custody.

### V2 — Completion and quote validity

The algorithm must distinguish a complete hypothetical liquidation from a partially filled opposing-token conversion. If remaining external liquidity, price limits, representability or work bounds prevent full conversion, never credit an assumed output for the unsold remainder or return a partial result labeled complete.

The owner's intended normal behavior is that current liquidation can be calculated. It remains a verification obligation to define and test its valid domain, including the case where this vault owns all available swap liquidity. No automatic stale-price fallback, emergency basket exit or haircut is approved. An unresolved complete-liquidation case is a release blocker requiring explicit specification, not permission to fabricate value or freeze all ordinary routes by default.

Three managed positions do not bound external tick traversal. Valuation must fit the gas/work objectives independently of moving the balancing zap to rebalance.

### V3 — Single-token bootstrap

Accept an actual target-token first deposit; reject opposing-token entry. No initial opposing token or funded full-range core is required. The initial book may be local target plus a target wing. A later permissionless rebalance can swap and establish the core.

Specify target-to-share decimal scaling, permanent minimum/sink protection, minimum nonzero issue, and pre-existing-residual treatment before implementation. Do not reuse a dual-token square-root bootstrap that would mint zero for a target-only deposit. Proposed convention for review: initially scale target units into share units and permanently lock an explicit small share minimum, while assigning pre-existing liquidatable residual value to the sink rather than the first depositor. Exact constants/formulas remain in §15.

### V4 — Subsequent issuance: valuation basis selected, mint formula to validate

For existing supply S and incumbent complete liquidation value V_before, shares represent fractional ownership of V. A target contribution must never be included both in V_before and as new credit.

The proposed accounting candidate for review is liquidation-value growth:

`m = floor(S * (V_after - V_before) / V_before)` for positive growth,

where V_after includes net credited contribution after explicitly attributed operation fees and placement effects, and before new shares are minted. It preserves incumbent liquidation value per share in ideal arithmetic when the state transition is fully accounted for. It is not yet a proof of manipulation resistance or route consistency.

The simpler `floor(S * netTargetCredit / V_before)` is equivalent only if the credited target amount equals the increase in V. Keeping the deposit locally without pool changes may make this true; placing liquidity, charging retained fees or performing other state changes can break that equivalence. Prove an optimization rather than assume it. Reject zero-mint deposits atomically; no silent donation or deferred receipt.

This candidate is not an owner-ratified formula. Final accounting must specify fee treatment, exact state ordering, placement-loss payer, zero-value/nonzero-supply behavior and integer bounds. No min-ratio across both currencies, internal-CP mint or oracle-NAV substitute may be silently selected instead of the whole-liquidation-value basis.

### V5 — Redemption entitlement and fee accounting

For exact-input redemption of s shares, the reference gross entitlement is:

`grossTarget = floor(s * V_before / S)`.

V_before is the canonical whole-vault liquidation quote immediately before this operation's economic changes. It is not replaced by a smaller partial-holder liquidation price because execution follows a different sequence. The initiating user bears the specified operation fees, but simulated liquidation costs already reflected in V must not be charged again under another name. Finalize the explicit gross/net fee convention in §15.

Honor the approved net entitlement subject to the user's minimum. Do not silently haircut it or burn extra shares to make settlement fit. If exact-output is offered, independently specify ceiling/inversion against the integer forward function and maximum authorized shares; do not assume linear inversion through state-changing execution.

### V6 — Required funding and non-dilution proof

The owner expects partial execution to cover the proportionate whole-liquidation entitlement and permits realization overshoot. Prove this relationship for the actual priority sequence, active own liquidity, fees, extremes and rounding. A favorable constant-product example alone does not prove the general case.

Evaluate remaining holders against the **same pre-withdrawal state**. A reference non-dilution condition, before separately authorized shared maintenance costs and explicitly bounded rounding, is:

`V_after / (S - s) >= V_before / S`.

Use full-width cross multiplication in verification, not lossy division. Separate execution effects, fee destinations and genuinely exogenous market changes. Realizing more assets is not the same as authorizing unbounded holder loss. An uncovered entitlement or violation is an atomic failure and a reported design defect within the intended supported domain—not an approved payout reduction. Proving useful-domain fulfillment and bounding permitted costs is required before release.

## 7A. Required withdrawal execution priority

The ordering below is owner-directed. Preserving core liquidity takes priority over avoiding an opposing-wing swap.

1. Use spendable local target inventory, excluding other operation liabilities.
2. If insufficient, remove enough from an out-of-range wing currently holding the target token.
3. If still insufficient, realize the out-of-range opposing-token wing before touching the core, and swap as needed into target.
4. If out-of-range sources are insufficient/empty or all funded positions are in range, remove liquidity from core/in-range positions to obtain the required target **without a swap where possible**.
5. Only if that is insufficient, convert opposing proceeds to cover the remaining target deficit.

Classify wings by actual current composition, not the token they held when opened. A mixed in-range wing belongs to the in-range stage. Within stage4, the deterministic removal priority among mixed wings and core must be specified and tested; do not silently reverse stage3 versus core.

Favor a bounded sufficient liquidity removal/conversion over an expensive exact-fit search. Pay the specified entitlement, not every token realized. Realization overage remains owned by the vault. Preserve the target sleeve, then place eligible remaining inventory into the appropriate out-of-range slot; if only opposing inventory remains, its opposing wing is valid. If placement is impossible, blocked or rounds to zero, retain and book assets locally. No dust burn or public surplus refund.

Overage settlement is operation-local, not an obligation to execute a complete balancing zap. Position updates, swap count and overshoot loss must be bounded. Final synchronization occurs after payout and permitted redeployment. The last economic exit/minimum-share residual case must not strand assets through arithmetic or falsely promise sale into the vault's own removed liquidity.

## 8. Liquidity sleeve and manager-state behavior

### S1 — Configured-token sleeve only

`D_target = sum_j D_target,j` is the actual target-token principal owned by the vault across core and wings. Target relation:

`F_target = p * D_target`.

For lossless placement without conversion, with `T_target=F_target+D_target`:

`targetFree = floor(T_target * pWad / (1e18 + pWad))`.

At illustrative p=20%,100 deployed corresponds to20 local, not20% of pool reserves or combined holdings. The denominator is not whole-vault liquidation value, all pool liquidity, or the target-token equivalent of opposing inventory. There is **no required opposing-token sleeve**. Opposing local balances remain owned and fully accounted for until deployment/conversion.

Rebalance swaps change token quantities; recompute the relation from the resulting book rather than hold the pre-swap denominator fixed. E is backing but not local cover until collected. If D_target=0, the target relation alone does not guarantee a positive payout buffer; account for retained local inventory without calling it an opposing sleeve or promising continuous capacity.

Use the established effective fee-oracle percentage and document zero/type-default semantics. Numeric default, bounds and absolute/relative deadband require approval;20% and5% relative deadband remain proposals, not owner-confirmed numbers.

### S2 — Idle maintenance

- Permissionless and separate from user deposits/redemptions. Open at most one authenticated manager session per rebalance transaction under the proposed execution structure.
- Observe all positions, harvest eligible wings, collect fees once, and settle exact token deltas.
- Use available paired inventory for the full-range core. **A balancing swap/zap is allowed in this function** to initialize or enlarge the core, including after a target-only first deposit. Expensive swap sizing must not be invoked by ordinary deposits simply because this function supports it.
- Restore the target sleeve against post-operation owned deployed principal; place residual inventory in eligible wings, preferring target remainder where feasible.
- Public callers cannot dictate unsafe pool/recipient/price/budget choices. Enforce protocol-side loss, impact, slippage and progress bounds; a caller's permissive minimum is not holder protection.
- No automatic keeper reward, share issuance, arbitrary recipient, or asset sweep. Caller pays transaction gas. Trading fees/price impact normally affect the traded vault inventory unless separately funded; authorize and bound these maintenance costs explicitly rather than falsely claim the historical depositor pays them later.
- Prevent repeated no-progress swapping and remove/add churn. Tests must include adversarial callers repeatedly invoking rebalance and manipulating price around it.
- A standalone transaction still has a gas cap. If the balancing method cannot fit, redesign or separately approve bounded staged maintenance; moving an unbounded solver here is not acceptance.

### S3 — Already-unlocked manager

No nested `unlock`, no position mutation/poke/fee collection by this vault, no assumed ability to close the outer session. Target deposits stay local and are valued with the canonical hypothetical liquidation accounting. Read-only liquidation valuation remains conceptually distinct from execution availability.

Compute the current target redemption entitlement; if `requestedTarget > availableLocalTarget`, revert atomically with a typed error carrying **both amounts**, e.g. `InsufficientLocalTargetLiquidity(requested, available)` (name proposed; values required). Error data is the diagnostic; events inside a reverted transaction are not durable logs. If covered, pay target from the sleeve without any underlying swap. Do not replace the valuation with local balance alone or apply an extra low-capacity haircut.

Permissionless rebalance must not attempt a nested session; its blocked-state rejection must leave state untouched. Quote interfaces must distinguish economic amount from current executable cover where their shared ABI permits, and follow the selected explicit failure convention otherwise.

### S4 — Availability limitations

A sleeve is capacity management, not unlimited liquidity. Publish local target cover, economic liquidation value and failure conditions distinctly. No opposing-token payout, queue, stale-rate fallback or emergency basket exit is inferred. Hypothetical quoting during a blocked session does not authorize actual pool operations in that session.

## 9. Public interface and route contract

Use existing shared interfaces where semantics match; product-specific extensions carry the new prefix. Enumerate every selector on interface → Target → Facet → package cuts → live proxy; no metadata-only compatibility.

| Route | Required behavior / condition |
|---|---|
| Target-only activation | Single-token actual funding, anti-inflation/sink accounting, empty core allowed, no mandatory zap |
| Exact-in target deposit | Whole-liquidation-based issuance, verified input, min shares, idle and blocked paths |
| Exact-in share redemption | Proportional whole-liquidation entitlement paid in target; prescribed realization order; local cover when blocked |
| Opposing-token entry/output | Unsupported; reject before lasting funding; do not advertise in token lists |
| Dual joins/exits and direct pair swaps | Not implied; do not install inherited legacy selectors that expose unsupported routes |
| Exact-output target/share routes | Specify supported integer inverse and caller maximum; do not infer support from approximate linear arithmetic |
| Native SY | Same economic routes, enumerated token lists, correct external/internal share funding and context; no double burn |
| Transition and unlock-context quotes | Complete projected state, correct caller/manager interaction state, same-state parity and sequential composition |
| Sleeve/position views | Custody distinct from backing, three identities, principal/fees, effective target and output cover |
| Maintenance | Separate permissionless harvest, balancing zap, core addition, target-sleeve restoration and residual wing placement; bounded and holder-protected |
| Import | Proposed excluded v1; no implied support from retained old selectors |

Preserve eligible exits when registry disables inbound operations. No absolute availability promise during token blacklist, unavailable underlying settlement or insufficient local cover.

Native ETH decision must explicitly define WETH face, PoolKey order, `msg.value`, wrapping/refunds, surplus native custody and receiver reentrancy. ERC20-only v1 may not claim native compatibility.

## 10. Quotes, rates and bounded work

- Project all three positions, relevant fee checkpoints, owned active liquidity, pool price/tick/liquidity, supply, local balances, caller credit and mode.
- A projected sequential operation must use its projected state, not overwrite it with live balances. Include rate/side-effect projections where consuming interfaces require them.
- Quote state is not authorization to spend caller or incumbent assets. Execution validates real settlement and user limits.
- No repeated external revaluation inside a numerical search without an explicit bounded call budget and measured worst case.
- One-share rate semantics must reference canonical target-denominated whole-vault V/S with explicit scaling/fee convention. Do not value a share by independently liquidating only one share's basket. Distinguish economic rate from current executable local redemption capacity and verify the consumer provider honors that distinction.
- Required rate-provider failure behavior is fail-closed where rates are required; no unit-rate, stale-rate or face-value substitution.
- Own-position active-liquidity changes must be tracked at each wing boundary, even where aggregate external liquidity-net is zero.
- Approve numerical ceilings for quote traversal/probes, swaps and manager mutations before the plan. Three owned positions do not bound the number of external initialized ticks a swap can cross.

## 11. Security requirements and historical regression targets

| ID | Requirement and required adversarial witness |
|---|---|
| SEC-01 | External trade changes deployed amounts, then attacker claims unfunded push: no credit or shares; contract attacker as well as EOA |
| SEC-02 | Booked custody cannot fund refunds, approvals or new depositor issuance; fat max with only used amount delivered |
| SEC-03 | Target-only dust activation → donation → positive-share victim deposit → attacker exit; pre-existing target/opposing inventory and residual sink cannot be captured |
| SEC-04 | Exact-input excess has no refund; exact-output pull uses only used; push refunds only this-call unused credit |
| SEC-05 | Cross-function/token callback, forged PoolManager callback, replayed payload, wrong pool/currency/budget and cross-instance attacks revert atomically |
| SEC-06 | Fee growth counted exactly once across collection/add/remove; fee wrapping and zero liquidity handled |
| SEC-07 | Core plus overlapping wing boundaries in both directions; exact ticks, negative rounding, extrema, empty/mixed/crossed wings, close/reopen and residual fees |
| SEC-08 | Manipulate hypothetical whole-liquidation depth by temporary liquidity/price changes; deposit/redeem/rebalance/blocked cycles, JIT and keeper sandwiches; no manipulation-derived overmint or unauthorized holder loss |
| SEC-09 | Depleted sleeve, token/provider failure and late slippage guard leave balances, shares, positions and context unchanged |
| SEC-10 | Disabled inbound preserves supported holder exits and SY routes |
| SEC-11 | No arbitrary execution, standing imported-NFT approvals, public asset sweeps, replacement of recipient or third-party pull without intent |
| SEC-12 | Registry identity, CREATE3 determinism, storage isolation, permit nonce/domain replay and proxy surface completeness |
| SEC-13 | Hypothetical removal excludes ALL own liquidity before conversion; all-own-liquidity, zero external depth, partial-fill and maximum traversal do not fabricate liquidation proceeds |
| SEC-14 | Same-state target entitlement is funded under priority sequence; bounded overshoot retained/redeployed, not refunded to attacker; terminal V/share invariant and fee attribution verified |
| SEC-15 | Expensive zap is reachable through separate rebalance but not automatically through ordinary entry; repeated permissionless rebalance cannot create uncontrolled holder losses |
| SEC-16 | Blocked economic quote remains distinct from local cover; insufficient sleeve reports requested/available and rolls back token/share/context state |

Oracle guards are not a security proof. If adopted, specify price units (not sqrt-price bps mislabeled as price bps), window, observation freshness, warm-up, deviation calculation, failure behavior and effect on exit liveness. No 25/50/10/1-bp FullSpread constant is automatically wings law. The council's 25-bp versus 100-bp/30-minute suggestions are uncalibrated and not selected.

Require conservation invariants over user assets, local custody, three positions, fees and share liabilities with explicitly proven rounding bounds. No generic one-wei allowance or profitable exploit labeled expected merely to turn a test green.

## 12. Consumer coverage and configuration enumeration

The coverage unit is **hook family × eligible vault assignment × buffered/raw mask × route × manager relationship × economic state**, not one representative wrapper.

### 12.1 Weighted

For each total leg count `n=2..8`, exercise each legal buffered count `b=1..n`; `r=n-b`. This includes eight Wings SEs in an eight-leg standalone Weighted pool. For a consumer requiring a raw DETF self-leg, at most seven of eight legs can be buffered. One buffered vault does not mean an invalid one-token Weighted pool.

Enumerate every legal buffered/raw mask and eligible family assignment, including homogeneous Wings, heterogeneous current SE families and mixtures with bare tokens. When exhaustive permutations are reducible by symmetry, provide a proof of equivalence, retain unequal weights/decimals and asymmetric price states, and seek explicit acceptance of any reduced matrix. Do not call pairwise coverage exhaustive. A generated finite matrix must list all selected, excluded, invalid and pending cases.

### 12.2 Other families

- Orbital: every legal 1–3 buffered-leg assignment, all-three-Wings included; distinguish DETF self-leg fixtures from standalone hooks.
- Curve and Balancer quad: all-four-Wings plus every legal mixed/raw assignment supported by their package rules.
- Single/dual constant-product and other eligible SE-buffer hooks: every legal assignment and both directions.
- DETF entry/mint/bond/burn/claim/staking/SY paths using shares, the configured target and bare-token legs, wherever advertised. Test rejection of the opposing currency for this vault; broad DETF composition does not require every SE to accept every pool token.
- Same-manager nesting, different-manager nesting, shared dependencies, repeated underlying pool exposure and rejected duplicate bindings.
- Existing FullSpread and Pons-family consumers as coexistence/regression controls. A hook used as an outer consumer is distinct from a hooked pool used as the vault's own underlying market.

No deprecated family is silently revived. Eligibility exclusions must cite current owner/product law. A slot count or interface match alone is not evidence of successful useful operations.

For every family, test instances configured with target0 and target1, target-only first deposit with empty core, partial/full wing conversion, separate rebalance before/after user activity, opposing-only backing, and sleeve exhaustion. Test two distinct instances on the same PoolKey with opposite targets; account for cross-instance effects rather than assuming one vault's quote cannot change the other's.

## 13. Gas and operational acceptance

Gas is a release requirement. It cannot be waived by increasing Foundry's harness limit or rejecting all expensive normal inputs.

- Record compiler version, optimizer, EVM fork, dependency revisions, linked runtimes, source/artifact identities, chain ID/block/client and funding state.
- Current repository tooling is reported as solc 0.8.35, optimizer runs 1, `via_ir=false`; reverify at implementation. No via-IR/config workaround.
- Measure full outer transaction receipts, including intrinsic/calldata and nested calls, as well as separately labeled quote-only/subcall diagnostics. `forge test` gas for a whole test function is not a transaction receipt.
- Verify active per-transaction limit independently of block capacity. EIP-7825 specifies 16,777,216 where active; 31M is not a portable acceptance cap. Verify target-chain activation/policy at the release block.
- Required gas cases: target-only activation with empty core; no-zap deposit; canonical whole-liquidation quote with all three slots funded; prescribed redemption and overage placement; cold/warm; every price region; maximum admitted work; fee accrual; empty/full target sleeve; separate harvesting/balancing rebalance; complete required consuming transactions including Weighted eight-buffered and four-buffered stable hooks.
- Measure balancing-solver cost separately from mandatory valuation cost. A costly whole-liquidation quote repeated by rate providers can recreate the original composability failure even if entry never swaps. Prove bounded quote reuse/projected-state correctness instead of hiding the expense in the harness.
- Proposed acceptance ceiling is at most 90% of the verified transaction cap for required successful production workloads, subject to owner approval. Block/sequencer/RPC constraints and useful-domain validation still apply. Define separate quote RPC limits where relevant.
- If the eight-leg operation cannot fit, the feature is not accepted as eight-leg compatible. Publish the failing configuration and trace; do not replace a real Wings SE with a cheap ERC4626 wrapper.
- Every changed deployable runtime must fit its chain limit, including the 24,576-byte EIP-170 gate where applicable. Measure final artifacts, not intermediate builds.

## 14. Verification and release definition

Use real registry-deployed vaults, packages, facets, manager, fee oracle, PoolManager and consumer hooks. Non-SUT hostile token/provider fixtures are allowed only for explicitly scoped failure tests; do not mock away the cost or behavior being assessed.

Required evidence: independent arithmetic references; deterministic regressions; fuzzed ownership/rounding; stateful invariants; full public-route/proxy coverage; adversarial catalog A–O applicability map; hermetic and relevant pinned fork validation; complete matrix manifest and actual end-of-run tallies; final runtime/gas measurements.

Refresh deployed artifacts before tests. Follow repository compile patience: do not cancel Solidity compilation without explicit owner consent. This PRD executes nothing.

Release requires all normative requirements mapped to source and executable evidence, no unresolved critical/high finding, every required compatibility cell resolved, and external security review appropriate to the capital at risk. Passing tests and council agreement alone are not proof of economic safety. Deployment/verification and migration authorization remain separate.

## 15. Review register and handoff

### 15.1 Settled strategy requirements — do not reopen by implementation convenience

Target-only user flows and activation; current whole-vault liquidation valuation; full-range core; nearest-boundary-to-extreme wings; observation-triggered eligibility upon conversion; separate permissionless rebalance allowed to zap; target-only sleeve on vault-owned deployed target principal; opposing-wing liquidation before core; sufficient realization/retained overage; atomic insufficient-local-cover error while blocked. Existing FullSpread remains unchanged.

### 15.2 Remaining specification and verification work

| ID | Item | Required resolution |
|---|---|---|
| RV-1 | Liquidation algorithm | Exact ordered simulation, fee conventions, completion domain, integer rules and bounded traversal; demonstrate useful quotes even in nested state without executing swaps |
| RV-2 | Mint formula | Validate value-growth candidate vs pre-entry rate pricing, state ordering, fee/loss attribution and manipulation; never include new input in denominator twice |
| RV-3 | Redemption funding | Prove prioritized execution covers allocated V proportion and preserves remaining-holder value within approved costs; specify overshoot bound and stage4 mixed-wing/core order |
| RV-4 | Harvest scheduling | Confirm whether normal idle user calls merely observe eligibility or must execute a bounded harvest; full balancing zap remains separate either way |
| RV-5 | Sleeve parameters | Percentage default/bounds, absolute token floor, deadband and effective-zero behavior; target-only denominator is settled |
| RV-6 | Bootstrap and metadata | Target/share decimals, initial share scale, minimum/sink and residual treatment for target-only activation; no dual minimum formula by default |
| RV-7 | Maintenance protections | Protocol-enforced swap/holder-loss/progress limits and expense attribution; caller gas is not the vault's trading fee; no keeper reward implied |
| RV-8 | Surface and platform | Exact-output support/domains, native ETH/WETH, SY lists, provider valuation/capacity semantics, pinned target chains and gas margin |

These items are not invitations to replace the selected strategy. Some are mathematical/engineering obligations, others require owner approval of a precise proposal. Record counterexamples and unresolved domains honestly. The user should not be asked to supply proofs. A separate implementation plan follows PRD satisfaction, not this authoring task.

### 15.3 Acceptance checklist

- [ ] Distinct product and opposite-target instance identity, no FullSpread behavior changes.
- [ ] Single-target first deposit and ordinary no-zap entry work with empty core.
- [ ] Exact valid wing boundaries, eligibility and bounded close/reopen fee lifecycle.
- [ ] Whole-book V simulation removes owned liquidity before quote; no fake completion or stale fallback.
- [ ] Issuance, redemption and residual value invariants hold across selected routes and rounding domains.
- [ ] Owner-directed withdrawal priority and retained overage demonstrated on real proxy execution.
- [ ] Target-only sleeve and blocked requested/available error proven, including valuation/cover separation.
- [ ] Permissionless separate rebalance can initialize the core, restores sleeve and survives adversarial calling.
- [ ] Applicable security catalog, stateful invariants, public selectors and consumer matrix pass without SUT mocks.
- [ ] Actual outer gas and separate rebalance fit verified network caps; all changed runtimes fit.
- [ ] Remaining register resolved with evidence and owner review before implementation authorization.

## 16. Sources and evidence ledger

Source review date: 2026-10-05. Source line numbers are navigation aids, not immutable revision attestations. Version0.2 is a moderator consolidation of subsequent explicit owner directions, not a newly completed council review of this changed strategy.

- `CLAUDE.md:26–61,93–107`: deployment, token law, tests and compile requirements.
- `.claude/skills/indexedex-testing/SKILL.md:25–37,152–186`: production-first, credit/refund/disable semantics.
- `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md:86–105,180–238,352–368`: catalog and security evidence requirements.
- Historical full-range PRD cited in §2, lines 66–114: wings intent and later supersession.
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:119–208`: current FullSpread sleeve convention, attribution and proportional issuance; precedent rather than automatic wings economics.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol:19–44,56–76`: exact orientation; price below the range uses token0, above the range token1. Local file pragma `^0.8.24`, port comment references 0.8.30; neither is the actual compiler measurement.
- Council source reviews cite current Hookless Common, PositionRepo, RouteTypes and shared quote interfaces; see retained originals for locations and gaps.
- Earlier pricing comparisons and corrections: [clarifications](../research/uniswap-v4-upper-lower-wings-prd-2026-10-05/clarifications/CONSOLIDATION.md) and [partial matched-exit research](../research/uniswap-v4-upper-lower-wings-prd-2026-10-05/matched-exits/PARTIAL_CONSOLIDATION.md). These addressed an earlier internal-invariant-entry design and do not validate whole-liquidation-value issuance. The matched-exit round remained incomplete after a researcher policy failure.
- Context7 `/uniswap/v4-core`, followed by primary upstream references: https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol and https://github.com/Uniswap/v4-core/blob/main/src/libraries/Position.sol . Mutable upstream main is not a pinned dependency revision. Nested unlock and unsettled-delta behavior corroborate the local design boundary.
- https://eips.ethereum.org/EIPS/eip-7825 : transaction gas cap specification; target-chain deployment/activation must be separately verified.

No shell, tests, compilation, git history operations, restoration or production edits were performed in this PRD revision. Only this Wings PRD was revised; existing FullSpread PRDs, plans, contracts and tests were not changed. No implementation plan was authored. No new gas, safety or runtime measurement is claimed.

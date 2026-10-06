# Implementation plan — UniswapV4UpperLowerWingsStandardExchangeVault

**Date:** 2026-10-05  
**Status:** Executable acceptance cells passed. Not a release, deployment, or audit. See records/uniswap-v4-upper-lower-wings/FINAL_HANDOFF.md. Owner rulings in PRD v0.4 supersede the original open policy gates.  
**Controlling PRD:** [UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md](UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md), **v0.4 owner rulings take precedence over v0.3/v0.2 and conflicting gates below**.  
**Execution:** A separate implementation task must name this plan. Deployment and migration require separate authorization.

## 1. Objective and non-goals

Implement a new, independent vault family with immutable hookless PoolKey and target token. Accept target-only deposits, including bootstrap; issue shares using approved target-denominated realizable whole-vault liquidation accounting. Maintain a full-range core, upper/lower wing slots and a target-only sleeve. Harvest before eligible idle money operations. Reserve balancing swaps for separate permissionless rebalance; withdrawals may swap according to the PRD's priority.

Unsellable opposing inventory remains owned but contributes zero hypothetical sale proceeds. A partly filled conversion is not a failed valuation merely because market capacity is insufficient. An unfinished calculation is not an authorized zero valuation.

Preserve FullSpread Hookless, Pons-family, existing consumers and unrelated work. Do not rename or overwrite the restored protocol-tree vault to make it this product. Do not migrate live storage, restore obsolete APIs wholesale, enable via-IR, raise gas caps, invent a keeper reward, expose opposing-token public routes, or add emergency basket exits without approval.

This is a moderator-authored execution specification using prior research and latest owner directions, not a claim that a fresh council round approved every implementation detail.

## 2. Required reading and baseline

Before implementation, read current `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and referenced development/testing rules; `docs/agent/INDEXEDEX_AGENT_LAW.md`; canonical `.claude/skills/indexedex-testing/SKILL.md`; and Crane `crane-architecture`, `crane-deployment`, `crane-testing`, `crane-adversarial-testing` under `lib/crane/.claude/skills/`. Read relevant SE/SY and DETF I/O product law rather than using historical comments as authority.

Record repository/submodule revisions, dirty paths, exact dependency/source/artifact identities, compiler, Foundry and EVM fork. The previous reported setup was solc0.8.35, optimizer runs1, via-IR false; verify rather than treating that as a new measurement. Coordinate overlapping work and preserve edits that predate this task.

Historical locator `35f47b5195d16fdf90fd7c032a10f8d3b916fd90` can inform wing placement. The restored `92cdf89a^` is center-only, not the historical three-wing geometry. Historic whole-test gas is not this product's baseline. Historical-source research is nonblocking unless actual reuse needs provenance/license review.

Never cancel an operation involving Solidity compilation without explicit owner consent. Arrange hours-long execution support before starting. Follow current worktree artifact-seeding law if using a new worktree; do not delete working caches/artifacts. This authoring task runs none of those operations.

## 3. File and integration scope

Notation: `P = UniswapV4UpperLowerWingsStandardExchangeVault`.

- Production root `W = contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
- Hermetic test root `T = test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`.
- Evidence root `E = docs/plans/records/uniswap-v4-upper-lower-wings/`.

### Planned production units

| Files under W, prefixed P unless noted | Responsibility |
|---|---|
| `interfaces/IP.sol`, `IPDFPkg.sol` (expand P in names) | Product/interface ownership of PkgArgs/PkgInit, routes/views/errors/events |
| `Repo.sol`, `PositionRepo.sol`, `Types.sol` | Immutable binding, three live position records, custody/context and projected-state types |
| `Geometry.sol`, `Inventory.sol` | Legal wing endpoints, classification, exact principal and owned-fee accounting |
| `LiquidationQuote.sol` | Post-own-removal pool overlay and market-limited conversion simulation |
| `Accounting.sol` | Approved bootstrap/issue/burn/fee arithmetic, independent of placement |
| `Harvest.sol`, `WithdrawalPlanner.sol`, `RebalancePlanner.sol` | Bounded operation-specific plans with explicit budgets and projected effects |
| `Common.sol`, `ExecutionDelegate.sol` | Authenticated callback/settlement and shared orchestration; split delegates further only with documented need |
| `InTarget/Facet.sol`, `OutTarget/Facet.sol`, `QueryTarget/Facet.sol` | Target-only entry/exit and projected/economic quotes |
| `LiquidReserveTarget/Facet.sol`, `RebalanceTarget/Facet.sol` | Cover/position observations and separate permissionless maintenance |
| `DFPkg.sol`, `Component_FactoryService.sol`, `test/bases/TestBase_P.sol` | Complete registry deployment and production-first fixture |

These are planned names/responsibilities, not a claim files exist. Use full product prefix in actual names; interface files start with `I`. Reuse compatible shared ERC20/permit/vault/SY facets instead of duplicating standards.

Consumer tests may be added under the matching Weighted, Orbital, Curve/Balancer quad and CP hook directories, plus DETF integration test directories. Shared test fixtures may live beside existing SeMatrix fixtures. List each concrete consumer path in the implementation scope manifest before editing.

Existing shared production interfaces, rate providers, fee-oracle code, manager registry wiring, FullSpread libraries and config are read-only by default. First attempt integration through current interfaces. If necessary glue cannot live in W, present exact paths and semantic impact for a scope amendment; do not silently refactor consumers. Fix neither unrelated failures nor the old FullSpread analytic solver in this task.

## 4. Decision and proof gates

Create `E/SPECIFICATION_DECISIONS.md` and `E/REQUIREMENT_MAP.md` before implementing money paths. Map every PRD requirement to files, tests and evidence. Open items do not prevent independent geometry/deployment/quote-reference work, but do block dependent production behavior and release.

### Gate A — Issuance, unsold recovery and bootstrap

For S>0 and V_before>0, analyze the PRD candidate `floor(S*(V_after−V_before)/V_before)`. Define post-harvest snapshots, credited input, fee destinations and actual placement losses. Prove any optimization to `S*credit/V_before`; never assume them equivalent.

Explicitly evaluate:

- Positive target value plus zero-sale opposing inventory: how new issuance participates in later opposing recovery.
- S>0,V=0: deposits, zero-value redemption and recapitalization. No automatic policy is selected.
- External LP removes depth, attacker deposits, depth returns and attacker redeems.
- New target input enables a no-swap core addition or changes V through positioning; separate actual contribution from incumbent recovery.
- S=0 with donated target/opposing inventory; initial scale, permanent minimum and sink allocation.

Deliver exact arithmetic examples plus executable references in the later authorized implementation. Seek owner approval of ownership/recovery policy and numeric bootstrap values. Do not silently require a new oracle or delete retained inventory to pass this gate.

### Gate B — Fees, costs and redemption funding

Create a table for user operation fees, fees already reflected in V, placement/removal loss, actual swap charges, fees recovered by remaining owned LP, and vault-funded rebalance costs. Name payer, recipient, timing and formula. Apply no charge twice. Interleaved harvest costs must be attributed explicitly rather than assumed free.

For fixed shares s, derive target entitlement from post-harvest pre-redemption V. Verify prescribed realization/overshoot can honor it without implicit extra share burns or haircut. Use remaining-holder V/share at the same pre-operation state as reference, with separately approved costs. Counterexamples block that path; do not lower the promised payout merely to make a test pass.

### Gate C — Work, losses and surface parameters

Approve finite total budgets for tick discovery/reads, valuation steps, harvest mutations, withdrawal removals/swaps, rebalance candidate evaluations and losses. Three slots alone do not bound external ticks. Require useful supported domains, not universal rejection.

Ratify sleeve default/bounds/deadband, per-instance identity parameters, native ETH/WETH policy, supported exact-output routes, initial share decimals/minimum, target chains and transaction margin. Proposed20% sleeve/5% relative deadband/90% cap margin are not automatic defaults.

## 5. Phase 0 — Inventory and preservation

**Work:** inspect current family architecture and shared interfaces; capture source/artifact baseline, old failures, existing tests and exclusions. Establish product ID and allowed-edit manifest. Identify consumer requirements for target-only tokens and economic rates versus cover.

**Outputs:** `E/BASELINE.md`, `E/SCOPE_MANIFEST.md`, initial requirement map and decisions.

**Done:** no ambiguity about old restored code versus new family, no hidden assumption of a clean worktree, and consumer suite identities are recorded. No rollout wiring.

## 6. Phase 1 — Pure geometry and independent accounting reference

**Work:** implement W Geometry/Types and test-local independent references under `T/reference/`. Core uses min/max usable ticks. Upper starts at nearest aligned sqrt boundary strictly above price and ends at max; lower starts at min and ends at nearest strictly lower boundary. Mathematical floor for negative ticks; reject collapsed positions, retain unplaceable assets locally.

Track principal orientation using actual price and amounts. Nonzero opposing principal qualifies a wing for harvest; fees alone do not. Reopening requires fully settling old principal and fee claims. Never accumulate hidden fourth positions or unbounded epochs.

**Tests:** both target orientations; aligned/nonaligned/negative ticks; protocol extrema; mixed/dormant/fully crossed/reversed wings; core-wing overlap; rounding debt ≤ budget; zero liquidity; invalid spacing. Test against independent arithmetic, not the production helper twice.

**Done:** deterministic geometry and inventories proven over intended ranges. No swap-sizing solver added here.

## 7. Phase 2 — Package identity, custody and callback framework

**Work:** implement Repo/PositionRepo, interface PkgArgs/PkgInit, FactoryService, DFPkg and production TestBase. Include PoolManager+PoolKey+target and other immutable policy-defining fields in appropriate instance identity. Distinguish opposite-target instances. Use canonical namespace/slot and CREATE3 patterns; no existing live storage migration.

Deploy real facets through factories and package/instance through manager registry. Bind callback to configured manager and active operation payload/nonce/budgets. Cross-entry guards must cover all money/maintenance surfaces while allowing only the authorized callback. End with zero unsettled currency deltas and cleared context.

R snapshots are actual booked local balances of both tokens/self-share where relevant; F excludes caller credit/liabilities. Economic B separately includes all owned D/E. Permit and pretransfer credit follow current law. No arbitrary delegatecall target or residual sweep.

**Tests:** Behavior-based Facet/package declarations, Target-derived selector list, live proxy loupe/smoke, registry discovery, deterministic identities, opposite targets, storage isolation, forged/replayed callbacks, double initialization, guards, pretransfer false claims, exact pull deltas.

**Done:** a real registry-deployed subject exists without a falsely enabled unapproved issuance route. No mocks of SUT/manager/fee oracle/PoolManager.

## 8. Phase 3 — Canonical realizable liquidation quote

**Work:** implement W LiquidationQuote with a hypothetical pool overlay. Snapshot current backing excluding new credit. Remove all owned liquidity from projected active liquidity and each affected boundary; collect E into projected F once. Quote sale of opposing inventory through the remaining pool and combine target proceeds with local/recovered target.

Expose value, input consumed, unsold amount and reason/status. Complete input and market-limited input are valid economic outcomes. Overflow/invalid state/work-limit cannot return a fake market-limited valuation. Follow external initialized ticks across empty active regions; shared boundaries and zero aggregate net changes must still account for owned removal.

No pool writes or hidden actual swaps. Use projected state after harvest where appropriate. No stale caches or live reads overwriting a supplied projection. Distinguish fee configuration from a consumer share-rate provider.

**Reference tests:** clone a state in a test harness, actually remove all own positions and perform the permitted opposing conversion, then compare proceeds, fees, consumed/unsold amounts and final pool state against the independent simulation. Fund real external LP positions through protocol fixtures. Cover all-owned liquidity, external gaps, directional exhaustion, partial sale, protocol fees and price extremes. Do not make the SUT mock its own output.

**Early gas probe:** measure pure V and nested repeated rate calls with three positions and high tick work before building every route. If budget is already infeasible, report and resolve algorithm choice; do not defer failure to final integration.

**Done:** valid market-limited V, honest computational failures and real reference parity. Gate A/B/C decisions remain independent requirements.

## 9. Phase 4 — Shared pre-operation harvest and quote projection

**Work:** implement one lifecycle shared by money execution and projections:

1. Validate route/deadline/caller, acquire vault lock and establish isolated credit or authorized share input.
2. Determine manager interaction state.
3. Idle: harvest every eligible occupied wing at most once for this operation; settle fee/principal, add available paired amounts to core without balancing swap, retain target sleeve and place eligible residuals.
4. Build the post-harvest incumbent snapshot excluding pending credit.
5. Execute/quote the requested operation and finalize local custody after payout/placement.

Blocked: no harvest position calls, use actual state, target inputs stay local, covered payouts use F. Pure views simulate required idle harvest. ERC20 transfers/approvals/permits and share receipt projections do not automatically trigger harvest merely because they are callable.

Define finite invocation order and do not recursively harvest newly created positions in the same operation. Split frames/helpers rather than enable via-IR. Stage enough state to revert the entire lifecycle if the requested operation fails.

**Tests:** two eligible wings; only fees present; eligibility at one opposing unit; price reversals; push input before harvest; late min-out failure; nested blocked entry; successive projected calls; projected ReceiveShares leaves supply/backing/pool unchanged under its existing interface contract.

**Done:** post-harvest preview/execution parity, no ordinary balancing zap, bounded state machine and rollback. User-gas profile includes harvest cost, not only the final deposit instruction.

## 10. Phase 5 — Target-only deposit and share issuance

**Dependency:** Gate A accounting choices and Gate B cost timing approved. Do not implement a V=0 recapitalization by intuition.

Implement target-only bootstrap with optional wing deployment and empty core; reject opposing entry before transfer. Implement approved positive-V issuance from isolated net credit and approved post-harvest/pre-mint states. Mint floor, reject zero mint, honor min shares. Match actual input/placement deltas and sink policy. Blocked target deposits use the same valuation definition with no position changes.

Use closed-form same-leg placement where possible; do not import the old analytic composition solver into deposits. If a wing slot is mixed/occupied or at an extreme, preserve approved local-retention behavior without losing credit.

**Tests:** both targets, mixed decimals, first deposit alone, second deposit, price changes between operations, donations before/after activation, partially sellable opposing recovery, fee collection, temporarily removed external liquidity, low/zero V, disabled inbound and route rejection. Prove per-share invariants and actual conservation, not only positive output.

**Done:** useful target entry under intended states and exact quote agreement; no unsupported recovery ownership policy hidden in code.

## 11. Phase 6 — Ordered withdrawal and retained overage

**Dependency:** Gate B entitlement/fee/overshoot rules approved.

After shared harvest, compute approved entitlement for authorized burned shares. Honor target minimum and fixed-share authorization. Planner order:

1. Local spendable target.
2. Out-of-range target principal.
3. Out-of-range opposing principal plus necessary conversion, **before core**.
4. In-range mixed wings/core removal to acquire target without swapping where sufficient.
5. Swap opposing proceeds only for remaining deficit.

Propose deterministic mixed-wing-before-core order in stage4, validate against holder protection and record it before implementation. Do not skip stage3 to optimize swap count. In-range classification follows state AFTER mandatory harvest; a stage can legitimately be empty.

Prefer bounded sufficient removal over expensive exact-fit solving. Return exactly approved payout, retain overage, preserve permitted target sleeve and place remaining eligible amounts into appropriate wings; do not run general balancing zap. Rounding dust/unplaceable amounts stay booked locally. Enforce minimums, protocol loss bounds, allowance cleanup and final custody sync.

Blocked: compare complete immediate target outflow obligation with actual available local target and revert with requested/available values if insufficient. Define whether error requested includes external fee outflows, consistently with net recipient amount. No nested removal or swap.

**Tests:** every priority stage alone and combined; full/partial/out-of-range/mixed slots; repeated tiny exits; oversized max; bounded overshoot; only opposing inventory; target payout while V includes market-limited remainder; zero V per approved domain; local insufficiency error; late failure rollback; remaining-holder V/share and actual asset conservation.

**Done:** exact entitlement funding across accepted domain, no additional burn or haircut, excess retained and accounted. Counterexamples to claimed coverage must be reported, not relabeled expected.

## 12. Phase 7 — Separate permissionless rebalance

**Work:** implement bounded harvest, quote/execute balancing swap, full-range addition, target sleeve reset using resulting principal, residual wing placement. Vault pays trading/approved maintenance costs; caller pays gas. No caller reward or share issuance.

Read/reuse existing math only after identifying valid domains and total nested work. Reusing a solver merely because it now has a separate transaction is insufficient; measure standalone worst case. If staged operations are needed, specify intermediate ownership, replay resistance and quote parity and obtain approval before adding a staged surface.

Protocol controls cap loss/impact and require progress; a caller's chosen min-out cannot be the only holder defense. Avoid oscillating remove/add/swap and repeated fee losses with unchanged target conditions. Rebalance is unavailable through nested unlock.

**Tests:** first single-token deposit followed by rebalance creates funded core; converted-wing harvest without swap; balancing swap with external/own active LP fees; opposing-only reserve; zero/default/max sleeve config; sandwich/JIT/manipulated pool; repeated calls; no-profit caller; blocked revert; failures leave all slots/balances/context unchanged.

**Done:** measured finite work and a justified holder-cost bound, with actual core/sleeve state validated. Permissionless access is not a safety proof.

## 13. Phase 8 — Public quotes, native SY and consumers

Implement selected In/Out and economic/position/sleeve views on live facets. Expose target-only token lists. Wire native SY semantics using current shared infrastructure, distinguishing product-native SY from native ETH handling. Do not inherit a legacy direct token swap, opposing deposit or basket exit merely because a facet contains it.

Implement `IStandardExchangeTransitionQuote` and applicable unlock-context/rate projection interfaces. Quote state carries all slot changes, unsold inventory and harvest effects. `ReceiveShares` changes holder inventory only as the existing interface specifies. Unsupported exact-output or other operations must follow explicitly selected product/consumer requirements, not silently succeed with invented amounts.

Assess the existing consumer rate provider: a one-share executable redemption preview may differ from canonical V/S, particularly in blocked state. Supply compliant integration in the new family; if existing shared production must change, request the scoped amendment first.

Generate a finite machine-readable coverage manifest for every eligible hook/vault assignment, raw/buffered mask, target choice and manager relation. Weighted n=2..8 with b=1..n buffered covers1..8 Wings vaults where legal. Eight buffered standalone is valid; adding a mandatory raw DETF leg limits buffered count to7. Include homogeneous8, stable quad4, Orbital3, CP and mixed existing eligible SE families. Preserve asymmetry of weights/decimals/targets; prove any symmetry reduction and obtain acceptance. Do not call pairwise sampling exhaustive.

**Done:** binding AND useful money routes with correct post-harvest/blocked semantics. Enumerate invalid/deprecated/skipped/pending cells. No substitute ERC4626 wrappers as evidence for real Wings gas.

## 14. Phase 9 — Adversarial, invariant and release gates

Add suites under T for Geometry, LiquidationQuote, Harvest, Deposit, WithdrawalPriority, Rebalance, Pretransfer, Donations, RecoveryValue, Manipulation, Callbacks, NativeSY, ProxySurface, Gas and stateful invariants. Use test-local independent expected math, real production deployment and real protocol ports. Non-SUT hostile tokens/providers only for documented failure tests.

Map PRD SEC-01..16 plus new addendum requirements to executable tests. Mandatory new witnesses:

- All-own-liquidity sale yields zero opposing proceeds but preserves actual ownership.
- Traversal work exhaustion never produces a cheaper apparently valid V.
- Unsold inventory recovery after adversarial external LP removal/restoration cannot evade approved ownership rules.
- Pre-operation harvest excludes caller credit and rolls back with failed user operation.
- Mandatory harvest plus repeated valuation fits complete consumer transaction budgets.
- Vault-funded maintenance losses stay inside approved limits under repeated permissionless calling.

Invariant ledgers include actual local tokens, all position principal, earned fees, share supply, fee recipients, transient debts, current-operation credit and unsold opposing inventory. Check no hidden fourth position/claim, no unfunded delivery, no public surplus capture, no double fees, consistent V and no stale quote-state reads. Exercise ERC20 permit replay, disabled exits, mixed decimals, token pause/blacklist, forbidden FoT/rebase delivery, native if approved, callbacks and rate failures.

### Validation workflow (for a later authorized implementer)

Refresh concrete runtime artifacts before testing. The repository workflow is `python3 scripts/forge-artifacts.py test <edited-production-sources> --test-root <selected-test-root>`; use exact newly created paths and repeated consumer roots from the scope manifest. Verify dependency selection includes every linked facet/delegate/package. Do not treat this command description as executed evidence.

Run focused tests per phase, then full new-family/adversarial/invariant suites, selected real consumer matrix, unchanged FullSpread/Pons controls and relevant pinned fork cases. Report complete exits/tallies, not truncated tails. Record changed deployed runtime sizes including libraries. No via-IR or test gas-limit increase.

Measure actual outer transactions with verified chain limits, including intrinsic/calldata, cold/warm cases and required nested rates/quotes. Report harness/subcall gas separately. Record worst supported tick/slot/work cases and separate rebalance. Distinguish market failure, arithmetic failure, policy rejection and OOG. Failing configurations remain named; no eight-leg compatibility claim if eight-leg fails.

### Release completion

All gates resolved, every requirement linked to source/test/evidence, no unresolved critical/high issue, selected matrix complete, public API reachable on proxies, final artifact sizes compliant and transaction budgets met. Independent audit/review is still needed; passing tests are not proof of economic soundness. No deployment or migration under this plan alone.

## 15. Evidence deliverables and stop conditions

Produce under E:

- `BASELINE.md`, `SCOPE_MANIFEST.md`, `SPECIFICATION_DECISIONS.md`.
- `REQUIREMENT_MAP.md`, `ACCOUNTING_AND_RECOVERY.md`, `VALUATION_PARITY.md`.
- `CONSUMER_MATRIX.json` and readable `CONSUMER_RESULTS.md` with explicit exclusions.
- `GAS_AND_SIZES.md`, `SECURITY_RESULTS.md`, `FINAL_HANDOFF.md`.

Preserve original failing witnesses before fixes. Report precise source/runtime versions, commands, exit status, complete suite tallies and unresolved limitations. LSP diagnostics alone do not establish stale or pre-existing failures.

**Pause dependent implementation and request a decision** if zero-V/recovery ownership lacks an approved rule, normal redemption cannot fund its entitlement, manipulation violates intended ownership, a required interface cannot express the economics, the gas budget cannot support useful required routes, or existing shared production needs out-of-scope edits. Continue independent permitted foundations where appropriate; do not claim complete or safe.

**Final implementation handoff:** summarize changed files, approved decisions, passing and failing acceptance cells, known gas limitations and audit follow-ups. Stop; do not deploy, migrate or overwrite unrelated work.

## 16. Source navigation and authoring limitations

Current source references reviewed for planning: `contracts/interfaces/IStandardExchangeTransitionQuote.sol:4–38` defines operations and ReceiveShares semantics; `:41–58` external/rate projection extensions. Canonical architecture: `lib/crane/.claude/skills/crane-architecture/SKILL.md:13–37,61–75,153–159`. PRD sources and prior security/custody references are in its evidence ledger. Read actual files again at execution because line numbers and worktree contents can change.

No new runtime/dependency verification, historical checkout, compilation, tests or gas measurement occurred during this plan's authorship. Prior review results are evidence to investigate, not passing gates for the new family. This task wrote the plan and synchronized the PRD addendum only.

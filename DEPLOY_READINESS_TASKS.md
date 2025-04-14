# Deploy Readiness: Pending Tasks Triage (tasks/)

Last updated: 2026-02-09

This report triages *pending* tasks under `tasks/` (non-archive) by how directly they impact a safe production deploy.

Assumptions used for prioritization:
- “Deploy” means mainnet/prod deployment of the IndexedEx Diamonds + enabling user interaction.
- Items that can cause loss of funds, broken invariants, or security issues in production rank highest.
- Pure refactors, UX-only, and test-only improvements rank lower unless they materially reduce deploy risk.

If any assumption is wrong (e.g., Aerodrome is out of scope for the first deploy), reprioritize accordingly.

## Critical (Block Deploy)

These are the items most likely to cause fund loss or critical security failures *if the affected feature is shipped*.

## High (Strongly Recommended Pre-Deploy)

These meaningfully reduce operational risk, misconfiguration risk, or “silent failure” risk.

3) `tasks/IDXEX-061-add-pretransferred-balance-validation/`
   - Status: Ready (not started)
   - Dependency: IDXEX-035 ✓
   - Why high: Adds an explicit sanity precondition for `pretransferred == true` flows across Basic/Protocol/Seigniorage commons, improving safety and debuggability.

4) `tasks/IDXEX-085-fix-richir-preview-compound-simulation/`
   - Status: Ready (TASK.md only)
   - Dependency: IDXEX-072 ✓
   - Why high: Removes hardcoded “magic-number” preview discounts/buffers and replaces them with an analytical compound-state simulation. Incorrect previews can cause user-facing failures (reverts due to min-amount checks) and erode trust in quoted outcomes.

5) `tasks/IDXEX-002-review-dfpkg-spec-coverage/`
   - Status: Ready (review; not started)
   - Dependency: None
   - Why high: Ensures every DFPkg deploy path is covered by runnable, meaningful specs (success + specific revert assertions). Prevents “untested deploy path” surprises late in deploy.

6) `tasks/IDXEX-010-review-fuzz-invariant-tests/`
   - Status: Ready (review; not started)
   - Dependency: None
   - Why high: Identifies gaps in fuzz/invariant coverage for math-heavy components. Not always a hard blocker, but strongly recommended before trusting mainnet economic logic.

## Medium (Helpful Before Deploy / Operational Quality)

1) `tasks/IDXEX-064-fix-preview-claim-liquidity-balance-source/`
   - Status: Ready (not started)
   - Dependency: IDXEX-051 ✓
   - Why medium: Aligns `previewClaimLiquidity()` with execution by using raw balances (not scaled18). Reduces UX surprise and improves minAmountsOut correctness.

2) `tasks/IDXEX-082-add-events-to-existing-fee-setters/`
   - Status: Ready (not started)
   - Dependency: IDXEX-054 ✓
   - Why medium: Adds missing event emissions for fee changes, improving monitoring/auditing and operational visibility.

3) `tasks/IDXEX-083-add-wad-percentage-bounds-validation/`
   - Status: Ready (not started)
   - Dependency: IDXEX-054 ✓
   - Why medium: Similar to IDXEX-066 but broader; explicitly notes an economics review is needed (some systems may intentionally allow >1.0 WAD). Treat as medium until policy is decided.

4) `tasks/IDXEX-057-add-balancer-v3-exact-out-fork-test/`
   - Status: Ready (not started)
   - Dependency: IDXEX-034 ✓
   - Why medium: Adds fork-level proof that Balancer batch-router exact-out refund semantics work against real chain state.

5) `tasks/IDXEX-062-add-permit2-path-test-coverage/`
   - Status: Ready (not started)
   - Dependency: IDXEX-035 ✓
   - Why medium: Completes branch coverage for `_secureTokenTransfer` Permit2 path in unit/spec tests.

6) `tasks/IDXEX-068-add-permit2-revert-selectors/`
   - Status: Ready (not started)
   - Dependency: IDXEX-037 ✓
   - Why medium: Tightens revert assertions so tests don’t pass on unrelated reverts.

7) `tasks/IDXEX-089-add-slippage-revert-selector-matching/`
   - Status: Ready (not started)
   - Dependency: IDXEX-049 ✓
   - Why medium: Same theme as IDXEX-068; improves test precision around slippage failures.

8) `tasks/IDXEX-070-add-transient-token-vault-deposit-test/`
   - Status: Ready (not started)
   - Dependency: IDXEX-037 ✓
   - Why medium: Strengthens transient-storage correctness with an “in-flight” callback read.

9) `tasks/IDXEX-075-move-protocolnftsold-to-repo-pattern/`
   - Status: Ready (not started)
   - Dependency: IDXEX-071 ✓
   - Why medium: Eliminates direct state variable on a Target (slot 0) in favor of Repo namespaced storage, reducing future upgrade collision risk.

10) `tasks/IDXEX-074-use-crane-one-wad-constant/`
   - Status: Ready (not started)
   - Dependency: IDXEX-041 ✓
   - Why medium: Consolidates constants; small but reduces drift.

## Low (Nice-to-Have / Cleanup / Test Ergonomics)

1) `tasks/IDXEX-058-dedup-refund-excess-seigniorage/`
   - Status: Ready (not started)
   - Dependency: IDXEX-034 ✓
   - Why low: Deduplicates an internal helper; no behavior change expected.

2) `tasks/IDXEX-069-extract-shared-test-dfpkg-base/`
   - Status: Ready (not started)
   - Dependency: IDXEX-037 ✓
   - Why low: Test-only refactor to reduce boilerplate.

3) `tasks/IDXEX-078-add-fuzz-harness-drift-detection/`
   - Status: Ready (not started)
   - Dependency: IDXEX-046 ✓
   - Why low: Documentation/guardrails against harness drift; helpful but not deploy-critical.

4) `tasks/IDXEX-079-use-stderror-arithmetic-in-fuzz/`
   - Status: Ready (not started)
   - Dependency: IDXEX-046 ✓
   - Why low: Improves test explicitness.

5) `tasks/IDXEX-080-asymmetric-double-deploy-test/`
   - Status: Ready (not started)
   - Dependency: IDXEX-047 ✓
   - Why low: Adds extra coverage; unlikely to change deploy risk.

6) `tasks/IDXEX-077-remove-aerodrome-debug-banner/`
   - Status: Ready (not started)
   - Dependency: IDXEX-043 ✓
   - Why low: Comment cleanup.

7) `tasks/IDXEX-090-remove-dead-ppm-bond-constants/`
   - Status: Ready (not started)
   - Dependency: IDXEX-056 ✓
   - Why low: Commented dead constants cleanup.

## Out of Scope for “Deploy Now” (Feature / Architecture)

These are valuable, but they don’t unblock deploying the current production scope unless you explicitly require them.

1) `tasks/IDXEX-012-frontend-ui-update/`
   - Status: Ready (not started)
   - Dependency: None
   - Notes: Important for operating the protocol via a UI and for repeatable local Base-mainnet-fork workflows, but not required to deploy contracts.

2) `tasks/IDXEX-013-implement-uniswap-v4-vault/`
   - Status: Ready (not started)
   - Dependency: None
   - Notes: Major new integration + ERC-6909 + unlock/callback. Treat as separate release train.

3) `tasks/IDXEX-081-remove-token-specific-exchange-routes/`
   - Status: Ready (not started)
   - Dependency: IDXEX-072 ✓
   - Notes: Reduces surface area and interface bloat; useful cleanup but not a deploy blocker.

4) `tasks/IDXEX-067-add-seigniorage-setter-interface/`
   - Status: Ready (not started)
   - Dependency: IDXEX-036 ✓
   - Notes: Requires a governance/econ decision: whether runtime seigniorage reconfiguration is desired.

5) `tasks/IDXEX-076-use-crane-constprodutils-for-proportional-deposit/`
   - Status: Ready (not started)
   - Dependency: IDXEX-042 ✓
   - Notes: DRY/refactor; do post-deploy unless you’re already touching those DFPkgs.

## Blocked

1) `tasks/IDXEX-084-erc6909-tokenid-vault-interfaces/`
   - Status: Blocked
   - Dependency: CRANE-255
   - Notes: Required for ERC-6909/V4-ish interface story; does not block deploying current non-ERC6909 flows.

2) `tasks/IDXEX-065-add-operator-fee-oracle-auth-tests/`
   - Status: Ready, but effectively blocked on wiring `OperableFacet` into the *test* DFPkg
   - Dependency: IDXEX-036 ✓ (task text also notes an OperableFacet wiring prerequisite)
   - Notes: Not required for deploy, but helpful to fully validate the owner/operator model.

## Minimum Deploy Checklist (Suggested)

If you want a conservative “ship it” posture, do these before mainnet:
- Complete: `tasks/IDXEX-059-fix-aerodrome-exact-out-swap-semantics/` (or explicitly exclude Aerodrome exact-out from scope)
- Complete: `tasks/IDXEX-060-add-reentrancy-guards-camelot-aerodrome/` (or document diamond-level reentrancy protection)
- Complete: `tasks/IDXEX-011-review-storage-layout/` and record findings in `docs/reviews/`
- Complete: `tasks/IDXEX-066-add-fee-oracle-bounds-validation/` and `tasks/IDXEX-073-add-lock-duration-ordering-validation/`
- Optional-but-recommended for user quoting reliability: `tasks/IDXEX-085-fix-richir-preview-compound-simulation/`

## Triage Gaps / Missing Info That Affects Priorities

These items change what is “Critical” vs “Can wait”:
- Which DEX integrations are in scope for the first deploy (UniswapV2 / CamelotV2 / Aerodrome / BalancerV3)? If Aerodrome is out, IDXEX-059/060 drop in urgency.
- Are you shipping exact-out (`exchangeOut`) routes on day one? If exact-out is disabled or not surfaced, IDXEX-059 is less urgent.
- Is there a known diamond-level reentrancy guard (and is it applied consistently)? If yes, IDXEX-060 becomes documentation/consistency rather than a security blocker.
- Fee policy decision: should any percentage fields ever exceed `ONE_WAD`? This determines whether IDXEX-083 is enforceable and what exact bounds to implement in IDXEX-066.

## Quick Stats (Active Non-Archive Tasks)

- Total pending task directories referenced in `tasks/INDEX.md`: 34
- Blocked: 1 explicit (IDXEX-084) + 1 prerequisite-noted (IDXEX-065)
- Reviews pending (no code changes yet): IDXEX-002, IDXEX-010, IDXEX-011

## Proposed Next Steps (Report-Only)

1) Confirm deploy scope (1 message answer is enough): which integrations and which user flows ship on day one?
   - DEX targets: UniswapV2 / CamelotV2 / Aerodrome / BalancerV3
   - Routes: exact-in only vs exact-in + exact-out
   - RICHIR routes: enabled/disabled

2) Convert the top deploy gates into a short checklist doc you can pin in a release PR:
   - “Must do before deploy” tasks (likely: IDXEX-059/060/011/066/073 depending on scope)
   - “Can defer” tasks
   - Explicit waivers: anything intentionally not fixed + justification

3) Create reviewer notes stubs for the review-only tasks so findings have a home:
   - `docs/reviews/YYYY-MM-DD_IDXEX-011_storage-layout.md`
   - `docs/reviews/YYYY-MM-DD_IDXEX-002_dfpkg-spec-coverage.md`
   - `docs/reviews/YYYY-MM-DD_IDXEX-010_fuzz-invariant-review.md`

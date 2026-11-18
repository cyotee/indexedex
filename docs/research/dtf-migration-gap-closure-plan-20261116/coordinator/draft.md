# Migration gap-closure implementation and test plan - draft r1

Draft identity: `dtf-migration-gap-closure-plan-20261116-r1`.
Date: November 16, 2026.
Status: council-authored implementation plan, awaiting the sole advisory pass.
This document plans future work; no implementation or execution has occurred.

## 1. Outcome, authority and preserved scope

The user requested a council implementation plan closing the accepted review
gaps. The outcome is usable booked donation remainders, a working native QA
lifecycle, truthful reward metadata, observed Raw/RawRate pricing parity, and
current evidence navigation.

Required inputs:

- Review: `docs/reviews/dtf-migration-implementation-council-20261116-0228/REMEDIATION_PRD.md`,
  SHA-256 `5df379c5865f3be2f74b70a834e1c48965b30c86697aeef41619b41dd36393ba`.
- Resolution: the same review root's `coordinator/resolution.md`,
  SHA-256 `4c4cf99eff4899a69f94b245665c7717097b342f3b9bb96c7bc02ed4d70ffe49`.
- Original implementation plan:
  `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
  SHA-256 `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`.

The November 15 scope correction and sections 1.1-1.10 remain governing.
Preserve original-wallet eligibility, source-native custody/conservation, the
NFT 3 split, TokenStaking conserved originals, full-original manual pricing,
keep-until-reloaded credit, immutable issuance, funded fresh cliffs, real paid
owner-first activation, reward gates and irreversible selector removal.

Do not restore the operator application, portable bundles, journals, holder
ancestry, automatic pricing capture, a selected live-production-composition
prerequisite, a mandatory NFT wrapper, or the rejected TokenStaking adapter
dependency. Do not add production ownership, upgrade, arbitrary withdrawal or
generic execution authority.

This plan repairs source for freshly built instances. It assumes no ability to
upgrade an already activated immutable deployment. Live deployment, funding,
activation, allocations and any deployed-instance remedy remain separate.
No commit, push, dependency installation or public transaction is included.

### Paths

| Alias | Repository-relative directory |
| --- | --- |
| M | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| T | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| K | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration` |
| S | `scripts/foundry/recovery/dtf-migration` |
| D | `docs/incidents/2026-09-16-dtf-recovery/migration` |
| B | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf` |
| C | `contracts/vaults/detf/common` |
| H | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted` |
| W | `contracts/hooks/uniswap/v4/standardExchange/weighted` |

### Scope-to-proof ledger

| Gap | Required change | Proof of closure |
| --- | --- | --- |
| F1 | Release booked genesis remainders through the existing explicit retained sweep | Actual LP progress without new payment before and after activation; conservation, failure and retry witnesses |
| F2 | Give the QA owner a genuine paid purchase and repair the two-stage sequence | Same local instance reaches payment, funded ordinary bond, activation and claims; missing purchase still rejects |
| F3 | Separate instance reward availability from principal style | Real tokenURI JSON and rendered SVG agree with actual claims for ordinary, cliff and role NFTs; ordinary packages unchanged |
| P1 | Add valid real-hook Raw/RawRate differential fixtures | Independent live-hook gross quote, exact user split, active non-unit rates, boundaries and live independence |
| F4 | Add current evidence links and portable exact native instructions | Every gap links current commands, sources/artifacts, results and limitations while historical records remain intact |

## 2. Chosen mechanisms

### 2.1 F1: release donations only through the existing explicit sweep

**Decision:** extend the already installed `sweepDust()` in
`M/UniswapV4DetfMigrationMaintenanceFacet.sol`. Add no public selector, method
argument, new owner permission, storage field or recovery stage.

The sweep remains permissionless and sends liquidity only to the existing
reserve/bond-child destination. The current owner still exclusively selects
genesis. A pre-live call does not release donations or create a reserve.

Implement `sweepDust()` with one outer `nonReentrant` guard:

1. Require idle children using the existing check.
2. If the ordinary reserve is live, obtain the fixed `_budgetTokens()` list.
3. For each non-self token, read its booked `donationInventory` amount. For a
   positive amount, set that donation book to zero, add exactly that amount to
   `residualInventory`, and emit the release event below.
4. Call the existing `_sweepDustBody()` and `_syncAllExpectedHoldReserves()`.

Do not call the inherited `_entrySweepDust()` from this newly guarded wrapper:
it already has a nonreentrant guard. Its two existing body operations are the
ones in step 4. Do not change the shared ordinary implementation.

Declare this event on `M/interfaces/IUniswapV4DetfMigration.sol`:

```solidity
event MigrationCapitalReleasedToResidual(address indexed token, uint256 amount);
```

The event records a book transfer, not successful liquidity consumption.
Events do not change the interface's callable selector set. Preserve existing
received/consumed/bootstrap event meanings and all sixteen removal selectors.

The handoff is:

```text
held_after_release = held_before_release
donation_after = 0
residual_after_release = residual_before + donation_before
next_operation_floor = held - residual_after_release
```

Release the book, never the total balance. Duplicate entries in the fixed token
list cannot double-release: the first visit zeroes the book. Exclude
`address(this)` so self-leg accounting stays untouched. The normal sweep then
joins spendable residuals; genuine refunds/dust remain residual for later
retries. It must not credit a donor, mint compensation, set the owner-purchase
marker, debit recovery inventory or expose arbitrary transfers.

**Why the handoff is here:** the ordinary bond path invokes
`_trySweepDust()` at `B/UniswapV4DetfTarget.sol:554-557`. Releasing at bootstrap
would let that implicit sweep consume the remainder before the intended
postactivation witness. Releasing only in explicit `sweepDust()` preserves
existing implicit-operation budgets and makes both Stage 1 and Stage 2
continuations directly testable. Do not add the handoff to `_sweepDustBody`,
`sweepDustAtomic`, `_beginBudget`, bootstrap or the bond path.

Preserve existing registry behavior; do not add a blanket parent-disable gate.
The existing underlying join rules still apply. Any propagated failure reverts
the release, swaps/joins, approvals and events together. A successful dust-only
call may leave residuals; that is not evidence of positive reserve progress.

### 2.2 F3: instance-wide reward presentation

In `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol::tokenURI`:

- Keep `migrationCliff = bond_.isMigrationPosition(tokenId_)`.
- Set `migrationPresentation = true` for this Migration-specific target.
- Set `rewardsClosed = !parent.migrationActivated()` independently of cliff style.

In `C/bondNft/DETFFundedBondMetadata.sol`:

- Keep titles, principal schedule, maturity and cliff/linear progress controlled
  by `migrationCliff` and the actual position.
- Use `migrationPresentation` for Migration reward banners, accrued-versus-
  claimable display and the `Reward delivery` trait for purchased positions.
- For a Migration ordinary purchase, describe linear principal and activation-
  gated reward delivery. Do not apply the cliff description to it.
- Continue using `_claimableRewards` for numeric rewards and total claimable
  value. Closed total claimable equals principal due, not necessarily zero.
- Preserve protocol ID 0's nonclaimable role, and fee/creator role semantics.
- The ordinary metadata target leaves the Migration fields false, retaining its
  ordinary output. No new `View` field is needed.

Touch `_uri`, `_purchased`, `_positionValues` and `_claimAttributes` only as
needed for these branches. Do not change `_claimableRewards` arithmetic,
economic claim methods, position state, gons, roles or activation.

### 2.3 F2: genuine payment through the QA owner

In `S/MigrationCoreLocalQA.s.sol`, add:

```solidity
function buyOwnerFirstBond(
    IERC20 token_,
    uint256 amount_,
    uint256 duration_,
    uint256 deadline_
) external onlyController returns (uint256 bondId_, uint256 lpOut_);
```

The helper pulls exactly `amount_` freshly from its fixed controller, checks
the received delta, approves only that amount to its bound parent, calls
`parent.bond(token_, amount_, duration_, controller, false, deadline_)`,
clears that approval, and verifies its preexisting token surplus is unchanged.
Use the existing safe ERC20 utility. Do not both pretransfer and pull payment.
No arbitrary payer/recipient/call route or marker setter is added.

Fix parameters at the script call site to the existing gold helper's values:
`pairA`, `1 ether`, `90 days`, and `block.timestamp + 1 hours`.
The controller uses its genuine locally wrapped fixture WETH, separate from
donation and recovery inventory. It approves the helper; the helper performs
the actual current-owner parent call.

Keep the current two entrypoints and their signatures:
`deployAndIssue()` and `exerciseAfterCliff(address parentAddress_)`.

Stage A:

1. Keep the production infrastructure, registry deployment and explicit helper
   ownership.
2. Donate the current 100 ether of each contribution leg, but bootstrap with
   50 ether of each. Record the remaining positive donation books.
3. Configure and independently issue compensation; keep the existing exact
   issuance/backing assertions before the ordinary purchase changes rewards.
4. Approve and execute the helper's separate 1-ether paid ordinary purchase.
5. Query the compensation ID from `independentIssuance(DEV).bondTokenId` and
   the paid ID from `migrationOwnerFirstBondTokenId()`. Assert IDs 3 and 4 for
   this controlled reservation order, but use queried IDs thereafter.
6. Assert positive funded ordinary principal, `isMigrationPosition == false`,
   ordinary duration, controller ownership, actual payment and cleared
   allowances. The independent bond stays a separate 90-day cliff.
7. Remove the second 100/100 donation from this specific QA scenario. Do not
   explicitly sweep yet. Assert the original booked remainders survived the
   ordinary purchase's implicit sweep.
8. Emit/query the actual parent/helper/child addresses and both IDs.

Stage B, called with the **parent address**, not the owner-helper address:

- Confirm current helper binding, controller and real paid prerequisite.
- Derive the compensation and paid IDs from the parent queries.
- Preserve the compensation principal-only flow while Stage 1 reward and
  combined claims remain closed. Keep the old donation books positive.
- Make the helper's `activate()` capture actual metadata for both IDs before
  and after activation. Add `uint256 indexed tokenId` to its QA-only
  `MetadataCapture` event.
- Verify activation and the sixteen-selector cut.
- Call the existing parent `sweepDust()` with no new donation. Require actual
  old-capital LP progress and donation-book release; record protected balances.
- Preserve later rewards, SY/deferred-role and repeat-claim assertions.
- The subsequent ordinary purchase is distinct from the owner-first purchase
  (normally ID 5). Use its returned ID, not an assumed old ID 4.

Keep the production activation prerequisite unchanged. The helper beneficiary
may be the controller: completed owner purchase is an instance fact, not a
requirement that its NFT remain with the administrative owner.

### 2.4 P1: valid observed raw-hook fixtures

Add `T/MigrationRawWeightedPricing.t.sol`, inheriting the existing Migration
TestBase. Do not inherit the older hook TestBase's `setUp`, copy its etched
Permit2, replace SUT code/storage or relax ordinary DETF admission.

Obtain actual native9 output DETF on each fresh fixture:

1. Fund the real Migration reserve and configure/issue compensation to the
   test wallet through existing helpers.
2. Advance the test clock past its real cliff; claim principal and use the
   actual receipt-to-DETF exit. Require an exact positive liquid DETF receipt.
3. Seed the comparison hook with a bounded positive portion of that balance.
   Do not mint parent DETF directly or impersonate the parent.

Deploy a separate four-leg registered production Weighted hook using the
already deployed manager, PoolManager, hook factory and `weightedHookPkg`:

| Role | Currency | SE binding | Weight |
| --- | --- | --- | --- |
| Original ETH | actual fixture `pairA`, native18 | zero | 0.3e18 |
| Original DTF | actual fixture `pairB`, native18 | zero | 0.2e18 |
| Output | real Migration `detf`, native9 | zero | 0.4e18 |
| Auxiliary | the other underlying currency of actual `se0` | `se0` | 0.1e18 |

Read the auxiliary currency from `IBasicVault(se0).vaultTokens()`, verify it is
distinct, and use the existing external fixture supply. Sort currencies and
their weights/SE/provider/decimal entries together. Use actual
`HookPkgArgsDecimalsLib` decimal helpers. The comparison hook's liquidity owner
is the test wallet; it is not substituted for the parent's valid reserve.

Use `HookFactory.findMineNonce`, `weightedHookPkg.deployVault(args, nonce)`,
all unordered `deployPair` calls, and `finalizeInitialization`, matching the
existing gold helper. `UniswapV4StandardExchangeWeightedBufferHookTestDeployLib`
is a reference for `deployHookInstance`, not a nonexistent `deploy` method.
Seed through real `joinNativeComponents` with actual allowances and receipts.
Require positive selected raw reserves, actual auxiliary SE inventory and LP.

Use fresh hooks for:

- R0: no raw input/output providers.
- R1: real `RateProviderFixtureLib.providerFor(create3Factory,
  diamondPackageFactory, se0, pairA)` and its `se1/pairB` counterpart on the
  raw input legs; raw output has no provider.
- R2: those input providers plus a real provider for `detf` quoted into `pairA`
  on the output leg, covering the evaluator's admitted RawRate output model.

Use production provider packages. Explicitly supplied providers survive
`fillMissing`; the auxiliary provider is derived from its real SE/token pair.
Require observed nonzero, non-unit rates for RawRate cases. Change backing via
genuine external-token transfers to the real SE, as the existing V3 backing
freeze test does, and require that the observed rate actually changed.
Rate bindings are deliberate arithmetic fixtures, not approved live economics.

Extend `MigrationWeightedPricingFixture` in
`M/TestBase_UniswapV4DetfMigrationSnapshot.sol` with
`observedHook(consumer, hook, seigniorage, weth, originalDtf)`.
Move the existing capture-to-input mapping into that test-only helper.
The existing `observed(subject, oracle, weth, originalDtf)` obtains its parent
hook and seigniorage and delegates to it, preserving current callers.
The new entry calls the real hook's `captureWeightedMintBook()`; it must not
invent reserves, derived balances, provider bytes or auxiliary deposit operands.

Install captured inputs through the actual current owner's
`setMigrationWeightedPricing`; use the existing `MigrationSnapshotConsumer`
for intermediate results with the real parent as its consumer/output identity.
Require the parent's `previewOriginalCredit` to equal the two separately
floored user results. The original parent reserve remains unchanged.

For each contribution on the same unchanged book, the independent oracle is:

```text
boosted = floor(originalAmount * (1e18 + p) / 1e18)
gross = realComparisonHook.previewExchangeIn(input, boosted, actualDetf).amountOut
user = floor(gross * (1e18 - p) / 1e18)
```

The hook applies its actual trading fee once. Successful raw-input quotes must
have zero input refund. Compare pair equivalent, uplift, fee/net, rated inflow,
gross and user values; expected gross must come from that real external hook
call, never a copied formula or the evaluator under test. For native18 raw
inputs, rated inflow is net for Raw and `floor(net * observedRate / 1e18)`
for RawRate, followed by the observed native scale.

Cover both contributions, nonzero fees/p, zero-component and zero-fee/p
controls, unequal weights, native9 output floors, actual max-in/output-reserve
boundaries and exact rejection bytes. Determine boundaries using the real
hook, not solely the evaluator. Exercise real rate/backing or pool mutation:
old loaded evaluation stays unchanged; a new observed book restores live
parity; a deliberate manual adjustment changes the quote without a live change.

Retain the current real V3/disabled-buffer comparisons and arithmetic vectors.
If a supported-domain differential fails, first distinguish fixture/capture
errors from an actual evaluator counterexample. Do not weaken the oracle,
change Weighted policy, add a mode or declare the gap closed. Preserve the
counterexample and diagnose the minimal canonical correction; any production
pricing correction must be explicitly recorded, tested and included in the
artifact/dependency verification. No speculative pricing rewrite is planned.

### 2.5 F4: current entry with preserved historical bodies

Use one current execution entry:
`D/gap-closure-20261116/<run-stamp>/verification.md`.
Prepend dated current-status links to `D/verification.md` and
`D/quote-evidence.md`; retain their original bodies verbatim below explicit
historical headings. Link manual pricing evidence by model and keep P1
unverified until its executed comparisons pass.

Prepend a current-plan/source-scope notice to `D/source-route-matrix.md` and
`D/recovery-route-disposition.md`. Preserve the old hashes as historical
provenance; do not rewrite old source observations or demand reruns solely
because the governing plan's scope paragraph changed.

Update `D/foundry-runbook.md` to require the current repository root, with no
machine-specific `cd` into a historical worktree. Its stage table must list
every actual `Phase_08_Stage_01_MigrationExecution` function by name:
prepare/deploy, fund/bootstrap, pricing, each configure function, independent
issue, owner purchase, activate, each existing fungible surrender and harvest.
Explicitly mark NFT surrender and the retained parent `sweepDust()` as
production operations not wrapped by that typed script. Do not add wrappers
only to make the table look complete.

Link actual future commands, source/artifact identities, results, decoded
metadata, fork scope and gas measurements. Keep old 236/183/28,641 results as
baseline observations, not expected new totals. Preserve the existing
task-11 numeric limits and shape restrictions. No new application, general
recorder framework, portable bundle or transaction journal is part of this work.

## 3. Work packages and edit boundaries

Use regression-first implementation for the concrete F1-F3 defects. P1 adds
missing differential evidence and need not manufacture a failing arithmetic
test when the existing evaluator is correct. No prose-pinning/source-grep tests.

| Task | Depends on | Primary owned files | Exit |
| --- | --- | --- | --- |
| 1 | None | New execution evidence directory only | Scope/toolchain/source baseline recorded |
| 2 | 1 | Maintenance facet, migration interface event, new DonationRemainder spec, relevant hostile/fork test extensions | F1 real progress, separation and failure tests pass |
| 3 | 1 | Migration metadata target, shared renderer, Surface/OwnerFirstBond/common metadata tests | F3 numeric/economic controls pass |
| 4 | 1 | Snapshot test helper, new RawWeightedPricing spec | P1 real raw-hook comparisons pass |
| 5 | 2,3 | CoreLocalQA script/helper, new CoreLocalQA helper spec | Honest payment/ID sequence and helper regressions pass |
| 6 | 2,3,4,5 | Execution evidence only unless an in-scope failure is diagnosed | Integrated tests, fork, actual native lifecycle and rendering pass |
| 7 | 6 | Five named current documents and new verification entry | Every gap has accurate current evidence and navigation |

Tasks 2, 3 and 4 may be authored in parallel only with these disjoint edit
boundaries. Task 2 does not edit Surface; its installed-selector assertions
belong in its new spec. Task 4 does not edit the core Migration TestBase.
Task 5 owns the native script. Serialize builds/tests that share `out/` and
`cache_forge`; parallel authoring is not permission for concurrent artifact
writers. Do not rerun a passed check absent a relevant source/artifact change.

## Todos

- [ ] 1. Record accepted scope and verification baseline.
  - Recommended task executor category: deep-low.
  - Read the accepted report/resolution and this plan; inspect current files for
    intervening edits. Preserve unrelated work.
  - Record actual Forge/Solar versions, relevant configuration, source hashes
    and resolved runtime artifact identities under the new timestamped evidence
    root. Use native read-only diagnostics; no installation or Git commit.
  - If a new worktree is separately chosen, follow the router's warm
    `out/`/`cache_forge` seeding law before compilation. Do not invent new
    FOUNDRY_OUT/FOUNDRY_CACHE_PATH/FOUNDRY_TEST roots for this task.
  - Acceptance: all five gaps, files and baseline evidence are identified; no
    historical result is represented as a repaired-source result.

- [ ] 2. Repair explicit sweep of booked donations.
  - Recommended task executor category: deep-high.
  - Implement section 2.1 only; no allocation/bootstrap/purchase behavior change.
  - Add `T/MigrationDonationRemainder.t.sol` on the real Migration TestBase.
  - Tests: `test_partialBootstrapRemainderSweepsBeforeActivation`,
    `test_partialBootstrapRemainderSweepsAfterActivation`,
    `test_preLiveSweepCannotReleaseGenesisCapital`,
    `test_explicitSweepDoesNotReleaseTwice`,
    `test_pairAndShareRefundsRemainSpendable`,
    `test_unbookedBalancesStayProtected`.
  - Use real 100/100 donations with 50/50 bootstrap, then assert positive LP
    progress, book/event reconciliation, no new bond or supply, no owner marker,
    zero temporary allowances and no caller payout.
  - The Stage 2 test must assert positive original donation books after the paid
    purchase and immediately before the explicit postactivation sweep.
  - Add a hostile transfer failure/reentry case using the existing external
    hostile contribution fixture. A test-only `setTransferRevertCaller(address)`
    and `ForcedTransferRevert()` may extend that external ERC20's existing
    `transferFrom`: when armed for the reserve hook, fail its actual pull.
    Keep default behavior unchanged. Require full book/balance/backing/routing
    rollback; separately have the token attempt reentry to `sweepDust` and
    verify the actual lock error. Do not mock the parent/hook/SE.
  - Extend `K/MigrationRecoveryDonation.t.sol` with a real recovery-inventory
    coexistence witness: on a partial-bootstrap instance, use its existing real
    legacy recovery helpers to book DTF, then sweep only genesis donations.
    Record matching physical balances and unchanged recovery book. No `vm.store`
    or synthetic write to that book.
  - Preserve existing GenesisCapital assertions: bootstrap still leaves its
    donations booked until the new explicit sweep. Do not weaken them.
  - QA: focused command C2; pinned K suite in C6; current EIP-170/surface suite.
  - Acceptance: real pre/post activation progress and all accounting boundaries
    hold; the callable selector set and ordinary package behavior are unchanged.

- [ ] 3. Correct activation-aware bond reward presentation.
  - Recommended task executor category: deep-low.
  - Implement section 2.2, keeping all economic methods untouched.
  - Add tests for a genuinely funded owner-first bond with positive accrued
    rewards: closed numeric rewards, principal-only total, partial/full linear
    maturity before activation, principal claim updates, then activation and
    actual reward claim. Zero accrued rewards cannot satisfy the main witness.
  - Retain cliff boundaries and reserved role behavior. Exercise an ordinary
    non-Migration package with real rewards; compare numeric/structural output
    rather than testing only a flag or pinning a full prose snapshot.
  - Decode attributes by trait name rather than assuming identical positional
    indices across bond classes. Keep exact units and clocks.
  - QA: C3, common metadata regression within C6, actual emitted SVGs in C7.
  - Acceptance: all displayed claimable values match the actual route gates,
    without changing linear/cliff principal policy or ordinary-package output.

- [ ] 4. Establish observed raw pricing parity.
  - Recommended task executor category: deep-high.
  - Implement section 2.4 in the existing snapshot helper and new
    `T/MigrationRawWeightedPricing.t.sol`.
  - Required tests: `test_RawObservedHookParity`,
    `test_RawRateInputObservedHookParity`,
    `test_RawRateOutputObservedHookParity`,
    `test_RawModelsObservedDomainBoundaries`,
    `test_RawModelsFrozenBookAndExplicitReplacement`,
    `test_RawRateManualAdjustmentWithoutLiveMutation`.
  - Use fresh valid fixtures per variant. Assert actual non-unit rates, positive
    input/output reserves, positive auxiliary SE inventory and meaningful
    successful quotes. Record full operands and exact success/revert outcomes.
  - A same-formula expected value or fabricated mode over a buffered hook is
    not the independent gross oracle. No new hook rate setter is assumed.
  - QA: C4; preserve existing pricing and V3/disabled comparisons.
  - Acceptance: real production-hook parity closes P1 at the tested declared
    model/domain scope, not a live-production composition certification.

- [ ] 5. Repair the retained native owner lifecycle.
  - Recommended task executor category: deep-low.
  - Implement section 2.3 in the actual script, keeping its external stage
    signatures and production activation guard unchanged.
  - Add `T/MigrationCoreLocalQA.t.sol` using the actual helper as an external
    caller and a real registry Migration instance.
  - Test missing-purchase activation rejection; honest fresh pull and ordinary
    funding; wrong controller; missing approval; insufficient balance; expired
    deadline; repeated Stage 1 purchase; and preservation of preexisting helper
    token surplus. Verify exact deltas and atomic rollback.
  - Preserve compensation ID semantics and query both IDs for later actions.
    Use the exact `pairA/1 ether/90 days` purchase values, not a placeholder.
  - QA: C5 and the actual two-stage native execution C7.
  - Acceptance: helper tests pass and the retained script, not an alternative
    simulation-only fixture, reaches activation and later claims.

- [ ] 6. Execute integrated and real-surface verification.
  - Recommended task executor category: deep-low.
  - Run C6 once on the final integrated source/artifact set, then C7 using the
    same source-qualified runtime artifacts. Inspect every actual exit.
  - Preserve raw failure attempts, nonzero test selection and diagnostic
    output. Fix failures caused by these changes; report unrelated preexisting
    failures without editing tests green. A required unresolved gate prevents
    a complete five-gap closure claim.
  - Capture the actual native transactions, source/artifact bindings, LP and
    token deltas, bond terms/IDs, metadata JSON/SVG and visual results.
  - Acceptance: focused and full tests, required pinned forks, native lifecycle,
    current gas/size constraints and metadata rendering are demonstrated.

- [ ] 7. Reconcile current documentation and completion evidence.
  - Recommended task executor category: writing.
  - Apply section 2.5 after actual results exist. Link each gap to its precise
    new test/native/visual evidence and retain any remaining qualification.
  - Use current plan identity without rewriting original plan checkboxes or
    historic review verdicts. Do not claim that four members tested the repairs.
  - Walk current links and exact function names. Label external historical raw
    log locations explicitly; new execution artifacts belong in this checkout.
  - Acceptance: a reader can find current scope, commands, results, models,
    measured gas and unresolved limits from every plan-named entry.

## 4. Future command and evidence contract

These commands are for the separately started implementation, not this authoring
run. Run from the current repository root. Variables are ordinary shell
conveniences, not a new configuration or bundle format:

```sh
ROOT="$(pwd -P)"
M="contracts/vaults/detf/protocols/dexes/uniswap/v4/migration"
T="test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration"
K="test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration"
S="scripts/foundry/recovery/dtf-migration"
D="docs/incidents/2026-09-16-dtf-recovery/migration"
E="$D/gap-closure-20261116/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$E"
export PATH="$HOME/.foundry/bin:$PATH"
export FOUNDRY_PROFILE=default
```

Verify the root contains `foundry.toml` and the named helper. Keep configured
`out/` and `cache_forge/`; never delete them, switch compilers to work around a
failure or enable `via_ir`. Record compiler identity and full creation bytes,
including metadata. Do not strip metadata to force artifact equality.

Start long commands through an owned background session with one completion
subscription and actual exit capture. Allow hours for a cold build; silence is
not failure. Do not run two shared-artifact writers concurrently.

### C2 - funding regression work

```sh
python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationMaintenanceFacet.sol" \
  "$M/interfaces/IUniswapV4DetfMigration.sol" \
  --test-root "$T/MigrationDonationRemainder.t.sol" \
  --test-root "$T/MigrationCore.t.sol" \
  --test-root "$T/MigrationGenesisCapital.t.sol" \
  --test-root "$T/MigrationHostileContribution.t.sol" \
  --test-root "$T/MigrationSurface.t.sol" -- -vvv
```

### C3 - metadata regression work

```sh
python3 scripts/forge-artifacts.py test \
  "$M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol" \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  --test-root "$T/MigrationSurface.t.sol" \
  --test-root "$T/MigrationOwnerFirstBond.t.sol" \
  --test-root test/foundry/spec/vaults/detf/common/bondNft/DETFFundedBondMetadata.t.sol \
  -- -vvv
```

### C4 - real raw-hook pricing comparisons

```sh
python3 scripts/forge-artifacts.py test \
  "$M/TestBase_UniswapV4DetfMigrationSnapshot.sol" \
  --test-root "$T/MigrationRawWeightedPricing.t.sol" \
  --test-root "$T/UniswapV4DetfMigrationSnapshot.t.sol" \
  --test-root "$T/MigrationWeightedPricing.t.sol" -- -vvv
```

### C5 - actual QA owner helper

```sh
python3 scripts/forge-artifacts.py test \
  "$S/MigrationCoreLocalQA.s.sol" \
  --test-root "$T/MigrationCoreLocalQA.t.sol" \
  --test-root "$T/MigrationOwnerFirstBond.t.sol" -- -vvv
```

The helper's current parser accepts multiple edited sources and repeated
`--test-root`. Its `script` action builds the target's runtime dependencies and
then invokes `forge script --use solar`. No placeholder command or invented
launcher is required.

### C6 - final integrated automation

After all edits, build before consumers:

```sh
forge build --use solar

forge test --use solar \
  --no-match-path '**/fork/**' --no-match-contract Fork

FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationMaintenanceFacet.sol" \
  "$M/interfaces/IUniswapV4DetfMigration.sol" \
  "$M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol" \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  --test-root "$K" -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv
```

The full hermetic log must explicitly include the new tests, existing Migration
invariants, ordinary V4 DETF, common bond/staking/metadata and Weighted-hook
suites. Do not repeat those subsets after a clean integrated run unless a
relevant source/artifact changes. Counts must be actual, nonzero new counts.

Use the existing `robinhood_mainnet_alchemy` alias and configured credentials
privately; fixtures retain their existing pins. Do not run forks in CI, change
the pin/provider to obtain a pass or call an unavailable fork a success.

### C7 - actual retained native lifecycle and rendered metadata

Start one owned, fresh, nonforked local Anvil as a background session:

```sh
anvil --host 127.0.0.1 --port 18548 --chain-id 31337 \
  --gas-limit 32000000 --balance 1000000
```

Confirm the port was free, preserve the owned handle, and verify node identity,
nonforked state, chain ID and actual header gas limit. Do not reuse or kill an
unrelated node. If occupied, select another free loopback port and record it.
The larger development balance is needed because the fixture wraps 10,000 ETH
plus pays deployment gas; it is synthetic local capital, not public funding.
Keep normal code-size enforcement.

```sh
RPC="http://127.0.0.1:18548"
DEV="0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

FOUNDRY_BLOCK_GAS_LIMIT=1000000000 \
python3 scripts/forge-artifacts.py script \
  "$S/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA" \
  --sig 'deployAndIssue()' --rpc-url "$RPC" \
  --broadcast --unlocked --sender "$DEV" \
  --gas-estimate-multiplier 100 -vvvv
```

The large Forge budget is aggregate simulation capacity, not permission to
exceed the node's 32,000,000 mined transaction limit. Require each transaction
envelope and receipt to fit that limit; preserve failures instead of raising
the node ceiling or disabling size checks.

Read `MIGRATION_PARENT` from this run's actual emitted log and verify it against
the deployment receipt, runtime code and `owner()` readback. Query both
position IDs and their stored start/duration. Set `CUTOVER_TS` to one second
after the greater of their actual maturity timestamps. These are measured
runtime variables, not sample addresses or guessed launch times.
Preserve the Stage A broadcast JSON before a later run replaces `run-latest`.

```sh
cast rpc --rpc-url "$RPC" evm_setNextBlockTimestamp "$CUTOVER_TS"
cast rpc --rpc-url "$RPC" evm_mine

FOUNDRY_BLOCK_GAS_LIMIT=1000000000 \
python3 scripts/forge-artifacts.py script \
  "$S/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA" \
  --sig 'exerciseAfterCliff(address)' "$MIGRATION_PARENT" \
  --rpc-url "$RPC" --broadcast --unlocked --sender "$DEV" \
  --gas-estimate-multiplier 100 -vvvv
```

Verify actual successful receipts and on-chain readbacks for payment, the
ordinary owner bond, activation/cut, explicit old-donation sweep and claims.
A console assertion or compilation alone does not establish mined success.

Save actual pre/post tokenURI JSON and embedded SVG for paid ordinary and
compensation bonds, plus reserved-role controls. Render the actual SVGs using
the existing local browser/image tooling. Inspect numbers, activation status,
linear/cliff labels, clipping and overlap. Preserve captures and a concise
visual verdict; no reconstructed mock images or prose-only test.

The native run provides a measured local gas witness for the changed existing
sweep and helper path. Existing task-11 target-chain limits remain historical
source-qualified evidence, not fresh ArbOS-fee estimates. No new bare fork
launcher, simulated receipt presented as mined, or unchanged gas campaign is
required. Stop only the owned node after preserving evidence and cleanup.

### Evidence files

Under the new timestamped `E`, retain:

| File/directory | Contents |
| --- | --- |
| `source-manifest.json` | Actual changed files and relevant runtime dependency/source identities; no claim that a short edit list certifies every dependency |
| `artifact-manifest.json` | Source-qualified artifact paths, compiler/settings, full creation-byte hashes and link/immutable substitutions |
| `commands.md`, raw logs and exit receipts | Exact invocation, cwd, profile, start/end, exit, actual test count and source/artifact scope; secrets excluded |
| `native-stage-a/`, `native-stage-b/` | Actual broadcast files, receipts, gas, runtime identities, balances, positions, LP progress and readbacks |
| `metadata/` | Actual JSON/SVG and rendered captures with bond ID/stage |
| `pricing-parity.md` | Observed bindings/operands, exact oracle and evaluator results, domain failures, model-specific coverage |
| `verification.md` | F1-F4/P1 closure ledger, ordinary/fork/native/visual/gas outcomes and explicit limits |

Do not invent a reusable evidence application. Bounded existing tool output and
small task-local extraction are sufficient. If compilation changes a relevant
artifact between gates, retain the prior evidence as prior-artifact evidence
and rerun only affected checks. No source/test weakening or metadata stripping.

## Final verification wave

- [ ] F1. Verify every gap against current evidence.
  - Recommended task executor category: deep-high.
  - Read the actual implementation diff and new evidence. Confirm all five
    ledger rows, real residual progress, the paid helper sequence, metadata
    availability, independent raw-hook gross oracle and preserved authority.
  - Reuse settled checks; review missing or contradictory evidence, not another
    blanket rerun. A required unrun/failing gate remains open.

- [ ] F2. Verify native receipts and rendered metadata.
  - Recommended task executor category: deep-low.
  - Confirm the actual parent argument, queried IDs, 32M envelopes, successful
    receipts, preserved Stage A artifacts, actual SVG captures and owned cleanup.
  - Do not conflate hermetic calls, fork tests, simulations and mined local
    transactions or infer public execution approval.

- [ ] F3. Publish truthful final closure and limitations.
  - Recommended task executor category: writing.
  - Verify links from the five current documents and record each gap as closed
    only with its new evidence. Preserve all historical text and failed runs.
  - State any unresolved technical or external-capability gate; no fabricated
    full completion, deployment approval or exhaustive security-audit claim.

## 5. Council synthesis and alternatives not selected

All four initial planning contributions settled and are preserved. The selected
F1 mechanism combines Astra's existing-book handoff with Kimi's explicit
permissionless sweep, using the already installed `sweepDust` rather than any
new selector.

- Grok/MiniMax owner-only release APIs add avoidable permanent ABI/authority.
- Kimi's new permissionless sweep API is unnecessary because the current
  maintenance facet already exposes the required fixed-destination operation.
- Astra's bootstrap-time handoff is not selected: a normal paid owner purchase
  implicitly sweeps and can consume the remainder before the planned Stage 2
  witness. The explicit-only handoff preserves that testable sequence.
- Grok's buffered-hook operand/pure-library comparison repeats the arithmetic
  evidence and cannot close observed raw-hook parity.
- The raw fixture must be separate from the ordinary parent's reserve. No
  bare-pair admission change or unresolved canonical-Permit2 deployment problem
  is needed when reusing the Migration TestBase and normal direct hook APIs.
- Metadata needs persistent instance context after activation; conditioning the
  added `Open` presentation only on `rewardsClosed == true` is insufficient.
- The helper must pull fresh payment once, not both accept a pretransfer and
  pull it again. Fixed beneficiary and actual 1-ether/90-day values are settled.
- Use the current 100/100 native donations, not the 1,000-unit amount mentioned
  in Astra's proposal. Stage B takes the parent, not the helper.
- Keep configured artifact/cache paths. Fresh alternate FOUNDRY_OUT/cache roots
  are not needed; preserve the repository's warm-artifact discipline.
- Native receipt proof requires `--broadcast --unlocked`; a simulation without
  broadcasting cannot produce the proposed mined gas receipt.

No owner product choice remains unresolved. Actual runtime values and any
failure diagnosis are execution work, not permission to invent another policy.

## 6. Participation, advisory and limits

Coordinator: invoking `xai/grok-4.7`, not an independent member vote.
Continued council sessions:

| Member | Route | Task | Initial delivery |
| --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high | st_01a1e26e | Member-published response |
| Grok | xai/grok-4.7:high | st_01a1e26f | Inline, coordinator archived |
| MiniMax | minimax/MiniMax-M3 | st_01a1e270 | Inline, one publication-only recovery, coordinator archived |
| Kimi | kimi-coding/k3.1-pro:high, global | st_01a1e271 | Inline, coordinator archived |

Native metadata established the existing task/session routes and high reasoning
for Astra/Grok/Kimi. MiniMax's adaptive compatibility override was observed;
actual per-request thinking remains unexposed. All continued at epoch 2 for
planning; MiniMax's publication-only recovery was epoch 3 with no tools.

One advisory pass on this exact identified draft follows. The final will retain
the draft, originals, feedback and each concern's resolution. Final coordinator
revisions will not be represented as newly member-approved text.

This was source-grounded planning, not implementation or runtime verification.
No tests, builds, Git, RPC, transactions, deployments or product edits occurred.
All checkboxes above are future work. The plan authorizes no public operation,
financial allocation or repair of an immutable live deployment.

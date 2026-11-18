# Identity

- Member: **kimi**
- Role: independent research/plan-authoring council member
- Requested model/route: **kimi-coding/k3.1-pro:high**, global route
- Runtime identity: **not exposed**
- Assignment: `dtf-migration-gap-closure-plan-20261116`
- Publication: `apply_patch` is unavailable; the complete contribution is returned inline. No alternative writer was used.

# Question and targets

Provide one decision-complete implementation and verification plan for accepted findings F1-F4 and pricing qualification P1.

The plan covers:

1. Making legitimate post-bootstrap `donationInventory` reach the new reserve.
2. Repairing the retained native QA owner-first purchase and lifecycle.
3. Making reward metadata match activation for every Migration bond.
4. Making current native evidence discoverable and the runbook portable.
5. Establishing real observed-hook Raw/RawRate differential parity.

It does not reopen the migration audit, restore the withdrawn operator application, add a mandatory NFT wrapper, change the production activation prerequisite, or authorize deployment.

# Evidence

## Facts read

- F1: `UniswapV4DetfMigrationPolicy._beginBudget`, `_endBudget`, and `_residualBalance` already provide a protected residual-spending domain. `UniswapV4DetfMigrationWeightedHookTarget._releaseDonation` currently releases a fresh live donation by reducing both `donationInventory` and `operationFloor`. The common `_sweepDustBody` performs bounded fixed-route reserve joins and retains unjoinable refunds.
- F2: `MigrationCoreLocalOwner` has no purchase method. Its independent compensation bond is ID 3; the next genuine purchase should be ID 4. Production activation correctly requires `ownerFirstBondTokenId != 0`.
- F3: `DETFFundedBondMetadata` already separates `migrationCliff`, `migrationPresentation`, and `rewardsClosed`. Its `_claimableRewards` zeroes closed rewards, but ordinary Migration purchases currently do not receive the activation-specific presentation because `migrationPresentation` is false for them.
- F4: current native results and numeric gas records exist, but the named verification/pricing documents remain historical and the runbook selects a machine-specific historical worktree.
- P1: `UniswapV4DetfMigrationSnapshot.t.sol` supplies real V3 and disabled-buffer comparisons. `MigrationWeightedPricing.t.sol:338-364` changes Raw/RawRate manual modes but supplies arithmetic vectors rather than observed raw-hook comparisons.
- A bare non-self pair is incompatible with ordinary DETF composition: `UniswapV4DetfProcessArgsLib.storeHookSetsAndRates` raises `BarePairForbidden`.
- The production Weighted hook requires at least one SE (`ZeroStandardExchangeRequired`) but permits a rate provider on a raw leg. Its decimal validation supports a real nine-decimal output token.
- `MigrationWeightedPricingFixture.observed` and `MigrationSnapshotConsumer` can be reused where their inputs are semantically valid. Existing production capture records raw reserves, rates, scales, weights, fee, and model-dependent state.
- The existing Weighted hook TestBase’s `vm.etch` installs the existing Permit2 dependency at its canonical address during setup. It is not a hook/SUT storage or code replacement. No additional `etch`, `store`, or post-deployment SUT mutation is needed.

## Existing execution context

- Current full hermetic record: 28,641 passes, zero failures/skips.
- Post-removal Migration records: 236 hermetic and 183 pinned-fork passes.
- Existing target-gas record: 32,000,000 transaction ceiling, with separately admitted loading, issuance, construction, and recovery shapes.
- Existing records are evidence for their source scope, not proof that the repairs in this plan have executed.

## Design inferences

- F1 should reuse `_releaseDonation` and the existing sweep instead of creating a second join/accounting path.
- P1 should use a real Weighted hook without attaching bare inputs to an ordinary DETF package.
- F3 should treat `migrationPresentation` as instance-wide presentation context while `migrationCliff` alone controls principal style.
- No owner product decision is unresolved.

# Assumptions

- Changes target current source and freshly generated deployment/test artifacts. No already activated immutable deployment can be upgraded by this plan.
- Future local QA uses only development accounts, local chains, and explicitly synthetic fixtures.
- Historical source evidence remains valid within its recorded source scope; documentation updates do not reauthenticate it.
- Actual financial allocations, public funding, activation, and legacy governance remain outside scope.
- FactoryService consumers read creation bytecode from `out/`; concrete artifacts must be refreshed before tests or scripts.

# Coverage

| Target | Planned coverage |
|---|---|
| F1 production funding | Interface, retained target/facet, accounting transitions, actual LP progress, refunds, rollback, pre/post activation, and gas |
| F2 native QA | Helper API, separate payment source, NFT identities, two-stage local execution, metadata calls, and activation/claims |
| F3 metadata | Numeric JSON, decoded SVG review, owner-first ordinary terms, migration cliffs, roles, and ordinary packages |
| F4 evidence | Portable runbook, exact wrapped/unwrapped operations, current source/compiler/artifact binding, commands/results, gas, and unresolved limits |
| P1 pricing evidence | Real Raw and RawRate observed-hook differentials, exact domains/reverts, adjusted rates, and live independence |
| Ordinary behavior | Existing V3/disabled-buffer parity, ordinary DETF/bond/staking/Weighted suites, and full hermetic regression |

# Proposed plan

## Dependency-ordered work

### Task 1 — Bind the starting source and create focused regression scaffolding

Before edits, record the affected current source files, compiler versions, and existing artifact identities in:

`docs/incidents/2026-09-16-dtf-recovery/migration/gap-closure-20261116/source-manifest.json`.

Add the focused test cases named below against the existing real registry fixtures. They must be capable of failing against the current behavior; do not mock or subclass the SUT.

**Depends on:** none.  
**Parallel boundary:** P1’s new test file can be prepared independently because it does not edit production source or existing shared test files.

### Task 2 — F1: release booked donation remainders through the existing residual sweep

#### Files and symbols

- `migration/interfaces/IUniswapV4DetfMigration.sol`
  - Add the retained callable declaration and one sweep event.
- `migration/UniswapV4DetfMigrationWeightedHookTarget.sol`
  - Add `sweepMigrationDonationInventory`.
  - Reuse `_releaseDonation`, `_beginBudget`, `_sweepDustBody`, `_endBudget`, and `_syncAllExpectedHoldReserves`.
- `migration/UniswapV4DetfMigrationWeightedHookFacet.sol`
  - Add exactly the new selector to `facetFuncs`.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol`
- `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol`
  - Add a native gas witness only; do not change production deployment flow.

#### Chosen mechanism

Add:

```solidity
function sweepMigrationDonationInventory(uint256 minimumLpOut_)
    external
    nonReentrant
    returns (uint256 lpOut_);
```

The function is permissionless, like the existing residual sweep, and remains available before and after activation.

Exact sequence:

1. Require idle children, an enabled registry route, and a live reserve.
2. Record the fixed bond child’s reserve-LP balance.
3. Call `_beginBudget()`.
4. Iterate only the fixed `_budgetTokens()` set. For each nonzero `donationInventory[token]`, call `_releaseDonation(token, amount)` exactly once. This debits the legitimate donation book and lowers the operation floor by the same amount.
5. Call the existing `_sweepDustBody()`. Its fixed reserve destination, bounded conversion/join retries, and refund retention remain unchanged.
6. Call `_endBudget()` so any unspent amount becomes `residualInventory`, not newly restored donation credit.
7. Synchronize reserve accounting and measure the actual LP delta.
8. Revert if `lpOut_ < minimumLpOut_`; otherwise emit one sweep event containing the actual LP delta.

There are no caller-selected token addresses, target addresses, arbitrary amounts, beneficiaries, or calldata. Work is bounded by the fixed hook/SE set and existing sweep limits, not custody population.

#### Invariants and exclusions

- `donationInventory` decreases only by the amount released into the current operation.
- Any unjoined amount is retained once as `residualInventory`; it cannot be released again from the donation book.
- Unsolicited balances, legacy recovery inventory, bond/staking backing, and previously protected residuals cannot become a new withdrawal or migration credit.
- No self-leg donation is manufactured and no personal DETF/bond issuance occurs.
- Activation state and removed selectors remain unchanged.
- A bookkeeping-only transition is not acceptance: actual reserve LP must increase for the funded test case.

#### Failure and rollback

A disabled registry, inactive reserve, busy child, conversion/join failure, or unmet minimum reverts the complete call, including donation-book release, allowances, conversions, LP movement, and residual accounting. Previously committed operations remain untouched.

#### Regressions

Add to `MigrationCore.t.sol`:

- `test_partialBootstrapRemainderReachesReserveBeforeActivation`
- `test_partialBootstrapRemainderReachesReserveAfterActivation`
- `test_donationInventorySweepRollbackPreservesCapitalAndBacking`
- `test_donationInventorySweepPreservesUnsolicitedAndRecoveryDomains`
- `test_donationInventorySweepRetainsConversionRefundsForRetry`

Use the existing permitted 100-unit donation/50-unit bootstrap setup. Assert actual LP growth, zero remaining donation book after release, native balance/reserve reconciliation, unchanged supply and bond backing, no new personal bond, zero temporary allowances, and correct residual/retry behavior. For the postactivation case, make the genuine owner purchase and activate first, then verify the same remainder route and permanent cut.

Extend `MigrationSurface.t.sol` so the new selector is present on the real retained proxy before and after activation and is absent from ordinary packages.

#### Observable acceptance

Both Stage 1 and Stage 2 real-proxy tests move legitimate partial-bootstrap remainders into actual reserve liquidity without new payment. Refund and failure cases conserve every accounting domain.

### Task 3 — F3: make reward availability instance-wide and activation-based

#### Files and symbols

- `migration/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol::tokenURI`
- `contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol`
  - `_uri`
  - `_purchased`
  - `_positionValues`
  - `_claimAttributes`
  - `_claimableRewards`
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol`
- Existing ordinary bond metadata regressions.

#### Chosen mechanism

In the Migration metadata target:

1. Keep `migrationCliff = bond.isMigrationPosition(tokenId_)`.
2. Set `migrationPresentation = true` for every token rendered by this Migration-specific target, including ordinary owner-first purchases and reserved roles.
3. Set `rewardsClosed = !IUniswapV4DetfMigration(parent_).migrationActivated()` for every token.

In the shared renderer, gate Migration-specific reward presentation on `migrationPresentation`, not `migrationCliff`:

- Include the reward-delivery attribute and accrued-reward value for every Migration position.
- Render activation-dependent reward status for ordinary linear purchases as well as cliffs.
- Keep all principal progress, timestamps, linear-versus-cliff calculations, and principal-due values controlled by `migrationCliff` and the existing position data.
- For an ordinary Migration purchase while closed, describe linear principal with reward delivery requiring activation. After activation, retain ordinary rendering with open rewards.
- Preserve existing reserved-role allocation history and ordinary-package output when `migrationPresentation` is false.

`_claimableRewards` remains the single numeric gate: closed rewards are zero, and total claimable value excludes them while accrued rewards remain separately visible.

#### Failure behavior and exclusions

This is view-only. No claim gate, position, gons, recipient, clock, or activation storage changes. No ordinary package acquires Migration metadata behavior.

#### Regressions

Add to `MigrationSurface.t.sol`:

- `test_ownerFirstBondMetadataClosedBeforeActivation`
- `test_ownerFirstBondMetadataOpensWithoutChangingLinearTerms`
- `test_migrationCliffAndRoleMetadataRemainConsistent`

Before activation, parse the genuine owner bond’s JSON and assert:

- claimable rewards and total claimable rewards are zero;
- accrued rewards remain separately represented;
- reward delivery is closed;
- principal, linear vesting, start, and maturity remain unchanged;
- an actual reward claim still reverts.

After activation, assert claimable rewards match `previewClaim`, delivery is open, and linear principal terms are unchanged. Keep existing cliff numeric boundary tests and reserved-role checks.

Do not pin prose. Save decoded JSON/SVG under the evidence directory and manually inspect the rendered SVG before and after activation for owner-first, cliff, and reserved-role positions.

#### Observable acceptance

Numeric JSON and rendered output agree with actual claim availability for every Migration position, while ordinary-package regressions remain green.

### Task 4 — P1: add real Raw/RawRate observed-hook differential coverage

#### Files

- **New:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedRawPricing.t.sol`
- Reuse:
  - `TestBase_UniswapV4StandardExchangeWeightedBufferHook`
  - `MigrationSnapshotConsumer`
  - `MigrationWeightedPricingFixture`
  - production Weighted capture and preview APIs
- **New evidence:** `migration/gap-closure-20261116/pricing-parity.md`

No production pricing file changes are planned unless a differential test exposes a concrete defect.

#### Chosen fixture

Deploy a real registered Weighted hook with four legs:

1. Raw 18-decimal WETH contribution leg, no provider.
2. RawRate 18-decimal original-DTF contribution leg with a nonzero external rate fixture.
3. Raw nine-decimal output leg represented by the existing `MintableERC20Decimals` non-SUT fixture.
4. One auxiliary SE leg, disabled through the real registry so the hook satisfies `ZeroStandardExchangeRequired` and capture represents it as `DisabledBuffer`.

Use actual sorted token order and derive indices from captured book contents. Seed genuine positive inventory in every leg. The auxiliary leg is not a contribution or output and introduces no V3 dependency into these Raw/RawRate comparisons.

Reuse the existing hook TestBase without copying or expanding its setup. Its canonical Permit2 installation is external dependency setup; do not etch/store the deployed hook, consumer, provider, tokens, or reserves. The rate fixture replaces no SUT.

Create `MigrationSnapshotConsumer` with the output token as its subject/domain, the raw WETH and DTF tokens as contribution identities, and the captured real hook inputs. This avoids ordinary DETF’s `BarePairForbidden` rule without changing source policy.

#### Differential oracle

For each positive original amount:

1. Read seigniorage from the real fee oracle.
2. Compute the existing uplift with full-precision `mulDiv`.
3. Call the real hook’s `previewExchangeIn(input, boosted, output)`.
4. Apply `DETFMintSplitLib._splitLiveGross` once.
5. Compare gross and user output with the consumer’s pure manual evaluation.

Use exact success/revert bytes at domain boundaries; zero-component behavior remains covered by the existing manual evaluator tests.

#### Regressions

- `test_RawObservedHookDifferential`
- `test_RawRateObservedHookDifferential`
- `test_RawRateAdjustedBookAndProviderChange`
- `test_RawModelsExactRevertAndLiveIndependence`

Cover multiple positive amounts, nonzero fee/seigniorage, the mapped max-in boundary, and both contribution directions. Change the external rate, capture a new manual book, and prove the new comparison matches while the old consumer remains unchanged. Also deliberately adjust the manual rate without changing the provider and confirm that the adjusted book—not live equality—determines the new quote. Assert no live hook/provider/oracle storage reads during consumer evaluation.

#### Observable acceptance

Raw and RawRate manual results match the real observed hook within their common success domain, including exact reverts. Existing real V3/disabled-buffer comparisons remain intact. P1 closes as evidence; no arithmetic defect is presumed.

### Task 5 — F2: repair and execute the retained two-stage native QA

#### Files and symbols

- `scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol`
  - `MigrationCoreLocalOwner`
  - `deployAndIssue`
  - `exerciseAfterCliff`
- No production activation changes.

#### Chosen helper API

Add to `MigrationCoreLocalOwner`:

```solidity
function buyOwnerFirstBond(
    IERC20 token_,
    uint256 amount_,
    uint256 duration_,
    uint256 deadline_
) external onlyController returns (uint256 bondId_, uint256 lpOut_);
```

The helper:

1. Requires a bound parent and `parent.owner() == address(this)`.
2. Approves exactly `amount_` to the parent.
3. Calls the existing paid `parent.bond(token_, amount_, 90 days, controller, false, deadline_)`.
4. Clears the approval.
5. Requires `parent.migrationOwnerFirstBondTokenId() == bondId_` and a nonzero funded ordinary position.

The current owner supplies the payment; the controller receives the ordinary NFT. This uses the existing instance-fact rule and does not require the NFT to remain with the administrative owner.

#### Payment and transaction sequence

In `deployAndIssue`:

1. Complete donation, bootstrap, configuration, independent issuance, and subsequent donation as before.
2. Wrap a **separate** 1 ETH of development capital into the configured WETH and transfer exactly 1 WETH to the helper.
3. Call `buyOwnerFirstBond(pairA, 1 ether, 90 days, deadline)`.
4. Assert independent compensation is ID 3 and the ordinary owner-first purchase is ID 4.
5. Assert ID 4 has ordinary linear terms and `isMigrationPosition(4) == false`.
6. Assert donation inventory and harvested/recovery inventory did not fund the purchase.

Update the QA metadata event to carry `tokenId`, and capture both IDs 3 and 4 before and after activation. Do not replace the existing ID 3 compensation assertions.

In `exerciseAfterCliff`:

- Preserve ID 3’s mature migration-principal flow.
- Verify ID 4’s ordinary terms and persistent prerequisite.
- Activate only after the genuine purchase.
- Exercise postactivation rewards for both positions where funded rewards exist.
- Preserve repeat-claim and deferred role/SY assertions.

The existing production missing-purchase tests remain the negative witness; do not add a synthetic marker or weaken activation.

#### Native execution acceptance

Run `deployAndIssue` and `exerciseAfterCliff` on the same fresh local 31337 Anvil, advancing 90 days between them. Save both transaction receipts, the emitted metadata, parent/child identities, and actual supply/backing changes. Compilation alone does not close F2.

### Task 6 — F4: publish current, portable evidence navigation

#### Files

- `migration/foundry-runbook.md`
- `migration/verification.md`
- `migration/quote-evidence.md`
- `migration/source-route-matrix.md`
- `migration/recovery-route-disposition.md`
- **New:** `migration/gap-closure-20261116/verification.md`
- Supporting current records under `migration/gap-closure-20261116/`.

#### Chosen mechanism

- Replace the runbook’s historical-worktree `cd` with an explicitly supplied repository root:

  ```bash
  export INDEXEDEX_ROOT=/path/to/current/indexedex
  cd "$INDEXEDEX_ROOT"
  ```

- For every native operation, name the exact `Phase_08_Stage_01_MigrationExecution` function or state **not wrapped**. Explicitly mark NFT surrender as an unwrapped production operation; do not add a wrapper merely to close F4.
- Separate local QA, pinned fork tests, simulation, and public broadcast instructions. Public operations require separate authorization.
- Prepend a dated current-status link to `verification.md` while preserving the November 13 report below it.
- Mark `quote-evidence.md` as historical capture-era evidence and link to the current manual-pricing parity report.
- Add current-plan/source-scope banners to the two route indexes without rewriting their historical source observations.
- The current completion record must link exact commands/logs, source/compiler/artifact identities, gas shapes, native QA receipts, metadata output, and unresolved deployment/allocation limits.

F1-F3 remain open in that record until their own source-bound checks pass.

### Task 7 — Execute focused, native, fork, ordinary, and full verification

Refresh concrete runtime artifacts before any consumer test or script. Use the existing artifact helper during focused iterations; never retarget `FOUNDRY_TEST`, delete caches, use `via_ir`, or substitute stale artifacts.

#### Focused artifact-first run

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookFacet.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationSurface.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedRawPricing.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedPricing.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOwnerFirstBond.t.sol
```

Build the native QA consumers after production edits:

```bash
python3 scripts/forge-artifacts.py build \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  --consumer scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol \
  --consumer scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol
```

#### Migration, ordinary, and Weighted regressions

```bash
forge build --use solar

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**'

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**'

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/common/**'

forge test --use solar \
  --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/**'
```

#### Pinned legacy forks

```bash
FOUNDRY_PROFILE=fork forge test --use solar \
  --match-path 'test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/**' \
  -j 1 --compute-units-per-second 10 --rpc-timeout 120
```

This is a local pinned-source check, not CI or a public transaction. Missing archive capability is an unrun check, not a pass.

#### Realistic two-stage native QA

Start a fresh owned local node using the existing script’s chain/account conventions:

```bash
anvil --host 127.0.0.1 --port 18548 \
  --chain-id 31337 --unlocked --balance 1000000
```

After the artifact-first build:

```bash
forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA \
  --sig 'deployAndIssue()' \
  --rpc-url http://127.0.0.1:18548 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --broadcast --unlocked
```

Read the emitted parent address, advance the local clock, and mine:

```bash
cast rpc --rpc-url http://127.0.0.1:18548 evm_increaseTime 7776000
cast rpc --rpc-url http://127.0.0.1:18548 evm_mine
```

Then execute the second stage:

```bash
forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA \
  --sig 'exerciseAfterCliff(address)' "$MIGRATION_PARENT" \
  --rpc-url http://127.0.0.1:18548 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --broadcast --unlocked
```

Save actual receipts and logs. Stop the owned node and record cleanup. No launcher, application, journal, public funder, or private key is introduced.

#### New F1 target-gas witness

Add `runDonationRemainderGas()` to `MigrationDeploymentGasResumedQA` so a fresh real-proxy instance donates more than it bootstraps and then executes the new sweep with a 32,000,000-gas envelope. Record actual receipt gas and reserve progress.

Use the existing owned 4663 fork procedure at block 108944663, with the current checkout substituted as the source root:

```bash
anvil --host 127.0.0.1 --port 18561 --chain-id 4663 \
  --fork-url "$ROBINHOOD_MAINNET_RPC_URL" \
  --fork-block-number 108944663 \
  --gas-limit 100000000 --disable-min-priority-fee \
  --balance 1000000 --no-mining --silent
```

The 100,000,000 local block setting is not the admission limit. The applicable transaction bound remains 32,000,000.

```bash
FOUNDRY_PROFILE=fork forge script --use solar \
  scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol:MigrationDeploymentGasResumedQA \
  --sig 'runDonationRemainderGas()' \
  --rpc-url http://127.0.0.1:18561 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked --legacy --gas-price 2000000000
```

Mine and reconcile the receipt using the existing local procedure. Do not rerun historical gas work unchanged; measure only the new operation and retain the old shape limits.

#### Full hermetic release gate

```bash
forge test --use solar --no-match-path '**/fork/**' --no-match-contract Fork
```

Record exact source and artifact identities for this run. A previous full pass is not evidence for the repaired tree.

### Task 8 — Final acceptance and completion record

Close only when all rows hold:

| Gap | Final acceptance |
|---|---|
| F1 | Real Stage 1 and Stage 2 proxies turn legitimate partial-bootstrap donations into actual reserve LP; refunds, failures, unrelated inventory, backing, and activation remain conserved; new target-gas receipt fits 32,000,000 |
| F2 | The same retained native QA instance deploys, independently issues ID 3, genuinely purchases ordinary ID 4, activates, and completes post-cliff rewards with actual local receipts |
| F3 | Owner-first, migration-cliff, and reserved-role numeric/rendered metadata agree with activation; ordinary packages and principal terms regress green |
| F4 | A portable runbook and current completion entry expose exact native functions, unwrapped operations, current evidence, source/artifact/compiler binding, gas, and remaining limits |
| P1 | Raw and RawRate observed-hook differentials pass with exact domains and live independence; existing V3/disabled-buffer evidence remains linked |
| Repository | Focused, Migration, pinned fork, ordinary DETF/common/Weighted, and full hermetic commands have current source-bound exit-zero evidence |

Publish the outcome in `migration/gap-closure-20261116/verification.md` and link it from the plan-named evidence entries. Preserve every historical report and failed attempt.

# Conclusions

The recommended repairs are deliberately narrow:

- F1 reuses the existing donation-release and residual-sweep machinery rather than adding another reserve route.
- F2 repairs only the retained QA helper and sequence.
- F3 separates presentation context from principal arithmetic.
- F4 reconciles navigation and evidence without recreating valid historical work.
- P1 adds the missing real Raw/RawRate observed-hook comparisons without changing pricing or ordinary package policy.

No further owner product choice is needed. Completion requires the future source edits and actual evidence above; this contribution itself changes nothing.

# Limits

- This was planning only. No implementation, project commands, tests, builds, Git, RPC, transactions, deployment, or peer-file reads occurred.
- Current source was read selectively for the five accepted gaps and P1; this is not a new whole-repository audit.
- Exact future gas and runtime behavior remain unverified until the specified checks execute.
- No live or activated instance can be upgraded under this plan. Fresh source/deployment artifacts and any operational action require separate authorization.
- `apply_patch` was unavailable. The complete contribution is inline; the assigned `members/kimi/response.md` was not written, and no alternative writer was used.

# Identity

- Member: Astra.
- Profile: research / implementation-plan authoring.
- Phase: initial independent planning contribution.
- Requested role: `council-member`.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Runtime model, provider and reasoning configuration: not exposed.
- Date: November 16, 2026.
- Run: `dtf-migration-gap-closure-plan-20261116`.

# Question and targets

Write one implementation and verification plan closing accepted F1-F4 and pricing qualification P1. This contribution recommends:

1. **F1:** after successful genesis reconciliation, move the remaining booked non-self donation inventory into the existing residual inventory. Use the existing retained `sweepDust` path to join it before or after activation.
2. **F2:** add a controller-only, genuinely paid ordinary purchase to `MigrationCoreLocalOwner`, and execute it after independent issuance but before activation.
3. **F3:** mark every bond rendered by the migration metadata target as belonging to the migration instance; gate reward presentation by activation independently of principal vesting style.
4. **P1:** compare the manual evaluator against valid, registered production Weighted hooks with raw legs and a real buffered auxiliary leg. Obtain output DETF through the production migration claim path. Do not attach a bare-pair reserve to an ordinary DETF.
5. **F4:** publish one current verification entry point, prepend clear historical-status notices to old records, and make the native runbook relative to the current repository root.

These are fixed recommendations, not an executor menu. No additional product decision is needed to implement this plan. Failed verification remains a technical failure to diagnose; it is not permission to change the accepted policies.

The current checkout is the implementation target. The original migration plan, baseline PRD, final review, immutable council draft, resolution and member originals remain unchanged.

Path abbreviations used below:

| Prefix | Repository-relative path |
| --- | --- |
| `M/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `T/` | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `K/` | `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `S/` | `scripts/foundry/recovery/dtf-migration/` |
| `B/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `C/` | `contracts/vaults/detf/common/` |
| `D/` | `docs/incidents/2026-09-16-dtf-recovery/migration/` |
| `H/` | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/` |
| `W/` | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |

# Evidence

I read the complete new brief, final `REMEDIATION_PRD.md` and coordinator `resolution.md`. The full original migration plan and baseline PRD were read in this session's prior independent review. The final resolution adopts the pricing qualification: inspected real-proxy V3/disabled-buffer comparisons and Raw/RawRate unit arithmetic vectors are different evidence classes.

Current-source observations used to choose the mechanisms:

| Area | Read source | Planning consequence |
| --- | --- | --- |
| Genesis books | `M/UniswapV4DetfMigrationAllocationTarget.sol:305-414` | Bootstrap already measures pair/share changes, accounts separately for self-token residuals, and admits partial use of donated capital. Release must occur after all those measurements, not by classifying the parent's entire balance as spendable. |
| Residual isolation | `M/UniswapV4DetfMigrationPolicy.sol:18-63`; `M/UniswapV4DetfMigrationWeightedHookTarget.sol:327-387` | The existing operation floor protects balances outside `residualInventory`. Live donations already release their newly received amounts into this budget. The bootstrap repair can reuse the same accounting model without a new permanent administration selector. |
| Residual execution | `B/UniswapV4DetfCommon.sol:497-575,584-736`; `M/UniswapV4DetfMigrationMaintenanceFacet.sol` | The retained sweep has native-component joins, share/pair consolidation, approvals and fixed LP destination. Use this execution path; do not add a second donation router. |
| Existing refund expectations | `T/MigrationGenesisCapital.t.sol:68-189`; `T/MigrationCore.t.sol:43-71` | Existing tests include measured residual capital and permitted partial bootstrap. Assertions that deliberately equate remaining physical capital with `donationInventory` must be updated to the new book transition and strengthened with actual progress assertions. |
| Native owner helper | `S/MigrationCoreLocalQA.s.sol:41-81,266-345` | Its helper cannot currently purchase. Its lifecycle assumes compensation ID 3 and a later ordinary ID 4. Adding the real owner purchase changes the latter expectation and requires updating metadata capture. |
| Actual ordinary purchase | `M/UniswapV4DetfMigrationBondFacet.sol:31-61`; `B/UniswapV4DetfTarget.sol:310-410,478-575` | The parent already enforces the right owner, payment and one-time purchase rules. Call that real entrypoint. The public prerequisite query is `migrationOwnerFirstBondTokenId()`, not a fabricated purchase-record getter. |
| Metadata | `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol:19-33`; `C/bondNft/DETFFundedBondMetadata.sol:12-201` | Existing fields distinguish migration presentation, reward closure and cliff style. No additional storage or claim-rule change is needed. The shared renderer currently uses `migrationCliff` for some reward-display decisions; those must follow instance presentation instead. |
| Metadata tests | `T/MigrationSurface.t.sol:109-161`; `T/MigrationOwnerFirstBond.t.sol:20-88` | Extend actual tokenURI coverage to the paid ordinary bond and preserve the real principal/reward assertions already present. |
| Existing pricing oracle | `M/TestBase_UniswapV4DetfMigrationSnapshot.sol:1-89,153-191`; `T/UniswapV4DetfMigrationSnapshot.t.sol:35-154` | Its expected-value path is V3-SE-oriented. It cannot be reused unchanged as a raw-input oracle. Its observed-book conversion and evaluator harness can be reused with an explicit hook parameter. |
| Raw-hook admissibility | `B/UniswapV4DetfProcessArgsLib.sol:95-143`; `H/UniswapV4StandardExchangeWeightedBufferHook_Deploy.t.sol:128-147` | Ordinary DETF rejects a non-self bare pair; a hook with no SE bindings is also rejected. A mixed hook with a real buffered auxiliary leg avoids both invalid fixture assumptions without changing policy. |
| Real hook deployment | `H/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol`; `W/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol:27-93`; `W/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol` | Use the existing package, salt miner, hook factory, registry, PoolManager and native-component join APIs. Do not create a derived or storage-injected hook. |
| Observed capture | `W/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:131-210`; `W/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol:333` | Public `captureWeightedMintBook()` records actual raw/SE reserves, scales, weights, fee and provider return data. These observations can populate the manual book for comparison. |
| Permit2 and providers | `contracts/test/bases/TestBase_ERC4626StandardExchange.sol`; `lib/crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol`; `contracts/test/libs/RateProviderFixtureLib.sol` | The migration gold fixture uses a genuinely deployed Permit2 and production StandardExchange rate providers. Reuse that setup instead of inheriting the hook test base's `vm.etch` setup. |
| Current entry documents | Complete `D/verification.md`, `D/foundry-runbook.md`, and the relevant opening/manual-pricing portions of `D/quote-evidence.md` | Preserve historical records, but place current status and current links first. Remove the runbook's archived-worktree working-directory assumption. |
| Artifact workflow | `docs/testing/ARTIFACT_BUILDS.md`; `contracts/utils/foundry/ArtifactCreationCode.sol`; `.omo/verification/artifact-mismatch-20261116/DIAGNOSIS.md`; `foundry.toml` | Build dynamic runtime artifacts before tests/scripts. Record full creation bytes and the actual source-qualified artifact used. Use Solar, existing profiles and normal code-size enforcement. Do not erase shared caches to make identity errors disappear. |

The coordinator's P1 observations were treated as source leads and checked against these APIs. They were not treated as a selected design or as authority to modify source admission policy.

Existing 236-case hermetic Migration, 183-case fork and 28,641-case full-hermetic results remain baseline evidence from the final review. They are not execution evidence for these proposed changes. No project command or runtime check was run during this planning pass.

# Assumptions

- All accepted migration requirements remain in force: manual owner-selected pricing; keep-until-reloaded credit; separate configuration and issuance; original-wallet surrender; actual custody and source units; the NFT 3 two-contribution exception; conserved TokenStaking originals; real paid owner-first activation; fresh funded cliffs; reward closure; irreversible administration removal; and bounded, repeated recovery.
- F1 changes the classification of **already booked** genesis capital after a successful bootstrap. It does not permit spending unsolicited balances, legacy recovery inventory or arbitrary third-party assets.
- Local QA uses the existing synthetic external contribution currencies and actual production package graph. It is not a historical eligibility, real-DTF funding or financial-allocation approval.
- A manual book may deliberately use observed operands from a separate valid hook. It need not describe the migration parent's current reserve. This is essential to P1's comparison without violating ordinary DETF reserve admission.
- The existing 32,000,000 transaction gas ceiling is the local execution ceiling for this closure proof. Forge simulation may have a larger aggregate budget; mined transactions and normal code-size limits may not be waived.
- Existing credentials for the pinned fork profile must be available to the eventual executor without printing them. No endpoint substitution, new provider or pin retuning is part of this plan.
- All commands below are future implementation/verification instructions. Nothing in this contribution authorizes running them now.

# Coverage

| Gap | Chosen mechanism | Principal requirements preserved | Closure evidence |
| --- | --- | --- | --- |
| F1 | Atomic donation-book-to-residual handoff after genesis reconciliation; existing retained sweep | MIG-P13, MIG-AC16/31, E4; exact custody, no extra compensation, no new administration path | Before/after activation progress tests; genuine excess and refunds; protected-balance negatives; real native postactivation sweep; receipt gas |
| F2 | Controller-funded owner helper invokes the existing ordinary `bond` entrypoint | Section 1.5; current-owner payment; non-cliff ordinary terms; one-time prerequisite | Real helper tests; Stage 1 activation negative; fresh two-stage native broadcast reaching claims and later ordinary purchase |
| F3 | Activation-aware presentation for every migration-instance bond, independent of cliff style | Task 5; MIG-P08; economic payout rules and ordinary-package rendering unchanged | Actual tokenURI attributes and SVGs for cliff, paid ordinary and reserved roles; ordinary-package controls |
| F4 | Current evidence index and dated historical notices; repository-root runbook | Task 9/F4; November 15 scope correction | Current source/artifact/run links, usable commands, explicit stale/conditional/superseded labels |
| P1 | Valid mixed production hooks, genuine raw assets/rates, independent live hook quote oracle | Task 2/E3 and manual pricing law; ordinary `BarePairForbidden` remains | Raw and RawRate real-hook parity, active non-unit provider effects, edge rejection, frozen evaluation after real source mutation |

The final evidence must distinguish:

- code implemented;
- test present;
- test actually executed on the identified source/artifact set;
- mined local execution;
- historical evidence reused with its binding limits;
- unresolved or conditional evidence.

No row closes merely because a test name exists, a script compiles, a command exits zero with no matching tests, or an old passing result is linked.

# Conclusions

## 1. F1 implementation: release booked genesis remainders into the existing residual budget

### Production changes

Edit:

- `M/UniswapV4DetfMigrationAllocationTarget.sol`, `bootstrapMigrationReserve`.
- `M/interfaces/IUniswapV4DetfMigration.sol`, one event declaration.

After the existing loop has reconciled **all** measured pair/share balance deltas and retained the existing self-token residual accounting, but before the final reserve synchronization/event/return, iterate the already obtained `_budgetTokens()` list once more:

```text
for each tracked token other than address(this):
    released = donationInventory[token]
    if released is nonzero:
        donationInventory[token] = 0
        residualInventory[token] += released
        emit MigrationCapitalReleasedToResidual(token, released)
```

Add:

```solidity
event MigrationCapitalReleasedToResidual(address indexed token, uint256 amount);
```

This event describes a book transfer, not a claim that the capital has already entered liquidity. Keep existing conversion-consumption and bootstrap events and their meanings.

The separate release pass is intentional: every measured conversion/join adjustment finishes before any remaining book is released. A repeated token entry, if one is ever encountered, sees a zero donation balance after its first release and cannot release the same book twice. The iteration is over the fixed configured token/SE inventory, not donor, entitlement, holder or NFT populations.

Do not modify `operationFloor` during this bootstrap handoff. Bootstrap is not an open residual-budget operation. The next existing `_beginBudget` computes the floor from the updated residual book.

Do not call `sweepDust` recursively from inside the bootstrap's administration lock. The bootstrap creates the reserve and publishes the spendable remainder atomically; the existing retained `sweepDust` performs subsequent joining. Keeping that subsequent operation separate also prevents legitimately unjoinable dust from reverting an otherwise valid bootstrap.

No new selector, storage slot, owner permission, recovery stage, destination argument, re-bootstrap option or upgrade route is added. Adding an event does not add a selector to an ERC-165 interface ID.

### Accounting contract

Let `D` be the measured remaining donation book for a non-self token and `R` the existing residual book immediately before release:

```text
physical balance after release = physical balance before release
D_after = 0
R_after = R_before + D_before
protected floor on the next budget = held balance - R_after
```

The release uses `D`, never `held balance`. Thus an unsolicited transfer remains protected. Separate recovery books remain unchanged. The existing special accounting for newly minted self DETF is unchanged.

A later sweep must move usable residual capital into the real reserve and LP into the existing bond-vault destination. It may leave genuine native-unit dust in the residual budget. It must not recreate a positive donation book, confiscate the dust, pay a caller or mint a compensation bond.

### Regressions

Add `T/MigrationDonationRemainder.t.sol`, inheriting `TestBase_UniswapV4DetfMigration`. Use fresh registry-deployed instances for independent cases.

| Test ID | Required scenario and assertions |
| --- | --- |
| F1-T01 | Donate 100 units of both legs; bootstrap with 50 of each. Assert the original book was 100, measured bootstrap consumption is correct, all remaining booked non-self donations are released once, no physical token moves merely because of release, no independent issuance exists and no user compensation was minted. An old implementation fails the expected book transition. |
| F1-T02 | From that fresh Stage 1 instance, call the real retained sweep without another payment. Require a positive increase of real hook LP held by the bond child and a reduction of usable residual capital. Snapshot supply, bond identities, independent issuance, owner-first marker and original-credit records; the sweep must not create compensation or satisfy the first-purchase prerequisite. |
| F1-T03 | On a separate instance, leave the released remainder unswept, perform the real paid owner purchase, then activate. Record that the remainder still exists before the tested sweep. After the loader selectors have disappeared, execute the retained sweep and prove positive reserve progress without another donation. The test must not silently become a no-remainder case. |
| F1-T04 | Exercise a measured conversion/join refund with the existing real V3 SE and hook. Establish that the scenario actually leaves a nonzero return/remainder. Verify actual native input/output, the final book handoff, zero leftover protocol approvals and later usable progress. Update `MigrationGenesisCapital.t.sol::_accept` to expect release into residual ownership rather than a permanently positive donation book; preserve its physical-balance and minimum-LP assertions. |
| F1-T05 | Transfer an additional unbooked amount directly to the parent before bootstrap. Record it separately. Bootstrap and sweep may spend the booked remainder only; at least the unbooked amount must remain protected, and no recovery inventory may change. Cover raw pair and SE-share balances. |
| F1-T06 | Force bootstrap failure with an impossible minimum LP output. Compare the complete pre/post donation books, balances, supply, liveness, residual-related observable state and logs. No release event survives. Cover subsequent zero/dust sweep and repeated sweep in an unchanged state: no double release, payout or false progress. |

Use actual balance/LP movement to prove residual availability. Do not add a public storage getter merely to simplify this test. Expected residual quantities can be tracked in the test's independent ledger and reconciled against the release event, protected balances and subsequent movement.

Retain existing hostile-token, callback and rollback tests. Do not replace a failing current assertion with a weaker inequality unless the new book transition makes its old equality obsolete and the replacement proves the physical and accounting conservation explicitly.

## 2. F3 implementation: separate reward availability from principal style

Implement this before finalizing F2's metadata captures.

### Production changes

In `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol::tokenURI`:

- Keep `migrationCliff = bond_.isMigrationPosition(tokenId_)`.
- Set `migrationPresentation = true` for every token rendered by this migration-specific target.
- Set `rewardsClosed = !parent.migrationActivated()`.
- Update its NatSpec: purchased positions retain ordinary principal vesting but use migration-instance reward availability.

In `C/bondNft/DETFFundedBondMetadata.sol`:

1. Keep cliff/linear time attributes, titles and principal calculations selected by `migrationCliff`.
2. Select the migration activation banner, reward availability attributes and accrued-versus-claimable reward display by `migrationPresentation`, including purchased positions.
3. For a migration ordinary purchased position, describe linear principal vesting and rewards payable only after activation. Do not describe its principal as a 90-day cliff.
4. Ensure Stage 1 `Claimable rewards` is zero and `Total claimable` contains only genuinely claimable principal. Preserve a separate accrued-reward value where the migration renderer reports it.
5. After activation, display the actual claimable reward amount and principal-plus-reward total.

The normal metadata target leaves `migrationPresentation` false. Its ordinary linear descriptions, attributes and visuals remain unchanged. Protocol/fee/creator roles retain their role semantics; protocol ID 0 must not acquire a user claim or transferable presentation.

Do not modify `_claim`, receipt accounting, gons, vesting, activation, fee roles or claim selectors.

### Regressions and visual evidence

Extend `T/MigrationSurface.t.sol` and `T/MigrationOwnerFirstBond.t.sol`:

| Test ID | Required assertions |
| --- | --- |
| F3-T01 | Buy the real Stage 1 owner-first ordinary bond and create actual funded rewards through existing production behavior. Require positive accrued rewards so zero expected claimable is not vacuous. Before activation, tokenURI reports linear vesting, zero claimable rewards and the correct principal-only total. Real reward and combined claims still reject. |
| F3-T02 | At partial linear vesting and at full maturity before activation, compare numeric metadata to actual principal entitlement. Claim principal through the real method and verify updated metadata while rewards remain closed. Activation alone must not change principal, start time, duration or accrued gons. After activation, display and execute the real reward claim. |
| F3-T03 | Retain cliff positions' exact boundary checks; test migration fee/creator role metadata before/after activation with actual positive funded role rewards. Protocol role behavior stays nonclaimable. |
| F3-T04 | Exercise an ordinary non-migration package with actual funded rewards and inspect its tokenURI. It must retain ordinary linear wording, available rewards and its ordinary attribute/image shape. Do not merely assert the migration flag is false. |

Decode actual base64 tokenURI JSON and its embedded SVG. Match attributes by trait name rather than relying on positions that legitimately differ by bond class. Convert amount strings back to native units in test-only parsing when necessary; do not compare only the presence of a prose phrase.

For the native QA run, preserve the actual paid-bond and cliff-bond URIs before and after activation. Render their embedded SVGs with the existing local browser/image tooling and inspect for clipping, overlapping text, incorrect cliff labels and a reward-availability banner inconsistent with the numeric attributes. These are captures of the emitted metadata, not reconstructed mock images.

## 3. F2 implementation: make the retained native lifecycle purchase honestly

### Helper operation

Add this explicit operation to `MigrationCoreLocalOwner` in `S/MigrationCoreLocalQA.s.sol`:

```solidity
function buyOwnerFirstBond(
    IERC20 token_,
    uint256 amount_,
    uint256 duration_,
    uint256 deadline_
) external onlyController returns (uint256 bondId_, uint256 lpOut_);
```

Its fixed behavior is:

1. Require the helper to be bound through its existing binding rule.
2. Record its current payment-token balance.
3. Pull the requested fresh payment from `controller` using the existing safe ERC20 utility. For the selected QA route, require the exact amount to arrive.
4. Approve only that amount to the bound parent.
5. Call the real `parent.bond(token_, amount_, duration_, controller, false, deadline_)` as the current owner helper.
6. Clear the parent allowance.
7. Require the helper to retain only its prior payment-token balance for this full-consumption QA route. This prevents preexisting helper surplus from being used as the payment and detects a route that did not consume the selected amount.
8. Return the actual bond ID and LP amount. Assertions in the test/script verify the parent's `migrationOwnerFirstBondTokenId()`, nonzero funded principal and ordinary position flag.

There is no arbitrary-call method, payer argument, recipient argument, marker setter or compensation shortcut. The controller authorizes and supplies payment; the helper is the actual parent caller. The beneficiary is fixed to the controller. Existing parent guards continue to reject a second Stage 1 purchase or zero/unusable payment.

### Native stage sequence

Preserve the two native entrypoints `deployAndIssue()` and `exerciseAfterCliff(address)`.

Revise `deployAndIssue()` as follows:

1. Keep the real local infrastructure, registry, packages and explicit helper ownership.
2. Donate the existing 1,000-unit amounts of both external contribution currencies, but bootstrap with 500 units of each. This deliberately produces the F1 remainder in the native run.
3. Assert the remaining booked capital has been released while the physical capital remains held. Do not sweep it yet; the native run will prove retained postactivation progress.
4. Set the manual book and issue the independent compensation bond through the existing helper method. Keep the initial exact issuance/backing checks **before** the paid purchase changes supply and staking rewards.
5. Approve one ether of the real pair-A payment currency from the controller to the helper. Call `buyOwnerFirstBond` with a 90-day ordinary duration.
6. Verify actual controller payment, unchanged unrelated helper balance, cleared helper-parent allowance, positive real LP and child principal, and the public recorded first-purchase ID. The purchased position must have `isMigrationPosition == false`.
7. Record readable addresses and IDs for subsequent native calls and verify them by actual chain reads. Keep the on-chain `MigrationOwnerFirstBondPurchased` event as the product event.

With the existing reservation order, the independent bond remains ID 3 and the owner purchase is ID 4. The script must nevertheless derive the independent ID from `independentIssuance(controller).bondTokenId` and the owner ID from `migrationOwnerFirstBondTokenId()` for subsequent use. This avoids another hardcoded-ID failure.

Revise `MigrationCoreLocalOwner.activate()` to capture metadata for **both** IDs. Change the QA-only `MetadataCapture` event to include `uint256 indexed tokenId` so a retained log distinguishes the images. Its pre/post activation captures must use the actual queried IDs.

Revise `exerciseAfterCliff(address)`:

- Confirm the stored paid prerequisite and its ordinary terms before attempting activation.
- Preserve Stage 1 reward/combined-claim rejection and mature compensation principal-only payment.
- Keep remaining source capital unswept through the preactivation checks.
- Activate using the actual owner helper.
- Confirm administrative selector removal and actual reward availability.
- Call retained `sweepDust` after activation, with no further donation, and require positive reserve/LP progress from the old released capital. Record before/after balances and the untouched protected amounts.
- Execute the existing postactivation ordinary purchase. It is a different ordinary bond, normally ID 5; remove the obsolete assertion that it must be ID 4. Assert distinct identities, actual owner, positive principal and ordinary position semantics.

Do not use a test-only prank to make the native owner purchase, and do not treat independent issuance as the paid prerequisite. Do not restore the removed launcher or operator framework.

### Hermetic helper regressions

Add `T/MigrationCoreLocalQA.t.sol` using the actual `MigrationCoreLocalOwner` and the production migration TestBase. The owner helper is an external caller fixture; the migration SUT still comes from the registry and actual packages.

| Test ID | Required assertions |
| --- | --- |
| F2-T01 | Independent issuance alone still fails activation with `MigrationOwnerFirstBondRequired`. The helper does not weaken the parent prerequisite. |
| F2-T02 | The real controller supplies the selected payment; helper purchase records the actual owner caller, creates a funded ordinary bond for the controller and allows later activation. Check payment, LP, child principal, duration, marker and cleared allowance. |
| F2-T03 | Wrong controller, absent token approval, insufficient payment balance, expired deadline and a repeated Stage 1 purchase fail without partial helper/parent/child state changes. Keep exact relevant revert checks. |
| F2-T04 | A preexisting helper token surplus remains untouched by a successful fresh payment. Reverting purchases restore the newly pulled amount and parent allowance changes atomically. |

These helper tests do not replace running the two actual native script entrypoints. Native execution is the closure gate for the script lifecycle.

## 4. P1 implementation: real Raw/RawRate comparisons at the valid hook boundary

### Fixture choice

Add `T/MigrationRawWeightedPricing.t.sol`, based on `TestBase_UniswapV4DetfMigration`.

Do **not** inherit `H/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol::setUp`, because it etches Permit2. Do not change that unrelated base as part of this task. The migration TestBase already obtains real Permit2, manager, V3 SEs, PoolManager, registry and hook packages through production deployment paths.

Use the existing registered migration parent as the real nine-decimal output currency:

1. Fund its genuine reserve and load its existing valid book.
2. Configure and issue one actual compensation bond to the test wallet.
3. Advance only the test clock through that bond's cliff.
4. Claim principal and unstake through the real receipt path, obtaining real liquid DETF in the test wallet while activation remains closed.
5. Use a positive portion of that liquid balance to seed a separate real Weighted hook. Do not mint or inject parent DETF and do not overwrite any SUT storage or runtime.

The standalone hook has four sorted currencies:

- the fixture's configured 18-decimal WETH-role currency, raw;
- its 18-decimal original-DTF-role currency, raw;
- the genuine migration DETF, raw nine-decimal output;
- the other underlying currency of the fixture's genuine `se0` V3 pair, bound to `se0` as a real buffered auxiliary leg.

Read that auxiliary currency from the actual SE's vault-token list, require it to be distinct from the three other currencies, and seed it with the existing real external test currency. This gives the hook an actual SE binding and positive buffered inventory. It is not an unused fake address supplied merely to satisfy validation.

Use weights 0.3, 0.2, 0.4 and 0.1 for the roles above, moving all associated values together when sorting by address. Thus both input/output weight ratios are unequal and nontrivial.

Deploy through `UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.deploy`, which uses the existing package, hook factory, salt mining and registry. Use the real manager as fee oracle. Seed all four currencies through `joinNativeComponents`, with real approvals and measured results. Require positive raw reserves, positive auxiliary SE reserve and positive hook LP supply.

This hook is **not** installed as the parent's ordinary DETF reserve. The original parent's valid buffered reserve remains unchanged. Consequently neither `BarePairForbidden` nor the hook's at-least-one-SE requirement is relaxed.

### Rate variants

Create fresh deployed instances for three fixed variants:

| Variant | Raw input providers | Output provider |
| --- | --- | --- |
| R0 | None: both contribution roles are `Raw` | None: DETF output is `Raw` |
| R1 | Real StandardExchange rate providers for `se0 -> pairA` and `se1 -> pairB` | None: output remains `Raw` |
| R2 | The same genuine input-provider types | A real StandardExchange rate provider quoting the genuine parent DETF into pairA; output is `RawRate` |

Use `RateProviderFixtureLib.providerFor` and the actual production rate-provider package, not a fixed-rate mock. The hook permits a provider on a raw leg independently of its SE binding. These are explicit fixture rate bindings, not a claim about an intended live deployment composition.

Make non-unit rates and rate changes observable through legitimate backing changes to the real source vaults. External mintable fixture currencies may fund those changes; the rate providers, SEs, migration parent and hooks are not altered. Require the observed rates to be nonzero and the tested RawRate cases to be non-unit. For the output-reserve boundary case, establish the required higher positive output rate by actual source backing, then record it.

### Reuse the observed-book helper, not the V3 oracle

In `M/TestBase_UniswapV4DetfMigrationSnapshot.sol`, add an explicit helper entrypoint to `MigrationWeightedPricingFixture`:

```text
observedHook(consumer, hook, seigniorage, weth, originalDtf)
```

Factor the existing capture-to-input conversion into that helper. The existing `observed(detf, feeOracle, weth, originalDtf)` continues to read the ordinary parent's hook and seigniorage and delegates to it, preserving its existing callers.

`observedHook` obtains the actual hook's public `captureWeightedMintBook()` result and converts its reserves, scales, weights, provider returns, enabled V3 auxiliary deposit inputs and current fee into `Pricing.Inputs`. Its `consumer` is the real migration DETF. The seigniorage parameter is the explicit chosen manual policy operand; it is not invented as an observed hook field.

Load those exact inputs through the current migration owner's real `setMigrationWeightedPricing`. Use the existing `MigrationSnapshotConsumer` as the breakdown harness for `evaluateOriginal`, and require the actual migration proxy's `previewOriginalCredit` to agree with the two separately evaluated user amounts.

Do not use the existing `_oracle` for this raw fixture: it computes V3 deposit units and selects `se0/se1` for the contribution leg. It is not the relevant expected-value path.

### Independent oracle

For each contribution independently, using the same unchanged observed book:

```text
boosted = floor(original * (1e18 + p) / 1e18)
gross = actualRawHook.previewExchangeIn(inputCurrency, boosted, outputDETF)
expectedUser = floor(gross * (1e18 - p) / 1e18)
```

Require the live quote's raw-input refund to be zero in successful cases. The oracle must call the **production hook** for gross output. It must not compute its expected gross through `MigrationWeightedPricingLib`, a copied Weighted formula or a subclass override.

Independently calculate the observable intermediate mapping:

```text
net = boosted - floor(boosted * actualHookFee / 1e18)
scaled = floor(net * observedInvScale / 1e18)
Raw rated inflow = scaled
RawRate rated inflow = floor(scaled * observedRate / 1e18)
```

Compare these intermediates and the production hook's gross against the evaluator breakdown. Compare the separately floored user amounts and their sum with the actual migration preview. This tests the full wrapper sequence without pretending an ordinary DETF package accepts a bare-pair reserve.

### Required cases

| Test ID | Required case |
| --- | --- |
| P1-T01 | R0: both contribution directions, positive non-dust native inputs, unequal weights, a zero-p/zero-fee control, and nonzero p/current hook fee. Each valid expected gross and user result must be positive. |
| P1-T02 | R1: both input directions with observed non-unit input rates, integer values producing rounding, and the same uplift/fee/user-split assertions. |
| P1-T03 | R2: actual output-provider mapping, native9 output flooring and observed raw-output reserve cap. Compare the exact successful result or the production hook's actual rejection with the evaluator; retain the real rate and reserve operands in the evidence. |
| P1-T04 | Input-domain boundaries: use the actual raw reserve/rate/fee/p operands to find the last permitted native input and the next input, checking the production hook itself. Cover MaxIn behavior with Raw output and the distinct output-reserve rejection with RawRate output. Do not infer success from a zero quote or catch a revert and count the branch as exercised. |
| P1-T05 | Two-component sum, zero component, reversed evaluation order, and genuine live mutation. Change actual source backing/rates or execute an actual hook exchange; require the live quote to change, while the previously loaded manual book and evaluations remain unchanged until an explicit owner replacement. |
| P1-T06 | Assert fixture validity: registry deployment, actual selected currencies and SE binding, positive auxiliary SE inventory, real provider code, no SUT `etch`/storage injection, and no ordinary-parent raw-reserve reconfiguration. These assertions accompany economic comparisons, not replace them. |

If a supported-domain mismatch emerges, do not alter Weighted policy, manually choose easier expected outputs or weaken a test. Diagnose the exact difference. The plan authorizes fixture/test and evidence work for P1; a newly demonstrated production pricing defect must be reported rather than silently broadening this repair into a pricing redesign.

Until all these observed-state gates pass on the identified artifacts, retain P1's explicit unverified qualification. After they pass, describe the coverage as **hermetic observed production-hook parity for the tested modes**, not a certification of a selected Robinhood deployment.

## 5. Dependency-ordered work packages

| Task | Dependencies | Allowed implementation/output scope | Exit condition |
| --- | --- | --- | --- |
| GP-01: establish source and evidence baseline | None | Read accepted review/resolution and relevant source; create new execution evidence directory only | Input scope, current file hashes, toolchain, profile/config and historical reuse limits recorded. No old plan/report rewritten. |
| GP-02: release genesis donation remainders | GP-01 | Allocation target, migration interface event, new DonationRemainder spec, affected GenesisCapital/Core assertions | F1 mechanism implemented; production-proxy progress/conservation tests present; no new selector or destination. |
| GP-03: correct migration bond presentation | GP-01 | Migration metadata target, shared metadata renderer, Surface and OwnerFirstBond specifications | F3 behavior covered across purchased/cliff/role positions and ordinary-package controls. |
| GP-04: repair native owner purchase and lifecycle | GP-02, GP-03 | CoreLocalQA helper/stages, new CoreLocalQA helper spec | Honest payment path; IDs/query use corrected; native script contains both preactivation and postactivation assertions and F1 remainder proof. |
| GP-05: add observed raw pricing comparisons | GP-02 | Snapshot observed-book test helper and new RawWeightedPricing spec | Valid real mixed hooks and all P1 cases present; no source-admission or pricing-production policy edits. |
| GP-06: bind final artifacts and execute automated gates | GP-02 through GP-05 | Existing build/test tools and new evidence outputs | Solar build, focused/new coverage, full hermetic gate and pinned Migration forks pass or remain explicitly unresolved; no zero-case PASS. |
| GP-07: execute native QA and inspect actual metadata | GP-06 | Retained CoreLocalQA, owned local Anvil and evidence outputs | Both real broadcast stages succeed, old capital progresses after activation, actual metadata renders correctly, receipts respect 32M/code-size limits. |
| GP-08: reconcile documentation and publish closure | GP-06, GP-07 | `D/verification.md`, `D/quote-evidence.md`, `D/foundry-runbook.md`, new gap-closure evidence index | All five status rows link current source/artifacts/commands/results; old records preserved with clear scope; no false global-completion or public-execution approval. |

GP-02 and GP-03 have separate production paths, but integration occurs before native QA. GP-05 does not require changing GP-03's shared renderer. Do not introduce concurrent edits to the same fixture/evidence file without explicit ownership coordination.

No commit, configuration migration, dependency upgrade or new test profile is part of these tasks.

## 6. Exact future verification workflow

### Environment and evidence roots

Run from the current repository root containing `foundry.toml` and `scripts/forge-artifacts.py`, not an archived worktree. Use the existing installed Foundry/Solar tools. A future executor should set:

```sh
ROOT="$(pwd -P)"
M="contracts/vaults/detf/protocols/dexes/uniswap/v4/migration"
T="test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration"
K="test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration"
S="scripts/foundry/recovery/dtf-migration"
D="docs/incidents/2026-09-16-dtf-recovery/migration"
RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
E="$D/gap-closure-20261116/$RUN_STAMP"
RUNTIME=".omo/verification/dtf-migration-gap-closure-20261116/$RUN_STAMP"
mkdir -p "$E" "$RUNTIME"
export FOUNDRY_PROFILE=default
export FOUNDRY_OUT="$ROOT/$RUNTIME/out"
export FOUNDRY_CACHE_PATH="$ROOT/$RUNTIME/cache_forge"
```

Use a new timestamped runtime directory. This avoids overwriting the shared `out/` and `cache_forge/` or borrowing their artifact identity. These are ordinary Foundry directories, not a new portable execution-bundle format. Retain the relevant manifests and artifact hashes in the durable evidence tree.

Record the actual Forge/Solar versions and resolved relevant configuration. Do not print credential values or store an unredacted RPC configuration dump. Do not install another compiler or change `foundry.toml`.

Capture each invocation, process exit, output and nonzero executed-test count. Background tool execution may be used by the executor, but one owned run should have one completion watch; do not launch duplicate builds/tests or repeated status polling.

### Focused working checks

The existing artifact helper builds runtime dependencies first. These are exact selected working checks:

```sh
python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationAllocationTarget.sol" \
  "$M/interfaces/IUniswapV4DetfMigration.sol" \
  --test-root "$T/MigrationDonationRemainder.t.sol" \
  --test-root "$T/MigrationGenesisCapital.t.sol" \
  --test-root "$T/MigrationCore.t.sol" -- -vvv

python3 scripts/forge-artifacts.py test \
  "$M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol" \
  contracts/vaults/detf/common/bondNft/DETFFundedBondMetadata.sol \
  --test-root "$T/MigrationSurface.t.sol" \
  --test-root "$T/MigrationOwnerFirstBond.t.sol" -- -vvv

python3 scripts/forge-artifacts.py test \
  "$S/MigrationCoreLocalQA.s.sol" \
  --test-root "$T/MigrationCoreLocalQA.t.sol" -- -vvv

python3 scripts/forge-artifacts.py test \
  "$M/TestBase_UniswapV4DetfMigrationSnapshot.sol" \
  --test-root "$T/MigrationRawWeightedPricing.t.sol" \
  --test-root "$T/UniswapV4DetfMigrationSnapshot.t.sol" \
  --test-root "$T/MigrationWeightedPricing.t.sol" -- -vvv
```

Obtain native Solidity diagnostics for the changed production, helper and test files. Preserve compiler warnings; do not suppress errors or weaken tests. A check already covered by the final full-hermetic run on identical artifacts does not need another redundant focused run.

### Final artifacts and automated gates

After integrating all source changes:

```sh
forge build --use solar

python3 scripts/forge-artifacts.py build --all-artifacts \
  --consumer "$S/MigrationCoreLocalQA.s.sol" \
  --consumer "$T/MigrationDonationRemainder.t.sol" \
  --consumer "$T/MigrationCoreLocalQA.t.sol" \
  --consumer "$T/MigrationRawWeightedPricing.t.sol" \
  "$S/MigrationCoreLocalQA.s.sol" \
  "$M/TestBase_UniswapV4DetfMigrationSnapshot.sol"

forge test --use solar \
  --match-path test/foundry/spec/utils/foundry/ArtifactCreationCode.t.sol \
  --match-test '^test_fullSourceIdentifier\(\)$' -vvv

forge test --use solar \
  --no-match-path '**/fork/**' --no-match-contract Fork
```

Require a nonzero actual pass for `test_fullSourceIdentifier()`. The full hermetic gate includes the new tests, migration invariants, ordinary DETF/bond/staking regressions, shared metadata controls and the current deployment/operation gas specifications. Report the new actual counts; do not reuse 28,641 as an expected new total.

The ordinary and migration production TestBases must continue using real registry-deployed contracts. No derived SUT, `vm.store`/SUT `vm.etch`, mock fee oracle, fake registered vault or zero facet placeholder is an acceptable repair.

Run the existing pinned migration forks with the existing authorized `ALCHEMY_KEY` supplied privately:

```sh
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  "$M/UniswapV4DetfMigrationAllocationTarget.sol" \
  --test-root "$K" -- -vvv
```

The profile's endpoint alias is `robinhood_mainnet_alchemy`; existing fixtures select their pins. Do not replace those pins with latest state or change historical assertions to obtain a pass. If the authorized endpoint is unavailable, the fork gate stays unverified and final closure must say so.

Run builds before tests/scripts because `ArtifactCreationCode` reads creation bytes from the configured artifact directory. If artifact identity differs, preserve the evidence and resolve that build-input mismatch. Do not strip metadata, suppress an identity assertion or silently reuse a historical `out/`.

### Fresh native local execution

Start one owned, fresh, nonforked Anvil using normal size enforcement:

```sh
anvil --host 127.0.0.1 --port 18548 \
  --chain-id 31337 --gas-limit 32000000
```

The executor must first establish that this endpoint is available. Do not reuse or kill somebody else's server. Record the owned process/session, node identity and latest header. Confirm `forkedNetwork` is null and the actual header gas limit is 32,000,000. This is a hermetic QA node, not the separate Robinhood fork-rehearsal workflow.

Set:

```sh
RPC="http://127.0.0.1:18548"
DEV="0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
```

Run the actual first stage through the existing script helper:

```sh
FOUNDRY_BLOCK_GAS_LIMIT=1000000000 \
python3 scripts/forge-artifacts.py script \
  "$S/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA" \
  --rpc-url "$RPC" --broadcast --unlocked --sender "$DEV" \
  --gas-estimate-multiplier 100 \
  --sig 'deployAndIssue()' -vvvv
```

The larger Forge setting is the script's aggregate simulation budget. It does not alter the owned node's mined transaction ceiling. Any broadcast request or actual transaction exceeding the 32M ceiling fails this gate; do not raise the node limit or disable code-size checks.

Preserve the corresponding `broadcast/MigrationCoreLocalQA.s.sol/31337/` run before another stage overwrites `run-latest.json`. Derive the helper and product addresses from this run's actual deployment receipts/logs, then verify them with on-chain reads at this exact local endpoint.

Record:

- helper/controller and parent owner;
- parent, bond child, receipt, raw/staking SY, RT and reserve hook addresses;
- the independent bond from `independentIssuance(DEV)`;
- the real paid owner bond from `migrationOwnerFirstBondTokenId()`;
- actual position values, allowances, payment balances, supply/backing and the released remainder;
- actual tokenURI JSON/SVG for both bond IDs.

Set `OWNER_HELPER` to the verified helper address. Read both real positions. Calculate `CUTOVER_TS` as one second after the greater of the compensation cliff and paid ordinary bond end. This uses their stored creation timestamps/durations, not the script launch time.

On this owned local node only:

```sh
cast rpc --rpc-url "$RPC" evm_setNextBlockTimestamp "$CUTOVER_TS"
cast rpc --rpc-url "$RPC" evm_mine

FOUNDRY_BLOCK_GAS_LIMIT=1000000000 \
python3 scripts/forge-artifacts.py script \
  "$S/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA" \
  --rpc-url "$RPC" --broadcast --unlocked --sender "$DEV" \
  --gas-estimate-multiplier 100 \
  --sig 'exerciseAfterCliff(address)' "$OWNER_HELPER" -vvvv
```

`OWNER_HELPER` and `CUTOVER_TS` are required measured values from Stage A. Do not fill them with a sample address or guessed timestamp.

Require successful receipts for the actual Stage B calls, including activation, reward claims, the postactivation sweep and the later ordinary purchase. Verify resulting state through native `cast call`/receipt reads, not merely `STATE_TRACE` or console messages. Preserve the second broadcast run and the exact metadata captures.

The evidence must show:

- no activation before the paid prerequisite;
- real Stage A payment and a funded ordinary bond;
- mature compensation principal works while rewards remain closed;
- activation actually removes all administrative selectors;
- old released capital produces positive LP progress after activation without another donation;
- reward presentation and real payout agree after activation;
- the later ordinary bond is distinct from the first owner bond;
- transaction status is successful and receipt gas/code size stay within the stated limits.

If a stage fails, retain its raw failure and receipts, determine which transactions actually mined, and diagnose the cause. Do not install a custom journal/replay engine or blindly repeat a possibly completed purchase. A fresh owned local node may be used for a corrected full lifecycle after a source change, with the failed run preserved and clearly separated.

Stop only the owned node after evidence capture.

## 7. Source/artifact/run binding

For each final gate, store the following under `D/gap-closure-20261116/<run-stamp>/`:

| Record | Required content |
| --- | --- |
| `source-manifest.json` | Repository-relative paths and SHA-256 values for changed files and the actual runtime dependency closure. Include source versions from artifact metadata/build inputs for linked libraries, facets, packages, factory/proxy code and relevant test/script helpers. Do not imply an edited-file-only list certifies all dependencies. |
| `artifact-manifest.json` | Actual compiler version/commit, relevant settings, source-qualified contract IDs, resolved artifact paths, artifact-file hashes and full creation-bytecode hashes. Record link and immutable references where relevant. |
| `commands.md` and raw logs/status records | Exact command, working directory, profile, artifact/cache root, redacted environment policy, start/end, process exit, selected nonzero tests and actual results. Avoid secrets in logs. |
| `native-stage-a/` and `native-stage-b/` | Actual broadcast JSON, successful and failed receipts, transaction input/gas limits/gas used, node/header identity, deployed addresses and code hashes, readbacks and source/artifact mapping. |
| `metadata/` | Actual pre/post tokenURI JSON, decoded SVGs, rendered captures and brief numeric/visual inspection results with the relevant bond ID and stage. |
| `pricing-evidence.md` | Each actual R0/R1/R2 fixture's bindings, reserves, rates, weights, decimals/scales, fee, p, input, expected live-hook result, evaluated result and boundary outcome. Identify the actual passed tests. |
| `verification.md` | Final F1-F4/P1 ledger, ordinary-regression results, fork status, local gas/call limits, unresolved qualifications and exact links to all supporting records. |

Generate these as bounded evidence capture using existing tools. Do not create another migration application, reusable transaction wrapper framework, bundle format, checkpoint store or runtime journal.

Compare relevant source hashes before and after the final run. Also record the resolved runtime artifact set around commands that may compile. If a relevant artifact changes, earlier execution is evidence for the earlier artifact, not automatic proof of the final one. Re-run only affected verification after a real change; do not keep repeating already settled checks.

For local deployed contracts with links or immutables, retain full runtime bytes and account explicitly for the artifact's declared substitutions when comparing. Never discard metadata to conceal a creation-bytecode difference: full creation identity affects deterministic deployment.

Historical receipts may remain linked with the coordinator's prior 293/299 comparison and its dependency/artifact limitations. They cannot certify these new release, helper or metadata changes. No new all-history source census or public-chain scan is needed.

## 8. F4 documentation edits

Make exactly these current-document changes after the relevant results exist:

1. **`D/verification.md`:** prepend a dated current-status section linking the final review and new gap-closure verification. State actual closure status for F1-F4/P1, actual new command results and any remaining conditional fork/gas/provenance scope. Retain the November 13 record below under an explicit historical heading; do not rewrite its old observations as though they were current runs.
2. **`D/quote-evidence.md`:** prepend the governing manual-pricing scope. State that the older automatic-capture/live-composition increment is historical. Link the new raw observed-hook evidence when executed, distinguish it from the retained unit vectors and V3/disabled-buffer comparisons, and preserve the original reports below. Until P1 passes, say it remains unverified.
3. **`D/foundry-runbook.md`:** replace the archived absolute working-directory assumption with a current-repository-root requirement. Document the existing native stage calls, the real paid owner prerequisite, genesis remainder release followed by retained sweep, manual pricing, and receipt inspection before repetition. Add the bounded local QA commands or link the new exact executed-command record.

The runbook must clearly distinguish:

- live migration operations that require their own authority and reviewed inputs;
- the hermetic QA script with external fixture currencies;
- pinned read-only/local fork tests;
- historical records and withdrawn application requirements.

Do not edit the original migration plan's old checkboxes or the final review to claim closure. The new current evidence entry point carries the closure status and references those immutable inputs.

Documentation checks:

- All current links resolve within the current checkout or are explicitly labeled historical paths.
- No current command starts in an archived worktree.
- No headline treats the old automatic-capture prerequisite, portable bundle, journal or removed operator failure as a current blocker.
- No future/unrun command is described as passed.
- Full test totals, individual case coverage, native receipts and source/artifact identity are separate claims.

## 9. Final acceptance and stop condition

The executor can mark this gap-closure plan complete only when:

1. **F1:** a permitted partial bootstrap releases only measured booked remainders; real usable capital reaches the reserve through the existing path before and after activation; refunds/dust remain conserved; unsolicited/recovery balances remain protected; no compensation, owner-first marker or arbitrary payout is created.
2. **F2:** the real helper/controller payment produces the genuine prerequisite; the exact retained two-stage native QA reaches activation, claims, retained funding progress and a later ordinary purchase with valid IDs and receipts.
3. **F3:** actual metadata agrees with real principal and reward availability for purchased, cliff and reserved positions; ordinary-package behavior remains unchanged; actual SVG captures are readable and correctly labeled.
4. **P1:** the valid real mixed hooks produce nonvacuous observed Raw and RawRate comparisons, including native9 output and domain failures, on the final identified artifacts. Otherwise P1 stays explicitly open and the five-gap plan is not complete.
5. **F4:** current evidence navigation and repository-root native instructions are published, preserve historical records and accurately describe all results and remaining limitations.
6. Solar compilation, meaningful automated coverage, the full hermetic regression, required pinned migration forks, source/artifact binding and the native local receipt/code-size/gas gates are clean or explicitly unresolved. An unresolved required gate prevents a full-completion claim.

A successful five-gap closure does not turn selective council coverage into an exhaustive repository audit. It does not approve a live manual book, historical allocation dataset, public deployment, funding transfer, activation or legacy-governance action.

### Exclusions

- No implementation during this planning contribution.
- No ordinary DETF bare-pair admission change and no all-raw/no-SE hook admission change.
- No production pricing-formula change hidden inside P1 fixture work.
- No direct DETF mint, storage injection, SUT etch or mocked product to make a test pass.
- No arbitrary capital withdrawal, generic executor, new owner power, queued mechanism or restoration of removed selectors.
- No change to original-wallet eligibility, NFT 3's split, TokenStaking original conservation, manual-book lifetime, cliff clocks or reward-accounting policy.
- No TypeScript operator, launcher, portable execution bundle, transaction journal or application recovery layer.
- No public RPC transaction, new external historical census, provider/pin substitution, dependency/toolchain installation or Git operation.
- No edits to the original migration plan, baseline PRD, final review, resolution, immutable drafts or member originals.

# Limits

This is one independent authoring contribution. The mechanisms are grounded in current source and specify future gates; they are not implemented or runtime-proven by this response.

I read no peer planning or original files, delegated nothing, and ran no project commands, tests, builds, Git operations, RPC calls or transactions. Historical command files and code were read as evidence only. Only this assigned `members/astra/response.md` was authored.

The contribution neither replaces the accepted requirements nor authorizes implementation. It requests no additional product decision or extra council round. A separate single advisory pass may assess the coordinator's identified synthesis.

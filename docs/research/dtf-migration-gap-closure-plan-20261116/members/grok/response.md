## Identity

Member: grok. Phase: independent plan authoring. Requested role: council-member. Requested model: xai/grok-4.7:high. Runtime identity: not exposed. Run: `dtf-migration-gap-closure-plan-20261116`. This contribution does not replace the review, does not authorize implementation, and does not demand another round.

## Question and targets

Write one executable plan that closes accepted gaps F1, F2, F3, F4, and pricing qualification P1 in `/Users/cyotee/Projects/indexedex`. Do not repeat the audit. Do not restore a CLI, journal, ancestry proof, automatic price capture, live-production composition, a TokenStaking adapter dependency, a mandatory NFT surrender wrapper, or a recreation of the task-11 gas campaign.

## Evidence

Facts read this pass:

- Final review `REMEDIATION_PRD.md`, supplied SHA-256 `5df379c5865f3be2f74b70a834e1c48965b30c86697aeef41619b41dd36393ba`, not recomputed.
- Resolution `coordinator/resolution.md`, supplied SHA-256 `4c4cf99eff4899a69f94b245665c7717097b342f3b9bb96c7bc02ed4d70ffe49`, not recomputed.
- Migration plan, supplied SHA-256 `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`. November 15 correction and sections 1.1–1.10 govern.
- `bootstrapMigrationReserve` debits only consumed genesis amounts and then sets the reserve live, so it cannot run again (`UniswapV4DetfMigrationAllocationTarget.sol:305-414`).
- Live donations release only that call's receipts (`UniswapV4DetfMigrationWeightedHookTarget.sol:327-377`, `_releaseDonation` at 380-384).
- `MigrationCore.t.sol:43-72` donates 100 and bootstraps 50, then stops.
- `MigrationCoreLocalOwner` can bind, bootstrap, configure, issue, and activate. It cannot buy a bond (`MigrationCoreLocalQA.s.sol:41-82`). `exerciseAfterCliff` calls `activate()` at line 320. `deployAndIssue` expects independent bond id 3.
- Production purchase helper transfers separate `pairA`, approves, and calls `bond` with `pretransferred = false` (`TestBase_UniswapV4DetfMigration.sol:376-386`). The activation guard at `AllocationTarget.sol:267-268` is correct and stays.
- Ordinary owner bonds skip migration presentation, so `rewardsClosed` stays false (`UniswapV4DetfMigrationBondMetadataTarget.sol:30-32`). Shared rendering still describes those rewards as claimable (`DETFFundedBondMetadata.sol:34-42,105-116,166-179`).
- Snapshot `_oracle` (`TestBase_UniswapV4DetfMigrationSnapshot.sol:153-191`) compares a live SE `previewExchangeIn`. `test_ManualMath_AllFourModesAndAmountDependentV3` (`MigrationWeightedPricing.t.sol:338-364`) changes manual modes and checks arithmetic only.
- `storeHookSetsAndRates` reverts `BarePairForbidden` when a hook pair has no Standard Exchange (`UniswapV4DetfProcessArgsLib.sol:120-126`).
- The weighted-hook TestBase etches permit2 at line 110. That etch is not a model for the migration SUT.
- Task-11 `batch-limits.md` already records the 32,000,000 ceiling and the admitted shapes. Do not rerun that campaign.
- Runbook stage table (`foundry-runbook.md:27-40`) names fungible `surrender*` functions and does not name NFT surrender.

Inference: a retained owner call that releases booked `donationInventory` into the existing sweep is the smallest path that can move the remainder after the reserve is live, including after activation. A live `previewExchangeIn` on the current migration hook is not a Raw/RawRate oracle.

Unverified: I did not execute tests, decode a rendered URI, or recompute hashes.

## Assumptions

- An already activated deployment is not upgraded. Fixes apply to source and fresh artifacts.
- Caller-selected amounts are allowed when bounded by that token's `donationInventory`. The resolution settled this. No new owner decision is open.
- Reusing `_sweepDustBody` after `_releaseDonation` is the reserve route. Debiting recovery inventory is forbidden.
- `rewardsClosed == false` remains the ordinary-package default. Only the migration metadata target sets it from `migrationActivated()`.
- P1 is an evidence obligation. The pricing library is changed only if the new comparison fails.

## Coverage

Examined for this plan: allocation bootstrap and genesis conversion, donation release and sweep budget, core partial-bootstrap test, QA owner and both script stages, TestBase purchase helper, migration and shared bond metadata, snapshot oracle, pricing-mode test, process-args bare-pair rejection, hook TestBase etch, runbook stage table, and task-11 gas header.

Not examined: every recovery step body, ordinary metadata callers beyond the shared library, and peer planning files.

## Proposed plan

### F1 — release booked donations through the existing sweep

Chosen mechanism: add owner-only `fundReserveFromBookedDonations(IERC20[] tokens, uint256[] amounts, uint256 minLpOut, uint256 deadline)` on `UniswapV4DetfMigrationWeightedHookTarget`, next to `donateMigrationCapital`. Declare it on `IUniswapV4DetfMigration` and add its selector to `UniswapV4DetfMigrationWeightedHookFacet.facetFuncs`. Do not add it to `_administrationSelectors`.

Dismissed: repeating `bootstrapMigrationReserve` after `isReserveLive`, a permissionless reclassification, and any recovery-inventory debit. Bootstrap cannot run twice and is removed at activation. A bookkeeping move alone fails the acceptance condition.

State transition, reserve already live:

1. `MultiStepOwnableRepo._onlyOwner()`. Require not disabled, idle children, and an unexpired deadline.
2. Require `minLpOut > 0`, equal array lengths, no duplicates, and at least one token.
3. For each token, call the existing `_requireDonationToken`. Require `0 < amount <= donationInventory[token]`.
4. Record the hook-LP balance of `_bondLpHolder()`, recovery inventory, bond backing, and DETF supply.
5. `_beginBudget()`.
6. `_releaseDonation(token, amount)` for each selected token. That debits `donationInventory` and lowers `operationFloor` by the same amount, which is the existing spendable-residual rule.
7. `_sweepDustBody()`. This is the same join used by a live `donateMigrationCapital`.
8. Require the LP increase to be at least `minLpOut`. Otherwise revert.
9. `_endBudget()`. Unjoined dust of the released amount becomes `residualInventory`, not `donationInventory`.
10. Sync expected holds. Emit the existing capital-consumed event already emitted by `_releaseDonation`. No new beneficiary event.

Invariants: donation book falls by exactly the selected amounts; LP rises by at least `minLpOut`; no user DETF is minted; no bond principal changes; recovery inventory is untouched; unsolicited balances stay inside the operation floor because only the released donation amount lowers that floor. Work is bounded by the selected list, which cannot exceed the donate-table length.

Failure: any failed check or a short LP increase reverts the whole call, so the donation book is unchanged. Conversion refunds that the sweep does not join stay in residual inventory only on success. They are not credited back to donations and are not withdrawn.

Availability: the selector survives activation. It works in Stage 1 after bootstrap and in Stage 2. It does not restore pricing or configuration authority.

Exclusions: no arbitrary token, no `address(this)` self-leg, no recovery token, no zero `minLpOut`, no personal credit, no upgrade of a live proxy.

Regression: add `test_partialBootstrapRemainderJoinsReserveBeforeAndAfterActivation` to `MigrationCore.t.sol`. Start from the existing 100-donate / 50-bootstrap setup at lines 43-72. Non-owner reverts. Owner funds the remainder with `minLpOut = 1`. Assert LP increases, `donationInventory` falls by the selected amount, user supply and recovery inventory are unchanged, and a too-large amount or an impossible `minLpOut` reverts with inventories unchanged. Repeat one selected token after `activateMigration` and assert the new selector is still installed. Keep the existing non-owner genesis assertion.

Native wrapper, same task: add `fundBookedDonations` to `Phase_08_Stage_01_MigrationExecution.s.sol`. The sender is the current owner. This is the new funding operation, not an NFT wrapper.

Acceptance: on a registry-deployed proxy, donated-but-unbootstrapped pair tokens move into hook LP held by the bond child, with the inventory identities above, both before and after activation.

### F2 — QA owner buys the ordinary bond before activation

Chosen mechanism: add `buyOwnerFirstBond(IERC20 token, uint256 amount, uint256 duration, uint256 deadline)` to `MigrationCoreLocalOwner`. The controller calls it. The function approves `parent` for `amount` and calls `parent.bond(token, amount, duration, address(this), false, deadline)`. It does not write `ownerFirstBondTokenId`. The production guard stays unchanged.

Payment source: in `deployAndIssue`, after `setConfigureIssue`, transfer `1 ether` of `pairA` from the broadcast sender to the owner contract. That transfer is new capital, not `donationInventory` and not the 100 ether already donated. Then call `buyOwnerFirstBond(IERC20(pairA), 1 ether, 30 days, block.timestamp + 1 hours)`.

Sequence inside `deployAndIssue`, still under `vm.startBroadcast()`:

1. Donate and bootstrap as now.
2. `setConfigureIssue`, which keeps independent bond id 3.
3. Transfer 1 ether `pairA` to the owner contract and buy the owner bond.
4. Require `migrationOwnerFirstBondTokenId() != 0`, that id is not 3, `isMigrationPosition` is false, vesting duration is 30 days, and the owner contract's `pairA` balance fell by 1 ether.
5. Require bond 3 is still the 90-day compensation position.

`activate()` must capture `tokenURI(migrationOwnerFirstBondTokenId())` before and after activation, not hardcoded token id 3. Token 3 remains the compensation cliff bond used by `exerciseAfterCliff`.

`exerciseAfterCliff` then reaches `activate()` and its existing reward claims. Do not seed the marker. Do not treat independent compensation as the purchase.

Failure witness: keep the direct `activateMigration` revert `MigrationOwnerFirstBondRequired` already expected in `MigrationWeightedPricing.t.sol` before `_buyOwnerFirstBond`. Add `test_QaOwnerActivateWithoutPurchaseReverts` in `MigrationOwnerFirstBond.t.sol` that uses the real owner contract, skips the new purchase, and expects that same production error.

Exclusions: no ownership transfer, no arbitrary call forwarder, no change to `AllocationTarget.activateMigration`.

Acceptance: `deployAndIssue` then, after 90 days, `exerciseAfterCliff` on local chain 31337 completes payment, nonzero ordinary owner bond, activation, and the later claims. The missing-purchase test still reverts.

### F3 — activation closes reward display for every migration-instance bond

Chosen mechanism: in `UniswapV4DetfMigrationBondMetadataTarget.tokenURI`, set `rewardsClosed = !IUniswapV4DetfMigration(parent).migrationActivated()` for every token id. Keep `migrationPresentation = migrationCliff || tokenId < 3`. Do not mark the owner bond as a cliff.

In `DETFFundedBondMetadata`, use the existing `rewardsClosed` flag for purchased non-cliff bonds as well as cliff bonds:

- `_claimableRewards` already returns 0 when closed. Keep accrued `rewardsDue` available to the view, but do not add it to claimable totals while closed.
- For `tokenId >= 3 && !migrationCliff && rewardsClosed`, the JSON `Reward delivery` trait is `Locked until activation`, and the SVG status line says reward claims are locked. After activation the trait is `Open` and the existing linear description remains.
- Description for that closed ordinary bond says linear principal vesting remains and reward or combined claims are closed until activation. Do not copy the cliff description onto it.

Ordinary packages never set `rewardsClosed`, so their renderer output stays on the false branch. Do not change ordinary bond targets.

Regression: add `test_ownerBondMetadataClosesRewardsUntilActivation` to `MigrationOwnerFirstBond.t.sol`. Buy through `_buyOwnerFirstBond`. Decode `tokenURI` for that id. Before activation, parsed claimable-rewards attribute is 0, total claimable equals principal due only, and the reward-delivery trait is locked. Principal vesting attributes stay linear. After activation, claimable rewards equal `previewClaim.rewardsDue` when that value is nonzero, or stay 0 if none accrued, and the trait is open. Reserved ids 1 and 2 keep their existing locked trait before activation. Add one pure assertion that `_uri` with `rewardsClosed == false` and a non-cliff purchased view still reports claimable rewards equal to `rewardsDue`. That protects ordinary rendering without pinning a whole SVG.

Exclusions: no change to `_claim` or `_requireActivated`. Display does not bypass payment.

Acceptance: parsed numeric attributes and the reward-delivery trait, plus the locked status line, match the payout gate before and after activation.

### F4 — current navigation without rewriting history

Chosen mechanism: add `docs/incidents/2026-09-16-dtf-recovery/migration/current-completion.md`. Do not replace `verification.md`, `quote-evidence.md`, the route matrix, or the recovery disposition. Prepend a short dated banner to each of those four files. The banner states that the body is historical, cites the current plan hash `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949` as the governing plan, and links `current-completion.md`. The old 98,213-byte hash remains in the historical body as provenance, not as the current plan identity.

`current-completion.md` links:

- this gap-closure plan and the final review
- `.omo/verification/artifact-mismatch-20261116/full-hermetic.log` (28,641 passes) and `DIAGNOSIS.md`
- `.omo/verification/dtf-operator-removal-20261115/REMOVAL.md`, plus the worktree `native-spec.log` and `native-fork.log` as historical fork evidence
- `conformance-20261114/task-11/batch-limits.md` for the 32,000,000 ceiling and admitted shapes
- the new `gap-closure-20261116/` receipts after they exist
- F1–F3 and P1 as open until their tests pass, then closed only by those receipts

Rewrite `foundry-runbook.md` so commands run from the repository root. Delete the hardcoded `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1` instruction. Name that worktree as historical evidence only.

Replace the stage table with the exact `Phase_08_Stage_01_MigrationExecution` functions: `prepareDeployment`, `deploy`, `fund`, `bootstrap`, `setPricing`, every `configure*` function, `independentIssue`, `ownerFirstBond`, `activate`, every existing `surrender*` function, `harvest`, and the new `fundBookedDonations`. State explicitly that `surrenderMigrationNft` is a production operation and is not wrapped. Do not add that wrapper.

Exclusions: no gas-campaign rerun, no deletion of historical logs, no claim that the November 16 artifact rebuild replayed forks.

Acceptance: a reader can reach current commands, source scope, gas limits, and unresolved work from the plan-named files without a private session log.

### P1 — Raw/RawRate parity against observed hook math

Chosen mechanism: add `test_RawAndRawRate_MatchObservedHookMath` to `MigrationWeightedPricing.t.sol`. Do not attach a bare pair to a DETF package. Do not subclass the weighted-hook TestBase, because its setup etches permit2. Do not etch the migration proxy, registry, or pricing library.

The current snapshot oracle is the V3/enabled and disabled-buffer comparison. Keep it. `test_ManualMath_AllFourModesAndAmountDependentV3` remains an arithmetic vector, not parity.

The new test reads the already deployed migration `reserveHook`: token, weight, `invScale`, `ratedScale`, fee, seigniorage, and `rateProvider(i).getRate()` where present. It copies those values into two manual books whose input leg is `LegMode.Raw` and `LegMode.RawRate`. `seReserve` is 0 and the V3 deposit operand is empty. Expected output is computed with the hook's own pure quote path: `Weighted.applyTradingFeeNet`, `Weighted.ratedPairUnits` and `scaleTo` for RawRate, then `Claim.exactInputBudget` and `Claim.rawOutput`, then `DETFMintSplitLib._splitLiveGross`. Assert `PricingLib.evaluateOriginal` matches `pairEquivalent`, `boosted`, `net`, `ratedInflow`, `gross`, and `user`.

If the deployed hook rate is zero, use the nonzero rate already configured by that hook's rate-provider view after reading it. Do not invent a second vault model. If no rate view is nonzero, the RawRate case uses the rate returned by the hook's own `rateProvider` call even when the test must first set that provider through the hook's existing production setter. It must not etch the hook.

If this comparison fails, fix `UniswapV4DetfMigrationWeightedPricingLib` in the same task so the pure evaluator matches that hook math. Do not start from an assumed defect.

Exclusions: no selected live reserve composition, no nested-vault quote, no change to the V3 snapshot oracle.

Acceptance: one passing test whose expected values come from the deployed hook's observed scales, reserves, fee, and rate, for both Raw and RawRate, plus the existing V3/disabled snapshot assertions still passing.

### Dependency-ordered tasks

| Task | Gap | Edits | Depends on | Parallel with |
| --- | --- | --- | --- | --- |
| T1 | F1 | Hook target, migration interface, hook facet funcs, `Phase_08` wrapper, `MigrationCore.t.sol` | none | T2, T3 |
| T2 | F3 | Migration metadata target, `DETFFundedBondMetadata`, owner-bond metadata test | none | T1, T3 |
| T3 | P1 | `MigrationWeightedPricing.t.sol`; pricing lib only if the new assertion fails | none | T1, T2 |
| T4 | F2 | `MigrationCoreLocalQA.s.sol`, `MigrationOwnerFirstBond.t.sol` failure witness | T2, so URI capture matches the new renderer | none |
| T5 | F4 | banners, `current-completion.md`, runbook table including `fundBookedDonations` and the unwrapped NFT surrender | T1–T4 receipts | none |
| T6 | gate | no product edits | T5 | none |

T1 and T2 do not share a file. T4 owns the QA script, so T2 must not edit it. T3 touches the pricing library only on a failed comparison; if that happens, rerun T3 before T6 and do not overlap it with another pricing edit. There is no other pricing edit.

### Future verification

Refresh artifacts before each focused test. Do not retarget `FOUNDRY_TEST`, delete caches, or weaken assertions. Every compiling Forge command uses `--use solar`.

```sh
python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
forge build --use solar
forge test --use solar --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationCore.t.sol
forge test --use solar --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationOwnerFirstBond.t.sol
forge test --use solar --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedPricing.t.sol
forge test --use solar --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshot.t.sol
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/common/**'
```

After a pricing-library change, also run the snapshot path above. After the metadata-library change, the common bond path is mandatory.

Local QA uses the script's existing chain 31337 and Anvil account `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`. The script comment names port 18548. No new launcher and no public RPC.

```sh
forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA --sig "deployAndIssue()" --rpc-url http://127.0.0.1:18548 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Advance the local chain 90 days with the node's existing timestamp method, mine one block, then:

```sh
forge script --use solar scripts/foundry/recovery/dtf-migration/MigrationCoreLocalQA.s.sol:MigrationCoreLocalQA --sig "exerciseAfterCliff(address)" <parent> --rpc-url http://127.0.0.1:18548 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Write command, exit code, parent address, owner-bond id, LP delta, and decoded metadata traits to `docs/incidents/2026-09-16-dtf-recovery/migration/gap-closure-20261116/`. Do not overwrite `conformance-20261114/` or the `.omo/verification` logs.

Final gate, after T5 points at those receipts:

```sh
forge build --use solar
forge test --use solar --no-match-path '**/fork/**' --no-match-contract Fork
```

Fork replay is not required to close these five gaps. The completion record must say the 183-case fork log remains historical and was not regenerated after the November 16 artifact rebuild. Ordinary-family failures that this change causes must be fixed. Pre-existing failures outside the edited files are recorded, not edited green.

### Final acceptance and exclusions

Closed only when all of the following are true in source-bound receipts:

- Partial bootstrap remainder increases real hook LP, and the donation book debit matches the selected amount, before and after activation.
- `deployAndIssue` plus `exerciseAfterCliff` pays for a non-cliff owner bond and then activates. A missing purchase still reverts in production code.
- Owner-bond JSON claimable rewards are 0 before activation and follow `rewardsDue` after activation. Ordinary `rewardsClosed == false` rendering is unchanged.
- Plan-named documents link the current entry, the portable runbook lists exact wrapped functions, and NFT surrender is stated as unwrapped.
- Raw and RawRate match the observed hook math. V3/disabled snapshot comparisons still pass.
- The full hermetic command exits 0, or names a pre-existing failure outside the edited files.

Still excluded after closure: public deployment, a production allocation, a live-proxy upgrade, a new NFT wrapper, a new gas campaign, and any withdrawn operator application.

## Conclusions

Use one retained owner sweep for F1, one real `bond` call from the QA owner for F2, activation-derived `rewardsClosed` for every migration-instance bond for F3, a new current-completion entry plus a portable function table for F4, and one observed-hook math comparison for Raw/RawRate. No owner product choice remains open. No live deployment is repaired by this plan.

## Limits

I did not run the tests or decode a URI. The sweep's exact refund token is whatever `_sweepDustBody` leaves in the proxy; the success condition is the LP increase plus the donation debit, not a guessed refund amount. If the deployed hook exposes no rate, the RawRate case must use that hook's production rate-provider setter rather than an etched rate. This contribution was returned inline because `apply_patch` is unavailable. No other writer was used.

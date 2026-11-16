## Identity

| Field | Value |
| --- | --- |
| Run ID | `dtf-migration-plan-execution-20261114` |
| Member label | `kimi` |
| Profile | `review` |
| Phase | `initial independent response` |
| Owned path | `docs/reviews/dtf-migration-plan-execution-20261114/members/kimi/response.md` |
| Requested role | `council-member` |
| Requested model and reasoning | `kimi-coding/k3.1-pro:high`, global route |
| Actual role, model, reasoning, task ID, session ID | not exposed |
| Fresh or continued | fresh |
| Peers read before submission | no |
| Review mode | independent static source and diff review; no sub-agent, test execution, deployment, wallet operation, installation, or Git write |

## Question and targets

Did the committed changes from `90ff0307a7a8e084aa073e02eff125e9c7973933` (`origin/main`) to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (`HEAD`) completely and correctly execute `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision `migration-detf-implementation-plan-r7-token-staking-migrated-exposure`, including sections 1-11 and the section 11 completion standard?

The required targets were the named plan and the explicit commit diff. I verified that `HEAD` and `origin/main` resolve to those exact hashes, that the merge base is `90ff0307a7a8e084aa073e02eff125e9c7973933`, and that the explicit diff contains 241 files, 38,251 insertions and 175 deletions, with no deleted files. I used the 241-file index and filename-presence index only as indexes and re-verified every absence or diff statistic used below.

I read all 726 lines of the governing plan, including sections 1, 1.1-1.9, 2, 3, 4, 5, 6, 6.1, 7, 8, 8.1, 8.2, 9, 10 and 11. Section 1 controls over the optional r20 PRD. I did not read or rely on the optional PRD.

## Evidence

### Static implementation evidence

The following are source observations, not runtime results:

- `UniswapV4DetfMigrationAllocationTarget.sol:263-277` requires a completed owner-first bond, resolves each selector's current owning facet, processes local Remove cuts, clears the allocation interface declaration and sets `activated`. Its `_administrationSelectors` returns 16 selectors at line 282. I matched those selectors against both removable facets' eight-function declarations and read the package cuts. No zero-address removal recipe is used.
- `UniswapV4DetfMigrationBondFacet.sol` restricts the Stage 1 purchase to the current owner and one completed purchase, rejects pretransfer payment, and publishes the prerequisite only after the inherited paid purchase and child funding return. `UniswapV4DetfMigrationExchangeFacet.sol` and the migration SY target close ordinary acquisition before activation. These paths were read statically; their tests were not run.
- Original-wallet validation precedes custody in the fungible surrender paths. Examples are `UniswapV4DetfMigrationTarget.sol:80-109` for weighted liquid and `:266-302` for NFT surrender, and `UniswapV4DetfMigrationRecoveryTarget.sol:49-81`, `:117-149`, `:187-224`, `:265-302` and `:402-434` for the other retained surrender families. Partial credit uses the stored remaining-Q/remaining-C calculation and terminal remainder rule. NFT contribution credits are scaled separately from the stored originals.
- `UniswapV4DetfMigrationRepo.sol:84-91` mints exactly the delivered credit and calls `createMigrationPosition`. `bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol:29-41` creates a fresh 90-day position from the actual creation time. Its `_calculateClaim` and `_claim` at lines 60-77 implement the marked-position cliff and activation gate for reward or combined claims.
- `UniswapV4DetfMigrationSnapshotLib.sol:135-180` is a pure evaluator over the captured book, including canonical fee, rated-input, weighted-budget and user-split arithmetic. Capture and admission are bounded to direct contribution-to-pair routes, recognized ordinary V3 deposit inputs and raw DETF output. The supplied evidence does not establish closure for the actual recovery configuration, as finding F-02 records.
- `UniswapV4DetfMigrationRecoveryTarget.sol:324-366` applies current-owner authorization and typed recovery stages. `MigrationLegacyRecoveryLib.sol` keeps reward-only claims separate from principal claims, combined claims and NFT sale, and tracks receipt gons, internal shares and operation-local conversion outputs. Recovery donation is fixed to DTF and the new reserve at `UniswapV4DetfMigrationRecoveryTarget.sol:441-470`.
- The migration receipt, SY and reward-token targets defer Stage 1 reward growth and role allocations rather than delivering them, while preserving mature principal. I read the direct bond-delivery, receipt transfer/unstake, SY acquisition/redemption and RT redemption paths. No additional defect is asserted on those read paths merely because their runtime behavior was not exercised.
- All shared changed-file hunks named in the brief were read. This includes the weighted-hook capture and arithmetic extraction, frozen V3 quote support, common bond/staking/SY virtual extension points, common DETF initialization extraction and residual-budget hook, V3 FullSpread capture support, and the three changed ordinary deployment/facet test files. The new `UniswapV4DetfInitializationLib.sol`, frozen-quote interfaces/libraries and weighted capture interface were read in full.

### Completion evidence that contradicts completion

- `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md:6` expressly says the bounded increment is not completion of task 2, E3, the full plan or lifecycle integration. Lines 165-175 say there is no identified production recovery binding and list uncertified quote models.
- `scripts/recovery/dtf-migration/execution.ts:98` returns `fullTask9: "open"` for read-only operation and line 185 returns the same value with receipts. `preparation.ts:110` and `:134` also set `fullTask9: "open"`. This is code read, not an inference from a checkbox.
- `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md:952-971` has a "Required categories still blocked" table and states that full original task 9 and release remain open. Lines 1159 and 1235-1236 retain full-plan acceptance and target-gas limits.
- At `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, `git ls-tree` found only `operator-runbook.md` and `quote-evidence.md` under the incident's `migration/` directory. Explicit `git cat-file -e` checks verified the absence of `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md` and `verification.md`. A separate check verified that `TestBase_UniswapV4DetfMigration_Adversarial.sol` is absent. These absences are not inferred from the coordinator's index.

## Assumptions

- Current files used for new-file review represent the verified `HEAD`; modified shared files were assessed through the explicit base-to-HEAD diff, with surrounding current source opened where needed.
- Plan section 1 and its later owner clarifications govern. No requirement was imported solely from the unread optional r20 PRD.
- Test source is evidence of intended coverage only. Test names, commit subjects, unchecked checkboxes and supplied historical pass prose are not treated as observed execution.
- Absence findings rely on direct checks at the reviewed commit, not filename-index rows.
- Unread files are not assumed either correct or defective. The negative verdict rests on identified requirements and evidence, not on an assumption that every unread file would fail.
- Numerical allocations and deployment authorization are not invented as implementation requirements. The findings instead concern the plan's explicit source-closure, verification, rehearsal and named-artifact obligations.

## Coverage

### Required-surface coverage

| Surface | Examination | Result and limit |
| --- | --- | --- |
| Governing plan | Fully read, all sections 1-11 | Requirements and section 11 standard identified. |
| Explicit diff | Verified hashes, merge base, name status, numstat and shortstat | 241 files confirmed; 98 files or modified-file diff sets examined, 143 remaining files named unread below. |
| Migration repo, policy, allocation targets, migration target, snapshot library, parent package and factories | Read in full | Static architecture and lifecycle paths examined. |
| Recovery target/repo and both legacy adapter interfaces/libraries | Read in full | All retained surrender families and typed recovery stages traced. |
| Bond child target/repo/package/facets/metadata and interfaces | Read in full | Fresh cliff funding, claim gate and metadata composition examined. |
| Migration receipt, SY and reward-token targets/packages/repos/facets/interfaces | Read in full | Stage 1 reward retention and activated release paths examined. |
| Migration TestBases and main migration interfaces | Read in full | Production deployment composition and API declarations examined; this is not an adversarial TestBase substitute. |
| Shared changed files listed in the brief | Every diff hunk read; new support files read | Ordinary behavior was not judged by runtime; no test was run. |
| Selected lifecycle tests | `MigrationCore`, `MigrationSurface`, `MigrationOwnerFirstBond`, `MigrationEgress`, `MigrationRetainedAccounting`, both `MigrationDeploymentGas` files, `MigrationLegacySources`, `MigrationNftLifecycle`, `MigrationOriginalWallet`, and `MigrationRecoveryAccrual` read | Source-level coverage only; no passing execution inferred. Other test files are explicitly unread below. |
| Operator implementation | `cli.ts`, `execution.ts`, `execution-state.ts`, `execution-deployment.ts`, `execution-owner-bond.ts`, `journal.ts`, `preparation.ts`, and `MigrationDeploymentGasResumedQA.s.sol` read | Resume and gas mechanisms inspected; task 9 remains explicitly open. |
| Evidence documents | `quote-evidence.md` fully read; `operator-runbook.md` partially read | Runbook lines 221-299, 390-659, 715-925 and 1016-1069 were not read. No unread range is used as evidence. |
| Optional r20 PRD | Not read | Not used for any requirement or finding. |

### Section 11 condition ledger

| Section 11 condition | Static examination | Completion judgment |
| --- | --- | --- |
| Full behavior works through the real registry-deployed package | Parent registry deployment, child preparation, package cuts and selected deployment tests read | Runtime work is not demonstrated by this review; required verification evidence is absent. Blocked by F-03, F-05 and F-06. |
| Every required legacy source supports configured original-wallet surrender/custody and source-claim conservation | Every production surrender and adapter path read | E1/E2 closure is not established; required source artifacts are absent and the runbook retains blocked categories. Blocked by F-01. |
| Missing configuration and wrong wallets revert atomically | Validation-before-custody paths and selected negative tests read | Static implementation exists, but no current passing runtime or complete source-matrix evidence was established. Blocked by F-01 and F-05. |
| Original credit is frozen and proportionally consumed without intermediate-holder history | Pure evaluator and remaining-Q/remaining-C arithmetic read | The evaluator is bounded, and its own evidence disclaims E3 completion for an unidentified actual configuration. Blocked by F-02. |
| Every surrender creates an exactly funded fresh cliff bond | Parent mint/pull/stake path, child 90-day marker and two-contribution NFT path read | Static path exists; full runtime demonstration and required verification remain absent. Blocked by F-05. |
| Activation is structurally irreversible | Sixteen actual-owner Remove cuts, package surface and owner-first-bond gate read | Static path exists; complete runtime/loupe evidence and verification report remain absent. Blocked by F-05. |
| Tests and resumable rehearsal demonstrate these facts | Selected test and operator source read; no tests run | Task 9 is explicitly open, target gas remains open, and `verification.md` is absent. Blocked by F-04, F-05 and F-06. |

The sentence "the plan was executed completely and correctly" is therefore not supported. The unexamined runtime conditions and the specifically identified open conditions each independently block that sentence.

### Unread diff remainder

The following 143 files were not read. They are partially accounted for only by their presence in the verified name-status/numstat diff; no hunk in them is claimed as examined. Root abbreviations below are exact path prefixes:

- `M = contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `FS = scripts/foundry/recovery/dtf-migration/`
- `OS = scripts/recovery/dtf-migration/`
- `FT = test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `ST = test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`

**Eleven unread invariant harness files under `M/invariant/`:**

- `MigrationLegacyClaimHandler.sol`
- `MigrationLegacyHandler.sol`
- `MigrationLegacyRecoveryHandler.sol`
- `MigrationNativeHandler.sol`
- `MigrationNativeLedger.sol`
- `MigrationSourceUnitsHandler.sol`
- `MigrationSourceUnitsLedger.sol`
- `MigrationSourceUnitsRecoveryHandler.sol`
- `MigrationStatefulBindings.sol`
- `TestBase_MigrationSourceUnits.sol`
- `TestBase_MigrationStateful.sol`

**One unread optional document:**

- `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md`

**Seven unread Foundry script files under `FS/`:**

- `MigrationClaimWitness.sol`
- `MigrationCoreLocalQA.s.sol`
- `MigrationDelegatedReceiverFixture.sol`
- `MigrationIndirectClaimFixture.sol`
- `MigrationSnapshotLocalQA.s.sol`
- `Phase_08_Stage_00_OperatorEnvironment.s.sol`
- `Phase_08_Stage_01_MigrationExecution.s.sol`

**Seventy-eight unread operator-script files under `OS/`:**

- `bundle-files.ts`
- `bundle-materialize.ts`
- `bundle.test.ts`
- `bundle.ts`
- `candidate-input.ts`
- `candidate-inventory.test.ts`
- `candidate-inventory.ts`
- `candidate-nfts.ts`
- `candidate-proofs.ts`
- `candidate-reconciliation.ts`
- `candidates.test.ts`
- `candidates.ts`
- `claim-vault.test.ts`
- `claimed-sy-member.ts`
- `claimed-sy-source.ts`
- `claimed-sy-state.test.ts`
- `claimed-sy-state.ts`
- `claimed-sy-witness.test.ts`
- `claimed-sy-witness.ts`
- `claimed-sy.ts`
- `core-local-qa-guard.sh`
- `dtf-custody-se.test.ts`
- `earlier-liquid.test.ts`
- `earlier-receipt.test.ts`
- `execution-domain.ts`
- `execution-plan.ts`
- `execution-rpc.ts`
- `execution-schema.ts`
- `execution.test.ts`
- `held-se-lp.test.ts`
- `nft-contributions.test.ts`
- `payloads.ts`
- `preparation.fixture.ts`
- `preparation.test.ts`
- `pricing-local-qa.sh`
- `provenance.ts`
- `quotes.ts`
- `receipt-association.ts`
- `receipt-evidence.ts`
- `receipt-input.ts`
- `receipt-reconciliation.test.ts`
- `receipt-reconciliation.ts`
- `receipt-rpc.ts`
- `receipt.fixture.ts`
- `receipt.test.ts`
- `rehearsal-admission.ts`
- `rehearsal-chain.ts`
- `rehearsal-claim-vault-source.ts`
- `rehearsal-claim-vault.ts`
- `rehearsal-claimed-sy-indirect.ts`
- `rehearsal-claimed-sy-intake.ts`
- `rehearsal-claimed-sy-local.ts`
- `rehearsal-claimed-sy-source.ts`
- `rehearsal-claimed-sy-transfer.ts`
- `rehearsal-claimed-sy-witness.ts`
- `rehearsal-claimed-sy.ts`
- `rehearsal-data.ts`
- `rehearsal-dtf-custody-se.ts`
- `rehearsal-dtf-custody-source.ts`
- `rehearsal-earlier-liquid.ts`
- `rehearsal-earlier-receipt.ts`
- `rehearsal-held-se-lp-source.ts`
- `rehearsal-held-se-lp.ts`
- `rehearsal-owner-bond.ts`
- `rehearsal-portable.ts`
- `rehearsal-process.ts`
- `rehearsal-proof.ts`
- `rehearsal-recovery.ts`
- `rehearsal-weighted-liquid.ts`
- `rehearsal-weighted-receipt-source.ts`
- `rehearsal-weighted-receipt.ts`
- `rehearsal-weighted-sy.ts`
- `rehearse.ts`
- `remaining-claimed-sy.test.ts`
- `schema.ts`
- `weighted-liquid.test.ts`
- `weighted-receipt.test.ts`
- `weighted-sy.test.ts`

**Twenty-six unread fork-test files under `FT/`:**

- `MigrationClaimVault.t.sol`
- `MigrationClaimVaultForkBase.sol`
- `MigrationDtfCustodySe.t.sol`
- `MigrationDtfCustodySeForkBase.sol`
- `MigrationEarlierLiquid.t.sol`
- `MigrationEarlierReceipt.t.sol`
- `MigrationHeldSeLp.t.sol`
- `MigrationLegacyLpExit.t.sol`
- `MigrationLegacySeExit.t.sol`
- `MigrationNftForkBase.sol`
- `MigrationRecoveryAccrualRollback.t.sol`
- `MigrationRecoveryClaimVault.t.sol`
- `MigrationRecoveryDonation.t.sol`
- `MigrationRecoveryDtfCustodySe.t.sol`
- `MigrationRecoveryEarlier.t.sol`
- `MigrationRecoveryForkBase.sol`
- `MigrationRecoveryGas.t.sol`
- `MigrationRecoveryWeighted.t.sol`
- `MigrationRecoveryWeightedReceipt.t.sol`
- `MigrationRecoveryWeightedSy.t.sol`
- `MigrationWeightedLiquid.t.sol`
- `MigrationWeightedReceipt.t.sol`
- `MigrationWeightedReceiptForkBase.sol`
- `MigrationWeightedSy.t.sol`
- `invariant/MigrationLegacyInvariant.t.sol`
- `invariant/MigrationSourceUnitsInvariant.t.sol`

**Twenty unread hermetic-test files under `ST/`:**

- `MigrationAdministration.t.sol`
- `MigrationClaimVaultConfiguration.t.sol`
- `MigrationClaimedSyConfiguration.t.sol`
- `MigrationDtfCustodySeConfiguration.t.sol`
- `MigrationEarlierLiquidConfiguration.t.sol`
- `MigrationEarlierReceiptConfiguration.t.sol`
- `MigrationGenesisCapital.t.sol`
- `MigrationHeldSeLpConfiguration.t.sol`
- `MigrationHostileContribution.t.sol`
- `MigrationNftConfiguration.t.sol`
- `MigrationOwnerBondCallbacks.t.sol`
- `MigrationPermit2.t.sol`
- `MigrationPermit2Callback.sol`
- `MigrationPermitAndRetirement.t.sol`
- `MigrationRecovery.t.sol`
- `MigrationWeightedLiquidConfiguration.t.sol`
- `MigrationWeightedReceiptConfiguration.t.sol`
- `MigrationWeightedSyConfiguration.t.sol`
- `UniswapV4DetfMigrationSnapshot.t.sol`
- `invariant/MigrationNativeInvariant.t.sol`

## Conclusions

No. The committed changes do not completely execute the named r7 plan, and the section 11 completion standard is not met.

The diff contains substantial migration implementation and source-level test/tooling work. Static reading did not establish a specific money-loss defect in the activation, surrender, fresh-bond or reward-gating paths examined. That limited observation is not a correctness certification: the plan requires closed source routes, exact actual-configuration pricing, full validation and resumable rehearsal evidence that the committed artifacts themselves leave open or do not contain.

F-01 through F-06 are blocking completion findings. In particular, task 9 is explicitly open in code, task 2's evidence disclaims E3 completion, required source/package/adversarial artifacts are absent, and no `verification.md` records the required commands, exits, test summaries, gas bounds and unresolved failures. No claim of complete and correct execution can be made on this record.

## Review findings

### F-01: E1/E2 source and surrender closure is not delivered

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md:425-453` (task 1 and its evidence); `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md:952-971` ("Required categories still blocked" and task 9/release open). Verified absent at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`: `docs/incidents/2026-09-16-dtf-recovery/migration/source-manifest.json`, `source-route-matrix.md`, and `surrender-spec.md`.
- **Plan requirement:** Section 3 E1/E2 and task 1 require every accepted source category/generation to have pinned identity, units, ownership/remaining-unit reads, surrender and harvest/conversion routes, original-wallet custody/conservation evidence, rollback evidence, the three named artifacts and fork run receipts. Section 11 requires every required source to be supported with configured original-wallet surrender/custody and source-claim conservation.
- **Impact:** Production adapter code exists, but the required source-by-source closure and executable evidence cannot be established from this commit. The runbook itself retains blocked categories; separately, its raw-weight limitation does not substitute for the plan's bounded claimed-SY preparation path. This blocks the every-source condition and prevents a complete/correct verdict even though individual adapter paths were read.
- **Fix direction:** Produce the pinned source manifest, complete route matrix and surrender specification with actual source identities and units; execute the required original-wallet custody, conservation and rollback cases on pinned local forks; retain receipts and concrete unresolved blockers. Do not mark full completion while any required row remains unresolved.
- **Evidence class:** verified artifact absence at the reviewed commit plus supplied-document limitation and static source review.

### F-02: Frozen quote evidence is explicitly bounded and does not close E3

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md:6` and `:165-175`; `UniswapV4DetfMigrationSnapshotLib.sol:22-180`, especially the direct-route and recognized-model admission checks.
- **Plan requirement:** Section 3 E3 and task 2 require an exact frozen evaluator for the actual configured weighted reserve/routes, with the full dependency inventory, all amount-dependent nested inputs, immutable behavior under later live changes, and differential vectors in `quote-evidence.md`.
- **Impact:** The committed evidence covers a bounded direct-pair, recognized ordinary-V3-deposit, raw-DETF-output fixture. It expressly disclaims task 2/E3 completion and has no identified production recovery binding. Therefore frozen credit for the actual recovery configuration is not established, blocking section 11's frozen-original-credit condition.
- **Fix direction:** Identify and pin the actual recovery composition; inventory every live quote dependency; either support all reachable nested models with exact frozen inputs and differential outputs or keep them explicitly unsupported as completion blockers. Record actual-configuration vectors and mutation-independence evidence rather than broadening from the fixture claim.
- **Evidence class:** supplied-document limitation corroborated by static evaluator admission logic.

### F-03: Required package evidence and adversarial TestBase are absent

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md:218` names both the ordinary and adversarial Migration TestBases; line 474 requires `migration/package-evidence.md`. Verified absent at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigration_Adversarial.sol` and `docs/incidents/2026-09-16-dtf-recovery/migration/package-evidence.md`.
- **Plan requirement:** Section 4 requires a production-first adversarial TestBase composed from the real registry-deployed Migration system. Task 3 requires registry/proxy declarations, storage and source-of-supply reconciliation in `package-evidence.md`; E4 requires demonstrated empty-reserve bootstrap without fabricated bonds or preminted entitlements.
- **Impact:** The ordinary TestBase and deployment tests do not supply the separately named adversarial fixture or the required package-evidence artifact. Package/bootstrap reconciliation and the planned adversarial composition are therefore incomplete as delivered artifacts, and the real-package completion condition lacks required evidence.
- **Fix direction:** Add the planned adversarial TestBase using the real registry, reserve, staking and children, and produce package evidence containing actual declarations, storage and source-of-supply reconciliation for empty-reserve donation/bootstrap. Preserve the ordinary TestBase rather than renaming it as a substitute.
- **Evidence class:** verified absence of two plan-named artifacts at the reviewed commit.

### F-04: Task 9 and the resumable rehearsal remain explicitly open

- **Location read:** `scripts/recovery/dtf-migration/execution.ts:98` and `:185`; `scripts/recovery/dtf-migration/preparation.ts:110` and `:134`; `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md:970-971`.
- **Plan requirement:** Task 9 requires deterministic preparation, separate stages, evidence-bound checkpoints, interruption-safe resume, no repeated donation/issuance, and a resumable rehearsal report. Section 11 requires tests and resumable rehearsal to demonstrate the accepted behavior.
- **Impact:** Both the simulation path and receipt-returning execution path report `fullTask9: "open"`; preparation reports the same status. The runbook independently states that full original task 9 and release remain open. The presence of resume machinery and selected tests does not satisfy the unfinished task, so section 11 cannot be met.
- **Fix direction:** Close the source and dataset prerequisites, execute the complete lifecycle with mined-before-checkpoint interruptions and fresh-process resumes, reconcile actual bond IDs/consumption/donations, and retain deterministic fixtures and receipts. Change the open status only after that full rehearsal is actually demonstrated.
- **Evidence class:** direct static code statement plus corroborating runbook limitation.

### F-05: Task 10 verification evidence is absent

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md:510-546` (task 10 and required evidence) and `:721-723` (completion standard). Verified absent at `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`: `docs/incidents/2026-09-16-dtf-recovery/migration/verification.md`.
- **Plan requirement:** Task 10 requires full integration, adversarial, invariant and fork validation, ordinary regressions, and a verification report containing exact commands, compiler version, source revision, exit codes, test summaries, gas bounds and unresolved pre-existing failures. Section 10 also requires full hermetic validation before handoff and treats unavailable checks as unrun, not passing.
- **Impact:** No committed artifact establishes that the required suites or full rehearsal ran successfully at this revision. This review did not run them, and static test names cannot replace the report. The testing half of section 11 is unproved regardless of the implementation's apparent breadth.
- **Fix direction:** Run the plan's artifact-first build, migration and ordinary hermetic suites, pinned fork suites, adversarial/invariant coverage and full scripted rehearsal; record exact commands, environment/compiler, revision, exit codes, nonzero test counts, gas bounds and pre-existing failures in `verification.md`.
- **Evidence class:** verified artifact absence at the reviewed commit; no runtime claim.

### F-06: Target-chain gas feasibility remains open

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md:1159` and `:1235-1236`; `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol`; `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDeploymentGas.t.sol`; `scripts/foundry/recovery/dtf-migration/MigrationDeploymentGasResumedQA.s.sol`.
- **Plan requirement:** Task 10 requires measured small/large loading, issuance and harvest batches, with operational limits selected from measured gas and target-chain limits rather than permissive hermetic settings. Task 9 requires bounded resumable operations and task 10 requires gas bounds in the verification evidence.
- **Impact:** The tests impose 32 million gas call limits in source, but the runbook retains target deployment gas as open and records a prior 44,353,454-gas parent deployment above 32 million. No current `verification.md` supplies mined target-relevant receipts or final batch bounds. Source-level call limits are not observed target-chain feasibility.
- **Fix direction:** Measure actual preparation/finalization and selected configuration/issuance/harvest transactions at small and large populations under target-chain rules; retain receipts and derive operational batch limits from those measurements. Preserve the two-step construction while proving its actual gas bounds rather than relying on a permissive node.
- **Evidence class:** supplied-document limitation plus unexecuted test/script source.

## Limits

- This was a static review only. I did not run Forge, project tests, TypeScript tests, builds, installations, deployments, wallets, or any Git write. I did not launch a sub-agent or council and did not read peer response files.
- Static reading is not a passing test run. Selected test files were read as source; their names and assertions are not observed outcomes. Historical evidence prose was treated as supplied documentation, not independently reproduced execution.
- The 143 files listed as unread, and the specified unread runbook ranges, were not assessed. The negative verdict does not depend on assuming defects in them; equally, they cannot be used to claim coverage or correctness.
- Actual deployed legacy runtime behavior at a pinned block was not independently re-executed. The review assessed committed adapters, evidence documents and named artifacts only.
- The optional r20 PRD was not read and supplied no requirement or finding. Section 1 of the r7 plan controlled every override used.
- Findings identify incomplete execution and missing evidence/artifacts. They do not allege that every examined production path is incorrect, and they do not authorize implementation, configuration changes, commits, deployment or compensation execution.

## Identity

Member: grok. Requested role: council-member. Requested model: xai/grok-4.7:high. Runtime identity: not exposed. Phase: initial independent response. Run: `dtf-migration-implementation-council-20261116-0228`. Profile: review. This response does not replace the plan, does not authorize implementation, and does not request another round.

## Question and targets

Question: was `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, including the November 15, 2026 owner scope correction, fully and correctly executed in the current working tree at `/Users/cyotee/Projects/indexedex`?

Targets reviewed as the current checkout, not an archived worktree:

1. Migration implementation, interfaces, TestBases and invariant handlers under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
2. Hermetic specs under `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
3. Legacy fork specs under `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
4. Native scripts under `scripts/foundry/recovery/dtf-migration/` and `docs/incidents/2026-09-16-dtf-recovery/migration/foundry-runbook.md`.
5. Shared extension points actually opened, listed under Coverage. Not a whole-repository audit.
6. Completion evidence under `docs/incidents/2026-09-16-dtf-recovery/migration/`, plus the coordinator-admitted current records `.omo/verification/dtf-operator-removal-20261115/REMOVAL.md` and `.omo/verification/artifact-mismatch-20261116/DIAGNOSIS.md` with `full-hermetic.log`.

The plan SHA-256 `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949` is coordinator-supplied. It was not recomputed. A filesystem read of the current plan file reported 743 lines and 97559 bytes.

## Evidence

Read completely: the brief and the current plan, including the November 15 correction and sections 1.1-1.10, 5-11.

Read in current source, with the locators used below: allocation setter, loaders, activation and bootstrap; both administration facets' selector lists; bond purchase exception; NFT surrender and two-contribution credit; pricing library and book struct; package salt, init and facet list; exchange Stage 1 gate; bond-child cliff and reward gate; staking reward deferral; policy mint gate; native execution script function list; runbook; route matrix; recovery disposition; November 13 `verification.md`.

Supplied execution records read, not rerun:

- Current-checkout `full-hermetic.log` ends with `28641 tests passed, 0 failed, 0 skipped` across 2691 suites. The same log names the migration hermetic suites, including pricing, administration, surface, owner-first bond, egress, recovery, hostile contribution, native invariant and operation gas. A failing suite would have made that aggregate nonzero. This is a supplied pass, not a pass I executed.
- `DIAGNOSIS.md` says that run followed a single-Solar artifact rebuild, with no contract, test or script edits during the repair, and that historical fork suites were not rerun. I did not independently confirm the Git claim.
- `REMOVAL.md` records a worktree build, 236 migration hermetic passes and 183 fork passes on November 15. That worktree is historical execution evidence only.
- Coordinator-supplied, not recomputed by me: 293/299 compared files matched `conformance-20261114/task-13/source-final.json`; the four removed app-only Solidity files are absent; `MigrationSnapshotLocalQA.s.sol` and `Phase_08_Stage_01_MigrationExecution.s.sol` differ; no current Solidity file in the four primary target roots was missing from that map.

Probed absent from this checkout, consistent with the withdrawn application and not treated as defects: `scripts/recovery/dtf-migration`, `Phase_08_Stage_00_OperatorEnvironment.s.sol`, and `migration/operator-runbook.md`.

No peer response was read. No test, build, shell, Git, RPC, transaction or subagent was run.

## Assumptions

- The plan's section 9 dispositions govern the 53 PRD acceptance IDs. The PRD was not reread sentence by sentence.
- Direct WETH and original-DTF legs make an identity pair-equivalent a plausible reading of section 5.2. I did not recompute a canonical differential fixture.
- Earlier NFT eligible units are source `originalShares`, not declining funded principal, because both the code and the route matrix say so. I did not read deployed bytecode.
- Coordinator hash binding is admitted evidence, not a hash I calculated.
- Withdrawn TypeScript CLI, preparation application, portable bundles, custom journals, application crash recovery, holder-transfer ancestry, automatic pricing capture and the live-production-composition prerequisite are superseded. Their absence is not a defect.

## Coverage

| Group | Status | What was examined |
| --- | --- | --- |
| Migration contracts, interfaces, TestBases, handlers | Partially examined | All 63 Solidity filenames. Function-level read of allocation, activation, pricing, NFT credit, bond cliff, reward deferral, package composition and facet selector lists. Handlers and TestBases were located, not read line by line. |
| Hermetic specs | Partially examined | 28 files, 210 `test` functions located. Suite names confirmed inside the November 16 passing log. Individual assertions were not all read. |
| Fork specs | Partially examined | 31 files, 151 `test` functions located. NFT, liquid, receipt and recovery names sampled. Not executed on this checkout. |
| Native scripts and runbook | Examined | Four current scripts located. `Phase_08_Stage_01_MigrationExecution.s.sol` function list read. Runbook read. |
| Shared extension points | Partially examined | Migration overrides of `UniswapV4DetfCommon`, bond and exchange targets, `DETFFundedBondTarget` cliff override, staking distribution override, and pricing calls into the weighted claim/math libraries and `DETFMintSplitLib`. Ordinary target and hook-math bodies were not audited. |
| Completion evidence | Partially examined | Route matrix, recovery disposition, November 13 verification, runbook, removal record, diagnosis and hermetic log tail. Archived checkouts, `source-manifest.json`, `quote-evidence.md` and `package-evidence.md` were not read through. |

Omitted on purpose: peer originals, archived worktrees as implementation, Crane `_processFacetCuts` body, deployed bytecode, and any production broadcast.

No `vm.store`, `vm.etch` or `vm.mockCall` was found in the migration contract or migration test trees.

## Conclusions

Execution verdict: **not fully executed**.

The retained contract surface and native Foundry script surface are present in this checkout, and the withdrawn application paths probed here are absent. I found no retained-requirement contradiction in the contract paths I traced. That is not a bug-absence guarantee.

The plan is not fully executed as an evidence-backed completion because the current route indexes are not bound to this plan file, pinned fork execution was not rerun against the regenerated artifacts, target-chain operational batch limits were not found as a current selection, and the live runbook still sends execution to another checkout. Those are missing execution evidence, not fabricated failing tests.

Correctness findings are separate and are limited to the two evidence-binding defects below. No high-severity contract defect was established.

### Tasks 1-10

| Task | Disposition |
| --- | --- |
| 1 Source, custody, conservation | Implemented in current adapters and surrender entrypoints. Route evidence exists but is not bound to the current plan bytes. Fork execution is supplied only through the November 15 worktree receipt plus coordinator hash binding. Not closed on this checkout. |
| 2 Manual Weighted pricing | Implemented. `MigrationWeightedPricing` (19 tests) is in the passing current hermetic log. I did not re-read `quote-evidence.md` against the current library. |
| 3 Package, owner, bootstrap | Implemented. Core, genesis and deployment-gas hermetic suites are in that same passing log. |
| 4 Configuration and expected-book loads | Implemented. Expected-book check is before quotation. Configuration suites are in the passing hermetic log. |
| 5 Cliff bonds and reward gates | Implemented in the bond child and staking receipt paths I read. Egress and owner-bond hermetic suites passed in the supplied log. Not every child selector was traced. |
| 6 Atomic surrender | Implemented, including Stage 1 rejection before the NFT pull and per-contribution bonds. Source-fork execution is not a current-checkout receipt. |
| 7 Irreversible activation | Implemented as a 16-selector removal across both administration facets, with the owner-first-bond prerequisite. Surface and administration hermetic suites are in the passing log. I did not inspect a live loupe. |
| 8 Bounded recovery | Implemented and indexed for all 14 rows, including one recorded E-P permanent-custody boundary. Fork recovery witnesses were not rerun here. |
| 9 Native scripts | Retained script functions are present and the withdrawn CLI is absent here. Current differing scripts have no script-specific compile receipt in the records I read. The runbook points at another tree. |
| 10 Integration, adversarial, invariant, fork, gas | Hermetic invariant, hostile and gas tests are in the passing current log. Fork integration and target-chain batch-limit selection are not established for this checkout. Not fully executed. |

### F1-F4

| Item | Disposition |
| --- | --- |
| F1 Policy and source coverage | Not fully verified. Contract policy is present. The route index cites a different plan fingerprint and says it reran no recovery checks. |
| F2 Production proxy and money paths | Partially supplied. Current hermetic proxy suites passed. Pinned legacy forks were not rerun after the November 16 artifact rebuild. |
| F3 Native Foundry execution | Partially supplied. Hermetic contract suites passed on this checkout. Script broadcast was correctly not treated as authorization. Compile of the two scripts that differ from the historical map was not separately receipted. |
| F4 Completion record and deployment limits | Not complete. `verification.md` is a November 13 operator-era record that itself leaves completion open. No later record I read replaces it for this checkout. Deployment, funding and activation remain unauthorized, which is correct. |

### MIG-P01-P15

| ID | Status | Locator |
| --- | --- | --- |
| MIG-P01 | Implemented; hermetic pricing/config tests supplied | `UniswapV4DetfMigrationWeightedPricingLib.sol:141-146`; loaders call `evaluateOriginals` only after `Repo._weightedPricing(expectedBookId_)` |
| MIG-P02 | Implemented; book replacement does not recompute stored credit | `AllocationTarget.sol:45-56`; surrender uses stored contribution credit, `MigrationLegacyNftLib.sol:67-75` |
| MIG-P03 | Implemented for weighted fixed-principal; earlier NFT uses source original shares | `MigrationLegacyNftLib.sol:32-40` and `:67-74` |
| MIG-P04 | Implemented | `MigrationLegacyNftLib.sol:48-60`; zero remaining reverts in `position` |
| MIG-P05 | Implemented for the NFT path read | Whole identity stored at `WeightedHookTarget.sol:278-285`; one pull, then per-contribution bonds |
| MIG-P06 | Implemented, with the section 1.7 two-bond override | `Repo.sol:92-98`; two credits at `ClaimVaultAllocationTarget.sol:55-62`; bonds at `WeightedHookTarget.sol:286-296` |
| MIG-P07 | Implemented | `BondNFTVaultTarget.sol:29-42`; duration stored as 90 days; later bonds call the same creation path |
| MIG-P08 | Implemented in the paths read | Accrual is not deleted; `_claim` rejects reward claims while inactive, `BondNFTVaultTarget.sol:73-76` |
| MIG-P09 | Implemented | Independent issue is a separate owner function, `AllocationTarget.sol:105-148`, and does not set `ownerFirstBondTokenId` |
| MIG-P10 | Implemented | Stage 1 `administration` modifier reverts after activation, `AllocationTarget.sol:37-42`; replacement overwrites configuration without calling `_fundBond` |
| MIG-P11 | Implemented in source; live loupe unverified | `AllocationTarget.sol:267-303`; mint gate `Policy.sol:125-127`; no cut facet in `DFPkg.sol:183-197` |
| MIG-P12 | Implemented | Owner set in `DFPkg.sol:275-291`; setter remains until activation; fee and creator are not that owner |
| MIG-P13 | Implemented | Bootstrap and `donateMigrationCapital` do not check pricing. Pricing is not a funding gate. |
| MIG-P14 | Implemented; repeatable reward-only path is in the recovery index, fork witness not rerun here | `RecoveryTarget.sol:324`; disposition table in `recovery-route-disposition.md` |
| MIG-P15 | Implemented on the NFT surrender read | Wallet check before pull, `WeightedHookTarget.sol:262-272`. Other surrender functions were located, not each read. |

### E1-E5

| Gate | Status |
| --- | --- |
| E1 | Code and a 14-row matrix exist. Matrix fingerprint does not match this plan file. Fork demonstration is not a current-checkout run. Unverified against current artifacts. |
| E2 | Stage 1 rejection and original-wallet check are in the NFT path. Hermetic configuration tests passed. Fork conservation was not rerun here. |
| E3 | Evaluator is pure and rejects invalid domains, `WeightedPricingLib.sol:18-80`. Nineteen hermetic pricing tests are in the passing log. I did not recompute canonical outputs. |
| E4 | `bootstrapMigrationReserve` mints only the reserve self-leg and requires donated inventory, `AllocationTarget.sol:305-367`. Genesis hermetic tests are in the passing log. |
| E5 | Reward delivery I read is activation-gated or deferred, `StakedDETFTarget.sol:354-368` and `:410-411`. Egress hermetic tests passed. Not every exit alias was traced. |

### MIG-AC01-AC53

Same-evidence rows share one status. "Hermetic supplied" means the named current-checkout log included the relevant suite and the aggregate had zero failures. It does not mean I read that test.

| IDs | Status | Evidence |
| --- | --- | --- |
| MIG-AC01, MIG-AC03 | Implemented; hermetic supplied | Mint requires activation, `Policy.sol:125-127`. `MigrationSurface` and `MigrationAdministration` are in the passing log. |
| MIG-AC02 | Implemented; fork execution not rerun here | NFT surrender reverts before pull when inactive, `WeightedHookTarget.sol:266`. |
| MIG-AC04, MIG-AC37, MIG-AC52 | Implemented; hermetic supplied | Removable loaders and expected-book checks. Configuration suites are in the passing log. |
| MIG-AC05, MIG-AC15, MIG-AC46, MIG-AC47 | Implemented; hermetic supplied | Owner-only administration; owner included in package salt material via full `PkgArgs`, `DFPkg.sol:247-250`. |
| MIG-AC06, MIG-AC40, MIG-AC42 | Implemented; fork rollback tests located, not rerun here | One transaction funds every contribution bond; a revert undoes custody. |
| MIG-AC07, MIG-AC08, MIG-AC36, MIG-AC49 | Revised by section 1; implemented for weighted NFT | `MigrationLegacyNftLib.sol:32-40,67-74`. Rewards are not added to `Pr`. |
| MIG-AC09, MIG-AC11, MIG-AC18, MIG-AC23 | Implemented in code; source-bound fork evidence incomplete | Fourteen matrix rows. Binding defect below. |
| MIG-AC10, MIG-AC17, MIG-AC32, MIG-AC34, MIG-AC44, MIG-AC45 | Implemented; hermetic recovery supplied, fork recovery not rerun | Recovery selection is separate from bond principal. |
| MIG-AC12, MIG-AC48 | Ordinary hermetic regressions are inside the 28,641-pass log. Migration composition was read. Live selector census unverified. | |
| MIG-AC13, MIG-AC51 | Implemented | Independent and surrender records are separate. Two-original NFT credits are stored separately. |
| MIG-AC14, MIG-AC19, MIG-AC20, MIG-AC25, MIG-AC43 | Implemented; hermetic egress supplied | `BondNFTVaultTarget.sol:29-76`. |
| MIG-AC16 | Implemented; genesis hermetic supplied | Donation bootstrap, not personal credit. |
| MIG-AC21, MIG-AC22 | Revised by section 1.10; implemented | Full-original quote once; later surrender does not call the evaluator. |
| MIG-AC24 | Revised by section 1.10; implemented; hermetic supplied | Setter stores a new book and does not walk stored credit, `AllocationTarget.sol:45-56`. |
| MIG-AC26, MIG-AC27, MIG-AC28, MIG-AC29, MIG-AC30 | Implemented; hermetic surface supplied; live loupe unverified | `AllocationTarget.sol:267-303`. Repeat activation is the removed selector. No migration pause switch was found. |
| MIG-AC31 | Superseded as to the operator application. Native script functions exist. Current rehearsal receipt absent. | `Phase_08_Stage_01_MigrationExecution.s.sol:18-235`. |
| MIG-AC33 | Incomplete as target-chain selection | Hermetic `MigrationOperationGas.t.sol:10-14` ran. It does not record a Robinhood block-gas limit or a selected operational batch size. |
| MIG-AC35, MIG-AC39, MIG-AC50 | Revised by sections 1.3 and 1.4; implemented on the NFT path read | `WeightedHookTarget.sol:270-273`. |
| MIG-AC38 | Implemented; hermetic configuration supplied | Replacement overwrites configuration and does not call `_fundBond`. |
| MIG-AC41 | Implemented | Partial fungible selectors exist. Whole NFT consumption is in the path read. Fungible bodies were not each read. |
| MIG-AC53 | Implemented in the reward paths read; egress hermetic supplied | `StakedDETFTarget.sol:363-368`, `_release` at line 411. |

Section 8.1 examples are represented by named tests I located, including `test_threeUnitsPay333Then334Then334OnActualProxy` and `test_weightedNftThreeIssuesTwoIndependentlyFundedBondsOnOneSurrender`. Those fork tests were not rerun on this checkout. Unclaimed configuration does not call `_fundBond`. Fresh clocks come from `createMigrationPosition`.

## Review findings

### 1. Route and recovery indexes cite a different plan fingerprint

Severity: medium. Confidence: high that the cited fingerprint differs from the current file size and the coordinator-supplied hash. Evidence class: current document comparison. Not a failing test, and not a contract-logic defect.

Location: `docs/incidents/2026-09-16-dtf-recovery/migration/source-route-matrix.md:3` and `recovery-route-disposition.md:3`.

Both cite plan SHA-256 `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e` and 98213 bytes. The current plan file read here is 97559 bytes. The brief's coordinator-supplied hash is `affff781dfc522d96bba1c2fba28053ec5e7804f97c10504441445eaefef7949`. I did not compute either hash. Both indexes say the reference update reran no recovery checks.

Violated requirement: task 1 and F1 require source-route evidence bound to the governing plan. The brief requires evidence recency and source binding.

Impact: an executor can treat custody, unit and permanent-custody conclusions as closed against this plan when the index itself names different plan bytes. E-P permanent custody may still be a valid source conclusion; this finding does not reopen it as unsupported. It says the written closure is not bound to the plan under review.

Fix direction: rebind those two indexes to the current plan file, or add an explicit supersession note, without restoring withdrawn operator requirements and without inventing a rerun.

### 2. The live runbook executes a different checkout

Severity: low. Confidence: high. Evidence class: current document read.

Location: `docs/incidents/2026-09-16-dtf-recovery/migration/foundry-runbook.md:7-8`.

The runbook tells the operator to `cd` into `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`. This review's implementation target is the current checkout. The coordinator also reported that two retained scripts differ from the historical map.

Violated requirement: task 9's usage document is the execution entry for the retained scripts. It currently points at a tree that is not the reviewed implementation.

Impact: a later `forge script` or `forge test` from the runbook can validate a stale tree and be mistaken for current-checkout execution.

Fix direction: point the command root at this repository, and state that the conformance worktree is historical evidence.

No other defect is filed. In particular, the removed application, the lack of holder-ancestry proof, the manual pricing setter, and the lack of a live production reserve composition are superseded by sections 1 and the November 15 correction.

## Limits

- A source review cannot prove the absence of bugs. Fungible surrender bodies, SY redemption, recovery step decoding and ordinary hook math were not read line by line.
- I did not recompute the plan hash, the coordinator's 293/299 comparison, or any artifact hash.
- The November 16 hermetic pass is a supplied log. I did not run it. Fork suites are absent from that log.
- `verification.md` is November 13 operator-era evidence. It says completion was rejected and later gates were pending. It is not current completion and its withdrawn operator checks are not current defects.
- E-P permanent custody is accepted only as the written source disposition. I did not read the cited deployed bytecode.
- `apply_patch` was unavailable. This inline response is the original. No file was published.

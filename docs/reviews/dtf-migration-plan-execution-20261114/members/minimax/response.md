# Identity

- Run ID: `dtf-migration-plan-execution-20261114`
- Member label: `minimax`
- Profile: `review`
- Phase: `initial independent response`
- Requested role: `council-member`
- Requested model and reasoning: `minimax/MiniMax-M3`, admitted adaptive thinking, not a selectable depth
- Actual role, model, reasoning, task ID and session ID: not exposed
- Owned path: `docs/reviews/dtf-migration-plan-execution-20261114/members/minimax/response.md`
- Fresh or continued: fresh
- Peers read before submission: no
- Tools used: file reads, `git diff`/`git log`/`git ls-files` (read-only), `grep`, directory listings. No `forge`, no project test runner, no install, no deploy, no wallet operation, no Git write.

# Question and targets

Did the committed changes from `90ff0307a7a8e084aa073e02eff125e9c7973933` (`origin/main`) to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (`HEAD`) completely and correctly execute `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision `migration-detf-implementation-plan-r7-token-staking-migrated-exposure`, including sections 1-11 and the section 11 completion standard?

Required targets I worked from: that plan file, and the explicit diff `90ff0307a7a8e084aa073e02eff125e9c7973933..c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (24 commits, 241 files, 38,251 insertions, 175 deletions, no deletions). I confirmed the range with `git log --oneline` and `git diff --stat` and did not rely on the coordinator's file index or the filename presence index as findings.

I did not treat `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md` as a specification. Where the plan and the PRD could diverge, I applied plan section 1 (MIG-P01..MIG-P15 and sections 1.1-1.9) as the governing precedence.

# Evidence

## A. Plan text read in full

`docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (726 lines), read end to end. Sections 1, 1.1-1.9, 2, 3, 4, 4.1, 5, 5.1-5.6, 6, 6.1, 7 (all ten task entries plus the final verification wave F1-F4), 8, 8.1, 8.2, 9, 10 and 11 are the requirements I applied.

## B. Production migration tree read (new files under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`)

Read in full:

- `UniswapV4DetfMigrationRepo.sol` (94 lines) — lifecycle/snapshot/config storage, `_fundBond`.
- `UniswapV4DetfMigrationPolicy.sol` (128 lines) — shared policy: `_isMintingAllowedToken` gate on `activated`, `_realizeExpansionIfNeeded`/`_pendingExpansionDetf` empty-participation handling, `_admit`, `_requireIdleChildren`, budget/residual accounting.
- `UniswapV4DetfMigrationSnapshotLib.sol` (183 lines) — `capture`, `_route`, `_rated`, `evaluateOriginal`, `evaluateOriginals`.
- `UniswapV4DetfMigrationAllocationTarget.sol` (412 lines) — `captureMigrationSnapshot`, independent allocation/issuance, all entitlement loaders, `activateMigration`, `_administrationSelectors`, `bootstrapMigrationReserve`.
- `UniswapV4DetfMigrationClaimVaultAllocationTarget.sol` (318 lines) — NFT, held SE/LP, weighted liquid, earlier liquid, claim-vault, weighted-receipt and earlier-receipt loaders.
- `UniswapV4DetfMigrationTarget.sol` (394 lines) — retained reads, `donateMigrationCapital`, and the weighted-liquid, weighted-SY, DTF-custody-SE and NFT surrender paths.
- `UniswapV4DetfMigrationRecoveryTarget.sol` (470 lines) — held SE/LP, earlier-liquid, earlier-receipt, weighted-receipt and claim-vault surrender paths, plus `recoverMigrationNfts` staged recovery and `_donateRecovery`.
- `UniswapV4DetfMigrationDFPkg.sol` (395 lines) — package composition, `facetCuts`, `initAccount`, `postDeploy`, `calcSalt`, child validation.
- `UniswapV4DetfMigrationFacet.sol`, `UniswapV4DetfMigrationBondFacet.sol`, `UniswapV4DetfMigrationExchangeFacet.sol`, `UniswapV4DetfMigrationMaintenanceFacet.sol`, `UniswapV4DetfMigrationQueryFacet.sol`, `UniswapV4DetfMigrationAllocationFacet.sol`, `UniswapV4DetfMigrationClaimVaultAllocationFacet.sol`, `UniswapV4DetfMigrationRecoveryFacet.sol` — the deployed selector sets and the ordinary-route gates.
- `UniswapV4DetfMigration_Component_FactoryService.sol`, `UniswapV4DetfMigration_Pkg_FactoryService.sol` — CREATE3/registry deployment wiring.
- `bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` (120 lines) — `createMigrationPosition`, cliff `_calculateClaim`, `_requireActivated` on reward claims, `_deliverClaim`.
- `claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol` (538 lines) — Stage-1 reward gate, deferred fee/creator allocation, `_distributeRewards` override, `_requireActive` paths.
- `legacy/MigrationLegacyNftLib.sol` (79 lines) and `legacy/MigrationLegacyRecoveryLib.sol` (480 lines) — fixed source constants, measured custody/consumption, earlier-receipt interval inversion.
- `TestBase_UniswapV4DetfMigration.sol` (first 90 lines) — real registry deployment through production factories.

## C. Shared changed files read (diff hunks)

`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol`, `DETFFundedBondMetadata.sol`, `DETFNFTVaultDFPkg.sol`; `contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol`, `StakedDETFTarget.sol`; `contracts/vaults/detf/common/sy/DETFSYDFPkg.sol`, `DETFSYTarget.sol`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (full hunk set), `UniswapV4DetfDFPkg.sol` (hunk set), `UniswapV4DetfInitializationLib.sol` (new, full file).

## D. Crane and repository references read

`lib/crane/contracts/introspection/ERC2535/ERC2535Repo.sol` (`_removeFacet`), `lib/crane/contracts/proxies/MinimalDiamondCallBackProxyResolution.sol`, `lib/crane/contracts/proxies/MinimalDiamondCallBackProxy.sol`, `lib/crane/contracts/introspection/ERC2535/DiamondCutTarget.sol` (selector presence only), `contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol` (`_distribute`).

## E. Evidence artifacts and tree inspection

- `ls docs/incidents/2026-09-16-dtf-recovery/migration/` at HEAD: exactly two files, `operator-runbook.md` (76,583 bytes) and `quote-evidence.md` (18,995 bytes).
- `find . -name 'verification.md'` over the repository (excluding `node_modules` and `.git`): no match.
- `ls pricing/evidence/implementation`: does not exist; there is no `pricing` directory in the repository.
- `git ls-files | grep -i receipt` and `find` for receipt artifacts under the incident tree: no fork-run receipt artifacts under `docs/incidents/2026-09-16-dtf-recovery/migration/`.
- `grep -rn 'vm.store|vm.etch|deployCodeTo|vm.mockCall'` over the migration contract tree and both migration test trees: no matches.

## F. Evidence artifact text read

`docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` (opening `DoneClaim` paragraph, line 6; evidence-path statement, line 8; supported-configuration and frozen-closure sections; mined-proof section).
`docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md` (head; `Conserved TokenStaking remainder`, line 121; `Separate NFT contribution bonds`, line 161; `Local rehearsal`, line 797, gas paragraph line 853; `Stage and evidence order`, line 859; `Interruption and recovery procedure`, line 886; `Required categories still blocked`, line 952; `Execution and recovery`, line 699; closing paragraph, line 1234).

## G. Test and script surface surveyed

Contract-name census over both migration test trees; `grep` for `surrenderMigration*` call sites in the fork tests; `function test` listing for `MigrationWeightedLiquid.t.sol`; `scripts/recovery/dtf-migration/cli.ts` help text; directory listing of `scripts/recovery/dtf-migration/`.

# Assumptions

1. `origin/main` is `90ff0307a7a8e084aa073e02eff125e9c7973933` and `HEAD` is `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, as the brief states. I verified the commit range with `git log --oneline 90ff0307..c33f7068` (24 commits) and `git diff --stat` (241 files, 38,251 insertions, 175 deletions) rather than assuming.
2. The working tree at HEAD is the review target; untracked incident inputs and local `.omo` files are outside scope and I did not treat them as evidence.
3. Plan section 1 overrides the r20 PRD wherever they conflict, per the brief and the plan's own precedence paragraph.
4. The plan's own completion law governs: section 7 Task 1 acceptance states that "unresolved rows prevent full implementation completion, not a silent scope reduction". I applied that rule literally.
5. Static reading is not a passing test run. I did not run `forge test`, `forge build`, `forge script`, the Bun script suites, or the fork suites. Every statement below about behavior is a statement about the source I read, not about observed runtime.
6. "Executed completely and correctly" means the section 11 sentence holds on every condition. I do not write that sentence.

# Coverage

## Section 11 completion-standard conditions

| # | Section 11 condition | Status | Basis |
| --- | --- | --- | --- |
| C1 | Full accepted migration behavior works through the real registry-deployed package | **Partially examined, not established** | The registry path and package composition are implemented and I read them (`UniswapV4DetfMigrationDFPkg.sol`, `UniswapV4DetfMigration_Pkg_FactoryService.sol`, `TestBase_UniswapV4DetfMigration.sol`). Not established as *working*: the runbook's own closing paragraph records "operational originals, opaque-origin reconciliation, other blocked sources, host portability, full hermetic/full-plan acceptance and target gas remain open", and no test or build run was observed by this council. |
| C2 | Every required legacy source is supported with configured original-wallet surrender/custody and source-claim conservation | **Examined; FAILED** | I read every surrender path and every legacy adapter constant. The code paths exist for weighted liquid, weighted SY, DTF-custody SE, NFT, held SE/LP, earlier liquid, earlier receipt, weighted receipt and claim vault. But `operator-runbook.md` line 952 onward ("Required categories still blocked") records an unclosed gate for every required category, including "TokenStaking raw weight", "Underlying SE shares", "Fungible LP" and "Earlier liquidation", and states that integration used synthetic allocation inputs with "approved operational allocations remain absent". |
| C3 | Missing configuration and wrong wallets revert atomically | **Examined; no defect found** | Every surrender path calls `preview*` (reverts when unconfigured) and then compares `msg.sender != config_.original.originalWallet` before any `safeTransferFrom`/`transferFrom`, before any consumption write and before `Repo._fundBond`. NFT path additionally requires `msg.sender == holder_`. |
| C4 | Agreed original credit is frozen and proportionally consumed without intermediate-holder history | **Examined; no defect found** | `UniswapV4DetfMigrationSnapshotLib.evaluateOriginal` reads only the captured `s.book`; `evaluateOriginals` sums the two components against the same book. Every fungible preview applies `Math.mulDiv(s_.remainingCredit, amount_, s_.remainingUnits)` with the whole-remainder branch; the NFT path applies `Math.mulDiv(originals_[i_].credit, remaining_, originalUnits_)`. No path re-runs a partial-input mint preview. No path reads transfer history. |
| C5 | Every surrender creates an exactly funded fresh cliff bond | **Examined; no defect found** | `Repo._fundBond` mints DETF to itself, approves the child and calls `createMigrationPosition(credit_, recipient_)`, which calls `_createFundedPosition(principal_, 90 days, recipient_)` and marks the token id as a migration position. The bond child's `_calculateClaim` zeroes vested principal before `startTimestamp + vestingDuration`. |
| C6 | Activation is structurally irreversible | **Examined; no defect found on the code surface read** | `activateMigration` builds one `Remove` cut per administration selector using `ERC2535Repo._layoutStruct().facetAddress[selector]` (the actual owning facet, not a zero-address recipe), and Crane's `_removeFacet` validates ownership, clears the mapping and removes the facet address. The union of the two removable facets' `facetFuncs()` (8 + 8) equals the 16 entries of `_administrationSelectors()`, so no administration selector is left installed. `ERC165Repo` Allocation flag is cleared and `activated` is set in the same transaction. I did not read the `sy/`, `sy/rewards/`, `invariant/` subtrees or every package/factory/callback surface, so I do not claim the *whole* restoration surface is closed. |
| C7 | The tests and resumable rehearsal demonstrate those facts | **Examined; FAILED** | `migration/verification.md` (plan Task 10 evidence) does not exist anywhere in the repository. `migration/source-manifest.json`, `migration/source-route-matrix.md`, `migration/surrender-spec.md` (plan Task 1 evidence) and `migration/package-evidence.md` (plan Task 3 evidence) do not exist. `migration/quote-evidence.md` exists but disclaims task 2 and E3 closure. No fork-run receipt artifacts exist under the incident `migration/` tree. This council ran no test, so no observed test result supports the condition either. |

## Diff coverage by file group (241 files)

| Group | Files | Coverage |
| --- | --- | --- |
| New migration contracts, core (repo, policy, snapshot lib, allocation target/facet, migration target/facet, recovery target/repo/facet, query/maintenance/exchange/bond facets, DFPkg, factories) | 24 | **Read in full** |
| New migration contracts, subtrees (`bondNft/` remainder, `claimToken/` remainder, `sy/`, `sy/rewards/`, `invariant/` handlers and TestBases, `interfaces/` remainder, `legacy/IMigration*.sol`, `TestBase_UniswapV4DetfMigrationSnapshot.sol`) | ~35 | **Partially examined.** File inventory and sizes read; `interfaces/IUniswapV4DetfMigration.sol` grepped by symbol and interface boundary; `interfaces/IUniswapV4DetfMigrationSnapshot.sol` and `interfaces/IUniswapV4DetfMigrationRecovery.sol` not read in full; `sy/`, `sy/rewards/`, `invariant/` and the remaining `bondNft/`/`claimToken/` files not read in full. **I did not read:** `UniswapV4DetfMigrationSYDFPkg.sol`, `UniswapV4DetfMigrationSYTarget.sol`, `UniswapV4DetfMigrationSYRepo.sol`, `UniswapV4DetfMigrationSYFacet.sol`, `IUniswapV4DetfMigrationSY.sol`, `IUniswapV4DetfMigrationSYDFPkg.sol`, all five `sy/rewards/*` files, `UniswapV4DetfMigrationBondNFTRepo.sol`, `UniswapV4DetfMigrationBondNFTVaultDFPkg.sol`, `UniswapV4DetfMigrationBondNFTVaultFacet.sol`, `UniswapV4DetfMigrationBondMetadataTarget.sol`, `UniswapV4DetfMigrationBondMetadataFacet.sol`, `IUniswapV4DetfMigrationBondNFTVault.sol`, `UniswapV4DetfMigrationStakedDETFRepo.sol`, `UniswapV4DetfMigrationStakedDETFFacet.sol`, `IUniswapV4DetfMigrationStakedDETF.sol`, all eight `invariant/*` handlers/ledgers/TestBases, `legacy/IMigrationLegacyNft.sol`, `legacy/IMigrationLegacyRecovery.sol`, `interfaces/IUniswapV4DetfMigrationDFPkg.sol`. |
| Shared changed files (detf common/package/target/init lib, bond NFT trio, claim token pair, SY pair) | 14 | **Partially examined.** Read: `UniswapV4DetfCommon.sol` (full hunk set), `UniswapV4DetfDFPkg.sol` (hunk set, initAccount extraction), `UniswapV4DetfInitializationLib.sol` (full), `DETFFundedBondTarget.sol`, `DETFFundedBondMetadata.sol`, `DETFNFTVaultDFPkg.sol`, `RebasingClaimTokenDFPkg.sol`, `StakedDETFTarget.sol`, `DETFSYDFPkg.sol`, `DETFSYTarget.sol`. **Not read:** the `UniswapV4DetfTarget.sol` hunk set (beyond what the migration facets call), and the `DETFFundedBondMetadata.sol`/`StakedDETFTarget.sol` hunks were read but their *callers* in the ordinary (non-migration) package were not re-verified end to end. |
| Shared changed files, hook and standard-exchange family | 8 | **Partially examined.** I read the new `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol` and `contracts/utils/StandardExchangeFrozenQuoteLib.sol` only through their use sites in `UniswapV4DetfMigrationSnapshotLib.sol` and `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`. **I did not read the diff hunks of:** `UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol`, `UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol`, `UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol`, `UniswapV4StandardExchangeWeightedBufferHookTarget.sol`, `facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol`, `interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol`, and I did not read `contracts/utils/StandardExchangeFrozenQuoteLib.sol` or `contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol` in full. |
| Shared changed files, V3 full-spread family | 3 | **Not read.** `UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol`, `UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol`, `UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol`. The plan requires ordinary packages to keep their specified behavior; I make no claim about these three files. |
| Operator scripts (TypeScript) | ~85 | **Partially examined.** Read the `cli.ts` help contract; listed the directory; did not read the individual stage modules, schemas, journal, bundle or rehearsal implementations. |
| Foundry operator scripts | 7 | **Not read.** `scripts/foundry/recovery/dtf-migration/*`. |
| Tests (spec + fork, migration tree) | ~65 | **Partially examined.** Read the contract-name census, the `MigrationSurface.t.sol` declaration test in part, the `MigrationWeightedLiquid.t.sol` test-function list, and the `surrenderMigration*` call-site census in the fork tests. I did not read any test body end to end. |
| Tests (modified) | 3 | **Not read.** `test/foundry/spec/.../UniswapV4Detf_Deploy.t.sol` and the two V3 full-spread test files. |
| Documents | 3 | Plan read in full; `operator-runbook.md` read in part (the sections cited above); `quote-evidence.md` read in part (the sections cited above); `MIGRATION_DETF_DRAFT_PRD.md` not read (optional context, and section 1 of the plan overrides it). |

**Unexamined condition statement.** Because the V3 full-spread hunks, the hook/standard-exchange family hunks, the `sy/` and `sy/rewards/` subtrees, the `invariant/` subtree, the remaining `bondNft/` and `claimToken/` files, the operator script modules, the Foundry operator scripts, and the test bodies were not read, I cannot assert that the ordinary-family behavior required by plan sections 4.1, 8 ("Ordinary regression") and 9 (MIG-AC12, MIG-AC48) is preserved, and I cannot assert that section 11 conditions C1, C6 and C7 hold. Those three conditions are stated below as blocking the "complete and correct" sentence.

# Conclusions

**No.** The committed range does not satisfy the plan's section 11 completion standard, and I do not write that the plan "was executed completely and correctly."

The diff is a substantial, internally coherent implementation of the plan's architecture, and on the surfaces I read the *mechanics* it implements match the plan's arithmetic, gating and removal rules closely. But the section 11 sentence is a conjunction, and it fails on at least two conditions that are decidable from the committed tree alone:

1. **C2 fails.** The repository's own operator artifact states that every required legacy source category still carries an unclosed gate, that the operational original-wallet allocations are absent, and that the integration was demonstrated with synthetic inputs. The plan's Task 1 acceptance makes that outcome fatal by construction: "unresolved rows prevent full implementation completion, not a silent scope reduction."
2. **C7 fails.** The plan-named evidence artifacts for Tasks 1, 3 and 10 do not exist, `migration/quote-evidence.md` disclaims task 2 and E3 closure and points at a `pricing/evidence/implementation/` tree that is not in this repository, and there is no committed record of build or test exit codes for a 38,251-line change. No test run was observed by this council.

Two further conditions are open on evidence the plan itself requires (target-feasible deployment gas in C1; the wider restoration surface in C6), and three conditions (C3, C4, C5) I examined and found no defect on.

My recommendation: do not treat this range as plan completion. The code work appears close to the plan's intent on the surfaces read; the gap is the plan's evidence and source-coverage obligations, which are the plan's own stated completion gate.

# Review findings

## F1. The repository's own operator runbook records every required source category as blocked, with operational originals absent

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/migration/operator-runbook.md`, section `### Required categories still blocked` (line 952) and the file's closing paragraph (line 1234). Both are in the diff and current at HEAD (`git log` on the file shows `c33f7068` as the last commit touching it).
- **Plan requirement:** section 3, "Source categories requiring explicit migration rows are: both DETF generations; both NFT models; sDETF/earlier receipts; SY; migrated TokenStaking/claim-vault rights; underlying SE shares; fungible LP tokens. An NFT LP lock and a fungible LP token are separate rows. A required source with no exposure must be proven absent from the approved dataset, not omitted by assumption." Section 7 Task 1 acceptance: "all required source rows have executable evidence or an explicit concrete blocker; unresolved rows prevent full implementation completion, not a silent scope reduction." Section 11: "every required legacy source is supported with configured original-wallet surrender/custody and source-claim conservation."
- **Observation:** the runbook's table lists ten categories with unclosed gates, including "TokenStaking raw weight | `reassign` debits caller, with no approved pull or recipient callback; ordinary Migration atomic surrender unsupported", "Underlying SE shares | Direct-user records/integration absent; earlier and weighted WETH SE disabled", "Fungible LP | Original records/integration absent; owner-restricted exits and earlier `UnsupportedRoute` remain", and "Earlier liquidation | SB-E1/E2/E3 disabled exits; SB-E4 unproved liquid conversion". It then states: "Synthetic originals, external liquidity and local funding are operational test data, not approved allocations. Full original task 9 and release remain open." The closing paragraph states: "The retained phase15 archive dependency, legacy source-match qualifications, operational originals, opaque-origin reconciliation, other blocked sources, host portability, full hermetic/full-plan acceptance and target gas remain open."
- **Impact:** the code paths for these categories exist and I read them, but the plan's completeness condition is not about the existence of a code path; it is about "every required legacy source is supported with configured original-wallet surrender/custody". The runbook states the *configured* originals are absent and that the demonstrations used synthetic originals. Section 11's C2 therefore does not hold, and by the plan's own Task 1 acceptance rule the unresolved rows prevent full implementation completion.
- **Fix direction (advice only; I did not apply it):** treat the blocked-category table as the release gate it is. Before claiming plan completion, either (a) produce the approved operational original-wallet records for each row and re-run the surrender/conservation demonstration against them, or (b) obtain an explicit owner decision that narrows scope, recorded as a new plan revision with its own section 1 precedence row. Do not close the rows by asserting the synthetic integration.
- **Evidence class:** committed implementation documentation (the plan's Task 9 evidence artifact), read at HEAD, cross-checked against the surrender code I read.

## F2. Five plan-named evidence artifacts are absent, including the verification record for sections 10 and 11

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/migration/` at HEAD contains exactly `operator-runbook.md` and `quote-evidence.md`. `find . -name 'verification.md'` over the repository returns no match. No fork-run receipt artifacts exist under the incident `migration/` tree.
- **Plan requirement:** section 7 Task 1 Evidence: "`migration/source-manifest.json`, `migration/source-route-matrix.md`, `migration/surrender-spec.md` and fork run receipts." Task 3 Evidence: "registry/proxy declarations, storage and source-of-supply reconciliation in `migration/package-evidence.md`." Task 10 Evidence: "commands, compiler version, source revision, exit codes, test summaries, gas bounds and unresolved pre-existing failures in `migration/verification.md`." Section 10: "The evidence report records exact commands, environment/compiler versions, exit status and behavioral results." Section 11: "the tests and resumable rehearsal demonstrate those facts."
- **Observation:** `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md` and `verification.md` do not exist. A missing plan-named artifact, after verifying absence in the tree, is a defect against the task that required it: the E1/E2/E3 route-closure and deployment evidence and the section 10/11 test record have no committed home.
- **Impact:** there is no auditable record of what was actually built, compiled and run for a 38,251-line change, and the E1/E2/E3 closure the plan makes a mandatory feasibility gate has no artifact. Section 11's C7 is unsatisfied on the tree alone, before any question of test execution.
- **Fix direction (advice only):** generate the five named artifacts from an actually authorized run — `forge build --use solar`, the four section 10 test commands, the fork suite, and the script rehearsal — recording exact commands, compiler version, source revision, exit codes, test summaries and gas bounds in `migration/verification.md`, and materialize the source manifest, route matrix and surrender spec from the real E1/E2 closure rather than restating the code.
- **Evidence class:** repository tree inspection at HEAD plus plan text.

## F3. `migration/quote-evidence.md` disclaims task 2 and E3 closure and points to evidence outside the repository

- **Location read:** `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` line 6 and line 8.
- **Plan requirement:** section 7 Task 2 Evidence: "frozen input vectors and differential outputs in `migration/quote-evidence.md`; exact source-read inventory." Task 2 acceptance: "on identical pre-capture state, frozen calculation equals the canonical mint-branch result; live-state changes cannot alter it." Section 3 E3: "Implement a snapshot evaluator reproducing the mint branch and all amount-dependent nested quote inputs under the actual configured weighted reserve routes. Later changes to any live dependency must not affect it."
- **Observation:** the document's own `DoneClaim` states it "is not completion of task 2 for an unidentified recovery configuration, E3, the full Migration plan, or lifecycle integration." It further states "All evidence paths below are relative to `pricing/evidence/implementation/`", and that tree does not exist in this repository (`ls pricing` → no such directory). The evidence it cites was produced in a separate worktree, `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02`, against fixture addresses that the document itself describes as "local assets ... fixtures, not historical ETH/DTF records or pinned recovery assets."
- **Impact:** the plan's mandatory feasibility gate E3 and the Task 2 frozen-vector evidence are not demonstrated for the actual configured reserve and routes, and the vectors a reviewer would need are not in the reviewed repository. I read `UniswapV4DetfMigrationSnapshotLib.sol` and it does implement a frozen evaluator with no live fallback; what is missing is the plan-required proof and its vectors.
- **Fix direction (advice only):** re-run the frozen-evaluation differential against the committed `UniswapV4DetfMigrationSnapshotLib.sol` and the actual capture configuration, and rewrite `migration/quote-evidence.md` with the vectors and source-read inventory inside the repository, removing the disclaimer only when it is accurate.
- **Evidence class:** committed document read at HEAD, plus tree inspection of the referenced path.

## F4. The recorded parent-deployment gas exceeds the recorded target-chain limit, and the plan's gas benchmark step is unmet

- **Location read:** `operator-runbook.md` line 853 ("The independently verified original-wallet local parent deployment consumed **42,985,865 gas** ... exceeding the separately recorded historical `getMaxTxGasLimit()` value of **32,000,000**. The permissive local fork mined it; this does not establish that the same deployment can run publicly.") and the closing paragraph ("Prior parent deployment 44,353,454 gas exceeds 32 million; the new rehearsal's permissive node does not convert that finding into target acceptance.").
- **Plan requirement:** section 10: "Benchmark bounded loading, independent issuance and harvest batches at small and large population sizes; select operational batch limits from measured gas and target-chain limits, not the permissive hermetic gas setting." Section 7 Task 10 acceptance includes "gas bounds".
- **Observation:** the two recorded parent-deployment figures in the same artifact (42,985,865 and 44,353,454) exceed the recorded 32,000,000 limit, and the artifact itself declines to convert the local success into target acceptance.
- **Impact:** section 11's "the full accepted migration behavior works through the real registry-deployed package" is not demonstrated by a deployment the artifact says may not be deployable on the target chain. This is an open feasibility gate, not a code defect.
- **Fix direction (advice only):** treat deployment gas as a first-class gate — split the parent deployment into separately deployable units, or record a target-chain gas path with a measured bound, before an operational activation is sequenced. Keep the two figures reconciled in the runbook.
- **Evidence class:** committed implementation documentation.

## F5. The operator runbook's activation selector census is stale relative to the implementation at HEAD

- **Location read:** `operator-runbook.md` line 1179 ("Activation requires the genuine paid first owner bond and permanently removes all twelve administration selectors across the two removable facets"), and the same file's other per-phase counts at lines 545 ("all 14"), 985 ("all eleven"), 1076 and 1111. Implementation read: `UniswapV4DetfMigrationAllocationTarget.sol` line 282 (`selectors_ = new bytes4[](16);`) and its `_administrationSelectors()` body; `UniswapV4DetfMigrationAllocationFacet.sol` `facetFuncs()` (8 selectors); `UniswapV4DetfMigrationClaimVaultAllocationFacet.sol` `facetFuncs()` (8 selectors).
- **Plan requirement:** section 6.1 step 2: "Assemble the exact removable selector set from the deployed Migration administration facet definition." Section 7 Task 7 Evidence: "removed/retained selector census, loupe receipts and interface-support declarations." Section 7 Task 9 Evidence: "command help, input schemas, fixture outputs and resumable rehearsal report in `migration/operator-runbook.md`."
- **Observation:** the implementation removes sixteen administration selectors (8 + 8 across the two removable facets, matching the 16 entries of `_administrationSelectors()`). The runbook's last activation statement says twelve, and the file carries three further, mutually inconsistent counts. I verified independently that the union of the two removable facets' `facetFuncs()` is exactly the 16-selector removal set, so this is a stale-evidence defect in the plan's named operator artifact, not a gap in the cut.
- **Impact:** the plan's Task 7 census and Task 9 runbook disagree with the code. An operator or reviewer relying on the runbook would under-count the removed surface and would not see the four selectors added after the phase that wrote that sentence.
- **Fix direction (advice only):** regenerate the census in `migration/operator-runbook.md` from the deployed loupe after the final phase, listing all sixteen removed administration selectors and the retained set, and remove the superseded per-phase counts.
- **Evidence class:** implementation read plus committed document read.

## F6. No defect found on the Stage-1 gating, frozen-credit arithmetic, proportional consumption, cliff funding and wrong-wallet atomicity surfaces

This heading records surfaces I examined and found correct, so that the negative result is bounded and auditable rather than implied.

- **Location read:** `UniswapV4DetfMigrationBondFacet.sol` (`_entryBond`), `UniswapV4DetfMigrationExchangeFacet.sol` (`_entryExchangeIn`), `UniswapV4DetfMigrationQueryFacet.sol` (`_entryPreviewMint`), `UniswapV4DetfMigrationPolicy.sol` (`_isMintingAllowedToken`), `UniswapV4DetfMigrationAllocationTarget.sol` (`activateMigration`), `UniswapV4DetfMigrationTarget.sol` and `UniswapV4DetfMigrationRecoveryTarget.sol` (all surrender paths), `UniswapV4DetfMigrationSnapshotLib.sol`, `legacy/MigrationLegacyNftLib.sol`, `bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol`, `claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol`.
- **Plan requirement checked:** MIG-P01, MIG-P02, MIG-P03, MIG-P05, MIG-P06, MIG-P07, MIG-P08, MIG-P11, MIG-P12, MIG-P13, MIG-P15; sections 1.3, 1.4, 1.5, 1.7, 4.1, 5.2, 5.3, 5.4, 5.5, 6.1.
- **Observation:** Stage 1 ordinary new money is closed at three independent points (minting tokens gated on `activated`; `exchangeIn` rejects non-DETF/non-receipt inputs pre-activation; `previewMint` returns `(0,0)` pre-activation). The owner-first bond is genuinely privileged: `MultiStepOwnableRepo._onlyOwner()`, a single-purchase guard (`ownerFirstBondTokenId != 0` reverts), `pretransferred_` rejected, and the token id published only after the inherited path returns. `activateMigration` reverts with `MigrationOwnerFirstBondRequired` when that id is zero, so independent compensation alone cannot unlock activation. Credit is quoted once from the frozen book and consumed proportionally by `Math.mulDiv` in every fungible and NFT path, with the whole-remainder branch paying the residue. Section 1.7's two-original NFT case is implemented as two separately quoted contributions and two separately funded bonds from one custody/consumption record. Wrong-wallet and unconfigured calls revert before custody, consumption, supply change or bond creation. The shared-file hunks I read are narrow `virtual` extension points plus a `_residualBalance` hook, and `UniswapV4DetfInitializationLib` lifts the ordinary `initAccount` body without altering it; the migration metadata changes are gated on `migrationCliff` / `migrationPresentation` flags that ordinary positions leave false.
- **Impact:** no defect found on these surfaces. This is a source-reading result; no test was executed, and the `sy/`, `sy/rewards/` and `invariant/` subtrees that carry part of the Stage-1 reward-gate surface were not read in full (see Coverage), so the absence of a defect is asserted only for the surfaces named above.
- **Evidence class:** implementation source read at HEAD.

# Limits

1. **This is a static review.** No `forge build`, `forge test`, `forge script`, Bun script test, or fork suite was run. No statement here asserts an observed runtime result. The plan's section 10 commands and section 11's "the tests and resumable rehearsal demonstrate those facts" cannot be satisfied by reading source.
2. **Coverage is partial and bounded.** I read the plan in full, the core migration contracts in full, the migration activation and surrender paths in full, the shared DETF hunks for the detf/bond/claim-token/SY families, and the two committed evidence artifacts in the parts cited. I did not read: the `sy/`, `sy/rewards/`, `invariant/`, remaining `bondNft/`, remaining `claimToken/` and remaining `interfaces/` migration subtrees; the shared hook and standard-exchange family hunks; the V3 full-spread shared hunks; the operator script modules; the Foundry operator scripts; any test body end to end; the three modified test files; the draft PRD. Every one of these is recorded in the Coverage table. The absence of a finding against an unread file is not evidence that the file is correct.
3. **The unexamined conditions block the positive sentence.** Because the V3 full-spread hunks, the hook/standard-exchange family hunks, the `sy/` and `sy/rewards/` subtrees, the `invariant/` subtree and the test bodies were not read, and because no test or build was observed, section 11 conditions **C1** (full accepted behavior through the real registry-deployed package), **C6** (activation structurally irreversible across the whole restoration surface) and **C7** (tests and resumable rehearsal demonstrate those facts) are stated as blocking the sentence "the plan was executed completely and correctly". C2 and C7 are in addition failed on the committed tree itself, independently of this council's coverage.
4. **Absence findings are tree-verified, not inferred.** F2 rests on `ls` of the incident `migration/` directory and a repository-wide `find` for `verification.md`, both at HEAD. F3 rests on the absence of a `pricing` directory in the repository.
5. **The plan's own checkbox state is not used as evidence.** The plan's task checkboxes are unchecked; I did not treat that, commit subjects ("verified", "complete"), or test names as execution proof. Where the runbook asserts a completed rehearsal, I treated it as a documentation claim and checked whether the committed tree contradicts it (it does, in F1 and F4).
6. **No peer files were read** and no peer response, feedback, draft or resolution was consulted. No sub-agent or second council was launched.
7. **This response does not authorize implementation.** It records findings, coverage and limits only. Any remediation, re-run, or scope decision requires separate authorization, and the owner decisions that F1 and F4 turn on are not mine to make.

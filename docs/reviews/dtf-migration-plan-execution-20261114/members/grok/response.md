# grok initial response

## Identity

- Run ID: dtf-migration-plan-execution-20261114
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: `docs/reviews/dtf-migration-plan-execution-20261114/members/grok/response.md`
- Requested role: council-member
- Requested model and reasoning: `xai/grok-4.7:high`
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Task ID: not exposed
- Session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

This response does not authorize implementation and does not replace the plan.

## Question and targets

Question: Did the committed changes from `90ff0307a7a8e084aa073e02eff125e9c7973933` (`origin/main`) to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3` (`HEAD`) completely and correctly execute `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision `migration-detf-implementation-plan-r7-token-staking-migrated-exposure`, including sections 1-11 and the section 11 completion standard?

Targets used: that plan, and the named commit range. The 241-file index and the filename presence index were re-checked for the rows cited below. They are not findings and not authority. The r20 PRD was not used to add requirements. Section 1 of the plan governs where it differs from r20.

Answer: no. The range does not completely and correctly execute the plan. Section 11 is not met on the conditions examined. Unexamined conditions also block that sentence. Static reading is not a test pass. This council did not run section 10.

## Evidence

Plan revision and status were read from the plan header and sections 1, 1.1-1.9, 2, 2.1, 3, 4, 4.1, 5, 5.1-5.6, 6, 6.1, 7, 8, 8.1, 8.2, 9, 10, the final verification wave, and 11. Tasks 1-10 and F1-F4 are still unchecked. That checkbox state was re-read. It is not, by itself, the section 11 standard. Commit subjects were not treated as execution proof.

`git diff --numstat 90ff0307a7a8e084aa073e02eff125e9c7973933..c33f70683cbaabfedc2dbce1142fdd65660d4cf3` was 241 files, 38251 insertions, 175 deletions. `git log --oneline` for that range was 24 commits. No deleted files were in the name-only index. Those counts were re-derived, not taken from the index as authority.

Incident `migration/` listing, re-read from the working tree and from `git ls-files` under `docs/incidents/2026-09-16-dtf-recovery`: only `quote-evidence.md` and `operator-runbook.md`. Repo-wide `git ls-files` for the plan's evidence basenames found no `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md`, or `verification.md`. `source-manifest.json` hits were only unrelated audit trees, not `docs/incidents/2026-09-16-dtf-recovery/migration/source-manifest.json`. No path in the required diff matched a fork-run receipt or `broadcast/` artifact. Paths containing "receipt" are collector scripts and receipt-surrender tests, not task 1 fork-run receipts.

`TestBase_UniswapV4DetfMigration_Adversarial.sol` is absent from `git ls-files` under the migration tree. Present test bases are `TestBase_UniswapV4DetfMigration.sol` and `TestBase_UniswapV4DetfMigrationSnapshot.sol`, plus invariant bases whose names are not the planned adversarial TestBase.

Exact QA filenames `MigrationFunding`, `MigrationBonds`, `MigrationRewardGates`, `MigrationSurrender`, `MigrationActivation`, `MigrationHarvest`, and `MigrationConfiguration` are absent. Differently named files exist, including `UniswapV4DetfMigrationSnapshot.t.sol`, `MigrationSurface.t.sol`, `MigrationLegacySources.t.sol`, several `Migration*Configuration.t.sol` files, and `MigrationRecovery*.t.sol`. Their names are not observed runs.

Surfaces read before the conclusion:

- `UniswapV4DetfMigrationTarget.sol` in full, including weighted-liquid, weighted-SY, DTF-custody-SE, and NFT surrender, the ERC-721 callback, and donation.
- `UniswapV4DetfMigrationPolicy.sol` in full.
- `UniswapV4DetfMigrationSnapshotLib.sol` in full.
- `UniswapV4DetfMigrationRepo.sol` in full, including `_fundBond`.
- `UniswapV4DetfMigrationAllocationTarget.sol` in full, including snapshot capture, independent configuration and issuance, claimed-SY configuration, and `activateMigration`.
- `UniswapV4DetfMigrationClaimVaultAllocationTarget.sol` in full, including both NFT configurators.
- `MigrationLegacyNftLib.sol` and `IMigrationLegacyNft.sol` in full.
- `UniswapV4DetfMigrationBondNFTVaultTarget.sol` in full.
- `UniswapV4DetfMigrationBondFacet.sol` in full.
- `UniswapV4DetfMigrationDFPkg.sol` through `facetCuts`, `initAccount`, `postDeploy`, and `_requireArgs`. The remainder of that file after the interface list was read through child validation.
- Allocation, claim-vault allocation, migration, and recovery facet `facetFuncs` lists in full.
- `IUniswapV4DetfMigrationRecovery.sol` in full.
- `UniswapV4DetfMigrationRecoveryTarget.sol` through held-SE/LP surrender, `recoverMigrationNfts`, claim-vault surrender, and `_donateRecovery`.
- `MigrationLegacyRecoveryLib.sol` through weighted claim, SY/SE/claim-vault redemption, unstake, and the start of conversion. Later conversion and earlier-sale bodies were not read line by line.
- `UniswapV4DetfMigrationStakedDETFTarget.sol` through reward distribution, deferred release, and the activation gate.
- Ordinary `_pairEq`, `_quoteMintGross`, `_openingBondQuote`, `_entryBond`, `_splitLiveGross`, and `applyTradingFeeNet`.
- ERC-2535 `_processFacetCut` and `_removeFacet`.
- Shared diffs for the bond target, bond metadata, staked target, SY target, DETF target, DETF common residual/sweep, weighted claim lib, V3 full-spread query/package/facet, NFT vault package, and SY package. Ordinary SY facet `facetInterfaces` was read and is a subset of the package's original six IDs.
- `quote-evidence.md` through the mined-proof table. It states that the bounded direct-pair increment is not completion of task 2, E3, or the full plan.
- `operator-runbook.md` through the routine harvest and permanent-custody paragraphs. Later runbook sections were not read in full.
- `scripts/recovery/dtf-migration/claimed-sy.ts` through `validateClaimedSyInputs`. It distinguishes `complete-original-token-staking` and `complete-remaining-token-staking` and requires measured SY coverage of eligible weight. The rest of that script and the other preparation scripts were not read.

Activation path read: `activateMigration` requires the current owner, Stage 1, idle children, and `ownerFirstBondTokenId != 0`. It builds one Remove cut per administration selector using `ERC2535Repo` `facetAddress[selector]`, reverts if that address is zero, then calls `_processFacetCuts`. Crane `_processFacetCut` skips a zero facet address; the migration code does not rely on that skip. `_removeFacet` reverts on an unset selector and on `SelectorFacetMismatch` when the cut's facet is not the owner. The sixteen selectors in `_administrationSelectors` match the eight allocation-facet functions plus the eight claim-vault-allocation-facet functions. `IUniswapV4DetfMigrationAllocation` support is cleared and `activated` is set in the same function. That does not prove every factory or callback route is unable to restore a cut. `updatePkg` requires empty code. `initAccount` reverts if `weth` is already set. `postDeploy` reverts if the reward token is already set. The generic factory cut path was not read.

Surrender path read: each fungible surrender read reverts `MigrationSurrenderClosed` before transfer when `activated` is false, checks the recorded original wallet, measures wallet and custody deltas, then applies section 5.4 remaining-Q/remaining-C arithmetic with `Math.mulDiv`, keeping residue until the final unit. NFT surrender checks activation, original wallet, and current holder before `safeTransferFrom`, then funds one bond per stored contribution. A single-contribution configuration stores one contribution. The separate configurator stores ETH and DTF credits separately and surrender funds both bonds in one transaction. `contributionCredits` reverts if a component credit floors to zero. Custody is inside the same call as bond funding, so a later revert undoes both only if the EVM reverts the transaction. That atomicity was not executed.

Owner-first bond path read: Stage 1 `bond` is current-owner only, rejects `pretransferred`, rejects a second purchase, and records `ownerFirstBondTokenId` only after `super._entryBond` returns. Inherited `_purchaseBond` reverts when the unboosted quote is zero. Inherited `_purchaseReserveLpBond` reverts when user DETF is zero. Activation rejects a zero recorded id. Independent issuance uses `createMigrationPosition`, not `bond`.

Cliff and reward path read: `createMigrationPosition` calls `_createFundedPosition` with `90 days` and sets `migrationPosition`. Ordinary `createFundedPosition` does not set that flag. Migration `_calculateClaim` sets vested principal to zero before `startTimestamp + vestingDuration` and to full remaining principal at or after that time. `_claim` rejects any `rewardClaim` before activation, including a zero computed reward. Fee and creator allocations are issued to the staking contract and deferred while inactive. `claimDeferredRewards` and `claimDeferredRoleRewards` require activation. SY `claimRewards` and `claimRewardRemainder` require activation. Ordinary metadata flags default false when unset. The migration metadata target is the caller that sets `migrationCliff`.

Quote path read: capture admits only direct contribution-to-pair routes. For a pair token, ordinary `_pairEq` returns the input amount, so the identity `pairEquivalent = amount` matches that admitted domain. Evaluation is pure over the stored book, applies seigniorage uplift, `applyTradingFeeNet`, captured V3 deposit evaluation when a buffer is enabled, weighted `exactInputBudget`, `rawOutput`, and `_splitLiveGross`. It does not call live `previewExchangeIn` during evaluation. The committed quote evidence says a local fixture matched a live oracle before mutations and diverged after live mutations. That file also says this is not E3 closure for an unidentified recovery configuration.

TokenStaking: the production migration tree has no raw-weight pull and no occurrence of `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00`. Comments say claim-vault shares are not TokenStaking weights. The claimed-SY script path read above is the preparation representation of section 1.8. Whether every still-held weight form is consolidated there was not read.

## Assumptions

- Weighted `principal` is the original fixed principal and `claimedPrincipal` is withdrawn principal, because the interface stores both and recovery uses the same equality check. That was not confirmed against deployed bytecode.
- A direct pair route makes `pairEq` an identity. Non-direct contribution routes fail capture. That is treated as an explicit unsupported domain, not as a silent substitute formula, only inside the routes capture admits.
- Earlier NFT token IDs below 3 may or may not be user positions. The plan's reserved-ID sentence is weighted-specific. No earlier position inventory was read.
- Unset metadata bools are false. Ordinary URI construction was not re-executed.
- Transaction revert undoes custody and bond minting together. That is an EVM assumption, not an observed run.
- The filename index was used only as a map. Every absence cited above was re-checked with `git ls-files` or a directory read.

## Coverage

| Surface | Examined | Result used |
| --- | --- | --- |
| Plan sections 1-11 | Read | Section 11 standard applied; checkboxes re-read and not used as the standard |
| Migration repo, policy, snapshot lib, package init/postDeploy | Read | Mechanisms present; package-evidence file absent |
| Allocation target and both allocation facets | Read | Sixteen administration selectors match installed facet functions |
| Migration target surrender and donation | Read | Stage 2 gate, wallet check, and 5.4 arithmetic present on the paths read |
| Recovery target surrender and `recoverMigrationNfts` | Read through donation | Reward-only stage is separately selectable; later lib bodies partial |
| Bond child, bond facet, staking reward gate, SY reward gate | Read | Cliff and Stage 1 payout gate present on the paths read |
| Legacy NFT lib and interfaces | Read | `tokenId < 3` applies to both collections |
| Legacy recovery lib | Partial | Read through unstake and conversion entry; did not read `sellEarlier`, `redeemWeightedLp`, or `redeemEarlierReceipt` bodies |
| Shared hook claim lib diff | Read | New zero-output revert on the live direct-pair path |
| Shared bond, staking, SY, DETF common/target diffs | Read | Extension points default to prior behavior on the hunks read |
| Shared V3 full-spread diff | Read | Additive frozen-quote view and interface id |
| Ordinary DFPkg versus `UniswapV4DetfInitializationLib` | Partial | Numstat only: 9 insertions, 88 deletions, 113 new lines. Line-by-line equivalence not read |
| Exchange, maintenance, and query facet bodies | Partial | Mint override line only. Selector bodies not read |
| Reward-token target and staking facet wiring | Not read | Blocks any claim that every payout route was enumerated |
| Factory cut restoration outside migration `updatePkg` / `initAccount` / `postDeploy` | Not read | Blocks a structural-irreversibility conclusion |
| Section 8, 8.1, 8.2, and 10 tests | Names only | Not executed. Bodies not read. Exact planned QA names mostly absent |
| Scripts other than `claimed-sy.ts` lines 1-60 | Not read | Blocks a task 9 completeness conclusion |
| `operator-runbook.md` after the harvest section | Not read | Blocks treating the runbook as a complete task 9 report |
| `quote-evidence.md` after the mined-proof table | Not read | The disclaimer already blocks E3 closure |
| Remaining diff hunks | Not read line by line | 241 files. Unread hunks are named in Limits |

Section 11 conditions:

| Condition | Examined | Holds |
| --- | --- | --- |
| Real registry-deployed package implements the accepted behavior | Package composition read; no deployment executed | Not shown |
| Every required legacy source has configured original-wallet surrender and conservation | Code paths read for the wired categories; source matrix absent | Not shown |
| Missing configuration and wrong wallet revert atomically | Revert-before-transfer read; not executed | Not shown as a run |
| Frozen original credit consumed proportionally without ancestry | Arithmetic read for admitted routes; E3 evidence disclaims closure | Not shown for the recovery book |
| Every surrender creates an exactly funded fresh cliff bond | `_fundBond` and 90-day marker read; not executed | Not shown as a run |
| Activation structurally irreversible | Owning-facet Remove read; factory restoration not read | Not shown |
| Tests and resumable rehearsal demonstrate those facts | Tests not run; `verification.md` absent | No |

Every unexamined row blocks the sentence "executed completely and correctly."

## Conclusions

The commit range did not completely and correctly execute the plan.

Examined code does implement several accepted mechanisms: Stage 1 rejection before custody, original-wallet checks, frozen proportional consumption on the surrender functions read, a separate two-contribution NFT issuance path, a 90-day migration cliff that ordinary purchases do not receive, activation removal of the installed administration selectors, an owner-paid first-bond prerequisite, Stage 1 reward deferral on the staking and SY paths read, and a separately selectable reward-harvest stage. Those observations are not section 11 completion.

Completion fails because the plan's named evidence artifacts are absent, the committed quote evidence disclaims E3 and task 2 closure, tests were not run and `verification.md` does not record them, and at least one shared ordinary quote path changed. Unread factory, script, test, and recovery-lib surfaces also block a complete-and-correct sentence.

Unchecked task boxes were re-read and are not the basis of this verdict. Commit subjects were not used.

## Review findings

### F1. Required task evidence artifacts are absent

- Location read: working-tree listing of `docs/incidents/2026-09-16-dtf-recovery/migration` and `git ls-files` for `source-manifest.json`, `source-route-matrix.md`, `surrender-spec.md`, `package-evidence.md`, and `verification.md`. The incident directory contains only `quote-evidence.md` and `operator-runbook.md`. The required diff has no `broadcast/` receipt and no file named `verification.md`.
- Plan requirement: task 1 evidence is `migration/source-manifest.json`, `migration/source-route-matrix.md`, `migration/surrender-spec.md`, and fork-run receipts. Task 3 evidence is `migration/package-evidence.md`. Task 10 evidence is `migration/verification.md` with commands, compiler version, revision, exits, summaries, gas bounds, and pre-existing failures. Section 11 requires the tests and rehearsal to demonstrate the facts. Section 3 E1 forbids marking a category supported without a concrete route record.
- Impact: source-route closure, package reconciliation, and the section 11 demonstration record are not in the committed tree. A later reader cannot tell which legacy category is supported, blocked, or permanently custodial from the named artifacts. Script collectors and test filenames do not replace those files.
- Fix direction: write the named evidence files from the execution that is actually being claimed, or change the plan's evidence names if different files are the intended record. Do not treat this review as that record.
- Evidence class: absence verified by directory read and `git ls-files`.

### F2. Committed quote evidence does not close E3

- Location read: `docs/incidents/2026-09-16-dtf-recovery/migration/quote-evidence.md` lines 1-8 and the mined-proof table through the frozen-versus-live user outputs.
- Plan requirement: task 2 and gate E3 require a snapshot evaluator for the actual reserve and routes, with frozen inputs and differential outputs in `migration/quote-evidence.md`, and equality with the canonical mint branch on identical pre-capture state. Large unsupported domains must fail explicitly rather than be omitted.
- Impact: the file says the bounded direct-pair / recognized V3-deposit / raw-DETF increment is not completion of task 2, E3, the full plan, or lifecycle integration. Its fixture pairs are not historical WETH, and it says no receipt model is admitted. The evaluator read in `UniswapV4DetfMigrationSnapshotLib` matches that bounded domain: non-direct routes revert at capture, and evaluation does not call live hook preview. That can be a correct limited implementation. It is not E3 closure for the recovery reserve.
- Fix direction: extend capture and the evidence file to the actual funded recovery routes, or record the concrete unsupported domain as an E3 blocker. Do not mark task 2 complete from the current disclaimer.
- Evidence class: document text read, plus the snapshot library read.

### F3. Planned adversarial TestBase is absent

- Location read: `git ls-files` under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration`. No path contains `TestBase_UniswapV4DetfMigration_Adversarial`.
- Plan requirement: section 4 names `TestBase_UniswapV4DetfMigration_Adversarial.sol` as a real registry-deployed Migration system beside `TestBase_UniswapV4DetfMigration.sol`. Section 8.2 requires the named adversarial catalog, with inapplicable cases stated, not weakened.
- Impact: the production-first adversarial base the plan named was not added. Other invariant bases exist. Their existence was not read as a substitute, and no test was run.
- Fix direction: add the named adversarial TestBase or record, in the plan's own evidence, which catalog cases that base was supposed to host and where those cases now live. Do not infer coverage from the file name of an unread invariant.
- Evidence class: absence verified by `git ls-files`.

### F4. Shared weighted quote now reverts on zero raw output

- Location read: diff of `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol` from `90ff0307a7a8e084aa073e02eff125e9c7973933` to `c33f70683cbaabfedc2dbce1142fdd65660d4cf3`, and current `rawOutput` at lines 156-160, called from `_outputBudget` for a leg with no standard exchange.
- Plan requirement: section 4.1 and task 5 require ordinary packages and ordinary Stage 2 bonds to retain their specified behavior. Task 2 says to factor quote math only where required for reuse. Task 10 requires ordinary weighted DETF regressions when shared code changes. The previous direct-pair branch assigned `Math.descale` and reverted only when the output was at least the raw reserve. It returned zero.
- Impact: `rawOutput` now reverts `Math.ZeroAmount` when descale is zero. Every ordinary caller of this shared library, not only Migration, now reverts on a direct-pair quote that previously returned zero. That is a behavior change outside the migration package. Whether a production quote hits that dust case was not executed.
- Fix direction: keep the factored helper for the frozen evaluator, and preserve the previous zero return on the live direct-pair path unless an ordinary-package requirement says zero output must revert. Record the ordinary regression the plan requires. Do not apply that edit here.
- Evidence class: static diff plus current source. Not a test run.

### F5. Earlier NFT surrender rejects token IDs below 3

- Location read: `MigrationLegacyNftLib.preview` lines 47-49 and `UniswapV4DetfMigrationClaimVaultAllocationTarget._configureNftEntitlements` line 32. Both apply `tokenId < 3` after `requireSource`, which admits both `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` and `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`.
- Plan requirement: section 2.1 says reserved IDs are not user purchases for the weighted NFT. It does not say that for the earlier CP NFT. Section 3 requires both NFT models as separate rows. Section 6 requires NFT surrender of a matching configured position, with burned or empty positions rejected by actual state, not by an unstated id floor.
- Impact: an earlier collection token whose id is 0, 1, or 2 cannot be configured or surrendered even if it has eligible shares and a matching wallet. If those ids are also reserved on the earlier source, the gate is harmless. That occupancy was not read, so two readers can treat the gate as either a faithful reserved-id rule or an extra rejection.
- Fix direction: apply the id floor only to the weighted collection unless earlier source evidence shows the same reserved ids. Put that evidence in the missing source matrix. Do not apply the edit here.
- Evidence class: static source. Earlier token-id occupancy not read.

### No other defect on the surrender arithmetic read

On the fungible surrender functions read, missing configuration reverts before transfer, the caller must be the stored original wallet, partial credit is `floor(remainingCredit * amount / remainingUnits)`, and the final unit takes remaining credit. NFT whole-identity consumption is stored after custody and before bond funding in the same call. Those observations are not a section 11 pass and do not cancel F1-F5.

## Limits

- No Forge command, test, install, deploy, wallet operation, or Git write was run. A passing test name was not treated as a run.
- Peer response files were not read.
- The ordinary DFPkg extraction into `UniswapV4DetfInitializationLib` was not compared line by line.
- `sellEarlier`, `redeemWeightedLp`, `redeemEarlierReceipt`, the reward-token target, exchange and maintenance facet bodies, and generic factory re-cut code were not read.
- Most of `operator-runbook.md`, the rest of `quote-evidence.md`, and all scripts except the claimed-SY validator prefix were not read.
- Test and invariant bodies were not read. Section 8.1 examples and section 8.2 invariants were not observed.
- The 241-file diff was not read hunk by hunk. Unread hunks include the script tree under `scripts/recovery/dtf-migration/` beyond the claimed-SY prefix, the Foundry script tree under `scripts/foundry/recovery/dtf-migration/`, the fork and spec test trees, and the migration invariant handlers.
- This review does not authorize implementation, deployment, funding, activation, or a plan edit.

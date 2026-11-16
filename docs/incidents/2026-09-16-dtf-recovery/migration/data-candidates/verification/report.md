# Phase27 independent verification

**Verdict: needs-fix.** The producer stopped at a genuine frozen-input binding failure before implementation. Its blocked handoff and exact two mismatches are independently confirmed; a functional phase27 candidate pipeline is not delivered or verified. This report completes the independent negative verification, not F1-03, Task9, the Migration plan, or operational approval.

Date: 2026-11-13. Subject: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-27-data-candidates`, branch `work/dtf-migration-phase-27-data-candidates`, actual HEAD `0856a5c56e5d09b81c669f59b613efef79133e19`.

## 1. Findings

### Blocking: the complete declared input set fails authentication

Location: primary checkout `docs/incidents/2026-09-16-dtf-recovery/manifest.json`, entries `LOSS_AND_RECOVERY_LEDGER.md` and `CUSTODY_AND_HARVEST.md`.

I independently resolved and hashed every declaration from the actual `sources.json` and `manifest.json`, including the pre-exploit sibling files. All 15 source declarations match; 19 of 21 manifest declarations match. That is 34 matches and two mismatches across 36 declarations and 27 unique paths. `sources.json` itself matches its manifest binding.

| Frozen relative path | Declared bytes | Actual bytes | Declared SHA-256 | Actual SHA-256 |
| --- | ---: | ---: | --- | --- |
| `LOSS_AND_RECOVERY_LEDGER.md` | 15308 | 15943 | `8564764d3d2140b25a9de361c49606c2e4d3d53cc404309ccc00bb955f572f07` | `52758ad2bbfa4efce31668ba1079aff608a8c72798280512e0247a0fb1747a71` |
| `CUSTODY_AND_HARVEST.md` | 7357 | 7920 | `0ddb0eb30523e26551dce653d3f3bfb2e439f7b0c83fe2c8c93aaf953d6f42cd` | `ab837ca952449a6d9ac155f5cd641329134ed92c0b9a610007ad7cd9b33698d8` |

These are declared Markdown bindings, not malformed economic CSV quantities. Their content was not parsed to explain the discrepancy. The complete-set authentication requirement in the brief and provenance section 9.1 fails regardless of whether the individual CSV bindings match. A successful partial subset cannot be represented as an intact complete frozen input tree.

Fix direction, not an edit or approval: supply an intact input tree satisfying the declared bindings, or obtain an explicit revised input-binding contract from the task owner. Neither excluding these entries, modifying the frozen manifest, fetching new data, recovering guessed older bytes, nor silently using the changed files is authorized here. No assertion is made about who changed them or why. `binding-audit.json` retains every independently computed expected/actual identity, not just the failures.

### Blocking to functional acceptance: no phase27 implementation or candidates exist

Location: `implementation/report.md`, its source manifest, and the actual candidate worktree.

Actual HEAD equals the requested parent. Both the full tracked diff against that parent and the staged diff are empty, ignoring submodules. Initial untracked membership consists of exactly the five producer evidence files. The operator source inventory contains 53 TypeScript files; none changed during verification. There is no new candidate command, versioned candidate schema, candidate derivation test or phase27 runbook edit. The complete actual `cli.ts` still dispatches the pre-existing bundle, prepare, validate, rehearsal and execution commands. Its independently executed `--help` exposes no historical-candidate command.

The producer explicitly reports `BLOCKED BEFORE IMPLEMENTATION`, empty source edits and empty candidate outputs. The observed repository agrees. Therefore there are no actual candidate documents or candidate unresolved records to reconcile. This is not a zero-exposure finding. The required candidate CLI, complete weighted/CP joins, inventory derivation, source/category coverage output, candidate rejection tests and repeat/relocation proof remain undelivered. Passing the existing baseline checks cannot replace any of those deliverables.

## 2. Actual stopped handoff and seal

I read the entire actual producer report, source manifest, manifest, binding audit and seal, including the audit's cleanup/limitations sections. I did not accept a status message as a completed implementation.

| Producer file | Bytes | Independently verified SHA-256 |
| --- | ---: | --- |
| `implementation/report.md` | 5795 | `61da0dfcfc164c81bc1ab45baec3b7df3e3b2c6f8ff2a85155e46d67f833fb59` |
| `implementation/source-manifest.json` | 3179 | `ef45e54769c7eb4bdf409e2263cb1926a236023e9f7503ed817bcfe9ecbeace6` |
| `implementation/binding-audit.json` | 13354 | `47828b37707de3e9f55c3d3d9d421d58d205d445d8299a769924d806974bd3e1` |
| `implementation/manifest.json` | 916 | `68ee43125e6ae034cf93a44773ddbacf4d3599e5557a2d2cd798fe217ad1eea1` |
| `implementation/seal.json` | 346 | `fe9d0e574ea654a1e8fc7ce565dd159c82115030b194c7b3198796b06c8a9dea` |

All three manifest file links and the seal-to-manifest link match actual bytes. All 12 producer source-manifest input identities still match. All 36 independently recomputed raw checks agree with the producer's expected/actual identities and pass/fail results. `producer-audit.json` preserves those comparisons.

This confirms a consistent blocked handoff, not implementation completion. The producer's `writtenLast` and zero-pending-operation fields are its assertions; hash closure alone does not independently prove write chronology or historical process absence. Its cleanup statement reports no temporary tree, process, monitor or subagent, and no such producer operation was adopted or started by this verifier. Original producer failures and its unrun-check statements remain unchanged.

## 3. Requirements and reading boundary

Read fully: the binding phase27 brief; current primary-checkout plan r5; current PRD r22; complete root `requirements-coverage-0856a5c5.md`; complete `ENTITLEMENT_LEDGER_PROVENANCE.md`; actual input declarations; and complete stopped producer handoff. The current plan's sections 1.1-1.5 override older bearer/full-credit and preactivation-surrender wording. The source identities of these documents are retained, not substituted with old worktree snapshots.

Read the repository router and assistant coding, deployment and testing rules, and the complete existing CLI/schema/preparation/provenance boundaries. Existing test fixture and relevant preparation/bundle boundaries were inspected, and the full operator suite was executed. This is not a claim to have independently audited all unchanged baseline runtime modules or every historical proof cited by F1.

**Raw-table reading and derivation stopped at the failed complete binding gate.** Exact bytes of every declared original were read for hashing, but raw CSV/snapshot/reconciliation records were not parsed or inspected row by row. No claim of a complete semantic frozen-source read, independently confirmed historical row count, join, quantity total or unit conversion is made. The root weighted observation JSON was not used as an oracle or approval source. I did not construct a replacement normalizer in verification/.

## 4. Required record-level work: explicitly unverified

`coverage.json` is a verification-disposition inventory, not a candidate dataset or loader file. Every item below remains blocked/not derived rather than sampled, assumed absent, or marked passing:

| Required work | Actual disposition |
| --- | --- |
| Weighted S006/S008/S011 chain + collection + token-ID join | No actual derivation exists. The brief's 43 purchases/43 unique transactions/43 mints and 41 pre-incident/2 post-incident are required expectations, not independently established results in this report. |
| Original recipient/payer, purchase/mint locators and transaction attribution | Unverified for every historical record. No transaction total was assigned to multiple NFTs/recipients. Unique direct-input attribution and ambiguity/conflict detection are not demonstrated. |
| Direct DTF/WETH, routed intermediate amounts, native input, refunds and net contribution | No exact quantities were derived. Inbound observations do not prove complete native/refund/net contribution history. Unknown cannot be replaced with zero. |
| Earlier CP 16 purchase observations | Required expectation only. No record-level confirmation or original receipt proof is claimed. LP-accounting shares stay distinct from physical LP; routed intermediate DTF must not be counted again. Missing original raw CP receipts remain unresolved. |
| Positions, accounts, held exclusions, custody, recoveries, conversions, exceptions, rounding and reconciliation | All declared file bindings checked; keys, source references, one-to-one joins, duplicate events, row coverage and supported totals not independently reconciled. No historical nominal exposure or obsolete loss formula was converted into compensation. |
| Original Q0 and source units | No current/snapshot balance was promoted to original Q0. Raw weights, gons, native9/native18/native19/native28, wrapper backing and LP-accounting units remain distinct. |
| Partial claims, earlier delivery, raw rights and controlled claimed descendants | Unresolved; no fabricated zero prior credit, full C0 per partial slice, reduced-contribution requote or new claim mechanism is approved. |
| Independent compensation versus asset surrender | No eligibility decision or allocation produced. Disjoint economic origin, original wallet review, aliases and competing representations remain unresolved. Grouped account observations do not establish a unique origin. |
| Historical current owner/control | Not refreshed. Current-owner observations at an old cutoff are not current control, nor authority for a transferee to use original-wallet compensation. |
| Source/category census | No independently derived positive or negative census. Every accepted category remains in `coverage.json`; an unobserved row is not proof of absence. |
| Repeated, different-CWD and relocated raw-tree output equality | Not run: there is no candidate implementation/output, and the complete input binding gate fails. Existing bundle relocation tests are synthetic baseline transport tests, not this historical derivation proof. |

The source inventory retains weighted/earlier liquid, both NFT models, weighted/earlier receipts, ordinary SY, TokenStaking, direct and indirect claim-vault rights, earlier SE, weighted WETH SE, weighted DTF-custody SE and both physical LP sources. ETH/WETH remain contribution/recovery provenance, not newly invented standalone compensated surrender routes.

The earlier receipt supply discrepancy, missing original inputs and wallet review, stale current state, incomplete WETH/native/recovery coverage, previous delivery, representation aliases and unobserved accepted categories all remain open. There is no complete intermediate-holder ancestry runtime prerequisite and no new eligibility or pricing policy.

## 5. Independent executed checks

Commands and individual exits are preserved in `commands.md`; final test screen and actual CLI output are separate evidence files. Executables observed: Bun 1.4.2 (`50a8a8387`), Node v26.11.1.

| Check | Observed result | Meaning |
| --- | --- | --- |
| Full worktree/parent and staged diffs | Exit 0, empty tracked/staged diffs | No phase27 source increment to audit |
| Strict types over `scripts/recovery/dtf-migration/*.ts` | Exit 0 | Existing operator sources type-check with strict, unchecked-index, exact-optional and verbatim-module flags |
| One complete `bun test --timeout 15000 ./scripts/recovery/dtf-migration/*.test.ts` | Exit 0; 109 pass, 0 fail, 11 files | Existing offline baseline; exactly one invocation, not candidate-specific coverage |
| Actual CLI `--help` | Exit 0 | Existing dispatch/help, not a new historical command |
| Actual CLI `prepare` on producer blocked manifest | Expected exit 1, `INPUT` | Literal version mismatch, missing required preparation fields and unrecognized blocked-evidence fields |
| Actual CLI `validate` on producer blocked manifest | Expected exit 1, `INPUT` | Literal prepared-manifest version mismatch and missing prepared fields |
| Before/after byte identity | All 33 original-input/manifest/producer paths and all 53 operator TS paths unchanged | Independent preservation check after offline commands |

The existing tests use synthetic loopback HTTP transport and saved warm ABI/source inputs. They are not RPC acquisition from the incident chain, a paid provider replay, an EVM proof or operational source authentication. No Forge, Anvil, historical fork, full Solidity suite, deployment or public action was run. No runtime source change justified or required such replay.

The candidate rejection requirement itself is **unverified because no candidate document exists**. The narrow actual rejection above proves only that the real stopped handoff manifest cannot enter the existing prepare/validate path. Source inspection shows strict preparation and prepared-envelope version boundaries before provenance/quote acquisition. No live loader records, configuration IDs, awards or approved flags were generated. No stage/execute/rehearse command, signer or provider acquisition was invoked.

Every required new boundary case remains missing: exact multi-input NFT attribution, ambiguous transaction sharing, CP direct/routed values, unknown versus observed zero, malformed raw quantities, missing/changed raw bindings, duplicate/link integrity, unit separation and rejection of an actual candidate document. Existing malformed-input and provenance tests are not relabeled phase27 tests.

## 6. Failures, cleanup and unchanged evidence

The producer's binding failures and all five original evidence files remain intact. Its incomplete F1 reading and unrun types/tests/derivation statements are preserved; this verifier's complete requirements read and baseline check run do not retroactively change that history.

Verifier lookup and display failures are recorded in `commands.md`: initial truncated read displays, a JSON parse of an elided read rendering, an incorrect testing-rule filename, missing evidence paths and an inspector-truncated test-log display. None caused a source/input mutation, substituted historical data or discarded test failure. The corrected independent byte audit retained both real mismatches. The test suite was not repeated to replace a truncated display. `operator-final-screen.txt` is explicitly a final screen, not an invented complete raw log.

JSON editor diagnostics could not run because Biome is not installed. No dependency/configuration change or installation was attempted. Evidence JSON is machine-parseable, and source checks are the completed command-line strict types and tests, not an editor-clean claim.

All writes are owned verification artifacts. No source, runbook, frozen input, old evidence, plan, PRD, F1, Git index or ref was written. `unchanged-inputs.json` records exact before/after identities. Final repository state and cleanup are recorded in `cleanup.json`; no verifier candidate/relocation data tree was created. Rejected preparation created no output directory. Test fixtures close their loopback servers and remove their own temporary data; no broad temporary-directory deletion was used.

The five owned command sessions (three finite read-only Git sessions and two finite monitored offline checks) completed with wrapper exit 0. The two expected loader child exits of 1 remain preserved. No owned operation, monitor, subagent, server, chain process or checkpoint remains pending. Cleanup does not claim authority over unrelated shared services.

## 7. Preserved limits and final seal

Nothing here closes E-S, broader TokenStaking claim conservation, disabled conversions, approved operational datasets, selected real reserve composition or the retained `45,116,678 > 32,000,000` gas deployment constraint.

P1 remains historical raw preservation, not a current behavior defect or a reason to replay passing current checks. The F1-specified unavailable first-producer versions remain:

| Historical raw artifact | Required bytes | Required SHA-256 |
| --- | ---: | --- |
| `out/TestBase_UniswapV4DetfMigrationSnapshot.sol/MigrationSnapshotConsumer.json` | 466441 | `e7e44f1c9dd1feae73302f69cc50182b084c3e156ff63108f9e1206f52b201bf` |
| `out/MigrationNativeHandler.sol/MigrationNativeHandler.json` | 266621 | `3628e086cdf17079f06aa157c414326519ba5de6d7a60df05e7deaa59e91d013` |

Those are preserved requirement identities, not newly located files. No search, reconstruction or substitution of their missing bytes occurred.

`manifest.json` binds this complete report, independent source/binding/producer/unchanged-input audits, required-work dispositions, command/exit record, actual retained outputs and final cleanup. `seal.json` is written last after command completion and cleanup, binding that manifest. The seal records `needs-fix`, failed full-input authentication and absent implementation. It must not be read as candidate acceptance, operational loader approval, full-plan completion, or authorization to commit, acquire source data, fund, deploy, configure, issue, activate or harvest.

**Stopped result:** the genuine blocked handoff is independently confirmed; the requested functional candidate increment needs fixing and is not verified. The negative verification report/evidence/seal is the complete deliverable of this lane, with the omitted functional checks stated explicitly rather than represented as passes.

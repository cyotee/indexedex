# Claim-vault EOF correction

Date: 2026-11-12. Status: root correction and validation complete; independent corrected-source review and follow-up commit pending.

## Exact change and original failure

Commit 9c227900b280713305d4a1a1d1cdc3d8d273f23d delivered the runtime-accepted40-file candidate but failed its staged/combined whitespace gate. The independent commit audit recorded needs-fix D1. That commit, audit, source snapshots and all previous seals remain unchanged.

Root removed exactly one final LF from each of nine added files. All other bytes are identical. source-delta.json records exact before/after hashes. All40 candidate paths were rebound: nine have only this one-byte change,31 remain byte-identical to prior independent acceptance. No statement, assertion, API, storage, fixture value or behavior changed; no new test was added for whitespace. Both the full original-parent4a53299b-to-current-tree whitespace gate and HEAD-to-current ignore-blank-lines check pass.

## Executed corrected-source checks

All six commands in commands.json completed with exit0 under monitor mon_421RFJBGZ9MVA9XE/bash_85. Artifact-first Solar builds preceded full suites and both operator stages.

| Check | Actual result |
| --- | --- |
| Complete current Migration specs | 130 passed,0 failed/skipped;22 suites |
| Complete pinned Migration forks | 81 passed,0 failed/skipped;16 suites |
| Both operator-stage builds | exit0 |
| Six operator test files, one run |64 passed,0 failed |
| Strict operator TypeScript |exit0, no diagnostics |
| Fresh fixed18566 CLI |bounded-rehearsal-complete, exit0;all three interrupted resumes |

All nine edited-file LSP error checks returned no diagnostics. Existing compiler warnings remain in logs. An initial monitor request with a four-hour timeout was rejected by tool validation before any command started; the same command then ran once under a persistent completion watch without a premature compile deadline. No failed product check was suppressed.

## Exact current bindings and actual receipts

Current source bindings are in final-source-bindings.json. artifact-reconciliation.json binds ten current artifacts and628 distinct compiled metadata source hashes, all matched to actual source. Eight raw artifact JSON hashes differ from the prior E1 set and are explicitly recorded; old raw hashes are not relabeled unchanged. All20 captured runtime byte arrays match their hashes. Five current artifact-to-actual-runtime comparisons match with only compiler-declared link/immutable spans masked and actual span bytes retained.

Fresh execution: runtime/rehearsal-1794451995939/. Root independently decoded each interrupted signed intent, checked signer, chain4663, nonce and hash, required completion absent before resume and successful mined status, and compared all15 canonical receipt fields including complete logs against the resumed journal. Results are in receipt-audit.json.

| Resume | Nonce | Actual hash |
| --- | ---: | --- |
| donation | 2123 | 0x5b17d1e14671ab202b71ae48b6ec5402f36588bcf1f107b37cea602beca44b02 |
| issuance | 2139 | 0x0a2f1e4bdd6d7a62ebec64feae5621e40e669f6d338fd86bd665ea92179ee7f6 |
| owner-bond | 2157 | 0xf5259aa029db69dc5ad451d7650994eef9fcdc3fa7694516d6572e5278871497 |

The actual parent deployment receipt is 0x164e3d434eb60cadf95d1e33baeb9b681fe482964e4fb05d29f8a2e8f448d533, gas 44099850. This remains above the retained historical32-million limit; no target-gas acceptance is claimed. Matching deterministic prior hashes are not copied execution evidence: this is the separately captured fresh root run.

## Cleanup and limits

Fresh CLI cleanup records owned PID67199 exited and checkpoint removal. Root independently checked no port18566 listener and no PID67199, confirmed checkpoint absence and removed only its empty owned parent. Final whitespace checks passed. All runtime commands and the validation monitor completed; source modifications are stopped.

No new commit, amend, merge, public action, held09 work, metadata retrieval, dependency/configuration change or test weakening occurred. Exact historical legacy source equivalence remains unproved; host-specific authority/Foundry paths and the retained phase15 W-SD archive dependency remain. Operational originals, other source categories, full hermetic/full-plan/portableF3 and target-gas acceptance remain open.

This is root validation, not an independent corrected-source verdict. Independent review and a separate follow-up formatting commit must close delivery; the old failed commit/audit are retained.

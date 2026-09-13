# Funded DETF release execution

Strict local execution exposed two production defects: CP/V3 zero-LP retry gas exhaustion (PR-09) and Orbital high-precision NAV intermediate overflow (PR-10). Both have scoped source fixes and seven new direct/constructive-fuzz regressions. Four Quad fee-LP cases now explicitly fund the existing growth-fee precondition without weakening assertions.

Current source/config SHA: `ef447bba96c7914b47a84f95ccd6b9ecbae984cc92a464b64479955cc3148f71`. The complete normal build, targeted regressions and unfiltered hermetic suite require renewal. No Solidity edits while this sequence runs. Earlier 31,305 hermetic, 27 security, 35 pinned fork and 410 frontend passes remain historical evidence; unaffected evidence may be reused only with matching source closures. The original 39-case local run remains 33 passed / 6 failed / 0 skipped.

P1/P2/P3 and affected P5 deployment evidence are reopened. Preserve nodes 18663/18664, protected local core, all 156 old receipts and warm caches. Updated immutable production packages need fresh local addresses and verification. Funding quote and final acceptance remain pending. Exact candidate is NOT READY. D60/D66 exclusions remain. No public deployment or fund migration.

Fresh final-candidate rehearsal preparation (2026-09-11 UTC): local node `http://127.0.0.1:18665` passed configured chain/pin/Prague/32M-gas/24,576-byte preflight. Previous 18663 node and receipts remain historical, and 18664 remains reserved for the full isolated funding simulation. The sequential `post-build-release-lifecycle-fixed/run.json` coordinator waits for the matching complete build/regression/full-hermetic sequence before any new Forge command. All 5,365 task-start files remain present; only 15 explicitly reviewed files changed. Seven tests were added and all 39 lifecycle declarations remain. These source/preflight checks do not mark runtime validation complete.


### PR-09 nested zero-amount follow-up — 2026-09-11T09:31:51.601696+00:00

The complete candidate build passed in 9,253.252 seconds. Its seven new regressions returned five passes / two failures / zero skips: all four Orbital cases passed, but the CP/V3 direct remainder and one constructive fuzz input still exhausted the 30M call bound through repeated `UniswapV3Exchange_ZeroAmount()` errors. The failed trace and source snapshot are preserved under `production-readiness/before-nested-zero-error-fix/`. Exact native V3/V4 zero-amount errors now terminate residual retries; all tests, amounts and gas bounds remain unchanged. Current source/config SHA is `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe`. The renewed complete sequence is `current-repository-production-readiness-nested-zero-sequence.json` (session 58257). Old sessions 45836/6831 exited with review-required status; no deployment occurred on fresh node 18665. Release acceptance remains open.

### 2026-09-11T11:56:15.840718+00:00 — current build and seven regressions passed

Candidate `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe`: complete production/test/maintained-script build passed in 8,552.311 seconds. All seven PR-09/10 regressions passed with unchanged assertions and gas bounds; CP fuzz includes the retained failing replay. Session 58257 continues through the existing 27 regressions and unfiltered full suite. Session 4270 remains dependent on completed P3; fresh local deployment and final acceptance are still pending.

### 2026-09-11T12:10:08.211830+00:00 — current complete validation passed

Session 58257 exited 0: complete build, seven PR-09/10 regressions, 27 existing security/boundary cases, and 31,312 unfiltered tests across 2,696 suites all passed; zero failed/skipped tests. Forty applicable acceptance rows resolve to passing named cases. Source/config remains `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe`. Session 4270 continues through package/caller reconciliation and fresh strict local release validation. Acceptance is still incomplete.

# DETF production readiness — remaining implementation plan

**Written:** 2026-09-10  
**Starting status:** The owner reports that all tests now pass. Test-failure remediation is complete on that basis. Release verification and acceptance reconciliation remain.  
**Parent requirements:** [DETF alignment PRD](./DETF_ALIGNMENT_PRD.md), D32–D66 and A1–A42; [funded staking implementation plan](./DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md).

This is the current remaining-work plan following the owner's passing test run. It supersedes older statements that the reported failures still need remediation. Historical logs and completion records remain evidence of their respective source snapshots. Writing this plan does not execute its commands or authorize public deployment.

## Final execution record — 2026-09-11 UTC

The exact candidate has passed all required implementation and validation work. Local source/configuration SHA: `187b03242b92380b8696be84a5d3f55a74ba4a140012b67820a4bee70cd7b2fe`; Crane source/configuration SHA: `b45a057611f782040ee29f1fddbbcc8eeba01def2c9341ef01c6bb65f685e123`. The dirty Crane authorization patch is part of this candidate. Git HEAD alone does not identify it.

| Required evidence | Final result | Record under `implementation-artifacts/detf-funded-staking/` |
| --- | --- | --- |
| Complete build, including all 294 maintained scripts | PASS; 8,552.311 seconds; Solc 0.8.35, optimizer 1, no viaIR | `implementation-full-build.json` |
| Full unfiltered default suite | **31,312 passed / 0 failed / 0 skipped; 2,696 suites**; 785.228 command seconds (762.11 Forge seconds) | `implementation-hermetic-test.json` |
| Security and direct dust regressions | 27 existing plus seven PR-09/10 cases passed; these overlap the full suite | `production-readiness/corrected-candidate-regressions.json`, `production-readiness/lifecycle-production-regressions.json` |
| Pinned external-provider and retained V3 forks | 27 + eight passed; reused only through 423 verified unchanged compiler dependencies | `production-readiness/provider-renewal-core-final/run.json`, `v3-retained-live-pool-production-readiness-run.json`, `production-readiness/lifecycle-fork-evidence-reuse.json` |
| Fresh strict local architecture | All 19 onchain stages and isolated export passed; 156 successful receipts | `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/architecture-run.json`, `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/receipt-manifest.json` |
| Strict local lifecycle | **39 passed / 0 failed / 0 skipped**; unchanged 30M money-path bounds; 661.434 seconds | `current-robinhood-rehearsal-production-readiness-lifecycle-fixed/lifecycle-run.json` |
| Final artifacts, payloads, storage and installed code | 138 components, 30 release packages, 20 actual local registrations, 135 receipt-bound CREATE3 inputs, 64 storage fields; all reconciled | `production-readiness/final-static-renewal.json` and its six linked records |
| Callers and presentation | 28 ABI declarations compatible; unchanged lint/typecheck and 410 tests / 59 files reused; eight matching SVG fixtures | `production-readiness/frontend-abi-reconciliation.json`, `production-readiness/frontend-check.json`, `production-readiness/renderer-evidence-reuse.json` |
| Acceptance and security | 40 applicable criteria complete; A33/D60 excluded; A42/D66 deferral verified; all ten findings resolved | `acceptance-progress.json`, `production-readiness/security-findings.json` |
| Complete isolated funding simulation | 156 transactions; 747,456,930 summed gas limits; 0.0817942118499 ETH quote / 0.102242764812375 ETH with 25% buffer | `current-robinhood-rehearsal-production-readiness-funding/funding-quote.json` |

The final local release uses `http://127.0.0.1:18665`, chain 4663, upstream pin 56,118,361, Prague rules, 24,576-byte runtime limits and 32M-gas blocks. The corrected core is `0xd41305e8ba283b1043e78f0cfc506557f2c69df1`. Actual transactions used 528,256,469 gas in total; the largest transaction gas limit was 12,038,566 and largest gas usage 8,917,457. All receipts, actual installed cuts, recursive library runtimes, constructor payloads and salt/address calculations reconcile to the candidate. Funding ran on separate node 18664 and preserved the completed architecture head. The quote finished at 2026-09-11T12:44:59Z and is a point-in-time simulation, not a future fee guarantee.

The vulnerable pinned public core `0xD7786b10BC8Bc97dc7651CAb7B97086c8b227882` is **ineligible for this release**. The source correction does not repair existing deployed bytecode. Application network/address bindings were preserved through isolated exports; the conditional new-browser-transaction gate was not triggered, and no new browser money-path pass is claimed.

Current acceptance is tied to the [final release manifest](../../../implementation-artifacts/detf-funded-staking/production-readiness/release-manifest.json). The [public deployment runbook](../../../implementation-artifacts/detf-funded-staking/production-readiness/PUBLIC_DEPLOYMENT_RUNBOOK.md) records future operator configuration, fee/salt/core checks and replacement procedures for immutable instances. Public deployment, customer activation, publication, migration and independent audit commissioning remain separate actions. This internal review is not an independent external audit.

## 1. Starting point and scope

| Work | Status / treatment |
| --- | --- |
| Reported test failures | Complete per the owner's latest report; record the passing run under P0. Do not carry historical failure counts forward as current failures. |
| Earlier targeted remediation | 4,255 selected tests passed; [record](../../../implementation-artifacts/detf-funded-staking/user-failure-remediation-753/VALIDATION.md). These overlap subsequent checks. |
| H9 fuzz follow-up | 60 tests passed across nine configurations, with 12,482 fuzz executions; [record](../../../implementation-artifacts/detf-funded-staking/user-failure-remediation-h9-fuzz/VALIDATION.md). This changed tests, not production redemption logic. |
| Production build and script coverage | Attach matching evidence where already available; build only missing or changed artifacts under P3. A passing test report alone does not identify the preceding build or maintained-script coverage. |
| Eight retained V3 fork cases | Complete: all eight passed at the required pins; original execution provenance retained. |
| Current-package local deployment and 39 rehearsal cases | Complete: fresh corrected candidate on node 18665, 19 stages / 156 successful receipts, all 39 cases passed. Superseded 33/39 run and production-defect traces remain archived. |
| Security review and final acceptance/manifests | Complete requirement review and ten resolved findings; exact machine-verifiable release manifest and operator handoff attached. |

Functional DETF scope is the unified V4 implementation bound to CP, Weighted, Orbital and Curve Quad reserve hooks, plus the SE/SY packages retained by the parent plan. **D60 excludes further functional refactoring of Balancer-hosted DETFs. D66 defers unfinished Slipstream work.** Preserve existing code, tests and historical evidence for those families. Balancer SE and V4 hook integrations remain distinct from excluded Balancer-hosted DETFs and stay in the required coverage.

The H9 observation must be recorded as an excluded-family limitation. It is a useful rounding regression reference, not authorization to reopen Balancer DETF development. Verify that excluded products are absent from the release deployment manifest. Deploying them would require a separate scope revision and readiness review.

## 2. Execution order

| ID | Deliverable | Dependency | Completion evidence |
| --- | --- | --- | --- |
| P0 | Record the passing baseline and correct stale task state | None | Source/run provenance and reconciled remaining queue |
| P1 | Review security-sensitive production paths and fix confirmed gaps | P0 | Findings with code dispositions and production-path regressions |
| P2 | Finish package, storage, selector and caller reconciliation | P0; incorporate P1 changes | Complete manifests and matching caller checks |
| P3 | Establish the final build/test artifact set | P1, P2 | Matching build, scripts and passing tests; no stale bytecode |
| P4 | Execute all retained V3 fork cases | P3 | Eight passing cases on pinned actual pools |
| P5 | Deploy and validate the strict local release rehearsal | P3, P4 | Current package receipts/code hashes and all 39 cases passing |
| P6 | Close the acceptance matrix and prepare deployment handoff | P0–P5 | Completed acceptance report and exact release manifest |

If a later step changes production code, deployment arguments or caller behavior, return to the affected earlier steps. Preserve earlier evidence and mark precisely which results require renewal. Documentation-only reconciliation does not trigger another full Solidity run.

## 3. P0 — Record the passing baseline

- [x] Record the owner's full-suite pass with explicit provenance. Preserve available command, profile, filters, pass/fail/skip counts, fuzz/invariant settings, timestamps and logs. Do not invent missing counts or represent the owner's run as agent-executed.
- [x] Identify the tested source snapshot: Git revision plus a manifest of dirty/untracked source changes, dependency revisions, compiler/configuration fingerprint and maintained-script inventory. Reuse [build_provenance.py](../../../implementation-artifacts/detf-funded-staking/build_provenance.py).
- [x] Match the passing tests to their preceding production build. FactoryServices load creation code from `out/` with `vm.getCode`; test compilation alone is insufficient after production changes.
- [x] Reconcile `execution-status.md`, `current-implementation-queue.json`, `acceptance-progress.json` and the parent validation report with the new result. Preserve older failures as history, with links to their resolutions.
- [x] Replace stale process references with actual evidence. In particular, `current-repository-funded-final-sequence.json` records `PROCESS_EXITED_WITHOUT_CAPTURED_COMPLETION`; do not rewrite that historical process as a successful run. Attach a new owner-run record instead.
- [x] Reuse matching completed provider forks, frontend checks and security cases. Identify only gaps or invalidated evidence for rerun.

**Exit:** the queue reflects the passing test report and a concrete release candidate. Missing provenance is labeled as such; it is not a newly asserted test failure. No blanket rerun is required merely to reconcile the records.

## 4. P1 — Production security review and concrete fixes

Review the actual common components and all four V4 bindings through deployed proxies. Use the parent plan's A1–A42 mapping to locate existing coverage before adding tests. Fix confirmed production defects in production code; changes to bounds or expectations alone do not close a production finding.

### P1.1 — Small amounts and zero-output redemption

Source anchors:

- [UniswapV4DetfTarget.sol](./protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol): `_burnHeld`, `_swapBurnPath`, `_exitBurnLp`, `_payBurnOut`.
- [UniswapV4DetfExchangeTarget.sol](./protocols/dexes/uniswap/v4/detf/UniswapV4DetfExchangeTarget.sol) and [UniswapV4DetfQueryTarget.sol](./protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryTarget.sol).
- Funded staking under `common/claimToken/`, bonds under `common/bondNft/`, and wrappers under `common/sy/`.

- [x] Trace positive input through DETF-to-owned-LP conversion and the final recipient asset conversion. The existing `lpOut_ == 0` guard does not by itself establish a nonzero final payout.
- [x] Exercise one native unit, the last amount quoting zero, the first payable amount, a partial exit and a full exit across relevant decimal/route bindings. Include primary and reserve-swap branches, composed unstake/redemption, and SY callers where supported.
- [x] Verify that a positive requested minimum prevents zero-output settlement and that a failed exit leaves user balances, token supply, reserve custody, staking liabilities and bond state unchanged.
- [x] Characterize `minAmountOut = 0` separately against the accepted route semantics. Record whether zero payout is deliberate, already rejected, or an unintended loss of user input. Resolve unintended input destruction with a production guard at the final output boundary, reusing existing error conventions and atomic reverts. Do not globally reject zero partial bond payouts that legitimately leave unvested principal intact.
- [x] Retain direct small-amount security regressions independently of the payable-domain conservation fuzz tests. Keep `bound()` for constructive fuzz inputs; do not add rejection loops, early returns or weaker assertions to hide edge cases.

**Exit:** every reviewed redemption path has an explicit rounding/minimum-output disposition, and any confirmed defect has a passing production regression. The excluded H9 behavior remains accurately documented rather than presented as a production fix.

### P1.2 — Funded accounting, authorization and external calls

- [x] Review held-DETF backing versus total sDETF/gons liabilities, isolated bond principal/rewards, allocation/rebase dust, unsolicited inventory and exact final exits.
- [x] Verify epoch settlement before participation changes, one aggregate catch-up, immediate issuance rewards, no duplicate distribution, and primary-gate/reserve-swap consistency between previews and execution.
- [x] Verify caller/recipient/approval checks, actual transfer deltas, hostile external callbacks, cross-instance storage isolation, and failed-operation atomicity. Existing inventory must not fund a second caller's claim.
- [x] Review protocol LP ownership versus external LP, complete LP-bond payment custody and non-DETF valuation, immutable liquidity permissions, and live Fee Collector rotation/redemption authorization.
- [x] Recheck the changed V4 residual-capital sweep and dust parking against real SE quotes: joinable residuals are processed, repeated unchanged balances terminate, and parked assets do not create an unfunded user entitlement.
- [x] Record each finding with affected deployed routes, severity, reproduction, disposition, changed source hashes and regression evidence. Close security-critical findings before release; explicitly record any remaining product limitation.

**Exit:** all in-scope review findings are resolved or have a concrete documented disposition consistent with product law. A test-only adjustment is identified as such. Do not describe this internal review as an independent external audit.

## 5. P2 — Final package and caller reconciliation

Reuse `current-source-manifest.json`, `current-se-package-inventory.json`, `current-funded-selector-manifest.json`, `v4-current-caller-migration.json` and existing storage/consolidation records under `implementation-artifacts/detf-funded-staking/`.

- [x] Enumerate every release package and dependency, its FactoryService, constructor/`PkgInit`/`PkgArgs` encoding, registry registration and deterministic deployment salt. Exclude D60/D66 deferred products from new release claims.
- [x] Reconcile interface signatures → targets → facet declarations → package cuts → deployed proxy selectors. Check duplicates, omissions, ERC-165 declarations, removed selectors and every supported standard replacement.
- [x] Finish field-by-field storage reader/writer and initializer dispositions. Preserve legacy interfaces genuinely required by excluded families; do not reinterpret their storage as new funded state.
- [x] Verify nine-decimal DETF/sDETF/SY boundaries, retained native SE/token decimals, supported route discovery and all required companion addresses.
- [x] Reconcile maintained launch scripts, generated ABIs, address exports and `frontend/apps/dtf` callers against the candidate. Verify token formatting, previews, minimum output, deadlines, approvals and bond/staking routes.
- [x] Run relevant caller checks when sources, ABIs or bindings changed. The active application declares `npm --prefix frontend/apps/dtf run check`; add its applicable live transaction tests against the local rehearsal when deployment bindings change. Reuse matching earlier lint/typecheck/unit/SVG evidence.
- [x] Reconcile retained/merged/retired tests with requirement coverage and compiled method counts. Report measured build/runtime effects without adding overlapping test totals or claiming unmeasured speedups.

**Exit:** each release package and supported caller has a complete, current manifest; no unresolved stale selector, payload or storage mapping remains.

## 6. P3 — Final build and validation provenance

- [x] Evaluate reuse of the owner's passing run and preserve its distinct provenance. Its build fingerprint was unavailable; the corrected candidate therefore has a separately recorded matching complete build and full hermetic pass, without relabeling the owner report as agent evidence.
- [x] If production code changed in P1/P2, run `forge build` before targeted tests; include maintained scripts in the complete build. After corrections stabilize, obtain one matching full hermetic result. If only evidence is missing, collect or run only the missing check.
- [x] Verify deployed runtime and creation artifacts against current sources and dependencies, especially components loaded indirectly by FactoryServices. Check every release component against the 24,576-byte runtime limit and verify library linking.
- [x] Record exact commands, exit codes, source/configuration fingerprints, test counts, skipped cases and timings. No required test may silently disappear through a changed filter.

The existing complete sequence, **only when a new complete run is needed**, is:

```sh
python3 implementation-artifacts/detf-funded-staking/run-current-repository-checks.py --label production-readiness-final
```

Use a fresh label if that record already exists. Preserve `out/` and `cache_forge/`; seed a new worktree from a warm checkout if one is needed. Keep the normal production/script roots, default hermetic profile, existing compiler settings and `via_ir = false`. Do not lower fuzz/invariant coverage, clear caches or interrupt long compiles.

**Exit:** the final release artifacts and accepted passing tests refer to the same source candidate, with maintained-script coverage recorded. This step does not supersede the owner's already-passing test result unless sources or required scope changed.

## 7. P4 — Retained V3 fork verification

Use [run-v3-retained-live-pool-forks.py](../../../implementation-artifacts/detf-funded-staking/run-v3-retained-live-pool-forks.py).

- [x] Inspect the runner's prepared-source hashes and sequence dependencies against P0/P3. It currently expects a finished full-run sequence and matching `implementation-full-build.json`. If those refer to the old interrupted run, update the evidence-loading path to the accepted current record while retaining completion and source-match checks; do not fabricate a successful old sequence or remove the guards.
- [x] Use the configured RPC credentials without writing them into evidence. Preserve the existing pins: Base block **45,446,736**, Robinhood block **56,118,361**.
- [x] Execute all eight retained cases: five in `UniswapV3StandardExchange_Fork_Test` and three in `UniswapV3StandardExchange_Robinhood_Test`.

```sh
python3 implementation-artifacts/detf-funded-staking/run-v3-retained-live-pool-forks.py --label production-readiness
```

- [x] Preserve coverage of actual pool bindings, full-range/import conversion, two-token activation, later single-token routes and locked-pool behavior. Use real factories, manager/registry deployments and providers.

**Exit:** eight cases executed and passed with matching current artifacts, pinned blocks and zero skipped required cases. RPC unavailability is a recorded incomplete check, not a pass. Existing successful unrelated provider forks need renewal only when their dependencies changed.

## 8. P5 — Strict local package deployment and lifecycle rehearsal

Use the maintained [launch wrapper](../../../scripts/shell/anvil_robinhood_main.sh) and [RobinhoodReleaseRehearsal.t.sol](../../../test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol).

- [x] Recheck the local node recorded under `current-robinhood-rehearsal/`; earlier readiness is historical. Required settings: loopback endpoint, chain **4663**, pinned upstream block **56,118,361**, runtime limit **24,576 bytes**, block gas limit **32,000,000**. Preserve the test's explicit transaction gas bounds. The final candidate uses fresh node 18665, verified in [strict-node-preflight.json](../../../implementation-artifacts/detf-funded-staking/current-robinhood-rehearsal-production-readiness-lifecycle-fixed/strict-node-preflight.json); preparation sent no deployment transactions. Earlier node 18663 and its superseded receipts remain preserved. Recheck liveness before the dependent deployment.
- [x] Preserve unrelated nodes, deployment manifests and prior receipts. If a node is needed, reuse the maintained pinned-node runner after checking its port and evidence-file guards. Never replace an occupied server or relax code-size limits to make deployment pass.
- [x] Deploy current release packages via FactoryServices and the manager registry into the local rehearsal. Verify existing core dependencies by code hash before reuse; reconcile stale core/facets in the local deployment if required. Record CREATE3/CREATE2 salt/address calculations, hook flags, constructor arguments, code hashes and successful receipts.
- [x] Run the complete existing 39-case matrix, including four V4 DETF bindings, V2/V3/V4/Morpho provider combinations, public-liquidity cases, Balancer SE hook cases and retained-inventory abuse coverage.

After P3 and local-node preflight, the existing shell entrypoints are:

```sh
bash scripts/shell/anvil_robinhood_main.sh rehearse-packages --rpc-url http://127.0.0.1:18665
bash scripts/shell/anvil_robinhood_main.sh rehearse-lifecycle --rpc-url http://127.0.0.1:18665
```

Set `REHEARSAL_DIR` consistently for both commands and retain the directory it records. The test consumes `REHEARSAL_RPC_URL` and `REHEARSAL_DEPLOYMENTS_DIR`; keep them aligned with the shell-generated manifests. Check existing deployment/salt state before rerunning a stage. These commands are for the isolated local fork only.

- [x] Verify actual funded bond purchase, vested/reward claims, stake/unstake, primary and fallback routes, SY conversion, LP custody, fee rotation and recipient balance deltas. Tie each deployed contract to P3 artifacts.
- [x] Preserve transaction gas measurements under strict limits and any required deployment funding estimate. A passing hermetic setup with a high gas allowance is not a replacement for this check.

**Exit:** current packages deploy successfully and all 39 cases pass under strict local limits. The compiled inventory must explain any legitimate count change; do not lower the expected count to conceal missing coverage.

## 9. P6 — Acceptance closure and deployment handoff

- [x] Close applicable A1–A42 rows against exact evidence, preserving D60 exclusions and D66 deferrals. Reconcile the parent plan's unchecked stages against actual implementation rather than rebuilding already-completed features.
- [x] Update [DETF_FUNDED_STAKING_AND_SY_VALIDATION_REPORT.md](./DETF_FUNDED_STAKING_AND_SY_VALIDATION_REPORT.md), the parent completion record and the artifact trackers. Replace stale active-run text; distinguish owner-reported checks, agent-executed checks and any independent review.
- [x] Produce one release manifest containing the final revision/dirty-source manifest, compiler/dependency settings, artifact hashes, package/facet addresses or predictions, salts, hook flags, registry wiring, creation parameters, fee/creator configuration, deployment order and local receipt references.
- [x] Attach security finding dispositions, fork/rehearsal logs, selector/storage/caller manifests, exact test counts and known limitations. State explicitly which products are excluded from the deployment candidate.
- [x] Prepare the concrete public deployment runbook and required operational configuration for the exact candidate. DETF instances are immutable; document how a defective or misconfigured instance would be superseded instead of assuming an upgrade or admin pause exists.

**Exit:** no in-scope implementation, security finding or required validation task remains unresolved; release documents match the tested artifacts. Public deployment, migration, publication and external audit commissioning remain separate actions, outside this plan's execution scope.

## 10. Evidence and completion rules

Store new evidence under `implementation-artifacts/detf-funded-staking/production-readiness/` or the existing runner's uniquely labeled output paths; link those paths from the final report. Do not overwrite historical failure logs or successful checkpoints.

Every task must end as **complete with evidence**, **excluded/deferred by an existing scope decision**, or **open with a precise reason and next action**. A checked box requires the task's exit criteria, not merely code written or a planned command. The owner-reported all-tests-pass milestone is preserved; only changes or missing required coverage justify repeating it.

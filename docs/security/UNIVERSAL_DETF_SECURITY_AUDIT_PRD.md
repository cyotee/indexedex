# Universal DETF security audit PRD

| Field | Value |
|-------|-------|
| Status | In progress v0.3 — owner authorized local fixes during review |
| Date | 2026-09-05 |
| Deliverable | Evidence-backed audit report, followed by owner review |
| Priority composition | Universal Uniswap V4 DETF + Single Standard Exchange Buffer Constant Product hook |
| Current workflow | Reproduce findings, apply focused local fixes, verify regressions, maintain audit report |

**Owner instruction update (2026-09-05):** After authorizing audit execution, the owner explicitly requested fixes to their code during the review. This supersedes the report-only/no-fix restrictions below and in the execution plan. Those paragraphs preserve the original process history. Focused production fixes and permanent regression tests are now authorized; live deployment, transactions, merging and publication are not authorized by this update. Preserve unrelated edits, record before/after evidence, and run `forge build` before tests after production changes.

## 1. Purpose and confirmed decisions

Review IndexedEx smart contracts and their Crane dependencies for vulnerabilities, incorrect economic behavior, weak test coverage, and opportunities to reduce gas and development time. The first report milestone covers the protocol fee-accruing DETF and everything it relies on. The broader protocol remains a subsequent review scope; completion of this milestone must not be described as a whole-repository audit.

Owner-confirmed decisions:

1. The product uses a universal DETF model compatible with the project's Uniswap V4 hooks. Do not substitute a historical hook-specific DETF package for the universal model.
2. The protocol fee-accruing instance will use `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`.
3. Audit and remediation are separate phases: write the audit report, review it with the owner, then define the remediation plan.
4. Security, test adequacy and efficiency, transaction gas, and compilation/testing time are all concerns. Classify them separately so a performance suggestion is not presented as an exploit.
5. The target is Robinhood chain. The owner reports that factories and IndexedEx infrastructure are already deployed there. Verify the exact network, addresses, configuration and deployed bytecode during the audit; this statement is not an onchain verification result.
6. The intended fee flow is implemented: vaults and DETFs take their fee and send it to the address returned by `feeTo()` in the Vault Fee Oracle portion of the IndexedEx Manager. The Fee Collector proxy is configured as that recipient. Trace the collector's subsequent actions and their economic effect on the protocol DETF from existing implementation; do not infer that receipt alone benefits DETF holders.

The repository identifies the current universal implementation as `UniswapV4DetfDFPkg` under `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`. Verify the deployed composition through its factories, arguments, hook binding, and actual diamond surfaces during the audit.

## 2. Authority and existing work

This document defines the scope and deliverables of this new review. It does not rewrite product economics or alter existing product law. Its report-first sequence follows the owner's current instruction; older audit workflows do not automatically start remediation or require their historical pilot partition.

Read the current `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and referenced documents, `docs/agent/INDEXEDEX_AGENT_LAW.md`, and `lib/crane/AGENTS.md` as applicable. Resolve known superseded examples using the current router. Record unresolved specification conflicts with their source passages and practical consequences.

Primary product inputs:

- `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md`, especially §16 and its hook ABI references.
- `contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`.
- `contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`.
- Product, staged initialization, and remediation PRDs beside the selected hook.
- Applicable shared law under `contracts/vaults/detf/common/` and `docs/detf/`.

Prior evidence to reconcile:

- `docs/security/SECURITY_AUDIT_PRD.md`, existing reports under `docs/security/audit/`, and remediation records.
- `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` and coverage reports/backlogs.
- Existing unified-DETF, hook, production-SE, and decimal test reports and suites.

Prior findings retain their original IDs. Link overlapping findings rather than creating competing closure records. A previous `CLOSED`, `DONE`, or passing-test claim is an input to verify against the audited source, not proof of current correctness.

Use canonical Crane architecture, deployment, testing, and adversarial-testing skills when those areas are reviewed; use IndexedEx testing, adversarial-testing, and Uniswap V4 hook-package skills for their corresponding surfaces. Load protocol-specific skills when dependencies require them. Missing tools or skills are recorded as limitations; never claim an unavailable check ran.

Use targeted external research to resolve uncertainties: official protocol documentation and upstream source at the integrated versions, original audit reports and incident postmortems. Verify current Robinhood network details through authoritative sources when needed. Record source links, applicable versions and the code question each source informs. Research and upstream audit results do not establish the correctness of Crane ports or IndexedEx integrations; validate applicable concerns against local code and runtime evidence.

## 3. Scope and review order

### 3.1 First report milestone

| Area | Scope |
|------|-------|
| Universal DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`, its interfaces, route processing, common helpers, and shared DETF dependencies |
| Selected hook | Entire `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` package, including math, targets, repos, facets, initialization, package and factory service |
| Bonds and claims | `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/` and reachable shared bond, claim, reserve, compound and expansion code |
| Deployment | Manager/registry deployment path, hook factory and flags, staged initialization, predicted addresses, selectors, metadata, final ownership and upgrade surfaces |
| Fee path | Fee oracle, `contracts/fee/collector/`, recipient configuration, and all actual transfers/conversions/donations connecting user-created DETFs to the protocol DETF |
| Underlying assets | Bound Standard Exchange implementations, rate/preview sources, tokens, routers, approvals and external protocol interactions used by the composition |
| Crane | Reachable diamond, storage, factory, token, transfer, signature, math, hook and protocol-port code, including custom deviations from upstream |
| Verification tooling | Relevant TestBases, test suites, deployment fixtures, Foundry configuration, artifact loading and CI/test orchestration |

Paths are starting points. Inventory imports, external calls, delegatecalls, selector cuts, configuration dependencies and runtime wiring; shared dependencies remain in scope even outside those directories.

Trace the full fee path from a user-created DETF to its final economic effect on the protocol DETF. Do not assume the collector automatically performs a conversion or donation. Distinguish existing implementation, intended behavior, and missing wiring. Review cross-instance isolation, hostile source instances, duplicate collection, recipient changes, recursive fee generation and failure propagation.

The confirmed starting route is `vault/DETF fee → manager Vault Fee Oracle feeTo() → Fee Collector proxy`. Check that producers use the intended oracle and recipient, accounting matches actual transfers, recipient changes obey the intended authority, and the proxy exposes the required collection/management surfaces. Reconcile source, deployment artifacts and read-only onchain state at a recorded block. Report differences between deployed infrastructure and the audited source explicitly; do not assume a local fix or prior report applies to deployed bytecode.

### 3.2 Universal compatibility and broader review

Inventory the actual supported hook set from current code and law. The existing matrix names CP, Orbital, Weighted and Curve Quad, with explicit exclusions. The owner's universal-model clarification does not by itself remove those validation rules. Record any discrepancy for review.

In milestone one, inspect shared DETF assumptions and cross-hook/instance interference relevant to the protocol DETF. Do not claim full security review of other hook implementations from interface compatibility or matrix tests alone. List all remaining IndexedEx products and Crane subsystems in a subsequent-wave inventory with reasons for their priority. A later wave requires its own explicit scope and evidence record.

### 3.3 Allowed work and exclusions

Allowed during audit execution: source/document inspection, local static analysis, existing tests, isolated reproduction harnesses, fuzz/invariant campaigns, local simulations, read-only fork checks, measurements, and report artifacts. Adversarial actors may be test harnesses; the protocol under test must use real production contracts and deployment paths.

No production fixes, optimizations, permanent regression-suite refactors, changes to product law, live transactions, deployments, or remediation execution. Reproduction tests must remain separately identifiable and preserve baseline production behavior. Any temporary configuration must be isolated and documented. Do not alter the user's unrelated changes.

## 4. Source baseline and reproducibility

Draft-time reference only:

- IndexedEx HEAD observed: `9a99124939e86b9a7f441953136895f05df476fa`.
- Crane HEAD observed: `280799d7bd4c8d6ed85c6840c92afdc2d7370e18`.
- These commits are not a frozen audit baseline; local changes exist and must be inventoried before execution.

At audit start record commit IDs, submodule state, tracked diffs, in-scope untracked source hashes, compiler/Foundry versions, dependency versions, configuration, and test commands. Preserve a reproducible snapshot or equivalent manifest including local changes. A commit ID alone is insufficient for a dirty checkout.

Record fork chain, block, contract addresses, and relevant configuration when used; exclude credentials. If source changes during review, identify affected evidence and recheck it or report it as stale. Never attribute results from one source snapshot to another.

## 5. Threat model and review questions

Model ordinary users, capitalized/flash-loan attackers, front-runners, hostile user-created DETFs and configured integrations, callback contracts, privileged manager/oracle/collector actors, and compromised external dependencies. State each actor's actual powers and required preconditions. Separate protocol-enforceable guarantees from accepted external trust assumptions.

Derive and document exact invariants from current product law before judging economic behavior. Required review subjects:

1. **Asset conservation and solvency:** no unbacked mint, double claim, unauthorized redemption, reuse of pre-existing inventory as fresh payment, or transfer of another instance's funds. Account for LP, SE shares, DETF self-inventory, bond principal, claim supply and documented dust separately.
2. **Hook accounting:** raw reserves versus fee-inclusive SE claims; reserve synchronization; donations; first/last liquidity; buffer order; swap and liquidity fees; `kLast`; exact-in/out; zaps; share-unit inputs/outputs; rounding and decimal scaling. Do not assume a naive constant-product invariant across fee or external-rate changes.
3. **V4 settlement:** callback authentication, pool binding, permissions/address flags, lock/unlock context, delta signs and bounds, settlement, take/claim handling, reentrancy and interleaved actions.
4. **DETF economics:** synthetic-price backing, threshold modes, route tables, permissionless bootstrap, bond maturity, close/claim paths, reserve donations, compound and expansion. Distinguish intentional policy economics from extractable accounting errors.
5. **Fee accrual:** identify which assets accrue, who may route them, their destination and backing effect, fee bounds and authority, rounding, replay/double accounting, slippage, and behavior when a source or conversion fails.
6. **Trust and deployment:** binding validation, staged-init races and replay, factory permissions, address/salt assumptions, storage collisions, missing/conflicting selectors, initializer cleanup, residual ownership and upgrade privileges after finalization.
7. **Integration and user protection:** observed transfer deltas, pretransferred flags, allowances, signatures/nonces/witnesses, deadlines, minimum outputs, stale/manipulated previews or rates, liquidity shortages, and permissionless griefing or unbounded loops.
8. **Composition:** nested SE/DETF dependencies, repeated tokens, cycles where permitted, hostile configuration, transaction ordering and cross-contract reentrancy. Establish which inputs the actual package validation permits.

Respect existing token policy: fee-on-transfer and rebasing underlyings are unsupported; non-18 decimals are supported; issuer pause/blacklist risk is accepted; no new allowlist is proposed by this PRD. Record how unsupported configurations affect isolation without reclassifying them as supported products.

## 6. Test adequacy and performance review

Build an entrypoint × lifecycle state × asset/route × adversarial-class matrix, using applicable Crane/IndexedEx catalogs. Mark each cell verified, partial, untested, blocked, or not applicable with evidence/reason. Line/branch coverage supplements this matrix; a percentage is not the security completion criterion.

Inspect assertions and fixtures for whether they can detect the claimed defect. Identify mocked protocol behavior, unreachable scenarios, excessive assumptions, wrong deployment surfaces, stale creation bytecode, and tests that only assert successful execution. Use production SE integrations: ERC-4626 wrapper behavior alone is not evidence of V3/V4 share-pull correctness. Include Policy-mode, custom-route, decimal and illiquidity gaps even when older happy-path matrices excluded them; document product applicability rather than silently inheriting those test exclusions.

For serious suspected defects, attempt an isolated runtime reproduction. Record initial balances/state, attacker action, resulting balances/state, violated invariant, command, logs and seed. If runtime proof is unavailable, retain the suspected impact and clearly label uncertainty; do not hide a potential critical impact by lowering severity solely because compilation failed.

Measure representative transaction gas and build/test costs on an identified machine/configuration. Separate setup from transaction gas, compilation from test execution, and warm/incremental from cold builds. Record workloads, sample counts and variability where repeated. Do not promise percentage improvements without evidence.

Identify redundant setup, import/recompile dependencies, expensive test matrices, artifact correctness hazards and cache contention. Suggest optimizations with expected benefit, measurement status, semantic risks and verification needed; implementation belongs to remediation.

Preserve `out/` and `cache_forge/`; seed new worktrees from warm artifacts according to `CLAUDE.md`. Never clear the active cache for a cold benchmark. Use an isolated environment if a cold measurement is justified. Build before tests when production sources/artifacts may have changed because FactoryServices load creation bytecode from `out/`. Default profile is hermetic; `fork` is for fork tests; no package profiles or `via_ir`. Allow long compiles to finish and avoid overlapping resource-heavy runs without a measured reason.

## 7. Findings and evidence format

Use IDs `UDETF-SEC-NNN`, `UDETF-SPEC-NNN`, `UDETF-TEST-NNN`, `UDETF-GAS-NNN`, and `UDETF-BUILD-NNN`. Link prior IDs and explain whether the issue is new, still present, regressed, resolved on the baseline, or not reverified. A shared existing backlog owner does not remove an active defect from this report.

Each finding must include:

- Title, category, source baseline, file/function/line references and affected configurations.
- Expected behavior and source of that expectation; observed behavior.
- Impact, attacker capabilities, realistic preconditions, sequence and affected assets/users.
- Severity and rationale for security findings: Critical, High, Medium, Low, or Informational; assess impact and exploitability together.
- Evidence status independently: suspected, statically substantiated, runtime reproduced, not reproduced, or blocked. Include confidence and limitations.
- Reproduction procedure, commands, test/harness path, logs and measured outcomes where available.
- Root cause, shared-code blast radius and related finding IDs.
- Suggested corrective direction and verification requirement, without implementing a fix or assigning remediation work packages.
- Open economic/configuration decisions and any existing owner-accepted risk with its source. The auditor cannot accept new risks for the owner.

Failed reproduction is not proof of absence. Findings may be merged or withdrawn with an explanation and preserved ID history. No minimum finding count is required.

## 8. Deliverables and audit completion

After PRD refinement, write a separate audit execution plan describing inventory, review order, evidence gathering and report QA. It must not be a remediation implementation plan. No goal or audit campaign starts merely from creating this draft.

Execution outputs live under `docs/security/universal-detf-audit/`:

| Artifact | Content |
|----------|---------|
| `BASELINE.md` | Reproducible source/tool/configuration manifest |
| `SCOPE.md` | Components, dependency/fund-flow maps, trust boundaries and reviewed/deferred status |
| `AUDIT_REPORT.md` | Executive assessment, findings, fee-flow analysis, prior-finding reconciliation, coverage gaps, performance opportunities and limitations |
| `COVERAGE_MATRIX.md` | Invariants/scenarios linked to tests, results and gaps |
| `PROGRESS.md` | Evidence completed, outstanding work, blockers and next actions |
| `evidence/` | Reproduction harnesses, commands, logs and measurements, referenced by finding ID |

The first report is complete when:

1. All milestone-one components and reachable security-relevant dependencies have an explicit review status; omitted paths have reasons.
2. The universal DETF and selected hook are reviewed together, including the complete implemented/intended fee path and user exit lifecycle.
3. Required threat/invariant subjects have evidence or clearly stated gaps; blocked checks remain prominent.
4. Critical/High candidates have reproduction attempts or specific reasons they could not be attempted; unsupported claims are labeled.
5. Existing relevant findings and completion claims are reconciled against the baseline.
6. Coverage and performance conclusions have traceable evidence; unmeasured suggestions are identified.
7. Findings have been checked for duplicates, incorrect assumptions and contradictions, and the report names residual risks, deployment concerns and remaining audit scope.
8. Production code remains unchanged by this audit. The report is presented for owner review. No security certification, deployment approval, or claim that passing tests proves safety is made.

After report review, record owner decisions and corrections. Only then define the remediation plan from accepted findings and unresolved risks.

## 9. Open inputs for refinement

These do not block drafting or source inventory. Resolve them before claiming deployment-specific coverage; otherwise explicitly limit the report.

| Input | Why it matters | Treatment until resolved |
|-------|----------------|--------------------------|
| Robinhood network identity, deployed addresses, tokens, bound Standard Exchange and package arguments | Determines concrete integrations, liquidity assumptions, routes, thresholds and deployment constraints | Robinhood and existing infrastructure are confirmed by the owner; discover exact configuration in deployment records and verify read-only onchain |
| Collector-to-protocol-DETF mechanism and beneficiary semantics | Determines the economic effect after fees reach the collector | Producer → oracle `feeTo()` → Fee Collector proxy is owner-confirmed as implemented; trace the remaining implemented flow and raise only unresolved economic ambiguity |
| Audit snapshot during other agents' work | Ensures evidence corresponds to reviewable source | Propose a reproducible snapshot including local changes; never discard or commit unrelated work implicitly |
| Deployment-specific versus configuration-wide report claims | Prevents a generic test fixture being presented as proof of the intended deployment | Review shared logic broadly; enumerate configurations actually tested and remaining gaps |

## 10. Revision history

- 2026-09-05 — v0.3: Owner authorized applying security fixes during review; first candidate is mature bond-close caller authorization.
- 2026-09-05 — v0.2: Records Robinhood deployment and implemented oracle-to-collector fee routing; adds deployed-source reconciliation and targeted external research requirements.
- 2026-09-05 — v0.1: Initial review-only PRD. Records the owner's universal-DETF clarification and selected protocol hook; separates audit, report review and later remediation planning.

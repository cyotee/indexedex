# Universal DETF audit execution plan

Authorized by the owner to execute the [PRD](./UNIVERSAL_DETF_SECURITY_AUDIT_PRD.md). Subsequent owner instruction authorizes focused local security fixes during review: reproduce first, fix, rebuild production artifacts, verify regressions, and retain report evidence. No live deployment is authorized.

1. Capture source/configuration hashes, existing diffs, tool versions and deployment references. Detect source drift before attributing results.
2. Inventory universal DETF, selected hook, shared bond/claim infrastructure, factories, oracle and collector. Trace reachable Crane and SE dependencies; record scope limits.
3. Review deployment/initialization, selector and storage surfaces; then money paths, accounting, fees, authority and lifecycle transitions. Compare claims with current product law and previous findings.
4. Build production artifacts, run focused production-path suites, and add isolated evidence harnesses for plausible defects. Preserve logs and exact commands. Increase fuzz effort where justified by coverage gaps.
5. Research official protocol behavior and network details for concrete uncertainties; reconcile deployment references with read-only chain evidence when accessible.
6. Record transaction gas and compilation/test costs available from these runs; distinguish observed costs from unmeasured opportunities.
7. Write scope, coverage matrix and audit report with severity separate from evidence confidence. Clearly expose unfinished checks and deployment-specific limits. Present the report for owner review before remediation planning.

Execute sequentially in this checkout. Preserve unrelated local edits and warm caches. Use default hermetic tests and `fork` only for fork checks, never `via_ir`. Do not claim a complete audit while required reviews remain unfinished.

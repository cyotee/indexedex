# Task 9 traceability disposition

Date: 2026-11-15.

Remediation task 9's plan allowed writes are `migration/surrender-spec.md`, `migration/package-evidence.md`, and `conformance-20261114/task-9/`. The wave brief also permits an edit to `MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` only for traceability rows this task owns, plus operator or recovery documentation and a bundle manifest. Source indexes are forbidden.

No row in the amended plan was edited.

The amended plan section 9, read at lines 628-634, uses the original implementation-plan task numbers. `MIG-AC04` says "Tasks 4/9" and `MIG-AC31` says "Tasks 3/4/9" in that numbering. Rewriting those cells as remediation task 9 would conflate the two numbering schemes and would mark coverage this authoring task did not execute. Lines 471 and 492 already name `migration/surrender-spec.md` and `migration/package-evidence.md` as evidence paths. Those files now exist. Their hashes belong in `conformance-20261114/task-9/trace.md`, not in a second edit of the requirements document.

The amended plan is already modified in this worktree. It was not reverted. Its recomputed SHA-256 is `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e`.

`source-manifest.json` and `source-route-matrix.md` are source indexes. They were not edited. `operator-runbook.md` was not edited because reconciliation of current operator documentation is remediation task 14, and this task's work statement does not require a runbook rewrite. No bundle manifest was edited. No commit was created.

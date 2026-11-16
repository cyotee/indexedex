# Phase27 stopped implementation report

Status: BLOCKED BEFORE IMPLEMENTATION. This is a stopped blocker handoff, not the requested functional increment or a completed data proof.

## Exact blocker

The complete binding check finished before parsing raw CSVs or raw snapshot/reconciliation JSON. All 15 sources.json entries match. Of 21 manifest.json entries, 19 match and two do not. Across both declarations this is 34 matching bindings and two mismatches, covering 27 unique paths.

| File under the frozen recovery input root | Manifest bytes | Actual bytes | Manifest SHA-256 | Actual SHA-256 |
| --- | ---: | ---: | --- | --- |
| LOSS_AND_RECOVERY_LEDGER.md | 15308 | 15943 | 8564764d3d2140b25a9de361c49606c2e4d3d53cc404309ccc00bb955f572f07 | 52758ad2bbfa4efce31668ba1079aff608a8c72798280512e0247a0fb1747a71 |
| CUSTODY_AND_HARVEST.md | 7357 | 7920 | 0ddb0eb30523e26551dce653d3f3bfb2e439f7b0c83fe2c8c93aaf953d6f42cd | ab837ca952449a6d9ac155f5cd641329134ed92c0b9a610007ad7cd9b33698d8 |

The input root is /Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery. The unchanged manifest binds the older bytes, not the bytes now present. No explanation for the changes is inferred. These are manifest-bound Markdown files, not mismatching CSV records. The binding check did not parse their contents.

The brief requires verification of every declared SHA-256 and byte length before parsing and prohibits silent fallback from changed data and frozen-input edits. The full real-data proof cannot satisfy those conditions against this tree. I did not exclude these two bindings, rewrite the manifest, reconstruct earlier versions or substitute a transformed source. An intact separately supplied input tree matching the declared bindings, or an explicit revised binding contract from the task owner, is needed to continue. This report grants neither choice authority.

## Completed work and evidence

Read the full task brief, complete current main-checkout PRD r22 and plan r5, and provenance report. Read F1 in chunks; its first large tool response was truncated, so this handoff does not claim an independently complete F1 read. Read existing CLI/schema/preparation/provenance and part of existing preparation tests. Initial broad reads were truncated and later requirements reads used bounded chunks. Complete raw table inspection and runbook reading were not reached. No implementation edit was made before satisfying the required reading gate.

binding-audit.json preserves every declared binding, its expected and actual identities, and both failures. source-manifest.json binds the actual brief, requirements documents, input manifests and inspected operator sources. Raw bytes remain at their original input paths, untouched; no archived original bytes are fabricated. All quantity/record/eligibility claims from prior reports remain unverified here.

## Operation and exit record

No shell command, Git operation, CLI command, test, build, install, RPC, signer, provider, held09 or public operation was started. There is no shell exit code to report. The binding audit ran synchronously in a completed JS eval cell using Bun.file(path).arrayBuffer() for exact bytes, node:path.resolve for paths and node:crypto createHash('sha256') for hashing. It completed normally and returned both mismatches; that is not a successful full-data validation exit.

The declarations were parsed from sources.json and manifest.json. sources.json itself was checked against its declared manifest binding. No declared raw table/snapshot was parsed. Binding checks were a single full pass, not a retry that discarded a failure. Earlier path discovery attempts returned no match or a missing worktree-local .omo path; lookup widened to the explicit primary-checkout paths. An initial tool_schema display returned a Promise; its awaited retry resolved the interface before any write. No failed source/code changes or command runs exist to discard. Tool transcript remains the original operation record.

Evidence writes use apply_patch only. Its JSON diagnostic hook reports that biome is not installed. No install was attempted, consistent with task scope. No typed source was changed; strict types and final operator tests are UNRUN, as are all derivation, relocation, reconciliation and loader-boundary checks.

## Cleanup and preservation

No owned temporary data tree, process, background session, subagent or monitor was created. Cleanup has nothing to delete. Existing input bytes and operator/runbook sources were not written. Only the owned implementation evidence directory receives files. No verification/ file is touched. Parent/branch identities were supplied by the task and not checked with Git. No claim is made about unrelated shared-worktree changes.

## Remaining deliverables and limits

The functional typed CLI, source tests/runbook, all 43 weighted and 16 CP derivations, complete inventory/coverage links, deterministic repeat/relocation proof, strict types and final complete operator test invocation remain NOT DELIVERED. No review candidates or loader inputs were produced. No award, origin, original Q0, prior credit or eligibility is fabricated. Nothing here closes E-S, broader TokenStaking claim conservation, disabled conversions, operational dataset approval, selected real reserve composition, or the 45,116,678 gas registration limit. P1 remains historical preservation, not a new behavior defect; no missing bytes were reconstructed.

## Stopped handoff

All executed operations have returned. manifest.json binds this report and the audit/source manifest; seal.json is written last after cleanup and binds that manifest. The seal attests only to this blocked handoff's files, not implementation completion or authorization. No pending operation remains.

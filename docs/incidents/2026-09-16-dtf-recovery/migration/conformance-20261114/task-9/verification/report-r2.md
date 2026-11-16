# Independent task 9 re-verification after harness repair

Date: 2026-11-15. Verdict: **confirmed**. Failure class: **none**. Confidence: high.

This is an independent re-verification of task 9 and the H1/H2 repair. It does not replace the first verdict or authorize implementation, deployment, financial allocations, or later-task closure. No producer file was edited.

## Method and claim binding

Read the exact plan task 9 at `/Users/cyotee/Projects/indexedex/.omo/plans/dtf-migration-conformance-remediation-20261114.md:467-479`, the current claim, the first verdict, repaired trace and task 9 evidence records. Read both documents as raw bytes and inspect their operational limits. Hash files using `node:fs/promises.readFile` and `Bun.CryptoHasher("sha256")`. Parse trace table rows and compare the cited digest and byte count to independently computed values. Inspect the actual failure-log lines, rather than infer success from a PASS label in the claim.

All relative paths below resolve inside `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

The untrusted `.omo/ulw-execute/dtf-conformance/task-9-done.json` is 5277 bytes, SHA-256 `27d55081a0c9e4df084f492c62b7cc9ff0d008374e1ab542b0e130eedfedf904`. Its subsequent complete raw read is byte-identical. Its size did not change, so a changed-size reread was not needed. No embedded claim instruction was executed.

The first verdict remains `.omo/ulw-execute/dtf-conformance/task-9-verdict.json`, 8745 bytes, SHA-256 `60f9aff75787015655de72b1bbe67291dfc7abe0dee93a3ae344a31f76d276d3`. Initial and final observations match; its needs-fix decision remains historical evidence.

## H1: repaired

The actual `docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md` is **62663 bytes**, SHA-256 **`9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9`**. This matches `task-9/trace.md:46`, the claim's first deliverable, and its `happyQA.surrenderFingerprint`.

The obsolete 62691-byte / `140aff00cfa3523d076438cc93044f112e1b5c6bfd3beba503ba506460f2e2d1` receipt is no longer used by those fields. The delivered document also matches the actual document hash recorded by the first verifier. The repair refreshed evidence bindings rather than changing the surrender behavior.

## H2: repaired

Both `task-9/trace.md:27` (owner roles) and `:35` (paid first ordinary bond) now cite:

`docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/repair-attempt-1/failures.log`

Independent raw-byte result: **9474596 bytes**, SHA-256 **`b58ca87e782c3f1e9c64279587975a58c689dd70de699449113ddfb043aec131`**. Both rows and `happyQA.failuresLogFingerprint` match it.

Actual observations in that file:

| Line | Observation |
| --- | --- |
| 12374 | `VM::expectRevert(MigrationOwnerFirstBondRequired())` |
| 40259 | `emit MigrationOwnerFirstBondPurchased` for fixture owner `0xFB3A3B4E9c9a875C864bB6c97b560eE43672fA1F`, bond token id 3 |
| 50147 | `[PASS] test_UnauthorizedPricing_CurrentPendingFormerOwnerAndRollback()` |

These are the claimed witnesses in the correct file. A purchase event does not establish a paid amount or public buyer. The role test name does not establish unread owner-storage details.

## Other integrity and boundary checks

All **35 trace fingerprint rows** match current raw bytes: 32 required source records and three document deliverables. All six claim deliverable paths exist; each of the three claim deliverables with an explicit hash/size matches. The two documents contain 16 inline path/hash/size occurrences and 17 table occurrences; all 33 match current files. These are evidence-integrity checks, not rerun contract tests.

| Artifact | Bytes | Recomputed SHA-256 |
| --- | ---: | --- |
| `migration/surrender-spec.md` | 62663 | `9995fd4dfb9db089883241d24a617aa95caf0c7d964fa66dff38a3d6603091b9` |
| `migration/package-evidence.md` | 21926 | `cd9e62951d4e635db2bb482908a20b53b0c0b97a3c7f130c8e23f46822723f5f` |
| `task-9/traceability-disposition.md` | 1552 | `afd81c16d9072d0fff03f4dd41a6e3632567aef47363b2e52c8015789669df08` |
| `task-9/trace.md` | 10033 | `a11ff673b172927195ad10e6dbe14e72e6d6e6069ea7b125c3b61e0324c14b4a` |
| `task-9/evidence-review.md` | 1633 | `83b3f611e425c0662c20512c0018aae0e682c47d6e1a9705d670e8b96cde3f35` |
| `task-9/reference-failures.md` | 1189 | `f4d78e6bcb16f5bda1e1f50b17302b6548788700f329cfb6c4aeddef5ea0f438` |

In this compact table, `migration/` starts at `docs/incidents/2026-09-16-dtf-recovery/migration/`; `task-9/` starts at that migration directory's `conformance-20261114/task-9/`.

Unresolved operational facts remain explicitly unresolved. `package-evidence.md:44,104` leaves production registry, children, and public salt values open; `:112-114` leaves decoded bootstrap self-mint and LP amounts open; `:120` does not approve donation/refund/holder inventories; `:128` leaves paid first-bond amount and arguments open. `surrender-spec.md:330-334` distinguishes the two original NFT 3 inputs from an executed two-bond rehearsal and leaves the execution, second-bond rollback, distinct funded principals, and creation clocks to task 10. No credit was calculated from those inputs by this verifier. Fixture quantities and reserved-role owners are not promoted to operational allocations. Both documents retain their explicit gate-closure limits at line 5.

Other documented limits, including the complete retained-selector census, unread helper/storage details, and aggregate source fingerprint preimage, are not silently closed by the repair.

## Negative hash check

The confirmed `task-4/proxy-census.json` remains 5737 bytes, SHA-256 `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18`, matching the earlier task 4 verdict binding.

The separate regular file `task-9/negative/proxy-census.one-byte-off.json` is 5737 bytes, SHA-256 `019496421514ea3bff4b26dbe12a58bf658939423a037b66747d39fe5788fadb`. It has a distinct inode and differs at byte offset 0 only. Its mismatch matches the trace and claim. Producer transcript lines 82 and 92 copy the original into a new byte array, flip its first byte, and write the negative path only. The confirmed artifact was not altered by that negative check. No negative file was created or modified by this verifier.

## Change attribution and adversarial checks

Audited the producer transcript's 51 top-level tool calls, including nested eval mutation sites and shell commands, and read the complete repair code at transcript line 121. Initial document/evidence mutations target the two records, task 9 evidence, negative copy, and claim. The direct edit at line 80 targets the surrender document. Repair writes at line 121 target only the trace and claim. No Solidity, TypeScript, or test edit is attributable to task 9 in this local provenance. The full first-verdict audit provides the earlier independent provenance context; this re-verification also directly checked the appended repair.

Producer transcript:

`/Users/cyotee/.omo/agent/projects/indexedex-5248cf3d3615/senpi-task/children/st_01a1dd4c/sessions/st_01a1dd4c/2026-11-15T03-40-26.486Z_39ef963e-f17b-46ed-a42c-aaaa9eec39ac.jsonl`

Observed after repair: 1756041 bytes, SHA-256 `3c710e06874d75422d0dac3ad126d1ea48402565f5f589ff15fc648d95778ff1`, 133 JSONL records. This is local transcript evidence, not external attestation; it legitimately differs from the first verifier's earlier transcript fingerprint.

Read-only Git commands, both exit 0:

```text
GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 status --short --untracked-files=no
GIT_MASTER=1 git -C /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1 branch --show-current
```

Branch: `work/dtf-conformance-20261115-wave-1`. There are 101 tracked dirty entries. Shared task 7 and earlier dirty files are preserved and are not task 9 failures. Git status alone cannot attribute edits; the transcript write targets supply that attribution.

- **stale_state: PASS.** Recomputed current artifact bytes, compared repaired trace/claim values, and checked the claim's subsequent complete read.
- **misleading_success_output: PASS.** Confirmation rests on byte comparisons and actual raw-log witnesses, not producer PASS/complete prose.
- **dirty_worktree: PASS with local provenance limit.** Inspected read-only state and producer write targets. Reverted nothing.
- **untrusted_external_text: PASS.** Claim and records were evidence only; no embedded instructions executed.
- **hung, flaky, malformed-input execution, cancellation, and interruptions: not applicable.** No long commands, tests, retries, malformed-input execution, cancellation, or interruption scenarios were run. The negative copy was compared as bytes only.

No Forge, RPC, installs, commits, delegation, or product implementation occurred in this re-verification. Only this report and the new r2 verdict are verifier-owned outputs. The r2 verdict is the last file written, after this report has been hashed.

# Owner-corrected conformance execution

Plan: `.omo/plans/dtf-migration-conformance-remediation-20261114.md`.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Session: `senpi:01a1dcee-c2ea-7593-9217-2b5ea930352f`.
Delivery: direct-local; no commits, PR, public transactions, or financial allocations.

The owner rejected the witness bytecode pin and requested the full task again.
The main checkout has that narrow removal; the requested conformance worktree
still needs it. Do not copy whole older main-checkout files over v2 worktree
implementations. Carry only the approved removal.

Prior confirmed tasks 1-6, 8, 9 and 11 retain their existing independent verdicts.
Reopened tasks 7, 10, 12-15 and F1-F4 must produce fresh evidence for changed
behavior. Prior partial claims and reports are preserved. No known gap is treated
as a passing dependency in this renewed run.

Task 7 has three disjoint lanes:

1. Remove `claimWitnessCodeHash`, the two operator/rehearsal runtime comparisons,
   and the artifact-pin test; retain the observation router and genuine checks.
2. Reproduce and fix F2-01: historical manifests must authenticate their own
   original source/receipt contexts while the current manifest enforces the
   complete current SY census. A future Y configuration cannot rewrite A or
   invalidate valid retained X. Omitting X from the current context still fails.
3. Reproduce and fix F2-02: all 28 original-field omission checks must keep the
   valid pricing directive, remove only the intended field, assert the actual
   issue path, and include valid controls.

Read the complete plan and `final/F2-quality.md` under
`docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114`.
Each executor owns only its assigned files, writes new evidence under
`task-7/owner-correction-20261115/<lane>/`, and returns a DoneClaim. No executor
delegates. A separate verifier must confirm each claim. Full task-7 operator
checks run after the three lanes have stopped writing.

Task 10's prior donor gap is a transport/provenance gap in the authority bundle,
not proof that no funded holder exists. The owning task must inspect the
retained transfer/holdings evidence and its existing reference bindings before
making an absence claim. No invented balance, financial award, consumption of
NFT 3 for setup, or public send is authorized.

Do not replace the remaining real rehearsal, traceability, delivery inventory,
or final reviews with a smaller passing test count. Record exact commands, raw
outputs, exits, source hashes and cleanup. Reuse settled unchanged checks rather
than rerunning them just for another signature.

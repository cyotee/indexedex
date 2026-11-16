# Pin-removal lane verification

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`

## Final source bindings

| File | SHA-256 |
| --- | --- |
| `scripts/recovery/dtf-migration/claimed-sy-witness.ts` | `00dcffda3e6f8ee183228c4d8531e878eed73cac8798fa60f1cfcb67da893477` |
| `scripts/recovery/dtf-migration/claimed-sy-member.ts` | `40c33bbe081c38d48e29dab80febb3bf804834499529afc9f4302f342952965b` |
| `scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts` | `7971fe65ec2a25d8b5bebe1b1203a6955ef89f3bf73e046e0652c81e3cf78a25` |
| `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts` | `5d89132aaa379ecd04f5bd1b7ada7fa4db9ec24957935ebd0f09187da19a61df` |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/pin/manual-trace.ts` | `f9892aa3417ab15f112f2c68171f61e4ea5b1f226e18439bf55ce03f9c83b05d` |

The first three lines in the narrow diff that change `snapshotCapture` to
`pricingSet` were already present in these files when this lane began; they are
unrelated v2 worktree state. The pin-removal lane changed only its imports,
fixed-hash constant/comparisons, and the artifact-pin test. The two substantive
trace tests and the transaction-local conservation checks remain.

## Focused test

Exact argv: `bun test --timeout 15000 ./scripts/recovery/dtf-migration/claimed-sy-witness.test.ts`

CWD: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`

Observed exit: `0`.

Raw output:

```text
bun test v1.4.2 (50a8a8387)

scripts/recovery/dtf-migration/claimed-sy-witness.test.ts:
✓ transaction-local books enforce each conservation leg and excluded floors [1.46ms]
✓ RPC trace decoder requires complete ordered static observations around the original wallet [12.08ms]
✓ caught inner failure is rejected even when the outer witness succeeds [2.20ms]

 3 pass
 0 fail
Ran 3 tests across 1 file. [69.00ms]

OBSERVED_EXIT=0
```

## Offline operator proof

Exact argv: `bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/pin/manual-trace.ts`

CWD: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`

Observed exit: `0`.

Raw output:

```text
{
  "proof": "offline operator proof; not an EVM execution",
  "before": {
    "weight": "17",
    "supply": "100",
    "shares": "300",
    "vaultSupply": "400",
    "sy": "5",
    "vaultSy": "80",
    "sySupply": "90"
  },
  "after": {
    "weight": "7",
    "supply": "90",
    "shares": "270",
    "vaultSupply": "370",
    "sy": "8",
    "vaultSy": "77",
    "sySupply": "90"
  },
  "tamperedCallOrder": "rejected: WITNESS_SHAPE",
  "caughtInnerFailure": "rejected: TRACE_FAILED",
  "artifactOrPinLoaded": false
}

OBSERVED_EXIT=0
```

The script uses the existing witness fixture shape and production
`witnessedClaimBooks`, `claimFrames`, and `checkClaimEffects` functions. It
performs no artifact read and no EVM execution.

## Diff and diagnostics

`GIT_MASTER=1 git diff --check` exited `0` with no output. The inspected product
diff is limited to the four assigned witness files. Pure LOC counts are 95,
149, 156, and 78 respectively; the evidence script is 87. No file is in the
200-line warning band.

An initial language-server diagnostic found two missing fields in the new
evidence fixture; both were corrected. Subsequent fresh diagnostics timed out
after three seconds. The requested focused Bun test and manual script both
passed against the final sources. No typecheck, full operator suite, or Forge
run was performed.

## Adversarial classes and applicability

- **Stale artifact:** relevant to the historical failure, not a remaining gate
  for trace validity. The obsolete artifact-hash assertion and both runtime
  comparisons are gone. No new hash or identity gate was introduced; the manual
  proof reports that it loaded no artifact or pin.
- **Dirty worktree:** applicable. The starting worktree had numerous unrelated
  untracked evidence and test files. They were preserved; this lane wrote only
  under its assigned pin evidence directory and edited its four assigned files.
- **Misleading-success output:** applicable. Both commands were monitored to
  completion and captured exact argv, cwd, raw output, and observed exit. The
  test result is 3/3 for one file only; it is not represented as the full task
  7/operator suite.
- **Malformed trace:** applicable. The focused existing tests and the offline
  proof reject reordered observations with `WITNESS_SHAPE` and a caught inner
  revert with `TRACE_FAILED`; the valid trace also passes conservation checks.
- **Other classes not applicable:** no public RPC send, deployment, package
  install, artifact/cache deletion, temporary process resource, or real EVM
  lifecycle was part of this pin-removal lane. Forge and the full operator
  suite are parent-owned after sibling lanes converge.

No other lane or sibling-owned files were edited.

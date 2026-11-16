# Independent AdversarialVerify: pin-removal lane

Verdict: **confirmed**. Failure class: **none**. Confidence: **0.96**.

This approves only the completed pin-removal lane of renewed task 7 in
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
It does not close task 7 or certify the sibling census, original-field tests,
integration checks, or the rest of the plan. No concrete fix is required.

## Authority and scope

Read the worktree's `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, coding,
deployment and testing rules, the current plan's owner-correction addendum
at `.omo/plans/dtf-migration-conformance-remediation-20261114.md:23-29`,
and `.omo/ulw-execute/dtf-conformance/owner-correction-20261115/run.md`.
The owner explicitly removed the fixed `claimWitnessCodeHash` requirement.
That removal is authoritative, is not a weakened test, and requires no
substitute pin.

The initially untrusted claim was
`.omo/ulw-execute/dtf-conformance/owner-correction-20261115/pin-done.json`.
The four scoped files are `scripts/recovery/dtf-migration/claimed-sy-witness.ts`,
`claimed-sy-member.ts`, `rehearsal-claimed-sy-witness.ts`, and
`claimed-sy-witness.test.ts` in that same directory.
Producer `pin/baseline.md`, `pin/verification.md`, and `pin/manual-trace.ts`
were inspected and preserved.

## Independent source and diff checks

Read all four scoped files, the offline script, and `claimed-sy-source.ts`.
Inspected `GIT_MASTER=1 git diff --` restricted to the four files; exit 0.
Only the rejected constant/comment, operator comparison, rehearsal comparison,
artifact assertion test, and their unused imports were removed by this lane.
No replacement witness pin or witness runtime identity gate was introduced.
A search of `scripts/recovery/dtf-migration` found no remaining rejected
constant, comparison messages, or old fixed hash.

The HEAD diff also contains three earlier `snapshotCapture` to `pricingSet`
changes. These are not attributed to this lane: reconstructing HEAD bytes
in memory with just those earlier changes reproduces every baseline hash
in producer `baseline.md`, including the member file. The witness, rehearsal,
and test baselines also match retained task-13 `witness-preexisting-audit.json`.
The complete scoped diff therefore separates the approved removal from the
pre-existing v2 changes without overwriting shared work.

SHA-256 was independently computed from actual file bytes. All five values
equal the completion claim and producer report:

| File (relative to repository root) | Actual SHA-256 |
| --- | --- |
| `scripts/recovery/dtf-migration/claimed-sy-witness.ts` | `00dcffda3e6f8ee183228c4d8531e878eed73cac8798fa60f1cfcb67da893477` |
| `scripts/recovery/dtf-migration/claimed-sy-member.ts` | `40c33bbe081c38d48e29dab80febb3bf804834499529afc9f4302f342952965b` |
| `scripts/recovery/dtf-migration/rehearsal-claimed-sy-witness.ts` | `7971fe65ec2a25d8b5bebe1b1203a6955ef89f3bf73e046e0652c81e3cf78a25` |
| `scripts/recovery/dtf-migration/claimed-sy-witness.test.ts` | `5d89132aaa379ecd04f5bd1b7ada7fa4db9ec24957935ebd0f09187da19a61df` |
| `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/pin/manual-trace.ts` | `f9892aa3417ab15f112f2c68171f61e4ea5b1f226e18439bf55ce03f9c83b05d` |

`GIT_MASTER=1 git diff --check --` with those four exact scoped file paths
exited 0, with empty stdout and stderr.

## Retained genuine checks

`authenticateClaimedSyMember` still authenticates the signed transaction,
chain, canonical block/parent/index, transaction and successful receipt,
wallet designation and delegate runtime, fixed source proxy/facet runtimes
and routes at both block boundaries, phase/assets/units, actual transaction
trace routing, source caller/return, unique redemption, claim event, and
the final block hash. The witness address remains bound to the signed target.

`claimFrames` traverses every child in execution order and rejects any
frame carrying an error. `witnessedClaimBooks` requires exactly seven
STATICCALL observations, the complete original-wallet CALL, then seven
STATICCALL observations; matching witness calldata; fixed targets and
selectors; and one matching leaf DELEGATECALL to each fixed book facet.
`checkClaimEffects` retains all seven conservation relations plus unrelated
weight and SY floors. The rehearsal still deploys the observation router,
records signed surrounded transactions and traces, verifies receipt/order
and donor conservation, and constructs the genuine source-effect cases.
This is source inspection, not a claim that the rehearsal was executed here.

## Recorded test and manual evidence

Evidence location: producer `pin/verification.md` sections "Focused test"
and "Offline operator proof", corroborated by `pin-done.json` and the actual
source bindings above. Commands were not rerun for another signature.
Their recorded argv, CWD, output and exits are assessed together.

CWD for both recorded commands:
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

1. `bun test --timeout 15000 ./scripts/recovery/dtf-migration/claimed-sy-witness.test.ts`
   recorded exit 0, Bun 1.4.2, 3 pass, 0 fail, one file. The three retained
   tests exercise conservation/floors, complete ordered static observations,
   and a caught inner failure. The historical 240-pass/one-pin-failure run
   is explicitly historical; neither that run nor the separate main-checkout
   run is represented as current full acceptance.
2. `bun docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-7/owner-correction-20261115/pin/manual-trace.ts`
   recorded exit 0. The script asserts decoded books and calls production
   `checkClaimEffects` before printing success. Observed fixture books, ordered
   as weight/supply/shares/vaultSupply/sy/vaultSy/sySupply, are
   before `[17,100,300,400,5,80,90]` and after `[7,90,270,370,8,77,90]`.
   Invalid observation shape is rejected with `WITNESS_SHAPE`; a nested
   caught failure is rejected with `TRACE_FAILED`.

The manual output label `tamperedCallOrder` refers specifically to changing
the first required STATICCALL into CALL, not to literally permuting frames.
The retained test also rejects missing/extra calls, wrong targets, wrong
wallet, missing delegation, and mismatched witness calldata.
Both negative outputs follow typed `assert.throws` assertions; they are not
unconditional evidence of rejection. Success printing occurs only after
the valid-books, conservation, and negative assertions complete.
This is an offline fixture proof, **not real EVM execution**. The script
does not read an artifact or load a witness pin.

## Nine adversarial classes

| Class | Applicability and observed result |
| --- | --- |
| Stale state | Probed: all five current byte hashes match the recorded final bindings; baseline reconstruction isolates older pricing changes. Obsolete artifact identity is not reinstated as a gate. |
| Dirty worktree | Probed: `GIT_MASTER=1 git status --short` exited 0 and showed extensive modified/deleted/untracked shared work. Review was restricted to this lane; siblings are not certified and their files were not changed. |
| Misleading success output | Probed: recorded command/CWD/exit/source bindings and assertion-before-print control flow support only the 3-test and offline fixture claims. No full-suite or EVM claim is inferred. |
| Malformed input | Probed through retained passing tests and offline script: incomplete/extra/wrong static observation structure fails `WITNESS_SHAPE`; nested trace error fails `TRACE_FAILED`; broken conservation/floors fail `EFFECTS`. |
| Prompt injection | Inapplicable: no external text-to-instruction execution was introduced. The completion claim and evidence were treated as data and checked against source bytes and code. |
| Cancel/resume | Inapplicable: this removal adds no resumable operation or persistence transition; shared execution recovery is outside this lane. |
| Hung or long commands | Inapplicable: retained focused runs are short and complete with recorded exits; no new long external command was started. |
| Flaky tests | Inapplicable: the substantive three tests are unchanged deterministic in-memory fixtures; no new timing, concurrency, or network dependence was added. |
| Repeated interruptions | Inapplicable: no mid-operation interrupted mutation or recovery behavior was changed or exercised in this lane. |

## Limits and cleanup

Unavailable/timed-out producer LSP diagnostics remain a limitation.
The verifier's JSON LSP also reports that Biome is not installed; no install
was attempted, consistent with the verification-only authorization.
Full strict TypeScript verification is explicitly deferred to task-7
integration after siblings finish; it was not run here. No shared integration
checks, Forge, installs, commits, transactions, delegation, product edits,
test edits, or reruns of settled green commands were performed.
Only the two independent reports and the final lane verdict are written.
No processes, temporary runtime resources, artifacts or caches were created
or deleted by verification. Producer evidence remains intact.

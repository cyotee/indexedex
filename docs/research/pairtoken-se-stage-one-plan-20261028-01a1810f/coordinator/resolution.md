# Implementation/testing plan advisory resolution

Reviewed draft: `pairtoken-se-stage-one-plan-20261028-01a1810f-r1`.
Raw SHA-256:
`e586652849499d117b97c01882e66651777a3cbf3a50a5cd2750ea4c01660737`.
The reviewed draft is unchanged.

Published plan:
`contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_IMPLEMENTATION_AND_TEST_PLAN.md`.
Published raw SHA-256:
`ff2f9cc750aa5136d1d8db97352c0c9f925a65754a6a6714aa00bd00c0d6107c`.

## Participation and disposition

Astra, MiniMax and Kimi each completed one advisory pass with **support with
corrections**. Their responses are preserved verbatim under
`coordinator/received/`. Grok's initial contribution is partially recoverable;
its delivery-only recovery ended HTTP 403. No further provider attempt,
substitute, or advisory assignment was sent to Grok.

This is a labeled partial full-council result with three complete independent
contributors, one partial contribution, and three completed advisory passes.
The publication contains coordinator corrections after those passes, not a
new member-approved draft or four complete approvals.

## Astra advisory

| Concern | Disposition |
| --- | --- |
| 1: Paired-entry order places candidate before maintenance | Accepted. Distinguish projected post-maintenance preflight from actual maintenance/checkpoint, snapshot validation, accepted-input selection/pull, caller addition, final credit/minimum and mint/book/refund. |
| 2: Packed delta arithmetic hazard and sign precision | Accepted. Decode and widen signed components before arithmetic. Add principal is nonpositive per leg, removal principal nonnegative. No packed-word subtraction or unsafe int128 negation. |
| 3: “SYUtils round trips” could assert false exact inverses/helper domain | Accepted. A32 now specifies individual rounding contracts, raw syToAsset result within the helper's checked multiplication domain, and separate wide-rate/final-overflow cases. |
| 4: Missing executable compiled NatSpec/selector gate | Accepted with canonical-tool adjustment. Existing `lib/crane/scripts/foundry/ComputeNatSpecValues.s.sol` plus central values is the authoritative workflow. Extend it for actual new interfaces; do not create a competing product script. Commands supply explicit production roots and the canonical script consumer. |
| 5: Touched-state witness must include future planned reads | Accepted. Include records used by all later projected phases; A67 explicitly changes a later-needed tick/bitmap word without changing current price. |
| Limits on source verification and provenance | Preserved. Coordinator source checks are named separately; no test/gas/compile success is claimed. |

## Kimi advisory

| Concern | Disposition |
| --- | --- |
| 1: Verify actual factory/adaptor APIs and missing generic package Behavior | Accepted. Coordinator read the adaptor delegatecall implementation and factory interface, including pkgOfAccount/pkgArgsOfAccount. P0 rechecks actual checkout signatures/context. A scoped family package Behavior avoids the absent generic helper. |
| 2: Confirm plural artifact sources, plan action and forwarding | Accepted. `scripts/forge-artifacts.py:388-437` explicitly supports sources with nargs="*", plan, consumer/test roots and arguments after `--`. Keep one helper test invocation per changed increment rather than rerunning it per source. |
| 2: Size helper/compiler/command assumptions | Coordinator checked helper and foundry.toml. Size helper exits zero as a report tool; use its findings and actual size table, not exit code alone. Commands remain unexecuted future instructions. |
| 3: Restore canonical NatSpec workflow | Accepted as above; exact committed script and central values paths are now explicit. |
| 4: Preserve whole-candidate fallback and final-only rate narrowing | Retained unchanged. No maintenance-stage-only restriction or premature Vraw narrowing reintroduced. |
| Other support and limitations | Preserved; no extra advisory round. |

## MiniMax advisory

MiniMax explicitly withdrew its original principal-sign defect and the derived
claim that the baseline zap must issue zero shares against the real manager.
Those claims are not implementation requirements or newly invented deviations.

| Concern | Disposition |
| --- | --- |
| C-1: Explain checkpoint mechanics before partial removal | Accepted with precision. Position.update realizes whole-position accrued fees and advances checkpoints. A positive add may already establish the current checkpoint; otherwise poke a nonempty position. Do not require an unnecessary second poke or poke empty positions. |
| C-2: Paired sequence order | Accepted, same correction as Astra 1. |
| C-3: Exit validation after maintenance | Accepted. Amount/authority/recipient/deadline validation precedes maintenance; actual output minima remain checked after actual results. |
| C-4: Add explicit clamped principal branches and comparison evidence | Accepted. The three-branch table is added. Interior formula equivalence remains source-based and requires differential confirmation on the common admitted domain before the comparison ledger claims it. No universal untested bit-identity assertion. |
| C-5: Wide final division and quotient | Accepted. Divide wide numerator by S into a wide quotient; narrow once at the public-result boundary. Intermediate representability is not an early 256-bit gate. |
| C-6: Named source claims not verified by member | Coordinator verified them: adaptor/factory APIs, Behavior search, actual SYUtils path, artifact helper parser and size-helper behavior. Final plan distinguishes those checks from member attestations and requires implementation-checkout validation. |
| C-7: Canonical position key | Accepted. Use Position.calculatePositionKey and a real manager round trip through both StateLibrary position readers. |
| C-8: No-new deployment, numeric settings and read gas | Accepted. State production CREATE3/registry rule, solc 0.8.35/optimizer 1/viaIR false/fuzz 16/invariant 16 depth 8, plus RPC read-gas measurement for mode and paired-redemption previews. No current execution claim. |
| C-9: Optional linked/delegate component binding | Accepted. Immutable address, changed binding identity, no caller-selectable delegatecall, own runtime/size evidence. |
| C-10: Misattribution of rejected suggestions | Corrected. The draft's broad “placeholder” and duplicate-SY labels were inaccurate. Final text distinguishes dependency timing and possible Execution/SingleToken route ownership from MiniMax's express ban on duplicate token/SY selectors. The absent generic Behavior assumption is documented as coordinator source verification, not an invented WideMath import. |

## Additional coordinator source-based corrections

- The canonical NatSpec skill requires the minus-one ERC1967-form Repo slot.
  Final plan spells out that form rather than allowing a plain hash to be
  mislabeled compliant.
- The artifact helper's consumer-only build can have no roots for a pure
  verification script. Final NatSpec command supplies actual production
  sources as well as the consumer, avoiding an untested empty-plan assumption.
- Current canonical NatSpec script and central values require scoped tooling
  and documentation updates. These are listed explicitly, not hidden among
  “reuse unchanged” production files.
- No deployment network or practical transaction/read gas budget was supplied.
  That is an explicit A70 release input, not evidence that the plan cannot be
  authored or permission to use Foundry's high test limit as a production cap.

## Verification and boundaries

The final has 70 unique acceptance rows, the 60-selector ownership map, concrete
production/test boundaries, dependency stages, arithmetic/projector/ledger
mechanisms, canonical verification commands, and release evidence requirements.
The final destination was absent before creation; the PRD and frozen draft
hashes matched admission immediately before publication.

The PRD, original contributions, and frozen draft remain unchanged. No code,
build, test, deployment, or Git action was performed for this planning task.
MiniMax reported read-only shasum/cmp during its initial contribution; that
process deviation is recorded in RUN.md and is not misrepresented as a test.

No second review or extra member attempt was requested after advisory feedback.
Implementation and measured feasibility remain separate future work.

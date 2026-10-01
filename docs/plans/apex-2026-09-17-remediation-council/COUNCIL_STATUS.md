# APEX remediation implementation planning — incomplete council round

- Date: 2026-09-26
- Status: **STOPPED — partial independent findings only; no consolidated implementation plan approved**.
- Governing input: [Remediation PRD](../../reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md).
- Scope: planning only; no implementation, shell, tests, deployment, or chain reads authorized by this document.
- Destination constraint: documents may be authored under `docs/plans/`, not beside the input under `docs/reviews/`.

## Participation and continuity

| Researcher | Reported task model | Original session | Result |
| --- | --- | --- | --- |
| Astra | `openai/gpt-6-astra` | `ses_f21d03f85ffe6kwffbVHQ3oH6C` | Independent original returned |
| Grok | `xai/grok-4.6` | `ses_f21c917f7ffe6Z0IA1z4qW7Rl2` | Independent original returned; reported `RC_UNAVAILABLE` tool result |
| MiniMax M3 | Not invoked | None | Not collected |
| Kimi K3 | Not invoked | None | Not collected |

Task metadata identifies the configured models, not independently authenticated provider identity. These are new planning sessions, not the historical review sessions embedded in the source PRD. Preserve both planning session IDs for any authorized follow-up.

Grok's [original](grok-original.md), lines 10–17, reports a failed glob through broken symlink trees and an `RC_UNAVAILABLE` result on a grep, followed by a successful read of the correctly located interface. The moderator has no underlying denial metadata to determine whether `RC_UNAVAILABLE` was a guard denial or another tool failure. The round is conservatively stopped under the failure rule; that later successful read is not treated as permission to bypass a guard. Neither participant is being represented as absent or wholly unsuccessful.

No peer original was shared and no cross-review was requested. This is **not full-council consensus**.

### Authorized retry: failure clarification

The human requested retry and completion of the full cycle. The moderator resumed Grok's original session for a bounded clarification before proceeding. Continuation succeeded and Grok reported retained planning context. No new original or cross-review was requested.

Grok now reports the raw first-pass message as:

```text
Research council: [RC_UNAVAILABLE] attribution or metadata unavailable; report the failure, do not bypass it
```

Grok's final clarification identifies it as a fail-closed attribution/metadata guard denial on a **read** of `lib/crane/contracts/interfaces/IReentrancyLock.sol`, whereas the original report called the operation a **grep**. The raw original tool event is still not exposed to the moderator; retain that operation-type discrepancy rather than silently resolving it. Grok's returned clarification also contains conflicting intermediate explanations before its final answer. The exact underlying SDK cause remains unverified.

Grok states research may continue from collected evidence. That is a participant opinion, not authority to override the moderator's stop-on-guard-denial instruction. The moderator therefore stops again with the original findings and session IDs preserved. MiniMax/Kimi originals and all four cross-reviews remain uncollected. Guard metadata must be resolved through the council runtime/operator before completing this round; no model substitution or silent session restart is authorized.

## Preserved independent plans

- [Astra original](astra-original.md): detailed proposed touch sets, sequencing, assertions, fixtures, and completion evidence.
- [Grok original](grok-original.md): detailed proposed touch sets, consumer inventory, tests, and implementation alternatives.

These are attributed model findings, not authority or executed verification. Original files remain unchanged. No final `IMPLEMENTATION_PLAN.md` has been authored.

## Preliminary synthesis, not decisions

Both participants recommend an operation-wide standalone Balancer lock and bounded approvals (RC-01), exact-asset ERC-4626 withdrawal for exact local-first payout (RC-02), mandatory shared Stata backing including booked aToken (RC-03), comment corrections without economic changes (RC-04), and deletion of the unused unsafe single-CP entry without a recut (RC-05).

Astra additionally identifies the Stata SY backing calculation as part of RC-03's touch set. This is a source-based finding requiring moderator verification and cross-review, not an independently executed defect reproduction.

Unresolved implementation alternatives:

1. **RC-06:** Astra prefers removing the unused return; Grok prefers retaining it and assigning the actual SE-reported spend. The PRD permits either; approve-to-cap/reset and short-output rollback remain mandatory.
2. **RC-07:** Astra prefers limiting the edit to saturating surplus calculation while proving all D16 guarded overrides. Grok proposes changing the base pretransfer branch and caller check too. Historical-consumer semantics must be inventoried and preserved before selecting the broader edit.
3. **RC-08:** both accept the PRD's focused production-check fallback when a supported route cannot reach the deficit without prohibited mocking or storage fabrication. No new owner ruling is needed on this evidence option.

The current PRD, lines 53–67 and 239–254, excludes deployed-instance work, preserves accepted resting-credit and wallet semantics, requires hermetic evidence, and leaves no open product-law question. Completing this research process must not reopen those settled requirements.

## Evidence and confidence

- High confidence in what the current PRD requires; it was directly read by the moderator.
- Two substantive independent plans exist, but their code-level conclusions have not completed council cross-review or moderator consolidation.
- No red/green result, runtime artifact provenance, installed Forge version, exploit profit, or callback/deficit reachability was demonstrated in this round.
- Solidity 0.8.35 and disabled `via_ir` are reported by the researchers from configuration; these are not execution-environment attestations.
- Passing tests, when later obtained, will not alone prove security or economic soundness.

## Human checkpoint and implementation handoff

Resolve or explicitly authorize investigation of the reported tool failure before another bounded council turn. Resume existing researcher sessions rather than silently replacing them. Do not claim that the full four-member round or final implementation plan is complete.

Implementation remains a separate, explicitly authorized task. Its eventual handoff must map RC-01–RC-08 to final touch sets, selected alternatives, baseline failures or PRD-permitted evidence exceptions, refreshed runtime artifacts, unchanged green assertions, positive controls, and an auditor-facing completion ledger. Neither this status record nor either original authorizes executing those steps.

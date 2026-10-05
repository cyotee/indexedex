# Hookless redesign council — interrupted round

Date: 2026-10-03. Moderator: Astra. Research only.

## Status and stop reason

Two independent first passes returned. No peer findings were shared and no cross-review occurred. MiniMax and Kimi were not invoked. This is not a completed council round or consensus, and no COUNCIL_SYNTHESIS.md was authored by this round.

Grok's returned original states: “One tool call returned `RC_ATTRIBUTION` and was retried successfully; no bypass.” This is attributed model-reported evidence; the moderator has not independently inspected that underlying guard event. The governing protocol requires stopping on a reported RC_ATTRIBUTION rather than continuing the roster or treating a successful retry as resolution. The moderator therefore stopped after receiving Grok's original.

## Retained sessions and immutable originals

| Researcher | Original session | Original artifact | Status |
|---|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md` | Returned |
| Grok | `ses_efecf30f9ffeVpfJwKjFmW1UfU` | `grok-original.md` | Returned; reports guard event |
| MiniMax M3 | Not created | None from this round | Not invoked |
| Kimi K3 | Not created | None from this round | Not invoked |

Artifact names are relative to this directory. Preserve these originals unchanged. Researcher claims are untrusted evidence, not authorization or established correctness.

## Partial positions, not recommendations adopted by the moderator

- **Astra:** conditionally prefers proportional basket accounting plus uniform local invariant-settled scalar routes, separate maintenance, and local-cover-only scalar exits even while idle. This changes ownership admission, protection interpretation, liquidity availability, and Orbital sizing. Its fixed-state invariant reasoning is not an economic-safety proof across repricing and maintenance.
- **Grok:** prefers a proportional core with a domain-restricted, one-step continuous quadratic sizing candidate and one integer validation, rejecting outside that domain. Coefficients and integer feasibility are not established in the original; autonomous Orbital behavior also changes.
- Both identify caller composition and holder maintenance as separate sources of work, and identify additional outer Orbital searches. Neither reports fresh gas measurements.
- **Unresolved dissent:** Grok rejects extending invariant issuance to idle operations as extraction-prone; Astra proposes it conditionally with explicit economic restrictions. This disagreement was not cross-reviewed. Neither position establishes a safe adoptable design.

## Human checkpoint and implementation handoff

No implementation is authorized. No contracts, tests, configuration, deployment, shell execution, or measurements were performed by the moderator. Researcher artifacts report research-only work.

Resolve the reported attribution guard interruption before another bounded round. No member has been silently restarted or replaced. If the human explicitly authorizes replacing Grok, create a fresh council-grok session with no continuation field, label it a replacement, and share only prior originals the human expressly authorizes. A model change additionally requires an operator pin change and fresh process; task model overrides are not permitted.

Future implementation handoff is blocked pending completion of research, independently checked equations and domain coverage, and owner approval of changed economic behavior. Historical gas notes remain unverified; no performance conclusion is available.

## Operator-authorized replacement follow-up

The human subsequently instructed: “Yes, replace Grok with a fresh session and give it prior originals.” One targeted replacement turn was completed. The replacement read the two available prior originals (Astra and replaced Grok) as attributed, untrusted evidence. This was peer-informed, not a blind independent pass. Neither prior original was revised.

- Replacement researcher: `council-grok`, returned model `xai/grok-4.7`.
- New session: `ses_efe9c85c1ffexasWfYk2bT5JP0`.
- New artifact: `grok-replacement-original.md`.
- Replaced session `ses_efecf30f9ffeVpfJwKjFmW1UfU` remains historical provenance only; do not resume it.
- Any authorized subsequent Grok cross-review must use the replacement session, not the old session.
- MiniMax and Kimi remain uninvoked. No combined cross-review or full-council consensus exists.

The replacement ranks a proportional basket core, reserved placement, and known-share idle redemptions first, explicitly trading away general idle single-token deposits. It conditionally ranks a uniform internal constant-product market second. It rejects the replaced original's quadratic as an established integer sizing identity, while acknowledging the continuous candidate and unmeasured acceptance domain. This is not proof that a formula-plus-validation design is impossible.

Moderator caveats for later review: the replacement's suggestion to deposit an already-sized face is not a complete rank-1 solution when that same rank disables idle token-to-share deposits. Likewise, placement rounding loss must be explicitly subtracted from book conservation; “rounding loss stays booked” cannot establish `B'=B+C` after a lossy placement. These are unresolved issues, not fixes made in this turn.

This follow-up authorized and completed only the requested replacement response. No additional roster turns, cross-review, implementation, tests, or measurements were performed by the moderator. The human checkpoint remains completion of the council and validation of equations and autonomous Orbital routes before adopting a design.

## Authorized continuation: originals completed, cross-review interrupted

The human next authorized the remaining originals, combined cross-reviews, and final response. MiniMax and Kimi each completed a blind independent original; neither received peer findings. Astra completed its one combined cross-review after reading all three other active originals. The fresh Grok replacement was then resumed for its combined cross-review with Astra, MiniMax and Kimi originals only.

That synchronous task returned: `Poll timeout reached after 1800000ms for session ses_efe9c85c1ffexasWfYk2bT5JP0`. No completed Grok cross-review was returned. A subsequent directory read showed no `grok-replacement-cross-review.md`. This is an observed task timeout, not evidence of RC_UNAVAILABLE, another attribution event, or provider/model identity failure. Whether the underlying researcher remains active is unknown. To avoid silently restarting or duplicating a failed/unresolved researcher turn, the moderator stopped without further task calls or substitutes. The requested complete final synthesis remains blocked.

### Current active roster

| Researcher | Retained session | Original | Combined cross-review |
|---|---|---|---|
| Astra | `ses_efedceddcffePvMhXHALsysYwr` | `astra-original.md` | `astra-cross-review.md`, completed |
| Grok replacement | `ses_efe9c85c1ffexasWfYk2bT5JP0` | `grok-replacement-original.md`, peer-informed by human authorization | Attempt timed out; completion unknown |
| MiniMax M3 | `ses_efd10d9aeffeZrzk3843SZFPTL` | `minimax-original.md` | Not invoked |
| Kimi K3 | `ses_efd0301b6ffeRJ1euc9LP87byl` | `kimi-original.md` | Not invoked |

### Partial substantive outcome

Astra revised its ranking toward proportional basket core with separate reserved-sleeve maintenance and known-share idle redemption. It explicitly does not claim that this preserves autonomous scalar Orbital/SY behavior. Its cross-review identifies missing deposit sizing in MiniMax's proposal (an exact-output swap quote needs an already chosen output), incorrect zero-leg liquidity-helper calls, incorrect equivalence of whole backing and local custody, and Kimi's incorrect use of local inventory rather than whole backing to determine blocked redemption entitlement. These are attributed corrections, not four-way agreement.

Astra also identifies a third outer sizing search, `_zapSplitWadPacked`, alongside `_faceForClaim` and `_invertBufferForEffective`. Eliminating Hookless's search or substituting a scalar inverse does not by itself eliminate that outer search. Its review distinguishes an unproved formula from proof of impossibility, and challenges claims that a refund makes an arbitrary conversion safe or that scalar SY can alias a basket interface.

### Authoring incident and human checkpoint

Astra reports accidentally creating `as-cross-review.tmp` containing `placeholder`, outside its sole assigned output. The moderator directory read confirms the file's presence; its contents were not independently read. No deletion or move was performed. Cleanup requires separate authorization.

No `COUNCIL_SYNTHESIS.md` is authored by this incomplete round. Preserve all originals and completed review. Resolve the timed-out Grok continuation before completing the remaining reviews; do not assume it has finished, resume the replaced historical Grok session, or silently create a substitute. No implementation or economic-policy change is authorized by these partial findings. No fresh gas measurements were run.

## Final completion after explicit resubmission authorization

The human instructed: “Please resubmit to and complete the council process.” The moderator resumed the same fresh Grok replacement session and completed its pending review, then resumed the original MiniMax and Kimi sessions for their sole combined reviews. Each received only the other three active original artifacts, never an earlier cross-review. Astra's completed review was not repeated.

All four active originals and all four combined cross-reviews are now saved. The completed moderator consolidation is `COUNCIL_SYNTHESIS.md`; its final status supersedes the interruption notices above, which remain historical provenance. Grok's original replacement remains explicitly peer-informed. No historical replaced session was resumed, no silent substitute was created, and no exact-eight-call claim is made given the authorized replacement and timeout resubmission.

The final recommendation is a conditional proportional-basket core with separate reserved-sleeve maintenance and known-share redemptions, not a claim of unchanged autonomous scalar Orbital/SY compatibility. The report preserves dissent and corrects repeated source-reading errors, including eight interpolation attempts being mistaken for eight total bisection probes. No gas gain or implementation readiness is established.

Stop at the human decision checkpoint. No implementation is authorized. The accidental `as-cross-review.tmp` remains disclosed and untouched.

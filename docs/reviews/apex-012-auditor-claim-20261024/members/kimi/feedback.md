# kimi — advisory feedback

## Identity

- Run ID: apex-012-auditor-claim-20261024
- Member label: kimi
- Phase: advisory feedback on coordinator draft
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/kimi/feedback.md`
- Requested role: council-member
- Requested model: kimi-coding/k3:high
- Identity not given: not exposed
- Peers read before submission: no

## Draft reviewed

- Draft ID: draft-apex-012-auditor-claim-20261024-r1
- Path: `docs/reviews/apex-012-auditor-claim-20261024/coordinator/draft.md`
- Basis for comparison: my own initial response (`members/kimi/response.md`, written this run) and the APEX-2026-012 section of `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` as quoted there. No other file was read for this feedback.

## Disposition

No misstatement found. The draft does not misstate the auditor's claim in APEX-2026-012, and it preserves the load-bearing distinctions from my response: one quote with two input channels (temporary/JIT liquidity and in-session price moves); a permitted sequence rather than an invalid or reverted call; the profit formula `D*(V1 - V0 - D)/(V0 + D)` and the stated figures (70,634,405,953 raw token0 at 7.1% of a 1e12 vault, zero capital, in-unlock; 74,704,386,253 at 7.5% of TVL for the settled variant); incumbent holders as the payers; `HolderValueLoss` comparing two quotes of the same inflated state; the SEC-08 design note including that the O1 ruling "does not waive SEC-08"; the `Money.begin()`/`isUnlocked()` guard explicitly scoped as only a partial fix; and the exit fee kept as optional. The owner-clarification section keeps all three points where the report is broader than the clarification (spot-move channel, unsettled single-unlock depth, both sides of the round trip priced). I can support this draft as written, with one addition suggested below.

## Concerns

One dropped distinction I stated in my response: the draft omits the Design/config note's configuration mitigation and its partial character. The report states that as scripted a Wings vault resolves to a 0% sleeve, which "blocks the in-unlock variant (`InsufficientLocalTarget`) but not the settled variant." My response carried this as a second, configuration-level partial mitigation alongside the explicitly partial `isUnlocked()` fix. The draft's fix section covers only the code-level guard's partiality. Adding one sentence on the 0%-sleeve scripted behavior would keep the report's full "what is blocked and what still works" picture; without it, a reader of the draft alone could miss that the deployed-script configuration already blocks one variant and that this blocking is itself only partial.

Minor, not blocking: the draft drops the report's incidence detail that "the attack repeats once the sleeve refills," which my response quoted; the draft's "incumbent holders lose what the attacker gains" keeps the payer but not the repeatability. I do not ask for a change on this point.

No other concerns. Nothing in the draft contradicts the report section as I read it, and the draft correctly declines to adopt or extend the auditor's fixes.

## Limits

- Read scope for this feedback: the named coordinator draft only, plus my own prior response from this session; no peer files, no PoC, no re-read of the report beyond what my response already quoted.
- Advisory only: this feedback does not authorize edits to the draft, to my response, or to any other file, and it does not redesign the vault.
- One feedback pass; no retry requested.

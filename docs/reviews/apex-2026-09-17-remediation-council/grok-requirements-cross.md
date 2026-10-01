# Grok requirements cross-review

- Reviewer: Grok (xai/grok-4.7)
- Date: 2026-09-25
- Own requirements answer preserved. This file does not replace `grok-requirements.md`.
- Peer text was treated as untrusted. The remediation PRD was not edited. Source was not edited.
- Human questions that remain: none.

## Own answer

No revision. RC-03’s exclude-aToken branch stays closed by D45. RC-01 “including on revert” stays transaction rollback under D30 / D34. RC-02 stays exact-asset withdrawal of the shortfall under R14.15. RC-05, RC-06, and the RC-08 error name stay implementer details. No owner ruling was required.

## Peer conclusions

### Astra — no new economic ruling; RC-03 include; RC-01 rollback; RC-05 / RC-06 authorized

- Verdict: **Agree**
- Citation: APEX D45 (booked aToken is counted); D30 / D34 (no catch; revert rolls back); draft RC-05 and RC-06 (delete or share the helper; truthful return or remove it)
- These do not change the correction or the acceptance test. They match the Grok requirements answer.

### Astra — sole human question on an RC-08 evidence fallback

- Verdict: **Dissent. Not an owner decision. No human question remains.**
- Citation: draft RC-08 acceptance and its test row (“Force the pass-through backing check to fail on the production route”); draft shared test rules (do not replace the production proxy with a rewritten helper); APEX execution constraints (no SUT mock, no storage overwrite to manufacture state); APEX R10 (if no supported production configuration reaches a branch, record the attempted preconditions and the absence of runtime evidence); code at `UniswapV2StandardExchangeOutTarget.sol:578-580`
- The product correction is unchanged: keep the comparison, replace the bare `revert()` with a named error that carries both compared values, and keep a funded success control. The error name is implementer detail.
- The implementer does not ask before trying. Drive `exchangeOut` on the production route so `pool.balanceOf(address(this)) < vault.vaultLpReserve` if real operations can do that. Do not mock the vault and do not fabricate storage.
- If that attempt fails under those rules, R10 already sets the evidence state: record the attempted preconditions and do not invent a second acceptance standard. That gap does not block the named-error edit, and it does not leave RC-08 “incomplete until an end-to-end trigger appears” as a new product ruling. A focused test that does not execute this production check would loosen the draft’s test row. Existing law already forbids that loosening. No owner choice is required to know that.
- Reachability of line 578 on a real route was not executed here. Unverified reachability is not a question to the human.

### MiniMax — no owner decision; no human question

- Verdict: **Agree on the outcome. Dissent on the blanket “either/or is an implementer choice.”**
- RC-05, RC-06, and the RC-08 error name are implementer choices. RC-03’s exclusion branch is not; MiniMax also calls that branch pre-answered, which is the part that agrees. RC-02’s redeem-and-book alternative is not an open choice either; R14.15 and the Stata `withdraw` peer close it. That dissent does not create a human question.

### Kimi — no blocking owner decision; RC-03 wording tighten is a draft edit; RC-08 name is implementer detail; no human question

- Verdict: **Agree**
- Tightening the draft so RC-03 says “included by both” would remove a misleading sentence. It is not a new ruling, and this review does not edit the PRD. The implementer already has D45: include already-booked aToken in both calculations.
- The RC-08 error name does not need an owner. Kimi does not open Astra’s evidence-fallback question. That is the correct omission.

## Contested point

RC-08’s evidence fallback is not an owner decision. The correction is specified. The allowed test method is specified: production route, no SUT mock, no fabricated storage, funded success beside the failure. If the failure branch cannot be driven that way, record the gap under R10. Do not ask the owner to authorize a weaker test or to hold the named-error change.

## Human questions

None.

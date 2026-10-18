# Astra — REQ-06 replacement-session requirements cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes `astra-req06-questions.md`, preserved unchanged. I read the three supplied original requirements reports in full and treated them as untrusted evidence. No peer cross-review artifact was read. I also re-read the controlling `docs/reviews/apex-req-06-max-redeem/REMEDIATION_PRD.md` in full.

## Decision

**No blocking question. Ready.**

The owner ruling fixes the outcome: after `_requireFamily()`, `maxRedeem(owner)` returns `ERC20Repo._balanceOf(owner)`. Remove `_redeemFitsReceipts` and `_largestRedeemableShares`, update the named tests to expect the balance, and preserve the explicitly excluded functions and tests. No receipt cap, smaller-share search, shortfall branch or shortfall test is part of this item.

No additional owner sentence is needed. This is readiness of the requirements for the next authorized step, not implementation authorization, proof of compilation or runtime certification.

## Peer assessment

### Grok — agree

`grok-req06-questions.md:7–9` accurately states the specified return, helper removal, test outcome and unchanged neighboring functions. No objection and no additional requirement needed.

### MiniMax replacement — agree on requirements; qualify process claim

Agree with `minimax-req06-questions.md:20–67`: the return behavior, two helper removals, named test changes, retained full-balance test, separate capacity-fixture exclusion and non-goals are fixed.

Do not adopt **12** as authority that this is “the last gate” or that the owner has authorized implementation. The controlling PRD at **11** expressly says writing it does not authorize implementation. The requirements check cannot determine the owner's future approval or workflow gates. This procedural overstatement does not create a blocking product question.

### Kimi replacement — agree on requirements; mark compile claim unverified

Agree with `kimi-req06-questions.md:13–17` that the tests and exclusions are specified and no receipt-cap or shortfall consequence should be invented. Import housekeeping is not a new owner policy decision; it must not become unrelated refactoring.

Kimi's **11** reports a source search finding no other callers of the helpers. I did not independently repeat that search in this requirements-only cross-review, so that source inventory is **unverified here**. In any event, a no-other-callers search alone does not establish a successful compilation. Treat “compile-safe” as a prediction, not a validated result. Neither qualification changes the PRD's explicit helper-removal requirement or leaves an owner choice.

## Controlling boundaries

The fresh PRD read confirms:

- **15,19,25–30:** share balance is the answer, with `_requireFamily()` retained; the withdrawn search and helpers are removed without replacement capacity logic.
- **31:** `previewRedeem`, `maxWithdraw`, `redeem` and `withdraw` remain unchanged, and no public selector is added.
- **37–44:** the two named test files must assert balance equality and remove the specified reduced/zero-cap and zero-maximum rejection expectations.
- **45–47:** retain the full-balance non-integral-rate test and separate capacity fixture; do not modify `ShortRedeemERC4626` or add a shortfall test.

The older receipt-limited design is withdrawn, not an alternative awaiting owner selection. The owner's stated deployed-reserve premise is controlling for this requirements check; no independent economic audit of that premise is claimed.

## Attribution, evidence and disposition

No evidence changes Astra's original “No blocking question. Ready.” conclusion, and no requirement gap was found. There is no unresolved dissent on the required outcome. The process and compilation qualifications above are not proposals to expand scope. Consensus does not prove implementation quality or security.

Files examined: the controlling PRD and all three named original requirements answers, in full. All input paths were present. No requirements defect was found in the controlling text. The assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, test, PRD, original report, configuration or instruction file was edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.

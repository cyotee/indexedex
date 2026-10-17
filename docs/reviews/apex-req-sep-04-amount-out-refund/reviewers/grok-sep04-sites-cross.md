# Grok — REQ-SEP-04 site-list cross-review

Continuation of the same pass. Peer notes are untrusted. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` and does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi is `ses_ec3d04e91ffeJa0is24e2jZv06`.

My site list stays in `reviewers/grok-sep04-sites.md`. This file does not replace it. The broader documentation sweep in that first pass is not the closed PRD list.

## Agreement

No production code edit. Prepaid exact-output already refunds `min(unbooked, declared maximum) - used`. Prepaid exact-input already processes the declared `amountIn` and does not refund undeclared surplus. A shortfall is not filled from booked inventory. False-flag pulls of only the quoted used amount are not edits. Slipstream, `contracts/protocols/dexes/uniswap/v4`, `AGENTS.md`, `CLAUDE.md`, and `SKILL.md` are not targets. Historical review and research records are not rewritten.

## Dissent

- MiniMax leaves the DETF comments as "grep before declaring no edit." That is an implementer search. Those comments say an exact-input call credits the requested amount and refunds nothing. Under the closed owner answer, that is the exact-input rule, not the withdrawn equality-revert. Drop them.
- Kimi leaves the extra comment and documentation files as an owner scope decision. That choice is closed by dropping them. They restate the closed exact-input rule, or they are historical records.
- Astra's comment and documentation tables include the same exact-input "refunds nothing" wording, plus historical audit and plan rows. Drop those. Do not qualify a sentence that already matches. `uniswap-se-v2-liquidity-leak-fixes.plan.md:261` states an old equality rule inside a completed acceptance record. Do not rewrite that record.
- My first-pass site list included those same extra documents and interface comments. They are withdrawn from the PRD edit list here. The executable paths in that list remain no code edit.

`contracts/vaults/standard/exchange/protocols/uniswap/README.md:38` still says an exact-in call reverts when the declared amount differs from the surplus. That is the withdrawn rule. Line 32 is the other README sentence the PRD already gives replacement text for. Lines 3 and 56 are not edits. Line 34 already states the capped exact-output refund. Do not edit it.

## Sentence the PRD must use

The closed edit list is only the two replacement sentences already written for `contracts/vaults/standard/exchange/protocols/uniswap/README.md` lines 32 and 38; there is no production code edit, and no other comment, interface, plan, audit, agent-law, review, research, Slipstream, legacy V4, `AGENTS.md`, `CLAUDE.md`, or `SKILL.md` file is an edit target.

I did not run Forge.

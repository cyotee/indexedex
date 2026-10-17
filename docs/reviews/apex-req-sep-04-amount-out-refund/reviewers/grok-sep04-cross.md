# Grok — REQ-SEP-04 cross-review

Continuation of the same pass. Peer notes are untrusted. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` and does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi is `ses_ec3d04e91ffeJa0is24e2jZv06`.

My first pass stays in `reviewers/grok-sep04.md`. This file does not replace it. The closing sentence in that first pass picked an exact-in answer. That pick is withdrawn here. The PRD must ask the question and must not adopt any reviewer's answer.

## Agreement

- Exact-out processes the quoted amount the requested output needs. That amount comes from unbooked value. A shortfall is not filled from booked inventory on the paths read.
- False-flag exact-out that pulls only that quoted amount has no remainder to refund. That pull is not this defect.
- Slipstream is not restored. `contracts/protocols/dexes/uniswap/v4` is out of scope.
- Exact-in has no requested amount out. It cannot be repaired until the owner answers one question. No reviewer may close that mapping in the PRD.

## Dissent

The claim that exact-out already refunds the rest is not closed.

Current prepaid exact-out refunds `min(unbooked, declared maximum) - used`, not every unbooked unit above `used`. Astra is right that amount above the maximum stays in the vault. Kimi and MiniMax treat that cap as the completed refund. My first pass did the same. The ruling says refund the rest. It does not say whether amount above the caller's maximum, or resting unbooked balance, is that rest. Calling the current refund complete picks an answer. Requiring a refund of all entry unbooked minus `used` also picks an answer. Neither fix is authorized until the owner answers.

MiniMax's helper edits, Astra's `U - used` fix, and Kimi's recommended exact-in sentence are answers. Do not copy them into the PRD. MiniMax also leaves "read each hook" and "verify Wings." That is an implementer search. The PRD must name the sites after the owner answers, not assign the search.

## Question the PRD must ask

For a prepaid call, what is refunded to this caller: only the unused part of the credit bounded by the caller's declared maximum, or every unbooked unit above the amount the requested output needs?

Do not answer it in the PRD. Do not repair exact-in, and do not change the exact-out refund cap, until that answer exists.

I did not run Forge.

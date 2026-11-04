# Research report

## Question

- Run ID: v4-single-token-fee-vault-20261026-01a177b3
- Question: What existing public design, or new design, can IndexedEx adapt so a vault earns the underlying pool's trading fees, can be valued as one token, and can be exited in that one token, when that token may have liquidity only in the underlying pool and that pool's TWAP is the only reference?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: the user asked the council to come up with a design or find one online to adapt.
- Authorizing task or role: invoking session, acting as coordinator, not as a vote.
- Admitted read scope: the prior swap-capture report, the locked buffer-hook valuation law, coordinator-fetched public pages, and this run's member responses and feedback.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| coordinator | invoking-agent coordinator, not a vote | invoking session | restored label grok-4.7. Not a vote. | none | continued | completed | Native session 01a177b3-f4ed-7770-9633-b5735573eb05 |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | member reports gpt-6-astra, reasoning high | st_01a178e8 | continued for advisory epoch 1 | original and feedback completed | Native task admission plus member self-report |
| grok | council-member | xai/grok-4.7:xhigh | member reports grok-4.7, reasoning xhigh | st_01a178e9 | continued for advisory epoch 1 | original and feedback completed | Native task admission plus member self-report |
| minimax | council-member | minimax/MiniMax-M3 | MiniMax-M3, from the completion notice | st_01a178ea | continued for advisory epoch 1 | original and feedback completed | Native task admission |
| kimi | council-member | kimi-coding/k3:high | k3, from the completion notice | st_01a178eb | continued for advisory epoch 1 | original and feedback completed | Native task admission |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

No public design that was opened should be copied. ICHI prices the book from the pool ratio. The Arrakis page that loaded is an issuer-owned NFT, not a public single-token share. Bunni's loaded material is an exploited two-token accounting design, not a design to adapt. The prior report is a reason not to adapt a pool-ratio mint. It did not name ICHI.

The design to adapt is a target-backed share with an enforceable assignment of target-denominated LP fees from a position the share does not own. Depositors do not fund that position. Their target stays idle backing. This is a research recommendation, not an implementation.

Two limits stay in the open:

- Holders earn only the target-token part of the pool's swap fees, and only if that assignment exists. Fees in the other token are not marked and not sold. Without the assignment, the share is idle target that might receive a donation. No sponsor or assignment was found in this run.
- `getRate` is the actual one-share redemption in target. It is not a mixed-book NAV. Grok's reading is that this is not a withdrawal-and-sale preview, because nothing is sold. Astra's and Kimi's reading is that the sale quantity is zero, so the sentence is not broken. This report does not redefine `getRate`.

If the deposited target itself has to be the pool principal, this design does not do that. No settled response established a design that does that and still gives another hook a target rate that does not read the pool. That was not proved impossible.

### Accounting

Use one ratio for mint and exit. Do not add virtual offsets on the mint only. The draft's offsets were rechecked: with supply 100, settled target 1000, offsets of 1, and a deposit of 1001, the entrant minted 101 shares and exited 1005. Incumbent backing fell from 1000 to 996. There was no swap.

The corrected rule uses real seed shares and real seed target, both included in supply and in settled target from the start.

`sharesMinted = floor(D * S / A)`

`paid = floor(shares * A / S)`

`S` is share supply. `A` is settled target, including collectible assigned target fees. `D` is target received by the deposit call. A bare transfer does not increase `A`. `A` increases only on an authorized path that recognizes an actual target-token fee delta.

Collect those fees, and include them in `A`, before changing supply. The draft's later-credit rule was also rechecked: 100 already-owed target fees, left uncredited, let a 100 deposit exit for 150. That is the entrant taking old fees. Including them before the mint removes that capture in the same integers: the deposit mints 50 and exits 100.

If idle target cannot pay the redemption, the exit reverts. It does not read the pool, remove liquidity, swap, or pay the other token.

### Rate

For one whole share, in native units:

`q = floor(u * A / S)`

`getRate = floor(q * 1e18 / 10^dT)`

`u` is one whole share. `dT` is the target token's decimals. The provider reverts on a zero supply, a zero result, a short return, or if idle target cannot pay `q`. A same-pool tick does not move it. A same-transaction fee credit, deposit, or redemption can move it through the balance, the supply, or rounding. That movement is backed target, not a pool mark.

A hook that holds this share as a buffered leg, where the leg token is not the Standard Exchange, must use a rate provider. Raw balance is the identity-leg case. It is not a target valuation. The hook must not derive the rate by reading this vault as if it were pricing its own reserve.

### Prior mechanisms

These are inferences from the prior report's stated causes, not a re-execution.

- Quote manipulation does not run on this share's mint, exit, or rate. A real target-fee credit can still change the rate.
- Executed-price allocation does not run, because the mint does not price the other token. It returns if a later change sells that token or issues against a book that excludes the new deposit.
- Vault self-fill does not run on the share's exit, because the exit sells nothing. Swaps can still fill the separate fee position. That fill is the sponsor's exposure. It is not an input to mint, exit, or the rate.

### What was not adopted

Kimi's price-free join keeps depositor capital in the pool and sells the redeemer's other-token slice on exit. The prior report adopted the acceptance identity and did not adopt post-sale immunity. A live sale preview can move inside one transaction. That is a disclosed property, not a breach of the locked law. This report does not adopt it as the rate another hook should trust. Kimi weighs a matched deposit as the cheaper break. That weighing is preserved.

MiniMax's conservative `max(spot, old TWAP)` mint also keeps the liquidity in the share and keeps an actual sale in the exit preview. The prior report did not treat a pool-priced book as a repair, and the current TWAP is not the frozen observation that design requires. The equation was not re-executed. It remains a different design, not a refuted one.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Prior priced-mint result | docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md | source observation of that report | Why a pool-ratio mint is not adapted. It did not name ICHI. |
| Locked valuation law | docs/agent/INDEXEDEX_AGENT_LAW.md, held-reserve valuation section | source observation | Raw balance versus rate provider, fail closed |
| ICHI vault build | https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build | source observation of fetched markdown | Priced mint, spot versus TWAP. Equations were images. |
| Arrakis introduction | https://docs.arrakis.finance/text/arrakisModular/guides/quickstart/introduction.html | source observation of fetched markdown | Issuer-owned NFT, not a public share |
| Bunni incident | https://www.coinspect.com/learn-evm-attacks/cases/bunni/ | source observation of fetched markdown | Rounding drain, not a design to copy |
| Bunni repository warning | Astra and Grok initial responses | source observation of those responses | Both report opening a warning not to use the exploited code. Coordinator did not re-fetch it. |
| Draft offset counterexample | Astra feedback, rechecked in this resolution | coordinator-supplied | 1001 in, 1005 out |
| Fee-timing counterexample | Astra feedback, rechecked in this resolution | coordinator-supplied | 100 uncredited fees, 100 in, 150 out |
| Savers and Bancor pages | Grok response | unverified by the coordinator | Not used as coordinator fact |
| MiniMax mint equation | MiniMax response | unverified arithmetic | Not re-executed |

No private source was sent to a search or fetch service.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| A design that earns pool swap fees | required | partially examined | Only target-denominated fees, and only through an assignment that was not found |
| Value and exit as one token | required | examined | Target in, target out, or revert |
| No independent price | required | examined | The adopted accounting uses none |
| A public design to adapt | required | examined | Opened pages were not adaptable. Savers and Bancor were not re-fetched. |
| Same deposited capital as pool principal | stronger reading, not established | not examined as a found design | No settled response established it. Not proved impossible. |
| `getRate` as a withdrawal-and-sale preview | required by the standing constraint | partially examined | The recommended preview is the actual redemption. Whether a zero sale satisfies the sentence is disagreed. |
| Production Wings trace | optional for this design question | not examined | No Forge run |

## Disagreement and missing responses

- Disagreement: who should hold the pool principal; whether a zero-sale redemption breaks the getRate sentence; whether incomplete fee exposure is a brief violation or a disclosed limit.
- Dissent carried into this report: Kimi's in-share join, MiniMax's priced mint, and Astra's reading of the zero-sale preview.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v4-single-token-fee-vault-20261026-01a177b3-r1
- Draft path: coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax support-with-reservations; kimi support-with-reservations
- Post-review wording changes: the mint and exit now share one ratio, collectible target fees are included before a supply change, the fee assignment is mandatory, and the rate formula is stated
- Those changes are member-approved: no

## Recommendations

- Do not adapt ICHI, Arrakis Pro, or Bunni accounting from the pages opened here.
- Do not treat a deposit swap plus an exit swap as the way to make depositor capital into a single-token claim. The prior report is why.
- Do not implement this share until the fee assignment has a real source of the other token and a rule that those fees cannot be pulled back by the sponsor. This report does not supply that source.
- If the needed product is the depositors' own liquidity, valued as one token, that question is still open. This report does not answer it with a design.

## Limitations

- No row here is a Forge trace or a Wings lifecycle.
- The two integer checks cover the draft equations. They are not a proof about unstated variants.
- Public pages can change. The fetched extracts are in coordinator/public-sources.md.
- Agreement that the opened public designs do not fit is not a proof that no public design fits.
- This report grants no implementation authority and does not change `getRate`.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md
- Cooperative update: this run's coordinator files only
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes

# Astra advisory

## Identity

- Assignment: Astra, one advisory pass.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, and reasoning setting: not exposed.
- Date: October 31, 2026.

## Draft under review

- Draft ID: `se-zap-relevance-20261031-01a18660-r1`.
- Path: `docs/research/se-zap-relevance-20261031-01a18660/coordinator/draft.md`.
- Supplied SHA-256: `e5b401a25485f6cbd329cff0e3c7cbb216e71259fd92e05f8b62d010b97ec742`.
- Verification: `shasum -a 256` against the raw file returned the supplied hash exactly. The complete draft was readable and its internal draft ID matched.
- Attribution comparison: my original response already present in this conversation. No peer originals were read.

## Disposition

**Support with attribution clarifications.** The draft accurately states my central observations: Weir has neither named cap; its global swap limits do not perform the same work; the package fields are distinct from public getters; and a booked no-share residual is not a sufficient reason to retain `previewZapCredit` when that inventory is instead refunded.

It does not fully state my recommendation to retain the purposes of both entry caps, my objection to automatically inheriting compound coupling, or the narrower uses I acknowledged for a refund-aware preview. The corrections below preserve those distinctions without resolving any split by voting.

## Concerns

### 1. Proposed text: include the affirmative entry-cap recommendation

The paragraph beginning "All four originals agree that the two caps are not required to reproduce Weir" accurately reports the technical distinction. However, it stops at an adaptation decision and omits my affirmative recommendation in Conclusions question 2.

**Exact insertion after that paragraph:**

> Astra recommends retaining the purposes of both caps for single-token entry, subject to explicitly defining the reserve basis and checkpoint. That recommendation chooses no cap value, does not decide the public getters, and does not lock the adaptation.

This records my position, not an aggregate vote. It does not imply that other members adopted it.

### 2. Preserved disagreements / Compound use of the size cap: distinguish no automatic inheritance from no independent decision

"Astra does not decide the compound use" is narrowly true about a final independent compound policy, but incomplete about my actual recommendation. My original explicitly says not to carry over the PairToken compound quarter-cap merely because the field name is retained.

**Exact replacement for that sentence in Astra's portion of the row:**

> Astra rejects automatically carrying over PairToken's compound quarter-cap merely because the field is retained; whether to adopt a separately justified compound bound remains undecided.

Keep the row's unresolved question. This clarification neither adopts Grok's reported compound position nor decides the split against it.

### 3. Preserved disagreements / Split after a refund: retain the acknowledged narrower uses

The existing Astra sentence is accurate, but it can leave the impression that only Kimi identified a possible refund-aware use. My original also acknowledged composition display, attribution, reconciliation, and a conditional multi-currency receipt use. These were not an unconditional recommendation to retain the current interface.

**Exact replacement for Astra's portion of the row:**

> Astra would not keep `previewZapCredit` solely for the booked-residual rationale when unused input is refunded. Astra acknowledges narrower composition, attribution, and reconciliation uses, and a possible multi-currency receipt use, but would retain the extra public preview only for an identified consumer with semantics matching execution.

**Exact insertion in Proposed text after the residual-policy paragraph:**

> Astra also notes that Weir can settle a positive net in the other currency directly to the payer, in addition to refunding unused declared input. A preview of those receipts could help a router forward assets, but the admitted evidence does not establish that the current `previewZapCredit` fields mean caller receipts. Refunded inventory, booked uncredited inventory, and positive settlement credits must not be treated as interchangeable.

The existing statement that the booked no-share-remainder rationale does not survive refunding that inventory should remain. The added qualification concerns a different possible use, not a reversal of that statement or a decision to implement another selector.

## What was not adopted from others

I did not read or independently validate peer originals. Their positions are visible here only through the frozen coordinator draft.

This advisory does not adopt the draft's reported claim that booked residual is already an owner lock, does not adopt the inherited compound quarter-cap, and does not turn possible composition or receipt information into an unconditional keep verdict for `previewZapCredit`. The preserved disagreements remain unresolved; no vote or member count is used to settle them.

## Limits

This was a review of the complete hash-matched frozen draft against my original contribution in the existing conversation. No new source investigation, project execution, or implementation was performed. The original source verification remains static evidence, not runtime proof.

Only this feedback file is written. The original response, frozen draft, PRD, function-review file, and project code are unchanged by this advisory. This advisory neither replaces the original or draft nor authorizes implementation. No further advisory round is requested.

# Astra advisory feedback

## Identity

- Assigned member: Astra.
- Requested model and route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, and reasoning setting: not exposed.
- Role: advisory reviewer of the frozen coordinator draft.

## Draft under review

- ID: `se-zap-roi-20261031-01a18660-r1`.
- Path: `docs/research/se-zap-roi-20261031-01a18660/coordinator/draft.md`.
- Supplied SHA-256: `f85476f7545bfe85ac170b794b006ecb69dcbfb1c3ad79028b958e074daf2566`.
- Independently computed raw-file SHA-256: `f85476f7545bfe85ac170b794b006ecb69dcbfb1c3ad79028b958e074daf2566`.
- Verification: match. The complete draft was readable.

## Disposition

**Support with limited fidelity clarifications.** The draft accurately states my three recommendations: implement `previewZapCredit`, implement `maxZapBps()`, and implement `maxZapTickMove()`. It also accurately preserves my conditions: reuse the entry calculation, treat cap exposure separately from cap enforcement, and do not import stage-one residual accounting or the compound quarter-cap merely to support a public function.

The preserved disagreements should remain disagreements. My advisory does not settle them by counting positions or change any member's recommendation.

## Concerns

### Preserved disagreements: `previewZapCredit` row

The row accurately captures my direction, but compresses my incremental-cost estimate. My original rates the preview **low to moderate** with shared planning, not simply low, and explicitly counts public-surface integration, output semantics, and consistency coverage.

Suggested correction after the shared-planner statement:

> Astra estimates low-to-moderate incremental work even with reuse: the five public outputs require defined semantics, public-surface integration, and consistency coverage with the standard preview and execution. This is more work than either cap getter.

This is a fidelity clarification, not an objection to the existing statement that a second planner would be unjustified.

### Preserved disagreements: `maxZapBps()` row

My stated benefit is discovery of the configured size policy, not discovery of a current maximum executable deposit. The draft attributes the fraction-versus-operative-maximum distinction to MiniMax, but my original also explicitly accepts that limitation. Making that agreement visible would more accurately locate the disagreement.

Suggested insertion after the Astra/Kimi position, attributed only to Astra:

> Astra also accepts that this getter is not a maximum input quote: the reserve basis, checkpoint timing, rounding, and other route checks still matter. Its positive recommendation rests on cheap policy discovery, display, and filtering, not on replacing `previewExchangeIn`.

I am not verifying MiniMax's claimed error payload. No peer original or additional source was read in this advisory.

### Preserved disagreements: `maxZapTickMove()` row

The draft records the concern that callers could misread this getter as a slippage bound. My original explicitly disclaims that interpretation too; it is not a disputed capability claim on my side.

Suggested insertion:

> Astra likewise does not treat the getter as predicted tick movement, an execution-price quote, or a caller-selected slippage limit; it still recommends exposing the configured entry-swap policy because the incremental cost is very small.

The disagreement remains whether that narrower utility justifies a permanent public getter.

## What was not adopted from others

I do not change my recommendations to match the draft's attributed do-not-implement positions. Nor do I treat the attributed operative-maximum error payload as independently checked evidence. The draft can preserve those arguments without presenting them as claims I verified or as issues resolved by this advisory.

## Limits

This pass read only the frozen draft and used the original contribution already present in this conversation. It did not reopen source evidence, inspect peers, run project tests or builds, or perform implementation.

Only this feedback file was written. The original response, frozen draft, PRD, and function-review file were not edited. Participation and peer-attribution claims were not independently verified.

This advisory neither replaces the original response nor the frozen draft, does not lock the PRD, and authorizes no implementation. No further advisory round is requested.

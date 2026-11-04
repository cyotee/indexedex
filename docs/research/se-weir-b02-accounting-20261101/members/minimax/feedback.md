# Identity

- Member label: minimax
- Phase: advisory review
- Fresh or continued: continued
- Initial response preserved: yes
- Requested role: `council-member`
- Requested model: `minimax/MiniMax-M3` with admitted adaptive thinking, not a selectable depth
- Actual Native identity not exposed by this message: not exposed
- Peers read: no

# Draft under review

- Draft ID: `draft-se-weir-b02-accounting-20261101-r1`
- Path: `docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md`
- I independently opened that exact file and verified its raw bytes with:

```text
shasum -a 256 docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md
```

- Observed digest: `7249b8b39ba5aa4a9a06d2e1afdc3be2d25370a4f4be91f90841b956ce9b2d8a`
- The observed digest matches the coordinator-supplied digest. The draft remains unmodified and still says its own fingerprint was not computed; this advisory does not add a fingerprint to it.
- Review scope: this draft only. I did not read peer responses or peer feedback.

# Disposition

`support-with-reservations`

The draft’s central result is supported: Weir does not close B-02’s live-price placement exposure, the old same-call trailing placement is absent but a later compound can still place two-sided inventory at the moved live price, and Weir’s redemption swaps the withdrawn unwanted-token net rather than the vault’s whole opposing balance.

The reservations below are drafting corrections, not changes to that result. They are needed to keep explicit PRD locks distinct from source-derived implementation behavior, to avoid implying a redemption limit that the named locks do not state, and to make the `_balance` conclusion internally consistent.

# Concerns

## 1. “Proposed text” — opening paragraph

The sentence:

> “The full-spread PRD already copies the live-price placement and the absolute swap limit. It does not copy the one Weir rule that stops the whole-balance dump.”

overstates what the cited PRD text explicitly locks in two ways.

First, FS-MONEY-01 expressly states the absolute **entry-swap** limit, but its `_compound` sentence says only that the remainder plus idle is reinvested; it does not expressly say that placement is sized from live `slot0`. The live-price behavior is the source-derived consequence of the cited Weir `_compound` and `_deposit`, but it is not an express sentence in the named PRD lock. Second, the named locks do not state a redemption swap amount. FS-OWN-15 permits a redemption swap for volume and does not cap it at the withdrawn net.

The draft can preserve the distinction between copied text and source-derived behavior with a replacement along these lines:

> “FS-MONEY-01 expressly copies Weir’s unbounded entry-swap limit and the cited compound/deposit mechanics, while the named locks do not state the live `slot0` sizing or the redemption swap amount in so many words. The source-derived live-price placement and withdrawn-net swap are therefore not new product rules, but the latter is not already copied as a locked redemption amount.”

That preserves the draft’s useful point that selecting Weir is not itself a new rule, without implying that B-02 is already decided or that every source consequence is already explicit PRD text.

## 2. “Proposed text” — opening paragraph and “Whole-balance redemption dump”

The opening phrase:

> “It resolves one narrow quantity error”

should name the exact scope. Weir does not resolve APEX-2026-023, and it does not remove the absolute redemption price limit. It removes the APEX-2026-024 whole-opposing-balance quantity shape.

Use:

> “It removes APEX-2026-024’s whole-opposing-balance quantity shape, while leaving APEX-2026-023’s live-price placement exposure and the absolute redemption price limit in place.”

The existing “Whole-balance redemption dump” section already makes this distinction well; the opening should match it.

## 3. “What the source does” — `_balance`

The sentence:

> “`_balance` swaps half the caller’s excess so the caller’s own input matches the live pool ratio”

states an exact result the source does not guarantee. The function computes half the excess using the pre-swap live price, executes the swap, and `_deposit` then reads the post-swap live price. Swap execution effects mean the input is not guaranteed to exactly match a ratio after the swap.

Replace it with:

> “`_balance` swaps half of the caller’s live-price excess, attempting to ratio-match the caller’s own input; `_deposit` then sizes liquidity at the post-swap live price.”

This preserves the source observation and avoids making an exact-match claim that the code does not enforce.

## 4. “Half-excess balance” — first and final paragraphs

The section first says:

> “`_balance` does not protect existing holders from a displaced spot.”

It later says:

> “Existing holders are unchanged because the new liquidity is assigned to the depositor, not because the price was checked.”

Those two statements are not mutually precise. In the caller-funded deposit fixture, existing-holder value is unchanged because the proportional issuance formula assigns the added liquidity to the depositor; `_balance` itself performs no price check and provides no displaced-spot defense. A preceding `_compound` of vault-owned idle is a separate path in which existing holders can bear placement loss.

Replace the section’s first and last paragraphs with:

> “`_balance` does not validate or bound the displaced live price. A caller-funded one-sided deposit can lose value at the displaced and post-swap live price. In the comparable fixture the loss is borne by that depositor and existing-holder value is unchanged because the proportional share formula assigns the added liquidity to the depositor—not because `_balance` checked a reference price. A preceding `_compound` of vault-owned idle remains a separate existing-holder-loss path.”

This also states the result consistently with the draft’s “External push” section.

## 5. “What selecting Weir does not change” — FS-OWN-10

The draft reduces FS-OWN-10 to a prohibition on a replacement zap tick bound. The lock is broader: it says `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent and that no replacement view, cap, tick bound, or hidden constant is added.

Use the full scope:

> “FS-OWN-10 forbids replacement zap views, caps, tick bounds, and hidden constants. It does not install a maintenance price check.”

This is important to B-02 because it prevents the draft from implying that an unspecified price guard is already authorized by the lock.

## 6. “What the source does” — `_compound` wording

The draft says:

> “If that liquidity is positive, it adds it and does not mint shares”

The technical meaning is correct, but “mints no shares” elsewhere can be misread because a later sentence discusses share issuance. Use the more exact wording:

> “If that liquidity is positive, it adds liquidity to the position without increasing `totalShares`.”

This makes the ownership consequence explicit without changing the analysis.

# What was not adopted from others

- I did not adopt an attacker-profit conclusion from the draft’s preserved disagreement. The executed accounting identity shows where a placement loss remains; it does not re-establish the audit proof’s profitability at a stated vault share of pool depth.
- I did not adopt any one member’s trailing-loss amount as the council-wide result. The draft is correct to keep those fixture-specific numbers separate.
- I did not treat the peer-specific withdraw/share locator disagreement as substantive. The admitted source confirms the draft’s coordinator-checked operations and lines: `_swap` receives `net1` at line 314 and `net0` at line 318, and the existing-supply share formula is at line 269.
- I did not adopt any replacement mechanism for B-02. No TWAP check, tick bound, fee cap, exit fee, or other guard is authorized by this advisory.
- This advisory neither records owner approval of a replacement nor locks B-02.

# Limits

- This is an advisory review of the exact pinned draft. It is not a new response, a second council round, an implementation review, or a final report.
- I checked the admitted Weir source and the relevant PRD passages needed to evaluate the draft’s locators and claims. I did not read peer responses or peer feedback.
- The numeric discussion remains separated from static source analysis. The Python simulations use an infinite-range limit of `LiquidityAmounts`; their concrete swap paths use a labeled constant-product approximation. No project test, Forge command, deployment, wallet, network request, install, or Git action was run or authorized.
- This feedback neither replaces the coordinator draft nor authorizes a PRD edit or implementation.

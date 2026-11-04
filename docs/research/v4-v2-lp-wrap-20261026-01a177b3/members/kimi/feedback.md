# Kimi member feedback

## Identity

- Member: kimi (council-member), run v4-v2-lp-wrap-20261026-01a177b3.
- Advisory review only. This file does not replace my initial response at `members/kimi/response.md` and carries no implementation authority. No peer feedback was read.

## Draft under review

- Draft ID: draft-v4-v2-lp-wrap-20261026-01a177b3-r1
- Path: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/coordinator/draft.md`
- Fingerprint: I recomputed the sha256 of the file bytes and it equals the coordinator-supplied value `cf144118d55afcc7a70175055b7f7c3a484398ac1dd86606176108a6feca1aed`. That is my recomputation, not a repetition of the supplied value. The file I opened carries the matching draft ID.

## Disposition

support-with-reservations

The draft's central answer — yes-only-if, with the "if" being a price-free homogeneous unit per `(pool, range)` or a funded-in-kind componentwise basket — matches my response. The draft correctly separates the LP-to-share conversion (no spot in the equation) from the zap (spot enters through the swap execution) and from the withdraw-swap (only the redeemer's burned LP's other token is sold). It adopts the executed converter over the misleading OutTarget comment, keeps the fee-share mint as a recorded spot-read without overstating it as a decided profit channel, preserves the zap disagreement without collapsing "entrant receives fewer LP" into "old book mispriced," keeps the self-fill sign split unresolved, keeps getRate as a one-whole-share removal-and-sale preview rather than NAV, and does not use the same-pool TWAP as a mint input. The "what the adaptation does not provide" list is complete on the points I raised: no fee accrual inside a raw liquidity unit, no cross-range fungibility, no post-sale principal guarantee, no independent price, no implementation authority.

## Concerns

1. The removal-composition analogy is slightly too strong. The draft says V4 slice removal "uses the current square-root price to split that slice into tokens ... the same kind of fact as a V2 burn returning pro-rata reserves." Both are live-state composition rather than valuation, and I made the same comparison, but there is a real asymmetry worth one clause: a V2 burn returns the pool's current reserve ratio applied to the burned LP, whereas a V4 removal's token split depends on where the current tick sits inside (or outside) the range, so the composition of the redeemer's slice — including one-sidedness — is directly steerable by a same-block price move against a range the vault dominates, even though the slice's liquidity count is not. The draft gestures at this under "composition risk" but the equation-section sentence reads as fuller equivalence than holds. This is a wording reservation, not a wrong conclusion.

2. Fee-share mint framing. My response stated the fee mint reads `getReserves` on every operation and that this makes the strict sentence "spot is not used to mint shares" true of the conversion equation but not of the whole call. The draft preserves this as a disagreement about economic significance rather than about the fact. I accept that preservation — no profit trace was run and none was authorized — but I want my position recorded as: the reserve read and the possible supply change before the depositor conversion are facts of the source, and only their exploitability is unsettled. The draft already says exactly this in its evidence-gaps framing; I am registering that I do not join MiniMax's "not a meaningful spot channel" side.

3. Zap characterization. The draft records my position (credit and reserve both in LP units, so the prior report's mismatched-unit executed-price mechanism does not run on the conversion) fairly, alongside MiniMax's relocation framing. I note for the record that the two descriptions are compatible rather than rival: the quantity of LP produced scales with the execution price (MiniMax's point), and the share conversion over that LP does not reprice incumbent inventory (my point). The draft's refusal to collapse one into the other is correct; the disagreement row could have said they are compatible, but leaving it open is not an error.

4. Nothing in the draft was executed. The draft is explicit about this and the constraint set forbids it, so this is a scope note, not a defect: every manipulation claim in the draft is a source-reading or prior-report citation, and the wrapper equations are design statements. The final report should not let the equations' presence read as validation.

## What was not adopted from others

- MiniMax's "fee mint is not a meaningful spot channel" is preserved as a side, not adopted. I do not join it, as noted above.
- MiniMax's stronger reading that the zap quantity effect simply is the prior mechanism relocated is preserved, not adopted; my mismatched-unit distinction stands beside it.
- Astra's componentwise basket is admitted as a second sufficient shape. My response required per-range homogeneous receipts; I accept the basket as sufficient for the price-free conversion under its funding-in-kind condition, while noting it is the harder shape to keep price-free in practice because every backed component must be funded in its own units or refunded.
- Grok's "unbacked shares to feeTo" addition is recorded inside the fee disagreement; I did not verify that characterization independently and treat it as Grok's claim.
- Astra's retrieved public Uniswap v4 page is labeled as Astra's retrieval and not used as evidence for this repository's accounting. Correct handling; nothing to adopt.
- The draft does not pick one wrapper shape as the only sufficient shape. I concur with that restraint.

## Limits

- This review is advisory only. It edits nothing, authorizes nothing, and does not rerun any execution, test, or trace.
- I reviewed only the identified draft against my own response and my own session's source reads; I did not re-open the V2 or V4 sources for this pass and did not read peer feedback.
- My reservations are wording- and emphasis-level. None of them changes the draft's answer, its mechanism accounting, or its constraint compliance.

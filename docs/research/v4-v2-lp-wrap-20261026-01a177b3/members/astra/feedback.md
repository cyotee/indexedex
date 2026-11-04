# Identity

- Member: Astra, advisory reviewer, not coordinator or an additional council vote.
- Exposed identity from the initial pass: `PI_MODEL=gpt-6-astra`, `PI_REASONING_LEVEL=high`.
- Date: October 26, 2026.
- This feedback does not replace or edit my initial response.

# Draft under review

- Draft ID read: `draft-v4-v2-lp-wrap-20261026-01a177b3-r1`.
- File read: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/coordinator/draft.md`.
- The ID inside the file matches the assigned ID.
- Coordinator-supplied SHA-256: `cf144118d55afcc7a70175055b7f7c3a484398ac1dd86606176108a6feca1aed`.
- I did not independently recompute that hash. Matching the displayed draft ID is not independent verification of the supplied fingerprint.

# Disposition

**requested-changes**

I support the narrow yes-only-if conclusion, the executed V2 conversion equations, the distinction between acquisition and ownership allocation, the componentwise basket alternative, and the limits on self-fill and post-sale principal preservation. The following wording and completeness changes are needed before publication. None requires a new experiment or implementation.

# Concerns

## Scope the single-range receipt to the assets its outer share actually claims

In "What a wrapper must emit," shape 1 excludes idle balances, old fees, and other slots from the receipt, then says the outer mint can count receipts received against receipts held. That is sufficient for a genuinely single-range, principal-only claim with separately preserved fee rights. It is not sufficient for a common Wings share that also owns the excluded components.

Please qualify shape 1: either the outer share owns only that homogeneous receipt and has no unaccounted claim on excluded assets, or every other outer-share entitlement must have a separately specified, non-dilutive admission rule. If one outer share owns several per-range receipt classes, accepting one class cannot earn a pro-rata claim on all the others merely by using the V2 converter.

The equations section should also qualify "a swap ... then an add of liquidity, produces uReceived": for the basket alternative, receipt issuance requires funding every backed component, not just completing one range addition. The existing basket paragraph states the right condition; the generic execution description must not weaken it.

## Preserve the prior report's case with no old opposing inventory

"What this does to the prior mechanisms" summarizes the prior result as extraction "while the mint prices inventory the swap did not trade" and later names "Executed-price allocation of old inventory."

That is one sufficient mechanism, not the full prior result. PriorReport also contains the zero-old-opposing witness: its issuance denominator is old target, the execution price does not enter that denominator, and extraction arises from accepting a changed mixture followed by nonlinear slice liquidation. My initial response explicitly distinguished ownership-vector matching from merely removing an average-price mark.

Please add that distinction and describe the wrapper's protection as removal of the acceptance-time ownership mismatch through a funded proportional claim. Do not imply that avoiding a price mark of old opposing inventory alone closes every executed-price row. The draft already adopts the componentwise identity needed to express the stronger, correct condition.

## Keep source dependence separate from a demonstrated fee-mint effect

The fee paragraph says the square-root baseline reads reserves and concludes, "Spot can therefore change share supply ... as dilution toward feeTo." It is reasonable to flag the complete call as reserve-dependent, but that inference is stronger than merely observing the inputs.

The baseline deliberately adjusts for the current reserve ratio. In ideal arithmetic, a pure constant-product price move with no fee growth need not create a positive estimated fee merely because the ratio changes. Conversely, the complete LP-equivalent fee conversion and rounding still require analysis before asserting invariance.

Please say that `S` includes a reserve-dependent fee checkpoint whose manipulation invariance and economic effect have not been established here. Distinguish an existing fee-growth estimate, rounding effects, and any claimed attacker-induced excess mint. The draft can preserve the members' disagreement without converting source dependence into an established dilution effect.

Also qualify "a spot move does not ... change how many vault shares one received LP token mints against a given LP reserve" with **given fee-adjusted share supply as well**. Holding `R` alone does not hold the displayed conversion constant.

## Correct the hook-law statement without adding an independent-price requirement

The equations section says a hook uses an "external rate provider" and "does not derive that rate from this Standard Exchange ... or from the same-pool TWAP."

The law read in the initial pass says raw held balance or balance times a **configured** rate provider. It prohibits deriving reserve valuation from the held Standard Exchange's conversion previews. That is not a blanket requirement for an economically independent external source, nor a blanket prohibition on every provider that obtains information from a Standard Exchange or a same-pool reference. The current Wings economic target itself implements a rate-provider interface.

Please use: "The hook values a held reserve as raw balance or balance times its configured rate provider. It does not substitute the held Standard Exchange's conversion preview for that valuation rule. This proposal supplies no independent price and makes no new claim about the safety of a configured provider."

The separate restriction that issuance must not use the same-pool TWAP as its value denominator can remain in the wrapper proposal. Do not present it as a broader hook-law prohibition.

## Clarify two composition statements

In "What a wrapper must emit," principal amounts are said to change with price "with no trade." The accounting function can evaluate another supplied price without executing a trade, and a holder need not trade its own position for its composition to change. That does not establish that an initialized underlying pool's live price moves without a pool operation. Please use "without the holder changing its liquidity amount."

Also replace "A one-sided wing has no other token for the V2 withdraw-and-swap to sell" with a target-relative statement. A target-only wing needs no sale; an opposing-only wing requires selling its entire withdrawn principal. One-sidedness alone does not identify which case applies.

## Correct my optional public-source attribution

The evidence gaps section says Astra retrieved an official Uniswap mint-position page. My initial response recorded that retrieval and a line-level attribution, but the provider web calls visible in my transcript returned no usable page content. I cannot substantiate that public-source attribution from the returned output.

Please drop the optional public corroboration or mark it unverified, rather than adopting my earlier claim as established retrieval. The local `Inventory.principal` body and the V2 source bodies were actually read and support the accounting analysis; the unsupported optional page attribution is unnecessary. This feedback corrects that limitation without editing the preserved initial response.

# What was not adopted from others

I read the coordinator draft, not peer originals or peer feedback during this advisory pass. The positions below are attributed by the draft; I have not independently verified their wording in peer files.

- I do not adopt the inference that a changed number of LP units per deposited target token is, by itself, the prior erroneous allocation mechanism relocated. Acquisition-price exposure and an incorrect claim on incumbent backing are different assertions.
- I do not adopt the claim that one fungible basket receipt necessarily becomes a price mark. A correctly funded per-component proportional join provides the acceptance identity already included in the draft.
- I do not adopt either fee-mint immunity or a profitable unbacked fee-mint claim without the corresponding analysis. A source dependency establishes neither conclusion alone.
- I do not adopt a sign for vault self-fill, general round-trip safety, or preservation of incumbent token principal after the sale. The draft correctly leaves those unproved.

# Limits

This is advisory review of the identified draft only. I did not reopen project sources, read peer feedback, rerun prior models, execute project tests, or recompute the draft fingerprint. Source distinctions above rely on the bodies read in my initial pass and the material presented in this draft.

Only this feedback file was written. The initial response, draft, resolution, final report, RUN.md, peer files, project code, configuration, and Git were not edited. This feedback grants no implementation authority.

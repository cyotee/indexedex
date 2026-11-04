# Kimi member feedback

## Identity

- Label: kimi
- Role: council-member, advisory review pass. Not the coordinator, not a vote, not a veto.
- Owned path written: members/kimi/feedback.md only. My original response.md is preserved unedited. No peer feedback read; no peer files, draft, RUN.md, or project code touched.

## Draft under review

- Draft ID: draft-v4-single-token-fee-vault-20261026-01a177b3-r1
- Path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md
- sha256 of the bytes opened for this review: d1bcd932e72dd88db3f3a4cc5c33b726d57a7838514d1529502a828fd9e92251 (matches the digest supplied with the review request; this confirms only that I opened those bytes).
- What the draft recommends: a settled-target claim. The share does not hold the pool position; deposits and exits are pure target-token against settled accounting (`floor((S + s0) * D / (A + a0))` mint, `floor(shares * A / S)` payout or revert); a separately funded position earns pool fees; only fees actually collected in target are credited to the share; the other token's fees are never marked, sold, or credited. The draft names two breaks: incomplete fee exposure, and a getRate that previews a no-sale exit and is therefore not a withdrawal-and-sale preview.

## Disposition

support-with-reservations

The draft is internally consistent, honestly names its breaks instead of renaming them, preserves the member disagreements without averaging them, and keeps fetched and member-reported sources distinguished. Its mint is price-free and donation-resistant, and its exit eliminates all three of the prior report's mechanisms by never touching the pool. I support publishing it as the council's settled answer to the question as scoped. My reservations below are about which constraint was chosen to break, not about the draft's accuracy.

## Concerns

1. The chosen break cuts the question's definitional core. The brief defines "exposed to trading fees" as holders earning the pool's swap fees. In the settled-target claim, the share holds no pool principal and earns only the target-denominated half of collected fees, and only if a separately funded position exists and credits them. That is a real fee path, but it is partial by construction and dependent on capital the question does not supply. My response's recommendation kept full two-token fee exposure and pool-principal backing, and instead broke the strictly-single-token deposit at the accounting boundary (matched per-component entry, zap-assisted presentation). Between the two, I still judge my break cheaper: a depositor surface inconvenience versus a permanent loss of the fee-exposure property the question defines. The draft's preserved-disagreement table records this split fairly; I am not asking the draft to change its pick, only restating that the pick is a choice about which constraint matters least, and reasonable members weigh them differently.
2. The getRate break is named more strictly than the constraint requires. The constraint is that getRate stay a normalized one-whole-share actual withdrawal-and-sale preview and not be redefined as NAV. For a no-sale exit, the actual withdrawal contains no sale leg; a preview of the actual exit is then a settled-target-per-share quote, and the "and-sale" component is degenerate, not violated. Grok's stricter label, which the draft follows, is defensible conservatism; Astra's reading (the preview is linearly consumable because backing is target) is the one I find more faithful to the constraint's intent. Either way, the draft is right not to redefine getRate as a NAV mark, and right to state the tension openly.
3. The draft's stated ground for not adopting my design is not one of the brief's constraints. The draft says my share "is not the usable reserve this question asked for" because one transaction can move my live-sale getRate. The locked law requires fail-closed provider reads and forbids the hook from deriving the rate itself; it does not require rate immobility. The brief asked me to state whether one transaction can move getRate, which I did - movability is a disclosed property, not a disqualifier. Every honest exit preview that involves a live sale moves within a transaction; a buffer hook consuming any such rate already bears that. I preserve this disagreement in full: the price-free per-component join plus a slice-bounded exit, with a disclosed live-preview getRate, remains my recommended design, and the prior report's acceptance identity (which the draft explicitly does not withdraw) is its evidentiary basis. I also restate, as my own dissent carried from the prior run, that inside a slice-bounded-exit domain this rule eliminates the issuance-pricing extraction channel, leaving only bounded execution-quality residuals on optional sales.
4. The draft's treatment of my cited Bunni evidence: it records the repository warning as Grok's unre-fetched report. For the record, my response independently fetched https://github.com/Bunniapp/bunni-v2 this run; the README states Bunni v2 was exploited and the repo does not have the issues addressed. That citation stands on my own fetch, not only on Grok's.
5. Minor: the draft's mint equation is sound as written, including genesis constants and bare-transfer resistance, but the fee-credit path (who calls it, when, and with what liveness assumption about the separate position) is outside the settled accounting and is where the design's remaining trust assumption lives. The draft gestures at this through the "separately funded position" framing; a final report should state plainly that the fee yield depends on an external funder's continued operation.

## What was not adopted from others

- MiniMax's priced conservative mint (`max(spot, old TWAP)` over the whole book, then slice sale): not adopted. I agree with non-adoption. It marks inventory the deposit did not trade at a same-pool price, the prior report did not treat that class as a repair, and the frozen reference it needs is not the TWAP implementation read in the prior run (public poke, truncated live tick credited across the idle gap). The draft correctly records that MiniMax's arithmetic was not re-executed and that non-adoption is not a refutation.
- THORChain Savers and Bancor pages: member-fetched, not coordinator-fetched; the draft borrows only the asset-quantity-balance concept from Savers and not the exit swap. I neither confirm nor dispute those page contents; I did not open them.
- ICHI's pool-priced mint with spot-versus-TWAP band: not adopted; I agree. I opened both ICHI pages this run, and the share calculation prices deposited value against vault TVL at the pool's token ratio - the pattern the prior evidence shows extractable under the same-pool premise. The draft notes the formulas are images; the surrounding text on the page is sufficient for that characterization.
- Arrakis Pro: not adopted; I agree. The page I opened describes an issuer-owned, self-custodial NFT vault with an offchain manager - a custody pattern, not a public single-token depositor share with an onchain issuance rule.
- My own design (price-free per-component join, slice-bounded exit, live-preview getRate, zap-assisted single-token surface): not adopted. Disagreement preserved as stated in Concerns 1 and 3.

## Limits

- Advisory only: this feedback is not a veto, not a vote, and not implementation authority. The draft remains the coordinator's text.
- My digest check confirms only that the bytes I opened match the supplied sha256; it says nothing about other versions.
- I read no peer feedback and no peer response files beyond what the draft itself quotes; my original response.md is unchanged.
- No new fetches were performed for this review; the Bunni repository corroboration above refers to my own fetch during the initial pass, already cited there.
- No project code, tests, configuration, or Git state was touched; only the owned feedback path was written.

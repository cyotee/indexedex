# Identity

- Member: `kimi`
- Phase: `advisory review`
- Requested role: `council-member`
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Runtime provider/model attestation: not exposed
- Runtime task identifier: not exposed
- Fresh or continued: continued
- Initial response preserved: yes
- This file replaces a missing initial response: no
- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

# Draft under review

- Draft ID: `draft-v3-fullspread-v4-accounting-prd-20261116-r1`
- Path: `/Users/cyotee/Projects/indexedex/docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md`
- Exact file opened: yes
- Fingerprint: not computed
- Review basis: the exact draft and the admitted source context already read for the initial response; no peer artifact was consulted.

# Disposition

`requested-changes`

The draft covers the requested accounting scope and correctly separates vault accounting from hook accounting. The changes requested below concern execution determinism and internal wording, not a request to reopen its named V4 copies or settle its open product questions by implication.

# Concerns

| ID | Draft section | Concern | Advised correction |
| --- | --- | --- | --- |
| K1 | V3-ACC-07 and V3-ACC-11 | The requirement that “fees observed on that add are booked” is not deterministic for a V3 `pool.mint`. The reviewed V3 mint callback pays token amounts owed; it does not supply the V4 `feesAccrued` return named by the template. ACC-11 gives a precise pre-burn fee snapshot for exits but no corresponding pre-add snapshot and booking rule for every one-sided and both-token share mint. Two implementations could collect before the add, infer fees from a combined callback/balance delta, or leave them owed and produce different booked balances and input budgets. | Add one common mint-fee paragraph to ACC-11 and reference it from ACC-05 and ACC-07: before every share-minting add, snapshot the position's collectable fees after any planned entry swap and before the liquidity add; book those pre-add fees exactly once; exclude them from depositor input, callback funding available to the add, added liquidity, and share credit; reconcile any subsequent collection against the snapshot so booked and still-owed fees cannot overlap. State the V3 `burn(0)`/`collect` or owed-read sequence expressly rather than relying on “fees observed.” Preserve ACC-19's copied later-claim dilution rather than inventing a per-vintage fee promise. |
| K2 | V3-ACC-09 | “Booked tokens ... are excluded ... from the next add's budget” is unqualified and conflicts with the same section's statement that `donate` or `compound` may deploy a booked remainder. Read literally, it forbids the maintenance add that the booked balance exists to fund. | Replace “the next add's budget” with “the next user share-minting add's contribution budget.” Add that an authorized maintenance operation may explicitly budget its eligible booked balances under V3-OPEN-02, while user deposits and withdrawals still cannot deploy staying holders' booked balances. |
| K3 | V3-ACC-19 | “Later mints use only new liquidity in the denominator” contradicts ACC-02's actual formula. New liquidity is the numerator; existing deployed liquidity is the denominator. The following dilution explanation is consistent with FS-OWN-24/30, but this sentence misstates the copied issuance math. | Replace the sentence with: “Later mints calculate gross shares from actual newly added liquidity against pre-add deployed liquidity and pre-mint supply. Future fee and booked claims use the enlarged post-mint supply, including the new shares and the genesis floor.” |

# What was not adopted from others

- No peer response or peer feedback was read, so nothing is independently adopted or rejected here from another member's artifact. Attributions inside the coordinator draft are treated as draft text, not as peer consultation.
- From my initial response, the draft did not settle as locks the recommendations to require the `donate`/`compound` surface, unconditionally retire every exact-out selector, or strictly remove SY/transition-quote surfaces. They remain V3-OPEN-02, V3-OPEN-06, and V3-OPEN-05. I do not request that this advisory silently settle those owner choices.
- My recommended pool-locked no-fallback rule is adopted in V3-ACC-15. Import and existing-supply migration remain express decisions in V3-OPEN-01 and V3-OPEN-04, which preserves the intended distinction between a V4 copy and a V3-only product decision.
- The draft's refusal to import hook component or Hook LP entitlement formulas into V3 vault share math is consistent with my initial boundary. No wider hook refactor is requested by this feedback.

# Limits

- This feedback is advisory. It does not authorize implementation, testing, deployment, or a draft/final-PRD edit, and it does not replace the draft.
- The initial `members/kimi/response.md` was preserved and was not edited for this review.
- No peer response, peer feedback, RUN record, or final PRD was read. No sub-agent was launched. No fingerprint was computed.
- No new source review, implementation, test, installation, deployment, wallet operation, or Git operation was performed.
- The optional rate-provider facet was not independently examined in my initial pass or this review. I therefore make no independent finding about the provider-specific factual claims in V3-ACC-18; my requested changes concern the draft's V3 accounting text.
- This disposition is my independent advisory position only and does not claim council consensus.

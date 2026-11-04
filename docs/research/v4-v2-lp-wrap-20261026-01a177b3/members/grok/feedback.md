# Advisory feedback

## Identity

- Member: grok
- Role: council-member. Advisory only. Not the coordinator. Not a vote by itself.
- Run: `v4-v2-lp-wrap-20261026-01a177b3`
- Owned path: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/members/grok/feedback.md`
- Initial response, preserved and not edited: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/members/grok/response.md`
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Exposed identity in this session: Grok 4.7. The reasoning label was not independently verified here.
- Peer feedback was not read. Peer initial responses were not opened on this pass.

## Draft under review

- Draft ID: `draft-v4-v2-lp-wrap-20261026-01a177b3-r1`
- Path: `docs/research/v4-v2-lp-wrap-20261026-01a177b3/coordinator/draft.md`
- The opened file carries that draft ID.
- A local sha256 of the opened bytes matched the fingerprint supplied in the assignment. That match identifies the file. It is not proof of the draft's conclusions, and the hash is not repeated here.

## Disposition

support-with-reservations

The answer line is the one this member supports: yes-only-if. The V2 vault mints from LP received and liquidates a holder's LP portion into one token. That removes spot from the LP-to-share equation and from the share-to-LP converter. It does not eliminate spot-price share manipulation for the product. A V4 wrapper reproduces only that narrow property, and only with a price-free claim unit. Naming the current Wings quote an LP token does not.

The converter, the rejected OutTarget comment, the two reserve bases, the zap, the slice sale, the fee-share qualification, the three-mechanism split, the getRate constraint, and the refusal of implementation authority match the initial response. The reservations below should be carried into the final. They do not change the answer label.

## Concerns

1. Exact-out single-token exit sizes the LP before the converter. `_quoteZapOutToTargetWithFee` reads pool reserves and chooses `lpToBurn`. `_convertToSharesUp` then maps that LP amount into shares. Spot does not enter the converter. It does enter how much LP, and therefore how many shares, that route demands. The proposed text is right that the share-to-LP assignment is not a whole-book quote. It should not be read as "no exit route consults reserves before choosing the LP amount." Exact-in exit assigns LP from shares and only then sells. Exact-out exit does the reverse sizing. Carry that split. It is the zap's split, run backward.

2. The disagreement table compresses the wrapper condition. This member required one homogeneous receipt: each unit an equal claim on one reserve, ranges not mixed. Idle balances, fees, and the other slots stay outside that unit unless they are joined in kind, component by component, with unmatched input refunded in kind. That join is not the V2 LP pattern. The prior report accepted it only as an acceptance-time identity, not as post-sale immunity. The draft body already says the two shapes are not the same design and selects neither. Do not promote the table's "do not mix" line into a claim that this member rejected an in-kind basket, and do not promote the body's "both sufficient" line into a claim that this member adopted the basket as the LP-token role.

3. Keep the executed-price wording narrow, and do not close the exposure. The mismatched-unit form, credit in one unit and reserve in another, does not run when both are LP. This member still says execution price remains on the zap, because the unit count is the output of a swap, and remains on the exit sale, because the other token is sold at the execution price. A deposit swap plus an exit swap is not a fix. The draft's preserved disagreement is acceptable if the final does not turn "the prior form does not run on the converter" into "executed-price exposure is closed."

4. The fee-share path reads reserves and can increase supply with shares that are not new LP, paid to `feeTo`, before the depositor conversion. That is enough to reject "spot is not used to mint shares" for the whole call. It was not traced under a manipulated reserve, and it was not shown to mint the depositor extra shares. The draft's refusal to decide economic significance matches that limit. Do not upgrade "can be unbacked" into a demonstrated extraction, and do not drop the supply-change observation in order to call the whole call spot-free.

5. Three sentences in the proposed wrapper text are not this member's source findings. They can stay if they stay proposals. They should not be written as observations of the current V2 vault.
   - A failed sale reverts or returns residual in kind, and does not borrow target from the incumbent sleeve.
   - If the outer vault owns the entire internal wrapper and neither layer has fees or offsets, the outer conversion adds no economic protection beyond correct inner accounting.
   - The receipt need not be a transferable ERC-20 if mint, burn, and backing are enforceable.

   The third is consistent with the initial response: the PoolManager position is not a depositable pair token, so the receipt has to be created by the add. Consistency is not a trace of an ERC-20 requirement.

## What was not adopted from others

Peer files were not opened. These are positions the draft attributes to other members. They are not adopted here as this member's findings.

- MiniMax's reading that the fee mint is not a meaningful spot channel, because the no-fee baseline is rebuilt at the current ratio and impermanent loss is clamped to zero. The function does clamp, and it does read the live ratio. That does not make the whole call spot-free. The draft correctly leaves the economic significance unsettled.
- MiniMax's reading that the prior mechanism is relocated into the zap because shares per deposited token scale with the manipulated price. The zap is not the safe leg. That quantity effect is not the mismatched-unit issuance defect. The draft keeps those apart. This feedback agrees with keeping them apart.
- Astra's componentwise basket as the V2 LP-token role. A price-free per-component join can avoid a scalar mark. It is a different design from counting one homogeneous claim. The draft says the shapes are not the same and does not pick one. That is the acceptable treatment. Adopting the basket as the answer to "can the position play the LP role" would not be.
- Astra's zero-fee algebra of an exit sale changing remaining pair balances. Not verified here. The draft already calls it an algebraic limit, not an executed profit witness. No sign is assigned.
- Astra's public Uniswap v4 mint-position page. Not fetched here. The draft already says the coordinator did not re-fetch it and that it does not establish this repository's wrapper accounting. It is not evidence for this feedback.
- Any stronger post-sale principal invariant, no-profitable-round-trip theorem, or self-fill sign. The draft does not adopt those. This feedback does not add them.

## Limits

- This file does not replace the initial response and does not authorize implementation, tests, deployment, or Git.
- No project code was edited. The draft, the resolution, the final, and RUN.md were not edited.
- The hash match identifies the reviewed bytes. It does not prove the proposed text.
- Attributions to other members are taken from the draft. They were not checked against those members' files.
- No profit row from the prior report was re-executed.
- Current Wings `getRate` remains the whole-book quote over supply. This feedback does not redefine it as NAV and does not define a replacement.

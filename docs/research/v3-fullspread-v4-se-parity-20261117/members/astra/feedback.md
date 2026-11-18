# Member feedback

## Identity

- Run ID: v3-fullspread-v4-se-parity-20261117
- Member label: astra
- Phase: advisory review
- Owned path: `docs/research/v3-fullspread-v4-se-parity-20261117/members/astra/feedback.md`
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual Native role: not exposed
- Actual Native model and reasoning: not exposed
- Native task ID and session ID: not exposed
- Fresh or continued: continued
- Initial response path: `members/astra/response.md`
- Initial response preserved: yes; submitted in the initial pass and not overwritten or edited on this pass

## Draft under review

- Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1
- Path: `/Users/cyotee/Projects/indexedex/docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed; prohibited by the assignment
- Draft bytes opened: yes; the exact assigned file was read completely, including recovery of clipped long lines
- Draft identity match: its ID, path, and run ID match the assignment

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft accurately retains my verdict of plan not accurate against the supported upperLowerWings comparator, Q2 not confirmed, and the separate observation that the inspected V3 production design substantially follows the plan. It also correctly distinguishes the declared appointment-disable choice from a copied requirement and does not claim runtime proof.

The draft misstates the plan's zero-output pass-through requirement, presents the comparator dispute as conflicting instructions rather than different scopes, and omits the requested account of behaviors that match the supported comparator. The concerns below advise local corrections; they do not ask for implementation or another council round.

## Concerns

Locations below refer to `docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`. References to plan or contract lines are observations already obtained in this same conversation's initial pass; those files were not reopened for this review.

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Proposed text, zero-output pass-through bullet, line 54; Coverage adopted from responses, lines 89 and 91 | The bullet says the plan does not say what a zero-output quote does. The immediately following plan line 96 expressly says: "A zero first word is a failed or unsupported plan, not a successful pass-through." My initial response cited that requirement and distinguished it from the present FullSpread branch. Omitting it makes a specified Plan/V3-versus-FullSpread difference look like an unspecified plan case. The V3 code locators also miss the decisive statements: the zero-output failure assignment was at Planner lines 286-289, and the pass-through failure revert was at InBase line 39, with the additional zero-output rejection at line 50. | State that plan line 96 explicitly rejects a successful zero-output pass-through and that the inspected V3 branch implements that requirement, while the present V4 FullSpread branch does not reject merely because output is zero when the minimum permits it. Cite plan lines 95-96, `UniswapV3FullSpreadStandardExchangeVaultPlanner.sol:281-301`, and `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:35-54`. Keep the V4 comparison as static branch analysis, not a demonstrated transaction. Update the coverage locators accordingly. |
| C2 | Proposed text, lines 34-39 and 41-49; Preserved disagreements, line 72 | The draft calls the router and PRD "conflict[ing] as instructions about which vault is 'the' V4 SE vault" and declines to identify a primary comparator. My initial reasoning was that the PRD explicitly scopes a different product while the router identifies the supported family. A document under examination choosing FullSpread is evidence of that scope difference; it does not instruct this council to substitute the document's question or comparator. Preserving another member's comparator does not discharge the assignment to name the V4 vault used for the answer. | Identify upperLowerWings as the supported V4 SE comparator for the primary answer and state the primary Q1 verdict explicitly. Preserve the on-disk FullSpread comparison and MiniMax's different selection as a separate analysis. Describe the distinction as a comparator/scope disagreement rather than conflicting task instructions. Continue to acknowledge that the FullSpread files are present and that their historical identity was not established. |
| C3 | Proposed text, Wings comparison, lines 41-47; opening conclusion, line 30; Coverage adopted from responses, lines 89-93 | The Wings comparison names important mismatches but never names the behaviors that match that comparator. The later list of matching economic rows concerns FullSpread, so it cannot fill that requirement. The compression also omits material distinctions from my response: Wings' selected-target-only routes versus V3's either-token entries, bundles, and pass-through; Wings' entry issuance without the plan's usage-fee deduction; and Wings' automatic harvest/local funding versus the plan's privileged maintenance and no-sleeve exits. These explain different receipts and successful calls independently of the family label. | Add a compact supported-comparator behavior summary using the already supplied evidence. Name the limited matches, such as the two-word exact-input preview, disabled-deposit rejection with withdrawals available, and booked-credit isolation. Name the differing share/fee calculations, accepted assets and bundle/pass-through routes, exit entitlement, booked-balance valuation, maintenance/local funding, quote/SY surfaces, and exact-out. Keep retained import labeled as an explicit V3 extension. Do not turn this into a new audit or imply that shared signatures establish economic parity. |

For C1, the prior source observations were from:

- `docs/research/v3-fullspread-v4-accounting-plan-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_IMPLEMENTATION_PLAN.md:95-96`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol:281-301`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:35-54`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:120-130`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol:63-80`.

For C3, the already submitted behavioral evidence includes the Wings money implementation at `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81-105,120-180`, its route predicate at `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultQuoteBase.sol:27-31`, and the paired V3 observations in my initial response's Observable behavior comparison. These references identify existing evidence; no fresh source verification is claimed on this pass.

## What was not adopted from others

- Peer responses read: not read on this pass or before my initial submission. I read only the coordinator draft's descriptions of other members' positions.
- Peer feedback read: not read.
- Unread members treated as support: no.
- I do not independently validate the draft's claims about what all four members reported. Those remain coordinator attributions.
- I do not adopt the possible one-liquidity-unit sizing difference as an established behavioral result. The draft appropriately leaves it unverified.
- I preserve the distinction between supported-family identification and the separate comparison with present FullSpread files; I do not adopt the latter as my primary Q1 comparator.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This feedback does not authorize implementation and does not replace the draft or my preserved initial response.
- Only the exact assigned draft and the feedback template were read on this pass. Prior observations were used from this continued conversation; no plan, PRD, contract, response, or peer file was reopened.
- No fingerprint, tests, builds, installs, Git operations, deployments, wallet operations, or project-code edits were performed.
- Only the owned `members/astra/feedback.md` file was written. The draft, resolution, final, run record, initial response, and peer files were not edited.
- Inherited parent permissions are not evidence of confinement.

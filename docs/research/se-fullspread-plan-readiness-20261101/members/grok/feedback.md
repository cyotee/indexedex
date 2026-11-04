# Member feedback

## Identity

- Run ID: se-fullspread-plan-readiness-20261101
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-fullspread-plan-readiness-20261101/members/grok/feedback.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/se-fullspread-plan-readiness-20261101/members/grok/response.md
- Initial response preserved: yes

This advisory neither replaces the draft nor authorizes implementation.

## Draft under review

- Draft ID: draft-se-fullspread-plan-readiness-20261101-r1
- Path: docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md
- Fingerprint supplied by the coordinator: 3ed7a08203e0cb077ad442a4b2e8538cd315f13bd2a132ee46627f51cce5e2b3
- Fingerprint independently computed: not computed. The assignment forbade recomputation. The draft's own fingerprint field says `not computed`. That field is recorded as given. It is not independent proof of the supplied hash.
- Draft bytes opened: yes. The identity lines match the assigned draft ID and path.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The not-ready verdict is right. All of the draft's blocking items are real gaps except item 9, and items 1, 5, 8, 11, and 12 ask the owner the wrong question or a question that is too wide. Support of the verdict is not approval of those questions.

This advisory neither replaces the draft nor authorizes implementation.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Proposed text, Decisions that block the plan, item 1 | The question embeds a fee design that no locked sentence states: take the fee from the depositor's shares, and make preview and `minAmountOut` use the net amount. That is an invented alternative, not the only way to close FS-OWN-24 versus APEX-2026-044. The acceptance question and the `sharesMinted` base are also different decisions. The base matters only if the extra mint stays. The fee shares themselves are a third base case the question drops. | Split the question. Ask whether the extra mint to `feeTo` is an accepted exception to APEX-2026-044, or whether this vault must not mint that dilutive fee. If the mint stays, ask separately whether `sharesMinted` is only the depositor's credit, and whether the 1,000-share floor and the fee shares are excluded. Do not prescribe preview or `minAmountOut` accounting. |
| C2 | Proposed text, Decisions that block the plan, item 2 | "What exact pre-operation bound must the plan enforce?" can be read as ordering a bound while FS-OWN-10 still forbids one. The owner can accept live-price placement, or amend FS-OWN-10. The question does not say the second branch is an amendment. | Say that any bound amends FS-OWN-10. Do not ask for a bound as if the lock already allowed one. |
| C3 | Proposed text, Decisions that block the plan, item 5 | FS-MONEY-01 already says idle is not in the issuance denominator. A later depositor's claim on sleeve value is the consequence of that sentence plus FS-OWN-30, not an open formula. Reopening "does issuance stay liquidity-only" asks the owner to un-lock a stated rule. The real gap is the zero deployed-liquidity denominator: supply can be positive while `v.liquidity` is zero, and the existing-supply division does not say what happens. | Delete the request to re-decide liquidity-only issuance. Keep one question: when deployed liquidity is zero and supply is positive, what is the issuance denominator, and does the call revert? |
| C4 | Proposed text, Decisions that block the plan, item 8 | The question asks which getters are installed and what values are written. FS-PKG-01 still says the PRD has not decided whether the aware facet becomes a package input. An answer that names proxy getters does not say whether that facet, or the Position Repo facet, is a `PkgInit` field. | Add that question: are the Protocol Aware facet and the Position Repo facet `PkgInit` inputs, or only selectors on this proxy? |
| C5 | Proposed text, Decisions that block the plan, item 9; Preserved disagreements, Rate provider | FS-RATE-01 and FS-HOOK-04 already say a package that requires a provider is an unresolved record. The plan must not invent a provider to make a matrix row pass. Item 9 asks the owner to name one, and it adds a 32-byte decoder migration that the examined PRD does not mention. No PRD sentence in item 9 leaves that migration open. | Remove item 9 from the blocking list. The locked outcome is an FS-HOOK-04 record, not a named provider. If a decoder migration remains, cite the PRD sentence that leaves it open. Do not add it from a member response alone. Do not authorize `getRate()`. |
| C6 | Proposed text, Decisions that block the plan, item 11 | FS-OWN-31 already says the borrowed path pays the caller's local fraction and reverts `UnderlyingUnavailable` if that fraction cannot finish the caller's fraction. FS-OWN-30 says the own-unlock sleeve is not a top-up. "May the vault spend more than that holder's local fraction?" reopens those sentences. The open part is narrower: the error has one `required` and one `available`, and a one-token exit can be short on one of two tokens. | Ask which token's amounts are `required` and `available` on a one-token exit. Delete the spend-more branch. |
| C7 | Proposed text, Decisions that block the plan, item 12 | The question covers only genesis. FS-OWN-27 scales internal amounts generally. The existing-supply formula can still be scaled or not after genesis is answered. | Ask whether any scaled amount enters `frame.shares = liq * totalShares / liquidity` on later deposits, not only whether genesis shares are raw liquidity minus 1,000. |
| C8 | Proposed text, Decisions that block the plan, item 15 | Event signatures and the two library slots are independent. One compound question lets a partial owner answer close both. | Keep both questions. State that an answer to one does not close the other. |
| C9 | Proposed text, What is not a new product choice | The section names the live matrix directory and does not say that `hook-se-matrix.json` already has seven `COMPATIBLE` rows for `UniswapV4FullSpreadStandardExchangeVault` whose cited test files are absent. A plan author can treat those rows as current proof. | Say those seven JSON rows are stale and are not current proof. Name `hook-se-matrix.json` as the evidence file to replace, not as a passed column. The followup-review snapshots are not the current matrix. |
| C10 | Proposed text, What is not a new product choice; Preserved disagreements, Finding-test count and Quote step cap | Deferring the inventory is acceptable only if the final still dispositions every ID. The exclusion sentence is too coarse. "Balancer pool, Aave or Stata vault, DETF minter, or Crane ownership library" does not cover, and must not be used to drop, APEX-2026-013, 032, 045, or 052. Tracker closure of 011, 041, 042, and 051 by deletion does not drop those tests. This advisory does not show that the plan must choose a quoter, step cap, or tick spacing. | In the final, disposition every second-audit ID. Keep the deletion sentence. Do not add a quoter or spacing question. Do not let the exclusion sentence swallow 013, 032, 045, or 052. |

Items 3, 4, 6, 7, 10, 13, and 14 are sound blocking questions. Item 6 is a correction of my initial response: FS-OWN-21 closes custody, not the one-token conversion. Item 7 correctly adds `previewExchangeOut`'s required revert to the view conflict. Item 13 is a real event-quantity gap I did not list. The preserved-disagreement row on donation correctly records that I did not treat conversion as a blocker, and correctly keeps the question.

The preserved-disagreement row on pretransfer is right not to add an APEX-2026-039 owner question. The absence test is still required. Booking only the requested amount, refunding unused input to the payer, and burning only the caller's shares are enough to write that test. Do not drop the test because the question was not added.

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I did not read Astra, MiniMax, or Kimi. Nothing below is an independent check of their files. It is only what this draft attributes to them, and what of my initial response the draft did not keep.

From the draft's own preserved-disagreement table, these positions were not adopted:

- MiniMax's quoter, step cap, fallback, and minimum spacing were not made owner questions. That non-adoption should stand. Do not add them in the final.
- Astra's request for a 039 attribution question was not added. That non-adoption should stand. The absence test remains.
- My claim that donation conversion is not a blocker was not adopted. That non-adoption is correct. Item 6 should stay.
- My claim that the plan must not ask the owner to name a rate provider was not adopted. That non-adoption is the defect in item 9 and in the Rate provider row. FS-HOOK-04 is the locked outcome.

The draft also does not carry the per-ID inventory from my initial response. That omission is acceptable in this draft only because the final is still required to disposition every ID. It is not acceptable as the final's substitute for that inventory.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral. This file neither replaces the draft nor authorizes implementation, tests, installs, Git, or edits outside this path.
- The supplied SHA-256 was not recomputed. Opening the draft is not hash verification.
- Other members' response and feedback files were not read. Attributions to them are coordinator-supplied and unverified here.
- The "all four originals reach that verdict" sentence is coordinator-supplied. My own initial response does reach not-ready. I do not independently confirm the other three.
- Inherited parent permissions are not evidence of confinement.
- One advisory round. No further round is requested.

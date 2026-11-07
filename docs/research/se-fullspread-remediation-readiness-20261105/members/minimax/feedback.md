# Member feedback

## Identity

- Run ID: se-fullspread-remediation-readiness-20261105
- Member label: minimax
- Phase: advisory review
- Owned path: `docs/research/se-fullspread-remediation-readiness-20261105/members/minimax/feedback.md`
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: role `council-member` as assigned; runtime model identity, reasoning depth, task ID, and session ID not exposed
- Fresh or continued: continued; the same conversation that produced the initial response
- Initial response path: `docs/research/se-fullspread-remediation-readiness-20261105/members/minimax/response.md`
- Initial response preserved: yes; not overwritten

## Draft under review

- Draft ID: draft-se-fullspread-remediation-readiness-20261105-r1
- Path: `docs/research/se-fullspread-remediation-readiness-20261105/coordinator/draft.md`
- Fingerprint supplied by the coordinator: not computed
- Fingerprint independently computed: not computed
- Draft bytes opened: yes; the file opened and its identity lines match the assignment

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft's locators are sound. I re-read the cited lines of `docs/reviews/se-fullspread-plan-execution-20261104/REMEDIATION_PRD.md` (L22-L56, L80-L82, L89-L91, L95-L102, L107-L109, L131-L138, L170-L172, L176-L188, L218-L227) and of the base plan (L19, L71, L94, L123, L156, L176, L180, L194, L217, L323, L374, L389, L493-L496) and of the family PRD (L33, L228, L328, L418, L467). Every locator in the draft checked out. My concern is with what the draft asks the owner, not with where it points: each of its three adopted open choices is either decided by a line the draft quotes, or is a code check that a later plan author performs, so the proposed "not ready" verdict rests on questions the source text answers.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | "Proposed text", adopted choice 1 ("Owner lock, Domain through Token1 in, lines 30-42") and "Preserved disagreements", symbol `n` | The draft quotes the gross-rounding sentence from line 30 and then lists "a quantity that must not exceed the amount the pool applies" as a third role of `n`, without applying the constraint. Applied, it fixes the direction: with gross `= floor(n/g)` and the fee rounded up, the pool applies `gross - ceil(gross * feePips / 1_000_000) = floor(gross * g)`, which is never larger than the root `n`, so the only reading that satisfies line 30 is that the plan uses the pool-applied amount and the root is the solver's input. Line 28 points the same way: the add consumes the other token "at the price that swap produces". As written, the draft presents pricing from the root and pricing from the smaller executable amount as two equally available choices, so a reader who applies the constraint proceeds and a reader who does not either breaks line 30 or concludes the lock is inconsistent. The residual the draft does not name is different and sharper: line 44 states the boundary "in the position's per-liquidity ratio at `s'`", the root's price, while the rounded swap actually lands at the applied amount's price. | Advice: apply the line 30 constraint in the draft, state that the planned `n` is the pool-applied amount and the root is only the solver's input, and either drop the symbol question or reduce it to the one that remains: which price governs the add's ratio once the gross rounding and the fee rounding make the executed price differ from `s'`. If the coordinator still wants an owner answer, ask that price question, not the symbol question. |
| C2 | "Proposed text", adopted choice 2 ("Owner lock item 5, line 56, repeated at F11 line 172 and recommendations line 225") and "Preserved disagreements", unnamed six gas routes | The draft states that the six routes are not named and that a later author "cannot copy one standalone gas list from the text that was re-read", but the re-read text constrains the set in two ways the draft does not use. Plan line 374 assigns the six standalone routes to `Money.t.sol` in the same row as FS-A05 to FS-A08, which are the first deposit, the bundle deposit, the entry refund and the one-token exit, and that points the two `exchangeIn` shapes at the mint and the exit. The money-facet table the coordinator re-read in the family PRD lists five money selectors, so five plus the second `exchangeIn` shape is exactly six, and the two remaining selectors at plan line 94 are the operator appointment calls, a different class of operation from a money or maintenance route. What is genuinely unstated is narrower than the draft's wording: line 56's first sentence says "Every supported route has a gas test" while its second sentence names six standalone routes, and the draft's own re-read of plan line 94 shows seven money-facet selectors. | Advice: narrow the concern to that residual, namely whether the operator appointment calls are standalone routes under line 56's first sentence, and ask it in those terms; or record the six as derivable from plan line 374's FS-A05 to FS-A08 list together with the five money-facet selectors. Do not state that no standalone gas list can be copied from the text that was re-read. |
| C3 | "Proposed text", adopted choice 3 ("F7, lines 131-138, and recommendations line 223") and "Preserved disagreements", capacity overrides | The draft says the finding and the recommendation do not say "keep them, delete them, or accept them when a parent forces the override", and that the coordinator found no sentence in the remediation PRD that picks one end state. Line 136 does pick the procedure: "Do not treat the empty bodies as satisfying 'not part of this fixture.' Do not delete them until the parent requirement is checked." The parent check is a fact about a file the plan author opens, and the draft's own Evidence gaps section records that the fixture parent interface was not an admitted required target, which makes it later-plan work rather than an owner question. Plan line 217 already states the product rule that both candidate outcomes preserve, and line 135 already records that the empty bodies do not add a sleeve capacity gate, so no product behavior differs between keeping and removing them. | Advice: restate the concern as the parent-interface check with its two outcomes, keep the overrides if the parent forces them and remove them otherwise, and drop the owner question; if the coordinator still wants an owner answer, name the product behavior that would differ between the outcomes, because line 217 states that it does not. |
| C4 | "Proposed text", the paragraph beginning "Astra also reported a fourth gap" | The paragraph records that the lock states no outcome for a starting state outside its domain "including zero active liquidity", and supports that with family PRD FS-OWN-22 and FS-PKG-02, which are package-acceptance sentences about which pool key may be installed, not about the position's state at call time. The remediation PRD does state an outcome for the zero-active-liquidity case: F3 at lines 95 to 102 and recommendation line 221 say a collapsed one-sided candidate returns the input as remainder without keeping a selected swap, and the family PRD's refund rule at line 33 and first-deposit floor at line 418 settle the payout and the revert. A reader could diverge: one takes the paragraph as leaving the zero-liquidity case open, another reads F3 and line 221 as deciding it. | Advice: cross-reference F3 and recommendation line 221 in that paragraph and split the two things it merges, so the zero-active-liquidity starting state, which the PRD addresses, is separated from the remaining out-of-domain case, for example a price outside `sL < s < sU`, which it does not. If an owner answer is still wanted, ask it in those terms. |
| C5 | "Coverage adopted from responses", Remediation PRD row, "Member line numbers for the lock items differ by about one line from the re-read." | The statement is unqualified, and the minimax initial response does not exhibit it: `members/minimax/response.md` cites the five lock answers at lines 52, 53, 54, 55 and 56, the lock body at lines 22 to 48, and the findings at the lines the draft uses, all matching the coordinator's re-read exactly. A reader could diverge about whether every member's lock locators need a correction pass, or only one member's. | Advice: attribute the offset to the member whose numbering it describes, or state that it applies to one member's lines only. The minimax lock locators need no correction. |

## What was not adopted from others

- Peer responses read: no
- Peer feedback read: no
- Unread members treated as support: no

The draft's own summary of the four members' positions was read as part of the draft and is not a peer file. I did not open any member response or feedback file, and I did not treat silence or agreement reported in the draft as my position.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- The re-reads behind these concerns are the remediation PRD, the implementation plan, and the family PRD, all read in full earlier in this conversation. No source file, fixture parent interface, member file, coordinator resolution, or run record was read, so C3 characterizes the parent-interface question and does not answer it.
- No test, compile, gas measurement, install, deployment, or mutating Git action was run. This review changes nothing outside this owned path.

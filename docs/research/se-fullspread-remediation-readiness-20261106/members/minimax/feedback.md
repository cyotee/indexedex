# Member feedback — minimax

## Identity

- Member: minimax
- Run ID: se-fullspread-remediation-readiness-20261106
- Phase: advisory feedback
- Requested role: council-member
- Requested model: minimax/MiniMax-M3
- Write: not exposed for any runtime identity not given
- Profile: research

## Draft under review

- Draft ID: draft-se-fullspread-remediation-readiness-20261106-r1
- Path: `docs/research/se-fullspread-remediation-readiness-20261106/coordinator/draft.md`
- Coordinator-supplied SHA-256: `7de78ac3f367b07c4e005441f6fb9fe66ad7801f27a61c861718388eb45973f6`, recorded as given and not recomputed. My own fingerprint: not computed.

## Disposition

support-with-reservations

The verdict and the location are right. I re-read the lock at the coordinates the draft gives, and the collision is there: remediation PRD line 28 (`Rule`) ends "A donate or compound remainder is booked", and line 30 (`Boundary`) says, for the wanted token, "add it with no swap and refund what the add does not take" without a route qualifier, while the next sentence splits the other-token case by route ("A share mint refunds it. A donate or compound books it."). My initial response did not test that intersection, and the draft's finding stands: two careful plan authors can land on different dispositions for the wanted-token dust of a boundary `donate` or `compound`, so the verdict cannot be `ready` while the text is unchanged.

The reservations are about the shape of the open choice, not the verdict. All three are advice about wording and framing; none is an edit, and I did not touch the draft.

## Concerns

### Concern 1 — section `The open choice`: the collision rests on a premise the draft does not state, and the alternative premise dissolves it

- Section: `The open choice`.
- Why two readers could diverge: the draft treats the collision as an unrankable contradiction inside one dated lock. That depends on reading the `Rule` sentences ("Rounding leaves any remainder in the input token. A user-deposit remainder is refunded. A donate or compound remainder is booked.") as general route rules that reach the boundary branch. A careful reader can scope them the other way: the `Rule` paragraph opens on the 49% swap path and its subject is the rounding remainder that the swap leaves, and the boundary branch performs no swap, so the `Rule` sentences classify only that path. On that narrower reading the `Boundary` sentence governs the boundary dust on its own, and the base rule that a maintenance remainder is booked is then displaced by the later 2026-11-06 text; the outcome is determinate and no owner question arises. The two readings produce opposite, determinate plans, so a reader who adopts the narrower premise reaches `ready` and never asks the owner, while the draft's own framing asks the owner to break a tie the draft has not shown to be a tie.
- Requested change, as advice: say in `The open choice` that the collision depends on the route split in `Rule` reaching the boundary branch, and that the narrower scoping would let `Boundary` govern alone. Then state how the mechanism that a later author would use to settle a lock-versus-base conflict applies to the wanted-token dust, since the family PRD precedence clause at line 5 puts a dated 2026-11-06 owner lock above earlier and undated sentences in that file. That turns the question from "the text is contradictory" into "which reading governs", which is the question the owner can actually answer.

### Concern 2 — section `The open choice`: the base route rule is on point for this case and the draft cites only the plan sentence

- Section: `The open choice`.
- Why two readers could diverge: the draft cites family plan section 9 ("Do not refund a donation or compound remainder.") and dismisses it as an older sentence that cannot delete the `Boundary` refund sentence. The admitted base also states the same route rule at PRD level, in family PRD line 240 under `FS-OWN-32` ("A donation or compound remainder is booked, not refunded. That booking is not this refund rule.") and in the section 2.1 dispositions table at line 282, row `Entry remainder` ("A donation or compound remainder is booked."). A plan author working from the base finds two PRD-level sentences that say a maintenance remainder is booked and may conclude the outcome is already fixed, with `Boundary` read as the share-mint path; the draft's framing leaves the reader thinking the base does not bear on the question. The owner is then asked a question whose answer the base appears to already give, and may answer for that reason.
- Requested change, as advice: name those two PRD-level statements alongside the plan sentence and say how each bears on the wanted-token dust. If the answer is that a boundary maintenance dust is refunded, the plan has to record a carve-out from three base statements for that branch only; if the answer is that it is booked, the base statements stand and the `Boundary` refund sentence is read as the user-deposit path. Stating that asymmetry lets the owner answer in a form the plan can encode, and it shows the owner that one reading is base-preserving and the other is not.

### Concern 3 — section `Participation`: the recorded dissent understates what my response asserted

- Section: `Participation`.
- Why two readers could diverge: the draft records that "MiniMax and Kimi did not name the boundary-dust split". That is literally true, but my initial response did not omit the sentence; it listed the out-of-range branch under the heading "The out-of-range branch has one specified outcome" and quoted the `Boundary` sentences as one outcome. So my `ready` verdict rested on the very sentence the coordinator now challenges. A reader of the final report who takes the draft's phrasing at face value will record my position as a missed corner case rather than a contrary reading of the same sentence, which changes how much weight the `ready` side of the disagreement deserves.
- Requested change, as advice: state that the `ready` verdict rested on the `Boundary` paragraph being one specified outcome, and keep the dissent line accurate on that point. The draft's `Closed by the current text` list does not include the out-of-range branch, so the narrower description of the disagreement is consistent with the rest of the draft.

## Not adopted from the draft

- I did not adopt the draft's dismissal of the base sentences as sufficient to close the wanted-token dust, for the reason in Concern 2. I accept the collision; I do not accept that the base is irrelevant to it.
- I did not adopt any conclusion about the code. I did not open the Solidity files the remediation PRD cites, so the split is a question about the text only.

## Limits

- Advisory only. This feedback does not authorize implementation, tests, deployment, or Git, does not replace the draft, and does not write the plan.
- Static reading of the remediation PRD, the family PRD, the family plan, and the draft. No forge, cast, npm, bun, install, deploy, or Git action was run.
- I did not read peer responses, peer feedback, the questions file, or member question files, and I did not re-read the earlier readiness reports beyond the admitted r2 report.
- The coordinator-supplied SHA-256 is recorded as given. A repeated value is not verification, and I did not compute an independent one.

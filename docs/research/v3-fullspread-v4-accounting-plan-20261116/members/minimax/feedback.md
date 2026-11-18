# Member feedback — minimax

## Identity

- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Member label: minimax
- Profile: research
- Phase: advisory review
- Owned path: `docs/research/v3-fullspread-v4-accounting-plan-20261116/members/minimax/feedback.md`
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: council-member; `minimax/MiniMax-M3`; admitted adaptive thinking; task ID and session ID not exposed
- Fresh or continued: fresh retry context for the same logical assignment, attempt 2 after a transient empty completion
- Initial response path: `docs/research/v3-fullspread-v4-accounting-plan-20261116/members/minimax/response.md`
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v3-fullspread-v4-accounting-plan-20261116-r1
- Path: `docs/research/v3-fullspread-v4-accounting-plan-20261116/coordinator/draft.md`
- Fingerprint supplied by the coordinator: `f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314`
- Fingerprint independently computed: no; the assignment prohibited recomputation
- Draft bytes opened: yes; the exact assigned draft was read

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The draft accurately carries my proposal and the locked owner locks for the genesis-floor outcome, import burn, later import, share math, fees, and package surface. It is not decision-complete because the two corrections below create materially different implementation and test behavior.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| MM-1 | Step 1, **Booked balances and the floor write**, especially the test sentence beginning “A direct transfer does not increase `reserves()` and is not a later caller's credit”; read against Step 4's unbooked-credit rule | The draft does not identify which token a “direct transfer” moves. If it means a pool-token transfer, the sentence contradicts V3-ACC-10 and Step 4: the transferred pool token is unbooked credit and may be spent by the next one-token pretransfer. If it means a share-token transfer, the sentence must say so. As written, an implementer could write a test that rejects a valid V3-ACC-10 pretransfer or leave transferred pool tokens stranded. | Name the token in the test. State that a share-token transfer creates no reserve or liquidity credit, while a pool-token transfer creates unbooked credit usable by the pretransfer route, does not increase `reserves()`, and does not become booked unless authorized maintenance books it. Replace the ambiguous assertion with those two cases. |
| MM-2 | Step 4, **One-token routes, funding, exits, and pass-through**, in the V3-ACC-16 paragraph stating that `setOperator` and `setOperatorFor` revert `VaultDisabled` because they are absent from the exception list | V3-ACC-16 constrains “execution routes”; it does not define administrative configuration selectors as execution routes. V3-OWN-03 adds `setOperator` and `setOperatorFor` but assigns them no disabled-vault behavior. The draft turns absence from an exception list into a mandatory `VaultDisabled` rule, so two careful implementers could block operator administration or allow it, and the draft gives no locked or retained-behavior authority for that outcome. | Do not infer the disabled-vault behavior solely from the exception list. Classify `setOperator` and `setOperatorFor` as administrative selectors outside V3-ACC-16, or identify the authority that makes them execution routes; if their disabled-vault behavior is a plan choice, state it explicitly as such. |

## What was not adopted from others

- Peer responses read: none
- Peer feedback read: none
- Unread members treated as support: no

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority and does not replace the draft.
- Coverage was limited to the exact pinned draft, my own initial response, and the locked PRD. No peer response or peer feedback was read, and no test, build, Git command, install, deployment, or implementation was performed.
- This feedback records the execution defects and corrections above; it does not claim runtime verification.

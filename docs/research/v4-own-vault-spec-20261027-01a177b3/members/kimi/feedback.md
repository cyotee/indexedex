# Member feedback

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: kimi
- Phase: advisory review
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/kimi/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: council-member; model and reasoning not exposed; task ID st_01a17cf9 (as given in the assignment message); session ID not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/kimi/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: 2e2c595866b5475ba8802496f7606df9dbc5fc7cfef2b46a65175581f6750ea8 (frozen-file sha256 given in the assignment; the draft body carries a pre-insertion sha256 c015e6977c4cc64b54c5377fd99d6f16ab384ed4e02a52faa35ef235fe71404b and defers to the RUN.md frozen-file value)
- Fingerprint independently computed: not computed
- Draft bytes opened: 23364

The draft's own identity lines match the assigned Draft ID and path.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| K1 | Decision 3, exit payment paragraph: "An exit, after the pre-burn settle, pays `floor(unclaimed_i * sharesBurned / balanceBefore)` of each currency... Tokens the pool pays because liquidity was removed fund that payment." | Funding-source ambiguity with a double-count risk. The accumulator design implies fee claims are paid from the vault's sync-collected fee token balances that back `unclaimed_i`. The quoted sentence instead says the principal-removal proceeds fund the payment. If the removal proceeds fund the fee claim while the collected balances that back `unclaimed_i` remain in the vault, the same fee value is recognized twice; if the collected balances fund it, the sentence is wrong. Decision 5 compounds the ambiguity by selling "the opposing amount of that fee claim" without stating which balance that amount leaves from. | State explicitly: the fee claim is paid from the attributed collected-fee balances backing `unclaimed_i` (or from a fee collection executed inside the same removal call, never both); those backing balances are excluded from `U`, are not swap input beyond the burned shares' own claim, and the removed slice's principal proceeds are a separate quantity. Add the corresponding double-count check to Decision 8. |
| K2 | Decision 4 and "What this does not deliver" | The draft excludes the single-token zap route entirely, so depositors must already hold both pool currencies. My initial response included the zap with explicit non-claims. The draft records that dissent fairly and preserves the non-claim as a condition on any later addition, so this is a product-consequence reservation, not a recording defect: entry UX now depends on an external swapper, and the specification should say whether an external zap-in front of the vault (some other contract swaps, then deposits both currencies) is an accepted integration pattern or out of scope. | One sentence in Decision 4 or "What this does not deliver" stating the standing of an external zap-in front of the vault, so a later agent does not silently reintroduce the vault-initiated swap the draft excludes. |
| K3 | Decision 3, `S = 0` case and "Evidence gaps" | Fee-growth field names were not re-read and the pool-side collection mechanics are left as "collect what the pool owes this position, in token units." That is an acceptable flagged gap, but it sits on the draft's most novel component (the accumulator). A later implementer working only from this file plus cited sources still needs to verify, from admitted V4 sources, how a single position's owed fees are read and collected, including whether collection and liquidity removal share a delta or must be separated to satisfy K1. | Keep the flagged gap, and add to Decision 8 a requirement that the implementation's fee-collection step is verified against the admitted V4 sources before the accumulator equations are wired, so the untraced pool mechanics cannot be filled from excluded source. |

## What was not adopted from others

- Peer responses read: not read. The coordinator's "Preserved disagreements" table is the only account of peer positions used here, and it is treated as coordinator text, not as peer text.
- Peer feedback read: not read
- Unread members treated as support: no

## Assessment of the assigned questions

- Dissent recording: fair. My compounding proposal is named as a rejected alternative under Decision 1 and Decision 3 with its actual content (fees change `U` before the mint); my zap inclusion is named under Decision 4 with my non-claim preserved verbatim in substance; the dissent table attributes positions accurately. The draft did not reframe my position.
- Implementability without excluded source: yes, with the flagged gaps. The eight decisions, both normative sequences, and the twelve invariants are complete enough to implement from the draft plus the IndexedEx paths it cites. The two open implementation-time verifications (pool fee-collection mechanics, position-owner and callback behavior) are stated in the draft itself and are checkable against admitted V4 sources; neither requires the excluded third-party source.
- `getRate`: not redefined as NAV. Decision 7 keeps it as the normalized one-whole-share withdrawal-and-sale preview, with the same-state consistency invariant (Decision 8 item 9), an explicit revert set, no synthetic constant, and an explicit sentence that this council does not redefine it. The preview includes the pending fee delta, matching the execution ordering.
- Reconstruction of excluded source: none found. Every requirement traces to re-read IndexedEx code (BetterMath, InTarget, DFPkg initAccount), to the three prior reports, to the Crane architecture skill, or to named member proposals. No constant, name, or control flow in the draft tracks the excluded implementation; the accumulator, the receipt ledger, and the callback gating are stated as proposals with their own rationales.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- The coordinator's fingerprint was not recomputed per the assignment; byte count was read, no hash command was run.
- Coordinator-reported re-reads (BetterMath, InTarget, DFPkg decimals) were not independently re-verified on this pass; my initial response re-read BetterMath and InTarget directly and the draft's equations match what I observed then.

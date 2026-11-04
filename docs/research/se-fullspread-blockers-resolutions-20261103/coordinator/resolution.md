# Coordinator resolution

## Draft reviewed

- Draft ID: draft-se-fullspread-blockers-resolutions-20261103-r1
- Path: `docs/research/se-fullspread-blockers-resolutions-20261103/coordinator/draft.md`
- Fingerprint: not computed. No member was asked to compute one.
- The draft file was not edited after advisory began.

## Advisory outcome

| Member | Disposition | What this resolution does with it |
| --- | --- | --- |
| astra | requested-changes | Applied the omitted procedure details that do not change the chosen branch. |
| grok | requested-changes | Applied the preview, borrowed-path, and attribution corrections. F6's payment proposal stays not adopted. |
| minimax | requested-changes | Applied the F1 misdescription, the selector naming, and the computable-event limit. MiniMax withdrew the F1 and F6 objections. |
| kimi | requested-changes | Applied the conditional fee booking, the F3 attribution, and the amount-source sentence. |

None rejected the need for one sentence per finding. Coordinator revisions in the report are not member-approved text. A proposal is not an owner lock.

## What changed from the draft

| Section | Concern | Final treatment |
| --- | --- | --- |
| F1 | The no-processing branch stands. The draft misdescribed MiniMax and told ordinary previews to follow a flag they do not have. | Corrected. The shared interface sentence was re-read. Ordinary previews are not given a pretransfer branch. |
| F2 | Kimi booked fees only when collected. Astra separated user debits from fee credits. | The sentence no longer asserts that every modification collects fees. |
| F3 | Kimi did not propose skipping the call before the deposit. Astra said skip only the zero-size add. | The skip is labeled a refinement of the zero-liquidity outcome, not a four-member agreement on a pre-check. |
| F5 | Astra's objective was greatest added liquidity, not greatest swap input. | The objective is restored. |
| F6 | Grok says a revert does not fit the unscoped no-revert lock. MiniMax withdrew the booking proposal and asked for an error name. | The revert stays the proposal. The conflict with the unscoped lock is stated. The error name is added. |
| F7 | The "included a fee" predicate is not computable without a new store. | The recommended predicate is the fee delta of that call. The previously booked case needs a store the proposal does not add. |
| F9 | Position getters were unnamed. | Named. |
| F10 | Share donation and the DETF precedent were omitted. The missing shared-interface claim was re-checked. | Applied. |
| F11 | A one-token exit is not an `exchangeIn`. Borrowed-path conditions were omitted. | The selector is named. The conditions are named. |
| F15 | "This file" was ambiguous. The inventory needs a completion check. | The blockers file is named. The completion check is added. |

## Not changed

- No proposal is an owner lock.
- F6's payment and the withdrawn booking proposal are not adopted.
- Kimi's half-input swap and two-argument `donate` are not adopted.
- This resolution does not edit the blockers file or the PRD and does not authorize implementation.

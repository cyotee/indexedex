# Identity

Kimi, independent council member (`kimi`), one advisory round for run `se-fullspread-plan-readiness-20261101`. Peer feedback was not read.

# Draft under review

- Draft ID: `draft-se-fullspread-plan-readiness-20261101-r1`
- Path: `docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md`
- Coordinator-supplied SHA-256: `3ed7a08203e0cb077ad442a4b2e8538cd315f13bd2a132ee46627f51cce5e2b3`
- The file was readable. Its internal fingerprint says `not computed`, consistent with the instruction that the supplied bytes match. I did not recompute the hash and did not review another draft.

# Disposition

**REQUEST CHANGES.** The draft correctly concludes **not ready**, and its additional blockers expose real decisions missing from my original list. Before becoming the final answer, it must also provide the required matrix-file targets and all 45 finding-level test dispositions, add the pretransfer-attribution blocker, and make the corrections below.

This advisory neither replaces the draft nor authorizes implementation.

# Concerns

1. **Proposed text and What is not a new product choice — the mandatory coverage deliverables are missing.** The draft names only the matrix root and says the final finding inventory waits for advisory. The assignment requires the readiness answer itself to identify the current matrix files and state, for every second-audit finding ID, whether a test is required and why. Disagreement over the count is not a reason to omit that inventory. The final should name the seven matrix behavior contracts, the shared fixture/adapter files, both same-manager helpers, and the JSON/Markdown/acceptance evidence files, then give all 45 dispositions without hiding the members' disagreements.

2. **Preserved disagreements — Pretransfer and APEX-2026-039: add a blocking decision.** The draft currently leaves this without an owner question, but FS-OWN-20's statement that "a pretransfer books only the requested amount" limits quantity, not attribution. It does not say who supplied the balance, whether another caller may book it, or whether staged self-custody is rejected. That leaves the 039 mechanism available and makes an absence-test expectation a product choice. Add an owner question asking whether pretransfers must be atomic and bound per sender, and whether self-recipient/staged credit is rejected. My original position that the unbooked-balance rule alone was sufficient should not be retained.

3. **Decisions that block the plan, item 9 — the 32-byte decoder migration is unsupported within the draft.** The missing external rate provider and valuation policy are established blockers. The draft gives no PRD sentence or finding mechanism explaining why a decoder migration is required or whether it belongs to this vault's plan. Remove that part of the owner question or cite the requirement that makes it a separate scope decision; do not broaden the plan by implication.

4. **Decisions that block the plan, item 15 — split two independent decisions.** Paired-event ABI and the responsibilities/retention of `SwapProjection` and `ExecutionPreparation` can be answered independently. One owner answer about event signatures would not close the library-slot decision, and vice versa. Make these separate blockers, each with its own PRD sentence and owner question.

5. **Decisions that block the plan, item 13 — include the no-liquidity-added state transition, not only the event amount.** The item correctly notes that `Compounded.amount` is undefined, but APEX-2026-048 also makes the outcome for nonzero but undeployable/sub-quantum fees material. Clarify the owner question so it asks whether that call succeeds while leaving fees booked, and what state change and event, if any, result; otherwise the implementor must still choose the liveness behavior.

6. **Preserved disagreements — Quote step cap and tick spacing: do not add a new blocker without a requirement forcing that choice.** The draft appropriately refrains from adding one. APEX-2026-041 can remain a required regression against an undocumented cap in the new planner, while 026's Wings liquidation walk is not this vault's mechanism. The gas ceilings and intentional exact-out rejection already supply the relevant locked boundaries.

# What was not adopted from others

- From my original response, the exact matrix-file list and the complete 45-finding disposition table were not adopted. They should be restored in the final; they are mandatory outputs, not optional member detail.
- My one-token donation, live-price maintenance, additive-fee, compound-idle, query-surface, busy-view, and rate-provider concerns were adopted. The draft's further blockers concerning the zero-address share floor, sleeve value in issuance, shortfall units, first-mint units, WETH storage, paired events, and library slots are reasonable additions on the text presented in the draft.
- My original treatment of APEX-2026-039 as testable without another owner decision should be revised as described in Concern 2.
- I agree with not adding an owner-selected step cap or minimum tick spacing merely to answer APEX-2026-041/026. The final should preserve that restraint while still requiring the corresponding regression coverage.

# Limits

I reviewed only the named draft, using prior conversation context. I did not recompute its hash, reopen the PRD or audit sources, read peer feedback, implement anything, or run tests. Source checks and other members' positions are reported here only as characterized by the draft, not as independently re-verified evidence. This is one advisory round; it neither replaces the draft nor authorizes implementation.

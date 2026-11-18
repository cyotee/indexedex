# Identity

- Member: astra.
- Profile: research.
- Phase: advisory review.
- Run ID: v3-fullspread-v4-accounting-plan-20261116.
- Requested role: council-member.
- Requested model: chatgpt-subscription/gpt-6-astra:high.
- Actual runtime model, reasoning setting, account route, role, session identity, and task ID: not exposed.

# Draft under review

- Path: `docs/research/v3-fullspread-v4-accounting-plan-20261116/coordinator/draft.md`.
- Draft ID: `draft-v3-fullspread-v4-accounting-plan-20261116-r1`.
- Coordinator-supplied SHA-256: `f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314`.
- Fingerprint status: coordinator-supplied provenance; not recomputed.
- The exact draft was readable and was read in full.
- Additional evidence read: my own initial `members/astra/response.md` and the locked `docs/research/v3-fullspread-v4-accounting-prd-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_PRD.md`, solely to compare proposal fidelity and the locks.

# Disposition

requested-changes

The draft accurately preserves the central proposal: raw-liquidity issuance, the zero-address floor, separate booked custody, fee collection before adds, caller-held-share exits, fixed 49% sizing, retained external preview, and new facets. Step 8 accurately preserves both import locks: burn the emptied source NFT and permit imports after supply exists without replacing the destination position or resetting supply. The distinction between required preview widening and optional execution-return widening also represents my proposal accurately.

The corrections below concern executable instructions and acceptance coverage. They do not reopen those locks.

# Concerns

| ID | Draft section | Concrete execution defect or ambiguity | Advised correction |
| --- | --- | --- | --- |
| A1 | Step 3, "Callbacks must not spend booked balances"; Steps 4 and 7 | Step 3 says to reserve the operation so the callback transfer does not need booked tokens without limiting that instruction to another user's protected inventory. An exit must spend its own apportioned opposing booked claim, and authorized maintenance must be able to deploy eligible booked tokens. A blanket callback restriction would prohibit both. V3-ACC-09, V3-ACC-12, and V3-OWN-02 distinguish protected staying-holder custody from authorized operation budgets. | State the budgets explicitly: user adds and pass-through cannot consume booked custody; an exit may reserve and spend only its own floored booked claim; authorized maintenance may reserve its eligible booked input. Require each budget to be excluded from other available credit while in flight and reconciled on completion. Add cases proving a booked-funded exit and maintenance succeed while another user's add cannot consume those tokens. |
| A2 | Step 7, final V3-ACC-16 bullet; Step 4, disable and pool-lock bullets | Step 7 groups appointments with maintenance and then says "Maintenance remains available while the vault is disabled." Step 4 expressly requires disabled `setOperator` and `setOperatorFor` to revert. Step 7 also says maintenance cannot operate a locked pool without retaining Step 4's qualification that the route must require a pool operation. These formulations permit different gate implementations on the same new facet. | Name `donate` and `compound` as the two disabled-maintenance exceptions, and retain `VaultDisabled` for both appointment functions. Express pool locking in terms of required swap/mint/burn/collect actions rather than facet membership. Test the appointment and economic routes separately, including the specified empty-compound no-op, without inventing a new blanket lock on local administration. |
| A3 | Steps 5-7, package cut; Step 4, treatment of the old in-multi query facet | The draft removes SY and transition quotes but never settles the old many-to-one/one-to-many selector cuts. Step 4 even leaves removal of the old in-multi query facet conditional. My original proposal explicitly removed those legacy cuts because their old inverse/reserve semantics cannot serve as the adopted bundle semantics. Installing the new facets alone can leave the retired economic routes reachable. The loupe assertion cannot identify an "intended cut" while these entries remain undecided. | Explicitly adopt removal of the legacy multi-route selectors as a plan choice and list their disposition in the package-cut acceptance inventory. Move `previewExchangeIn` exactly once before retiring its old facet home. Assert legacy selectors are absent and the new bundle selectors retain V3-OWN-03 argument meanings; do not preserve old selectors by silently reinterpreting their arguments. |
| A4 | Step 7, V3-OWN-02 maintenance paragraph | The paragraph specifies one-token versus both-token behavior but does not define which balances determine that classification or the collection order. One author could branch on the directed donation alone; another could branch on collected fees plus booked balances plus that donation. For example, a token0 donation with token1 already booked would swap under the first reading and add proportionally under the second. My proposal expressly defined the combined eligible budget and distinguished it from stray custody booked after processing. | Carry the explicit sequence from my initial response section 7: collect unpaid destination fees, form eligible input from collected fees plus booked balances plus the directed donation, and choose one-token or proportional processing from that combined budget. Keep unrelated unbooked custody out of initial eligibility, retain actual-held-balance booking after qualifying processing, and preserve empty compound with stray custody as a no-op. State that underlying donation mints no shares. Add the mixed donation/booked-token case. |
| A5 | "Disagreement carried," test-filename bullet; Steps 0 and 9, test scope and acceptance | The draft says it names concrete test files so the author has one list, and Step 0 limits edits to the tree plus named tests. It names an import suite and a TestBase, but supplies no corresponding destination list for most new accounting, maintenance, gate, invariant, and gas coverage. More materially, it omits the independent economic oracles and stateful lifecycle acceptance from my original sections 3, 5, and 9. Shared planner previews and execution can agree while making the same accounting mistake. | Supply a concrete test destination and requirement mapping as plan choices, reconciling it with Step 0's fence. Require real manager/registry-deployed proxy tests and independent pre-state/share/claim/token-movement assertions. Restore a multi-holder sequence covering genesis, stray transfer, fees, later mint, later import, maintenance, partial exit, and final ordinary-holder exit. Include tiny burns with zero rounded liquidity but nonzero fee/booked claims, later-mint claim dilution, and complete failed-import rollback. Do not treat preview equality alone as economic proof. |
| A6 | Step 10, Gas | The numerical ceilings are carried accurately, but the measurement instruction permits one favorable state per route. It drops the state/direction/funding matrix and dense/dust-tick crossing coverage from my original section 10. A fixed 49% input still needs a swap simulation whose cost can vary with crossed ticks; ordinary-state measurements cannot establish the stated acceptance bar. | Retain the ceilings and add the required measurement matrix: first/later mints, both directions, supported funding modes, fee/booked-heavy exits, one-token and both-token maintenance, and genesis/later imports including NFT transfer/decrease/collect/burn. Include dense/dust-tick and substantial-crossing fixtures for quotes and economic routes. Record state, cold-call method, body/transaction gas, preview gas, and pass or unresolved status. Do not accept a revert as a successful route measurement or add a quote cap to obtain a pass. |

# What was not adopted from others

No peer response or feedback was read in this pass. The draft's descriptions of other members' positions are synthesis claims, not independently verified peer evidence here.

I do not request adoption of execution-return widening, a new storage slot, a new usage-fee key, a required `deployedReserve` selector, or the V4 zero-address `_mint` call. The draft properly distinguishes those alternatives from locked behavior. The proposed suite filenames and facet groupings remain plan choices; their spelling is not a product requirement.

# Limits

This was one advisory pass over the pinned draft, using only the two expressly permitted comparison files. No source implementation, other council artifact, peer original, or peer feedback was opened. No hash was computed. No test, build, gas measurement, Git operation, installation, sub-agent launch, or implementation was performed.

The source and runtime observations in my initial response were not independently rechecked in this pass. This feedback identifies drafting and execution-plan corrections, not verified code defects or measured performance failures. Only this owned feedback file was written.

This feedback does not authorize implementation and does not replace the draft. It requires no further advisory round.

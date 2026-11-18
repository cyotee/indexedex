# Resolution

- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Draft reviewed: draft-v3-fullspread-v4-accounting-plan-20261116-r1
- Draft path: docs/research/v3-fullspread-v4-accounting-plan-20261116/coordinator/draft.md
- Coordinator-supplied SHA-256: f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314
- Draft bytes changed after review: no
- Final path: docs/research/v3-fullspread-v4-accounting-plan-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_IMPLEMENTATION_PLAN.md
- This resolution does not authorize implementation and does not replace the locked PRD.

## Participants

| Label | Initial | Feedback | Disposition |
| --- | --- | --- | --- |
| astra | completed, st_01a1e6b4 | completed, st_01a1e6cc | requested-changes |
| grok | completed, st_01a1e6b5 | completed, st_01a1e6cd | requested-changes |
| minimax | completed, st_01a1e6b6 | attempt 1 st_01a1e6ce empty; attempt 2 st_01a1e6d2 completed | requested-changes |
| kimi | completed, st_01a1e6b7 | completed, st_01a1e6cf | requested-changes |

No initial response is missing. No feedback is missing. Silence was not treated as approval.

## Dispositions

| ID | Disposition | Why |
| --- | --- | --- |
| A1 | accepted | Step 3's callback sentence would block an exit's own booked claim and authorized maintenance. The final states the three budgets. |
| A2, G1 | accepted as a contradiction fix | Step 4 and Step 7 cannot both be followed. The final names `donate` and `compound` as the only disabled economic exceptions. |
| MM-2 | accepted in part | The disabled behavior of `setOperator` and `setOperatorFor` is not a locked V3-ACC-16 result. The final states it as a plan choice: those two selectors revert `VaultDisabled`. The administrative-outside-the-gate reading is not adopted. |
| A3 | accepted | The old multi-route cuts are removed. `previewExchangeIn` moves once. Old selectors are not reinterpreted. |
| A4 | accepted | Maintenance classifies the combined eligible budget, not the donation alone. |
| A5 | accepted | The final names test destinations and requires independent economic checks, including the lifecycle sequence. |
| A6 | accepted | Gas coverage is a matrix, not one favorable state. |
| G2 | accepted | Import carries deadline, disable, and locked-pool gates. |
| G3 | accepted | `exchangeOut` and the bundle routes carry their own gate order. |
| G4 | accepted | A zero-liquidity NFT that still yields tokens is collected. The zero-liquidity reject is not a V3-OWN-01 preserve. |
| MM-1 | accepted | The direct-transfer test names the token. |
| Kimi, Step 1 credit | accepted | Same correction as MM-1. |
| Kimi, pass-through preview | accepted | Word one is the planned swap output. |
| Kimi, V3-ACC-20 test | accepted | The later-mint exit uses enlarged supply, including the floor. |
| Kimi, dust ticks | accepted | Entry, exit, and gas include a tick-crossing path. |
| Kimi, `previewExchangeOut` gas | accepted | That preview is measured against 5,000,000. |

## Not adopted

- Widening `importPosition`'s return. Preview widening and the recipient transfer remain required. Execution-return widening stays a plan choice.
- A new storage slot, a re-keyed usage fee, a required `deployedReserve`, and the V4 `ERC20Repo._mint(address(0))` call.
- Classifying `setOperator` and `setOperatorFor` as administrative selectors that ignore `VaultDisabled`. That reading is recorded. The plan choice is the revert.

## Publication

The reviewed draft is unchanged. The admitted final is a new file. It incorporates the accepted corrections. It does not authorize implementation.

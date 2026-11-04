# Council report

## Identity

- Run ID: se-fullspread-implementation-plan-20261104
- Profile: research
- Council kind: full
- Question: Write the complete implementation and testing plan for `UniswapV4FullSpreadStandardExchangeVault` from the current PRD.
- Coordinator mode: invoking-agent
- Coordinator model: not exposed as a member route
- Final path: docs/research/se-fullspread-implementation-plan-20261104/REPORT.md
- Published plan: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md

## Participants

| Label | Requested model | Actual model | Actual reasoning | Task ID | Initial | Advisory |
| --- | --- | --- | --- | --- | --- | --- |
| astra | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high | high | st_01a1a3fe | response.md written | requested-changes |
| grok | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh | xhigh | st_01a1a3ff | response.md written | requested-changes |
| minimax | minimax/MiniMax-M3 | minimax/MiniMax-M3 | not exposed | st_01a1a400 | response.md written | requested-changes |
| kimi | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high | high | st_01a1a401 | response.md written | requested-changes |

Session IDs were not exposed. No member was replaced. No second advisory round was run. This report does not treat agreement as correctness.

## Evidence

The operative requirements are the current full-spread PRD and the 2026-11-04 owner locks. The four originals are `members/astra/response.md`, `members/grok/response.md`, `members/minimax/response.md`, and `members/kimi/response.md`. The reviewed draft is `coordinator/draft.md`, ID `draft-se-fullspread-implementation-plan-20261104-r1`, coordinator-supplied SHA-256 `32745f5d7579e53ae2121206add5114f1a451c2f467bb024ba7eba3371d96407`. No member recomputed that hash. The factory citation `PostDeployAccountHookFacet` at `DiamondPackageCallBackFactory.sol` line 31 was read by the coordinator before the draft used it.

## Conclusions

The published plan is the implementation and testing plan. It does not authorize implementation.

Accepted from the advisory reviews, and applied in the published plan:

- The query facet installs only `reserveOfToken` and `reserves`.
- The prohibition is a family `poolManager()` and a family `poolKey()`. The Crane getters stay callable.
- One-word `exchangeIn` decoders migrate with the preview readers. The migration must compile repo-wide.
- A one-token pretransfer over-max is not itself a revert. Existing minima and `MinLiquidityNotMet` still apply. A bundle over-max still reverts before any leg, with no new error.
- The floor mint runs only on the first successful deposit, not at initialization.
- `booked` and `reserved` are `uint256[2]` in `vaultTokens()` order. The idle unbooked formula uses the index, not an address key. Reservations are defined and are not pretransfer credit.
- Preview and execution call the same Planner function.
- `clampedFee` is the oracle fee capped at `3e17`. A zero `feeTo` mints no fee shares.
- Check order is stated for every public mutator, including the accepted bundle errors.
- Borrowed-path checks name the required values and the distinct errors. Settlement is sync, transfer or value, settle, then take, with no `settleFor`.
- A nonzero unpaid fee-owed read is collected before a maintenance swap or proportional add.
- FS-A38 and inventory row 045 share the same files. Standalone gas, preview gas, and composed gas have owning files.
- FS-OWN-13 is in the traceability table.
- The matrix adapter name is `SeMatrix_FullSpreadV4Fixture.sol`. Sibling behavior files sit beside the seven existing contracts. Those contracts are not edited to weaken other families.

Rejected:

- Installing `isOperator` and `isOperatorFor`. The PRD did not require them. Installing them would advertise a partial `IOperable`. The published plan states that they are absent.
- Treating MiniMax assumption A1 as an unconditional success with a zero output. Astra and Grok showed that the existing minimum still binds. The published plan keeps the over-max comparison from being a new revert and keeps the existing checks.
- A second advisory round. The brief authorized one round.

Deferred: none. The remaining name differences were recorded as names, not as open product questions.

## Limits

No Forge run, test, install, deployment, or Git operation was performed. Selector hex copied from the accepted report must be rechecked at implementation time. Gas, compiler, and hook results remain future evidence. This report is not an audit.

## Publication

- Plan path: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md
- Implementation authority: none

# Council report

## Identity

- Run ID: se-fullspread-hook-matrix-20261104
- Profile: research
- Council kind: full
- Question: Review the published full-spread plan and complete its hook-matrix so an implementer can add this vault's row to each of the seven topologies without inventing a binding.
- Coordinator mode: invoking-agent
- Final path: docs/research/se-fullspread-hook-matrix-20261104/REPORT.md
- Updated plan: contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md

## Participants

| Label | Requested model | Actual model | Actual reasoning | Task ID | Initial | Advisory |
| --- | --- | --- | --- | --- | --- | --- |
| astra | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high | high | st_01a1a420 | response.md written | requested-changes |
| grok | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh | xhigh | st_01a1a421 | response.md written | requested-changes |
| minimax | minimax/MiniMax-M3 | minimax/MiniMax-M3 | not exposed | st_01a1a422 | response.md written | requested-changes |
| kimi | kimi-coding/k3.1-pro:high, global route | kimi-coding/k3.1-pro:high | high | st_01a1a423 | response.md written | requested-changes |

Session IDs were not exposed. Astra's initial task reported no assistant output after the response file was written. The file was accepted. No member was replaced. No second advisory round was run. This report does not treat agreement as correctness.

## Evidence

The reviewed draft is `coordinator/draft.md`, ID `draft-se-fullspread-hook-matrix-20261104-r1`, coordinator-supplied SHA-256 `0ee55f1e89a984afe5b6f20fe2491b7220f7114bd1ea8120da99aaf57482932c`. No member recomputed that hash. The draft was not edited after review. The published correction is in the plan's section 12, plus the three path sentences in sections 3, 13, and 14.

## Conclusions

The plan's hook-matrix now names the seven real behavior paths, the seven primary row files, the weighted 3-leg row, the Balancer 5-leg row, and each topology's binding. The update does not authorize implementation.

Accepted from the advisory reviews, and applied in the plan:

- The opening sentence includes the separately named larger-leg rows.
- The PairToken identity record is one bind: the share is the leg token, the provider triple is explicit, and `providerFor` is not used. It passes only if that configuration is accepted and executes without a PairToken money call. A rejection is FS-HOOK-04. It does not become a raw-leg substitute for FS-A26.
- `test_row_identity_thisVault` is the FS-A24 attempt of `token == this vault`. It is not the canonical proof.
- Rows that override `setUp` call the family's TestBase `setUp` once and do not call the behavior `setUp`.
- Weighted 3-leg and both Balancer rows override every inherited public test that calls the fixed-length seed helpers. Those helpers stay non-virtual.
- `hasPartialCase()` is false, and the refund test is still overridden. The no-refund control is `amountRefunded == 0`. The hook refund is asserted on the hook's balance, not the swapper's.
- Exact-out is not a disjunction. The vault preview returns zero. The hook tests expect a revert and no payment.
- Curve and Balancer raw directions use the first raw token in the ascending sorted record.
- Product index 0 and product index 1 are separate cases from the two rate-target cases.
- The behavior-file edit ban does not block a mechanical `amountOut` decoder migration. If the ABI decoder already ignores the refund word, the comparison stays.

Rejected:

- Sibling behavior contracts. The PRD adds a row beside each behavior. Astra and MiniMax did not press this difference in advisory review.
- A second instance of this vault, or a V3 full-spread vault, as the canonical other SE. FS-HOOK-02 names PairToken.
- A rate-provider field on `single/`.
- Treating a rejected identity bind as an already specified runnable substitute.

Deferred: none. If the PairToken identity record is rejected at implementation time, FS-A26 stays open. That is the PRD rule, not an open product choice.

## Limits

No Forge run, test, install, deployment, or Git operation was performed. The matrix names the bindings. It does not claim those rows have been run. This report is not an audit and does not authorize implementation.

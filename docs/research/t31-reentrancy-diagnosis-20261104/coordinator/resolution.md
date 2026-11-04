# Coordinator resolution

## Identity

- Run ID: t31-reentrancy-diagnosis-20261104
- Draft reviewed: draft-t31-reentrancy-diagnosis-20261104-r1
- Draft path: docs/research/t31-reentrancy-diagnosis-20261104/coordinator/draft.md
- Draft bytes after review: unchanged. Corrections below are published in REPORT.md, not written back into the reviewed draft.
- This resolution does not authorize implementation.

## Dispositions

| Label | Disposition | Adopted |
| --- | --- | --- |
| astra | requested-changes | Yes. The final cause is conditional on the cited failed-frame semantics. Callback reach stays unverified. The process record no longer says the council ran no forge command. |
| grok | support | The central diagnosis is kept: a missing retained log does not prove the lock failed. |
| minimax | support-with-reservations | Yes. The regression-test name is labeled peer-reported. The two cited commits are not treated as two different rules. Empty-bytes decoding is stated as an ABI-decoder fact. The emit locator is line 252. |
| kimi | requested-changes | Yes. The uncited diamond sentence is removed. The limitation is whether the nested query reverted `IsLocked`. `MinAmountOutNotMet` is not treated as a reachable alternative on the empty-data path. |

No second advisory round. Astra and kimi said their corrections were citation and wording, not a request for another round. MiniMax supported the diagnosis and asked for the same class of precision.

## Corrections applied in the report

- The cause is conditional: under the cited failed-frame truncation, the oracle cannot pass once the outer swap reverts, even if the nested query returns `IsLocked`. That explains the supplied failure if the user's runtime has those semantics. It is not a trace of the callback path.
- The shared guard is present in the inspected source. It was not verified in the user's execution.
- Callback reach is unverified. The source places the permit pull before route execution.
- No member reran the test. MiniMax reported running `forge --version` despite the brief. That remains a process note, not proof of the user's binary.
- The diamond revert-forwarding sentence is removed. It had no locator in the draft's evidence.
- `MinAmountOutNotMet` at `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:132` runs only after `_runStep` returns. Empty `step.data` is decoded in `StockBalancerV3RouterAdapter.execute` before that payout check. It is not a reachable alternative on the reviewed empty-data path. The supplied message still has no selector.
- Grok's `testRecordLogsDiscardsRevertedCallLogs` is peer-reported. MiniMax could not locate that name in the tree at commit `430523103f3e2f9ba432ffdd2031a9f966153d0d`. The mechanism rests on `crates/cheatcodes/src/inspector.rs` truncation, which MiniMax reported at `:1050`, `:1072-1079`, and `:2267-2271`.
- MiniMax reported that `inspector.rs` is byte-identical at that commit and at v1.9.0 commit `6056c5845d34205a83cf7108042adb137325c9df`. The report does not treat those as two rules and does not pin the user's binary. This workspace has `/opt/homebrew/bin/forge` and `~/.foundry/bin/forge`. Kimi's moving-head upstream citation is supplementary only.
- The hostile emit is `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:252`. The override is `:237-256`.

# Coordinator draft

## Identity

- Draft ID: draft-t31-reentrancy-diagnosis-20261104-r1
- Run ID: t31-reentrancy-diagnosis-20261104
- Profile: research
- Phase: coordinator synthesis, not a member vote
- Question: What is the root cause of `test_T31_reentrancyDuringPullIsLocked` failing with `nested query must emit SawIsLocked (IsLocked under shared lock)`?
- This draft does not authorize implementation.

## Question and targets

The target is `test_T31_reentrancyDuringPullIsLocked` in `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol`, and the production and test code that assertion depends on. The failure text and gas are the user's supplied runtime. This council did not re-run the test.

## Evidence

Every member read the same assertion shape. The test calls `vm.recordLogs()`, catches `swapExactInWithPermit` in an empty `catch`, then fails unless `vm.getRecordedLogs()` still contains topic `keccak256("SawIsLocked()")`. Sources cited: `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`. The only emit of that event is inside `HostileReenterERC20.transferFrom`, and only when the nested `queryExactIn` returns failure data whose first four bytes equal `IReentrancyLock.IsLocked.selector` (`:227-255`).

Every member read the same lock. `swapExactInWithPermit` and `queryExactIn` are both `nonReentrant`. The modifier locks before the body and reverts `IReentrancyLock.IsLocked()` when the shared transient slot is already set. The permit pull is inside the locked body, before `_executeRoute`. Sources cited: `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`, `BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-33`, `ReentrancyLockModifiers.sol:21-29`, `ReentrancyLockRepo.sol:30` and `:95-98`.

Every member read the same later failure in source. The test step uses router `address(0xBEEF)` and empty `data`. `StockBalancerV3RouterAdapter.execute` `abi.decode`s that data as a six-field tuple before calling the child router. Empty bytes cannot decode. Sources cited: test `:101-113`; `StockBalancerV3RouterAdapter.sol:12-24`. MiniMax also names `MinAmountOutNotMet` at `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:132` as a fallback if execution reached that check. The supplied message contains no revert selector, so neither candidate is a trace.

Three members read Foundry's failed-frame rule. Grok cites public `inspector.rs` at the commit named by the local `forge` symlink, `430523103f3e2f9ba432ffdd2031a9f966153d0d`: a failed call frame truncates `recorded_logs` to the length stored at frame start, and the comment says failed-frame logs are reverted. Grok also cites that commit's `testRecordLogsDiscardsRevertedCallLogs`, which asserts that a log emitted inside `try emitAndRevert {} catch {}` is absent afterward. Kimi cites the same truncation in current public upstream `inspector.rs:1030-1082`. MiniMax cites the same truncation in Foundry v1.9.0 `inspector.rs:1072-1079`. Astra did not treat recorder retention as established from the local forge-std comments, which only say that `recordLogs` records logs and `getRecordedLogs` returns them (`Vm.sol:721-765`).

## Assumptions

- The user's rerun used a Foundry build with the failed-frame truncation those three citations describe. The supplied message does not name the binary. Grok and MiniMax name different commits. Both citations describe the same truncation rule. This draft does not pick one commit as the binary that produced the failure.
- Ordinary Solidity `abi.decode` of empty bytes reverts. That is inference from the adapter source, not revert data from the supplied run.
- MiniMax reported running `forge --version`. The brief forbade running forge. That report is recorded as a process note, not as proof of the user's binary.

## Coverage

| Target | Status |
| --- | --- |
| T31 assertion and hostile token | Examined by all four |
| Shared lock, pull-before-route, empty step data | Examined by all four |
| Foundry failed-frame log rule | Examined by grok, kimi, and minimax against public inspector source. Not examined by astra as a runtime rule |
| Supplied revert selector or trace | Absent. The empty catch discards it. This council did not run forge |
| Previous diagnosis reports | Optional. Not used as evidence |

## Conclusions

The cause of this failing assertion is the test's log oracle, not a missing shared lock.

The assertion requires `SawIsLocked` to remain in Foundry's recorded-log buffer after `swapExactInWithPermit` returns to the test. The only emit is inside that call. The test's own comment says the outer call reverts, and the source makes a successful return unreachable once the pull returns: the adapter must decode empty step data. On the Foundry rule cited by grok, kimi, and minimax, a failed frame truncates recorded logs back to the checkpoint taken when the frame started. Catching the error in the test does not keep those logs. The assertion then fails with exactly the supplied message even if the nested query reverted `IsLocked()` and the token emitted.

The shared lock is present in the source all four members read. Both entries use one modifier and one transient slot. The lock is taken before the permit pull. The diamond forwards facet revert data unchanged. Nothing in the supplied message shows that lock absent, released early, or bypassed.

What the supplied message proves: the assertion at the cited `assertTrue` ran with no retained `SawIsLocked` topic, at the reported gas.

What it does not prove: that `transferFrom` ran, that the nested query failed to revert `IsLocked()`, that the marker was not emitted before the outer frame failed, or which error the empty catch swallowed. Astra is right that those three cases are indistinguishable from the failure text alone. Grok, kimi, and minimax are right that the source the test executes cannot retain the marker across the outer revert the test expects. The cause of the assertion is that observation gap. The message is not a trace that fills it.

The exact outer revert selector is not settled. Grok and kimi name the empty-data decode. MiniMax also names `MinAmountOutNotMet` as a later fallback. Either revert fails the same outer frame and, under the cited Foundry rule, discards the same logs. The selector is not required to name the oracle failure.

## Limits

- No member re-ran the test. Callback reach in the user's run is inferred from source order, not from a trace.
- The Foundry citations are public source for commits the members named. They are not a hash of the binary that produced the supplied message.
- This draft does not authorize an edit. The evidence implies only that a later observation of the nested `IsLocked` result has to survive the outer revert. It does not choose a replacement oracle.

## Member positions

| Label | Position on the cause |
| --- | --- |
| astra | Root cause of the missing marker in the supplied run is not established. The message proves only that the expected topic was absent |
| grok | The assertion fails because this Foundry drops logs from the reverted swap the test catches. A missing log does not prove the lock failed |
| minimax | The observation channel is destroyed by the outer revert. The guard is shared and is not the defect |
| kimi | Test-oracle and log-lifetime failure. Empty route data reverts the outer frame after the pull, and Foundry truncates that frame's logs |

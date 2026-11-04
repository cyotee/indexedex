# T31 reentrancy diagnosis

## Answer

Under Foundry's failed-frame log truncation, `test_T31_reentrancyDuringPullIsLocked` cannot pass once `swapExactInWithPermit` reverts, even if the nested query returns `IsLocked`. The missing `SawIsLocked` log is the test oracle failing. It is not evidence that the shared lock is absent.

That explains the supplied failure if the runtime that produced it has the truncation rule cited below. The failure text does not prove the callback ran, and it does not prove the lock held in that run. The lock is present in the inspected source. It was not verified in the user's execution.

This report does not authorize an edit.

## What the supplied message proves

The assertion at `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:140` ran with no retained log whose first topic is `keccak256("SawIsLocked()")`. Reported gas was 1626168.

## What it does not prove

It does not prove whether `transferFrom` ran, whether the nested query reverted `IsLocked`, whether `SawIsLocked` was emitted before the outer frame failed, or which error the empty `catch` swallowed. Those cases are indistinguishable from the failure text alone.

## Why the assertion cannot observe a working lock

The test records logs, catches `swapExactInWithPermit`, and then searches the buffer (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:128-140`). The test comment at line 128 says the outer call reverts and that the log is the intended observation.

`SawIsLocked` is emitted only inside `HostileReenterERC20.transferFrom`, and only when the nested `queryExactIn` fails with `IReentrancyLock.IsLocked.selector` (`:237-256`; the emit is `:252`). That call is inside the swap the test catches.

`swapExactInWithPermit` is `nonReentrant`. It pulls the permit, then executes the route (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:41-48`). `queryExactIn` uses the same modifier (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-33`). The modifier locks before the body and reverts `IReentrancyLock.IsLocked()` when the shared transient slot is already set (`lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-29`; `lib/crane/contracts/access/reentrancy/ReentrancyLockRepo.sol:95-98`).

After a successful pull, the route cannot return. The single step uses router `address(0xBEEF)` and `data: ""` (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:104-109`). `_runStep` dispatches that data to the adapter (`BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:102-116`). `StockBalancerV3RouterAdapter.execute` decodes it as a six-field tuple before calling the child (`contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol:18-19`). The Solidity ABI decoder rejects insufficient data. `MinAmountOutNotMet` at `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:132` runs only after `_runStep` returns, so it is not reachable on this empty-data path. The supplied message still contains no selector.

Foundry truncates recorded logs when the emitting frame fails. MiniMax reported that truncation in `crates/cheatcodes/src/inspector.rs` at `:1050` (checkpoint at frame start), `:1072-1079` (failed-frame logs are reverted), and `:2267-2271` (`call_end`). MiniMax also reported that this file is byte-identical at commit `430523103f3e2f9ba432ffdd2031a9f966153d0d` and at v1.9.0 commit `6056c5845d34205a83cf7108042adb137325c9df`. Grok reported the same truncation at the first commit, and reported a Foundry test named `testRecordLogsDiscardsRevertedCallLogs`. MiniMax could not locate that test name in the tree at that commit, so the report does not rely on it. Kimi's citation of current public upstream `inspector.rs:1030-1082` is moving-head corroboration only.

Local forge-std does not state this rule. `recordLogs` and `getRecordedLogs` are documented only as record and return (`lib/crane/lib/forge-std/src/Vm.sol:723` and `:765`).

Catching the outer error does not keep logs from the failed frame. If the nested query returns `IsLocked` and the token emits, the later route revert still drops that log before line 140 reads the buffer. If the pull never reaches `transferFrom`, there is also no retained marker. Either way the assertion fails. The text cannot say which one happened.

## Runtime assumption

The supplied message does not name the Foundry binary. This workspace has `/opt/homebrew/bin/forge` and `~/.foundry/bin/forge`. The two commits named above are not two different truncation rules on the file MiniMax compared. Whether the user's rerun used a build with that file is an assumption. Earlier suite runs in this session used `~/.foundry/bin`. That is session context, not a fact in the failure text.

No member reran the test. MiniMax reported running `forge --version` despite the brief. That query is not proof of the binary that produced the failure.

## Review

| Label | Disposition |
| --- | --- |
| astra | requested-changes, adopted as the conditional wording above |
| grok | support |
| minimax | support-with-reservations, adopted as the citation limits above |
| kimi | requested-changes, adopted as the removed diamond sentence, the neutral `IsLocked` limitation, and the unreachable payout check |

Draft `draft-t31-reentrancy-diagnosis-20261104-r1` was not rewritten after review. The corrections are in this report and in `coordinator/resolution.md`.

## Limits

Callback reach in the user's run is unverified. No trace was captured. This is not a proof of deployed bytecode. The report does not choose a replacement oracle. A later observation of the nested `IsLocked` result would have to survive the outer revert. That sentence is not an authorized edit.

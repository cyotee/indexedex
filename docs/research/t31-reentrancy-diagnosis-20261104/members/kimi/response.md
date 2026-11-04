# Independent research response

## Identity

- Member: kimi
- Profile: research
- Phase: initial independent response
- Role: council-member
- Requested model: `kimi-coding/k3.1-pro:high`
- Route: global
- Actual runtime model, task ID, and conversation ID: not exposed

## Question and targets

Question: What is the root cause of `test_T31_reentrancyDuringPullIsLocked` failing with `nested query must emit SawIsLocked (IsLocked under shared lock)`? The assigned target is the named function in `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:99-140` and the production or test code on its call path. The failure text and gas are supplied runtime evidence, not a fresh council run (`docs/research/t31-reentrancy-diagnosis-20261104/brief.md:77-81`).

## Evidence

### Source observation: the assertion observes logs only after catching the outer call

- The test registers `0xBEEF` as a stock Balancer V3 router and gives the route step empty `data` (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:101-109`).
- The test arms and funds the hostile token, approves Permit2, and constructs a signature over the route parameters (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:122-126`, `:161-212`).
- The outer `swapExactInWithPermit` is wrapped in `try ... catch {}`. After it returns to the test, the test calls `vm.getRecordedLogs()`, searches for topic `keccak256("SawIsLocked()")`, and asserts that a match was found (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`). The empty `catch` does not expose the outer revert reason.
- The hostile token's armed `transferFrom` makes a low-level call to `queryExactIn`. It emits `SawIsLocked` only when that call fails and the first four revert-data bytes equal `IReentrancyLock.IsLocked.selector`; it then returns `true` (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:227-255`). Thus the marker is emitted inside the token call beneath the outer swap, not by the test contract after the outer revert.

### Source observation: the pull precedes route execution, and both entries use the same lock

- `swapExactInWithPermit` is `nonReentrant`; after validation it calls `_pullPermit` and only then `_executeRoute` (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`). Permit2's signature-transfer path calls `safeTransferFrom` on the permitted token after nonce and signature processing (`lib/crane/contracts/protocols/utils/permit2/SignatureTransfer.sol:75-82`).
- `queryExactIn` is also `nonReentrant` (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-33`). Their common base inherits `ReentrancyLockModifiers` (`contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol:22`).
- The modifier checks `_onlyUnlocked`, locks, executes the function body, and unlocks only after successful completion (`lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-29`). `_onlyUnlocked` reverts `IReentrancyLock.IsLocked()` when the shared transient slot is active (`lib/crane/contracts/access/reentrancy/ReentrancyLockRepo.sol:89-99`). The interface used by production re-exports the same interface used by the hostile token (`lib/crane/contracts/interfaces/IReentrancyLock.sol:3`), whose error is `IsLocked()` (`lib/crane/contracts/access/reentrancy/IReentrancyLock.sol:18-23`).

### Source observation and inference: empty route data supplies the later outer revert

- **Source observation:** `_runStep` dispatches execution with `step.data` (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:102-116`). The stock adapter first decodes that data as `(address,address,address,uint256,bool,bytes)` and only afterward calls the child router (`contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol:12-24`).
- **Inference:** decoding the test's empty byte string as that six-field tuple cannot succeed, so once the pull has completed, route execution reverts at the decode before any call to `0xBEEF`. This ordering follows from the pull-before-route source at `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:47-48` and the decode-before-child source at `StockBalancerV3RouterAdapter.sol:18-24`.

### Source observation: Foundry rolls back recorded logs for failed frames

- The local forge-std interface exposes `getRecordedLogs` and `recordLogs`, but its comments do not define failed-frame retention (`lib/crane/lib/forge-std/src/Vm.sol:721-723`, `:763-765`).
- Current public upstream Foundry source records a checkpoint containing the recorded-log count and buffer generation when a call frame starts (`foundry_cheatcodes/inspector.rs:1030-1052`). When `finish_created_accounts_frame` receives `success == false`, it explicitly states that failed-frame logs are reverted and truncates the recorded-log buffer to that checkpoint, or to zero if the buffer was replaced (`foundry_cheatcodes/inspector.rs:1055-1082`). Retrieved from [Foundry's `inspector.rs` source, lines 1030-1082](https://foundry-rs.github.io/foundry/src/foundry_cheatcodes/inspector.rs.html#1030-1082). Relevant public query: `site:foundry-rs.github.io/foundry "recorded_logs"`; no private source excerpt was sent.

### Inference: complete mechanism

1. On the source-intended successful permit path, Permit2 calls the hostile token while the outer swap holds the lock (`BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:41-48`; `SignatureTransfer.sol:75-82`). The nested `queryExactIn` reaches the same modifier and returns `IsLocked`, causing the hostile token to emit `SawIsLocked` (`BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-33`; `ReentrancyLockRepo.sol:95-98`; `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:244-252`).
2. The hostile `transferFrom` then returns successfully, allowing the outer swap to proceed to route execution (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:237-255`; `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:47-48`). The empty step data causes the later adapter decode revert (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:105-109`; `StockBalancerV3RouterAdapter.sol:18-24`).
3. That later failure is the failure of the outer swap frame containing the marker emission. Under the cited Foundry failed-frame cleanup, the marker is truncated from the recorder before `vm.getRecordedLogs()` runs (`foundry_cheatcodes/inspector.rs:1030-1082`; `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`). Catching the outer error in the test does not retain the reverted frame's logs.
4. The resulting `found == false` produces exactly the supplied assertion message at `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:133-140` without requiring a missing or separate production lock.

## Assumptions

- The reachability chain assumes permit verification, the token transfer, and setup complete as their source intends. The supplied assertion text alone does not prove those steps ran.
- The Foundry failed-frame behavior is read from current public upstream source. The exact source revision of the binary used for the supplied run was not supplied or inspected.
- No compiler-specific deviation from ordinary empty-input ABI decoding is assumed.
- The workspace was read as live files, not as an atomic whole-repository snapshot.

## Coverage

| Target | Status |
| --- | --- |
| Named T31 test and `HostileReenterERC20` | Examined at `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:99-140`, `:161-212`, and `:216-256` |
| Execute, query, shared lock, Permit2 pull, and stock-adapter decode | Examined at the cited production and dependency paths |
| Local forge-std log interface | Examined at `lib/crane/lib/forge-std/src/Vm.sol:721-723` and `:763-765`; it does not specify failed-frame retention |
| Foundry failed-frame implementation | Current public upstream `foundry_cheatcodes/inspector.rs:1030-1082` examined; exact supplied-run binary revision not examined |
| Two optional previous reports | Examined as context only; no prior conclusion is used as behavioral evidence |
| Peer response or feedback files | Not examined, as instructed |
| Fresh test, trace, forge, Git, install, or deployment | Not performed, as instructed |

## Conclusions

**Root cause:** the test's observation mechanism expects `SawIsLocked` to survive an outer call that the test itself catches after route failure. The source path places the marker emission during the pull before `_executeRoute`, then decodes empty route data and reverts the outer frame (`BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:47-48`, `:102-116`; `StockBalancerV3RouterAdapter.sol:18-24`; `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:244-252`). Foundry's failed-frame cleanup truncates the recorder to its pre-call checkpoint, so the subsequent search cannot retain that marker (`foundry_cheatcodes/inspector.rs:1030-1082`; `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`). This is a test-oracle/log-lifetime failure, not evidence that the shared production reentrancy lock is absent.

The supplied message proves that the final `assertTrue(found, ...)` observed no retained matching log (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:131-140`; `docs/research/t31-reentrancy-diagnosis-20261104/brief.md:77-81`). It does **not** prove whether `transferFrom` ran, whether the nested query returned `IsLocked`, whether `SawIsLocked` was emitted before rollback, or which error the empty `catch` swallowed (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`, `:237-253`). Static source establishes the shared-lock path and the log-discard mechanism; it does not convert those unobserved runtime steps into trace evidence.

This response does not authorize implementation.

## Limits

- No fresh runtime trace was available or produced. Callback reach and marker emission before rollback are source-based inference, not observations from the supplied run.
- The cited Foundry implementation is current public upstream source, not a verified source match for the supplied run's binary. The local forge-std interface alone does not document failed-frame log retention (`lib/crane/lib/forge-std/src/Vm.sol:721-723`, `:763-765`).
- The outer revert reason is hidden by the test's empty `catch`; the empty-data decode revert is inferred from the cited source order rather than decoded from supplied revert data (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-130`; `StockBalancerV3RouterAdapter.sol:18-24`).
- Live files can change; this is not an atomic repository snapshot.

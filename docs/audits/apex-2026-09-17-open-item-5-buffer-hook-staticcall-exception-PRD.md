# PRD: Balancer buffer-hook interface probes as a D37 exception (APEX open item 5)

- **Parent plan:** [apex-2026-09-17-remediation-and-regression-tests.plan.md](./apex-2026-09-17-remediation-and-regression-tests.plan.md) (D30, D37, D41, D48, R14.9, R14.20)
- **Open-items file:** [apex-2026-09-17-review-open-items.md](./apex-2026-09-17-review-open-items.md) item 5
- **Created:** 2026-09-21
- **Status:** executed 2026-09-21; full hermetic run 4 green (32,714/32,714)
- **Execution boundary:** one plan amendment, tests, and evidence. No production change is expected; the six hook targets stay as they are unless a boundary test shows a probe is doing more than interface detection.

## 1. Objective

Turn the two `staticcall` patterns that remain in the six Balancer buffer-pool hook targets into a recorded, owner-approved exception to D37 (the way D41 and D48 are), and prove its boundaries with tests: the router prepay hand-off is skipped only when the router has no prepay interface and is a hard call otherwise; the vault walk skips a candidate only on a failed or zero preview, and every operative Standard Exchange call is hard.

## 2. Current state (verified 2026-09-21)

| Fact | Evidence |
| --- | --- |
| Six hook targets carry the probe: `constProd/standardExchange/StandardExchangeBufferHookTarget.sol`, `stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol`, `stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol`, `weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol`, `weighted/mixedLegBuffer/MixedLegWeightedBufferPoolHookTarget.sol`, `weighted/multiPairBuffer/MultiPairStandardExchangeBufferHookTarget.sol`. | `rg 'function _isPrepayRouter'` |
| Prepay hand-off: `_isPrepayRouter(seRouter)` staticcalls `prepaySessionActive()`; only a 32-byte reply selects the router. `_passPrepay` / `_restorePrepay` then call `passPrepayAuth(seVault)` / `restorePrepayAuth()` directly (hard). A router without the selector is skipped. | e.g. stable common target lines 515 to 530 |
| Vault walk: `_tryPreSeatFromVault` and `_tryReconcileVault` staticcall the SE's `previewExchangeOut` / `previewExchangeIn`; a failed call, non-32-byte reply or zero result returns `false` and the loop moves to the next vault; the operative `_doPreSeat` / `_doReconcile` is a direct internal call whose revert propagates. | stable common target lines 330 to 352 and 436 to 452 |
| At HEAD both the previews and the operations, plus the prepay hand-offs, were `try`/`catch` (previews caught, operations caught through an external self-call, prepay `try … catch {}`). | `git show HEAD:…HookTarget.sol` |
| Reason recorded for the probe: the hermetic Crane `RouterMock` used by every buffer-pool suite has no prepay interface; an unconditional hard hand-off broke every `test_swap_*`. | plan "Deviations" |
| No test today exercises the prepay hand-off in either direction (`rg 'passPrepayAuth|prepaySessionActive'` over the pool test tree returns nothing). | inventory 2026-09-21 |
| Vault-walk tests exist (`*_WalkAndExhaust*.sol`, `*_RoutingAndWalk*.sol`, M11 / S1 / L21 families) and cover walking past an exhausted vault; whether they cover a vault whose preview *reverts* and an operative call that reverts is to be confirmed in step 1. | test inventory |
| Real IndexedEx SE routers implement `IBalancerV3StandardExchangeRouterPrepay` (`routers/prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol`), so in production the hand-off is always the hard path. | source |

## 3. Locked decisions

| ID | Decision |
| --- | --- |
| P1 | **D49 (amendment to D37).** The Balancer buffer-pool hook packages keep two `staticcall` probes as interface detection, on the same footing as D41 and D48: (a) `prepaySessionActive()` selects whether the SE router receives the prepay hand-off; (b) the SE `previewExchangeIn` / `previewExchangeOut` probe selects which vault the walk uses. Both are reads with no state change. Every operative call that moves tokens or shares (`passPrepayAuth`, `restorePrepayAuth` once selected, `exchangeIn`, `exchangeOut`, `addLiquidity`, `removeLiquidity`, Vault `sendTo`) stays a hard call whose revert propagates unchanged. No other catch or soft call is permitted by this amendment. |
| P2 | The amendment is written into the plan's Decisions table as D49 and into the evidence file's R14.9 row; D37's inventory note "including prepay-auth and post-swap deposits become hard calls" is annotated to point at D49. |
| P3 | Tests prove both boundaries per §4 on every one of the six packages through their existing gold TestBases and deployment paths. No production SUT mocks. The routers used as the "prepay-capable" and "prepay-less" fixtures are the real IndexedEx `BalancerV3StandardExchangeRouter` package and Crane's `RouterMock` respectively; no new router mock is written. A dependency failure fixture for the SE side follows `contracts/test/stubs/APEXDependencyFailureStubs.sol`. |
| P4 | If a boundary test shows a probe skipping anything other than a missing interface or a failed/zero preview, that is a defect: fix the target under this PRD's evidence rules (red then green), do not widen the exception. |
| P5 | No change to `RouterMock` in Crane, no Crane commit or pointer bump (D21). |

## 4. Boundary tests (per package, six packages)

| Test | Assertion |
| --- | --- |
| `test_D49_prepayRouter_handoffIsHard_revertPropagates` | Pool bound to an SE leg whose router is the real IndexedEx SE router (prepay-capable). Make `passPrepayAuth` revert for the hook (for example, the hook is not the authorized prepay caller, or the session is closed). The swap or join that triggers reconcile reverts with the router's own error; balances, BPT supply and SE shares unchanged. |
| `test_D49_prepayRouter_handoffSucceeds_funded` | Same fixture with the hand-off authorized: the reconcile completes, the router's prepay session ends restored (`prepaySessionActive()` back to its pre-call value), SE shares are received by the pool. |
| `test_D49_noPrepayRouter_handoffSkipped_swapCompletes` | Pool bound to an SE leg reached through Crane `RouterMock` (no prepay selector). The probe returns `false`, no hand-off is attempted (assert no call to `passPrepayAuth` via `vm.expectCall` count zero or a recording router), and the swap completes with the same output as the prepay-capable case for an SE that does not need prepay. |
| `test_D49_walk_previewRevert_skipsToNextVault` | Two or more SE legs; make the first leg's `previewExchangeIn` (reconcile) or `previewExchangeOut` (pre-seat) revert using a non-SUT failure fixture on that SE's dependency, or a paused underlying that makes the preview revert. The walk uses the next vault; the first vault's shares and the pool's books for it are unchanged. |
| `test_D49_walk_previewZero_skipsToNextVault` | Same with a preview that returns 0 (exhausted or capped vault); next vault used. Existing WalkAndExhaust / RoutingAndWalk tests may satisfy this; record the exact names instead of duplicating. |
| `test_D49_walk_operativeRevert_propagates` | Preview succeeds, then the operative `exchangeIn` / `exchangeOut` on the selected vault reverts (non-SUT failure fixture). The whole swap or join reverts with the SE's original bytes; nothing is skipped to a later vault; full rollback of transfers, shares, books and allowances. |
| `test_D49_noOtherSoftCalls` | Source scan asserted in the evidence: `rg -n '\.staticcall\('` in the six targets lists only the `prepaySessionActive`, `previewExchangeIn` and `previewExchangeOut` probes. Any other staticcall is a finding. |

The single-vault packages (`StandardExchangeBufferHookTarget`, `MixedLegWeightedBufferPoolHookTarget`, `MultiPairStandardExchangeBufferHookTarget`) run the walk tests against their walk-equivalent (single candidate: preview revert or zero means the operation is skipped and the swap settles from the physical buffer, or reverts if the pool cannot settle; record which).

## 5. Work packages (parallelizable by package)

| WP | Deliverable |
| --- | --- |
| WP0 | D49 text in the plan Decisions table and evidence R14.9 row; §4 test-name inventory of what already exists (walk/exhaust suites). |
| WP1 | `StandardExchangeBufferHookTarget` (constProd) boundary tests. |
| WP2 | `CommonBufferMultiVaultStablePoolHookTarget` and `MixedBufferMultiVaultStablePoolHookTarget` boundary tests. |
| WP3 | `CommonBufferMultiVaultWeightedPoolHookTarget`, `MixedLegWeightedBufferPoolHookTarget`, `MultiPairStandardExchangeBufferHookTarget` boundary tests. |
| WP4 | Evidence: `catch-sites.json` rows for the six targets marked `D49_STATICCALL_PROBE`, `r12-gating.json` `catchScan.d49Staticcall` list, open-items item 5 closed. |

## 6. Acceptance criteria

- [x] A1. D49 is recorded in the plan and evidence with the exact two probe sites per package (file and line).
- [x] A2. Every package has passing tests for: hard hand-off revert propagation, funded hand-off success, skipped hand-off on a prepay-less router, preview-revert skip, preview-zero skip (new or named existing), operative revert propagation.
- [x] A3. The staticcall source scan over the six targets lists only the three probe selectors.
- [x] A4. No production source change, unless P4 triggered one, in which case the red/green pair is recorded like every other APEX fix.
- [x] A5. Full hermetic suite green; `git diff --check` clean; Crane tree untouched beyond the two NatSpec files already recorded.

## 7. Verification

```bash
rg -n '\.staticcall\(' \
  contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferHookTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/CommonBufferMultiVaultStablePoolHookTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/MixedBufferMultiVaultStablePoolHookTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/CommonBufferMultiVaultWeightedPoolHookTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/MixedLegWeightedBufferPoolHookTarget.sol \
  contracts/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/MultiPairStandardExchangeBufferHookTarget.sol
rg -n '\b(try|catch)\b' contracts/protocols/dexes/balancer/v3/pools --glob '*.sol' | grep -v '/test/\|TestBase_'   # expect no executable hit

forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/**' --match-test 'test_D49_' -vv
forge test -vv
```

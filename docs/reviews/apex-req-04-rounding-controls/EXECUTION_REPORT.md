# REQ-04 execution report

Date: 2026-10-16

Current status: COMPLETE under the owner-authorized follow-up. Production and test compilation passed. All 175 focused rows passed, including all 17 previously failing rows. The full six-family regression suite passed: **3,642 tests, 0 failures, 0 skipped across 383 suites**. The original run and its stop condition are preserved below.

## Authorized follow-up

After diagnosis reproduced all 17 failures, the owner requested all suggested corrections. The PRD and plan now record that authorization.

- Both quad single-deposit execution paths use the validated zero-aware quote, followed by `ZeroAmount()` before taking input. The strict shared math libraries are unchanged in this follow-up.
- Dual preview returns before issuing an underlying SE `DepositExactIn` transition when the internal swap sale is zero. This avoids Aerodrome's `InvalidQuoteState()` and the Balancer-backed zero-deposit underflows without catching arbitrary errors.
- Balancer SimpleYield F6/F9 and Orbital RebasingAware now have explicit positive one-unit fixture controls, with fixed expected LP amounts of `240384615373`, `240384613`, and `1`. These assert preview/execution parity, recipient LP balance, exact input debit, exact SE inventory and no new face residual. Default fixtures still require zero preview and execution rejection; expected behavior is never selected from the observed preview.
- Both quad zero-share tests now require exactly `ZeroAmount()`. The other named-selector controls and all exact-output share-debit assertions remain.

The follow-up changes three production files and six test files. [Incremental diff](./evidence/followup-implementation.diff) and [scope checks](./evidence/followup-static-checks.json) distinguish these changes from the existing workspace. Validation runs the artifact helper first for the focused rows, then for the full six-family suite: [focused command](./evidence/followup-focused-command.json), [focused log](./evidence/followup-focused.log), [full command](./evidence/followup-full-command.json), [full log](./evidence/followup-full.log). The runner stops if a stage fails.

Focused validation completed with exit code 0: **175 passed, 0 failed, 0 skipped** across 175 suites. All 17 previously failing rows passed. Production compilation refreshed 39 files in 75.85 seconds; test compilation refreshed 91 files in 2002.37 seconds. Both succeeded with warnings. Focused runtime took 175.42 seconds. [Machine-readable follow-up results](./evidence/followup-results.json).

Full validation completed with exit code 0: **3,642 passed, 0 failed, 0 skipped across 383 suites**, in 2021.51 seconds. The full selection reused production artifacts and compiled four additional test units in 48.18 seconds, successfully with warnings. All **175 exact-output share-debit checks** passed (29 per family, plus Curve's inherited recurrence row). All **six liquidity-accounting invariant suites** passed, each with 256 runs, 16,384 calls and zero reverts. The follow-up meets the amended acceptance criteria.

Final `git diff --check` passed. Source hashes confirm exactly the declared three production and six test changes relative to the follow-up starting state; the strict math libraries and excluded non-CP behavior are unchanged. Changes remain uncommitted. No deployment or broadcast was performed.

## Original execution

Initial status: STOPPED at the plan’s explicit execution-selector gate. Implementation applied; compilation and the prescribed validation run finished. The original remediation acceptance criteria were not met.

The user explicitly requested execution of `REMEDIATION_PRD.plan.md`. The controlling document is [REMEDIATION_PRD.md](./REMEDIATION_PRD.md).

## Original scope and implementation

The initial workspace contained existing modifications, deletions, staged changes, and untracked files. See [starting Git status](./evidence/git-status-before.txt). Changes in this execution are limited to the four named quad production sources, the six named matrix behavior tests, and execution evidence in this directory.

- Verified the plan's source preconditions before editing: Balancer math line 291 was the bare invariant subtraction; Curve math lines 463 and 465 were the named reverts.
- Added preview-only single-join math in both quad libraries. Converted zero inputs and non-increasing invariant growth return zero; a share division that rounds down returns zero. Existing fee, supply, index, and book validation remains in the applicable math paths.
- Routed the face-token deposit preview through the new quote helpers. Curve retains its existing inactive/invalid-token handling and existing flexible SE-share route.
- Added `if (shares == 0) revert ZeroAmount();` after each existing strict execution quote and before input transfer, exactly as the plan directs. Strict execution math is unchanged.
- The six rounding controls now require a successful preview of zero, then execution rejection with the specified selector(s), with caller/hook/book balances unchanged. Removed preview-revert echoing and successful zero-share retention branches.
- Corrected Orbital's preview selector to the two-argument form; retained its six-argument execution call.
- Each exact-output share assertion captures the face-leg SE's `previewExchangeOut` before execution. Recorded SE `Transfer` logs count only zero-address mints to the hook during settlement. The assertion is `before + mintedBack == after + expectedDebit`, so the net balance decrease plus minted-back shares equals the quoted debit.
- Existing funded-swap, refund, and code-less-caller controls remain.

[Implementation diff relative to the starting workspace](./evidence/implementation.diff) isolates these edits from pre-existing changes. [Starting source hashes](./evidence/source-hashes-before.json) cover all hook production and test sources under the relevant tree.

## Original validation

Ran the prescribed command from the existing warm checkout, preserving `out/`, `cache_forge/`, configured source/test paths, and `via_ir = false`:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol \
  contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/dual \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve \
  -- -vv
```

The first attempt is captured in [forge-validation.log](./evidence/forge-validation.log). Production compilation passed (42 files, 96.20 seconds), and test compilation passed (191 files, 3261.95 seconds), both with warnings. Before executing tests, Forge crashed in macOS system proxy discovery (`system-configuration` / `SCDynamicStoreBuilder`, "Attempted to create a NULL object"). The helper exited with code 250; there are no runtime test results from that attempt.

The same command was retried outside the sandbox after approval, preserving the compiled artifacts. Retry output is captured in [forge-validation-retry.log](./evidence/forge-validation-retry.log). The retry skipped both compilation stages and completed with **exit code 1: 3,625 passed, 17 failed, 0 skipped, 3,642 tests across 383 suites**. Forge reported 3669.48 seconds for the runtime suite. All 17 failures are `test_row_partialConsumption_bookedNotRefunded()` rounding controls.

All **175 exact-output share-debit checks passed**: 29 each for weighted, dual, single constant-product, orbital, and Balancer quad; 30 for Curve quad (including its inherited recurrence suite). All **six liquidity-accounting invariant suites passed**, each with 256 runs, 16,384 calls, and zero reverts.

Machine-readable results: [results.json](./evidence/results.json). The prescribed run was completed; no follow-up test runs or production changes were made after observing the stop-condition failure.

Static checks: `git diff --check` passed. Original strict single-join functions (and Balancer's shared unbalanced join) remain byte-for-byte unchanged. All non-quad hook production sources and the excluded non-CP behavior file match the initial hashes.

## Original stop condition

The prescribed runtime check reached the plan’s explicit stop condition:

- **Curve quad:** a zero preview is followed by execution selector **`0x00bf0cb2` (`MathDomain()`)**, rather than an allowed selector. This occurs in MorphoBlueStandardExchange, RebasingAwareERC4626, SimpleYieldERC4626Control, its F6/F9 variants, and the inherited Permit2Recurrence row. `cast sig 'MathDomain()'` independently confirmed the selector.
- **Balancer quad:** RebasingAwareERC4626 previews zero but execution returns **`0x4e487b71` (`Panic(uint256)`)**.

The plan explicitly requires stopping on these selectors. No selector was added to the allowed set, no assertion was weakened, and no further production edits were made. The already-running command was allowed to finish, and its final totals are recorded above. The strict quote remains ahead of the added `shares == 0` guard; by code inspection, that guard cannot intercept a revert from the quote.

Other strengthened controls also expose scope/fixture gaps. These failures require a revised remediation decision rather than marking this plan complete.

| Family | Rows | Observed failure | Count |
| --- | --- | --- | ---: |
| Dual | AerodromeStandardExchange; CommonBufferMultiVaultStablePool; CommonBufferMultiVaultWeightedPool; MixedBufferMultiVaultStablePool; MixedLegWeightedBufferPool; MultiPairStandardExchangeBufferPool; StandardExchangeBufferPool | Static dust preview reverts; execution is not attempted after that failed assertion | 7 |
| Curve quad | MorphoBlueStandardExchange; RebasingAwareERC4626; SimpleYieldERC4626Control; SimpleYieldERC4626Control_F6; SimpleYieldERC4626Control_F9; Permit2Recurrence | Preview succeeds with zero; execution selector is `0x00bf0cb2` (`MathDomain()`) | 6 |
| Balancer quad | RebasingAwareERC4626 | Preview succeeds with zero; execution selector is `0x4e487b71` (`Panic(uint256)`) | 1 |
| Orbital | RebasingAwareERC4626 | Preview returns **1** share, rather than zero | 1 |
| Balancer quad | SimpleYieldERC4626Control_F6 | Preview returns **240384615373** shares, rather than zero | 1 |
| Balancer quad | SimpleYieldERC4626Control_F9 | Preview returns **240384613** shares, rather than zero | 1 |

Full source paths, test names, and observed selectors are retained in [failures.txt](./evidence/failures.txt). This execution did not diagnose the underlying causes of the seven failed dual previews or reinterpret the positive-preview fixtures. No baseline runtime was run, so the report does not claim a before/after failure count for the starting workspace.

## Original completion criteria (superseded by the authorized follow-up)

Not achieved: the six-family zero-preview/allowed-execution-revert requirement is failing. The zero-share guard placed after the existing strict quote is insufficient for the observed quad execution failures. Resolving that behavior, the dual preview gaps, and the positive-preview fixture assumptions requires revising the plan’s decisions/scope.

Completed: both compilation stages, the prescribed full test selection, all exact-output share-debit checks, and all six invariant suites. Static checks confirm the strict execution math, non-quad production, and excluded non-CP behavior file remain unchanged. See [static-checks.txt](./evidence/static-checks.txt), [starting status](./evidence/git-status-before.txt), and [ending status](./evidence/git-status-after.txt).

Changes remain uncommitted. No deployment or broadcast was performed.

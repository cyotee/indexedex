# Implementation plan: Orbital raw-inventory liquidity remediation

**Date:** 2026-10-04  
**PRD:** [UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.md](UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_REMEDIATION_PRD.md)  
**Execute artifact:** give this path to a separately authorized implementation agent. This document task runs nothing.  
**Ready scope:** PRD R1–R4/R6 and partial-route characterization. OD-1 pricing and OD-2 recovery are deferred; do not invent their policies.

## 0. Read and preserve

Read `CLAUDE.md`, `.github/ASSISTANT_RULES.md`, their linked coding/testing law, current family PRD/addendum, and canonical skills directly:

- `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md`
- `.claude/skills/indexedex-testing/SKILL.md`
- `lib/crane/.claude/skills/crane-testing/SKILL.md`
- `lib/crane/.claude/skills/crane-deployment/SKILL.md`
- `lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md`

Use `docs/agent/SKILL_CATALOG.md` for current routing. Current router supersedes older example profiles. This remediation uses the existing hermetic profile; it does not waive existing family fork requirements for release.

**Never cancel an operation that includes Solidity compilation without explicit owner consent.** Arrange non-terminating execution/completion notification where supported. If a tool enforces a deadline, establish a supported long-running mechanism before starting; do not repeat the earlier 15-minute cutoff. Wait for real process exit. Do not delete artifact/cache directories. Seed a new worktree according to project law before its first compile.

## 1. Exact file scope

Define `O = contracts/hooks/uniswap/v4/standardExchange/orbital/` and `T = test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`.

### Production allowlist

- `O/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`: full-book and flexible proportional ownership helpers; raw conversion/used-amount plumbing. Preserve partial pricing and fee/bookkeeping behavior pending decisions.
- `O/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol`: zap terminal raw ratio, projected inventories, ownership-specific inverse mapping and zero-conversion handling. Preserve rated swap planning.
- `O/UniswapV4StandardExchangeOrbitalBufferHookMath.sol`: narrowly scoped full-precision raw ratio/ceil backing helpers. Do not globally change `fullBookUsedWad` without auditing its partial and non-ownership callers.
- `O/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol`: raw shares-minted conversion helpers only; preserve rated swap helpers and existing supported conversions.

Read-only execution trace targets: `DepositCore.sol`, `DepositZapTarget.sol`, `WithdrawTarget.sol`, `SeTarget.sol` with the same full prefix. If fixing the selected routes requires edits beyond the allowlist, document the exact call-site reason and obtain a scope amendment; do not change fee/storage/ABI semantics to avoid it.

### Test allowlist

Create:

1. `T/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityPolicy.t.sol`
2. `T/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityConversions.t.sol`
3. `T/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityRateFailure.t.sol`

Small test-only helpers may live under `T/rawLiquidity/`. Reuse existing production TestBases and their decimal variants. Existing tests under `T/` may be amended only for documented intended raw-accounting expectations, never to hide failures or disable supported cases. Consumer tests outside `T/` are run unchanged. No production mock substitutions.

### Document outputs

- `docs/plans/records/UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_BASELINE.md`
- `docs/plans/records/UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_PARTIAL_DECISION.md`
- `docs/plans/records/UNISWAP_V4_ORBITAL_RAW_LIQUIDITY_VALIDATION.md`

These paths are future implementation outputs, not claims they already exist. Preserve current unrelated modifications in all paths, particularly Orbital Common/ExitQuoteLib and concurrent Hookless analytic work. Do not reset, stash, delete, or overwrite another task's changes.

## 2. Baseline and dependency inventory

**Before editing production:** record repository/submodule revisions, dirty paths, compiler/Foundry versions and configuration, exact source and deployed-artifact identities. Separate inherited worktree modifications from this task's changes. Coordinate overlapping edits; don't benchmark a moving dependency set.

Trace complete entrypoints for proportional joins, flexible share joins, zap entry, proportional exit, single-output exit and partial fallback. Record:

- incumbent inventory capture and caller credit exclusion;
- pre-operation growth-fee mint/supply snapshot;
- buffering/unwrapping, projected SE state, rated swap phases;
- terminal LP issuance, refunds, radius validation and L2/reserve/kLast updates;
- every shared helper used by partial pricing or swaps.

Run/record existing required suites before changes using fresh artifacts. Measure representative full-book and zap workloads in both directions, with raw and buffered legs, mixed decimals, fee-bearing/non-1:1 SEs, and actual FullSpread consumer fixtures. Record cold/warm gas separately, quote/rate-read counts, full transaction gas versus subcall gas, success/revert and enforced call stipend.

**Done:** baseline file contains reproducible results, including actual failures. Never classify a failure unrelated just because its assertion file is untouched. A failed baseline is not a successful speedup denominator.

## 3. Independent raw reference and diagnostic tests

Write test-local expected math, not a second call to the production helper:

- `m = min floor(S*C_i/B_i)` for positive full-book legs;
- required inventory `ceil(m*B_i/S)`;
- proportional payout `floor(burn*B_i/S)`;
- full-width comparisons proving backing after real settlement.

Include integer over/undermint examples without assuming the tiny vectors are reachable deployed states. Add realistic production-first vectors for 0/1/2/3 buffered legs, rates 0.5/1/1.5/2 WAD where accepted, nonidentical share/face decimals, and non-1:1 conversion fees. Distinguish helper arithmetic tests from full proxy tests.

Add a partial-path decision record with exact current formulas and units. Diagnostic failures that reproduce a deferred defect must be clearly separated from passing acceptance suites; do not claim them fixed or weaken them to pass.

**Done:** expected raw ownership and actual delivery are independently observable; failing pre-fix vectors and deferred vectors are identified.

## 4. Implement raw full-book/flexible ownership

1. Snapshot raw incumbent token inventory or SE shares before adding this caller's credit. Preserve donation/funding law and protocol-fee sequencing.
2. Compute offered contribution in matching units: direct shares remain shares; face inputs use actual supported SE buffering preview. No provider-valued incumbent redemption.
3. Calculate floor mint through full-precision arithmetic; do not scale same-leg raw ratios through rated token WADs.
4. Compute ceil-required raw contributions, map required SE shares to sufficient bounded face input and verify forward output. Preserve user maxima and exact route refund ownership.
5. Validate actual settlement backs issuance. Revert unsupported/insufficient conversion results rather than silently treating zero output as face credit or promising an unsupported exact-output route.
6. Apply to all full-book flexible preview/execute twins. Keep first mint and partial-pricing call sites separate.

**Done:** PRD A1–A4 pass, including backing after execution. Do not treat SE deposit fees as permission to dilute incumbents.

## 5. Implement raw zap-terminal ownership

1. Keep rated `_depositSales`/`_depositOutputs`, sphere pricing and swap-state threading.
2. Build a distinct terminal ownership view of projected post-swap held shares/raw tokens and resulting contributions. Never replace projected state with live storage balances.
3. Apply the same raw floor mint and ceil backing policy; invert actual buffering as necessary. Ownership-specific zero conversions never substitute face amounts.
4. Preserve execution's use of the planned route; do not add redundant complete simulations solely for rate valuation. Retain necessary realized-balance checks.
5. Count all quote calls. Eight interpolation steps are not the entire `_faceForClaim` loop; 64 expansion steps are not the subsequent refinement loop. Preserve supported domains and substantiate gas rather than raising caps.

**Done:** fixed-post-swap terminal ownership is rate-independent; complete zap preview/execution agrees at matched state. Rate-sensitive swap outputs are expected and must not be asserted invariant.

## 6. Preserve payouts and characterize outage behavior

Exercise whole proportional/flexible exits with healthy, reverting, zero-return and malformed providers; fees on/off; nonzero residual buffered holdings; and applicable full-exit boundary cases.

Confirm raw entitlement remains unchanged. Where required rated fee, radius, L2 or reserve synchronization fails, confirm complete rollback of LP supply, tokens, SE balances and cached state—even if transfers occur earlier in the trace.

**Do not implement:** stale cache retention, scaled-last-reserve updates, rate=1 substitution, skipped protocol mint, omitted radius checks, or new recovery entrypoints. Record OD-2 as deferred. An SE that cannot redeem is another independent liveness dependency.

**Done:** PRD A6–A7 pass; report clearly that raw ownership does not guarantee rate-independent entrypoint execution.

## 7. Partial pricing decision note

For `_partialSharesUsed`, `_partialUsed`, `_partialMinShares`, `_partialNavShares`, `_singleSidedPlan` and `_partialDepositAtState`, record actual units, route predicates, zero-leg behavior, final NAV formula, radius inputs and whether it affects direct share, face, flexible or projected calls.

Show why merely inserting raw shares into rated `R` creates a new unit mismatch. Propose the smallest explicit raw-inventory policy alternatives with consequences for existing routes, fee-bearing SE deposits and price manipulation. No default rated-NAV exception is authorized.

**Done:** decision file identifies OD-1 and the executable scope already completed. Continue independent validation; ask the owner only for the partial policy before implementing that branch. Do not quietly change or delete partial support, and do not describe full raw-law compliance while this branch remains unresolved.

## 8. Build, regression, gas and sizes

The commands below are future implementation instructions using the repository workflow, not executions or pass claims from this document-authoring session. Refresh concrete deployment artifacts after production changes. This root imports the affected math/claim helpers; verify the workflow's dependency plan covers every edited source.

```bash
python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/FullSpreadConsumerBurnGates.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol

forge build --sizes
```

The Orbital directory includes Liquidity, B6, Buffer, Fees, ZapIn, Preview, Swap, SeExchange, Surface, PackageDecl, Adversarial, decimal/invariant suites and actual FullSpread matrix files. Record every selected suite and final tally. The Weighted matrix is an unchanged control, not permission to edit Weighted. Respect current deprecated-family exclusions and report them explicitly rather than silently broadening/reducing release scope.

Do not pipe away the build's failure status or describe a global size failure as unrelated without identifying the offending runtimes. Record all changed deployed libraries as well as facets/delegates/packages. Remeasure after the final edit, not before the last helper was added.

Measure before/after matched workloads with the same dependency versions, artifacts, state, caller, funding mode and cold/warm condition. Preserve existing 31M stipends/32M consumer constraints wherever present; no generic increase in harness gas counts as a solution. Require no new gas regression on successful comparable corrected proportional routes; report and obtain a decision for unavoidable regressions rather than waive them. Required consumers must actually succeed for full release acceptance.

A capped/failing baseline remains a failure requiring attribution. Do not repair a separate Hookless solver in this task; provide the failing trace and handoff. Other accepted parts may be reported separately, not as a green whole.

## 9. Final report and handoff

Write validation record with:

- requirement-to-code/test mapping for A1–A10;
- revisions, exact patch scope, artifacts/toolchain identities;
- complete commands, exits, suite tallies, raw references and backing checks;
- measured cold/warm gas, total nested quote counts and final runtime sizes;
- preserved ABI/storage/config and rated swap/fee/bootstrap behavior;
- baseline failures versus new attributable failures, with evidence;
- OD-1/OD-2 status, diagnostic limitations and exact remaining work.

Completion labels must distinguish bounded correction, partial pricing, recovery, and consumer/release acceptance. No fabricated historical baseline, no "all fixed" with deferred partial pricing, no passing claim based on LSP silence, comments, or interrupted output. Stop at the documented human decision checkpoint; authoring this plan is not deployment authorization.

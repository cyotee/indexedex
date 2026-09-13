# Uni V4 DETF release-gate remediation

Date: 2026-09-13.

Status: all 20 previously outstanding failures are resolved. All three release
campaigns, the full build, runtime artifact builds, launch-script compilation,
and the full hermetic repository gate passed.
No deployment, Anvil restart, or staking migration is part of this work.

## Production defect

Orbital reserves backed by the real Uniswap V3 Standard Exchange exhausted gas
while claiming funded bonds in the ALL9 and P9/R6 compositions. The trace reached
`retireEscrowDust -> synchronizeRewards -> previewSynthetic -> previewBurnToToken`
and exhausted gas inside a nested SE quote. The claim test's existing 30-million
gas allowance was retained.

`_pendingExpansionDetf` and `_realizeExpansionIfNeeded` valued every reserve leg
even when no full expansion epoch had elapsed or the current epoch had already
been consumed. Repeated bond/staking synchronization unnecessarily repeated those
expensive liquidation previews.

Both paths now check the existing first-bond epoch anchor, live state, and fixed
eight-hour period before requesting any synthetic price. The shared predicate
short-circuits before timestamp subtraction when time is at/before the anchor.
The highest-price selection, strict mint threshold, expansion amount, fee split,
and complete-epoch advancement are unchanged. Eligible epochs still use all
capital legs; below-threshold completed epochs are still consumed. Immediate
issuance seigniorage remains independent of the expansion clock. Synchronization
still refreshes expected custody balances even when no expansion is due, retaining
the existing defense against reusing observed inventory as a new prepayment.

The new production-proxy regression records real account calls to distinguish
legitimate custody balance synchronization from synthetic reserve valuation. It
requires no `previewSynthetic` call immediately after launch, one second before
a boundary, immediately after consuming a boundary, and one second before the
next boundary. It verifies positive expansion exactly at both boundaries.

## Fixture defects

Sixteen reserve-liquidity tests expected positive expansion from a yield injection
while configuring a `100e18` mint threshold. Their premise was incompatible with
the approved threshold-gated expansion rule.

The two expansion-specific behaviors now deploy with a reachable `2e18` mint
threshold. This also keeps their post-yield reserves within Orbital's specified
fixed-radius domain. Ordinary fallback tests retain the wide `100e18` deadband;
no production threshold defaults or Orbital pricing/radius rules were changed.

Their helper finds a real caller-funded yield payment just above the **payment
leg's** configured threshold, using snapshots only to search for the payment.
The final funded state uses the actual yield token transfer. The legacy first-leg
`syntheticPrice()` getter is insufficient for this purpose because the first
sorted capital leg may differ from the route being traded. The helper queries
the actual hook with the payment leg's creation rate, current supply and real
protocol-owned LP.

The tests retain exact preview/execution agreement, minimum-output rollback,
no issuance/burning by the fallback itself, unchanged protocol LP, full catch-up,
no replay, and early/late staking participation checks. They compare the DETF
quote to the actual reserve-swap quote, so a mistakenly open primary issuance
route cannot silently satisfy the fallback test.

## CI correction

The hermetic CI step now unsets `FOUNDRY_ETH_RPC_URL` and `ETH_RPC_URL` for Forge
execution. An empty fork override was interpreted as a filesystem RPC path by
the installed Forge, causing failure before any test ran. Other credential
suppression and fork-suite exclusions remain in place.

## Evidence

All logs and exact release commands/configuration are preserved under
`.scratch/detf-remaining-errors-20260913/`.

- `orbital-before.log`: original funded-claim out-of-gas trace.
- `focused-1.log`: all four original Orbital/Univ3 claim failures pass after the
  production epoch guard; the existing gas allowance was not increased.
- `orbital-fallback-trace.log`: excessive test yield exceeds the fixed radius;
  the math domain rejection is retained.
- `focused-2.log`: exact-boundary/no-unnecessary-valuation regression passes.
- `focused-3.log`: all 156 reserve-liquidity tests pass across eight suites,
  including all 16 originally failing cases.

Rebuilt DETF runtime sizes are 13,997 bytes (Bond), 3,449 (Claim), 13,633
(Exchange), 12,959 (Maintenance), and 19,503 (Query), all below EIP-170.
Measurements are preserved in `detf-facet-sizes.json`.

## Release campaigns

Solidity 0.8.35, optimizer enabled with one run, `via_ir=false`; default profile
and configured artifact/cache paths retained.

| Seed | Fuzz cases | Invariant runs × depth | Result |
|---|---:|---:|---|
| 1 | 10,000 | 1,000 × 100 | 12 tests passed, 0 failed |
| 17 | 10,000 | 1,000 × 100 | 12 tests passed, 0 failed |
| 257 | 10,000 | 1,000 × 100 | 12 tests passed, 0 failed |

Total: 30,000 highest-price fuzz cases and 300,000 composed-DETF invariant calls,
with `fail_on_revert=true` and zero unexpected reverts. The original deterministic
highest-price/threshold tests and the new epoch-valuation regression also passed
in every campaign. `release-config-*.json`, `release-*.log`, and
`release-results.json` record exact commands, resolved settings, results and timing.

An additional direct-claim regression is included in the final full gate: across
the existing Orbital/Univ3 decimal lifecycle fixtures, claim a matured bond with
unsettled epochs inside the original 30-million-gas allowance, without first
sending a synchronization transaction. It checks full principal, exact funded
sDETF payout, due expansion supply conservation and retirement of the bond NFT.
This test-only addition followed the release campaigns; production code is unchanged.

## Final full-repository gate

All stages exited successfully:

| Gate | Result | Log |
|---|---|---|
| `forge build` | Passed | `full-build.log` |
| All runtime artifact builds | Passed | `all-runtime-artifacts.log` |
| Stage 06-10 wrapper / Stage 07-02 custody script compilation | Passed | `launch-script-build.log` |
| Full hermetic suite | **31,534 passed, 0 failed, 0 skipped, across 2,722 suites** | `full-hermetic.log` |

All eight decimal bindings passed the new direct-claim regression. The full gate
includes the previously failing suites, the wrapper regressions, and the
surrounding protocol families. No failing test was excluded or weakened to obtain
a green result. The established fork exclusions are retained.

The test command matches the corrected CI step:

```sh
env -u FOUNDRY_ETH_RPC_URL -u ETH_RPC_URL forge test -vv \
  --no-match-path '**/fork/**' --no-match-contract 'Fork'
```

`full-gate-results.json` records each command, process exit code and duration.
`remediation-source-sha256.json` identifies the reviewed sources. Existing
unrelated workspace changes were preserved; no commit, push, public deployment,
Anvil restart or staking migration was performed.

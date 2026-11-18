# Explicit fee-recipient maintenance - November 17, 2026

The owner requested removing interleaved dust sweeps from ordinary DETF
workflows and retaining separate maintenance callable only by the current
fee oracle `feeTo()`. This supersedes the earlier gap-closure plan's
permissionless sweep and preservation of implicit sweeps.

## Implemented behavior

- Shared mint, burn, bond, donated-capital join and reserve-donation
  notification paths no longer call the residual sweep.
- Ordinary operations still synchronize held balances. Migration operations
  still settle their protected budgets and retain refunds.
- Both ordinary and Migration `sweepDust()` require the live fee recipient.
  Migration ownership alone does not authorize sweeping.
- The unused `sweepDustAtomic()` self-call, helper and installed selector
  were removed. Residual join and pair-conversion callbacks remain self-only.
- Migration capital and recovered-asset donations perform one native join
  against an isolated payment budget. Prior residuals, unrelated balances and
  recovery inventory are not inputs to that join. Refunds remain for maintenance.
- The retained local QA claim lifecycle no longer sweeps. Its separate
  `sweepOldDonations(address)` entry exercises authorized maintenance.

## Initial separation verification

Production artifacts were rebuilt with `scripts/forge-artifacts.py` and Solar
before the affected tests. No test was skipped or gas allowance increased.

| Check | Result |
| --- | --- |
| Pre-change authorization and purchase regressions | Both failed for the intended reasons: a stranger could sweep, and a purchase minted extra sweep LP |
| Migration hermetic cases on the integrated source | 267 passed, including old residual isolation, current-recipient authorization, principal/reward claims without sweeping, and donation/reentry controls |
| Ordinary sweep regressions | Passed for mint, burn, bond, donation, notification, unauthorized callers, recipient rotation, and removed callback routing |
| Ordinary DETF invariant | 256 runs, 16,384 calls, zero reverts; deterministic lifecycle also passed |
| Pinned recovery-donation forks | Nine passed, including real recovered DTF, protected custody/backing, callback rejection, rollback/retry and explicit donation-remainder maintenance |
| Solidity diagnostics | No errors on the edited production paths, QA script and checked regression files |

The broad V4 DETF run executed 9,838 tests: 8,584 passed and 1,254 failed.
Three newly failing donation checks still expected the effect of both former
automatic sweeps (join and NFT notification) after only one explicit sweep.
Their original final accounting assertions were preserved and both maintenance
actions made explicit; the focused rerun passed all four selected cases.

The remaining 1,251 failing cases match both test identities and failure
classes in the archived pre-change
`consumer-regression-after-product-law-hermetic.log`. Renamed sweep-policy
tests were mapped to their previous names for that comparison. These failures
include existing V3 mixed-decimal route, first-bond, quote-domain and residual
cases. The broad suite is not green.

## Commands

Run from the current repository root with the installed Solar-capable toolchain:

```sh
export PATH="$HOME/.foundry/bin:$PATH"
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationPolicy.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4 -- -vv

FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vv
```

Session command output was saved under `/tmp/indexedex-explicit-sweep-*`.
These are local execution logs, not portable deployment receipts.

## Caller-driven iteration follow-up

The owner subsequently requested moving repetition out of the maintenance
function as well. Each call now performs at most one successful reserve join.
It tries the native basket, supported listed baskets if needed, then individual
asset routes until one succeeds. Refunds remain held and booked for the next
fee-recipient transaction. The repeated outer rounds, immediate refund
recombination and single-token amount-halving loops were removed. Traversal of
configured assets and alternative pair/share choices still selects a route.

Two regressions failed before this change: the partial-bootstrap sweep exceeded
a 31,900,000-gas call allowance, and it minted more LP than the first basket's
independent quote. Both now pass. The gas test measures 2,818,365 gas for the
call. The second test proves exact quote-to-LP equality on each of two separate
authorized calls, with the first call's refunds funding the second.

All 269 migration hermetic cases and all nine pinned recovery-donation cases
passed on this implementation. Existing protected-custody, donation-release,
allowance, reentry, fee-recipient rotation and lifecycle assertions remain.
The refund regression now observes pair and SE-share refunds across successive
external calls rather than repeated joins inside one call.

The ordinary DETF matrix passed 8,321 tests, including the real CP refund/reuse
regression and the invariant's 256 runs / 16,384 calls with zero reverts.
Its 1,249 failures match prior failing test identities and failure classes;
there are no new failing cases. Test-side callers now iterate explicitly,
with a 256-call failure bound and the existing exhaustive final residual oracle
unchanged. Per-call gas caps, custody, supply, authorization and allowance
assertions were preserved. Static diagnostics found no new errors; the checked
ordinary files retain an existing mutability warning at
`UniswapV4Detf_Orbital_PonsV1Se_ProductLaw.t.sol:66`.

This gas result applies to the tested fixture. It is not a universal transaction
gas guarantee. No public deployment, upgrade, commit or new mined native
lifecycle was performed. Verification does not complete every historical
migration-plan gate. Follow-up logs are under
`/tmp/indexedex-single-pass-sweep-*`.

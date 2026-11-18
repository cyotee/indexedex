# Maintenance separation - 2026-11-17

Current whole-plan results are in
[implementation-audit-20261118/verification.md](implementation-audit-20261118/verification.md).
The native deployment, lifecycle, metadata and separate maintenance checks now
have successful mined evidence. The broader ordinary V3 suite remains red as
recorded there.

The owner has separated dust reinvestment from ordinary DETF workflows.
Mint, redeem, bond, donate and reserve-donation notifications retain and account
for their remainders; they do not launch a residual sweep.

The existing parent `sweepDust()` is a separate maintenance operation restricted
to the fee oracle's current `feeTo()` caller. Migration ownership alone does not
grant this permission. Migration maintenance still releases booked donation
remainders only through that explicit entry, preserving recovery custody.
The obsolete self-only `sweepDustAtomic()` callback is no longer installed.

Each `sweepDust()` call now performs at most one successful reserve join.
The fee-recipient caller may submit another transaction to invest the refunds.
The contract no longer repeats deposit rounds, recombines refunds after a join,
or halves a single-token input to retry it. Asset enumeration and supported
pair/share route selection remain; a zero quote leaves the capital booked.

`MigrationCoreLocalQA.exerciseAfterCliff(address)` completes the claim lifecycle
without sweeping. Its separate `sweepOldDonations(address)` entry exercises
one maintenance transaction with the authorized caller. The formerly failing
partial-bootstrap test now passes a 31,900,000-gas call allowance and measures
2,818,365 gas for one sweep call. This is a production-fixture result, not a
universal gas bound or a mined native deployment receipt.

The November 16 plan and results below describe the earlier behavior. The current
owner instruction supersedes their implicit-sweep and permissionless-sweep rules.
Source and test results are recorded in [the maintenance verification note](explicit-sweep-20261117.md).

## Current native execution details

The typed execution stage provides both `setPricing` for legacy inputs and
`setPricingV3` for the current complete book, including versioned V3 pool
operands. Both use `SENDER` and the proxy's real owner checks.

Use a fresh owned node and a separate `FOUNDRY_BROADCAST` directory for a new
rehearsal. The verified run used `--isolate --gas-estimate-multiplier 130`;
the old multiplier of 100 underfunded a constructor call. Native fixture
publication has an explicit 31,900,000 envelope, while the node stays at
32,000,000. `FOUNDRY_BLOCK_GAS_LIMIT=1000000000` is aggregate simulation
capacity only. `--start-fresh` archives stale native broadcast/recovery records;
review the relevant chain state before starting or resuming actual operations.

`deployAndIssue()` establishes the instance. Derive maturity from the two
actual stored positions before calling `exerciseAfterCliff(address)`.
The latter restores its simulation-only negative probes before broadcast, so
they cannot consume the sender's simulated transaction nonces.

Invoke `sweepOldDonations(address)` separately from the current `feeTo()`
account. In the owned local rehearsal the oracle owner explicitly assigned its
controlled dev account before maintenance. Two separate native sweep receipts
used 2,002,343 and 1,508,610 gas and both increased reserve LP. This does not
approve changing a public fee recipient or establish a universal gas bound.

The mixed-book scenario is a simulation-only Foundry test:

```sh
forge test --use solar --match-contract MigrationMixedRecordsTest -vv
```

It uses the real registry/proxy TestBase and retains the complete A/B issuance,
NFT contribution, stale-book and terminal-activation assertions. Its former
`runMixedRecordRehearsal()` script entry attempted to use the ephemeral script
address as a fixture actor and is removed. This test is not a broadcast receipt.

# Commands and recorded results - 2026-11-16

Run from the current repository root. Do not `cd` into a historical worktree.

```sh
export PATH="$HOME/.foundry/bin:$PATH"
forge build --use solar
forge test --use solar --no-match-path '**/fork/**' --no-match-contract Fork
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationMaintenanceFacet.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120
```

The 2026-11-16 run of those commands is recorded in [gap-closure-20261116/20261116T190111Z/verification.md](gap-closure-20261116/20261116T190111Z/verification.md). The non-fork suite passed 28,667 tests. The fork suite passed 184 tests. The native `sweepDust` call reverted and is not a success.

`Phase_08_Stage_01_MigrationExecution` functions, by name: `prepareDeployment`, `deploy`, `fund`, `bootstrap`, `setPricing`, `setPricingV3`, `configureIndependent`, `configureNfts`, `configureNftContributions`, `independentIssue`, `configureHeldSeLp`, `surrenderHeldSeLp`, `configureEarlierLiquid`, `surrenderEarlierLiquid`, `configureWeightedLiquid`, `surrenderWeightedLiquid`, `activate`, `configureWeightedSy`, `configureClaimedSy`, `surrenderWeightedSy`, `configureDtfCustodySe`, `surrenderDtfCustodySe`, `configureClaimVault`, `surrenderClaimVault`, `configureWeightedReceipt`, `surrenderWeightedReceipt`, `configureEarlierReceipt`, `surrenderEarlierReceipt`, `ownerFirstBond`, `harvest`.

NFT surrender and the retained parent `sweepDust()` are production operations. That typed script does not wrap them. The local QA helper's mined `sweepDust` reverted `RateProviderFailed` under a 32,000,000 gas cap. Do not raise that cap to manufacture a receipt.

## Historical body

# Migration contracts and Foundry scripts

Owner scope correction: November 15, 2026. The custom TypeScript migration
application, its shell launchers and its dedicated rehearsal fixtures are removed.
The migration contracts and native Foundry tests remain. Older operator reports,
source captures and transaction evidence are historical records.

Run commands from the conformance worktree:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1
export PATH="$HOME/.foundry/bin:$PATH"
forge build --use solar
forge test --use solar --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol'
```

Use the repository's Solar-capable Foundry nightly. Fork coverage is separate
and uses the existing `robinhood_mainnet_alchemy` RPC alias and `ALCHEMY_KEY`:

```sh
FOUNDRY_PROFILE=fork forge test --use solar --match-path 'test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/**/*.t.sol'
```

## Native transaction stages

`scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol`
contains typed functions callable directly with `forge script --sig`.
They use the exported `SENDER` address and the interface-owned argument types.
There is no preparation application, execution manifest or custom journal.

| Operation | Solidity function |
| --- | --- |
| Prepare child deployment, then deploy the migration | `prepareDeployment`, `deploy` |
| Supply reserve capital | `fund`, `bootstrap` |
| Load the manual pricing book | `setPricing` |
| Load reviewed entitlement inputs | The source-specific `configure*` functions |
| Issue selected independent compensation | `independentIssue` |
| Make the owner's required paid ordinary purchase | `ownerFirstBond` |
| Open migration and permanently remove administrative loaders | `activate` |
| Submit supported fungible surrenders | The source-specific `surrender*` functions |
| Execute selected recovery steps | `harvest` |

Supply actual reviewed addresses, quantities, pricing inputs and entitlement
records. The script does not derive historical compensation eligibility.
Funding, configuration and issuance remain separate operations.
Inspect existing chain state and receipts before repeating a call.

For example, with `SENDER`, `RPC_URL` and `MIGRATION_PROXY` already set, simulate
the activation stage after its contract prerequisites have been satisfied:

```sh
forge script --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol:Phase_08_Stage_01_MigrationExecution --sig 'activate(address)' "$MIGRATION_PROXY" --sender "$SENDER" --rpc-url "$RPC_URL"
```

The example omits `--broadcast`. Actual deployment, funding, compensation and
activation require separately reviewed inputs and authorization.

## Native local QA

`MigrationCoreLocalQA.s.sol`, `MigrationDeploymentGasResumedQA.s.sol` and
`MigrationSnapshotLocalQA.s.sol` remain local Foundry QA scripts. The operation-gas
contract tests reuse the first two. The snapshot script retains its local
chain/account and Anvil checks and no longer invokes an external shell guard.

Contract test results establish the behavior exercised by those tests.
They do not approve a production entitlement dataset or public execution.

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

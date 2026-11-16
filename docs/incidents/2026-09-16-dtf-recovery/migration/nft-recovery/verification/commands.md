# Independent verification commands

All commands run in
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`,
on `work/dtf-migration-phase-07-recovery`, baseline
`6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
The recovery implementation is the existing uncommitted producer delta.

## Admitted recovery replay

Executed with `/bin/zsh -lic` for existing archive access, no resolved RPC URL
or credentials recorded. The artifact helper builds first with Solar.

```sh
export PATH=/Users/cyotee/.foundry/bin:$PATH
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationDFPkg.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeighted.t.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryEarlier.t.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol \
  --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryGas.t.sol \
  -- -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv
```

The monitored wrapper uses `set -o pipefail`, tees complete output to
`fork-independent.log`, and prints `VERIFY_RECOVERY_FORK_EXIT=<status>`.
The final report distinguishes actual new execution from retained regression
and historical source evidence. No production, existing test, or producer
evidence edits are authorized.

## Additional independent executions

`evidence.json.runs` records the literal successful two-source sequence and
five-case spec commands. `accrual-evidence.json.terminalWitness.command`
records the literal terminal-NFT accrual reproduction command and exit.
Both scripts use artifact-first preparation followed by fork-profile
`forge script --use solar`, without broadcast. All four final runners exit 0.
The terminal runner proves a defect: its successful assertions are **not**
a passing task-8 harvestability result. Final `AdversarialVerify` is
**needs-fix**, as detailed in `report.md` finding R1.

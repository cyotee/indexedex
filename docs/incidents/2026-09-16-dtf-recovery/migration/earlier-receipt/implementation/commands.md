# Earlier receipt implementation command ledger

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-18-earlier-receipt`.
Base: `acdbe319f3a20c3af6bea594c62461b6c7988717`.
Source contract and independent admission are immutable inputs.

Initial raw SHA-256 checks matched:

* `source/contract.md`: 22508 bytes,
  `173bc343faf90a1d01ada52f16f86b0d707f6d87687bc438d9e209654bcbdc91`.
* `source-verification/report.md`: 20560 bytes,
  `86d0c1a22ffd398b528f9008c658a8fc51c39f273cdd50275faabd64668fbf35`.

Initial plain Git status exited 128 because the prescribed Crane dependency
is a symbolic link. Read-only status with `--ignore-submodules=all` succeeded:
only the retained earlier-receipt evidence was untracked; HEAD and branch
matched the required base and `work/dtf-migration-phase-18-earlier-receipt`.

Build, test and runtime attempts are retained separately, including failures.
No commit or merge is authorized.

## Bootstrap and failed attempts

All commands used the bounded phase18 worktree. Monitor completion receipts
record the exit codes. The first two artifact-build attempts used the
Homebrew Forge selected by PATH, including the first login-shell retry.
Both exited1 with `Error: solc "solar" does not exist`; `build-01.log` and
`build-02.log` retain their actual output. A third launch failed before tee
with `zsh:export:1: not valid in this context: Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Applications/Visual`.
It created no build log. The corrected invocation used a shell-quoted login
command with `export PATH="/Users/cyotee/.foundry/bin:$PATH"` and succeeded
in `build-04.log`. No compiler, dependency, permission or configuration was
changed. The installed Forge is1.9.1-nightly, commit
`430523103f3e2f9ba432ffdd2031a9f966153d0d`; Solar reports0.8.38.

`specs-01.log` preserves two now-stale declaration-list assertions; all new
ER configuration tests already passed. The lists were extended, not weakened.
`forks-01.log` preserves two Solidity address checksum errors. `forks-02.log`
preserves the real NFT3 immature-sale rejection in the new mixing test.
`forks-03.log` preserves the real frozen evaluator E3 rejection when an
alternate large NFT4 original was tried. The final mixing fixture retains
the genuine NFT3 original and advances time to its actual source unlock.
It neither manufactures a maturity nor changes source balances or bytecode.
The genuine zero-credit fixture uses acquired original ER internal shares
and disclosed small synthetic original components, not an invented denominator.

`audit-01.log` preserves the first stopped-candidate audit failure. A final
test compilation after the first successful CLI had regenerated the raw
allocation ABI artifact, invalidating that CLI's raw input hash binding.
`runtime-01/` remains unchanged as a non-final attempt. The final CLI runs
after the last artifact-producing compilation into fresh `runtime-02/`.
No stale input hash was accepted, edited, relabeled or bypassed.

`audit-02.log` retains an auditor decoder error: the existing journal nonce
contract is a decimal string, not a number. Only the evidence decoder was
corrected; no journal, receipt or operator code was changed.
`audit-03.log` then caught the empty owned
`.omo-runtime/dtf-migration-earlier-receipt` parent left after the CLI removed
its checkpoint root. Inspection found no files or child directories.
`rmdir` of that exact empty parent exited0. No foreign runtime was removed.
`audit-04.log` passed that stopped candidate. Before final sealing, the
runtime identity check was strengthened to capture the actual three linked
libraries rather than merely mask their addresses. The current final candidate
is the fresh `runtime-03/` CLI and successful `audit-05.log`. Earlier attempts
remain intact and are not substituted for this final execution.

LSP updates emitted3-second fresh-diagnostic timeouts during some edits.
Explicit fresh checks of the changed Recovery target and ER operator runner
returned zero errors; the complete Solar and strict-type checks below are
the executable gates. The evidence auditor was changed to existing Node
builtins rather than adding Bun type dependencies or suppressing diagnostics.

## Final validation commands

`python3 scripts/forge-artifacts.py build` received every one of the eleven
actually edited production roots, including both interfaces, both repositories,
the primary allocation target, the removable claim/receipt allocation target
and facet, the recovery target and facet, and both legacy helper/interface
files. `prodRoots` in the invocation receipts is the exact ordered list.
The exact root list is:

```sh
roots=(
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigration.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationRecovery.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryRepo.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/IMigrationLegacyRecovery.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyRecoveryLib.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryFacet.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationTarget.sol
contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationClaimVaultAllocationFacet.sol
)
python3 scripts/forge-artifacts.py build "${roots[@]}"
python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration
FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test "${roots[@]}" --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration
forge build --use solar scripts/foundry/recovery/dtf-migration/Phase_08_Stage_00_OperatorEnvironment.s.sol scripts/foundry/recovery/dtf-migration/Phase_08_Stage_01_MigrationExecution.s.sol
```

`specs-02.log`: exit0,142/142.
`forks-05.log`: exit0,101/101. `stages-01.log`: exit0 for both stages.
Foundry's existing format-config and repository warning output is retained.

```text
bun node_modules/typescript/bin/tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict --noUncheckedIndexedAccess --exactOptionalPropertyTypes --verbatimModuleSyntax --skipLibCheck --types node scripts/recovery/dtf-migration/*.ts
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts ./scripts/recovery/dtf-migration/execution.test.ts ./scripts/recovery/dtf-migration/weighted-liquid.test.ts ./scripts/recovery/dtf-migration/weighted-sy.test.ts ./scripts/recovery/dtf-migration/dtf-custody-se.test.ts ./scripts/recovery/dtf-migration/claim-vault.test.ts ./scripts/recovery/dtf-migration/weighted-receipt.test.ts ./scripts/recovery/dtf-migration/earlier-receipt.test.ts
```

After the runtime-link capture change, `types-sealed.log` checks all operator
files and the owned evidence auditor together: exit0.
`operator-tests-sealed.log` is the one final combined invocation:
exit0,72 tests across8 files. Earlier successful invocations remain retained.

```text
bun scripts/recovery/dtf-migration/cli.ts rehearse --rpc-alias robinhood_mainnet_alchemy --fork-block 108944663 --port 18568 --checkpoint .omo-runtime/dtf-migration-earlier-receipt/checkpoints --evidence docs/incidents/2026-09-16-dtf-recovery/migration/earlier-receipt/implementation/runtime-03
```

Preceding CLIs used the same arguments with `runtime-01` and `runtime-02`.
All three exited0. They use the genuine local registry/package and real EIP170 enforcement. No raw helper
replaces the CLI or Migration path. All transaction signing remains on the
owned fixed loopback rehearsal, and upstream access is read-only through the
unchanged pinned provider path. An environment alias is recorded, never a
resolved private endpoint.

The final independent auditor checks current compiled source metadata,
runtime bytes, original input hashes, raw signed receipts, three interruption
journals, exact ER economics, immutable producer/verifier seals and cleanup.
`audit.ts --seal` additionally binds `report.md` and all owned evidence.
The final seal and its streaming log exclude themselves from self-reference.

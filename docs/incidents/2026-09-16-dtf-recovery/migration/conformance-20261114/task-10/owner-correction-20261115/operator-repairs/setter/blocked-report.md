# Setter repair: required producer change outside allowed files

Status: blocked, no product change, no repair success claim.

The allowed four product files were not edited. The sibling's execution files,
the witness pin, plan boxes, and parent's readiness marker were not changed.

## Diagnosis

The exact saved canonical-chain file named by `operator-setter-blocker.json`
contains transaction
`0xa3bde746c8e8aed493469528c9b3dfc423ecaba903f4ed04a56d3b72b4e4fc63`,
status `0x1`, one event from proxy
`0xdb43a01045d82d54b9c641fae4827292ee0554cf`, and trace return
`0xe7f20b629b1814a326fbcf0d71509cf6fa97fd347db8a00eeae32ded0fbfd531`.
That equals the expected book computed by production `nextBookId` from the
saved execution manifest.

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol:45-56`
constructs the book, validates it, hashes it, stores it, emits
`Pricing.MigrationWeightedPricingSet(book_.id)`, and returns its ID.
The declaration is in
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol:54`.

The separate generated artifact
`out/IUniswapV4DetfMigrationWeightedPricing.sol/IUniswapV4DetfMigrationWeightedPricing.json`
contains that event and decodes the saved log to the expected ID.
The generated migration artifact omits it; the allocation artifact has no events.
The recovery and package artifacts also lack it.

The producer blocker is
`scripts/recovery/dtf-migration/rehearsal-data.ts:69-75`:
`bootstrapManifest` adds five generated ABI sources but no separate pricing
interface artifact. The actual saved pricing execution has exactly those five
ABI bindings and no pricing event ABI binding among its 35 total sources.
Its `preparedManifest` is null; preparation cannot provide another binding.
`rehearsal-data.ts:146` also selects the migration interface as the preparation
pricing getter artifact; that path does not supply this separately declared event.

`execution-domain.ts:artifact` only reads manifest-bound ABI sources.
`execution-state.ts:captureAtReceipt` tries migration, allocation, and recovery.
Loading an adjacent unbound artifact, synthesizing an event fragment, replacing
the saved journal domain, or appending a new source to the historical manifest
would not preserve the original immutable execution-domain authentication.

Required parent action: admit a producer change to
`scripts/recovery/dtf-migration/rehearsal-data.ts` so future executions carry
the generated pricing event artifact through the existing source binding and
bundle machinery. Existing saved domains must remain immutable; the parent must
decide how to renew the blocked rehearsal evidence. No historical binding was
fabricated here, and no new lifecycle or decoding policy was introduced.

## Observed runs

All runs used cwd
`/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.
Each started once through a command monitor; no duplicate command was run.
Raw stdout, stderr, and numerical exit files are alongside this report.

1. Exact argv:
   `bun /Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1/docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-10/owner-correction-20261115/operator-repairs/setter/manual-receipt.ts`
   Observed exit: **1**. Files: `manual-before.stdout`,
   `manual-before.stderr`, `manual-before.exit`.
   Production `loadExecution` loads the exact saved source bindings;
   journal equality and the original intent domain hash are checked.
   Production `Rpc.canonicalReceipt` authenticates saved header/log ordering.
   Production `captureCompletion` validates the actual saved signed intent and
   transaction, then rejects with
   `manual setter event differs from exact Inputs`.
   The RPC subclass supplies only saved evidence; every network operation is
   forbidden. The standalone generated-interface decode is explicitly diagnostic,
   not an injected production ABI or authority context.

2. Exact argv:
   `bun test --timeout 15000 ./scripts/recovery/dtf-migration/execution-domain.test.ts ./scripts/recovery/dtf-migration/execution-state.test.ts`
   Observed exit: **0**. **15 pass, 0 fail**, Bun 1.4.2.
   Files: `focused-baseline.stdout`, `focused-baseline.stderr`,
   `focused-baseline.exit`. These are unchanged baseline tests, not after-fix
   evidence. Same-block history/configuration/issuance tests passed.

3. Exact argv: `git status --short`, environment `GIT_MASTER=1`.
   Observed exit: **0**. Files: `dirty-worktree.stdout`,
   `dirty-worktree.stderr`, `dirty-worktree.exit`.
   There were 190 status rows, including existing modified domain/state files,
   untracked domain/state tests, and the sibling's execution files.
   No dirty source was overwritten or reverted.

## Evidence fingerprints

SHA-256 of the original canonical-chain file:
`c6b1e9c210ccce97c27d1fb051f2b70198af57302b367cc6952416aee8645666`.
All original evidence bytes were read only.

| Path | SHA-256 |
| --- | --- |
| `scripts/recovery/dtf-migration/execution-domain.ts` | `2e25b584b4406c89094a85ea74d3ecc0b9b666c7d1241373d080d3197b541bca` |
| `scripts/recovery/dtf-migration/execution-state.ts` | `d84784b41a70331fb11248a4bc9dcdc067cdcb8ab1d7e3adb9c2a9aa55020cd1` |
| `scripts/recovery/dtf-migration/execution-domain.test.ts` | `5f67a9d9deb6b38daa227f43437af38e8ae4ffcda42ca192d440ea998a816b20` |
| `scripts/recovery/dtf-migration/execution-state.test.ts` | `33ac83c00d4d9e071f0457b5ed1324397480228a3546b2723c6d21b25ee1998c` |
| `scripts/recovery/dtf-migration/rehearsal-data.ts` | `e0367f3e3e2bb60d30dc94e26103e8b9afac95dcdf94e66a29a2ffbeabd3366a` |
| `scripts/recovery/dtf-migration/provenance.ts` | `6d33b68b347a100dcd643afef879e1fe610279c5e3808fd07a20dc20c70058f2` |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol` | `d71c777d4a685b17c6e5231970c7b458cedd1501cbfff65dd404f04c887cdb54` |
| `out/IUniswapV4DetfMigrationWeightedPricing.sol/IUniswapV4DetfMigrationWeightedPricing.json` | `bc27f132877882a81b5d89f7ecb2637eb4b04fa685ad42430930e595cd181bbd` |

## Probe accounting and limits

- Before-fix regression: reproduced against saved real local-chain evidence,
  original intent, exact source bindings, and production verification.
- After-fix positive and wrong-ID/emitter/topic/missing-event/malformed-data
  probes: **blocked**, not passed or inapplicable. There is no authorized
  producer binding, so corrupted copies would all reject even without the fix
  and would provide misleading coverage. No such success claim was made.
- Malformed/rehashed domain: unchanged focused test
  `historical intent domain is reconstructed independently of surrounding reference hashes`
  passed; no setter-specific replacement-domain acceptance was fabricated.
- Stale state: unchanged `stale journal and second active checkpoint reject
  before any signer is created` passed. A stale pricing artifact mutation
  probe is blocked until a pricing artifact is actually bound.
- Misleading success: the manual replay exits 1 despite receipt status 1 and
  standalone decode success. Green baseline tests do not close the repair.
- Dirty worktree: captured raw; all existing source edits preserved.
- Full operator/type checks: deliberately not run while the sibling owns its
  repair. No Forge, installs, commits, RPC requests, or transactions occurred.
- UI/accessibility/responsive/browser QA: inapplicable; no rendered surface or
  browser behavior changes. Network outage/permission/authentication probes:
  inapplicable to this offline replay, whose transport forbids network calls.
  Concurrency/load/performance probes: inapplicable to a blocked ABI-loading
  change with no product edits; receipt ordering has existing passing coverage.
  Deployment/rollback/restart probes: inapplicable; nothing was deployed,
  broadcast, or started, and no runtime state was mutated.
- Cleanup: replay provider destroyed in `finally`; all monitors exited.
  No Anvil was started and no new runtime directory requires removal.
  Evidence files intentionally retained for independent verification.

## Evidence code review

The evidence script owns one saved-receipt diagnosis (79 nonblank,
non-comment lines). External input is parsed at the existing schema boundaries.
The saved transport matches method strings exhaustively with an explicit error
for every unsupported request. No casts, `any`, non-null assertions, defensive
fallback, new production export, or test seam was added. The subclass is an
offline evidence adapter, not a production decoder. Its only method override
has two parameters. No production logging or source tests were added or changed.

The planned narrow repair remains unfinished. This report asks the parent for
the exact producer scope needed; it does not authorize that edit or mark task 10
ready.

# Bounded operator preparation delivery

Date: 2026-11-11.

**DoneClaim: preparation and read-only validation are implemented.**
The final neighboring suite passes **41 tests**, strict TypeScript checking
passes, and the actual CLI preparation/validation surface is exercised.
The exact typed execution-consumer interface is in `interface.md`.
This is not a claim that transaction execution, local-chain rehearsal,
resume, approved allocations, all-category task9 or release is complete.

## Scope and source acceptance

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-08-operator`.
Branch: `work/dtf-migration-phase-08-operator`.
Observed HEAD:
`421072a7630a0d3d47a6f36e1062d9eae98c93e2`.

The root notepad records independent phase07 commit acceptance, successful
warm seeding and `OPERATOR_WORKTREE_VERIFIED` before dispatch. Direct branch,
HEAD, clean tracked status, `out`/`cache_forge` and dependency-link inspection
matched. The phase07 commit receipt and independent verification identify
the same source base. No uncommitted predecessor production state was used.

Read the complete phase08 brief and fixed CLI contract, original plan task9
and its native-unit/snapshot contract, MIG-P03/P07/P11/P13/P14 and the
preparation provenance recipe. Consulted the router, assistant coding,
deployment/testing rules, canonical orchestration/Foundry skills and
TypeScript/testing/Bun guidance. Actual current allocation, snapshot and
recovery interfaces and implementation bodies determine the payloads.

Only the authorized script directory, operator runbook and operator
evidence paths were authored. No production, shared TestBase, configuration,
dependency, historical evidence, commit, push, merge or public write occurred.
Shared dependency links and warm artifacts were read, not changed.

`source-manifest.json` records exact raw SHA-256 bindings for all eight
authored TypeScript paths, consumed interfaces, warm snapshot ABI artifact,
execution brief, CLI contract and original plan. The artifact fingerprint is
an artifact-envelope identity, not a claim of newly compiled or deployed code.

## Implemented behavior

- `schema.ts`: strict readonly runtime schemas, exact decimal integer
  normalization, complete source provenance descriptors and finite recovery
  selection. Unknown fields, missing/unknown amounts and arbitrary output
  credit inputs reject.
- `provenance.ts`: raw SHA-256/size checks before use, RFC6901 full-original
  proof matching, native origin partition conservation and disjoint
  descendant identities. Source paths resolve relative to the input file.
- `payloads.ts`: separate independent and both admitted NFT configurations,
  canonical source-specific identities, whole replacements, duplicate/
  overlap/omission rejection, all required category dispositions and genuine
  bounded recovery tuple validation.
- `quotes.ts`: signer-free RPC reads of chain, canonical header and code
  bindings, actual full immutable snapshot, recomputed snapshot seal and
  independently evaluated ETH/DTF/combined original quotes. No constant-rate
  estimator, live remaining-principal reprice or arbitrary C0 credit exists.
- `preparation.ts`: deterministic normalization, recipient totals, selected
  issuance requests, source/domain/payload fingerprints, exclusive review
  dataset writes and full reconstructive manifest validation. Blocked inputs
  retain a disposition report but get no executable manifest.
- `cli.ts`: real `prepare`, `validate` and help entrypoints. Duplicate flags,
  execution flags and unsupported commands reject.
- `preparation.fixture.ts` and `preparation.test.ts`: neighboring deterministic
  tests with both distinct NFT models, amounts above the floating-point safe
  range and the actual CLI in fresh subprocesses.

Preparation returns only original setter arguments plus expected identities
and quote metadata. It creates no bond, predicts no emitted bond ID, changes
no supply and records no transaction success. Independent/NFT output files
contain full replacement records, not deltas. Configuration and execution
remain separate. The downstream lane must use `validateManifest` and actual
canonical receipt/state reconciliation.

## Commands, results and diagnostics

All commands ran from the operator worktree. Installed Bun is
**1.4.2**, build `50a8a8387`; no toolchain was installed or upgraded.

Final command:

```sh
bun --version &&
bun test --timeout 15000 ./scripts/recovery/dtf-migration/preparation.test.ts &&
bun scripts/recovery/dtf-migration/cli.ts --help &&
GIT_MASTER=1 git diff --check --ignore-submodules=all
```

Monitor `mon_QEXP05ZFBR2F42RE`, session `bash_4`: **exit 0**.
Result: **41 passed, 0 failed, one file, 511 ms**. This includes actual
`prepare --input ... --output ...` and `validate --manifest ...` child
processes, each with exit0, empty stderr and read-only result mode.
The earlier 27-test run also passed before expanded source/category/domain
tests and final hardening; it is not added to the final distinct count.

The final strict gate, monitor `mon_4R4R14Y66ETSD78T`, `bash_5`, **exit0**:

```sh
./node_modules/.bin/tsc --noEmit --strict --noUncheckedIndexedAccess \
  --exactOptionalPropertyTypes --verbatimModuleSyntax \
  --module NodeNext --moduleResolution NodeNext --target ES2022 --types node \
  scripts/recovery/dtf-migration/schema.ts \
  scripts/recovery/dtf-migration/provenance.ts \
  scripts/recovery/dtf-migration/payloads.ts \
  scripts/recovery/dtf-migration/quotes.ts \
  scripts/recovery/dtf-migration/preparation.ts \
  scripts/recovery/dtf-migration/cli.ts \
  scripts/recovery/dtf-migration/preparation.fixture.ts \
  scripts/recovery/dtf-migration/preparation.test.ts
```

The installed skill's `check-test-junk.ts` found no findings, **exit0**.
Its `check-no-excuse-rules.ts` could not resolve its required
`typescript/unstable/async` and `typescript/unstable/ast` APIs from the
repository's installed TypeScript; **exit2**, not a clean audit.
Combined audit monitor `mon_V8XKY7P30Y6X680E`, `bash_7`, therefore exits1.
No dependency/configuration change or suppressed diagnostic was used.

Initial LSP diagnostics exposed missing NodeNext import extensions and
unavailable Bun test type declarations. Imports were corrected; tests use
native `node:test`, HTTP, process and event APIs under Bun, without adding
types. The subsequent successful LSP wave had no errors, with one unused
import later removed. Final fresh LSP requests timed out at3000ms; no final
clean LSP claim is made. Strict compiler checking of all final source passes.
JSON LSP is unavailable because Biome is not installed; retained JSON was
parsed and its fixture payload hash checked successfully.

Authored source sizes are 63-203 nonblank/noncomment lines per file.
Each file owns one boundary: schemas, provenance, payload construction,
read-only quotes, manifest preparation, CLI dispatch, wire fixture or tests.
Untrusted JSON enters through schemas, application inputs are readonly,
stage selection is finite, errors are typed, and no assertion/suppression,
fallback pricing, timing sleep or dependency workaround was introduced.
No Forge build/test was needed: no Solidity or artifact-producing source
was edited. Actual mined-chain QA belongs to the dependent rehearsal.

## Observed deterministic evidence and limits

`deterministic-fixture.json` retains the exact full configuration objects,
configuration/original IDs, selected issuance request and expected native
quote outputs. Its recomputed payload hash matches
`890836bf556ac8cec25d32ea6f5e0f8b14943965cb4dd7bb4636c5504b2b68dc`.
The captured fixture command `mon_ZWS69PX7XR0E48N0`, `bash_6`, exited0.

This fixture is an explicitly synthetic JSON-RPC wire server, **not an EVM**.
Its arithmetic is deliberately simple and is not represented as the
production frozen evaluator. It tests the real client, full ABI decoding,
native integer handling, snapshot seal/domain checks, component isolation,
provenance and persisted-manifest handling. No new actual onchain snapshot,
deployment, receipt, nonce, bond ID, balance observation or transaction hash
is claimed. Production code obtains quote values from the actual deployed
snapshot; the next real rehearsal must prove that path on a genuine
manager-registry deployment.

File bindings establish integrity and explicit reviewed-record provenance;
they do not authenticate an arbitrary historical statement or approve a
beneficiary. Existing incident CSVs remain non-issuable and are not directly
uploaded. Operational-review inputs still need reviewed source truth,
funding provenance, actual deployment identity and an actual captured
snapshot. Synthetic inputs are loopback-only and barred from nonlocal use.

Every disposition report retains independent, weighted NFT, earlier NFT,
both liquid generations, both receipts, SY, TokenStaking, claim-vault,
underlying SE, fungible LP and earlier liquidation. The ten unsupported
categories reject with their actual E1/E2 or SB-E1/E2/E3/E4 gate. Neither
an absent record nor an empty recovery selection becomes category success.
Earlier holding does not prove liquidation. No unproved history route gains
an actionable configuration through this increment.

Deployment/funding/capture plans necessarily precede the actual snapshot
required here. Their genuine package/donation/genesis argument contracts
belong to the dependent execution lane; this lane does not fabricate a
pre-capture snapshot or generic calldata path. Weighted accrued recovery
selection must use synchronized attributed gons and bounded simulation,
not total balances or a zero stored inventory shortcut.

## Cleanup and handoff

Every monitor and child CLI process has completed with its recorded exit.
There is no pending runtime. No Anvil, fork node, production signer,
persistent impersonation or chain listener was started.

Wire fixtures subscribe to the actual listening event before use; each
test's awaited `afterEach` closes its owned server, removes its RPC
environment variable and removes its unique `dtf-prepare-test-*` root.
The standalone fixture capture awaits the same cleanup in `finally`.
Provider cleanup runs in `finally`; child CLI exit events are subscribed
with bounded timeouts. These awaited cleanup calls completed within the
successful runners. Individual ephemeral root names and ephemeral ports
were not retained; no cleanup of unrelated roots/services was attempted.
Warm caches, out artifacts and shared services remain untouched.

Initial plain Git status failed on the prescribed Crane symlink with
`expected submodule path 'lib/crane' not to be a symbolic link`; using
`--ignore-submodules=all` resolved inspection without changing the link.
One monitor filter was rejected before launch and corrected. Final raw
fingerprint/scoped-status/whitespace command `mon_KMSY5117DYAX1F8A`,
`bash_8`, exited0. Untracked script/evidence files are intentionally not
committed; no tracked production change exists.

**No source blocker prevents bounded preparation.** The execution,
real-rehearsal and independent-verification DAG nodes may consume this
interface. Their success is not implied here; all full-task and legacy
source gates remain open.

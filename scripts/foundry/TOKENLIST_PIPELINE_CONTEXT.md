# Token List Pipeline — Context for Future Sessions

This document captures the intent, architecture, current state, and open work for the
deployment-artifact-to-UI pipeline that runs through the
[Uniswap Token List standard](https://github.com/Uniswap/token-lists). Read this first
when starting a new session that touches Solidity deploy scripts, the Node aggregator,
or the frontend tokenlist code.

Companion files (read after this one for deeper detail):

- `docs/superpowers/plans/2026-06-05-tokenlist-pipeline.md` — original implementation
  plan with every task, code snippet, and TDD step. Phases that were skipped or
  deferred are documented inline.
- `docs/tokenlist-pipeline.md` — short user-facing operations doc (how to run, how
  to opt out, schema gotchas).
- `scripts/foundry/local_testing/README.md` — staged local-deploy flow; this is where
  the producer side is currently wired.

---

## Why this pipeline exists

Before this work, deployment artifacts lived as eight ad-hoc per-category JSON arrays
per `(environment, chain)`, hand-shaped by Solidity scripts and consumed by ~600
lines of category-specific glue in `frontend/app/lib/tokenlists.ts`. Adding a new
pool type meant editing the producer, the registry, the consumer cache, the per-
category builder, and every UI call site. There was no schema, no validation, no
label-override story, and no path for third-party tooling to ingest our lists.

The redesign solves three problems at once:

1. **Stable producer/consumer contract** — both sides agree on the Uniswap Token List
   schema. The producer emits typed fragments; the consumer reads validated lists.
2. **Single-file change to add a new pool type** — drop a new directory under the
   fragment tree, add a row to `tokenlists.config.ts`, optionally add a tag filter
   in the consumer. No registry rewrites, no cache surgery.
3. **Label overrides without redeploys** — set
   `extensions.display: "My Label"` on any fragment or list entry. The UI's
   `resolveLabel` picks it up before falling back to `name` / `symbol`.

---

## Architecture: three layers, one schema contract

```
+---------------------------------------------------------------+
| Layer 1 — Producer (Solidity)                                 |
|                                                               |
|   Foundry deploy scripts call:                                |
|     _writeManifestEntry(typeDir, key, ManifestEntry e)        |
|                                                               |
|   Writes one JSON fragment per artifact:                      |
|     deployments/<env>/<chain>/fragments/<typeDir>/<key>.json  |
|                                                               |
|   Fragment shape (NOT a Token List, just an entry):           |
|     { chainId, address, name, symbol, decimals, tags[] }      |
+---------------------------------------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| Layer 2 — Aggregator (Node / TypeScript)                      |
|                                                               |
|   scripts/node/src/main.ts walks the fragment tree,           |
|   derives default tags from directory paths, groups           |
|   fragments into output buckets per tokenlists.config.ts,     |
|   bumps semver against the previous list, validates with      |
|   Ajv against @uniswap/token-lists/src/tokenlist.schema.json, |
|   normalizes inputs to fit schema limits, and writes:         |
|                                                               |
|     frontend/app/addresses/<env>/<chain>/<bucket>.tokenlist.json |
|                                                               |
|   Invoked automatically by scripts/shell/local_testing.sh     |
|   after the last forge script.                                |
+---------------------------------------------------------------+
                              |
                              v
+---------------------------------------------------------------+
| Layer 3 — Consumer (Next.js UI / TypeScript)                  |
|                                                               |
|   frontend/app/lib/tokenlistRegistry.ts statically imports    |
|   every Token List for every (env, chain).                    |
|                                                               |
|   frontend/app/lib/tokenlistCompose.ts merges lists by        |
|   (chainId, address) and exposes:                             |
|     composeLists, byTag, byAddress, resolveLabel              |
|                                                               |
|   frontend/app/lib/tokenlists.ts derives the eight legacy     |
|   category arrays via tag filters over the composed store.    |
|   Public API surface unchanged — call sites untouched.        |
+---------------------------------------------------------------+
```

The Token List schema sits at the layer boundaries. Each layer can be evolved
independently as long as it keeps emitting / accepting schema-valid lists.

---

## Locked design decisions (revisit deliberately, not casually)

These six choices shape the whole design. Each can be revisited, but doing so
ripples through multiple files.

1. **Fragment granularity:** one JSON per artifact. Pro: clean PR diffs, surgical
   re-deploys. Con: many small files in the deployments tree (hundreds across
   all envs/chains). Worth it for the diff hygiene.
2. **List boundary:** one Token List per top-level directory category
   (`balancer-v3-pools.tokenlist.json`, `strategy-vaults.tokenlist.json`, etc.).
   The alternative — one list per protocol — would match external publishing
   conventions but doesn't match our directory taxonomy.
3. **`extensions` typing:** open `Record<string, unknown>` at the schema layer;
   the consumer narrows when reading specific keys. No producer-side typed
   extension interfaces yet — deferred until a concrete use case demands it.
4. **Semver bump:** auto-derived from a diff against the previous published list.
   Major if any address removed/replaced, minor if any added, patch if metadata-
   only. Implementation in `scripts/node/src/bumpVersion.ts`.
5. **Aggregator location:** `scripts/node/` at the repo root, separate from the
   frontend. Keeps the build pipeline simple — frontend doesn't need the
   `@uniswap/token-lists` dev dep, only the runtime types (inlined).
6. **Phase 2 shadow consume:** skipped in this implementation. The plan had a
   transitional step where the UI loaded both legacy and composed lists and
   logged diffs. We cut over directly because the migration script
   (`scripts/node/src/migrateLegacy.ts`) deterministically produces the same
   data the legacy path was producing.

---

## Sharp edges from the Uniswap Token List schema

These constraints bit us during implementation. The aggregator's `normalize.ts`
handles them so producers can stay simple, but anyone editing the pipeline
needs to know:

| Field | Limit | Workaround |
|---|---|---|
| Tag identifier | `^[\w]+$`, max 10 chars | Short tags only. Use `balV3` not `balancerV3Pool`. |
| Tag definition `name` | `^[ \w]+$`, max 20 | Plain text only, no hyphens. |
| Tag definition `description` | `^[ \w\.,:]+$`, min 1 | No hyphens, no slashes. **`ERC4626-compliant` fails; `ERC4626 compliant` passes.** |
| Token `symbol` | max 20, no whitespace | Normalizer truncates and stores full value in `extensions.fullSymbol`. |
| Token `name` | max 60 | Normalizer truncates and stores full value in `extensions.fullName`. |
| Extension primitive string | max 42 | Even `fullSymbol` / `fullName` get truncated to 42. |
| Extension values | string / number / boolean / null / object | Arrays are NOT allowed. Normalizer rewrites arrays as indexed objects (`["a","b"]` → `{"0":"a","1":"b"}`). |
| List `tokens` | minItems: 1 | Aggregator and migrator skip empty buckets entirely. |
| List `name` | `^[\w ]+$`, max 30 | Plain text only. |

The schema lives at `scripts/node/node_modules/@uniswap/token-lists/src/tokenlist.schema.json`
if you need to verify a specific constraint. The package ships only `src/` (no
`dist/`) — imports use the source paths directly:
```ts
import tokenListSchema from '@uniswap/token-lists/src/tokenlist.schema.json' with { type: 'json' }
import type { TokenList } from '@uniswap/token-lists/src/types'
```

---

## Tag taxonomy

Directory → default tags (defined in `scripts/node/src/deriveTags.ts`):

```
tokens               → [token]
pools/balancerV3     → [pool, balancer, balV3]
pools/uniV2          → [pool, uniV2]
pools/aerodrome      → [pool, aero]
vaults/erc4626       → [vault, erc4626]
vaults/strategy      → [vault, strat]
vaults/protocolDetf  → [vault, detf]
```

The UI's `getCached()` in `frontend/app/lib/tokenlists.ts` reads each category as a
tag filter:

```
baseTokens          → byTag(['token'])
erc4626Tokens       → byTag(['erc4626'])
balancerPoolTokens  → byTag(['balancer', 'balV3'])
uniV2PoolTokens     → byTag(['uniV2'])
aerodromePoolTokens → byTag(['aero'])
strategyVaultTokens → byTag(['strat'])
protocolDetfTokens  → byTag(['detf'])
```

If you add a new pool type:

1. Add a row to `TAXONOMY` in `scripts/node/src/deriveTags.ts`.
2. Add a bucket to `tokenlists.config.ts` with matching `tagDefinitions`.
3. Add a tag filter call in `frontend/app/lib/tokenlists.ts` `getCached()`.
4. Add the static imports to `frontend/app/lib/tokenlistRegistry.ts`.
5. Have your Solidity script call
   `_writeManifestEntry("new/dir", "<key>", entry)`.

---

## File map

### Producer (Solidity)

```
scripts/foundry/local_testing/shared/
  ManifestEntry.sol                  struct + library; vm-serialize to JSON
  LocalTestingDeploymentBase.sol     adds _fragmentRoot() + _writeManifestEntry()

scripts/foundry/local_testing/anvil_single/
  Script_03_DeployBaseProtocols.s.sol      emits tokens/weth9.json
  Script_06_DeployFoundationAssets.s.sol   emits tokens/{tta,ttb,ttc,rich}.json
  Script_10_DeployScenario1Overlay.s.sol   emits pools/uniV2/{uniV2AbPool,uniV2BWethPool}
                                           and vaults/strategy/{uniV2AbVault,uniV2BWethVault}
```

Producer pattern: every script's `_export*` step now has a sibling
`_exportFragments()` that calls `_writeManifestEntry` once per artifact.
Legacy `_exportJson` keeps writing the per-category file in parallel for now
(Phase 4 cleanup will remove it).

### Aggregator (Node)

```
scripts/node/
  package.json                       devDeps: tsx, vitest, typescript, @types/node
                                     deps: @uniswap/token-lists, ajv, ajv-formats,
                                           fast-glob
  tsconfig.json                      ES2022 / Bundler / strict
  vitest.config.ts
  src/
    types.ts                         ManifestFragment, ListBucketConfig,
                                     AggregatorConfig, BumpResult
    deriveTags.ts                    TAXONOMY directory→tags lookup
    readFragments.ts                 walk deployments/<env>/<chain>/<typeDir>/
    bumpVersion.ts                   diff prev vs current → {major,minor,patch}
    schema.ts                        Ajv-compiled validator
    normalize.ts                     fit fragment to schema (symbol/name truncation,
                                     array → indexed object, extension string cap)
    groupByList.ts                   filter fragments per bucket.includeTypeDirs
    buildList.ts                     fragments → validated TokenList
    writeList.ts                     load previous, write new
    main.ts                          CLI entrypoint, prints [OK]/[SKIP]/[FAIL] per bucket
    migrateLegacy.ts                 ONE-SHOT: convert legacy per-category JSONs
                                     to bucket-style Token Lists
  test/
    deriveTags.test.ts
    bumpVersion.test.ts
    schema.test.ts
    buildList.test.ts
    readFragments.test.ts
  fixtures/
    sample-deploys/sepolia/11155111/...   minimal fixtures for tests
    tokenlists.fixture.config.ts          smoke-test config

tokenlists.config.ts                 REPO-ROOT config: environments × chains × buckets
```

### Shell glue

```
scripts/shell/local_testing.sh       run_aggregator() invoked after stages.
                                     SKIP_TOKENLIST_BUILD=1 to opt out.
                                     INDEXEDEX_REPO_ROOT exported into the Node child.
```

### Consumer (UI)

```
frontend/app/lib/
  tokenlistCompose.ts                inline TokenList/TokenInfo types,
                                     composeLists / byTag / byAddress / resolveLabel
                                     (uses Map.forEach because tsconfig target=es5)
  tokenlistRegistry.ts               static imports of all migrated Token Lists per
                                     (env, chain). Edit when a new (env, chain) gets a
                                     bucket.
  tokenlists.ts                      getCached() now reads from composeLists().
                                     Public API unchanged — every call site downstream
                                     (swap/page.tsx, batch-swap/page.tsx, etc.) keeps
                                     working without edits.

frontend/app/addresses/<env>/[<chain>/]<bucket>.tokenlist.json
  Output of the aggregator (or the one-time migrator). Schema-valid Uniswap Token Lists.
  Sibling sepolia-*.tokenlist.json files are the LEGACY per-category JSONs, still
  imported by addresses/index.ts but no longer consumed by tokenlists.ts.
```

---

## How to operate

### Run a deploy and refresh the Token Lists

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh --restart-anvil foundation
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh scenario1
```

You should see `[INFO] Building token lists from fragments` and one
`[OK]`/`[SKIP]` line per bucket at the end.

### Run the aggregator manually

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run build-tokenlists -- --config "$(git rev-parse --show-toplevel)/tokenlists.config.ts"
```

### Run the Node tests

```bash
cd scripts/node && npm test
```

20 tests across 5 files. Should all pass.

### Re-run the one-time legacy migration

If you wipe `frontend/app/addresses/<env>/<bucket>.tokenlist.json` files and want
to regenerate from the legacy per-category arrays:

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run migrate-legacy
```

### Override a dropdown label

Edit any fragment or list entry to add:

```json
"extensions": { "display": "My Custom Label" }
```

The UI's `resolveLabel` reads this before `name` / `symbol`.

### Opt out of the aggregator

```bash
SKIP_TOKENLIST_BUILD=1 bash scripts/shell/local_testing.sh foundation
```

---

## Migration phases — what's done, what's deferred

The plan had four phases. Status:

### Phase 1 — Parallel produce ✅ done
- Solidity helper `_writeManifestEntry`
- Pilot scripts 03/06/10 emit fragments alongside legacy JSONs
- Node aggregator with 20 passing tests
- Shell wrapper invokes the aggregator post-deploy
- Bootstrap data via one-time legacy migration (64 lists across 7 envs × 2 chains)
- User-facing doc at `docs/tokenlist-pipeline.md`

### Phase 2 — Shadow consume ⊘ skipped
The plan included a step where the UI loads both legacy and composed lists in dev
mode and logs diffs. We skipped this because the migration script deterministically
produces the same data the legacy path was producing — there was nothing to shadow-
diff against meaningfully. Worth resurrecting only if a future change makes the
two paths diverge.

### Phase 3 — Cutover ✅ done
- `getCached()` rewired to compose lists + tag filter
- Public API surface unchanged (no UI call sites needed editing)
- Frontend `tsc --noEmit` clean

### Phase 4 — Producer cleanup ⏸ partial / deferred
- Scripts 03/06/10 emit BOTH legacy and fragment outputs. Removing the legacy
  `_exportJson` from these requires also updating every script that reads them
  (`_readAddress(... "weth")` etc. in downstream scripts). Defer until all
  scripts are fragment-aware.
- Remaining scripts (Script_05, Script_11, Script_12, all supersim scripts) do
  NOT yet emit fragments. Their tokens won't appear in the new Token Lists
  until they're migrated.
- The unused per-category fields on `ArtifactBundle.tokenlists` are still
  imported by `frontend/app/addresses/index.ts`. They add to the bundle but
  cause no runtime issues. Bundle-size cleanup, not a correctness issue.

### Open follow-ups worth tracking
1. Migrate the remaining Solidity scripts to emit fragments (Phase 4).
2. Add a `vaults/seigniorageDetf` bucket so that category leaves the legacy path.
3. Add typed `extensions` interfaces per tag category (e.g. `BalancerPoolExtensions`
   with `factory`, `composingAssets`, `hook`).
4. Add a `factories/`, `facets/`, `hooks/`, `routers/` typed taxonomy with
   separate consumers (not part of the Token List).
5. Once all envs deploy via the aggregator, delete the legacy per-category JSON
   files and remove the dead imports from `addresses/index.ts`.

---

## Operating principles for future changes

- **Producer scripts MUST stay schema-ignorant.** They emit fragments with raw
  fields. They should never compute `version`, `timestamp`, or validate against
  the Uniswap schema — that's the aggregator's job.
- **The Token List schema is the contract.** If you change a fragment shape, the
  aggregator's `normalize.ts` is where you reconcile it.
- **Adding a new pool type is a five-file change.** If you find yourself touching
  more than that, you're fighting the design — back up and re-read this doc.
- **Run `cd scripts/node && npm test` after any change to the aggregator.** TDD
  was used to build it; preserve that hygiene.
- **Frontend `npx tsc --noEmit` after any consumer change.** The `getCached()`
  rewrite is the kind of code where a missed tag filter would silently empty
  a dropdown.
- **Keep `tokenlists.config.ts` aligned with `deriveTags.ts`.** Every tag a
  fragment can carry should appear in some bucket's `tagDefinitions`, otherwise
  the schema validator complains.

---

## Quick reference: who depends on what

```
Foundry deploy script
        |
        | calls _writeManifestEntry(typeDir, key, entry)
        v
LocalTestingDeploymentBase.sol
        |
        | vm.writeFile to
        | deployments/<env>/<chain>/fragments/<typeDir>/<key>.json
        v
local_testing.sh                    <-- entry point users run
        |
        | run_aggregator()
        v
scripts/node/src/main.ts
        |
        | readFragmentsForChain → buildList (tags + normalize + bump + validate) → writeList
        v
frontend/app/addresses/<env>/<chain>/<bucket>.tokenlist.json
        |
        | static imports
        v
frontend/app/lib/tokenlistRegistry.ts
        |
        | LIST_REGISTRY[env][chain]
        v
frontend/app/lib/tokenlistCompose.ts (composeLists, byTag, resolveLabel)
        |
        | byTag(['balancer', 'balV3'], chainId)
        v
frontend/app/lib/tokenlists.ts (getCached, buildPoolOptionsForChain, ...)
        |
        | poolOptions
        v
frontend/app/swap/page.tsx <select> dropdown
```

---

## Commits that built this

In `git log` order (newest first):

```
95e62b2be  feat(frontend): UI consumer uses composed Token Lists for pool dropdown
98287b413  feat(frontend): one-time migration of legacy tokenlists to Token List schema
23493d65b  feat(scripts/shell): invoke tokenlist aggregator after deploy stages
3de04ec5b  feat(scripts/foundry): emit Token List fragments from Scripts 03/06/10
018c6ee74  feat(scripts/foundry): ManifestEntry + _writeManifestEntry helper
22d716b99  feat(scripts/node): tokenlist aggregator package with TDD-tested modules
```

Each commit is independently revertable. The aggregator package (oldest) is the
foundation; reverting it cascades to the others. Reverting only the UI consumer
commit (`95e62b2be`) puts the UI back on the legacy per-category JSON path while
keeping the new producer/aggregator infrastructure available.

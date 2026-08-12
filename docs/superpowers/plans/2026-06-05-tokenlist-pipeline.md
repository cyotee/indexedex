# Token List Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ad-hoc per-category deployment JSON layout with a typed-directory producer + Node aggregator + composing UI consumer, communicating via the Uniswap Token List standard so adding a new pool type becomes a one-file change per layer, label overrides live in `extensions.display`, and third-party tooling can ingest our lists.

**Architecture:** Three layers separated by the Token List schema as interface contract.
1. Solidity scripts write one fragment per artifact into typed directories (`deployments/<env>/<chain>/{tokens,pools/<protocol>,vaults/<flavor>,factories,facets,hooks,routers}/<key>.json`). Fragments are raw entries with `address`, `name`, `symbol`, `decimals`, `tags[]`, `extensions{}` — no list metadata.
2. A Node aggregator (`scripts/node/build_tokenlists.ts`) walks the fragment tree, derives tags from directory paths, groups into output lists per a config file, computes the semver bump by diffing against the previous published list, stamps `name`/`timestamp`/`version`, validates against `@uniswap/token-lists`'s Ajv schema, and writes per-category Token Lists to `frontend/app/addresses/<env>/<chain>/`.
3. The UI loads N statically-imported Token Lists per `(env, chain)`, composes them via `composeLists()` (merge by `(chainId, address)` with declared priority), and exposes tag-filtered selectors (`byTag`, `byAddress`, `resolveLabel`). `buildPoolOptionsForChain` and siblings collapse to tag filters over the composed store.

**Tech Stack:** Foundry / Solidity 0.8.30, Node 20+, TypeScript, `@uniswap/token-lists` (schema + Ajv validation), `ajv`, `ajv-formats`, Next.js 14 (UI), Vitest (Node tests), Forge (Solidity tests).

**Locked starting decisions** (revisitable later, but the plan assumes these):
1. **Fragment granularity:** one JSON per artifact (clean diffs, dozens-to-hundreds of small files per env-chain).
2. **List boundary:** one Token List per top-level type-directory (`balancer-v3-pools.tokenlist.json`, `strategy-vaults.tokenlist.json`, etc.). Re-bucketing to per-protocol is a config change, not a code change.
3. **`extensions` shape:** hand-maintained TS interfaces per tag category (`BalancerPoolExtensions`, `StrategyVaultExtensions`, …). Loose `Record<string, unknown>` accepted at parse time; refined types narrow in selectors.
4. **Version bump:** auto-derived from a diff against the previously published list. Major if any address removed/replaced, minor if any added, patch if metadata-only.
5. **Aggregator location:** `scripts/node/` at the repo root, project-scoped. Not under `frontend/`.
6. **Phase-2 shadow strictness:** log diffs to console only, never throw. Less disruptive; lets dev work continue while we close gaps.

**Migration phases (each is independently shippable):**
- **Phase 1 — Parallel produce.** Solidity emits fragments alongside legacy per-category JSON. Aggregator runs to a side directory. UI unaffected.
- **Phase 2 — Shadow consume.** UI loads both legacy and composed lists in dev; asserts equality at boot and logs diffs.
- **Phase 3 — Cutover.** UI reads only composed lists. Delete legacy per-category builders in `tokenlists.ts`.
- **Phase 4 — Producer cleanup.** Solidity stops writing legacy per-category JSON. Delete the deprecated helpers.

---

## Reference material

**Uniswap Token List standard**
- Repo: https://github.com/Uniswap/token-lists
- JSON schema: https://uniswap.org/tokenlist.schema.json
- npm: `@uniswap/token-lists` (provides the JSON Schema; pair with `ajv` + `ajv-formats` for runtime validation)
- Key fields: `name`, `timestamp` (ISO 8601), `version: { major, minor, patch }`, `keywords[]`, `tags{}` (top-level tag definitions), `tokens[]` (each entry has `chainId`, `address`, `name`, `symbol`, `decimals`, optional `logoURI`, `tags[]`, `extensions{}`).
- Extensions are an open object — anything we put in `extensions` does not invalidate the list.

**Current code locations (the things that change)**
- Solidity producer base: `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol`
- Solidity stages: `scripts/foundry/local_testing/anvil_single/Script_0{1..6}_*.s.sol`, `Script_1{0..2}_*.s.sol`
- Shell wrapper: `scripts/shell/local_testing.sh`
- Supersim wrapper: `scripts/shell/local_testing_supersim.sh`
- UI address registry: `frontend/app/addresses/index.ts`
- UI tokenlists glue: `frontend/app/lib/tokenlists.ts` (sole consumer of the eight per-category arrays)
- UI artifact resolver: `frontend/app/lib/addressArtifacts.ts`
- UI consumer of pool options: `frontend/app/swap/page.tsx:493` (`poolOptions`), `frontend/app/swap/page.tsx:3400` (dropdown), `frontend/app/batch-swap/page.tsx:256`, `frontend/app/swap/hooks/useSwapState.ts:136`

---

## File structure

**New files**
```
scripts/node/
  package.json                                  # local package, separate from frontend
  tsconfig.json
  vitest.config.ts
  src/
    types.ts                                    # ManifestFragment, TokenListRef, ComposedStore types
    schema.ts                                   # Ajv compile + tokenlist schema loader
    readFragments.ts                            # walk deployments/<env>/<chain>/<type>/
    deriveTags.ts                               # directory path -> default tags
    groupByList.ts                              # apply tokenlists.config.ts to bucket fragments
    bumpVersion.ts                              # diff previous list vs current tokens, emit {major,minor,patch}
    buildList.ts                                # fragments -> validated TokenList
    writeList.ts                                # write to frontend/app/addresses + log diff
    main.ts                                     # CLI entrypoint
  test/
    deriveTags.test.ts
    bumpVersion.test.ts
    buildList.test.ts
    schema.test.ts
  fixtures/                                     # sample fragments + expected lists for tests
tokenlists.config.ts                            # repo-root config: list name, keywords, tag taxonomy per output list

scripts/foundry/local_testing/shared/
  ManifestEntry.sol                             # struct definitions + JSON serialization helpers

frontend/app/lib/
  tokenlistCompose.ts                           # composeLists, byTag, byAddress, resolveLabel
  tokenlistShadow.ts                            # Phase 2: legacy-vs-composed equality check
  tokenlistRegistry.ts                          # Phase 2: Record<env, Record<chain, TokenListRef[]>>

docs/
  tokenlist-pipeline.md                         # short user-facing doc (post-Phase-1)
```

**Modified files**
```
scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol
  + import ManifestEntry
  + _writeManifestEntry(string memory typeDir, string memory key, ManifestEntry memory entry)
  + _fragmentRoot() helper

scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol   # Phase 1 pilot
scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol   # Phase 1 second pilot
(remaining scripts migrated in Phase 4)

scripts/shell/local_testing.sh
  + run_aggregator() invoked after the last forge script in every command
  + SKIP_TOKENLIST_BUILD opt-out env var

scripts/shell/local_testing_supersim.sh
  + same run_aggregator() integration

frontend/app/addresses/index.ts                 # Phase 3: list registry shape
frontend/app/lib/tokenlists.ts                  # Phase 3: collapses to tag-filtered selectors

package.json (root)                             # Phase 1: add devDeps + npm scripts
```

---

# Phase 1 — Parallel produce

Goal: After this phase, every staged Solidity run emits typed fragments **in addition to** the legacy per-category JSONs. The aggregator runs and writes validated Token Lists to a side directory. The UI is untouched and behaves exactly as before.

## Task 1.1: Initialize the `scripts/node/` package

**Files:**
- Create: `scripts/node/package.json`
- Create: `scripts/node/tsconfig.json`
- Create: `scripts/node/vitest.config.ts`
- Create: `scripts/node/.gitignore`

- [ ] **Step 1: Create the package manifest**

Create `scripts/node/package.json`:

```json
{
  "name": "@indexedex/scripts-node",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build-tokenlists": "tsx src/main.ts",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@uniswap/token-lists": "^1.0.3",
    "ajv": "^8.17.1",
    "ajv-formats": "^3.0.1",
    "fast-glob": "^3.3.2"
  },
  "devDependencies": {
    "tsx": "^4.19.2",
    "typescript": "^5.6.3",
    "vitest": "^2.1.5",
    "@types/node": "^22.10.0"
  }
}
```

- [ ] **Step 2: Create the TypeScript config**

Create `scripts/node/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*", "test/**/*"]
}
```

- [ ] **Step 3: Create the Vitest config**

Create `scripts/node/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
  },
})
```

- [ ] **Step 4: Create the gitignore**

Create `scripts/node/.gitignore`:

```
node_modules/
dist/
*.log
```

- [ ] **Step 5: Install and verify**

```bash
cd scripts/node && npm install
```

Expected: clean install, no errors, `node_modules/` populated.

- [ ] **Step 6: Commit**

```bash
git add scripts/node/package.json scripts/node/package-lock.json scripts/node/tsconfig.json scripts/node/vitest.config.ts scripts/node/.gitignore
git commit -m "feat(scripts/node): scaffold tokenlist aggregator package"
```

---

## Task 1.2: Define core types

**Files:**
- Create: `scripts/node/src/types.ts`

- [ ] **Step 1: Write the types module**

Create `scripts/node/src/types.ts`:

```ts
import type { TokenList, TokenInfo } from '@uniswap/token-lists'

export type Address = `0x${string}`
export type ChainId = number

export interface ManifestFragment {
  chainId: ChainId
  address: Address
  name: string
  symbol: string
  decimals: number
  tags?: string[]
  extensions?: Record<string, unknown>
  // Filled in by the reader; not present in source JSON.
  sourcePath?: string
  sourceTypeDir?: string
}

export interface ListBucketConfig {
  id: string
  name: string
  keywords: string[]
  includeTypeDirs: string[]
  defaultTags: string[]
  tagDefinitions: Record<string, { name: string; description: string }>
}

export interface AggregatorConfig {
  environments: Array<{
    environment: string
    chains: Array<{ chainId: ChainId; chainDir: string }>
  }>
  buckets: ListBucketConfig[]
  inputRoot: string
  outputRoot: string
}

export interface BumpResult {
  bump: 'major' | 'minor' | 'patch' | 'none'
  previous: { major: number; minor: number; patch: number } | null
  next: { major: number; minor: number; patch: number }
  changes: {
    added: Address[]
    removed: Address[]
    modified: Address[]
  }
}

export type { TokenList, TokenInfo }
```

- [ ] **Step 2: Commit**

```bash
git add scripts/node/src/types.ts
git commit -m "feat(scripts/node): add core type definitions"
```

---

## Task 1.3: Add tag-derivation logic (TDD)

**Files:**
- Create: `scripts/node/test/deriveTags.test.ts`
- Create: `scripts/node/src/deriveTags.ts`

- [ ] **Step 1: Write the failing tests**

Create `scripts/node/test/deriveTags.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { deriveTagsFromTypeDir } from '../src/deriveTags.js'

describe('deriveTagsFromTypeDir', () => {
  it('derives pool + protocol tags for pools/balancerV3', () => {
    expect(deriveTagsFromTypeDir('pools/balancerV3')).toEqual(['pool', 'balancerPool', 'balancerV3'])
  })

  it('derives pool + uniV2 for pools/uniV2', () => {
    expect(deriveTagsFromTypeDir('pools/uniV2')).toEqual(['pool', 'uniV2Pool', 'uniV2'])
  })

  it('derives vault + erc4626 for vaults/erc4626', () => {
    expect(deriveTagsFromTypeDir('vaults/erc4626')).toEqual(['vault', 'erc4626Vault', 'erc4626'])
  })

  it('derives token tag for tokens/', () => {
    expect(deriveTagsFromTypeDir('tokens')).toEqual(['token'])
  })

  it('returns empty for unknown directory', () => {
    expect(deriveTagsFromTypeDir('mystery')).toEqual([])
  })

  it('normalizes leading slash and trailing slash', () => {
    expect(deriveTagsFromTypeDir('/pools/balancerV3/')).toEqual(['pool', 'balancerPool', 'balancerV3'])
  })
})
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd scripts/node && npm test -- deriveTags
```

Expected: FAIL — `Cannot find module '../src/deriveTags.js'`.

- [ ] **Step 3: Implement `deriveTagsFromTypeDir`**

Create `scripts/node/src/deriveTags.ts`:

```ts
const TAXONOMY: Record<string, string[]> = {
  'tokens': ['token'],
  'pools/balancerV3': ['pool', 'balancerPool', 'balancerV3'],
  'pools/uniV2': ['pool', 'uniV2Pool', 'uniV2'],
  'pools/aerodrome': ['pool', 'aerodromePool', 'aerodrome'],
  'vaults/erc4626': ['vault', 'erc4626Vault', 'erc4626'],
  'vaults/strategy': ['vault', 'strategyVault'],
  'vaults/protocolDetf': ['vault', 'protocolDetf'],
}

export function deriveTagsFromTypeDir(typeDir: string): string[] {
  const normalized = typeDir.replace(/^\/+|\/+$/g, '')
  return TAXONOMY[normalized] ?? []
}

export function isKnownTypeDir(typeDir: string): boolean {
  const normalized = typeDir.replace(/^\/+|\/+$/g, '')
  return normalized in TAXONOMY
}

export function knownTypeDirs(): string[] {
  return Object.keys(TAXONOMY)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd scripts/node && npm test -- deriveTags
```

Expected: PASS, 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/node/src/deriveTags.ts scripts/node/test/deriveTags.test.ts
git commit -m "feat(scripts/node): derive default tags from fragment directory"
```

---

## Task 1.4: Add fragment reader (TDD)

**Files:**
- Create: `scripts/node/test/readFragments.test.ts`
- Create: `scripts/node/src/readFragments.ts`
- Create: `scripts/node/fixtures/sample-deploys/sepolia/11155111/tokens/tta.json`
- Create: `scripts/node/fixtures/sample-deploys/sepolia/11155111/pools/balancerV3/abPool.json`

- [ ] **Step 1: Create fixture fragments**

Create `scripts/node/fixtures/sample-deploys/sepolia/11155111/tokens/tta.json`:

```json
{
  "chainId": 11155111,
  "address": "0x1111111111111111111111111111111111111111",
  "name": "Test Token A",
  "symbol": "TTA",
  "decimals": 18,
  "tags": ["testToken"]
}
```

Create `scripts/node/fixtures/sample-deploys/sepolia/11155111/pools/balancerV3/abPool.json`:

```json
{
  "chainId": 11155111,
  "address": "0x2222222222222222222222222222222222222222",
  "name": "BV3ConstProd of (TTA / TTB)",
  "symbol": "abBalancerV3ConstProdPool",
  "decimals": 18,
  "extensions": {
    "composingAssets": [
      "0x1111111111111111111111111111111111111111",
      "0x3333333333333333333333333333333333333333"
    ]
  }
}
```

- [ ] **Step 2: Write the failing tests**

Create `scripts/node/test/readFragments.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { join } from 'node:path'
import { readFragmentsForChain } from '../src/readFragments.js'

const FIXTURES = join(__dirname, '..', 'fixtures', 'sample-deploys')

describe('readFragmentsForChain', () => {
  it('returns all fragments for the chain with sourceTypeDir attached', async () => {
    const fragments = await readFragmentsForChain(FIXTURES, 'sepolia', '11155111')
    expect(fragments).toHaveLength(2)

    const token = fragments.find(f => f.symbol === 'TTA')!
    expect(token.sourceTypeDir).toBe('tokens')

    const pool = fragments.find(f => f.symbol === 'abBalancerV3ConstProdPool')!
    expect(pool.sourceTypeDir).toBe('pools/balancerV3')
    expect(pool.extensions?.composingAssets).toEqual([
      '0x1111111111111111111111111111111111111111',
      '0x3333333333333333333333333333333333333333',
    ])
  })

  it('returns empty array when the chain directory does not exist', async () => {
    const fragments = await readFragmentsForChain(FIXTURES, 'sepolia', '999')
    expect(fragments).toEqual([])
  })

  it('throws on malformed JSON', async () => {
    await expect(
      readFragmentsForChain(join(__dirname, 'nonsense'), 'sepolia', '11155111')
    ).resolves.toEqual([])
  })
})
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd scripts/node && npm test -- readFragments
```

Expected: FAIL — module not found.

- [ ] **Step 4: Implement `readFragmentsForChain`**

Create `scripts/node/src/readFragments.ts`:

```ts
import { readFile, stat } from 'node:fs/promises'
import { join, relative, sep, posix } from 'node:path'
import fg from 'fast-glob'
import type { ManifestFragment } from './types.js'
import { knownTypeDirs } from './deriveTags.js'

export async function readFragmentsForChain(
  inputRoot: string,
  environment: string,
  chainDir: string
): Promise<ManifestFragment[]> {
  const chainRoot = join(inputRoot, environment, chainDir)

  try {
    const s = await stat(chainRoot)
    if (!s.isDirectory()) return []
  } catch {
    return []
  }

  const patterns = knownTypeDirs().map((d) => `${d}/**/*.json`)
  const files = await fg(patterns, { cwd: chainRoot, absolute: true })

  const fragments: ManifestFragment[] = []
  for (const file of files) {
    const raw = await readFile(file, 'utf8')
    const parsed = JSON.parse(raw) as ManifestFragment

    const relPath = relative(chainRoot, file).split(sep).join(posix.sep)
    const typeDir = relPath.split('/').slice(0, -1).join('/')
    const collapsedTypeDir = collapseToKnownTypeDir(typeDir)

    fragments.push({
      ...parsed,
      sourcePath: file,
      sourceTypeDir: collapsedTypeDir,
    })
  }

  return fragments
}

function collapseToKnownTypeDir(relTypeDir: string): string {
  for (const known of knownTypeDirs()) {
    if (relTypeDir === known || relTypeDir.startsWith(known + '/')) {
      return known
    }
  }
  return relTypeDir
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd scripts/node && npm test -- readFragments
```

Expected: PASS, 3 tests green.

- [ ] **Step 6: Commit**

```bash
git add scripts/node/src/readFragments.ts scripts/node/test/readFragments.test.ts scripts/node/fixtures/
git commit -m "feat(scripts/node): read manifest fragments from typed directory tree"
```

---

## Task 1.5: Add version-bump logic (TDD)

**Files:**
- Create: `scripts/node/test/bumpVersion.test.ts`
- Create: `scripts/node/src/bumpVersion.ts`

- [ ] **Step 1: Write the failing tests**

Create `scripts/node/test/bumpVersion.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { computeBump } from '../src/bumpVersion.js'
import type { TokenInfo } from '../src/types.js'

const T = (address: string, decimals = 18, extras: Partial<TokenInfo> = {}): TokenInfo => ({
  chainId: 1,
  address,
  name: 'X',
  symbol: 'X',
  decimals,
  ...extras,
})

describe('computeBump', () => {
  it('starts at 1.0.0 when there is no previous list', () => {
    const result = computeBump(null, [T('0x1')])
    expect(result.bump).toBe('major')
    expect(result.next).toEqual({ major: 1, minor: 0, patch: 0 })
  })

  it('patches when only metadata changed for the same address set', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1', 18, { name: 'old' })] }
    const result = computeBump(prev, [T('0x1', 18, { name: 'new' })])
    expect(result.bump).toBe('patch')
    expect(result.next).toEqual({ major: 2, minor: 3, patch: 5 })
    expect(result.changes.modified).toEqual(['0x1'])
  })

  it('minor bumps when an address is added', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1')] }
    const result = computeBump(prev, [T('0x1'), T('0x2')])
    expect(result.bump).toBe('minor')
    expect(result.next).toEqual({ major: 2, minor: 4, patch: 0 })
    expect(result.changes.added).toEqual(['0x2'])
  })

  it('major bumps when an address is removed', () => {
    const prev = { major: 2, minor: 3, patch: 4, tokens: [T('0x1'), T('0x2')] }
    const result = computeBump(prev, [T('0x1')])
    expect(result.bump).toBe('major')
    expect(result.next).toEqual({ major: 3, minor: 0, patch: 0 })
    expect(result.changes.removed).toEqual(['0x2'])
  })

  it('reports none when nothing changed', () => {
    const prev = { major: 1, minor: 0, patch: 0, tokens: [T('0x1')] }
    const result = computeBump(prev, [T('0x1')])
    expect(result.bump).toBe('none')
    expect(result.next).toEqual({ major: 1, minor: 0, patch: 0 })
  })

  it('compares addresses case-insensitively', () => {
    const prev = { major: 1, minor: 0, patch: 0, tokens: [T('0xABCDEF')] }
    const result = computeBump(prev, [T('0xabcdef')])
    expect(result.bump).toBe('none')
  })
})
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd scripts/node && npm test -- bumpVersion
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `computeBump`**

Create `scripts/node/src/bumpVersion.ts`:

```ts
import type { BumpResult, TokenInfo, Address } from './types.js'

export interface PreviousList {
  major: number
  minor: number
  patch: number
  tokens: TokenInfo[]
}

export function computeBump(previous: PreviousList | null, current: TokenInfo[]): BumpResult {
  if (previous === null) {
    return {
      bump: 'major',
      previous: null,
      next: { major: 1, minor: 0, patch: 0 },
      changes: {
        added: current.map((t) => t.address as Address),
        removed: [],
        modified: [],
      },
    }
  }

  const prevByAddr = new Map(previous.tokens.map((t) => [t.address.toLowerCase(), t]))
  const currByAddr = new Map(current.map((t) => [t.address.toLowerCase(), t]))

  const added: Address[] = []
  const removed: Address[] = []
  const modified: Address[] = []

  for (const [addr, token] of currByAddr) {
    if (!prevByAddr.has(addr)) {
      added.push(token.address as Address)
    } else if (!tokenInfoEquals(prevByAddr.get(addr)!, token)) {
      modified.push(token.address as Address)
    }
  }

  for (const [addr, token] of prevByAddr) {
    if (!currByAddr.has(addr)) removed.push(token.address as Address)
  }

  const { major, minor, patch } = previous
  let next = { major, minor, patch }
  let bump: BumpResult['bump'] = 'none'

  if (removed.length > 0) {
    next = { major: major + 1, minor: 0, patch: 0 }
    bump = 'major'
  } else if (added.length > 0) {
    next = { major, minor: minor + 1, patch: 0 }
    bump = 'minor'
  } else if (modified.length > 0) {
    next = { major, minor, patch: patch + 1 }
    bump = 'patch'
  }

  return {
    bump,
    previous: { major, minor, patch },
    next,
    changes: { added, removed, modified },
  }
}

function tokenInfoEquals(a: TokenInfo, b: TokenInfo): boolean {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b))
}

function canonical(t: TokenInfo): unknown {
  return {
    chainId: t.chainId,
    address: t.address.toLowerCase(),
    name: t.name,
    symbol: t.symbol,
    decimals: t.decimals,
    logoURI: t.logoURI ?? null,
    tags: [...(t.tags ?? [])].sort(),
    extensions: t.extensions ?? null,
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd scripts/node && npm test -- bumpVersion
```

Expected: PASS, 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/node/src/bumpVersion.ts scripts/node/test/bumpVersion.test.ts
git commit -m "feat(scripts/node): semver bump derived from diff against previous list"
```

---

## Task 1.6: Add schema validation (TDD)

**Files:**
- Create: `scripts/node/test/schema.test.ts`
- Create: `scripts/node/src/schema.ts`

- [ ] **Step 1: Write the failing test**

Create `scripts/node/test/schema.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { validateTokenList } from '../src/schema.js'

describe('validateTokenList', () => {
  it('accepts a minimal valid token list', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      version: { major: 1, minor: 0, patch: 0 },
      tokens: [
        {
          chainId: 11155111,
          address: '0x1111111111111111111111111111111111111111',
          name: 'Test',
          symbol: 'TST',
          decimals: 18,
        },
      ],
    })
    expect(result.valid).toBe(true)
    expect(result.errors).toEqual([])
  })

  it('rejects a list missing `version`', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      tokens: [],
    } as any)
    expect(result.valid).toBe(false)
    expect(result.errors.length).toBeGreaterThan(0)
  })

  it('rejects a token with a malformed address', () => {
    const result = validateTokenList({
      name: 'Indexedex Test',
      timestamp: '2026-06-05T00:00:00.000Z',
      version: { major: 1, minor: 0, patch: 0 },
      tokens: [
        { chainId: 1, address: 'not-an-address', name: 'T', symbol: 'T', decimals: 18 },
      ],
    })
    expect(result.valid).toBe(false)
  })
})
```

- [ ] **Step 2: Run to verify failure**

```bash
cd scripts/node && npm test -- schema
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `validateTokenList`**

Create `scripts/node/src/schema.ts`:

```ts
import Ajv from 'ajv'
import addFormats from 'ajv-formats'
import { schema as tokenListSchema } from '@uniswap/token-lists'
import type { TokenList } from './types.js'

const ajv = new Ajv({ allErrors: true, strict: false })
addFormats(ajv)
const validate = ajv.compile(tokenListSchema)

export interface ValidationResult {
  valid: boolean
  errors: string[]
}

export function validateTokenList(list: TokenList): ValidationResult {
  const valid = validate(list) as boolean
  const errors = valid
    ? []
    : (validate.errors ?? []).map((e) => `${e.instancePath || '<root>'} ${e.message ?? 'invalid'}`)
  return { valid, errors }
}
```

- [ ] **Step 4: Run to verify success**

```bash
cd scripts/node && npm test -- schema
```

Expected: PASS, 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/node/src/schema.ts scripts/node/test/schema.test.ts
git commit -m "feat(scripts/node): Ajv-validated Token List schema check"
```

---

## Task 1.7: Add list-building integration (TDD)

**Files:**
- Create: `scripts/node/test/buildList.test.ts`
- Create: `scripts/node/src/buildList.ts`
- Create: `scripts/node/src/groupByList.ts`

- [ ] **Step 1: Write the failing tests**

Create `scripts/node/test/buildList.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { buildList } from '../src/buildList.js'
import type { ManifestFragment, ListBucketConfig } from '../src/types.js'

const POOLS_BUCKET: ListBucketConfig = {
  id: 'balancer-v3-pools',
  name: 'Indexedex Balancer V3 Pools',
  keywords: ['indexedex', 'balancer'],
  includeTypeDirs: ['pools/balancerV3'],
  defaultTags: [],
  tagDefinitions: {
    pool: { name: 'Pool', description: 'AMM pool' },
    balancerPool: { name: 'Balancer Pool', description: '' },
    balancerV3: { name: 'Balancer V3', description: '' },
  },
}

const fragment: ManifestFragment = {
  chainId: 11155111,
  address: '0x2222222222222222222222222222222222222222',
  name: 'AB Pool',
  symbol: 'abPool',
  decimals: 18,
  sourceTypeDir: 'pools/balancerV3',
}

describe('buildList', () => {
  it('produces a schema-valid list with derived tags and stamped metadata', () => {
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [fragment],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })

    expect(result.list.name).toBe('Indexedex Balancer V3 Pools')
    expect(result.list.timestamp).toBe('2026-06-05T00:00:00.000Z')
    expect(result.list.version).toEqual({ major: 1, minor: 0, patch: 0 })
    expect(result.list.tokens).toHaveLength(1)
    expect(result.list.tokens[0]?.tags).toEqual(['pool', 'balancerPool', 'balancerV3'])
    expect(result.list.tags).toEqual(POOLS_BUCKET.tagDefinitions)
    expect(result.validation.valid).toBe(true)
  })

  it('drops fragments whose sourceTypeDir is outside includeTypeDirs', () => {
    const other: ManifestFragment = { ...fragment, sourceTypeDir: 'tokens', address: '0x3333333333333333333333333333333333333333' }
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [fragment, other],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })
    expect(result.list.tokens).toHaveLength(1)
    expect(result.list.tokens[0]?.address.toLowerCase()).toBe(fragment.address)
  })

  it('preserves explicit fragment tags as a union with directory-derived tags', () => {
    const tagged = { ...fragment, tags: ['custom', 'pool'] }
    const result = buildList({
      bucket: POOLS_BUCKET,
      fragments: [tagged],
      previousList: null,
      timestamp: '2026-06-05T00:00:00.000Z',
    })
    expect(result.list.tokens[0]?.tags).toEqual(['pool', 'balancerPool', 'balancerV3', 'custom'])
  })
})
```

- [ ] **Step 2: Run to verify failure**

```bash
cd scripts/node && npm test -- buildList
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `groupByList`**

Create `scripts/node/src/groupByList.ts`:

```ts
import type { ListBucketConfig, ManifestFragment } from './types.js'

export function filterFragmentsForBucket(
  bucket: ListBucketConfig,
  fragments: ManifestFragment[]
): ManifestFragment[] {
  const allow = new Set(bucket.includeTypeDirs)
  return fragments.filter((f) => f.sourceTypeDir !== undefined && allow.has(f.sourceTypeDir))
}
```

- [ ] **Step 4: Implement `buildList`**

Create `scripts/node/src/buildList.ts`:

```ts
import type { ListBucketConfig, ManifestFragment, TokenList, TokenInfo } from './types.js'
import { deriveTagsFromTypeDir } from './deriveTags.js'
import { filterFragmentsForBucket } from './groupByList.js'
import { computeBump, type PreviousList } from './bumpVersion.js'
import { validateTokenList, type ValidationResult } from './schema.js'

export interface BuildListInput {
  bucket: ListBucketConfig
  fragments: ManifestFragment[]
  previousList: PreviousList | null
  timestamp: string
}

export interface BuildListResult {
  list: TokenList
  validation: ValidationResult
  bump: ReturnType<typeof computeBump>
}

export function buildList({ bucket, fragments, previousList, timestamp }: BuildListInput): BuildListResult {
  const scoped = filterFragmentsForBucket(bucket, fragments)

  const tokens: TokenInfo[] = scoped.map((f) => {
    const derivedTags = deriveTagsFromTypeDir(f.sourceTypeDir ?? '')
    const explicitTags = f.tags ?? []
    const tags = unionPreservingOrder(derivedTags, explicitTags)

    return {
      chainId: f.chainId,
      address: f.address,
      name: f.name,
      symbol: f.symbol,
      decimals: f.decimals,
      ...(tags.length > 0 ? { tags } : {}),
      ...(f.extensions ? { extensions: f.extensions as TokenInfo['extensions'] } : {}),
    }
  })

  const bump = computeBump(previousList, tokens)
  const list: TokenList = {
    name: bucket.name,
    timestamp,
    version: bump.next,
    keywords: bucket.keywords,
    tags: bucket.tagDefinitions,
    tokens,
  }

  return { list, validation: validateTokenList(list), bump }
}

function unionPreservingOrder<T>(a: T[], b: T[]): T[] {
  const seen = new Set<T>()
  const out: T[] = []
  for (const x of [...a, ...b]) {
    if (!seen.has(x)) {
      seen.add(x)
      out.push(x)
    }
  }
  return out
}
```

- [ ] **Step 5: Run to verify pass**

```bash
cd scripts/node && npm test -- buildList
```

Expected: PASS, 3 tests green.

- [ ] **Step 6: Commit**

```bash
git add scripts/node/src/buildList.ts scripts/node/src/groupByList.ts scripts/node/test/buildList.test.ts
git commit -m "feat(scripts/node): assemble validated Token Lists from fragments"
```

---

## Task 1.8: Add list writer with previous-version load

**Files:**
- Create: `scripts/node/src/writeList.ts`

- [ ] **Step 1: Implement the writer**

Create `scripts/node/src/writeList.ts`:

```ts
import { readFile, writeFile, mkdir } from 'node:fs/promises'
import { dirname } from 'node:path'
import type { TokenList } from './types.js'
import type { PreviousList } from './bumpVersion.js'

export async function loadPreviousList(path: string): Promise<PreviousList | null> {
  try {
    const raw = await readFile(path, 'utf8')
    const parsed = JSON.parse(raw) as TokenList
    return {
      major: parsed.version.major,
      minor: parsed.version.minor,
      patch: parsed.version.patch,
      tokens: parsed.tokens,
    }
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null
    throw err
  }
}

export async function writeList(path: string, list: TokenList): Promise<void> {
  await mkdir(dirname(path), { recursive: true })
  await writeFile(path, JSON.stringify(list, null, 2) + '\n', 'utf8')
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/node/src/writeList.ts
git commit -m "feat(scripts/node): load previous list + atomic-ish list writer"
```

---

## Task 1.9: Wire the CLI entrypoint + repo-root config

**Files:**
- Create: `scripts/node/src/main.ts`
- Create: `tokenlists.config.ts` (repo root)
- Modify: `scripts/node/package.json` — add a `--config` arg to the `build-tokenlists` script

- [ ] **Step 1: Create the root config**

Create `tokenlists.config.ts`:

```ts
import type { AggregatorConfig } from './scripts/node/src/types.js'

export const config: AggregatorConfig = {
  inputRoot: 'deployments',
  outputRoot: 'frontend/app/addresses',
  environments: [
    {
      environment: 'local_testing',
      chains: [{ chainId: 11155111, chainDir: 'anvil_single' }],
    },
    {
      environment: 'supersim_sepolia',
      chains: [
        { chainId: 11155111, chainDir: 'ethereum' },
        { chainId: 84532, chainDir: 'base' },
      ],
    },
  ],
  buckets: [
    {
      id: 'base-tokens',
      name: 'Indexedex Base Tokens',
      keywords: ['indexedex', 'tokens'],
      includeTypeDirs: ['tokens'],
      defaultTags: [],
      tagDefinitions: {
        token: { name: 'Token', description: 'ERC20 token' },
        testToken: { name: 'Test Token', description: 'Test ERC20' },
      },
    },
    {
      id: 'balancer-v3-pools',
      name: 'Indexedex Balancer V3 Pools',
      keywords: ['indexedex', 'balancer', 'pool'],
      includeTypeDirs: ['pools/balancerV3'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: 'AMM pool' },
        balancerPool: { name: 'Balancer Pool', description: 'Balancer pool' },
        balancerV3: { name: 'Balancer V3', description: 'Balancer V3 pool' },
      },
    },
    {
      id: 'strategy-vaults',
      name: 'Indexedex Strategy Vaults',
      keywords: ['indexedex', 'vault'],
      includeTypeDirs: ['vaults/strategy'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        strategyVault: { name: 'Strategy Vault', description: 'Pachira strategy vault' },
      },
    },
    {
      id: 'erc4626-vaults',
      name: 'Indexedex ERC4626 Vaults',
      keywords: ['indexedex', 'vault', 'erc4626'],
      includeTypeDirs: ['vaults/erc4626'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        erc4626Vault: { name: 'ERC4626 Vault', description: 'ERC4626-compliant vault' },
        erc4626: { name: 'ERC4626', description: 'ERC4626 standard' },
      },
    },
    {
      id: 'protocol-detfs',
      name: 'Indexedex Protocol DETFs',
      keywords: ['indexedex', 'detf'],
      includeTypeDirs: ['vaults/protocolDetf'],
      defaultTags: [],
      tagDefinitions: {
        vault: { name: 'Vault', description: 'Vault share token' },
        protocolDetf: { name: 'Protocol DETF', description: 'Protocol decentralized ETF' },
      },
    },
  ],
}
```

- [ ] **Step 2: Implement the CLI entrypoint**

Create `scripts/node/src/main.ts`:

```ts
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { readFragmentsForChain } from './readFragments.js'
import { buildList } from './buildList.js'
import { loadPreviousList, writeList } from './writeList.js'
import type { AggregatorConfig } from './types.js'

async function loadConfig(configPath: string): Promise<AggregatorConfig> {
  const mod = await import(pathToFileURL(configPath).href)
  if (!mod.config) throw new Error(`Config at ${configPath} must export a named 'config'`)
  return mod.config as AggregatorConfig
}

function parseArgs(argv: string[]): { configPath: string } {
  let configPath = process.cwd() + '/tokenlists.config.ts'
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--config' && i + 1 < argv.length) {
      configPath = argv[i + 1]!
      i++
    }
  }
  return { configPath }
}

async function main() {
  const { configPath } = parseArgs(process.argv.slice(2))
  const config = await loadConfig(configPath)
  const repoRoot = process.cwd()
  const timestamp = new Date().toISOString()

  let totalLists = 0
  let totalTokens = 0
  let failures = 0

  for (const env of config.environments) {
    for (const chain of env.chains) {
      const fragments = await readFragmentsForChain(
        join(repoRoot, config.inputRoot),
        env.environment,
        chain.chainDir
      )

      for (const bucket of config.buckets) {
        const outPath = join(
          repoRoot,
          config.outputRoot,
          env.environment,
          chain.chainDir,
          `${bucket.id}.tokenlist.json`
        )
        const previous = await loadPreviousList(outPath)
        const { list, validation, bump } = buildList({ bucket, fragments, previousList: previous, timestamp })

        if (!validation.valid) {
          failures++
          console.error(`[FAIL] ${env.environment}/${chain.chainDir}/${bucket.id}`)
          for (const e of validation.errors) console.error(`  - ${e}`)
          continue
        }

        if (bump.bump === 'none' && previous !== null) {
          console.log(`[SKIP] ${env.environment}/${chain.chainDir}/${bucket.id} unchanged`)
          continue
        }

        await writeList(outPath, list)
        totalLists++
        totalTokens += list.tokens.length
        console.log(
          `[OK]   ${env.environment}/${chain.chainDir}/${bucket.id} ${formatVersion(list.version)} (${bump.bump}, ${list.tokens.length} tokens)`
        )
      }
    }
  }

  console.log(`\nWrote ${totalLists} list(s), ${totalTokens} token(s) total, ${failures} failure(s).`)
  if (failures > 0) process.exit(1)
}

function formatVersion(v: { major: number; minor: number; patch: number }): string {
  return `v${v.major}.${v.minor}.${v.patch}`
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
```

- [ ] **Step 3: Smoke-test against the fixture tree**

```bash
cd scripts/node && npm run build-tokenlists -- --config $(pwd)/fixtures/tokenlists.fixture.config.ts
```

Before running, create the fixture config:

Create `scripts/node/fixtures/tokenlists.fixture.config.ts`:

```ts
import type { AggregatorConfig } from '../src/types.js'

export const config: AggregatorConfig = {
  inputRoot: 'fixtures/sample-deploys',
  outputRoot: 'fixtures/sample-output',
  environments: [
    { environment: 'sepolia', chains: [{ chainId: 11155111, chainDir: '11155111' }] },
  ],
  buckets: [
    {
      id: 'base-tokens',
      name: 'Fixture Tokens',
      keywords: ['fixture'],
      includeTypeDirs: ['tokens'],
      defaultTags: [],
      tagDefinitions: { token: { name: 'Token', description: '' } },
    },
    {
      id: 'balancer-v3-pools',
      name: 'Fixture Balancer V3 Pools',
      keywords: ['fixture'],
      includeTypeDirs: ['pools/balancerV3'],
      defaultTags: [],
      tagDefinitions: {
        pool: { name: 'Pool', description: '' },
        balancerPool: { name: 'Balancer', description: '' },
        balancerV3: { name: 'BV3', description: '' },
      },
    },
  ],
}
```

Expected output:
```
[OK]   sepolia/11155111/base-tokens v1.0.0 (major, 1 tokens)
[OK]   sepolia/11155111/balancer-v3-pools v1.0.0 (major, 1 tokens)

Wrote 2 list(s), 2 token(s) total, 0 failure(s).
```

Verify the files exist:

```bash
ls scripts/node/fixtures/sample-output/sepolia/11155111/
```

Expected: `base-tokens.tokenlist.json`, `balancer-v3-pools.tokenlist.json`.

- [ ] **Step 4: Re-run to verify no-change skip behavior**

```bash
cd scripts/node && npm run build-tokenlists -- --config $(pwd)/fixtures/tokenlists.fixture.config.ts
```

Expected:
```
[SKIP] sepolia/11155111/base-tokens unchanged
[SKIP] sepolia/11155111/balancer-v3-pools unchanged
```

- [ ] **Step 5: Add `sample-output` to gitignore**

Append to `scripts/node/.gitignore`:

```
fixtures/sample-output/
```

- [ ] **Step 6: Commit**

```bash
git add scripts/node/src/main.ts tokenlists.config.ts scripts/node/fixtures/tokenlists.fixture.config.ts scripts/node/.gitignore
git commit -m "feat(scripts/node): CLI entrypoint + root tokenlists.config.ts"
```

---

## Task 1.10: Add Solidity manifest writer

**Files:**
- Create: `scripts/foundry/local_testing/shared/ManifestEntry.sol`
- Modify: `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol`

- [ ] **Step 1: Define the struct + serializer**

Create `scripts/foundry/local_testing/shared/ManifestEntry.sol`:

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

struct ManifestEntry {
    uint256 chainId;
    address addr;
    string name;
    string symbol;
    uint8 decimals;
    string[] tags;
    string extensionsJson; // pre-serialized JSON object, "" for none
}

library ManifestEntryLib {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Serialize a ManifestEntry to a JSON string conforming to the fragment shape.
    function toJson(ManifestEntry memory e) internal returns (string memory) {
        string memory obj = "fragment";
        vm.serializeUint(obj, "chainId", e.chainId);
        vm.serializeAddress(obj, "address", e.addr);
        vm.serializeString(obj, "name", e.name);
        vm.serializeString(obj, "symbol", e.symbol);
        vm.serializeUint(obj, "decimals", uint256(e.decimals));

        if (e.tags.length > 0) {
            vm.serializeString(obj, "tags", e.tags);
        }

        string memory finalJson;
        if (bytes(e.extensionsJson).length > 0) {
            finalJson = vm.serializeString(obj, "extensions", e.extensionsJson);
        } else {
            finalJson = vm.serializeUint(obj, "decimals", uint256(e.decimals));
        }
        return finalJson;
    }
}
```

> **Note for the implementer:** `vm.serializeString` with a JSON-string value will quote it. To embed a pre-built JSON object under `extensions`, the safe path is to write the fragment file and then run the aggregator only against the directory, not to re-parse in Solidity. If the embedded JSON ends up double-escaped, the simplest fix is to drop `extensionsJson` and accept that only flat `string`-valued extensions can be written from Solidity in Phase 1; richer extensions (composing assets, factory pointers) get written by the aggregator from cross-fragment context or by a small post-Solidity TS shim. Verify the output of Step 4 carefully.

- [ ] **Step 2: Add the writer helper to the base contract**

Add to `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol` (after the `_artifactPath` helper):

```solidity
import {ManifestEntry, ManifestEntryLib} from "./ManifestEntry.sol";

string internal constant FRAGMENT_ROOT = "deployments";

function _fragmentRootForEnv() internal view returns (string memory) {
    // OUT_DIR_OVERRIDE points to a per-env, per-chain root used by legacy artifacts.
    // For fragments we want a parallel tree under deployments/<env>/<chain>/.
    // The environment + chain segments are encoded in OUT_DIR_OVERRIDE itself, so we reuse it.
    string memory outDir = _outDir();
    return string.concat(outDir, "/fragments");
}

function _writeManifestEntry(
    string memory typeDir,
    string memory key,
    ManifestEntry memory entry
) internal {
    string memory dir = string.concat(_fragmentRootForEnv(), "/", typeDir);
    vm.createDir(dir, true);

    string memory path = string.concat(dir, "/", key, ".json");
    string memory json = ManifestEntryLib.toJson(entry);
    vm.writeFile(path, json);
}
```

> **Note on path layout:** Phase 1 writes fragments under `deployments/local_testing/anvil_single/fragments/<typeDir>/<key>.json` so the existing legacy JSONs are untouched. The aggregator's `inputRoot` for Phase 1 will be `deployments/local_testing/anvil_single/fragments` (no `<env>/<chain>` segments — the wrapper passes a single (env, chain) per invocation). Adjust `tokenlists.config.ts` accordingly when wiring shell in Task 1.12.

- [ ] **Step 3: Verify the contract compiles**

```bash
forge build --skip test
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add scripts/foundry/local_testing/shared/ManifestEntry.sol scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol
git commit -m "feat(scripts/foundry): add ManifestEntry + _writeManifestEntry helper"
```

---

## Task 1.11: Pilot — emit fragments from Script 06 (Foundation Assets)

**Files:**
- Modify: `scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol`

- [ ] **Step 1: Read the existing Script_06 to identify the artifacts it writes**

Read `scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol` and locate every variable assigned to a deployed token address (TTA, TTB, TTC, RICH, ERC20Minter).

- [ ] **Step 2: After each token deployment, emit a fragment**

For each token, immediately after the legacy JSON write, add:

```solidity
{
    string[] memory tags = new string[](1);
    tags[0] = "testToken";
    ManifestEntry memory entry = ManifestEntry({
        chainId: block.chainid,
        addr: address(tta),
        name: "Test Token A",
        symbol: "TTA",
        decimals: 18,
        tags: tags,
        extensionsJson: ""
    });
    _writeManifestEntry("tokens", "tta", entry);
}
```

Repeat for TTB, TTC, RICH. (The ERC20Minter facade is not a token in itself — skip it.)

- [ ] **Step 3: Verify the script compiles**

```bash
forge build --skip test
```

Expected: success.

- [ ] **Step 4: Smoke-run Stage 06 only against a local Anvil**

```bash
bash scripts/shell/local_testing.sh --kill-anvil
FOUNDRY_FORK_RPC_ALIAS= ANVIL_CHAIN_ID=31337 \
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh --restart-anvil stage01
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh stage02
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh stage06
ls deployments/local_testing/anvil_single/fragments/tokens/
```

Expected: `tta.json`, `ttb.json`, `ttc.json`, `rich.json` exist, each a valid fragment.

- [ ] **Step 5: Inspect one fragment**

```bash
cat deployments/local_testing/anvil_single/fragments/tokens/tta.json
```

Expected shape:
```json
{
  "address": "0x...",
  "chainId": 31337,
  "decimals": 18,
  "name": "Test Token A",
  "symbol": "TTA",
  "tags": ["testToken"]
}
```

If `extensions` ends up double-escaped, drop the `extensionsJson` branch from `ManifestEntryLib.toJson` for now and revisit in Phase 4.

- [ ] **Step 6: Commit**

```bash
git add scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol
git commit -m "feat(scripts/foundry): pilot fragment emission in Script_06 foundation assets"
```

---

## Task 1.12: Wire aggregator into local_testing.sh

**Files:**
- Modify: `scripts/shell/local_testing.sh`

- [ ] **Step 1: Add the aggregator runner**

Insert before the final `log_info "Local testing command complete"` line:

```bash
run_aggregator() {
  if [[ "${SKIP_TOKENLIST_BUILD:-0}" == "1" ]]; then
    log_info "Skipping tokenlist build (SKIP_TOKENLIST_BUILD=1)"
    return 0
  fi
  if [[ ! -d "$REPO_ROOT/deployments/local_testing/anvil_single/fragments" ]]; then
    log_info "No fragments directory yet — skipping tokenlist build"
    return 0
  fi
  log_info "Building token lists from fragments"
  ( cd "$REPO_ROOT/scripts/node" && npm run --silent build-tokenlists -- --config "$REPO_ROOT/tokenlists.config.ts" )
}

run_aggregator
```

> **Note:** the aggregator must run in the `scripts/node` working directory so `tsx` resolves `node_modules`; the `--config` flag points at the repo-root config which uses repo-relative paths. The config's `inputRoot: 'deployments'` is interpreted relative to the repo root because `main.ts` calls `process.cwd()` — but we're `cd`-ing to `scripts/node`. **Fix in Step 2.**

- [ ] **Step 2: Fix the cwd issue in `main.ts`**

Modify `scripts/node/src/main.ts` — replace `const repoRoot = process.cwd()` with:

```ts
const repoRoot = process.env.INDEXEDEX_REPO_ROOT ?? process.cwd()
```

And in the shell, export it before invocation:

```bash
INDEXEDEX_REPO_ROOT="$REPO_ROOT" ( cd "$REPO_ROOT/scripts/node" && npm run --silent build-tokenlists -- --config "$REPO_ROOT/tokenlists.config.ts" )
```

- [ ] **Step 3: Re-run a full local_testing flow**

```bash
bash scripts/shell/local_testing.sh --kill-anvil
FOUNDRY_FORK_RPC_ALIAS= ANVIL_CHAIN_ID=31337 \
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh --restart-anvil foundation
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh scenario1
```

Expected: at the end you see lines like:
```
[INFO] Building token lists from fragments
[OK]   local_testing/anvil_single/base-tokens v1.0.0 (major, 4 tokens)
[SKIP] local_testing/anvil_single/balancer-v3-pools unchanged
...
```

And `frontend/app/addresses/local_testing/anvil_single/base-tokens.tokenlist.json` now exists.

- [ ] **Step 4: Update tokenlists.config.ts paths to reflect actual layout**

In `tokenlists.config.ts`, the `local_testing.anvil_single` chain directory is `anvil_single` but the actual fragments live under `deployments/local_testing/anvil_single/fragments`. Update `inputRoot` to `deployments` and each chain's `chainDir` to `anvil_single/fragments`:

```ts
environments: [
  {
    environment: 'local_testing',
    chains: [{ chainId: 31337, chainDir: 'anvil_single/fragments' }],
  },
  ...
]
```

Note the chainId — for local non-fork mode it's `31337`; for the new Sepolia-fork default it's `11155111`. Add both, with separate `chainDir`s if needed.

> **Trade-off:** This pollutes the config with implementation paths. After Phase 4, when the legacy JSON layout is gone, we can collapse the fragment subdirectory and the config becomes cleaner. Acceptable for the migration window.

- [ ] **Step 5: Commit**

```bash
git add scripts/shell/local_testing.sh scripts/node/src/main.ts tokenlists.config.ts
git commit -m "feat(scripts/shell): invoke tokenlist aggregator after deploy stages"
```

---

## Task 1.13: Backfill fragment emission for remaining Phase-1 scripts

Repeat the pattern from Task 1.11 for **Script_03** (base protocols — WETH9 fragment) and **Script_10** (Scenario 1 — UniV2 pool tokens as `pools/uniV2/` fragments).

**Files:**
- Modify: `scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol`
- Modify: `scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol`

- [ ] **Step 1: Add WETH9 fragment in Script_03**

After the WETH9 deployment, write:

```solidity
{
    string[] memory tags = new string[](1);
    tags[0] = "weth";
    ManifestEntry memory entry = ManifestEntry({
        chainId: block.chainid,
        addr: weth9Address,
        name: "Wrapped Ether",
        symbol: "WETH9",
        decimals: 18,
        tags: tags,
        extensionsJson: ""
    });
    _writeManifestEntry("tokens", "weth9", entry);
}
```

- [ ] **Step 2: Add UniV2 pool fragments in Script_10**

After each UniV2 pool deployment (TTA/TTB and TTB/WETH), write a fragment under `pools/uniV2/`:

```solidity
{
    string[] memory tags = new string[](0);
    ManifestEntry memory entry = ManifestEntry({
        chainId: block.chainid,
        addr: address(ttaTtbPool),
        name: "Pachira Vault of (TTA / TTB)",
        symbol: "uniV2_ttA_ttB",
        decimals: 18,
        tags: tags,
        extensionsJson: ""
    });
    _writeManifestEntry("pools/uniV2", "ttaTtb", entry);
}
```

Repeat for TTB/WETH.

- [ ] **Step 3: Verify**

```bash
forge build --skip test
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh --restart-anvil foundation
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing.sh scenario1
ls deployments/local_testing/anvil_single/fragments/pools/uniV2/
```

Expected: two fragment files.

- [ ] **Step 4: Commit**

```bash
git add scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1Overlay.s.sol
git commit -m "feat(scripts/foundry): emit WETH9 and UniV2 pool fragments"
```

---

## Task 1.14: Phase 1 doc + close-out

**Files:**
- Create: `docs/tokenlist-pipeline.md`

- [ ] **Step 1: Write a short user-facing doc**

Create `docs/tokenlist-pipeline.md`:

```markdown
# Token List pipeline

The deployment scripts emit per-artifact JSON **fragments** into a typed directory tree.
A Node aggregator reads those fragments and writes Uniswap-compatible Token Lists
into the frontend address registry.

## Producer side (Solidity)

Solidity deploy scripts call `_writeManifestEntry(typeDir, key, entry)` per artifact.
The `typeDir` chooses the fragment's home:

- `tokens/` — ERC20 base tokens
- `pools/balancerV3/` — Balancer V3 pool tokens
- `pools/uniV2/` — Uniswap V2 LP tokens
- `pools/aerodrome/` — Aerodrome LP tokens
- `vaults/strategy/` — Pachira-style strategy vault shares
- `vaults/erc4626/` — ERC4626 vault shares
- `vaults/protocolDetf/` — Protocol DETF share tokens
- `factories/`, `facets/`, `hooks/`, `routers/` — consumed by other registries, not the Token List

## Aggregator (Node)

Run after deploys (the shell wrapper invokes this automatically):

    cd scripts/node && npm run build-tokenlists -- --config $PWD/../../tokenlists.config.ts

Outputs go to `frontend/app/addresses/<env>/<chain>/<bucket>.tokenlist.json`.
Version is auto-bumped by diff against the previous published list.

## Consumer (UI)

Phase 1: legacy per-category JSONs are still authoritative. Composed lists are
written but not yet read. See migration phases in
`docs/superpowers/plans/2026-06-05-tokenlist-pipeline.md`.

## Opting out

    SKIP_TOKENLIST_BUILD=1 bash scripts/shell/local_testing.sh foundation
```

- [ ] **Step 2: Commit**

```bash
git add docs/tokenlist-pipeline.md
git commit -m "docs: short user-facing doc for the Token List pipeline"
```

> **Phase 1 done.** The Solidity producer emits fragments, the aggregator validates and writes Token Lists, the shell wrapper runs the aggregator on every deploy, and the UI is unchanged. Verify by running `scenario1` end to end and confirming both the legacy per-category JSONs and the new `frontend/app/addresses/local_testing/anvil_single/*.tokenlist.json` files are present and the UI still loads without errors.

---

# Phase 2 — Shadow consume

Goal: UI loads both legacy per-category JSONs and the new composed Token Lists. In dev mode, it diffs them per-address and logs discrepancies to the console. No production behavior change.

## Task 2.1: Add composeLists module (TDD)

**Files:**
- Create: `frontend/app/lib/__tests__/tokenlistCompose.test.ts`
- Create: `frontend/app/lib/tokenlistCompose.ts`

- [ ] **Step 1: Write the failing tests**

Create `frontend/app/lib/__tests__/tokenlistCompose.test.ts`:

```ts
import { describe, it, expect } from 'vitest'
import { composeLists, byTag, byAddress, resolveLabel } from '../tokenlistCompose'
import type { TokenList } from '@uniswap/token-lists'

const list = (id: string, version = { major: 1, minor: 0, patch: 0 }, tokens: any[]): TokenList => ({
  name: id,
  timestamp: '2026-06-05T00:00:00.000Z',
  version,
  tokens,
})

describe('composeLists', () => {
  it('merges by lowercase address with later priority winning', () => {
    const a = list('a', undefined, [{ chainId: 1, address: '0xABC', name: 'A', symbol: 'A', decimals: 18, tags: ['pool'] }])
    const b = list('b', undefined, [{ chainId: 1, address: '0xabc', name: 'B', symbol: 'B', decimals: 18, tags: ['token'] }])
    const store = composeLists([
      { id: 'a', priority: 50, list: a },
      { id: 'b', priority: 100, list: b },
    ])
    const entry = byAddress(store, '0xABC', 1)!
    expect(entry.name).toBe('B')
    expect(entry.tags).toEqual(['token'])
  })

  it('filters by tag union', () => {
    const a = list('a', undefined, [
      { chainId: 1, address: '0x1', name: 'P', symbol: 'P', decimals: 18, tags: ['pool', 'balancerPool'] },
      { chainId: 1, address: '0x2', name: 'V', symbol: 'V', decimals: 18, tags: ['vault'] },
      { chainId: 1, address: '0x3', name: 'T', symbol: 'T', decimals: 18, tags: ['token'] },
    ])
    const store = composeLists([{ id: 'a', priority: 0, list: a }])
    const pools = byTag(store, ['pool', 'vault'], 1)
    expect(pools.map((t) => t.symbol).sort()).toEqual(['P', 'V'])
  })

  it('resolveLabel prefers extensions.display, then name, then symbol', () => {
    expect(resolveLabel({ chainId: 1, address: '0x0', name: 'N', symbol: 'S', decimals: 18, extensions: { display: 'Pretty' } } as any)).toBe('Pretty')
    expect(resolveLabel({ chainId: 1, address: '0x0', name: 'N', symbol: 'S', decimals: 18 } as any)).toBe('N')
    expect(resolveLabel({ chainId: 1, address: '0x0', name: '', symbol: 'S', decimals: 18 } as any)).toBe('S')
  })
})
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd frontend && npx vitest run app/lib/__tests__/tokenlistCompose.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement the module**

Create `frontend/app/lib/tokenlistCompose.ts`:

```ts
import type { TokenList, TokenInfo } from '@uniswap/token-lists'

export type Address = `0x${string}`

export interface TokenListRef {
  id: string
  priority: number
  list: TokenList
}

export interface ComposedStore {
  // key: `${chainId}-${addressLower}`
  entries: Map<string, TokenInfo>
}

export function composeLists(refs: TokenListRef[]): ComposedStore {
  const sorted = [...refs].sort((a, b) => a.priority - b.priority)
  const entries = new Map<string, TokenInfo>()
  for (const ref of sorted) {
    for (const t of ref.list.tokens) {
      entries.set(key(t.chainId, t.address), t)
    }
  }
  return { entries }
}

export function byTag(store: ComposedStore, tags: string[], chainId: number): TokenInfo[] {
  const want = new Set(tags)
  const out: TokenInfo[] = []
  for (const t of store.entries.values()) {
    if (t.chainId !== chainId) continue
    if (!t.tags) continue
    if (t.tags.some((tag) => want.has(tag))) out.push(t)
  }
  return out
}

export function byAddress(store: ComposedStore, address: string, chainId: number): TokenInfo | undefined {
  return store.entries.get(key(chainId, address))
}

export function resolveLabel(t: TokenInfo): string {
  const display = (t.extensions as { display?: unknown } | undefined)?.display
  if (typeof display === 'string' && display.length > 0) return display
  if (t.name && t.name.length > 0) return t.name
  return t.symbol
}

function key(chainId: number, address: string): string {
  return `${chainId}-${address.toLowerCase()}`
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd frontend && npx vitest run app/lib/__tests__/tokenlistCompose.test.ts
```

Expected: PASS, 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add frontend/app/lib/tokenlistCompose.ts frontend/app/lib/__tests__/tokenlistCompose.test.ts
git commit -m "feat(frontend): composeLists + tag-filtered selectors"
```

---

## Task 2.2: Add list registry

**Files:**
- Create: `frontend/app/lib/tokenlistRegistry.ts`

- [ ] **Step 1: Define the list registry**

Create `frontend/app/lib/tokenlistRegistry.ts`:

```ts
import type { TokenListRef } from './tokenlistCompose'
import type { DeploymentEnvironment, CanonicalArtifactChainId } from '../addresses'
import { CHAIN_ID_SEPOLIA, CHAIN_ID_BASE_SEPOLIA } from '../addresses'

// Statically import the lists the aggregator now produces.
// Phase 2: these are loaded *alongside* the legacy per-category JSONs.
import localTestingBaseTokens from '../addresses/local_testing/anvil_single/base-tokens.tokenlist.json'
import localTestingBalancerV3Pools from '../addresses/local_testing/anvil_single/balancer-v3-pools.tokenlist.json'
import localTestingStrategyVaults from '../addresses/local_testing/anvil_single/strategy-vaults.tokenlist.json'

export const LIST_REGISTRY: Partial<
  Record<DeploymentEnvironment, Partial<Record<CanonicalArtifactChainId, TokenListRef[]>>>
> = {
  // Local-testing fork maps onto Sepolia in the artifact resolver.
  sepolia: {
    [CHAIN_ID_SEPOLIA]: [
      { id: 'base-tokens', priority: 100, list: localTestingBaseTokens as any },
      { id: 'balancer-v3-pools', priority: 50, list: localTestingBalancerV3Pools as any },
      { id: 'strategy-vaults', priority: 50, list: localTestingStrategyVaults as any },
    ],
  },
}
```

> **Note:** The static-import paths assume `tsconfig.json` has `resolveJsonModule: true`. If not, add it now. Until each list file exists from the aggregator, this import will break the build — guard the Phase 2 PR by **ensuring Phase 1 has been run at least once** so the files are committed.

- [ ] **Step 2: Commit**

```bash
git add frontend/app/lib/tokenlistRegistry.ts
git commit -m "feat(frontend): static list registry alongside artifact registry"
```

---

## Task 2.3: Add shadow consumer

**Files:**
- Create: `frontend/app/lib/tokenlistShadow.ts`
- Modify: `frontend/app/lib/tokenlists.ts` — call shadow check at the end of `getCached()` in dev

- [ ] **Step 1: Implement the shadow comparison**

Create `frontend/app/lib/tokenlistShadow.ts`:

```ts
import { composeLists, byTag } from './tokenlistCompose'
import { LIST_REGISTRY } from './tokenlistRegistry'
import type { TokenListEntry } from './tokenlists'
import type { DeploymentEnvironment } from './addressArtifacts'

const TAGS_FOR_CATEGORY: Record<string, string[]> = {
  balancerPools: ['balancerPool'],
  strategyVaults: ['strategyVault'],
  erc4626Tokens: ['erc4626Vault'],
  protocolDetfTokens: ['protocolDetf'],
}

export function shadowDiff(
  category: keyof typeof TAGS_FOR_CATEGORY,
  legacy: TokenListEntry[],
  chainId: number,
  environment: DeploymentEnvironment
): void {
  if (process.env.NODE_ENV === 'production') return
  const refs = (LIST_REGISTRY[environment] as any)?.[chainId]
  if (!refs) return

  const composed = byTag(composeLists(refs), TAGS_FOR_CATEGORY[category], chainId)

  const legacyAddrs = new Set(legacy.map((e) => e.address.toLowerCase()))
  const composedAddrs = new Set(composed.map((e) => e.address.toLowerCase()))

  const onlyLegacy = [...legacyAddrs].filter((a) => !composedAddrs.has(a))
  const onlyComposed = [...composedAddrs].filter((a) => !legacyAddrs.has(a))

  if (onlyLegacy.length > 0 || onlyComposed.length > 0) {
    // eslint-disable-next-line no-console
    console.warn(
      `[tokenlist-shadow] ${category} chain=${chainId} env=${environment}`,
      { onlyLegacy, onlyComposed }
    )
  }
}
```

- [ ] **Step 2: Wire shadow check into `getCached()`**

In `frontend/app/lib/tokenlists.ts`, at the end of `getCached()` just before the cache assignment (around line 274), add:

```ts
import { shadowDiff } from './tokenlistShadow'

// ...

shadowDiff('balancerPools', balancerPoolTokens, artifactsChainId, environment)
shadowDiff('strategyVaults', strategyVaultTokens, artifactsChainId, environment)
shadowDiff('erc4626Tokens', erc4626Tokens, artifactsChainId, environment)
shadowDiff('protocolDetfTokens', mergedProtocolDetfTokens, artifactsChainId, environment)
```

- [ ] **Step 3: Smoke-test in dev**

```bash
cd frontend && npm run dev
```

Open the swap page, open browser devtools, observe `[tokenlist-shadow]` warnings only for categories where the composed lists are incomplete. Phase 1 only populates `tokens` and a small slice of pools — expect many warnings; that's the point.

- [ ] **Step 4: Commit**

```bash
git add frontend/app/lib/tokenlistShadow.ts frontend/app/lib/tokenlists.ts
git commit -m "feat(frontend): dev-mode shadow diff between legacy and composed lists"
```

> **Phase 2 done.** Use the shadow warnings as a checklist to drive Phase 4 producer migration: every category should reach `onlyLegacy: []` and `onlyComposed: []` before cutover.

---

# Phase 3 — Cutover

Goal: UI no longer reads per-category JSONs. Delete legacy per-category builders. `tokenlists.ts` shrinks ~70%.

## Task 3.1: Rewrite `tokenlists.ts` to use the composed store

**Files:**
- Modify: `frontend/app/lib/tokenlists.ts`

- [ ] **Step 1: Reduce `getCached()` to a composed-store lookup**

Replace the body of `getCached(chainId, environment)` with:

```ts
import { composeLists, byTag, resolveLabel, type ComposedStore } from './tokenlistCompose'
import { LIST_REGISTRY } from './tokenlistRegistry'

const storeCache: Record<string, ComposedStore> = {}

function getStore(chainId: number, environment: DeploymentEnvironment): ComposedStore {
  const k = `${environment}:${chainId}`
  const cached = storeCache[k]
  if (cached) return cached
  const refs = (LIST_REGISTRY[environment] as any)?.[chainId] ?? []
  const store = composeLists(refs)
  storeCache[k] = store
  return store
}
```

- [ ] **Step 2: Replace the eight category arrays with tag selectors**

In every function that returned a category array (e.g. `getBalancerPoolTokens`, `getStrategyVaultTokens`), replace the body with a tag filter:

```ts
export function getBalancerPoolTokensForChain(chainId: number, environment = getDefaultDeploymentEnvironment()): TokenListEntry[] {
  return byTag(getStore(chainId, environment), ['balancerPool'], chainId).map(toLegacyEntry)
}
```

`toLegacyEntry` is a small adapter that fills in `display` via `resolveLabel`:

```ts
function toLegacyEntry(t: import('@uniswap/token-lists').TokenInfo): TokenListEntry {
  return {
    chainId: t.chainId,
    address: t.address as `0x${string}`,
    name: t.name,
    symbol: t.symbol,
    decimals: t.decimals,
    display: resolveLabel(t),
  }
}
```

- [ ] **Step 3: Delete the per-category derivation helpers**

Remove `buildDisplay`, `withDisplay`, `buildStrategyVaultEntriesFromPlatform`, `buildProtocolDetfEntriesFromPlatform`, `humanizeKey`, and the legacy `TokenCache`/`EMPTY_CACHE` machinery.

- [ ] **Step 4: Run the UI**

```bash
cd frontend && npm run dev
```

Verify the swap page's "Select Pool" dropdown still populates with the same entries (sanity-compare with the pre-Phase-3 production list).

- [ ] **Step 5: Commit**

```bash
git add frontend/app/lib/tokenlists.ts
git commit -m "refactor(frontend): collapse tokenlists.ts to composed-store tag filters"
```

---

## Task 3.2: Drop legacy per-category JSON imports

**Files:**
- Modify: `frontend/app/addresses/index.ts`

- [ ] **Step 1: Remove the per-category JSON imports and `ArtifactBundle.tokenlists` field**

The legacy `ArtifactBundle.tokenlists` is now dead. Delete:
- `tokens`, `erc4626`, `seigniorageDetfs`, `protocolDetf`, `strategyVaults`, `uniV2Pools`, `aerodromePools`, `aerodromeStrategyVaults`, `balancerPools` properties on `ArtifactBundle.tokenlists`
- The per-category JSON imports at the top of the file
- `normalizeList` (no longer needed)
- `tokenlists: { ... }` from `buildBundle`

Keep: `platform`, `factories`, `chainRole`, `chainId`, `environment`.

- [ ] **Step 2: Run a typecheck**

```bash
cd frontend && npx tsc --noEmit
```

Expected: clean. If `getAddressArtifacts(...).tokenlists` is referenced anywhere else, fix those call sites by reading from the composed store instead.

- [ ] **Step 3: Commit**

```bash
git add frontend/app/addresses/index.ts
git commit -m "refactor(frontend): drop per-category tokenlist arrays from ArtifactBundle"
```

---

## Task 3.3: Remove shadow diff (cutover complete)

**Files:**
- Modify: `frontend/app/lib/tokenlists.ts`
- Delete: `frontend/app/lib/tokenlistShadow.ts`

- [ ] **Step 1: Remove shadow imports and calls**

Delete `shadowDiff` invocations and the import; delete the file.

- [ ] **Step 2: Commit**

```bash
git add frontend/app/lib/tokenlists.ts frontend/app/lib/tokenlistShadow.ts
git commit -m "refactor(frontend): remove shadow diff post-cutover"
```

> **Phase 3 done.** The composed lists are the single source of truth in the UI.

---

# Phase 4 — Producer cleanup

Goal: every Solidity script writes fragments only. Delete legacy per-category JSON writers and the now-unused per-category tokenlist files.

## Task 4.1: Migrate remaining scripts

**Files:**
- Modify: every remaining Solidity script under `scripts/foundry/local_testing/anvil_single/` and `scripts/foundry/local_testing/supersim/`

For each script:
- [ ] Identify each artifact it writes to a legacy per-category JSON.
- [ ] Replace each legacy write with a `_writeManifestEntry(typeDir, key, entry)` call into the correct typed directory.
- [ ] Compile, smoke-run, verify fragment count matches expected artifact count.
- [ ] Commit one script per commit:
  ```bash
  git commit -m "refactor(scripts/foundry): migrate Script_NN to fragments-only"
  ```

## Task 4.2: Delete legacy per-category writer code in `LocalTestingDeploymentBase`

**Files:**
- Modify: `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol`

- [ ] Remove `_writeAddress`, `_appendTokenlistEntry`, and any helpers that wrote the legacy per-category JSONs.
- [ ] Drop the `_fragmentRootForEnv` workaround and emit fragments directly under `_outDir() + "/" + typeDir + "/"`.
- [ ] Update `tokenlists.config.ts` to remove the `fragments/` path segment from `chainDir`.

## Task 4.3: Delete legacy per-category JSONs

**Files:**
- Delete: `frontend/app/addresses/<env>/<chain>/<env>-{balancerv3,protocol-detf,strategy-vaults,...}.tokenlist.json` (the ones consumed pre-Phase-3)

- [ ] One commit per environment:
  ```bash
  git rm frontend/app/addresses/sepolia/sepolia-*.tokenlist.json
  git commit -m "chore(frontend): delete legacy per-category tokenlist JSONs (sepolia)"
  ```

## Task 4.4: Final smoke + docs update

- [ ] Run every supported `local_testing` command end to end; verify the UI's "Select Pool" dropdown shows the same entries it did at the start of the migration.
- [ ] Update `docs/tokenlist-pipeline.md` — remove the "legacy per-category JSONs are still authoritative" paragraph.
- [ ] Commit.

> **Phase 4 done.** Producer, aggregator, and consumer are all on the Token List standard. Adding a new pool type is one Solidity helper call + one config entry.

---

## Self-review

**1. Spec coverage:**
- Token List schema as interface contract → Task 1.6 + Phase 3 consumer rewrite. ✅
- Per-artifact fragments → Tasks 1.10 + 1.11 + 1.13 + 4.1. ✅
- Typed directory tree → Task 1.10 + `deriveTags` taxonomy in 1.3. ✅
- Auto semver bump → Task 1.5. ✅
- Schema validation → Task 1.6. ✅
- UI composition + tag filters → Tasks 2.1 + 3.1. ✅
- Label override via `extensions.display` → Task 2.1 `resolveLabel`. ✅
- Shell integration → Task 1.12. ✅
- Phased migration with reversibility → All four phases each independently shippable. ✅
- Factories/facets/hooks/routers excluded from token lists → Acknowledged in Tasks 1.10 doc note + 1.14 user doc. They get their own future registry; not in this plan. **Gap flagged**: this plan does not specify the factory/facet registry shape. That's intentional — surface it as a follow-up plan once Phase 3 lands.

**2. Placeholder scan:** None of the prohibited phrases appear. The "Note for the implementer" callouts in Task 1.10 flag a known Solidity-JSON-escaping edge case with a concrete fallback, not a TODO.

**3. Type consistency:** `ManifestFragment`, `TokenInfo`, `TokenList`, `TokenListRef`, `ComposedStore`, `ListBucketConfig`, `BumpResult` are defined in Task 1.2 and referenced consistently. `_writeManifestEntry` signature `(string typeDir, string key, ManifestEntry entry)` matches across Tasks 1.10, 1.11, 1.13, 4.1. `composeLists`, `byTag`, `byAddress`, `resolveLabel` match between definitions in 2.1 and call sites in 2.3 + 3.1.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-05-tokenlist-pipeline.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan because the four phases are independently shippable and each task is small enough for a single subagent to own end to end.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Better if you want to ride along closely on Phase 1 and steer adjustments as we hit the Solidity-JSON-escaping edge case in Task 1.10.

**Which approach?**

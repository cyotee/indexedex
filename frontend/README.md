# IndexedEx frontend

The only Next app is **DTF** (`frontend/apps/dtf`). Do not recreate `apps/indexedex` or `apps/pachira`.

npm workspaces under `frontend/`:

| Path | Package | Role |
|------|---------|------|
| `apps/dtf` | `@indexedex/app-dtf` | Down To Finance: https://downto.finance (app: https://app.downto.finance, project `dtfinance`) |
| `packages/protocol` | `@indexedex/protocol` | Shared addresses, ABIs, chains, registry, swap helpers |

## Local development

```bash
cd frontend
npm install
npm run dev          # DTF — http://localhost:3002
npm run build
npm test             # DTF unit tests
npm run test:e2e     # Playwright — DTF
```

App details: [apps/dtf/README.md](./apps/dtf/README.md). Product roadmap: [ROADMAP.md](./ROADMAP.md).

**Vercel Root Directory:** project `dtfinance` → `frontend/apps/dtf`.

Ignore build: `bash ../../scripts/vercel-ignore-build.sh dtf` (skips when neither the DTF app nor `packages/protocol` / workspace root changed).

---


## How Token Lists reach the UI

Token addresses come from chain-keyed Token List files under
`packages/protocol/src/addresses/chain/<chainId>/`. Two pieces of plumbing load them:

- `packages/protocol/src/tokenlistRegistry.ts` re-exports `GENERATED_LIST_REGISTRY` from
  `tokenlistRegistry.generated.ts`. That generated file is produced by the
  Node aggregator (`scripts/node/build-tokenlists`) by scanning every
  `chain/<id>/<bucket>.tokenlist.json` it finds.
- `packages/protocol/src/addressArtifacts.ts` re-exports `GENERATED_CHAIN_PLATFORM_OVERRIDES`
  from `chainPlatformOverrides.generated.ts`, which the same aggregator emits
  by scanning every `chain/<id>/platform.json`.

So **dropping new tokenlist files into `packages/protocol/src/addresses/chain/<id>/` and
re-running the aggregator is enough to expose them to the registry**. The two
generated `.ts` files are checked in.

What the registry exposes is not the same as what the menus render — see the
two sections below for the manual edits each path still requires.

---

## Naming conventions

Follow these so the auto-discovery generator picks files up without ambiguity.

| Location                                              | Convention                                                                 |
|-------------------------------------------------------|----------------------------------------------------------------------------|
| `packages/protocol/src/addresses/chain/<chainId>/`                      | `<chainId>` is the numeric chain id only — no prefix, no separators.       |
| `packages/protocol/src/addresses/chain/<chainId>/<bucket-id>.tokenlist.json` | `<bucket-id>` is kebab-case, matches the `id` field of a bucket in `tokenlists.config.ts`. |
| `packages/protocol/src/addresses/chain/<chainId>/platform.json`         | Literal filename.                                                          |
| Bucket `id` (in `tokenlists.config.ts`)               | kebab-case (`base-tokens`, `balancer-v3-pools`, `aerodrome-pools`).        |
| Fragment `includeTypeDirs` (in `tokenlists.config.ts`)| `<category>/<camelCaseSubcategory>` (`pools/balancerV3`, `vaults/strategy`).|
| `packages/protocol/src/addresses/<environment>/` (env-keyed artifacts)  | snake_case environment name matching `DeploymentEnvironment`.              |

---

## Adding a new chain

The registry side is automatic. The wallet / app side still needs manual
wiring because each chain id is a typed value that flows through several
modules.

### 1. Get the tokenlist files into `packages/protocol/src/addresses/chain/<NEW_ID>/`

Either run the aggregator (`cd scripts/node && npm run build-tokenlists`) so
it emits the chain directory for you, or hand-drop `<bucket-id>.tokenlist.json`
files and a `platform.json` following the naming conventions above. The
aggregator-driven path is preferred because it also regenerates
`packages/protocol/src/tokenlistRegistry.generated.ts` and
`app/lib/chainPlatformOverrides.generated.ts` so the registry sees the chain.

### 2. Declare the chain in `packages/protocol/src/addresses/index.ts`

- Add a `CHAIN_ID_<NAME>` constant for the numeric id.
- Extend the `CanonicalArtifactChainId` union to include it.
- Add an entry to `ARTIFACT_REGISTRY` under each `DeploymentEnvironment` the
  chain belongs to (its env-keyed `ArtifactBundle`). The chain-keyed
  `platform.json` written in step 1 will override the `platform` field of this
  bundle at runtime, so the bundle's other fields (router, vault, etc.) are
  what matter here.

### 3. Allowlist the chain in `packages/protocol/src/networkSelection.tsx`

Add the new constant to the comparison in `isCanonicalArtifactChainId`. This
gates which chain ids the nav-bar selector and `localStorage` accept.

### 4. (Only if needed) Add a resolver case in `packages/protocol/src/addressArtifacts.ts`

`resolveArtifactsChainId` maps the wallet's reported chain id to a canonical
artifact chain id. The default cases handle Sepolia, Base Sepolia, Anvil
(`31337` and `1337` fall back to Sepolia by default), and Base (which maps to
Base Sepolia under `supersim_sepolia`). Only edit this if your new chain
needs the same kind of indirection — e.g. a local fork that should be served
artifacts from a different canonical chain id.

### 5. Wire the chain into the Wagmi config in `apps/dtf/app/providers.tsx`

- Import the chain from `wagmi/chains` (or `defineChain` if it's not built-in).
- Add it to the `chains: [...]` array passed to `createConfig`.
- Add a `transports` entry — pick the same `useLocalRpc` switching pattern
  the existing chains use if the chain has a local-Anvil equivalent.
- If the chain needs a custom RPC env var (e.g.
  `NEXT_PUBLIC_<CHAIN>_RPC_URL`), declare it at the top of the file next to
  the existing ones.

### 6. Re-run the aggregator if step 1 was manual

`cd scripts/node && npm run build-tokenlists` regenerates the two
`.generated.ts` files. Skip this if the aggregator was already run in step 1.

After these edits, type-check with `npm run typecheck` from `frontend/`.
Adding the new id to the union but missing it in `ARTIFACT_REGISTRY` (or
vice versa) is a type error, which is the point of routing every chain id
through `CanonicalArtifactChainId`.

---

## Adding a new class of token list (new bucket / new file)

A "class" here means a new `<bucket-id>.tokenlist.json` filename — a new
grouping of tokens, distinct from any bucket currently being emitted. Pick a
kebab-case `<bucket-id>` that isn't already used by a bucket in
`tokenlists.config.ts`.

### 1. Pick a `bucket-id` and a `typeDir`

- `bucket-id` is the kebab-case filename stem the aggregator writes
  (e.g. `my-family-vaults` → `my-family-vaults.tokenlist.json`).
- `typeDir` is the fragments path the aggregator reads from
  (e.g. `vaults/myFamily`). The convention is
  `<category>/<camelCaseSubcategory>`.

Both must be unused. Skim `tokenlists.config.ts` for existing bucket ids and
`includeTypeDirs`, and check `packages/protocol/src/addresses/chain/*/` for existing
`*.tokenlist.json` filenames.

### 2. Register the bucket in `tokenlists.config.ts`

Append to `buckets`:

```ts
{
  id: 'my-family-vaults',
  name: 'Indexedex MyFamily Vaults',
  keywords: ['indexedex', 'vault', 'myFamily'],
  includeTypeDirs: ['vaults/myFamily'],
  defaultTags: [],
  tagDefinitions: {
    vault: { name: 'Vault', description: 'Vault share token' },
    myFamily: { name: 'MyFamily Vault', description: '...' },
  },
},
```

### 3. Emit fragments from the relevant deployment script

The deploy-side details (Solidity helpers, fragment shape, idempotency) live
in `deployments/local_testing/README.md`. Each fragment must land under
`fragments/<typeDir>/<key>.json` and tag the entries with tag ids declared in
the bucket's `tagDefinitions`.

### 4. Run the aggregator

```bash
cd scripts/node && npm run build-tokenlists -- --config ../../tokenlists.config.ts
```

After this:

- `packages/protocol/src/addresses/chain/<chainId>/my-family-vaults.tokenlist.json` exists for
  every chain that emitted matching fragments.
- `packages/protocol/src/tokenlistRegistry.generated.ts` includes a static import of the
  new file for every chain that has one.
- `getListRefs(chainId)` (from `packages/protocol/src/tokenlistRegistry.ts`) now returns the
  new bucket — meaning anything that iterates `getListRefs` generically (e.g.
  `packages/protocol/src/tokenlists.ts` composition, `/token-info`'s balance grid) shows it
  with no further edits.

### 5. Wire the bucket into menu surfaces (`app/lib/menuConfig.ts`)

This is the step the auto-discovery layer does not cover. `MENU_CONFIG` in
`app/lib/menuConfig.ts` enumerates one entry per menu surface, and each entry
has a `fromLists` array binding bucket ids to a renderer `type`:

```ts
{ listId: 'my-family-vaults', type: 'vault' }
```

Allowed `type` values today are `'token' | 'vault' | 'lp' | 'balancer'` (see
the `OptionType` union at the top of the file). Add the entry to whichever
`MENU_CONFIG` surface(s) the new bucket should appear in:

| Menu surface                                | `MENU_CONFIG` key in `menuConfig.ts`     |
|---------------------------------------------|------------------------------------------|
| Select Pool dropdown (`/swap`, `/batch-swap`)| `'pool-select'`                          |
| Token In / Token Out (`/swap`, `/batch-swap`, `/detf`) | `'token-select'`                |
| Vault selector (`/vaults`)                  | `'vaults-page'`                          |
| DETF picker (`/detf`)                       | `'seigniorage-detfs-page'`               |
| Balance grid (`/token-info`)                | `'token-info'`                           |

Each existing surface has a header comment describing its spec — read it
before adding a bucket to make sure the new class fits the surface's intent
(e.g. `/swap` deliberately excludes ERC4626 vaults because they aren't valid
swap routes).

If the new class needs a `type` the UI doesn't have today (e.g. a renderer
or swap routing path that doesn't exist), this is no longer a tokenlist-only
change — you'll need to add the `type` value, the renderer/route handler,
and any swap-graph integration before menu wiring will do anything visible.

### 6. Type-check

```bash
cd frontend && npm run typecheck
```

---

## Quick decision guide

| Goal                                                                   | Files to touch                                                                                                                              |
|------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| Add more tokens to an existing bucket on an existing chain             | None in `frontend/`. Emit fragments from the deployment script and re-run the aggregator.                                                  |
| Add an existing bucket to a chain that didn't have it before           | None in `frontend/`. Emit fragments + re-run the aggregator.                                                                                |
| Add a brand-new chain id                                               | `addresses/index.ts`, `lib/networkSelection.tsx`, `providers.tsx`. Possibly `lib/addressArtifacts.ts` if the chain needs id-resolution.    |
| Add a brand-new bucket / `*.tokenlist.json` filename                   | `tokenlists.config.ts`, then `lib/menuConfig.ts` for each surface the bucket should appear in.                                              |
| Add a bucket whose tokens need a UI behavior that doesn't exist yet    | All of the above, plus new renderer/`type` plumbing in the relevant menu/page components.                                                  |

## Vercel (production)

One site: **DTF**.

| Setting | Value |
|--------|--------|
| Project | `dtfinance` |
| Public URL | https://downto.finance (app: https://app.downto.finance) |
| Git repo | `cyotee/indexedex` |
| Root Directory | `frontend/apps/dtf` |
| Framework | Next.js |
| Ignored Build Step | `bash ../../scripts/vercel-ignore-build.sh dtf` |

Config: `frontend/apps/dtf/vercel.json`. Details: [apps/dtf/README.md](./apps/dtf/README.md).

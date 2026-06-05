# Runbook — local deploys, Token List pipeline, UI dev server

End-to-end commands for running the staged local-testing deploy flow, the
Token List aggregator, and the UI dev server. Read
`scripts/foundry/TOKENLIST_PIPELINE_CONTEXT.md` first for the design context.

---

## One-time setup

### Toolchain

You need:

- Foundry (`forge`, `cast`, `anvil`) on PATH
- Node 20 or newer
- An `ALCHEMY_KEY` exported in your shell if you want the default Sepolia fork
  (the wrapper resolves the URL from `foundry.toml`'s `ethereum_sepolia_alchemy`
  alias). Skip if you'll run pure local without forking.

### Install Node deps for the aggregator (once)

```bash
cd scripts/node && npm install
```

### Install frontend deps (once)

```bash
cd frontend && npm install
```

### Standard deployer account

The wrapper uses an unlocked Anvil dev account. Account #0 from Foundry's default
mnemonic:

```
address     0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86
private key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Export it once per shell session:

```bash
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86
```

All commands below assume `DEV_ADDRESS` is set.

---

## Single-chain flows — `scripts/shell/local_testing.sh`

### What the wrapper does

1. Resolves a Sepolia Alchemy RPC from `foundry.toml` (default fork mode) or
   skips fork resolution if `FOUNDRY_FORK_RPC_ALIAS=` is empty.
2. Starts (or reuses) Anvil on `127.0.0.1:8545` with chain id `11155111`
   (Sepolia) by default. Override via env vars below.
3. Runs the requested stage(s) via `forge script --broadcast --slow --unlocked`.
4. After the last stage, invokes the Token List aggregator
   (`scripts/node/src/main.ts`) unless `SKIP_TOKENLIST_BUILD=1` is set.

### Foundation (Stages 01–03)

The cheapest reusable bring-up. Deploys Crane infrastructure, Indexedex core, and
local base protocols (WETH9, Permit2, Uniswap V2 core, Balancer V3 core).

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation
```

After this completes you'll see one fragment written by Stage 03 at
`deployments/local_testing/anvil_single/fragments/tokens/weth9.json`, and the
aggregator will refresh `frontend/app/addresses/local_testing/anvil_single/...`
Token Lists.

### Scenario 1 — Uniswap V2 pools

Deploys Stages 05 (foundation packages), 06 (foundation assets: TTA/TTB/TTC/RICH),
and 10 (UniV2 TTA/TTB and TTB/WETH pools + vaults). Foundation must already be
deployed.

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation
bash scripts/shell/local_testing.sh scenario1
```

Fragments produced:

```
tokens/                tta.json, ttb.json, ttc.json, rich.json, weth9.json
pools/uniV2/           uniV2AbPool.json, uniV2BWethPool.json
vaults/strategy/       uniV2AbVault.json, uniV2BWethVault.json
```

### Scenario 2 — Scenario 1 + Balancer pools

Deploys Stage 11 on top of Scenario 1: rate providers for the UniV2 vaults and
Balancer pools pairing TTB with the UniV2 vault tokens.

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation
bash scripts/shell/local_testing.sh scenario2
```

Note: Stage 11 has not yet been migrated to emit fragments. Its tokens will
appear in the legacy `11_scenario_2.json` artifact but not in the Token Lists
until the migration is done. See `TOKENLIST_PIPELINE_CONTEXT.md` "Phase 4 —
Producer cleanup".

### Scenario 3 — Single Vault DETF (RICH / WETH)

Deploys Stages 05, 06, and 12. Stage 12 brings up a custom Balancer router with
prepay hooks, a local `WeightedPool8020Factory`, the Single Vault DETF instance
for the RICH/WETH graph, the Protocol NFT Vault and RICHIR dependencies, and the
outer Balancer pool pairing WETH with the Single Vault DETF token.

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation
bash scripts/shell/local_testing.sh scenario3
```

Stage 12 has not yet been migrated to emit fragments either. Same note as above.

### Individual stages

Run a single stage at a time when iterating. Use `-vv` (or up to `-vvvvv`) for
verbose Foundry output.

```bash
bash scripts/shell/local_testing.sh stage01
bash scripts/shell/local_testing.sh stage02
bash scripts/shell/local_testing.sh stage03
bash scripts/shell/local_testing.sh stage05      # foundation packages
bash scripts/shell/local_testing.sh stage06      # foundation assets (test tokens + RICH)
bash scripts/shell/local_testing.sh stage10 -vv  # Scenario 1 overlay with verbose output
bash scripts/shell/local_testing.sh stage11      # Scenario 2 overlay
bash scripts/shell/local_testing.sh stage12      # Scenario 3 overlay
```

### Anvil lifecycle

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation   # kill existing Anvil first
bash scripts/shell/local_testing.sh --kill-anvil                 # stop wrapper-managed Anvil and exit
bash scripts/shell/local_testing.sh --dry-run foundation         # simulate without --broadcast
```

### Pure-local mode (no Sepolia fork)

The default forks Sepolia via the Alchemy alias. To run a completely isolated
local devnet with chain id `31337`:

```bash
FOUNDRY_FORK_RPC_ALIAS= ANVIL_CHAIN_ID=31337 \
  bash scripts/shell/local_testing.sh --restart-anvil foundation
```

### Useful env overrides

| Var | Default | Purpose |
|---|---|---|
| `RPC_URL` | `http://127.0.0.1:8545` | Anvil endpoint the wrapper talks to |
| `ANVIL_HOST` / `ANVIL_PORT` | `127.0.0.1` / `8545` | Where Anvil binds |
| `ANVIL_CHAIN_ID` | `11155111` | Chain id Anvil reports. Use `31337` for pure local. |
| `FOUNDRY_FORK_RPC_ALIAS` | `ethereum_sepolia_alchemy` | Foundry rpc_endpoints alias for fork URL. Empty disables forking. |
| `ANVIL_FORK_URL` | unset (alias-resolved) | Explicit fork URL. Overrides the alias. |
| `ANVIL_FORK_BLOCK_NUMBER` | unset | Pin a fork block for determinism. |
| `LOCAL_TESTING_DEPLOYER_ADDRESS` | `$SENDER` | Override deployer address recorded in artifacts. |
| `LOCAL_TESTING_OWNER` | `$DEPLOYER_ADDRESS` | Override ownership initialization. |
| `OUT_DIR_OVERRIDE` | `deployments/local_testing/anvil_single` | Where artifacts are written. |
| `NETWORK_PROFILE` | `local_testing` | Passed to Solidity scripts via env. |
| `SKIP_TOKENLIST_BUILD` | `0` | Set to `1` to skip the post-deploy aggregator. |

---

## Dual-chain flow — `scripts/shell/local_testing_supersim.sh`

Scenario 4 brings up two local SuperSim forks (Ethereum Sepolia + Base Sepolia)
and deploys the Single Vault DETF graph plus bridge infrastructure across both.
Requires `supersim` installed.

### Full Scenario 4 run

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86 \
  bash scripts/shell/local_testing_supersim.sh scenario4
```

### Per-stage commands

```bash
bash scripts/shell/local_testing_supersim.sh foundation   # per-chain Stage 20 only
bash scripts/shell/local_testing_supersim.sh configure    # bridge config Stage 22 only
bash scripts/shell/local_testing_supersim.sh --kill-supersim
```

Stage layout:

- `20` — per-chain foundation + Single Vault DETF graph on each fork
- `21` — bridge infrastructure on both forks
- `22` — Single Vault DETF bridge configuration on both forks
- `23` — reserve bridge validation on both forks

SuperSim deploys have not yet been migrated to emit fragments. The aggregator
will skip them gracefully (no fragments → no new Token Lists for those envs).

---

## Token List aggregator — `scripts/node/`

### Automatic invocation

The aggregator runs at the end of every `local_testing.sh` command. You don't
need to call it manually unless you're iterating on the pipeline itself.

### Manual invocation

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run build-tokenlists -- --config "$(git rev-parse --show-toplevel)/tokenlists.config.ts"
```

Expected output: one `[OK]` line per bucket that produced a non-empty list, one
`[SKIP]` for unchanged buckets, one `[FAIL]` per validation error (with the
schema error path).

### Run the aggregator tests

```bash
cd scripts/node && npm test
```

20 tests across 5 files. Should all pass.

### Re-run the one-time legacy migration

Regenerates the bucket-style Token Lists from the pre-existing per-category JSON
arrays (`<env>-balancerv3-pools.tokenlist.json` etc.). Run only when you've
intentionally wiped or want to refresh the migrated lists.

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run migrate-legacy
```

### Validate a single bucket against the schema

Quick way to debug a single failing list:

```bash
cd scripts/node && npx tsx -e "
  import('./src/schema.js').then(async ({ validateTokenList }) => {
    const fs = await import('node:fs/promises');
    const list = JSON.parse(await fs.readFile(
      '../../frontend/app/addresses/sepolia/balancer-v3-pools.tokenlist.json',
      'utf8'
    ));
    const r = validateTokenList(list);
    console.log(JSON.stringify(r, null, 2));
  })"
```

---

## UI dev server — `frontend/`

### Start

```bash
cd frontend && npm run dev
```

This wraps `next dev` with a port-kill guard on `3000`. Open
`http://localhost:3000`. The UI reads address artifacts from
`frontend/app/addresses/` at compile time; if you redeploy you need to restart
the dev server (or use `dev:fresh` to also nuke the Next.js cache).

### Fresh start (clears `.next/` cache)

Use this after a redeploy that changes Token Lists or addresses, especially if
the dropdowns look stale.

```bash
cd frontend && npm run dev:fresh
```

### Typecheck the frontend

```bash
cd frontend && npm run typecheck
```

Equivalent to `node scripts/typecheck.mjs`. Use `npx tsc --noEmit` for a direct
TypeScript invocation if you want raw `tsc` output.

### Lint

```bash
cd frontend && npm run lint
```

### Combined `lint + typecheck`

```bash
cd frontend && npm run check
```

### Choosing the deployment environment

The UI reads `NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT` to decide which env's
Token Lists to use as the default. Supported values: `sepolia`,
`public_sepolia`, `supersim_sepolia`. Default is `supersim_sepolia`.

```bash
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=sepolia npm run dev
```

The dropdowns will read from `frontend/app/addresses/<env>/<chain>/<bucket>.tokenlist.json`
for whichever env you select.

---

## End-to-end flow you'll usually run

```bash
# Once per shell session
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92f86

# Bring up a clean chain and deploy your scenario
bash scripts/shell/local_testing.sh --restart-anvil scenario1
# (aggregator runs automatically at the end and refreshes frontend/app/addresses)

# Start the UI against that local deploy
cd frontend && npm run dev:fresh
```

For iterating on the same chain without restarting Anvil:

```bash
# Redeploy a specific stage on the running chain
bash scripts/shell/local_testing.sh stage10 -vv

# Refresh the UI cache
cd frontend && npm run dev:fresh
```

For a fresh chain plus fresh UI cache:

```bash
bash scripts/shell/local_testing.sh --kill-anvil
bash scripts/shell/local_testing.sh --restart-anvil scenario2
cd frontend && npm run dev:fresh
```

---

## Override a dropdown label without redeploying

Edit any fragment under `deployments/<env>/<chain>/fragments/` or any list under
`frontend/app/addresses/<env>/<chain>/` to add:

```json
"extensions": { "display": "My Custom Label" }
```

For fragments: re-run the aggregator so the change propagates into the Token List.

```bash
cd scripts/node && \
INDEXEDEX_REPO_ROOT="$(git rev-parse --show-toplevel)" \
  npm run build-tokenlists -- --config "$(git rev-parse --show-toplevel)/tokenlists.config.ts"
```

For Token Lists: edit the JSON directly. The UI picks it up on the next
`dev:fresh`. No deploy needed.

---

## Common troubleshooting

### "Foundry RPC alias not found: ethereum_sepolia_alchemy"

You don't have `ALCHEMY_KEY` exported. Either set it, or run without forking:

```bash
FOUNDRY_FORK_RPC_ALIAS= ANVIL_CHAIN_ID=31337 \
  bash scripts/shell/local_testing.sh --restart-anvil foundation
```

### "Set DEV_ADDRESS or SENDER before running local testing scripts"

You forgot to export `DEV_ADDRESS`. See "One-time setup".

### Aggregator shows `[FAIL]` with schema errors

Read the error path. The most common culprits are listed in
`TOKENLIST_PIPELINE_CONTEXT.md` "Sharp edges from the Uniswap Token List schema":

- Tag identifiers must match `^[\w]+$` and stay under 10 chars
- Tag descriptions can't contain `-` or `/`
- Symbols cap at 20 chars (the normalizer handles this, but if you bypass it…)
- Extensions can't be arrays (normalizer rewrites to indexed objects)
- Lists with zero tokens are rejected (aggregator skips these silently)

### Dropdown shows old addresses after a redeploy

You forgot `dev:fresh`. Next.js caches the imported JSON modules.

```bash
cd frontend && npm run dev:fresh
```

### "Reusing Anvil at http://127.0.0.1:8545" but you wanted a fork-mode chain

The wrapper reuses any running Anvil on port 8545. Restart it:

```bash
bash scripts/shell/local_testing.sh --restart-anvil foundation
```

### Aggregator says "scripts/node/node_modules missing"

You haven't installed Node deps for the aggregator package.

```bash
cd scripts/node && npm install
```

# Agent runbook: Anvil Robinhood fork + UI testing (chain 4663)

**Purpose:** Tell an agent (or human) exactly how to **fork Robinhood mainnet**, run the IndexedEx staged deploy, and point the **frontend** at the local fork so DETF / SE surfaces can be exercised in the UI.

**Product law SoT:** [`ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md)  
**Implementor plan:** [`ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md)  
**Pipeline code:** `scripts/foundry/anvil_robinhood_main/` (lab **+** fee-DETF CHIR stages 14–22)  
**Shell entry:** `scripts/shell/anvil_robinhood_main.sh`  
**Fee-only alternate:** `scripts/shell/anvil_robinhood_fee_detf.sh` (subset; prefer main for unified UI testing)  
**RH pins:** Crane `ROBINHOOD_MAIN` (`lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`)

---

## 0. Non-negotiables (read first)

| Rule | Detail |
|------|--------|
| **Chain id is 4663** | Anvil **must** run with `--chain-id 4663` (same as Robinhood mainnet). Scripts `require(block.chainid == 4663)`. |
| **Fork Robinhood — do not hermetic Uni** | PoolManager / Uni V3 factory / Permit2 / WETH come from the **fork** via `ROBINHOOD_MAIN`. Never redeploy RH Uni cores. |
| **Use Foundry RPC aliases** | Prefer `robinhood_mainnet_alchemy` (then public fallback). Do **not** invent RPC URLs when aliases exist in `foundry.toml`. |
| **No scripted first bond** | Deploy leaves DETFs **inert**. UI (or a separate research script) does the first bond. Grep of deploy tree must stay free of `.bond(`. |
| **Never `via_ir`** | Default Foundry profile only. |
| **Never `new` facets/DFPkgs** | CREATE3 / FactoryService / manager registry only. |

---

## 1. Prerequisites

From **repo root** (`lib/indexedex`):

```bash
# Foundry
forge --version && cast --version && anvil --version

# Host tools used by orchestrator
command -v jq && command -v lsof
```

### 1.1 Alchemy key (recommended)

`foundry.toml` aliases:

| Alias | URL template | When to use |
|-------|----------------|-------------|
| `robinhood_mainnet_alchemy` | `https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}` | **Default** for Anvil fork (rate limits OK) |
| `robinhood_mainnet` / `robinhood_mainnet_public` | `https://rpc.mainnet.chain.robinhood.com` | Fallback if no Alchemy key |

Export before fork/deploy:

```bash
# Prefer project env (do not commit secrets)
export ALCHEMY_KEY=...   # or source your local .env / shell profile

# Sanity: alias resolves without leftover ${...}
forge config --json | jq -r '.rpc_endpoints.robinhood_mainnet_alchemy'
# After expand:
eval "echo $(forge config --json | jq -r '.rpc_endpoints.robinhood_mainnet_alchemy')"
```

If Alchemy is missing or DNS fails, set an explicit fork URL (public RH):

```bash
export ANVIL_FORK_URL=https://rpc.mainnet.chain.robinhood.com
```

### 1.2 Anvil accounts (well-known — local only)

| Role | Address | Key note |
|------|---------|----------|
| **Deployer / SENDER / OWNER** (Anvil #0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | Anvil default mnemonic account 0 |
| **UI wallet** (Anvil #1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Import into MetaMask / wallet for UI |

Scripts mint **TT0…TT7** (~`1e12` whole units each) to **both** accounts.

---

## 2. How forking works (agent mental model)

```text
Robinhood mainnet (chain 4663)
        │  eth_get* via FOUNDRY alias
        ▼
   Anvil process
   --chain-id 4663
   --fork-url <resolved robinhood_mainnet_alchemy or public>
   --fork-block-number 20714383   # ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK unless overridden
   --disable-code-size-limit      # required: Uni V4 SE OutFacet > EIP-170 24kb
   --host 127.0.0.1 --port 8545
        │
        ▼
   forge script stages 00–14
   OUT_DIR=deployments/anvil_robinhood_main
        │
        ▼
   frontend/packages/protocol/src/addresses/chain/4663/*
   getAddressArtifacts(4663)  →  UI
```

**Orchestrator defaults** (`scripts/foundry/anvil_robinhood_main/deploy_all.sh`):

| Env | Default |
|-----|---------|
| `RPC_URL` | `http://127.0.0.1:8545` (local Anvil only for broadcast) |
| `FOUNDRY_FORK_RPC_ALIAS` | `robinhood_mainnet_alchemy` (falls back to `robinhood_mainnet`) |
| `ANVIL_FORK_BLOCK_NUMBER` | `20714383` |
| `ANVIL_CHAIN_ID` | `4663` |
| `OUT_DIR_OVERRIDE` | `deployments/anvil_robinhood_main` |
| `NETWORK_PROFILE` | `anvil_robinhood_main` |
| `GAS_ESTIMATE_MULTIPLIER` | `300` (large CREATE3 facets) |

Safety: broadcast is **refused** if `RPC_URL` is not localhost.

---

## 3. One-shot: deploy everything (preferred)

From **repo root**:

```bash
cd /path/to/lib/indexedex

export ALCHEMY_KEY=...   # if using Alchemy alias
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Clean Anvil + full stages 00–14
bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

**Success criteria (must all hold):**

```bash
# 1) Exit 0 and log contains:
#    [SUCCESS] Command 'all' completed

# 2) Local chain is Robinhood id
cast chain-id --rpc-url http://127.0.0.1:8545
# → 4663

# 3) RH Uni V4 PoolManager has code on the fork
cast code 0x8366a39CC670B4001A1121B8F6A443A643e40951 --rpc-url http://127.0.0.1:8545 | head -c 20
# → non-empty 0x...

# 4) Stage artifacts 00–14 exist
ls deployments/anvil_robinhood_main/[0-9]*.json

# 5) Inert demos present (names may vary slightly by export keys)
jq 'keys' deployments/anvil_robinhood_main/13_inert_demos.json
# expect: weightedBufferN8, 2× CP, 2× Orbital, 2× Weighted DETF, 2× single SE buffer

# 6) D14: SE rate providers non-zero
RPV3=$(jq -r .rp_v3Se_tt0_tt1 deployments/anvil_robinhood_main/09_rate_providers.json)
RPV4=$(jq -r .rp_v4Se_tt4_tt5 deployments/anvil_robinhood_main/09_rate_providers.json)
cast call "$RPV3" 'getRate()(uint256)' --rpc-url http://127.0.0.1:8545   # > 0
cast call "$RPV4" 'getRate()(uint256)' --rpc-url http://127.0.0.1:8545   # > 0

# 7) Frontend export
test -f frontend/packages/protocol/src/addresses/chain/4663/platform.json
jq '{chainId, indexedexManager, cpDetfGentle, weightedBufferN8}' \
  frontend/packages/protocol/src/addresses/chain/4663/platform.json
```

**Wall-clock:** first full run often **10–20+ minutes** (compile + n=8 demos). Use `--slow` (already set by orchestrator). Do not kill mid-stage unless restarting cleanly.

### 3.1 Useful command variants

```bash
# Kill only
bash scripts/shell/anvil_robinhood_main.sh --kill-anvil

# Resume stages without restarting Anvil (artifacts must match live chain)
bash scripts/shell/anvil_robinhood_main.sh packages
bash scripts/shell/anvil_robinhood_main.sh demos
bash scripts/shell/anvil_robinhood_main.sh export

# Single stage
bash scripts/shell/anvil_robinhood_main.sh stage07

# Force re-run stages (with restart, JSON is purged automatically)
FORCE=1 bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil

# Dry-run (no broadcast)
bash scripts/shell/anvil_robinhood_main.sh all --dry-run

# Verbosity
bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil -vv
```

**Partial groups:** `foundation` (00–03), `assets` (04), `pools` (05–06), `se` (07–09), `packages` (10–12), `demos` (13), `export` (14).

---

## 4. Manual Anvil (only if not using the shell)

Agents should **prefer the shell** (handles fork alias, chain id, code-size limit, account sanitize). If starting Anvil by hand:

```bash
# Resolve Alchemy template the same way deploy_all does
FORK_URL=$(eval "printf '%s' \"$(forge config --json | jq -r '.rpc_endpoints.robinhood_mainnet_alchemy')\"")

anvil \
  --host 127.0.0.1 \
  --port 8545 \
  --chain-id 4663 \
  --fork-url "$FORK_URL" \
  --fork-block-number 20714383 \
  --compute-units-per-second 50 \
  --fork-retry-backoff 1000 \
  --disable-code-size-limit
```

`--disable-code-size-limit` is **required** for this pipeline (Uni V4 SE OutFacet exceeds EIP-170 24kb). Hermetic tests use the same exception; do not enable `via_ir` as a workaround.

Then run stages without `--restart-anvil` so the shell reuses the process:

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all
```

---

## 5. Point the UI at the local Robinhood fork

### 5.1 What the deploy already wrote

| Path | Role |
|------|------|
| `frontend/packages/protocol/src/addresses/chain/4663/platform.json` | Manager, packages, demos, RH pins, deployer/uiWallet |
| `…/base-tokens.tokenlist.json` | TT0…TT7 |
| `…/strategy-vaults.tokenlist.json` | SE vaults + buffers |
| `…/protocol-detfs.tokenlist.json` | Six inert DETFs |

Protocol package treats **4663 as first-class** (`CHAIN_ID_ROBINHOOD`):

```ts
import { getAddressArtifacts, CHAIN_ID_ROBINHOOD } from '@indexedex/protocol'
// CHAIN_ID_ROBINHOOD === 4663
const artifacts = getAddressArtifacts(4663)
// artifacts.platform.indexedexManager, .cpDetfGentle, .tt0, …
```

Do **not** remap 4663 → Sepolia.

### 5.2 Wallet / network

1. Keep Anvil running on `http://127.0.0.1:8545`.
2. In MetaMask (or equivalent):
   - **Network name:** e.g. `Anvil Robinhood`
   - **RPC URL:** `http://127.0.0.1:8545`
   - **Chain ID:** `4663`
   - **Currency:** ETH
3. Import Anvil account **#1** (UI wallet) for end-user flows.  
   Account **#0** is deployer/owner (already used by forge).
4. Ensure wallet is on chain **4663** (not 31337 / Sepolia).

### 5.3 Frontend app env

Start the frontend from the monorepo’s usual frontend workspace (see `frontend/ROADMAP.md` / package scripts). Prefer env that does **not** force Sepolia remapping for chain selection.

Minimal agent checklist:

```bash
# Example — adapt to current frontend package layout
cd frontend   # or frontend/apps/<app>

# Prefer loading chain-keyed artifacts for 4663.
# If the app still defaults to supersim/sepolia, set RPC + chain so the wallet
# and wagmi config use:
#   rpc: http://127.0.0.1:8545
#   chainId: 4663

# Build/dev after stage 14 so platform.json is fresh
npm install   # if needed
npm run dev   # or the app's documented dev command
```

If the app has a hard-coded chain list, ensure **4663** is allowed and transports map `4663 → http://127.0.0.1:8545`.

### 5.4 What to click-test in the UI

| Step | Expectation |
|------|-------------|
| Connect wallet on 4663 | Account #1 balances include **TT0…TT7** (large mint) |
| Discover DETFs / SEs | Addresses match `platform.json` / tokenlists under `chain/4663` |
| Open a **gentle** DETF (CP or Weighted) | Shows **inert** / not live until first bond |
| **First bond** in UI | Uses UI wallet + TT/pair; **not** pre-done by scripts |
| Optional | SE wrap/unwrap, Weighted buffer n=8 views |

DETFs stay inert after deploy until the user bonds — that is intentional (PRD D4).

---

## 6. Stage map (for debugging)

| Stage | Responsibility | Artifact |
|-------|----------------|----------|
| 00 | Preflight: chain 4663 + RH pin bytecode | `00_preflight.json` |
| 01 | Crane CREATE3 + diamond factory + facets | `01_crane_foundation.json` |
| 02 | FeeCollector + IndexedexManager | `02_indexedex_core.json` |
| 03 | Hook diamond factory → manager | `03_hook_factory.json` |
| 04 | TT0–TT7 mint to acct0/acct1 | `04_test_tokens.json` |
| 05 | Uni V3 pools + NPM seed on RH factory | `05_univ3_pools.json` |
| 06 | Uni V4 SE pools + seed on RH PoolManager | `06_univ4_pools.json` |
| 07 | Uni V3 SE package + vaults + seed | `07_univ3_se.json` |
| 08 | Uni V4 SE package + vaults + seed | `08_univ4_se.json` |
| 09 | StandardExchange RPs; **assert getRate() > 0** | `09_rate_providers.json` |
| 10 | Hook DFPkgs (CP / Orbital / Weighted / Single SE) | `10_hook_packages.json` |
| 11 | Bond NFT + rebasing claim packages | `11_detf_children.json` |
| 12 | CP / Orbital / Weighted DETF packages | `12_detf_packages.json` |
| 13 | Inert demos only (no bond) | `13_inert_demos.json` |
| 14–21 | Fee-DETF: pons RICH → Uni V3 SE → CHIR live + UI ETH | `14_pons_rich.json` … `21_ui_wallet.json` |
| 22 | Export `chain/4663` (lab + CHIR + featured-fee-detfs) | `22_frontend_export.json` |

Logs: `deployments/anvil_robinhood_main/runtime/anvil.log` when Anvil is started by the script.

---

## 7. Troubleshooting (agent checklist)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `chainId must be 4663` | Anvil on 31337 or wrong port | Restart with `--chain-id 4663`; check `cast chain-id` |
| Timed out waiting for Anvil | Bad/missing fork RPC | Set `ALCHEMY_KEY` or `ANVIL_FORK_URL=https://rpc.mainnet.chain.robinhood.com`; read `runtime/anvil.log` |
| `UNISWAP_V4_POOL_MANAGER missing code` | Not actually forking RH | Fix fork URL; confirm pin has code via `cast code` |
| `ErrorCreatingContract` on large facet | Code-size limit | Orchestrator already passes `--disable-code-size-limit`; do not strip it |
| `vm.prank: cannot prank for a broadcasted transaction` | Old hook package stage | Ensure current `Script_10` uses `registry.deployPkg` without prank |
| `TokensNotAscending` on weighted n=8 | Unsorted TT list | Current `Script_13` sorts by address — pull latest scripts |
| V3 RP `getRate()==0` | Old V3 SE without shares→pair preview | Current InQuery supports shares→token; re-run stages 07–09 |
| UI shows Sepolia addresses | Chain remapped or wrong env | Use `getAddressArtifacts(4663)`; wallet chain **4663**; check `chain/4663/platform.json` |
| Stale contracts after Anvil restart | Stage JSON from previous fork | Always `--restart-anvil` (purges stage JSONs) or delete `deployments/anvil_robinhood_main/[0-9]*.json` |
| Broadcast refused | Non-local RPC | `RPC_URL` must be `http://127.0.0.1:8545` |

---

## 8. Anti-patterns (do not do)

- Fork **Base / Sepolia / Ethereum** and expect RH Uni pins or chain id 4663.
- Hardcode production addresses instead of `ROBINHOOD_MAIN` / stage JSON.
- Call DETF `.bond(` from deploy scripts.
- Use `FOUNDRY_PROFILE` package-specific profiles or `via_ir`.
- Point the wallet at Anvil with chain id **31337** while scripts assert **4663**.
- Assume `all --restart-anvil` finished without checking for `[SUCCESS] Command 'all' completed` and exit 0.

---

## 9. Minimal copy-paste agent sequence

```bash
# Repo root = lib/indexedex
export ALCHEMY_KEY="${ALCHEMY_KEY:?set Alchemy key or set ANVIL_FORK_URL}"
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
# wait for: [SUCCESS] Command 'all' completed

cast chain-id --rpc-url http://127.0.0.1:8545   # 4663
test -f frontend/packages/protocol/src/addresses/chain/4663/platform.json

# Leave Anvil running. Configure UI/wallet:
#   RPC http://127.0.0.1:8545 , chainId 4663 , import Anvil #1
# Start frontend; load getAddressArtifacts(4663); first bond in UI on a gentle DETF.
```

---

## 10. Related files

| File | Why |
|------|-----|
| `scripts/shell/anvil_robinhood_main.sh` | Thin wrapper → `deploy_all.sh` |
| `scripts/foundry/anvil_robinhood_main/deploy_all.sh` | Anvil lifecycle + stage runner |
| `scripts/foundry/anvil_robinhood_main/README.md` | Short operator notes |
| `foundry.toml` `[rpc_endpoints]` | `robinhood_mainnet*` aliases |
| `frontend/packages/protocol/src/addressArtifacts.ts` | `CHAIN_ID_ROBINHOOD` / `getAddressArtifacts(4663)` |
| `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` | Inventory row for this family |

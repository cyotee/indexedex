# Implementation Plan: Anvil Robinhood-Fork Uni V4 DETF + Hook Deploy

**PRD (product law SoT):** [`ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md) (**Accepted v0.3.1**)  
**This plan (implementor SoT once executing):** staged Foundry scripts + shell orchestrator + `chain/4663` artifacts + minimal protocol loader  
**Date:** 2026-08-09  
**Status:** **READY FOR EXECUTION** (goal-command agent)

**Authority**

| Layer | Role |
|-------|------|
| **PRD v0.3.1** | Product/deploy requirements (D1–D16). Wins on conflict. |
| **This plan** | File map, phases, stage contracts, fixture graph, DoD, agent checklist |
| Skills | `crane-deployment`, `crane-architecture`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` |
| Gold patterns | `scripts/foundry/local_testing/**`, `scripts/foundry/anvil_base_main/**`, co-located `TestBase_UniswapV*` |

**Process rules**

1. If this plan and PRD disagree, **PRD wins** — patch this plan.  
2. If unspecified in PRD + this plan, **stop and ask** — do not invent product law.  
3. **Never** script DETF `bond` / first bond.  
4. **Never** deploy hermetic PoolManager / Uni V3 factory when forked RH has them.  
5. **Never** `new` facets/DFPkgs; **never** `via_ir`.  
6. Facets/packages: CREATE3 + FactoryService; vaults/DETFs/hooks: manager registry / `deployHookVault`.

---

## 0. Locked implementor card (PRD D1–D16)

| ID | Lock |
|----|------|
| D1 | Mintable test tokens only (`TT0`…`TT7`) |
| D2 | Anvil **`--chain-id 4663`**; scripts `require(block.chainid == 4663)` |
| D3 | Superseded listing DETF tree **out** |
| D4 | Inert DETFs only; UI buys first bond |
| D5 | Gentle **+** launch-rich inert per CP / Orbital / Weighted |
| D6 | **Uni V3 SE + Uni V4 SE** (not Uni V2 primary) |
| D7 | Frontend: **`frontend/packages/protocol/src/addresses/chain/4663/` only** |
| D8 | `scripts/foundry/anvil_robinhood_main/deploy_all.sh` + `scripts/shell/anvil_robinhood_main.sh` |
| D9 | Eight tokens; Weighted full-door routes |
| D10 | Fork @ `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK` unless override |
| D11 | acct0 deployer; acct1 UI; mint `1e12 * 10**decimals` each token to both |
| D12 | Weighted Buffer **and** Weighted DETF both **\(n=8\)** |
| D13 | Weighted \(n=8\): **≥1 V3 SE leg and ≥1 V4 SE leg** |
| D14 | **RP on every SE-buffered leg** (shares → pairToken) |
| D15 | Artifacts + **minimal** protocol loader for 4663 / local RPC |
| D16 | Any app via `@indexedex/protocol` |

**Canonical externals:** import `ROBINHOOD_MAIN` from Crane — do not hardcode production addresses except via that library.

---

## 1. Goal for the executing agent

Deliver a green path:

```bash
# From repo root, with Alchemy/public RH RPC available
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil
```

Result:

1. Anvil forking RH mainnet at chain id **4663**.  
2. Full package + inert demo surface per PRD.  
3. Stage JSON under `deployments/anvil_robinhood_main/`.  
4. UI artifacts under `frontend/packages/protocol/src/addresses/chain/4663/`.  
5. Protocol package resolves `chainId === 4663` against those artifacts + local RPC docs.

---

## 2. Directory / file map (create)

```text
scripts/foundry/anvil_robinhood_main/
  README.md
  deploy_all.sh
  DeploymentBase.sol                    # extends local-testing base patterns; OUT_DIR default
  RobinhoodCanonicalLib.sol             # thin wrappers: pin checks, ROBINHOOD_MAIN accessors
  FixtureGraph.sol                      # TT0–TT7 roles, pool edges, weight vector constants
  Script_00_Preflight.s.sol
  Script_01_DeployCraneFoundation.s.sol
  Script_02_DeployIndexedexCore.s.sol
  Script_03_DeployHookFactory.s.sol
  Script_04_DeployTestTokens.s.sol
  Script_05_DeployUniV3PoolsAndSeed.s.sol
  Script_06_DeployUniV4PoolsAndSeed.s.sol
  Script_07_DeployUniV3StandardExchange.s.sol
  Script_08_DeployUniV4StandardExchange.s.sol
  Script_09_DeployRateProviders.s.sol
  Script_10_DeployHookPackages.s.sol
  Script_11_DeployDetfChildren.s.sol
  Script_12_DeployDetfPackages.s.sol
  Script_13_DeployInertDemos.s.sol      # weighted n=8 buffer + inert DETFs + single SE buffers
  Script_14_ExportFrontendArtifacts.s.sol

scripts/shell/anvil_robinhood_main.sh   # thin wrapper → deploy_all.sh

deployments/anvil_robinhood_main/
  .gitkeep
  README.md                             # operator notes, account keys, commands

frontend/packages/protocol/src/addresses/chain/4663/
  platform.json                         # written by export stage (or placeholders then overwrite)
  base-tokens.tokenlist.json
  strategy-vaults.tokenlist.json        # SE vaults
  protocol-detfs.tokenlist.json         # inert DETFs
  # additional lists as needed (hooks, uni-v3/v4 pools) matching existing tokenlist schema

# Protocol loader (minimal — touch only what is required for 4663):
frontend/packages/protocol/src/addresses/index.ts     # extend types / registry if needed
frontend/packages/protocol/src/addressArtifacts.ts    # CHAIN_ID_ROBINHOOD=4663 resolve
# + chainPlatformOverrides generation path if aggregator is used

docs/DEPLOYMENT_SCRIPT_INVENTORY.md     # add family section
```

**Reuse (do not rewrite):**

| Pattern | Source |
|---------|--------|
| Artifact resume / JSON IO | `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol` |
| Crane foundation stage | `local_testing/anvil_single/Script_01_DeployCraneFoundation.s.sol` |
| IndexedEx core | `…/Script_02_DeployIndexedexCore.s.sol` |
| Mintable tokens | `…/Script_06_DeployFoundationAssets.s.sol` (`ERC20MintBurnOwnableOperableDFPkg` / minter facade) |
| Anvil lifecycle | `scripts/foundry/anvil_base_main/deploy_all.sh`, `scripts/shell/local_testing.sh` |
| Uni V3 SE deploy | `contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol` + `UniswapV3_Component_FactoryService` |
| Uni V4 SE deploy | `…/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol` + `UniswapV4_Component_FactoryService` |
| Rate providers | `StandardExchangeRateProvider_FactoryService` + existing anvil stage pattern |
| Hook packages | Co-located hook TestBases + skill `indexedex-uniswap-v4-hook-packages` |
| DETF packages | Co-located `TestBase_UniswapV4*DETF.sol` |
| V4 liquidity seed | `scripts/foundry/shared/UniswapV4LiquiditySeeder.sol` (if fits) |
| RH pins | `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` |

---

## 3. Concrete fixture graph (implementation defaults)

PRD allows these choices **within** D9/D12/D13/D14. Treat as normative unless blocked by code — then document deviation in stage JSON `notes`.

### 3.1 Tokens

| Key | Symbol | Decimals | Mint each to acct0 & acct1 |
|-----|--------|----------|----------------------------|
| `tt0`…`tt7` | `TT0`…`TT7` | 18 | `1_000_000_000_000e18` (`1e12` whole units) |

Use mintable ownable operable ERC-20 package (same family as local_testing TTA/TTB/TTC). Deployer (acct0) is minter/owner.

### 3.2 Uni V3 pool edge list (connected + density)

**Minimum required:** every token appears in ≥1 seeded V3 pool.

**Preferred default (implement this):**

1. **Chain path:** `TT0-TT1`, `TT1-TT2`, …, `TT6-TT7` (7 pools) — connectivity.  
2. **Star extras from TT0:** `TT0-TT2`, `TT0-TT3`, `TT0-TT4`, `TT0-TT5`, `TT0-TT6`, `TT0-TT7` if not already chain — for multi-hop richness.  
3. **SE wrap pools (named):**  
   - `v3SePoolA` = `TT0` / `TT1` (primary V3 SE underlying)  
   - `v3SePoolB` = `TT2` / `TT3` (optional second V3 SE if needed for multiple buffered legs)

Fee tier: use a fee available on RH Uni V3 factory (TestBase default or `3000` if supported — verify via factory `feeAmountTickSpacing` on fork; fail preflight if chosen fee unsupported).

Init price: 1:1 `sqrtPriceX96` for like-decimal pairs.

### 3.3 Uni V4 pools (for V4 SE)

Create/initialize on **`ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`**:

| Key | Currencies | Fee / hooks | Purpose |
|-----|------------|-------------|---------|
| `v4SePoolA` | sort(`TT4`,`TT5`) | package-required; hooks as V4 SE TestBase | Primary V4 SE |
| `v4SePoolB` | sort(`TT6`,`TT7`) | same | Optional second V4 SE |

Seed CL liquidity via Position Manager or project seeder helper (match TestBase).

### 3.4 SE vault instances

| Key | Package | Underlying | Notes |
|-----|---------|------------|-------|
| `uniV3Se_tt0_tt1` | Uni V3 SE DFPkg | V3 pool TT0/TT1 | Bound as **V3 SE leg** on Weighted |
| `uniV4Se_tt4_tt5` | Uni V4 SE DFPkg | V4 pool TT4/TT5 | Bound as **V4 SE leg** on Weighted |

Deposit seed inventory into each SE so wrap/unwrap works (script may deposit from deployer).

### 3.5 Rate providers (D14)

For each SE vault instance used as a buffered leg:

| Key | Rates | Target |
|-----|-------|--------|
| `rp_v3Se_tt0_tt1` | SE shares → `TT0` **or** the pairToken used on that Weighted binding | Use `StandardExchangeRateProvider` package; follow TestBase / anvil stage wiring |
| `rp_v4Se_tt4_tt5` | SE shares → matching pairToken on binding | Same |

If product requires RP unit = pairToken of the **leg**, set that leg’s `pairToken` to the token the RP quotes into (document in `13_inert_demos.json`).

### 3.6 Weighted Buffer \(n=8\) (standalone demo)

| Field | Value |
|-------|--------|
| `n` | 8 |
| Tokens | `TT0`…`TT7` (pass unsorted; package sorts by address) |
| Weights | Equal `0.125e18` each (sum `1e18`; each ≥1%) |
| SE slots | Map by **token address index after sort** — ensure the leg whose `pairToken` is TT0 or TT1 binds **V3 SE**; leg for TT4 or TT5 binds **V4 SE** (D13). Remaining legs bare (`SE=0`, `RP=0`). |
| RP | Non-zero only on SE-buffered indices (D14) |
| Doors | All 28 pair pools initialized + seeded |
| poolManager | `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` |
| feeOracle | IndexedEx manager fee oracle surface |

Deploy via package `deployVault(args, mineNonce)` → `deployHookVault` (premine nonce).

### 3.7 Weighted DETF \(n=8\) (gentle + launch-rich)

| Field | Value |
|-------|--------|
| `n` | 8 = **DETF diamond self-leg + 7 external tokens** |
| Externals | Use seven of `TT0`…`TT7` (exclude one only if address-sort forces conflict — prefer all seven externals from TT set; DETF is the eighth). Concrete: external = `TT0`…`TT6`, DETF is self; or full sort-compatible set from TestBase pattern. |
| SE mix | ≥1 V3 SE + ≥1 V4 SE on external legs (D13) |
| RP | On every SE leg (D14) |
| Gentle | `expansionEpochLength=0`, `expansionClosureRatePerYearWad=0` (family defaults) |
| Launch-rich | Copy TestBase / CP PRD template: e.g. `expansionClosureRatePerYearWad = 4.4e18`, epoch 8h (`28800` or `0`→default) — **match co-located TestBase launch-rich helper** |
| Instances | Two inert deploys: `weightedDetfGentle`, `weightedDetfLaunchRich` |
| **No bond** | Stop after `deployVault` |

### 3.8 CP DETF (gentle + launch-rich)

| Instance | Backing SE | pairToken | Expansion |
|----------|------------|-----------|-----------|
| `cpDetfGentle` | `uniV3Se_tt0_tt1` | `TT0` or `TT1` ∈ SE tokens | Gentle zeros |
| `cpDetfLaunchRich` | `uniV4Se_tt4_tt5` | `TT4` or `TT5` ∈ SE tokens | Launch-rich `R` |

Covers both SE types across the two demos. Use `TestBase_UniswapV4SingleStandardExchangeDETF` for PkgInit/PkgArgs shape.

### 3.9 Orbital DETF (gentle + launch-rich)

| Instance | External pairs | SE | Expansion |
|----------|----------------|-----|-----------|
| `orbitalDetfGentle` | e.g. TT0 + TT4 | TT0→V3 SE, TT4→V4 SE (or one SE + one bare if product allows) | Gentle |
| `orbitalDetfLaunchRich` | same binding shape or swapped | ≥1 SE total; prefer mixed | Launch-rich |

**Forbidden:** both-bare (product law).

### 3.10 Single SE Buffer hooks

| Instance | SE | pairToken |
|----------|-----|-----------|
| `singleSeBuffer_v3` | `uniV3Se_tt0_tt1` | `TT0` (or TT1) |
| `singleSeBuffer_v4` | `uniV4Se_tt4_tt5` | `TT4` (or TT5) |

Deploy via hook package + `deployHookVault`; initialize fee-0 buffer pools on RH PoolManager per hook PRD.

### 3.11 Anvil accounts

| Role | Default Anvil address | Key (document only; never commit secrets beyond well-known Anvil keys) |
|------|----------------------|------------------------------------------------------------------------|
| Deployer / owner / SENDER | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (acct0) | Anvil #0 |
| UI wallet | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` (acct1) | Anvil #1 |

Export both in `00_preflight.json` / `platform.json`.

---

## 4. Stage specifications

Each stage:

- Reads prior artifacts; **skips** if own artifact exists and valid unless `FORCE=1`.  
- Broadcasts with `--unlocked --sender $DEV_ADDRESS --slow`.  
- Writes JSON to `deployments/anvil_robinhood_main/<NN>_<name>.json`.  
- Labels contracts with `vm.label`.

### Stage 00 — Preflight

**File:** `Script_00_Preflight.s.sol`

- Assert `block.chainid == 4663`.  
- Assert code at: `UNISWAP_V4_POOL_MANAGER`, `UNISWAP_V3_FACTORY`, `PERMIT2`, `WETH`, `UNISWAP_UNIVERSAL_ROUTER` (and any other addresses stage scripts will call).  
- Record `forkBlock`, RPC alias/url (non-secret), deployer, uiWallet.  
- **No broadcast required** (view/assert only) unless writing file needs broadcast — prefer pure script write.

**Artifact keys:** `chainId`, `forkBlock`, `poolManager`, `v3Factory`, `permit2`, `deployer`, `uiWallet`, …

### Stage 01 — Crane foundation

Mirror local_testing Script_01:

- `InitDevService.initEnv` → create3 + diamondPackageFactory  
- Shared facets: ERC20, ERC2612, ERC5267, ERC4626*, multi-asset vault, multiStepOwnable, operable, diamondCut, etc. as needed by later stages  

**Artifact:** `01_crane_foundation.json`

### Stage 02 — IndexedEx core

Mirror Script_02:

- FeeCollector, IndexedexManager  
- Operator config for deployer  
- Fee oracle / bond terms defaults if required by DETF TestBases  

**Artifact:** `02_indexedex_core.json`

### Stage 03 — Hook diamond factory

- Deploy `UniswapV4HookDiamondPackageCallBackFactory` via FactoryService (CREATE3 facets + factory).  
- `indexedexManager.setHookDiamondPackageFactory(hookFactory)` (owner prank/broadcast as deployer).  
- Factory must use / pin RH PoolManager per factory PRD (constructor/immutables — follow TestBase).  

**Artifact:** `03_hook_factory.json`

### Stage 04 — Test tokens + mints

- Deploy TT0…TT7 mintable.  
- Mint `1e12e18` each to acct0 and acct1.  
- Optionally deploy minter facade if local_testing pattern required for UI; not mandatory if tokens are freely mintable by owner and balances already set.  

**Artifact:** `04_test_tokens.json` + tokenlist fragments

### Stage 05 — Uni V3 pools + seed

- Create pools per §3.2 on `ROBINHOOD_MAIN.UNISWAP_V3_FACTORY`.  
- Approve NPM / router; add liquidity from deployer.  
- Record pool addresses, fee, token pairs.  

**Artifact:** `05_univ3_pools.json`

### Stage 06 — Uni V4 pools + seed

- Initialize pools on RH PoolManager for V4 SE underlyings (§3.3).  
- Seed liquidity.  

**Artifact:** `06_univ4_pools.json`

### Stage 07 — Uni V3 SE package + instances

- Deploy Uni V3 SE facets + DFPkg via registry path (`deploy*DFPkg` / Component FactoryService).  
- `deployVault` for `uniV3Se_tt0_tt1` (and optional second).  
- Seed SE with exchangeIn deposits.  

**Artifact:** `07_univ3_se.json`

### Stage 08 — Uni V4 SE package + instances

- Same for Uni V4 SE; `poolManager = ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`.  

**Artifact:** `08_univ4_se.json`

### Stage 09 — Rate providers

- Deploy StandardExchangeRateProvider DFPkg (manager path as other anvil stages).  
- Deploy RP instances for each SE used on multi-leg surfaces.  

**Artifact:** `09_rate_providers.json`

### Stage 10 — Hook packages (DFPkgs only)

Register/deploy packages (not all instances yet if instances need full SE graph — packages first):

- CP Buffer Constant Product hook DFPkg  
- Orbital Buffer hook DFPkg  
- Weighted Buffer hook DFPkg  
- Single SE Buffer hook DFPkg  

Follow `indexedex-uniswap-v4-hook-packages` + each package FactoryService.

**Artifact:** `10_hook_packages.json`

### Stage 11 — DETF children

- Uni V4 bond NFT DFPkg (`…/common/nft/`)  
- Uni V4 rebasing claim DFPkg (`…/common/rebasing/`)  
- Path: pure Crane CREATE3 for non-registry children where TestBase does; registry for DETFNFT vault pkg as TestBase  

**Artifact:** `11_detf_children.json`

### Stage 12 — DETF packages

Deploy via `indexedexManager` / Component FactoryService:

- `UniswapV4SingleStandardExchangeDETDFPkg`  
- `UniswapV4StandardExchangeOrbitalDETDFPkg`  
- `UniswapV4StandardExchangeWeightedDETDFPkg`  

**Artifact:** `12_detf_packages.json`

### Stage 13 — Inert demos (no bond)

Order matters (hooks may be created inside DETF postDeploy):

1. Standalone **Weighted Buffer \(n=8\)** instance + seed all doors.  
2. **Single SE Buffer** V3 + V4 instances + init pools.  
3. **CP** gentle + launch-rich inert DETFs.  
4. **Orbital** gentle + launch-rich inert DETFs.  
5. **Weighted DETF \(n=8\)** gentle + launch-rich inert DETFs.  

Assert after each: instance code length > 0; DETF `isReserveLive` / equivalent is **false** if exposed (inert). **Do not call bond.**

**Artifact:** `13_inert_demos.json` — full address map with stable keys from §3.

### Stage 14 — Export frontend

Write / sync into `frontend/packages/protocol/src/addresses/chain/4663/`:

| File | Contents |
|------|----------|
| `platform.json` | create3, diamondFactory, manager, feeCollector, hookFactory, poolManager, v3Factory, permit2, deployer, uiWallet, all package + instance keys from stages |
| `base-tokens.tokenlist.json` | TT0…TT7 Token List entries |
| `strategy-vaults.tokenlist.json` | SE vaults |
| `protocol-detfs.tokenlist.json` | Six inert DETFs (gentle/launch-rich × 3 families) labeled by name/symbol |
| Optional | hooks list, pool lists if UI menus need them |

Match existing Token List / platform schema used by `chain/11155111` and tokenlist aggregator.

If the monorepo uses `scripts/node` build-tokenlists to regenerate `chainPlatformOverrides.generated.ts`, **run that** after writing `platform.json` so `getAddressArtifacts(4663)` can pick up overrides.

**Minimal protocol loader (D15):**

1. Add `export const CHAIN_ID_ROBINHOOD = 4663`.  
2. Extend `resolveArtifactsChainId` / `CanonicalArtifactChainId` / `getArtifactBundle` so **4663 is first-class**, not remapped to Sepolia.  
3. Register a deployment environment **or** pure chain-keyed path: prefer chain-keyed `platform.json` override + a thin bundle for tokenlists under `chain/4663/`.  
4. Document env: `NEXT_PUBLIC_…` / RPC `http://127.0.0.1:8545` + chain id 4663 in pipeline README.  
5. Unit test or vitest if package has tests for `getAddressArtifacts(4663)`.

Do **not** require first-bond UI E2E green.

---

## 5. Shell orchestrator

### 5.1 `deploy_all.sh` (primary)

Port patterns from `anvil_base_main/deploy_all.sh` + `local_testing.sh`:

| Flag / env | Behavior |
|------------|----------|
| `--restart-anvil` | Kill port + start anvil |
| `--kill-anvil` | Kill only |
| `--force` | Re-run stages ignoring existing JSON |
| `--dry-run` | forge script without `--broadcast` |
| `-v`… | forge verbosity |
| Commands | `all`, `foundation` (00–03), `assets` (04), `pools` (05–06), `se` (07–09), `packages` (10–12), `demos` (13), `export` (14), `stageNN` |

Anvil start args (**mandatory**):

```bash
anvil \
  --host 127.0.0.1 \
  --port 8545 \
  --chain-id 4663 \
  --fork-url "$ANVIL_FORK_URL" \
  --fork-block-number "${ANVIL_FORK_BLOCK_NUMBER:-20714383}" \
  --compute-units-per-second "${ANVIL_COMPUTE_UNITS_PER_SECOND:-50}" \
  # ... retry backoff as anvil_base_main
```

Resolve fork URL from `FOUNDRY_FORK_RPC_ALIAS` default `robinhood_mainnet_alchemy` (fallback `robinhood_mainnet`) via `forge config --json` like `local_testing.sh`.

Exports:

```bash
export OUT_DIR_OVERRIDE=deployments/anvil_robinhood_main
export NETWORK_PROFILE=anvil_robinhood_main
export CHAIN_ID=4663
export SENDER="$DEV_ADDRESS"
export OWNER="${OWNER:-$DEV_ADDRESS}"
```

Guard: if `RPC_URL` is not localhost, refuse broadcast (PRD safety).

### 5.2 `scripts/shell/anvil_robinhood_main.sh`

```bash
#!/usr/bin/env bash
# Thin wrapper — exec deploy_all.sh with same args
exec "$(dirname "$0")/../foundry/anvil_robinhood_main/deploy_all.sh" "$@"
```

### 5.3 README

Operator doc: prerequisites (Alchemy key), commands, Anvil account table, “DETFs are inert — bond in UI”, artifact paths, known gas/time expectations for \(n=8\).

---

## 6. Implementation phases (execute in order)

### Phase A — Scaffold (no full BOM yet)

1. Create directory + `DeploymentBase.sol` (OUT_DIR, chain assert helper, wallet addresses).  
2. `RobinhoodCanonicalLib.sol` + `FixtureGraph.sol` constants.  
3. `deploy_all.sh` + shell wrapper + README skeleton.  
4. Script_00 + Script_01 + Script_02 green on RH fork.  

**Exit:** foundation artifacts exist; chain id 4663.

### Phase B — Assets & pools

1. Script_04 tokens + mints.  
2. Script_05 V3 pools + seed.  
3. Script_06 V4 pools + seed.  

**Exit:** acct1 holds TT balances; pools have liquidity.

### Phase C — SE + RP

1. Script_03 if not done (hook factory may be needed before hook packages only — can be Phase A).  
2. Script_07 V3 SE.  
3. Script_08 V4 SE.  
4. Script_09 RPs.  

**Exit:** SE exchangeIn smoke (optional cast/script assert); RP addresses non-zero.

### Phase D — Packages

1. Script_10 hook packages.  
2. Script_11 DETF children.  
3. Script_12 DETF packages.  

**Exit:** packages registered / code present in artifacts.

### Phase E — Demos

1. Script_13: Weighted \(n=8\) buffer + door seed (hardest).  
2. Single SE buffers.  
3. CP / Orbital / Weighted inert DETFs (gentle + launch-rich).  

**Exit:** all demo keys in `13_inert_demos.json`; no bond txs in traces.

### Phase F — Frontend export + loader

1. Script_14 export.  
2. Protocol package 4663 support.  
3. Regenerate chain overrides if required.  
4. Smoke: Node/TS import `getAddressArtifacts(4663)` or equivalent.  

### Phase G — Docs & inventory

1. Update `docs/DEPLOYMENT_SCRIPT_INVENTORY.md`.  
2. Finalize pipeline README.  
3. Cross-check PRD DoD checklist.

---

## 7. Coding constraints (non-negotiable)

| Rule | Detail |
|------|--------|
| No `new` SUT | CREATE3 / FactoryService / registry only |
| No hermetic Uni cores | RH pins only for V3/V4/Permit2 |
| No first bond | Grep scripts for `.bond(` — must be clean |
| No `via_ir` | default Foundry profile |
| Role names | `rateAsset`, `pairToken`, `standardExchangeVault`, … |
| Hook deploy | `deployHookVault` + mineNonce; no vault-factory salt for flags |
| DETF deploy | `indexedexManager.deployVault` / `deploy*DFPkg` |
| Superseded DETF | Do not import `detf/.../standardExchange/single/` tree |
| Compile risk | Split stages if stack-too-deep / import weight; never via_ir |
| Gas / time | Weighted \(n=8\) door seeding may be slow — use `--slow`; consider sub-calls |

---

## 8. Verification / DoD (agent must prove)

### 8.1 Automated / script-level

- [ ] `deploy_all.sh all --restart-anvil` completes exit 0.  
- [ ] `cast chain-id --rpc-url http://127.0.0.1:8545` → `4663`.  
- [ ] `cast code $POOL_MANAGER` non-empty (RH pin).  
- [ ] Artifacts `00`–`14` present under `deployments/anvil_robinhood_main/`.  
- [ ] `13_inert_demos.json` contains: weighted buffer n=8, 2× CP, 2× Orbital, 2× Weighted DETF, 2× single SE buffer.  
- [ ] UI wallet balances for TT0…TT7 ≥ mint amount.  
- [ ] `rg '\.bond\(' scripts/foundry/anvil_robinhood_main` → no matches (except comments).  
- [ ] Frontend `chain/4663/platform.json` exists with manager + packages + demos.  
- [ ] Protocol package resolves chain 4663 (test or small tsx smoke).  

### 8.2 Optional smoke (recommended, not UI E2E)

- [ ] `cast call` SE `previewExchangeIn` / vault token list non-empty.  
- [ ] Weighted buffer `n()` == 8 if view exists.  
- [ ] DETF view `isReserveLive` false or equivalent inert signal if available.

### 8.3 Manual UI (operator; not agent ship gate)

Document in README; do not block script DoD:

1. Point wallet RPC to Anvil, chain 4663.  
2. Import Anvil acct1.  
3. Discover DETFs / SEs from protocol package.  
4. First bond on gentle CP or Weighted in UI.

---

## 9. Risk register (implementor)

| Risk | Mitigation |
|------|------------|
| Weighted \(n=8\) OOG / timeout | Seed doors in loops with lower per-tx liquidity; split Script_13 into 13a/13b if needed |
| Hook mineNonce fails | Reuse TestBase mining util; store nonce in artifact |
| V3 fee tier missing on RH | Query factory; pick supported fee in Script_05 |
| Stack too deep in scripts | Internal helpers, fewer locals, split stages |
| SE package API mismatch | Strictly copy TestBase deploy sequence |
| Protocol types only know Sepolia/Base | Explicitly extend for 4663 (Phase F) |
| Product code incomplete for Weighted DETF n=8 | Stop and report; do not silently ship smaller n without PRD change |

---

## 10. Agent execution checklist

```text
[ ] Read PRD v0.3.1 D1–D16 and this plan §0–§3
[ ] Load skills: crane-deployment, indexedex-testing, indexedex-uniswap-v4-hook-packages
[ ] Phase A scaffold + 00–02
[ ] Phase B 04–06
[ ] Phase C 03 (if pending), 07–09
[ ] Phase D 10–12
[ ] Phase E 13 (no bond)
[ ] Phase F 14 + protocol 4663 loader
[ ] Phase G inventory + README
[ ] Run full `all --restart-anvil` clean
[ ] Prove DoD §8.1
[ ] Summarize artifacts + any deviations
```

---

## 11. Out of scope (do not implement under this plan)

- Public RH mainnet/testnet broadcast deploys  
- Scripted first bond / live DETF  
- Balancer V3 core on RH  
- Uni V2 SE as primary  
- Superseded listing DETF tree  
- Dual/quad stable hooks  
- Full UI first-bond E2E green  
- `via_ir`, mocks of SUT vaults/manager/registry  

---

## 12. Suggested commit cadence

1. `feat(deploy): anvil robinhood scaffold + foundation stages`  
2. `feat(deploy): TT0-7 + uni v3/v4 pools on RH fork`  
3. `feat(deploy): uni v3/v4 SE + rate providers`  
4. `feat(deploy): hook + detf packages`  
5. `feat(deploy): inert demos weighted n=8 + export chain/4663`  
6. `feat(protocol): chain 4663 address artifact loading`  
7. `docs: deployment inventory + anvil robinhood README`  

---

## 13. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-09 | Initial plan from Accepted PRD v0.3.1 for goal-agent execution |

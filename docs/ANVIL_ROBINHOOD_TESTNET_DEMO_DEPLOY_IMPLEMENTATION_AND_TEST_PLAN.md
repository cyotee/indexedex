# Implementation Plan: Anvil Robinhood Testnet (46630) live + launch-rich demo

**PRD (product law SoT):** [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) (**Accepted v2.0**, D1–D55)  
**This plan (implementor SoT once executing):** Foundry groups **00–09** + `Script_SimulateLaunch` (01–08) + shell orchestrator + `@indexedex/protocol` **46630** + DTF `/mint` and equal ten-DETF list  
**Date:** 2026-08-15  
**Status:** **READY FOR EXECUTION** (goal-command agent)

---

## Goal-command bootstrap (paste to a new agent)

```text
Implement docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md
against docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md v2.0.

Read both files fully before editing. PRD wins on product. This plan wins on
file map / phases / DoD. If a PkgArgs field is in neither, STOP and ask —
do not invent.

Scope: groups 00–09, SimulateLaunch 01–08, shell orchestrator
(local Anvil + --live public 46630), protocol 46630, DTF list + /mint.
NOT 4663 broadcast. NOT Balancer / pons / Uni V3.
NOT vm.warp. NOT FeeCollector push into TTRICH-S.
Do not edit anvil_robinhood_main / anvil_robinhood_fee_detf / chain/4663.

Skills: crane-deployment, crane-architecture, crane-testing,
indexedex-testing, indexedex-uniswap-v4-hook-packages.

Never `new` facets/DFPkgs. Never via_ir. DETF role names only.
Forge patience: first compile 20–40+ min is normal — do not kill.
Seed cache_forge/ + out/ from a warm checkout before first forge in a
new worktree (CLAUDE.md worktree compile seed).

Existing files under scripts/foundry/anvil_robinhood_testnet/ are
exploratory — reconcile to this plan; they are not accepted SoT.
```

---

## Authority

| Layer | Role |
|-------|------|
| **PRD v2.0** | Product/deploy requirements (D1–D55). Wins on conflict. Patch this plan. |
| **This plan** | File map, phases, gold paths, D42 Crane fix, DoD, agent checklist |
| **Family PRDs + shipped code** | Uni V4 DETF / hook / SE mechanics. Wins on package call shapes. |
| Skills | `crane-deployment`, `crane-architecture`, `crane-testing`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages`, `indexedex-ui-refactor` |
| Gold | Co-located `TestBase_UniswapV4*DETF.sol`, `TestBase_UniswapV4StandardExchange.sol`, hook TestBases, `scripts/foundry/local_testing/**`, `scripts/foundry/anvil_robinhood_main/**` (**copy patterns only**) |

### Process rules

1. If this plan and PRD disagree on **product**, **PRD wins** — patch this plan.  
2. If unspecified in PRD + this plan, **stop and ask** — do not invent product law.  
3. **Never** `new` facets/DFPkgs. Facets: CREATE3 + `*FactoryService`. Vaults / DETFs / hooks: `indexedexManager.deploy*DFPkg` / `deployVault` / `deployHookVault`.  
4. **Never** `via_ir`. Default Foundry profile.  
5. **Do** script first bond + D47 richness on all ten DETFs.  
6. **Do not** `vm.warp` to mature bonds. **Do not** `pushSingleTokenFee` / donate into `TTRICH-S`.  
7. **Do not** edit `anvil_robinhood_main/` or `anvil_robinhood_fee_detf/`. **Do not** overwrite `chain/4663/`.  
8. Broadcast as `DEPLOYER_ADDRESS` (`forge --sender`; cast wallet signs). Local Anvil or `--live` public 46630. Never `--private-key`. Never `--unlocked`.  
9. Role names only: `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool`, `rebasingClaimToken`.  
10. Production-first: no mocks of SUT (vaults, DETF, manager, registry, fee oracle, facets, DFPkgs).  
11. Forge cold compile commonly takes **20–40+ minutes**. Wait for process exit. Seed `cache_forge/` + `out/` from a warm checkout before the first forge in a new worktree.

---

## 1. Goal for the executing agent

Deliver a green local path:

```bash
# Repo root = lib/indexedex
export ALCHEMY_KEY=...
export DEPLOYER_ADDRESS=0x...

bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil
# wait for [SUCCESS]

cast chain-id --rpc-url http://127.0.0.1:8545   # must print 46630

# DTF (port 3002) against the same Anvil:
#   NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_testnet \
#   NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545 \
#   npm run dev -w @indexedex/app-dtf
```

**Result:**

1. Anvil forking Robinhood **Testnet** at chain id **46630**.  
2. Groups **01–09** deployed: platform, 13 `TT*` + facade, leaf/nest/fee-sink, **ten live + launch-rich DETFs**, frontend `chain/46630/` export.  
3. Every DETF: `isReserveLive() == true` and D47 (all-legs mint-open, S ≥ 1.1e18).  
4. Artifacts under `deployments/anvil_robinhood_testnet/`.  
5. Replay `01`…`09` after an Anvil reset restores the prefix.  
6. `@indexedex/protocol` resolves **46630**. DTF lists all **ten** DETFs equally. `/mint` offers the **14** stand-ins only (not faucet stocks).  
7. Fees sit on FeeCollector. No push into `TTRICH-S`. No time warp. Public 46630 via `--live` + `DEPLOYER_ADDRESS`.

---

## 2. Accounts, env, pins

| Role | Address |
|------|---------|
| Deployer / owner / SENDER / first-bonder | `DEPLOYER_ADDRESS` (required; no Anvil #0 default) |
| UI wallet | `UI_WALLET` or `DEPLOYER_ADDRESS` |

| Env | Value |
|-----|--------|
| `RPC_URL` | Local default `http://127.0.0.1:8545`. `--live` uses public `robinhood_testnet`. |
| Chain id | **46630** |
| Fork alias | **`robinhood_testnet_alchemy`** → fallback `robinhood_testnet` |
| `ANVIL_FORK_BLOCK_NUMBER` | After D35: `ROBINHOOD_TESTNET.DEFAULT_FORK_BLOCK` (bump to a known-good recent 46630 head at first implement) |
| `OUT_DIR_OVERRIDE` | `deployments/anvil_robinhood_testnet` |
| `FORCE` | `1` to ignore resume JSON |
| Anvil flags | `--chain-id 46630` · `--disable-code-size-limit` · fork URL + block |

**Required pins** (must have code; never redeploy): PRD §5.3 — WETH, Permit2, Uni V4 PoolManager / PositionManager / Universal Router. Do **not** require Uni V3, pons, USDG, Balancer, mainnet WETH.

Import `ROBINHOOD_TESTNET` from Crane. Do not hardcode production addresses except via that library.

---

## 3. Directory / file map

```text
scripts/foundry/anvil_robinhood_testnet/
  README.md                         # rewrite to PRD v2.0 (today still says v0.4 / inert / 01–03)
  DeploymentBase.sol                # chain id 46630, OUT_DIR, broadcast guard
  RobinhoodCanonicalLib.sol         # required pins only
  FixtureEconomics.sol              # ALL numeric locks from PRD §2 / §2.8 (see §4)
  LaunchState.sol / LaunchIo.sol    # resume JSON
  Stage_00_Preflight.sol
  Stage_01_Factories.sol
  Stage_02_Platform.sol             # MUST add D46/D52/bond terms (missing today)
  Stage_03_UniV4Packages.sol
  Stage_04_Tokens.sol               # NEW
  Stage_05_LeafPoolsAndSEs.sol      # NEW
  Stage_06_LeafDETFs.sol            # NEW — deploy + first-bond + D47
  Stage_07_NestDETFs.sol            # NEW
  Stage_08_FeeSink.sol              # NEW
  RichnessLib.sol                   # NEW — D47 loop (preview, swap pair→DETF, assert)
  Script_00_Preflight.s.sol
  Script_01_Factories.s.sol
  Script_02_Platform.s.sol
  Script_03_UniV4Packages.s.sol
  Script_04_Tokens.s.sol            # NEW
  Script_05_LeafPoolsAndSEs.s.sol   # NEW
  Script_06_LeafDETFs.s.sol         # NEW
  Script_07_NestDETFs.s.sol         # NEW
  Script_08_FeeSink.s.sol           # NEW
  Script_09_ExportFrontend.s.sol    # NEW
  Script_SimulateLaunch.s.sol       # CHANGE: 01–08 in one broadcast (today 01–03)
  deploy_all.sh                     # NEW

scripts/shell/anvil_robinhood_testnet.sh

deployments/anvil_robinhood_testnet/
  00_preflight.json … 09_export.json

frontend/packages/protocol/src/addresses/chain/46630/
  platform.json
  base-tokens.tokenlist.json
  strategy-vaults.tokenlist.json
  protocol-detfs.tokenlist.json
  featured-fee-detfs.tokenlist.json   # tokens: []  (D49)

frontend/packages/protocol/src/
  addresses/index.ts
  addressArtifacts.ts
  runtimeChains.ts
  chainPlatformOverrides.generated.ts

frontend/apps/dtf/                    # 46630 consume path

lib/crane/contracts/tokens/ERC20/
  ERC20MinterFacadeTarget.sol       # D42 fix
  ERC20MinterFacadeRepo.sol         # D42 key (token, recipient)
```

**Exploratory code on disk is not SoT.** Reuse structure (Stage libraries + thin scripts + resume JSON). **Must fix** before treating 00–03 as done:

| Today | Required |
|-------|----------|
| `FixtureEconomics.DEFAULT_MIN_LOCK = 30 days` | **`86400`** (PRD D5 / D38) |
| `DEFAULT_MAX_LOCK = 180 days` | keep |
| Stage_02: no fee / bond / liquid setters | D46 usage `5e16`, dex `3e14`; D51 seigniorage `5e16`; D52 liquid `0.2e18` on Uni V4 SE liquid-reserve iface; bond terms min `86400` / max `180 days` |
| `Script_SimulateLaunch` = 01+02+03 | **01–08** |
| README v0.4 / “later inert DETFs” | live + D47; 00–09 + DTF |

**Do create** `deploy_all.sh` + `scripts/shell/anvil_robinhood_testnet.sh`. Copy `anvil_robinhood_main/deploy_all.sh` patterns: `--restart-anvil`, `--force`, `--dry-run`, commands `all` / `foundation` (00–03) / `assets` (04) / `pools` (05) / `leaves` (06) / `nests` (07) / `feesink` (08) / `export` (09) / `stageNN`. Alias `robinhood_testnet_alchemy` then `robinhood_testnet`. Anvil node: `--chain-id 46630 --disable-code-size-limit`. Broadcast as `DEPLOYER_ADDRESS` (`--sender`; cast wallet) on localhost and on `--live`.

**Reuse (do not rewrite):**

| Pattern | Source |
|---------|--------|
| Artifact resume / JSON IO | existing `LaunchIo.sol` + `local_testing/shared/LocalTestingDeploymentBase.sol` |
| CREATE3 / manager / hook factory | existing Stage_01 / Stage_02 + `IndexedexManagerFactoryService` |
| Hook DFPkg deploy | skill `indexedex-uniswap-v4-hook-packages` + hook TestBases |
| Uni V4 SE `deployVault(poolKey, widthMultiplier)` | `TestBase_UniswapV4StandardExchange` — **`widthMultiplier = 1`** |
| DETF `deployVault(PkgArgs)` | co-located `TestBase_UniswapV4*DETF.sol` |
| Token + facade authorize | archived `scripts/archive/foundry/sepolia/Script_07_DeployTestTokens.s.sol` |
| V4 pool init + seed | existing 4663 lab seeder / TestBase (`tickSpacing = 60`, 1:1 mid) |
| First bond | family `bond(pairToken, amount, 86400, #0, false, deadline)` |
| Reserve swap (D47) | family reserve-hook swap / DETF quote path used in `*_PriceMovement.t.sol` |

---

## 4. FixtureEconomics (copy these constants — do not invent)

```text
SALT_NS                  = "RhTestnet"
MIN_LOCK                 = 86400
MAX_LOCK                 = 180 days
USAGE_FEE                = 5e16          // 5%
DEX_SWAP_FEE             = 3e14          // 0.03%
SEIGNIORAGE              = 5e16          // 5% product default
V4_LIQUID_RESERVE        = 0.2e18
SE_WIDTH_MULTIPLIER      = 1
CLAIM_WIDTH_MULTIPLIER   = 1
// caller premines via UniswapV4DetfHookPremineLib; nonce is not a FixtureEconomics constant
CREATION_PAIR_PER_DETF   = 1e18
MINT_THRESHOLD           = 1.05e18
BURN_THRESHOLD           = 0.95e18
THRESHOLD_MODE           = Policy (0)
EXPANSION_EPOCH          = 0             // → 8h
EXPANSION_R              = 0             // → 10%/yr
EXPANSION_CATCHUP        = 0             // unlimited
BASE_AMP                 = 100           // both Quads
ORBITAL_DETF_BINDING     = 2
DETF_WEIGHT              = 0.2e18        // both Weighted
RICH_TARGET              = 1.1e18        // D47 mint-open (Policy 1.05); not 10.5e18
FACADE_MAX_MINT          = 10_000_000e18
FACADE_MIN_INTERVAL      = 0
PREMINT                  = 1e12 ether    // whole units, 18 dec
POOL_FEE                 = 3000          // 0.30%
POOL_TICK_SPACING        = 60
POOL_SQRT_PRICE          = TickMath.getSqrtPriceAtTick(0)
TT_TT_SEED               = 1e9 ether
WETH_POOL_SEED           = 100 ether each side
LEAF_FIRST_BOND          = 10 ether per external
  except TTDOL-Q         = 10 ether per external (TTUSDE, TTUSDG, WETH)
NEST_FIRST_BOND          = 10_000 ether per inner
TTRICH_FIRST_BOND        = 10 ether WETH
INVENTORY_STARTER        = 100_000 ether  // then loop to RICH_TARGET
SWAP_MIN_OUT             = 1
```

**Mag7 pair weights (NVDA-first, already 80%):**

| pair | WAD |
|------|-----|
| TTNVDA | `184000000000000000` |
| TTMSFT | `160000000000000000` |
| TTAAPL | `144000000000000000` |
| TTGOOGL | `96000000000000000` |
| TTAMZN | `96000000000000000` |
| TTMETA | `72000000000000000` |
| TTTSLA | `48000000000000000` |

**Nest pair weights:** S, O, Q, W each `200000000000000000`.

**13 group-04 tokens** (name / symbol): PRD §2.1 table. **`TTRICH` / Test Token RICH** in group 08. All 18 decimals.

**DETF + claim names:** PRD §2.6. **SE names:** PRD §2.6 SE table.

**PkgArgs wiring:** PRD §2.8 — copy that table. `vaultShares[i] = address(0)` when SE set.

---

## 5. Phase 0 — Crane facade D42 (blocker for group 04)

**Today:** `ERC20MinterFacadeTarget.mintToken` reads `lastMintTimestamps` by **token** and writes by **recipient**. Repo mapping is `mapping(address => uint256)`.

**Required:**

1. Repo: `mapping(address token => mapping(address recipient => uint256)) lastMintTimestamps` (or equivalent composite key).  
2. Target: **both** read and write key **`(token, recipient)`**.  
3. Update Crane facade unit tests that assume the old key.  
4. Land this **before** Script_04. Interval is 0 on this fork (hides the bug); still ship the fix.

Do not change IndexedEx DETF product code.

---

## 6. Implementation phases (execute in order)

### Phase A — Reconcile 00–03 to PRD

1. D35: bump `ROBINHOOD_TESTNET.DEFAULT_FORK_BLOCK` to a known-good recent 46630 head; record the number in README + `00_preflight.json`.  
2. Fix `FixtureEconomics` to §4.  
3. Stage_02: `setDefaultUsageFee(5e16)`, `setDefaultDexSwapFee(3e14)`, `setDefaultSeigniorageIncentivePercentage(5e16)`, `setDefaultLiquidReservePercentageOfTypeId(IUniswapV4StandardExchangeLiquidReserve, 0.2e18)`, `setDefaultBondTerms({min: 86400, max: 180 days})`.  
4. Preflight: required pins only (PRD §5.3). Fail if Uni V3 / pons / Balancer are *required*.  
5. Prove `Script_00`…`Script_03` + replay `01` then `02` after Anvil reset.

**Exit:** `01_factories.json`, `02_platform.json`, `03_univ4_packages.json`. Hook factory wired. Curve Quad hook + DETF **packages** exist. No instances.

### Phase B — Group 04 tokens + facade

1. Deploy 13 Operable mintable ERC-20s (§2.1).  
2. Deploy facade DFPkg (`maxMintAmount=10_000_000e18`, `minMintInterval=0`).  
3. `setOperatorFor(mint.selector, facade, true)` on each token.  
4. Mint `1e12` whole units of each to #0 and #1. Leave facade on.  
5. Export `erc20MinterFacade` + token addresses.

**Exit:** #0 and #1 hold 1e12 of each of the 13. Facade address in `04_tokens.json`.

### Phase C — Group 05 leaf pools + SEs

Create and seed (PRD §2.5):

| Pool | Seed |
|------|------|
| TTNVDA / TTUSDG | 1e9 / 1e9 |
| TTSPY / TTUSDG | 1e9 / 1e9 |
| TTUSDG / TTUSDE | 1e9 / 1e9 |
| TTUSDE / WETH | 100 / 100 WETH |
| TTUSDG / WETH | 100 / 100 WETH |

Fee 3000, tick 60, 1:1 mid. Wrap **enough** WETH on #0 (pools + later TTDOL/TTRICH first-bond + D47 — do not cap at 300).

Deploy Uni V4 SE on each pool: `deployVault(poolKey, 1)`. Names D53. RP on each: shares → that leg’s `pairToken` (PRD §2.3 / §2.8). TTDOL-Q RPs: `seUsdeWeth` → `TTUSDE`, `seUsdgUsde` → `TTUSDG`, `seUsdgWeth` → WETH. Do **not** point `seUsdgUsde` at WETH — that SE does not hold WETH.

**Exit:** five SEs + five RPs in `05_leaf_pools_ses.json`.

### Phase D — Group 06 five leaf DETFs + first-bond + D47

Deploy via registry `deployVault` with §2.8 PkgArgs (rows 1, 2, 3, 4, 9). Then:

1. First-bond each (PRD §2.7 leaf table). Lock `86400`. `capitalToken` = SE-leg pair.  
2. Assert `isReserveLive()`.  
3. Inventory starter 100_000 then **D47 loop** (`RichnessLib`): swap each external pair → detfToken on that reserve until `syntheticVs(pair) ≥ 10.5e18` (CP: `syntheticPrice()`) **and** mint allowed. `minOut = 1`.  
   - TTNVDA-S: TTNVDA  
   - TTNVDA-SMH-O: TTNVDA **and** TTSMH  
   - TTIDX-Q: TTSPY, TTVTI, TTQQQ  
   - TTM7-W: all seven Mag7  
   - TTDOL-Q: TTUSDE, TTUSDG, WETH  
4. Keep S/O/Q/W `detfToken` balances on #0 for nests.  
5. Deploy per-instance rebasing claim (D55 names, `widthMultiplier=1`, owner=DETF).

**Exit:** five live + all-legs-rich leaf DETFs. `06_leaf_detfs.json`.

### Phase E — Group 07 four nest DETFs + first-bond + D47

1. Create empty pools `TTM7-W`/`TTUSDG` and `TTIDX-Q`/`TTUSDG` (0.30% / tick 60). Do **not** seed.  
2. SE + RP on each (D53 names). Shared: nest #5, #6, #8 use the **same** W/TTUSDG SE.  
3. Deploy nest DETFs §2.8 rows 5–8.  
4. First-bond (10_000 each inner). If #0 is short inner `detfToken`, **repeat the corresponding leaf swap** — no other capital source.  
5. D47 on every external inner pair.  
6. Claim tokens D55.

**Exit:** four live + all-legs-rich nests. `07_nest_detfs.json`.

### Phase F — Group 08 TTRICH + fee-sink + first-bond + D47

1. Deploy `TTRICH` / Test Token RICH / 18 dec. Authorize facade. Mint 1e12 to #0 and #1.  
2. Pool `TTRICH`/WETH 0.30% / tick 60, seed 100/100. SE + RP → TTRICH.  
3. Deploy `TTRICH-S` §2.8 row 10. First-bond **10 WETH**. D47 on WETH.  
4. **Do not** `pushSingleTokenFee` / donate into `TTRICH-S`.

**Exit:** `08_fee_sink.json`. Ten DETFs live + rich.

### Phase G — SimulateLaunch 01–08 + shell

1. `Script_SimulateLaunch` runs Stage_01 … Stage_08 in **one** `vm.startBroadcast`. No `vm.prank`. Group **09** is export-only and is **not** inside SimulateLaunch (no on-chain txs).  
2. Omit `--broadcast` = gas estimate.  
3. `deploy_all.sh` + `scripts/shell/anvil_robinhood_testnet.sh` (see file map).  
4. Rewrite README (PRD v2.0, Anvil flags, replay, D47, DTF env).  
5. Clean replay: `--restart-anvil` then `01`…`09`.

### Phase H — Group 09 export + protocol 46630 + DTF

**Do not overwrite `chain/4663/`.** New tree only: `frontend/packages/protocol/src/addresses/chain/46630/`.

#### H1 — `Script_09_ExportFrontend`

Write (same Token List / platform schema as `chain/4663/`):

| File | Contents |
|------|----------|
| `platform.json` | `chainId: 46630`, WETH, Permit2, Uni V4 pins, manager, feeCollector, hookFactory, **`erc20MinterFacade`**, 14 stand-in addresses, 8 SE addresses, **ten** DETF addresses, deployer, uiWallet |
| `base-tokens.tokenlist.json` | 14 `TT*` tagged `token` + `testToken`; official WETH tagged `weth` (not `testToken`); five faucet stocks tagged **`rh-faucet` only** (PRD D43). `chainId: 46630` |
| `strategy-vaults.tokenlist.json` | Eight SEs (D53 names), tags `vault` / `se` |
| `protocol-detfs.tokenlist.json` | **All ten** DETFs, equal, tags `vault` + `detf`. **No** `fee-detf` featured tag. Order = PRD §2.6 table (1–10) |
| `featured-fee-detfs.tokenlist.json` | `{ "tokens": [] }` — D49 no featured DETF |

Faucet stock addresses: `ROBINHOOD_TESTNET.FAUCET_*` (TSLA, AMZN, PLTR, NFLX, AMD). Official WETH: `ROBINHOOD_TESTNET.WETH`.

Then: `cd scripts/node && npm run build-tokenlists` so `chainPlatformOverrides.generated.ts` picks up `46630`.

#### H2 — Protocol package (first-class 46630)

Mirror how 4663 is wired; **do not remap 46630 → 4663**.

1. `CHAIN_ID_ROBINHOOD_TESTNET = 46630` beside `CHAIN_ID_ROBINHOOD = 4663`.  
2. `CanonicalArtifactChainId` includes 46630.  
3. `DeploymentEnvironment` adds `'anvil_robinhood_testnet'`.  
4. `ARTIFACT_REGISTRY.anvil_robinhood_testnet[46630]` bundle from the new JSON (tokens / protocolDetf / strategyVaults; empty balancer / uniV2 / aerodrome).  
5. `resolveArtifactsChainId(46630)` → `46630`. Never Sepolia, never 4663.  
6. `getAddressArtifacts(46630)` prefers `anvil_robinhood_testnet` then chain override. Error text lists 46630.  
7. `runtimeChains.ts`: `robinhoodTestnet` (public RPC + explorer from PRD §1) and `robinhoodTestnetAnvil(rpcUrl)` (localhost). `resolveAppChain(46630, localRpc)` uses the Anvil variant when a local RPC is set.  
8. DTF / protocol network selection: 46630 is selectable. Default for this rehearsal: `NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_testnet`.  
9. Wagmi: when that env is selected, route 46630 to `NEXT_PUBLIC_LOCAL_RPC_URL` (default `http://127.0.0.1:8545`).  
10. Port **3002** (`frontend/apps/dtf`). Do not add a second app.

#### H3 — DTF surfaces (D34, D49)

1. DETF list / portfolio / staking pickers read `protocol-detfs` — **ten rows, equal**. No featured-fee hero.  
2. `/mint` uses `isTestTokenEntry` (name `/test token/i` **or** symbol `/^TT[A-Z0-9]+$/`). Must list the **14** stand-ins. Must **not** list WETH or faucet stocks.  
3. Wallet add-network for Anvil: RPC `http://127.0.0.1:8545`, chain id **46630**, currency ETH.  
4. Smoke: app boots; connected on 46630 Anvil; ten DETFs visible; `/mint` shows 14 test tokens. Playwright against 46630 is in-scope if the 4663 e2e helpers exist — add `E2E_CHAIN_ID=46630` path, do not break 4663 defaults.

#### H4 — Docs

Add family section to `docs/DEPLOYMENT_SCRIPT_INVENTORY.md`. README: how to run DTF on the fork.

---

## 7. D47 richness loop (normative)

```text
function enrich(detf, pairTokens[]):
  for pair in pairTokens:
    while syntheticVs(detf, pair) < 10.5e18
       or not isMintingAllowed(detf, pair):   // CP: syntheticPrice / isMintingAllowed()
      preview = quote pair → detfToken on reserve (family path)
      swap pair → detfToken, minOut = 1
      if preview == 0: STOP and report (do not invent another path)
  assert isReserveLive
  assert all listed pairs ≥ 10.5e18 and mint-open
```

Do **not** native-V4 donate. Do **not** ERC-20-push surplus onto the hook. Do **not** hardcode a final swap size (5% seigniorage + 5% usage move the tape).

Cap iterations at a high bound (e.g. 64 per pair) and revert with a clear error if still below target — then inspect, do not silently ship.

---

## 8. Coding constraints

| Rule | Detail |
|------|--------|
| No `new` SUT | CREATE3 / FactoryService / registry / `deployHookVault` |
| No hermetic Uni cores | 46630 pins only |
| `via_ir` | forbidden |
| First bond | **required** on all ten |
| Time warp | **forbidden** |
| Fee push to TTRICH-S | **forbidden** |
| Balancer / pons / Uni V3 | **forbidden** |
| Public broadcast | **`--live` + `DEPLOYER_ADDRESS`**. Cast wallet signs. Local default is Anvil fork. |
| Group 09 / `chain/46630/` | **required** — new tree only; never overwrite `chain/4663/` |
| 4663 lab / `chain/4663/` | do not touch |
| Role names | PRD D25 |
| Hook deploy | `deployHookVault` + mineNonce (`0` = auto) |
| DETF deploy | `indexedexManager.deployVault` after `deploy*DFPkg` |
| Compile | split stages if stack-too-deep; never via_ir |
| Tests | production-first; no mocks of SUT |

---

## 9. Verification / DoD (agent must prove)

### 9.1 Script-level

- [ ] `cast chain-id` → `46630`.  
- [ ] `cast code` WETH / Permit2 / PoolManager non-empty (RH pins).  
- [ ] Artifacts `00`–`09` present under `deployments/anvil_robinhood_testnet/`.  
- [ ] 13 group-04 tokens + `TTRICH` + `erc20MinterFacade` in JSON.  
- [ ] Ten DETF addresses in `06`/`07`/`08` JSON.  
- [ ] Each DETF `isReserveLive() == true`.  
- [ ] Each DETF D47: all-legs synthetic ≥ `10.5e18` and mint open.  
- [ ] `FeeCollector` holds usage/dex fees if any accrued; **no** scripted push into `TTRICH-S`.  
- [ ] `rg 'vm.warp' scripts/foundry/anvil_robinhood_testnet` → no maturity warps.  
- [ ] `rg 'pushSingleTokenFee|new UniswapV4|via_ir' scripts/foundry/anvil_robinhood_testnet` → clean.  
- [ ] SimulateLaunch without `--broadcast` completes (gas).  
- [ ] Fresh Anvil + replay `01`…`09` restores prefix.  
- [ ] `chain/46630/` has platform + four tokenlists. `featured-fee-detfs` tokens empty.  
- [ ] `protocol-detfs` has **ten** entries, no featured tag.  
- [ ] `base-tokens`: 14 `testToken`s; WETH is `weth` only; faucet stocks are `rh-faucet` only.  
- [ ] `getAddressArtifacts(46630)` resolves (protocol package unit/smoke).  
- [ ] `git diff` does not touch `anvil_robinhood_main/`, `anvil_robinhood_fee_detf/`, `chain/4663/`.

### 9.2 `cast` + DTF smoke (required)

- [ ] Facade `mintToken` to #1 succeeds for `TTUSDG`.  
- [ ] `isMintingAllowed` / `isMintingAllowed(pair)` true on a leaf and a nest.  
- [ ] DTF on port 3002 with `anvil_robinhood_testnet` + local RPC: wallet on 46630; **ten** DETFs listed equally; `/mint` shows **14** stand-ins and not faucet stocks / WETH.  
- [ ] Official WETH `balanceOf(#0)` after wrap covers remaining D47 headroom.

### 9.3 Not a ship gate (operator later)

- Bond maturity / claim (no warp).  
- Public 46630.  
- Full Playwright money-path suite (add `E2E_CHAIN_ID=46630` helpers if cheap; do not block on a green 4663 e2e rewrite).

---

## 10. Risk register

| Risk | Mitigation |
|------|------------|
| D47 never reaches 10.5 (depth / fee) | Loop on preview; increase pair size geometrically; stop with error after cap |
| Multi-leg mint open on SE door only | Assert **every** external pair (PRD D47) |
| WETH wrap shortfall | Wrap lazily in RichnessLib / Stage_08; no 300 cap |
| Hook mineNonce / flag mismatch | Copy TestBase miner; store nonce in artifact |
| Stack too deep in Stage_06/07 | Split helpers; one DETF function each |
| Facade D42 regresses Crane tests | Run Crane facade unit tests after the key change |
| Cold forge “hang” | Do not kill; seed `cache_forge/` + `out/` |
| Exploratory 00–03 drifts from PRD | Phase A reconcile is mandatory before 04 |

---

## 11. Agent execution checklist

```text
[ ] Read PRD v2.0 D1–D55 + §2.7 / §2.8
[ ] Read this plan §0–§9
[ ] Load skills: crane-deployment, indexedex-testing, indexedex-uniswap-v4-hook-packages, indexedex-ui-refactor
[ ] Seed cache_forge/ + out/ if new worktree
[ ] Phase 0 — D42 Crane facade (token, recipient)
[ ] Phase A — reconcile 00–03 (fees, bond 86400, liquid 20%, fork pin)
[ ] Phase B — 04 tokens + facade
[ ] Phase C — 05 leaf pools/SEs
[ ] Phase D — 06 leaf DETFs + first-bond + D47
[ ] Phase E — 07 nests + first-bond + D47
[ ] Phase F — 08 TTRICH + fee-sink + first-bond + D47
[ ] Phase G — SimulateLaunch 01–08 + shell + README
[ ] Phase H — 09 export + protocol 46630 + DTF list + /mint
[ ] Prove DoD §9.1 + §9.2
[ ] Summarize artifacts + any PRD deviations (must be none, or stop)
```

---

## 12. Out of scope (PRD non-goals — not a slice)

These are **product non-goals**, not deferred work:

- Public broadcast to live 46630 or 4663  
- `vm.warp` to unlock bonds / scripted sell→claim  
- FeeCollector → `TTRICH-S` push (D37)  
- Balancer, pons, Uni V3 on 46630  
- Extra leaf/nest books beyond D27+D26+D30+D36  
- Editing `anvil_robinhood_main` / `anvil_robinhood_fee_detf` / `chain/4663/`  
- Changing DETF / SE **product** behavior (D42 Crane facade is the only allowed adjacent fix)  
- Fabricated APY / USD in UI or README  

---

## 13. Suggested commit slices (not required)

1. `crane:` D42 facade `(token, recipient)` + tests  
2. `scripts:` Phase A 00–03 reconcile + FixtureEconomics  
3. `scripts:` 04 tokens + facade  
4. `scripts:` 05 leaf pools/SEs  
5. `scripts:` 06 leaf DETFs + richness lib  
6. `scripts:` 07 nests  
7. `scripts:` 08 fee-sink  
8. `scripts:` SimulateLaunch 01–08 + shell + README  
9. `frontend:` 09 export + protocol 46630 + DTF list + `/mint`  

---

**Next for the operator:** point a new agent at this file with the goal-command bootstrap block. Groups 00–09, SimulateLaunch, local Anvil rehearsal, and `--live` public 46630 are in scope.

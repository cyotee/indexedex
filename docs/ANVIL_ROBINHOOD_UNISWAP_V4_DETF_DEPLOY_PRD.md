# PRD: Anvil Robinhood-Fork Deploy for Uniswap V4 DETFs + Hooks

**Status:** **Accepted v0.3.1** — requirements locked; implementation plan ready for `/goal`  
**Date:** 2026-08-09  
**Owner surface:** Foundry deploy scripts + shell orchestrator + UI address/tokenlist artifacts  
**Related:**

| Doc / path | Role |
|------------|------|
| **[Implementation plan](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md)** | **Implementor SoT** (phases, file map, fixture graph, DoD) |
| [`docs/ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md) | L2-E product intent (not script law) |
| [`docs/LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) §2.9 / Phase L2-E | Eng BOM for chain 4663 |
| [`docs/ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md`](./ANVIL_LOCAL_TESTING_SCENARIOS_PRD.md) | Sibling local-testing model (Sepolia-oriented foundation) |
| [`docs/DEPLOYMENT_SCRIPT_INVENTORY.md`](./DEPLOYMENT_SCRIPT_INVENTORY.md) | Existing script families |
| Crane `ROBINHOOD_MAIN.sol` / `ROBINHOOD_TESTNET.sol` | **Canonical external addresses** |
| Family PRDs under `contracts/vaults/detf/protocols/dexes/uniswap/v4/**` | DETF product + PkgArgs law |
| SE packages under `contracts/protocols/dexes/uniswap/v3/` and `…/v4/` | Uni V3 / V4 Standard Exchange vaults |
| Hook PRDs under `contracts/hooks/uniswap/v4/**` | Hook product + deploy path |
| Skill `indexedex-uniswap-v4-hook-packages` | Hook factory / `deployHookVault` law |
| Skills `crane-deployment`, `indexedex-testing` | CREATE3 / registry / production-first |

---

## 0. One-line goal

Ship a **resumable Anvil deploy pipeline** that **forks Robinhood Chain mainnet with chain ID `4663`**, deploys **all Uniswap V4 DETF packages** under `contracts/vaults/detf/protocols/dexes/uniswap/v4/` and **the hooks they depend on** (plus Single SE Buffer + full **Weighted \(n=8\)** route surface), wraps **eight mintable test tokens** in **Uniswap V3 and Uniswap V4 Standard Exchange vaults** against **Robinhood canonical Uni V3/V4 cores**, deploys **gentle + launch-rich inert** DETF demos, funds the **UI wallet**, and exports addresses to **`chain/4663/`** so the **UI can buy the first bond** and exercise weighted multi-door routes.

---

## 0.1 Locked decisions

| # | Decision | Status |
|---|----------|--------|
| D1 | **Test tokens only** for fixture legs (mintable ERC-20s). Freely mint what UI wallets need. Do not depend on RH stock tokens or restricted assets for the happy path. | **Locked** |
| D2 | Anvil **must** run as Robinhood chain ID **`4663`** (not 31337). | **Locked** |
| D3 | **Superseded listing DETF** (`…/standardExchange/single/` DETF tree) is **out of required BOM** (see §0.2 glossary). | **Locked (out)** |
| D4 | Scripts **do not** open / buy first bonds. Deploy **inert** DETF instances only. Fund test wallet(s) with ample mintable tokens; first bond is a **UI test**. | **Locked** |
| D5 | Deploy **both gentle and launch-rich** inert demo instances per required DETF family (see §0.3). | **Locked (both)** |
| D6 | Backing SE surface is **Uniswap V3 SE** + **Uniswap V4 SE** vault packages (not Uni V2 for this pipeline). Launch path wraps V3 and V4 pools. | **Locked** |
| D7 | Frontend artifacts: **`frontend/packages/protocol/src/addresses/chain/4663/` only** (no named `anvil_robinhood_main/` profile folder). | **Locked** |
| D8 | Shell entrypoints: **`scripts/foundry/anvil_robinhood_main/deploy_all.sh`** primary **+** thin **`scripts/shell/anvil_robinhood_main.sh`** wrapper. | **Locked** |
| D9 | Fixture set: **eight mintable tokens** (`TT0`…`TT7`) sized so UI can exercise **trade routes across all Weighted buffer doors** (see §6.2). | **Locked** |
| D10 | Fork block: **`ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`** unless `ANVIL_FORK_BLOCK_NUMBER` overrides. | **Locked** |
| D11 | Wallets: Anvil **account(0) = deployer/owner**; **account(1) = UI test wallet**. Mint **~1e12 whole units** (scaled by decimals) of each test token to **both**. | **Locked** |
| D12 | **Weighted Buffer \(n=8\) and Weighted DETF \(n=8\)** (gentle + launch-rich) are both required. DETF \(n=8\) = DETF self-leg + **7** external `TT` legs. | **Locked** |
| D13 | Multi-leg Weighted surfaces use **mixed SE**: **≥1 V3 SE leg and ≥1 V4 SE leg** on the \(n=8\) bindings. | **Locked** |
| D14 | **Rate provider on every SE-buffered leg** (SE shares → that leg’s `pairToken`). Bare legs: RP = 0. | **Locked** |
| D15 | Frontend scope: **artifacts under `chain/4663/` + minimal `@indexedex/protocol` loader** so any app can select chain 4663 / local Anvil RPC. Not full first-bond UI green. | **Locked** |
| D16 | Primary consumer: **any app via `@indexedex/protocol` + `chain/4663`** (not a single app DoD). | **Locked** |

---

## 0.2 Glossary — “superseded listing DETF”

There are **two different product trees** under Uni V4 DETF:

| Tree | Path | What it is |
|------|------|------------|
| **Current gold families** | `…/standardExchange/constantProduct/single/`, `…/orbital/`, `…/weighted/` | True DETFs whose **reserve** is an SE Buffer **hook** (CP / Orbital / Weighted) on Uni V4 |
| **Listing-family draft (superseded)** | `…/standardExchange/single/` (`UniV4SingleStandardExchangeDETF_*`) | Older design: DETF **lists** itself on a Uni V4 pool with **`hooks = address(0)`**, bond NFT owns OOR positions, rebasing claim manages listing LP. CP family PRD explicitly says this tree is **superseded** — do not extend it as the product path |

**“Superseded listing DETF”** = that older `standardExchange/single/` DETF package, **not** the Single SE **Buffer hook** at `contracts/hooks/uniswap/v4/standardExchange/single/` (which **is** in scope).

| In scope | Out of scope |
|----------|--------------|
| Hook: `hooks/…/standardExchange/single/` (wrap/unwrap buffer) | DETF: `detf/…/uniswap/v4/standardExchange/single/` (listing-family draft) |
| DETFs: CP / Orbital / Weighted | — |

---

## 0.3 Glossary — “gentle vs launch-rich”

These are **natural expansion / Policy templates** set at DETF deploy via `PkgArgs` (immutable after deploy). They are **not** bond purchase modes.

| Template | Typical `PkgArgs` resolve | Product intent |
|----------|---------------------------|----------------|
| **Gentle** | `expansionEpochLength = 0` → **8h**; `expansionClosureRatePerYearWad = 0` → **10%/yr** premium closure | Slow peg walk; peer-like policy for normal instances |
| **Launch-rich** | Explicit high `R` (e.g. `4.4e18` ≈ close premium ~1y from very rich synthetic) + same or shorter epoch | Instance can sit **well above peg** after first bond; high **token** expansion APY while rich; dilutes toward peg over months–~1 year |

Family PRDs (e.g. Uni V4 CP DETF §10) treat both as equal-priority **test matrix** rows. For **this deploy PRD** (**D5 locked**):

- Scripts deploy **two inert demo instances per required family**: one **gentle**, one **launch-rich** (PkgArgs from family PRD / TestBase templates).  
- Scripts **do not** first-bond either template (UI does first bond).  
- Artifacts must label instances clearly (e.g. `cpDetfGentle`, `cpDetfLaunchRich`).

---

## 1. Problem statement

We can already:

- Run hermetic / fork **tests** for Uni V4 hooks and DETFs (TestBases + `test/foundry/fork/robinhood_4663/**`).
- Run staged Anvil deploys for **Base** (`anvil_base_main`) and **Sepolia** (`anvil_sepolia`, `local_testing`).
- Point the UI at committed address artifacts under `frontend/packages/protocol/src/addresses/**`.

We **cannot** today:

- Bring up a **Robinhood-shaped** local stack (chain id **4663**) with one command for UI + launch rehearsal.
- Deploy the **full Uni V4 DETF + hook package surface** as first-class stages.
- Deploy **Uni V3 SE + Uni V4 SE** vaults over real RH Uni cores with mintable test tokens for launch wrapping.
- Guarantee UI launch flows hit **live Robinhood PoolManager / V3 factory / Permit2 / Universal Router** instead of hermetic mocks — while still **minting** fixture assets freely.

Without this pipeline, UI work either talks to incomplete local fixtures or requires public RH deploys before product is ready.

---

## 2. Primary user stories

### US-1 — Operator bring-up

As a developer, I want a single shell entrypoint that:

1. Starts (or reuses) Anvil forked from Robinhood mainnet with **`--chain-id 4663`**,  
2. Deploys IndexedEx foundation + Uni V3/V4 SE + Uni V4 DETF/hook packages,  
3. Deploys **inert** demo DETFs, mints test tokens to wallets, seeds V3/V4 pool liquidity, exports JSON artifacts,

so I can open the UI and **manually buy the first bond**.

### US-2 — Canonical Uni cores only

As a protocol engineer, I want every **external** Uniswap / Permit2 / Multicall integration to resolve from **`ROBINHOOD_MAIN`**. IndexedEx packages and mintable test tokens are **ours**; PoolManager, V3 factory/NPM, UR, etc. are **not** redeployed.

### US-3 — Full family surface

As a product engineer, I want **CP / Orbital / Weighted** Uni V4 DETF packages deployable (plus shared children and required hooks), including the standalone Single SE Buffer hook.

### US-4 — V3 + V4 SE wrap path

As a launch engineer, I want **Uniswap V3 Standard Exchange** and **Uniswap V4 Standard Exchange** packages and demo vaults wrapping **test-token pools** on RH Uni V3 / V4 so UI and launch code exercise the real wrap path we ship.

### US-5 — UI-owned first bond

As a frontend engineer, I want DETFs **inert** after script deploy, with **minted test-token balances** on the test wallet large enough for first bond + follow-on UI flows — **no** scripted `bond()`.

### US-6 — Resumable stages

As an operator, I want numbered stages that skip when artifacts exist (`--force` to redo).

---

## 3. Scope

### 3.1 In scope

| Area | Requirement |
|------|-------------|
| **Anvil environment** | Fork Robinhood mainnet; **chain id `4663`** |
| **Mintable test tokens** | Deploy **eight** mintable ERC-20s `TT0`…`TT7`; mint to deployer + UI wallet |
| **IndexedEx foundation** | CREATE3, DiamondPackageCallBackFactory, shared facets, Manager / FeeCollector / Vault Registry / fee oracle |
| **Hook factory** | Deploy hook diamond factory; `setHookDiamondPackageFactory` |
| **Uni V3 SE** | Package + demo vault(s) over RH Uni V3 pools of test tokens |
| **Uni V4 SE** | Package + demo vault(s) over RH Uni V4 pools of test tokens (PoolManager = `ROBINHOOD_MAIN`) |
| **Hook packages** | CP / Orbital / Weighted buffer hooks + **Single SE Buffer** (wrap/unwrap) |
| **DETF children** | Shared Uni V4 bond NFT + rebasing claim packages |
| **DETF packages + inert demos** | CP / Orbital / Weighted — **inert only** |
| **Canonical pin checks** | `code.length > 0` at every required `ROBINHOOD_MAIN` address |
| **Artifacts** | Stage JSON under `deployments/anvil_robinhood_main/`; frontend under **`addresses/chain/4663/`** |
| **Docs** | README + inventory update |

### 3.2 Out of scope (v1)

| Item | Why |
|------|-----|
| Public 4663 / 46630 broadcast deploys | Separate release runbook |
| **Scripted first bond / “go live”** | UI owns first bond (D4) |
| Balancer V3 core on Robinhood | Parallel L2-E track; not required for Uni V3/V4 SE + Uni V4 DETF path |
| Uni V2 SE as primary backing for this pipeline | Replaced by V3 + V4 SE (D6) |
| Superseded listing DETF tree | See §0.2 |
| RH stock-token legs as required fixtures | Test tokens only (D1) |
| SuperSim dual-chain | Not RH |
| Changing DETF/hook product behavior | Scripts only wire existing packages |
| `via_ir` | Forbidden |

### 3.3 Explicit non-goals

- **Do not** deploy hermetic `PoolManager` / Uni V3 factory when forked RH already has them.  
- **Do not** `new` facets/DFPkgs.  
- **Do not** bypass vault registry for registered vault/DETF/hook packages.  
- **Do not** call DETF `bond` / first-bond helpers from deploy scripts.  
- **Do not** brand DETF role names with product tickers.

---

## 4. Environment law

### 4.1 Chain and fork (**locked**)

| Parameter | Value | Notes |
|-----------|--------|--------|
| Upstream | `robinhood_mainnet` or `robinhood_mainnet_alchemy` | Prefer Alchemy when key present |
| Fork block | **`ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`** (`20_714_383`) unless `ANVIL_FORK_BLOCK_NUMBER` set (**D10**) | Record pin in preflight artifact |
| Anvil host/port | `127.0.0.1:8545` | Match sibling wrappers |
| **Chain ID** | **`4663` (mandatory)** | `anvil --chain-id 4663 …`; scripts assert `block.chainid == 4663` |
| Sender | Anvil unlocked account (`DEV_ADDRESS` / `--sender`) | `--unlocked --broadcast --slow` |

**Rationale:** UI and wagmi must see real Robinhood chain id so launch code is not tested against a fake 31337 network.

### 4.2 Canonical external integrations (mandatory pin table)

Scripts **read from** Crane `ROBINHOOD_MAIN` (or a thin mirror kept in parity). No free-floating production addresses in stage scripts.

| Role | Constant | Notes |
|------|----------|--------|
| Chain | `CHAIN_ID` = `4663` | Assert on fork |
| WETH | `WETH9` | Canonical; **not** primary UI mint/bond asset (test tokens are) |
| USDG | `USDG` | Canonical stable; optional pin only |
| Permit2 | `PERMIT2` | Canonical CREATE2 |
| Uni V3 Factory | `UNISWAP_V3_FACTORY` | For V3 pool create + V3 SE |
| Uni V3 NPM / routers / quoter | `UNISWAP_V3_*` | As needed for seeding / SE |
| Uni V4 PoolManager | `UNISWAP_V4_POOL_MANAGER` | **Required** for V4 SE + hooks + DETFs |
| Uni V4 Position Manager / Quoter / State View | `UNISWAP_V4_*` | As needed |
| Universal Router | `UNISWAP_UNIVERSAL_ROUTER` | UI / route hops |

**Preflight fails** if any required address has empty code.

### 4.3 Profiles and paths (**locked D7–D8**)

| Item | Path / name |
|------|-------------|
| Script root | `scripts/foundry/anvil_robinhood_main/` |
| Primary orchestrator | `scripts/foundry/anvil_robinhood_main/deploy_all.sh` |
| Thin shell wrapper | `scripts/shell/anvil_robinhood_main.sh` (delegates to `deploy_all.sh`; discoverable next to `local_testing.sh`) |
| Deployment artifacts (raw stage JSON) | `deployments/anvil_robinhood_main/` (or `deployments/chain/4663/` — impl plan may colocate; **frontend** path is normative below) |
| **Frontend artifacts** | **`frontend/packages/protocol/src/addresses/chain/4663/` only** — no `anvil_robinhood_main/` profile folder |
| Operator label | `anvil_robinhood_main` (scripts/docs name for this pipeline) |
| Foundry profile | default (**no `via_ir`**) |

---

## 5. Product inventory (deploy BOM)

### 5.1 DETF families

Source: `contracts/vaults/detf/protocols/dexes/uniswap/v4/`

| Family | Path | Package | Reserve hook | v1 |
|--------|------|---------|--------------|-----|
| **SE CP Single DETF** | `standardExchange/constantProduct/single/` | `UniswapV4SingleStandardExchangeDETDFPkg` | CP Buffer Hook | **Required** |
| **SE Orbital DETF** | `standardExchange/orbital/` | `UniswapV4StandardExchangeOrbitalDETDFPkg` | Orbital Buffer Hook | **Required** |
| **SE Weighted DETF** | `standardExchange/weighted/` | `UniswapV4StandardExchangeWeightedDETDFPkg` | Weighted Buffer Hook | **Required** |
| Listing Single DETF (superseded) | `standardExchange/single/` | listing-family package | `hooks=0` listing pool | **Out** (§0.2) |

**Shared children (required):**

| Package | Path |
|---------|------|
| Bond NFT DFPkg | `…/uniswap/v4/common/nft/` |
| Rebasing claim DFPkg | `…/uniswap/v4/common/rebasing/` |

### 5.2 Standard Exchange vault packages (**locked D6**)

| Package | Path | External core |
|---------|------|---------------|
| **Uniswap V3 Standard Exchange** | `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeDFPkg.sol` | `ROBINHOOD_MAIN` Uni V3 factory / pool / NPM as package requires |
| **Uniswap V4 Standard Exchange** | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` | `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` (+ periphery as required) |

**Demo vaults:** at least one V3 SE and one V4 SE over **mintable test-token** pools with **seeded liquidity**, so UI can wrap/unwrap and DETF/hooks can bind real SEs.

### 5.3 Hooks

#### Required by DETF families

| Hook package | Path |
|--------------|------|
| Single SE Buffer **Constant Product** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` |
| SE **Orbital** Buffer | `…/standardExchange/orbital/` |
| SE **Weighted** Buffer | `…/standardExchange/weighted/` |

#### Explicitly required (UI / route hop)

| Hook package | Path | Role |
|--------------|------|------|
| **Single Standard Exchange Buffer** (wrap/unwrap; **not** CP) | `contracts/hooks/uniswap/v4/standardExchange/single/` | `pairToken ↔ SE shares` hop; **not** DETF reserve |

#### Factory

| Component | Path |
|-----------|------|
| Hook Diamond Package Callback Factory | `contracts/hooks/uniswap/v4/factory/` |

#### Not required for v1

Dual SE CP buffer, quad stable buffers/swap hooks, standalone non-SE orbital/weighted/quad swap hooks — unless a later UI surface needs them.

### 5.4 Deploy path law (normative)

```text
Facets / pure Crane children
  → CREATE3 FactoryService (never `new`)

Hook diamond instances
  → Hook DFPkg.deployVault(args, mineNonce)
  → VaultRegistry.deployHookVault(...)
  → UniswapV4HookDiamondPackageCallBackFactory (CREATE2 flag mining)

SE vaults (V3 / V4)
  → indexedexManager / vault registry deploy*DFPkg + deployVault
  → bind to pools created on ROBINHOOD Uni V3 / PoolManager

DETF diamonds
  → indexedexManager.deployVault / deploy*DFPkg
  → postDeploy may deployHookVault for reserve hook + init V4 pool on ROBINHOOD PoolManager
  → stop at inert; NO bond()
```

**PoolManager** on every V4 package: **`ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`**.  
**V3 factory / pool** on V3 SE: **`ROBINHOOD_MAIN` Uni V3 constants**.

---

## 6. Fixture strategy (UI-launch oriented)

### 6.1 Principles (**locked**)

1. **Production externals** for Uni V3, Uni V4, Permit2, UR.  
2. **Mintable test tokens only** for pair legs / pool legs / wallet funding (D1).  
3. **Production-first** IndexedEx packages (TestBase-equivalent registry paths).  
4. **Uni V3 SE + Uni V4 SE** wrap test-token pools (D6).  
5. Demo DETFs remain **inert** (D4).  
6. **Fund** deployer + designated UI test wallet(s) with large mintable balances; leave Permit2/approvals to UI unless a later iteration requires pre-approvals.

### 6.2 Eight-token matrix + weighted trade routes (**locked D9**)

**Tokens:** eight mintable ERC-20s, **18 decimals**, symbols **`TT0`…`TT7`** (names free; stable artifact keys `tt0`…`tt7`).

| Asset | Role |
|-------|------|
| `TT0`…`TT7` | All pair legs, Weighted doors, SE wraps, DETF capital |
| ETH | Gas only |
| WETH / USDG / RH_* | Pin-only; **not** fixture legs |

#### Why eight

Weighted SE Buffer product law: \(n \in [2,8]\); at \(n=8\) there are \(\binom{8}{2} = 28\) pair doors. Operator goal: **UI can test trade routes across all weighted pools**. Fixture set must therefore support a **full \(n=8\)** Weighted buffer topology with liquidity on every door the product initializes.

#### Normative pool / SE / product graph

| Surface | Binding | Purpose |
|---------|---------|---------|
| **Uni V3 pools** | Seed a **connected** graph over `TT0`…`TT7` sufficient for multi-hop V3 routes (minimum: chain or star covering all eight tokens; prefer full adjacency if gas allows — impl plan picks concrete edges, must cover all eight) | Spot liquidity + V3 SE underlyings |
| **Uni V3 SE vaults** | ≥1 vault wrapping a V3 test-token pool (recommend **multiple** SE instances if needed so ≥1 Weighted/Orbital leg is V3-buffered and wrap path is UI-visible) | Launch wrap of **V3** pools |
| **Uni V4 pools** | Seed pools on RH PoolManager for V4 SE underlyings and for any non-hook CL the SE package requires | Spot + V4 SE |
| **Uni V4 SE vaults** | ≥1 vault wrapping a V4 test-token pool (same multi-instance preference as V3) | Launch wrap of **V4** pools |
| **Weighted Buffer Hook demo** | **\(n=8\)** mandatory: tokens = `TT0`…`TT7` (address-sorted at bind); **≥1 V3 SE leg and ≥1 V4 SE leg** (D13); **RP on every SE-buffered leg** (D14); weights PRD-legal (sum `1e18`, each ≥1%); all \(\binom{8}{2}=28\) pair doors initialized + **seeded** | Full weighted trade-route surface |
| **Weighted DETF demos** | Gentle + launch-rich inert; **\(n=8\) mandatory** (DETF self-leg + **7** externals from `TT0`…`TT7` excluding DETF’s address slot); same mixed V3+V4 SE + RP-on-SE rule as buffer | UI first-bond + expansion compare at product max |
| **CP DETF demos** | Gentle + launch-rich inert; backing SE = V3 SE **or** V4 SE (at least cover both SE types across the two instances or via separate binding); `pairToken` ∈ that SE’s tokens | Single-leg gold path |
| **Orbital DETF demos** | Gentle + launch-rich inert; two external pairs from test tokens; **≥1 SE** (not both-bare); prefer mixed V3+V4 when both legs buffered; **RP on each SE leg** | Multi-leg sphere path |
| **Single SE Buffer demo** | **Both** a V3 SE hop and a V4 SE hop | `pairToken ↔ vaultShare` routes |
| **Rate providers** | Deploy Standard Exchange Rate Provider package (or equivalent) instances so **each** SE-buffered leg has RP rating **SE shares → pairToken** (1e18 pair per share peer unless package law differs) | D14 |

**Liquidity seeding rule:** every Weighted door used by the \(n=8\) hook demo must receive enough seed that a non-trivial exact-in swap does not revert for “no liquidity” under normal UI test sizes. Scripts seed doors; scripts **do not** first-bond DETFs.

### 6.3 Liquidity seeding (scripts **do** this)

Scripts **must** seed underlying V3/V4 pools and SE inventory enough that:

- SE `exchangeIn` / `exchangeOut` works for UI wrap tests,  
- Buffer hooks can be initialized,  
- UI first bond has enough market depth / capital path after user bonds (first bond itself is UI-driven).

Scripts **must not** call DETF `bond`.

### 6.4 Per-family demo instances (**locked D5**)

| Family | Script deliverable |
|--------|-------------------|
| CP Single DETF | Package + **two inert** instances: gentle + launch-rich |
| Orbital DETF | Package + **two inert** instances: gentle + launch-rich (1 SE + bare or 2 SE) |
| Weighted DETF | Package + **two inert** instances: gentle + launch-rich, **both \(n=8\)** (D12) |
| Weighted Buffer Hook | Package + **one** standalone \(n=8\) demo (28 doors; mixed V3+V4 SE; RP on SE legs) |
| Single SE Buffer | Package + demos against **both** V3 SE and V4 SE |
| CP / Orbital hooks | Via DETF postDeploy and package registration as required |

`PkgArgs` / expansion templates come from family PRDs / TestBases. **Do not invent** threshold/expansion numbers in shell.

### 6.5 Wallet funding model (**locked D11**)

| Role | Anvil account | Funding |
|------|---------------|---------|
| Deployer / owner | **account(0)** | ETH + mint **1e12** whole units × decimals of each `TT0`…`TT7` |
| UI test wallet | **account(1)** | Same mint amounts of each test token; ETH for gas |
| Approvals | — | **Default: none** — UI exercises Permit2 / approve |
| First bond | — | **UI only** |

Export both addresses in stage JSON / frontend artifacts.

---

## 7. Stage model (proposed)

Each stage writes JSON under `deployments/anvil_robinhood_main/`. Resume if file exists unless `--force`.

| Stage | Purpose |
|------:|---------|
| **00** | Preflight: fork RPC, assert `chainid == 4663`, pin required `ROBINHOOD_MAIN` code |
| **01** | Crane foundation (CREATE3, diamond factory, shared facets) |
| **02** | IndexedEx core (manager, fee collector, registry, fee oracle, bond terms defaults) |
| **03** | Hook diamond factory + `setHookDiamondPackageFactory` |
| **04** | Mintable **TT0…TT7** + mint to account(0) and account(1) |
| **05** | Uni V3 pools over test tokens + seed liquidity on RH V3 |
| **06** | Uni V4 pools over test tokens + seed liquidity on RH PoolManager |
| **07** | Uni V3 SE package + demo V3 SE vault instance(s) |
| **08** | Uni V4 SE package + demo V4 SE vault instance(s) |
| **09** | Hook packages (CP / Orbital / Weighted / Single Buffer) |
| **10** | DETF children (bond NFT + rebasing claim packages) |
| **11** | DETF packages (CP / Orbital / Weighted) |
| **12** | **Inert** demos: gentle+launch-rich per DETF family; standalone **Weighted \(n=8\)** hook; Single SE Buffer hops (no bond) |
| **13** | Export → **`frontend/.../addresses/chain/4663/`** + stage summary under deployments |

**Shell groups:**

```text
foundation   → 00–03
assets       → 04
pools        → 05–06
se           → 07–08
packages     → 09–11
demos        → 12
export       → 13
all          → 00–13
```

**Removed vs v0.1:** any stage that opens first bond / “live” overlay.

### 7.1 Implementation patterns to reuse

| Pattern | Source |
|---------|--------|
| Artifact IO / resume | `LocalTestingDeploymentBase` / `anvil_base_main` DeploymentBase |
| Orchestrator flags | `--restart-anvil`, `--kill-anvil`, `--force`, `--dry-run`, verbosity |
| V3 / V4 SE deploy | `TestBase_UniswapV3StandardExchange`, `TestBase_UniswapV4StandardExchange` |
| Hook deploy | Co-located hook TestBases + `indexedex-uniswap-v4-hook-packages` |
| DETF deploy | Co-located `TestBase_UniswapV4*DETF.sol` |
| Fork pin | `test/foundry/fork/robinhood_4663/**` |
| V4 liquidity seed helper | `scripts/foundry/shared/UniswapV4LiquiditySeeder.sol` (if applicable) |

---

## 8. Frontend / UI contract

### 8.1 Artifacts the UI needs

| Class | Contents |
|-------|----------|
| Platform | create3, diamond factory, manager, fee collector, hook factory |
| Externals | PoolManager, V3 factory, Permit2, UR (from `ROBINHOOD_MAIN`) |
| Test tokens | `TT0`…`TT7` addresses + decimals |
| SE | V3 SE package + instance(s); V4 SE package + instance(s) |
| Packages | Hook DFPkgs, DETF DFPkgs, bond NFT pkg, rebasing pkg |
| Instances | Inert DETFs, buffer hook demo(s) |
| Wallets | Documented funded UI test address |
| Tokenlists | Test tokens + vault/DETF fragments |

### 8.2 Env wiring (**locked D7, D15, D16**)

- Chain-keyed artifacts: **`frontend/packages/protocol/src/addresses/chain/4663/`**.  
- RPC default for local: `http://127.0.0.1:8545` (Anvil forked RH).  
- Chain id: **`4663`**.  
- Operator pipeline name remains `anvil_robinhood_main` in scripts/docs.  
- **In scope:** minimal `@indexedex/protocol` loader / registry wiring so **any** app consuming the protocol package can select chain **4663** and point at local Anvil.  
- **Out of scope for this PRD:** end-to-end first-bond green in a specific app (UI bugs are follow-ups).  
- Primary consumer: protocol package completeness, not one app.

### 8.3 Launch-code alignment

Scripts prepare stack so UI can:

1. Discover packages / inert DETFs / SE vaults,  
2. Connect wallet with minted test tokens,  
3. **Buy first bond** (and subsequent mint/claim/route flows),  
4. Exercise V3 SE and V4 SE wrap paths and Single SE Buffer hops.

Script DoD stops at **inert + funded**; UI DoD owns first bond.

---

## 9. Security, safety, and ops constraints

| Constraint | Rule |
|------------|------|
| Private keys | Prefer Anvil `--unlocked`; never commit mainnet keys |
| Fork RPC keys | Env only; no secret logging |
| Broadcast guard | Refuse non-local RPC for this pipeline |
| Rate limits | Anvil fork throttle knobs as in `anvil_base_main` |
| Idempotency | Stage JSON resume; stable CREATE3 salts for foundation |
| Chain id | Hard fail if `block.chainid != 4663` after fork |

---

## 10. Success criteria (Definition of Done)

### 10.1 Script DoD

1. `deploy_all.sh all` (or equivalent) completes on clean Anvil RH fork with **chain id 4663**.  
2. Preflight fails if required Uni V3 / V4 / Permit2 code is missing.  
3. **Eight** mintable tokens `TT0`…`TT7` deployed; account(0) and account(1) each hold **≥ 1e12 whole units** (scaled) per token.  
4. At least one **Uni V3 SE** and one **Uni V4 SE** demo vault exist over seeded test-token pools.  
5. All required hook + DETF **packages** deployed via registry paths.  
6. Standalone **Weighted Buffer \(n=8\)** (mixed V3+V4 SE, RP on SE legs, 28 doors seeded); **Weighted DETF \(n=8\)** gentle + launch-rich inert; **Single SE Buffer** for V3 and V4 SE hops.  
7. **Two inert** demos (gentle + launch-rich) per CP / Orbital / Weighted; **no** `bond` in scripts.  
8. Frontend artifacts under **`chain/4663/`** + **minimal protocol loader** for chain 4663 / local RPC.  
9. `deploy_all.sh` + `scripts/shell/anvil_robinhood_main.sh` exist; README + inventory updated.  
10. No `via_ir`; no `new` facets/DFPkgs; no hermetic PoolManager/V3 factory for happy path.  
11. Every SE-buffered Orbital/Weighted leg has a non-zero rate provider (shares → pairToken).

### 10.2 UI rehearsal DoD (manual / separate)

1. App connects to local RPC as chain **4663** using **`chain/4663`** address artifacts.  
2. Menus show `TT0`…`TT7`, SE vaults, gentle + launch-rich inert DETFs, weighted route surface.  
3. Funded **account(1)** can **open first bond** via UI (scripts did not).  
4. UI can attempt swaps across Weighted doors (full \(n=8\) surface).  
5. No missing-address errors for this surface.

### 10.3 Non-regression

- Existing `anvil_base_main`, `local_testing`, public Sepolia pipelines untouched except optional shared helper extraction.  
- Hermetic TestBases remain gold unit/integration path.

---

## 11. Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| V3/V4 SE package deploy complexity on fork | Stage fails | Follow co-located TestBases; seed pools before SE vault deploy |
| Hook flag mining brittle | Slow/fail deploys | Premine; reuse TestBase helpers; no auto-mine default |
| DETF family incomplete in product code | Demo instance fails | Package-only gate with clear error; track maturity per family |
| Fork RPC rate limits | Aborts | Alchemy; Anvil throttle; stage resume |
| Chain id mis-set to 31337 | UI wrong network | Orchestrator forces `--chain-id 4663`; stage 00 asserts |
| Operator expects live DETF | Confusion | README: inert by design; bond in UI |
| Artifact schema drift | UI blank | Mirror existing anvil export shapes |

---

## 12. Open questions

**None remaining for PRD lock.** Operator Q&A (two rounds, 2026-08-09):

| Item | Resolution |
|------|------------|
| Frontend layout | **`chain/4663/` only** (D7) |
| Shell entrypoint | **`deploy_all.sh` + shell wrapper** (D8) |
| Token / pool graph | **Eight tokens TT0…TT7** (D9) |
| Fork block | **`DEFAULT_FORK_BLOCK`** (D10) |
| Wallets / mint | **acct0 + acct1**, 1e12 each (D11) |
| Expansion demos | **Gentle + launch-rich** (D5) |
| Weighted \(n=8\) | **Buffer and DETF both \(n=8\)** (D12) |
| V3 vs V4 SE on multi-leg | **Mixed ≥1 each on Weighted \(n=8\)** (D13) |
| Rate providers | **RP on every SE-buffered leg** (D14) |
| Frontend scope | **Artifacts + minimal protocol loader** (D15) |
| Primary app | **Any consumer of `@indexedex/protocol` / chain/4663** (D16) |

**Implementation-only freedom** (not product ambiguity): concrete V3 pool edge list (must cover all eight tokens), equal vs unequal weight vectors (must satisfy family PRD), CREATE3 salts, stage file names, exact seed amounts beyond “UI swaps don’t revert.”

---

## 13. Proposed deliverables (implementation phase)

After PRD **Accepted**, implementation plan for goal agent:

1. `scripts/foundry/anvil_robinhood_main/` — DeploymentBase + Script_00…13  
2. `deploy_all.sh` + thin `scripts/shell/anvil_robinhood_main.sh` (`--chain-id 4663`, fork URL, restart/kill/force)  
3. Stage JSON under `deployments/anvil_robinhood_main/` (or colocated) + README  
4. Frontend export into **`addresses/chain/4663/`** + loader wiring  
5. Inventory update  
6. Manual UI checklist (first bond + weighted multi-door routes)

---

## 14. Acceptance checklist for PRD review

- [x] Chain id **4663** locked  
- [x] Test tokens only (**eight**: TT0…TT7)  
- [x] No scripted first bond; fund wallets  
- [x] Gentle **and** launch-rich inert DETF demos  
- [x] Uni V3 SE + Uni V4 SE (not Uni V2 primary)  
- [x] Superseded listing DETF explained and **out**  
- [x] Single SE Buffer **hook** still **in**  
- [x] Weighted Buffer **and** Weighted DETF both \(n=8\)  
- [x] Mixed V3 SE + V4 SE on Weighted; RP on every SE leg  
- [x] Frontend **`chain/4663/`** + minimal protocol loader  
- [x] `deploy_all.sh` + shell wrapper  
- [x] Fork pin + wallet mint policy  
- [x] **Ready for implementation plan / `/goal`**  

---

## 15. Appendix A — Dependency graph

```text
Anvil fork RH mainnet --chain-id 4663 @ DEFAULT_FORK_BLOCK
  └─ ROBINHOOD_MAIN pins (V3 factory, V4 PoolManager, Permit2, UR, …)
       └─ 01 Crane + facets
            └─ 02 IndexedEx manager / registry / fee oracle
                 └─ 03 Hook diamond factory
                      ├─ 04 TT0…TT7 mint → acct0 + acct1
                      ├─ 05 Uni V3 pools (8-token connected graph) + seed
                      ├─ 06 Uni V4 pools + seed
                      ├─ 07 Uni V3 SE package + vault instances
                      ├─ 08 Uni V4 SE package + vault instances
                      ├─ 09 Hook DFPkgs
                      ├─ 10 Bond NFT + Rebasing DFPkgs
                      └─ 11 DETF DFPkgs
                           └─ 12 Inert demos: gentle+launch-rich DETFs;
                                  Weighted n=8 hook (28 doors seeded);
                                  Single SE Buffer V3/V4 hops  (NO bond)
                                └─ 13 Export → frontend/…/chain/4663/
                                     └─ [UI] first bond + weighted routes
```

## 16. Appendix B — Role vocabulary

| Role | Name |
|------|------|
| Rate / settlement asset | `rateAsset` |
| Other vault token(s) | `pairToken` / `pairToken0`… |
| Underlying SE | `underlyingVault` / `standardExchangeVault` |
| SE share | `vaultShare` |
| DETF share | `detfToken` |
| Reserve | `reserveHook` / `reservePool` |
| Claim | `rebasingClaimToken` |

---

## 17. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-08-09 | Initial draft |
| v0.2 | 2026-08-09 | Locked: chain id 4663; test tokens; no first bond; gentle demos; Uni V3+V4 SE; glossary for superseded listing DETF + gentle/launch-rich; removed live-bond stage |
| v0.3 | 2026-08-09 | Q&A lock: `chain/4663/` artifacts; deploy_all + shell wrapper; **8 tokens TT0–TT7** + Weighted \(n=8\) full-door routes; DEFAULT_FORK_BLOCK; acct0/acct1 large mints; gentle **and** launch-rich inert DETFs; §12 cleared |
| v0.3.1 | 2026-08-09 | Second Q&A: Weighted Buffer **and** DETF both \(n=8\); mixed V3+V4 SE on Weighted; RP on every SE leg; frontend = artifacts + minimal protocol loader; any app via protocol package |

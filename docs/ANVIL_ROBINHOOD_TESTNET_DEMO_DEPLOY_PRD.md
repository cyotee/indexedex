# PRD: Robinhood Testnet (46630) launch-rehearsal deploy + DTF demo

**Status:** **Accepted v2.0 — requirements locked.** Product law stays here. Execution follows the implementation plan. Do **not** treat existing files under `scripts/foundry/anvil_robinhood_testnet/` as accepted implementation until they match that plan.  
**Date:** 2026-08-15  
**Owner surface:** Foundry launch-group scripts for public 46630 (rehearsed on an Anvil fork) + DTF UI artifacts  
**Implementation plan:** [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md) — **READY FOR EXECUTION** (groups **00–09** + DTF)

| Doc / path | Role |
|------------|------|
| **This file** | Requirements SoT for the **46630 demo / launch rehearsal** |
| [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md) | Implementor SoT (goal-command): groups **00–09**, shell, protocol 46630, DTF |
| [`ROBINHOOD_LAUNCH_PLAN.md`](./ROBINHOOD_LAUNCH_PLAN.md) | Product launch narrative (Olympus / DETF / RICH). **Balancer claims in that file are superseded here for this rehearsal** (D19). |
| [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) §2.9 | Eng inventory of what is already live on 4663 vs 46630 |
| [`ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md) | Existing **4663 mainnet-fork** lab (leave working; rewrite later to match these groups) |
| [`ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md`](./ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md) | Current 4663 UI runbook |
| Crane `ROBINHOOD_TESTNET.sol` | Canonical 46630 external addresses |
| Crane `ERC20MinterFacade*` | Public mint path for our faux stables |
| `scripts/foundry/anvil_robinhood_main/` | Template 4663 lab (Uni V3 + pons + CHIR) — **do not overwrite** |
| `scripts/foundry/anvil_robinhood_fee_detf/` | Template 4663 fee-DETF-only — **do not overwrite** |
| `frontend/ROADMAP.md` | UI no-deploy policy for frontend-only turns |
| Family PRDs under `contracts/vaults/detf/protocols/dexes/uniswap/v4/**` | DETF product + PkgArgs law |
| Curve Quad family PRD (`…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_PRD.md`) | **LOCKED v0.4** — one of four showcase families (D27) |
| [`docs/research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md`](./research/2026-08-15-robinhood-mainnet-usd-and-vault-tokens.md) | USDG vs USDe vs receipts |
| [`docs/research/2026-08-15-robinhood-usde-morpho-loop.md`](./research/2026-08-15-robinhood-usde-morpho-loop.md) | Why USDe/USDG exists; USDe/WETH is thin |
| [`docs/research/2026-08-15-robinhood-stock-token-detf-groups.md`](./research/2026-08-15-robinhood-stock-token-detf-groups.md) | Stock-token groups; §6 leaf books; testnet showcase source |
| Skill `indexedex-uniswap-v4-hook-packages` | Hook factory / `deployHookVault` law |
| Skills `crane-deployment`, `indexedex-testing` | CREATE3 / registry / production-first |

---

## 0. One-line goal

Ship a **resumable 46630 launch pipeline** (Foundry groups 00–09: factories → platform → Uni V4 packages → tokens → **ten live + launch-rich DETFs** → frontend `chain/46630/` + DTF list/`/mint`) that **broadcasts as `DEPLOYER_ADDRESS`** (forge `--sender`; cast wallet signs) the same way on public Robinhood Chain Testnet and on a **local Anvil fork** (`--chain-id 46630 --disable-code-size-limit`). Rehearse locally, then `--live` to the public RPC. Replay proven groups after an Anvil reset. Simulate 01–08 in one script for a gas estimate. Later reshape the **4663 mainnet** scripts to the same groups.

---

## 0.1 How to use this file

- **Now:** this PRD is accepted. Execute the implementation plan (00–09 + DTF). Rehearse on Anvil; `--live` is the public 46630 path.
- **Exploratory code** already on disk under `scripts/foundry/anvil_robinhood_testnet/` is **not** SoT until reconciled to the implementation plan.
- **Implementors invent nothing.** Every PkgArgs field, fee, seed, and richness gate is in §2 / §2.8. If a field is missing, stop and amend the PRD — do not guess.

---

## 1. Naming and network

The network is **Robinhood Chain Testnet**, not Ethereum Sepolia. Informal nickname: “Robinhood Sepolia” (the L2 settles to Ethereum Sepolia).

| | Value |
|--|--|
| Official name | Robinhood Chain Testnet |
| Chain ID | **46630** |
| Native gas | ETH |
| Settlement L1 | Ethereum Sepolia (`11155111`) |
| Public RPC | `https://rpc.testnet.chain.robinhood.com` (port **443**; fallback only) |
| **Fork RPC alias (locked)** | **`robinhood_testnet_alchemy`** → `https://robinhood-testnet.g.alchemy.com/v2/${ALCHEMY_KEY}` |
| Public Foundry aliases | `robinhood_testnet` / `robinhood_testnet_public` — fallback only if Alchemy cannot resolve |
| Explorer | `https://explorer.testnet.chain.robinhood.com/` |
| Faucet | `https://faucet.testnet.chain.robinhood.com/` |
| Local Anvil (when forked) | `http://127.0.0.1:8545`, **chain id 46630** |
| Deployer | `DEPLOYER_ADDRESS` (required). Forge `--sender`; cast wallet signs. No Anvil #0 default. Anvil pre-funds Foundry mnemonic accounts; fund `DEPLOYER_ADDRESS` on the fork if it is not one of those. |

**Wallet add-network (public testnet, not Anvil):**

| Field | Value |
|--|--|
| Network name | Robinhood Chain Testnet |
| RPC URL | `https://rpc.testnet.chain.robinhood.com` |
| Chain ID | `46630` |
| Currency | ETH |
| Explorer | `https://explorer.testnet.chain.robinhood.com` |

Anvil **must** run `--chain-id 46630` and `--disable-code-size-limit`. Do **not** fork 46630 state under chain id 4663 (wrong WETH, missing Uni V3, would clobber `chain/4663/` lab artifacts).

Do **not** invent RPC URLs. Operator must export `ALCHEMY_KEY` for the Alchemy alias.

---

## 2. Locked decisions

| # | Decision | Status |
|---|----------|--------|
| D1 | **Happy-path demo money is ours.** The §2.1 mintable table (**13** tokens in group 04) + **`TTRICH`** (group 08) via Crane `ERC20MinterFacade`. Do **not** seed pools, first-bond, or `/mint` against official RH stock tokens, faucet stocks, or explorer “USDC/USDG” clones. | **Locked** |
| D2 | Anvil **must** be chain id **`46630`**, forked from Robinhood Chain Testnet (`ROBINHOOD_TESTNET` pins). | **Locked** |
| D3 | **Sibling script family.** Do not mutate `anvil_robinhood_main` / `anvil_robinhood_fee_detf` as the only copy. New tree: `scripts/foundry/anvil_robinhood_testnet/`. Those 4663 trees stay the current mainnet-fork lab until rewritten to these groups. | **Locked** |
| D4 | **These groups are the public 46630 deploy path.** Rehearse on a local Anvil fork (`RPC_URL=http://127.0.0.1:8545`, Anvil `--chain-id 46630 --disable-code-size-limit`). Live: `--live` to the official 46630 RPC. Broadcast as `DEPLOYER_ADDRESS` (`forge --sender`; cast wallet signs). Never `--private-key`. Never `--unlocked` impersonation. Do **not** broadcast to 4663 from this tree. | **Locked** |
| D5 | **Scripted first bond on every DETF** then **launch-rich** (D47). Bonder = the **deployer EOA** (`DEPLOYER_ADDRESS`). Lock **1 day** (`86400`). Max lock **180 days** (`DEFAULT_BOND_MAX_TERM`). Amounts and order in §2.7. Scripts must leave each instance `isReserveLive() == true` and mint-open per D47. | **Locked** |
| D6 | **Reuse Crane `ERC20MinterFacade`** (`mintToken(token, amount, recipient)`). Authorize it as `mint` operator on **each mintable stand-in** via `IOperable.setOperatorFor`. Export `erc20MinterFacade` on `platform.json` so `/mint` works. | **Locked** |
| D7 | Frontend artifacts (group 09): **`frontend/packages/protocol/src/addresses/chain/46630/`**. Register chain **46630** in `@indexedex/protocol`. Do not overwrite `chain/4663/`. | **Locked** |
| D8 | Official RH testnet ETH / faucet stocks are **flavor / wrap-ETH only**. Official testnet **WETH** is flavor/wrap **and** a **`pairToken`** on **D26** (`TTDOL-Q`) and **D36** (`TTRICH-S`). Faucet stocks are never fixture legs. | **Locked** |
| D9 | **Never redeploy** RH cores that already have code (testnet WETH, Permit2, Uni V4 PoolManager + periphery + Universal Router). | **Locked** |
| D10 | **Never `new` facets/DFPkgs.** CREATE3 / FactoryService / (for vaults and DETFs) **IndexedexManager vault registry** only. `PkgInit` / `PkgArgs` on the **interface**. | **Locked** |
| D11 | **`via_ir` forbidden.** Default Foundry profile. | **Locked** |
| D12 | Product copy / token names must **not** impersonate official Robinhood Stock Tokens or Paxos USDG. Stand-ins are clearly **test** tokens (`Test Token …` / `TT…`). | **Locked** |
| D13 | **Foundry groups:** **00** preflight → **01** factories → **02** platform → **03** Uni V4 packages → **04** tokens + facade → **05** leaf pools/SEs → **06** five leaf DETFs (live + rich) → **07** four nest DETFs (live + rich) → **08** `TTRICH` + fee-sink (live + rich) → **09** frontend export + DTF wiring. | **Locked** |
| D14 | Anvil **`--fork-url`** is Foundry alias **`robinhood_testnet_alchemy`**. Fallback `robinhood_testnet` only if Alchemy cannot resolve. | **Locked** |
| D15 | This group list is the **template for later 4663 mainnet script rewrite**. Enable Uni V3 / pons on 4663 only if those cores have code. | **Locked** |
| D16 | Groups must be **resumable**. After a group is proven, an Anvil reset + replay of groups `01…N` must restore that prefix. Each group is **idempotent** (skip if artifact JSON is valid and targets have code, unless `FORCE=1`). | **Locked** |
| D17 | A group may only read earlier group JSON plus `ROBINHOOD_TESTNET` pins. | **Locked** |
| D18 | Group logic lives in **libraries** (or equivalent shared modules) called by thin `Script_0N_*.s.sol` **and** by **`Script_SimulateLaunch`** that runs **01–08** in **one** `vm.startBroadcast` / one simulation for **gas estimate**. **Not** group 09. No `vm.prank` on the broadcast path. | **Locked** |
| D19 | **No Balancer** on this launch path. Do not deploy Balancer V3 Vault, factories, routers, Balancer SE vaults, or Balancer DETFs. | **Locked** |
| D20 | **No Uni V3 and no pons** on 46630 (those cores have no code). Do not require them in preflight. `TTRICH` is a **mintable stand-in**, not a pons launch. | **Locked** |
| D21 | Group 01 includes the **Uni V4 hook diamond factory** with CREATE3 + diamond package factory. `setHookDiamondPackageFactory` runs in **group 02** once IndexedexManager exists. | **Locked** |
| D22 | Group 02 is the **IndexedEx platform**: FeeCollector, IndexedexManager (Vault Registry + Vault Fee Oracle on that diamond), SE **rate provider DFPkg** (package only, no per-vault instances). | **Locked** |
| D23 | Group 03 deploys Uni V4 **packages only**: hook DFPkgs (CP / Orbital / Weighted / **Curve Quad Stable Buffer** / Single SE Buffer), Uni V4 SE DFPkg, DETF children (bond NFT + rebasing claim **packages**), Uni V4 DETF DFPkgs (CP / Orbital / Weighted / **Curve Quad Stable**). **No** pools, vault instances, or DETF instances. | **Locked** |
| D24 | Accounts: deployer / owner / SENDER / first-bonder = `DEPLOYER_ADDRESS` (required; no Anvil #0 default). `UI_WALLET` env or the deployer. | **Locked** |
| D25 | DETF / SE **role names only** in code (`rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`, `detfToken`, `reservePool`, `rebasingClaimToken`). No RICH/RICHIR as role names. | **Locked** |
| D26 | **Dollar Quad leaf is in scope** (fifth leaf). Three Uni V4 SEs: `TTUSDE`/WETH, `TTUSDG`/WETH, `TTUSDG`/`TTUSDE`. `pairToken`s **R1:** `TTUSDE`, `TTUSDG`, **WETH** (pairwise distinct). 3/3 SE-buffered. See §2.3. | **Locked** |
| D27 | **Leaf showcase = four live + launch-rich DETFs, one per Uni V4 SE family** (CP Single, Orbital, Curve Quad, Weighted). Stories and `pairToken`s in §2.1. No other themed **leaf** books (High-narrative, Semi core-7, Rates-3, …) in this rehearsal. | **Locked** |
| D28 | **Mintable stand-ins = 14 tokens.** Group 04 deploys the **13** rows in §2.1. Group 08 adds **`TTRICH`**. All 18 decimals. Official testnet WETH is **not** facade-minted. | **Locked** |
| D29 | **Bare-book SE pattern:** Weighted / Orbital / Index Quad use **1 SE + rest bare**. CP Single’s one external leg **is** the SE. D26 Dollar Quad is **3/3 SE**. Showcase leaf/nest SEs are Uni V4 `pairToken` vs **`TTUSDG`**. Fee-sink SE is **`TTRICH` / WETH**. RP on every SE (D39). | **Locked** |
| D30 | **Nested showcase = four live + launch-rich DETFs** whose `pairToken`s are D27 **`detfToken`s**: Showcase nest (Weighted-4), Beta nest (Orbital), Index wrap (CP Single), Mag7 wrap (CP Single). No nested Curve Quad. Table in §2.2. Group **07**. | **Locked** |
| D31 | **All 14 mintable stand-ins are 18 decimals.** | **Locked** |
| D32 | **Weighted pair *relative* tape** is the market-cap-ish vector in §2.8 (NVDA-first). **Not** 100% of the book — D54 takes 20% self-leg, then this tape is **80%**. Nest inners are **equal 20% each** after the same 20% self-leg. Frozen demo tape, **not** a live oracle. Do not show as a promised USD index. | **Locked** |
| D33 | **Group 04 mint path:** facade `maxMintAmount = 10_000_000e18`, `minMintInterval = 0`; mint **1e12** whole units of each of the **13** §2.1 tokens to `DEPLOYER_ADDRESS` and `UI_WALLET`; leave facade on. Group 08 does the same for `TTRICH`. | **Locked** |
| D34 | **First UI consumer:** `frontend/apps/dtf` (port 3002). List all **ten** DETFs **equally** (D49), each live + launch-rich, plus `/mint` for the 14 stand-ins. Do not add a second app in this PRD. | **Locked** |
| D35 | **Fork pin:** bump Crane `ROBINHOOD_TESTNET.DEFAULT_FORK_BLOCK` to a **known-good recent testnet head at first implement**. Scripts may override with `ANVIL_FORK_BLOCK_NUMBER`. Do not fork unpinned head. | **Locked** |
| D36 | **Group 08:** mintable **`TTRICH`** (`Test Token RICH`, 18 dec, facade + 1e12 like D33) + live + launch-rich Uni V4 **CP Single** fee-sink. `pairToken` = official testnet **WETH**. SE = Uni V4 `TTRICH` / WETH at **0.30%**. RP on (shares → `TTRICH`). Same Policy / creation / expansion as D38. Not a pons launch. | **Locked** |
| D37 | **Fee routing (this rehearsal):** Vault Fee Oracle `feeTo` = **FeeCollector**. Usage/dex fees **accumulate on the FeeCollector**. Do **not** script `pushSingleTokenFee` / donate into `TTRICH-S`. Manual push later (operator / later PRD). `TTRICH-S` still exists as the live fee-sink exhibit. | **Locked** |
| D38 | **Shared DETF PkgArgs** (all ten): `creationPairPerDetfWad = 1e18` on every external leg (**peg ruler**, synthetic 1.0). Uni V4 **opening** `openingPairPerDetfWad` is **2.2e18** (N10: CP Single mint-opens at 2.2e18 after a real first bond; 1.1e18 left mint closed). `thresholdMode = Policy`, mint **1.05e18**, burn **0.95e18**. Expansion fields **`0`** → family defaults: epoch **8h**, **R = 10%/yr**, unlimited catch-up. Both Quads `baseAmp = 100`. Orbital `rateAsset`: leaf = `TTNVDA`; Beta nest = **W** `detfToken`. Orbital `detfBindingIndex = 2` (DETF is the third hook token). Caller premines via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; nonce not in PkgArgs. `vaultShares[i] = address(0)` when that leg has an SE (SE diamond is the share). Bond min **1 day**, max **180 days** (set on the fee oracle in group 02 from `DEFAULT_BOND_MIN_TERM` / `DEFAULT_BOND_MAX_TERM` overridden min to `86400`). **Do not** raise creation to “look rich”; opening is the launch-rich lever. | **Locked** |
| D39 | **Rate providers on every SE** (leaf, nest, fee-sink). Each RP rates shares → that leg’s `pairToken`. D39 is **not** a price. | **Locked** |
| D40 | **Fixture Uni V4 pools** (the `pair`/`TTUSDG` or WETH books in §2.5): fee **0.30% (3000 pips)**, tick spacing **60**, init mid **1:1** (`TickMath.getSqrtPriceAtTick(0)`). Reserve-hook product pools use **family plumbing** (typically fee 0 / tick 60 / 1:1) — do not invent other ticks. | **Locked** |
| D41 | **Superseded by D4.** Public 46630 broadcast is in scope via `--live` + `DEPLOYER_ADDRESS`. Anvil is the rehearsal target. | **Locked** |
| D42 | **Crane facade fix before group 04:** `ERC20MinterFacadeTarget` must use the **same** last-mint key for read and write: **`(token, recipient)`**. | **Locked** |
| D43 | **Tokenlist flavor:** official testnet WETH tagged `weth`; five faucet stocks tagged `rh-faucet`. **Not** `testToken` — `/mint` must not offer them. | **Locked** |
| D44 | **DETF ERC-20 symbols/names** are the §2.6 table. | **Locked** |
| D45 | **Seed fixture pools from the deployer EOA** (`DEPLOYER_ADDRESS`) after mint/wrap. TT/TT pools: **1e9** whole units each side. Pools with WETH: **100 WETH** + **100** whole units of the TT*. Nest W/Q pools stay **empty**. UI wallet gets **no extra ETH**. Deployer wraps **enough** official WETH for those seeds **plus** `TTDOL-Q` / `TTRICH-S` first-bond **plus** D47 richness buys on WETH-legged books. Do not cap at 300 WETH. | **Locked** |
| D46 | **Vault Fee Oracle (group 02):** `setDefaultUsageFee(5e16)` = **5%**; `setDefaultDexSwapFee(3e14)` = **0.03%**. No per-vault overrides. | **Locked** |
| D47 | **Rescinded for Uni V4 SE DETF.** Diamond impersonation + hook `depositSingle` as the DETF is **forbidden**. First bond as the deployer EOA is the only launch path. Launch-rich is **opening** (`openingPairPerDetfWad` = 2.2e18, N10 recorded). `isReserveLive` after first bond is the live gate. Mint-open is T3 of the peg/opening PRD, not a second LP step. | **Rescinded** |
| D48 | **No Anvil time warp.** Bonds stay locked. Demo does not mature/claim by `vm.warp`. | **Locked** |
| D49 | **No featured DETF.** DTF lists all **ten** equally. | **Locked** |
| D50 | **Implementation plan** covers groups **00–09**, SimulateLaunch **01–08**, shell orchestrator (local Anvil + `--live`), protocol **46630**, DTF equal list + `/mint`. | **Locked** |
| D51 | **Seigniorage incentive:** product default **5%** (`5e16`). Do not leave the old 50% constant. `setDefaultSeigniorageIncentivePercentage(5e16)` is allowed so a live oracle matches. D47 still runs until S ≥ 10.5. | **Locked** |
| D52 | **Uni V4 SE liquid reserve:** `setDefaultLiquidReservePercentageOfTypeId(IUniswapV4StandardExchangeLiquidReserve, 0.2e18)` = **20%**. | **Locked** |
| D53 | **SE vault-share ERC-20:** symbol `SE-{A}-{B}`, name `Test SE A/B`, using the two Uni V4 pool tokens (currency order: address-sorted is fine; symbol string uses the product names in §2.8). Shared SEs keep **one** name. Uni V4 SE `deployVault(poolKey, widthMultiplier)` uses **`widthMultiplier = 1`**. | **Locked** |
| D54 | **Weighted self-leg.** Both Weighted books (`TTM7-W`, `TTNEST-W`): `detfWeight = 0.2e18` (**20%**). Pair weights in §2.8 already sum to **0.8e18**. Family law: each weight ≥ 1%; `detfWeight + sum(pairWeights) = 1e18`. | **Locked** |
| D55 | **Rebasing claim metadata** (per DETF instance, group 06/07/08): name `Test Claim {DETF name}`, symbol `TC-{DETF symbol}` (e.g. `Test Claim NVDA Single` / `TC-TTNVDA-S`). `widthMultiplier = 1`. `optionalSalt = 0`. Owner = the DETF diamond. | **Locked** |

---

## 2.1 Showcase instances (D27–D29)

46630 is a **type exhibit**, not the full stock-token matrix. Deploy **five leaf** Uni V4 SE DETFs (D27 four families + D26 dollar Quad), first-bond each, then launch-rich (D47). `TTNVDA` and `TTUSDG` may appear in more than one instance.

| # | Family | Teaches | `pairToken`s (PkgArgs order) | SE |
|---|--------|---------|------------------------------|----|
| 1 | **CP Single** | One door | `TTNVDA` | That leg **is** the SE: Uni V4 `TTNVDA` / `TTUSDG` |
| 2 | **Orbital** | Two related doors | `TTNVDA`, `TTSMH` | 1 SE + 1 bare. SE on `TTNVDA` / `TTUSDG` |
| 3 | **Curve Quad** | Three **like-kind** index doors | `TTSPY`, `TTVTI`, `TTQQQ` | 1 SE + 2 bare. SE on `TTSPY` / `TTUSDG` |
| 4 | **Weighted** | Seven **distinct** names | Mag7 **NVDA-first:** `TTNVDA`, `TTMSFT`, `TTAAPL`, `TTGOOGL`, `TTAMZN`, `TTMETA`, `TTTSLA` | 1 SE + 6 bare. SE on `TTNVDA` / `TTUSDG` |
| 9 | **Curve Quad (D26)** | Three **SE-buffered** dollar/ETH doors | `TTUSDE`, `TTUSDG`, **WETH** | **3/3 SEs** — §2.3 |

RP on each SE (D39): shares → that leg’s `pairToken`. Do **not** use native ETH as a pool currency. Do **not** bind faucet `TSLA`/`AMZN`/`PLTR`/`NFLX`/`AMD` as fixture legs (D8).

Do **not** also deploy High-narrative, Semi core-7, Rates-3, Country-3, or other §6 books from the stock-token note.

### Mintable stand-ins — group 04 (D28, D31, D33)

**13** tokens (plus `TTRICH` in group 08). Symbols must match `/mint` (`isTestTokenEntry`: name `/test token/i` **or** symbol `/^TT[A-Z0-9]+$/`).

| Symbol | Name | Role |
|--------|------|------|
| `TTUSDG` | Test Token USDG | Cash / SE quote. D26 `pairToken`. **Not** Paxos USDG |
| `TTUSDE` | Test Token USDE | D26 `pairToken`. **Not** Ethena USDe |
| `TTNVDA` | Test Token NVDA | Single + Orbital + Weighted; SE underlying |
| `TTMSFT` | Test Token MSFT | Mag7 Weighted |
| `TTAAPL` | Test Token AAPL | Mag7 Weighted |
| `TTGOOGL` | Test Token GOOGL | Mag7 Weighted |
| `TTAMZN` | Test Token AMZN | Mag7 Weighted |
| `TTMETA` | Test Token META | Mag7 Weighted |
| `TTTSLA` | Test Token TSLA | Mag7 Weighted |
| `TTSMH` | Test Token SMH | Orbital second door |
| `TTSPY` | Test Token SPY | Index Quad; SE underlying |
| `TTVTI` | Test Token VTI | Index Quad |
| `TTQQQ` | Test Token QQQ | Index Quad |

Group 04 deploys these **13**. Group 08 adds `TTRICH`. **14** facade tokens total.

Official testnet **WETH** is wrap-ETH + D26/D36 `pairToken`. It is **not** in this table and **not** `/mint`.

### SE pools group 05 must create

| Uni V4 pool | Used by | Seed (D45) |
|-------------|---------|------------|
| `TTNVDA` / `TTUSDG` | Single, Orbital, Weighted | 1e9 / 1e9 |
| `TTSPY` / `TTUSDG` | Index Quad | 1e9 / 1e9 |
| `TTUSDE` / WETH | D26 | 100 / 100 WETH |
| `TTUSDG` / WETH | D26 | 100 / 100 WETH |
| `TTUSDG` / `TTUSDE` | D26 | 1e9 / 1e9 |

Nested SEs are created in **group 07**. Fee-sink pool is **group 08**.

---

## 2.2 Nested instances (D30)

Outer `pairToken`s are the inner **`detfToken`s** (D27 diamonds). Labels: **S** = `TTNVDA-S`, **O** = `TTNVDA-SMH-O`, **Q** = `TTIDX-Q`, **W** = `TTM7-W`.

| # | Book | Family | Inner legs (PkgArgs order) | SE (D29) |
|---|------|--------|----------------------------|----------|
| 5 | **Showcase nest** | Weighted | S, O, Q, W | 1 SE + 3 bare. SE on **W** / `TTUSDG` |
| 6 | **Beta nest** | Orbital | W, Q | 1 SE + 1 bare. SE on **W** / `TTUSDG` (same pool/SE as #5) |
| 7 | **Index wrap** | CP Single | Q | That leg **is** the SE: **Q** / `TTUSDG` |
| 8 | **Mag7 wrap** | CP Single | W | That leg **is** the SE: **W** / `TTUSDG` (same as #5) |

No nested Curve Quad. Name-in-basket Orbital (S+W) is **not** in D30. Do **not** list an outer as a leg of itself. Do **not** list the same inner twice.

### SE pools group 07 must create (after group 06)

| Uni V4 pool | Used by | Seed |
|-------------|---------|------|
| **W** (`TTM7-W`) / `TTUSDG` | Showcase nest, Beta nest, Mag7 wrap | **Empty** |
| **Q** (`TTIDX-Q`) / `TTUSDG` | Index wrap | **Empty** |

---

## 2.3 Dollar Quad leaf (D26) — remap R1

Fifth **leaf**. **3/3 SE-buffered** Curve Quad. Not in the D30 nest.

Each `standardExchanges[i]` **must contain** `pairTokens[i]` (`PairTokenNotInSeTokens` / hook `_requireSeOwnsToken`). The three fixture books stay the same; which book buffers which pair is the assignment that satisfies that law. An earlier draft put WETH on `TTUSDG`/`TTUSDE` — that SE does not hold WETH and cannot deploy.

| Leg | `pairToken` | Uni V4 book (0.30%, tick 60) | SE wraps that pool | RP rates shares → |
|-----|-------------|------------------------------|--------------------|-------------------|
| 0 | **`TTUSDE`** | `TTUSDE` / WETH | Uni V4 SE | **`TTUSDE`** |
| 1 | **`TTUSDG`** | `TTUSDG` / `TTUSDE` | Uni V4 SE | **`TTUSDG`** |
| 2 | **WETH** | `TTUSDG` / WETH | Uni V4 SE | **WETH** |

`pairToken`s `{TTUSDE, TTUSDG, WETH}` are pairwise distinct. Mixed-vol vs Quad like-kind *operator convention* — accepted so we can show an all-SE Quad next to the like-kind Index Quad. WETH = official testnet WETH. Do **not** use native ETH. `baseAmp = 100`. Symbol `TTDOL-Q`.

---

## 2.4 Fee-sink RICH (D36–D37)

| Item | Value |
|------|--------|
| Token | `TTRICH` / **Test Token RICH** / 18 decimals |
| Mint | Same facade as D33 + **1e12** to Anvil #0 and #1 (group 08) |
| Fee-sink DETF | Uni V4 **CP Single**, first-bonded live **and launch-rich** |
| `pairToken` | Official testnet WETH |
| SE / pool | Uni V4 `TTRICH` / WETH, **0.30%**, tick 60, seed 100/100, RP shares → `TTRICH` |
| PkgArgs | §2.8 row 10 |
| Fees | Oracle `feeTo` = FeeCollector. Fees **sit on the collector**. No scripted push (D37) |

Role names stay `pairToken` / `detfToken` — never a role named RICH.

---

## 2.5 Fixture pools and seed (D40, D45)

| Pool | Fee / tick | Seed from Anvil #0 | Group |
|------|------------|--------------------|-------|
| `TTNVDA` / `TTUSDG` | 0.30% / 60 | 1e9 each | 05 |
| `TTSPY` / `TTUSDG` | 0.30% / 60 | 1e9 each | 05 |
| `TTUSDG` / `TTUSDE` | 0.30% / 60 | 1e9 each | 05 |
| `TTUSDE` / WETH | 0.30% / 60 | 100 + 100 WETH | 05 |
| `TTUSDG` / WETH | 0.30% / 60 | 100 + 100 WETH | 05 |
| `TTRICH` / WETH | 0.30% / 60 | 100 + 100 WETH | 08 |
| `TTM7-W` / `TTUSDG` | 0.30% / 60 | **Empty** | 07 |
| `TTIDX-Q` / `TTUSDG` | 0.30% / 60 | **Empty** | 07 |

Anvil **#1** gets **no extra ETH**. Nest SEs may deploy empty (hook law).

---

## 2.6 DETF ERC-20 metadata (D44) and claim tokens (D55)

| # | Book | DETF symbol | DETF name | Claim symbol | Claim name |
|---|------|-------------|-----------|--------------|------------|
| 1 | NVDA Single | `TTNVDA-S` | Test DETF NVDA Single | `TC-TTNVDA-S` | Test Claim NVDA Single |
| 2 | NVDA+SMH Orbital | `TTNVDA-SMH-O` | Test DETF NVDA SMH Orbital | `TC-TTNVDA-SMH-O` | Test Claim NVDA SMH Orbital |
| 3 | Index Quad | `TTIDX-Q` | Test DETF Index Quad | `TC-TTIDX-Q` | Test Claim Index Quad |
| 4 | Mag7 Weighted | `TTM7-W` | Test DETF Mag7 Weighted | `TC-TTM7-W` | Test Claim Mag7 Weighted |
| 5 | Showcase nest | `TTNEST-W` | Test DETF Showcase Nest | `TC-TTNEST-W` | Test Claim Showcase Nest |
| 6 | Beta nest | `TTBETA-O` | Test DETF Beta Nest | `TC-TTBETA-O` | Test Claim Beta Nest |
| 7 | Index wrap | `TTIDX-WRAP` | Test DETF Index Wrap | `TC-TTIDX-WRAP` | Test Claim Index Wrap |
| 8 | Mag7 wrap | `TTM7-WRAP` | Test DETF Mag7 Wrap | `TC-TTM7-WRAP` | Test Claim Mag7 Wrap |
| 9 | Dollar Quad | `TTDOL-Q` | Test DETF Dollar Quad | `TC-TTDOL-Q` | Test Claim Dollar Quad |
| 10 | RICH fee-sink | `TTRICH-S` | Test DETF RICH Single | `TC-TTRICH-S` | Test Claim RICH Single |

These DETF symbols are protocol-minted shares, **not** facade `/mint` tokens. `/mint` lists only the 14 `TT*` stand-ins (13 in group 04 + `TTRICH`).

### SE share names (D53)

| Uni V4 pool | SE symbol | SE name |
|-------------|-----------|---------|
| `TTNVDA` / `TTUSDG` | `SE-TTNVDA-TTUSDG` | Test SE TTNVDA/TTUSDG |
| `TTSPY` / `TTUSDG` | `SE-TTSPY-TTUSDG` | Test SE TTSPY/TTUSDG |
| `TTUSDE` / WETH | `SE-TTUSDE-WETH` | Test SE TTUSDE/WETH |
| `TTUSDG` / WETH | `SE-TTUSDG-WETH` | Test SE TTUSDG/WETH |
| `TTUSDG` / `TTUSDE` | `SE-TTUSDG-TTUSDE` | Test SE TTUSDG/TTUSDE |
| `TTM7-W` / `TTUSDG` | `SE-TTM7-W-TTUSDG` | Test SE TTM7-W/TTUSDG |
| `TTIDX-Q` / `TTUSDG` | `SE-TTIDX-Q-TTUSDG` | Test SE TTIDX-Q/TTUSDG |
| `TTRICH` / WETH | `SE-TTRICH-WETH` | Test SE TTRICH/WETH |

---

## 2.7 First bond + launch-rich (D5, D47)

**Bonder:** `DEPLOYER_ADDRESS`. **Lock:** `86400` seconds (min). **`capitalToken`:** the SE-leg `pairToken` below. Excess external capital refunded (family law). After each first bond, `isReserveLive()` is true. After the richness step, D47 holds.

D38 `creationPairPerDetfWad = 1e18` remains the **peg** (synthetic 1.0). Empty-book first-bond join is `G = pair / opening`. Opening `0` resolves to creation (at peg). Launch-rich is **opening above peg**, not a second diamond `depositSingle`. D47 diamond impersonation is **rescinded**.

Nested first bonds use **inventory swaps** for free inner `detfToken`. Those same swaps, continued until D47, **are** the leaf richness step.

### Order

1. Deploy + first-bond **leaves** (1–4, 9).
2. **Inventory + richness swaps** on every leaf until D47. Keep S/O/Q/W `detfToken` for nest capital.
3. Deploy + first-bond **nests** (5–8).
4. **Richness swaps** on every nest until D47 (every external inner pair).
5. Deploy + first-bond **fee-sink** (10).
6. **Richness swap** on `TTRICH-S` until D47.

### Leaf first-bond capital (whole units, 18 decimals)

| Instance | Fund every external | `capitalToken` |
|----------|---------------------|----------------|
| `TTNVDA-S` | 10 `TTNVDA` | `TTNVDA` |
| `TTNVDA-SMH-O` | 10 `TTNVDA` + 10 `TTSMH` | `TTNVDA` |
| `TTIDX-Q` | 10 each `TTSPY` `TTVTI` `TTQQQ` | `TTSPY` |
| `TTM7-W` | 10 each Mag7 `TT*` (NVDA-first order) | `TTNVDA` |
| `TTDOL-Q` | 10 `TTUSDE` + 10 `TTUSDG` + **10 WETH** | `TTUSDG` |

### Inventory + richness swaps

Start with the nest-inventory sizes. Then add pair via `depositSingle` until D47. Slice each add at `min(need, fd/4)` so the SE-buffered zap can execute. Family `minOut = 1`.

On multi-leg books, sell **each** external `pairToken` (not only the SE door) until **that** pair’s `syntheticVs` ≥ 10.5e18.

| Reserve | #0 sells first | Then |
|---------|----------------|------|
| `TTNVDA-S` | 100_000 `TTNVDA` | more `TTNVDA` until D47 |
| `TTNVDA-SMH-O` | 100_000 `TTNVDA` | `TTNVDA` and `TTSMH` until **both** legs D47 |
| `TTIDX-Q` | 100_000 `TTSPY` | `TTSPY`, `TTVTI`, `TTQQQ` until **all three** D47 |
| `TTM7-W` | 100_000 `TTNVDA` | each Mag7 `TT*` until **all seven** D47 |
| `TTDOL-Q` | (none for nest inventory) | `TTUSDE`, `TTUSDG`, WETH until **all three** D47 |

Keep received S/O/Q/W balances for nest first bonds. Do **not** use `TTDOL-Q` `detfToken` as nest capital.

### Nest + fee-sink first-bond capital

| Instance | Fund every external | `capitalToken` |
|----------|---------------------|----------------|
| `TTNEST-W` | 10_000 each of S, O, Q, W | W (`TTM7-W`) |
| `TTBETA-O` | 10_000 W + 10_000 Q | W |
| `TTIDX-WRAP` | 10_000 Q | Q |
| `TTM7-WRAP` | 10_000 W | W |
| `TTRICH-S` | **10 WETH** | WETH |

If a nest first-bond needs more inner `detfToken` than the inventory swaps produced, **repeat the corresponding leaf swap** until #0 can fund the table. Do not invent another capital source.

After each nest / fee-sink first bond, run D47 on **every external pair** of that instance.

---

## 2.8 PkgArgs — complete (do not invent fields)

Shared on **all ten** (D38): creation `1e18` per external; Policy 1.05 / 0.95; expansion `0` / `0` / `0`; caller premines via `UniswapV4DetfHookPremineLib`; `deployVault(args, mineNonce)`; nonce not in PkgArgs; `vaultShares = address(0)` where an SE is set.

### Weighted weights (D32 + D54)

`TTM7-W` — `detfWeight = 200000000000000000`. Pair order = PkgArgs order:

| `pairToken` | Weight | WAD |
|-------------|--------|-----|
| `TTNVDA` | 18.4% | `184000000000000000` |
| `TTMSFT` | 16.0% | `160000000000000000` |
| `TTAAPL` | 14.4% | `144000000000000000` |
| `TTGOOGL` | 9.6% | `96000000000000000` |
| `TTAMZN` | 9.6% | `96000000000000000` |
| `TTMETA` | 7.2% | `72000000000000000` |
| `TTTSLA` | 4.8% | `48000000000000000` |

Pair sum = `800000000000000000`. + self-leg = `1e18`. These are the old 23/20/18/12/12/9/6 tape × 0.8.

`TTNEST-W` — `detfWeight = 200000000000000000`. Each of S, O, Q, W = `200000000000000000` (20%).

### Per-instance wiring

| # | Symbol | Family | `pairTokens` / SEs / RPs | Extra |
|---|--------|--------|--------------------------|-------|
| 1 | `TTNVDA-S` | CP Single | `TTNVDA` · SE `TTNVDA`/`TTUSDG` · RP → `TTNVDA` | — |
| 2 | `TTNVDA-SMH-O` | Orbital | `pair0=TTNVDA` SE+RP; `pair1=TTSMH` bare, no RP | `rateAsset=TTNVDA`; `detfBindingIndex=2` |
| 3 | `TTIDX-Q` | Curve Quad | `TTSPY` SE+RP; `TTVTI` bare; `TTQQQ` bare | `baseAmp=100` |
| 4 | `TTM7-W` | Weighted | Mag7 table above; SE+RP only on `TTNVDA` | `detfWeight=0.2e18` |
| 5 | `TTNEST-W` | Weighted | S,O,Q,W; SE+RP only on W | `detfWeight=0.2e18`; 20% × 4 |
| 6 | `TTBETA-O` | Orbital | `pair0=W` SE+RP; `pair1=Q` bare | `rateAsset=W`; `detfBindingIndex=2` |
| 7 | `TTIDX-WRAP` | CP Single | Q · SE `Q`/`TTUSDG` · RP → Q | — |
| 8 | `TTM7-WRAP` | CP Single | W · SE `W`/`TTUSDG` · RP → W | — |
| 9 | `TTDOL-Q` | Curve Quad | 3/3 SE+RP per §2.3 | `baseAmp=100` |
| 10 | `TTRICH-S` | CP Single | WETH · SE `TTRICH`/WETH · RP → `TTRICH` | — |

---

## 3. Proposed (not locked)

All prior proposals P2–P8 are **locked or superseded**. No open proposals.

---

## 4. Open questions

All closed. Token counts, groups, launch-rich, Weighted self-leg, SE/claim names, bond max, and WETH roles are in §2.

---

## 5. Why we cannot use official test tokens as demo money

Research 2026-08-14: official docs, faucet page, Crane `ROBINHOOD_TESTNET`, live RPC + Blockscout token API.

### 5.1 Official set (complete)

| Asset | How you get it | Mintable by us? |
|-------|----------------|-----------------|
| ETH (gas) | Faucet **0.01 / 24h**; also third-party faucets | No (native) |
| WETH `0x7943e237c7F95DA44E0301572D358911207852Fa` | Wrap official testnet ETH | Wrap only |
| TSLA / AMZN / PLTR / NFLX / AMD | Faucet **5 each / 24h** | **No** — `mint` reverts `MINTER_ROLE` |

Faucet: [faucet.testnet.chain.robinhood.com](https://faucet.testnet.chain.robinhood.com/). Official token contracts page publishes **USDG only on mainnet**. `ROBINHOOD_TESTNET.USDG = address(0)`. There is **no official mintable stablecoin** on testnet.

### 5.2 Not official (do not wire)

Explorer is full of community USDC / USDG / USDT / extra WETH clones. A matching ticker at a different address is **not** their token.

### 5.3 Infra that is live on 46630 (reuse)

| Pin | Address | Required? |
|-----|---------|-----------|
| WETH | `0x7943e237c7F95DA44E0301572D358911207852Fa` | **Yes** |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | **Yes** |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | Yes (reads) |
| L2 Multicall | `0xa432504b6F04Cafe775b09D8AA92e8dbe41Ec7a8` | Optional |
| Uni V4 PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` | **Yes** |
| Uni V4 PositionManager | `0x58daec3116aae6D93017bAAea7749052E8a04fA7` | **Yes** |
| Uni V4 Quoter | `0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94` | Yes (quotes) |
| Uni V4 StateView | `0xF3334192D15450CdD385c8B70e03f9A6bD9E673b` | Optional |
| Universal Router | `0x8876789976dEcBfCbBbe364623C63652db8C0904` | **Yes** |
| Faucet stock tokens | `ROBINHOOD_TESTNET.FAUCET_*` | Flavor only |
| Uni V2 / V3 factory, NPM, SwapRouter02 | no code / `address(0)` | **Do not require** |
| pons factory / locker / V3 router | 4663 pins have **no code** | **Do not require** |
| USDG | `address(0)` | Absent |
| Balancer V3 | not present | **Out of scope (D19)** |
| Mainnet WETH `0x0Bd7…AD73` | no code on 46630 | Do not use |

Therefore the 4663 **pons → Uni V3 SE → CHIR** path cannot be copied to 46630.

---

## 6. Minter facade (Crane — for group 04)

Public mint surface the DTF `/mint` page already calls.

| Path | Role |
|------|------|
| `lib/crane/contracts/tokens/ERC20/IERC20MinterFacade.sol` | `mintToken(IERC20MintBurn token, uint256 amount, address recipient)` |
| `ERC20MinterFacadeTarget.sol` | Cap + interval, then `token.mint` |
| `ERC20MinterFacadeRepo.sol` | `maxMintAmount`, `minMintInterval`, `lastMintTimestamps` |
| `ERC20MinterFacadeFacetDFPkg.sol` | `PkgArgs { maxMintAmount, minMintInterval }` |

Gold authorize pattern: archived `scripts/archive/foundry/sepolia/Script_07_DeployTestTokens.s.sol`

1. CREATE3-deploy `ERC20MinterFacadeFacetDFPkg`.
2. `diamondPackageFactory.deploy(facadePkg, abi.encode(PkgArgs))`.
3. On each Operable token: `setOperatorFor(IERC20MintBurn.mint.selector, facade, true)`.
4. Export `erc20MinterFacade`.

**D42 (must land in Crane before group 04):** `ERC20MinterFacadeTarget` must key `lastMintTimestamps` by **`(token, recipient)`** on both read and write.

---

## 7. Launch groups (requirements)

Logical **groups**. Shared modules + thin `Script_0N_*.s.sol`. **`Script_SimulateLaunch`** runs **01–08** in one simulation for gas.

```text
scripts/foundry/anvil_robinhood_testnet/
  DeploymentBase.sol
  RobinhoodCanonicalLib.sol
  libraries / stage modules for 01–08
  Script_00_Preflight.s.sol
  Script_01_Factories.s.sol
  Script_02_Platform.s.sol
  Script_03_UniV4Packages.s.sol
  Script_04_Tokens.s.sol
  Script_05_LeafPoolsAndSEs.s.sol
  Script_06_LeafDETFs.s.sol
  Script_07_NestDETFs.s.sol
  Script_08_FeeSink.s.sol
  Script_09_ExportFrontend.s.sol
  Script_SimulateLaunch.s.sol     # 01–08, one broadcast / one simulation
  deploy_all.sh
scripts/shell/anvil_robinhood_testnet.sh
deployments/anvil_robinhood_testnet/
frontend/packages/protocol/src/addresses/chain/46630/
```

### 7.1 Groups

| Group | Script | Reads | Writes | Artifact |
|-------|--------|-------|--------|----------|
| **00** Preflight | `Script_00_Preflight` | §5.3 required pins | none | `00_preflight.json` |
| **01** Factories | `Script_01_Factories` | — | CREATE3 factory, DiamondPackageCallBackFactory, Uni V4 **hook diamond factory**, shared ERC20 / ownable / operable / vault facets | `01_factories.json` |
| **02** Platform | `Script_02_Platform` | 01 | FeeCollector; IndexedexManager (registry + fee oracle); hook factory wired; SE RP **package**; D46 fees; D51 skip seigniorage setter; D52 liquid 20%; bond terms min `86400` / max `180 days` | `02_platform.json` |
| **03** Uni V4 packages | `Script_03_UniV4Packages` | 01+02, Uni V4 PM, Permit2 | Hook DFPkgs; Uni V4 SE **package**; DETF children **packages**; Uni V4 DETF **packages**. **No instances.** | `03_univ4_packages.json` |
| **04** Tokens | `Script_04_Tokens` | 01+02 | 13 §2.1 tokens + facade + 1e12 to #0 and #1 | `04_tokens.json` |
| **05** Leaf pools + SEs | `Script_05_LeafPoolsAndSEs` | 01–04 | Five §2.5 leaf pools + SEs + RPs; D45 seeds | `05_leaf_pools_ses.json` |
| **06** Leaf DETFs | `Script_06_LeafDETFs` | 01–05 | Five leaf DETFs + first-bond + D47 | `06_leaf_detfs.json` |
| **07** Nest DETFs | `Script_07_NestDETFs` | 01–06 | Two empty nest pools + SEs + RPs + four nest DETFs + first-bond + D47 | `07_nest_detfs.json` |
| **08** Fee-sink | `Script_08_FeeSink` | 01–07 | `TTRICH` + facade mint + pool/SE/RP + `TTRICH-S` + first-bond + D47. No fee push. | `08_fee_sink.json` |
| **Simulate** | `Script_SimulateLaunch` | pins | **01–08** in one broadcast | all group JSON except 09 |
| **09** Export | `Script_09_ExportFrontend` | 01–08 | `chain/46630/` platform + tokenlists. Protocol 46630 + DTF list/`/mint`. No extra ETH to #1. | frontend artifacts |

The SE rate-provider *type* may live under an existing `balancer/v3/rateProviders/standardExchange/` path. That is the **generic SE rate provider package**, not a Balancer vault. Using that package is allowed. Deploying Balancer is not.

### 7.2 Reset and gas

```text
prove group N
→ restart Anvil (fresh 46630 fork)
→ replay Script_01 … Script_0N
→ continue with N+1
```

Or run `Script_SimulateLaunch` on a fresh fork (omit `--broadcast`) for a full-prefix **gas estimate**.

Broadcast only if `RPC_URL` is localhost.

### 7.3 What this means for 4663 mainnet scripts later

Do **not** edit `anvil_robinhood_main` until this PRD is accepted and the 46630 groups are proven.

| Today (4663 lab) | This PRD |
|------------------|----------|
| Tokens at stage 04, no facade | Tokens + facade = **group 04** |
| No Balancer | **Still no Balancer** (D19) |
| Uni V3 required | **Not on 46630** |
| pons RICH at 14 | **Group 08** mintable stand-in |
| CHIR first-bonded at 20 | **First bond + D47** |
| Export at 22 | **Group 09** + DTF |

---

## 8. Frontend (group 09 — in the implementation plan)

| Item | Requirement |
|------|-------------|
| `CHAIN_ID_ROBINHOOD_TESTNET = 46630` | Beside `CHAIN_ID_ROBINHOOD = 4663` |
| `runtimeChains.ts` | `robinhoodTestnet` + Anvil localhost variant |
| `chain/46630/platform.json` | WETH, Permit2, Uni V4 pins, manager, **`erc20MinterFacade`**, 14 stand-ins, **ten** DETF addresses, SE addresses |
| `chain/46630/base-tokens.tokenlist.json` | 14 `TT*` tagged `token` + `testToken`; official WETH tagged `weth`; five faucet stocks tagged `rh-faucet` only |
| `/mint` | After group 04 + export; wallet on 46630 Anvil |
| DTF list | All ten DETFs equally (D49). No featured row. |

Do **not** overwrite `chain/4663/`.

---

## 9. Definition of done (requirements — not a build checklist)

When this PRD is accepted, the implementation plan is groups **00–09 + SimulateLaunch + DTF** (D50):

- Chain id 46630; required testnet pins still have code (not redeployed).
- Groups 01–03: factories, platform (D46/D51/D52/bond terms), Uni V4 **packages** only.
- Groups 04–08: 13 tokens + facade; leaf pools/SEs; five leaf DETFs live + D47; four nest DETFs live + D47; `TTRICH` + fee-sink live + D47.
- Every DETF: `isReserveLive()`, and D47 (all-legs mint-open, S ≥ 10.5e18).
- Group 09: `chain/46630/` export; protocol package 46630; DTF lists ten DETFs equally; `/mint` lists 14 stand-ins.
- Shell: local `scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil`; live `… all --live`. Both require `DEPLOYER_ADDRESS`.
- `Script_SimulateLaunch` runs **01–08**.
- Replay `01` … `09` after an Anvil reset succeeds.
- No Balancer, no pons, no Uni V3, no time warp, no fee push into `TTRICH-S`. Broadcast as `DEPLOYER_ADDRESS` (`--sender`; cast wallet) on Anvil and on public 46630. No 4663 broadcast from this tree.
- 4663 lab scripts and `chain/4663/` unchanged.

---

## 10. Explicit non-goals

- Live broadcast to **4663** from this tree (46630 `--live` is in scope, D4)
- Using faucet stock tokens or explorer USDC/USDG clones as fixture legs
- Redeploying RH WETH / Permit2 / Uni V4 cores
- Deploying Balancer or any Balancer vault / DETF
- Porting pons / Uni V3 onto 46630
- Replacing or rewriting the 4663 Anvil lab in this PRD’s first implementation
- Fabricating APY / USD prices in the UI
- Changing DETF / SE product behavior
- Extra themed **leaf** DETFs beyond D27+D26 (High-narrative, Semi core-7, Rates-3, …)
- Extra **nests** beyond D30
- Using `--unlocked` / Anvil impersonation as the deploy path (D4)

---

## 11. Operator notes (after implementation — not now)

```bash
export DEPLOYER_ADDRESS=0x...   # cast wallet; forge --sender

# Local Anvil rehearsal (node may use --disable-code-size-limit)
export ALCHEMY_KEY=...
bash scripts/shell/anvil_robinhood_testnet.sh all --restart-anvil

# Live 46630 (same scripts, same sender)
bash scripts/shell/anvil_robinhood_testnet.sh all --live
```

Wallet against the local fork: `http://127.0.0.1:8545`, chain id **46630**.  
Wallet against public testnet: §1 add-network table.

---

## 12. Revision log

| Date | Rev | Change |
|------|-----|--------|
| 2026-08-14 | v0.1–v0.4 | Working drafts while researching faucet tokens and iterating stages |
| 2026-08-14 | **v1.0** | Clean requirements PRD: D1–D25, no Balancer, grouped Foundry stages. |
| 2026-08-15 | **v1.1–v1.8** | D26–D46: showcase set, nests, fees, first-bond live, FeeCollector accumulate. |
| 2026-08-15 | **v1.9** | D47 launch-rich; D48–D53 warp / featured / 00–08 / seigniorage / SE names. |
| 2026-08-21 | **D4/D41** | 46630 groups are the live deploy path. `--sender $DEPLOYER_ADDRESS` (cast wallet). Anvil fork is rehearsal (`--disable-code-size-limit` on the node). `--live` for public 46630. No `--private-key`, no Anvil #0 default. |
| 2026-08-20 | **D4/D41** | First live-path rewrite (superseded 2026-08-21). |
| 2026-08-15 | **v2.0** | Consistency pass + implementation plan. **D54/D55**. D50 = groups 00–09 + DTF (Anvil rehearsal and `--live`). |

**Next:** execute [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md) with a goal-command agent.

# PRD: Rewrite Robinhood Testnet (46630) launch scripts

**Status:** **Accepted.** Requirements locked. Implement against the plan; do not invent Phases or pins.  
**Date:** 2026-08-23  
**Owner surface:** Foundry launch-group scripts under `scripts/foundry/anvil_robinhood_testnet/` plus Phase 09 frontend export to `frontend/packages/protocol/src/addresses/chain/46630/`  
**Implementation plan:** [`ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md)

| Doc / path | Role |
|------------|------|
| **This file** | Requirements for a **rewrite** of the 46630 launch scripts. Structure, pin law, packages vs instances. |
| [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) | Older accepted v2.0 demo law (ten DETFs, groups 07/08, no Uni V3). Historical for product numbers. **Not** the SoT for script layout after this rewrite. |
| [`ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_IMPLEMENTATION_AND_TEST_PLAN.md) | Implementor SoT for that older PRD. Freeze until replaced. |
| Crane `ROBINHOOD_TESTNET.sol` | Constants for 46630. Only addresses with bytecode on 46630 belong in preflight. |
| Family PRDs under `contracts/vaults/detf/**` and SE packages under `contracts/protocols/dexes/**`, `contracts/vaults/standard/exchange/protocols/morpho/blue/` | Product law for packages the scripts deploy. |
| `frontend/ROADMAP.md` | UI no-deploy policy on frontend-only turns. |
| Skills `crane-deployment`, `indexedex-testing` | CREATE3 / registry / never `new` facets or DFPkgs. |

---

## 0. How to use this file

This PRD is accepted. Rewrite only from the implementation plan. If a Stage, pin, or skip rule is missing from both files, stop and amend the PRD. Do not invent.

---

## 1. Problem

The current 46630 tree grew from a demo pipeline (factories, Uni V4 packages, mintable tokens, leaf Uni V4 SEs, `DTF-DETF`, `TTDOL-Q`, frontend export). Later we bolted on Weighted/Orbital packages, a rehearsal Morpho Blue, a Morpho Blue SE package, a rehearsal Uniswap V3 factory, and a Uni V3 SE package. Group numbers (`03b`, `03c`, `03d`) show that.

Group 00 mixed two jobs:

- **Live pins:** Uni V4 / Permit2 / WETH / Universal Router, which already have code on 46630.
- **Vendor catalogs from another chain:** Morpho’s Robinhood **main** CREATE2 table, plus a Uni V3 factory of `address(0)`.

Those catalog rows are not on 46630. The launch then deploys **rehearsal** Morpho (03c) and **rehearsal** Uni V3 factory (03d) at new addresses. Pinning empty mainnet CREATE2 first made `00_preflight.json` look like Morpho and Uni V3 were already there.

The older demo PRD still describes groups 07/08, ten DETFs, and “no Uni V3.” The on-disk scripts no longer match that document or a single clear purpose (demo product vs UI create-path lab).

---

## 2. One-line goal

One set of Foundry **Phases / Stages**. Two shell entrypoints (local Anvil Dev 0 vs public testnet `DEPLOYER_ADDRESS`). No single Foundry or shell command that hides every scenario. Phases initialize a slice of the environment. Stages group common operations inside a Phase.

---

## 3. Network (carried forward)

| | Value |
|--|--|
| Official name | Robinhood Chain Testnet |
| Chain ID | **46630** |
| Local Anvil | Fork **Robinhood Chain Testnet** always. `http://127.0.0.1:8545`, `--chain-id 46630 --disable-code-size-limit`. No blank-chain Anvil in this rewrite. |
| Local signer | Anvil Dev 0 + `--unlocked` |
| Live signer | `--live` as `DEPLOYER_ADDRESS` (cast wallet) |
| Fork alias | `robinhood_testnet_alchemy`, fallback `robinhood_testnet` |
| Artifacts | `deployments/anvil_robinhood_testnet/` |
| Frontend | `frontend/packages/protocol/src/addresses/chain/46630/` |

Do not broadcast this tree to 4663. Do not overwrite `chain/4663/`.

---

## 4. Script law: Phases and Stages (proposed locked)

This is the layout law for Foundry scripts from now on. Shell scripts choose **which Phases/Stages to run** and **which signer**. Foundry scripts do not encode Anvil vs public as two parallel trees.

**Phase:** a slice of environment init.  
**Stage:** a group of common operations inside a Phase.  
**Foundry unit:** one Stage (thin `Script_*` + library).  
**Shell:** composes Stages. No monolithic Foundry entrypoint that runs every scenario.

| Phase | Name | What belongs here | What does not |
|-------|------|-------------------|---------------|
| **00** | Environment init | Anvil-only setup and sanity: `deal`, unlock, chain-id checks that we would **not** do on a public network. Stages group those ops. | Anything that must also run on public 46630 |
| **01** | External dependencies | Per-protocol, per-version Stages. **Pin** a canonical address if it has bytecode on this chain. **Else** deploy a rehearsal instance of that external protocol. Uniswap V3, Uniswap V4, Morpho Blue, Permit2, WETH each get their own Stage (or an explicit skip). | Any IndexedEx or Crane factory / facet / package / vault / DETF |
| **02** | Crane factories | Stage 01: CREATE3 Factory. Stage 02: Diamond Package Factory. Stage 03: Uni V4 **Hook Factory** (IndexedEx-owned today; promote into Crane later in a **different** effort. Do not block this rewrite on that promotion). | Common facets, IndexedEx manager |
| **03** | Common facets | Stages by commonality (e.g. ERC20 + permit/EIP-712, ownership/operable, shared vault facets). If a facet is used by more than one SE or DETF package, it lives here. | Facets consumed by only one package (those stay in Phase 05 or 06) |
| **04** | IndexedEx core | Stage 01: Fee Collector and Indexedex Manager (wire Hook Factory on the manager here). Stage 02: ERC20 **Minter Facade**. | SE/DETF packages, test token **instances** |
| **05** | SE vault packages | Shared SE **Rate Provider** package as its own Stage (not specific to one SE type). Uni V4 multi-pool **TWAP oracle** (CREATE3 facet + DFPkg + canonical PoolManager instance + adapter factory) as its own Stage **before** the Uni V4 SE package. Then **one Stage per SE package**. A Stage may deploy facets used **only** by that package. If a facet becomes shared, **promote it to a new Phase 03 Stage.** The TWAP diamond is an **oracle instance**, not a vault: do not `deployVault` / vault-registry. | DETF packages, SE **vault instances** |
| **06** | DETF packages and hooks | Shared **bond NFT** package and shared **rebasing claim** package: each its own Stage (not specific to one DETF type). Then **one Stage per Hook DFPkg type**. Then **one Stage per DETF package**, including facets specific to that package. Same facet promotion rule to Phase 03. | DETF **instances**, test tokens |
| **07** | Chain-specific tokens and SE vaults | Test tokens and SE vault **instances**. Separate Stages. **Tokens never share a Stage with SEs.** Mag7 tokens are their own token Stage, distinct from the core four (`DTF`, `TTUSDG`, `TTUSDE`, `TTWETH`). | DETF instances (Phase 08), packages |
| **08** | Protocol DETF instances | Fee DETF (`DTF-DETF`) and USD quad (`TTDOL-Q`). **Separate Stages.** No tokens and no SE deploys in this Phase. | Packages, test tokens, SE vaults |
| **09** | Export | Concatenate live addresses from prior Phases into `frontend/packages/protocol/src/addresses/chain/46630/`. No on-chain txs. | Deploys |

### 4.1 Shell entrypoints (locked)

Two shells. Same Foundry Stages. No one Foundry script that runs every Phase.

1. **Local Anvil** (this rewrite’s default path): fork **Robinhood Chain Testnet (46630)** always. Signer Anvil Dev 0 (`--unlocked`). Runs **Phase 00 then every Stage of Phases 01–09**.
2. **Public testnet:** signer `DEPLOYER_ADDRESS` (cast wallet). **Does not run Phase 00.** Which of 01–09 it runs is **deferred** until UI testing on local Anvil is done. Do not invent a public subset in the first rewrite.

### 4.2 File naming (locked)

Foundry scripts:

`Phase_<PP>_Stage_<SS>_<PascalName>.s.sol`

Libraries:

`Phase_<PP>_Stage_<SS>_<PascalName>.sol`

Examples:

- `Phase_02_Stage_01_Create3Factory.s.sol`
- `Phase_02_Stage_03_HookFactory.s.sol`
- `Phase_04_Stage_02_Erc20MinterFacade.s.sol`
- `Phase_05_Stage_02_UniswapV4TwapOracle.s.sol`
- `Phase_07_Stage_02_Mag7TestTokens.s.sol`
- `Phase_08_Stage_01_FeeDetf.s.sol`
- `Phase_09_Stage_01_ExportFrontend.s.sol`

Shells invoke by Phase and Stage numbers, not by ad hoc group aliases (`03b`, `stage06t`).

### 4.3 Pin vs rehearsal (Phase 01)

A Phase 01 Stage for protocol P:

1. If a **canonical address for this chain** has code, pin it (JSON + later Stages bind it). Never redeploy Uni V4 / Permit2 / WETH when they already have code.
2. If this chain has no canonical instance, deploy a **rehearsal** host (e.g. `new Morpho`, `new UniswapV3Factory`). Write the **live** address in that Stage’s JSON.
3. Do not write another chain’s CREATE2 into the pin file when this chain has no code there.

Phase 01 on **mainnet** (later, out of scope for this rewrite except as the pattern) is typically pin-only.

`new Morpho` / `new UniswapV3Factory` are allowed **only** in Phase 01 rehearsal Stages. Never `new` facets or DFPkgs. Vault/DETF packages still go through Indexedex Manager / vault registry. `PkgInit` / `PkgArgs` on the **interface**.

If a Phase 05 or 06 facet later becomes shared, the **next** rewrite promotes it to Phase 03. Do not leave a copy in 05/06 and 03.

**Morpho markets:** Phase 01 deploys rehearsal Morpho Blue (plus IRM and oracle as that Stage needs). It does **not** `createMarket`. The **UI** creates Morpho markets. Morpho SE **vaults** are also UI, not Phase 07.

**Uni V3 pools and SE vaults:** UI creates them (factory `createPool` + `initialize` + package `deployVault`). Phase 01 Uni V3 Stage is rehearsal **factory** (and pin if code exists). NPM / SwapRouter / Quoter are not required for the DTF create wizard; do not deploy them unless a later PRD asks.

---

## 5. Draft Stage list (Anvil runs all)

Order is dependency order. Numbers may gain a Stage if we split further; do not skip a dependency.

| Phase | Stage | Name (sketch) |
|-------|-------|----------------|
| 00 | 01+ | Anvil deal / unlock / sanity (Anvil shell only) |
| 01 | 01 | Permit2 pin |
| 01 | 02 | WETH pin |
| 01 | 03 | Uniswap V4 pin (PoolManager, PositionManager, Universal Router, and other V4 pins with code) |
| 01 | 04 | Uniswap V3: pin factory if code, else rehearsal `UniswapV3Factory` (enable 0.01% / 0.05% / 0.3% / 1%) |
| 01 | 05 | Morpho Blue: pin if code, else rehearsal Morpho + AdaptiveCurveIRM + oracle |
| 02 | 01 | CREATE3 Factory |
| 02 | 02 | Diamond Package Factory |
| 02 | 03 | Uni V4 Hook Factory |
| 03 | 01 | All common facets in **one Stage** (ERC20 + permits, ownership/operable, diamond cut, shared vault facets) |
| 04 | 01 | Fee Collector + Indexedex Manager (set Hook Factory on manager; fee/bond/liquid defaults) |
| 04 | 02 | ERC20 Minter Facade |
| 05 | 01 | SE Rate Provider package |
| 05 | 02 | Uni V4 TWAP oracle (facet + DFPkg + canonical instance + adapter factory) |
| 05 | 03 | Uniswap V4 SE package (`PkgInit.twapOracle` from 05-02) |
| 05 | 04 | Uniswap V3 SE package |
| 05 | 05 | Morpho Blue SE package |
| 06 | 01 | Bond NFT package |
| 06 | 02 | Rebasing claim package |
| 06 | 03+ | One Stage per Hook DFPkg type (CP buffer, Weighted buffer, Orbital buffer, Curve Quad buffer, …) |
| 06 | then | One Stage per DETF package (CP, Weighted, Orbital, Curve Quad, …) |
| 07 | 01 | Core test tokens (`DTF`, `TTUSDG`, `TTUSDE`, `TTWETH`) + facade mint |
| 07 | 02 | Mag7 test tokens (`TTNVDA` … `TTTSLA`) |
| 07 | then | Uni V4 SE **instances** required by Phase 08 (`DTF`/`TTWETH`, three USD SEs). No Morpho or Uni V3 SE instances. |
| 08 | 01 | Fee DETF (`DTF-DETF`) |
| 08 | 02 | USD quad DETF (`TTDOL-Q`) |
| 09 | 01 | Export frontend JSON from prior Stage artifacts |

Phase 03 Stage split (ERC20 vs vault vs DETF facets) can be chosen in the implementation plan without changing this law.

---

## 6. As-built today (honest inventory)

Current `all` runs: `00 01 02 03 03b 03c 03d 04 04b 05 06t 06e 09`. One shell with flags. Descriptive only.

| Today | New home |
|-------|----------|
| Group 00 live Uni V4 / Permit2 / WETH / UR | Phase 01 pin Stages |
| Anvil start / deal / `--unlocked` | Phase 00 |
| CREATE3 + diamond factory | Phase 02 Stages 01–02 |
| Hook diamond factory | Phase 02 Stage 03 |
| Shared ERC20 / vault / ownable facets | Phase 03 |
| FeeCollector + IndexedexManager + fee defaults | Phase 04 Stage 01 |
| ERC20MinterFacade | Phase 04 Stage 02 |
| SE rate-provider package | Phase 05 Stage 01 |
| Uni V4 TWAP oracle (facet + DFPkg + canonical instance + adapter factory) | Phase 05 Stage 02 |
| Uni V4 / V3 / Morpho SE packages | Phase 05 later Stages |
| Morpho / Uni V3 rehearsal hosts | Phase 01 Stages 04–05 |
| Bond NFT + rebasing claim pkgs | Phase 06 Stages 01–02 |
| Family hook DFPkgs | Phase 06, one Stage per hook type |
| CP / Weighted / Orbital / Curve Quad DETF pkgs | Phase 06, one Stage per DETF package |
| Core four tokens | Phase 07 Stage 01 |
| Mag7 tokens | Phase 07 Stage 02 |
| Uni V4 SE instances | Phase 07 SE Stages |
| `DTF-DETF`, `TTDOL-Q` | Phase 08 Stages 01–02 |
| Group 09 frontend export | Phase 09 |

---

## 7. Non-goals

- Rewriting `anvil_robinhood_main` or `anvil_robinhood_fee_detf` in this pass.
- Promoting Hook Factory into Crane (separate effort).
- Public 46630 Stage subset (deferred until Anvil UI testing).
- Deploying Balancer, pons, or Uni V2 unless a Phase 01 Stage is added.
- Scripting Morpho `createMarket` or Morpho / Uni V3 SE **instances**.
- Replacing DETF family product law (thresholds, opening WAD, role names).
- A Foundry script that runs every Phase in one `run()` (no `Script_SimulateLaunch` monolith).

---

## 8. Closed (2026-08-23)

| Q | Decision |
|---|----------|
| A | **Skip a Stage** when its JSON addresses are present **and** those addresses have bytecode. `FORCE=1` re-runs. |
| B | **Always deploy a new CREATE3 Factory** in this tree. When a canonical CREATE3 exists, add it to the network constants library and pin it in Phase 01. Not in this rewrite. |
| C | FeeCollector / Manager **facets** deploy in **Phase 04 Stage 01** (not Phase 03). |
| D | **One Stage** for all common facets (Phase 03 Stage 01). |

---

## 9. Locked

| # | Decision |
|---|----------|
| R1 | Foundry scripts are **Phases** with **Stages**. Shells compose them. No one Foundry script for every scenario. |
| R2 | **Two shells:** Anvil Dev 0 (Phase 00 + 01–09) and public 46630 as `DEPLOYER_ADDRESS` (never Phase 00; Stage list deferred). |
| R3 | Anvil **always forks 46630**. |
| R4 | Phase 00 is Anvil-only env init (`deal` and similar). |
| R5 | Phase 01 is **external deps only**: pin if this chain has code, else rehearsal. No IndexedEx architecture. |
| R6 | Phase 02: CREATE3, Diamond Package Factory, then **Hook Factory**. Crane promotion of Hook Factory is out of scope. |
| R7 | Phase 03 is **common** facets. Package-only facets stay in 05/06 until promoted. |
| R8 | Phase 04 Stage 01: Fee Collector + Indexedex Manager. Stage 02: **Minter Facade**. |
| R9 | Phase 05: shared **SE Rate Provider** Stage, Uni V4 **TWAP oracle** Stage (facet + DFPkg + canonical instance + adapter factory, not a vault), then one Stage per **SE package**. |
| R10 | Phase 06: shared **bond NFT** Stage, shared **rebasing claim** Stage, **one Stage per Hook DFPkg type**, **one Stage per DETF package**. |
| R11 | Phase 07: tokens and SE **instances** only. Core four tokens and Mag7 are **separate token Stages**. Tokens never share a Stage with SEs. No Morpho or Uni V3 SE instances here. |
| R12 | Phase 08: **Fee DETF** and **TTDOL-Q**, separate Stages. |
| R13 | Phase 09: export addresses from prior Stages. No txs. |
| R14 | File names: `Phase_<PP>_Stage_<SS>_<PascalName>.s.sol`. |
| R15 | Do not pin another chain’s empty CREATE2. Uni V4 / Permit2 / WETH on 46630 are Phase 01 **pins**. Morpho and Uni V3 on 46630 are Phase 01 **rehearsal deploys**. Uni V3 rehearsal is the **factory**. |
| R16 | **UI** creates Morpho markets, Morpho SE vaults, and Uni V3 pools/SEs. |
| R17 | Crane-first: no `new` facets/DFPkgs. Registry for vault/DETF packages. |
| R19 | Skip Stage if JSON addresses exist and have code. `FORCE=1` re-runs. |
| R20 | Phase 02 Stage 01 always **deploys** CREATE3. Do not pin a CREATE3 until it is in network constants. |
| R21 | FeeCollector / Manager facets are Phase 04 Stage 01. |
| R22 | Phase 03 is **one Stage** for all common facets. |

---

## 10. Success

- A reader can name the Phase for a file from the path.
- Anvil shell runs every Stage of 00–09 against a 46630 fork as Dev 0.
- Phase 01 Uni V4 JSON is a pin of existing bytecode; Morpho/Uni V3 JSON is the rehearsal address that Stage deployed.
- Phase 05/06 contain no vault/DETF **instances**.
- Phase 07 token Stages contain no `deployVault`. Phase 07 SE Stages contain no DETF `deployVault`. Phase 08 contains no token or SE deploys.
- Phase 09 `platform.json` has live `morpho`, `morphoBlueSePkg`, `v3Factory`, `uniV3SePkg`, DETF pkgs, Uni V4 SE pkg, `twapOracle` / `twapOraclePkg` / `twapAdapterFactory`, manager, facade, tokens, listed Uni V4 SEs, `DTF-DETF`, `TTDOL-Q`.

---

## 11. Next

Implementation plan is [`ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_TESTNET_LAUNCH_SCRIPTS_REWRITE_IMPLEMENTATION_AND_TEST_PLAN.md). Execute that plan. Do not invent Stages.

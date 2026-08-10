# PRD: Robinhood Launch — RH-only RICH on pons + Uni SE + Fee DETF

**Status:** **Draft v0.4** — package path corrected (constant-product CP DETF); **implementor plan ready**  
**Date:** 2026-08-09  
**Owner surface:** Local test scenario scripts (Foundry Anvil fork + **separate** shell family) · `@indexedex/protocol` artifacts · **Indexedex** frontend first (dtf app later)  
**Working title / track:** **Robinhood-only** fee-DETF lifecycle — pons **RICH** → Uni V3 SE → **CHIR** CP fee-DETF · scripted bootstrap · UI for remaining surface  
**Implementor SoT (scripts):** [`ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md`](./ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md)

**Related (in-scope references):**

| Doc / path | Role |
|------------|------|
| **[Implementation plan](./ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md)** | **Script/Anvil stages, file map, bootstrap DoD** |
| [`docs/ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md`](./ANVIL_ROBINHOOD_UNISWAP_V4_DETF_DEPLOY_PRD.md) | Sibling **lab** Anvil RH fixture — **do not merge**; pure lab only |
| [`docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md`](./ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md) | Operator patterns for fork + UI on 4663 (adapt for new shell family) |
| `scripts/foundry/anvil_robinhood_main/` | Lab only (D16) — **not** this launch shell family |
| Uni V3 SE under `contracts/protocols/dexes/uniswap/v3/` | **Required** SE wrapping pons RICH/WETH pool |
| **Fee-DETF** under `…/uniswap/v4/standardExchange/constantProduct/single/` | Uni V4 Single SE CP DETF + Buffer CP Hook reserve (**not** listing DETF) |
| Skills `pons-architecture`, `pons-integration`, `pons-operations` | pons v1 facts |
| Crane `ROBINHOOD_MAIN.sol` | RH Uni / WETH / Permit2 / **Universal Router** pins |
| `frontend/ROADMAP.md` + `frontend/apps/indexedex/` | Indexedex first; fee-DETF UI on **`/staking`** |
| `@indexedex/protocol` `chain/4663/` | Address + tokenlist export SoT |

**Out-of-scope as product references (D26):** Base CCA RICH, Ethereum RICH supply plans, multi-chain launch calendars in `LAUNCH_PLAN.md` / `ROBINHOOD_LAUNCH_PLAN.md` capital topology. Those docs may still exist historically; **this PRD does not depend on them.** This track is **RH-only RICH via pons**.

---

## 0. One-line goal

Ship a **dedicated local Anvil (4663) test scenario** and **Indexedex UI** for a **Robinhood-only** stack: **create RICH on pons v1**, wrap the pons **Uni V3 RICH/WETH pool** in a **Uni V3 Standard Exchange**, deploy a **launch-rich, price-gated Single Standard Exchange fee-DETF** (destination for protocol fees / Fee Collector deposits — **manual** fee routing out of automated DoD), **script** pons launch + **large market buy** + **minimal first bond** that sets a **very high** initial price (**~10 WETH per DETF token**), export **`chain/4663/`**, then use the **UI** (Universal Router swaps, **`/staking`** fee-DETF workspace) for subsequent bond, sell→rebasing claim, and full fee-DETF + Uni V4 integration testing — **with zero Balancer integrations**.

---

## 0.1 Locked decisions

| # | Decision | Status |
|---|----------|--------|
| **D1** | **Target chain** is Robinhood Chain mainnet / Anvil fork with chain ID **`4663`**. | **Locked** |
| **D2** | Integration venues: **Uniswap V3** and **Uniswap V4** (RH-canonical). Both IndexedEx V3/V4 architecture components are in the **local test / launch readiness BOM**. Fee-DETF path requires **Uni V3** (pons pool + Uni V3 SE). | **Locked** |
| **D3** | **Fee-DETF product** is a **Single Standard Exchange DETF** whose **underlying** is a **Uni V3 Standard Exchange** on the **pons RICH/WETH pool**. It is the instance intended to **receive protocol fees** deposited from the **Fee Collector** (and, manually, pons launch/pool fees). | **Locked** |
| **D4** | **Hero SE** = **Uniswap V3 Standard Exchange** wrapping the pons v1 **RICH/WETH** Uni V3 pool. | **Locked** |
| **D5** | **Layer cake:** | **Locked** |
| | ```text | |
| | pons v1 factory → RH-only RICH | |
| |   → Uni V3 pool (RICH / WETH) | |
| |     → Uni V3 Standard Exchange | |
| |       → Single SE fee-DETF (launch-rich + price-gated mint/burn) | |
| | ``` | |
| **D6** | **pons** is required: we **create RICH** via the pons factory. Promo + in-app trade in scope. | **Locked** |
| **D7** | **Scripted bootstrap (supersedes earlier “no scripted bond”):** scripts **do** run (1) RICH pons launch, (2) **market buy** of a **large** RICH amount, (3) **first bond** with a **minimal** RICH+WETH size aimed at **~10 WETH per DETF token** initial pricing. **Do not** script later bonds, sell→rebasing claim, or full surface — those are **UI tests**. | **Locked** (v0.3) |
| **D8** | **Frontend work order:** Indexedex first, then dtf. Shared protocol package for artifacts. | **Locked** |
| **D9** | Artifacts: `frontend/packages/protocol/src/addresses/chain/4663/` + tokenlists; **no hard-coded vault tables**. | **Locked** |
| **D10** | `anvil_robinhood_main` remains **lab only**; not this path. | **Locked** |
| **D11** | Anvil **#0** = deployer / pons creator / script actor for bootstrap; **#1** = UI test wallet (post-bootstrap UI flows). | **Locked** |
| **D12** | Token **address** is identity; symbol **RICH** is a label (pons names are not unique). | **Locked** |
| **D13** | Graduation is not a quality claim. | **Locked** |
| **D14** | Product voice: honest; pons as venue; no fake partnership; no stock-token framing. | **Locked** |
| **D15** | DETF role names in protocol interfaces; UI may show RICH as symbol. | **Locked** |
| **D16** | **Separate shell family only** for this scenario. | **Locked** |
| **D17** | Uni V3 **and** Uni V4 architecture components in BOM; UI must be able to **test Uni V4 integrations** once deployed. | **Locked** |
| **D18 / D29** | **No Balancer integrations for the Robinhood launch / this scenario.** Do not deploy Balancer Vault, factories, routers, or Balancer-SE paths. Fee-DETF implementation **must not depend on Balancer**. *(Supersedes v0.2 “minimum Balancer host if needed.”)* | **Locked** (v0.3) |
| **D19** | Create **RH-only RICH** via pons v1 factory on the fork (our launch). | **Locked** |
| **D20** | RICH acquisition for bootstrap/UI: **market buy on the pons Uni V3 pool** (no happy-path `deal` of RICH). Scripts perform the **large** market buy for bootstrap. | **Locked** |
| **D21** | Fee-DETF for this first pass: **launch-rich** + **price-gated mint/burn** (long expansion runway). It is the **fee-accruing** instance (Fee Collector deposit target by product intent). | **Locked** |
| **D22 / D30** | In-app RICH buy/sell integrates with **Uniswap Universal Router** on Robinhood (`ROBINHOOD_MAIN.UNISWAP_UNIVERSAL_ROUTER` = `0x8876789976dEcBfCbBbe364623C63652db8C0904`). | **Locked** (v0.3) |
| **D23** | First UI milestone: **Anvil fork 4663** first. | **Locked** |
| **D24** | First pass purpose: fee-DETF path end-to-end enough for local + UI validation of fee-DETF product surface (not automated multi-vault fee distribution). | **Locked** |
| **D25** | Launch-rich + price-gate **PkgArgs** from family law / TestBase templates (implementor copies numbers; target first-bond economics per D31). | **Locked** |
| **D26** | **RH-only scope:** only Robinhood launch matters now. Other chains’ launch plans are **out of scope and not requirements references**. RICH in this PRD = **RH pons instance only**. | **Locked** (v0.3) |
| **D27** | **Fee routing is manual for now:** fees from other vaults → Fee Collector → deposit into fee-DETF is **not** automated in scripts/UI DoD. **Pons** creator/pool fees are also **collected and routed manually** into this DETF later. **No need to test fee distribution automation** in this pass. | **Locked** (v0.3) |
| **D28** | **First bond capital:** after market-buying RICH, bond with **RICH and WETH** (both legs as required by Single SE DETF first bond). | **Locked** (v0.3) |
| **D31** | **Bootstrap economics (intent):** market-buy **a lot** of RICH; use a **minimal** first bond sized so initial DETF price is **very high**, target **~10 WETH per DETF token**. Remaining RICH/WETH used later via **UI** for a **normal bond** and **sell for rebasing claim token**. Exact swap/bond sizes tunable in implementor plan; ratio intent is locked. | **Locked** (v0.3) |
| **D32** | Fee-DETF UI home: **reuse `/staking`** (existing fee-DETF IA). | **Locked** (v0.3) |
| **D33** | **This first pass includes the fee-accruing DETF** for local testing. **Which specific DETF instance(s) ship at public launch** is decided **after** UI work. Uni V4 integration components **are** included and **tested in the UI**; extra DETF *instances* for launch catalog remain deferred. | **Locked** (v0.3) |

### 0.1.1 Package selection (resolved v0.4)

| Role | Path |
|------|------|
| Fee-DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/` |
| Reserve host | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` (Buffer CP Hook holds SE shares as pair leg) |
| Backing SE | `contracts/protocols/dexes/uniswap/v3/` |
| **Out** | `…/uniswap/v4/standardExchange/single/` (listing DETF) · Balancer Single SE DETF |

**Roles:** `detfToken` = **CHIR**; `pairToken` / rateAsset = **WETH**; RICH = other token in pons Uni V3 pool (not DETF pairToken). First bond capital = **WETH** (pair path).

---

## 0.2 Glossary

| Term | Meaning in this PRD |
|------|---------------------|
| **RICH** | **Robinhood-only** token created via **pons v1** in this scenario. Not Base/Ethereum launch-plan RICH. Address is identity. |
| **Fee-DETF** | Launch-rich, price-gated **Single SE DETF** over Uni V3 SE(RICH/WETH); intended sink for Fee Collector deposits and manual fee routing. |
| **Fee Collector** | Protocol fee aggregation surface; **manual** deposit into fee-DETF for now (D27). |
| **Bootstrap** | Scripted: pons create RICH → large market buy → minimal high-price first bond (D7, D31). |
| **Universal Router** | RH Uniswap Universal Router for in-app RICH swaps (D30). |
| **Lab fixture** | `anvil_robinhood_main` only. |

---

## 0.3 Explicit non-goals

| Non-goal | Notes |
|----------|--------|
| Other-chain RICH / CCA / multi-chain calendars | D26 |
| Automated fee distribution Fee Collector → fee-DETF | D27 — manual later |
| Automated pons fee claim → fee-DETF | D27 — manual later |
| Any **Balancer** deploy or integration on RH | D29 |
| Scripting post-first-bond surface (normal bond, sell→rebasing) | UI only (D7) |
| Final public-launch DETF instance catalog | After UI (D33) |
| Merging into `anvil_robinhood_main` | D16 |
| pons v2 | Not live |
| dtf app first | D8 |
| Happy-path `deal` of RICH | D20 |
| Fabricated APY / TVL / USD | Honesty |

---

## 1. Problem statement

We need a **RH-only** local rehearsal of:

```text
pons launch RICH → Uni V3 SE → fee-DETF
  script: large buy + minimal ~10 WETH/DETF first bond
  UI: Universal Router · /staking · further bonds · rebasing sell · Uni V4 surfaces
```

…without Balancer, without multi-chain capital plans, and without automated fee-pipeline testing.

---

## 2. Hero product architecture

### 2.1 Stack

```text
┌─────────────────────────────────────────────────────────────────────┐
│  Indexedex UI (Anvil 4663)                                          │
│  Universal Router RICH swap · /staking fee-DETF · Uni V4 test UI    │
├─────────────────────────────────────────────────────────────────────┤
│  Fee-DETF: Single SE DETF (launch-rich + price-gated)               │
│  Fee Collector deposit target (manual routing) · no Balancer        │
│  First bond: RICH + WETH (scripted minimal high-price)              │
├─────────────────────────────────────────────────────────────────────┤
│  Uniswap V3 Standard Exchange ← pons RICH/WETH pool                 │
├─────────────────────────────────────────────────────────────────────┤
│  pons v1 → RH-only RICH + locked Uni V3 pool                        │
├─────────────────────────────────────────────────────────────────────┤
│  RH Uni V3/V4 cores · WETH · Permit2 · Universal Router             │
│  IndexedEx Uni V3 + Uni V4 architecture packages (no Balancer)      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Pins (RH)

| Item | Value |
|------|--------|
| Chain ID | `4663` |
| pons v1 factory | `0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB` |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| Universal Router | `0x8876789976dEcBfCbBbe364623C63652db8C0904` |
| Explorer | `https://robinhoodchain.blockscout.com` |
| Anvil RPC (first milestone) | `http://127.0.0.1:8545` |

### 2.3 Fee-DETF role (product)

| Aspect | Intent |
|--------|--------|
| What it is | Single SE DETF over Uni V3 SE(RICH/WETH) |
| Why | Instance that will **hold / receive** protocol fees when Fee Collector distributes; also manual destination for pons-related fees |
| Automation now | **None** for fee push — manual deposit later |
| Policy | Launch-rich + price-gated mint/burn; long expansion runway |
| First bond | RICH + WETH; minimal size → **~10 WETH per DETF token** |

### 2.4 Balancer

**Forbidden** for this track (D29). See §0.1.1 package gate.

### 2.5 Uni V3 / Uni V4

| | Role |
|--|------|
| **V3** | pons pool, Uni V3 SE, Universal Router RICH swap, fee-DETF underlying |
| **V4** | Architecture packages + **UI test surface** in this pass; launch instance catalog later (D33) |

---

## 3. Lab pipeline relationship

| | Lab `anvil_robinhood_main` | This PRD shell family |
|--|---------------------------|------------------------|
| Purpose | Broad multi-family lab | RH fee-DETF + pons RICH bootstrap |
| Merge? | No | Separate entry only |
| First bond | Lab policy | **Scripted** minimal high-price first bond |
| Balancer | N/A for this PRD | **None** |

---

## 4. Test scenario

### 4.1 Scripted bootstrap (DoD)

1. Anvil **4663** fork + preflight RH pins (incl. Universal Router code).  
2. Crane + Indexedex core (manager, registry, fee oracle, fee collector as needed).  
3. Deploy Uni V3 + Uni V4 architecture packages (BOM; no Balancer).  
4. **Pons create RICH** (deployer creator).  
5. Deploy **Uni V3 SE** on RICH/WETH pool (+ RP if required).  
6. Deploy **fee-DETF** (launch-rich + price gates) with SE underlying — still inert until step 8.  
7. **Market buy large RICH** (script; pool / Universal Router as appropriate on chain).  
8. **First bond** with **RICH + WETH**, **minimal** size targeting **~10 WETH per DETF token**.  
9. Export `chain/4663/` (RICH live, fee-DETF **live** after first bond, packages, pins).

### 4.2 UI-tested after bootstrap (not scripted)

| Journey | Priority |
|---------|----------|
| Connect Anvil 4663 | P0 |
| Promo RICH (address-first) | P0 |
| **Universal Router** buy/sell RICH in Indexedex | P0/P1 |
| `/staking` fee-DETF workspace | P0 |
| **Normal bond** with remaining inventory | P0 |
| **Sell for rebasing claim token** | P0 |
| Mint/burn under price gates, portfolio, bond NFT | P0/P1 |
| Uni V4 integration surfaces (packages/SE as exported) | P0 for “can exercise”; instances optional |
| Manual fee deposit UX | **Out** this pass (D27) |

### 4.3 Stage map (proposal)

| Stage | Responsibility |
|-------|----------------|
| L-00 | Preflight 4663 + RH pins |
| L-01 | Crane foundation |
| L-02 | Indexedex core |
| L-03+ | Uni V3/V4 architecture BOM (no Balancer) |
| L-PONS | Create RICH |
| L-SE-V3 | Uni V3 SE on RICH/WETH |
| L-RP | Rate providers if needed |
| L-FEE-DETF | Fee-DETF package + instance (launch-rich / gated) |
| L-BUY | Large market buy of RICH |
| L-FIRST-BOND | Minimal RICH+WETH first bond (~10 WETH/DETF intent) |
| L-EXPORT | `chain/4663` |

### 4.4 Artifacts (minimum keys)

`chainId`, `ponsFactory`, `rich`, `richWethPool`, `uniV3Se_rich`, `feeDetf`, `feeDetfTemplate=launch-rich`, `universalRouter`, `weth`, `permit2`, manager/registry/packages, Uni V3/V4 BOM addresses, tokenlists with tags `rich`, `pons-launch`, `fee-detf`, `featured-fee-detf` (or equivalent for `/staking`).

### 4.5 Wallets

| Account | Role |
|---------|------|
| #0 | Deploy, pons create, scripted buy + first bond (or fund #1 then prank — implementor chooses; bootstrap must leave UI-usable state) |
| #1 | UI wallet for post-bootstrap flows; must hold remaining RICH/WETH after bootstrap if #0 performed buy/bond, **or** hold bought RICH if buy is to #1 |

**Implementor note:** Prefer scripted market buy + first bond so **UI wallet (#1)** retains surplus RICH/WETH for normal bond + sell tests; first bond may be from #1 with scripted txs, or #0 bonds minimal and transfers surplus to #1 — document choice in implementor plan.

---

## 5. Frontend (Indexedex first)

| Area | Requirement |
|------|-------------|
| Chain 4663 + Anvil transport | Yes |
| Explorer Blockscout | Yes |
| Artifacts-driven addresses | Yes |
| **Swap** via **Universal Router** for RICH/WETH | Yes (D30) |
| Fee-DETF on **`/staking`** | Yes (D32) |
| Post-bootstrap: normal bond, sell→rebasing | Yes |
| Uni V4 test surfaces | Yes (D33) |
| Automated fee routing UI | No (D27) |
| dtf app | Later (D8) |

Promo CTA: **Buy RICH (Universal Router) → Manage fee-DETF on /staking**.

---

## 6. Open / deferred (non-blocking for plan start)

| # | Topic | Notes |
|---|--------|-------|
| **F1** | Exact Uni V4 package inventory | Enumerate in implementor plan |
| **F2** | Fee-DETF package path without Balancer | **Gate** §0.1.1 — must resolve before fee-DETF stages |
| **F3** | Exact swap size “a lot” and first-bond amounts for ~10 WETH/DETF | Calibrate in plan/scripts; ratio intent locked |
| **F4** | Which actor holds surplus after bootstrap (#0 vs #1) | Implementor plan |
| **F5** | Shell family names | Implementor plan |
| **F6** | Public RH production deploy | After local green |
| **F7** | Public launch DETF instance set | After UI (D33) |

---

## 7. Success criteria (DoD)

### 7.1 Scripts / chain

- [ ] Separate shell family runnable on Anvil 4663.  
- [ ] RH-only RICH created via pons; SE + fee-DETF deployed **without Balancer**.  
- [ ] Uni V3 + Uni V4 architecture BOM present.  
- [ ] Large market buy + minimal first bond (~10 WETH/DETF intent) **scripted**.  
- [ ] Export `chain/4663/` includes RICH, SE, fee-DETF, Universal Router, packages.  
- [ ] No happy-path `deal` of RICH; CREATE3 / registry only.

### 7.2 Indexedex UI

- [ ] Connect 4663 Anvil.  
- [ ] Universal Router buy/sell RICH.  
- [ ] `/staking` fee-DETF workspace works post-bootstrap (already live).  
- [ ] UI: normal bond + sell for rebasing claim.  
- [ ] Uni V4 integration surfaces exercisable as exported.  
- [ ] No hard-coded vault tables.

### 7.3 Explicitly out of DoD

- [ ] Automated Fee Collector → fee-DETF distribution  
- [ ] Automated pons fee → fee-DETF  
- [ ] Balancer anything  
- [ ] Other-chain RICH  
- [ ] Final launch DETF catalog  
- [ ] dtf parity  

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| No Balancer-free Single SE DETF package | §0.1.1 gate before stages |
| First-bond math ≠ ~10 WETH/DETF | Calibrate L-FIRST-BOND; document measured price |
| Large market buy impact / launch restrictions | Respect pons protection windows; size carefully |
| Surplus not on UI wallet | F4 — plan actor flow |
| Lab vs launch `chain/4663` collisions | Tags + launch-owned keys |

---

## 9. Workstreams

```text
1. Resolve fee-DETF package without Balancer (§0.1.1)
2. Implementor plan: separate shell family + stages L-* 
3. Scripts: pons RICH → SE → fee-DETF → large buy → first bond → export
4. Protocol artifacts / tokenlists / featured fee-DETF tags
5. Indexedex: 4663 plumbing
6. Indexedex: Universal Router RICH swap
7. Indexedex: /staking fee-DETF post-bootstrap flows + Uni V4 UI tests
8. Rehearse DoD §7 → then dtf port
```

---

## 10. Revision history

| Version | Date | Notes |
|---------|------|--------|
| **v0.1** | 2026-08-09 | Initial draft; O1–O10 open |
| **v0.2** | 2026-08-09 | O1–O10 → D16–D25 |
| **v0.3** | 2026-08-09 | Clarifying Qs 1–8: **RH-only RICH**; fee-DETF = Fee Collector sink (**manual** fees); **no Balancer**; **Universal Router**; script bootstrap; **`/staking`**; etc. |
| **v0.4** | 2026-08-09 | Package correction: **constantProduct/single** CP DETF + Buffer CP Hook (not listing DETF). Roles: **CHIR** / **WETH** pairToken; reserve hook holds SE shares. Link implementor plan `ANVIL_ROBINHOOD_FEE_DETF_LAUNCH_IMPLEMENTATION_AND_TEST_PLAN.md`. First bond = **WETH** pair path. |

---

## 11. Next steps

1. **Package gate:** confirm Single SE fee-DETF without Balancer (§0.1.1).  
2. Implementation plan for separate shell family + Indexedex lifecycle.  
3. Implement scripts → artifacts → Indexedex.

§0.1 locked decisions stay stable unless an explicit supersession note is added.

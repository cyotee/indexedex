# Implementation Plan: Anvil Robinhood Fee-DETF Launch Scenario (CHIR + RICH/pons)

**Product PRD (law SoT):** [`ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md`](./ROBINHOOD_PONS_SINGLE_SE_DETF_LAUNCH_TEST_SCENARIO_PRD.md) (**v0.3** + package correction below)  
**This plan (implementor SoT):** separate Foundry shell family + staged scripts + bootstrap + `chain/4663` export for **Indexedex UI** work  
**Date:** 2026-08-09  
**Status:** **READY FOR EXECUTION** (script/deploy track only — UI work is a follow-on)

---

## Authority

| Layer | Role |
|-------|------|
| **Product PRD** | Product intent, DoD, wallets, no-Balancer, pons, Universal Router, UI scope |
| **This plan** | Stages, file map, fixture numbers, package paths, bootstrap sequence, agent checklist |
| **Family PRDs** | `UniswapV4SingleStandardExchangeDETF_PRD.md` (constantProduct/single) · Buffer CP Hook PRD · Uni V3 SE PRD |
| **Gold code** | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` · `TestBase_UniswapV3StandardExchange.sol` · Buffer CP Hook TestBase |
| **Patterns** | `scripts/foundry/anvil_robinhood_main/**` (lab only — **copy patterns, do not merge**) |
| **Skills** | `crane-deployment`, `crane-architecture`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages`, `pons-integration` |

### Process rules

1. If this plan and product PRD disagree on **product**, PRD wins — patch this plan.  
2. If this plan and **family PRD/code** disagree on **package mechanics**, **code + family PRD win** — patch product PRD.  
3. **Never** `new` facets/DFPkgs; **never** `via_ir`.  
4. Facets: CREATE3 + FactoryService. Vaults / DETFs / hooks: **IndexedEx manager registry** / `deployHookVault` / package `deployVault`.  
5. **No Balancer** deploys or imports on this path.  
6. **Do not modify** `scripts/foundry/anvil_robinhood_main/` (lab).  
7. Fork RH at chain id **4663**; use `ROBINHOOD_MAIN` pins only for Uni / WETH / Permit2 / Universal Router / PoolManager.  
8. Scripts **do** first-bond (this family); product PRD’s older “never bond” lab rule does **not** apply here.

---

## 0. Package correction (normative for this plan)

Product PRD §0.1.1 gate is **resolved**:

| Role | Package path |
|------|----------------|
| **Fee-DETF** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/` |
| **Reserve host** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` (Single SE Buffer CP Hook) |
| **Backing SE** | `contracts/protocols/dexes/uniswap/v3/` (Uni V3 Standard Exchange) |
| **Out of scope** | `…/uniswap/v4/standardExchange/single/` (listing DETF) · Balancer Single SE DETF |

### Economic topology (implementor mental model)

```text
pons v1 → RICH + Uni V3 pool (RICH ↔ WETH)
              │
              ▼
     Uni V3 SE  (vaultTokens = {RICH, WETH})
              │ vaultShare
              ▼
     Buffer CP Hook reserve
       raw leg  = CHIR (detfToken free balance on hook)
       pair leg = SE vaultShare (virtual WETH claim)
       V4 pool currencies = CHIR ↔ WETH  (users swap here)
       fungible hook LP = pro-rata both legs
              │
              ▼
     CHIR DETF diamond
       bond principal = hook LP
       creationPairPerDetfWad ≈ 10e18  (10 WETH per 1 CHIR)
```

**Roles (locked):**

| Role | Asset |
|------|--------|
| `detfToken` | **CHIR** |
| `pairToken` / rateAsset | **WETH** |
| Other SE pool token | **RICH** (not DETF pairToken) |
| Backing SE | Uni V3 SE on pons RICH/WETH pool |

**First bond capital:** **WETH** (`pairToken` path per family law). Scripted RICH market buy is for **pons/SE market depth** (and residual RICH on deployer); it is **not** DETF listing pairToken.

---

## 1. Goal for the executing agent

Deliver a green local path:

```bash
# Repo root = lib/indexedex
export ALCHEMY_KEY=...   # or ANVIL_FORK_URL=https://rpc.mainnet.chain.robinhood.com
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil
# wait for: [SUCCESS] Command 'all' completed
```

**Result:**

1. Anvil forking Robinhood mainnet at **chain id 4663**.  
2. pons **RICH** launched; Uni V3 SE on that pool; Buffer CP hook + **CHIR** fee-DETF **live** after scripted first bond.  
3. Stage JSON under `deployments/anvil_robinhood_fee_detf/`.  
4. UI artifacts under `frontend/packages/protocol/src/addresses/chain/4663/` (fee-DETF / RICH keys; do not break unrelated lab keys if present — prefer overwrite of known launch keys + tokenlist tags).  
5. Anvil left running on `http://127.0.0.1:8545` for Indexedex UI work.  
6. Anvil **#1** has ETH for gas so a public user can buy RICH (UR) and bond on `/staking` without scripted funding of RICH.

---

## 2. Accounts & defaults

| Role | Address | Key |
|------|---------|-----|
| Deployer / SENDER / OWNER / bootstrap actor | Anvil **#0** `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | Default Anvil mnemonic #0 |
| UI wallet | Anvil **#1** `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | Import in MetaMask |

| Env | Default |
|-----|---------|
| `RPC_URL` | `http://127.0.0.1:8545` (broadcast **localhost only**) |
| `ANVIL_CHAIN_ID` | `4663` |
| `FOUNDRY_FORK_RPC_ALIAS` | `robinhood_mainnet_alchemy` → fallback `robinhood_mainnet` |
| `ANVIL_FORK_BLOCK_NUMBER` | `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK` (same as lab: `20714383` unless pin changes) |
| `OUT_DIR_OVERRIDE` | `deployments/anvil_robinhood_fee_detf` |
| `NETWORK_PROFILE` | `anvil_robinhood_fee_detf` |
| `UI_WALLET` | Anvil #1 |
| Anvil flags | `--chain-id 4663` · `--disable-code-size-limit` · fork URL + block |

---

## 3. Directory / file map (create)

```text
scripts/foundry/anvil_robinhood_fee_detf/
  README.md
  deploy_all.sh
  DeploymentBase.sol                 # resume JSON, broadcast guards, logging (pattern-copy lab base)
  RobinhoodCanonicalLib.sol          # ROBINHOOD_MAIN accessors + pin bytecode checks
  PonsV1Lib.sol                      # factory address, launch ABI helpers, event decode
  FixtureEconomics.sol               # creation rate, buy size, first-bond size constants
  Script_00_Preflight.s.sol
  Script_01_DeployCraneFoundation.s.sol
  Script_02_DeployIndexedexCore.s.sol
  Script_03_DeployHookDiamondFactory.s.sol   # required for Buffer CP hook deploy path
  Script_04_PonsLaunchRich.s.sol
  Script_05_DeployUniV3SeOnRichPool.s.sol
  Script_06_DeployRateProvider.s.sol         # SE share → WETH if fee-DETF / oracle paths need it
  Script_07_DeployFeeDetfChildren.s.sol      # bond NFT vault pkg + rebasing claim pkg
  Script_08_DeployFeeDetfPackage.s.sol       # Buffer CP hook pkg + CP DETF pkg via registry
  Script_09_DeployChirInstance.s.sol         # inert CHIR instance (PkgArgs launch-rich)
  Script_10_BootstrapMarketBuyRich.s.sol     # large RICH buy (Universal Router or V3 router)
  Script_11_BootstrapFirstBond.s.sol         # minimal WETH bond → live @ ~10 WETH/CHIR
  Script_12_FundUiWalletEth.s.sol            # ensure #1 has ETH for UI (optional if Anvil default ok)
  Script_13_ExportFrontendArtifacts.s.sol

scripts/shell/anvil_robinhood_fee_detf.sh    # thin wrapper → deploy_all.sh

deployments/anvil_robinhood_fee_detf/
  .gitkeep
  README.md                                  # operator commands, accounts, UI pointer

# Export targets (stage 13):
frontend/packages/protocol/src/addresses/chain/4663/
  platform.json                              # merge/overwrite launch keys
  base-tokens.tokenlist.json                 # include RICH
  strategy-vaults.tokenlist.json             # Uni V3 SE
  protocol-detfs.tokenlist.json              # CHIR fee-DETF
  featured-fee-detfs.tokenlist.json          # CHIR for /staking IA (create if missing)

# Protocol registry (minimal if not already wired for 4663):
frontend/packages/protocol/src/addresses/index.ts
frontend/packages/protocol/src/addressArtifacts.ts
frontend/packages/protocol/src/chainPlatformOverrides.generated.ts  # regenerate if pipeline requires
```

**Copy patterns from (do not rewrite inventively):**

| Need | Source |
|------|--------|
| Anvil lifecycle + RPC alias | `scripts/foundry/anvil_robinhood_main/deploy_all.sh` |
| Crane / manager stages | lab `Script_01` / `Script_02` / `Script_03` |
| Uni V3 SE deploy | lab `Script_07` + `TestBase_UniswapV3StandardExchange` |
| Hook + DETF package deploy | `TestBase_UniswapV4SingleStandardExchangeDETF` + hook TestBase |
| Artifact export | lab `Script_14_ExportFrontendArtifacts` |

---

## 4. Fixture economics (implementation defaults)

Tune via env overrides if needed; commit sensible defaults.

| Constant | Default | Notes |
|----------|---------|--------|
| `CREATION_PAIR_PER_DETF_WAD` | **`10e18`** | **10 WETH per 1 CHIR** at empty-book join |
| `THRESHOLD_MODE` | `Policy` | Price-gated mint/burn |
| `MINT_THRESHOLD` / `BURN_THRESHOLD` | Family resolve defaults (`0` → policy defaults) unless TestBase launch-rich row sets explicit | Copy from `_launchRichArgs()` + family PRD |
| `EXPANSION_EPOCH_LENGTH` | `0` → 8h resolve | Launch-rich row |
| `EXPANSION_CLOSURE_RATE_PER_YEAR_WAD` | **`4.4e18`** | Launch-rich ~1y walk narrative (family PRD §10) |
| `EXPANSION_MAX_CATCH_UP_EPOCHS` | `0` | Unlimited whole-epoch catch-up |
| `CHIR_NAME` / `CHIR_SYMBOL` | `"IndexedEx Fee DETF"` / **`CHIR`** | Product symbol locked |
| `RICH_NAME` / `RICH_SYMBOL` | `"RICH"` / **`RICH`** | pons metadata |
| `LARGE_RICH_BUY_WETH` | **`50 ether`** (WETH in) | “A lot” — deepen pons pool; override with `LARGE_RICH_BUY_WETH` |
| `FIRST_BOND_WETH` | **`0.1 ether`** starting guess | Minimal join; **measure** post-bond mid vs 10 WETH/CHIR; adjust if needed (see §6.3) |
| `BOND_LOCK_DURATION` | `max(minLock, 30 days)` | From fee oracle bond terms after core deploy |
| `UNI_V3_SE_WIDTH_MULTIPLIER` | Same as lab / TestBase default | Document actual value in stage JSON |
| `PONS_FACTORY` | `0xA5aAb3F0c6EeadF30Ef1D3Eb997108E976351feB` | Active v1 (verify still correct at fork block) |
| `WETH` | `ROBINHOOD_MAIN` WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |
| `UNIVERSAL_ROUTER` | `ROBINHOOD_MAIN.UNISWAP_UNIVERSAL_ROUTER` | `0x8876789976dEcBfCbBbe364623C63652db8C0904` |
| `POOL_MANAGER` | `ROBINHOOD_MAIN` Uni V4 PM | Never redeploy |

**Bond terms:** before CHIR instance deploy, set global/vault bond terms on fee oracle (min/max lock) exactly as TestBase does so postDeploy fee-recipient NFT path succeeds.

---

## 5. Stage map

| Stage | Script | Writes | Depends on |
|-------|--------|--------|------------|
| **00** | Preflight | `00_preflight.json` | Anvil 4663, RH pin bytecode (PM, V3 factory, WETH, Permit2, UR) |
| **01** | Crane foundation | `01_crane_foundation.json` | 00 |
| **02** | IndexedEx core | `02_indexedex_core.json` | 01 — manager, registry, fee collector, fee oracle |
| **03** | Hook diamond factory | `03_hook_factory.json` | 02 — required for Buffer CP hook packages |
| **04** | pons launch RICH | `04_pons_rich.json` | 00 — factory create; parse `TokenLaunched` → `rich`, `pool`, `isToken0`, etc. |
| **05** | Uni V3 SE on RICH pool | `05_univ3_se_rich.json` | 01–04 — DFPkg + `deployVault(pool, width)` |
| **06** | Rate provider | `06_rate_provider.json` | 05 — SE shares → WETH if needed |
| **07** | DETF children pkgs | `07_detf_children.json` | 02 — bond NFT vault pkg + rebasing claim pkg |
| **08** | Hook pkg + DETF pkg | `08_fee_detf_packages.json` | 03, 05, 07 — Buffer CP hook DFPkg + CP DETF DFPkg via **registry** |
| **09** | CHIR instance (inert) | `09_chir_instance.json` | 08 — `deployVault` / registry path with launch-rich `PkgArgs` |
| **10** | Market buy RICH | `10_market_buy_rich.json` | 04 — large WETH→RICH via UR (preferred) or V3 SwapRouter |
| **11** | First bond | `11_first_bond.json` | 09, WETH on #0 — `bond(pairAmount, lock, …)` → assert `isReserveLive` |
| **12** | UI wallet ETH check | `12_ui_wallet.json` | optional deal/transfer ETH to #1 if balance low |
| **13** | Export frontend | `13_frontend_export.json` + `chain/4663/*` | all prior |

### Command groups (`deploy_all.sh`)

| Command | Stages |
|---------|--------|
| `all` | 00–13 |
| `foundation` | 00–03 |
| `pons` | 04 |
| `se` | 05–06 |
| `packages` | 07–08 |
| `instance` | 09 |
| `bootstrap` | 10–12 |
| `export` | 13 |
| `stageNN` | single stage |

Resume: skip stage if artifact JSON exists and `FORCE` unset (lab pattern). `--restart-anvil` purges stage JSON.

---

## 6. Stage specifications

### 6.1 Stage 00 — Preflight

- `require(block.chainid == 4663)`.  
- `ROBINHOOD_MAIN` pins have code: PoolManager, V3 factory, V3 NPM (if used for SE), WETH, Permit2, Universal Router.  
- Log fork block, deployer, uiWallet.

### 6.2 Stages 01–03 — Crane + IndexedEx + hook factory

Pattern-copy lab stages 01–03 with:

- `OUT_DIR` / profile names for **fee_detf** family.  
- **No Balancer** package deploys.  
- Ensure fee oracle bond terms can be set (stage 02 or 07).

### 6.3 Stage 04 — pons launch RICH

1. Interface active factory (from `pons-integration` references; verify ABI against live bytecode at fork).  
2. As **#0**, pay launch fee, call create/launch with metadata name/symbol **RICH**.  
3. Respect launch protection: if creator-only first block, either creator initial buy in same stage or wait until `restrictionsEndBlock` before stage 10.  
4. Persist: `rich`, `pool`, `factory`, `restrictionsEndBlock`, `positionId` (if any), `launchTx`.

**Failure modes:** wrong factory address at fork block; insufficient ETH for fee; launch reverted — fix ABI/params, do not invent a mock token.

### 6.4 Stage 05 — Uni V3 SE

1. Deploy Uni V3 SE **components + DFPkg** via CREATE3 / manager registry (TestBase / lab Script_07).  
2. `deployVault(IUniswapV3Pool(ponsPool), widthMultiplier)`.  
3. Assert `vaultTokens()` contains **WETH** and **RICH**.  
4. Persist `uniV3SePkg`, `uniV3Se_rich`, `widthMultiplier`.

### 6.5 Stage 06 — Rate provider (if required)

- Deploy StandardExchange rate provider package if CHIR / fee paths require share→WETH rate.  
- `getRate() > 0` after SE has inventory (may need a dust seed via SE deposit of WETH in this stage or after first bond — prefer seed **WETH** into SE from #0 if RP must be non-zero before bond; document choice).

### 6.6 Stages 07–08 — Children + packages

Follow `TestBase_UniswapV4SingleStandardExchangeDETF` order:

1. Bond NFT vault DFPkg + rebasing claim DFPkg (owner wiring ready for DETF).  
2. Buffer CP **hook package** (hook factory path).  
3. CP DETF **DFPkg** via `indexedexManager` / registry — `PkgInit` on **interface**, not contract.  
4. **Never** `diamondPackageFactory.deploy` for registered vault packages outside registry path.

### 6.7 Stage 09 — CHIR instance (inert)

```text
PkgArgs (intent):
  name / symbol: ... / CHIR
  standardExchangeVault: uniV3Se_rich
  standardExchangeVaultShare: address(0) if share == vault (TestBase pattern)
  pairToken: WETH
  creationPairPerDetfWad: 10e18
  thresholdMode: Policy
  mint/burn thresholds: 0 → resolve defaults (or explicit launch-rich Policy bands if TestBase has them)
  expansionEpochLength: 0 → 8h
  expansionClosureRatePerYearWad: 4.4e18
  expansionMaxCatchUpEpochs: 0
  hookMineNonce: 0 → auto-mine
```

- Deploy via registry / package `deployVault` as TestBase.  
- Assert `isReserveLive() == false` before stage 11.  
- Persist `chir`, `reserveHook`, `bondNftVault`, `rebasingClaim`, `creationPairPerDetfWad`.

### 6.8 Stage 10 — Large RICH market buy (#0)

1. Wrap enough ETH → WETH on #0.  
2. Swap **`LARGE_RICH_BUY_WETH`** of WETH → RICH on pons V3 pool via **Universal Router** (preferred; matches UI) or RH V3 router pin.  
3. Slippage: wide for local (e.g. minOut = 0 or high tolerance) — document.  
4. Wait past pons buy restrictions if needed.  
5. Persist balances: `richBought`, `wethSpent`, `router`.

### 6.9 Stage 11 — First bond (#0) → live

1. Ensure #0 has **`FIRST_BOND_WETH`** WETH (wrap if needed).  
2. Approve CHIR DETF (and Permit2 if path requires) for WETH.  
3. Call family **`bond(pairAmount, lockDuration, recipient, …)`** with `pairAmount = FIRST_BOND_WETH`, recipient = #0.  
4. Assert `isReserveLive() == true`.  
5. Record measured economics:  
   - free DETF received / pair in  
   - optional `creationPairPerDetfWad` vs observed mid  
6. If first bond reverts on `MINIMUM_LIQUIDITY` / dust, **increase** `FIRST_BOND_WETH` (keep “minimal but viable”); re-run stage with `FORCE=1`.  
7. Persist `bondTokenId` (if any), `pairIn`, `detfOut`, `isReserveLive`.

**Do not** script second bond, sell→rebasing, or fee deposits.

### 6.10 Stage 12 — UI wallet

- If #1 ETH balance &lt; e.g. `100 ether`, transfer from #0 (Anvil #0 is rich by default — usually no-op).  
- **Do not** `deal` RICH to #1 (product: buy on pool in UI).  
- Optionally log suggested UI checklist.

### 6.11 Stage 13 — Frontend export

Write/update `chain/4663/`:

**platform.json** (minimum keys):

```text
chainId, networkProfile, rpcUrl
create3Factory, diamondPackageFactory / crane*
indexedexManager, vaultRegistry, vaultFeeOracle, feeCollector
hookFactory
weth, weth9, permit2, poolManager, universalRouter
v3Factory, v3Npm (if used)
ponsFactory, rich, richWethPool
uniV3Se_rich, uniV3SePkg
rp_se_rich_weth (if any)
bufferCpHookPkg, chirDetfPkg, bondNftVaultPkg, rebasingClaimTokenPkg
chir / feeDetf, reserveHook, creationPairPerDetfWad, feeDetfTemplate=launch-rich
deployer, owner, uiWallet
```

**Tokenlists:**

| File | Entries |
|------|---------|
| `base-tokens.tokenlist.json` | WETH (if listed), **RICH** tags: `token`, `pons-launch`, `rich` |
| `strategy-vaults.tokenlist.json` | `uniV3Se_rich` tags: `vault`, `se` |
| `protocol-detfs.tokenlist.json` | **CHIR** tags: `vault`, `detf`, `fee-detf` |
| `featured-fee-detfs.tokenlist.json` | **CHIR** only (drives `/staking` fee-DETF IA) |

Regenerate protocol overrides if the monorepo requires `build-tokenlists` / generated map for `platform.json`.

---

## 7. Shell orchestrator requirements

`scripts/shell/anvil_robinhood_fee_detf.sh` + `deploy_all.sh` must:

1. Resolve fork RPC via Foundry aliases (lab pattern).  
2. Start Anvil: host/port, **chain-id 4663**, fork URL/block, **`--disable-code-size-limit`**.  
3. Refuse broadcast if `RPC_URL` is not localhost.  
4. Support `--restart-anvil`, `--kill-anvil`, `FORCE=1`, `-vv`, dry-run if easy.  
5. Sequential stage run with resume.  
6. Print success banner + paths to artifacts + UI reminder (RPC 4663, import #1).

---

## 8. Explicit non-goals (this plan)

| Non-goal | Why |
|----------|-----|
| Merge into `anvil_robinhood_main` | Product D16 |
| Balancer anything | D29 |
| Listing DETF package | Wrong family |
| Scripted second bond / rebasing sell / fee Collector auto-deposit | UI / manual later |
| Full Uni V4 multi-family lab (Orbital/Weighted n=8) | Fee-DETF first pass only |
| dtf app / Indexedex UI implementation | Follow-on after green Anvil |
| Public RH mainnet production deploy | Local Anvil first |
| Happy-path `deal(RICH)` | Buy on pool only |

**In scope Uni V4:** RH PoolManager pin + Buffer CP hook + CHIR DETF (that is the Uni V4 architecture needed for this fee-DETF). Extra Uni V4 SE lab vaults are **optional later**, not required for DoD of this plan.

---

## 9. Success criteria (DoD)

### 9.1 Automated / script

- [ ] `bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil` exits 0.  
- [ ] `cast chain-id --rpc-url http://127.0.0.1:8545` → `4663`.  
- [ ] Stage JSON 00–13 present under `deployments/anvil_robinhood_fee_detf/`.  
- [ ] `rich`, `uniV3Se_rich`, `chir`, `reserveHook` non-zero.  
- [ ] `cast call $chir 'isReserveLive()(bool)'` → `true` after stage 11.  
- [ ] `creationPairPerDetfWad` exported as `10e18` (or documented override).  
- [ ] No Balancer addresses required in platform.json.  
- [ ] `chain/4663/platform.json` + tokenlists include RICH + CHIR fee-DETF + featured list.  
- [ ] `#1` has ETH for UI gas.

### 9.2 Manual smoke (operator, before UI coding)

- [ ] Import #1 into wallet; network 4663 → `http://127.0.0.1:8545`.  
- [ ] `#0` holds RICH (from market buy) and residual WETH; CHIR live.  
- [ ] (Optional) `cast` read CHIR `pairToken()`, SE address, hook address match export.

### 9.3 UI readiness handoff (not this plan’s code DoD)

Indexedex can point at:

- `getAddressArtifacts(4663)`  
- featured fee-DETF = CHIR  
- Universal Router + RICH pool for swaps  
- `/staking?detf=<chir>`  

UI plumbing is a **separate** implementation plan/PR.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| pons factory ABI drift | Pin ABI from pons-integration; verify against fork bytecode; stage 04 clear errors |
| Launch buy restrictions | Wait `restrictionsEndBlock` before stage 10; or creator buy rules documented |
| First bond too small | Bump `FIRST_BOND_WETH`; re-run 11 |
| Hook mine / flag failure | `hookMineNonce=0` auto-mine; ensure hook factory stage 03 |
| SE empty → RP = 0 | Optional WETH dust deposit into SE before RP assert |
| `chain/4663` collision with lab export | Launch keys overwrite known fields; tag fee-DETF; document “fee_detf profile owns CHIR/RICH keys” |
| Code-size facet deploy | Keep `--disable-code-size-limit` |
| Wrong DETF package used | Code review gate: path must contain `constantProduct/single` |

---

## 11. Implementation phases (agent work order)

### Phase A — Scaffold (½–1 day)

1. Create `scripts/foundry/anvil_robinhood_fee_detf/` skeleton + shell wrapper.  
2. Port `DeploymentBase` / Anvil lifecycle from lab with new OUT_DIR.  
3. README operator commands.

### Phase B — Foundation (1 day)

1. Stages 00–03 green on RH fork.  
2. Bond terms set on fee oracle.

### Phase C — Pons + SE (1–2 days)

1. Stage 04 pons RICH create.  
2. Stage 05 Uni V3 SE on pool.  
3. Stage 06 RP as needed.

### Phase D — Fee-DETF packages + instance (1–2 days)

1. Stages 07–09 mirroring TestBase deploy path.  
2. Assert inert CHIR before bond.

### Phase E — Bootstrap (1 day)

1. Stages 10–11 market buy + first bond.  
2. Calibrate `FIRST_BOND_WETH` until live + sane mid.  
3. Stage 12 UI ETH.

### Phase F — Export + verify (½ day)

1. Stage 13 artifacts + tokenlists + featured-fee list.  
2. Protocol package registry check for 4663.  
3. Run full `all --restart-anvil` cold path once green.  
4. Fill DoD checklist §9.

### Phase G — Handoff note

Write short `deployments/anvil_robinhood_fee_detf/README.md` section **“UI next steps”**:

- Anvil still running  
- wallet #1 + chain 4663  
- artifact paths  
- journeys: buy RICH (UR) · `/staking` CHIR · second bond · sell rebasing  

---

## 12. Agent checklist (execution)

```text
[ ] Read product PRD + this plan + TestBase_UniswapV4SingleStandardExchangeDETF
[ ] Confirm package paths: constantProduct/single + Buffer CP hook + Uni V3 SE
[ ] Scaffold shell family (do not touch anvil_robinhood_main)
[ ] 00–03 foundation green
[ ] 04 pons RICH
[ ] 05 Uni V3 SE
[ ] 07–09 CHIR inert launch-rich @ 10e18 creation rate
[ ] 10 large RICH buy via UR
[ ] 11 first bond WETH → isReserveLive
[ ] 13 export chain/4663 + featured-fee-detfs
[ ] Full all --restart-anvil once
[ ] README + DoD checked
```

---

## 13. Related docs to patch after execute (optional follow-ups)

1. Product PRD → **v0.4**: lock constantProduct package, reserve-hook topology, first-bond **WETH-only**, point to this plan.  
2. `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` — add `anvil_robinhood_fee_detf` family.  
3. `docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md` — add fee-DETF scenario section (or separate short runbook).  
4. Frontend implementation plan (4663 wagmi + UR + `/staking`) — **after** scripts green.

---

## 14. Revision history

| Version | Date | Notes |
|---------|------|--------|
| **v1.0** | 2026-08-09 | Initial implementor plan: separate Anvil family; pons RICH → Uni V3 SE → Buffer CP hook + CHIR CP DETF; scripted large RICH buy + WETH first bond @ 10e18 creation; export for UI |

---

## 15. One-line success

> One command stands up Anvil **4663** with **live CHIR fee-DETF** backed by Uni V3 SE on **pons RICH/WETH**, artifacts in **`chain/4663/`**, ready for Indexedex UI against wallet **#1**.

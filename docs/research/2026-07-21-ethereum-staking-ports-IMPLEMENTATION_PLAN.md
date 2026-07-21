# Implementation Plan: Ethereum Staking Protocol Ports (Crane)

**Date:** 2026-07-21  
**Status:** **Rewritten** — full project + transitive dependency vendoring (D2-FULL); prior mint/wrap-slice work is **superseded, not done**  
**PRD:** [`2026-07-21-ethereum-staking-protocol-ports-PRD.md`](./2026-07-21-ethereum-staking-protocol-ports-PRD.md)  
**Research:** [`2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`](./2026-07-21-ethereum-staking-protocols-se-vault-assessment.md)  
**Methodology:** [`lib/crane/DEFI_PORTING_PRD.md`](../../lib/crane/DEFI_PORTING_PRD.md) §A.1, **§A.4–A.5**, Part B  
**Target tree (Crane surface):** `lib/crane/contracts/protocols/staking/ethereum/{lido,rocket-pool,etherfi,stakewise,frax}/`  
**Target tree (vendored domain):** `lib/crane/contracts/external/{stakewise,etherfi,lido,rocketpool,<transitive>}/`

---

## Normative summary (read first — no wiggle room)

| Rule | Meaning |
|------|---------|
| **D2-FULL** | **Full vendoring** of each protocol’s **on-chain Solidity project** (user + protocol domain contracts required to build and exercise that project’s staking product), **plus all transitive Solidity dependencies** not already present in Crane. |
| **Not done** | Interfaces-only, Service-only, mint/wrap subgraph “slice,” soft-pass forks, or “document skip” of compile-required trees. Prior work under that bar is **incomplete**. |
| **A.4 remap** | Shared infra **already in Crane** (OZ, Solady, forge-std, WETH9, Uni V3, etc.) is **not** re-copied under the protocol tree; imports are **rewritten** to existing `@crane/...` paths. |
| **Transitive unique deps** | Protocol-only stacks (e.g. Aragon for Lido, EigenLayer for ether.fi, full RP contract graph) **are** vendored into `contracts/external/<name>/` so the protocol **compiles as a unit**. |
| **Tests** | (1) Vendored code **builds**; (2) **adapted upstream tests** where the project has Foundry/Hardhat suites that map to Solidity; (3) **mainnet fork** gates for live addresses. Service tests alone do **not** satisfy. |
| **Frax (D3)** | Exception: thin `staking/ethereum/frax/` only; bulk already under `tokens/stable/frax`. Do **not** re-vendor Frax monorepo. |
| **No new remappings** | Do not invent alias paths; use existing `@crane/...` (and already-configured paths). |

**Agent failure modes that invalidate “done” (explicit):**

1. Claiming done with only `*Service` + fork against mainnet and a handful of domain files.  
2. Leaving compile-required transitive deps as “deferred” without vendoring them.  
3. Nesting OpenZeppelin under `staking/ethereum/**`.  
4. Marking progress complete while `external/<protocol>/` is a thin mint/wrap cut vs full upstream `contracts/` (or equivalent) tree at the pinned commit.  
5. Soft-passing capacity/eligibility (e.g. empty deposit pool) without a hard domain-path test elsewhere.

---

### Hard constraints (agent)

| Rule | Detail |
|------|--------|
| **No new remappings** | Do **not** add new alias paths in `remappings.txt` / Foundry remapping lists. All imports use **existing** `@crane/...` (and already-configured paths only). Narrow Foundry **profiles** that only reuse existing aliases are OK. |
| **Common deps first** | Phase A (inventory + Crane-shared gap-fill) before enlarging protocol full vendors. |
| **Protocol order** | §5.0 — Frax (thin) → StakeWise → ether.fi → Lido → Rocket Pool. |
| **No new git submodules** | Copy sources into the tree (project rule). |
| **No protocol-local OZ** | Never `staking/ethereum/**/openzeppelin/**`. |

### Locked product decisions (2026-07-21; D2 updated 2026-07-21 rewrite)

| # | Decision | Choice |
|---|----------|--------|
| D1 | **Epic scope** | **Crane full ports + IndexedEx generic ERC-4626 SE** in the same worktree epic. SE may land after Frax thin Service green (sfrxETH). |
| **D2-FULL** | **Port depth** | **Full project vendoring + transitive Solidity deps.** Pin each upstream at a commit/tag. Copy the protocol’s Solidity package(s) into `contracts/external/<lib>/`. Vendor **every compile-time dependency** that is not already satisfied by Crane via remap. Crane wrapper surface (interfaces, Service, rate) sits on top — it does **not** replace domain. |
| D3 | **FraxETH layout** | **Thin wrappers only** under `staking/ethereum/frax/`. Bulk remains under `tokens/stable/frax`. |
| D4 | **Verification** | **Build of full vendor graph** + **upstream-adapted tests** + **Ethereum mainnet fork** gates. Hermetic-only or fork-only without full vendor = **not done**. |

---

## 0. How to use this document

| Section | Purpose |
|---------|---------|
| **§1 Scope & port mode (D2-FULL)** | Unambiguous definition of “full vendor” |
| **§2 Shared / transitive dependency research** | What must be remapped vs newly vendored |
| **§3 Crane gap analysis** | What exists vs must be filled |
| **§4 Common-dep work (Phase A)** | Shared remap + gap-fill before protocol full trees |
| **§5 Protocol order & per-protocol full-vendor checklists** | Ordered work + must-have trees |
| **§6 Single agent worktree task** | Executable blocks |
| **§7 Verification gates** | Commands + inventory proofs that cannot be faked |
| **§8 Progress log** | Prior slice work superseded; re-execute under D2-FULL |
| **§9–10** | Follow-on / changelog |

**Execution order (hard rule):**

```text
1) Phase A: DEPENDENCY_MAP + Crane-shared gap-fill (no new remaps)
2) Scaffold staking/ethereum/* Service surface (may exist; keep)
3) Full vendor each protocol in §5.0 order (entire project + transitive unique deps)
4) Port/adapt upstream tests + mainnet fork gates
5) IndexedEx ERC-4626 SE (D1) — may start after Frax thin green
```

---

## 1. Scope & port mode (D2-FULL)

### 1.1 Protocols in this plan

| ID | Protocol | Upstream (pin at execute) | Vendor root in Crane |
|----|----------|---------------------------|----------------------|
| S | StakeWise V3 | `stakewise/v3-core` | `contracts/external/stakewise/` |
| E | ether.fi | `etherfi-protocol/smart-contracts` (+ submodules required to compile) | `contracts/external/etherfi/` + transitive dirs |
| L | Lido | `lidofinance/core` (+ Aragon / apps **if required to compile core staking surface**) | `contracts/external/lido/` + transitive dirs |
| R | Rocket Pool | `rocket-pool/rocketpool` | `contracts/external/rocketpool/` |
| F | FraxETH | already in Crane | **D3 thin only** — `staking/ethereum/frax/` |

### 1.2 What “full vendoring” means (normative)

For **S, E, L, R**:

1. **Pin** upstream `repo@commit` (or release tag resolved to commit) in `staking/ethereum/<p>/README.md` and `external/<lib>/VENDOR.md`.  
2. **Copy** the upstream **Solidity source tree** that constitutes the protocol project (typically `contracts/`, `src/`, or monorepo package equivalent — **not** a hand-picked mint/wrap subset).  
3. **Transitive dependencies:**  
   - If already in Crane (`openzeppelin-contracts`, `openzeppelin-upgradeable`, `solady`, `solmate`, Uni V3, LayerZero, forge-std, …): **rewrite imports** to existing `@crane/contracts/external/...` or protocol paths. **Do not** nest a second OZ under the protocol vendor.  
   - If **not** in Crane (EigenLayer for ether.fi, Aragon for Lido, any other Solidity lib the pin imports): **copy that dependency’s Solidity** into `contracts/external/<dep-name>/` (pinned), then remap protocol imports to `@crane/contracts/external/<dep-name>/...`.  
4. **Pragma / OZ version friction:** Prefer remap to Crane OZ 4.9.6 / upgradeable already present. If a file **cannot** compile without OZ 5.x / 3.x APIs, **gap-fill** missing files into the existing Crane external trees (or document a minimal dual-pin under `external/openzeppelin-contracts-v5/` **only if** existing remaps cannot express it **without** new alias paths — prefer expanding existing trees). Document every adaptation in `VENDOR.md` (pragma bump, SafeMath→native, OZ hook renames).  
5. **Off-chain / non-Solidity:** SSZ/BLS toolchains, frontends, deploy scripts, Hardhat config — **not** required as runtime Solidity; keep only if tests need fixtures.  
6. **Crane surface (always, in addition to full vendor):**  
   - Canonical interfaces under `staking/ethereum/<p>/interfaces/`  
   - `*Service` library (ops over vendored + mainnet ABIs)  
   - Rate helper (`getRate()` / Balancer `IRateProvider` shape)  
   - README with pin, tree map, adaptations  

**Service is a thin façade over the vendored project — never a substitute for missing domain code.**

### 1.3 Explicitly rejected “port modes” (fail acceptance)

| Mode | Status |
|------|--------|
| Interface-only + Service + fork | **FAIL** |
| Mint/wrap subgraph only (prior D2 slice) | **FAIL** under D2-FULL |
| Fork-only verification without full `external/<lib>/` tree | **FAIL** |
| “Document skip” of EigenLayer/Aragon/minipools **when the pin’s contracts import them** | **FAIL** — vendor or prove zero import edges via inventory |
| Soft-pass tests (`if capacity == 0 pass`) without domain unit proof of the path | **FAIL** |

### 1.4 Definition of done (program)

- [ ] §4 Phase A closed with `DEPENDENCY_MAP.md` covering **all** transitive libs for S/E/L/R  
- [ ] **StakeWise, ether.fi, Lido, Rocket Pool** each have:  
  - [ ] Full vendored project under `contracts/external/<lib>/` at pinned commit  
  - [ ] All **unique** transitive Solidity deps vendored under `contracts/external/<dep>/`  
  - [ ] Shared deps remapped to Crane (no nested OZ under protocol trees)  
  - [ ] `VENDOR.md` + protocol README pins + adaptation log  
  - [ ] **Inventory gate** (§7.1): file count / tree map vs upstream pin (not a tiny slice)  
  - [ ] **Build gate:** vendored package compiles (profile or package scope OK)  
  - [ ] **Test gate:** upstream-adapted tests **and** mainnet fork Service gates (§7)  
  - [ ] Crane interfaces + Service + rate under `staking/ethereum/<p>/`  
- [ ] Frax: thin D3 + green fork  
- [ ] No new remapping aliases; all `@crane/` imports in new/edited code  
- [ ] IndexedEx generic ERC-4626 SE on **sfrxETH** (D1): registry deploy, `vaultTokens()` length 2, deposit/redeem  
- [ ] Progress log marks D2-FULL complete only after §7 inventory + build + tests  

### 1.5 Supersession notice

Work completed under the **old D2** (“faithful domain vendor where feasible / mint-wrap slice”) — including OsToken-only, WeETH-only, WstETH-only, narrow RP deposit pool, and 23 staking_eth smoke tests — is **partial scaffolding only**. It **does not** meet D2-FULL. Agents must **expand or replace** those trees to full upstream packages, not mark polish-complete.

---

## 2. Shared dependency research (remap vs vendor)

Sources: upstream `package.json`, `.gitmodules`, `remappings.txt`, `foundry.toml` (refresh at pin time).

### 2.1 Upstream declared dependencies (on-chain relevant)

| Dependency | Lido | Rocket Pool | ether.fi | StakeWise | FraxETH (in Crane) | **Action under D2-FULL** |
|------------|:----:|:-----------:|:--------:|:---------:|:------------------:|--------------------------|
| OpenZeppelin Contracts | ✅ | ✅ | ✅ | ✅ | ✅ → Crane | **Remap** to Crane OZ 4.9.6; gap-fill symbols only |
| OpenZeppelin Upgradeable | ➖ / via apps | ➖ | ✅ | ✅ | ➖ | **Remap** to Crane upgradeable; gap-fill |
| Solady | ➖ | ➖ | ✅ | ➖ | ➖ | **Remap** to Crane solady; gap-fill |
| forge-std | ✅ | ➖ (Hardhat) | ✅ | ✅ | ✅ | Tests only; use Crane/Foundry |
| WETH9 / IWETH | common | common | common | common | yes | **Remap** to Crane WETH9 |
| Ethereum Deposit Contract | ✅ | ✅ | ✅ | ✅ | ✅ | Interface in common + real mainnet in fork |
| **Aragon OS / apps / MiniMe** | ✅ | ➖ | ➖ | ➖ | ➖ | **Vendor** if Lido pin imports them for compile |
| **EigenLayer contracts** | ➖ | ➖ | ✅ submodule | ➖ | ➖ | **Vendor** under `external/eigenlayer/` (or pin path) if ether.fi imports them |
| Uniswap V3 | ➖ | ➖ | ✅ | ➖ | ➖ | **Remap** to Crane Uni V3 if imported; else vendor only missing pieces |
| LayerZero (weETH bridge) | ➖ | ➖ | ✅ | ➖ | ➖ | **Remap/gap-fill** Crane `external/layerzero` if bridge modules are in the vendored package; if package can exclude bridge packages cleanly, document **package boundary** (not “skip because hard”) |
| SSZ / BLS / lodestar | dev | dev | ➖ | ➖ | ➖ | Dev-only; skip unless Solidity verifier needed |

### 2.2 Remap-first policy (shared)

| Rank | Dependency | v1 necessity | Crane target |
|------|------------|--------------|--------------|
| 1 | OZ non-upgradeable | High | `@crane/contracts/external/openzeppelin-contracts/` |
| 2 | OZ upgradeable | High (S, E) | `@crane/contracts/external/openzeppelin-upgradeable/` |
| 3 | Solady | High if E imports | `@crane/contracts/external/solady/` |
| 4 | WETH9 | High | Crane WETH9 protocol path |
| 5 | Uni V3 | If E imports | Crane `protocols/dexes/uniswap/v3` |
| 6 | LayerZero | If E bridge package included | Crane `external/layerzero` + gap-fill |
| 7 | forge-std | Tests | Foundry / Crane |

### 2.3 Must-vendor-if-imported (unique / missing)

| Dependency | Protocols | Location when needed |
|------------|-----------|----------------------|
| EigenLayer | ether.fi | `contracts/external/eigenlayer/` (pinned submodule commit) |
| Aragon / related Lido apps | Lido | `contracts/external/aragon/` or upstream-layout under `external/lido/` as upstream organizes |
| Full protocol trees | S E L R | `contracts/external/{stakewise,etherfi,lido,rocketpool}/` |
| Any other Solidity import edge discovered at pin | any | `contracts/external/<name>/` + DEPENDENCY_MAP row |

### 2.4 Research method (mandatory at each pin)

```bash
# After shallow clone of pin:
# 1) List all Solidity files in upstream contracts/src
find contracts src -name '*.sol' 2>/dev/null | wc -l

# 2) Import graph of third-party roots
rg -oN --no-filename "from ['\"](@?[^'\"]+)['\"]" -g'*.sol' \
  | sed 's/.*from //' | sort -u

# 3) Classify each import: Crane-remap vs new-vendor
# Write results into DEPENDENCY_MAP.md and external/<lib>/VENDOR.md
```

**Inventory gate:** Crane `external/<lib>/` Solidity file count must be in the same order of magnitude as upstream pin’s contract tree (after excluding pure test/mocks only if upstream keeps them separate — prefer **including** protocol-owned test helpers if they are part of the package). A tree of “~5–15 hand-picked files” against an upstream of hundreds = **automatic fail**.

---

## 3. Crane gap analysis (as of rewrite)

| Dependency | Crane location | Status | Action under D2-FULL |
|------------|----------------|--------|----------------------|
| OZ 4.9.6 | `external/openzeppelin-contracts` | ✅ | Default remap |
| OZ upgradeable | `external/openzeppelin-upgradeable` | ✅ | Remap; gap-fill symbols for S/E |
| Solady | `external/solady` | ✅ | Gap-check for ether.fi |
| Uni V3 | `protocols/dexes/uniswap/v3` | ✅ Partial | Remap or gap-fill if E needs |
| LayerZero | `external/layerzero` | ⚠️ Partial | Gap-fill if E includes bridge packages |
| EigenLayer | — | ❌ | **Vendor** with ether.fi full port |
| Aragon | — | ❌ | **Vendor** with Lido if imported |
| stakewise / etherfi / lido / rocketpool | partial slice trees | ⚠️ **Incomplete** | **Replace with full pin trees** |
| FraxETH | `tokens/stable/frax` | ✅ | D3 thin staking wrappers only |
| Beacon DepositContract | common iface may exist | thin OK | Keep interface; fork uses mainnet |

---

## 4. Prioritized common dependency plan (Phase A)

### A0 — Policy & inventory

| Task | Output |
|------|--------|
| A0.1 | Confirm Crane OZ + upgradeable pins in DEPENDENCY_MAP |
| A0.2 | `staking/ethereum/DEPENDENCY_MAP.md`: upstream import → `@crane/...` **or** `external/<new>/` vendor target |
| A0.3 | Per-protocol expected unique transitive vendors (EigenLayer, Aragon, …) |
| A0.4 | DepositContract interface under common if missing |

### A1 — Shared already in Crane (verify import samples compile)

No re-port of OZ/Solady/WETH9. Prove sample imports build.

### A2 — Shared staking common

| Pri | Deliverable |
|----:|-------------|
| 1 | `IDepositContract.sol` |
| 2 | `EthereumStakingLib.sol` (ETH/WETH helpers) |
| 3 | `IStakingRateProvider.sol` |
| 4 | `staking/ethereum/README.md` (navigator + D2-FULL pointer) |

### A3 — Gap-fill shared trees when full vendor compile fails

| Trigger | Action |
|---------|--------|
| Missing OZ/Solady/LZ/Uni symbol | Add file into **existing** Crane external tree from a pinned release; **no** new remap alias |
| Missing EigenLayer / Aragon | **New** `external/<dep>/` full copy + DEPENDENCY_MAP |

### A4 — Phase A non-goals

- Do **not** treat EigenLayer/Aragon as “never port” — that was the old plan. They are **in scope when imported**.  
- Do **not** re-vendor Frax monorepo.  
- Do **not** edit remapping aliases.

---

## 5. Protocol prioritization & full-vendor plan

### 5.0 Order (unchanged)

```text
Phase A → FraxETH (thin D3) → StakeWise → ether.fi → Lido → Rocket Pool
```

Rationale: prove Service/fork + SE on Frax first; then full-vendor smallest-to-largest among score ties (StakeWise → ether.fi → Lido), then Rocket Pool.

### 5.1 Per-protocol full-vendor checklist (copy for each of S/E/L/R)

```text
[ ] Shallow clone upstream@pin; record commit in README + VENDOR.md
[ ] Copy full Solidity project tree → contracts/external/<lib>/
[ ] Run import classification (§2.4); vendor every non-Crane transitive dep
[ ] Rewrite all shared imports to @crane/...
[ ] forge build of vendor graph (document profile/command)
[ ] Inventory: file count + top-level map vs upstream (attach to VENDOR.md)
[ ] Port/adapt upstream tests into Crane test tree (Foundry); map Hardhat→Foundry as needed
[ ] Domain tests must `new` / deploy vendored contracts (not only mainnet)
[ ] interfaces + Service + rate under staking/ethereum/<p>/
[ ] Mainnet fork Service tests (§7.3) hard-fail on success path
[ ] No nested OZ under staking/ethereum
[ ] No new remapping aliases
```

### 5.2 StakeWise (priority 2) — full vendor

| Item | Requirement |
|------|-------------|
| Upstream | `stakewise/v3-core@<pin>` |
| Vendor | **Entire** protocol contracts package (vaults, osToken, controllers, factories, oracles used by contracts, libraries, interfaces) — not OsToken alone |
| Transitive | OZ upgradeable → Crane remap; any other Solidity dep → vendor or remap |
| Crane surface | `IEthVault`, `IOsETH`, controller ifaces, `StakeWiseService`, `OsETHRateProvider` |
| Tests | Upstream Foundry tests adapted under Crane path **or** equivalent coverage of vault deposit/redeem + osETH mint/burn; plus mainnet fork |
| Fail if | Only `OsToken.sol` + controller stub |

### 5.3 ether.fi (priority 3) — full vendor

| Item | Requirement |
|------|-------------|
| Upstream | `etherfi-protocol/smart-contracts@<pin>` |
| Vendor | Full contracts package for eETH / LiquidityPool / weETH / staking managers / governance utils **as present in pin** |
| Transitive | **EigenLayer** submodule/commit if imported → `external/eigenlayer/`; Uni V3 / LZ / Solady / OZ → remap or gap-fill Crane |
| Package boundary | If a **separate** package is only the LZ bridge and can be omitted without breaking core compile, document boundary in VENDOR.md with `forge build` proof of core package; do not silently omit core restaking modules |
| Crane surface | `IEETH`, `IWeETH`, `IEtherFiLiquidityPool`, `EtherFiService`, `WeETHRateProvider` |
| Tests | Upstream tests for deposit/wrap/unwrap adapted; domain deploy of WeETH+pool stack; mainnet fork deposit+wrap |
| Fail if | Only `WeETH.sol` + interfaces |

### 5.4 Lido (priority 4) — full vendor

| Item | Requirement |
|------|-------------|
| Upstream | `lidofinance/core@<pin>` |
| Vendor | Full **core** Solidity tree for stETH/wstETH staking product (oracle, withdrawal queue, staking router, etc. **as in pin**) |
| Transitive | **Aragon / apps** if required to compile → vendor under `external/aragon/` or upstream-relative layout; OZ multi-version → remap/adapt with VENDOR.md log |
| Crane surface | `IStETH`, `IWstETH`, `LidoService`, `WstETHRateProvider` |
| Tests | Upstream Foundry (or adapted) wrap/submit tests; domain WstETH (+ stETH as vendored); mainnet fork wrap/unwrap + rate |
| Fail if | Only `WstETH.sol` + `IStETH.sol` |

### 5.5 Rocket Pool (priority 5) — full vendor

| Item | Requirement |
|------|-------------|
| Upstream | `rocket-pool/rocketpool@<pin>` |
| Vendor | Full `contracts/` (or equivalent) tree: storage, deposit, token, network, minipool, DAO settings interfaces/impls as shipped — **not** only RETH+DepositPool slice |
| Transitive | OZ/SafeMath → remap/native 0.8 adaptations documented; any remaining libs vendor |
| Crane surface | `IRETH`, deposit pool, storage interfaces, `RocketPoolService`, `RETHRateProvider` |
| Tests | Upstream Hardhat tests adapted to Foundry where feasible; domain multi-contract deploy via RocketStorage address book; mainnet fork deposit when capacity |
| Fail if | Toy deposit/reth without full storage/network graph |

### 5.6 FraxETH (priority 1) — thin (D3 exception)

| Item | Requirement |
|------|-------------|
| Vendor | **No** full re-vendor; use `tokens/stable/frax/FraxETH` |
| Surface | `staking/ethereum/frax/` Service + rate + re-exports + README |
| Tests | Mainnet fork submit/deposit + rate |

### 5.7 Minimum Service APIs (still required)

| Protocol | Service ops |
|----------|-------------|
| Frax | `submit`, `submitAndDeposit`, sfrxETH deposit/redeem, previews |
| Lido | submit ETH→stETH, wrap/unwrap, submitAndWrap, rate views |
| Rocket Pool | deposit ETH→rETH, burn/redeem when liquid, exchange rate, capacity |
| ether.fi | deposit→eETH, wrap/unwrap weETH, depositAndWrap, share math |
| StakeWise | vault deposit/redeem, osETH mint/burn as allowed, rate views |

### 5.8 Mainnet addresses (verify at execute)

| Token / contract | Address (verify) |
|------------------|------------------|
| stETH | `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84` |
| wstETH | `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0` |
| rETH | `0xae78736Cd615f374D3085123A210448E74Fc6393` |
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| ether.fi LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` |
| frxETH | `0x5E8422345238F34275888049021821E8E08CAa1f` |
| frxETHMinter | `0xbAFA44EFE7901E04E39Dad13167D089C559c1138` |
| sfrxETH | `0xac3E018457B222d93114458476f3E3416Abbe38F` |
| Deposit contract | `0x00000000219ab540356cBB839Cbe05303d7705Fa` |
| osETH / StakeWise vaults | StakeWise deployments docs |

---

## 6. Single agent worktree task

**Goal:** Full D2-FULL vendors for S/E/L/R + thin Frax + SE + tests that prove domain + fork.

### 6.1 Preconditions

```bash
export ETH_RPC_URL=...   # required for D4
# Worktree: worktrees/indexedex preferred; branch feature/crane-ethereum-staking-ports
```

### 6.2 Agent checklist (ordered)

#### Block 0 — Bootstrap

- [ ] Worktree/branch ready; read **this** plan (D2-FULL), PRD, `DEFI_PORTING_PRD` A.4–A.5  
- [ ] Treat prior slice trees as **incomplete**  
- [ ] `cast block-number --rpc-url $ETH_RPC_URL`

#### Block 1 — Phase A

- [ ] Refresh `DEPENDENCY_MAP.md` for full-vendor transitive set  
- [ ] Common helpers if missing  
- [ ] Zero new remapping aliases  

#### Block 2 — Frax thin (D3)

- [ ] Service + rate + fork green (may already exist)

#### Block 3 — StakeWise **full** vendor

- [ ] Replace slice with full `v3-core` contracts tree at pin  
- [ ] Remap OZ/etc.; build; inventory gate  
- [ ] Upstream-adapted tests + Service + fork  

#### Block 4 — ether.fi **full** vendor

- [ ] Full smart-contracts tree + EigenLayer (if imported) + other missing transitives  
- [ ] Remap Solady/OZ/Uni/LZ as applicable  
- [ ] Build; inventory; tests; Service; fork  

#### Block 5 — Lido **full** vendor

- [ ] Full core tree + Aragon/transitives if imported  
- [ ] Build; inventory; tests; Service; fork  

#### Block 6 — Rocket Pool **full** vendor

- [ ] Full rocketpool contracts tree  
- [ ] Build; inventory; tests; Service; fork  

#### Block 7 — IndexedEx ERC-4626 SE (D1)

- [ ] Registry path; `vaultTokens` = `[protocolVault, asset()]`; sfrxETH fork deposit/redeem  

#### Block 8 — Polish

- [ ] §7 all gates green; progress log; dual-push crane + IndexedEx  

### 6.3 Agent constraints (non-negotiable)

1. **D2-FULL** — full project + transitive Solidity deps; no slice mode.  
2. **No new remapping aliases.**  
3. **No** nested OZ under `staking/ethereum/**`.  
4. **No** new git submodules — copy in.  
5. **Service ≠ domain.**  
6. **Mainnet fork required** in addition to domain/upstream tests.  
7. Pin every vendor in README + VENDOR.md.  
8. §5.0 protocol order.  
9. Frax remains thin (D3).  
10. Inventory gate must pass before claiming a protocol done.

### 6.4 Suggested commit cadence

| Commit | Content |
|--------|---------|
| 1 | Plan rewrite + DEPENDENCY_MAP refresh for D2-FULL |
| 2 | Frax thin (if needed) + SE |
| 3 | StakeWise full vendor + tests |
| 4 | ether.fi full vendor + EigenLayer transitive + tests |
| 5 | Lido full vendor + Aragon transitive + tests |
| 6 | Rocket Pool full vendor + tests |
| 7 | Final suite + docs |

---

## 7. Verification gates

### 7.1 Inventory (per protocol S/E/L/R) — **gating**

```bash
# Example for stakewise; repeat for etherfi, lido, rocketpool
PIN=...  # from VENDOR.md
# Upstream count (from clone at pin)
find /tmp/upstream-stakewise -name '*.sol' | wc -l
# Crane vendor count
find lib/crane/contracts/external/stakewise -name '*.sol' | wc -l
# Expect same order of magnitude; attach both numbers to VENDOR.md
# Fail if Crane tree is only mint/wrap hand-picks
```

Also require:

- [ ] `VENDOR.md` lists pin, copy date, adaptation log, transitive vendor roots  
- [ ] `rg` shows **no** `openzeppelin` nested under `staking/ethereum`  
- [ ] Import sample: protocol domain files use `@crane/contracts/external/...` for OZ  

### 7.2 Build — **gating**

```bash
cd lib/crane
# Full or profiled build that includes external/{stakewise,etherfi,lido,rocketpool}
forge build
# Optional: FOUNDRY_PROFILE that scopes to vendor graphs without new remap aliases
```

Capture log. **Fail** if only Services compile and large vendor trees are excluded from the build.

### 7.3 Tests — **gating**

**A. Upstream-adapted / domain tests**

```bash
forge test --match-path '**/external/stakewise/**' -vv   # or Crane test path for adapted upstream
forge test --match-path '**/staking/ethereum/**Domain**' -vv
# Similarly for etherfi, lido, rocketpool
```

**B. Mainnet fork Service gates (D4)**

```bash
export ETH_RPC_URL=...
forge test --fork-url $ETH_RPC_URL --match-path '**/staking/ethereum/**' -vv
```

| Protocol | Minimum fork asserts (hard) |
|----------|------------------------------|
| Frax | submit/deposit → sfrxETH; rate |
| Lido | wrap/unwrap inverse; rate matches `stEthPerToken` |
| Rocket Pool | deposit mints rETH when capacity; rate > 0; domain tests cover empty-capacity |
| ether.fi | deposit+wrap weETH; unwrap recovers eETH |
| StakeWise | vault deposit increases shares; osETH rate |

**C. SE**

```bash
forge test --fork-url $ETH_RPC_URL \
  --match-path '**/ERC4626StandardExchange_SfrxETH_Fork.t.sol' -vv
```

### 7.4 Remap hygiene — **gating**

```bash
git diff origin/main -- remappings.txt lib/crane/remappings.txt
# Expect: no new alias path additions
# foundry.toml profile remappings may only restate existing aliases
```

### 7.5 Definition of “protocol done” (one-liner)

> **Full upstream Solidity tree at pin + transitive unique deps vendored + shared deps remapped + builds + upstream-adapted tests + hard mainnet fork Service tests + Crane Service/rate surface.**

Anything less is **not done**.

---

## 8. Progress log (agent updates)

| Date | Block | Status | Notes |
|------|-------|--------|-------|
| 2026-07-21 | Research / priority | ✅ | Shared dep matrix; order Frax→SW→E→L→RP |
| 2026-07-21 | Phase A / thin slice ports | ⚠️ **Superseded** | Mint/wrap domain slice + 23 smoke tests; **fails D2-FULL** |
| 2026-07-21 | SE sfrxETH | ✅ / keep | Generic ERC-4626 SE fork green — retain |
| 2026-07-21 | **Plan rewrite D2-FULL** | ✅ | Full project + transitive vendor required; slice mode forbidden |
| — | StakeWise full vendor | ⬜ | Expand `external/stakewise` to full pin |
| — | ether.fi full + EigenLayer | ⬜ | Expand `external/etherfi` + transitive |
| — | Lido full + Aragon if needed | ⬜ | Expand `external/lido` + transitive |
| — | Rocket Pool full tree | ⬜ | Expand `external/rocketpool` |
| — | Upstream-adapted tests | ⬜ | Per protocol |
| — | D2-FULL final suite | ⬜ | §7 inventory + build + tests |

---

## 9. Follow-on (after D2-FULL epic)

1. Pendle/Liquity/Uni import cleanup → canonical Lido interfaces.  
2. LST strategy adapters / multi-vault DETF legs using SE + Services.  
3. Continuous pin bumps / audit tracking for vendored trees.  

*(Former “port Aragon/EigenLayer later” follow-ons are **in-scope for D2-FULL** when imported — not follow-on.)*

---

## 10. Changelog

| Date | Change |
|------|--------|
| 2026-07-21 | Initial plan: shared dep research, priority order, thin/mint-wrap-oriented D2 |
| 2026-07-21 | Locked D1–D4 (original): domain vendor “where feasible”; thin Frax; fork required |
| 2026-07-21 | **Rewrite: D2-FULL** — full project vendoring + transitive Solidity dependencies; inventory/build/upstream-test gates; prior slice work superseded; EigenLayer/Aragon in scope when imported; explicit fail modes |

---

*Start execution at Block 0. Do not mark any of S/E/L/R complete until §7.1 inventory, §7.2 build, and §7.3 A+B tests pass for that protocol. SE (Block 7) may start after Frax thin green.*

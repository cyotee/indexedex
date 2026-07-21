# Implementation Plan: Ethereum Staking Protocol Ports (Crane)

**Date:** 2026-07-21  
**Status:** Draft — dependency research + **protocol prioritization** locked; ready for agent execution  
**PRD:** [`2026-07-21-ethereum-staking-protocol-ports-PRD.md`](./2026-07-21-ethereum-staking-protocol-ports-PRD.md)  
**Research:** [`2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`](./2026-07-21-ethereum-staking-protocols-se-vault-assessment.md)  
**Methodology:** [`lib/crane/DEFI_PORTING_PRD.md`](../../lib/crane/DEFI_PORTING_PRD.md) §A.4–A.5, Part B  
**Target tree:** `lib/crane/contracts/protocols/staking/ethereum/{lido,rocket-pool,etherfi,stakewise,frax}/`  
**Shared deps target:** `lib/crane/contracts/external/` (expand first; never nest OZ under protocol trees)

### Hard constraints (agent)

| Rule | Detail |
|------|--------|
| **No new remappings** | Do **not** edit `remappings.txt`, `foundry.toml` `[profile.*.remappings]`, or add new alias paths. All imports use **existing** `@crane/...` (and already-configured paths only). |
| **Common deps first** | Phase A before any protocol domain port. |
| **Protocol order** | §5.0 — most **common** deps first; ties → **smallest** upstream first. |

### Locked product decisions (2026-07-21)

| # | Decision | Choice |
|---|----------|--------|
| D1 | **Epic scope** | **Crane ports + IndexedEx generic ERC-4626 SE** in the same long agent worktree task. SE follows Crane ports (or Frax Service green if SE can land mid-stream on sfrxETH). |
| D2 | **Port depth** | **Faithful domain vendor where feasible** — pin upstream domain contracts into Crane (`external/<lib>/` and/or `staking/ethereum/<p>/` as appropriate), remap shared deps to **existing** `@crane/contracts/external/...` paths; still **no new remappings**. Prefer full domain for mint/wrap/redeem surfaces; still skip pure governance/operator periphery unless required to compile/run the surface. |
| D3 | **FraxETH layout** | **Thin wrappers only** under `staking/ethereum/frax/` (Service + re-exports + tests/README). Leave bulk under `tokens/stable/frax`; do not relocate MiniRouter monorepo. |
| D4 | **Verification** | **Ethereum mainnet fork required.** `ETH_RPC_URL` (or project equivalent) must be set; green fork tests are the acceptance gate. Hermetic-only is **not** sufficient for done. |

---

## 0. How to use this document

| Section | Purpose |
|---------|---------|
| **§1 Scope & port modes** | What “done” means for agent work |
| **§2 Shared dependency research** | Matrix of transitive deps across protocols |
| **§3 Crane gap analysis** | What already exists vs missing |
| **§4 Prioritized common-dep work** | Shared external/helpers before protocols |
| **§5 Protocol prioritization & ports** | **Ordered list** + per-protocol deliverables |
| **§6 Single agent worktree task** | One long executable checklist (follows §5.0 order) |
| **§7 Verification gates** | Commands that prove ports work |
| **§8 Progress log** | Agent fills as work completes |

**Execution order (hard rule):**

```text
1) Shared / transitive deps → contracts/external (copy/gap-fill only; NO new remappings)
2) Scaffold staking/ethereum/* using @crane/ imports only
3) Protocol ports in §5.0 priority order (domain vendor + Service + fork tests)
4) IndexedEx generic ERC-4626 SE (D1) — after FraxETH Service green at minimum;
   full SE acceptance after ports needed for its smoke path are green
```

---

## 1. Scope & port modes

### 1.1 Protocols in this plan

| ID | Protocol | Primary tokens | Upstream (pin at execute time) |
|----|----------|----------------|--------------------------------|
| L | Lido | stETH, wstETH | `lidofinance/core` |
| R | Rocket Pool | rETH | `rocket-pool/rocketpool` |
| E | ether.fi | eETH, weETH | `etherfi-protocol/smart-contracts` |
| S | StakeWise V3 | osETH, EthVault | `stakewise/v3-core` |
| F | FraxETH | frxETH, sfrxETH | already under `tokens/stable/frax` (complete wrappers only) |

### 1.2 Port mode for v1 (locked — D2)

**Faithful domain vendor where feasible**, plus Crane wrapper surface.

| Deliverable | Required |
|-------------|----------|
| Canonical interfaces under `staking/ethereum/<p>/` | Yes |
| Domain contracts needed for mint/wrap/redeem/rate (pinned upstream) under `external/<lib>/` and/or protocol tree | **Yes where feasible** |
| Shared deps remapped to **existing** `@crane/contracts/external/...` (no nested OZ; **no new remappings**) | Yes |
| `*Service` library (submit/wrap/unwrap/deposit/redeem + previews) | Yes |
| Rate provider helper (`IRateProvider` shape) | Yes |
| Fork TestBase + **mainnet fork tests** (D4) | Yes |
| Full Aragon apps / EigenLayer AVS stack / Uni V3 / LayerZero | **Only if required to compile or exercise the vendored mint/wrap surface**; otherwise document skip |
| Operator/oracle/DAO governance trees not on the user mint path | Prefer skip + document |

**Missing shared deps** still go to `contracts/external/` first (expand existing trees; import via paths already wired for `@crane`).

### 1.3 Definition of done (program)

- [ ] §4 common-dep tasks closed or explicitly “N/A (document reason)”
- [ ] L, R, E, S each have: domain vendor (as feasible) + interfaces + Service + rate helper + **green mainnet fork tests**
- [ ] F has thin `staking/ethereum/frax/` Service + re-exports (D3); green fork tests
- [ ] No per-protocol copies of OZ/Solady; no new remappings
- [ ] All new imports use `@crane/...`
- [ ] IndexedEx **generic ERC-4626 SE** deployed via registry path; `IBasicVault.vaultTokens()` = `[protocolVault, asset()]`; fork (or full TestBase) proof on **sfrxETH** at minimum (D1)
- [ ] `forge test` gates in §7 pass

---

## 2. Shared dependency research

Sources: upstream `package.json`, `.gitmodules`, `remappings.txt`, `foundry.toml` (fetched 2026-07-21). Versions are **upstream intent**; Crane may map to a single compatible pin where API-compatible.

### 2.1 Upstream declared dependencies (on-chain relevant)

| Dependency | Lido | Rocket Pool | ether.fi | StakeWise | FraxETH (in Crane) | **Share count** |
|------------|:----:|:-----------:|:--------:|:---------:|:------------------:|:---------------:|
| **OpenZeppelin Contracts (non-upgradeable)** | ✅ 3.4 / 4.4 / 5.2 | ✅ 3.4 / 4.9 | ✅ ~4.8.0 | ✅ (via upgradeable bundle) | ✅ remapped → Crane OZ 4.9.6 | **5/5** |
| **OpenZeppelin Contracts Upgradeable** | ➖ (Aragon/apps use proxies differently) | ➖ | ✅ ~4.8.2 | ✅ (primary) | ➖ for FraxETH surface | **2/5** (E,S) |
| **Solady** | ➖ | ➖ | ✅ | ➖ | ➖ | **1/5** (E) |
| **forge-std** | ✅ (Foundry tests) | ➖ (Hardhat) | ✅ | ✅ | ✅ (Crane tests) | **4/5** (dev) |
| **WETH9 / IWETH** | common integrator dep | common | common | common | via Curve/minter paths | **5/5** (integration) |
| **Ethereum Deposit Contract interface** | ✅ (staking) | ✅ | ✅ | ✅ | ✅ (minter) | **5/5** (domain) |
| **Aragon OS / apps / MiniMe** | ✅ full | ➖ | ➖ | ➖ | ➖ | **1/5** (L only) |
| **EigenLayer contracts** | ➖ | ➖ | ✅ submodule | ➖ | ➖ | **1/5** (E only) |
| **Uniswap V3 core/periphery** | ➖ | ➖ | ✅ submodule | ➖ | ➖ | **1/5** (E only) |
| **LayerZero (weETH bridge)** | ➖ | ➖ | ✅ remappings | ➖ | ➖ | **1/5** (E only, **out of v1**) |
| **SSZ / BLS / lodestar** | ✅ (dev/test) | ✅ (dev) | ➖ | ➖ | ➖ | **2/5** (dev only) |
| **SafeMath (legacy OZ)** | via OZ 2/3 | via OZ 3 | ➖ | ➖ | ✅ used in Frax monorepo | **3/5** legacy |
| **ERC-4626 (OZ extension)** | not for stETH | ➖ | partial | vaults | ✅ `IsfrxETH` / OZ ERC4626 | **2+/5** (S,F) |
| **Permit / EIP-2612** | via OZ | via rETH | via weETH | via OZ | ✅ | **5/5** surface |
| **openzeppelin-solidity 2.x** | ✅ legacy | ➖ | ➖ | ➖ | ➖ | **1/5** (L only) |

### 2.2 Share-ranked list (transitive / shared libraries)

Ranked primarily by **how many of L/R/E/S/F declare or require the dependency**, secondarily by **whether v1 integration ports need it**.

| Rank | Dependency | Protocols | v1 necessity | Notes |
|------|------------|-----------|--------------|-------|
| **1** | OpenZeppelin Contracts (ERC20, SafeERC20, Math, Address, Context, …) | L R E S F | **High** if domain vendored; **Low** if interface+Service only (use Crane IERC20/SafeERC20) | Crane has **4.9.6** under `external/openzeppelin-contracts` |
| **2** | WETH9 + aware helpers | L R E S F | **High** (ETH↔WETH in Services/tests) | **Present:** `protocols/tokens/wrappers/weth/v9/` |
| **3** | Ethereum Deposit Contract interface | L R E S F | **Medium** (only if Services/tests interact with deposit root / validator pubkeys) | Not found as first-class Crane staking helper; may use interface-only |
| **4** | OpenZeppelin Upgradeable (UUPS/Initializable/ERC20Upgradeable) | E S | **Medium** if vendoring upgradeable domain; **Low** for interface+fork | Crane has `external/openzeppelin-upgradeable` — **confirm version pin** |
| **5** | OZ multi-version coexistence (3.x / 4.x / 5.x) | L R (E pins 4.8) | **High only for full Lido/RP domain compile** | Avoid for v1; remap APIs to 4.9.6 where possible |
| **6** | Solady | E | **Low–Medium** if ether.fi domain uses Solady utils | Crane has `external/solady` — gap-check symbols |
| **7** | forge-std | L E S F tests | **High for Foundry tests** | Already via Crane/Foundry — do not re-vendor |
| **8** | EigenLayer | E | **Out of v1** (LRT risk layer; Service talks LiquidityPool/weETH only) | Do not port until LRT full stack needed |
| **9** | Uniswap V3 | E | **Out of v1** (not needed for deposit/wrap Service) | Crane has Uni under `protocols/dexes/uniswap` |
| **10** | Aragon stack | L | **Out of v1** (DAO/app layer) | Full Lido DAO not in scope |
| **11** | LayerZero | E | **Out of v1** | Crane has partial `external/layerzero` |
| **12** | SSZ/BLS/lodestar | L R | **Dev only** — not Solidity ports | Skip |
| **13** | openzeppelin-solidity 2.x | L | **Out of v1** unless forced by vendored file | Prefer not to reintroduce |

### 2.3 Protocol-specific “domain” deps (not shared)

These are **not** candidates for the common-deps phase; they ship with the protocol package if ever fully vendored:

| Protocol | Domain-only |
|----------|-------------|
| Lido | Aragon OS, Lido oracle/AccountingOracle, WithdrawalQueue, VaultHub, DSM |
| Rocket Pool | RocketStorage address book, minipool, RPL, network balances |
| ether.fi | LiquidityPool, eETH shares, weETH, BNFT/TNFT, EigenLayer strategy adapters |
| StakeWise | EthVault, OsToken, OsTokenVaultController, vault factory, oracles |
| FraxETH | frxETH minter, sfrxETH reward cycle vault, Curve pool (interfaces already present) |

### 2.4 Research method notes (agent re-verify at execute)

At port time, re-run:

```bash
# Clone shallow or use gh raw for pins
# Count solidity imports of openzeppelin/solady/etc. in upstream src only
rg -o '@openzeppelin[^"]+|solady/[^"]+|eigenlayer|aragon' -g'*.sol' | sort | uniq -c | sort -rn
```

Update §2 tables if upstream pins moved.

---

## 3. Crane gap analysis (as of 2026-07-21)

| Dependency | Crane location | Status | Action for staking ports |
|------------|----------------|--------|---------------------------|
| OZ Contracts **4.9.6** | `contracts/external/openzeppelin-contracts` | ✅ Present | **Default remap target** for OZ 4.x APIs |
| OZ Upgradeable | `contracts/external/openzeppelin-upgradeable` | ✅ Present (version TBD in package) | Confirm pin; fill gaps if S/E need symbols missing |
| Solady | `contracts/external/solady` | ✅ Present | Gap-check vs ether.fi imports if domain vendored |
| Solmate | `contracts/external/solmate` | ✅ Present | Unlikely needed for these five |
| forge-std | Foundry / Crane test deps | ✅ | Use as-is |
| WETH9 | `protocols/tokens/wrappers/weth/v9` | ✅ | Import in TestBases/Services |
| LayerZero | `contracts/external/layerzero` | ⚠️ Partial | Skip for v1 staking |
| Uniswap V3 | `protocols/dexes/uniswap/v3` | ✅ Partial | Skip for v1 staking |
| EigenLayer | — | ❌ Missing | **Do not port in common phase** |
| Aragon | — | ❌ Missing | **Do not port in common phase** |
| Beacon DepositContract iface | — | ❌ / unclear | Add thin interface under `external/ethereum/` or `staking/ethereum/common/` if needed |
| OZ 3.x tree | — | ❌ | Only if full Lido/RP domain compile required |
| OZ 5.x tree | Lido declares 5.2 | ❌ | Only if full Lido 0.8.x domain requires it |
| FraxETH interfaces | `tokens/stable/frax/FraxETH/*` | ✅ Partial | Promote Service under `staking/ethereum/frax` |
| Lido/RP/ether.fi/StakeWise canonical ports | `staking/ethereum/` | ❌ Empty | Main work |

**Conclusion for common-deps phase:**  
Most **shared** libraries already exist. The common phase is primarily:

1. **Inventory + remap policy** (document which OZ pin Services use).  
2. **Gap-fill** any missing OZ upgradeable / Solady **symbols** discovered when compiling first domain slices.  
3. **Thin shared staking helpers** (DepositContract interface, optional ETH/WETH Service glue under `staking/ethereum/common/`).  
4. **Explicitly defer** EigenLayer, Aragon, LZ, Uni V3, multi-OZ-version trees unless a later full-vendor epic opens.

---

## 4. Prioritized common dependency plan

### Phase A0 — Policy & inventory (no code, ~1–2h)

| Task | Output |
|------|--------|
| A0.1 | Confirm Crane OZ upgradeable version (`package.json` or git tag note) |
| A0.2 | Write `staking/ethereum/DEPENDENCY_MAP.md`: **import path table only** (upstream name → existing `@crane/contracts/external/...` or Crane module). **Do not** add remappings — document which **existing** `@crane/` path to use. |
| A0.3 | List symbols each Service will need (expect: IERC20, SafeERC20, Math — all present under existing `@crane` paths) |
| A0.4 | Decide DepositContract: interface-only under `staking/ethereum/common/interfaces/IDepositContract.sol` |

### Phase A1 — Shared stubs already satisfied (verify only)

| Dep | Share | Action | Gate |
|-----|------:|--------|------|
| OZ 4.9 ERC20 / SafeERC20 / Math | 5 | **No port** — use existing external | `forge build` sample import |
| WETH9 | 5 | **No port** — use TestBase_Weth9 | compile |
| forge-std | 4 | **No port** | — |
| Solady (if E needs) | 1 | **Gap-check only** before ether.fi | compile ether.fi Service |

### Phase A2 — Thin shared staking common (implement)

Priority order by share + utility:

| Pri | Task | Why shared | Deliverable |
|----:|------|------------|-------------|
| 1 | `staking/ethereum/common/interfaces/IDepositContract.sol` | L R E S F | Standard deposit contract interface (mainnet `0x00000000219ab540356cBB839Cbe05303d7705Fa`) |
| 2 | `staking/ethereum/common/EthereumStakingLib.sol` (optional) | L R E S F | ETH↔WETH helpers reusing WETH9; safe approve patterns |
| 3 | `staking/ethereum/common/rate/IStakingRateProvider.sol` | L R E S F | Thin alias or doc that packages implement Balancer `IRateProvider` |
| 4 | `staking/ethereum/README.md` + address tables | all | Navigator for agents |

### Phase A3 — Conditional external expands (only if compile fails)

Execute **only when** a protocol step fails with missing import:

| Trigger | Action | Location |
|---------|--------|----------|
| Missing OZ upgradeable symbol for StakeWise domain vendor | Copy missing files into `external/openzeppelin-upgradeable` from pinned upstream tag | external first |
| ether.fi domain uses Solady symbol not in Crane | Add file to `external/solady` | external first |
| Full Lido domain vendor epic (not v1) | Separate plan for OZ 3/5 + Aragon | do not sneak into v1 |

### Phase A4 — Explicit non-goals (common phase)

- [ ] EigenLayer  
- [ ] Aragon  
- [ ] LayerZero weETH bridge  
- [ ] Uniswap V3 for ether.fi  
- [ ] Multi-version OZ 3.x/5.x trees  
- [ ] SSZ/BLS  

---

## 5. Protocol prioritization & port plan (after Phase A)

### 5.0 Prioritization rule (normative)

```text
1. Primary key:   highest “common dependency score” first
2. Tie-break:     smallest upstream repo / surface first
3. Always:        no new remappings; @crane imports only
```

**Common dependency set \(C\)** = transitive deps with **share count ≥ 2** across {Lido, Rocket Pool, ether.fi, StakeWise, Frax} (from §2):

| ID in \(C\) | Dependency | Share |
|-------------|------------|------:|
| C1 | OpenZeppelin Contracts (non-upgradeable) | 5 |
| C2 | OpenZeppelin Contracts Upgradeable | 2 |
| C3 | forge-std (tests) | 4 |
| C4 | WETH9 / IWETH (integration + tests) | 5 |
| C5 | Ethereum Deposit Contract interface | 5 |
| C6 | Permit / EIP-2612 surface | 5 |
| C7 | SafeMath / legacy OZ math (where present) | 3 |

**Score(protocol)** = number of members of \(C\) that the protocol **uses or requires** for the v1 integration surface (declared upstream **or** needed by Service/fork tests).

**Size** = GitHub `size` (KB) for full upstream repos (2026-07-21 API); FraxETH uses **local Crane surface** size (already partially ported).

### 5.0.1 Scores

| Protocol | C1 OZ | C2 OZ-up | C3 forge-std | C4 WETH | C5 Deposit | C6 Permit | C7 SafeMath | **Score** |
|----------|:-----:|:--------:|:------------:|:-------:|:----------:|:---------:|:-----------:|:---------:|
| **FraxETH** | ✅ | ➖ | ✅ | ✅ | ✅ | ✅ | ✅ | **6** |
| **StakeWise** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ➖ | **6** |
| **ether.fi** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ➖ | **6** |
| **Lido** | ✅ | ➖ | ✅ | ✅ | ✅ | ✅ | ✅ | **6** |
| **Rocket Pool** | ✅ | ➖ | ➖ | ✅ | ✅ | ✅ | ✅ | **5** |

Notes:
- Rocket Pool is primarily Hardhat (no forge-std in upstream) → lower score.
- OZ Upgradeable counts for StakeWise + ether.fi (exercises Crane `external/openzeppelin-upgradeable` early among the score-6 group after Frax).
- Unique-only deps (Aragon, EigenLayer, Uni V3, LayerZero, Solady) **do not** increase score; they are deferred or protocol-local later.

### 5.0.2 Size (tie-break among equal scores)

| Protocol | Size basis | Size | Rank within score |
|----------|------------|-----:|-------------------|
| **FraxETH** | Crane `tokens/stable/frax/FraxETH` surface | **~20 KB / 4 files** | smallest |
| **StakeWise** | `stakewise/v3-core` GitHub size | **29,338 KB** | |
| **ether.fi** | `etherfi-protocol/smart-contracts` | **49,249 KB** | |
| **Lido** | `lidofinance/core` | **127,642 KB** | largest of score-6 |
| **Rocket Pool** | `rocket-pool/rocketpool` | **14,958 KB** | N/A (score 5; after all score-6) |

### 5.0.3 Final protocol port order

| Priority | Protocol | Score | Size rank | Why this position |
|---------:|----------|------:|-----------|-------------------|
| **1** | **FraxETH** | 6 | smallest | Max common score + tiniest surface; interfaces already in Crane; proves Service/fork + OZ/WETH path with minimal blast radius |
| **2** | **StakeWise** | 6 | next | Still max common score; smaller than ether.fi/Lido; **first OZ-upgradeable** consumer in the queue |
| **3** | **ether.fi** | 6 | mid | Max common score; larger than StakeWise; wrap pattern; **no** EigenLayer/Uni/LZ in v1 |
| **4** | **Lido** | 6 | largest of 6s | Max common score but **largest** repo; port last among score-6 so common patterns are already proven |
| **5** | **Rocket Pool** | 5 | (smaller repo but lower score) | Fewer common deps (no forge-std / no OZ-upg); after all score-6 |

```text
Phase A (common) → FraxETH → StakeWise → ether.fi → Lido → Rocket Pool
```

**Rationale summary:** Hitting **max common-dependency protocols first** surfaces remapping/import and external-gap issues early. **Smallest first among ties** keeps early failures cheap (FraxETH, then StakeWise) before large trees (ether.fi, Lido).

### 5.1 Per-protocol checklist (copy for each)

```text
[ ] Directory scaffold under staking/ethereum/<name>/
[ ] interfaces/* (canonical; document supersedes Pendle/Liquity fragments)
[ ] services/*Service.sol
[ ] rate/*RateProvider.sol
[ ] test/bases/TestBase_*Fork.sol
[ ] test/foundry/.../*_Fork.t.sol  (or Crane test tree convention)
[ ] README.md: addresses, upstream pin, license, routes
[ ] Remap all imports to @crane/...
[ ] forge test --match-path <protocol> green
[ ] No OZ copy under protocol tree
```

### Minimum Service APIs (from PRD)

| Protocol | Service ops |
|----------|-------------|
| Frax | `submit`, `submitAndDeposit`, sfrxETH `deposit`/`redeem`, previews |
| Lido | submit ETH→stETH, wrap/unwrap, submitAndWrap, rate views |
| Rocket Pool | deposit ETH→rETH, burn/redeem when liquid, exchange rate, capacity checks |
| ether.fi | deposit→eETH, wrap/unwrap weETH, depositAndWrap, share math views |
| StakeWise | vault deposit/redeem, osETH mint/burn (as allowed), rate views |

### Mainnet addresses (verify at execute)

| Token / contract | Address (verify) |
|------------------|------------------|
| stETH | `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84` |
| wstETH | `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0` |
| rETH | `0xae78736Cd615f374D3085123A210448E74Fc6393` |
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| ether.fi LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` **(verify)** |
| frxETH | `0x5E8422345238F34275888049021821E8E08CAa1f` |
| frxETHMinter | `0xbAFA44EFE7901E04E39Dad13167D089C559c1138` |
| sfrxETH | `0xac3E018457B222d93114458476f3E3416Abbe38F` |
| Deposit contract | `0x00000000219ab540356cBB839Cbe05303d7705Fa` |
| osETH / StakeWise vaults | from StakeWise deployments docs **(verify)** |

---

## 6. Single agent worktree task (execute end-to-end)

**Goal:** One long agent session in a git worktree ports common stubs + all five staking surfaces + green fork tests.

### 6.1 Preconditions

```bash
# From IndexedEx / Crane root as appropriate
git submodule update --init --recursive   # if needed
# Ethereum mainnet RPC available as ETH_RPC_URL or FOUNDRY_ETH_RPC_URL
export ETH_RPC_URL=...
```

Use Crane test layout conventions (`lib/crane/test/foundry/fork/...` or protocol-local `test/bases` + crane test mirror — **match existing Camelot/Frax fork patterns**).

### 6.2 Agent checklist (ordered)

#### Block 0 — Bootstrap

- [ ] Create branch / worktree: `feature/crane-ethereum-staking-ports`
- [ ] Read PRD + this plan + `DEFI_PORTING_PRD` A.4–A.5
- [ ] Confirm `ETH_RPC_URL` works: `cast block-number --rpc-url $ETH_RPC_URL`

#### Block 1 — Common deps (Phase A)

- [ ] A0.1–A0.4 complete → write `staking/ethereum/DEPENDENCY_MAP.md` (**import paths only; no remapping edits**)
- [ ] A2.1 `IDepositContract.sol` if any Service needs it
- [ ] A2.2 optional `EthereumStakingLib.sol` (ETH/WETH via existing WETH9 `@crane` path)
- [ ] A2.4 `staking/ethereum/README.md`
- [ ] Confirm: **zero** changes to `remappings.txt` / `foundry.toml` remappings
- [ ] **Gate:** document “no new OZ/Solady files required for v1” **or** fill specific external gaps with pinned commits (still no new remaps)

#### Block 2 — FraxETH (priority 1) — score 6, smallest

- [ ] `staking/ethereum/frax/` Service reusing `tokens/stable/frax/FraxETH` interfaces
- [ ] Fork test: ETH → frxETH → sfrxETH (or minter `submitAndDeposit`)
- [ ] Rate provider via `convertToAssets`
- [ ] **Gate:** green FraxETH fork tests

#### Block 3 — StakeWise (priority 2) — score 6, next-smallest full repo

- [ ] `IOsETH` / `IEthVault` / controller as needed
- [ ] `StakeWiseService` against a public mainnet vault
- [ ] Rate provider; first consumer of OZ-upgradeable path if domain touches it
- [ ] Fork tests: vault deposit and/or osETH path
- [ ] **Gate:** green StakeWise fork tests

#### Block 4 — ether.fi (priority 3) — score 6

- [ ] Canonical `IEETH`, `IWeETH`, `IEtherFiLiquidityPool`
- [ ] `EtherFiService` + weETH rate
- [ ] Fork tests: deposit + wrap path
- [ ] **Gate:** green ether.fi fork tests  
- [ ] **Do not** vendor EigenLayer / Uni V3 / LZ

#### Block 5 — Lido (priority 4) — score 6, largest repo

- [ ] Canonical `IStETH`, `IWstETH` (do not break Pendle/Liquity yet)
- [ ] `LidoService` + `WstETHRateProvider`
- [ ] Fork tests: wrap/unwrap; optional submit
- [ ] **Gate:** green Lido fork tests  
- [ ] **Do not** vendor Aragon / full DAO

#### Block 6 — Rocket Pool (priority 5) — score 5

- [ ] `IRETH` + deposit pool interface(s)
- [ ] `RocketPoolService` + rate provider
- [ ] Fork tests: deposit when possible; document empty-pool revert
- [ ] **Gate:** green Rocket Pool fork tests

#### Block 7 — IndexedEx generic ERC-4626 SE (D1)

- [ ] DFPkg + facets: SE is ERC-4626 with `asset() = protocolVault`
- [ ] `IBasicVault.vaultTokens()` = **`[protocolVault, IERC4626(protocolVault).asset()]`** (multi-asset basic vault; not single-token-only facet alone)
- [ ] Routes: underlying ↔ protocolVault ↔ SE share (compose)
- [ ] `deployVault(IERC4626)` via IndexedEx vault registry / manager path (no raw `new` DFPkg)
- [ ] **Mainnet fork** (or production-first TestBase that hits real sfrxETH): deposit/redeem proof on **sfrxETH**
- [ ] Assert `vaultTokens().length == 2` and membership of vault + underlying
- [ ] **Gate:** SE tests green with `ETH_RPC_URL`

*Ordering note:* Block 7 may start after **Block 2 (FraxETH)** is green so sfrxETH SE smoke does not wait for Lido/RP; re-run SE suite after later ports if adapters are added.

#### Block 8 — Integration polish

- [ ] Cross-link READMEs; update PRD / this plan progress log
- [ ] Optional: thin `Behavior_*` for rate providers
- [ ] Run full staking ethereum + SE test suite (§7)
- [ ] Confirm still **no remapping file changes** in the branch
- [ ] Commit with message summarizing ports + SE + test proof

### 6.3 Agent constraints (non-negotiable)

1. **No new remappings** — do not edit `remappings.txt` or Foundry remapping config; only existing `@crane/...` imports.  
2. **No** `new` for IndexedEx production deployables (facets/DFPkgs via CREATE3 / registry). Crane libraries/interfaces are normal Solidity.  
3. **No** new git submodules for OZ/Solady — copy into `contracts/external` only if gap-fill required, then import via **existing** `@crane/contracts/external/...` path.  
4. **No** protocol-local `dependencies/openzeppelin`.  
5. **Mainnet fork required** for acceptance (D4); hermetic alone is not done.  
6. **Faithful domain vendor where feasible** (D2); still skip pure governance/operator trees when not needed for mint/wrap.  
7. Pin upstream commit/tag in each protocol README.  
8. Follow **§5.0 order** for protocol ports (do not reorder for TVL).  
9. FraxETH = **thin** `staking/ethereum/frax` only (D3).  
10. If a domain vendor forces EigenLayer/Aragon solely for unused modules, **narrow** to the mint/wrap subgraph and document the cut.

### 6.4 Suggested commit cadence

| Commit | Content |
|--------|---------|
| 1 | common scaffold + DEPENDENCY_MAP + README |
| 2 | FraxETH Service + fork tests (priority 1) |
| 3 | Generic ERC-4626 SE + sfrxETH fork proof (can land here per Block 7 note) |
| 4 | StakeWise domain + Service + tests (priority 2) |
| 5 | ether.fi domain + Service + tests (priority 3) |
| 6 | Lido domain + Service + tests (priority 4) |
| 7 | Rocket Pool domain + Service + tests (priority 5) |
| 8 | polish / docs / final suite |

---

## 7. Verification gates

### 7.1 Build

```bash
cd lib/crane   # or monorepo root with remappings
forge build
```

### 7.2 Fork tests (adjust paths to actual files)

```bash
export ETH_RPC_URL=...

forge test --fork-url $ETH_RPC_URL \
  --match-path '**/staking/ethereum/**' -vv

# Or per protocol:
forge test --fork-url $ETH_RPC_URL --match-contract LidoServiceFork -vv
forge test --fork-url $ETH_RPC_URL --match-contract RocketPoolServiceFork -vv
forge test --fork-url $ETH_RPC_URL --match-contract EtherFiServiceFork -vv
forge test --fork-url $ETH_RPC_URL --match-contract StakeWiseServiceFork -vv
forge test --fork-url $ETH_RPC_URL --match-contract FraxETHServiceFork -vv
```

### 7.3 Behavioral assertions (minimum)

| Protocol | Assert |
|----------|--------|
| Frax | `submitAndDeposit` or deposit increases sfrxETH; `convertToAssets` monotonic after sync |
| Lido | wrap/unwrap inverse within 1 share; `stEthPerToken` matches rate provider |
| Rocket Pool | deposit mints rETH when pool has capacity; rate > 0 |
| ether.fi | deposit+wrap increases weETH; unwrap recovers eETH |
| StakeWise | vault deposit increases shares; osETH rate readable |

### 7.4 Hygiene gates

```bash
# Fail if protocol trees vendor OZ
! rg -n 'contracts/external/openzeppelin' lib/crane/contracts/protocols/staking/ethereum --glob '**/openzeppelin/**'
# Prefer @crane imports in new files
rg -n "import \"" lib/crane/contracts/protocols/staking/ethereum --glob '*.sol' | head

# Fail if remappings were edited (from branch base)
git diff origin/main -- remappings.txt foundry.toml lib/crane/remappings.txt lib/crane/foundry.toml 2>/dev/null | head
# Expect: no remapping-related hunks
```

---

## 8. Progress log (agent updates)

| Date | Block | Status | Notes |
|------|-------|--------|-------|
| 2026-07-21 | Research | ✅ | Shared dep matrix filled from upstream package/gitmodules |
| 2026-07-21 | Protocol priority §5.0 | ✅ | Score desc, size asc; no new remappings |
| 2026-07-21 | A0–A4 | ✅ | DEPENDENCY_MAP, IDepositContract, EthereumStakingLib, README; no new remaps |
| 2026-07-21 | Frax (pri 1) | ✅ | Thin Service + SfrxETHRateProvider; mainnet fork green |
| 2026-07-21 | StakeWise (pri 2) | ✅ | IEthVault/IOsETH/controller + Service + rate; fork green |
| 2026-07-21 | ether.fi (pri 3) | ✅ | deposit+wrap/unwrap Service + WeETHRateProvider; fork green |
| 2026-07-21 | Lido (pri 4) | ✅ | wrap/unwrap inverse + WstETHRateProvider; fork green |
| 2026-07-21 | Rocket Pool (pri 5) | ✅ | deposit when capacity + RETHRateProvider; fork green |
| 2026-07-21 | SE (Block 7) | ✅ | Generic ERC-4626 SE via registry; vaultTokens=[sfrxETH,frxETH]; deposit/redeem fork green |
| 2026-07-21 | Polish | ✅ | staking_eth + se_erc4626 FOUNDRY profiles; 11/11 staking + 3/3 SE fork tests green |

---

## 9. Follow-on (after this epic)

1. Optional import cleanup: Pendle/Liquity/Uni `IWstETH` → canonical Lido interfaces.  
2. Broader Lido Aragon / ether.fi EigenLayer full trees if not required for mint/wrap in this epic.  
3. LST strategy adapters on generic SE (ETH→wstETH/rETH/weETH) beyond pure 4626.  
4. Multi-vault weighted DETF legs using new SE instances.

---

## 10. Changelog

| Date | Change |
|------|--------|
| 2026-07-21 | Initial implementation plan: shared dep research, share-ranked priorities, common-first sequence, single agent worktree checklist |
| 2026-07-21 | **Protocol order locked:** common-dep score ↓, repo size ↑ on ties → FraxETH → StakeWise → ether.fi → Lido → Rocket Pool; **no new remappings** |
| 2026-07-21 | **Locked decisions D1–D4:** epic = Crane ports + ERC-4626 SE; faithful domain vendor; thin Frax layout; mainnet fork required |

---

*Start execution at Block 0. Do not begin protocol ports until Block 1 (common) is marked complete or explicitly N/A. Protocol ports follow §5.0 order only. SE (Block 7) may start after FraxETH green.*

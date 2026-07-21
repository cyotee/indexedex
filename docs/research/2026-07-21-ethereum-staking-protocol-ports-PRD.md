# PRD: Ethereum Staking Protocol Ports (Crane) + ERC-4626 SE Adapter Path

**Date:** 2026-07-21  
**Status:** Draft for implementation planning  
**Owners:** Crane (ports) + IndexedEx (ERC-4626 Standard Exchange adapter)  
**Companion docs:**
- [`docs/research/2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`](./2026-07-21-ethereum-staking-protocols-se-vault-assessment.md) — market / SE viability
- [`lib/crane/DEFI_PORTING_PRD.md`](../../lib/crane/DEFI_PORTING_PRD.md) — program-wide port methodology (esp. §A.4–A.5, §C.2 Lido)
- [`lib/crane/DEFI_PORTING_PRIORITIZATION.md`](../../lib/crane/DEFI_PORTING_PRIORITIZATION.md) — Lido already ranked Phase 1 #2
- Aave Stata SE gold path: `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`

---

## 1. Goal

1. **Port** the Ethereum liquid staking / restaking surfaces needed for IndexedEx strategy vaults into Crane under:

```text
lib/crane/contracts/protocols/staking/ethereum/
  lido/
  rocket-pool/
  etherfi/
  stakewise/
  (frax/ — optional promote/complete; see §5)
```

2. Provide a **Crane-native integration surface** per protocol (interfaces + Service + TestBase + fork verification), consistent with existing ports (Camelot stubs+Service, Aave full port, FraxETH interfaces+router).

3. Unblock an IndexedEx **generic ERC-4626 Standard Exchange vault** that wraps any compliant `IERC4626` as SE `asset()`, so Lido/Rocket Pool/ether.fi/StakeWise/Frax (and future yield tokens) share one adapter shim rather than N bespoke SE packages for identical 4626 math.

This PRD is the **Crane port** plan. The generic ERC-4626 SE vault is an **IndexedEx consumer** of these ports (and of any mainnet ERC-4626); its own implementation plan should live under IndexedEx `contracts/vaults/` or `contracts/protocols/` once this port surface is locked.

---

## 2. Product architecture (two layers)

```text
┌─────────────────────────────────────────────────────────────────┐
│ IndexedEx: ERC4626StandardExchangeDFPkg (generic adapter SE)   │
│  - SE share IERC4626.asset() = protocolVault (the ERC-4626)     │
│  - IBasicVault.vaultTokens() = [protocolVault, vault.asset()]   │
│  - IStandardExchangeIn/Out over those tokens + SE share         │
│  - deployVault(IERC4626 protocolVault) via vault registry       │
└────────────────────────────▲────────────────────────────────────┘
                             │ uses Crane services / interfaces
┌────────────────────────────┴────────────────────────────────────┐
│ Crane: protocols/staking/ethereum/<protocol>/                   │
│  - Canonical interfaces (IStETH, IWstETH, IRETH, …)             │
│  - *Service libraries (submit/wrap/unwrap/deposit/redeem)       │
│  - Optional hermetic stubs for local tests                      │
│  - TestBase_* + fork TestBase_*                                 │
│  - Rate-provider helpers (Balancer IRateProvider shape)         │
└────────────────────────────▲────────────────────────────────────┘
                             │ vendored / forked against
┌────────────────────────────┴────────────────────────────────────┐
│ Upstream protocol deployments (mainnet) + optional external/    │
└─────────────────────────────────────────────────────────────────┘
```

### Why a generic ERC-4626 SE (IndexedEx) + thin protocol ports (Crane)

| Approach | When | Drawback if overused |
|----------|------|----------------------|
| **Generic ERC-4626 SE** | Yield token **is** ERC-4626 (`sfrxETH`, some StakeWise vaults, MetaMorpho, Stata, …) | Cannot alone express non-4626 mint paths (Lido submit, rETH deposit pool, eETH deposit) |
| **Protocol Service ports** | Mint/wrap/redeem are protocol-specific | Needed for ETH→LST closed-form routes and hermetic tests |
| **Protocol-specific SE** | Only if routes diverge heavily (async queues, dual rebasing+wrap) | N packages to maintain |

**Recommended product split:**

| Protocol | Preferred yield token for SE `asset()` | Needs Crane Service beyond pure 4626? | SE package |
|----------|----------------------------------------|---------------------------------------|------------|
| Lido | `wstETH` (not rebasing stETH) | **Yes** — ETH/stETH submit + wrap/unwrap | Generic 4626 SE **only if** a 4626 wrapper over wstETH exists; else **Lido-aware routes** via Service in a thin SE or pre-mint wstETH then deposit into generic SE |
| Rocket Pool | `rETH` | **Yes** — deposit pool mint/burn + exchange rate | Same: Service for ETH↔rETH; generic SE if rETH wrapped as 4626 or SE holds rETH with custom In/Out |
| ether.fi | `weETH` | **Yes** — deposit + eETH wrap | Same as Lido pattern |
| StakeWise | `osETH` or vault share | **Yes** for vault mint; vault shares may be 4626-like | Generic SE for vault ERC-4626 shares; osETH Service for mint/burn |
| Frax | `sfrxETH` (**already IERC4626**) | Minimal if frxETH already held; Service for ETH→frxETH→sfrxETH | **Best fit for pure generic ERC-4626 SE** |

**Important precision:** Many LSTs are **value-accruing ERC-20s**, not ERC-4626. The generic ERC-4626 SE wraps an ERC-4626 **reserve**. Two valid patterns:

1. **Reserve = protocol ERC-4626** (sfrxETH, Stata, MetaMorpho) → generic SE deposits that token as `asset()`.
2. **Reserve = value-accruing LST** that is **not** 4626 (wstETH, rETH, weETH) → either:
   - (A) treat SE as ERC-4626 whose `asset()` is the LST (IndexedEx already does this for Stata — the SE is 4626, the reserve need not be), using **protocol Service** for base→LST legs; or  
   - (B) introduce a thin Crane/IndexedEx 4626 adapter only where needed.

This PRD’s Crane ports deliver the **protocol Service + interfaces** so IndexedEx can implement (A) as a **generalized “yield-token SE”** with an ERC-4626 SE share layer (the “adapter shim”), parameterized by `asset = LST` and optional protocol hooks — not necessarily requiring the LST itself to implement ERC-4626.

---

## 3. Crane port methodology (normative)

Follow `DEFI_PORTING_PRD.md` §A.4–A.5:

1. **Faithful protocol surface** — pin upstream tag/commit; no silent behavior changes.
2. **No new git submodules** — copy sources or interfaces into the tree.
3. **Remap shared deps** to `@crane/...` (OZ, ERC20 utils, WETH9) — do not re-vendor OZ per protocol.
4. **Crane wrapper surface** always includes:
   - Interfaces under `contracts/interfaces/protocols/staking/ethereum/<protocol>/` **or** co-located under the protocol dir (match local convention; Camelot uses both `interfaces/protocols/...` and protocol tree).
   - `*Service.sol` library for deposit/mint/wrap/unwrap/redeem quotes.
   - `TestBase_<Protocol>` (hermetic where stubs exist) + fork TestBase.
5. **Hermetic stubs** only when local deploy is valuable (like Camelot/Aerodrome). For large/upgradable systems (Lido Aragon, Rocket Pool storage, ether.fi), **prefer fork tests** against mainnet addresses + thin interface adapters; stubs only for the minimal mint/wrap path if tests require it.
6. **Do not** ship full DAO / node-operator / oracle networks unless required for the integration surface.

### Target directory layout (this PRD)

```text
lib/crane/contracts/protocols/staking/ethereum/
  README.md                          # index of ports + mainnet addresses
  common/                            # optional shared helpers (ETH/WETH, rate math)
    EthereumStakingService.sol       # optional: shared ETH↔WETH, slip helpers
  lido/
    interfaces/   (or re-export from contracts/interfaces/...)
    services/LidoService.sol
    stubs/                           # optional: minimal WstETH+StETH mock for hermetic
    test/bases/TestBase_Lido.sol
    test/bases/TestBase_LidoFork.sol
  rocket-pool/
    ...
  etherfi/
    ...
  stakewise/
    ...
  frax/                              # §5 — complete/promote from tokens/stable/frax
    ...
```

**Relation to existing `DEFI_PORTING_PRD` C.2 path** (`staking/lido/`): this PRD **supersedes the target path** to `staking/ethereum/lido/` so all Ethereum staking ports share one tree. Update `DEFI_PORTING_PRD.md` C.2 when this PRD is accepted.

**Empty dir today:** `lib/crane/contracts/protocols/staking/ethereum/` already exists (placeholder).

---

## 4. Inventory of what already exists in Crane

### 4.1 FraxETH — **partial port (usable interfaces; incomplete as a staking port)**

**Location:** `lib/crane/contracts/protocols/tokens/stable/frax/` (not under `staking/ethereum/`)

| Artifact | Path | Status |
|----------|------|--------|
| `IfrxETH` | `FraxETH/IfrxETH.sol` | Interface only (mint/burn/permit surface) |
| `IfrxETHMinter` | `FraxETH/IfrxETHMinter.sol` | Interface: `submit`, `submitAndDeposit`, validators |
| `IsfrxETH` | `FraxETH/IsfrxETH.sol` | **Full IERC4626-like** deposit/mint/redeem + reward cycle views |
| `FrxETHMiniRouter` | `FraxETH/FrxETHMiniRouter.sol` | Production router: ETH→frxETH via minter or Curve; optional sfrxETH deposit; **hardcoded mainnet addresses** |
| `wfrxETH` / `IwfrxETH` | `ERC20/wfrxETH.sol` | WETH9-style wrap for **Fraxchain native frxETH**, not Ethereum LST vault |
| Curve pool interface | `Curve/ICurvefrxETHETHPool.sol` | Pricing for MiniRouter |
| Fork test | `lib/crane/test/foundry/fork/ethereum/.../FrxETH/FrxETHMiniRouter_Test.t.sol` | Exists |
| Pendle SY | `perps/pendle/.../PendleSfrxEthSY.sol`, `interfaces/Frax/IFrxEthMinter.sol` | Third-party consumer of frxETH minter |

**Hardcoded mainnet addresses in MiniRouter (verify at use):**

| Contract | Address |
|----------|---------|
| frxETH | `0x5E8422345238F34275888049021821E8E08CAa1f` |
| frxETHMinter | `0xbAFA44EFE7901E04E39Dad13167D089C559c1138` |
| sfrxETH | `0xac3E018457B222d93114458476f3E3416Abbe38F` |
| Curve frxETH/ETH | `0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577` |

**Gaps for a complete FraxETH staking port:**

- [ ] No hermetic `frxETH` / `sfrxETH` / minter **implementations** (interfaces + live fork only)
- [ ] No `FraxETHService` library (MiniRouter is a contract with fixed addresses, not a reusable Service)
- [ ] Not under `staking/ethereum/frax/`
- [ ] No `TestBase_FraxETH` hermetic base
- [ ] No Balancer-style rate provider for sfrxETH/frxETH in the FraxETH package itself

**Recommendation:** **Do not re-port from scratch.** Complete by:

1. Adding `staking/ethereum/frax/` Crane wrappers that **re-export** existing interfaces and add `FraxETHService` (parameterized addresses, not hardcoded).
2. Keeping bulk Frax monorepo under `tokens/stable/frax/` as-is.
3. Preferring **sfrxETH** as the generic ERC-4626 SE first integration target (best 4626 fit in the staking set).

### 4.2 Lido — **fragment interfaces only (no Crane port)**

Scattered, incomplete, and **not** under a canonical staking package:

| Location | What |
|----------|------|
| `perps/pendle/interfaces/IStETH.sol`, `IWstETH.sol` | Partial stETH/wstETH (submit, shares, wrap) |
| `lending/euler/v1/oracle/adapter/lido/IStEth.sol` | Shares conversion only |
| `cdps/liquity/v2/bold/Interfaces/IWSTETH.sol` | wrap/unwrap + rate views |
| `dexes/uniswap/v4/.../IWstETH.sol` | wrap/unwrap + stEthPerToken |
| `perps/pendle/.../PendleWstEthSY.sol` | Pendle consumer |

**No** `LidoService`, **no** TestBase, **no** `staking/ethereum/lido/`.

### 4.3 Rocket Pool — **minimal fragment**

| Location | What |
|----------|------|
| `cdps/liquity/v2/bold/Interfaces/IRETHToken.sol` | `getExchangeRate()` only |
| Pendle `PendleAuraWethRocketEthSYV2.sol` | Consumer, not a port |

**No** deposit pool interface, **no** Service, **no** TestBase.

### 4.4 ether.fi — **Pendle-local interfaces only**

| Location | What |
|----------|------|
| `perps/pendle/interfaces/EtherFi/IEtherFiLiquidityPool.sol` | deposit, share math |
| `perps/pendle/interfaces/EtherFi/IEtherFiWEEth.sol` | wrap/unwrap eETH↔weETH |
| `perps/pendle/.../EtherFi/PendleWEEth*.sol` | SY adapters |

**No** first-class Crane staking port.

### 4.5 StakeWise — **none**

No dedicated interfaces, services, or stubs found under Crane protocols for StakeWise V3 / osETH.

### 4.6 Reference port styles to copy

| Style | Example | Use for staking when… |
|-------|---------|------------------------|
| **Full protocol tree** | Aave v3.6 under `lending/aave/v3.6/` | Rarely (too large for LST DAOs) |
| **Hermetic stubs + Service + TestBase** | Camelot V2, Aerodrome V1 | Want local deploy without fork |
| **Interfaces + production helper + fork test** | FraxETH MiniRouter | Thin LST surface (default for this PRD) |
| **Interfaces only inside another protocol** | Pendle EtherFi/Lido | **Anti-pattern** for first-class ports — extract/canonicalize |

---

## 5. Per-protocol port specifications

Each section: upstream · mainnet addresses · scope · layout · Service API · verification · risks · SE consumer notes.

Addresses marked **(verify)** must be confirmed from official docs at implementation time.

---

### 5.1 Lido (`staking/ethereum/lido/`)

#### Upstream

| Field | Value |
|-------|--------|
| Repos | `lidofinance/core` (stETH/Lido), `WstETH.sol`; docs `lidofinance/docs` |
| License | GPL-3.0 **(verify)** |
| Pin | Release tag at port time **(verify)** — e.g. documented v3.x core |
| Existing Crane note | `DEFI_PORTING_PRD` C.2 — path updated to `staking/ethereum/lido/` |

#### Mainnet (Ethereum) — verify

| Contract | Address |
|----------|---------|
| stETH / Lido | `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84` |
| wstETH | `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0` |
| WithdrawalQueue | **(verify)** from Lido deployed contracts docs |
| stETH on L2 / bridges | Out of scope for v1 port (document only) |

#### In scope (v1)

- Canonical `IStETH`, `IWstETH` (merge/supersede Pendle/Liquity/Uni fragments for new code)
- `LidoService`:
  - `submitETH` / `submitWETH` → stETH  
  - `wrap` / `unwrap` stETH ↔ wstETH  
  - `submitAndWrap` ETH → wstETH  
  - Views: `stEthPerToken`, `tokensPerStEth`, share conversions  
- Optional read-only `ILidoWithdrawalQueue` for status queries (no forced claim automation in v1 Service)
- `WstETHRateProvider` helper implementing Balancer `IRateProvider` (`getRate()` → stETH per wstETH scaled 1e18)
- Fork TestBase + wrap/unwrap/submit tests
- Optional hermetic stubs: simplified rebasing stETH + wstETH for unit tests only

#### Out of scope (v1)

- Full Lido DAO, node operator registry, oracle reports, AccountingOracle, DSM
- L2 bridge deployments
- stETH as SE `asset()` (rebasing) — **always prefer wstETH**

#### Port layout

```text
staking/ethereum/lido/
  interfaces/IStETH.sol
  interfaces/IWstETH.sol
  interfaces/ILidoWithdrawalQueue.sol   # optional v1
  services/LidoService.sol
  rate/WstETHRateProvider.sol           # or under rateProviders/
  stubs/                                # optional
  test/bases/TestBase_Lido.sol
  test/bases/TestBase_LidoFork.sol
  README.md
```

Also place thin re-exports under `contracts/interfaces/protocols/staking/ethereum/lido/` if that is the project convention for external consumers.

#### Crane Service API (sketch)

```solidity
library LidoService {
    function _submit(IStETH steth, address referral) internal returns (uint256 stethAmount);
    function _wrap(IWstETH wsteth, uint256 stethAmount) internal returns (uint256 wstethAmount);
    function _unwrap(IWstETH wsteth, uint256 wstethAmount) internal returns (uint256 stethAmount);
    function _submitAndWrap(IStETH steth, IWstETH wsteth, address referral)
        internal returns (uint256 wstethAmount);
    // views for previews
    function _previewWrap(IWstETH wsteth, uint256 stethAmount) internal view returns (uint256);
    function _previewUnwrap(IWstETH wsteth, uint256 wstethAmount) internal view returns (uint256);
}
```

#### Verification

- [ ] Fork: ETH → stETH → wstETH → stETH round-trip (accounting for share math)
- [ ] Fork: rate provider matches `stEthPerToken()`
- [ ] Behavior: ERC-20 permit if used; transfer restrictions none expected
- [ ] NatSpec per Crane LR-1 style on Service

#### SE / IndexedEx consumer notes

- Prefer SE routes that end in **wstETH** as reserve.
- Generic ERC-4626 SE: deposit **wstETH** after Service mint, or fold Service into SE In facet for ETH→wstETH→shares.
- Rebasing stETH must not be bare vault accounting asset.

#### Dedup work

- New code should import canonical `staking/ethereum/lido` interfaces.
- Leave Pendle/Liquity/Uni copies in place initially (avoid wide churn); mark deprecated in README; optional follow-up PR to re-point imports.

---

### 5.2 Rocket Pool (`staking/ethereum/rocket-pool/`)

#### Upstream

| Field | Value |
|-------|--------|
| Repo | `rocket-pool/rocketpool` |
| Key contracts | `RocketTokenRETH`, deposit pool / network balances (via RocketStorage address resolution) |
| License | **(verify)** GPL-3.0 typical |
| Docs | https://docs.rocketpool.net/overview/contracts-integrations |

#### Mainnet — verify

| Contract | Address |
|----------|---------|
| rETH | `0xae78736Cd615f374D3085123A210448E74Fc6393` |
| RocketStorage / DepositPool / Protocol DAO | **(verify)** from official contract list |

Rocket Pool uses a **storage address book** pattern: prefer Service that takes `IRocketStorage` or direct `IRETH` + deposit pool addresses as parameters rather than hardcoding every module.

#### In scope (v1)

- `IRETH` — ERC-20 + `getExchangeRate()`, burn/mint related views used by integrators
- `IRocketDepositPool` (or equivalent) — deposit ETH for rETH when capacity allows
- `RocketPoolService`:
  - deposit ETH → rETH  
  - burn/redeem rETH → ETH when protocol liquidity allows  
  - `previewDeposit` / `previewRedeem` using exchange rate + pool capacity checks  
- Rate provider: `getExchangeRate()` scaled as needed for Balancer
- Fork TestBase

#### Out of scope (v1)

- Full minipool / node operator / RPL staking / oDAO
- Hermetic full Rocket Pool network (unless a minimal rETH mock is added for unit tests)

#### Port layout

```text
staking/ethereum/rocket-pool/
  interfaces/IRETH.sol
  interfaces/IRocketDepositPool.sol
  interfaces/IRocketStorage.sol          # if needed for address resolution
  services/RocketPoolService.sol
  rate/RETHRateProvider.sol
  test/bases/TestBase_RocketPoolFork.sol
  README.md
```

#### Verification

- [ ] Fork: deposit when pool has capacity; assert rETH balance and rate
- [ ] Fork: redeem path when free ETH available; expect graceful revert/code when empty
- [ ] Document deposit-pool-empty behavior for SE previews (`maxDeposit`-style)

#### SE notes

- rETH is value-accruing, not rebasing — good SE reserve.
- Primary redeem is **liquidity-constrained** → SE Out must treat protocol redeem and secondary market as distinct routes; closed-form protocol redeem only when capacity exists.

#### Dedup

- Expand beyond Liquity’s one-line `IRETHToken`; do not break Liquity imports (keep thin interface or alias).

---

### 5.3 ether.fi (`staking/ethereum/etherfi/`)

#### Upstream

| Field | Value |
|-------|--------|
| Repo | `etherfi-protocol/smart-contracts` |
| Key surface | LiquidityPool, eETH, weETH (WeETH wrapper) |
| License | **(verify)** |
| Docs | ether.fi GitBook technical documentation |

#### Mainnet — verify (commonly cited; re-check)

| Contract | Address |
|----------|---------|
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` **(verify)** |

#### In scope (v1)

- Canonical `IEETH`, `IWeETH`, `IEtherFiLiquidityPool` (promote/complete Pendle fragments)
- `EtherFiService`:
  - `deposit` ETH → eETH  
  - `wrap` / `unwrap` eETH ↔ weETH  
  - `depositAndWrap` ETH → weETH  
  - share/amount conversion views from LiquidityPool  
- Rate provider for weETH (eETH per weETH or ETH backing per weETH — match ether.fi / DeFi standard)
- Fork TestBase
- Document restaking/AVS risk in README (EigenLayer dependency)

#### Out of scope (v1)

- Full validator NFT (T-NFT/B-NFT) operator flows
- ether.fi Cash / card products
- Cross-chain weETH LayerZero stack (`weETH-cross-chain`) — optional later
- EigenLayer restake contracts themselves

#### Port layout

```text
staking/ethereum/etherfi/
  interfaces/IEETH.sol
  interfaces/IWeETH.sol
  interfaces/IEtherFiLiquidityPool.sol
  services/EtherFiService.sol
  rate/WeETHRateProvider.sol
  test/bases/TestBase_EtherFiFork.sol
  README.md
```

#### Verification

- [ ] Fork: ETH → eETH → weETH → eETH
- [ ] Rate consistency vs pool total ether / shares
- [ ] Withdrawal/redeem path documentation (instant liquidity vs queue)

#### SE notes

- Mirror Lido: SE reserve = **weETH**, never bare rebasing eETH.
- LRT risk stack is higher than pure LST — flag in SE PRD fee/risk docs.

#### Dedup

- Pendle interfaces stay for now; new Crane code uses `staking/ethereum/etherfi`.

---

### 5.4 StakeWise V3 (`staking/ethereum/stakewise/`)

#### Upstream

| Field | Value |
|-------|--------|
| Repo | `stakewise/v3-core` |
| Architecture | Modular **Vaults** (EthVault, variants) + **osETH** (OsToken) over-collateralized liquid token + controllers |
| License | **(verify)** |

#### Mainnet — verify

| Contract | Role |
|----------|------|
| osETH (OsToken) | Liquid staking token |
| OsTokenVaultController / configs | Mint/burn osETH against vault positions |
| Genesis / partner EthVault instances | Per-vault stake surfaces |
| Vault factory | Permissionless vault deploy |

Pull exact addresses from StakeWise deployments docs at port time.

#### In scope (v1) — two sub-surfaces

**A. osETH liquid token (required)**

- `IOsETH` / `IOsToken` interfaces  
- `StakeWiseOsETHService`: mint/burn osETH against a chosen vault position per protocol rules  
- Rate / share conversion views  
- Fork tests against a known public vault + osETH

**B. EthVault integration (required for multi-instance SE story)**

- `IEthVault` (deposit/redeem stake, fee params)  
- Document which vaults are ERC-4626-compatible vs custom  
- `deploy`-time parameterization: Service takes `vault` address  

#### Out of scope (v1)

- Gnosis `GnoVault`  
- Full operator/oracle network  
- Every specialized vault variant (blocklist/private) — support via interface if ABI-compatible  

#### Port layout

```text
staking/ethereum/stakewise/
  interfaces/IOsETH.sol
  interfaces/IOsTokenVaultController.sol
  interfaces/IEthVault.sol
  interfaces/IVaultFactory.sol          # if needed
  services/StakeWiseService.sol
  rate/OsETHRateProvider.sol
  test/bases/TestBase_StakeWiseFork.sol
  README.md
```

#### Verification

- [ ] Fork: deposit into a public EthVault  
- [ ] Fork: mint osETH (if eligibility/over-collateral rules allow in test account flow)  
- [ ] Document osETH mint limits / health factors  

#### SE notes

- **Best multi-instance port:** `deployVault(ethVault)` style later in IndexedEx if vault shares are 4626.  
- osETH SE is a second product: liquid token over many vaults.  
- Aligns with generic ERC-4626 SE when vault implements 4626.

---

### 5.5 FraxETH completion (`staking/ethereum/frax/` — optional track)

Not in the user-requested four, but **already partially ported**. Track as **P0 for generic ERC-4626 SE validation**.

#### In scope (completion)

```text
staking/ethereum/frax/
  interfaces/          # re-export or thin wrappers of tokens/stable/frax/FraxETH/*
  services/FraxETHService.sol   # submit, submitAndDeposit, sfrxETH deposit/redeem; addresses as args
  rate/SfrxETHRateProvider.sol
  test/bases/TestBase_FraxETHFork.sol
  README.md            # points to tokens/stable/frax for full monorepo
```

#### Explicit non-goals

- Moving the entire `tokens/stable/frax` tree  
- Re-implementing frxETH/sfrxETH bytecode if fork+interfaces suffice  

#### SE notes

- **First hermetic validation target for generic ERC-4626 SE:** `asset = sfrxETH`.  
- ETH→sfrxETH uses `IfrxETHMinter.submitAndDeposit` or MiniRouter logic via Service.

---

## 6. Shared Crane deliverables

### 6.1 `staking/ethereum/README.md`

Index table: protocol, tokens, mainnet addresses, Service entrypoints, fork test commands, SE consumer status.

### 6.2 Rate providers

Reuse Balancer `IRateProvider` pattern already in Crane (`protocols/dexes/balancer/common/interfaces/IRateProvider.sol` and v3 rateProviders). Each LST package ships a minimal rate provider contract or library adapter:

| Token | Rate meaning (typical) |
|-------|------------------------|
| wstETH | stETH per wstETH |
| rETH | ETH per rETH |
| weETH | eETH (or ETH) per weETH |
| osETH | ETH per osETH **(verify)** |
| sfrxETH | frxETH per sfrxETH (4626 `convertToAssets`) |

### 6.3 Interface canonicalization policy

1. New first-class ports own the **canonical** interface paths under `staking/ethereum/<protocol>/`.  
2. Existing Pendle/Liquity/Uni/Euler fragments remain until a dedicated cleanup PR.  
3. Services and IndexedEx SE code **must** import the canonical path only.

### 6.4 Solidity version

Match Crane/IndexedEx foundry (`0.8.35` where possible). When upstream is older (Lido 0.4/0.6), **interfaces** are written in 0.8.x; do not recompile ancient Lido impls unless hermetic stubs need them.

---

## 7. IndexedEx consumer: generic ERC-4626 Standard Exchange (normative requirements)

> Full IndexedEx implementation plan may be a separate file; this section locks **consumer contracts** and **IBasicVault** surface so ports and SE design stay aligned.

### 7.1 Intent

Ship one DFPkg, e.g. `ERC4626StandardExchangeDFPkg` (name TBD), that:

1. Deploys an SE vault instance per `deployVault(IERC4626 protocolVault)` (registry path).  
2. The SE diamond **is** an ERC-4626 share token whose `IERC4626.asset()` is the **protocol ERC-4626 vault** being wrapped (e.g. `sfrxETH`, StataToken, MetaMorpho vault).  
3. Implements `IStandardExchangeIn` / `IStandardExchangeOut` for closed-form routes among the declared vault tokens and the SE share.  
4. Composes `IStandardExchangeProxy` (includes `IBasicVault`, `IStandardVault`, ERC-4626 permit proxy, In/Out).

### 7.2 **IBasicVault declaration (mandatory)**

The generic ERC-4626 SE **must** expose both layers of the wrapped vault through **`IBasicVault.vaultTokens()`** — not only the SE’s own `asset()`.

```text
IBasicVault.vaultTokens()  MUST include at least:

  [0] protocolVault   = the ERC-4626 vault being wrapped
                        (== this SE’s IERC4626.asset())
  [1] underlyingAsset = IERC4626(protocolVault).asset()
                        (the protocol vault’s own asset())

Order: fixed and documented (recommended: protocolVault first, then underlying,
matching DEX SE habit of “reserve / LP first, then constituents”).
```

| Surface | What it returns | Example (`sfrxETH` wrap) |
|---------|-----------------|---------------------------|
| **SE `IERC4626.asset()`** | Protocol ERC-4626 vault | `sfrxETH` |
| **`IBasicVault.vaultTokens()`** | Protocol vault **and** its underlying | `[sfrxETH, frxETH]` |
| **`IBasicVault.reserveOfToken(protocolVault)`** | SE’s tracked reserve of protocol vault shares (typically `lastTotalAssets` / balance of `sfrxETH` held) | balance of `sfrxETH` in SE accounting |
| **`IBasicVault.reserveOfToken(underlying)`** | Usually `0` for a pure wrap SE (underlying is not held at rest); still listed so exchange routes and DETF allowlists can discover it | `0` unless a route parks underlying |

**Why both:**

- DETF / router / registry discovery uses `IBasicVault.vaultTokens()` as the allowlist of tokens the SE will accept/produce for exchanges (see Single SE DETF: mint via `vaultTokens()` allowlist).  
- Listing only the protocol vault hides the underlying and breaks base-asset exchangeIn paths and composition.  
- Listing only the underlying hides the yield token the SE actually holds as reserve.

**Anti-pattern — do not use as-is for this package:**

```solidity
// contracts/vaults/basic/ERC4626BasedBasicVaultFacet.sol (today)
// vaultTokens() returns ONLY ERC4626Repo._reserveAsset()  // single token
```

That facet is insufficient for the generic ERC-4626 SE. The package **must** use multi-asset basic vault accounting (`MultiAssetBasicVaultFacet` / `MultiAssetBasicVaultRepo._initialize(tokens)`) with **both** addresses at init, same pattern as Uni V2 / Camelot / Aerodrome SE (`[reserve, token0, token1]`).

**Init sketch:**

```solidity
// initAccount / postDeploy wiring
IERC4626 protocolVault = IERC4626(args.protocolVault);
address underlying = protocolVault.asset();

// SE ERC-4626 layer: asset = protocol vault
ERC4626Repo._initialize(IERC20(address(protocolVault)), decimals, offset);

// IBasicVault discovery surface: vault + its asset
address[] memory vaultTokens_ = new address[](2);
vaultTokens_[0] = address(protocolVault);
vaultTokens_[1] = underlying;
MultiAssetBasicVaultRepo._initialize(vaultTokens_);
```

**Contents / fee identity:** `contentsId` (and any vault config hash) should be derived from the dual `vaultTokens` set so two SE instances wrapping different 4626s do not collide.

### 7.3 Token role diagram

```text
                    ┌──────────────────────────────────────┐
                    │  IndexedEx SE diamond (share ERC-20) │
                    │  IERC4626.asset() ──► protocolVault  │
                    │  IBasicVault.vaultTokens():           │
                    │    [ protocolVault, underlyingAsset ]│
                    └───────────────┬──────────────────────┘
                                    │ holds
                                    ▼
                    ┌──────────────────────────────────────┐
                    │  protocolVault (IERC4626)            │
                    │  e.g. sfrxETH, StataToken, vault     │
                    │  IERC4626.asset() ──► underlying     │
                    └───────────────┬──────────────────────┘
                                    │
                                    ▼
                    ┌──────────────────────────────────────┐
                    │  underlyingAsset (IERC20)            │
                    │  e.g. frxETH, USDC, WETH, …          │
                    └──────────────────────────────────────┘
```

### 7.4 Exchange routes (v1 minimum)

Given `vaultTokens = [protocolVault, underlying]`:

| Route | Direction | Mechanism |
|-------|-----------|-----------|
| underlying ↔ protocolVault | both | `IERC4626.deposit` / `mint` / `withdraw` / `redeem` on protocol vault |
| protocolVault ↔ SE share | both | SE ERC-4626 deposit/redeem of protocol vault shares |
| underlying ↔ SE share | both | compose: deposit into protocol vault then into SE (and reverse) |

Optional later (via strategy adapters / Crane Services — **not** part of pure 4626 math):

- ETH/WETH → underlying or protocol vault when protocol requires a Service (Lido submit, Frax minter, etc.)

### 7.5 Strategy adapter hook (protocol-specific legs beyond pure 4626)

When `underlying` is not the user’s starting asset (e.g. user holds ETH, protocol vault asset is frxETH or stETH path):

```text
IERC4626YieldExchangeAdapter {
  function baseToken() external view returns (address);
  function underlyingAsset() external view returns (address);  // IERC4626(protocolVault).asset()
  function protocolVault() external view returns (address);    // the ERC-4626
  function previewBaseToUnderlying(uint256) external view returns (uint256);
  function convertBaseToUnderlying(uint256, address receiver) external returns (uint256);
  // …
}
```

Adapters call Crane `*Service` libraries. Pure 4626 SE works without an adapter when the user already holds `underlying` or `protocolVault`.

| Protocol vault | `vaultTokens` example | Adapter for ETH path |
|----------------|----------------------|----------------------|
| sfrxETH | `[sfrxETH, frxETH]` | `FraxETHService` (ETH→frxETH) |
| Stata (WETH) | `[stataWeth, WETH]` | none if user has WETH |
| Lido path* | N/A until 4626 wrapper, or separate LST SE | `LidoService` |

\*Non-4626 LSTs (wstETH, rETH, weETH) still need a protocol-aware SE or a 4626 adapter vault; they do **not** fit the pure generic package unless wrapped.

### 7.6 Relation to Aave Stata SE

Aave Stata SE is a **specialized** multi-layer route set (base / aToken / stata) with marker + reward sweep. Generic ERC-4626 SE is the **simplified dual-token** pattern (`protocolVault` + `underlying` via `IBasicVault`). Do not merge packages; share ERC-4626 facets/repos and multi-asset basic vault wiring. Stata may later be deployable through the generic package **if** only underlying+stata discovery is required and aToken routes stay Stata-specific.

### 7.7 Tests that lock the IBasicVault rule

- [ ] After deploy, `vaultTokens().length == 2`  
- [ ] `vaultTokens()` contains `address(protocolVault)` and `IERC4626(protocolVault).asset()`  
- [ ] `SE.asset() == protocolVault`  
- [ ] `reserveOfToken(protocolVault)` tracks SE inventory of protocol vault shares  
- [ ] DETF / allowlist consumer can discover both tokens without reading private config  
- [ ] ExchangeIn underlying → SE share and protocolVault → SE share both succeed with preview == execution (modulo documented fee)

---

## 8. Phased execution plan

### Phase 0 — Scaffold (0.5–1 day)

- [ ] `staking/ethereum/README.md`  
- [ ] Directory scaffold for `lido`, `rocket-pool`, `etherfi`, `stakewise`, `frax`  
- [ ] Document canonical addresses table (verified)  
- [ ] Decision record: hermetic stubs vs fork-only per protocol (default: fork-only + optional minimal ERC20 mocks)

### Phase 1 — FraxETH Service completion + generic SE spike (IndexedEx + Crane)

- [ ] `FraxETHService` + fork TestBase under `staking/ethereum/frax/`  
- [ ] Validate **generic ERC-4626 SE** against live `sfrxETH` (IndexedEx)  
- [ ] Rate provider smoke test  

**Why first:** already have interfaces + MiniRouter + sfrxETH is true ERC-4626.

### Phase 2 — Lido port (Crane P0)

- [ ] Canonical interfaces + `LidoService` + rate provider  
- [ ] Fork tests  
- [ ] Wire Lido adapter into generic SE for ETH→wstETH→shares  

### Phase 3 — Rocket Pool port

- [ ] Interfaces + Service + fork tests  
- [ ] Capacity-aware previews  
- [ ] SE adapter  

### Phase 4 — ether.fi port

- [ ] Promote Pendle interfaces → canonical  
- [ ] Service + weETH rate + fork tests  
- [ ] SE adapter (LRT risk docs)  

### Phase 5 — StakeWise port

- [ ] Vault + osETH interfaces  
- [ ] Service + fork tests against public vault  
- [ ] SE adapter(s): vault share and/or osETH  

### Phase 6 — Cleanup

- [ ] Optional import re-point from Pendle/Liquity to canonical interfaces  
- [ ] Update `DEFI_PORTING_PRD.md` C.2 path  
- [ ] CODEBASE_MAP / Crane inventory  
- [ ] Cross-link staking research assessment doc  

---

## 9. Definition of done (per protocol)

A protocol port is **done** when:

1. Layout under `staking/ethereum/<protocol>/` with README and verified addresses.  
2. Canonical interfaces cover all functions the Service and SE adapter need.  
3. `*Service` library implements deposit/mint/wrap/unwrap (as applicable) with preview helpers.  
4. Rate provider or documented rate view for Balancer/SE pricing.  
5. Fork tests pass against Ethereum mainnet RPC for happy paths + one liquidity-constrained path where relevant.  
6. No new submodule; `@crane/` imports only; solc matches project.  
7. IndexedEx can call Service from a draft adapter without forking protocol internals.  
8. NatSpec on public Service entrypoints.

---

## 10. Risks and constraints

| Risk | Mitigation |
|------|------------|
| Rebasing tokens break ERC-4626/SE accounting | Ban stETH/eETH as SE `asset()`; use wstETH/weETH |
| Upgradeable proxies (Lido, ether.fi) | Fork tests; pin interface; don’t assume immutability |
| Deposit pool empty (Rocket Pool) | Preview max; SE route split |
| Restaking slashing (ether.fi) | Document; separate risk class from pure LST |
| StakeWise vault heterogeneity | Parameterize vault address; don’t assume one global pool |
| License (GPL) | Record per package; distribution already mixes GPL ports |
| Interface drift / duplicate IWstETH | Canonical path + gradual dedup |
| Over-scoping full DAOs | Stick to token + mint/wrap/redeem surface |

---

## 11. Task breakdown (suggested)

| ID | Task | Depends |
|----|------|---------|
| STK-ETH-0 | Scaffold dirs + README + address verify | — |
| STK-ETH-1 | FraxETHService + fork base | STK-ETH-0 |
| STK-ETH-2 | IndexedEx generic ERC-4626 SE spike on sfrxETH | STK-ETH-1 |
| STK-ETH-3 | Lido interfaces + LidoService + fork | STK-ETH-0 |
| STK-ETH-4 | Lido SE adapter | STK-ETH-2, STK-ETH-3 |
| STK-ETH-5 | Rocket Pool port | STK-ETH-0 |
| STK-ETH-6 | Rocket Pool SE adapter | STK-ETH-2, STK-ETH-5 |
| STK-ETH-7 | ether.fi port | STK-ETH-0 |
| STK-ETH-8 | ether.fi SE adapter | STK-ETH-2, STK-ETH-7 |
| STK-ETH-9 | StakeWise port | STK-ETH-0 |
| STK-ETH-10 | StakeWise SE adapter | STK-ETH-2, STK-ETH-9 |
| STK-ETH-11 | Dedup + DEFI_PORTING_PRD path update | ports green |

---

## 12. Acceptance criteria (program)

- [ ] Four requested protocols (Lido, Rocket Pool, ether.fi, StakeWise) have Crane ports under `staking/ethereum/<name>/`.  
- [ ] FraxETH status documented; Service completion optional but recommended before multi-protocol SE launch.  
- [ ] No reliance on Pendle-local interfaces for new IndexedEx code.  
- [ ] Generic ERC-4626 / yield-token SE can be demonstrated on at least **sfrxETH** and **one non-4626 LST** (wstETH or rETH) via adapter.  
- [ ] Production-first: fork tests use real mainnet contracts; no mocks of protocol SUT in lifecycle tests.  

---

## 13. Appendix A — FraxETH file map (as of 2026-07-21)

```text
lib/crane/contracts/protocols/tokens/stable/frax/
  FraxETH/
    IfrxETH.sol
    IfrxETHMinter.sol
    IsfrxETH.sol          # ERC-4626 surface
    FrxETHMiniRouter.sol  # mainnet-hardcoded helper
  ERC20/
    wfrxETH.sol           # Fraxchain wrap (different product)
    IwfrxETH.sol
  Curve/
    ICurvefrxETHETHPool.sol
```

**Missing for full port:** frxETH/sfrxETH/minter implementations, parameterized Service, staking/ethereum home, hermetic TestBase.

---

## 14. Appendix B — Existing Lido/ether.fi/rETH fragments (do not treat as ports)

```text
perps/pendle/interfaces/IStETH.sol
perps/pendle/interfaces/IWstETH.sol
perps/pendle/interfaces/EtherFi/*
lending/euler/v1/oracle/adapter/lido/*
cdps/liquity/v2/bold/Interfaces/IWSTETH.sol
cdps/liquity/v2/bold/Interfaces/IRETHToken.sol
dexes/uniswap/v4/**/IWstETH.sol
```

---

## 15. Changelog

| Date | Change |
|------|--------|
| 2026-07-21 | Initial PRD: Crane staking/ethereum ports for Lido, Rocket Pool, ether.fi, StakeWise; FraxETH inventory; generic ERC-4626 SE consumer outline |
| 2026-07-21 | **IBasicVault rule:** generic ERC-4626 SE must declare both `protocolVault` and `IERC4626(protocolVault).asset()` via `vaultTokens()`; do not use single-token `ERC4626BasedBasicVaultFacet` alone |

---

*Implementation should start with Phase 0–1 (Frax Service + generic SE spike), then Lido as the first non-4626 LST port.*

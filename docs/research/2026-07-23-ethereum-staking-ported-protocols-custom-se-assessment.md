# Ported Ethereum Staking Protocols — Custom vs Generic ERC-4626 SE Assessment

**Date:** 2026-07-23  
**Status:** Research reference  
**Scope:** Protocols already ported under Crane  
`lib/crane/contracts/protocols/staking/ethereum/`  
**Audience:** IndexedEx engineering planning for Standard Exchange vault packages  

**Related docs:**
- [`2026-07-21-ethereum-staking-protocols-se-vault-assessment.md`](./2026-07-21-ethereum-staking-protocols-se-vault-assessment.md) — market / SE viability catalog
- [`2026-07-21-ethereum-staking-protocol-ports-PRD.md`](./2026-07-21-ethereum-staking-protocol-ports-PRD.md) — Crane port + ERC-4626 SE adapter path
- [`2026-07-21-ethereum-staking-ports-IMPLEMENTATION_PLAN.md`](./2026-07-21-ethereum-staking-ports-IMPLEMENTATION_PLAN.md) — D2-FULL vendor + SE workplan
- Aave Stata SE gold path: `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`
- Generic ERC-4626 SE: `contracts/vaults/standard/erc4626/`
- Fork proof (sfrxETH): `test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol`

---

## 1. Executive summary

Among the five staking protocols ported into Crane under `staking/ethereum/`, **only Frax (`sfrxETH`) is a drop-in for the generic ERC-4626 Standard Exchange vault**. The other four require **protocol-specific Standard Exchange packages** because their mint/wrap/redeem surfaces are not IERC4626.

| Protocol | Preferred SE reserve | IERC4626? | Generic ERC4626 SE | Custom SE needed? |
|----------|----------------------|-----------|--------------------|-------------------|
| **Frax** | `sfrxETH` | **Yes** (`asset() = frxETH`) | **Yes** | Only if ETH→frxETH→sfrxETH must live *inside* the SE |
| **Lido** | `wstETH` | No (wrap/unwrap + rebasing `stETH`) | No | **Yes** |
| **Rocket Pool** | `rETH` | No (deposit pool + `burn` / rate token) | No | **Yes** |
| **ether.fi** | `weETH` | No (deposit + rebasing `eETH` wrap) | No | **Yes** |
| **StakeWise** | vault shares and/or `osETH` | No (4626-**like**, not IERC4626) | No | **Yes** |

**Bottom line:** **4 custom SE packages** for full protocol integration; **1 protocol (Frax/sfrxETH)** uses stock `ERC4626StandardExchange`.

**Easiest SE wrapper:** **Frax** (generic ERC4626 SE; largely already done). **Easiest custom SE:** **Rocket Pool (`rETH`)**. See §6.

---

## 2. Ported tree inventory

```text
lib/crane/contracts/protocols/staking/ethereum/
  common/          # shared helpers / rate interface
  frax/            # frxETH, sfrxETH — thin Service + rate
  lido/            # stETH, wstETH
  rocket-pool/     # rETH
  etherfi/         # eETH, weETH
  stakewise/       # EthVault shares, osETH
```

| Dir | Tokens | Service | Rate helper |
|-----|--------|---------|-------------|
| `frax/` | frxETH, sfrxETH | `FraxETHService` | `SfrxETHRateProvider` |
| `lido/` | stETH, wstETH | `LidoService` | `WstETHRateProvider` |
| `rocket-pool/` | rETH | `RocketPoolService` | `RETHRateProvider` |
| `etherfi/` | eETH, weETH | `EtherFiService` | `WeETHRateProvider` |
| `stakewise/` | EthVault shares, osETH | `StakeWiseService` | `OsETHRateProvider` |

Mainnet addresses (verify at use): see `lib/crane/contracts/protocols/staking/ethereum/README.md`.

---

## 3. What the generic ERC-4626 SE actually supports

**Package:** `contracts/vaults/standard/erc4626/`  
**Marker:** `IERC4626StandardExchange.protocolVault() → IERC4626`  
**Deploy:** `deployVault(IERC4626 protocolVault)` via vault registry

`ERC4626StandardExchangeInTarget` only routes:

```text
protocolVault.asset()  ↔  protocolVault (IERC4626)  ↔  SE shares
```

It calls standard:

- `deposit(assets, receiver)`
- `redeem(shares, receiver, owner)`
- `previewDeposit` / `previewRedeem`

It does **not** handle:

- native `payable` mint (`submit`, deposit pools)
- rebasing ↔ wrap (`stETH`/`eETH` ↔ `wstETH`/`weETH`)
- deposit-pool capacity / `burn`
- async exit queues (`enterExitQueue`)
- controller-gated mint/burn (`osETH`)

Therefore a protocol is a **generic SE candidate only if** it exposes a true **IERC4626** yield token that integrators can deposit/redeem with those signatures.

---

## 4. Per-protocol assessment

### 4.1 Frax — generic ERC4626 SE (no custom SE required for core)

| Field | Detail |
|-------|--------|
| **Surface** | `FraxETHService` — minter `submit` / `submitAndDeposit`, full `sfrxETH` ERC-4626 deposit/redeem/previews |
| **Yield token** | `sfrxETH` — real IERC4626 over `frxETH` (`IsfrxETH`) |
| **Generic SE** | `deployVault(sfrxETH)` → SE reserve = sfrxETH; legs = frxETH + sfrxETH + SE share |
| **Covered routes** | frxETH ↔ sfrxETH ↔ SE shares |
| **Not covered** | ETH/WETH → frxETH minter path |

**Recommendation:** integrate via **generic ERC4626 SE** first (fork proof already exists). A **custom** Frax SE is optional later only if product requires ETH-primary multi-layer routes inside one diamond (Aave-Stata-style: ETH/WETH/frxETH/sfrxETH/SE).

**Evidence:** `test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol`.

---

### 4.2 Lido — custom SE required

| Field | Detail |
|-------|--------|
| **stETH** | Rebasing ERC-20; `submit(referral) payable` — not ERC4626 |
| **wstETH** | Wrap/unwrap only (`IWstETH`) — **not** ERC4626 (no `asset`/`deposit`/`redeem`) |
| **Crane surface** | `LidoService` submit + wrap/unwrap + rate via `stEthPerToken` |

**Custom SE shape (Aave Stata–class multi-layer):**

| Layer | Token |
|-------|--------|
| Base | ETH / WETH |
| Intermediate | stETH (rebasing) |
| Preferred reserve / SE `asset()` | **wstETH** (non-rebasing) |
| SE share | IndexedEx vault ERC-20 / ERC-4626 |

**Must implement:** ETH→stETH→wstETH compose, wrap/unwrap legs, SE mint/burn, and explicit policy for **withdrawal queue vs secondary-market exit** (closed-form only; reject non-closed-form exact-out solvers).

**Do not** use raw rebasing stETH as vault reserve asset (share accounting / Balancer rate footguns).

---

### 4.3 Rocket Pool — custom SE required

| Field | Detail |
|-------|--------|
| **rETH** | Value-accruing ERC-20: `getExchangeRate` / `getEthValue` / `getRethValue` + `burn` — **not** IERC4626 |
| **Mint** | `RocketDepositPool.deposit{value}` with capacity (`getMaximumDepositAmount`) |
| **Crane surface** | `RocketPoolService` deposit / burn / rate |

**Custom SE shape:**

| Layer | Token |
|-------|--------|
| Base | ETH / WETH |
| Reserve | **rETH** |
| SE share | IndexedEx vault |

**Routes:** ETH↔rETH (deposit pool + burn/liquidity), rETH↔SE shares.  
**Previews** must respect **deposit pool capacity** (mint can fail when pool is full).

A thin Crane/IndexedEx 4626 adapter over rETH would be a separate product; it is not the protocol’s native surface and does not unlock generic SE without that extra layer.

---

### 4.4 ether.fi — custom SE required

| Field | Detail |
|-------|--------|
| **eETH** | Rebasing share token — not ERC4626 |
| **weETH** | Wrap/unwrap + `getRate` — **not** ERC4626 (same shape as wstETH) |
| **Mint** | `LiquidityPool.deposit{value}` → eETH → wrap weETH |
| **Crane surface** | `EtherFiService` deposit / wrap / unwrap / rate |

**Custom SE shape:** mirror **Lido** package:

| Layer | Token |
|-------|--------|
| Base | ETH / WETH |
| Intermediate | eETH |
| Preferred reserve | **weETH** |
| SE share | IndexedEx vault |

Mechanics are wrap + deposit (not 4626). Document restaking / AVS risk separately from pure LST packages; do not conflate with Lido SE.

---

### 4.5 StakeWise V3 — custom SE required

Two products; neither is stock IERC4626.

#### A. EthVault shares

Crane `IEthVault` is **4626-like** (`convertToShares` / `convertToAssets` / `redeem`) but **not** IERC4626:

- `deposit(receiver, referrer) payable` — native ETH, not `deposit(assets, receiver)` on an ERC-20 `asset()`
- `redeem(shares, receiver)` — not `(shares, receiver, owner)`
- No `asset()` on the integration interface
- Async exit: `enterExitQueue` (not always instant redeem)

Generic ERC4626 SE **cannot** call this API.

#### B. osETH

- Controller-gated mint/burn (`IOsETH` / `IOsTokenVaultController`)
- Rate via `convertToAssets(1e18)` on the controller
- Not an IERC4626 vault users deposit into via standard 4626

**Custom SE options:**

1. **StakeWise EthVault SE** — `deployVault(ethVault)` with payable deposit + redeem / exit-queue policy  
2. **osETH SE** — mint/burn against vault positions via controller paths  
3. Both packages if product needs both share types

Multi-instance vault marketplace maps well to IndexedEx `deployVault` matrix (similar spirit to per-asset Stata deploy).

---

## 5. Integration architecture

```text
                    ┌──────────────────────────────────────┐
  frxETH already    │ Generic ERC4626StandardExchangeDFPkg │  ← Frax sfrxETH only (today)
  held              └──────────────────────────────────────┘

                    ┌──────────────────────────────────────┐
  protocol mint /   │ Custom Standard Exchange packages    │
  wrap / queue     │  • LidoWstETH SE                      │
  / deposit pool    │  • RocketPoolRETH SE                  │
                    │  • EtherFiWeETH SE                    │
                    │  • StakeWiseEthVault SE (± osETH SE)  │
                    └──────────────────────────────────────┘
                              │
                              ▼
                    IStandardExchange (opaque to DETF / Balancer SE router)
```

DETF production code must remain **opaque** to concrete Lido/Rocket/ether.fi types — only `IStandardExchange*`.

---

## 6. Easiest protocol for SE wrapper implementation

### 6.1 Easiest overall: Frax (`sfrxETH`)

Frax is easiest by a wide margin — and for a different reason than the others: you largely **do not implement a new SE package**. Use the existing generic:

```text
contracts/vaults/standard/erc4626/  →  deployVault(sfrxETH)
```

| Why it’s easiest | Detail |
|------------------|--------|
| True IERC4626 | `sfrxETH.asset() = frxETH`; standard deposit/redeem/previews |
| Generic routes already written | frxETH ↔ sfrxETH ↔ SE shares |
| Fork path already exists | `ERC4626StandardExchange_SfrxETH_Fork.t.sol` |
| Crane surface is thin | `FraxETHService` is enough for minter if ETH→frxETH stays off-vault |

**Catch:** full ETH→frxETH→sfrxETH *inside* the vault is extra work. For “SE wrapper around the staking yield token,” Frax is already done in shape.

### 6.2 Easiest custom SE package: Rocket Pool (`rETH`)

Among the four protocols that need protocol-specific code, **Rocket Pool** is the simplest custom package:

| vs others | Rocket Pool advantage |
|-----------|------------------------|
| **Lido / ether.fi** | No rebasing intermediate + wrap leg — one rate token |
| **StakeWise** | No multi-vault marketplace, no osETH controller mint, no `enterExitQueue` as core v1 surface |
| Routes | ETH/WETH ↔ rETH ↔ SE shares only |

**Catch:** deposit-pool capacity and liquidity-dependent redeem/burn — previews and capacity checks are real, but still fewer layers than dual-token LST/LRT packages.

### 6.3 Implementation difficulty ladder

| Rank | Protocol | SE approach | Difficulty |
|-----:|----------|-------------|------------|
| 1 | **Frax** | Generic ERC4626 SE | Lowest (mostly wire + tests) |
| 2 | **Rocket Pool** | Custom, single-token | Lowest **custom** |
| 3 | **Lido** | Custom, wrap dual-token | Medium (gold pattern for wrap-style) |
| 4 | **ether.fi** | Custom, Lido-shaped + LRT risk | Medium–high |
| 5 | **StakeWise** | Custom vault and/or osETH | Highest in this set |

### 6.4 Practical recommendation

| Goal | Start with |
|------|------------|
| Prove IndexedEx integration end-to-end today | **Frax** (generic ERC4626 SE) |
| First **custom** SE template for non-4626 LSTs | **Rocket Pool** |
| Strategic gold for wrap-style dual-token LSTs | **Lido** (after or in parallel once single-token custom is green) |

**Note:** Difficulty order is **not** the same as strategic TVL priority. Lido is harder than Rocket Pool but remains the highest-leverage custom package for DeFi depth.

---

## 7. Suggested build order

Two complementary sequences:

### 7.1 Difficulty / learning sequence (implementation risk first)

| Order | Package | Rationale |
|------:|---------|-----------|
| 1 | **Frax via generic ERC4626 SE** | Already scaffolded / fork-tested; lowest risk |
| 2 | **Rocket Pool rETH custom SE** | Simplest custom surface (single rate token) |
| 3 | **Lido wstETH custom SE** | Dual-token wrap pattern becomes gold for wrap-style LSTs |
| 4 | **ether.fi weETH custom SE** | Lido-shaped mechanics + LRT risk surface |
| 5 | **StakeWise custom SE** | Multi-instance vault marketplace + optional osETH |

### 7.2 Strategic / TVL sequence (product impact first)

| Order | Package | Rationale |
|------:|---------|-----------|
| 1 | **Frax via generic ERC4626 SE** | Unblock 4626 path with minimal new code |
| 2 | **Lido wstETH custom SE** | Largest LST; deepest DeFi integrations |
| 3 | **Rocket Pool rETH custom SE** | Decentralized LST; multi-vault DETF diversification |
| 4 | **ether.fi weETH custom SE** | Dominant LRT |
| 5 | **StakeWise custom SE** | Vault marketplace + osETH |

Optional later: **Frax custom multi-layer SE** only if ETH-primary mint must live in-vault (not required to “integrate sfrxETH as a yield leg”).

**Default for agents:** prefer **§7.1** when the goal is shipping a working custom SE template with least rework; prefer **§7.2** when product prioritizes Lido distribution over learning curve.

---

## 8. Package naming sketch (when implementation starts)

Follow IndexedEx conventions (protocol names at integration boundary; no brand leakage into generic DETF surfaces):

```text
contracts/protocols/staking/   # or parallel to protocols/lending/aave
  lido/
    LidoWstETH_Component_FactoryService.sol
    LidoWstETHStandardExchangeDFPkg.sol
    LidoWstETHStandardExchangeInFacet.sol
    LidoWstETHStandardExchangeOutFacet.sol
    LidoWstETHMarkerFacet.sol
    TestBase_LidoWstETHStandardExchange.sol
  rocketpool/
    RocketPoolRETHStandardExchange...
  etherfi/
    EtherFiWeETHStandardExchange...
  stakewise/
    StakeWiseEthVaultStandardExchange...
    # optional: StakeWiseOsETHStandardExchange...
```

Frax core path stays on **generic** `contracts/vaults/standard/erc4626/` until a multi-layer package is justified.

Each custom package should expose a **marker interface** whose interface ID keys Vault Fee Oracle usage fees (Aave Stata pattern). Default production fee may be 0 for pure wrap strategies.

---

## 9. Design notes shared by all staking SEs

### Preferred reserve tokens (non-rebasing)

| Protocol | Prefer as SE reserve | Avoid as naked reserve |
|----------|----------------------|------------------------|
| Lido | wstETH | stETH (rebasing) |
| ether.fi | weETH | eETH (rebasing) |
| Rocket Pool | rETH | — |
| Frax | sfrxETH | — (frxETH is intermediate) |
| StakeWise | vault shares or osETH (product choice) | — |

### Route taxonomy (custom packages)

**Must-have (v1):**

- WETH / ETH ↔ yield token  
- yield token ↔ SE vault share  
- WETH / ETH ↔ SE vault share (compose)

**Should-have when protocol has intermediate:**

- rebasing ↔ wrapped (stETH ↔ wstETH, eETH ↔ weETH)  
- frxETH ↔ sfrxETH (if Frax multi-layer custom ships)

**Out of scope / reject:**

- Exact-out solvers against exit queues — prefer `InvalidRoute`  
- Nested LST↔LRT restake paths inside pure LST SE (separate LRT package)

### Testing (production-first)

- Real protocol contracts via Ethereum mainnet fork and/or Crane ports  
- Do **not** mock Lido/Rocket Pool/ether.fi/StakeWise as SUT dependencies for lifecycle  
- Cover: deposit mint, redeem, preview==execution where protocol allows, fee share mint, rate movement, withdrawal queue / capacity edges, reentrancy on share token if relevant  
- Gold TestBase chain: `CraneTest` → `IndexedexTest` → vault components → protocol SE TestBase

---

## 10. Risks (staking SE class)

1. Consensus / slashing — LST exchange rate can drop  
2. Smart contract / governance — upgradeable staking protocols  
3. Liquidity & depeg — secondary market LST/LRT vs ETH  
4. Withdrawal queue — primary redeem latency; SE Out may need secondary route with slippage  
5. Restaking / AVS risk (LRTs, ether.fi)  
6. Rebasing accounting bugs — prefer wrappers as reserve  
7. Rate provider stale / misconfig on Balancer legs  

---

## 11. Decision log

| Date | Decision |
|------|----------|
| 2026-07-23 | Reviewed Crane ports under `staking/ethereum/{frax,lido,rocket-pool,etherfi,stakewise}` against generic `ERC4626StandardExchange` API surface |
| 2026-07-23 | **Only Frax `sfrxETH`** qualifies for generic ERC4626 SE without a protocol-specific package |
| 2026-07-23 | **Lido, Rocket Pool, ether.fi, StakeWise** require custom Standard Exchange vaults for IndexedEx integration |
| 2026-07-23 | Frax ETH-primary multi-layer SE deferred as optional; not required for sfrxETH yield-leg integration |
| 2026-07-23 | **Easiest overall SE wrapper:** Frax via generic ERC4626 SE. **Easiest custom SE:** Rocket Pool (`rETH`). Difficulty ladder and dual build-order sequences recorded in §6–§7 |

---

## 12. Changelog

| Date | Change |
|------|--------|
| 2026-07-23 | Initial memo: custom vs generic SE classification for ported Ethereum staking protocols |
| 2026-07-23 | Added §6 easiest-wrapper analysis; split build order into difficulty vs strategic sequences (§7) |

---

*Internal research reference. Re-verify mainnet interfaces and addresses before implementation kickoff. Expand into per-protocol PRD + implementation plans (mirror Aave Stata SE plan) when build starts.*

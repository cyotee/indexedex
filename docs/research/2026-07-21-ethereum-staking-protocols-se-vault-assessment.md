# Ethereum Staking Protocols — Standard Exchange Vault Assessment

**Date:** 2026-07-21  
**Purpose:** Catalog Ethereum staking / liquid staking / restaking protocols and assess viability for IndexedEx **Standard Exchange (SE)** strategy vaults.  
**Audience:** Product + engineering planning for new SE packages under `contracts/protocols/` (parallel to Aave Stata SE and DEX SEs).  
**Primary data sources:** DeFiLlama (Liquid Staking / Liquid Restaking / Restaking category pages), protocol docs, public technical overviews. TVL figures are approximate snapshots as of research date and will drift.

---

## 1. Executive summary

### What “staking protocol” means here

Ethereum staking is not one product class. For SE vault planning, treat four layers:

| Layer | What it is | User-facing token pattern | SE vault relevance |
|-------|------------|---------------------------|--------------------|
| **A. Beacon / native staking** | 32 ETH validators, solo or SaaS operators | No standard liquid ERC-20; withdrawals via consensus | Poor direct SE target (async, operator-bound) |
| **B. Liquid staking (LST)** | Pooled ETH → tradeable claim on staked ETH + rewards | `stETH`/`wstETH`, `rETH`, `osETH`, `sfrxETH`, `mETH`, `cbETH`, `wBETH`, … | **Primary SE target** |
| **C. Restaking base** | Shared security markets (EigenLayer / Symbiotic / …) | Positions, not always a simple LST | Infrastructure; usually via LRT wrappers |
| **D. Liquid restaking (LRT)** | LST or ETH restaked; liquid claim on restaked position | `eETH`/`weETH`, `rsETH`, `ezETH`, `pufETH`, `rswETH`, … | Strong SE target with extra risk surface |

### IndexedEx SE vault fit (criteria)

A staking protocol is **viable for an SE vault** if it can map cleanly onto the same product shape as existing SEs (especially **Aave v3 Stata SE**):

1. **Programmatic mint/redeem** of a yield-bearing ERC-20 (or trivial wrap to one) from smart contracts.
2. **Stable route set** expressible as `IStandardExchangeIn` / `IStandardExchangeOut` (ETH/WETH ↔ LST ↔ SE shares).
3. **Previewable rates** (exchange rate / ERC-4626 `convertToAssets` / protocol rate providers).
4. **Composable reserve asset** usable in Balancer V3 buffers/pools and as a DETF SE leg (`IStandardExchange` opacity).
5. **Deploy path** compatible with CREATE3 + vault registry (`deployVault(asset)` style).
6. **Non-custodial or sufficiently trust-minimized** for DeFi strategy use (or explicitly accept CEX-issuer risk).
7. **Liquidity / secondary market** deep enough that forced exits and rate-provider oracles are sane.

**Not required for v1:** perfect ERC-4626 on the LST itself (we can wrap, as Aave Stata shows); synchronous always-on primary redeem (queues can be handled with explicit route design or secondary-market routes).

### Recommended priority (SE vault build order)

| Priority | Protocol(s) | Why |
|----------|-------------|-----|
| **P0** | **Lido** (`stETH` / `wstETH`) | Dominant TVL, deepest DeFi integrations, clear wrap pattern, rate providers everywhere |
| **P0** | **Rocket Pool** (`rETH`) | Decentralized, value-accruing, mature deposit/redeem, strong DeFi support |
| **P1** | **Frax Ether** (`frxETH` / `sfrxETH`) | `sfrxETH` is already ERC-4626 — closest to Aave Stata SE shape |
| **P1** | **ether.fi** (`eETH` / `weETH`) | Largest LRT; rebasing + wrap pattern mirrors Lido; high DETF demand |
| **P1** | **StakeWise V3** (`osETH` + vaults) | Modular vault marketplace; good multi-instance `deployVault` story |
| **P2** | **mETH (Mantle)**, **Stader ETHx**, **Swell** (`swETH`/`rswETH`) | Solid mid-tier LSTs/LRTs; useful matrix rows |
| **P2** | **Kelp** (`rsETH`), **Renzo** (`ezETH`), **Puffer** | LRT diversification after ether.fi |
| **P3** | **cbETH**, **wBETH** | Large TVL but CEX-issuer / permissioned mint-redeem friction |
| **Defer / special** | EigenLayer / Symbiotic **base** positions | Better as infrastructure behind LRTs than first-class SE assets |
| **Out of scope (v1)** | Pure SaaS staking (Figment, Kiln, etc.) without a liquid ERC-20 | No standard SE share surface |

---

## 2. Market snapshot (approx. 2026-07-21)

Sources: [DeFiLlama Liquid Staking (Ethereum)](https://defillama.com/protocols/liquid-staking/ethereum), [Liquid Restaking](https://defillama.com/protocols/liquid-restaking), [Restaking](https://defillama.com/protocols/restaking).

### Liquid staking on Ethereum (selected)

| Protocol | Approx. TVL | Token(s) | Notes |
|----------|------------:|----------|-------|
| Lido | ~$17.9B | stETH, wstETH | Clear market leader |
| Binance staked ETH | ~$6.8B | wBETH (and related) | CEX liquid staking |
| Rocket Pool | ~$1.0B | rETH | Permissionless node operators |
| StakeWise V2 (listing) | ~$0.74B | osETH ecosystem | V3 vault model in production |
| Liquid Collective | ~$0.62B | LsETH | Institutional / permissioned |
| mETH Protocol | ~$0.50B | mETH | Mantle ecosystem |
| Coinbase Wrapped Staked ETH | ~$0.35B | cbETH | CEX liquid staking |
| Stader | ~$0.19B | ETHx | Multi-chain LSD brand |
| Frax Ether | ~$0.10B | frxETH, sfrxETH | Dual-token + ERC-4626 vault |
| stake.link liquid | ~$63M | (link-related liquid stake) | Smaller |
| Swell Liquid Staking | ~$27M | swETH | Also has LRT product |
| Ankr | ~$17M | ankrETH | Multi-chain |
| Others | &lt;$20M each | various | Long tail |

**Ethereum liquid staking category TVL:** ~$28.4B.

### Liquid restaking (selected)

| Protocol | Approx. TVL | Token(s) | Notes |
|----------|------------:|----------|-------|
| ether.fi Stake | ~$3.2B | eETH, weETH | Dominant LRT |
| Kelp | ~$0.97B | rsETH | EigenLayer LRT |
| Renzo | ~$96M | ezETH | Multi-chain LRT |
| Puffer Stake | ~$47M | pufETH | Native restaking + anti-slashing narrative |
| Mantle Restaking | ~$36M | cmETH / related | Mantle stack |
| Swell Liquid Restaking | ~$24M | rswETH | Restaked swETH |
| Mellow Restaking | ~$22M | vault LRTs | Curated restaking vaults |
| Bedrock uniETH | ~$20M | uniETH | Smaller LRT |

**Liquid restaking category TVL:** ~$4.4B.

### Restaking bases (infrastructure, not LSTs)

| Protocol | Approx. TVL | Role |
|----------|------------:|------|
| EigenCloud (EigenLayer) | ~$5.2B | Primary ETH restaking marketplace (AVSs) |
| Babylon | ~$3.4B | Bitcoin staking / restaking (not ETH LST) |
| Symbiotic | ~$0.34B | Multi-asset shared security |

---

## 3. SE vault design notes for staking protocols

### 3.1 Gold reference: Aave Stata SE

IndexedEx already ships a **non-DEX** SE for yield-bearing ERC-4626s:

- Path: `contracts/protocols/lending/aave/v3.6/`
- Pattern: SE share is ERC-4626 whose `asset()` is the protocol yield token (StataToken); rich In/Out routes between base ↔ intermediate ↔ yield token ↔ SE share.
- Staking LSTs map to the same idea with layers:

```text
ETH / WETH  ↔  [optional intermediate: stETH / frxETH / eETH]
            ↔  yield token (wstETH / sfrxETH / weETH / rETH / …)
            ↔  IndexedEx SE vault share
```

### 3.2 Token mechanics that drive implementation shape

| Mechanic | Examples | SE implications |
|----------|----------|-----------------|
| **Rebasing** | stETH, eETH | Prefer **wrapped non-rebasing** form as vault `asset()` (`wstETH`, `weETH`) to avoid share accounting bugs and Balancer rate issues |
| **Value-accruing (rate grows)** | rETH, wstETH, weETH, sfrxETH, osETH, mETH, cbETH | Natural ERC-4626-like rate; ideal for previews + Balancer rate providers |
| **Dual token (stable peg + vault)** | frxETH + sfrxETH | Routes need ETH↔frxETH↔sfrxETH; `sfrxETH` is already ERC-4626 |
| **Primary redeem queue** | Most LSTs/LRTs | SE Out may use: (1) protocol withdraw request, (2) DEX swap to ETH, or (3) both as separate routes; document which is exact-in closed form |
| **Secondary market only exit** | Some CEX LSTs under stress | Weak SE Out fidelity; may mark `InvalidRoute` for protocol redeem and only support wrap/unwrap + secondary via router |

### 3.3 Route taxonomy (recommended for staking SE packages)

**Must-have (v1):**

- `WETH` / `ETH` ↔ yield token  
- yield token ↔ SE vault share  
- `WETH` / `ETH` ↔ SE vault share (compose)

**Should-have when protocol has intermediate:**

- rebasing ↔ wrapped (e.g. stETH ↔ wstETH, eETH ↔ weETH)  
- frxETH ↔ sfrxETH  

**Optional / later:**

- LST ↔ LRT (restake path) — often better as a **separate LRT SE** than nested inside pure LST SE  
- Exact-out solvers against exit queues — generally **reject** (`InvalidRoute`) per IndexedEx DETF/SE guidance for non-closed-form routes  

### 3.4 Testing expectations (production-first)

Mirror Aave Stata + DEX SE TestBases:

- Real protocol contracts via fork (Ethereum mainnet) and/or hermetic ports if Crane later vendors them.
- Do **not** mock Lido/Rocket Pool/ether.fi as SUT dependencies for lifecycle tests.
- Cover: deposit mint, redeem, preview==execution where protocol allows, fee share mint, rate movement after time/rewards, withdrawal queue edge cases, reentrancy on share token if relevant.

---

## 4. Protocol assessments

Viability scores:

- **A — Build soon:** clear routes, large liquidity, production DeFi usage  
- **B — Strong candidate:** good technical fit; smaller or more complex risk  
- **C — Conditional:** viable with constraints (issuer trust, permissioning, thin liquidity)  
- **D — Poor SE fit:** no liquid token surface, pure infrastructure, or wrong asset class  
- **X — Avoid / out of scope for IndexedEx SE v1**

---

### 4.1 Liquid staking protocols (Ethereum)

#### Lido Finance — **A (P0)**

| Field | Detail |
|-------|--------|
| **Product** | Pooled ETH staking; largest LST |
| **Tokens** | `stETH` (rebasing), `wstETH` (non-rebasing wrapper) |
| **TVL** | ~$17.9B (Ethereum liquid staking leader) |
| **Mint / redeem** | Submit ETH → stETH; wrap/unwrap wstETH; withdrawals via protocol request / secondary markets |
| **SE fit** | Excellent. Use **`wstETH` as SE `asset()`**; routes for ETH/WETH, stETH, wstETH, SE share |
| **Pros** | Ubiquitous DeFi collateral; battle-tested; deep Balancer/Curve/Aave integrations; well-known rate providers |
| **Cons** | Concentration / governance risk; rebasing footguns if someone uses raw stETH as vault asset; withdrawal latency under stress |
| **IndexedEx notes** | Highest leverage for DETF rateAsset legs and Balancer buffer pools. Closest strategic parallel to “default WETH yield leg.” |
| **Viability** | **A — P0** |

#### Rocket Pool — **A (P0)**

| Field | Detail |
|-------|--------|
| **Product** | Decentralized liquid staking with permissionless node operators (minipools) |
| **Tokens** | `rETH` (value-accruing) |
| **TVL** | ~$1.0B |
| **Mint / redeem** | Deposit ETH for rETH; redeem against protocol liquidity / burn mechanisms (availability varies with deposit pool) |
| **SE fit** | Excellent. Single value-accruing token simplifies routes vs Lido dual form |
| **Pros** | Decentralization narrative; clean rate model; mature; strong community + DeFi listings |
| **Cons** | Smaller liquidity than Lido; deposit pool can constrain mint/redeem at times → previews must handle partial liquidity |
| **IndexedEx notes** | Great second SE for multi-vault weighted DETFs (distinct LST valuations) |
| **Viability** | **A — P0** |

#### Frax Ether — **A (P1)**

| Field | Detail |
|-------|--------|
| **Product** | Dual-token liquid staking: frxETH (≈1 ETH claim) + sfrxETH (yield-bearing vault) |
| **Tokens** | `frxETH`, `sfrxETH` (**ERC-4626** over frxETH) |
| **TVL** | ~$100M |
| **Mint / redeem** | ETH → frxETH via minter; frxETH ↔ sfrxETH via ERC-4626 deposit/redeem |
| **SE fit** | **Best technical match to Aave Stata SE** (native ERC-4626 yield token) |
| **Pros** | Standard vault interface; clear previews; Frax ecosystem composability |
| **Cons** | Smaller TVL; dual-token mental model; peg/liquidity management for frxETH |
| **IndexedEx notes** | Strong first implementation *template* if team wants 4626-first staking SE before Lido complexity |
| **Viability** | **A — P1** (implementation simplicity may even justify building *before* Lido for a spike) |

#### StakeWise (V3) — **A/B (P1)**

| Field | Detail |
|-------|--------|
| **Product** | Marketplace of staking **Vaults**; optional liquidity via `osETH` |
| **Tokens** | `osETH`; per-vault share tokens |
| **TVL** | Hundreds of millions (DeFiLlama lists StakeWise family ~$0.7B+) |
| **Mint / redeem** | Stake into vaults; mint/burn osETH against vault positions |
| **SE fit** | Strong if scoped as: (1) **osETH SE**, and/or (2) generic **StakeWise Vault SE** with `deployVault(vault)` |
| **Pros** | Modular vaults map naturally to IndexedEx multi-instance packages; institutional + retail paths |
| **Cons** | Heterogeneous vault risk/fees; osETH over-collateralization rules; more complex than single-pool Lido |
| **IndexedEx notes** | Attractive for `deployVault` matrix: one DFPkg, many vault instances — similar spirit to per-asset Stata deploy |
| **Viability** | **A for osETH SE; B for full vault marketplace SE** |

#### mETH Protocol (Mantle) — **B (P2)**

| Field | Detail |
|-------|--------|
| **Product** | Liquid staked ETH aligned with Mantle ecosystem |
| **Tokens** | `mETH` (and related restaking variants) |
| **TVL** | ~$0.50B |
| **SE fit** | Good if mint/redeem and rate are fully on-chain and liquid on Ethereum mainnet |
| **Pros** | Meaningful TVL; ecosystem sponsorship |
| **Cons** | Ecosystem concentration; restaking variants add risk stack |
| **Viability** | **B — P2** |

#### Stader (ETHx) — **B (P2)**

| Field | Detail |
|-------|--------|
| **Product** | Multi-chain LSD; Ethereum token `ETHx` |
| **Tokens** | `ETHx` |
| **TVL** | ~$0.19B (protocol multi-chain) |
| **SE fit** | Standard LST SE if deposit contracts and redeem paths are stable |
| **Pros** | Established brand; permissionless positioning |
| **Cons** | Smaller ETH liquidity vs top tier; multi-chain product complexity is noise for ETH-only SE |
| **Viability** | **B — P2** |

#### Swell (liquid staking) — **B (P2)**

| Field | Detail |
|-------|--------|
| **Product** | `swETH` liquid staking; separate restaking (`rswETH`) and strategy vaults (`earnETH`) |
| **Tokens** | `swETH`, `rswETH` |
| **TVL** | ~$27M LST + ~$24M LRT (modest) |
| **SE fit** | Fine technically; priority limited by TVL |
| **Pros** | Clean LRT spin; L2 narrative (Swellchain) |
| **Cons** | Thin liquidity relative to leaders |
| **Viability** | **B — P2** (bundle with restaking product if built) |

#### Liquid Collective — **C (P3)**

| Field | Detail |
|-------|--------|
| **Product** | Institutional liquid staking (`LsETH`) |
| **TVL** | ~$0.62B |
| **SE fit** | Technically possible; **permissioning / KYC / allowlists** may block permissionless SE mint paths |
| **Pros** | Institutional quality, audits, large TVL |
| **Cons** | Not a retail DeFi primitive; may not support open `deposit` from arbitrary contracts |
| **Viability** | **C** — only if on-chain interfaces are permissionless enough for SE automation |

#### Coinbase cbETH — **C (P3)**

| Field | Detail |
|-------|--------|
| **Product** | Coinbase wrapped staked ETH |
| **Tokens** | `cbETH` |
| **TVL** | ~$0.35B (wrapped product; more ETH staked off-chain at Coinbase) |
| **Mint / redeem** | Primarily through Coinbase; on-chain wrap/unwrap limited relative to pure DeFi LSTs |
| **SE fit** | Weak for **primary** mint/redeem SE; possible **wrap-only / secondary-market** vault |
| **Pros** | Brand trust, size of Coinbase staking base |
| **Cons** | Issuer-controlled; high fee (historically ~25% of rewards); regulatory surface |
| **Viability** | **C** — secondary-market SE only, not core strategy vault |

#### Binance wBETH — **C (P3)**

| Field | Detail |
|-------|--------|
| **Product** | Binance liquid staked ETH |
| **Tokens** | `wBETH` |
| **TVL** | ~$6.8B (very large) |
| **SE fit** | Same class as cbETH: large but **CEX-gated** mint/redeem |
| **Pros** | Enormous TVL; deep CEX liquidity |
| **Cons** | Custodial / exchange dependency; poor fit for immutable permissionless SE philosophy |
| **Viability** | **C** — optional later for CEX-bridge strategies; not P0 |

#### Origin OETH / superOETHb — **B/C (P3)**

| Field | Detail |
|-------|--------|
| **Product** | Yield-bearing ETH product (rebasing / wrapped variants); often DeFi strategy layered on LSTs |
| **TVL** | Tens of millions |
| **SE fit** | Possible, but may be **strategy-on-strategy** (higher nested risk) |
| **Viability** | **B/C** — treat carefully vs pure LST |

#### Ankr, StaFi, Dinero (pxETH), Meta Pool, StakeStone, NodeDAO, long tail — **C/D**

| Assessment | Detail |
|------------|--------|
| **SE fit** | Possible for individual packages once top tier ships |
| **Why low priority** | Thin liquidity, weaker DeFi integrations, higher oracle/exit risk |
| **Viability** | **C/D** until a concrete partner or user demand appears |

#### Pure staking-as-a-service (Figment, Kiln, P2P.org, Stakefish, etc.) — **D/X**

| Assessment | Detail |
|------------|--------|
| **Product** | Operator runs validators for clients; often no public LST |
| **SE fit** | No standard liquid share → no SE vault surface |
| **Exception** | If they issue a public ERC-20 LST (or partner with one), reassess as LST |
| **Viability** | **X for SE v1** |

#### Solo / native beacon staking — **D/X**

| Assessment | Detail |
|------------|--------|
| **SE fit** | 32 ETH keys, exit queues, no fungible share without a pool wrapper |
| **Viability** | **X** — use LSTs instead |

---

### 4.2 Liquid restaking protocols (LRTs)

LRTs add **AVS / restaking slashing and reward complexity** on top of ETH staking. SE vaults are still viable, but risk documentation and rate-provider design must include restaking layers.

#### ether.fi — **A (P1)**

| Field | Detail |
|-------|--------|
| **Product** | Native liquid restaking; ETH staked + restaked (EigenLayer, etc.) |
| **Tokens** | `eETH` (rebasing), `weETH` (non-rebasing wrap) |
| **TVL** | ~$3.2B (dominant LRT) |
| **SE fit** | Excellent, **mirror Lido pattern**: SE `asset()` = `weETH` |
| **Pros** | Largest LRT liquidity; strong DeFi listings (Aave, Pendle, etc.); wrap model well understood |
| **Cons** | Restaking / AVS risk; protocol complexity beyond pure LST |
| **IndexedEx notes** | Natural DETF “higher yield ETH leg”; do not conflate with pure Lido SE |
| **Viability** | **A — P1** |

#### Kelp (rsETH) — **B (P2)**

| Field | Detail |
|-------|--------|
| **Product** | Liquid restaking token `rsETH` |
| **TVL** | ~$0.97B |
| **SE fit** | Standard LRT SE |
| **Pros** | Large TVL; multi-chain presence |
| **Cons** | Restaking risk; competitive vs ether.fi for first LRT package |
| **Viability** | **B — P2** |

#### Renzo (ezETH) — **B (P2)**

| Field | Detail |
|-------|--------|
| **Tokens** | `ezETH` |
| **TVL** | ~$96M |
| **SE fit** | Standard LRT SE |
| **Pros** | Broad chain deployment history |
| **Cons** | Smaller than leaders; past depeg stress episodes in LRT class (ecosystem-wide lesson) |
| **Viability** | **B — P2** |

#### Puffer — **B (P2)**

| Field | Detail |
|-------|--------|
| **Tokens** | `pufETH` (and related) |
| **TVL** | ~$47M |
| **SE fit** | Viable LRT SE with native restaking narrative |
| **Pros** | Distinct tech story (anti-slashing / based rollup adjacency) |
| **Cons** | Smaller liquidity |
| **Viability** | **B — P2** |

#### Mellow Restaking vaults — **B (P2/P3)**

| Field | Detail |
|-------|--------|
| **Product** | Curated restaking vaults (often ERC-4626-like) |
| **SE fit** | **Very good technical fit** if vaults are standard ERC-4626 |
| **Pros** | Instantiated vault matrix; strategy differentiation |
| **Cons** | Curator risk; heterogeneous vault quality |
| **Viability** | **B** — good second-wave package after generic LRT SE |

#### Swell rswETH, Mantle restaking, Bedrock uniETH, Eigenpie, etc. — **B/C**

Build after P0/P1 if demand or partner distribution appears. Prefer not to explode package count before Lido/Rocket Pool/ether.fi gold paths exist.

---

### 4.3 Restaking base layers (not LSTs)

#### EigenLayer (EigenCloud) — **D as SE asset; A as dependency**

| Field | Detail |
|-------|--------|
| **Product** | Restake ETH/LSTs to secure AVSs |
| **User surface** | Operator/delegator positions; often accessed via LRTs |
| **SE fit** | **Do not** make “raw EigenLayer position” a v1 SE vault. Users want `weETH`/`rsETH`, not operator shares |
| **Viability** | **D for SE share; critical dependency for LRT packages** |

#### Symbiotic — **D as SE asset; B as dependency**

| Field | Detail |
|-------|--------|
| **Product** | Multi-collateral shared security |
| **SE fit** | Same as EigenLayer — integrate via liquid wrappers / vault products, not raw restake positions |
| **Viability** | **D for direct SE; watch for liquid Symbiotic vault standards** |

#### Karak / other generalized restaking — **C/D**

| Assessment | Reassess if a liquid, Ethereum-native yield token with open mint/redeem and meaningful TVL emerges |

#### Babylon — **X for ETH SE**

| Assessment | Bitcoin staking restaking — wrong asset class for ETH Standard Exchange vaults |

---

## 5. Comparative SE-viability matrix

| Protocol | Category | Token(s) | On-chain mint | Predictable redeem | ERC-4626 / wrap | DeFi depth | SE score | Build priority |
|----------|----------|----------|---------------|--------------------|-----------------|------------|----------|----------------|
| Lido | LST | stETH/wstETH | Yes | Queue + secondary | wrap | ★★★★★ | A | P0 |
| Rocket Pool | LST | rETH | Yes | Liquidity-dependent | rate token | ★★★★ | A | P0 |
| Frax Ether | LST | frxETH/sfrxETH | Yes | 4626 + liquidity | **native 4626** | ★★★ | A | P1 |
| ether.fi | LRT | eETH/weETH | Yes | Liquidity + queue | wrap | ★★★★★ | A | P1 |
| StakeWise | LST | osETH / vaults | Yes | Vault-specific | rate + vaults | ★★★ | A/B | P1 |
| mETH | LST | mETH | Yes | Protocol-specific | rate | ★★★ | B | P2 |
| Stader | LST | ETHx | Yes | Protocol-specific | rate | ★★ | B | P2 |
| Kelp | LRT | rsETH | Yes | Protocol-specific | rate | ★★★ | B | P2 |
| Swell | LST/LRT | swETH/rswETH | Yes | Protocol-specific | rate | ★★ | B | P2 |
| Renzo | LRT | ezETH | Yes | Protocol-specific | rate | ★★ | B | P2 |
| Puffer | LRT | pufETH | Yes | Protocol-specific | rate | ★★ | B | P2 |
| Mellow | LRT vaults | various | Yes | Vault 4626-ish | often 4626 | ★★ | B | P2/P3 |
| Liquid Collective | LST | LsETH | Restricted | Restricted | rate | ★★ | C | P3 |
| Coinbase | LST | cbETH | Restricted | Restricted | rate | ★★★ | C | P3 |
| Binance | LST | wBETH | Restricted | Restricted | rate | ★★★ | C | P3 |
| EigenLayer | Base | positions | N/A | N/A | N/A | ★★★★ | D | — |
| Symbiotic | Base | positions | N/A | N/A | N/A | ★★ | D | — |
| SaaS validators | Native | none | Off-chain | Off-chain | no | — | X | — |

---

## 6. Suggested package architecture (when implementation starts)

### 6.1 Package naming (role-oriented)

Follow IndexedEx naming rules (no product-brand pollution in *generic* DETF surfaces). Protocol packages may use protocol names at the integration boundary:

```text
contracts/protocols/staking/
  lido/
    LidoWstETH_Component_FactoryService.sol
    LidoWstETHStandardExchangeDFPkg.sol
    LidoWstETHStandardExchangeInFacet.sol
    LidoWstETHStandardExchangeOutFacet.sol
    LidoWstETHMarkerFacet.sol
    TestBase_LidoWstETHStandardExchange.sol
  rocketpool/
    RocketPoolRETHStandardExchange...
  frax/
    FraxSfrxETHStandardExchange...   # 4626-native
  etherfi/
    EtherFiWeETHStandardExchange...
```

(Exact paths can follow existing `protocols/lending/aave` and `protocols/dexes/*` conventions.)

### 6.2 Shared staking SE lib (optional early)

Extract reusable helpers once two packages exist:

- ETH ↔ WETH handling  
- rebasing ↔ wrapped conversions  
- withdrawal-request status queries (if standardized enough)  
- rate-provider registration hooks for Balancer SE router  

Avoid premature abstraction before Lido + one 4626-native package (Frax) prove patterns.

### 6.3 Fee oracle marker

Each package should expose a marker interface (as Aave Stata does) whose interface ID keys Vault Fee Oracle usage fees. Default production fee may be 0 for pure wrap strategies.

### 6.4 DETF composition

Once SE vaults exist:

- Single SE DETF with `rateAsset = WETH` and underlying vault = Lido/Rocket Pool SE  
- Multi-vault weighted DETF mixing LST SE legs (Lido + Rocket Pool + ether.fi) for distinct valuations  

Keep DETF production code **opaque** to concrete Lido/Rocket types — only `IStandardExchange*`.

---

## 7. Risks common to all staking SE vaults

1. **Consensus / slashing risk** — underlying validators can be penalized; LST exchange rate can drop.  
2. **Smart contract / governance risk** — upgradeable staking protocols, DAO parameter changes, oracle modules.  
3. **Liquidity & depeg risk** — secondary market price of LST/LRT vs ETH can diverge under stress.  
4. **Withdrawal queue risk** — primary redeem latency; SE “Out” may need secondary-market route with slippage.  
5. **Restaking / AVS risk (LRTs)** — additional slashing conditions beyond Ethereum consensus.  
6. **Rebasing accounting bugs** — never store rebasing tokens as naked ERC-4626 assets without share-aware handling; prefer wrappers.  
7. **Regulatory / issuer risk (CEX LSTs)** — freeze, geographic restriction, or policy change.  
8. **Rate provider manipulation / stale rates** — Balancer pools using LST rate providers need careful config (see IndexedEx optional rate provider work).

---

## 8. Recommended next steps

1. **Lock P0 scope:** Lido `wstETH` SE + Rocket Pool `rETH` SE (or Frax `sfrxETH` spike first for 4626 template).  
2. **Write per-protocol PRD + implementation plan** beside package paths (mirror `AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md`).  
3. **Confirm mainnet addresses + interfaces** for submit/wrap/unwrap/deposit/redeem; capture in plan.  
4. **Fork TestBase** design on Ethereum mainnet RPC; no mocks of LST contracts.  
5. **Rate provider / Balancer buffer** integration checklist once SE shares exist.  
6. **LRT track** starts with ether.fi `weETH` after pure LST gold path is green.  
7. **Revisit CEX LSTs** only if product needs Coinbase/Binance distribution — expect restricted mint paths.

---

## 9. Source index

| Source | Use |
|--------|-----|
| [DeFiLlama Liquid Staking (Ethereum)](https://defillama.com/protocols/liquid-staking/ethereum) | TVL rankings for LSTs |
| [DeFiLlama Liquid Restaking](https://defillama.com/protocols/liquid-restaking) | TVL rankings for LRTs |
| [DeFiLlama Restaking](https://defillama.com/protocols/restaking) | EigenLayer / Symbiotic / Babylon bases |
| [Frax frxETH / sfrxETH docs](https://docs.frax.finance/frax-ether/frxeth-and-sfrxeth) | ERC-4626 sfrxETH model |
| [ether.fi technical docs](https://etherfi.gitbook.io/etherfi/) | eETH / weETH + restaking |
| [StakeWise](https://stakewise.io/) | Vault marketplace + osETH |
| [Fireblocks Liquid Staking 101](https://www.fireblocks.com/report/liquid-staking-101) | Staking model taxonomy |
| Spark / industry LST comparisons | Fee and redeem latency context (approximate) |
| IndexedEx Aave Stata SE plan | `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` |
| IndexedEx AGENTS.md | SE / DETF production-first rules |

---

## 10. Changelog

| Date | Change |
|------|--------|
| 2026-07-21 | Initial research memo: protocol catalog + SE vault viability assessment |

---

*This document is research for internal planning. TVL and product details change quickly; re-check DeFiLlama and protocol docs before implementation kickoff.*

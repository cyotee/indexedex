# Morpho + Uniswap: Lending & Market-Making Strategy Research

**Date:** 2026-08-02  
**Status:** Research reference (not a product PRD)  
**Audience:** IndexedEx engineering exploring Morpho Vault V2 + Uniswap V3/V4 strategy vaults  
**Scope:** Common industry strategies for Morpho lending, Uniswap V3/V4 market making, and cross-protocol combinations — synthesized so design work reuses existing product patterns instead of inventing from scratch.

**Related IndexedEx / Crane paths:**

| Topic | Path |
|-------|------|
| Generic ERC-4626 SE (wrap MetaMorpho / Vault V2) | `contracts/vaults/standard/erc4626/` |
| Aave Stata SE peer (supply-only lending SE) | `contracts/protocols/lending/aave/v3.6/` |
| Crane Morpho Blue service / TestBase | `lib/crane/contracts/protocols/lending/morpho/blue/` |
| Crane Morpho domain (Blue, MetaMorpho, Vault V2, Bundler3) | `lib/crane/contracts/external/morpho/` |
| Robinhood Morpho constants | `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` |
| Crane Morpho skill | `lib/crane/.claude/skills/crane-morpho/` |
| Morpho architecture / vaults skills | `morpho-architecture`, `morpho-vaults`, `morpho-blue-operations` |

**Related IndexedEx research:**

- **Strategy explanations (this map, expanded):** [`2026-08-02-morpho-uniswap-strategy-explanations.md`](./2026-08-02-morpho-uniswap-strategy-explanations.md)  
- **Lending × CL MM protocol processes (abstract to Morpho+Uni):** [`2026-08-02-lending-cl-mm-protocol-process-research.md`](./2026-08-02-lending-cl-mm-protocol-process-research.md)  
- **S3 design surfaces (borrow→LP pre-PRD):** [`2026-08-02-s3-borrow-to-lp-design-surfaces.md`](./2026-08-02-s3-borrow-to-lp-design-surfaces.md)  
- **S3 DFPkg PkgInit/PkgArgs sketch:** [`2026-08-02-s3-dfpkg-pkgargs-interface-sketch.md`](./2026-08-02-s3-dfpkg-pkgargs-interface-sketch.md)  
- Composition diagram: [`2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md`](./2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md)  
- V4 buffer/pricing hook PRD (S0 + swap surface): `contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md`  
- Generic ERC-4626 SE consumer rules: `docs/research/2026-07-21-ethereum-staking-protocol-ports-PRD.md` §7  
- Custom vs generic SE assessment: `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`

---

## 1. Executive summary

1. **Industry Morpho × Uniswap integration today is mostly distribution, not dual-protocol strategy.** Uniswap Earn deposits into Gauntlet-curated Morpho vaults; Coinbase / Robinhood Earn route stables into Morpho vaults. Morpho does lending; Uni (or the app) is the front door.

2. **Passive wrap of a Morpho Vault V2 (or MetaMorpho on chains that have it) does not need a Morpho-specific SE.** Use `ERC4626StandardExchangeDFPkg.deployVault(IERC4626 protocolVault)` under `contracts/vaults/standard/erc4626/`. Same path as `sfrxETH`.

3. **Robinhood Chain Morpho surface is Blue + Vault V2 + Bundler3** — **not** MetaMorpho V1. Design RH products against Vault V2 instances, not MetaMorpho V1.1.

4. **True Morpho + Uni strategy vaults** (capital that LPs *and* lends / borrows) map to known DeFi patterns: dual-sleeve allocation, borrow→LP, levered LP, ALM + idle lend, Morpho V2 custom adapters (Steakhouse Turbo/Term/Box), or Fluid-style unified liquidity. Levered LP and unified liquidity are hardest (oracle, NFT coll, liquidation).

5. **Recommended exploration ladder for IndexedEx:**  
   **S0** pure Morpho V2 wrap → **S2** dual sleeve (Morpho + Uni) → **S5** Morpho V2 + Uni adapter → only then **S3/S4** leverage.

---

## 2. IndexedEx baseline: wrapping Morpho lending

### 2.1 Generic ERC-4626 Standard Exchange

Package: `contracts/vaults/standard/erc4626/`

| Piece | Behavior |
|-------|----------|
| Deploy | `deployVault(IERC4626 protocolVault)` via vault registry / manager |
| SE `asset()` | Protocol vault (e.g. Morpho Vault V2, MetaMorpho) |
| Marker | `IERC4626StandardExchange.protocolVault()` |
| Routes | `underlying ↔ protocolVault shares ↔ SE shares` |
| Fee type | `VaultFeeType.LENDING` + marker interface id |
| TestBase | `contracts/test/bases/TestBase_ERC4626StandardExchange.sol` |
| Fork proof | `test/foundry/fork/eth_main/vaults/standard/erc4626/ERC4626StandardExchange_SfrxETH_Fork.t.sol` |

**Routes implemented by `ERC4626StandardExchangeInTarget`:**

```text
protocolVault.asset()  ↔  protocolVault (IERC4626)  ↔  SE shares
```

Uses standard `deposit` / `redeem` / `previewDeposit` / `previewRedeem`. Does **not** handle native ETH mint paths, rebasing wraps, async exit queues, or non-4626 surfaces.

### 2.2 When generic SE is enough vs not

| Target | Generic ERC4626 SE? | Notes |
|--------|---------------------|--------|
| MetaMorpho V1.1 (chains that list it) | **Yes** | IERC4626 over loan asset |
| Morpho Vault V2 instance | **Yes** | IERC4626; configure adapters separately |
| Morpho Blue market / supply shares | **No** | Not IERC4626; needs custom accounting |
| Borrow / loop / LP hybrid | **No** | Custom package or Morpho V2 adapters |

### 2.3 MetaMorpho vs Vault V2 (product language)

| Layer | Role | IERC4626? |
|-------|------|-----------|
| Morpho Blue | Isolated markets `(loan, coll, oracle, irm, lltv)` | No |
| MetaMorpho V1.1 | Curated ERC-4626 over Blue | Yes |
| Vault V2 | Permissionless vault shell + **adapters** + ID/cap risk | Yes |
| Bundler3 | Atomic multicall UX | N/A |

Vault V2 factory (permissionless):

```solidity
// VaultV2Factory — no access control on create
function createVaultV2(address owner, address asset, bytes32 salt) external returns (address);
```

Anyone can deploy a vault shell. Yield requires owner/curator wiring of adapters, caps, and allocation. Empty vault ≠ productive Earn product.

---

## 3. Robinhood Chain Morpho surface

Source: Crane `ROBINHOOD_MAIN` (Morpho docs addresses, ~2026-07-27).

| Component | On RH mainnet? | Crane constant / note |
|-----------|----------------|------------------------|
| Morpho Blue | Yes | `MORPHO` / `MORPHO_BLUE` |
| AdaptiveCurve IRM | Yes | `MORPHO_ADAPTIVE_CURVE_IRM` |
| Vault V2 factory | Yes | `MORPHO_VAULT_V2_FACTORY` |
| Vault V1 / Market V1 adapter factories | Yes | adapter factory constants |
| Morpho Registry | Yes | `MORPHO_REGISTRY` |
| Bundler3 + GeneralAdapter1 | Yes | bundler constants |
| **MetaMorpho V1 / V1.1** | **Not listed** | Design against **Vault V2**, not MetaMorpho V1 |
| Robinhood testnet Morpho | Not seeded in Crane | `ROBINHOOD_TESTNET` has no Morpho constants as of this note |

**Comment in `ROBINHOOD_MAIN.sol`:**

> Robinhood Chain tab: Blue + Vault V2 + Bundler3 (no MetaMorpho V1 / URD listed).

**Public RH Earn narrative:** USDG (and similar) through Morpho vaults into Morpho markets; Steakhouse-style curation and Turbo-style leveraged Morpho V2 products have been marketed on RH. Treat **Vault V2 + adapters** as the native advanced-strategy host on that chain.

**Practical RH wrap path:**

```text
loanToken (e.g. USDG)  ↔  Morpho Vault V2 shares  ↔  ERC4626 SE shares
                              deployVault(vaultV2Instance)  // not the factory
```

Factory address ≠ vault instance. Integration needs a live vault with configured adapters and liquidity, plus RH fork tests for preview==execution.

---

## 4. How industry combines Morpho and Uniswap today

| Pattern | What it is | Example / note |
|---------|------------|----------------|
| **Uni UI → Morpho vault** | Uniswap Earn: deposit USDC/USDT/ETH into Gauntlet Morpho vaults | Morpho lends; Uni is distribution (2026 Earn launch) |
| **Retail app → Morpho vault** | Coinbase / Robinhood Earn | Stables → Morpho Vault → Blue markets |
| **Curated supply only** | Vault V2 / MetaMorpho; no Uni LP | Steakhouse, Gauntlet Prime/Core, etc. |

**Design implication:** “Morpho × Uniswap” in production is often **Earn on Morpho + UX on Uniswap**, not a single vault that market-makes on Uni *and* supplies Morpho. A dual-protocol **strategy** vault is a different product class (capital efficiency / dual yield / leverage).

---

## 5. Morpho-side strategy catalog

### 5.1 Passive / curated supply (default, most TVL)

- User deposits one loan asset (USDC, WETH, USDG, …).
- Curator sets markets, caps, supply/withdraw queues.
- Yield = borrower demand on Morpho Blue.
- Risk bands: **Prime** (blue-chip collateral markets) vs **Core / High Yield** (wider collateral set).

Vault V2 adds adapters + granular ID/cap risk factors so allocation is not only a flat Blue market list.

### 5.2 Leveraged loop / carry (“Turbo”)

Classic DeFi carry (also on Aave/Spark):

```text
supply coll → borrow loan asset → buy more coll → supply → …
```

or stable↔stable loops when rate structure allows.

**Steakhouse Turbo** on Morpho V2 uses **custom Box adapters** so the vault can execute leveraged/carry beyond plain supply queues. RH marketing has described Turbo USDG-style products as leveraged carry into credit/stable markets (~multi-x target leverage, wind-down/liquidity risk called out by third-party summaries).

### 5.3 Term / fixed-maturity style

Steakhouse **Term / Box**: adapters with whitelisted actions, slippage constraints, maturity-style holds. Still Morpho V2 share shell; strategy lives in adapters.

### 5.4 Raw Blue (isolated market)

Power users pick full `MarketParams` (loan, coll, oracle, IRM, LLTV). No curator. Vault products primarily **abstract** this for end users.

### 5.5 Morpho V2 as strategy host (key architecture lesson)

| Concern | Hosted on Vault V2 |
|---------|-------------------|
| ERC-4626 shares / deposit-withdraw UX | Vault |
| Risk caps / IDs / roles / timelocks | Vault governance |
| Where capital actually sits | **Adapters** (Blue markets, custom strategies, Box) |

**Takeaway for IndexedEx:** complex Morpho+Uni products may fit **Morpho V2 vault + custom Uni adapter** better than bolting Uni into the generic ERC4626 SE alone. Steakhouse’s V1→V2 migration story: V1 could only route to Blue; V2 adapters unlock Term/Turbo-class strategies.

---

## 6. Uniswap V3/V4 market-making catalog

| Strategy | Idea | Typical shippers |
|----------|------|------------------|
| Full-range / wide | Low fee density, less rebalance, lower IL drama | Manual LPs, conservative ALMs |
| Narrow concentrated | High fee APR, high IL, often out-of-range | Manual + aggressive ALMs |
| Dynamic rebalance ALM | Keep range around price; auto-compound fees | Gamma, Arrakis, ICHI, similar ALMs |
| Inventory / asymmetric | One-sided or skewed range (bootstrap quote asset, DCA-ish) | Arrakis Pro Bootstrap, treasury strategies |
| V4 hooks | Custom curve, dynamic fee, limit-order-like, MEV control | Hook builders; still “LP + rule engine” |
| Stable–stable CL | Tiny range, fee + low IL | Stablecoin market makers |

**ALM product is the rebalance policy:** range width, swap vs limit-style rebalance, fee compounding, when to sit idle. Gauntlet and others have published Uniswap ALM analyses along these axes.

**Composability note:** V3/V4 positions are **NFTs** (not V2-style ERC-20 LP). Using LP as Morpho collateral usually needs a **vault share wrapper**, manager token, or custom market + oracle — not naive NFT deposit into Blue.

IndexedEx already has Uni V3/V4 Standard Exchange packages under `contracts/protocols/dexes/uniswap/v3/` and `v4/` for pure LP SE shapes.

---

## 7. Cross-protocol: lending + market making

Patterns that appear when products combine **lend and LP** (Morpho optional; economics transfer).

### 7.1 Levered LP (LP as collateral)

```text
mint Uni V3/V4 position → post as coll on lending → borrow → add liquidity → …
```

- Precedent: Aave + Uni V3 leveraged LP (Contango-class / academic CL strategies).
- **Hard on Morpho:** Blue needs oracle + market for that coll. NFT positions are non-standard ERC-20 coll.
- Rare as *native Morpho* product vs Aave/Fluid.

### 7.2 Borrow cheap → LP the proceeds

```text
post blue-chip coll on Morpho/Aave → borrow USDC → LP USDC/X on Uni
```

- Earn: LP fees − borrow APY − IL.
- Common manual / automation-tool style when coll is liquid and oracle-safe.

### 7.3 Supply idle leg, LP active leg

```text
inventory split: idle stables on Morpho when OOR / low edge; in-range capital on Uni
```

- Market-maker inventory management across **rate market** and **AMM**.
- Often implemented as ALM + separate lend sleeve rather than one atomic protocol.

### 7.4 Unified liquidity (Fluid / research designs)

- Same capital serves **swap depth** and **borrowable liquidity** (“smart collateral”).
- Fluid markets combined LP+borrow; research explores unified liquidity layers (DEX pool + lending pool sharing inventory).
- Closest category if the goal is **capital efficiency**, not merely dual yield.

### 7.5 Delta-neutral / basis-ish

- LP + hedge (perp/short), or lend one side / short the other.
- More structured-yield (Cian-class leverage + wraps) than plain Morpho vault.
- Galaxy-style yield stack: base rates → engineered products → activity (AMM fees).

### 7.6 Earn sandwich (distribution only)

- Uni (or app) front end + Morpho back end.
- **Zero co-deployment of LP + lend capital** in one strategy engine.
- Best UX precedent; not a strategy architecture template.

### 7.7 Morpho V2 adapter hosts Uni (recommended RH-native advanced path)

```text
User → Morpho Vault V2 shares
         ├─ Adapter: Morpho Blue markets (supply)
         └─ Adapter: Uni V3/V4 positions (or ALM manager)
```

- Caps, wind-down, roles live at vault layer.
- Matches Steakhouse Box/Turbo architectural lesson with Uni as a custom adapter domain.

---

## 8. Strategy map for Morpho V2 + Uni V3/4 exploration

Ranked by industry precedent vs build difficulty for IndexedEx:

| ID | Strategy concept | Morpho role | Uni role | Precedent | Difficulty |
|----|------------------|-------------|----------|-----------|------------|
| **S0** | Pure Morpho V2 wrap (generic ERC4626 SE) | Supply vault | none | Uni Earn, Coinbase, RH Earn | Low |
| **S1** | Uni ALM only; Morpho optional for idle stables | Idle cash | CL LP | Gamma / Arrakis | Medium |
| **S2** | **Dual sleeve**: % Morpho supply + % Uni LP | Rate yield | Fee yield | Yearn multi-strategy style | Medium |
| **S3** | Borrow on Morpho → LP on Uni (fixed leverage) | Debt | LP | Manual / Contango-class | Med–High |
| **S4** | Levered LP (LP coll → borrow → more LP) | Coll market | LP | Aave+Uni more than Morpho | High (oracle/NFT) |
| **S5** | Morpho V2 + custom Uni adapter | Vault shell + caps | Adapter holds V3/V4 | Steakhouse Turbo architecture | High, RH-aligned |
| **S6** | Fluid-like unified liquidity | Shared inventory | Shared inventory | Fluid / research | Very high |

### 8.1 Recommended ladder

1. **S0** — ship wrap + RH/ETH fork proof (validates infra, not dual strategy).  
2. **S2** — dual-sleeve product thesis (clear risk narrative: rate + fee).  
3. **S5** — if RH-native Morpho V2 governance/caps matter more than IndexedEx diamond as sole shell.  
4. **S3/S4** — only after coll representation, liquidation, and oracle design are explicit.

---

## 9. Risks (design constraints from industry)

| Risk | Where it bites |
|------|----------------|
| Impermanent loss / out-of-range | Concentrated Uni; fees may not cover IL |
| Liquidation | Any Morpho borrow sleeve |
| Rate inversion | Borrow APY > LP fee APR |
| Oracle / coll quality | LP NFT or exotic vault shares as Morpho coll |
| Liquidity / wind-down | Levered Morpho vaults with thin immediate buffer |
| Rebalance MEV / cost | ALM swaps; V4 hooks can mitigate or worsen |
| Curator / adapter trust | V2 roles; instant adapter adds vs timelocks |
| Adapter `realAssets` gas / DoS | Too many adapters or heavy reporting (Vault V2 skill note) |

---

## 10. Primary yield thesis (choose before architecture)

Pick one primary thesis before writing a PRD:

| Thesis | Description | Likely shape |
|--------|-------------|--------------|
| **Rate-first** | Mostly Morpho; Uni only for inventory/swaps | S0 / S1 light |
| **Fee-first** | Mostly Uni ALM; Morpho for idle/stable buffer | S1 / S2 |
| **Leverage / carry** | Morpho debt or Morpho loops (Turbo-like) | S3 / S5 |
| **Unified capital efficiency** | Same inventory for swap + lend | S6 |

---

## 11. IndexedEx package decision tree

```text
Is the product pure supply into an existing Morpho IERC4626 vault?
  YES → contracts/vaults/standard/erc4626 (S0)
  NO  → Is it dual-sleeve without Morpho borrow?
          YES → Custom IndexedEx SE or Morpho V2 multi-adapter (S2 / S5)
          NO  → Borrow or levered LP?
                  YES → Explicit coll oracle + liquidation design (S3 / S4)
                  NO  → Unified liquidity protocol design (S6) — new product class
```

**Do not invent a Morpho-named SE package** solely to wrap Vault V2/MetaMorpho supply — generic ERC4626 SE already does that.

**Do invent a custom package or Morpho V2 adapter** when:

- Uni V3/V4 positions are first-class inventory,
- Morpho borrow exists,
- rebalance / ALM logic is in-protocol,
- or marker/fee types must be Morpho-specific for registry/oracle policy.

---

## 12. Crane / testing notes (when implementing)

| Need | Approach |
|------|----------|
| Hermetic Blue | `TestBase_MorphoBlue` (ported Morpho + IRM + mocks) |
| Hermetic MetaMorpho | `TestBase_MetaMorpho` (where MetaMorpho exists) |
| Vault V2 | Domain under `external/morpho/vault-v2/`; Crane Service wrappers may be thin — factory `createVaultV2` + adapter setup |
| Production-first | Never mock Morpho/Vault SUT; use ports or fork binds |
| Profile | `FOUNDRY_PROFILE=morpho_port` for Morpho-heavy path work |
| RH fork | Bind `ROBINHOOD_MAIN.MORPHO*`; pick a **vault instance** address |
| SE tests | Inherit `TestBase_ERC4626StandardExchange` for S0; dual strategy needs new TestBase |

---

## 13. Source sketch (non-exhaustive)

External references consulted for this note (2026-08-02 research pass):

- Morpho addresses / Vault V2 concepts: docs.morpho.org  
- Gauntlet × Uniswap Earn × Morpho vaults (distribution pattern)  
- Steakhouse Morpho V2, Turbo/Term/Box adapter architecture  
- DeFi Saver Morpho vault risk tiers (Prime/Core/Steakhouse)  
- Uniswap ALM landscape (Gamma, Arrakis, Gauntlet ALM analysis)  
- Fluid smart-collateral / unified LP+lend product category  
- Galaxy / academic surveys of onchain yield (lending, AMM fees, engineered leverage)  
- ethresear.ch unified liquidity layer discussions  
- Crane `ROBINHOOD_MAIN` Morpho constant block  

Treat URLs and TVL figures as **time-sensitive**; re-check Morpho address pages and curator docs before shipping.

---

## 14. Open questions for a future PRD

1. Primary thesis: rate-first, fee-first, leverage, or unified?  
2. Host shell: IndexedEx diamond SE, Morpho V2 vault, or both (SE wraps Morpho V2)?  
3. Uni version: V3 only, V4 only, or dual (IndexedEx already has both SE packages)?  
4. Chain priority: Robinhood first (Vault V2 native) vs Base/ETH (MetaMorpho + V2)?  
5. Idle capital: Morpho supply only, or also Blue single-market without vault?  
6. Rebalance: keeper, public compound, Reactive, or fully user-triggered?  
7. DETF composition: is the product an SE leg for Single SE / MultiVault DETFs?

---

## 15. Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial research capture: Morpho wrap baseline, RH surface, Morpho/Uni strategy catalogs, S0–S6 map, IndexedEx decision tree |

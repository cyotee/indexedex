# Morpho + Uniswap Strategies Explained

**Date:** 2026-08-02  
**Status:** Strategy primer (companion to research map; not a product PRD)  
**Audience:** IndexedEx engineering and product design  
**Primary research map:** [`2026-08-02-morpho-uniswap-lending-mm-strategies.md`](./2026-08-02-morpho-uniswap-lending-mm-strategies.md)  
**Lending × CL MM protocol processes:** [`2026-08-02-lending-cl-mm-protocol-process-research.md`](./2026-08-02-lending-cl-mm-protocol-process-research.md)  
**Composition sketch:** [`2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md`](./2026-08-02-morpho-v2-uniswap-v4-composition-diagram.md)  
**In-flight product (S0 + V4 rate surface):** [`contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md`](../../../contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_BUFFER_AND_PRICING_HOOK_PRD.md)

This document **explains** the strategy families listed in the research note: what capital does, where yield comes from, what can go wrong, and how each maps onto IndexedEx / Morpho V2 / Uniswap V3–V4 shapes. Use the research note for the ranked map and decision tree; use this note when choosing or teaching a strategy.

---

## 0. How to read this primer

### 0.1 Two different product classes

| Class | What the user gets | Morpho role | Uniswap role |
|-------|--------------------|-------------|--------------|
| **Distribution / wrap** | One yield stream (usually Morpho rates), nicer UX | Back-end yield | Front door, router, or **rate-priced wrap pool** |
| **Dual / engineered strategy** | Combined or levered economics | Supply, borrow, or coll market | CL LP, ALM, or adapter inventory |

Most live “Morpho × Uniswap” products today are **distribution** (Uniswap Earn, Coinbase/Robinhood Earn). IndexedEx’s **Uniswap V4 Buffer and Pricing Hook** is also in that family: it does **not** market-make with concentrated liquidity; it prices **underlying ↔ SE shares** so Morpho (or any 4626 via SE) is swappable at the claim rate. Dual strategies (S1–S6) are a **different product class**.

### 0.2 Yield theses (pick one primary)

| Thesis | Capital job | Natural strategy IDs |
|--------|-------------|----------------------|
| **Rate-first** | Earn borrower demand on Morpho | S0, light S1 |
| **Fee-first** | Earn AMM fees (and manage IL) | S1, S2 |
| **Leverage / carry** | Amplify rates or LP with Morpho debt | S3, S4, Turbo-style S5 |
| **Unified capital efficiency** | Same inventory serves swap + lend | S6 |

### 0.3 Mental model: sleeves and shells

```text
USER SHARES (ERC-4626 or SE diamond)
        │
        ▼
   STRATEGY HOST  ─── IndexedEx SE diamond  OR  Morpho Vault V2 shell
        │
        ├─ Sleeve A: Morpho Blue supply / borrow / loop
        ├─ Sleeve B: Uniswap V3/V4 LP (or ALM manager)
        └─ Sleeve C: idle cash, hedges, term adapters, …
```

- **Shell** = share token + deposit/withdraw UX + (often) caps/roles.  
- **Sleeve** = where capital actually sits and how it earns.  
- **S0** is one shell, one Morpho sleeve, no Uni LP sleeve.  
- **S2** is one shell, two sleeves (rate + fee).  
- **S5** is Morpho V2 as shell, Uni as an **adapter** sleeve under Morpho governance.

---

## 1. Morpho-side strategy catalog

Basic Morpho supply (loan token → Vault V2 / MetaMorpho → Blue) is **not** listed here — it is protocol utility, not a Morpho×Uni strategy. IndexedEx wraps that path as **S0** infrastructure when needed.

### 1.1 Leveraged loop / carry (“Turbo”)

**Capital path (classic loop)**

```text
supply collateral on Morpho
  → borrow loan asset
  → buy more collateral (or swap into coll)
  → supply again
  → repeat until target leverage / LTV
```

Stable↔stable or basis-style loops appear when rate structure allows a positive carry after fees.

**Yield:** (levered supply APY − borrow APY) × leverage, minus gas, slippage, and liquidation buffer costs. Marketing often quotes multi-x **target** leverage; realized leverage and wind-down risk matter more than the headline.

**How Morpho V2 hosts it:** Not plain supply queues alone — **custom Box adapters** (Steakhouse Turbo narrative) so the vault can execute multi-step carry under vault caps and roles.

**Risks:** Liquidation; rate inversion (borrow > supply/loop edge); liquidity wind-down when many users exit; adapter trust and instant vs timelocked adapter adds.

**Strategy map IDs:** Leverage thesis; lives under **S3-like debt use** or **S5 Turbo-class adapters**, not under pure S0.

Term / fixed-maturity “Box” products (Steakhouse-style) are also **Morpho-only packaging** (constrained adapters, maturity-style holds) — not listed here unless a Uni adapter is in the same vault.

---

### 1.2 Raw Blue (isolated market)

**What it is:** User or bot picks full `MarketParams`: loan asset, collateral, oracle, IRM, LLTV. No curator.

**Yield / risk:** Fully on the chosen market. Maximum control, minimum packaging.

**Vault products** exist largely to **abstract** this for retail. IndexedEx S0 wraps vaults, not raw Blue supply shares (Blue is not IERC4626).

---

### 1.3 Morpho V2 as strategy host (architecture lesson)

| Concern | Lives on |
|---------|----------|
| ERC-4626 shares, deposit/withdraw | Vault V2 shell |
| Caps, IDs, roles, timelocks | Vault governance |
| Where capital sits | **Adapters** (Blue, Box, custom Uni, …) |

**Why it matters for Uni composition:** Complex Morpho + Uni products may fit **Vault V2 + Uni adapter** (**S5**) better than forcing all logic into a generic ERC-4626 SE alone. Steakhouse’s V1→V2 story: V1 mostly routed to Blue; V2 adapters unlock Term/Turbo-class behavior.

---

## 2. Uniswap V3 / V4 market-making catalog

Concentrated liquidity (CL) is **not** a constant 50/50 bag of two tokens. Capital sits in a **price range**. In range, inventory shifts as the market trades; out of range, you hold mostly one asset and earn little or no fee.

### 2.1 Full-range / wide range

**Idea:** Provide liquidity over a very wide band (approaching V2-like behavior).

**Yield:** Fee APR tends to be lower per unit of capital (fees spread thin); less frequent rebalance.

**Risks:** Still IL vs HODL, but fewer “stuck OOR” emergencies.

**Who ships it:** Manual LPs, conservative ALMs.

---

### 2.2 Narrow concentrated range

**Idea:** Tight ticks around current price for high fee density.

**Yield:** High fee APR **while in range**.

**Risks:** High IL; frequent OOR; rebalance cost can erase fees.

**Who ships it:** Aggressive manual LPs and aggressive ALMs.

---

### 2.3 Dynamic rebalance ALM

**Idea:** Automated Liquidity Manager keeps a range around the market; may auto-compound fees.

**Product = rebalance policy:** range width, how to rebalance (swap vs limit-style), fee compounding, when to park idle.

**Precedent:** Gamma, Arrakis, ICHI, and similar.

**IndexedEx note:** Pure ALM maps to **S1**; ALM + Morpho idle cash maps to **S1/S2**.

---

### 2.4 Inventory / asymmetric ranges

**Idea:** One-sided or skewed ranges — e.g. bootstrap a quote asset, DCA-like treasury distribution, or inventory that prefers to accumulate one side.

**Precedent:** Arrakis Pro Bootstrap, treasury strategies.

**Risks:** Explicit inventory bias (not “passive 50/50”); can underperform pure fee farming if the bias is wrong.

---

### 2.5 Uniswap V4 hooks (as market-making tools)

**Idea:** Hooks customize curve, dynamic fees, limit-order-like behavior, MEV controls, or **wrapper pricing**.

**Important split for IndexedEx:**

| Hook use | What capital does | Strategy family |
|----------|-------------------|-----------------|
| **CL + rule engine** | Real tick liquidity, fees, IL | S1–S4 / S6 territory |
| **Wrapper / buffer pricing** | No CL; swap = deposit/redeem into vault | **S0 surface**, not fee MM |

The **Uniswap V4 Buffer and Pricing Hook** is the second row: fee = 0, no add-liquidity, price from SE previews (Morpho interest via SE underlying paths).

---

### 2.6 Stable–stable concentrated liquidity

**Idea:** Tiny ranges around peg for correlated pairs.

**Yield:** Swap fees with low IL if the peg holds.

**Risks:** Depeg; then range and inventory break like any CL.

---

### 2.7 Composability constraint: LP is an NFT

V3/V4 positions are **NFTs**, not V2-style fungible LP tokens. Using “LP as Morpho collateral” usually requires:

- a **manager vault share** (ERC-20 claim on the NFT), or  
- a **custom Morpho market + oracle** over that share,  

not naive NFT deposit into Blue. This is why **S4** is hard on Morpho relative to Aave-class designs that already wrestled with Uni V3 coll.

IndexedEx already has pure Uni V3/V4 **Standard Exchange** packages for LP vault shapes under `contracts/protocols/dexes/uniswap/v3/` and `v4/`.

---

## 3. Cross-protocol: lend + market make

### 3.1 Levered LP (LP as collateral) — map ID **S4**

```text
mint Uni V3/V4 position
  → post as collateral on lending market
  → borrow
  → add more liquidity
  → repeat
```

**Yield:** Levered LP fees (and residual price exposure) minus borrow cost and liquidation risk.

**Precedent:** More Aave + Uni V3 / Contango-class than native Morpho products.

**Why Morpho is hard:** Blue needs ERC-20-ish coll + oracle + LLTV. NFT positions are non-standard.

**When to design:** Only after coll representation, oracle, and liquidation paths are explicit product law.

---

### 3.2 Borrow cheap → LP the proceeds — map ID **S3**

```text
post blue-chip coll on Morpho (or Aave)
  → borrow USDC (or other loan asset)
  → LP USDC/X on Uniswap
```

**Yield:** LP fees − borrow APY − IL (and funding of the coll asset’s opportunity cost).

**Character:** Fixed or managed leverage on the **debt** sleeve; LP is the **risk asset** sleeve. Common as manual or bot strategies when coll is liquid and oracle-safe.

**Risks:** Liquidation on Morpho; rate inversion; IL on Uni; correlation between coll crash and LP book.

---

### 3.3 Supply idle leg, LP active leg — map IDs **S1 / S2**

```text
when in range / high edge:  capital on Uni CL
when OOR / low edge:        stables (or loan asset) on Morpho supply
```

**Yield:** Blend of fee APR and rate APR over time; allocator decides the mix.

**Character:** Market-maker **inventory management** across a rate market and an AMM — often ALM + separate lend sleeve rather than one atomic protocol.

**S1 vs S2:**

- **S1:** Uni ALM is the product; Morpho is optional cash parking.  
- **S2:** Explicit dual-sleeve product (% Morpho + % Uni) with a clear rate+fee narrative (Yearn multi-strategy spirit).

---

### 3.4 Unified liquidity (Fluid / research) — map ID **S6**

**Idea:** Same capital simultaneously provides **swap depth** and **borrowable liquidity** (“smart collateral”). Not “two independent yields,” but **one inventory, two jobs**.

**Precedent:** Fluid-style markets; research on unified liquidity layers (DEX + lending sharing inventory).

**Difficulty:** Very high — accounting, liquidation, oracle, and MEV all couple. New product class relative to IndexedEx SE wraps.

---

### 3.5 Delta-neutral / basis-ish

**Idea:** LP + hedge (perp/short), or lend one side while shorting the other, to harvest fees/rates with reduced directional risk.

**Character:** Structured yield (Cian-class stacks, engineered leverage) more than a plain Morpho vault.

**Galaxy-style stack mental model:** base rates → engineered products → activity yield (AMM fees).

**IndexedEx:** Not a first ladder step; introduce only after S0–S2 (or S5) shells are solid.

---

### 3.6 Morpho V2 adapter hosts Uni — map ID **S5**

```text
User → Morpho Vault V2 shares
         ├─ Adapter: Morpho Blue markets (supply / possibly more)
         └─ Adapter: Uni V3/V4 positions (or ALM manager)
```

**Yield:** Whatever adapters return, subject to vault caps and `realAssets` reporting.

**Why RH-aligned:** Robinhood Morpho is Vault V2 native; advanced strategies in that ecosystem already teach **adapters under a 4626 shell** (Turbo/Term/Box).

**Governance:** Caps, wind-down, roles at vault layer; strategy risk in adapters.

**Vs IndexedEx diamond host:** S5 puts Morpho’s shell in charge; IndexedEx may still wrap the Morpho vault as S0 for registry/DETF, or build a dual-sleeve SE instead (**S2**).

---

## 4. Strategy map IDs (S0–S6) in depth

### S0 — Pure Morpho V2 wrap (generic ERC-4626 SE)

| | |
|--|--|
| **One-liner** | User holds SE (or app) shares that are 1:1 economically with Morpho Vault V2 (or MetaMorpho) supply. |
| **Morpho role** | Entire productive capital (supply vault). |
| **Uni role** | None required for the strategy; optional **swap UX** via V4 buffer/pricing hook. |
| **Yield** | Morpho / 4626 protocol interest. |
| **Difficulty** | Low (infra + fork proof). |
| **Precedent** | Uni Earn, Coinbase/RH Earn. |

**Capital flow**

```text
loanToken  ↔  Morpho Vault V2 shares  ↔  ERC4626 SE shares
                 deployVault(vaultInstance)   // not the factory
```

**IndexedEx path:** `contracts/vaults/standard/erc4626/` — do **not** invent a Morpho-named SE solely to wrap supply.

**V4 Buffer and Pricing Hook relationship**

```text
User swaps on Uni V4 pool:  underlying  ↔  SE shares
Hook: beforeSwap deltas priced by SE previewExchange*
SE: deposit/redeem Morpho (or other 4626) under the hood
```

That makes Morpho **tradeable at claim rate** on Uniswap without turning the product into CL market making. Hook PRD non-goals explicitly exclude levered LP, borrow, and dual-sleeve (**not S2–S6**).

**Ship value:** Validates Morpho instance pin, SE routes, fees, interest accrual proofs, RH/Base forks — foundation for later dual strategies.

---

### S1 — Uni ALM only; Morpho optional for idle stables

| | |
|--|--|
| **One-liner** | Product is automated concentrated liquidity; Morpho is a parking lot for idle cash when LP edge is low. |
| **Morpho role** | Optional idle sleeve. |
| **Uni role** | Primary: CL LP / ALM. |
| **Yield** | Fee-first; rates secondary. |
| **Difficulty** | Medium (rebalance policy + ops). |
| **Precedent** | Gamma / Arrakis-class ALMs. |

**When idle capital sits on Morpho:** OOR, wide quiet markets, or explicit “cash buffer %” policy.

**Risks:** IL and rebalance MEV dominate; Morpho adds only rate + withdraw liquidity risk on the idle sleeve.

**IndexedEx path:** Uni V3/V4 SE or ALM package + optional ERC4626 SE for idle Morpho — not the buffer hook alone (hook has no CL).

---

### S2 — Dual sleeve: % Morpho supply + % Uni LP

| | |
|--|--|
| **One-liner** | One vault share; allocator splits capital between Morpho rates and Uni fees. |
| **Morpho role** | Rate-yield sleeve (supply). |
| **Uni role** | Fee-yield sleeve (CL or ALM). |
| **Yield** | Explicit blend; narrative is “rates + fees.” |
| **Difficulty** | Medium (allocation, reporting, rebalance). |
| **Precedent** | Yearn multi-strategy spirit. |

**Example policy (illustrative)**

```text
target: 60% Morpho USDC supply, 40% Uni USDC/WETH ALM
rebalance when drift > band or ALM goes OOR
```

**Risks:** Two risk systems in one product (credit/oracle vs IL/rebalance); users must understand both; NAV reporting must not double-count or lag sleeves.

**Host choice:**

- IndexedEx multi-strategy SE diamond, or  
- Morpho V2 multi-adapter (**S5** shape with both Blue and Uni adapters).

Research ladder recommends **S2 after S0** as the first true dual-protocol **product thesis**.

---

### S3 — Borrow on Morpho → LP on Uni (fixed leverage)

| | |
|--|--|
| **One-liner** | Post coll, borrow loan asset, put borrowed proceeds into Uni LP. |
| **Morpho role** | Debt (and coll market). |
| **Uni role** | LP of borrowed proceeds (+ maybe coll residual). |
| **Yield** | LP fees − borrow APY − IL. |
| **Difficulty** | Med–High. |
| **Precedent** | Manual leverage, Contango-class automation. |

**Health factor is the product:** leverage target, liquidation buffer, and when to de-lever must be product law, not an afterthought.

**Risks:** Liquidation cascades; borrow rate spikes; LP book moves against coll; forced unwind costs.

**Do not start here** without S0-quality Morpho integration and an explicit coll/oracle story.

---

### S4 — Levered LP (LP coll → borrow → more LP)

| | |
|--|--|
| **One-liner** | LP is collateral; borrow against it to mint more LP (recursive). |
| **Morpho role** | Coll market over LP representation. |
| **Uni role** | Both inventory and coll source. |
| **Yield** | Highly levered fee exposure. |
| **Difficulty** | High (oracle + NFT/wrapper + liquidation). |
| **Precedent** | Aave+Uni more than Morpho-native. |

**Hardest Morpho-specific issue:** representing V3/V4 NFT (or vault share) as Blue coll with a safe oracle.

**Wind-down:** Thin buffers and correlated stress (LP value down while debt fixed) are the failure mode.

---

### S5 — Morpho V2 + custom Uni adapter

| | |
|--|--|
| **One-liner** | Morpho Vault V2 is the user shell; Uni positions live inside a vault adapter under Morpho-style caps. |
| **Morpho role** | Shell + caps + (often) Blue adapters too. |
| **Uni role** | Adapter-held V3/V4 or ALM. |
| **Yield** | Adapter-defined mix (can look like S2 or Turbo). |
| **Difficulty** | High; **RH-aligned**. |
| **Precedent** | Steakhouse Turbo/Term/Box architecture with Uni as custom domain. |

**Why choose S5 over pure IndexedEx S2 shell:**

- Want Morpho Vault V2 governance, ID/cap risk, curator tooling, RH Earn-adjacent packaging.  
- Want multi-adapter strategies industry already understands on Morpho V2.

**Why choose IndexedEx diamond instead:**

- Registry, fee oracle, DETF legs, multi-protocol SE composition already centered on IndexedEx diamonds.

**Hybrid:** Morpho V2 runs strategy; IndexedEx **S0-wraps** the Morpho vault for discovery/fees/DETF — user may never touch adapters directly.

**Adapter risk notes (from research):** `realAssets` gas/DoS if too many heavy adapters; curator trust on instant adapter adds vs timelocks.

---

### S6 — Fluid-like unified liquidity

| | |
|--|--|
| **One-liner** | One inventory book that is both AMM depth and borrowable liquidity. |
| **Morpho role** | Shared inventory (not a separate sleeve). |
| **Uni role** | Shared inventory (not a separate sleeve). |
| **Yield** | Capital efficiency (fees + lending on same dollars). |
| **Difficulty** | Very high. |
| **Precedent** | Fluid / research designs. |

**Not** “60/40 dual sleeve.” Accounting and liquidation couple swap and borrow continuously.

**IndexedEx decision tree:** treat as **new product class**, not a thin extension of ERC4626 SE or buffer hook.

---

## 5. How strategies relate to IndexedEx building blocks

| Building block | Supports |
|----------------|----------|
| Generic ERC-4626 SE (`contracts/vaults/standard/erc4626/`) | **S0**; Morpho V2 / MetaMorpho / sfrxETH / Stata-class wraps |
| Uni V3 / V4 Standard Exchange packages | Pure LP legs for **S1–S4** |
| Uni V4 Buffer and Pricing Hook | **S0 swap surface** (underlying ↔ SE); not CL MM |
| Morpho Blue Crane port + TestBases | Hermetic Morpho for S0+ proofs |
| Morpho Vault V2 + adapters | **S5** (and Turbo/Term-class) |
| Custom IndexedEx multi-sleeve SE | **S2** (and possibly S3 with debt module) |
| DETF families | May consume **SE shares as a leg** later; hook itself is not a DETF (hook PRD D64 independence) |

**Decision tree (from research, restated)**

```text
Pure supply into existing Morpho IERC4626?
  YES → ERC4626 SE (S0)  [+ optional V4 buffer hook for swap UX]
  NO  → Dual-sleeve without Morpho borrow?
          YES → IndexedEx multi-sleeve SE or Morpho V2 multi-adapter (S2 / S5)
          NO  → Borrow or levered LP?
                  YES → Explicit coll oracle + liquidation (S3 / S4)
                  NO  → Unified liquidity (S6) — new product class
```

---

## 6. Risk cheat sheet by strategy ID

| ID | Primary failure modes |
|----|----------------------|
| **S0** | Curator/market risk; withdraw liquidity; SE/protocol integration bugs; interest mispricing if previews wrong |
| **S1** | IL; OOR; rebalance cost/MEV; ALM policy error |
| **S2** | All of S0 + S1; bad allocation; opaque blended NAV |
| **S3** | Liquidation; rate inversion; IL on borrowed book |
| **S4** | Oracle/coll design; recursive leverage unwind; NFT representation |
| **S5** | Adapter trust; caps/wind-down; `realAssets` complexity; Uni IL inside Morpho shell |
| **S6** | Coupled liquidation + AMM accounting; novel mechanism risk |

---

## 7. Recommended exploration ladder (why this order)

1. **S0** — Ship Morpho wrap + interest-correct previews. Optional: V4 buffer/pricing hook so SE↔underlying is a Uni pool. Proves infra, not dual strategy.  
2. **S2** — First dual **product thesis** with a clear rate+fee story and no Morpho debt.  
3. **S5** — If RH-native Morpho V2 governance/caps matter more than IndexedEx as sole shell (or as host for adapters).  
4. **S3 / S4** — Only after coll representation, liquidation, and oracles are written as product law.  
5. **S6** — Only as an intentional new protocol design, not a feature flag on S2.

**Currently in flight (2026-08-02):** Buffer and Pricing Hook PRD implements the **S0 + V4 rate surface** lane (with mandatory ERC-4626 SE route fixes). It intentionally **does not** implement S1–S6 dual or levered strategies.

---

## 8. Worked comparisons

### 8.1 “Is the buffer hook a Morpho + Uniswap strategy?”

**Yes as composition; no as dual strategy.**

- Composition: Morpho yield + Uniswap V4 swap surface + SE mediation.  
- Not dual strategy: no CL LP sleeve, no Morpho borrow, no fee APR from ticks.  
- Closest labels: **S0** + **wrapper / buffer pool** (rate-priced wrap, not CL MM).

### 8.2 S2 vs S5 for “rates + Uni fees”

| | **S2 (IndexedEx dual sleeve)** | **S5 (Morpho V2 + Uni adapter)** |
|--|-------------------------------|----------------------------------|
| User share token | IndexedEx SE / vault diamond | Morpho Vault V2 |
| Risk controls | IndexedEx / fee oracle / custom | Morpho caps, IDs, roles, timelocks |
| Uni inventory | SE or ALM module | Adapter |
| RH narrative fit | Via wrap of anything | Native Morpho V2 story |
| DETF leg | Natural SE share | Wrap Morpho vault as SE (S0) then DETF |

### 8.3 S3 vs S4 leverage

| | **S3** | **S4** |
|--|--------|--------|
| What is coll? | Blue-chip (ETH, LSTs, …) | LP position / LP vault share |
| What is levered? | LP built from **borrowed** cash | LP that **is** the coll |
| Morpho fit today | Easier if coll markets exist | Hard (NFT/oracle) |
| Liquidation trigger | Coll price / HF | LP NAV / HF (often more fragile) |

---

## 9. Glossary (short)

| Term | Meaning here |
|------|----------------|
| **Blue** | Morpho Blue isolated lending markets |
| **Vault V2** | Permissionless Morpho vault shell + adapters (IERC4626) |
| **MetaMorpho** | Curated 4626 over Blue (not listed as RH Morpho surface in Crane constants) |
| **Adapter** | Strategy module under Vault V2 where capital actually sits |
| **SE** | IndexedEx Standard Exchange vault (diamond share token + exchange routes) |
| **ALM** | Automated liquidity manager for CL ranges |
| **CL** | Concentrated liquidity (V3/V4 ticks) |
| **Wrapper / buffer pool** | V4 pool with fee 0, no CL; swaps wrap/unwrap a vault at claim rate |
| **IL** | Impermanent loss vs holding the tokens outside the pool |
| **OOR** | Out of range (CL earns little/no fees) |

---

## 10. Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial strategy explanations companion: Morpho/Uni catalogs, S0–S6 deep dives, IndexedEx mapping, link to buffer/pricing hook as S0 surface |
| 2026-08-02 | Removed former §1 industry pass-through / distribution patterns (UI Earn, retail Earn sandwich) — not strategy capital; already covered briefly in §0.1 |
| 2026-08-02 | Removed Morpho passive/curated supply from §1 catalog — basic Morpho utility, not a listed strategy |
| 2026-08-02 | Removed Term/fixed-maturity from §1 catalog — Morpho-only packaging, not Morpho×Uni |
